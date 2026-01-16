local config = {
    -- maxCoreEnergy - на этом уровне будет поддерживаться количество энергии в ядре
    -- 1000 * 10^9 соответсвунт 1000 B или 1 T
    maxCoreEnergy = 10 * 10^9,
    maxDiffEnergy = 20000, -- максимальная скорость накапливания энергии Rf/t, тестировалось на этом значении
    step = 10000,  -- шаг изменния значения на гейте
    step2 = 50000, -- шаг на кнопку
    sleepTime = 0.1, -- шаг замеров в сек
}

local keyb = require("keyboard")
local event = require("event")
local term = require("term")
local unicode = require("unicode")
local com = require('component')
local gpu = com.gpu
local w, h = 80 , 25


gpu.setResolution(w, h) -- lvl 2

local function coreEnergy()
    return com.draconic_rf_storage.getEnergyStored()
end

local function format(num)
    if num >= 10^12 then
        return string.format("%0.3f T", num/10^12)
    elseif num >= 10^9 then
        return string.format("%0.3f B", num/10^9)
    elseif num >= 10^6 then
        return string.format("%0.3f M", num/10^6)
    elseif num >= 10^3 then
        return string.format("%0.3f K", num/10^3)
    else
        return string.format("%d", num)
    end
end

local filVal = 0
function expRunningAvg(newVal)
    filVal = filVal + ((newVal-filVal) * 0.3)
    return filVal
end

if false == com.isAvailable("draconic_rf_storage") then
    print("Rf storage not connected!")
    os.exit()
end

if false == com.isAvailable("flux_gate") then
    print("Flux gate not connected!")
    os.exit()
end

local time = os.time()
local energy = coreEnergy()

function asbMax(t)
    local  max = t[1]
    for _, val in ipairs(t) do
        if math.abs(val) > max then
            max = math.abs(val)
        end
    end

    return max
end

local _MID = h/2 + 3
local _NUM_READ = w
local energyLog = {}
local current = 0

function displayGraph(diff)
    current = current + 1
    if current > _NUM_READ then
        current = 1
    end

    energyLog[current] = diff

    local maxVal = asbMax(energyLog)

    gpu.fill(1, _MID, w, 1, '━')
    local row = 1
    for i = current, _NUM_READ + current - 1 do
        local key = i % w + 1

        if energyLog[key] then
            local d = (math.ceil(energyLog[key] / (maxVal * 0.1)))
            if d > 0 then
                gpu.setForeground(0x00ff00)
                gpu.fill(row, _MID-d, 1, d, '█')
            else
                gpu.setForeground(0xff0000)
                gpu.fill(row, _MID+1, 1, math.abs(d), '█')

            end
        end
        row = row + 1
    end
end

local serialization = require("serialization")
local modem = com.modem or error("НЕТ МОДЕМА (Плата беспроводной сети)")

local TYPE_MESSAGE = "DATA_REACTOR_STORAGE"
local sendDataPort = 647
local receiveRequestPort = 22

local function handleEventBroadcast(_, _, _, port, _, message)
    if message then
        local messageUnserialized = serialization.unserialize(message)
        if port == receiveRequestPort and messageUnserialized.type_data == TYPE_MESSAGE then
            local fluxGateFlow  = com.flux_gate.getFlow()
            local energyStored = com.draconic_rf_storage.getEnergyStored()
            local sendData = serialization.serialize({ type_data = TYPE_MESSAGE, payload = { fluxGateFlow = fluxGateFlow,
                                                                                             energyStored = energyStored } })
            modem.broadcast(sendDataPort, sendData)
        end
    end
end

modem.open(receiveRequestPort)
event.listen("modem_message", handleEventBroadcast)

function displayData(core, diff, action, fluxGateFlow)
    gpu.fill(1, 1, w, h, " ")
    gpu.set(3, 1, string.format("Энергии в ядре: %s [%0.0f Rf]", format(core), core))
    gpu.set(3, 2, string.format("Выход на гейте: %s Rf [%0.0f Rf]  %s", format(fluxGateFlow), fluxGateFlow, action))
    gpu.set(3, 3, string.format('Накопление энергии: %0.1f Rf/t', diff))
    gpu.set(w - unicode.len("Поддерживание : "..format(config.maxCoreEnergy).." "), 1,string.format("Поддерживание : %s", format(config.maxCoreEnergy), config.maxCoreEnergy)) -- вывод поддерживание энергии by BG
    gpu.setBackground(0xFFFFFF)
    gpu.setForeground(0x000000)
    gpu.set(73, 2, " + ")
    gpu.set(77, 2, " - ")
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
    displayGraph(diff)
end


local running = true


function touch (w, h)
    local StepButton = 10^9

    if keyb.isControlDown() then
        StepButton = 5 * 10^10
    elseif keyb.isShiftDown() then
        StepButton = 10^11
    end
    if w >= 73 and w <= 75 and h == 2 then
        config.maxCoreEnergy = config.maxCoreEnergy + StepButton
        gpu.setBackground(0x00FF00)
        gpu.set(73 , 2, " + ")
        gpu.setBackground(0x000000)
    elseif w >= 77 and w <= 79 and h == 2 then
        config.maxCoreEnergy = config.maxCoreEnergy - StepButton
        gpu.setBackground(0xFF0000)
        gpu.set(77 , 2, " - ")
        gpu.setBackground(0x000000)

    end
end

while running do

    term.setCursor(1,1)
    gpu.setForeground(0xffffff)
    os.sleep(config.sleepTime)

    local tmpEnergy = coreEnergy()
    local tmpTime = os.time()

    local energyDiff = tmpEnergy - energy
    local timeDiff = tmpTime - time

    local diff = expRunningAvg(energyDiff / timeDiff)

    local fluxGateFlow  = com.flux_gate.getFlow()


    local action = ""



    if tmpEnergy > config.maxCoreEnergy then
        if diff > (config.maxDiffEnergy * -1) and
                fluxGateFlow < 17000000 then  -- не больше (and fluxGateFlow < 17000000) by BG
            action = 'Повышаю ▲'
            com.flux_gate.setSignalLowFlow(fluxGateFlow + config.step)
        end
    else
        if diff < config.maxDiffEnergy and fluxGateFlow > 300000 then
            action = 'Понижаю ▼'
            com.flux_gate.setSignalLowFlow(fluxGateFlow - config.step)
        end
    end

    displayData(tmpEnergy, diff, action, fluxGateFlow)

    local e,_,w,h,_,_ = event.pull(0.1, "touch")
    if e == "touch" then
        touch(w, h)
    end

    time = tmpTime
    energy = tmpEnergy
end
