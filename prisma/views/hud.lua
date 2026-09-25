-- PRISMA · ОЧКИ: настройка AR-HUD с наглядным предпросмотром
local P = ...
local U, F, UI, V = P.util, P.fb, P.ui, P.vc
local C = UI.C

local H = { id = "hud", title = "ОЧКИ" }

local ANCHORS = { "TL", "TR", "BL", "BR" }
local ANCHOR_TXT = { TL = "↖ лево-верх", TR = "↗ право-верх", BL = "↙ лево-низ", BR = "↘ право-низ" }

local function num(x, y, w, label, key, min, max, step, o)
  o = o or {}
  local g = P.cfg.glasses
  local fmt = o.fmt or function(v) return tostring(v) end
  local function set(v)
    v = U.clamp(v, min, max)
    if o.dec then v = U.round(v, o.dec) end
    g[key] = v
    P.config.markDirty()
  end
  UI.stepper(x, y, w, label, fmt(g[key]),
    function() set(g[key] - step) end,
    function() set(g[key] + step) end,
    function()
      P.modal.input(label, { prompt = label, numeric = true, value = g[key], min = min, max = max, onOk = function(v) set(v) end })
    end, { vw = 8 })
end

local function drawSettings(x, y, w, h)
  local G = P.mods.glasses
  local g = P.cfg.glasses
  UI.panel(x, y, w, h, "НАСТРОЙКИ HUD")
  local ix, iw = x + 2, w - 4
  local row = y + 1
  if G.available() then
    UI.kv(ix, row, iw, "Мост очков", U.shortAddr(G.address()) .. "…", C.ok)
    UI.kv(ix, row + 1, iw, "Режим вывода", G.mode() == "retained" and "обновление виджетов (без мерцания)" or "полная перерисовка", G.mode() == "retained" and C.ok or C.warn)
  else
    UI.kv(ix, row, iw, "Мост очков", "не найден", C.bad)
    UI.text(ix, row + 1, "нужен openperipheral_bridge / glasses bridge", C.dim, C.panel)
  end
  if G.lastErr then UI.text(ix, row + 2, U.trunc("ошибка: " .. G.lastErr, iw), C.bad, C.panel) end
  row = row + 4
  UI.toggle(ix, row, iw, "Показывать HUD", g.enabled, function() g.enabled = not g.enabled; P.config.markDirty() end)
  row = row + 2
  UI.text(ix, row, "Пресет", C.dim, C.panel)
  local bw = math.floor((iw - 8) / 3)
  for i, p in ipairs({ { "mini", "Мини" }, { "normal", "Норма" }, { "full", "Полный" } }) do
    UI.button(ix + 8 + (i - 1) * (bw + 1), row, bw, p[2], function() G.applyPreset(p[1]) end, { active = g.preset == p[1] })
  end
  row = row + 2
  UI.cycler(ix, row, iw, "Якорь (угол экрана)", ANCHOR_TXT[g.anchor] or g.anchor,
    function() g.anchor = V.nextOf(ANCHORS, g.anchor, -1); P.config.markDirty() end,
    function() g.anchor = V.nextOf(ANCHORS, g.anchor, 1); P.config.markDirty() end, { vw = 14 })
  row = row + 1
  num(ix, row, iw, "Отступ X", "x", 0, 2000, 2); row = row + 1
  num(ix, row, iw, "Отступ Y", "y", 0, 2000, 2); row = row + 1
  num(ix, row, iw, "Ширина панели", "w", 60, 600, 5); row = row + 1
  num(ix, row, iw, "Масштаб текста", "scale", 0.3, 2, 0.05, { dec = 2, fmt = function(v) return string.format("%.2f", v) end }); row = row + 1
  num(ix, row, iw, "Прозрачность фона", "alpha", 0, 1, 0.05, { dec = 2, fmt = function(v) return string.format("%.2f", v) end }); row = row + 1
  num(ix, row, iw, "Обновление, сек", "interval", 0.2, 5, 0.1, { dec = 1, fmt = function(v) return string.format("%.1f", v) end }); row = row + 2
  UI.text(ix, row, "Секции", C.acc, C.panel); row = row + 1
  local half = math.floor(iw / 2) - 1
  local names = { { "core", "Ядро" }, { "reactors", "Реакторы" }, { "craft", "Крафт" }, { "sing", "Сингулярки" }, { "near", "Игроки" }, { "chat", "Чат" } }
  for i, n in ipairs(names) do
    local col = (i - 1) % 2
    local r = row + math.floor((i - 1) / 2)
    UI.toggle(ix + col * (half + 2), r, half, n[2], g.show[n[1]], function() g.show[n[1]] = not g.show[n[1]]; P.config.markDirty() end)
  end
  row = row + 4
  num(ix, row, iw, "Строк крафта", "maxCraft", 1, 8, 1); row = row + 1
  num(ix, row, iw, "Строк чата", "chatLines", 0, 12, 1); row = row + 1
  num(ix, row, iw, "Ширина чата, симв.", "chatWidth", 10, 80, 2); row = row + 1
  UI.toggle(ix, row, iw, "Чат снизу (иначе — сверху)", g.chatBelow ~= false, function()
    g.chatBelow = (g.chatBelow == false) and true or false
    P.config.markDirty()
  end); row = row + 2
  num(ix, row, iw, "Размер GUI: ширина", "screenW", 200, 1920, 10); row = row + 1
  num(ix, row, iw, "Размер GUI: высота", "screenH", 150, 1080, 10); row = row + 1
  if row + 1 < y + h - 1 then
    UI.button(ix, y + h - 2, 22, "Пересоздать виджеты", function() G.rebuild(); UI.toast("HUD пересоздан", "ok") end)
    UI.button(ix + 24, y + h - 2, 18, "Очистить очки", function() G.clear() end, { style = "warn" })
  end
end

local function drawPreview(x, y, w, h)
  local G = P.mods.glasses
  local g = P.cfg.glasses
  UI.panel(x, y, w, h, "ПРЕДПРОСМОТР")
  local ix, iw = x + 2, w - 4
  local pw = math.min(iw, 76)
  local ph = math.max(8, math.floor(pw * g.screenH / g.screenW / 2 + 0.5))
  if ph > h - 12 then ph = h - 12; pw = math.min(iw, math.floor(ph * 2 * g.screenW / g.screenH)) end
  local fx = ix + math.floor((iw - pw) / 2)
  local fy = y + 2
  F.rect(fx, fy, pw, ph, 0x000000)
  F.text(fx, fy, "┌" .. string.rep("─", pw - 2) .. "┐", C.line, 0x000000)
  F.text(fx, fy + ph - 1, "└" .. string.rep("─", pw - 2) .. "┘", C.line, 0x000000)
  for i = 1, ph - 2 do F.text(fx, fy + i, "│", C.line, 0x000000); F.text(fx + pw - 1, fy + i, "│", C.line, 0x000000) end
  UI.textC(fx, fy + ph - 2, pw, "экран игрока " .. g.screenW .. "×" .. g.screenH, C.dim, 0x000000)
  local ok, scene = pcall(G.build)
  local r = G.rect
  if ok and r.w > 0 then
    local rx = fx + 1 + math.floor((r.x / g.screenW) * (pw - 2))
    local ry = fy + 1 + math.floor((r.y / g.screenH) * (ph - 2))
    local rw = math.max(2, math.floor((r.w / g.screenW) * (pw - 2) + 0.5))
    local rh = math.max(1, math.floor((r.h / g.screenH) * (ph - 2) + 0.5))
    rx = U.clamp(rx, fx + 1, fx + pw - 2); ry = U.clamp(ry, fy + 1, fy + ph - 2)
    F.pushClip(fx + 1, fy + 1, pw - 2, ph - 2)
    F.rect(rx, ry, rw, rh, C.accbg)
    F.text(rx, ry, string.rep("▀", rw), C.acc)
    UI.textC(rx, ry + math.floor(rh / 2), rw, "HUD", C.acc, C.accbg)
    F.popClip()
    local area = (r.w * r.h) / (g.screenW * g.screenH)
    local by = fy + ph + 1
    UI.kv(ix, by, iw, "Размер панели", string.format("%.0f × %.0f px", r.w, r.h), C.text)
    UI.kv(ix, by + 1, iw, "Занимает экрана", U.pct(area, 1), area > 0.2 and C.warn or C.ok)
    if area > 0.2 then UI.text(ix, by + 2, "Совет: уменьшите ширину или отключите секции", C.warn, C.panel) end
  end
  UI.text(ix, y + h - 4, "Размер GUI зависит от «Размер интерфейса» в настройках", C.dim, C.panel)
  UI.text(ix, y + h - 3, "Minecraft (гуи-скейл): 480×270 при 4, 640×360 при 3.", C.dim, C.panel)
end

function H.draw(x, y, w, h)
  local cols = V.split(x, w, { 46, 54 })
  drawSettings(cols[1].x, y, cols[1].w, h)
  drawPreview(cols[2].x, y, cols[2].w, h)
end

return H
