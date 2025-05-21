-- PreCraft ULTIMATE (OpenComputers) - main.lua с классическим io.read() для ввода

local component = require("component")
local fs = require("filesystem")
local unicode = require("unicode")
local term = require("term")
local event = require("event")
local gpu = component.gpu
local me = component.me_interface

local WIDTH, HEIGHT = 160, 50
local PATH = "/home/BD.txt"
gpu.setResolution(WIDTH, HEIGHT)

local function clearScreen()
  gpu.setBackground(0x23272e)
  gpu.setForeground(0xE6EDF3)
  gpu.fill(1, 1, WIDTH, HEIGHT, " ")
end

local function centerText(y, text)
  local x = math.floor((WIDTH - unicode.len(text)) / 2) + 1
  gpu.set(x, y, text)
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
  f:write("return " .. require("serialization").serialize(tbl) .. "\n")
  f:close()
end

local function drawTable(data, selected, search)
  gpu.setBackground(0x23272e)
  gpu.setForeground(0xE6EDF3)
  gpu.fill(2, 4, WIDTH-2, HEIGHT-8, " ")
  local y = 5
  centerText(3, "PreCraft ULTIMATE")
  gpu.set(5, y, "№")
  gpu.set(10, y, "Название")
  gpu.set(40, y, "Кол-во")
  gpu.set(55, y, "Крафт")
  y = y + 2
  for i, v in ipairs(data) do
    if not search or unicode.lower(v.name):find(unicode.lower(search)) then
      if i == selected then
        gpu.setBackground(0x3A5068)
        gpu.setForeground(0xF1F1F1)
      else
        gpu.setBackground(0x23272e)
        gpu.setForeground(0xE6EDF3)
      end
      gpu.set(5, y, tostring(i))
      gpu.set(10, y, v.name)
      gpu.set(40, y, tostring(v.count or ""))
      gpu.set(55, y, tostring(v.craftSize or ""))
      y = y + 1
      if y > HEIGHT - 6 then break end
    end
  end
  gpu.setBackground(0x23272e)
  gpu.setForeground(0xE6EDF3)
end

local function drawMenu()
  gpu.setBackground(0x23272e)
  gpu.setForeground(0x2980b9)
  centerText(HEIGHT-4, "[A]dd  [E]dit  [D]elete  [S]earch  [Q]uit")
end

local function main()
  local data = loadData()
  local selected = 1
  local search = ""
  while true do
    clearScreen()
    drawTable(data, selected, search)
    drawMenu()
    term.setCursor(1, HEIGHT)
    io.write("Введите команду: ")
    local cmd = unicode.lower(io.read())
    if cmd == "a" then
      -- Добавить предмет
      clearScreen()
      centerText(10, "Добавление предмета")
      term.setCursor(5, 12)
      io.write("Имя: ")
      local name = io.read()
      term.setCursor(5, 13)
      io.write("Кол-во: ")
      local count = tonumber(io.read())
      term.setCursor(5, 14)
      io.write("Макс. размер крафта: ")
      local craftSize = tonumber(io.read())
      -- Получить id/dmg из 1-го слота ME-интерфейса
      local stack = me.getStackInSlot(1)
      if not stack then
        term.setCursor(5, 16)
        io.write("Положи предмет в 1-й слот ME-интерфейса! Нажми Enter...")
        io.read()
      else
        table.insert(data, {
          name = name or "???",
          id = stack.id,
          dmg = stack.dmg,
          count = count or 1,
          craftSize = craftSize or 1
        })
        saveData(data)
      end
    elseif cmd == "e" then
      -- Редактировать предмет
      if #data == 0 then goto afterMenu end
      clearScreen()
      centerText(10, "Редактирование")
      local v = data[selected]
      term.setCursor(5, 12)
      io.write("Имя ["..(v.name or "").."]: ")
      local name = io.read()
      if name ~= "" then v.name = name end
      term.setCursor(5, 13)
      io.write("Кол-во ["..(v.count or "").."]: ")
      local count = io.read()
      if count ~= "" then v.count = tonumber(count) end
      term.setCursor(5, 14)
      io.write("Макс. размер крафта ["..(v.craftSize or "").."]: ")
      local craftSize = io.read()
      if craftSize ~= "" then v.craftSize = tonumber(craftSize) end
      saveData(data)
    elseif cmd == "d" then
      -- Удалить предмет
      if #data == 0 then goto afterMenu end
      table.remove(data, selected)
      if selected > #data then selected = #data end
      saveData(data)
    elseif cmd == "s" then
      -- Поиск по названию
      clearScreen()
      term.setCursor(5, 12)
      io.write("Поиск: ")
      search = io.read()
      selected = 1
    elseif cmd == "q" then
      clearScreen()
      gpu.set(5, 5, "Выход...")
      os.exit()
    elseif tonumber(cmd) then
      local num = tonumber(cmd)
      if num >= 1 and num <= #data then selected = num end
    elseif cmd == "up" or cmd == "w" then
      if selected > 1 then selected = selected - 1 end
    elseif cmd == "down" or cmd == "s" then
      if selected < #data then selected = selected + 1 end
    end
    ::afterMenu::
  end
end

local ok, err = pcall(main)
if not ok then
  term.setCursor(1, HEIGHT)
  io.write("Ошибка: " .. tostring(err))
  io.read()
end
