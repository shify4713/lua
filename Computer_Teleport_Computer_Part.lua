local component = require("component")
local GUI = require("GUI")
local chest = component.diamond or component.chest
local chestSize = chest.getInventorySize()
local modem = component.modem
local serialization = require("serialization")
local computer = require("computer")
local text = require("text")
local event = require("event")
local broadcastPort = 51
local BROADCAST_TYPE = "REQUEST_TELEPORT"

local zeroPointName = "ZERO_POINT"

local leftBorder = 2
local topBorder = 6

local application = GUI.application()
local buttonsInLine = 5
local buttonsGap = 1
local buttonWidth = math.floor((application.width / buttonsInLine) - (buttonsGap * 2))
local buttonHeight = 1

application:addChild(GUI.panel(1, 1, application.width, application.height, 0x262626))
local containerButtons = application:addChild(GUI.container(1, 1, application.width, application.height))
local topInfoText = application:addChild(GUI.text(2, 2, 0xFFFFFF, ""))
topInfoText.hidden = true
local infoText = application:addChild(GUI.text(2, 3, 0xFFFFFF, " "))
infoText.hidden = true

local buttons = {}

local function onFilterByInput(input)
    local trimmedInput = text.trim(input)
    for ind = 1, #buttons do
        local button = buttons[ind]
        if trimmedInput == "" or string.find(button.text, trimmedInput) then
            button.hidden = false
        else
            button.hidden = true
        end
    end
    application:draw()
end

local input = application:addChild(GUI.input(leftBorder + (buttonWidth + buttonsGap) * 3, 2, buttonWidth, 3, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, "", "Фильтр точек"))
input.onInputFinished = function()
    onFilterByInput(input.text)
end

local function sendRequestToRobotForTeleport(teleportItem)
    local requestSerialised = serialization.serialize({type = BROADCAST_TYPE, payload = teleportItem})
    modem.broadcast(broadcastPort, requestSerialised)
end

local function requestTeleport(teleportItem)
    local isZeroPointPresent = false
    for ind = 1, chestSize do
        if chest.getStackInSlot(ind) then
            if chest.getStackInSlot(ind).display_name == zeroPointName then
                isZeroPointPresent = true
                break
            end
        end
    end
    if isZeroPointPresent then
        infoText.text = "Запрошен телепорт в ".."["..teleportItem.display_name.."]"
        infoText.hidden = false
        application:draw()
        sendRequestToRobotForTeleport(teleportItem)
        computer.pullSignal(3)
        infoText.hidden = true
        topInfoText.text = "Последний телепорт: "..teleportItem.display_name
        topInfoText.hidden = false
        application:draw()
    else
        infoText.text = "ДРУГОЙ ТЕЛЕПОРТ УЖЕ В ПРОЦЕССЕ"
        infoText.hidden = false
        application:draw()
        computer.pullSignal(3)
        infoText.hidden = true
        application:draw()
    end
end

local function checkCoordinatesInChest()
    containerButtons:removeChildren()
    buttons = {}
    local currentX = leftBorder
    local currentY = topBorder
    local ind = 1
    for index = 1, chestSize do
        local itemInChest = chest.getStackInSlot(index)
        if itemInChest and itemInChest.display_name ~= zeroPointName then
            local button = containerButtons:addChild(GUI.button(currentX, currentY, buttonWidth, buttonHeight, 0xFFFFFF, 0x000000, 0xCCCCCC, 0xFFFFFF, itemInChest.display_name))
            button.animated = false
            button.onTouch = function()
                if itemInChest then
                    requestTeleport(itemInChest)
                end
            end
            table.insert(buttons, button)
            currentX = currentX + buttonWidth + buttonsGap
            if (ind % buttonsInLine) == 0 then -- start a new line after buttonsInLine items
                currentX = leftBorder
                currentY = currentY + buttonHeight + buttonsGap
            end
            ind = ind + 1
        end
    end
end

local function refresh()
    checkCoordinatesInChest()
    infoText.text = "Список обновлён!"
    infoText.hidden = false
    application:draw()
    computer.pullSignal(3)
    infoText.hidden = true
    application:draw()
end

function event.shouldInterrupt()
    return false
end

local refreshButton = application:addChild(GUI.button(leftBorder + (buttonWidth + buttonsGap) * 2, 2, buttonWidth, 3, 0xFFFFFF, 0x000000, 0xCCCCCC, 0xFFFFFF, "Обновить список"))
refreshButton.animated = false
refreshButton.onTouch = function()
    refresh()
end

checkCoordinatesInChest()

application:draw()
application:start()