local component = require("component")
local computer = require("computer")
local serialization = require("serialization")
local fs = require("filesystem")
local event = require("event")
local text = require("text")
local charWidthLib = require("charsCheckerLib")

local peripherals = {
    bridge = component.openperipheral_bridge or error("No openperipheral_bridge available"),
    sensor = nill,
    modem = component.modem
}

local onlinePlayers = {
    { name = "Nyampir", isJoin=false, isHideOnline = false},
    { name = "OSSO", isJoin=false, isHideOnline=false},
    { name = "Alpaka_Masha", isJoin=false, isHideOnline=false},
    { name = "LiwMorgan", isJoin=false, isHideOnline=false}
}

local players = {
    { name = "Nyampir", isJoin =false, isHideOnline = false},
    { name = "OSSO", isJoin = false, isHideOnline = true},
    { name = "Alpaka_Masha", isJoin=false, isHideOnline = true},
    { name = "LiwMorgan", isJoin = false, isHideOnline = true},

    {name = "4epB9Ik", isJoin = false, isHideOnline = true},
    {name = "DevilPuppy", isJoin = false, isHideOnline = true},
    {name = "CharleyRog", isJoin = false, isHideOnline = true},
    {name = "Noise71", isJoin = false, isHideOnline = true},
    {name = "_FATALITY_", isJoin = false, isHideOnline = true},
    {name = "Murzoid", isJoin = false, isHideOnline = true},
    {name = "LilPodupiPUPI", isJoin = false, isHideOnline = true},
    {name = "KyKyPy3a", isJoin = false, isHideOnline = true},
    {name = "Grenadinio", isJoin = false, isHideOnline = true},
    {name = "Musik255", isjoin = false, isHideOnline = true}
}

-------------{TIME OPTIONS}------------------
local TIME_ZONE = 3 --Ваш часовой пояс
local t_correction = TIME_ZONE * 3600
---------------------------------------------

local settings = {
    tps = true, --показывать ли тпс
    me_items = true,--мониторить вещи в мэ
    sensor_players = true,--показывать игроков поблизост
    player_items = true, --вещи игроков
    players_online = true, --мониторить игроков онлайн
    chat_box = true,--сообщения в чат о заходе выходе из игры
    local_chat = true,--показывать локальный чат (сейчас не активно)
    dc_reactors_info = true, --выводить инфу с реакторов
    memory_monitoring = true,--мониторить текущую память компа
    admin = "OSSO", --администратор компа
    chat_box_name = "§8[§4Алиса§8]"--имя чат бокса который отправляет уведомление в чат
}

defaultSlotValue = 18

local constraints = {
    leftBorderAbsolute = defaultSlotValue / 2,
    topBorderAbsolute = defaultSlotValue / 2,

    timeTextWidth = defaultSlotValue * 5,

    nickname_width = defaultSlotValue * 4,
    online_value_width = defaultSlotValue * 3,

    tpsTextWith = defaultSlotValue * 3,
    tpsValueWidth = defaultSlotValue * 2,

    me_item_width = defaultSlotValue * 4,

    players_near_title_width = defaultSlotValue * 4,

    monitoring_me_title_width = defaultSlotValue * 5,

    status_player_title_width = defaultSlotValue * 5,
    status_player_box_width = defaultSlotValue,

    memory_status_width = defaultSlotValue * 6,

    dc_reactor_info_width = defaultSlotValue * 4,
    dc_reactor_status_size = defaultSlotValue * 0.48,
    slot_height_75 = defaultSlotValue * 0.75,
    slot_height_60 = defaultSlotValue * 0.6,

    experience_slot_width = defaultSlotValue * 4,

    messages_local_chat_width = defaultSlotValue * 14, --ширина локального чата 11 стандартных клеток
    messages_local_chat_height = defaultSlotValue * 7,--высота локального чата 7 стандартных клеток
}

local localize = {
    time = "Время:",
    tps = "TPS:",
    avg_tps = "Avg TPS:",
    join_in_game = " §7вошел в игру!",
    left_from_game = " §7покинул игру!",
    user_online = "online",
    user_offline = "offline",
    near_ME = "Игроки рядом",
    monitoring_me_title = "Мониторинг МЭ",
    status_players_title = "Статус игроков",
    level_mask = "Уровень: %d",
    dc_info_mask = "%.2f %%" --маска для отображения инфы дк реактора
}
local colors = {
    time_color = 0x0000CD, --Время 00:00:00
    tps_title_color = 0x0000CD, --TPS и Avg TPS
    tps_value_color = 0x0000CD, --значения тпс цвет
    monitoring_me_title_color = 0x0000CD, --Мониторинг МЭ надпись
    monitoring_me_item_count_color = 0x0000CD, --Мониторинг МЭ цвет количества
    players_near_title_color = 0x0000CD, --Игроки поблизости цвет
    player_near_nickname_color = 0x0000CD, --Цвет никнейма игрока поблизости
    player_status_title_color = 0x0000CD, --Статус игроков цвет надписи
    player_status_nickname_color = 0x0000CD, --Никнейм статуса игроков цвет
    player_status_online_color = 0x00FF00, --цвет бокса при онлайн игроке
    player_status_offline_color = 0xFF0000, --цвет бокса при оффлайн игроке
    memory_info_color = 0x0000CD, --Память 200 MB/4134 MB - цвет
    memory_percent_color = 0x0000CD, --Проценты памяти 40% цвет

    white = 0xFFFFFF,
    charge_level_color = 0x55FF55, --заряд предметов цвет заряда (зеленый)
    not_charge_level_color = 0x000000,

    dc_reactor_good_color = 0x00FF00, --цвет при топливе до 45%
    dc_reactor_medium_color = 0xFFFF00,--цвет при топливе до 85%
    dc_reactor_bad_color = 0xFF0000,--цвет при топливе после 85%
    dc_text_good_color = 0xFFFFFF,--цвет процентов топлива реактора
    dc_text_medium_color = 0x000000,--цвет процентов топлива реактора
    dc_text_bad_color = 0xFFFFFF,--цвет процентов топлива реактора

    local_chat_message_color = 0x000000 --цвет сообщений локального чата
}

local absoluteYIndex = constraints.topBorderAbsolute

local receiverDataPort = 647

local message_types = {
    DATA_TPS = {type = "DATA_TPS", requestPort = 13},
    DATA_ME_ITEMS_INFO = {type = "DATA_ME_ITEMS_INFO", requestPort = 16},
    DATA_LOCAL_CHAT = {type = "DATA_LOCAL_CHAT", requestPort = 21},
    DATA_PLAYERS_NEAR = {type = "DATA_PLAYERS_NEAR", requestPort = 17},
    DATA_ONLINE_CHECKER = {type = "DATA_ONLINE_CHECKER", requestPort = 15},
    DATA_DRACONIC_REACTOR = {type = "DATA_DRACONIC_REACTOR", requestPort = 18},
    DATA_REACTOR_STORAGE = {type = "DATA_REACTOR_STORAGE", requestPort = 22}
}

local message_types_keys_drawing = {
    message_types.DATA_TPS.type,
    message_types.DATA_ME_ITEMS_INFO.type,
    message_types.DATA_LOCAL_CHAT.type,
    message_types.DATA_DRACONIC_REACTOR.type,
    message_types.DATA_REACTOR_STORAGE.type,
    message_types.DATA_ONLINE_CHECKER.type,
    message_types.DATA_PLAYERS_NEAR.type,
}

local items = {
    {id = "dwcity:Vis_materia", dmg = 0},
    {id = "AdvancedSolarPanel:BlockAdvSolarPanel", dmg = 0}
}

function addBox(x, y, w, h, color, tran)
    peripherals.bridge.addBox(x, y, w, h, color, tran)
end

function addText(x, y, text, color)
    peripherals.bridge.addText(x, y, text, color)
end

function addIcon(x, y, name, meta)
    peripherals.bridge.addIcon(x, y, name, meta)
end

local function drawSlot(x, y, slotWidth, slotHeight, textToDrawInSlot, textColorToDrawInSlot, bgColor, percentsBgColor, alpha)--percents 0.52
    local borderColor = 0xFFFFFF
    local borderWidth = 1

    peripherals.bridge.addLine({ x, y }, { x, y + slotHeight }, borderColor)
    peripherals.bridge.addLine({ x + slotWidth, y }, { x + slotWidth, y + slotHeight }, borderColor)
    peripherals.bridge.addLine({ x, y }, { x + slotWidth, y }, borderColor)
    peripherals.bridge.addLine({ x, y + slotHeight }, { x + slotWidth, y + slotHeight}, borderColor)
    if percentsBgColor then
        local boxWidthPercents = (slotWidth - 2) * percentsBgColor
        peripherals.bridge.addBox(x + borderWidth, y + borderWidth, slotWidth - 2, slotHeight - 2, 0xCCCCCC, 0.5)
        peripherals.bridge.addBox(x + borderWidth, y + borderWidth, boxWidthPercents, slotHeight - 2, bgColor, 0.8)
    else
        peripherals.bridge.addBox(x + borderWidth, y + borderWidth, slotWidth - 2, slotHeight - 2, bgColor or 0xCCCCCC, alpha or 0.5)
    end

    if textToDrawInSlot and textColorToDrawInSlot then
        local marginTop = (slotHeight - 8) / 2
        addText(x + 3, y + marginTop, textToDrawInSlot, textColorToDrawInSlot)
    end
end

function drawTps(tpsPayload)
    drawSlot(constraints.leftBorderAbsolute, absoluteYIndex, constraints.tpsTextWith, constraints.slot_height_60, localize.tps, colors.tps_title_color)
    drawSlot(constraints.leftBorderAbsolute + constraints.tpsTextWith, absoluteYIndex, constraints.tpsValueWidth, constraints.slot_height_60, string.format("%.2f",tpsPayload.tps), colors.tps_value_color)
    absoluteYIndex = absoluteYIndex + constraints.slot_height_60
    drawSlot(constraints.leftBorderAbsolute, absoluteYIndex, constraints.tpsTextWith, constraints.slot_height_60, localize.avg_tps, colors.tps_title_color)
    drawSlot(constraints.leftBorderAbsolute + constraints.tpsTextWith, absoluteYIndex, constraints.tpsValueWidth, constraints.slot_height_60, string.format("%.2f",tpsPayload.avgTps), colors.tps_value_color)
    absoluteYIndex = absoluteYIndex + constraints.slot_height_60
end

function drawMEInfo(itemsMECounted)
    if itemsMECounted then
        drawSlot(constraints.leftBorderAbsolute, absoluteYIndex, constraints.monitoring_me_title_width, constraints.slot_height_60, localize.monitoring_me_title, colors.monitoring_me_title_color)
        absoluteYIndex = absoluteYIndex + constraints.slot_height_60
        for i = 1, #itemsMECounted do
            local itemCount = string.format("%u %.2f/с", itemsMECounted[i].count, itemsMECounted[i].itemsPerSecond or 0)
            drawSlot(constraints.leftBorderAbsolute, absoluteYIndex, defaultSlotValue, constraints.slot_height_60)
            addIcon(constraints.leftBorderAbsolute + 1, absoluteYIndex - 3, itemsMECounted[i].id, itemsMECounted[i].dmg)
            drawSlot(constraints.leftBorderAbsolute + defaultSlotValue, absoluteYIndex, constraints.me_item_width, constraints.slot_height_60, itemCount, colors.monitoring_me_item_count_color)
            absoluteYIndex = absoluteYIndex + constraints.slot_height_60
        end
    end
end

local function drawDraconicReactorsInfo(info)
    if settings.dc_reactors_info then
        absoluteYIndex = constraints.topBorderAbsolute
        local x = constraints.leftBorderAbsolute + constraints.timeTextWidth
        for dcReactorId, dcInfo in pairs(info) do-- {sadasdsa = {fuelConversion, maxFuelConversion, percent}}
            local dcInfoText = string.format(localize.dc_info_mask, dcInfo.percent * 100)
            local bgColor = dcInfo.percent < 0.45 and colors.dc_reactor_good_color
                    or dcInfo.percent < 0.85 and colors.dc_reactor_medium_color
                    or dcInfo.percent > 0.85 and colors.dc_reactor_bad_color
            local textColor = dcInfo.percent < 0.45 and colors.dc_text_good_color
                    or dcInfo.percent < 0.85 and colors.dc_text_medium_color
                    or dcInfo.percent > 0.85 and colors.dc_text_bad_color
            drawSlot(x, absoluteYIndex, constraints.dc_reactor_info_width - constraints.dc_reactor_status_size, defaultSlotValue * 0.48, dcInfoText, textColor, bgColor, dcInfo.percent)
            local statusBgColor = dcInfo.isActive and colors.player_status_online_color or colors.player_status_offline_color
            drawSlot(x + constraints.dc_reactor_info_width - constraints.dc_reactor_status_size, absoluteYIndex, constraints.dc_reactor_status_size, constraints.dc_reactor_status_size, nil, nil, statusBgColor)
            absoluteYIndex = absoluteYIndex + defaultSlotValue * 0.48
        end
    end
end

local function initialisePeripherals()
    if settings.chat_box then
        if component.isAvailable("chat_box") then
            peripherals.chat_box = component.chat_box
            peripherals.chat_box.setName(settings.chat_box_name)
        else
            settings.chat_box = false
        end
    end
    if settings.sensor_players then
        if component.isAvailable("openperipheral_sensor") then
            peripherals.sensor = component.openperipheral_sensor
        else
            settings.sensor_players = false
        end
    end
end

local function getTimeHost()
    local file = io.open('/tmp/UNIX.tmp', 'w')
    file:write('TIME_ZONE = '..TIME_ZONE)
    file:close()
    local lastmod = tonumber(string.sub(fs.lastModified('/tmp/UNIX.tmp'), 1, -4)) + t_correction
    local dt = os.date('%H:%M:%S', lastmod)
    return dt
end

local function drawTime()
    local timeText = localize.time .. " "..getTimeHost()
    drawSlot(constraints.leftBorderAbsolute, absoluteYIndex, constraints.timeTextWidth, constraints.slot_height_60, timeText, colors.time_color)
    absoluteYIndex = absoluteYIndex + constraints.slot_height_60
end

local function drawOnlinePlayers()
    absoluteYIndex = constraints.topBorderAbsolute
    local x = constraints.leftBorderAbsolute + constraints.timeTextWidth + constraints.dc_reactor_info_width
    drawSlot(x, absoluteYIndex, constraints.status_player_title_width, constraints.slot_height_60, localize.status_players_title, colors.player_status_title_color)
    absoluteYIndex = absoluteYIndex + constraints.slot_height_60
    for i = 1, #onlinePlayers do
        if not onlinePlayers[i].isHideOnline then
            drawSlot(x, absoluteYIndex, constraints.nickname_width, constraints.slot_height_60, players[i].name, colors.player_status_nickname_color)

            if onlinePlayers[i].isJoin then
                drawSlot(x + constraints.nickname_width, absoluteYIndex, constraints.status_player_box_width, constraints.slot_height_60, nill, nill, colors.player_status_online_color)
            else
                drawSlot(x + constraints.nickname_width, absoluteYIndex, constraints.status_player_box_width, constraints.slot_height_60, nill, nill, colors.player_status_offline_color)
            end
            absoluteYIndex = absoluteYIndex + constraints.slot_height_60
        end
    end
end
--------------------------------------------

local function splitForLines(textToSplit, chunkSizeWidthPixels)
    local words = {}
    for word in textToSplit:gmatch("%S+") do
        table.insert(words, word)
    end

    local lines = {}
    local currentLine = ""
    for _, word in ipairs(words) do
        local wordWidth = charWidthLib.checkWidth(word)
        local linePlusWordWidth = charWidthLib.checkWidth(currentLine .. " " .. word)
        if linePlusWordWidth <= chunkSizeWidthPixels then
            if currentLine == "" then
                currentLine = word
            else
                currentLine = currentLine .. " " .. word
            end
        else
            table.insert(lines, currentLine)
            currentLine = word
        end
    end
    if currentLine ~= "" then
        table.insert(lines, currentLine)
    end

    return lines
end

local function drawMessages(messages)
    local messageColor = 0x000000
    local x = constraints.leftBorderAbsolute
    local y = absoluteYIndex
    local borderPadding = 2
    local symbolHeight = 9
    local symbolWidth = 5
    local messageGap = 2
    local maxSymbolsInLine = math.floor((constraints.messages_local_chat_width - (borderPadding * 2)) / symbolWidth)
    local maxLines = (constraints.messages_local_chat_height - (borderPadding * 2)) / (symbolHeight  + messageGap)
    drawSlot(x, y, constraints.messages_local_chat_width, constraints.messages_local_chat_height, nill, nill, 0x000000, nill, 0.3)
    local messageX = x + borderPadding
    local currentY = y + borderPadding + constraints.messages_local_chat_height - messageGap
    local currentLine = 1
    local lastY = currentY
    for i = 1, #messages do -- итерируем по всем сообщениям
        lastY = currentY
        local message = tostring(messages[i]):gsub("&", "§")
        local lines = splitForLines(message, constraints.messages_local_chat_width - borderPadding * 2)
        currentY = currentY - (#lines * (symbolHeight + messageGap))
        if currentY < y then
            currentY = y + messageGap
        end
        for j = 1, #lines do
            local trimmedText = text.trim(lines[j])
            if #trimmedText > 0 then
                local line = "§f"..trimmedText
                if currentLine < maxLines then -- если строка влезает в контейнер
                    peripherals.bridge.addText(messageX, currentY, line, messageColor) -- выводим ее на экран
                    currentY = currentY + symbolHeight + messageGap -- сдвигаемся на следующую строку
                    currentLine = currentLine + 1
                else
                    break
                end
            end
        end
        if currentLine > maxLines then
            break
        end
        currentY = currentY - (#lines * (symbolHeight + messageGap))
        if currentY < y then
            currentY = y + messageGap
        end
    end
end

--------------------------------------------
local isLocalChatEnabled = settings.local_chat
local playerNicknameToShowDetailed = nil
local function handleKeyEvent(...)
    local args = {...}
    local eventName = args[1]
    local code = args[5]
    print(eventName.. " "..code)
    if eventName == "glasses_key_down" and code >= 2 and code <= 11 then
        local playersTmp = peripherals.sensor.getPlayers()
        if playerNicknameToShowDetailed and playerNicknameToShowDetailed == playersTmp[code - 1].name then
            playerNicknameToShowDetailed = nil
        else
            if playersTmp then
                local playerName = playersTmp[code - 1].name
                if playerName then
                    playerNicknameToShowDetailed = playerName
                end
            end
        end
    elseif eventName == "glasses_key_down" and code == 12 or code == 13 then
        isLocalChatEnabled = (code == 13) and true or false
    end
end

event.listen("glasses_key_down", handleKeyEvent)

function drawPlayerSlotItem(slotX, slotY, slotSize, inventorySlotLink)
    drawSlot(slotX, slotY, slotSize, slotSize)
    if inventorySlotLink then
        local inventorySlot = inventorySlotLink.all == nill and inventorySlotLink or inventorySlotLink.all()
        addIcon(slotX + 1, slotY + 1 , inventorySlot.id, inventorySlot.dmg)
        if inventorySlot.qty and inventorySlot.qty > 1 then
            if inventorySlot.qty > 9 then
                addText(slotX + slotSize/2 - 3, slotY + slotSize/2 + 1, string.format("%u", inventorySlot.qty), colors.white)
            else
                addText(slotX + slotSize/2 + 3, slotY + slotSize/2 + 1, string.format("%u", inventorySlot.qty), colors.white)
            end
        end
        if inventorySlot.electric then
            if inventorySlot.electric.charge then
                local gapX = 2
                local gapBottom = 3
                local barWidth = slotSize - gapX * 2
                local chargePercent = inventorySlot.electric.charge / inventorySlot.electric.maxCharge
                local chargeWidth = barWidth * chargePercent
                addBox(slotX + gapX, slotY + slotSize - gapBottom, barWidth, 1, colors.not_charge_level_color, 1)
                addBox(slotX + gapX, slotY + slotSize - gapBottom, chargeWidth, 1, colors.charge_level_color, 1)
            end
        end
        if inventorySlot.energy_te then
            if inventorySlot.energy_te.energyStored < inventorySlot.energy_te.maxEnergyStored then
                local gapX = 2
                local gapBottom = 3
                local barWidth = slotSize - gapX * 2
                local chargePercent = inventorySlot.energy_te.energyStored / inventorySlot.energy_te.maxEnergyStored
                local chargeWidth = barWidth * chargePercent
                addBox(slotX + gapX, slotY + slotSize - gapBottom, barWidth, 1, colors.not_charge_level_color, 1)
                addBox(slotX + gapX, slotY + slotSize - gapBottom, chargeWidth, 1, colors.charge_level_color, 1)
            end
        end
    end
end

function drawPlayerDetails(startX, startY, playerName, slotSize, numSlots, playerIndex)
    local playerStats = peripherals.sensor.getPlayerByName(playerName).all()
    if playerStats then
        local armor = playerStats.living.armor
        local inventory = playerStats.player.inventory
        drawSlot(startX, startY, constraints.players_near_title_width, slotSize, playerIndex..": "..playerName, colors.player_near_nickname_color)

        if numSlots == 9 then
            local slotAreaX = startX + constraints.players_near_title_width
            for col = 1, 9 do
                local slotX = slotAreaX + ((col - 1) * slotSize)
                drawPlayerSlotItem(slotX, absoluteYIndex, slotSize, inventory[col])
            end
            absoluteYIndex = absoluteYIndex + slotSize
        elseif numSlots == 36 then
            for row = 1, 4 do
                local slotAreaX = startX + constraints.players_near_title_width
                local slotAreaY = startY + slotSize
                for col = 1, 9 do
                    local i = (row - 1) * 9 + col
                    local slotX = slotAreaX + ((col - 1) * slotSize)
                    local slotY = slotAreaY + ((row - 1) * slotSize)
                    drawPlayerSlotItem(slotX, absoluteYIndex, slotSize, inventory[i])
                end
                if row == 2 then
                    slotAreaX = startX
                    drawPlayerSlotItem(slotAreaX, absoluteYIndex, slotSize, armor.helmet)
                    slotAreaX = slotAreaX + defaultSlotValue
                    drawPlayerSlotItem(slotAreaX, absoluteYIndex, slotSize, armor.chestplate)
                    slotAreaX = slotAreaX + defaultSlotValue
                    drawPlayerSlotItem(slotAreaX, absoluteYIndex, slotSize, armor.leggings)
                    slotAreaX = slotAreaX + defaultSlotValue
                    drawPlayerSlotItem(slotAreaX, absoluteYIndex, slotSize, armor.boots)
                elseif row == 3 then
                    slotAreaX = startX
                    local levelText = string.format(localize.level_mask, playerStats.player.experience.level)
                    drawSlot(slotAreaX, absoluteYIndex, constraints.experience_slot_width, defaultSlotValue, levelText, colors.player_status_online_color)
                end
                absoluteYIndex = absoluteYIndex + slotSize

            end
        else
            error("Invalid number of slots specified: " .. numSlots)
        end
    end
end

function drawPlayersNearME()
    local temp = peripherals.sensor.getPlayers()
    local playersCount = #temp
    for g = 1, #temp do
        for j = 1, #players do
            if players[j].name == temp[g].name and players[j].isHideOnline then
                playersCount = playersCount - 1
            end
        end
    end
    local x = constraints.leftBorderAbsolute + constraints.timeTextWidth + constraints.dc_reactor_info_width + constraints.status_player_title_width
    if playersCount > 0 then
        local yHeightTitle = defaultSlotValue * 0.8
        absoluteYIndex = constraints.topBorderAbsolute
        drawSlot(x, absoluteYIndex, constraints.players_near_title_width, yHeightTitle, localize.near_ME, colors.players_near_title_color)
        absoluteYIndex = absoluteYIndex + yHeightTitle
    end
    if settings.player_items then
        for i = 1, #temp do
            local isShowPlayer = true
            for j = 1, #players do
                if players[j].name == temp[i].name and players[j].isHideOnline then
                    isShowPlayer = false
                    break
                end
            end
            if isShowPlayer then
                local numSlots = (playerNicknameToShowDetailed == temp[i].name) and 36 or 9
                local success, result = pcall(drawPlayerDetails, x, absoluteYIndex, temp[i].name, defaultSlotValue, numSlots, i)
            end
        end
    end
end

--------------------------------------------
initialisePeripherals()
peripherals.modem.open(receiverDataPort) -- открываем порт для первого компьютера
--------------------------------------------
local function format(num)
    if num >= 10^12 then
        return string.format("%0.2f T", num/10^12)
    elseif num >= 10^9 then
        return string.format("%0.2f", num/10^9)
    elseif num >= 10^6 then
        return string.format("%0.2f M", num/10^6)

    elseif num >= 10^3 then
        return string.format("%0.2f K", num/10^3)
    else
        return string.format("%d", num)
    end
end

local function drawDcStorageReactors(info)
    local fluxGateFlow  = info.fluxGateFlow
    local energyStored = info.energyStored
    local energyStoredText = format(energyStored)
    local energyOutFluxGateText = format(fluxGateFlow)
    local x = constraints.leftBorderAbsolute + constraints.timeTextWidth
    drawSlot(x, absoluteYIndex, constraints.dc_reactor_info_width/2, constraints.slot_height_60, energyOutFluxGateText, colors.white)
    drawSlot(x + constraints.dc_reactor_info_width/2, absoluteYIndex, constraints.dc_reactor_info_width/2, constraints.slot_height_60, energyStoredText, colors.white)
    absoluteYIndex = absoluteYIndex + constraints.slot_height_60
end
--------------------------------------------
local eventDataDrawing = {
    DATA_PLAYERS_NEAR = {type_data = message_types.DATA_PLAYERS_NEAR.type, payload = nill}, --force draw as it doing locally in this class
}

local function handleEvent(_, _, _, port, _, message)
    if message then
        local data = serialization.unserialize(message)
        if data.type_data then
            eventDataDrawing[data.type_data] = data
        end
    end
end

-- Регистрируем обработчик событий
event.listen("modem_message", handleEvent)

local function drawAllData()
    absoluteYIndex = constraints.topBorderAbsolute
    peripherals.bridge.clear()
    drawTime()
    for index, message_key in ipairs(message_types_keys_drawing) do
        if eventDataDrawing[message_key] then
            local data = eventDataDrawing[message_key]
            if data.type_data == message_types.DATA_TPS.type then
                drawTps(data.payload)
                print("drawing TPS")
            elseif data.type_data == message_types.DATA_ME_ITEMS_INFO.type then
                drawMEInfo(data.payload)
                print("drawing DATA_ME_ITEMS_INFO")
            elseif data.type_data == message_types.DATA_PLAYERS_NEAR.type and settings.sensor_players then
                drawPlayersNearME()
                print("drawing PLAYERS_NEAR_ME")
            elseif data.type_data == message_types.DATA_ONLINE_CHECKER.type then                onlinePlayers = data.payload
                drawOnlinePlayers()
                print("drawing DATA_ONLINE_CHECKER")
            elseif data.type_data == message_types.DATA_DRACONIC_REACTOR.type then
                print("drawing DATA_DRACONIC_REACTOR")
                reactorsInfo = data.payload
                drawDraconicReactorsInfo(reactorsInfo)
            elseif data.type_data == message_types.DATA_REACTOR_STORAGE.type then
                print("drawing DATA_REACTOR_STORAGE")
                drawDcStorageReactors(data.payload )
            elseif data.type_data == message_types.DATA_LOCAL_CHAT.type then
                if isLocalChatEnabled then
                    drawMessages(data.payload)
                end
            end
        end
    end
    peripherals.bridge.sync()
end

while true do

    if settings.tps then
        local requestTpsTable = {type_data = message_types.DATA_TPS.type}
        local requestTps = serialization.serialize(requestTpsTable)
        peripherals.modem.broadcast(message_types.DATA_TPS.requestPort, requestTps)
    end

    if settings.me_items then
        local requestMETable = {type_data = message_types.DATA_ME_ITEMS_INFO.type, itemsToCheck = items}
        local requestME = serialization.serialize(requestMETable)
        peripherals.modem.broadcast(message_types.DATA_ME_ITEMS_INFO.requestPort, requestME)
    end

    if settings.players_online then
        local requestPlayersOnlineTable = {type_data = message_types.DATA_ONLINE_CHECKER.type, playersToCheck =onlinePlayers}
        local requestPlayers = serialization.serialize(requestPlayersOnlineTable)
        peripherals.modem.broadcast(message_types.DATA_ONLINE_CHECKER.requestPort, requestPlayers)
    end

    if settings.dc_reactors_info then
        local requestDraconicReactorTable = {type_data = message_types.DATA_DRACONIC_REACTOR.type}
        local requestReactorsInfo = serialization.serialize(requestDraconicReactorTable)
        peripherals.modem.broadcast(message_types.DATA_DRACONIC_REACTOR.requestPort, requestReactorsInfo)

        local requestDcStorageTable = {type_data = message_types.DATA_REACTOR_STORAGE.type}
        local requestDcStorage = serialization.serialize(requestDcStorageTable)
        peripherals.modem.broadcast(message_types.DATA_REACTOR_STORAGE.requestPort, requestDcStorage)
    end

    if settings.local_chat then
        local requestLocalChat = {type_data = message_types.DATA_LOCAL_CHAT.type}
        local requestLocalChatInfo = serialization.serialize(requestLocalChat)
        peripherals.modem.broadcast(message_types.DATA_LOCAL_CHAT.requestPort, requestLocalChatInfo)
    end

    drawAllData()
    os.sleep(0.3)
end