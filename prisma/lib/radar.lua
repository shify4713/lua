-- PRISMA · radar: датчик игроков поблизости
local P = ...
local U = P.util
local log = P.log
local component = require("component")

local R = {}
local sensor
local sensorAddr
local nearby = {}
local known = {}
local lastRun = 0
local lastFind = 0
local first = true

local function cfg() return P.cfg.radar end

local function findSensor()
  local b, a = U.findComp({ "sensor", "radar", "openperipheral_sensor", "op_sensor", "entity_detector", "player_detector" }, P.cfg.devices.sensor)
  if b then return b, a end
  -- полный перебор: имена типов в разных модах отличаются
  for addr, t in component.list() do
    local tl = tostring(t or ""):lower()
    if tl:find("sensor") or tl:find("radar") or tl:find("peripheral") then
      local p = U.proxy(addr)
      if p and (type(p.getPlayers) == "function" or type(p.getPlayerByName) == "function"
          or type(p.getEntity) == "function" or type(p.scan) == "function"
          or type(p.getEntities) == "function") then
        return p, addr
      end
    end
  end
  -- fallback: любой component с getPlayers
  for addr in component.list() do
    local p = U.proxy(addr)
    if p and type(p.getPlayers) == "function" then return p, addr end
  end
end

function R.init()
  nearby, known, first = {}, {}, true
  sensor, sensorAddr = findSensor()
  lastFind = U.now()
  if sensor then
    log.info("РАДАР", "датчик: " .. U.shortAddr(sensorAddr or "?"))
  end
end

function R.available() return sensor ~= nil end
function R.address() return sensorAddr end

local function ignored(name)
  local l = name:lower()
  for _, ign in ipairs(cfg().ignore or {}) do
    if l == tostring(ign):lower() then return true end
  end
  return false
end

local function parsePlayers(res)
  local list = {}
  local seen = {}
  if type(res) ~= "table" then return list end
  for k, v in pairs(res) do
    local name, dist
    if type(v) == "table" then
      name = v.username or v.playerName or v.player or v.commandSenderName or v.displayName or v.name or (type(k) == "string" and k) or nil
      dist = tonumber(v.distance) or tonumber(v.range) or tonumber(v.dist)
      if not dist and (v.x or v.y or v.z) then
        dist = math.sqrt((tonumber(v.x) or 0) ^ 2 + (tonumber(v.y) or 0) ^ 2 + (tonumber(v.z) or 0) ^ 2)
      end
    elseif type(v) == "string" then
      name = v
    elseif type(k) == "string" and type(v) == "number" then
      name, dist = k, v
    elseif type(k) == "string" then
      name = k
    end
    -- Entity Sensor иногда возвращает тип сущности в name, а ник — в playerName.
    if name and name ~= "" and tostring(name):lower() ~= "player" and not ignored(tostring(name)) and not seen[tostring(name):lower()] then
      seen[tostring(name):lower()] = true
      local pre = cfg().prefixes and cfg().prefixes[name]
      list[#list + 1] = { name = name, display = pre and (pre .. " " .. name) or name, dist = dist }
    end
  end
  return list
end

local function fetchPlayers()
  if not sensor then return nil end
  -- основной API OpenPeripherals
  if type(sensor.getPlayers) == "function" then
    local ok, res = pcall(sensor.getPlayers, cfg().range or 64)
    if not ok then ok, res = pcall(sensor.getPlayers) end
    if ok and type(res) == "table" then return parsePlayers(res) end
  end
  -- альтернативы
  for _, fn in ipairs({ "getNearbyPlayers", "scanPlayers", "getEntities", "scan" }) do
    if type(sensor[fn]) == "function" then
      local ok, res = pcall(sensor[fn], cfg().range or 64)
      if not ok then ok, res = pcall(sensor[fn]) end
      if ok and type(res) == "table" then
        local list = parsePlayers(res)
        if #list > 0 then return list end
      end
    end
  end
  return {}
end

function R.update(now)
  now = now or U.now()
  if now - lastRun < (cfg().interval or 1) then return end
  lastRun = now

  if not sensor then
    if now - lastFind > 10 then
      lastFind = now
      sensor, sensorAddr = findSensor()
      if sensor then log.info("РАДАР", "датчик найден: " .. U.shortAddr(sensorAddr or "?")) end
    end
    nearby = {}
    return
  end

  local list = fetchPlayers()
  if list == nil then
    -- датчик отвалился — сброс и поиск заново
    sensor, sensorAddr = nil, nil
    nearby = {}
    return
  end

  table.sort(list, function(a, b)
    if (a.dist or 1e9) ~= (b.dist or 1e9) then return (a.dist or 1e9) < (b.dist or 1e9) end
    return a.name < b.name
  end)

  if not first and cfg().alert then
    local seen = {}
    for _, p in ipairs(list) do
      seen[p.name] = true
      if not known[p.name] then log.warn("РАДАР", "рядом игрок: " .. p.display) end
    end
    known = seen
  else
    local seen = {}
    for _, p in ipairs(list) do seen[p.name] = true end
    known = seen
  end
  first = false

  local changed = #list ~= #nearby
  if not changed then
    for i = 1, #list do
      if list[i].name ~= nearby[i].name then changed = true; break end
    end
  end
  nearby = list
  if changed and P.state then P.state.dirty = true end
end

function R.list() return nearby end

function R.players()
  local r = {}
  for i, p in ipairs(nearby) do r[i] = p.display end
  return r
end

function R.addIgnore(name)
  name = U.trim(name)
  if name == "" then return end
  local l = cfg().ignore
  for _, x in ipairs(l) do if tostring(x):lower() == name:lower() then return end end
  l[#l + 1] = name
  P.config.markDirty()
end

function R.removeIgnore(i)
  if cfg().ignore[i] then table.remove(cfg().ignore, i); P.config.markDirty() end
end

return R
