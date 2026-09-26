-- PRISMA · fb: буфер кадра с дифф-выводом (без мерцания)
-- Рисуем в память, на экран отправляем только изменившиеся участки.
local P = ...

local F = {}
local gpu
local W, H = 0, 0
local ch, fg, bg = {}, {}, {}        -- задний буфер (что хотим показать)
local pch, pfg, pbg = {}, {}, {}     -- передний буфер (что уже на экране)
local rowDirty = {}
local cx1, cy1, cx2, cy2 = 1, 1, 1, 1
local clips = {}
local DEF_FG, DEF_BG = 0xD2D2D2, 0x0F0F0F
local GAP = 2                        -- склеиваем участки, если между ними <= GAP одинаковых клеток
F.calls = 0

function F.init(g, w, h)
  gpu = g
  W, H = w, h
  ch, fg, bg, pch, pfg, pbg, rowDirty = {}, {}, {}, {}, {}, {}, {}
  for i = 1, W * H do
    ch[i] = " "; fg[i] = DEF_FG; bg[i] = DEF_BG
    pch[i] = ""; pfg[i] = -1; pbg[i] = -1
  end
  for y = 1, H do rowDirty[y] = true end
  cx1, cy1, cx2, cy2 = 1, 1, W, H
  clips = {}
end

function F.size() return W, H end

-- принудительная перерисовка всего экрана при следующем flush
function F.invalidate()
  for i = 1, W * H do pch[i] = ""; pfg[i] = -1; pbg[i] = -1 end
  for y = 1, H do rowDirty[y] = true end
end

function F.pushClip(x, y, w, h)
  clips[#clips + 1] = { cx1, cy1, cx2, cy2 }
  cx1 = math.max(cx1, x); cy1 = math.max(cy1, y)
  cx2 = math.min(cx2, x + w - 1); cy2 = math.min(cy2, y + h - 1)
end

function F.popClip()
  local c = table.remove(clips)
  if c then cx1, cy1, cx2, cy2 = c[1], c[2], c[3], c[4] else cx1, cy1, cx2, cy2 = 1, 1, W, H end
end

function F.resetClip()
  clips = {}
  cx1, cy1, cx2, cy2 = 1, 1, W, H
end

function F.clear(color)
  color = color or DEF_BG
  for i = 1, W * H do ch[i] = " "; fg[i] = DEF_FG; bg[i] = color end
  for y = 1, H do rowDirty[y] = true end
end

function F.rect(x, y, w, h, color, c, f)
  c = c or " "
  local x1, y1 = math.max(x, cx1), math.max(y, cy1)
  local x2, y2 = math.min(x + w - 1, cx2), math.min(y + h - 1, cy2)
  if x2 < x1 or y2 < y1 then return end
  f = f or DEF_FG
  for yy = y1, y2 do
    local b = (yy - 1) * W
    for xx = x1, x2 do
      local i = b + xx
      ch[i] = c; fg[i] = f; bg[i] = color
    end
    rowDirty[yy] = true
  end
end

local function put(i, y, c, f, b)
  ch[i] = c
  fg[i] = f
  if b then bg[i] = b end
  rowDirty[y] = true
end

-- b == nil -> фон клетки сохраняется
function F.text(x, y, s, f, b)
  if y < cy1 or y > cy2 then return end
  s = tostring(s)
  f = f or DEF_FG
  local base = (y - 1) * W
  local px = x
  if not s:find("[\128-\255]") then
    for k = 1, #s do
      if px >= cx1 and px <= cx2 then put(base + px, y, s:sub(k, k), f, b) end
      px = px + 1
      if px > cx2 then break end
    end
  else
    for c in s:gmatch("[\1-\127\194-\244][\128-\191]*") do
      if px >= cx1 and px <= cx2 then put(base + px, y, c, f, b) end
      px = px + 1
      if px > cx2 then break end
    end
  end
end

function F.flush()
  local calls = 0
  local curF, curB = -2, -2
  for y = 1, H do
    if rowDirty[y] then
      rowDirty[y] = false
      local base = (y - 1) * W
      local x = 1
      while x <= W do
        local i = base + x
        if ch[i] ~= pch[i] or fg[i] ~= pfg[i] or bg[i] ~= pbg[i] then
          local f, b = fg[i], bg[i]
          local last = x
          local nx = x + 1
          while nx <= W do
            local j = base + nx
            if fg[j] ~= f or bg[j] ~= b then break end
            if ch[j] ~= pch[j] or fg[j] ~= pfg[j] or bg[j] ~= pbg[j] then
              last = nx
            elseif nx - last > GAP then
              break
            end
            nx = nx + 1
          end
          local parts = {}
          for k = x, last do
            local j = base + k
            parts[#parts + 1] = ch[j]
            pch[j] = ch[j]; pfg[j] = f; pbg[j] = b
          end
          if b ~= curB then gpu.setBackground(b); curB = b; calls = calls + 1 end
          if f ~= curF then gpu.setForeground(f); curF = f; calls = calls + 1 end
          gpu.set(x, y, table.concat(parts))
          calls = calls + 1
          x = last + 1
        else
          x = x + 1
        end
      end
    end
  end
  F.calls = calls
  return calls
end

return F
