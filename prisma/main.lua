--[[ PRISMA CORE v3.0 — Full rewrite ]]
local component = require("component")
local event = require("event")
local computer = require("computer")
local unicode = require("unicode")
local gpu = component.gpu

local function load(n)
  local ok,m = pcall(dofile,"/home/prisma/lib/"..n..".lua")
  if not ok then io.stderr:write(n..": "..tostring(m).."\n") return nil end
  return m
end

local config = dofile("/home/prisma/config.lua")
local cfg = config.load()
local ui = load("ui")
local utils = load("utils")
local reactor = load("reactor")
local core = load("core")
local precraft = load("precraft")
local glasses = load("glasses")
local radar = load("radar")
local chat = load("chat")

if not ui or not utils then print("UI/Utils fail") return end

local w,h = ui.init()
reactor.init(cfg); core.init(cfg); precraft.init(cfg)
glasses.init(cfg); radar.init(cfg); chat.init(cfg)

local running, tab, dirty = true, "dash", true
local lastDraw = 0
local TABS = {
  {id="dash",label=" DASH "},
  {id="react",label=" REACTORS "},
  {id="pre",label=" PRECRAFT "},
  {id="set",label=" SETTINGS "},
}

local timers = {r=0,c=0,rad=0,g=0,p=0}

local function bg()
  local n = computer.uptime()
  if cfg.modules.reactors and n-timers.r>=0.5 then pcall(reactor.update); timers.r=n; dirty=true end
  if cfg.modules.core and n-timers.c>=0.4 then pcall(core.update); timers.c=n; dirty=true end
  if cfg.modules.radar and n-timers.rad>=1.5 then pcall(radar.update); timers.rad=n; dirty=true end
  if cfg.modules.precraft and n-timers.p>=6 then pcall(precraft.update); timers.p=n end
  if cfg.modules.glasses and n-timers.g>=0.7 then
    pcall(function()
      glasses.update({
        core=core.getInfo(),
        reactors=reactor.getList(),
        players=radar.getPlayers(),
        chat=chat.getLogs()
      })
    end)
    timers.g=n
  end
end

local function drawDash()
  ui.clearBtns()
  ui.header("PRISMA CORE v3","ONLINE")
  ui.drawTabs(TABS,tab)

  -- Modules
  ui.frame(1,4,24,18,"MODULES")
  local mods={{"m_r","reactors","Reactors"},{"m_c","core","Energy Core"},{"m_p","precraft","Precraft"},
              {"m_g","glasses","Glasses AR"},{"m_rad","radar","Radar"},{"m_ch","chat","Local Chat"}}
  for i,m in ipairs(mods) do ui.toggle(m[1],3,6+(i-1)*2,20,m[3],cfg.modules[m[2]]) end

  -- Core
  ui.frame(26,4,52,11,"ENERGY CORE")
  local c=core.getInfo()
  if c.online then
    ui.text(28,6,"Energy  "..utils.formatNum(c.energy),ui.C.TEXT)
    ui.text(28,7,"Target  "..utils.formatNum(c.target),ui.C.ACCENT)
    ui.text(28,8,"Flow    "..utils.formatNum(c.flow).." RF/t",ui.C.DIM)
    ui.progress(28,10,46,c.percent,ui.C.OK)
    ui.btn("cp1",28,12,8,1,"+1G",ui.C.BTN_ON,ui.C.OK)
    ui.btn("cm1",38,12,8,1,"-1G",0x3A1515,ui.C.ALERT)
    ui.btn("cp10",48,12,8,1,"+10G",ui.C.BTN_ON,ui.C.OK)
    ui.btn("cm10",58,12,8,1,"-10G",0x3A1515,ui.C.ALERT)
  else ui.text(28,7,"ЯДРО НЕ НАЙДЕНО",ui.C.ALERT) end

  -- Reactors mini
  ui.frame(26,16,52,h-18,"REACTORS "..reactor.getCount().."/5")
  local list=reactor.getList()
  ui.text(28,17,"# STATUS    STATE      TEMP  SHIELD FUEL",ui.C.DIM)
  for i=1,5 do
    local r=list[i]; local y=18+i
    if r and r.online and r.info then
      local st=tostring(r.info.status or "?"):lower()
      local temp=math.floor(tonumber(r.info.temperature) or 0)
      local field=math.floor(((tonumber(r.info.fieldStrength)or 0)/(tonumber(r.info.maxFieldStrength)or 1))*100)
      local fuel=math.floor(((tonumber(r.info.fuelConversion)or 0)/(tonumber(r.info.maxFuelConversion)or 1))*100)
      local col=(st=="running"or st=="online") and ui.C.OK or ui.C.WARN
      ui.text(28,y,string.format("%d %-9s %-9s %4d° %3d%%  %3d%%",i,st,r.state or "-",temp,field,fuel),col)
    else ui.text(28,y,i.." ---",ui.C.DIM) end
  end

  -- Radar
  ui.frame(w-34,4,34,12,"RADAR")
  local pls=radar.getPlayers()
  if #pls==0 then ui.text(w-32,6,"no contacts",ui.C.DIM)
  else for i,n in ipairs(pls) do if i>8 then break end ui.text(w-32,5+i,"> "..unicode.sub(n,1,28),ui.C.ALERT) end end

  -- Chat
  ui.frame(w-34,17,34,h-19,"LOCAL CHAT")
  for i,l in ipairs(chat.getLogs()) do
    if i>h-22 then break end
    ui.text(w-32,18+i,unicode.sub(l,1,30),ui.C.TEXT)
  end

  ui.btn("exit",w-10,h,9,1," EXIT",0x3A1515,ui.C.ALERT)
end

local function drawReact()
  ui.clearBtns()
  ui.header("PRISMA CORE — REACTORS","ONLINE")
  ui.drawTabs(TABS,tab)
  ui.frame(1,4,w-2,h-5,"CONTROL")
  local list=reactor.getList()
  ui.text(3,5,"#  STATUS     STATE        TEMP   SHIELD SAT  FUEL  GEN",ui.C.DIM)
  for i=1,5 do
    local r=list[i]; local y=6+(i-1)*3
    if r and r.online and r.info then
      local st=tostring(r.info.status or "?"):lower()
      local temp=math.floor(tonumber(r.info.temperature)or 0)
      local field=math.floor(((tonumber(r.info.fieldStrength)or 0)/(tonumber(r.info.maxFieldStrength)or 1))*100)
      local sat=math.floor(((tonumber(r.info.energySaturation)or 0)/(tonumber(r.info.maxEnergySaturation)or 1))*100)
      local fuel=math.floor(((tonumber(r.info.fuelConversion)or 0)/(tonumber(r.info.maxFuelConversion)or 1))*100)
      local gen=math.floor((tonumber(r.info.generationRate)or 0)/1000)
      local col=(st=="running"or st=="online") and ui.C.OK or ui.C.WARN
      ui.text(3,y,string.format("#%d %-9s %-11s %4d°  %3d%%  %3d%% %3d%% %4dK",i,st,r.state or "-",temp,field,sat,fuel,gen),col)
      ui.btn("ra"..i,72,y,6,1,r.auto and "AUTO" or "MAN",r.auto and ui.C.BTN_ON or ui.C.BTN_OFF,r.auto and ui.C.OK or ui.C.DIM)
      ui.btn("rp"..i,80,y,4,1,"+",ui.C.BTN_ON,ui.C.OK)
      ui.btn("rm"..i,85,y,4,1,"-",0x3A1515,ui.C.ALERT)
      ui.btn("rc"..i,91,y,7,1,"CHARGE",0x3A2A00,ui.C.WARN)
      ui.btn("rw"..i,100,y,6,1,(st=="running"or st=="online") and "STOP" or "START",(st=="running"or st=="online") and 0x3A1515 or ui.C.BTN_ON,(st=="running"or st=="online") and ui.C.ALERT or ui.C.OK)
      ui.btn("rd"..i,108,y,4,1,"X",0x3A1515,ui.C.ALERT)
    else ui.text(3,y,"#"..i.." ---",ui.C.DIM) end
  end
  ui.btn("add",3,h-2,12,1,"[ + ADD ]",ui.C.BTN,ui.C.ACCENT)
  ui.btn("exit",w-10,h,9,1," EXIT",0x3A1515,ui.C.ALERT)
end

local function drawPre()
  ui.clearBtns()
  ui.header("PRISMA CORE — PRECRAFT","ONLINE")
  ui.drawTabs(TABS,tab)
  ui.frame(1,4,w-2,h-5,"AUTOCRAFT")
  ui.text(3,6,"Статус: "..(precraft.isActive() and "АКТИВЕН" or "ВЫКЛЮЧЕН"),precraft.isActive() and ui.C.OK or ui.C.ALERT)
  ui.text(3,8,"Полное меню предметов будет добавлено в следующем обновлении.",ui.C.DIM)
  ui.btn("ptog",3,11,16,1,precraft.isActive() and "[ STOP ]" or "[ START ]",precraft.isActive() and 0x3A1515 or ui.C.BTN_ON,precraft.isActive() and ui.C.ALERT or ui.C.OK)
  ui.btn("exit",w-10,h,9,1," EXIT",0x3A1515,ui.C.ALERT)
end

local function drawSet()
  ui.clearBtns()
  ui.header("PRISMA CORE — SETTINGS","ONLINE")
  ui.drawTabs(TABS,tab)

  ui.frame(1,4,48,22,"REACTOR")
  ui.text(3,6,"Target Shield %",ui.C.DIM)
  ui.text(22,6,tostring(cfg.reactors.targetShield or 20),ui.C.ACCENT)
  ui.btn("shp",28,6,4,1,"+",ui.C.BTN_ON,ui.C.OK)
  ui.btn("shm",33,6,4,1,"-",0x3A1515,ui.C.ALERT)

  ui.text(3,8,"Force Temp",ui.C.DIM)
  ui.text(22,8,tostring(cfg.reactors.forceModeTemp or 7500),ui.C.ACCENT)
  ui.btn("ftp",28,8,4,1,"+",ui.C.BTN_ON,ui.C.OK)
  ui.btn("ftm",33,8,4,1,"-",0x3A1515,ui.C.ALERT)

  ui.text(3,10,"Safe Temp",ui.C.DIM)
  ui.text(22,10,tostring(cfg.reactors.safeModeTemp or 8000),ui.C.ACCENT)
  ui.btn("stp",28,10,4,1,"+",ui.C.BTN_ON,ui.C.OK)
  ui.btn("stm",33,10,4,1,"-",0x3A1515,ui.C.ALERT)

  ui.text(3,12,"Crit Temp",ui.C.DIM)
  ui.text(22,12,tostring(cfg.reactors.tempCrit or 8100),ui.C.ACCENT)
  ui.btn("ctp",28,12,4,1,"+",ui.C.BTN_ON,ui.C.OK)
  ui.btn("ctm",33,12,4,1,"-",0x3A1515,ui.C.ALERT)

  ui.frame(51,4,50,22,"RADAR IGNORE")
  local ign=cfg.radar.ignore or {}
  for i=1,10 do
    if ign[i] then
      ui.text(53,5+i,i..". "..ign[i],ui.C.TEXT)
      ui.btn("irm"..i,90,5+i,7,1,"DEL",0x3A1515,ui.C.ALERT)
    end
  end
  ui.btn("iadd",53,18,14,1,"[ + ADD ]",ui.C.BTN_ON,ui.C.OK)

  ui.btn("exit",w-10,h,9,1," EXIT",0x3A1515,ui.C.ALERT)
end

local function redraw()
  if tab=="dash" then drawDash()
  elseif tab=="react" then drawReact()
  elseif tab=="pre" then drawPre()
  elseif tab=="set" then drawSet() end
  dirty=false; lastDraw=computer.uptime()
end

ui.clear(); redraw()

while running do
  bg()
  local ev,_,a1,a2 = event.pull(0.1)
  if ev=="touch" then
    local id=ui.hit(a1,a2)
    if id then
      if id=="exit" then running=false
      elseif id=="dash" or id=="react" or id=="pre" or id=="set" then tab=id; dirty=true
      elseif id:sub(1,2)=="m_" then
        local map={m_r="reactors",m_c="core",m_p="precraft",m_g="glasses",m_rad="radar",m_ch="chat"}
        local k=map[id]
        if k then
          cfg.modules[k]=not cfg.modules[k]
          if k=="glasses" then cfg.glasses.enabled=cfg.modules.glasses end
          if k=="precraft" then precraft.setActive(cfg.modules.precraft) end
          config.save(cfg); dirty=true
        end
      elseif id=="cp1" then core.adjustTarget(1e9); config.save(cfg); dirty=true
      elseif id=="cm1" then core.adjustTarget(-1e9); config.save(cfg); dirty=true
      elseif id=="cp10" then core.adjustTarget(10e9); config.save(cfg); dirty=true
      elseif id=="cm10" then core.adjustTarget(-10e9); config.save(cfg); dirty=true
      elseif id=="add" then reactor.addInteractive(); dirty=true
      elseif id:sub(1,2)=="ra" then reactor.toggleAuto(tonumber(id:sub(3))); dirty=true
      elseif id:sub(1,2)=="rp" then reactor.adjustFlow(tonumber(id:sub(3)),cfg.reactors.manualStep or 10000); dirty=true
      elseif id:sub(1,2)=="rm" then reactor.adjustFlow(tonumber(id:sub(3)),-(cfg.reactors.manualStep or 10000)); dirty=true
      elseif id:sub(1,2)=="rc" then reactor.charge(tonumber(id:sub(3))); dirty=true
      elseif id:sub(1,2)=="rw" then reactor.power(tonumber(id:sub(3))); dirty=true
      elseif id:sub(1,2)=="rd" then reactor.remove(tonumber(id:sub(3))); dirty=true
      elseif id=="ptog" then local a=not precraft.isActive(); precraft.setActive(a); cfg.modules.precraft=a; config.save(cfg); dirty=true
      elseif id=="shp" then cfg.reactors.targetShield=math.min(50,(cfg.reactors.targetShield or 20)+1); config.save(cfg); dirty=true
      elseif id=="shm" then cfg.reactors.targetShield=math.max(5,(cfg.reactors.targetShield or 20)-1); config.save(cfg); dirty=true
      elseif id=="ftp" then cfg.reactors.forceModeTemp=(cfg.reactors.forceModeTemp or 7500)+100; config.save(cfg); dirty=true
      elseif id=="ftm" then cfg.reactors.forceModeTemp=math.max(2000,(cfg.reactors.forceModeTemp or 7500)-100); config.save(cfg); dirty=true
      elseif id=="stp" then cfg.reactors.safeModeTemp=(cfg.reactors.safeModeTemp or 8000)+100; config.save(cfg); dirty=true
      elseif id=="stm" then cfg.reactors.safeModeTemp=math.max(3000,(cfg.reactors.safeModeTemp or 8000)-100); config.save(cfg); dirty=true
      elseif id=="ctp" then cfg.reactors.tempCrit=(cfg.reactors.tempCrit or 8100)+50; config.save(cfg); dirty=true
      elseif id=="ctm" then cfg.reactors.tempCrit=math.max(5000,(cfg.reactors.tempCrit or 8100)-50); config.save(cfg); dirty=true
      elseif id=="iadd" then
        local name=ui.input("IGNORE","Player: ")
        if name and name~="" then cfg.radar.ignore=cfg.radar.ignore or {}; table.insert(cfg.radar.ignore,name); config.save(cfg) end
        dirty=true
      elseif id:sub(1,3)=="irm" then
        local i=tonumber(id:sub(4))
        if cfg.radar.ignore and cfg.radar.ignore[i] then table.remove(cfg.radar.ignore,i); config.save(cfg); dirty=true end
      end
    end
  elseif ev=="chat_message" then
    if cfg.modules.chat then chat.add(a1,a2); dirty=true end
  end
  if dirty or computer.uptime()-lastDraw>2 then redraw() end
end

ui.clear()
gpu.setForeground(0x00D4FF); print("PRISMA CORE stopped."); gpu.setForeground(0xFFFFFF)
