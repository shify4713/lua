--wget -f https://raw.githubusercontent.com/shify4713/lua/main/ultimateOC.lua /lib/ultimateOC.lua
--wget -f https://raw.githubusercontent.com/shify4713/lua/refs/heads/main/autoCraftUltimate.lua /home/autoCraftUltimate.lua
-- ultimateOC.lua - Улучшенная библиотека для визуала OpenComputers
local fs = require("filesystem")
local unicode = require("unicode")
local gpu = require("component").gpu

local M = {}

-- Безопасное сохранение таблицы (быстрее и надёжнее)
function M.savef(path, tbl)
    local ok, ser = pcall(require("serialization").serialize, tbl)
    if not ok then error("Ошибка сериализации: "..tostring(ser)) end
    local f, err = io.open(path, "w")
    if not f then error("Не могу открыть файл для записи: "..err) end
    f:write(ser)
    f:close()
end

function M.loadf(path)
    if not fs.exists(path) then return {} end
    local f, err = io.open(path, "r")
    if not f then error("Не могу открыть файл: "..err) end
    local data = f:read("*a")
    f:close()
    local ok, tbl = pcall(require("serialization").unserialize, data)
    if not ok then error("Ошибка десериализации: "..tostring(tbl)) end
    return tbl or {}
end

-- Гибкий фильтр предметов по подстроке (поиск не зависит от регистра)
function M.filterItems(tbl, query)
    if not query or query == "" then return tbl end
    local res = {}
    query = unicode.lower(query)
    for i, item in ipairs(tbl) do
        if item.name and unicode.lower(item.name):find(query, 1, true) then
            table.insert(res, item)
        end
    end
    return res
end

-- Закруглённый прямоугольник c опциональной цветной рамкой
function M.roundRect(x, y, w, h, borderColor, fillColor)
    borderColor = borderColor or 0x44475a
    fillColor = fillColor or 0x1B1D23
    -- Заливка
    if fillColor then
        gpu.setBackground(fillColor)
        gpu.fill(x, y, w, h, " ")
    end
    -- Рамка
    gpu.setForeground(borderColor)
    gpu.set(x+1, y, string.rep("─", w-2))
    gpu.set(x+1, y+h-1, string.rep("─", w-2))
    for i = y+1, y+h-2 do
        gpu.set(x, i, "│")
        gpu.set(x+w-1, i, "│")
    end
    gpu.set(x, y, "╭")
    gpu.set(x+w-1, y, "╮")
    gpu.set(x, y+h-1, "╰")
    gpu.set(x+w-1, y+h-1, "╯")
end

-- Прогресс-бар (цветной)
function M.progressBar(x, y, w, percent, fg, bg)
    fg = fg or 0x50FA7B
    bg = bg or 0x44475a
    gpu.setBackground(bg)
    gpu.fill(x, y, w, 1, " ")
    gpu.setBackground(fg)
    gpu.fill(x, y, math.max(0, math.floor(w * percent)), 1, " ")
    gpu.setBackground(0x1B1D23)
end

-- Анимированная кнопка (с закруглением, цветами и "нажатием")
function M.animatedButton(x, y, w, h, text, active, baseColor, hoverColor, textColor)
    baseColor = baseColor or 0x00BFFF
    hoverColor = hoverColor or 0x1E90FF
    textColor = textColor or 0xFFFFFF
    local color = active and hoverColor or baseColor
    M.roundRect(x, y, w, h, color, color)
    gpu.setForeground(textColor)
    gpu.set(x + math.floor((w-unicode.len(text))/2), y + math.floor(h/2), text)
    gpu.setBackground(0x1B1D23)
end

-- Тень под текстом
function M.drawText(x, y, text, color, shadow)
    color = color or 0xF8F8F2
    if shadow then
        gpu.setForeground(0x282A36)
        gpu.set(x+1, y+1, text)
    end
    gpu.setForeground(color)
    gpu.set(x, y, text)
end

-- Быстрый логгер: добавляет строку в массив (до 50 записей)
function M.addLog(logs, text, lvl)
    lvl = lvl or "INFO"
    local now = os.date("!*t", os.time()+3*3600) -- МСК
    local t = string.format("[%02d:%02d:%02d][%s] %s", now.hour, now.min, now.sec, lvl, text)
    table.insert(logs, t)
    while #logs > 50 do table.remove(logs, 1) end
end

-- Рисует список логов (на экране)
function M.drawLogs(x, y, logs, count, color)
    count = count or 10
    color = color or 0x8BE9FD
    local logY = y
    for i = math.max(1,#logs-count+1), #logs do
        M.drawText(x, logY, logs[i], color)
        logY = logY + 1
    end
end

-- Быстрый автоматический скролл по массиву
function M.scrollArray(tbl, scroll, perPage)
    local res = {}
    perPage = perPage or 20
    scroll = math.max(1, math.min(scroll, math.max(1, #tbl-perPage+1)))
    for i=scroll, math.min(#tbl, scroll+perPage-1) do
        res[#res+1] = tbl[i]
    end
    return res
end

-- Цветной выделенный элемент (фон+текст)
function M.selectLine(x, y, w, text, selected, color, selColor, textColor)
    color = color or 0x23262E
    selColor = selColor or 0x00BFFF
    textColor = textColor or 0xF8F8F2
    gpu.setBackground(selected and selColor or color)
    gpu.setForeground(textColor)
    gpu.fill(x, y, w, 1, " ")
    gpu.set(x+1, y, text)
    gpu.setBackground(0x1B1D23)
end

return M
