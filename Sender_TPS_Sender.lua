local fs = require("filesystem")
local component = require("component")
local computer = require("computer")
local serialization = require("serialization")
local modem = component.modem

local TYPE_MESSAGE = "DATA_TPS"
local sendDataPort = 647
local receiveRequestPort = 13

modem.open(receiveRequestPort)

function time()
    local f = fs.open("/tmp/timeFile","w")
    f:write("test")
    f:close()
    return(fs.lastModified("/tmp/timeFile"))
end

timeConstant = 1
joke = 0
tSlot = 1
TPS = {}
avgTPS = 0
for tSlot=1,10 do
    TPS[tSlot]=0
end

function getCurrentTPS()
    realTimeOld = time()
    os.sleep(timeConstant)
    realTimeNew = time()
    realTimeDiff = realTimeNew-realTimeOld
    TPS[tSlot] = 20000*timeConstant/realTimeDiff
    avgTPS = (TPS[1]+TPS[2]+TPS[3]+TPS[4]+TPS[5]+TPS[6]+TPS[7]+TPS[8]+TPS[9]+TPS[10])/10
    if tSlot == 10 then
        tSlot = 0
    end
    tSlot = tSlot + 1
    return TPS[tSlot]
end

while true do
    print("Ожидаю запроса информации о ТПС от хоста.")
    local eventName, address, senderAddress, port, distance, message = computer.pullSignal("modem_message")
    if message then
        local messageUnserialized = serialization.unserialize(message)
        if port == receiveRequestPort and messageUnserialized.type_data == TYPE_MESSAGE then
            local tps = getCurrentTPS()
            local sendData = serialization.serialize({ type_data = TYPE_MESSAGE, payload = {tps = tps, avgTps = avgTPS} })
            modem.broadcast(sendDataPort, sendData)
            print("Информация отправлена.")
        end
    end
end