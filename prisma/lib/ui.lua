-- PRISMA CORE UI v2
-- Anti-flicker, partial redraw, tabs, modern cyber style

local component = require("component")
local unicode = require("unicode")
local gpu = component.gpu

local M = {}

M.C = {
  BG        = 0x0B0F14,
  PANEL     = 0x12181F,
  FRAME     = 0x1E3A4C,
  FRAME2    = 0x0F2430,
  TEXT      = 0xE8F4F8,
  TEXT_DIM  = 0x5A7A8A,
  ACCENT    = 0x00D4FF,
  ACCENT2   = 0x0099BB,
  OK        = 0x00E676,
  WARN      = 0xFFB300,
  ALERT     = 0xFF1744,
  BTN       = 0x152028,
  BTN_HOVER = 0x1E3040,
  BTN_ON    = 0x004D40,
  BTN_OFF   = 0x1A222A,
  TAB       = 0x152028,
  TAB_ACT   = 0x003D5C,
  SELECT    = 0x0A2A3A,
  BAR_BG    = 0x1A2530,
  BAR_FG    = 0x00D4FF,
  INPUT_BG  = 0x0E1620,
}

local buttons = {}
local w, h = 160, 50

function M.init()
  local mw, mh = gpu.maxResolution()
  w = math.min(160, mw)
  h = math.min(50, mh)
  gpu.setResolution(w, h)
  return w, h
end

function M.getSize() return w, h end

function M.clear(bg)
  gpu.setBackground(bg or M.C.BG)
  gpu.fill(1, 1, w, h, " ")
end

function M.fill(x, y, ww, hh, bg)
  gpu.setBackground(bg or M.C.BG)
  gpu.fill(x, y, ww, hh, " ")
end

function M.text(x, y, s, fg, bg)
  if fg then gpu.setForeground(fg) end
  gpu.setBackground(bg or M.C.BG)
  gpu.set(x, y, tostring(s))
end

function M.frame(x, y, ww, hh, title, accent)
  accent = accent or M.C.FRAME
  gpu.setForeground(accent)
  gpu.setBackground(M.C.BG)
  gpu.set(x, y, "┌" .. string.rep("─", ww - 2) .. "┐")
  for i = 1, hh - 2 do
    gpu.set(x, y + i, "│")
    gpu.set(x + ww - 1, y + i, "│")
  end
  gpu.set(x, y + hh - 1, "└" .. string.rep("─", ww - 2) .. "┘")
  if title then
    M.text(x + 2, y, "┤ " .. title .. " ├", M.C.ACCENT, M.C.BG)
  end
end

function M.panel(x, y, ww, hh, bg)
  gpu.setBackground(bg or M.C.PANEL)
  gpu.fill(x, y, ww, hh, " ")
end

function M.progress(x, y, ww, pct, fg, bg)
  pct = math.max(0, math.min(1, pct or 0))
  gpu.setBackground(bg or M.C.BAR_BG)
  gpu.fill(x, y, ww, 1, " ")
  local f = math.floor(ww * pct)
  if f > 0 then
    gpu.setBackground(fg or M.C.BAR_FG)
    gpu.fill(x, y, f, 1, " ")
  end
end

function M.button(id, x, y, ww, hh, label, bg, fg)
  buttons[id] = {x = x, y = y, w = ww, h = hh}
  gpu.setBackground(bg or M.C.BTN)
  gpu.setForeground(fg or M.C.TEXT)
  gpu.fill(x, y, ww, hh, " ")
  local lx = x + math.floor((ww - unicode.wlen(label)) / 2)
  local ly = y + math.floor(hh / 2)
  gpu.set(lx, ly, label)
end

function M.toggle(id, x, y, ww, hh, label, state)
  local bg = state and M.C.BTN_ON or M.C.BTN_OFF
  local fg = state and M.C.OK or M.C.TEXT_DIM
  local txt = (state and "[●] " or "[○] ") .. label
  M.button(id, x, y, ww, hh, txt, bg, fg)
end

function M.tab(id, x, y, ww, label, active)
  local bg = active and M.C.TAB_ACT or M.C.TAB
  local fg = active and M.C.ACCENT or M.C.TEXT_DIM
  M.button(id, x, y, ww, 1, label, bg, fg)
end

function M.hit(x, y)
  for id, b in pairs(buttons) do
    if x >= b.x and x < b.x + b.w and y >= b.y and y < b.y + b.h then
      return id
    end
  end
  return nil
end

function M.clearButtons()
  buttons = {}
end

function M.header(title, right)
  gpu.setBackground(M.C.PANEL)
  gpu.fill(1, 1, w, 1, " ")
  M.text(2, 1, title or "PRISMA CORE", M.C.ACCENT, M.C.PANEL)
  if right then
    M.text(w - unicode.wlen(right) - 1, 1, right, M.C.OK, M.C.PANEL)
  end
end

function M.drawTabs(tabs, active)
  local x = 2
  for _, t in ipairs(tabs) do
    local ww = unicode.wlen(t.label) + 4
    M.tab(t.id, x, 2, ww, t.label, t.id == active)
    x = x + ww + 1
  end
  gpu.setForeground(M.C.FRAME)
  gpu.setBackground(M.C.BG)
  gpu.set(1, 3, string.rep("─", w))
end

-- Простой модальный ввод
function M.input(title, prompt, default)
  local mw, mh = 50, 7
  local mx = math.floor((w - mw) / 2)
  local my = math.floor((h - mh) / 2)
  M.panel(mx, my, mw, mh, M.C.PANEL)
  M.frame(mx, my, mw, mh, title)
  M.text(mx + 2, my + 2, prompt or "> ", M.C.TEXT_DIM, M.C.PANEL)
  local inputX = mx + 2 + unicode.wlen(prompt or "> ")
  local maxLen = mw - (inputX - mx) - 3
  local str = default or ""
  local function redrawInput()
    gpu.setBackground(M.C.INPUT_BG)
    gpu.fill(inputX, my + 2, maxLen, 1, " ")
    gpu.setForeground(M.C.ACCENT)
    gpu.set(inputX, my + 2, unicode.sub(str .. "_", 1, maxLen))
  end
  redrawInput()
  M.button("inp_ok", mx + 6, my + 4, 14, 1, "[ OK ]", M.C.BTN_ON, M.C.OK)
  M.button("inp_cancel", mx + 28, my + 4, 14, 1, "[CANCEL]", 0x3A1515, M.C.ALERT)

  while true do
    local ev, _, a1, a2, a3 = event.pull(0.1)
    if ev == "key_down" then
      if a2 == 28 then return str end          -- Enter
      if a2 == 14 then                         -- Backspace
        if unicode.wlen(str) > 0 then str = unicode.sub(str, 1, -2) end
        redrawInput()
      elseif a2 == 1 then return nil           -- Esc
      elseif a1 and a1 >= 32 then
        str = str .. unicode.char(a1)
        redrawInput()
      end
    elseif ev == "touch" then
      local id = M.hit(a1, a2)
      if id == "inp_ok" then return str end
      if id == "inp_cancel" then return nil end
    end
  end
end

return M
