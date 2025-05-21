-- ultimateOC.lua: Современная либа для визуала и утилит OpenComputers
local filesystem = require("filesystem")
local component = require("component")
local unicode = require("unicode")
local gpu = component.gpu

local M = {}

-- Простой save/load сериализации таблицы
function M.savef(path, tbl)
    local f = assert(io.open(path, "w"))
    f:write(require("serialization").serialize(tbl))
    f:close()
end

function M.loadf(path)
    if not filesystem.exists(path) then return {} end
    local f = assert(io.open(path, "r"))
    local data = f:read("*a")
    f:close()
    return require("serialization").unserialize(data) or {}
end

-- Фильтр предметов по подстроке (поиск)
function M.filterItems(tbl, query)
    if not query or query == "" then return tbl end
    local res = {}
    query = unicode.lower(query)
    for i, item in ipairs(tbl) do
        if unicode.lower(item.name):find(query, 1, true) then
            table.insert(res, item)
        end
    end
    return res
end

-- Красивый прямоугольник с закругленными углами
function M.roundRect(x, y, w, h, borderColor)
    borderColor = borderColor or 0x44475a
    gpu.setForeground(borderColor)
    -- Горизонтальные
    gpu.set(x+1, y, string.rep("─", w-2))
    gpu.set(x+1, y+h-1, string.rep("─", w-2))
    -- Вертикальные
    for i = y+1, y+h-2 do
        gpu.set(x, i, "│")
        gpu.set(x+w-1, i, "│")
    end
    -- Углы
    gpu.set(x, y, "╭")
    gpu.set(x+w-1, y, "╮")
    gpu.set(x, y+h-1, "╰")
    gpu.set(x+w-1, y+h-1, "╯")
end

-- Быстрая функция для отображения прогресс-бара
function M.progressBar(x, y, w, percent, bg, fg)
    bg = bg or 0x44475a; fg = fg or 0x50FA7B
    gpu.setBackground(bg)
    gpu.fill(x, y, w, 1, " ")
    gpu.setBackground(fg)
    gpu.fill(x, y, math.floor(w * percent), 1, " ")
    gpu.setBackground(0x1B1D23)
end

return M
