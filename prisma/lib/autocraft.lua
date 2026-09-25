-- PRISMA · autocraft: автокрафт с настройками на каждый предмет
--   • держим нужное количество (keep) либо «сделать N и остановиться» (once)
--   • порог запуска (trigger %), партия (batch), приоритет, пауза после ошибки, тайм-аут
--   • прогресс, время и ETA по каждому активному крафту
local P = ...
local U = P.util
local log = P.log
local me = P.me

local A = {}
local items = {}
local history = {}
local paused = false
local dirty = false
local lastSave = 0
local nextScanAll = 0
A.stats = { done = 0, failed = 0, units = 0, started = 0 }

local SAVE_FIELDS = { "name", "damage", "label", "keep", "batch", "trigger", "prio", "enabled", "cooldown", "timeout", "once", "goal", "note", "total", "runs" }

local function cfg() return P.cfg.autocraft end
local function path() return P.dataDir .. "/autocraft.dat" end

-- ───────── сохранение / загрузка ─────────
local function save()
  local out = {}
  for _, it in ipairs(items) do
    local t = {}
    for _, k in ipairs(SAVE_FIELDS) do t[k] = it[k] end
    out[#out + 1] = t
  end
  U.writeTable(path(), { v = 1, items = out, stats = A.stats })
  dirty = false
  lastSave = U.now()
end

local function markDirty() dirty = true end
A.markDirty = markDirty

local function newRt()
  return { state = "scan", stateAt = U.now(), nextScan = 0, nextTry = 0, cool = 0, fails = 0 }
end

local function normalize(it)
  it.name = tostring(it.name)
  it.damage = tonumber(it.damage) or 0
  it.label = it.label or it.name
  it.keep = math.max(1, math.floor(tonumber(it.keep) or cfg().defaultKeep))
  it.batch = math.max(1, math.floor(tonumber(it.batch) or cfg().defaultBatch))
  it.trigger = U.clamp(tonumber(it.trigger) or 100, 1, 100)
  it.prio = U.clamp(math.floor(tonumber(it.prio) or 5), 1, 9)
  if it.enabled == nil then it.enabled = true end
  it.total = tonumber(it.total) or 0
  it.runs = tonumber(it.runs) or 0
  it.rt = it.rt or newRt()
  return it
end

function A.init()
  items = {}
  history = {}
  paused = false
  local t = U.readTable(path())
  if t and type(t.items) == "table" then
    for _, s in ipairs(t.items) do items[#items + 1] = normalize(s) end
    if type(t.stats) == "table" then for k, v in pairs(t.stats) do A.stats[k] = v end end
  else
    -- миграция со старого precraft_bd.txt
    local old = U.readTable(P.base .. "/precraft_bd.txt")
    if old then
      for _, o in ipairs(old) do
        if type(o) == "table" and (o.id or o.name) then
          items[#items + 1] = normalize({
            name = o.id or o.name, damage = o.dmg or 0, label = o.name,
            keep = o.count, batch = o.craftSize,
          })
        end
      end
      if #items > 0 then
        log.info("АВТОКРАФТ", "импортировано из старой базы: " .. #items)
        save()
      end
    end
  end
  local now = U.now()
  for i, it in ipairs(items) do it.rt.nextScan = now + (i - 1) * 0.15 end
end

-- ───────── доступ ─────────
function A.items() return items end
function A.count() return #items end
function A.history() return history end
function A.isActive() return cfg().enabled and true or false end
function A.isPaused() return paused end

function A.setActive(v)
  cfg().enabled = v and true or false
  paused = false
  P.config.markDirty()
  log.info("АВТОКРАФТ", v and "включён" or "выключен")
  if v then A.rescan() end
end

function A.togglePause()
  paused = not paused
  log.info("АВТОКРАФТ", paused and "пауза" or "продолжаем")
end

function A.rescan()
  for _, it in ipairs(items) do it.rt.nextScan = 0 end
end

function A.find(name, damage)
  for _, it in ipairs(items) do
    if it.name == name and it.damage == (tonumber(damage) or 0) then return it end
  end
end

function A.add(spec)
  if not spec or not spec.name or spec.name == "" then return nil, "не указан id предмета" end
  if A.find(spec.name, spec.damage) then return nil, "предмет уже в списке" end
  local it = normalize({
    name = spec.name, damage = spec.damage, label = spec.label,
    keep = spec.keep or cfg().defaultKeep, batch = spec.batch or cfg().defaultBatch,
  })
  items[#items + 1] = it
  it.rt.nextScan = 0
  markDirty()
  log.info("АВТОКРАФТ", "добавлен: " .. it.label)
  return it
end

function A.remove(it)
  for i, x in ipairs(items) do
    if x == it then
      if it.rt.req then me.cancel(it.rt.req) end
      table.remove(items, i)
      markDirty()
      return true
    end
  end
  return false
end

-- применить изменения из формы
function A.apply(it, v)
  for k, val in pairs(v) do it[k] = val end
  normalize(it)
  it.goal = nil            -- цель для «once» пересчитается
  it.rt.nextScan = 0
  markDirty()
end

function A.cancel(it)
  if it.rt.req then
    me.cancel(it.rt.req)
    it.rt.req = nil
    it.rt.state = "ok"
    it.rt.nextTry = U.now() + 5
    log.info("АВТОКРАФТ", "отменён: " .. it.label)
  end
end

function A.importSlot(slot)
  local s, err = me.slotItem(slot or 1)
  if not s then return nil, err end
  local it, e = A.add(s)
  if not it then return nil, e end
  return it
end

-- ───────── логика по одному предмету ─────────
local function target(it)
  if it.once then return it.goal or it.keep end
  return it.keep
end
A.target = target

local function setState(it, st, reason)
  local rt = it.rt
  if rt.state ~= st then rt.state = st; rt.stateAt = U.now() end
  rt.reason = reason
end

local function finish(it, okFlag, reason)
  local rt = it.rt
  local now = U.now()
  local gained = math.max(0, (rt.have or 0) - (rt.startHave or 0))
  local dur = now - (rt.startAt or now)
  if okFlag then
    A.stats.done = A.stats.done + 1
    local made = math.max(gained, 0)
    if made == 0 then made = rt.reqAmount or 0 end
    A.stats.units = A.stats.units + made
    it.total = it.total + made
    it.runs = it.runs + 1
    rt.dur = dur
    rt.fails = 0
    history[#history + 1] = { label = it.label, amount = made, dur = dur, t = now }
    while #history > 30 do table.remove(history, 1) end
    setState(it, "ok")
  else
    A.stats.failed = A.stats.failed + 1
    rt.fails = rt.fails + 1
    rt.nextTry = now + (it.cooldown or cfg().cooldown)
    setState(it, "fail", reason)
    if rt.lastLogged ~= reason then
      log.warn("АВТОКРАФТ", it.label .. ": " .. tostring(reason))
      rt.lastLogged = reason
    end
  end
  rt.req = nil
  rt.cool = now + 3
  rt.nextScan = now + 3.1
  markDirty()
end

local function onStock(it, q, err)
  local rt = it.rt
  local now = U.now()
  rt.scanBusy = false
  if q == nil then
    rt.err = err
    if not rt.have then setState(it, "scan") end
    return
  end
  rt.err = nil
  rt.have = q
  rt.haveAt = now
  if it.once and not it.goal then it.goal = q + it.keep; markDirty() end
  local tgt = target(it)

  if rt.req then
    local st = me.status(rt.req)
    if q ~= rt.lastHave then rt.lastHave = q; rt.lastProgress = now end
    local gained = q - (rt.startHave or q)
    local timeout = it.timeout or cfg().timeout
    if st == "done" or q >= tgt or gained >= (rt.reqAmount or 1) then
      finish(it, true)
    elseif st == "canceled" then
      finish(it, false, "отменён в ME")
    elseif st == "failed" then
      finish(it, false, "ошибка ME")
    elseif now - rt.startAt > timeout and now - (rt.lastProgress or rt.startAt) > timeout / 2 then
      me.cancel(rt.req)
      finish(it, false, "таймаут")
    else
      setState(it, st == "computing" and "plan" or "crafting")
    end
    return
  end

  if not it.enabled then setState(it, "off"); return end
  if q >= tgt then
    setState(it, "ok")
    if it.once then
      it.enabled = false
      it.goal = nil
      markDirty()
      log.info("АВТОКРАФТ", it.label .. ": цель достигнута, отключён")
    end
    return
  end
  local trig = tgt * (it.trigger or 100) / 100
  if q < trig then
    rt.want = true
    if (rt.state == "fail" or rt.state == "norecipe") and now < rt.nextTry then
      -- держим состояние ошибки до конца паузы
    elseif not cfg().enabled then setState(it, "idle")
    elseif paused then setState(it, "pause")
    else setState(it, "want") end
  else
    rt.want = false
    setState(it, "ok")
  end
end

-- ───────── отправка заказов ─────────
local function dispatch(now)
  if not cfg().enabled or paused then return end
  if not me.available() or me.online == false then return end
  local running = 0
  for _, it in ipairs(items) do if it.rt.req then running = running + 1 end end
  local slots = cfg().limit - running
  if slots <= 0 then return end
  local cpus = me.cpus(2)
  if cpus.ok and cpus.total > 0 then
    slots = math.min(slots, cpus.total - cpus.busy - (cfg().reserveCpus or 0))
  end
  if slots <= 0 then return end

  local cand = {}
  for i, it in ipairs(items) do
    local rt = it.rt
    if it.enabled and rt.want and not rt.req and rt.have and now >= (rt.nextTry or 0) and now >= (rt.cool or 0)
       and rt.haveAt and rt.haveAt >= (rt.cool or 0) then
      local tgt = target(it)
      cand[#cand + 1] = { it = it, i = i, ratio = (tgt - rt.have) / tgt }
    end
  end
  if #cand == 0 then return end
  table.sort(cand, function(a, b)
    if a.it.prio ~= b.it.prio then return a.it.prio > b.it.prio end
    if a.ratio ~= b.ratio then return a.ratio > b.ratio end
    return a.i < b.i
  end)

  for _, c in ipairs(cand) do
    if slots <= 0 then break end
    local it, rt = c.it, c.it.rt
    local need = target(it) - rt.have
    local amount = math.max(1, math.floor(math.min(it.batch, need)))
    local h, err = me.request(it.name, it.damage, amount)
    if h then
      rt.req = h
      rt.reqAmount = amount
      rt.startHave = rt.have
      rt.startAt = now
      rt.lastProgress = now
      rt.lastHave = rt.have
      rt.lastLogged = nil
      A.stats.started = A.stats.started + 1
      setState(it, "plan")
      rt.nextScan = now + 2
      slots = slots - 1
      me.invalidateCpus()
    else
      rt.fails = rt.fails + 1
      rt.nextTry = now + (it.cooldown or cfg().cooldown)
      A.stats.failed = A.stats.failed + 1
      local st = (err == "нет рецепта") and "norecipe" or "fail"
      setState(it, st, err)
      if rt.lastLogged ~= err then
        log.warn("АВТОКРАФТ", it.label .. ": " .. tostring(err))
        rt.lastLogged = err
      end
      if me.online == false then break end
    end
  end
end

-- ───────── главный тик (вызывается ~2 раза в секунду) ─────────
function A.update(now)
  now = now or U.now()
  local offline = (me.online == false)
  for _, it in ipairs(items) do
    local rt = it.rt
    if now >= rt.nextScan and not rt.scanBusy then
      rt.scanBusy = true
      local interval = rt.req and 3 or cfg().scan
      if offline then interval = math.max(interval, 15) end
      rt.nextScan = now + interval
      me.qty(it.name, it.damage, function(q, err) onStock(it, q, err) end, rt.req ~= nil)
    end
  end
  dispatch(now)
  if dirty and now - lastSave > 3 then save() end
end

function A.flush() if dirty then save() end end

-- ───────── информация для интерфейса ─────────
-- прогресс активного крафта: frac, elapsed, eta, gained, total
function A.progress(it)
  local rt = it.rt
  if not rt.req then return nil end
  local now = U.now()
  local total = math.max(1, rt.reqAmount or 1)
  local gained = math.max(0, (rt.have or 0) - (rt.startHave or 0))
  local frac = U.clamp(gained / total, 0, 1)
  local elapsed = now - (rt.startAt or now)
  local eta
  if frac > 0.02 and frac < 1 then eta = elapsed * (1 - frac) / frac end
  return frac, elapsed, eta, gained, total
end

-- активные крафты (для дашборда и очков)
function A.crafting()
  local r = {}
  for _, it in ipairs(items) do
    if it.rt.req then r[#r + 1] = it end
  end
  table.sort(r, function(a, b) return (a.rt.startAt or 0) < (b.rt.startAt or 0) end)
  return r
end

-- проблемные / ждущие
function A.problems()
  local r = {}
  for _, it in ipairs(items) do
    local st = it.rt.state
    if it.enabled and (st == "fail" or st == "norecipe") then r[#r + 1] = it end
  end
  return r
end

function A.summary()
  local running, want, fail, ok = 0, 0, 0, 0
  for _, it in ipairs(items) do
    local st = it.rt.state
    if it.rt.req then running = running + 1
    elseif st == "want" or st == "idle" or st == "pause" then want = want + 1
    elseif st == "fail" or st == "norecipe" then fail = fail + 1
    elseif st == "ok" then ok = ok + 1 end
  end
  return { running = running, want = want, fail = fail, ok = ok, total = #items, limit = cfg().limit }
end

-- сортировка/фильтр для таблицы
local STATE_ORDER = { crafting = 1, plan = 1, want = 2, idle = 3, pause = 3, fail = 4, norecipe = 4, scan = 5, ok = 6, off = 7 }
function A.view(sortMode, filter, query)
  local r = {}
  query = query and query ~= "" and U.lower(query) or nil
  for i, it in ipairs(items) do
    local st = it.rt.state
    local pass = true
    if filter == "active" then pass = it.rt.req ~= nil or st == "want"
    elseif filter == "problems" then pass = (st == "fail" or st == "norecipe")
    elseif filter == "off" then pass = not it.enabled end
    if pass and query and not U.lower(it.label .. " " .. it.name):find(query, 1, true) then pass = false end
    if pass then r[#r + 1] = { it = it, i = i } end
  end
  table.sort(r, function(a, b)
    local x, y = a.it, b.it
    if sortMode == "name" then
      if x.label ~= y.label then return x.label < y.label end
    elseif sortMode == "state" then
      local sa, sb = STATE_ORDER[x.rt.state] or 9, STATE_ORDER[y.rt.state] or 9
      if sa ~= sb then return sa < sb end
    elseif sortMode == "need" then
      local na = x.rt.have and (target(x) - x.rt.have) or 0
      local nb = y.rt.have and (target(y) - y.rt.have) or 0
      if na ~= nb then return na > nb end
    else
      if x.prio ~= y.prio then return x.prio > y.prio end
    end
    return a.i < b.i
  end)
  local out = {}
  for k, v in ipairs(r) do out[k] = v.it end
  return out
end

return A
