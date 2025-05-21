local component = require("component")
local fs = require("filesystem")
local shell = require("shell")
local event = require("event")
local unicode = require("unicode")
local term = require("term")
local computer = require("computer")
local g = component.gpu
local me = component.me_interface

-- Пути и библиотека
local DATA_FILE = "/home/BD.txt"
local LIB_PATH = "/lib/ultimateOC.lua"

if not fs.exists(LIB_PATH) then
    shell.execute("wget -f https://raw.githubusercontent.com/shify4713/lua/main/ultimateOC.lua " .. LIB_PATH)
end
local uoc = require("ultimateOC")

if not fs.exists(DATA_FILE) then
    uoc.savef(DATA_FILE, {})
end

-------------------- Настройки --------------------
local COLORS = {
    button = 0x00BFFF,
    buttonActive = 0x1E90FF,
    border = 0x44475a,
    text = 0xF8F8F2,
    shadow = 0x282A36,
    bg = 0x1B1D23,
    error = 0xFF5555,
    ok = 0x50FA7B,
    log = 0x8BE9FD,
    progress_bg = 0x44475a,
    progress_fg = 0x50FA7B,
    select = 0x222245,
    select_active = 0x44B3FF,
}
local WIDTH, HEIGHT = 110, 40
local craftStatus = "Ожидание..."
local nextCraftUpdate = 0
local isCrafting = false

-------------------- Переменные --------------------
local guiPath = {"main"}
local scroll = 1
local search = ""
local logs = {}
local selectedItem = nil
local dataItems = {}
local itemScroll = 1
local changeitem = false

-------------------- Визуал --------------------
local function clear()
    g.setBackground(COLORS.bg)
    g.fill(1,1,WIDTH,HEIGHT," ")
    g.setForeground(COLORS.text)
end

local function drawHeader()
    uoc.drawText(3,2,"Ultimate AutoCraft",COLORS.ok,true)
    uoc.drawText(WIDTH-34,2,"Статус: "..craftStatus,
        (craftStatus:find("Ошибка") and COLORS.error) or COLORS.ok)
    uoc.progressBar(3,4,WIDTH-6, isCrafting and 0.9 or 0)
end

local function drawLogs()
    uoc.drawLogs(3, HEIGHT-8, logs, 8, COLORS.log)
end

local function drawItems()
    uoc.drawText(3,6,"Название",COLORS.text)
    uoc.drawText(40,6,"Текущее",COLORS.text)
    uoc.drawText(55,6,"Держать",COLORS.text)
    uoc.drawText(70,6,"За раз",COLORS.text)
    local showItems = uoc.filterItems(dataItems, search)
    local perPage = 24
    local y = 7
    for i = itemScroll, math.min(#showItems, itemScroll+perPage-1) do
        local it = showItems[i]
        local isSel = (selectedItem and dataItems[selectedItem] and it==dataItems[selectedItem])
        uoc.selectLine(3, y, 100, (it.name or "<?>"), isSel, COLORS.select, COLORS.select_active, COLORS.text)
        g.setForeground(COLORS.text)
        g.set(40, y, tostring(it.current or 0))
        g.set(55, y, tostring(it.count or 0))
        g.set(70, y, tostring(it.craftSize or 0))
        y = y + 1
    end
    g.setBackground(COLORS.bg)
    g.setForeground(COLORS.text)
    local hint = (search == "" and "Поиск: (введите часть названия...)" or "Поиск: "..search)
    uoc.drawText(3,HEIGHT-10, hint, COLORS.text)
end

local function drawButtons()
    uoc.animatedButton(WIDTH-30, HEIGHT-4, 12, 3, isCrafting and "Остановить" or "Автокрафт", isCrafting, COLORS.button, COLORS.buttonActive)
    uoc.animatedButton(WIDTH-15, HEIGHT-4, 12, 3, "Добавить", false, COLORS.button, COLORS.buttonActive)
    uoc.animatedButton(WIDTH-45, HEIGHT-4, 12, 3, "Изменить", false, COLORS.button, COLORS.buttonActive)
    uoc.animatedButton(WIDTH-60, HEIGHT-4, 12, 3, "Удалить", false, COLORS.button, COLORS.buttonActive)
end

local function draw()
    clear()
    drawHeader()
    drawItems()
    drawButtons()
    drawLogs()
end

-------------------- IO и действия --------------------
local function reload()
    dataItems = uoc.loadf(DATA_FILE)
    for _,item in ipairs(dataItems) do
        local d = me.getItemDetail({id = item.id, dmg = item.dmg})
        item.current = d and d.qty or 0
    end
end

local function save()
    uoc.savef(DATA_FILE, dataItems)
end

local function addItem()
    changeitem = true
    clear()
    uoc.drawText(10,HEIGHT-7,"Вставьте предмет в 1-й слот ME интерфейса и введите параметры.",COLORS.ok)
    uoc.drawText(10,HEIGHT-6,"Название: ",COLORS.text)
    term.setCursor(20,HEIGHT-6)
    local name = tostring(io.read())
    uoc.drawText(10,HEIGHT-5,"Держать (число): ",COLORS.text)
    term.setCursor(29,HEIGHT-5)
    local count = tonumber(io.read())
    uoc.drawText(10,HEIGHT-4,"Крафт за раз (число): ",COLORS.text)
    term.setCursor(32,HEIGHT-4)
    local craftSize = tonumber(io.read())
    local stack = me.getStackInSlot(1)
    if stack then
        table.insert(dataItems, {name=name, id=stack.id, dmg=stack.dmg, count=count, craftSize=craftSize})
        save()
        uoc.addLog(logs, "Добавлен предмет: "..name,"INFO")
    else
        uoc.addLog(logs, "Ошибка: нет предмета в слоте 1!","ERROR")
    end
    changeitem = false
end

local function editItem()
    if not selectedItem then return uoc.addLog(logs,"Не выбран предмет!","ERROR") end
    local item = dataItems[selectedItem]
    clear()
    uoc.drawText(10,HEIGHT-7,"Изменение: "..item.name,COLORS.ok)
    uoc.drawText(10,HEIGHT-6,"Новое имя (Enter пропустить): ",COLORS.text)
    term.setCursor(40,HEIGHT-6)
    local name = tostring(io.read())
    if name and name ~= "" then item.name = name end
    uoc.drawText(10,HEIGHT-5,"Новое держать (число, Enter пропустить): ",COLORS.text)
    term.setCursor(54,HEIGHT-5)
    local count = tonumber(io.read())
    if count then item.count = count end
    uoc.drawText(10,HEIGHT-4,"Новый крафт за раз (число, Enter пропустить): ",COLORS.text)
    term.setCursor(55,HEIGHT-4)
    local cs = tonumber(io.read())
    if cs then item.craftSize = cs end
    save()
    uoc.addLog(logs, "Изменено: "..item.name,"INFO")
end

local function removeItem()
    if not selectedItem then return uoc.addLog(logs,"Не выбран предмет!","ERROR") end
    uoc.addLog(logs, "Удалён: "..dataItems[selectedItem].name,"WARN")
    table.remove(dataItems,selectedItem)
    selectedItem = nil
    save()
end

local function doCraft()
    isCrafting = true
    craftStatus = "Автокрафт..."
    save()
    uoc.addLog(logs,"Запущен автокрафт","INFO")
end

local function stopCraft()
    isCrafting = false
    craftStatus = "Остановлено"
    uoc.addLog(logs, "Остановлен автокрафт","WARN")
end

-------------------- Основной цикл автокрафта --------------------
local function autoCraftLoop()
    while true do
        if isCrafting then
            local now = computer.uptime()
            if now >= nextCraftUpdate then
                reload()
                for i, item in ipairs(dataItems) do
                    local details = me.getItemDetail({id=item.id, dmg=item.dmg}) or {qty=0}
                    item.current = details.qty
                    if details.qty < (item.count or 0) then
                        -- Автоматический выбор свободного CPU
                        local cpus = me.getCpus()
                        local freeCpu = nil
                        for _,cpu in ipairs(cpus) do
                            if not cpu.busy then freeCpu = cpu.name break end
                        end
                        if freeCpu then
                            local craftables = me.getCraftables({name=item.id, damage=item.dmg})
                            if craftables.n >= 1 then
                                local delta = math.min(item.craftSize or 1, item.count-details.qty)
                                local request = craftables[1].request(delta, false, freeCpu)
                                craftStatus = "Крафт: "..item.name
                                uoc.addLog(logs, "Крафт "..delta.."x "..item.name.." на CPU "..tostring(freeCpu),"INFO")
                            else
                                craftStatus = "Ошибка: нет рецепта "..item.name
                                uoc.addLog(logs, "Ошибка: нет рецепта "..item.name,"ERROR")
                            end
                        else
                            craftStatus = "Ошибка: нет свободных CPU"
                            uoc.addLog(logs, "Ошибка: нет свободных CPU","ERROR")
                        end
                    end
                end
                save()
                nextCraftUpdate = now + 5
            end
        end
        draw()
        os.sleep(0.2)
    end
end

-------------------- События --------------------
event.listen("touch", function(_,_,x,y,_,_)
    if changeitem then return end
    -- Кнопки
    if y >= HEIGHT-4 and y <= HEIGHT-2 then
        if x >= WIDTH-30 and x <= WIDTH-19 then
            if isCrafting then stopCraft() else doCraft() end
        elseif x >= WIDTH-15 and x <= WIDTH-4 then
            addItem()
        elseif x >= WIDTH-45 and x <= WIDTH-34 then
            editItem()
        elseif x >= WIDTH-60 and x <= WIDTH-49 then
            removeItem()
        end
    end
    -- Список предметов (выбор)
    if y >= 7 and y <= 30 then
        local showItems = uoc.filterItems(dataItems, search)
        local idx = itemScroll + (y-7)
        if showItems[idx] then
            for k,v in ipairs(dataItems) do
                if v == showItems[idx] then selectedItem = k break end
            end
        end
    end
    draw()
end)

event.listen("key_down", function(_,_,key,_,_)
    if changeitem then return end
    local showItems = uoc.filterItems(dataItems, search)
    if key == 200 then -- up
        itemScroll = math.max(1,itemScroll-1)
    elseif key == 208 then -- down
        itemScroll = math.min(math.max(1,#showItems-23),itemScroll+1)
    elseif key == 14 then -- backspace
        search = search:sub(1,-2)
    elseif key == 28 then -- enter
        -- не используется (можно для быстрого крафта)
    elseif key >= 32 and key < 128 then
        search = search .. unicode.char(key)
    end
    draw()
end)

-------------------- Старт --------------------
g.setResolution(WIDTH,HEIGHT)
reload()
draw()
autoCraftLoop()
