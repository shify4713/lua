-- PreCraft ULTIMATE: гибрид GUI+io.read с вкладками, мышью и терминальным вводом
local component = require("component")
local fs = require("filesystem")
local unicode = require("unicode")
local term = require("term")
local event = require("event")
local serialization = require("serialization")
local gpu = component.gpu
local me = component.me_interface

local WIDTH, HEIGHT = 120, 40
local PATH = "/home/BD.txt"
local LOG_MAX = 30

gpu.setResolution(WIDTH, HEIGHT)

-- State
local state = {
  tab = 1, -- 1=Главная, 2=Изменить, 3=Логи
  selected = 1,
  search = "",
  logs = {},
  go = false,
  data = {},
  redraw = true,
  running = true
}

local tabs = {"Главная", "Изменить", "Логи"}

local function now_msk()
  local utc = os.time(os.date("!*t"))
  local msk = utc + 3*3600
  local t = os.date("*t", msk)
  return string.format("%02d:%02d:%02d", t.hour, t.min, t.sec)
end

local function clearScreen()
  gpu.setBackground(0x23272e)
  gpu.setForeground(0xE6EDF3)
  gpu.fill(1, 1, WIDTH, HEIGHT, " ")
end

local function centerText(y, text, color)
  local x = math.floor((WIDTH - unicode.len(text)) / 2) + 1
  if color then gpu.setForeground(color) end
  gpu.set(x, y, text)
  gpu.setForeground(0xE6EDF3)
end

local function logAdd(kind, msg)
  table.insert(state.logs, {kind=kind, time=now_msk(), msg=msg})
  if #state.logs > LOG_MAX then table.remove(state.logs,1) end
end

local function loadData()
  if not fs.exists(PATH) then
    local f = io.open(PATH, "w")
    f:write("return {}\n")
    f:close()
  end
  local ok, data = pcall(dofile, PATH)
  return ok and data or {}
end

local function saveData(tbl)
  local f = io.open(PATH, "w")
  f:write("return " .. serialization.serialize(tbl) .. "\n")
  f:close()
end

local function drawTabs()
  local x = 3
  for i, tab in ipairs(tabs) do
    if i == state.tab then
      gpu.setBackground(0x2866b2)
      gpu.setForeground(0xffffff)
    else
      gpu.setBackground(0x23272e)
      gpu.setForeground(0xE6EDF3)
    end
    gpu.set(x, 2, " "..tab.." ")
    x = x + unicode.len(tab) + 4
  end
  gpu.setBackground(0x23272e)
  gpu.setForeground(0xE6EDF3)
end

local function tabFromCoords(x, y)
  if y ~= 2 then return nil end
  local x1 = 3
  for i, tab in ipairs(tabs) do
    local x2 = x1 + unicode.len(tab) + 1
    if x >= x1 and x <= x2 then return i end
    x1 = x2 + 2
  end
  return nil
end

local function filteredData()
  if not state.search or state.search == "" then return state.data end
  local t = {}
  for _,v in ipairs(state.data) do
    if unicode.lower(v.name):find(unicode.lower(state.search)) then table.insert(t, v) end
  end
  return t
end

local function drawMain()
  centerText(4, "PreCraft ULTIMATE", 0x00ffff)
  gpu.set(4, 6, "№")
  gpu.set(9, 6, "Название")
  gpu.set(45, 6, "Кол-во")
  gpu.set(58, 6, "Крафт")
  gpu.setBackground(0x23272e)
  gpu.setForeground(0xE6EDF3)
  local y = 8
  local show = filteredData()
  for i, v in ipairs(show) do
    if i == state.selected then
      gpu.setBackground(0x3A5068)
      gpu.setForeground(0xF1F1F1)
    else
      gpu.setBackground(0x23272e)
      gpu.setForeground(0xE6EDF3)
    end
    gpu.set(4, y, tostring(i))
    gpu.set(9, y, v.name or "")
    gpu.set(45, y, tostring(v.count or ""))
    gpu.set(58, y, tostring(v.craftSize or ""))
    y = y + 1
    if y > HEIGHT - 14 then break end
  end
  gpu.setBackground(0x23272e)
  gpu.setForeground(0xE6EDF3)
  -- Кнопки
  local by = HEIGHT-10
  local bx = 4
  local buttons = {
    {bx, by, "[Добавить]", "add"},
    {bx+14, by, "[Изменить]", "edit"},
    {bx+28, by, "[Удалить]", "del"},
    {bx+42, by, "[Поиск]", "search"},
    {bx+56, by, state.go and "[Стоп]" or "[Запуск]", "toggleGo"}
  }
  for _,b in ipairs(buttons) do
    gpu.setBackground(0x2980b9)
    gpu.setForeground(0xf7f7f7)
    gpu.set(b[1], b[2], b[3])
  end
  gpu.setBackground(0x23272e)
  gpu.setForeground(0xE6EDF3)
end

local function buttonFromCoords(x, y)
  local by = HEIGHT-10
  -- По расположению кнопок
  local bx = 4
  local buttons = {
    {bx, by, bx+9, by, "add"},
    {bx+14, by, bx+23, by, "edit"},
    {bx+28, by, bx+37, by, "del"},
    {bx+42, by, bx+49, by, "search"},
    {bx+56, by, bx+65, by, "toggleGo"}
  }
  for _,b in ipairs(buttons) do
    if x >= b[1] and x <= b[3] and y == b[2] then return b[5] end
  end
  return nil
end

local function drawEdit()
  centerText(6, "Редактирование", 0x00ffff)
  local v = filteredData()[state.selected]
  if not v then
    gpu.set(10, 8, "Нет выбранного предмета!")
    return
  end
  gpu.set(10, 8, "Имя: "..(v.name or ""))
  gpu.set(10, 9, "ID: "..(v.id or ""))
  gpu.set(10,10, "DMG: "..(v.dmg or ""))
  gpu.set(10,11, "Кол-во: "..tostring(v.count or ""))
  gpu.set(10,12, "Макс. размер крафта: "..tostring(v.craftSize or ""))
  gpu.setBackground(0x2980b9)
  gpu.setForeground(0xf7f7f7)
  gpu.set(10, 14, "[Изменить имя]")
  gpu.set(28, 14, "[Изменить кол-во]")
  gpu.set(50, 14, "[Изменить крафт]")
  gpu.setBackground(0x23272e)
  gpu.setForeground(0xE6EDF3)
end

local function editButtonFromCoords(x, y)
  if y ~= 14 then return nil end
  if x >= 10 and x <= 25 then return "name" end
  if x >= 28 and x <= 47 then return "count" end
  if x >= 50 and x <= 65 then return "craft" end
  return nil
end

local function drawLogs()
  centerText(5, "Логи автокрафта", 0x00ffff)
  local y0 = 7
  for i = math.max(1,#state.logs-LOG_MAX+1), #state.logs do
    local log = state.logs[i]
    if log then
      local color = 0xE6EDF3
      if log.kind == "ok" then color = 0x7CFC00
      elseif log.kind == "warn" then color = 0xFFD700
      elseif log.kind == "err" then color = 0xFF3C3C
      elseif log.kind == "craft" then color = 0x50B9FF end
      gpu.setForeground(0x474a4e)
      gpu.set(4, y0, "["..log.time.."] ")
      gpu.setForeground(color)
      gpu.set(14, y0, log.msg)
      y0 = y0 + 1
      if y0 > HEIGHT-4 then break end
    end
  end
  gpu.setForeground(0xE6EDF3)
end

local function drawMenu()
  gpu.setBackground(0x23272e)
  gpu.setForeground(0x2980b9)
  gpu.set(4, HEIGHT-2, "Мышью: вкладки, кнопки. [Q]uit - выход. Ввод только по io.read!")
  gpu.setForeground(0xE6EDF3)
  gpu.set(4, HEIGHT-1, "Режим: " .. (state.go and "▶ Работает" or "⏸ Остановлен"))
end

local function checkCraft()
  if not state.go then return end
  local anyDo = false
  for i,v in ipairs(state.data) do
    local itemsMe = me.getItemDetail({id=v.id, dmg=v.dmg})
    local qty = itemsMe and itemsMe.basic().qty or 0
    local needAll = (v.count or 0) - qty
    if needAll > 0 then
      local craftables = me.getCraftables({name=v.id,damage=v.dmg})
      if craftables.n and craftables.n >= 1 then
        local count = math.min(needAll, v.craftSize or needAll)
        local success, errMsg = pcall(function()
          local c = craftables[1].request(count)
          logAdd("craft", "Запущен автокрафт: "..(v.name or "?").." x"..tostring(count))
        end)
        if not success then
          logAdd("err", "Ошибка крафта "..(v.name or "?")..": "..tostring(errMsg))
        end
        anyDo = true
        os.sleep(0.1)
      else
        logAdd("warn", "Нет рецепта: "..(v.name or "?"))
      end
    end
  end
  if not anyDo then logAdd("info", "Простой: всё в наличии") end
end

local function render()
  clearScreen()
  drawTabs()
  if state.tab == 1 then
    drawMain()
  elseif state.tab == 2 then
    drawEdit()
  elseif state.tab == 3 then
    drawLogs()
  end
  drawMenu()
end

-- io.read в отдельном модальном окне
local function inputPrompt(prompt, default)
  clearScreen()
  centerText(HEIGHT//2-2, prompt, 0x00ffff)
  if default then
    term.setCursor(10, HEIGHT//2)
    io.write("["..default.."]: ")
  else
    term.setCursor(10, HEIGHT//2)
    io.write(": ")
  end
  local v = io.read()
  if v == "" and default then return default end
  return v
end

local function run()
  state.data = loadData()
  local lastCheck = os.clock()

  event.listen("touch", function(_, _, x, y)
    -- Вкладки
    local t = tabFromCoords(x, y)
    if t then
      state.tab = t
      state.redraw = true
      return
    end
    -- Кнопки на главной
    if state.tab == 1 then
      local act = buttonFromCoords(x, y)
      if act == "add" then
        -- Добавить предмет
        local name = inputPrompt("Имя предмета")
        if not name or name == "" then return end
        local count = tonumber(inputPrompt("Кол-во (целое)", "1")) or 1
        local craftSize = tonumber(inputPrompt("Макс. размер крафта", "1")) or 1
        local stack = me.getStackInSlot(1)
        if not stack then
          inputPrompt("Положи предмет в 1-й слот ME-интерфейса и нажми Enter", "")
          return
        end
        table.insert(state.data, {
          name = name,
          id = stack.id,
          dmg = stack.dmg,
          count = count,
          craftSize = craftSize
        })
        logAdd("ok", "Добавлен: "..name)
        saveData(state.data)
        state.redraw = true
      elseif act == "edit" then
        state.tab = 2
        state.redraw = true
      elseif act == "del" then
        if #filteredData() == 0 then return end
        logAdd("warn", "Удалён: "..(filteredData()[state.selected] and filteredData()[state.selected].name or "?"))
        table.remove(state.data, state.selected)
        saveData(state.data)
        if state.selected > #filteredData() then state.selected = #filteredData() end
        state.redraw = true
      elseif act == "search" then
        state.search = inputPrompt("Поиск по названию", state.search)
        state.selected = 1
        state.redraw = true
      elseif act == "toggleGo" then
        state.go = not state.go
        logAdd("info", "Режим: "..(state.go and "▶ GO" or "⏸ STOP"))
        state.redraw = true
      end
      -- Клик по строке?
      local show = filteredData()
      for i=1, math.min(#show, HEIGHT-14) do
        if y == 7+i then state.selected = i; state.redraw = true end
      end
    elseif state.tab == 2 then
      local b = editButtonFromCoords(x, y)
      local v = filteredData()[state.selected]
      if not v then return end
      if b == "name" then
        local name = inputPrompt("Новое имя", v.name)
        if name and name ~= "" then
          v.name = name
          logAdd("info", "Имя изменено для "..(v.name or "?"))
          saveData(state.data)
          state.redraw = true
        end
      elseif b == "count" then
        local count = tonumber(inputPrompt("Новое кол-во", v.count))
        if count then
          v.count = count
          logAdd("info", "Кол-во изменено для "..(v.name or "?"))
          saveData(state.data)
          state.redraw = true
        end
      elseif b == "craft" then
        local craftSize = tonumber(inputPrompt("Новый макс. размер крафта", v.craftSize))
        if craftSize then
          v.craftSize = craftSize
          logAdd("info", "Крафт изменён для "..(v.name or "?"))
          saveData(state.data)
          state.redraw = true
        end
      end
    end
  end)

  while state.running do
    if state.redraw then render(); state.redraw = false end
    -- Автокрафт раз в 5 сек, если включено
    if state.go and (os.clock() - lastCheck > 5) then
      checkCraft()
      lastCheck = os.clock()
      state.redraw = true
    end
    -- Ввод с клавы (q - выйти, w/s - вверх/вниз)
    term.setCursor(1, HEIGHT)
    io.write("Для ввода команды — [Q]uit/[W]вверх/[S]вниз/[Enter]обновить: ")
    local cmd = unicode.lower(io.read() or "")
    if cmd == "q" then
      state.running = false
    elseif cmd == "w" then
      if state.selected > 1 then state.selected = state.selected - 1; state.redraw = true end
    elseif cmd == "s" then
      if state.selected < #filteredData() then state.selected = state.selected + 1; state.redraw = true end
    else
      state.redraw = true
    end
  end
end

local ok, err = pcall(run)
if not ok then
  term.setCursor(1, HEIGHT)
  io.write("Ошибка: " .. tostring(err))
  io.read()
end
