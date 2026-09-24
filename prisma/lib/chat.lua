-- PRISMA CORE Local Chat Module

local component = require("component")
local event = require("event")
local unicode = require("unicode")

local M = {}
local chatBox
local logs = {}
local maxLines = 12
local cfg

function M.init(config)
  cfg = config.chat or {}
  maxLines = cfg.maxLines or 12
  chatBox = component.isAvailable("chat_box") and component.chat_box or nil
  if chatBox then
    pcall(function() chatBox.setName("§3[PRISMA]§r") end)
  end
  logs = {}
end

function M.add(name, msg)
  if not msg or msg:sub(1,1) == "!" then return end
  local line = string.format("%s: %s", name or "?", msg)
  table.insert(logs, line)
  while #logs > maxLines do table.remove(logs, 1) end
end

function M.getLogs()
  return logs
end

function M.listen()
  -- вызывается из главного цикла при событии chat_message
end

return M
