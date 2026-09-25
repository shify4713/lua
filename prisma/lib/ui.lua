-- PRISMA · ui: тема, виджеты, области нажатия, прокрутка, уведомления
-- Палитра подобрана под 256-цветный режим OpenComputers (никаких «грязных» оттенков).
local P = ...
local U, F = P.util, P.fb

local UI = {}

UI.THEMES = {
  cyan   = { acc = 0x00DBFF, accbg = 0x002440, accdim = 0x006D80 },
  green  = { acc = 0x33FF80, accbg = 0x002400, accdim = 0x009240 },
  amber  = { acc = 0xFFB600, accbg = 0x332400, accdim = 0x996D00 },
  violet = { acc = 0x996DFF, accbg = 0x330040, accdim = 0x664980 },
}
UI.THEME_ORDER = { "cyan", "green", "amber", "violet" }

local C = {
  bg = 0x0F0F0F, panel = 0x1E1E1E, raised = 0x2D2D2D, line = 0x3C3C3C,
  dim = 0x787878, text = 0xD2D2D2, bright = 0xF0F0F0, input = 0x000000,
  ok = 0x00FF80, okbg = 0x002400, warn = 0xFFB600, warnbg = 0x332400,
  bad = 0xFF2400, badbg = 0x330000,
  acc = 0x00DBFF, accbg = 0x002440, accdim = 0x006D80,
}
UI.C = C

function UI.setTheme(name)
  local t = UI.THEMES[name] or UI.THEMES.cyan
  C.acc, C.accbg, C.accdim = t.acc, t.accbg, t.accdim
end

-- ───────── области нажатия ─────────
local hits, wheels, hitBase = {}, {}, 0
UI.flash = nil
UI.scroll = {}

function UI.begin()
  hits, wheels, hitBase = {}, {}, 0
end

-- всё, что зарегистрировано до этого вызова, перестаёт реагировать (для модальных окон)
function UI.layer() hitBase = #hits end

function UI.hitbox(x, y, w, h, fn, arg)
  hits[#hits + 1] = { x = x, y = y, w = w, h = h, fn = fn, arg = arg }
end

function UI.hitAt(x, y)
  for i = #hits, hitBase + 1, -1 do
    local h = hits[i]
    if x >= h.x and x < h.x + h.w and y >= h.y and y < h.y + h.h then return h end
  end
end

function UI.click(x, y, button)
  local h = UI.hitAt(x, y)
  if not h then return false end
  UI.flash = { x = h.x, y = h.y, t = U.now() + 0.15 }
  if h.fn then h.fn(h.arg, x, y, button) end
  return true
end

-- ───────── тосты ─────────
local toasts = {}
function UI.toast(msg, kind, dur)
  toasts[#toasts + 1] = { msg = tostring(msg), kind = kind or "info", t = U.now() + (dur or 4) }
  while #toasts > 4 do table.remove(toasts, 1) end
  if P.state then P.state.dirty = true end
end

-- убирает устаревшее; true — нужна перерисовка
function UI.tick(now)
  local changed = false
  if UI.flash and now >= UI.flash.t then UI.flash = nil; changed = true end
  for i = #toasts, 1, -1 do
    if now >= toasts[i].t then table.remove(toasts, i); changed = true end
  end
  return changed
end

function UI.drawToasts(W, H)
  local y = H - 1
  for i = #toasts, 1, -1 do
    local t = toasts[i]
    local fg, bg = C.acc, C.accbg
    if t.kind == "ok" then fg, bg = C.ok, C.okbg
    elseif t.kind == "warn" then fg, bg = C.warn, C.warnbg
    elseif t.kind == "bad" then fg, bg = C.bad, C.badbg end
    local s = " " .. U.trunc(t.msg, 70) .. " "
    local w = U.ulen(s)
    F.rect(W - w - 1, y, w, 1, bg)
    F.text(W - w - 1, y, s, fg, bg)
    y = y - 1
  end
end

-- ───────── текст ─────────
function UI.text(x, y, s, fg, bg) F.text(x, y, s, fg or C.text, bg) end

function UI.textR(x, y, w, s, fg, bg)
  s = U.trunc(s, w)
  F.text(x + w - U.ulen(s), y, s, fg or C.text, bg)
end

function UI.textC(x, y, w, s, fg, bg)
  s = U.trunc(s, w)
  F.text(x + math.floor((w - U.ulen(s)) / 2), y, s, fg or C.text, bg)
end

function UI.hline(x, y, w, color, ch)
  F.text(x, y, string.rep(ch or "─", w), color or C.line)
end

-- «ключ ......... значение»
function UI.kv(x, y, w, key, value, vcolor, kcolor)
  value = U.trunc(tostring(value), math.max(3, w - 4))
  local vl = U.ulen(value)
  F.text(x, y, U.trunc(key, math.max(1, w - vl - 1)), kcolor or C.dim)
  F.text(x + w - vl, y, value, vcolor or C.text)
end

function UI.badge(x, y, s, fg, bg)
  s = " " .. s .. " "
  F.rect(x, y, U.ulen(s), 1, bg)
  F.text(x, y, s, fg, bg)
  return U.ulen(s)
end

-- ───────── панель ─────────
function UI.panel(x, y, w, h, title, o)
  o = o or {}
  local bg = o.bg or C.panel
  local bc = o.border or C.line
  F.rect(x, y, w, h, bg)
  F.text(x, y, "╭" .. string.rep("─", w - 2) .. "╮", bc, bg)
  F.text(x, y + h - 1, "╰" .. string.rep("─", w - 2) .. "╯", bc, bg)
  for i = 1, h - 2 do
    F.text(x, y + i, "│", bc, bg)
    F.text(x + w - 1, y + i, "│", bc, bg)
  end
  if title and title ~= "" then
    local t = " " .. U.trunc(title, w - 8) .. " "
    F.text(x + 2, y, t, o.tcolor or C.acc, bg)
  end
  if o.right then
    local r = " " .. U.trunc(o.right, w - 8) .. " "
    F.text(x + w - 2 - U.ulen(r), y, r, o.rcolor or C.dim, bg)
  end
end

-- ───────── кнопки ─────────
local STYLES = {
  normal  = function() return C.raised, C.text end,
  primary = function() return C.accbg, C.acc end,
  ok      = function() return C.okbg, C.ok end,
  warn    = function() return C.warnbg, C.warn end,
  danger  = function() return C.badbg, C.bad end,
  ghost   = function() return C.panel, C.text end,
}

-- o: style, disabled, active, arg
function UI.button(x, y, w, label, fn, o)
  o = o or {}
  local bg, fg = (STYLES[o.style or "normal"] or STYLES.normal)()
  if o.active then bg, fg = C.accbg, C.acc end
  if o.disabled then bg, fg = C.panel, C.dim end
  local pressed = UI.flash and UI.flash.x == x and UI.flash.y == y and not o.disabled
  if pressed then bg, fg = fg, C.bg end
  local h = o.h or 1
  F.rect(x, y, w, h, bg)
  local s = U.trunc(label, w - (w > 3 and 1 or 0))
  F.text(x + math.floor((w - U.ulen(s)) / 2), y + math.floor(h / 2), s, fg, bg)
  if not o.disabled and fn then UI.hitbox(x, y, w, h, fn, o.arg) end
end

-- переключатель: подпись слева, «ВКЛ/ВЫКЛ» справа
function UI.toggle(x, y, w, label, on, fn, arg)
  local bg = on and C.okbg or C.raised
  local fg = on and C.ok or C.dim
  local pw = 7
  F.text(x, y, U.trunc(label, w - pw - 1), C.text)
  F.rect(x + w - pw, y, pw, 1, bg)
  F.text(x + w - pw, y, on and " ● ВКЛ " or " ○ ВЫКЛ", fg, bg)
  UI.hitbox(x, y, w, 1, fn, arg)
end

-- степпер: подпись слева, справа [−][значение][+]; клик по значению — ввод
function UI.stepper(x, y, w, label, value, onDec, onInc, onEdit, o)
  o = o or {}
  local vw = o.vw or 10
  local total = vw + 8
  local cx = x + w - total
  F.text(x, y, U.trunc(label, math.max(1, cx - x - 1)), o.lcolor or C.text)
  UI.button(cx, y, 3, "−", onDec)
  F.rect(cx + 4, y, vw, 1, C.input)
  UI.textC(cx + 4, y, vw, tostring(value), o.vcolor or C.acc, C.input)
  if onEdit then UI.hitbox(cx + 4, y, vw, 1, onEdit) end
  UI.button(cx + 5 + vw, y, 3, "+", onInc)
end

-- выбор из списка: подпись слева, справа [‹][значение][›]
function UI.cycler(x, y, w, label, value, onPrev, onNext, o)
  o = o or {}
  local vw = o.vw or 10
  local cx = x + w - (vw + 8)
  F.text(x, y, U.trunc(label, math.max(1, cx - x - 1)), C.text)
  UI.button(cx, y, 3, "‹", onPrev)
  F.rect(cx + 4, y, vw, 1, C.input)
  UI.textC(cx + 4, y, vw, tostring(value), o.vcolor or C.acc, C.input)
  UI.button(cx + 5 + vw, y, 3, "›", onNext)
end

-- ───────── индикаторы ─────────
local PART = { "▏", "▎", "▍", "▌", "▋", "▊", "▉" }

-- o: track, label, lcolor, marks = { {frac, color}, ... }
function UI.bar(x, y, w, frac, color, o)
  o = o or {}
  frac = U.clamp(frac or 0, 0, 1)
  local track = o.track or C.raised
  F.rect(x, y, w, 1, track)
  local total = frac * w
  local full = math.floor(total)
  if full > 0 then F.rect(x, y, full, 1, color) end
  local rem = total - full
  if full < w and rem >= 0.125 then
    local idx = math.floor(rem * 8)
    if idx >= 1 then F.text(x + full, y, PART[math.min(idx, 7)], color, track) end
  end
  if o.marks then
    for _, m in ipairs(o.marks) do
      local mx = x + math.min(w - 1, math.floor(U.clamp(m[1], 0, 1) * w))
      F.text(mx, y, "│", m[2] or C.bright)
    end
  end
  if o.label then
    local s = U.trunc(o.label, w)
    local lx = x + math.floor((w - U.ulen(s)) / 2)
    local filled = math.floor(total + 0.5)
    local i = 0
    for ch in s:gmatch("[\1-\127\194-\244][\128-\191]*") do
      local cx = lx + i
      local onFill = (cx - x) < filled
      F.text(cx, y, ch, onFill and (o.lfill or C.bg) or (o.lcolor or C.bright))
      i = i + 1
    end
  end
end

local SP = { "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█" }

function UI.spark(x, y, w, vals, vmin, vmax, color)
  local n = #vals
  if n == 0 then return end
  vmin = vmin or math.huge
  vmax = vmax or -math.huge
  if vmin == math.huge or vmax == -math.huge then
    vmin, vmax = math.huge, -math.huge
    for i = 1, n do
      if vals[i] < vmin then vmin = vals[i] end
      if vals[i] > vmax then vmax = vals[i] end
    end
  end
  local span = vmax - vmin
  if span <= 0 then span = 1 end
  local start = math.max(1, n - w + 1)
  local px = x + w - (n - start + 1)
  for i = start, n do
    local f = U.clamp((vals[i] - vmin) / span, 0, 1)
    F.text(px, y, SP[1 + math.floor(f * 7)], color or C.acc)
    px = px + 1
  end
end

-- многострочный график (столбцы), h строк
function UI.graph(x, y, w, h, vals, vmin, vmax, color, track)
  local n = #vals
  F.rect(x, y, w, h, track or C.panel)
  if n == 0 then return end
  if not vmin or not vmax then
    vmin, vmax = math.huge, -math.huge
    for i = 1, n do
      if vals[i] < vmin then vmin = vals[i] end
      if vals[i] > vmax then vmax = vals[i] end
    end
    local pad = (vmax - vmin) * 0.15
    if pad <= 0 then pad = math.abs(vmax) * 0.01 + 1 end
    vmin, vmax = vmin - pad, vmax + pad
  end
  local span = vmax - vmin
  if span <= 0 then span = 1 end
  local start = math.max(1, n - w + 1)
  local px = x + w - (n - start + 1)
  for i = start, n do
    local f = U.clamp((vals[i] - vmin) / span, 0, 1)
    local eighths = math.floor(f * h * 8 + 0.5)
    for r = 1, h do
      local cell = U.clamp(eighths - (r - 1) * 8, 0, 8)
      if cell > 0 then
        F.text(px, y + h - r, cell == 8 and "█" or SP[cell], color or C.acc)
      end
    end
    px = px + 1
  end
end

-- ───────── вкладки ─────────
-- tabs: { {id,label,badge}, ... } ; возвращает конец занятого места
function UI.tabs(y, tabs, active, onPick, W)
  F.rect(1, y, W, 1, C.panel)
  local x = 2
  for _, t in ipairs(tabs) do
    local label = " " .. t.label .. " "
    local w = U.ulen(label)
    local on = (t.id == active)
    local bg = on and C.accbg or C.panel
    local fg = on and C.acc or C.dim
    F.rect(x, y, w, 1, bg)
    F.text(x, y, label, fg, bg)
    if on then F.text(x, y, "▌", C.acc, bg) end
    local bw = 0
    if t.badge and t.badge > 0 then
      local b = " " .. t.badge .. " "
      bw = U.ulen(b)
      F.text(x + w, y, b, C.bg, t.badgeColor or C.bad)
    end
    UI.hitbox(x, y, w + bw, 1, onPick, t.id)
    x = x + w + bw + 1
  end
  return x
end

-- ───────── прокрутка ─────────
-- Вызывать при отрисовке списка. Возвращает first, last, contentW.
function UI.scrollArea(id, x, y, w, h, total, stick)
  local s = UI.scroll[id]
  if not s then s = { off = 0 }; UI.scroll[id] = s end
  local maxOff = math.max(0, total - h)
  if stick and not s.touched then s.off = maxOff end
  if s.off > maxOff then s.off = maxOff end
  if s.off < 0 then s.off = 0 end
  s.h, s.total = h, total
  wheels[#wheels + 1] = { x = x, y = y, w = w, h = h, id = id }
  local cw = w
  if total > h then
    cw = w - 1
    local bx = x + w - 1
    F.rect(bx, y, 1, h, C.raised)
    local thumbH = math.max(1, math.floor(h * h / total + 0.5))
    local thumbY = y + math.floor((h - thumbH) * (maxOff > 0 and s.off / maxOff or 0) + 0.5)
    F.rect(bx, thumbY, 1, thumbH, C.accdim, "█", C.accdim)
    F.text(bx, y, "▲", C.acc, C.raised)
    F.text(bx, y + h - 1, "▼", C.acc, C.raised)
    UI.hitbox(bx, y, 1, h, function(_, _, my)
      if my == y then UI.scrollBy(id, -1)
      elseif my == y + h - 1 then UI.scrollBy(id, 1)
      elseif my < thumbY then UI.scrollBy(id, -h + 1)
      elseif my >= thumbY + thumbH then UI.scrollBy(id, h - 1) end
    end)
  end
  return s.off + 1, math.min(total, s.off + h), cw
end

function UI.scrollBy(id, d)
  local s = UI.scroll[id]
  if not s then return end
  local maxOff = math.max(0, (s.total or 0) - (s.h or 0))
  s.off = U.clamp(s.off + d, 0, maxOff)
  s.touched = s.off < maxOff
  if P.state then P.state.dirty = true end
end

function UI.scrollTo(id, index)
  local s = UI.scroll[id]
  if not s then return end
  if index < s.off + 1 then s.off = index - 1
  elseif index > s.off + s.h then s.off = index - s.h end
  s.off = math.max(0, s.off)
end

function UI.wheel(x, y, dir)
  for i = #wheels, 1, -1 do
    local a = wheels[i]
    if x >= a.x and x < a.x + a.w and y >= a.y and y < a.y + a.h then
      UI.scrollBy(a.id, -dir * 3)
      return true
    end
  end
  return false
end

-- ───────── цвета по значениям ─────────
function UI.heat(t, force, safe, crit)
  if t >= crit then return C.bad end
  if t >= safe then return C.warn end
  if t >= force then return C.ok end
  return C.acc
end

function UI.level(frac, warnBelow, badBelow)
  if frac <= badBelow then return C.bad end
  if frac <= warnBelow then return C.warn end
  return C.ok
end

return UI
