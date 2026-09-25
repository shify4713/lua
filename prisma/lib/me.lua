-- PRISMA · me: слой доступа к ME-сети (AE2 через OpenComputers)
-- Все запросы идут через очередь с ограничением скорости, чтобы интерфейс не подвисал.
-- API OC: getItemsInNetwork({name=,damage=}), getCraftables({name=,damage=}), getCpus(), craftable.request(n[,prio[,cpu]])
local P = ...
local U = P.util
local log = P.log

local M = {}
local dev
local queue, pending = {}, {}
local cpuCache = { list = {}, total = 0, busy = 0, at = -1e9, ok = false }
local powerCache = { at = -1e9 }

M.online = nil       -- nil = неизвестно, true/false после первого ответа
M.lastErr = nil
M.addr, M.type = nil, nil
M.calls, M.errors = 0, 0

function M.init()
  queue, pending = {}, {}
  local d, a, t = U.findComp({ "me_interface", "me_controller", "ae2_interface" }, P.cfg.devices.me)
  dev, M.addr, M.type = d, a, t
  M.online = nil
end

function M.available() return dev ~= nil end

local function markOk()
  if M.online == false and M.warned then
    log.info("ME", "связь с ME-сетью восстановлена")
    M.warned = false
  end
  M.online = true
  M.lastErr = nil
end

local function markFail(err)
  M.errors = M.errors + 1
  M.lastErr = tostring(err)
  local now = U.now()
  M.retryAt = now + 5
  if M.online ~= false and now - (M.lastWarn or -1e9) > 60 then
    log.warn("ME", "сеть недоступна: " .. U.trunc(tostring(err):gsub("\n.*", ""), 60))
    M.lastWarn = now
    M.warned = true
  end
  M.online = false
end

-- ───────── количество предмета ─────────
function M.rawQty(name, dmg)
  if not dev then return nil, "нет ME" end
  M.calls = M.calls + 1
  local filter = { name = name }
  if dmg ~= nil then filter.damage = dmg end
  local ok, res = pcall(dev.getItemsInNetwork, filter)
  if not ok then markFail(res); return nil, res end
  markOk()
  local q = 0
  if type(res) == "table" then
    for i = 1, (res.n or #res) do
      local s = res[i]
      if type(s) == "table" then q = q + (tonumber(s.size) or 0) end
    end
  end
  return q
end

-- поставить запрос в очередь; cb(qty | nil, err)
function M.qty(name, dmg, cb, urgent)
  local key = tostring(name) .. ":" .. tostring(dmg or 0)
  local job = pending[key]
  if job then
    job.cbs[#job.cbs + 1] = cb
    return
  end
  job = { key = key, name = name, dmg = dmg, cbs = { cb } }
  pending[key] = job
  if urgent then table.insert(queue, 1, job) else queue[#queue + 1] = job end
end

function M.queueSize() return #queue end

-- обработать не больше n запросов за проход
function M.pump(n)
  if not dev then
    if #queue > 0 then
      local q = queue
      queue, pending = {}, {}
      for _, job in ipairs(q) do
        for _, cb in ipairs(job.cbs) do pcall(cb, nil, "нет ME") end
      end
    end
    return
  end
  n = n or 2
  if M.online == false and U.now() < (M.retryAt or 0) then return end
  while n > 0 and #queue > 0 do
    local job = table.remove(queue, 1)
    pending[job.key] = nil
    local q, err = M.rawQty(job.name, job.dmg)
    for _, cb in ipairs(job.cbs) do
      local ok, e = pcall(cb, q, err)
      if not ok then log.warn("ME", "callback: " .. U.trunc(tostring(e), 60)) end
    end
    n = n - 1
    if M.online == false then break end   -- сеть лежит: не долбим
  end
end

-- ───────── процессоры крафта ─────────
function M.cpus(maxAge)
  local now = U.now()
  if not dev then return cpuCache end
  if now - cpuCache.at < (maxAge or 3) then return cpuCache end
  if M.online == false and now < (M.retryAt or 0) then return cpuCache end
  cpuCache.at = now
  M.calls = M.calls + 1
  local ok, res = pcall(dev.getCpus)
  if ok and type(res) == "table" then
    markOk()
    local list, busy = {}, 0
    for i = 1, (res.n or #res) do
      local c = res[i]
      if type(c) == "table" then
        list[#list + 1] = { name = c.name or "", busy = c.busy and true or false, storage = c.storage, cop = c.coprocessors }
        if c.busy then busy = busy + 1 end
      end
    end
    cpuCache.list, cpuCache.total, cpuCache.busy, cpuCache.ok = list, #list, busy, true
  else
    cpuCache.ok = false
    if not ok then markFail(res) end
  end
  return cpuCache
end

function M.invalidateCpus() cpuCache.at = -1e9 end

-- ───────── заказ крафта ─────────
-- возвращает handle либо nil, причина
function M.request(name, dmg, amount, cpuName)
  if not dev then return nil, "нет ME" end
  M.calls = M.calls + 1
  local filter = { name = name }
  if dmg ~= nil then filter.damage = dmg end
  local ok, cr = pcall(dev.getCraftables, filter)
  if not ok then markFail(cr); return nil, "ME: " .. U.trunc(tostring(cr), 40) end
  markOk()
  if type(cr) ~= "table" or (cr.n or #cr) < 1 then return nil, "нет рецепта" end
  local c = cr[1]
  local ok2, h, err
  if cpuName and cpuName ~= "" then
    ok2, h, err = pcall(c.request, amount, false, cpuName)
  else
    ok2, h, err = pcall(c.request, amount, false)
  end
  if not ok2 then return nil, U.trunc(tostring(h), 40) end
  if not h then return nil, U.trunc(tostring(err or "отказ ME (нет CPU / ресурсов)"), 40) end
  return h
end

-- состояние заказа: done | canceled | failed | computing | running
function M.status(h)
  if not h then return "unknown" end
  local function q(name)
    local okf, f = pcall(function() return h[name] end)
    if not okf or type(f) ~= "function" then return nil end
    local ok, v = pcall(f)
    if ok then return v end
    return nil
  end
  if q("isCanceled") then return "canceled" end
  if q("hasFailed") then return "failed" end
  if q("isDone") then return "done" end
  if q("isComputing") then return "computing" end
  return "running"
end

function M.cancel(h)
  if not h then return end
  pcall(function() return h.cancel() end)
end

-- ───────── списки для выбора предметов ─────────
-- весь список предметов сети (тяжёлый вызов — только по запросу пользователя)
function M.listNetwork(limit)
  if not dev then return nil, "нет ME" end
  M.calls = M.calls + 1
  local ok, res = pcall(dev.getItemsInNetwork)
  if not ok then markFail(res); return nil, tostring(res) end
  markOk()
  local out = {}
  limit = limit or 6000
  if type(res) == "table" then
    for i = 1, (res.n or #res) do
      local s = res[i]
      if type(s) == "table" and s.name then
        local label = s.label or s.name
        out[#out + 1] = {
          name = s.name, damage = s.damage or 0, label = label, size = tonumber(s.size) or 0,
          craft = s.isCraftable and true or false,
          key = U.lower(label .. " " .. s.name),
        }
        if #out >= limit then break end
      end
    end
  end
  res = nil
  if collectgarbage then pcall(collectgarbage) end
  table.sort(out, function(a, b)
    if a.label ~= b.label then return a.label < b.label end
    if a.name ~= b.name then return a.name < b.name end
    return a.damage < b.damage
  end)
  return out
end

-- предмет из конфиг-слота интерфейса
function M.configSlot(slot)
  if not dev then return nil, "нет ME" end
  slot = slot or 1
  for _, fn in ipairs({ "getInterfaceConfiguration", "getStackInSlot" }) do
    if type(dev[fn]) == "function" then
      local ok, s = pcall(dev[fn], slot)
      if ok and type(s) == "table" and s.name then
        return { name = s.name, damage = s.damage or 0, label = s.label or s.name }
      end
    end
  end
  return nil, "слот " .. slot .. " интерфейса пуст"
end

-- энергия ME-сети
function M.power()
  if not dev then return nil end
  local now = U.now()
  if now - powerCache.at < 5 then return powerCache end
  powerCache.at = now
  local function g(n)
    if type(dev[n]) ~= "function" then return nil end
    local ok, v = pcall(dev[n])
    return ok and tonumber(v) or nil
  end
  powerCache.stored, powerCache.max, powerCache.usage = g("getStoredPower"), g("getMaxStoredPower"), g("getAvgPowerUsage")
  return powerCache
end

return M
