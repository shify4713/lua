-- ui.lua — визуализация, кнопки, поля, табы, списки, модальные окна

local component = require("component")
local gpu = component.gpu
local unicode = require("unicode")

local ui = {}

function ui.border(x, y, w, h, color)
  gpu.setForeground(color)
  gpu.set(x, y, "╭"..string.rep("─", w-2).."╮")
  gpu.set(x, y+h-1, "╰"..string.rep("─", w-2).."╯")
  for i=1, h-2 do
    gpu.set(x, y+i, "│")
    gpu.set(x+w-1, y+i, "│")
  end
end

function ui.btn(x, y, w, h, str, colors, active, hover, pressed)
  local bg = colors.btn_bg
  if pressed then bg = 0x368ef0
  elseif active then bg = colors.btn_act
  elseif hover then bg = 0x6ec6ff end
  gpu.setBackground(bg)
  gpu.setForeground(colors.btn_fg)
  for i=0, h-1 do gpu.fill(x, y+i, w, 1, " ") end
  gpu.setForeground(colors.btn_border)
  gpu.set(x, y, "╭"..string.rep("─",w-2).."╮")
  gpu.set(x, y+h-1, "╰"..string.rep("─",w-2).."╯")
  for i=1, h-2 do gpu.set(x, y+i, "│"); gpu.set(x+w-1, y+i, "│") end
  gpu.setBackground(bg)
  gpu.setForeground(colors.btn_fg)
  gpu.set(x+math.floor((w-unicode.len(str))/2), y+math.floor(h/2), str)
end

function ui.tabBar(tabs, active, colors, x, y)
  local tx = x or 5
  local tabHit = {}
  for i, tab in ipairs(tabs) do
    local isActive = (active == i)
    local bg = isActive and colors.tab_on or colors.tab_off
    gpu.setBackground(bg)
    gpu.setForeground(colors.tab_fg)
    gpu.set(tx, y or 4, " "..tab.." ")
    tabHit[#tabHit+1] = {x1=tx, x2=tx+unicode.len(tab)+1, y=y or 4, idx=i}
    tx = tx + unicode.len(tab)+5
  end
  return tabHit
end

function ui.inputModal(WIDTH, HEIGHT, colors, prompt, value)
  local w, h = 60, 9
  local x, y = math.floor(WIDTH/2-w/2), math.floor(HEIGHT/2-h/2)
  gpu.setBackground(colors.input_bg)
  gpu.fill(x, y, w, h, " ")
  ui.border(x, y, w, h, colors.input_border)
  gpu.setForeground(colors.input_fg)
  gpu.set(x+3, y+2, prompt)
  gpu.set(x+3, y+4, value)
  gpu.set(x+3+unicode.len(value), y+4, "_")
  gpu.setBackground(colors.bg)
end

return ui