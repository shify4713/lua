-- PRISMA CORE Glasses / AR HUD Module
-- OpenPeripheral Bridge / Terminal Glasses

local component = require("component")
local utils = require("prisma.lib.utils") or dofile("/home/prisma/lib/utils.lua")

local M = {}
local opb
local cfg
local lastUpdate = 0

function M.init(config)
  cfg = config.glasses or {}
  opb = utils.get("openperipheral_bridge") or utils.get("terminal_glasses_bridge") or utils.get("terminal")
end

function M.isAvailable()
  return opb ~= nil
end

function M.update(data)
  if not opb or not cfg.enabled then return end
  local now = computer.uptime()
  if now - lastUpdate < 0.6 then return end  -- троттлинг AR
  lastUpdate = now

  pcall(function()
    opb.clear()
    local bx, by, bw = cfg.hudX or 2, cfg.hudY or 2, cfg.hudW or 280
    local h = 20

    -- Фон
    opb.addBox(bx, by, bw, 80, 0x050F1A, 0.45)
    opb.addBox(bx, by, bw, 1, 0x00E5FF, 0.6)

    local y = by + 4
    opb.addText(bx + 4, y, "PRISMA CORE AR", 0x00E5FF).setScale(0.8)
    y = y + 12

    -- Core
    if cfg.showCore and data.core then
      local c = data.core
      opb.addText(bx + 4, y, "CORE: " .. utils.formatNum(c.energy or 0) .. " / " .. utils.formatNum(c.max or 0), 0xE0F7FA).setScale(0.7)
      y = y + 9
      opb.addText(bx + 4, y, string.format("FLOW: %s RF/t  TARGET: %s", utils.formatNum(c.flow or 0), utils.formatNum(c.target or 0)), 0x4A7B9C).setScale(0.65)
      y = y + 11
    end

    -- Reactors summary
    if cfg.showReactors and data.reactors then
      opb.addText(bx + 4, y, "REACTORS:", 0x00FF9D).setScale(0.7)
      y = y + 9
      for i, r in ipairs(data.reactors) do
        if i > 5 then break end
        local st = r.online and (r.state or "OK") or "OFF"
        local col = r.online and 0x00FF9D or 0xFF2A2A
        opb.addText(bx + 6, y, string.format("#%d %s", i, st), col).setScale(0.65)
        y = y + 8
      end
      y = y + 4
    end

    -- Radar
    if cfg.showRadar and data.players then
      opb.addText(bx + 4, y, "CONTACTS:", 0xFF2A2A).setScale(0.7)
      y = y + 9
      if #data.players == 0 then
        opb.addText(bx + 6, y, "none", 0x4A7B9C).setScale(0.65)
      else
        for i, name in ipairs(data.players) do
          if i > 6 then break end
          opb.addText(bx + 6, y, name, 0xFF7A7A).setScale(0.65)
          y = y + 8
        end
      end
    end

    opb.sync()
  end)
end

return M
