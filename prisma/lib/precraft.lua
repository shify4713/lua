-- PRISMA CORE Precraft v3.4 — умный автокрафт (как autoCraftUltimate + пример магазина)
local component = require("component")
local computer = require("computer")
local serialization = require("serialization")
local fs = require("filesystem")
local utils = require("prisma.lib.utils") or dofile("/home/prisma/lib/utils.lua")

local M = {}
local me, items, cfg = nil, {}, {}
local active, paused = false, false
local lastTick, nextTickAt = 0, 0
local craftLimit = 6
local tickInterval = 60   -- сек
local DATA = "/home/prisma/precraft_bd.txt"
local status = {active=0, done=0, failed=0, msg="OFF"}

local function save()
  local f = io.open(DATA,"w")
  if f then f:write(serialization.serialize(items)); f:close() end
end

local function load()
  if not fs.exists(DATA) then items={}; return end
  local f = io.open(DATA,"r")
  if not f then return end
  local ok, data = pcall(serialization.unserialize, f:read("*a"))
  f:close()
  if ok and type(data)=="table" then items = data end
end

function M.init(config)
  cfg = config.precraft or {}
  craftLimit = cfg.craftLimit or 6
  tickInterval = cfg.tickInterval or 60
  me = utils.get("me_interface") or utils.get("ae2_interface")
  load()
  nextTickAt = computer.uptime() + tickInterval
end

function M.setActive(v) active = v; if v then paused=false; status.msg="AUTO" else status.msg="OFF" end end
function M.isActive() return active end
function M.isPaused() return paused end
function M.togglePause() paused = not paused; status.msg = paused and "PAUSE" or (active and "AUTO" or "OFF") end
function M.getItems() return items end
function M.getStatus() return status end
function M.getLimit() return craftLimit end
function M.setLimit(n) craftLimit = math.max(1, math.min(32, n or 6)); if cfg then cfg.craftLimit=craftLimit end end
function M.getTickInterval() return tickInterval end
function M.setTickInterval(s) tickInterval = math.max(10, s or 60); if cfg then cfg.tickInterval=tickInterval end end
function M.getNextTick() return math.max(0, nextTickAt - computer.uptime()) end

function M.addFromSlot()
  if not me then return false, "ME not found" end
  local ok, stack = pcall(function() return me.getStackInSlot(1) end)
  if not ok or not stack then return false, "Нет предмета в слоте 1 ME Interface" end
  local name = stack.label or stack.name or stack.id or "item"
  table.insert(items, {
    name = name,
    id = stack.id or stack.name,
    dmg = stack.dmg or stack.damage or 0,
    count = 64,       -- держать
    craftSize = 16,   -- за раз
    current = 0,
    state = "waiting",
    progress = 0,
    age = 0,
  })
  save()
  return true, name
end

function M.remove(i)
  if items[i] then table.remove(items,i); save(); return true end
  return false
end

function M.edit(i, field, value)
  if not items[i] then return false end
  if field=="count" or field=="craftSize" then
    items[i][field] = math.max(1, tonumber(value) or items[i][field])
  elseif field=="name" then
    items[i].name = tostring(value)
  end
  save()
  return true
end

local function getQty(id, dmg)
  if not me then return 0 end
  local qty = 0
  pcall(function()
    local list = me.getItemsInNetwork({name=id, damage=dmg})
    if list and list.n and list.n > 0 then
      for _,s in pairs(list) do
        if type(s)=="table" and (s.size or s.qty) then qty = s.size or s.qty; break end
      end
    else
      local d = me.getItemDetail({id=id, dmg=dmg})
      if d then
        local st = d.basic and d.basic() or (d.all and d.all()) or d
        qty = st and (st.qty or st.size or 0) or 0
      end
    end
  end)
  return qty
end

local function freeCpus()
  local free = {}
  pcall(function()
    local cpus = me.getCpus() or {}
    for _,cpu in ipairs(cpus) do
      if not cpu.busy then table.insert(free, cpu.name or cpu) end
    end
  end)
  return free
end

local function requestCraft(item, amount, cpuName)
  local ok, res = pcall(function()
    local craftables = me.getCraftables({name=item.id, damage=item.dmg})
    if not craftables or not craftables.n or craftables.n < 1 then return nil, "no recipe" end
    return craftables[1].request(amount, false, cpuName)
  end)
  return ok and res
end

function M.tick()
  if not active or paused or not me then return end
  local now = computer.uptime()
  status.active, status.done, status.failed = 0, status.done or 0, status.failed or 0

  -- обновить количества
  for _,it in ipairs(items) do
    it.current = getQty(it.id, it.dmg)
  end

  local free = freeCpus()
  local used = 0
  for _,it in ipairs(items) do
    if used >= craftLimit then break end
    local need = (tonumber(it.count) or 0) - (tonumber(it.current) or 0)
    if need > 0 then
      local size = math.min(tonumber(it.craftSize) or 1, need)
      if #free > 0 then
        local cpu = table.remove(free, 1)
        local req = requestCraft(it, size, cpu)
        if req then
          it.state = "идёт"
          it.age = 0
          it.progress = size
          status.active = status.active + 1
          used = used + 1
          status.msg = "CRAFT "..(it.name or "?")
        else
          it.state = "fail"
          status.failed = status.failed + 1
        end
      else
        it.state = "wait cpu"
      end
    else
      it.state = "ok"
    end
  end
  lastTick = now
  nextTickAt = now + tickInterval
  save()
end

function M.update()
  if not active then return end
  if computer.uptime() >= nextTickAt then
    M.tick()
  end
end

function M.forceTick() M.tick() end

return M
