--[[
  ╔══════════════════════════════════════════════════╗
  ║           PRISMA CORE v2.0                       ║
  ║     Tabbed • Anti-flicker • Full Settings        ║
  ╚══════════════════════════════════════════════════╝
]]

local component = require("component")
local event = require("event")
local computer = require("computer")
local unicode = require("unicode")
local gpu = component.gpu

local function loadMod(name)
  local ok, mod = pcall(dofile, "/home/prisma/lib/" .. name .. ".lua")
  if not ok then
    io.stderr:write("[PRISMA] " .. name .. " load error: " .. tostring(mod) .. "\n")
    return nil
  end
  return mod
end

local config = dofile("/home/prisma/config.lua")
local cfg = config.load()

local ui      = loadMod("ui")
local utils   = loadMod("utils")
local reactor = loadMod("reactor")
local core    = loadMod("core")
local precraft= loadMod("precraft")
local singularity = loadMod("singularity")
local glasses = loadMod("glasses")
local radar   = loadMod("radar")
local chat    = loadMod("chat")

if not ui or not utils then
  print("Critical: UI or Utils failed to load")
  return
end

local w, h = ui.init()
reactor.init(cfg)
core.init(cfg)
precraft.init(cfg)
singularity.init(cfg)
glasses.init(cfg)
radar.init(cfg)
chat.init(cfg)

local running = true
local tab = "dashboard"   -- dashboard | reactors | precraft | settings
local dirty = true        -- перерисовываем только когда нужно
local lastFull = 0

local TABS = {
  {id = "dashboard", label = " DASHBOARD "},
  {id = "reactors",  label = " REACTORS "},
  {id = "precraft",  label = " PRECRAFT "},
  {id = "settings",  label = " SETTINGS "},
}

-- ===================== BACKGROUND =====================
local timers = {reactor=0, core=0, radar=0, glasses=0, precraft=0}

local function bg()
  local now = computer.uptime()
  if cfg.modules.reactors and now - timers.reactor >= 0.45 then
    pcall(reactor.update); timers.reactor = now; dirty = true
  end
  if cfg.modules.core and now - timers.core >= 0.35 then
    pcall(core.update); timers.core = now; dirty = true
  end
  if cfg.modules.radar and now - timers.radar >= 1.2 then
    pcall(radar.update); timers.radar = now; dirty = true
  end
  if cfg.modules.precraft and now - timers.precraft >= 6 then
    pcall(precraft.update); timers.precraft = now
  end
  if cfg.modules.glasses and now - timers.glasses >= 0.8 then
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

-- ===================== DRAW HELPERS =====================
local function drawTabs()
  ui.drawTabs(TABS, tab)
end

local function drawDashboard()
  ui.clearButtons()
  ui.header("PRISMA CORE v2.0", "ONLINE")
  drawTabs()

  -- Left modules
  ui.frame(1, 4, 26, 20, "MODULES")
  local mods = {
    {id="m_react", key="reactors",   label="Reactors"},
    {id="m_core",  key="core",       label="Energy Core"},
    {id="m_pre",   key="precraft",   label="Precraft"},
    {id="m_sing",  key="singularity",label="Singularity"},
    {id="m_gls",   key="glasses",    label="Glasses AR"},
    {id="m_rad",   key="radar",      label="Radar"},
    {id="m_cht",   key="chat",       label="Local Chat"},
  }
  for i,m in ipairs(mods) do
    ui.toggle(m.id, 3, 6+(i-1)*2, 22, 1, m.label, cfg.modules[m.key])
  end

  -- Core panel
  ui.frame(28, 4, 55, 12, "ENERGY CORE")
  local c = core.getInfo()
  if c.online then
    ui.text(30, 6, "Energy  " .. utils.formatNum(c.energy), ui.C.TEXT)
    ui.text(30, 7, "Target  " .. utils.formatNum(c.target), ui.C.ACCENT)
    ui.text(30, 8, "Flow    " .. utils.formatNum(c.flow) .. " RF/t", ui.C.TEXT_DIM)
    ui.progress(30, 10, 50, c.percent, ui.C.OK, ui.C.BAR_BG)
    ui.button("c_p1", 30, 12, 9, 1, "+1G", ui.C.BTN_ON, ui.C.OK)
    ui.button("c_m1", 41, 12, 9, 1, "-1G", 0x3A1515, ui.C.ALERT)
    ui.button("c_p10",52, 12, 9, 1, "+10G", ui.C.BTN_ON, ui.C.OK)
    ui.button("c_m10",63, 12, 9, 1, "-10G", 0x3A1515, ui.C.ALERT)
  else
    ui.text(30, 7, "ЯДРО НЕ НАЙДЕНО", ui.C.ALERT)
  end

  -- Reactors mini
  ui.frame(28, 17, 55, h-19, "REACTORS  " .. reactor.getCount() .. "/5")
  local list = reactor.getList()
  ui.text(30, 18, "#  STATUS     STATE       TEMP   SHIELD  FUEL", ui.C.TEXT_DIM)
  for i=1,5 do
    local r = list[i]
    local y = 19 + i
    if r and r.online and r.info then
      local st = tostring(r.info.status or "?"):lower()
      local temp = math.floor(tonumber(r.info.temperature) or 0)
      local field = math.floor(((tonumber(r.info.fieldStrength) or 0)/(tonumber(r.info.maxFieldStrength) or 1))*100)
      local fuel = math.floor(((tonumber(r.info.fuelConversion) or 0)/(tonumber(r.info.maxFuelConversion) or 1))*100)
      local col = (st=="running" or st=="online") and ui.C.OK or ui.C.WARN
      ui.text(30, y, string.format("%d  %-9s  %-10s  %4d°  %3d%%   %3d%%", i, st, r.state or "-", temp, field, fuel), col)
    else
      ui.text(30, y, i .. "  ---", ui.C.TEXT_DIM)
    end
  end

  -- Right: Radar + Chat
  ui.frame(w-36, 4, 36, 14, "RADAR")
  local players = radar.getPlayers()
  if #players == 0 then
    ui.text(w-34, 6, "no contacts", ui.C.TEXT_DIM)
  else
    for i,name in ipairs(players) do
      if i>9 then break end
      ui.text(w-34, 5+i, "> " .. unicode.sub(name,1,30), ui.C.ALERT)
    end
  end

  ui.frame(w-36, 19, 36, h-21, "LOCAL CHAT")
  local logs = chat.getLogs()
  for i,line in ipairs(logs) do
    if i > h-24 then break end
    ui.text(w-34, 20+i, unicode.sub(line,1,32), ui.C.TEXT)
  end

  ui.button("exit", w-11, h, 10, 1, " EXIT ", 0x3A1515, ui.C.ALERT)
end

local function drawReactors()
  ui.clearButtons()
  ui.header("PRISMA CORE — REACTORS", "ONLINE")
  drawTabs()

  ui.frame(1, 4, w-2, h-5, "REACTOR CONTROL")
  local list = reactor.getList()
  ui.text(3, 5, "ID  STATUS      STATE         TEMP    SHIELD  SAT   FUEL    GEN      OUT", ui.C.TEXT_DIM)

  for i=1,5 do
    local r = list[i]
    local y = 6 + (i-1)*3
    if r and r.online and r.info then
      local st = tostring(r.info.status or "?"):lower()
      local temp = math.floor(tonumber(r.info.temperature) or 0)
      local field = math.floor(((tonumber(r.info.fieldStrength) or 0)/(tonumber(r.info.maxFieldStrength) or 1))*100)
      local sat = math.floor(((tonumber(r.info.energySaturation) or 0)/(tonumber(r.info.maxEnergySaturation) or 1))*100)
      local fuel = math.floor(((tonumber(r.info.fuelConversion) or 0)/(tonumber(r.info.maxFuelConversion) or 1))*100)
      local gen = math.floor((tonumber(r.info.generationRate) or 0)/1000)
      local col = (st=="running" or st=="online") and ui.C.OK or ui.C.WARN
      ui.text(3, y, string.format("#%d  %-10s  %-12s  %4d°   %3d%%   %3d%%  %3d%%   %4dK", i, st, r.state or "-", temp, field, sat, fuel, gen), col)

      ui.button("ra_"..i, 70, y, 6, 1, r.auto and "AUTO" or "MAN", r.auto and ui.C.BTN_ON or ui.C.BTN_OFF, r.auto and ui.C.OK or ui.C.TEXT_DIM)
      ui.button("rp_"..i, 78, y, 5, 1, "+", ui.C.BTN_ON, ui.C.OK)
      ui.button("rm_"..i, 84, y, 5, 1, "-", 0x3A1515, ui.C.ALERT)
      ui.button("rc_"..i, 91, y, 7, 1, "CHARGE", 0x3A2A00, ui.C.WARN)
      ui.button("rw_"..i, 100, y, 6, 1, (st=="running" or st=="online") and "STOP" or "START", (st=="running" or st=="online") and 0x3A1515 or ui.C.BTN_ON, (st=="running" or st=="online") and ui.C.ALERT or ui.C.OK)
      ui.button("rd_"..i, 108, y, 5, 1, "X", 0x3A1515, ui.C.ALERT)
    else
      ui.text(3, y, "#"..i.."  ---", ui.C.TEXT_DIM)
    end
  end

  ui.button("add_r", 3, h-2, 14, 1, "[ + ADD ]", ui.C.BTN, ui.C.ACCENT)
  ui.button("exit", w-11, h, 10, 1, " EXIT ", 0x3A1515, ui.C.ALERT)
end

local function drawPrecraft()
  ui.clearButtons()
  ui.header("PRISMA CORE — PRECRAFT", "ONLINE")
  drawTabs()

  ui.frame(1, 4, w-2, h-5, "AUTOCRAFT")
  ui.text(3, 6, "Полноценное меню пре-крафта будет здесь.", ui.C.TEXT_DIM)
  ui.text(3, 7, "Сейчас используется базовая логика из модуля.", ui.C.TEXT_DIM)
  ui.text(3, 9, "Статус: " .. (precraft.isActive() and "АКТИВЕН" or "ВЫКЛ"), precraft.isActive() and ui.C.OK or ui.C.ALERT)

  ui.button("pre_tog", 3, 12, 18, 1, precraft.isActive() and "[ STOP ]" or "[ START ]", precraft.isActive() and 0x3A1515 or ui.C.BTN_ON, precraft.isActive() and ui.C.ALERT or ui.C.OK)
  ui.button("exit", w-11, h, 10, 1, " EXIT ", 0x3A1515, ui.C.ALERT)
end

local function drawSettings()
  ui.clearButtons()
  ui.header("PRISMA CORE — SETTINGS", "ONLINE")
  drawTabs()

  ui.frame(1, 4, 50, 20, "REACTOR SETTINGS")
  ui.text(3, 6, "Target Shield %", ui.C.TEXT_DIM)
  ui.text(25, 6, tostring(cfg.reactors.targetShield or 20), ui.C.ACCENT)
  ui.button("sh_p", 30, 6, 5, 1, "+", ui.C.BTN_ON, ui.C.OK)
  ui.button("sh_m", 36, 6, 5, 1, "-", 0x3A1515, ui.C.ALERT)

  ui.text(3, 8, "Force Temp", ui.C.TEXT_DIM)
  ui.text(25, 8, tostring(cfg.reactors.forceModeTemp or 7500), ui.C.ACCENT)
  ui.button("ft_p", 30, 8, 5, 1, "+", ui.C.BTN_ON, ui.C.OK)
  ui.button("ft_m", 36, 8, 5, 1, "-", 0x3A1515, ui.C.ALERT)

  ui.text(3, 10, "Safe Temp", ui.C.TEXT_DIM)
  ui.text(25, 10, tostring(cfg.reactors.safeModeTemp or 8000), ui.C.ACCENT)
  ui.button("st_p", 30, 10, 5, 1, "+", ui.C.BTN_ON, ui.C.OK)
  ui.button("st_m", 36, 10, 5, 1, "-", 0x3A1515, ui.C.ALERT)

  ui.frame(53, 4, 50, 20, "RADAR IGNORE LIST")
  local ign = cfg.radar.ignore or {}
  for i=1,8 do
    local name = ign[i]
    if name then
      ui.text(55, 5+i, i..". "..name, ui.C.TEXT)
      ui.button("ig_rm_"..i, 90, 5+i, 8, 1, "REMOVE", 0x3A1515, ui.C.ALERT)
    end
  end
  ui.button("ig_add", 55, 16, 16, 1, "[ + ADD ]", ui.C.BTN_ON, ui.C.OK)

  ui.button("exit", w-11, h, 10, 1, " EXIT ", 0x3A1515, ui.C.ALERT)
end

local function redraw()
  if tab == "dashboard" then drawDashboard()
  elseif tab == "reactors" then drawReactors()
  elseif tab == "precraft" then drawPrecraft()
  elseif tab == "settings" then drawSettings()
  end
  dirty = false
  lastFull = computer.uptime()
end

-- ===================== MAIN LOOP =====================
ui.clear()
redraw()

while running do
  bg()

  local ev, _, a1, a2, a3 = event.pull(0.08)

  if ev == "touch" then
    local id = ui.hit(a1, a2)
    if id then
      if id == "exit" then running = false
      elseif id == "dashboard" or id == "reactors" or id == "precraft" or id == "settings" then
        tab = id; dirty = true
      elseif id:sub(1,2) == "m_" then
        local map = {m_react="reactors", m_core="core", m_pre="precraft", m_sing="singularity", m_gls="glasses", m_rad="radar", m_cht="chat"}
        local key = map[id]
        if key then
          cfg.modules[key] = not cfg.modules[key]
          if key == "glasses" then cfg.glasses.enabled = cfg.modules.glasses end
          if key == "precraft" then precraft.setActive(cfg.modules.precraft) end
          config.save(cfg)
          dirty = true
        end
      elseif id == "c_p1" then core.adjustTarget(1e9); config.save(cfg); dirty=true
      elseif id == "c_m1" then core.adjustTarget(-1e9); config.save(cfg); dirty=true
      elseif id == "c_p10" then core.adjustTarget(10e9); config.save(cfg); dirty=true
      elseif id == "c_m10" then core.adjustTarget(-10e9); config.save(cfg); dirty=true
      elseif id == "add_r" then reactor.addInteractive(); dirty=true
      elseif id:sub(1,3) == "ra_" then local i=tonumber(id:sub(4)); reactor.toggleAuto(i); dirty=true
      elseif id:sub(1,3) == "rp_" then local i=tonumber(id:sub(4)); reactor.adjustFlow(i, cfg.reactors.manualStep or 10000); dirty=true
      elseif id:sub(1,3) == "rm_" then local i=tonumber(id:sub(4)); reactor.adjustFlow(i, -(cfg.reactors.manualStep or 10000)); dirty=true
      elseif id:sub(1,3) == "rc_" then local i=tonumber(id:sub(4)); reactor.charge(i); dirty=true
      elseif id:sub(1,3) == "rw_" then local i=tonumber(id:sub(4)); reactor.power(i); dirty=true
      elseif id:sub(1,3) == "rd_" then local i=tonumber(id:sub(4)); reactor.remove(i); dirty=true
      elseif id == "pre_tog" then
        local a = not precraft.isActive()
        precraft.setActive(a)
        cfg.modules.precraft = a
        config.save(cfg)
        dirty = true
      elseif id == "sh_p" then cfg.reactors.targetShield = math.min(50, (cfg.reactors.targetShield or 20)+1); config.save(cfg); dirty=true
      elseif id == "sh_m" then cfg.reactors.targetShield = math.max(5, (cfg.reactors.targetShield or 20)-1); config.save(cfg); dirty=true
      elseif id == "ft_p" then cfg.reactors.forceModeTemp = (cfg.reactors.forceModeTemp or 7500)+100; config.save(cfg); dirty=true
      elseif id == "ft_m" then cfg.reactors.forceModeTemp = math.max(2000, (cfg.reactors.forceModeTemp or 7500)-100); config.save(cfg); dirty=true
      elseif id == "st_p" then cfg.reactors.safeModeTemp = (cfg.reactors.safeModeTemp or 8000)+100; config.save(cfg); dirty=true
      elseif id == "st_m" then cfg.reactors.safeModeTemp = math.max(3000, (cfg.reactors.safeModeTemp or 8000)-100); config.save(cfg); dirty=true
      elseif id == "ig_add" then
        local name = ui.input("ADD IGNORE", "Player name: ")
        if name and name ~= "" then
          cfg.radar.ignore = cfg.radar.ignore or {}
          table.insert(cfg.radar.ignore, name)
          config.save(cfg)
          dirty = true
        else dirty = true end
      elseif id:sub(1,6) == "ig_rm_" then
        local i = tonumber(id:sub(7))
        if cfg.radar.ignore and cfg.radar.ignore[i] then
          table.remove(cfg.radar.ignore, i)
          config.save(cfg)
          dirty = true
        end
      end
    end
  elseif ev == "chat_message" then
    if cfg.modules.chat then
      chat.add(a1, a2)
      dirty = true
    end
  end

  if dirty or (computer.uptime() - lastFull > 1.5) then
    redraw()
  end
end

ui.clear()
gpu.setForeground(0x00D4FF)
print("PRISMA CORE stopped.")
gpu.setForeground(0xFFFFFF)
