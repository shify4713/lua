-- PRISMA · glasses: компактный AR-HUD (OpenPeripheral Glasses Bridge)
--   • виджеты создаются один раз и потом только обновляются → без мерцания
--   • панель занимает ровно столько места, сколько нужно (авто-высота), якорь в любом углу
--   • каждая секция включается отдельно; есть пресеты «мини / норма / полный»
--   • если мост не поддерживает обновление виджетов — автоматически режим «перерисовка» (как в старых версиях)
local P = ...
local U = P.util
local log = P.log
local component = require("component")

local G = {}
local bridge, bridgeAddr
local widgets = {}          -- id -> { obj, spec }
local mode = "retained"     -- retained | simple
local lastRun = 0
local lastSig
local lastSync = 0
G.lastErr = nil
G.rect = { x = 0, y = 0, w = 0, h = 0 }
G.stats = { updates = 0, creates = 0, rebuilds = 0 }

local COL = { acc = 0x00D4FF, ok = 0x00E676, warn = 0xFFB300, bad = 0xFF1744, dim = 0x90A4AE, text = 0xE0F0F5, bg = 0x050D14, line = 0x1A3545 }

local function cfg() return P.cfg.glasses end

local function findBridge()
  local b, a = U.findComp({ "openperipheral_bridge", "glasses_bridge", "terminal_glasses_bridge", "glasses", "terminal" }, P.cfg.devices.glasses)
  if b then return b, a end
  for addr, t in component.list() do
    if t and (t:find("glasses") or t:find("bridge")) then
      local p = U.proxy(addr)
      if p and (p.addText or p.clear) then return p, addr end
    end
  end
end

function G.init()
  widgets, lastSig, lastRun = {}, nil, 0
  mode = "retained"
  bridge, bridgeAddr = findBridge()
  G.lastErr = nil
  if bridge then pcall(function() bridge.clear(); bridge.sync() end) end
end

function G.available() return bridge ~= nil end
function G.address() return bridgeAddr end
function G.mode() return mode end

function G.clear()
  widgets = {}
  lastSig = nil
  if bridge then pcall(function() bridge.clear(); if bridge.sync then bridge.sync() end end) end
end

-- ───────── пресеты ─────────
G.PRESETS = {
  mini   = { w = 112, scale = 0.5, maxCraft = 1, chatLines = 0, show = { core = true, reactors = true, craft = true, sing = false, near = true, chat = false } },
  normal = { w = 150, scale = 0.6, maxCraft = 3, chatLines = 4, show = { core = true, reactors = true, craft = true, sing = false, near = true, chat = true } },
  full   = { w = 190, scale = 0.65, maxCraft = 5, chatLines = 6, show = { core = true, reactors = true, craft = true, sing = true, near = true, chat = true } },
}

function G.applyPreset(name)
  local p = G.PRESETS[name]
  if not p then return end
  local g = cfg()
  g.preset = name
  g.w, g.scale, g.maxCraft, g.chatLines = p.w, p.scale, p.maxCraft, p.chatLines
  for k, v in pairs(p.show) do g.show[k] = v end
  P.config.markDirty()
  lastSig = nil
end

-- ───────── построение сцены ─────────
-- строит основной информационный блок (ядро/реакторы/крафт/синг/радар) в координатах,
-- начинающихся с y=pad; возвращает список элементов и итоговую высоту блока
local function buildMain(g, s, lh, pad, W)
  local mods = P.mods
  local els = {}
  local y = pad
  local function add(e) els[#els + 1] = e; return e end
  local function text(id, x, ty, str, color, sc)
    add({ id = id, kind = "text", x = x, y = ty, text = str, color = color or COL.text, scale = sc or s })
  end
  local function textR(id, ty, str, color, sc)
    local x = W - pad - U.ulen(str) * 5.6 * (sc or s)
    text(id, math.max(pad, math.floor(x)), ty, str, color, sc)
  end
  local function bar(id, x, ty, w, frac, color)
    add({ id = id .. ".t", kind = "box", x = x, y = ty, w = w, h = 2, color = 0x24343F, alpha = 0.9 })
    frac = U.clamp(frac or 0, 0, 1)
    if frac > 0.005 then add({ id = id .. ".f", kind = "box", x = x, y = ty, w = math.max(1, math.floor(w * frac)), h = 2, color = color, alpha = 1 }) end
  end

  text("hdr", pad, y, "◆ PRISMA", COL.acc, s * 1.15)
  textR("hdr.r", y, string.sub(U.clock(), 1, 5), COL.dim)
  y = y + lh + 2

  if g.show.core and mods.core then
    local c = mods.core.info()
    if c.online then
      local col = c.percent > 0.9 and COL.warn or COL.ok
      text("core.t", pad, y, "ЯДРО " .. U.num(c.energy) .. "  " .. math.floor(c.percent * 100) .. "%", col)
      local rate = c.rate * 20
      textR("core.r", y, (rate >= 0 and "+" or "") .. U.num(rate) .. "/с", rate >= 0 and COL.ok or COL.warn)
      y = y + lh
      bar("core.b", pad, y, W - pad * 2, c.percent, col)
      if c.max > 0 and c.target > 0 then
        add({ id = "core.m", kind = "box", x = pad + math.floor((W - pad * 2) * U.clamp(c.target / c.max, 0, 1)), y = y - 1, w = 1, h = 4, color = 0xFFFFFF, alpha = 0.9 })
      end
      y = y + 5
    else
      text("core.t", pad, y, "ЯДРО: нет данных", COL.bad)
      y = y + lh
    end
  end

  if g.show.reactors and mods.reactor and mods.reactor.count() > 0 then
    local r = mods.reactor
    for i, rr in ipairs(r.list()) do
      if rr.online then
        local d = rr.d
        local rc = P.cfg.reactors
        local col = COL.ok
        if d.temp >= rc.tempCrit then col = COL.bad elseif d.temp >= rc.safeModeTemp then col = COL.warn end
        if rr.kind ~= "running" then col = COL.dim end
        text("r" .. i .. ".t", pad, y, string.format("R%d %d°  %d%%", i, math.floor(d.temp), math.floor(d.field * 100)), col)
        local bw = math.floor(W * 0.28)
        bar("r" .. i .. ".b", W - pad - bw, y + math.floor(lh / 2) - 1, bw, d.temp / 10000, col)
      else
        text("r" .. i .. ".t", pad, y, "R" .. i .. " нет связи", COL.bad)
      end
      y = y + lh
    end
  end

  if g.show.craft and mods.autocraft then
    local list = mods.autocraft.crafting()
    if #list > 0 then
      text("cr.h", pad, y, "КРАФТ ×" .. #list, COL.acc)
      y = y + lh
      for i, it in ipairs(list) do
        if i > g.maxCraft then break end
        local frac, el, eta = mods.autocraft.progress(it)
        frac = frac or 0
        local nameMax = math.max(6, math.floor((W - pad * 2) / (5.6 * s) * 0.5))
        text("cr" .. i .. ".t", pad + 4, y, U.trunc(it.label, nameMax), COL.text)
        textR("cr" .. i .. ".r", y, math.floor(frac * 100) .. "% " .. U.dur(eta), COL.dim)
        y = y + lh - 1
        bar("cr" .. i .. ".b", pad + 4, y, W - pad * 2 - 4, frac, COL.acc)
        y = y + 4
      end
    end
  end

  if g.show.sing and mods.singularity then
    local sm = mods.singularity.summary()
    text("sg.t", pad, y, "СИНГУЛЯРКИ готово: " .. sm.ready, sm.ready > 0 and COL.ok or COL.dim)
    y = y + lh
  end

  if g.show.near and mods.radar then
    local pl = mods.radar.players()
    if #pl > 0 then
      local names = table.concat(pl, ", ")
      text("nr.t", pad, y, "РЯДОМ: " .. U.trunc(names, math.floor((W - pad * 2) / (5.6 * s)) - 8), COL.bad)
      y = y + lh
    end
  end

  return els, (y + pad - 2)
end

-- строит блок чата, возвращает элементы и высоту (0, если чат пуст/выключен)
local function buildChat(g, s, lh, pad, W)
  local mods = P.mods
  if not (g.show.chat and mods.chat and g.chatLines > 0) then return {}, 0 end
  local chat = mods.chat.lines(g.chatLines)
  if #chat == 0 then return {}, 0 end
  local chatScale = s * (g.chatScale or 0.95)
  local chatLh = math.ceil(8 * chatScale) + 1 + (g.chatGap or 0)
  local h = pad + lh + #chat * chatLh + pad - 1
  local out = {}
  out[#out + 1] = { id = "cbg", kind = "box", x = 0, y = 0, w = W, h = h, color = COL.bg, alpha = g.alpha }
  out[#out + 1] = { id = "cbg.l", kind = "box", x = 0, y = 0, w = 1, h = h, color = COL.acc, alpha = 0.7 }
  local ty = pad - 1
  out[#out + 1] = { id = "ch.h", kind = "text", x = pad + 2, y = ty, text = "ЧАТ", color = COL.acc, scale = s }
  ty = ty + lh
  for i, line in ipairs(chat) do
    out[#out + 1] = { id = "ch" .. i, kind = "text", x = pad + 2, y = ty, text = U.trunc(line, g.chatWidth), color = COL.text, scale = chatScale }
    ty = ty + chatLh
  end
  return out, h
end

local function build()
  local g = cfg()
  local s = g.scale
  local lh = math.ceil(8 * s) + 2
  local W = g.w
  local pad = 4

  local mainEls, mainH = buildMain(g, s, lh, pad, W)
  local chatEls, chatH = buildChat(g, s, lh, pad, W)

  -- порядок блоков: чат сверху (chatBelow=false) или снизу (по умолчанию)
  local mainOff, chatOff
  if chatH > 0 and g.chatBelow == false then
    chatOff, mainOff = 0, chatH + 3
  else
    mainOff, chatOff = 0, mainH + 3
  end
  local totalH = mainH + (chatH > 0 and (chatH + 3) or 0)

  local out = {}
  out[#out + 1] = { id = "bg", kind = "box", x = 0, y = mainOff, w = W, h = mainH, color = COL.bg, alpha = g.alpha }
  out[#out + 1] = { id = "bg.l", kind = "box", x = 0, y = mainOff, w = W, h = 1, color = COL.acc, alpha = 0.85 }
  for _, e in ipairs(mainEls) do e.y = e.y + mainOff; out[#out + 1] = e end
  for _, e in ipairs(chatEls) do e.y = e.y + chatOff; out[#out + 1] = e end

  -- координаты панели по якорю
  local ox, oy = g.x, g.y
  if g.anchor == "TR" or g.anchor == "BR" then ox = g.screenW - W - g.x end
  if g.anchor == "BL" or g.anchor == "BR" then oy = g.screenH - totalH - g.y end
  ox, oy = math.floor(ox), math.floor(oy)

  for _, e in ipairs(out) do
    e.x = math.floor(e.x + ox)
    e.y = math.floor(e.y + oy)
  end
  G.rect = { x = ox, y = oy, w = W, h = totalH }
  return out
end

-- ───────── вывод сцены ─────────
local function sig(e)
  if e.kind == "box" then
    return string.format("%.0f,%.0f,%.0f,%.0f,%.0f,%.2f", e.x, e.y, e.w, e.h, e.color, e.alpha)
  end
  return string.format("%.0f,%.0f,%s,%.0f,%.2f", e.x, e.y, e.text, e.color, e.scale)
end

local function create(e)
  if e.kind == "box" then
    return bridge.addBox(e.x, e.y, e.w, e.h, e.color, e.alpha)
  end
  local o = bridge.addText(e.x, e.y, e.text, e.color)
  if o and o.setScale then o.setScale(e.scale) end
  return o
end

local function update(w, e)
  local o, old = w.obj, w.spec
  if e.kind == "box" then
    if old.x ~= e.x then o.setX(e.x) end
    if old.y ~= e.y then o.setY(e.y) end
    if old.w ~= e.w then o.setWidth(e.w) end
    if old.h ~= e.h then o.setHeight(e.h) end
    if old.color ~= e.color then o.setColor(e.color) end
    if old.alpha ~= e.alpha then o.setOpacity(e.alpha) end
  else
    if old.text ~= e.text then o.setText(e.text) end
    if old.x ~= e.x then o.setX(e.x) end
    if old.y ~= e.y then o.setY(e.y) end
    if old.color ~= e.color then o.setColor(e.color) end
    if old.scale ~= e.scale then o.setScale(e.scale) end
  end
end

local function applyRetained(scene)
  local seen = {}
  local changed = false
  for _, e in ipairs(scene) do
    seen[e.id] = true
    local w = widgets[e.id]
    if not w then
      local o = create(e)
      if not o then error("addBox/addText вернул nil") end
      widgets[e.id] = { obj = o, spec = e }
      G.stats.creates = G.stats.creates + 1
      changed = true
    elseif w.spec.kind ~= e.kind then
      pcall(function() w.obj.delete() end)
      widgets[e.id] = { obj = create(e), spec = e }
      changed = true
    elseif sig(w.spec) ~= sig(e) then
      update(w, e)
      w.spec = e
      G.stats.updates = G.stats.updates + 1
      changed = true
    end
  end
  for id, w in pairs(widgets) do
    if not seen[id] then
      pcall(function() w.obj.delete() end)
      widgets[id] = nil
      changed = true
    end
  end
  return changed
end

local function applySimple(scene)
  local parts = {}
  for _, e in ipairs(scene) do parts[#parts + 1] = sig(e) end
  local s = table.concat(parts, "|")
  if s == lastSig and U.now() - lastSync < 10 then return false end
  lastSig = s
  bridge.clear()
  for _, e in ipairs(scene) do create(e) end
  G.stats.rebuilds = G.stats.rebuilds + 1
  return true
end

function G.update(now)
  now = now or U.now()
  local g = cfg()
  if not g.enabled then
    if next(widgets) or lastSig then G.clear() end
    return
  end
  if not bridge then
    if now - lastRun < 5 then return end
    lastRun = now
    bridge, bridgeAddr = findBridge()
    if not bridge then return end
    log.info("ОЧКИ", "мост найден: " .. U.shortAddr(bridgeAddr))
  end
  if now - lastRun < (g.interval or 0.5) then return end
  lastRun = now

  local ok, scene = pcall(build)
  if not ok then G.lastErr = "build: " .. tostring(scene); return end

  local changed
  if mode == "retained" then
    local ok2, res = pcall(applyRetained, scene)
    if ok2 then
      changed = res
    else
      -- мост не умеет обновлять виджеты — переходим на перерисовку
      G.lastErr = tostring(res)
      log.warn("ОЧКИ", "режим обновления недоступен, включаю перерисовку")
      mode = "simple"
      widgets = {}
      pcall(bridge.clear)
      return
    end
  else
    local ok2, res = pcall(applySimple, scene)
    if not ok2 then G.lastErr = tostring(res); return end
    changed = res
  end
  if changed or now - lastSync > 30 then
    lastSync = now
    if bridge.sync then
      local okS, err = pcall(bridge.sync)
      if not okS then G.lastErr = "sync: " .. tostring(err) end
    end
  end
end

-- принудительно пересоздать все виджеты
function G.rebuild()
  G.clear()
  lastRun = 0
  mode = "retained"
end

return G
