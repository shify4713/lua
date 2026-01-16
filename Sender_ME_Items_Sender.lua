local component = require("component")
local computer = require("computer")
local serialization = require("serialization")
local interface = component.me_interface
local modem = component.modem

local TYPE_MESSAGE = "DATA_ME_ITEMS_INFO"
local sendDataPort = 647
local receiveRequestPort = 16

local defaultSpeedTake = 10 --seconds

modem.open(receiveRequestPort)

local lastItems = {}
--[[
{{id = "dwcity:Vis_materia", dmg = 0}, {id = "dwcity:Vis_materia", dmg = 0}}
--]]
local function checkItemsInME(itemsToCheck)
    local checkedItems = {}
    local now = computer.uptime()
    for index = 1, #itemsToCheck do
        local itemToCheck = itemsToCheck[index]
        if interface.getItemDetail(itemToCheck) then
            local rawItem = interface.getItemDetail(itemToCheck)
            if rawItem then
                local itemInNetwork = rawItem.all()
                if itemInNetwork then
                    local itemChecked = {id = itemToCheck.id, dmg = itemToCheck.dmg, count = itemInNetwork.qty}
                    for inInd = 1, #lastItems do
                        local localItem = lastItems[inInd]
                        if localItem and localItem.id == itemToCheck.id and localItem.dmg == itemToCheck.dmg then
                            if localItem.totalCheckedTime then
                                local timeDiff = now - localItem.totalCheckedTime
                                if timeDiff >= 60 then
                                    local itemsDiff = itemChecked.count - localItem.totalCheckedCount
                                    local itemsPerSecond = itemsDiff / timeDiff
                                    itemChecked.itemsPerSecond = itemsPerSecond
                                    itemChecked.totalCheckedCount = itemChecked.count
                                    itemChecked.totalCheckedTime = now
                                else
                                    itemChecked.itemsPerSecond = localItem.itemsPerSecond
                                    itemChecked.totalCheckedCount = localItem.totalCheckedCount
                                    itemChecked.totalCheckedTime = localItem.totalCheckedTime
                                end
                            else
                                itemChecked.itemsPerSecond = 0
                                itemChecked.totalCheckedCount = itemChecked.count
                                itemChecked.totalCheckedTime = now
                            end
                            break
                        end
                    end
                    table.insert(checkedItems, itemChecked)
                end
            end
        end
    end
    lastItems = checkedItems
    return checkedItems
end

while true do
    print("Ожидаю запроса информации о МЭ предметах от хоста.")
    local eventName, address, senderAddress, port, distance, message = computer.pullSignal("modem_message")
    if message then
        local messageUnserialized = serialization.unserialize(message)

        if messageUnserialized and port == receiveRequestPort and messageUnserialized.type_data == TYPE_MESSAGE and messageUnserialized.itemsToCheck then
            local checkedItems = checkItemsInME(messageUnserialized.itemsToCheck)
            local sendData = serialization.serialize({ type_data = TYPE_MESSAGE, payload = checkedItems })
            modem.broadcast(sendDataPort, sendData)
            print("Информация отправлена. "..sendData)
        end
    end

end