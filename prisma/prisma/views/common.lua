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

-- ───────── цвет по нику (стабильный, как в майнкрафт-чатах) ─────────
local NICK_PALETTE = { 0xFF8A80, 0xFFD54F, 0x69F0AE, 0x64B5F6, 0xB388FF, 0xFFAB40, 0x4DD0E1, 0xF06292, 0xAED581, 0x90CAF9 }
function V.nickColor(name)
  name = tostring(name or "?")
  local h = 0
  for i = 1, U.ulen(name) do h = (h * 31 + name:byte(i) or 0) % 100003 end
  return NICK_PALETTE[(h % #NICK_PALETTE) + 1]
end

-- разбивает строку по словам так, чтобы каждая часть была не длиннее width (в символах)
local function wrapWords(text, width)
  width = math.max(4, width)
  local lines = {}
  local cur = ""
  for word in tostring(text or ""):gmatch("%S+") do
    local cand = (cur == "") and word or (cur .. " " .. word)
    if U.ulen(cand) <= width then
      cur = cand
    else
      if cur ~= "" then lines[#lines + 1] = cur end
      if U.ulen(word) > width then
        local w = word
        while U.ulen(w) > width do
          lines[#lines + 1] = U.usub(w, 1, width)
          w = U.usub(w, width + 1, -1)
        end
        cur = w
      else
        cur = word
      end
    end
  end
  if cur ~= "" or #lines == 0 then lines[#lines + 1] = cur end
  return lines
end
V.wrapWords = wrapWords

-- превращает последние n сообщений чата в готовые к отрисовке строки с переносом:
-- { {head=, cont=bool, text=, color=} , ... }. head — «ЧЧ:ММ Ник: » на первой строке
-- сообщения, на последующих — пробелы такой же ширины (для выравнивания).
function V.chatWrap(logs, width, n)
  local out = {}
  local from = math.max(1, #logs - (n or #logs) + 1)
  for i = from, #logs do
    local e = logs[i]
    local color = V.nickColor(e.name)
    local head = string.sub(e.clock or "", 1, 5) .. " " .. e.name .. ": "
    local headLen = U.ulen(head)
    local bodyWidth = math.max(6, width - headLen)
    local wrapped = wrapWords(e.msg, bodyWidth)
    for li, chunk in ipairs(wrapped) do
      if li == 1 then
        out[#out + 1] = { head = head, headLen = headLen, text = chunk, color = color }
      else
        out[#out + 1] = { head = "", headLen = headLen, text = chunk, color = color, cont = true }
      end
    end
  end
  return out
end

-- то же для событий журнала: { {clock=, src=, text=, color=, cont=bool}, ... }
function V.logWrap(entries, width, srcW)
  srcW = srcW or 14
  local out = {}
  for _, e in ipairs(entries) do
    local prefixLen = 6 + 1 + srcW + 1
    local bodyWidth = math.max(10, width - prefixLen)
    local wrapped = wrapWords(e.msg, bodyWidth)
    for li, chunk in ipairs(wrapped) do
      if li == 1 then
        out[#out + 1] = { clock = e.clock, src = e.src, text = chunk, lvl = e.lvl, prefixLen = prefixLen }
      else
        out[#out + 1] = { clock = "", src = "", text = chunk, lvl = e.lvl, prefixLen = prefixLen, cont = true }
      end
    end
  end
  return out
end

return V
