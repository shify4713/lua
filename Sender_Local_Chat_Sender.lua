local component = require("component")
local serialization = require("serialization")
local fs = require("filesystem")
local event = require("event")
local modem = component.modem or error("no modem found")

local TYPE_MESSAGE = "DATA_LOCAL_CHAT"
local sendDataPort = 647
local receiveRequestPort = 21

modem.open(receiveRequestPort)

local gpu = component.gpu

local chatLog_path = "chat_log.txt"

local adminsList = {
    {name = "4epB9Ik", color = "§6", type = "ADMIN"},
    {name = "DevilPuppy", color = "§6", type = "ADMIN"},
    {name = "CharleyRog", color = "§6", type = "ADMIN"},
    {name = "Noise71", color = "§6", type = "ADMIN"},
    {name = "_FATALITY_", color = "§6", type = "BUILDER"},
    {name = "Murzoid", color = "§6", type = "BUILDER"},
    {name = "LilPodupiPUPI", color = "§6", type = "ADMIN"},
    {name = "KyKyPy3a", color = "§6", type = "ADMIN"},
    {name = "max32", color = "§6", type = "TRAINEE"}
}

function splByToken(str, token)
    local t = {}
    local tempStr = ""
    local i = 1

    while i <= str:len() do
        if (string.sub(str, i, i) == "&") then
            table.insert(t, tempStr)
            tempStr = ""
        end

        tempStr = tempStr .. string.sub(str, i, i)
        i = i + 1

    end

    if (tempStr ~= "") then
        table.insert(t, tempStr)
    end

    return t
end

function writeMessage(text)
    if (string.sub(text, 1, 1) == "!") then
        text = string.sub(text, 2)
    end
    local t = splByToken(text, "&")

    for k, v in pairs(t) do
        if (not isColored(v)) then
            gpu.setForeground(0xFFFFFF)
            io.write(v)
        else
            setColor(string.sub(v, 2, 2))
            io.write(string.sub(v, 3))
        end
    end
end

function pcMsg(nick, msg) -- вывод строки в компе
    local type = ""
    if (not isGlobal(msg)) then
        if (msg ~= ".........") then
            type = "L"
            local file = fs.open(chatLog_path, "a")
            file:write("[" .. type .. "] " .. nick .. ": " .. msg .. "\n")
            file:close()

            gpu.setForeground(0x00FFFF)
            io.write(" ")
            gpu.setForeground(0xFFFFFF)
            if (type == "G") then
                gpu.setForeground(0xFF9933)
            else
                gpu.setForeground(0xFFFFFF)
            end
            io.write("[" .. type .. "] ")
            gpu.setForeground(0x00FF00)
            io.write(nick)
            gpu.setForeground(0xFFFFFF)
            io.write(": ")
            writeMessage(msg)
            io.write("\n")
        end
    end
end

function stringToArray(text)
    t = {}
    text:gsub(".", function()
        table.insert(t, c)
    end)
    return t
end

function countOfItems(arr)
    Count = 0
    for k, v in ipairs(arr) do
        Count = Count + 1
    end
    return Count
end

function isColored(text)
    if (string.sub(text, 1, 1) == "&") then
        return true
    else
        return false
    end
end

-- Проверяет в глобальном ли чате написано сообщение
function isGlobal(msg)

    if (string.sub(msg, 1, 1) == "!") then
        return true
    else
        return false
    end
end

-- возвращает оформленную строку с сообщением вида [23:12] [G] player: Hello
function message(nick, msg)
    if (not isGlobal(msg)) then
        if (msg ~= ".........") then
            local type = "§fL"
            local file = fs.open(chatLog_path, "a")

            file:write("[" .. type .. "] " ..nick .. ": " .. msg .. "\n")
            for index = 1, #adminsList do
                if adminsList[index].name == nick then
                    return "§8[" .."&5"..adminsList[index].type .. "§8] " .. adminsList[index].color.. nick .. "§f: " .. msg
                end
            end
            return "§8[" .. type .. "§8] " .. "§7".. nick .. "§f: " .. msg
        end
    end
end
--§
local messages = {}

local function monitorMessages(_, add, nick, msg)
    local type = isGlobal(msg)
    local color = 0x52ff00

    local cof = countOfItems(messages)

    table.insert(messages, 1, message(nick, msg, type))

    if (cof > 16) then
        table.remove(messages, 16)
    end
end

local function handleEvent(_, _, _, port, _, message)
    if message then
        print("Ожидаю запроса информации о ЛОКАЛЬНОМ ЧАТЕ от хоста.")
        local messageUnserialized = serialization.unserialize(message)
        if port == receiveRequestPort and messageUnserialized.type_data == TYPE_MESSAGE then
            local sendData = serialization.serialize({ type_data = TYPE_MESSAGE, payload = messages })
            modem.broadcast(sendDataPort, sendData)
            print("Информация отправлена.")
        end
    end
end

-- Регистрируем обработчик событий
event.listen("modem_message", handleEvent)
event.listen("chat_message", monitorMessages)

while true do
    event.pull()
end