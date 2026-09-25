-- PRISMA · ЖУРНАЛ: события системы и чат
local P = ...
local U, F, UI, V = P.util, P.fb, P.ui, P.vc
local C = UI.C

local L = { id = "log", title = "ЖУРНАЛ", scrollId = "log.events" }
local LEVELS = { "info", "warn", "crit" }
local LTXT = { info = "все", warn = "важные", crit = "аварии" }
local LCOL = { info = "text", warn = "warn", crit = "bad" }
local filter = "info"

local function drawEvents(x, y, w, h)
  local log = P.log
  UI.panel(x, y, w, h, "СОБЫТИЯ", { right = string.format("инфо %.0f · важных %.0f · аварий %.0f", log.counts.info, log.counts.warn, log.counts.crit) })
  local ix, iw = x + 2, w - 4
  UI.cycler(ix, y + 1, 30, "Показать", LTXT[filter],
    function() filter = V.nextOf(LEVELS, filter, -1) end,
    function() filter = V.nextOf(LEVELS, filter, 1) end, { vw = 9 })
  UI.button(ix + 33, y + 1, 14, "Очистить", function() log.clear() end, { style = "warn" })
  UI.button(ix + 48, y + 1, 16, "Тест сигнала", function() log.warn("тест", "проверка звукового сигнала") end)
  UI.hline(ix, y + 2, iw, C.line)
  local list = log.recent(300, filter)
  local rows = h - 4
  local first, last, cw = UI.scrollArea("log.events", x + 1, y + 3, w - 2, rows, #list, true)
  for i = first, last do
    local e = list[i]
    local ry = y + 3 + (i - first)
    UI.text(x + 2, ry, e.clock, C.dim, C.panel)
    UI.text(x + 11, ry, U.pad(e.src, 14), C.acc, C.panel)
    UI.text(x + 26, ry, U.trunc(e.msg, cw - 26), C[LCOL[e.lvl]] or C.text, C.panel)
  end
  if #list == 0 then UI.textC(x + 1, y + 5, w - 2, "записей нет", C.dim, C.panel) end
end

local function drawChat(x, y, w, h)
  local Ch = P.mods.chat
  UI.panel(x, y, w, h, "ЧАТ", { right = Ch.available() and "chat_box" or "chat_box не найден", rcolor = Ch.available() and C.dim or C.bad })
  local ix, iw = x + 2, w - 4
  UI.button(ix, y + 1, iw, "Написать в игровой чат…", function()
    P.modal.input("Сообщение в чат", { prompt = "Текст", value = "", w = 64, onOk = function(v)
      if v and v ~= "" then
        if Ch.say(v) then Ch.add("PRISMA", v) else UI.toast("chat_box недоступен", "bad") end
      end
    end })
  end, { style = "primary", disabled = not Ch.available() })
  local logs = Ch.logs()
  local rows = h - 5
  local first, last = UI.scrollArea("log.chat", x + 1, y + 3, w - 2, rows, #logs, true)
  for i = first, last do
    local e = logs[i]
    local ry = y + 3 + (i - first)
    UI.text(x + 2, ry, string.sub(e.clock, 1, 5), C.dim, C.panel)
    UI.text(x + 8, ry, U.trunc(e.name, 12), C.acc, C.panel)
    local nx = x + 8 + math.min(13, U.ulen(e.name) + 1)
    UI.text(nx, ry, U.trunc(e.msg, x + w - 2 - nx), C.text, C.panel)
  end
  UI.text(ix, y + h - 2, "Команды: !prisma status | craft | reactors | sing", C.dim, C.panel)
end

function L.draw(x, y, w, h)
  local cols = V.split(x, w, { 60, 40 })
  drawEvents(cols[1].x, y, cols[1].w, h)
  drawChat(cols[2].x, y, cols[2].w, h)
end

return L
