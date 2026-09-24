-- PRISMA CORE Glasses v3.3 — один блок, чат внутри справа
local component = require("component")
local computer = require("computer")
local utils = require("prisma.lib.utils") or dofile("/home/prisma/lib/utils.lua")

local M = {}
local opb, cfg, lastUpdate = nil, {}, 0

local function findBridge()
  for _,n in ipairs({"terminal_glasses_bridge","openperipheral_bridge","glasses_bridge","terminal"}) do
    local a = component.list(n)()
    if a then return component.proxy(a) end
  end
  for a,t in component.list() do
    if t and (t:find("glasses") or t:find("bridge")) then
      local ok,p = pcall(component.proxy,a)
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
  if now - lastUpdate < 0.7 then return end
  lastUpdate = now

  pcall(function()
    if opb.clear then opb.clear() end

    local bx, by, bw, bh = 4, 4, 520, 130
    if opb.addBox then
      opb.addBox(bx, by, bw, bh, 0x050D14, 0.5)
      opb.addBox(bx, by, bw, 2, 0x00D4FF, 0.7)
      -- разделитель
      opb.addBox(bx + 300, by + 4, 2, bh - 8, 0x1A3545, 0.8)
    end

    if not opb.addText then return end

    -- ===== LEFT: System =====
    local y, left = by + 6, bx + 6
    opb.addText(left, y, "◆ PRISMA CORE", 0x00D4FF).setScale(0.8)
    y = y + 13

    if data.core then
      local c = data.core
      if c.online then
        opb.addText(left, y, "CORE "..utils.formatNum(c.energy), 0x00E676).setScale(0.65)
        y = y + 9
        opb.addText(left, y, string.format("%d%%  %s RF/t", math.floor((c.percent or 0)*100), utils.formatNum(c.flow or 0)), 0x5A7A8A).setScale(0.55)
        y = y + 11
      else
        opb.addText(left, y, "CORE: OFFLINE", 0xFF1744).setScale(0.65)
        y = y + 12
      end
    end

    opb.addText(left, y, "REACTORS", 0x00E676).setScale(0.65)
    y = y + 9
    local any = false
    if data.reactors then
      for i,r in ipairs(data.reactors) do
        if i > 3 then break end
        any = true
        if r.online and r.info then
          local temp = math.floor(tonumber(r.info.temperature) or 0)
          local field = math.floor(((tonumber(r.info.fieldStrength) or 0)/(tonumber(r.info.maxFieldStrength) or 1))*100)
          local col = temp > 8000 and 0xFFB300 or 0x00E676
          opb.addText(left, y, string.format("#%d %s %d° %d%%", i, r.state or "?", temp, field), col).setScale(0.55)
          y = y + 8
        else
          opb.addText(left, y, "#"..i.." OFF", 0x5A7A8A).setScale(0.55)
          y = y + 8
        end
      end
    end
    if not any then opb.addText(left, y, "none", 0x5A7A8A).setScale(0.55); y = y + 8 end
    y = y + 3

    opb.addText(left, y, "CONTACTS", 0xFF1744).setScale(0.65)
    y = y + 9
    if data.players and #data.players > 0 then
      for i,name in ipairs(data.players) do
        if i > 3 then break end
        opb.addText(left, y, "> "..tostring(name), 0xFF8A80).setScale(0.55)
        y = y + 8
      end
    else
      opb.addText(left, y, "clear", 0x5A7A8A).setScale(0.55)
    end

    -- ===== RIGHT: Chat (внутри того же окна) =====
    local rx, cy = bx + 310, by + 6
    opb.addText(rx, cy, "CHAT", 0x00D4FF).setScale(0.8)
    cy = cy + 13

    if data.chat and #data.chat > 0 then
      local start = math.max(1, #data.chat - 7)
      for i = start, #data.chat do
        local line = tostring(data.chat[i] or "")
        -- перенос длинных строк
        while #line > 0 do
          local chunk = line:sub(1, 36)
          opb.addText(rx, cy, chunk, 0xE0F0F5).setScale(0.5)
          cy = cy + 9
          if cy > by + bh - 10 then break end
          line = line:sub(37)
        end
        if cy > by + bh - 10 then break end
      end
    else
      opb.addText(rx, cy, "no messages", 0x5A7A8A).setScale(0.5)
    end

    if opb.sync then opb.sync() end
  end)
end

return M
