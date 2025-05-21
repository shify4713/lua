-- PreCraft Classic: Надёжная версия с io.read(), логами и автокрафтом
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

local function drawTable(data, selected, search)
  gpu.setBackground(0x23272e)
  gpu.setForeground(0xE6EDF3)
  gpu.fill(2, 4, WIDTH-2, HEIGHT-12, " ")
  local y = 5
  centerText(3, "PreCraft ULTIMATE", 0x00ffff)
  gpu.set(4, y, "№")
  gpu.set(9, y, "Название")
  gpu.set(45, y, "Кол-во")
  gpu.set(58, y, "Крафт")
  y = y + 2
  local shown = 0
  for i, v in ipairs(data) do
    if not search or unicode.lower(v.name):find(unicode.lower(search)) then
      shown = shown + 1
      if i == selected then
        gpu.setBackground(0x3A5068)
        gpu.setForeground(0xF1F1F1)
      else
        gpu.setBackground(0x23272e)
        gpu.setForeground(0xE6EDF3)
      end
      gpu.set(4, y, tostring(i))
      gpu.set(9, y, v.name)
      gpu.set(45, y, tostring(v.count or ""))
      gpu.set(58, y, tostring(v.craftSize or ""))
      y = y + 1
      if y > HEIGHT - 12 then break end
    end
  end
  gpu.setBackground(0x23272e)
  gpu.setForeground(0xE6EDF3)
end

local function drawLogs(logs)
  local y0 = HEIGHT - 10
  gpu.setBackground(0x242b33)
  gpu.fill(2, y0, WIDTH-2, 9, " ")
  gpu.setForeground(0x50B9FF)
  gpu.set(2, y0, " Логи автокрафта (30) ")
  gpu.setForeground(0xE6EDF3)
  for i = math.max(1,#logs-LOG_MAX+1), #logs do
    local log = logs[i]
    if log then
      local color = 0xE6EDF3
      if log.kind == "ok" then color = 0x7CFC00
      elseif log.kind == "warn" then color = 0xFFD700
      elseif log.kind == "err" then color = 0xFF3C3C
      elseif log.kind == "craft" then color = 0x50B9FF end
      gpu.setForeground(0x474a4e)
      gpu.set(4, y0 + 1 + i-(#logs-LOG_MAX+1), "["..log.time.."] ")
      gpu.setForeground(color)
      gpu.set(14, y0 + 1 + i-(#logs-LOG_MAX+1), log.msg)
    end
  end
  gpu.setForeground(0xE6EDF3)
end

local function drawMenu(go)
  gpu.setBackground(0x23272e)
  gpu.setForeground(0x2980b9)
  centerText(HEIGHT-2, "[A]dd  [E]dit  [D]elete  [S]earch  [G]O/STOP  [Q]uit", 0x2980b9)
  gpu.setForeground(0x00ffff)
  gpu.set(4, HEIGHT-1, "Режим: " .. (go and "▶ Работает" or "⏸ Остановлен"))
  gpu.setForeground(0xE6EDF3)
end

local function logAdd(logs, kind, msg)
  table.insert(logs, {kind=kind, time=now_msk(), msg=msg})
  if #logs > LOG_MAX then table.remove(logs,1) end
end

local function checkCraft(data, logs, go)
  if not go then return end
  local anyDo = false
  for i,v in ipairs(data) do
    local itemsMe = me.getItemDetail({id=v.id, dmg=v.dmg})
    local qty = itemsMe and itemsMe.basic().qty or 0
    local needAll = (v.count or 0) - qty
    if needAll > 0 then
      local craftables = me.getCraftables({name=v.id,damage=v.dmg})
      if craftables.n and craftables.n >= 1 then
        local count = math.min(needAll, v.craftSize or needAll)
        local success, errMsg = pcall(function()
          local c = craftables[1].request(count)
          logAdd(logs, "craft", "Запущен автокрафт: "..(v.name or "?").." x"..tostring(count))
        end)
        if not success then
          logAdd(logs, "err", "Ошибка крафта "..(v.name or "?")..": "..tostring(errMsg))
        end
        anyDo = true
        os.sleep(0.1)
      else
        logAdd(logs, "warn", "Нет рецепта: "..(v.name or "?"))
      end
    end
  end
  if not anyDo then logAdd(logs, "info", "Простой: всё в наличии") end
end

local function main()
  local data = loadData()
  local logs = {}
  local selected = 1
  local search = ""
  local running = true
  local go = false
  local lastCheck = os.clock()
  while running do
    clearScreen()
    drawTable(data, selected, search)
    drawLogs(logs)
    drawMenu(go)
    term.setCursor(1, HEIGHT)
    io.write("Введите команду (Enter - обновить): ")
    local cmd = unicode.lower(io.read() or "")
    if cmd == "a" then
      -- Добавить предмет
      clearScreen()
      centerText(10, "Добавление предмета", 0x00ffff)
      term.setCursor(5, 12)
      io.write("Имя: ")
      local name = io.read() or ""
      term.setCursor(5, 13)
      io.write("Кол-во (целое): ")
      local count = tonumber(io.read() or "") or 1
      term.setCursor(5, 14)
      io.write("Макс. размер крафта (целое): ")
      local craftSize = tonumber(io.read() or "") or 1
      -- Получить id/dmg из 1-го слота ME-интерфейса
      local stack = me.getStackInSlot(1)
      if not stack then
        term.setCursor(5, 16)
        io.write("Положи предмет в 1-й слот ME-интерфейса! Нажми Enter...")
        io.read()
      else
        table.insert(data, {
          name = name,
          id = stack.id,
          dmg = stack.dmg,
          count = count,
          craftSize = craftSize
        })
        logAdd(logs, "ok", "Добавлен: "..name)
        saveData(data)
      end
    elseif cmd == "e" then
      -- Редактировать предмет
      if #data == 0 then goto afterMenu end
      clearScreen()
      centerText(10, "Редактирование", 0x00ffff)
      local v = data[selected]
      term.setCursor(5, 12)
      io.write("Имя ["..(v.name or "").."]: ")
      local name = io.read() or ""
      if name ~= "" then v.name = name end
      term.setCursor(5, 13)
      io.write("Кол-во ["..(v.count or "").."]: ")
      local count = io.read() or ""
      if count ~= "" then v.count = tonumber(count) or v.count end
      term.setCursor(5, 14)
      io.write("Макс. размер крафта ["..(v.craftSize or "").."]: ")
      local craftSize = io.read() or ""
      if craftSize ~= "" then v.craftSize = tonumber(craftSize) or v.craftSize end
      logAdd(logs, "info", "Изменено: "..(v.name or "?"))
      saveData(data)
    elseif cmd == "d" then
      -- Удалить предмет
      if #data == 0 then goto afterMenu end
      logAdd(logs, "warn", "Удалён: "..(data[selected] and data[selected].name or ""))
      table.remove(data, selected)
      if selected > #data then selected = #data end
      saveData(data)
    elseif cmd == "s" then
      -- Поиск по названию
      clearScreen()
      term.setCursor(5, 12)
      io.write("Поиск: ")
      search = io.read() or ""
      selected = 1
    elseif cmd == "g" then
      go = not go
      logAdd(logs, "info", "Режим: "..(go and "▶ GO" or "⏸ STOP"))
    elseif cmd == "q" then
      clearScreen()
      gpu.set(5, 5, "Выход...")
      running = false
      break
    elseif tonumber(cmd) then
      local num = tonumber(cmd)
      if num >= 1 and num <= #data then selected = num end
    elseif cmd == "up" or cmd == "w" then
      if selected > 1 then selected = selected - 1 end
    elseif cmd == "down" or cmd == "s" then
      if selected < #data then selected = selected + 1 end
    end
    ::afterMenu::
    -- Автокрафт раз в 5 секунд, если включено
    if go and (os.clock() - lastCheck > 5) then
      checkCraft(data, logs, go)
      lastCheck = os.clock()
    end
  end
end

local ok, err = pcall(main)
if not ok then
  term.setCursor(1, HEIGHT)
  io.write("Ошибка: " .. tostring(err))
  io.read()
end
