-- PRISMA CORE Radar / Sensor Module

local component = require("component")
local utils = require("prisma.lib.utils") or dofile("/home/prisma/lib/utils.lua")

local M = {}
local sensor
local cfg
local nearby = {}

function M.init(config)
  cfg = config.radar or {}
  sensor = utils.get("sensor") or utils.get("radar") or utils.get("openperipheral_sensor")
end

function M.update()
  nearby = {}
  if not sensor then return end
  pcall(function()
    local result = sensor.getPlayers and sensor.getPlayers() or {}
    if type(result) ~= "table" then return end
    for k, v in pairs(result) do
      local name = "Unknown"
      if type(v) == "table" and v.name then name = v.name
      elseif type(v) == "string" then name = v
      elseif type(k) == "string" then name = k end
      if name ~= "Unknown" then
        local ignore = false
        for _, ign in ipairs(cfg.ignore or {}) do
          if name:lower() == ign:lower() then ignore = true break end
        end
        if not ignore then
          local display = name
          if cfg.prefixes and cfg.prefixes[name] then
            display = cfg.prefixes[name] .. " " .. name
          end
          table.insert(nearby, display)
        end
      end
    end
  end)
end

function M.getPlayers()
  return nearby
end

function M.isAvailable()
  return sensor ~= nil
end

return M
