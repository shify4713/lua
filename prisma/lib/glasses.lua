-- PRISMA Glasses v3.4 — компактный HUD на весь доступный блок
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

function M.init(config) cfg = config.glasses or {}; opb = findBridge() end
function M.isAvailable() if not opb then opb=findBridge() end; return opb~=nil end

function M.update(data)
  if not cfg.enabled then return end
  if not opb then opb=findBridge(); if not opb then return end end
  local now = computer.uptime()
  if now - lastUpdate < 0.8 then return end
  lastUpdate = now

  pcall(function()
    if opb.clear then opb.clear() end
    local bx,by,bw,bh = 2, 2, 420, 105
    if opb.addBox then
      opb.addBox(bx,by,bw,bh,0x050D14,0.55)
      opb.addBox(bx,by,bw,2,0x00D4FF,0.75)
      opb.addBox(bx+270,by+3,1,bh-6,0x1A3545,0.9)
    end
    if not opb.addText then return end

    local y, L = by+5, bx+4
    opb.addText(L,y,"◆ PRISMA",0x00D4FF).setScale(0.75); y=y+11

    if data.core and data.core.online then
      local c=data.core
      opb.addText(L,y,"CORE "..utils.formatNum(c.energy),0x00E676).setScale(0.6); y=y+8
      opb.addText(L,y,string.format("%d%% %s RF/t",math.floor((c.percent or 0)*100),utils.formatNum(c.flow or 0)),0x5A7A8A).setScale(0.5); y=y+10
    else
      opb.addText(L,y,"CORE OFF",0xFF1744).setScale(0.6); y=y+10
    end

    opb.addText(L,y,"REACTORS",0x00E676).setScale(0.6); y=y+8
    local any=false
    if data.reactors then
      for i,r in ipairs(data.reactors) do
        if i>3 then break end; any=true
        if r.online and r.info then
          local t=math.floor(tonumber(r.info.temperature)or 0)
          local f=math.floor(((tonumber(r.info.fieldStrength)or 0)/(tonumber(r.info.maxFieldStrength)or 1))*100)
          opb.addText(L,y,string.format("#%d %s %d° %d%%",i,r.state or "?",t,f), t>8000 and 0xFFB300 or 0x00E676).setScale(0.5)
        else opb.addText(L,y,"#"..i.." OFF",0x5A7A8A).setScale(0.5) end
        y=y+7
      end
    end
    if not any then opb.addText(L,y,"none",0x5A7A8A).setScale(0.5); y=y+7 end
    y=y+2

    opb.addText(L,y,"NEAR",0xFF1744).setScale(0.6); y=y+8
    if data.players and #data.players>0 then
      for i,n in ipairs(data.players) do if i>3 then break end; opb.addText(L,y,">"..tostring(n),0xFF8A80).setScale(0.5); y=y+7 end
    else opb.addText(L,y,"clear",0x5A7A8A).setScale(0.5) end

    -- chat right
    local rx,cy = bx+278, by+5
    opb.addText(rx,cy,"CHAT",0x00D4FF).setScale(0.7); cy=cy+11
    if data.chat and #data.chat>0 then
      local start=math.max(1,#data.chat-6)
      for i=start,#data.chat do
        local line=tostring(data.chat[i] or "")
        if #line>28 then line=line:sub(1,28) end
        opb.addText(rx,cy,line,0xE0F0F5).setScale(0.48); cy=cy+9
        if cy>by+bh-8 then break end
      end
    else opb.addText(rx,cy,"empty",0x5A7A8A).setScale(0.48) end

    if opb.sync then opb.sync() end
  end)
end

return M
