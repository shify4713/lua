-- PRISMA CORE Glasses v3.2 — Chat on RIGHT side
local component = require("component")
local computer = require("computer")
local utils = require("prisma.lib.utils") or dofile("/home/prisma/lib/utils.lua")

local M = {}
local opb, cfg, lastUpdate = nil, {}, 0

local function findBridge()
  local names = {"terminal_glasses_bridge","openperipheral_bridge","glasses_bridge","terminal"}
  for _,n in ipairs(names) do
    local a = component.list(n)()
    if a then return component.proxy(a) end
  end
  for a,t in component.list() do
    if t and (t:find("glasses") or t:find("bridge") or t:find("terminal")) then
      local ok,p = pcall(component.proxy, a)
      if ok and p and (p.clear or p.addText) then return p end
    end
  end
  return nil
end

function M.init(config)
  cfg = config.glasses or {}
  opb = findBridge()
end

function M.isAvailable()
  if not opb then opb = findBridge() end
  return opb ~= nil
end

function M.update(data)
  if not cfg.enabled then return end
  if not opb then opb = findBridge(); if not opb then return end end

  local now = computer.uptime()
  if now - lastUpdate < 0.65 then return end
  lastUpdate = now

  pcall(function()
    if opb.clear then opb.clear() end

    local leftX, rightX = 4, 340
    local y = 6
    local sc = 0.7

    -- ===== LEFT PANEL: System info =====
    if opb.addBox then
      opb.addBox(leftX, 4, 300, 120, 0x050D14, 0.5)
      opb.addBox(leftX, 4, 300, 2, 0x00D4FF, 0.7)
    end

    if opb.addText then
      opb.addText(leftX+4, y, "◆ PRISMA CORE", 0x00D4FF).setScale(0.85)
      y = y + 14

      -- Core
      if data.core then
        local c = data.core
        if c.online then
          opb.addText(leftX+4, y, "CORE  "..utils.formatNum(c.energy).." / "..utils.formatNum(c.max), 0x00E676).setScale(sc)
          y = y + 10
          opb.addText(leftX+4, y, string.format("%d%%  Flow %s", math.floor((c.percent or 0)*100), utils.formatNum(c.flow or 0)), 0x5A7A8A).setScale(0.6)
          y = y + 12
        else
          opb.addText(leftX+4, y, "CORE: OFFLINE", 0xFF1744).setScale(sc)
          y = y + 14
        end
      end

      -- Reactors
      opb.addText(leftX+4, y, "REACTORS", 0x00E676).setScale(sc)
      y = y + 10
      local any = false
      if data.reactors then
        for i,r in ipairs(data.reactors) do
          if i > 4 then break end
          any = true
          if r.online and r.info then
            local temp = math.floor(tonumber(r.info.temperature) or 0)
            local field = math.floor(((tonumber(r.info.fieldStrength) or 0)/(tonumber(r.info.maxFieldStrength) or 1))*100)
            local col = temp > 8000 and 0xFFB300 or 0x00E676
            opb.addText(leftX+4, y, string.format("#%d %s %d° %d%%", i, r.state or "?", temp, field), col).setScale(0.58)
            y = y + 9
          else
            opb.addText(leftX+4, y, "#"..i.." OFF", 0x5A7A8A).setScale(0.58)
            y = y + 9
          end
        end
      end
      if not any then opb.addText(leftX+4, y, "none", 0x5A7A8A).setScale(0.58); y = y + 9 end
      y = y + 4

      -- Contacts
      opb.addText(leftX+4, y, "CONTACTS", 0xFF1744).setScale(sc)
      y = y + 10
      if data.players and #data.players > 0 then
        for i,name in ipairs(data.players) do
          if i > 4 then break end
          opb.addText(leftX+4, y, "> "..tostring(name), 0xFF8A80).setScale(0.58)
          y = y + 9
        end
      else
        opb.addText(leftX+4, y, "clear", 0x5A7A8A).setScale(0.58)
      end
    end

    -- ===== RIGHT PANEL: Chat =====
    if opb.addBox then
      opb.addBox(rightX, 4, 280, 120, 0x050D14, 0.5)
      opb.addBox(rightX, 4, 280, 2, 0x00D4FF, 0.7)
    end

    if opb.addText then
      local cy = 6
      opb.addText(rightX+4, cy, "CHAT", 0x00D4FF).setScale(0.85)
      cy = cy + 14

      if data.chat and #data.chat > 0 then
        local start = math.max(1, #data.chat - 8)
        for i = start, #data.chat do
          local line = tostring(data.chat[i] or "")
          if #line > 38 then line = line:sub(1, 38) end
          opb.addText(rightX+4, cy, line, 0xE0F0F5).setScale(0.55)
          cy = cy + 10
        end
      else
        opb.addText(rightX+4, cy, "no messages", 0x5A7A8A).setScale(0.55)
      end
    end

    if opb.sync then opb.sync() end
  end)
end

return M
