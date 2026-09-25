-- PRISMA · radar: датчик игроков поблизости
local P = ...
local U = P.util
local log = P.log
local component = require("component")

local R = {}
local sensor
local nearby = {}
local known = {}
local lastRun = 0
local first = true

local function cfg() return P.cfg.radar end

function R.init()
  nearby, known, first = {}, {}, true
  sensor = U.findComp({ "sensor", "radar", "openperipheral_sensor" }, P.cfg.devices.sensor)
  if not sensor then
    local a = component.list("sensor")()
    if a then sensor = U.proxy(a) end
  end
end

function R.available() return sensor ~= nil end

local function ignored(name)
  local l = name:lower()
  for _, ign in ipairs(cfg().ignore or {}) do
    if l == tostring(ign):lower() then return true end
  end
  return false
end

function R.update(now)
  now = now or U.now()
  if now - lastRun < (cfg().interval or 1) then return end
  lastRun = now
  if not sensor or type(sensor.getPlayers) ~= "function" then nearby = {}; return end
  local ok, res = pcall(sensor.getPlayers)
  if not ok or type(res) ~= "table" then return end
  local list, seen = {}, {}
  for k, v in pairs(res) do
    local name, dist
    if type(v) == "table" then
      name = v.name or (type(k) == "string" and k) or nil
      dist = tonumber(v.distance)
      if not dist and v.x and v.y and v.z then
        dist = math.sqrt((tonumber(v.x) or 0) ^ 2 + (tonumber(v.y) or 0) ^ 2 + (tonumber(v.z) or 0) ^ 2)
      end
    elseif type(v) == "string" then name = v
    elseif type(k) == "string" then name = k end
    if name and not ignored(name) then
      local pre = cfg().prefixes and cfg().prefixes[name]
      list[#list + 1] = { name = name, display = pre and (pre .. " " .. name) or name, dist = dist }
      seen[name] = true
    end
  end
  table.sort(list, function(a, b)
    if (a.dist or 1e9) ~= (b.dist or 1e9) then return (a.dist or 1e9) < (b.dist or 1e9) end
    return a.name < b.name
  end)
  if not first and cfg().alert then
    for _, p in ipairs(list) do
      if not known[p.name] then log.warn("РАДАР", "рядом игрок: " .. p.display) end
    end
  end
  first = false
  known = seen
  local changed = #list ~= #nearby
  if not changed then for i = 1, #list do if list[i].name ~= nearby[i].name then changed = true break end end end
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
