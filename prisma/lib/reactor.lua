-- PRISMA CORE Reactor Module
-- Топ-ассистент для Draconic Evolution (до 5 реакторов)
-- Учитывает: щит, насыщение, топливо, температуру

local component = require("component")
local computer = require("computer")
local serialization = require("serialization")
local fs = require("filesystem")
local utils = require("prisma.lib.utils") or dofile("/home/prisma/lib/utils.lua")

local M = {}

local SAVE = "/home/prisma/reactors.cfg"
local reactors = {}
local cfg = nil

local STATUS_MAP = {
  off = "ВЫКЛ", charging = "ЗАРЯД", online = "ГОТОВ",
  running = "РАБОТА", stopping = "СТОП", starting = "СТАРТ", invalid = "ОШИБКА"
}

function M.init(config)
  cfg = config.reactors or {}
  reactors = {}
  if fs.exists(SAVE) then
    local f = io.open(SAVE, "r")
    local data = serialization.unserialize(f:read("*a"))
    f:close()
    if data then
      for _, d in ipairs(data) do
        local rP = component.proxy(d.rAddr) or {address = d.rAddr}
        local iP = component.proxy(d.inAddr) or {address = d.inAddr}
        local oP = component.proxy(d.outAddr) or {address = d.outAddr}
        table.insert(reactors, {
          proxy = rP, gateIn = iP, gateOut = oP,
          auto = d.auto ~= false, state = "IDLE", info = {}, online = (rP.address and component.get(rP.address) ~= nil)
        })
      end
    end
  end
end

local function save()
  local data = {}
  for _, r in ipairs(reactors) do
    table.insert(data, {
      rAddr = r.proxy.address,
      inAddr = r.gateIn.address,
      outAddr = r.gateOut.address,
      auto = r.auto
    })
  end
  local f = io.open(SAVE, "w")
  f:write(serialization.serialize(data))
  f:close()
end

local function safeFlow(proxy)
  if not proxy or not proxy.getSignalLowFlow then return 0 end
  local ok, v = pcall(proxy.getSignalLowFlow)
  return (ok and tonumber(v)) or 0
end

local function setFlow(proxy, val)
  if proxy and proxy.setSignalLowFlow then
    pcall(proxy.setSignalLowFlow, math.floor(val))
  end
end

function M.update()
  for _, r in ipairs(reactors) do
    if not r.proxy or not r.proxy.getReactorInfo then
      r.online = false
      r.state = "НЕТ СВЯЗИ"
      goto continue
    end
    local ok, inf = pcall(r.proxy.getReactorInfo)
    if not ok or not inf then
      r.online = false
      r.state = "ПОИСК..."
      goto continue
    end
    r.info = inf
    r.online = true
    local status = tostring(inf.status or ""):lower()
    local temp = tonumber(inf.temperature) or 0
    local gen = tonumber(inf.generationRate) or 0
    local drain = tonumber(inf.fieldDrainRate) or 0
    local sat = (tonumber(inf.energySaturation) or 0) / (tonumber(inf.maxEnergySaturation) or 1)
    local field = (tonumber(inf.fieldStrength) or 0) / (tonumber(inf.maxFieldStrength) or 1)
    local fuel = (tonumber(inf.fuelConversion) or 0) / (tonumber(inf.maxFuelConversion) or 1)

    -- Входной гейт (щит)
    if status ~= "off" then
      local targetIn = math.ceil(drain / (1 - (cfg.targetShield / 100)))
      if status == "charging" then targetIn = 1000000 end
      setFlow(r.gateIn, targetIn)
    end

    -- Выходной гейт + логика
    if r.auto then
      local currentOut = safeFlow(r.gateOut)
      if status == "running" or status == "online" or status == "starting" then
        if temp < cfg.forceModeTemp then
          if currentOut > (cfg.initialFlow + 50000) then
            r.state = "ВОССТ."
            if (currentOut - gen) < 1000 then setFlow(r.gateOut, currentOut + 1000) end
          else
            r.state = "УДЕРЖ."
            if currentOut ~= cfg.initialFlow then setFlow(r.gateOut, cfg.initialFlow) end
          end
        elseif temp < cfg.safeModeTemp then
          r.state = "СТАБИЛЬНО"
          if (currentOut - gen) < 1500 then setFlow(r.gateOut, currentOut + 800) end
        elseif temp > cfg.tempCrit then
          r.state = "КРИТИЧНО"
          setFlow(r.gateOut, cfg.initialFlow)
        else
          r.state = "ОПТИМАЛЬНО"
          -- лёгкая подстройка под генерацию с учётом насыщения
          local targetOut = gen + (sat < 0.15 and 2000 or 500)
          if math.abs(currentOut - targetOut) > 2000 then
            setFlow(r.gateOut, targetOut)
          end
        end
        -- защита по топливу
        if fuel > 0.92 then
          r.state = "ТОПЛИВО!"
          setFlow(r.gateOut, math.min(currentOut, cfg.initialFlow))
        end
      else
        r.state = "ОЖИДАНИЕ"
        if currentOut ~= cfg.initialFlow then setFlow(r.gateOut, cfg.initialFlow) end
      end
    else
      r.state = "РУЧНОЙ"
    end
    ::continue::
  end
end

function M.getList()
  return reactors
end

function M.getCount()
  return #reactors
end

function M.addInteractive()
  -- Упрощённое добавление: ищем свободные
  local used = {}
  for _, r in ipairs(reactors) do
    if r.proxy then used[r.proxy.address] = true end
    if r.gateIn then used[r.gateIn.address] = true end
    if r.gateOut then used[r.gateOut.address] = true end
  end
  local freeR, freeG = {}, {}
  for addr in component.list("draconic_reactor") do
    if not used[addr] then table.insert(freeR, addr) end
  end
  for addr in component.list("flux_gate") do
    if not used[addr] then table.insert(freeG, addr) end
  end
  if #freeR < 1 or #freeG < 2 then return false, "Нужен 1 реактор + 2 гейта" end
  if #reactors >= 5 then return false, "Максимум 5 реакторов" end

  local r = component.proxy(freeR[1])
  local g1 = component.proxy(freeG[1])
  local g2 = component.proxy(freeG[2])
  local f1, f2 = safeFlow(g1), safeFlow(g2)
  local gateIn, gateOut
  if f1 > (cfg.detectOutMin or 530000) and f2 < (cfg.detectInMax or 500000) then
    gateOut, gateIn = g1, g2
  elseif f2 > (cfg.detectOutMin or 530000) and f1 < (cfg.detectInMax or 500000) then
    gateOut, gateIn = g2, g1
  else
    -- по умолчанию первый = out
    gateOut, gateIn = g1, g2
  end
  table.insert(reactors, {
    proxy = r, gateIn = gateIn, gateOut = gateOut,
    auto = true, state = "ДОБАВЛЕН", info = {}, online = true
  })
  save()
  return true
end

function M.remove(idx)
  if reactors[idx] then
    table.remove(reactors, idx)
    save()
    return true
  end
  return false
end

function M.toggleAuto(idx)
  if reactors[idx] then
    reactors[idx].auto = not reactors[idx].auto
    save()
  end
end

function M.charge(idx)
  local r = reactors[idx]
  if r and r.proxy and r.proxy.chargeReactor then pcall(r.proxy.chargeReactor) end
end

function M.power(idx)
  local r = reactors[idx]
  if not r or not r.info then return end
  local s = tostring(r.info.status or ""):lower()
  if s == "running" or s == "online" then
    pcall(r.proxy.stopReactor)
    r.auto = false
  else
    pcall(r.proxy.activateReactor)
  end
  save()
end

function M.adjustFlow(idx, delta)
  local r = reactors[idx]
  if not r then return end
  local cur = safeFlow(r.gateOut)
  setFlow(r.gateOut, math.max(cfg.initialFlow or 1000, cur + delta))
end

return M
