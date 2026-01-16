local component = require("component")
local robot = require("robot")
local redstone = component.redstone
local inventoryController = component.inventory_controller
local modem = component.modem
local event = require("event")
local sides = require("sides")
local serialization = require("serialization")
local isInProgress = false
local broadcastPort = 51
local BROADCAST_TYPE = "REQUEST_TELEPORT"

modem.open(broadcastPort)
robot.select(1)

local zeroCardName = "ZERO_POINT"
local function launchWithCard(teleportItemCard)
    robot.select(1)
    local tpCardTook = false
    local zeroCardTook = false

    local inventorySize = inventoryController.getInventorySize(sides.bottom)
    for index = 1, inventorySize do
        --take zero card
        --take normal card
        local item = inventoryController.getStackInSlot(sides.bottom, index)
        if item and item.label == zeroCardName then
            print("Took zero card")
            inventoryController.suckFromSlot(sides.bottom, index)
            zeroCardTook = true
        end
        if item and item.label == teleportItemCard.display_name then
            print("Took tp card")
            inventoryController.suckFromSlot(sides.bottom, index)
            tpCardTook = true
        end
        if zeroCardTook and tpCardTook then
            break
        end
    end
    for innInd = 1, robot.inventorySize() do
        --setup with zero card
        local item = inventoryController.getStackInInternalSlot(innInd)
        if item and item.label == zeroCardName then
            print("Found zero card inner")
            robot.select(innInd)
            inventoryController.equip()
            robot.use(sides.front, true)
            print("Used zero card inner")
            break
        end
    end
    --activate_redstone
    print("Set redstone output")
    redstone.setOutput(sides.front, 15)
    os.sleep(0.01)
    redstone.setOutput(sides.front, 0)
    for innInd = 1, robot.inventorySize() do
        --setup with zero card
        local item = inventoryController.getStackInInternalSlot(innInd)
        if item and item.label == teleportItemCard.display_name then
            robot.select(innInd)
            inventoryController.equip()
            robot.use(sides.front, true)
            print("Used actual card")

            --back cards to chest
            robot.dropDown()
            print("Back zero card to chest")
            inventoryController.equip()
            robot.dropDown()
            print("Back actual card to chest")
            break
        end
    end
end

local function handleBroadcast(_, _, _, port, _, message)
    if message then
        local messageUnserialized = serialization.unserialize(message)
        if port == broadcastPort and messageUnserialized.type == BROADCAST_TYPE then
            if not isInProgress then
                isInProgress = true
                print("Запрос на телепорт в "..messageUnserialized.payload.display_name.. " получен")
                launchWithCard(messageUnserialized.payload)
                isInProgress = false
            end
        end
    end
end

event.listen("modem_message", handleBroadcast)

while true do
    event.pull()
end