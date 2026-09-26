-- PRISMA · modal: окна поверх интерфейса (не блокируют работу программы)
-- Виды: input / confirm / menu / msg / pick (поиск + список) / form (несколько полей)
local P = ...
local U, F, UI = P.util, P.fb, P.ui
local C = UI.C

local M = {}
local stack = {}

local KEY = { esc = 1, back = 14, tab = 15, enter = 28, up = 200, down = 208, pgup = 201, pgdn = 209 }

local function dirty() if P.state then P.state.dirty = true end end

function M.active() return #stack > 0 end

function M.open(m)
  stack[#stack + 1] = m
  dirty()
  return m
end

function M.close()
  table.remove(stack)
  dirty()
end

function M.closeAll() stack = {}; dirty() end

local function frame(w, h, title)
  local W, H = F.size()
  w = math.min(w, W - 2)
  h = math.min(h, H - 2)
  local x = math.floor((W - w) / 2) + 1
  local y = math.floor((H - h) / 2) + 1
  F.rect(x + 1, y + 1, w, h, 0x000000)
  UI.panel(x, y, w, h, title, { bg = C.panel, border = C.acc, tcolor = C.bright })
  return x, y, w, h
end

-- ───────── простые окна ─────────
function M.msg(title, text, onClose)
  return M.open({ kind = "msg", title = title, text = text, onClose = onClose })
end

function M.confirm(title, text, onYes, yesLabel, danger)
  return M.open({ kind = "confirm", title = title, text = text, onYes = onYes, yes = yesLabel or "Да", danger = danger })
end

-- items: { {label, fn, style}, ... }
function M.menu(title, items, w)
  return M.open({ kind = "menu", title = title, items = items, w = w or 40 })
end

-- одиночный ввод. opts: prompt, value, numeric, min, max, int, onOk(value)
function M.input(title, opts)
  local key = "v"
  local f = { key = key, label = opts.prompt or "Значение", kind = opts.numeric and "num" or "text", min = opts.min, max = opts.max, int = opts.int, step = opts.step }
  return M.form({
    title = title, fields = { f }, values = { [key] = opts.value }, w = opts.w or 58, single = true,
    onOk = function(v) if opts.onOk then opts.onOk(v[key]) end end,
  })
end

-- ───────── поиск + список ─────────
-- spec: title, items (таблица или функция), label(item), sub(item), onPick(item), w, h, empty, extra = {{label, fn}}
function M.pick(spec)
  local m = { kind = "pick", spec = spec, query = "", sel = 1, w = spec.w or 74, h = spec.h or 32 }
  m.items = type(spec.items) == "function" and spec.items() or spec.items or {}
  m.dirtyList = true
  return M.open(m)
end

local function pickFilter(m)
  local q = U.lower(m.query)
  local out = {}
  for _, it in ipairs(m.items) do
    local key = it.key
    if not key then
      key = U.lower(m.spec.label(it))
      it.key = key
    end
    if q == "" or key:find(q, 1, true) then out[#out + 1] = it end
  end
  m.filtered = out
  m.dirtyList = false
  if m.sel > #out then m.sel = math.max(1, #out) end
end

-- ───────── форма ─────────
-- spec: title, fields, values, onOk(values), validate(values)->err, extra={{label,fn,style}}, w, note
function M.form(spec)
  local m = { kind = "form", spec = spec, vals = U.copy(spec.values or {}), bufs = {}, focus = nil, w = spec.w or 66 }
  if spec.single then
    m.focus = 1
    local f = spec.fields[1]
    m.bufs[f.key] = { text = M.raw(m.vals[f.key]), fresh = true }
  end
  return M.open(m)
end

function M.raw(v)
  if type(v) == "number" then
    if v == math.floor(v) and math.abs(v) < 1e15 then return string.format("%.0f", v) end
    return string.format("%.4g", v)
  end
  return tostring(v == nil and "" or v)
end

local function fieldClamp(f, v)
  if f.min then v = math.max(f.min, v) end
  if f.max then v = math.min(f.max, v) end
  if f.int then v = math.floor(v + 0.5) end
  return v
end

local function commit(m)
  if not m.focus then return end
  local f = m.spec.fields[m.focus]
  local b = f and m.bufs[f.key]
  if not b then return end
  if f.kind == "num" then
    local v = U.parseNum(b.text)
    if v then m.vals[f.key] = fieldClamp(f, v) end
  else
    m.vals[f.key] = b.text
  end
  m.bufs[f.key] = nil
end

local function setFocus(m, idx)
  commit(m)
  m.focus = idx
  if idx then
    local f = m.spec.fields[idx]
    if f and (f.kind == "num" or f.kind == "text") then
      m.bufs[f.key] = { text = M.raw(m.vals[f.key]), fresh = true }
    end
  end
  dirty()
end

local function adjust(m, f, dir, big)
  commit(m)
  local st = big and (f.big or (f.step or 1) * 10) or (f.step or 1)
  m.vals[f.key] = fieldClamp(f, (tonumber(m.vals[f.key]) or 0) + dir * st)
  if m.focus and m.spec.fields[m.focus] == f then setFocus(m, m.focus) end
  dirty()
end

local function cycle(m, f, dir)
  local opts = f.options
  local idx = 1
  for i, o in ipairs(opts) do if o[1] == m.vals[f.key] then idx = i end end
  idx = ((idx - 1 + dir) % #opts) + 1
  m.vals[f.key] = opts[idx][1]
  dirty()
end

local function formOk(m)
  commit(m)
  if m.spec.validate then
    local err = m.spec.validate(m.vals)
    if err then UI.toast(err, "bad"); return end
  end
  M.close()
  if m.spec.onOk then m.spec.onOk(m.vals) end
end

-- ───────── отрисовка ─────────
local function drawMsg(m)
  local lines = {}
  for l in tostring(m.text):gmatch("[^\n]+") do lines[#lines + 1] = l end
  local w = 52
  local x, y, ww, h = frame(w, #lines + 6, m.title)
  for i, l in ipairs(lines) do F.text(x + 3, y + 1 + i, U.trunc(l, ww - 6), C.text, C.panel) end
  UI.button(x + math.floor((ww - 12) / 2), y + h - 3, 12, "OK", function() M.close(); if m.onClose then m.onClose() end end, { style = "primary" })
end

local function drawConfirm(m)
  local lines = {}
  for l in tostring(m.text):gmatch("[^\n]+") do lines[#lines + 1] = l end
  local x, y, w, h = frame(54, #lines + 6, m.title)
  for i, l in ipairs(lines) do F.text(x + 3, y + 1 + i, U.trunc(l, w - 6), C.text, C.panel) end
  UI.button(x + 4, y + h - 3, 16, m.yes, function() M.close(); if m.onYes then m.onYes() end end, { style = m.danger and "danger" or "ok" })
  UI.button(x + w - 20, y + h - 3, 16, "Отмена", function() M.close() end)
end

local function drawMenu(m)
  local x, y, w, h = frame(m.w, #m.items * 2 + 5, m.title)
  for i, it in ipairs(m.items) do
    UI.button(x + 3, y + 1 + (i - 1) * 2 + 1, w - 6, it.label, function()
      M.close()
      if it.fn then it.fn() end
    end, { style = it.style or "normal" })
  end
  UI.button(x + 3, y + h - 2, w - 6, "Отмена", function() M.close() end, { style = "ghost" })
end

local function drawPick(m)
  local spec = m.spec
  if m.dirtyList or not m.filtered then pickFilter(m) end
  local x, y, w, h = frame(m.w, m.h, spec.title)
  -- поиск
  F.text(x + 3, y + 2, "Поиск:", C.dim, C.panel)
  F.rect(x + 10, y + 2, w - 14, 1, C.input)
  F.text(x + 11, y + 2, U.trunc(m.query .. "_", w - 16), C.acc, C.input)
  F.text(x + 3, y + 3, string.format("Найдено: %.0f из %.0f", #m.filtered, #m.items), C.dim, C.panel)
  local ly, lh = y + 5, h - 8
  local first, last, cw = UI.scrollArea("modal.pick", x + 2, ly, w - 4, lh, #m.filtered)
  if #m.filtered == 0 then
    F.text(x + 4, ly + 1, spec.empty or "Ничего не найдено", C.dim, C.panel)
  end
  for i = first, last do
    local it = m.filtered[i]
    local ry = ly + (i - first)
    local bg = (i == m.sel) and C.accbg or C.panel
    F.rect(x + 2, ry, cw, 1, bg)
    local sub = spec.sub and spec.sub(it) or ""
    local sl = U.ulen(sub)
    F.text(x + 3, ry, U.trunc(spec.label(it), cw - sl - 3), (i == m.sel) and C.acc or C.text, bg)
    if sl > 0 then F.text(x + 2 + cw - sl - 1, ry, sub, C.dim, bg) end
    UI.hitbox(x + 2, ry, cw, 1, function()
      M.close()
      if spec.onPick then spec.onPick(it) end
    end)
  end
  -- кнопки
  local bx = x + 3
  UI.button(bx, y + h - 2, 12, "Отмена", function() M.close() end)
  bx = bx + 14
  for _, e in ipairs(spec.extra or {}) do
    local bw = U.ulen(e.label) + 4
    UI.button(bx, y + h - 2, bw, e.label, function()
      if e.close then M.close() end
      if e.fn then e.fn(m) end
      if e.refresh then
        m.items = type(spec.items) == "function" and spec.items() or spec.items
        m.dirtyList = true
      end
    end, { style = e.style })
    bx = bx + bw + 2
  end
  UI.textR(x + 3, y + h - 2, w - 6, "↑↓ выбор · Enter · Esc", C.dim, C.panel)
end

local function drawForm(m)
  local spec = m.spec
  local fields = spec.fields
  local nrows = #fields
  local extraRow = (spec.extra and #spec.extra > 0)
  local h = nrows + 7 + (spec.note and 1 or 0) + (extraRow and 0 or 0)
  if spec.single then h = 8 end
  local x, y, w, hh = frame(m.w, h, spec.title)
  local right = x + w - 3
  for i, f in ipairs(fields) do
    local ry = y + 2 + (i - 1)
    local foc = (m.focus == i)
    local lw = spec.single and 0 or 24
    if not spec.single then
      F.text(x + 3, ry, U.trunc(f.label, lw - 1), foc and C.acc or C.text, C.panel)
    end
    local buf = m.bufs[f.key]
    if f.kind == "num" then
      local bw = spec.single and (w - 12) or 16
      local total = 3 + 1 + bw + 1 + 3 + (spec.single and 0 or 8)
      local cx = right - total + 1
      if spec.single then
        F.text(x + 3, ry, U.trunc(f.label, w - 8), C.dim, C.panel)
        ry = ry + 1
        cx = x + 3
      end
      local px = cx
      if not spec.single then
        if f.big then UI.button(px, ry, 3, "«", function() adjust(m, f, -1, true) end) end
        px = px + 4
      end
      if not spec.single then
        UI.button(px, ry, 3, "−", function() adjust(m, f, -1) end); px = px + 4
      end
      local shown
      if buf then shown = buf.text .. "_"
      else shown = (f.fmt and f.fmt(m.vals[f.key])) or M.raw(m.vals[f.key]) end
      local bbg = foc and C.accbg or C.input
      F.rect(px, ry, bw, 1, bbg)
      F.text(px + 1, ry, U.trunc(shown, bw - 2), foc and C.acc or C.bright, bbg)
      UI.hitbox(px, ry, bw, 1, function() setFocus(m, i) end)
      px = px + bw + 1
      if not spec.single then
        UI.button(px, ry, 3, "+", function() adjust(m, f, 1) end); px = px + 4
      end
      if f.big and not spec.single then
        UI.button(px, ry, 3, "»", function() adjust(m, f, 1, true) end)
      end
    elseif f.kind == "text" then
      local bw = spec.single and (w - 12) or 32
      local cx = spec.single and (x + 3) or (right - bw + 1)
      if spec.single then
        F.text(x + 3, ry, U.trunc(f.label, w - 8), C.dim, C.panel)
        ry = ry + 1
      end
      local shown = buf and (buf.text .. "_") or tostring(m.vals[f.key] or "")
      local bbg = foc and C.accbg or C.input
      F.rect(cx, ry, bw, 1, bbg)
      F.text(cx + 1, ry, U.trunc(shown, bw - 2), foc and C.acc or C.bright, bbg)
      UI.hitbox(cx, ry, bw, 1, function() setFocus(m, i) end)
    elseif f.kind == "bool" then
      UI.toggle(right - 8, ry, 9, "", m.vals[f.key], function() m.vals[f.key] = not m.vals[f.key]; dirty() end)
    elseif f.kind == "enum" then
      local label = tostring(m.vals[f.key])
      for _, o in ipairs(f.options) do if o[1] == m.vals[f.key] then label = o[2] end end
      local bw = 16
      local cx = right - (bw + 8) + 1
      UI.button(cx, ry, 3, "‹", function() cycle(m, f, -1) end)
      F.rect(cx + 4, ry, bw, 1, C.input)
      UI.textC(cx + 4, ry, bw, label, C.acc, C.input)
      UI.button(cx + 5 + bw, ry, 3, "›", function() cycle(m, f, 1) end)
    end
  end
  if spec.note and not spec.single then
    F.text(x + 3, y + h - 4, U.trunc(spec.note, w - 6), C.dim, C.panel)
  end
  -- кнопки
  local by = y + h - 2
  UI.button(x + 3, by, 14, spec.okLabel or "Сохранить", function() formOk(m) end, { style = "ok" })
  UI.button(x + 19, by, 12, "Отмена", function() M.close() end)
  local ex = x + 33
  for _, e in ipairs(spec.extra or {}) do
    local bw = U.ulen(e.label) + 4
    UI.button(ex, by, bw, e.label, function() M.close(); if e.fn then e.fn(m.vals) end end, { style = e.style })
    ex = ex + bw + 1
  end
end

function M.draw()
  for _, m in ipairs(stack) do
    UI.layer()
    if m.kind == "msg" then drawMsg(m)
    elseif m.kind == "confirm" then drawConfirm(m)
    elseif m.kind == "menu" then drawMenu(m)
    elseif m.kind == "pick" then drawPick(m)
    elseif m.kind == "form" then drawForm(m) end
  end
end

-- ───────── клавиатура ─────────
local NUMCH = "0123456789.,-+eEkKmMgGtTкКмМгГтТ "

local function typeInto(b, ch, numeric)
  if numeric and not NUMCH:find(ch, 1, true) then return end
  if b.fresh then b.text = ""; b.fresh = false end
  b.text = b.text .. ch
end

function M.key(char, code)
  local m = stack[#stack]
  if not m then return false end
  if code == KEY.esc then M.close(); return true end

  if m.kind == "msg" then
    if code == KEY.enter then M.close(); if m.onClose then m.onClose() end end
  elseif m.kind == "confirm" then
    if code == KEY.enter then M.close(); if m.onYes then m.onYes() end end
  elseif m.kind == "pick" then
    if m.dirtyList or not m.filtered then pickFilter(m) end
    if code == KEY.enter then
      local it = m.filtered[m.sel]
      if it then M.close(); if m.spec.onPick then m.spec.onPick(it) end end
    elseif code == KEY.up then m.sel = math.max(1, m.sel - 1); UI.scrollTo("modal.pick", m.sel)
    elseif code == KEY.down then m.sel = math.min(#m.filtered, m.sel + 1); UI.scrollTo("modal.pick", m.sel)
    elseif code == KEY.pgup then m.sel = math.max(1, m.sel - 10); UI.scrollTo("modal.pick", m.sel)
    elseif code == KEY.pgdn then m.sel = math.min(#m.filtered, m.sel + 10); UI.scrollTo("modal.pick", m.sel)
    elseif code == KEY.back then
      if U.ulen(m.query) > 0 then m.query = U.usub(m.query, 1, -2); m.dirtyList = true; m.sel = 1; UI.scrollTo("modal.pick", 1) end
    elseif char and char >= 32 and char ~= 127 then
      m.query = m.query .. require("unicode").char(char)
      m.dirtyList = true
      m.sel = 1
      UI.scrollTo("modal.pick", 1)
    end
  elseif m.kind == "form" then
    local fields = m.spec.fields
    local f = m.focus and fields[m.focus]
    if code == KEY.enter then
      if m.spec.single or m.focus == #fields or not m.focus then formOk(m)
      else setFocus(m, m.focus + 1) end
    elseif code == KEY.tab or code == KEY.down then
      setFocus(m, ((m.focus or 0) % #fields) + 1)
    elseif code == KEY.up then
      setFocus(m, ((m.focus or 2) - 2) % #fields + 1)
    elseif f and (f.kind == "num" or f.kind == "text") then
      local b = m.bufs[f.key]
      if b then
        if code == KEY.back then
          b.fresh = false
          if U.ulen(b.text) > 0 then b.text = U.usub(b.text, 1, -2) end
        elseif char and char >= 32 and char ~= 127 then
          typeInto(b, require("unicode").char(char), f.kind == "num")
        end
      end
    end
  end
  dirty()
  return true
end

function M.paste(text)
  local m = stack[#stack]
  if not m then return false end
  if m.kind == "pick" then
    m.query = m.query .. text:gsub("[\r\n]", "")
    m.dirtyList = true
  elseif m.kind == "form" and m.focus then
    local f = m.spec.fields[m.focus]
    local b = f and m.bufs[f.key]
    if b then typeInto(b, (text:gsub("[\r\n]", "")), f.kind == "num") end
  end
  dirty()
  return true
end

return M
