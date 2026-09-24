-- PRISMA CORE Glasses / AR HUD Module v2
-- Fully supports: terminal_glasses_bridge / openperipheral_bridge / terminal

local component = require("component")
local computer = require("computer")
local utils = require("prisma.lib.utils") or dofile("/home/prisma/lib/utils.lua")

local M = {}
local opb = nil
local cfg = {}
local lastUpdate = 0
local lastError = nil

local function findBridge()
  -- Пробуем все возможные имена компонента
  local names = {
    "terminal_glasses_bridge",
    "openperipheral_bridge",
    "glasses_bridge",
    "terminal",
    "openperipheral_glassesbridge"
  }
  for _, name in ipairs(names) do
    local addr = component.list(name)()
    if addr then
      return component.proxy(addr)
    end
  end
  -- Иногда bridge появляется как обычный peripheral
  for addr, typ in component.list() do
    if typ and (typ:find("glasses") or typ:find("bridge") or typ:find("terminal")) then
      local ok, proxy = pcall(component.proxy, addr)
      if ok and proxy and (proxy.clear or proxy.addText or proxy.sync) then
        return proxy
      end
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
  if not opb then
    opb = findBridge()  -- повторный поиск
  end
  return opb ~= nil
end

function M.getStatus()
  if opb then return "LINKED" end
  return lastError or "OFFLINE"
end

function M.update(data)
  if not cfg.enabled then return end
  if not opb then
    opb = findBridge()
    if not opb then return end
  end

  local now = computer.uptime()
  if now - lastUpdate < 0.55 then return end
  lastUpdate = now

  local ok, err = pcall(function()
    -- Очистка
    if opb.clear then opb.clear() end

    local bx = cfg.hudX or 4
    local by = cfg.hudY or 4
    local bw = cfg.hudW or 300

    -- ===== ФОН =====
    if opb.addBox then
      opb.addBox(bx, by, bw, 110, 0x050D14, 0.55)
      opb.addBox(bx, by, bw, 2, 0x00D4FF, 0.7)
      opb.addBox(bx, by + 108, bw, 2, 0x00D4FF, 0.4)
    end

    local y = by + 6
    local left = bx + 6
    local scale = 0.72

    -- ===== ЗАГОЛОВОК =====
    if opb.addText then
      opb.addText(left, y, "◆ PRISMA CORE AR", 0x00D4FF).setScale(0.85)
      y = y + 14

      -- ===== ENERGY CORE =====
      if cfg.showCore ~= false and data.core then
        local c = data.core
        if c.online then
          opb.addText(left, y, "ENERGY CORE", 0x00E676).setScale(scale)
          y = y + 10
          opb.addText(left, y, utils.formatNum(c.energy) .. " / " .. utils.formatNum(c.max), 0xE8F4F8).setScale(scale)
          y = y + 9
          local pct = math.floor((c.percent or 0) * 100)
          opb.addText(left, y, string.format("%d%%  |  Flow %s RF/t", pct, utils.formatNum(c.flow or 0)), 0x5A7A8A).setScale(0.65)
          y = y + 9
          opb.addText(left, y, "Target: " .. utils.formatNum(c.target or 0), 0x00D4FF).setScale(0.65)
          y = y + 13
        else
          opb.addText(left, y, "CORE: OFFLINE", 0xFF1744).setScale(scale)
          y = y + 13
        end
      end

      -- ===== REACTORS =====
      if cfg.showReactors ~= false and data.reactors then
        opb.addText(left, y, "REACTORS", 0x00E676).setScale(scale)
        y = y + 10

        local any = false
        for i, r in ipairs(data.reactors) do
          if i > 5 then break end
          any = true
          if r.online and r.info then
            local st = tostring(r.info.status or "?"):lower()
            local temp = math.floor(tonumber(r.info.temperature) or 0)
            local field = math.floor(((tonumber(r.info.fieldStrength) or 0) / (tonumber(r.info.maxFieldStrength) or 1)) * 100)
            local fuel = math.floor(((tonumber(r.info.fuelConversion) or 0) / (tonumber(r.info.maxFuelConversion) or 1)) * 100)
            local gen = math.floor((tonumber(r.info.generationRate) or 0) / 1000)

            local col = 0x00E676
            if st == "off" or st == "stopping" then col = 0xFF1744
            elseif temp > 8000 then col = 0xFFB300
            elseif field < 15 then col = 0xFF1744 end

            opb.addText(left, y, string.format("#%d %s  %d°  %d%%  %d%%  %dK", i, r.state or st, temp, field, fuel, gen), col).setScale(0.62)
            y = y + 9
          else
            opb.addText(left, y, string.format("#%d OFFLINE", i), 0x5A7A8A).setScale(0.62)
            y = y + 9
          end
        end
        if not any then
          opb.addText(left, y, "none", 0x5A7A8A).setScale(0.65)
          y = y + 9
        end
        y = y + 4
      end

      -- ===== RADAR =====
      if cfg.showRadar ~= false and data.players then
        opb.addText(left, y, "CONTACTS", 0xFF1744).setScale(scale)
        y = y + 10
        if #data.players == 0 then
          opb.addText(left, y, "clear", 0x5A7A8A).setScale(0.65)
          y = y + 9
        else
          for i, name in ipairs(data.players) do
            if i > 5 then break end
            opb.addText(left, y, "> " .. tostring(name), 0xFF8A80).setScale(0.62)
            y = y + 9
          end
        end
      end
    end

    -- Синхронизация
    if opb.sync then opb.sync() end
  end)

  if not ok then
    lastError = tostring(err)
    -- Если bridge умер — сбрасываем, чтобы найти заново
    opb = nil
  else
    lastError = nil
  end
end

return M
