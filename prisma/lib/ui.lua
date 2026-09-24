-- PRISMA CORE UI Library
-- Тёмный cyberpunk / tech стиль, partial redraw, высокая отзывчивость

local component = require("component")
local unicode = require("unicode")
local gpu = component.gpu

local M = {}

-- Цветовая палитра (Cyber / Prisma)
M.C = {
  BG        = 0x0A0E14,
  PANEL     = 0x111820,
  FRAME     = 0x1A4059,
  FRAME_DIM = 0x0C1F2E,
  TEXT      = 0xE0F7FA,
  TEXT_DIM  = 0x4A7B9C,
  ACCENT    = 0x00E5FF,
  OK        = 0x00FF9D,
  WARN      = 0xFFAA00,
  ALERT     = 0xFF2A2A,
  BTN       = 0x0B1B26,
  BTN_ON    = 0x004D40,
  BTN_OFF   = 0x1A1A24,
  SELECT    = 0x003D5C,
  BAR_BG    = 0x1A2530,
  BAR_FG    = 0x00E5FF,
}

local buttons = {}
local lastBg, lastFg = nil, nil

function M.setRes(maxW, maxH)
  local mw, mh = gpu.maxResolution()
  local w = math.min(maxW or 160, mw)
  local h = math.min(maxH or 50, mh)
  gpu.setResolution(w, h)
  return w, h
end

function M.clear(bg)
  bg = bg or M.C.BG
  gpu.setBackground(bg)
  local w, h = gpu.getResolution()
  gpu.fill(1, 1, w, h, " ")
end

function M.text(x, y, s, fg, bg)
  if fg then gpu.setForeground(fg) end
  if bg then gpu.setBackground(bg) else gpu.setBackground(M.C.BG) end
  gpu.set(x, y, s)
end

function M.fill(x, y, w, h, bg)
  gpu.setBackground(bg or M.C.BG)
  gpu.fill(x, y, w, h, " ")
end

function M.frame(x, y, w, h, title, accent)
  accent = accent or M.C.FRAME
  gpu.setForeground(accent)
  gpu.setBackground(M.C.BG)
  gpu.set(x, y, "┌" .. string.rep("─", w - 2) .. "┐")
  for i = 1, h - 2 do
    gpu.set(x, y + i, "│")
    gpu.set(x + w - 1, y + i, "│")
  end
  gpu.set(x, y + h - 1, "└" .. string.rep("─", w - 2) .. "┘")
  if title then
    M.text(x + 2, y, "┤ " .. title .. " ├", M.C.ACCENT, M.C.BG)
  end
end

function M.roundRect(x, y, w, h, border, fill)
  border = border or M.C.FRAME
  fill = fill or M.C.PANEL
  gpu.setBackground(fill)
  gpu.fill(x, y, w, h, " ")
  gpu.setForeground(border)
  gpu.set(x, y, "╭" .. string.rep("─", w - 2) .. "╮")
  gpu.set(x, y + h - 1, "╰" .. string.rep("─", w - 2) .. "╯")
  for i = y + 1, y + h - 2 do
    gpu.set(x, i, "│")
    gpu.set(x + w - 1, i, "│")
  end
end

function M.progressBar(x, y, w, percent, fg, bg)
  fg = fg or M.C.BAR_FG
  bg = bg or M.C.BAR_BG
  percent = math.max(0, math.min(1, percent or 0))
  gpu.setBackground(bg)
  gpu.fill(x, y, w, 1, " ")
  local fill = math.floor(w * percent)
  if fill > 0 then
    gpu.setBackground(fg)
    gpu.fill(x, y, fill, 1, " ")
  end
  gpu.setBackground(M.C.BG)
end

function M.button(id, x, y, w, h, label, bg, fg, active)
  buttons[id] = {x = x, y = y, w = w, h = h}
  local bcol = active and (bg or M.C.BTN_ON) or (bg or M.C.BTN_OFF)
  local fcol = fg or M.C.TEXT
  gpu.setBackground(bcol)
  gpu.setForeground(fcol)
  gpu.fill(x, y, w, h, " ")
  local lx = x + math.floor((w - unicode.wlen(label)) / 2)
  local ly = y + math.floor(h / 2)
  gpu.set(lx, ly, label)
  gpu.setBackground(M.C.BG)
end

function M.toggle(id, x, y, w, h, label, state)
  local bg = state and M.C.BTN_ON or M.C.BTN_OFF
  local fg = state and M.C.OK or M.C.TEXT_DIM
  local txt = (state and "[●] " or "[○] ") .. label
  M.button(id, x, y, w, h, txt, bg, fg, state)
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

function M.drawHeader(w, title, status)
  gpu.setBackground(M.C.PANEL)
  gpu.fill(1, 1, w, 2, " ")
  M.text(2, 1, title or "PRISMA CORE", M.C.ACCENT, M.C.PANEL)
  if status then
    M.text(w - unicode.wlen(status) - 1, 1, status, M.C.OK, M.C.PANEL)
  end
  gpu.setForeground(M.C.FRAME)
  gpu.set(1, 2, string.rep("─", w))
end

return M
