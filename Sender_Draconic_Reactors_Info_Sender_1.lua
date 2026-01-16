local component = require("component")
local computer = require("computer")
local serialization = require("serialization")
local modem = component.modem

local TYPE_MESSAGE = "DATA_DRACONIC_REACTOR"
local sendDataPort = 647
local receiveRequestPort = 18

modem.open(receiveRequestPort)

local function getDraconicReactorsInfo()
    local reactorsInfo = {}
    local reactors = component.list("draconic_reactor")
    for reactorId, componentName in pairs(reactors) do
        local reactor = component.proxy(reactorId)
        local reactorInfo = reactor.getReactorInfo()
        local infoData = { fuelConversion = reactorInfo.fuelConversion,
                           maxFuelConversion = reactorInfo.maxFuelConversion,
                           percent = reactorInfo.fuelConversion / reactorInfo.maxFuelConversion,
                           isActive = reactorInfo.status == "online"
        }
        reactorsInfo[reactorId] = infoData
    end
    return reactorsInfo
end

-- {type_data = ..., payload = {sadasdsa = {fuelConversion, maxFuelConversion, percent}}}
while true do
    print("Ожидаю запроса информации о РЕАКТОРАХ от хоста.")
    local eventName, address, senderAddress, port, distance, message = computer.pullSignal("modem_message")
    if message then
        local messageUnserialized = serialization.unserialize(message)
        if port == receiveRequestPort and messageUnserialized.type_data == TYPE_MESSAGE then
            local dcInfo = getDraconicReactorsInfo()
            local sendData = serialization.serialize({ type_data = TYPE_MESSAGE, payload = dcInfo })
            modem.broadcast(sendDataPort, sendData)
            print("Информация отправлена.")
        end
    end
end