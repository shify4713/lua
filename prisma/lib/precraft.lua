-- PRISMA CORE Precraft Module (stub + базовая логика)
-- Полноценная интеграция с твоим autoCraftUltimate / g.precraft будет в следующих итерациях

local component = require("component")
local serialization = require("serialization")
local fs = require("filesystem")
local utils = require("prisma.lib.utils") or dofile("/home/prisma/lib/utils.lua")

local M = {}
local me
local items = {}
local active = false
local cfg
local lastUpdate = 0

function M.init(config)
  cfg = config.precraft or {}
  me = utils.get("me_interface") or utils.get("ae2_interface")
  local path = cfg.dataFile or "/home/prisma/precraft_bd.txt"
  if fs.exists(path) then
    local f = io.open(path, "r")
    local ok, data = pcall(serialization.unserialize, f:read("*a"))
    f:close()
    if ok and type(data) == "table" then items = data end
  end
end

function M.setActive(v)
  active = v
end

function M.isActive()
  return active
end

function M.update()
  if not active or not me then return end
  local now = computer.uptime()
  if now - lastUpdate < (cfg.updateInterval or 5) then return end
  lastUpdate = now
  -- TODO: полноценный цикл крафта (из autoCraftUltimate)
  -- пока только обновляем количества
  for _, item in ipairs(items) do
    pcall(function()
      local d = me.getItemDetail({id = item.id, dmg = item.dmg})
      if d and d.basic then
        item.current = d.basic().qty or 0
      end
    end)
  end
end

function M.getItems()
  return items
end

return M
