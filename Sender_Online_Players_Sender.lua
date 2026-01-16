local computer = require("computer")
local component = require("component")
local serialization = require("serialization")
local chat_box = component.chat_box
local modem = component.modem

local TYPE_MESSAGE = "DATA_ONLINE_CHECKER"
local sendDataPort = 647
local receiveRequestPort = 15

local localize = {
    join_in_game = " §7вошел в игру!",
    left_from_game = " §7покинул игру!"
}
local players = { }
local admin = "Krobys"

function checkOnline(n)
    computer.removeUser(admin)
    if computer.addUser(players[n].name) then
        computer.removeUser(players[n].name)
        if not players[n].isJoin then
            if chat_box then
                chat_box.say("§a"..players[n].name .. localize.join_in_game)
            end
            players[n].isJoin = true
        end
        return true
    else
        if players[n].isJoin then
            if chat_box then
                chat_box.say("§c"..players[n].name .. localize.left_from_game)
            end
            players[n].isJoin = false
        end
        computer.removeUser(players[n].name)
        return false
    end
end

function checkUsersOnline()
    for index = 1, #players do
        if not players[index].isHideOnline then
            checkOnline(index)
        end
    end
    return players
end

modem.open(receiveRequestPort)

while true do
    print("Ожидаю запроса информации о ОНЛАЙН ИГРОКАХ от хоста.")
    local _, _, _, port, _, message = computer.pullSignal("modem_message")
    if message then
        local messageUnserialized = serialization.unserialize(message)
        if port == receiveRequestPort and messageUnserialized.type_data == TYPE_MESSAGE and messageUnserialized.playersToCheck then
            players = messageUnserialized.playersToCheck
            local checkedPlayers = checkUsersOnline()
            local sendData = serialization.serialize({ type_data = TYPE_MESSAGE, payload = checkedPlayers })
            modem.broadcast(sendDataPort, sendData)
            print("Информация отправлена.")
        end
    end
end