-- PRISMA · общие помощники для экранов
local P = ...
local U, F, UI = P.util, P.fb, P.ui
local C = UI.C

local V = {}

-- состояния автокрафта: текст, цвет текста, цвет фона
V.STATES = {
  crafting = { "КРАФТ",       "ok" },
  plan     = { "ПЛАНИРУЮ",    "acc" },
  want     = { "ЖДЁТ",        "warn" },
  idle     = { "ОЖИДАНИЕ",    "dim" },
  pause    = { "ПАУЗА",       "warn" },
  fail     = { "ОШИБКА",      "bad" },
  norecipe = { "НЕТ РЕЦЕПТА", "bad" },
  scan     = { "ПРОВЕРКА",    "dim" },
  ok       = { "ОК",          "ok2" },
  off      = { "ВЫКЛ",        "dim" },
}

function V.color(name)
  if name == "ok2" then return C.ok end
  return C[name] or C.text
end

function V.stateText(st)
  local s = V.STATES[st] or { st, "dim" }
  return s[1], V.color(s[2])
end

function V.reactorColor(rr)
  local rc = P.cfg.reactors
  if not rr.online then return C.bad end
  if rr.kind ~= "running" then return C.dim end
  local t = rr.d.temp or 0
  if t >= rc.tempCrit then return C.bad end
  if t >= rc.safeModeTemp then return C.warn end
  if t >= rc.forceModeTemp then return C.ok end
  return C.acc
end

-- рабочая область вида делится на колонки по весам; возвращает массив {x,w}
function V.split(x, w, weights, gap)
  gap = gap or 1
  local total = 0
  for _, k in ipairs(weights) do total = total + k end
  local avail = w - gap * (#weights - 1)
  local out, cx = {}, x
  local used = 0
  for i, k in ipairs(weights) do
    local cw = (i == #weights) and (avail - used) or math.floor(avail * k / total)
    out[i] = { x = cx, w = cw }
    cx = cx + cw + gap
    used = used + cw
  end
  return out
end

-- цикл по списку значений
function V.nextOf(list, cur, dir)
  local idx = 1
  for i, v in ipairs(list) do if v == cur then idx = i end end
  return list[((idx - 1 + dir) % #list) + 1]
end

function V.reasonText(it)
  return it.rt.reason or (it.rt.err and ("ME: " .. tostring(it.rt.err))) or ""
end

return V
