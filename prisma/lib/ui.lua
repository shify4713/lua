-- PRISMA CORE UI v3.2 — Hard clear, no overlap
local component = require("component")
local event = require("event")
local unicode = require("unicode")
local gpu = component.gpu

local M = {}
M.C = {
  BG=0x0A0E13, PANEL=0x111820, FRAME=0x1A3545, TEXT=0xE0F0F5, DIM=0x5A7A8A,
  ACCENT=0x00D4FF, OK=0x00E676, WARN=0xFFB300, ALERT=0xFF1744,
  BTN=0x152028, BTN_ON=0x004D40, BTN_OFF=0x1A222A, TAB=0x152028, TAB_A=0x003D5C,
  INPUT=0x0C1420
}

local buttons, w, h = {}, 160, 50

function M.init()
  local mw, mh = gpu.maxResolution()
  w = math.min(160, mw)
  h = math.min(50, mh)
  gpu.setResolution(w, h)
  return w, h
end
function M.size() return w, h end

function M.clear()
  gpu.setBackground(M.C.BG)
  gpu.fill(1, 1, w, h, " ")
end

-- Полная очистка всего экрана (гарантия от наложений)
function M.clearAll()
  gpu.setBackground(M.C.BG)
  gpu.fill(1, 1, w, h, " ")
  buttons = {}
end

function M.fill(x, y, ww, hh, bg)
  gpu.setBackground(bg or M.C.BG)
  gpu.fill(x, y, ww, hh, " ")
end

function M.text(x, y, s, fg, bg)
  gpu.setForeground(fg or M.C.TEXT)
  gpu.setBackground(bg or M.C.BG)
  gpu.set(x, y, tostring(s))
end

function M.frame(x, y, ww, hh, title)
  gpu.setForeground(M.C.FRAME)
  gpu.setBackground(M.C.BG)
  gpu.set(x, y, "┌" .. string.rep("─", ww-2) .. "┐")
  for i = 1, hh-2 do
    gpu.set(x, y+i, "│")
    gpu.set(x+ww-1, y+i, "│")
  end
  gpu.set(x, y+hh-1, "└" .. string.rep("─", ww-2) .. "┘")
  if title then M.text(x+2, y, "┤ "..title.." ├", M.C.ACCENT) end
end

function M.progress(x, y, ww, pct, fg)
  pct = math.max(0, math.min(1, pct or 0))
  gpu.setBackground(0x1A2530)
  gpu.fill(x, y, ww, 1, " ")
  local f = math.floor(ww * pct)
  if f > 0 then gpu.setBackground(fg or M.C.ACCENT); gpu.fill(x, y, f, 1, " ") end
end

function M.btn(id, x, y, ww, hh, label, bg, fg)
  buttons[id] = {x=x, y=y, w=ww, h=hh}
  gpu.setBackground(bg or M.C.BTN)
  gpu.setForeground(fg or M.C.TEXT)
  gpu.fill(x, y, ww, hh, " ")
  gpu.set(x + math.floor((ww - unicode.wlen(label))/2), y + math.floor(hh/2), label)
end

function M.toggle(id, x, y, ww, label, state)
  local bg = state and M.C.BTN_ON or M.C.BTN_OFF
  local fg = state and M.C.OK or M.C.DIM
  M.btn(id, x, y, ww, 1, (state and "[●] " or "[○] ")..label, bg, fg)
end

function M.tab(id, x, y, ww, label, active)
  M.btn(id, x, y, ww, 1, label, active and M.C.TAB_A or M.C.TAB, active and M.C.ACCENT or M.C.DIM)
end

function M.hit(x, y)
  for id, b in pairs(buttons) do
    if x >= b.x and x < b.x+b.w and y >= b.y and y < b.y+b.h then return id end
  end
end

function M.clearBtns() buttons = {} end

function M.header(title, right)
  gpu.setBackground(M.C.PANEL)
  gpu.fill(1, 1, w, 1, " ")
  M.text(2, 1, title or "PRISMA CORE", M.C.ACCENT, M.C.PANEL)
  if right then M.text(w - unicode.wlen(right) - 1, 1, right, M.C.OK, M.C.PANEL) end
end

function M.drawTabs(tabs, active)
  gpu.setBackground(M.C.BG)
  gpu.fill(1, 2, w, 1, " ")
  local x = 2
  for _, t in ipairs(tabs) do
    local ww = unicode.wlen(t.label) + 2
    M.tab(t.id, x, 2, ww, t.label, t.id == active)
    x = x + ww + 1
  end
  gpu.setForeground(M.C.FRAME)
  gpu.setBackground(M.C.BG)
  gpu.set(1, 3, string.rep("─", w))
end

function M.input(title, prompt, def)
  local mw, mh = 48, 7
  local mx = math.floor((w-mw)/2)
  local my = math.floor((h-mh)/2)
  M.fill(mx, my, mw, mh, M.C.PANEL)
  M.frame(mx, my, mw, mh, title)
  M.text(mx+2, my+2, prompt or "> ", M.C.DIM, M.C.PANEL)
  local ix = mx + 2 + unicode.wlen(prompt or "> ")
  local maxl = mw - (ix-mx) - 3
  local str = def or ""
  local function ri()
    gpu.setBackground(M.C.INPUT)
    gpu.fill(ix, my+2, maxl, 1, " ")
    gpu.setForeground(M.C.ACCENT)
    gpu.set(ix, my+2, unicode.sub(str.."_", 1, maxl))
  end
  ri()
  M.btn("ok", mx+5, my+4, 14, 1, "[ OK ]", M.C.BTN_ON, M.C.OK)
  M.btn("cancel", mx+26, my+4, 14, 1, "[CANCEL]", 0x3A1515, M.C.ALERT)
  while true do
    local ev, _, a1, a2 = event.pull(0.1)
    if ev == "key_down" then
      if a2 == 28 then return str end
      if a2 == 14 then
        if unicode.wlen(str) > 0 then str = unicode.sub(str, 1, -2) end
        ri()
      elseif a2 == 1 then return nil
      elseif a1 and a1 >= 32 then str = str .. unicode.char(a1); ri() end
    elseif ev == "touch" then
      local id = M.hit(a1, a2)
      if id == "ok" then return str end
      if id == "cancel" then return nil end
    end
  end
end

return M
