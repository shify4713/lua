--[[ PRISMA CORE v3.4 ]]
local component = require("component")
local event = require("event")
local computer = require("computer")
local unicode = require("unicode")
local gpu = component.gpu

local function load(n)
  local ok,m=pcall(dofile,"/home/prisma/lib/"..n..".lua")
  if not ok then io.stderr:write(n..": "..tostring(m).."\n") return nil end
  return m
end

local config=dofile("/home/prisma/config.lua")
local cfg=config.load()
local ui=load("ui"); local utils=load("utils")
local reactor=load("reactor"); local core=load("core")
local precraft=load("precraft"); local singularity=load("singularity")
local glasses=load("glasses"); local radar=load("radar"); local chat=load("chat")
if not ui or not utils then print("UI fail") return end

local w,h=ui.init()
reactor.init(cfg); core.init(cfg); precraft.init(cfg)
singularity.init(cfg); glasses.init(cfg); radar.init(cfg); chat.init(cfg)

local running,tab,needRedraw=true,"dash",true
local lastPlayersHash,lastChatCount="",0
local TABS={{"dash"," DASH "},{"react"," REACTORS "},{"pre"," PRECRAFT "},{"sing"," SINGULAR "},{"set"," SETTINGS "}}
local function tabList()
  local t={}
  for _,v in ipairs(TABS) do table.insert(t,{id=v[1],label=v[2]}) end
  return t
end
local timers={r=0,c=0,rad=0,g=0,p=0,s=0}

local function pHash() return table.concat(radar.getPlayers(),"|") end

local function bg()
  local n=computer.uptime()
  if cfg.modules.reactors and n-timers.r>=0.5 then pcall(reactor.update); timers.r=n end
  if cfg.modules.core and n-timers.c>=0.4 then pcall(core.update); timers.c=n end
  if cfg.modules.radar and n-timers.rad>=0.7 then
    pcall(radar.update); timers.rad=n
    local hsh=pHash()
    if hsh~=lastPlayersHash then lastPlayersHash=hsh; needRedraw=true end
  end
  if cfg.modules.singularity and n-timers.s>=4 then
    if singularity.scan() and tab=="sing" then needRedraw=true end
    timers.s=n
  end
  if cfg.modules.precraft and n-timers.p>=1 then pcall(precraft.update); timers.p=n end
  if cfg.modules.glasses and n-timers.g>=0.8 then
    pcall(function() glasses.update({core=core.getInfo(),reactors=reactor.getList(),players=radar.getPlayers(),chat=chat.getLogs()}) end)
    timers.g=n
  end
end

local function drawDash()
  ui.clearAll(); ui.header("PRISMA CORE v3.4","ONLINE"); ui.drawTabs(tabList(),tab)

  -- Modules (узкая колонка)
  ui.frame(1,4,20,15,"MODULES")
  local mods={{"m_r","reactors","Reactors"},{"m_c","core","Energy Core"},{"m_p","precraft","Precraft"},
              {"m_s","singularity","Singular"},{"m_g","glasses","Glasses"},{"m_rad","radar","Radar"},{"m_ch","chat","Chat"}}
  for i,m in ipairs(mods) do ui.toggle(m[1],2,5+i,17,m[3],cfg.modules[m[2]]) end

  -- Core
  ui.frame(22,4,42,9,"ENERGY CORE")
  local c=core.getInfo()
  if c.online then
    ui.text(24,5,"E "..utils.formatNum(c.energy),ui.C.TEXT)
    ui.text(24,6,"T "..utils.formatNum(c.target),ui.C.ACCENT)
    ui.text(24,7,"F "..utils.formatNum(c.flow).." RF/t",ui.C.DIM)
    ui.progress(24,8,38,c.percent,ui.C.OK)
    ui.btn("cp1",24,10,7,1,"+1G",ui.C.BTN_ON,ui.C.OK)
    ui.btn("cm1",32,10,7,1,"-1G",0x3A1515,ui.C.ALERT)
    ui.btn("cp10",40,10,7,1,"+10G",ui.C.BTN_ON,ui.C.OK)
    ui.btn("cm10",48,10,7,1,"-10G",0x3A1515,ui.C.ALERT)
  else ui.text(24,6,"ЯДРО НЕ НАЙДЕНО",ui.C.ALERT) end

  -- Reactors compact (меньше места)
  ui.frame(22,14,42,h-16,"REACT "..reactor.getCount().."/5")
  local list=reactor.getList()
  for i=1,5 do
    local r=list[i]; local y=15+i
    if r and r.online and r.info then
      local st=tostring(r.info.status or "?"):lower()
      local temp=math.floor(tonumber(r.info.temperature)or 0)
      local field=math.floor(((tonumber(r.info.fieldStrength)or 0)/(tonumber(r.info.maxFieldStrength)or 1))*100)
      local col=(st=="running"or st=="online") and ui.C.OK or ui.C.WARN
      ui.text(24,y,string.format("#%d %s %d° %d%%",i,r.state or st,temp,field),col)
    else ui.text(24,y,"#"..i.." ---",ui.C.DIM) end
  end
  ui.btn("add",24,h-2,10,1,"[+ADD]",ui.C.BTN,ui.C.ACCENT)

  -- Precraft status strip
  local ps=precraft.getStatus()
  ui.frame(65,4,30,5,"PRECRAFT")
  ui.text(67,5,ps.msg or "OFF", ps.msg=="AUTO" and ui.C.OK or ui.C.DIM)
  ui.text(67,6,"A:"..tostring(ps.active or 0).." D:"..tostring(ps.done or 0).." F:"..tostring(ps.failed or 0),ui.C.DIM)
  ui.text(67,7,"next "..string.format("%.0fs",precraft.getNextTick()),ui.C.DIM)

  -- Radar
  ui.frame(65,10,30,10,"RADAR")
  local pls=radar.getPlayers()
  if #pls==0 then ui.text(67,12,"no contacts",ui.C.DIM)
  else for i,n in ipairs(pls) do if i>7 then break end ui.text(67,11+i,">"..unicode.sub(n,1,25),ui.C.ALERT) end end

  -- Chat wider
  ui.frame(96,4,w-97,h-6,"LOCAL CHAT")
  for i,l in ipairs(chat.getLogs()) do
    if i>h-10 then break end
    ui.text(98,5+i,unicode.sub(l,1,w-100),ui.C.TEXT)
  end

  ui.btn("exit",w-10,h,9,1," EXIT",0x3A1515,ui.C.ALERT)
end

local function drawReact()
  ui.clearAll(); ui.header("PRISMA — REACTORS","ONLINE"); ui.drawTabs(tabList(),tab)
  ui.frame(1,4,w-2,h-5,"CONTROL")
  local list=reactor.getList()
  ui.text(3,5,"# STATUS STATE TEMP SHIELD SAT FUEL GEN",ui.C.DIM)
  for i=1,5 do
    local r=list[i]; local y=7+(i-1)*3
    if r and r.online and r.info then
      local st=tostring(r.info.status or "?"):lower()
      local temp=math.floor(tonumber(r.info.temperature)or 0)
      local field=math.floor(((tonumber(r.info.fieldStrength)or 0)/(tonumber(r.info.maxFieldStrength)or 1))*100)
      local sat=math.floor(((tonumber(r.info.energySaturation)or 0)/(tonumber(r.info.maxEnergySaturation)or 1))*100)
      local fuel=math.floor(((tonumber(r.info.fuelConversion)or 0)/(tonumber(r.info.maxFuelConversion)or 1))*100)
      local gen=math.floor((tonumber(r.info.generationRate)or 0)/1000)
      local col=(st=="running"or st=="online") and ui.C.OK or ui.C.WARN
      ui.text(3,y,string.format("#%d %-8s %-8s %4d° %3d%% %3d%% %3d%% %4dK",i,st,r.state or "-",temp,field,sat,fuel,gen),col)
      ui.btn("ra"..i,72,y,6,1,r.auto and "AUTO" or "MAN",r.auto and ui.C.BTN_ON or ui.C.BTN_OFF,r.auto and ui.C.OK or ui.C.DIM)
      ui.btn("rp"..i,80,y,4,1,"+",ui.C.BTN_ON,ui.C.OK)
      ui.btn("rm"..i,85,y,4,1,"-",0x3A1515,ui.C.ALERT)
      ui.btn("rc"..i,91,y,7,1,"CHARGE",0x3A2A00,ui.C.WARN)
      ui.btn("rw"..i,100,y,6,1,(st=="running"or st=="online") and "STOP" or "START",(st=="running"or st=="online") and 0x3A1515 or ui.C.BTN_ON,(st=="running"or st=="online") and ui.C.ALERT or ui.C.OK)
      ui.btn("rd"..i,108,y,4,1,"X",0x3A1515,ui.C.ALERT)
    else ui.text(3,y,"#"..i.." ---",ui.C.DIM) end
  end
  ui.btn("add",3,h-2,10,1,"[+ADD]",ui.C.BTN,ui.C.ACCENT)
  ui.btn("exit",w-10,h,9,1," EXIT",0x3A1515,ui.C.ALERT)
end

local function drawPre()
  ui.clearAll(); ui.header("PRISMA — PRECRAFT","ONLINE"); ui.drawTabs(tabList(),tab)
  ui.frame(1,4,w-2,h-5,"AUTOCRAFT")

  local active=precraft.isActive()
  local paused=precraft.isPaused()
  local st=precraft.getStatus()

  -- toolbar
  ui.btn("ptog",3,5,12,1,active and "[STOP]" or "[AUTO]",active and 0x3A1515 or ui.C.BTN_ON,active and ui.C.ALERT or ui.C.OK)
  ui.btn("ppause",16,5,10,1,paused and "[RESUME]" or "[PAUSE]",0x3A2A00,ui.C.WARN)
  ui.btn("ptick",28,5,12,1,"[TICK NOW]",ui.C.BTN,ui.C.ACCENT)
  ui.btn("padd",42,5,10,1,"[+ ADD]",ui.C.BTN_ON,ui.C.OK)

  ui.text(55,5,"Limit:",ui.C.DIM)
  ui.text(62,5,tostring(precraft.getLimit()),ui.C.ACCENT)
  ui.btn("plim+",66,5,4,1,"+",ui.C.BTN_ON,ui.C.OK)
  ui.btn("plim-",71,5,4,1,"-",0x3A1515,ui.C.ALERT)

  ui.text(78,5,"Tick:",ui.C.DIM)
  ui.text(84,5,tostring(precraft.getTickInterval()).."s",ui.C.ACCENT)
  ui.btn("ptick+",92,5,4,1,"+",ui.C.BTN_ON,ui.C.OK)
  ui.btn("ptick-",97,5,4,1,"-",0x3A1515,ui.C.ALERT)

  ui.text(3,7,string.format("Status: %s | Active: %s | Next: %.0fs",st.msg or "-",tostring(st.active or 0),precraft.getNextTick()),ui.C.DIM)

  -- list
  ui.text(3,9,"#  Name                      Have / Target  Batch  State",ui.C.DIM)
  local items=precraft.getItems()
  for i,it in ipairs(items) do
    if i>h-14 then break end
    local y=10+i
    local col=(it.state=="идёт" and ui.C.OK) or (it.state=="ok" and ui.C.DIM) or ui.C.WARN
    ui.text(3,y,string.format("%-2d %-24s %6s/%-6s %5s  %s",i,unicode.sub(it.name or "?",1,24),tostring(it.current or 0),tostring(it.count or 0),tostring(it.craftSize or 0),it.state or "-"),col)
    ui.btn("pe"..i,100,y,5,1,"EDIT",ui.C.BTN,ui.C.ACCENT)
    ui.btn("px"..i,107,y,4,1,"X",0x3A1515,ui.C.ALERT)
  end
  if #items==0 then ui.text(3,11,"Список пуст. Положи предмет в 1 слот ME Interface и нажми [+ ADD]",ui.C.DIM) end

  ui.btn("exit",w-10,h,9,1," EXIT",0x3A1515,ui.C.ALERT)
end

local function drawSing()
  ui.clearAll(); ui.header("PRISMA — SINGULARITY","ONLINE"); ui.drawTabs(tabList(),tab)
  ui.frame(1,4,w-2,h-5,"SINGULARITY (25)")
  local items=singularity.getItems()
  ui.text(3,5,"Name               Need     Have     Can    Sings",ui.C.DIM)
  for i,it in ipairs(items) do
    if i>h-10 then break end
    local have=singularity.getQty(it.block,it.dmg)
    local can=math.floor(have/it.need)
    local sings=singularity.getQty(it.singu,it.sDmg)
    local col=can>0 and ui.C.OK or ui.C.DIM
    ui.text(3,5+i,string.format("%-18s %5d  %8s  %5d  %5d",it.name,it.need,utils.formatNum(have),can,sings),col)
  end
  ui.text(3,h-2,"ME scan 4s cache | total "..#items,ui.C.DIM)
  ui.btn("exit",w-10,h,9,1," EXIT",0x3A1515,ui.C.ALERT)
end

local function drawSet()
  ui.clearAll(); ui.header("PRISMA — SETTINGS","ONLINE"); ui.drawTabs(tabList(),tab)
  ui.frame(1,4,48,18,"REACTOR")
  ui.text(3,6,"Shield %",ui.C.DIM); ui.text(18,6,tostring(cfg.reactors.targetShield or 20),ui.C.ACCENT)
  ui.btn("shp",24,6,4,1,"+",ui.C.BTN_ON,ui.C.OK); ui.btn("shm",29,6,4,1,"-",0x3A1515,ui.C.ALERT)
  ui.text(3,8,"Force T",ui.C.DIM); ui.text(18,8,tostring(cfg.reactors.forceModeTemp or 7500),ui.C.ACCENT)
  ui.btn("ftp",24,8,4,1,"+",ui.C.BTN_ON,ui.C.OK); ui.btn("ftm",29,8,4,1,"-",0x3A1515,ui.C.ALERT)
  ui.text(3,10,"Safe T",ui.C.DIM); ui.text(18,10,tostring(cfg.reactors.safeModeTemp or 8000),ui.C.ACCENT)
  ui.btn("stp",24,10,4,1,"+",ui.C.BTN_ON,ui.C.OK); ui.btn("stm",29,10,4,1,"-",0x3A1515,ui.C.ALERT)
  ui.text(3,12,"Crit T",ui.C.DIM); ui.text(18,12,tostring(cfg.reactors.tempCrit or 8100),ui.C.ACCENT)
  ui.btn("ctp",24,12,4,1,"+",ui.C.BTN_ON,ui.C.OK); ui.btn("ctm",29,12,4,1,"-",0x3A1515,ui.C.ALERT)

  ui.frame(51,4,50,18,"RADAR IGNORE")
  local ign=cfg.radar.ignore or {}
  for i=1,10 do if ign[i] then ui.text(53,5+i,i..". "..ign[i],ui.C.TEXT); ui.btn("irm"..i,90,5+i,7,1,"DEL",0x3A1515,ui.C.ALERT) end end
  ui.btn("iadd",53,17,12,1,"[+ ADD]",ui.C.BTN_ON,ui.C.OK)
  ui.btn("exit",w-10,h,9,1," EXIT",0x3A1515,ui.C.ALERT)
end

local function redraw()
  if tab=="dash" then drawDash()
  elseif tab=="react" then drawReact()
  elseif tab=="pre" then drawPre()
  elseif tab=="sing" then drawSing()
  elseif tab=="set" then drawSet() end
  needRedraw=false
end

ui.clear(); redraw()

while running do
  bg()
  local ev,_,a1,a2=event.pull(0.12)
  if ev=="touch" then
    local id=ui.hit(a1,a2)
    if id then
      if id=="exit" then running=false
      elseif id=="dash"or id=="react"or id=="pre"or id=="sing"or id=="set" then tab=id; needRedraw=true
      elseif id:sub(1,2)=="m_" then
        local map={m_r="reactors",m_c="core",m_p="precraft",m_s="singularity",m_g="glasses",m_rad="radar",m_ch="chat"}
        local k=map[id]
        if k then cfg.modules[k]=not cfg.modules[k]
          if k=="glasses" then cfg.glasses.enabled=cfg.modules.glasses end
          if k=="precraft" then precraft.setActive(cfg.modules.precraft) end
          config.save(cfg); needRedraw=true end
      elseif id=="cp1" then core.adjustTarget(1e9); config.save(cfg); needRedraw=true
      elseif id=="cm1" then core.adjustTarget(-1e9); config.save(cfg); needRedraw=true
      elseif id=="cp10" then core.adjustTarget(10e9); config.save(cfg); needRedraw=true
      elseif id=="cm10" then core.adjustTarget(-10e9); config.save(cfg); needRedraw=true
      elseif id=="add" then reactor.addInteractive(); needRedraw=true
      elseif id:sub(1,2)=="ra" then reactor.toggleAuto(tonumber(id:sub(3))); needRedraw=true
      elseif id:sub(1,2)=="rp" then reactor.adjustFlow(tonumber(id:sub(3)),cfg.reactors.manualStep or 10000); needRedraw=true
      elseif id:sub(1,2)=="rm" then reactor.adjustFlow(tonumber(id:sub(3)),-(cfg.reactors.manualStep or 10000)); needRedraw=true
      elseif id:sub(1,2)=="rc" then reactor.charge(tonumber(id:sub(3))); needRedraw=true
      elseif id:sub(1,2)=="rw" then reactor.power(tonumber(id:sub(3))); needRedraw=true
      elseif id:sub(1,2)=="rd" then reactor.remove(tonumber(id:sub(3))); needRedraw=true
      elseif id=="ptog" then precraft.setActive(not precraft.isActive()); cfg.modules.precraft=precraft.isActive(); config.save(cfg); needRedraw=true
      elseif id=="ppause" then precraft.togglePause(); needRedraw=true
      elseif id=="ptick" then precraft.forceTick(); needRedraw=true
      elseif id=="padd" then local ok,msg=precraft.addFromSlot(); needRedraw=true
      elseif id=="plim+" then precraft.setLimit(precraft.getLimit()+1); needRedraw=true
      elseif id=="plim-" then precraft.setLimit(precraft.getLimit()-1); needRedraw=true
      elseif id=="ptick+" then precraft.setTickInterval(precraft.getTickInterval()+10); needRedraw=true
      elseif id=="ptick-" then precraft.setTickInterval(precraft.getTickInterval()-10); needRedraw=true
      elseif id:sub(1,2)=="pe" then
        local i=tonumber(id:sub(3))
        local hold=ui.input("HOLD","Target qty:", tostring((precraft.getItems()[i] or {}).count or 64))
        if hold then precraft.edit(i,"count",hold) end
        local batch=ui.input("BATCH","Craft size:", tostring((precraft.getItems()[i] or {}).craftSize or 16))
        if batch then precraft.edit(i,"craftSize",batch) end
        needRedraw=true
      elseif id:sub(1,2)=="px" then precraft.remove(tonumber(id:sub(3))); needRedraw=true
      elseif id=="shp" then cfg.reactors.targetShield=math.min(50,(cfg.reactors.targetShield or 20)+1); config.save(cfg); needRedraw=true
      elseif id=="shm" then cfg.reactors.targetShield=math.max(5,(cfg.reactors.targetShield or 20)-1); config.save(cfg); needRedraw=true
      elseif id=="ftp" then cfg.reactors.forceModeTemp=(cfg.reactors.forceModeTemp or 7500)+100; config.save(cfg); needRedraw=true
      elseif id=="ftm" then cfg.reactors.forceModeTemp=math.max(2000,(cfg.reactors.forceModeTemp or 7500)-100); config.save(cfg); needRedraw=true
      elseif id=="stp" then cfg.reactors.safeModeTemp=(cfg.reactors.safeModeTemp or 8000)+100; config.save(cfg); needRedraw=true
      elseif id=="stm" then cfg.reactors.safeModeTemp=math.max(3000,(cfg.reactors.safeModeTemp or 8000)-100); config.save(cfg); needRedraw=true
      elseif id=="ctp" then cfg.reactors.tempCrit=(cfg.reactors.tempCrit or 8100)+50; config.save(cfg); needRedraw=true
      elseif id=="ctm" then cfg.reactors.tempCrit=math.max(5000,(cfg.reactors.tempCrit or 8100)-50); config.save(cfg); needRedraw=true
      elseif id=="iadd" then local name=ui.input("IGNORE","Player:"); if name and name~="" then cfg.radar.ignore=cfg.radar.ignore or {}; table.insert(cfg.radar.ignore,name); config.save(cfg) end; needRedraw=true
      elseif id:sub(1,3)=="irm" then local i=tonumber(id:sub(4)); if cfg.radar.ignore and cfg.radar.ignore[i] then table.remove(cfg.radar.ignore,i); config.save(cfg); needRedraw=true end
      end
    end
  elseif ev=="chat_message" then
    if cfg.modules.chat then chat.add(a1,a2); local c=#chat.getLogs(); if c~=lastChatCount then lastChatCount=c; needRedraw=true end end
  end
  if needRedraw then redraw() end
end

ui.clear(); gpu.setForeground(0x00D4FF); print("PRISMA stopped."); gpu.setForeground(0xFFFFFF)
