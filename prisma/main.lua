--[[
  ╔══════════════════════════════════════════════════════════╗
  ║           PRISMA CORE v1.0                               ║
  ║   Unified Control System for OpenComputers 1.7.10        ║
  ║   Reactors • Core • Precraft • Singularity • Glasses    ║
  ╚══════════════════════════════════════════════════════════╝
]]

local component = require("component")
local event = require("event")
local computer = require("computer")
local term = require("term")
local unicode = require("unicode")
local gpu = component.gpu

-- Загрузка модулей
local function loadMod(name)
  local path = "/home/prisma/lib/" .. name .. ".lua"
  local ok, mod = pcall(dofile, path)
  if not ok then
    io.stderr:write("[PRISMA] Failed to load " .. name .. ": " .. tostring(mod) .. "\n")
    return nil
  end
  return mod
end

local config = dofile("/home/prisma/config.lua")
local cfg = config.load()

local ui = loadMod("ui")
local utils = loadMod("utils")
local reactor = loadMod("reactor")
local core = loadMod("core")
local precraft = loadMod("precraft")
local singularity = loadMod("singularity")
local glasses = loadMod("glasses")
local radar = loadMod("radar")
local chat = loadMod("chat")

if not ui or not utils then
  print("Критическая ошибка загрузки UI/Utils")
  return
end

-- Инициализация
local w, h = ui.setRes(cfg.resolution.w, cfg.resolution.h)
reactor.init(cfg)
core.init(cfg)
precraft.init(cfg)
singularity.init(cfg)
glasses.init(cfg)
radar.init(cfg)
chat.init(cfg)

local running = true
local currentTab = "main"
local lastTick = 0

-- Фоновые таймеры (обязательные фоновые процессы)
local timers = {
  reactor = 0,
  core = 0,
  radar = 0,
  glasses = 0,
  precraft = 0,
}

local function backgroundUpdate()
  local now = computer.uptime()

  if cfg.modules.reactors and now - timers.reactor >= 0.4 then
    pcall(reactor.update)
    timers.reactor = now
  end
  if cfg.modules.core and now - timers.core >= 0.3 then
    pcall(core.update)
    timers.core = now
  end
  if cfg.modules.radar and now - timers.radar >= 1.0 then
    pcall(radar.update)
    timers.radar = now
  end
  if cfg.modules.precraft and now - timers.precraft >= 5.0 then
    pcall(precraft.update)
    timers.precraft = now
  end
  if cfg.modules.glasses and now - timers.glasses >= 0.7 then
    pcall(function()
      glasses.update({
        core = core.getInfo(),
        reactors = reactor.getList(),
        players = radar.getPlayers()
      })
    end)
    timers.glasses = now
  end
end

local function drawMain()
  ui.clearButtons()
  ui.clear(ui.C.BG)
  ui.drawHeader(w, "PRISMA CORE v1.0", "ONLINE")

  -- Левая панель — тумблеры модулей
  ui.frame(1, 3, 28, h - 4, "MODULES")
  local mods = {
    {id = "tog_reactors", key = "reactors", label = "Reactors"},
    {id = "tog_core", key = "core", label = "Energy Core"},
    {id = "tog_precraft", key = "precraft", label = "Precraft"},
    {id = "tog_sing", key = "singularity", label = "Singularity"},
    {id = "tog_glasses", key = "glasses", label = "Glasses AR"},
    {id = "tog_radar", key = "radar", label = "Radar"},
    {id = "tog_chat", key = "chat", label = "Local Chat"},
  }
  for i, m in ipairs(mods) do
    local state = cfg.modules[m.key]
    ui.toggle(m.id, 3, 5 + (i - 1) * 2, 24, 1, m.label, state)
  end

  -- Центр — Core + Reactors summary
  ui.frame(30, 3, 70, 18, "ENERGY CORE")
  local cinfo = core.getInfo()
  if cinfo.online then
    ui.text(32, 5, "ENERGY: " .. utils.formatNum(cinfo.energy), ui.C.TEXT)
    ui.text(32, 6, "TARGET: " .. utils.formatNum(cinfo.target), ui.C.ACCENT)
    ui.text(32, 7, "FLOW:   " .. utils.formatNum(cinfo.flow) .. " RF/t", ui.C.TEXT_DIM)
    ui.progressBar(32, 9, 64, cinfo.percent, ui.C.OK, ui.C.BAR_BG)
    ui.button("core_plus", 32, 11, 10, 1, "+1G", ui.C.BTN_ON, ui.C.OK, true)
    ui.button("core_minus", 44, 11, 10, 1, "-1G", 0x471C1C, ui.C.ALERT, true)
  else
    ui.text(32, 6, "ЯДРО НЕ НАЙДЕНО", ui.C.ALERT)
  end

  -- Reactors list
  ui.frame(30, 22, 70, h - 24, "REACTORS (" .. reactor.getCount() .. "/5)")
  local list = reactor.getList()
  ui.text(32, 23, "ID  STATUS      STATE        TEMP    SHIELD  FUEL", ui.C.TEXT_DIM)
  for i = 1, 5 do
    local y = 24 + i
    local r = list[i]
    if r and r.online and r.info then
      local st = tostring(r.info.status or "?"):lower()
      local temp = math.floor(tonumber(r.info.temperature) or 0)
      local field = math.floor(((tonumber(r.info.fieldStrength) or 0) / (tonumber(r.info.maxFieldStrength) or 1)) * 100)
      local fuel = math.floor(((tonumber(r.info.fuelConversion) or 0) / (tonumber(r.info.maxFuelConversion) or 1)) * 100)
      local col = (st == "running" or st == "online") and ui.C.OK or ui.C.WARN
      ui.text(32, y, string.format("#%d  %-10s  %-12s  %4d°  %3d%%   %3d%%", i, st, r.state or "-", temp, field, fuel), col)
    else
      ui.text(32, y, string.format("#%d  ---", i), ui.C.TEXT_DIM)
    end
  end
  ui.button("add_reactor", 32, h - 3, 16, 1, "[+ ADD]", ui.C.BTN, ui.C.ACCENT, true)

  -- Правая панель — Radar + Chat
  ui.frame(w - 38, 3, 38, 16, "RADAR")
  local players = radar.getPlayers()
  if #players == 0 then
    ui.text(w - 36, 5, "NO CONTACTS", ui.C.TEXT_DIM)
  else
    for i, name in ipairs(players) do
      if i > 10 then break end
      ui.text(w - 36, 4 + i, "> " .. name, ui.C.ALERT)
    end
  end

  ui.frame(w - 38, 20, 38, h - 22, "LOCAL CHAT")
  local logs = chat.getLogs()
  for i, line in ipairs(logs) do
    if i > h - 24 then break end
    ui.text(w - 36, 21 + i, unicode.sub(line, 1, 34), ui.C.TEXT)
  end

  ui.button("exit", w - 12, h - 1, 10, 1, "EXIT", 0x441111, ui.C.ALERT, true)
end

local function redraw()
  if currentTab == "main" then
    drawMain()
  end
end

-- Главный цикл
ui.clear()
redraw()

while running do
  backgroundUpdate()

  local ev, addr, a1, a2, a3, a4 = event.pull(0.05)
  if ev == "touch" then
    local id = ui.hit(a1, a2)
    if id == "exit" then
      running = false
    elseif id == "tog_reactors" then
      cfg.modules.reactors = not cfg.modules.reactors
      config.save(cfg)
      redraw()
    elseif id == "tog_core" then
      cfg.modules.core = not cfg.modules.core
      config.save(cfg)
      redraw()
    elseif id == "tog_glasses" then
      cfg.modules.glasses = not cfg.modules.glasses
      cfg.glasses.enabled = cfg.modules.glasses
      config.save(cfg)
      redraw()
    elseif id == "tog_radar" then
      cfg.modules.radar = not cfg.modules.radar
      config.save(cfg)
      redraw()
    elseif id == "tog_precraft" then
      cfg.modules.precraft = not cfg.modules.precraft
      precraft.setActive(cfg.modules.precraft)
      config.save(cfg)
      redraw()
    elseif id == "tog_sing" then
      cfg.modules.singularity = not cfg.modules.singularity
      singularity.setActive(cfg.modules.singularity)
      config.save(cfg)
      redraw()
    elseif id == "tog_chat" then
      cfg.modules.chat = not cfg.modules.chat
      config.save(cfg)
      redraw()
    elseif id == "core_plus" then
      core.adjustTarget(1e9)
      config.save(cfg)
      redraw()
    elseif id == "core_minus" then
      core.adjustTarget(-1e9)
      config.save(cfg)
      redraw()
    elseif id == "add_reactor" then
      reactor.addInteractive()
      redraw()
    end
  elseif ev == "chat_message" then
    -- event: chat_message, address, username, message
    if cfg.modules.chat then
      chat.add(a1, a2)
      redraw()
    end
  end

  if computer.uptime() - lastTick > 0.8 then
    redraw()
    lastTick = computer.uptime()
  end
end

ui.clear()
gpu.setForeground(0x00E5FF)
print("PRISMA CORE stopped.")
gpu.setForeground(0xFFFFFF)
