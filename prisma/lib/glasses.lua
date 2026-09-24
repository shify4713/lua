-- PRISMA CORE Glasses v3 — Terminal Glasses Bridge + Chat
local component = require("component")
local computer = require("computer")
local utils = require("prisma.lib.utils") or dofile("/home/prisma/lib/utils.lua")

local M = {}
local opb, cfg, lastUpdate, lastError = nil, {}, 0, nil

local function findBridge()
  local names = {"terminal_glasses_bridge","openperipheral_bridge","glasses_bridge","terminal","openperipheral_glassesbridge"}
  for _,n in ipairs(names) do
    local a = component.list(n)()
    if a then return component.proxy(a) end
  end
  for a,t in component.list() do
    if t and (t:find("glasses") or t:find("bridge") or t:find("terminal")) then
      local ok,p = pcall(component.proxy,a)
      if ok and p and (p.clear or p.addText or p.sync) then return p end
    end
  end
  return nil
end

function M.init(config)
  cfg = config.glasses or {}
  opb = findBridge()
  lastError = opb and nil or "Bridge not found"
end

function M.isAvailable()
  if not opb then opb = findBridge() end
  return opb ~= nil
end

function M.getStatus()
  return opb and "LINKED" or (lastError or "OFFLINE")
end

function M.update(data)
  if not cfg.enabled then return end
  if not opb then opb = findBridge(); if not opb then return end end

  local now = computer.uptime()
  if now - lastUpdate < 0.6 then return end
  lastUpdate = now

  local ok, err = pcall(function()
    if opb.clear then opb.clear() end

    local bx, by, bw = cfg.hudX or 4, cfg.hudY or 4, cfg.hudW or 320
    if opb.addBox then
      opb.addBox(bx, by, bw, 130, 0x050D14, 0.55)
      opb.addBox(bx, by, bw, 2, 0x00D4FF, 0.7)
    end

    local y, left, sc = by + 6, bx + 6, 0.7

    if opb.addText then
      opb.addText(left, y, "◆ PRISMA CORE AR", 0x00D4FF).setScale(0.85)
      y = y + 13

      -- CORE
      if cfg.showCore ~= false and data.core then
        local c = data.core
        if c.online then
          opb.addText(left, y, "CORE  " .. utils.formatNum(c.energy) .. " / " .. utils.formatNum(c.max), 0x00E676).setScale(sc)
          y = y + 9
          opb.addText(left, y, string.format("%d%%  Flow %s  Tgt %s", math.floor((c.percent or 0)*100), utils.formatNum(c.flow or 0), utils.formatNum(c.target or 0)), 0x5A7A8A).setScale(0.62)
          y = y + 12
        else
          opb.addText(left, y, "CORE: OFFLINE", 0xFF1744).setScale(sc)
          y = y + 12
        end
      end

      -- REACTORS
      if cfg.showReactors ~= false and data.reactors then
        opb.addText(left, y, "REACTORS", 0x00E676).setScale(sc)
        y = y + 9
        local any = false
        for i,r in ipairs(data.reactors) do
          if i > 5 then break end
          any = true
          if r.online and r.info then
            local st = tostring(r.info.status or "?"):lower()
            local temp = math.floor(tonumber(r.info.temperature) or 0)
            local field = math.floor(((tonumber(r.info.fieldStrength) or 0)/(tonumber(r.info.maxFieldStrength) or 1))*100)
            local fuel = math.floor(((tonumber(r.info.fuelConversion) or 0)/(tonumber(r.info.maxFuelConversion) or 1))*100)
            local gen = math.floor((tonumber(r.info.generationRate) or 0)/1000)
            local col = 0x00E676
            if st=="off" or st=="stopping" then col=0xFF1744
            elseif temp>8000 or field<15 then col=0xFFB300 end
            opb.addText(left, y, string.format("#%d %s %d° %d%% %d%% %dK", i, r.state or st, temp, field, fuel, gen), col).setScale(0.6)
            y = y + 8
          else
            opb.addText(left, y, "#"..i.." OFF", 0x5A7A8A).setScale(0.6)
            y = y + 8
          end
        end
        if not any then opb.addText(left, y, "none", 0x5A7A8A).setScale(0.6); y=y+8 end
        y = y + 4
      end

      -- RADAR
      if cfg.showRadar ~= false and data.players then
        opb.addText(left, y, "CONTACTS", 0xFF1744).setScale(sc)
        y = y + 9
        if #data.players == 0 then
          opb.addText(left, y, "clear", 0x5A7A8A).setScale(0.6); y=y+8
        else
          for i,name in ipairs(data.players) do
            if i>4 then break end
            opb.addText(left, y, "> "..tostring(name), 0xFF8A80).setScale(0.6)
            y = y + 8
          end
        end
        y = y + 4
      end

      -- LOCAL CHAT
      if cfg.showChat ~= false and data.chat then
        opb.addText(left, y, "CHAT", 0x00D4FF).setScale(sc)
        y = y + 9
        local logs = data.chat
        local start = math.max(1, #logs - 4)
        for i = start, #logs do
          local line = tostring(logs[i] or "")
          if #line > 42 then line = line:sub(1,42) end
          opb.addText(left, y, line, 0xE0F0F5).setScale(0.55)
          y = y + 8
        end
      end
    end

    if opb.sync then opb.sync() end
  end)

  if not ok then lastError = tostring(err); opb = nil else lastError = nil end
end

return M
