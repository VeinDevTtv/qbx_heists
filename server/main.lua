local QBX = exports['qbx_core']:GetCoreObject()
local ActiveHeists = {}
local cooldowns = {
    global = 0,
    gang = {},
    heist = {}
}

-- Initialize the database tables when resource starts
MySQL.ready(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `heist_records` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `gang_id` VARCHAR(50) NOT NULL,
            `heist_type` VARCHAR(50) NOT NULL,
            `start_time` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `end_time` TIMESTAMP NULL DEFAULT NULL,
            `status` VARCHAR(20) NOT NULL DEFAULT 'in_progress',
            `payout` INT DEFAULT 0,
            `participants` LONGTEXT NOT NULL,
            `stages_completed` INT DEFAULT 0
        )
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `gang_heist_stats` (
            `gang_id` VARCHAR(50) NOT NULL PRIMARY KEY,
            `heists_completed` INT DEFAULT 0,
            `total_earnings` INT DEFAULT 0,
            `last_heist` TIMESTAMP NULL,
            `cooldown_until` TIMESTAMP NULL
        )
    ]])

    print('[qbx_heists] Database tables initialized.')
end)

-- Function to check if player's gang is eligible for a specific heist level
local function CheckHeistEligibility(gangId, heistType)
    -- Get the heist level from config
    local heistLevel = 1
    for heistName, heistData in pairs(Config.Heists) do
        if heistName == heistType then
            heistLevel = heistData.level
            break
        end
    end

    -- Get required territories for this level
    local requiredTerritories = Config.HeistLevels[heistLevel].requiredTerritories

    -- Get number of territories controlled by the gang
    local territories = 0
    local result = MySQL.prepare.await("SELECT COUNT(*) as count FROM laptop_sprays WHERE gang_id = ?", {gangId})
    if result then
        territories = result
    end

    -- Check if gang meets the requirements
    if territories >= requiredTerritories then
        return true, territories
    else
        return false, territories, requiredTerritories
    end
end

-- Function to check cooldowns
local function CheckCooldowns(gangId, heistType)
    local currentTime = os.time()
    
    -- Check global cooldown
    if cooldowns.global > currentTime then
        return false, "global", math.ceil((cooldowns.global - currentTime) / 60)
    end
    
    -- Check gang cooldown
    if cooldowns.gang[gangId] and cooldowns.gang[gangId] > currentTime then
        return false, "gang", math.ceil((cooldowns.gang[gangId] - currentTime) / 60)
    end
    
    -- Check heist type cooldown
    if cooldowns.heist[heistType] and cooldowns.heist[heistType] > currentTime then
        return false, "heist", math.ceil((cooldowns.heist[heistType] - currentTime) / 60)
    end
    
    return true
end

-- Function to set cooldowns
local function SetCooldowns(gangId, heistType)
    local currentTime = os.time()
    local heistLevel = 1
    
    -- Find the heist level
    for name, data in pairs(Config.Heists) do
        if name == heistType then
            heistLevel = data.level
            break
        end
    end
    
    -- Set cooldowns
    cooldowns.global = currentTime + (Config.GlobalCooldown * 60)
    cooldowns.gang[gangId] = currentTime + (Config.GangCooldown * 60)
    cooldowns.heist[heistType] = currentTime + (Config.HeistLevels[heistLevel].cooldownHours * 3600)
    
    -- Also update in the database
    MySQL.update("UPDATE gang_heist_stats SET cooldown_until = FROM_UNIXTIME(?) WHERE gang_id = ?", 
        {cooldowns.gang[gangId], gangId})
end

-- Function to get all available heists for a gang
local function GetAvailableHeists(gangId)
    local available = {}
    local territories = 0
    
    -- Get the number of territories
    local result = MySQL.prepare.await("SELECT COUNT(*) as count FROM laptop_sprays WHERE gang_id = ?", {gangId})
    if result then
        territories = result
    end
    
    -- Check each heist level
    for level, data in pairs(Config.HeistLevels) do
        if territories >= data.requiredTerritories then
            -- Gang has enough territories for this level
            for _, heistType in ipairs(data.heistTypes) do
                local onCooldown, cooldownType, timeLeft = CheckCooldowns(gangId, heistType)
                
                if onCooldown then
                    table.insert(available, {
                        type = heistType,
                        name = Config.Heists[heistType].name,
                        level = level,
                        available = true,
                        cooldown = false,
                        payout = Config.Heists[heistType].payout,
                        locations = #Config.Heists[heistType].locations,
                        minPlayers = Config.Heists[heistType].minPlayers,
                        maxPlayers = Config.Heists[heistType].maxPlayers,
                        requiredItems = Config.Heists[heistType].requiredItems
                    })
                else
                    table.insert(available, {
                        type = heistType,
                        name = Config.Heists[heistType].name,
                        level = level,
                        available = false,
                        cooldown = true,
                        cooldownTime = timeLeft,
                        cooldownType = cooldownType,
                        payout = Config.Heists[heistType].payout,
                        locations = #Config.Heists[heistType].locations,
                        minPlayers = Config.Heists[heistType].minPlayers,
                        maxPlayers = Config.Heists[heistType].maxPlayers,
                        requiredItems = Config.Heists[heistType].requiredItems
                    })
                end
            end
        else
            -- Gang doesn't have enough territories for this level
            for _, heistType in ipairs(data.heistTypes) do
                table.insert(available, {
                    type = heistType,
                    name = Config.Heists[heistType].name,
                    level = level,
                    available = false,
                    locked = true,
                    requiredTerritories = data.requiredTerritories,
                    currentTerritories = territories,
                    payout = Config.Heists[heistType].payout,
                    locations = #Config.Heists[heistType].locations,
                    minPlayers = Config.Heists[heistType].minPlayers,
                    maxPlayers = Config.Heists[heistType].maxPlayers,
                    requiredItems = Config.Heists[heistType].requiredItems
                })
            end
        end
    end
    
    return available
end

-- Function to start a heist
local function StartHeist(gangId, heistType, playerId)
    -- Check if another heist is already active for this gang
    if ActiveHeists[gangId] then
        return false, "already_active"
    end
    
    -- Check heist eligibility
    local eligible, territories, required = CheckHeistEligibility(gangId, heistType)
    if not eligible then
        return false, "insufficient_level", {current = territories, required = required}
    end
    
    -- Check cooldowns
    local cooldownOk, cooldownType, timeLeft = CheckCooldowns(gangId, heistType)
    if not cooldownOk then
        return false, "cooldown", {type = cooldownType, time = timeLeft}
    end
    
    -- Check number of police online
    local policeCount = 0
    for _, player in pairs(QBX.Functions.GetPlayers()) do
        local Player = QBX.Functions.GetPlayer(player)
        if Player.PlayerData.job.name == "police" and Player.PlayerData.job.onduty then
            policeCount = policeCount + 1
        end
    end
    
    if policeCount < Config.MinimumPolice then
        return false, "police"
    end
    
    -- Check heist exists in config
    if not Config.Heists[heistType] then
        return false, "invalid_heist"
    end
    
    -- Create a unique ID for this heist instance
    local heistId = os.time() .. "_" .. math.random(1000, 9999)
    
    -- Choose a random location from available ones
    local locationIndex = math.random(1, #Config.Heists[heistType].locations)
    local location = Config.Heists[heistType].locations[locationIndex]
    
    -- Set up the heist state
    ActiveHeists[gangId] = {
        id = heistId,
        type = heistType,
        startTime = os.time(),
        location = location,
        stage = 1,
        totalStages = 3, -- Preparation, Execution, Escape
        participants = {playerId},
        currentObjective = "preparation",
        items = {},
        payout = 0,
        completed = false,
        failed = false
    }
    
    -- Insert into database
    MySQL.insert("INSERT INTO heist_records (gang_id, heist_type, participants) VALUES (?, ?, ?)",
        {gangId, heistType, json.encode({playerId})})
    
    return true, ActiveHeists[gangId]
end

-- Function to complete a heist
local function CompleteHeist(gangId, success)
    if not ActiveHeists[gangId] then
        return false, "not_active"
    end
    
    local heist = ActiveHeists[gangId]
    local heistConfig = Config.Heists[heist.type]
    local payout = 0
    
    if success then
        -- Calculate payout based on config range and number of stages completed
        local baseMin = heistConfig.payout.min
        local baseMax = heistConfig.payout.max
        local completionPercentage = heist.stage / heist.totalStages
        
        -- Calculate a payout with some randomness
        local basePayout = math.random(baseMin, baseMax)
        payout = math.floor(basePayout * completionPercentage)
        
        -- Apply success rate chance
        local successChance = heistConfig.successRate
        if math.random(1, 100) > successChance then
            -- Failed at the final moment!
            success = false
            payout = math.floor(payout * 0.25) -- Only get 25% if you fail at the end
        end
        
        -- Set cooldowns
        SetCooldowns(gangId, heist.type)
    else
        -- Failed heist still gets some minimal payout if they reached at least stage 2
        if heist.stage >= 2 then
            payout = math.floor(heistConfig.payout.min * 0.1) -- 10% of minimum payout for attempts
        end
    end
    
    -- Update the database record
    MySQL.update("UPDATE heist_records SET end_time = CURRENT_TIMESTAMP, status = ?, payout = ?, stages_completed = ? WHERE gang_id = ? AND end_time IS NULL",
        {success and "completed" or "failed", payout, heist.stage, gangId})
    
    -- Update gang stats
    if success then
        MySQL.query("INSERT INTO gang_heist_stats (gang_id, heists_completed, total_earnings, last_heist) VALUES (?, 1, ?, CURRENT_TIMESTAMP) " .. 
                   "ON DUPLICATE KEY UPDATE heists_completed = heists_completed + 1, total_earnings = total_earnings + ?, last_heist = CURRENT_TIMESTAMP",
            {gangId, payout, payout})
    end
    
    -- Distribute rewards to participants
    local payoutPerPlayer = math.floor(payout / #heist.participants)
    for _, playerId in ipairs(heist.participants) do
        local Player = QBX.Functions.GetPlayer(playerId)
        if Player then
            Player.Functions.AddMoney("cash", payoutPerPlayer, "heist-payout")
        end
    end
    
    -- Clean up the active heist state
    local completedHeist = ActiveHeists[gangId]
    ActiveHeists[gangId] = nil
    
    return true, {
        success = success,
        payout = payout,
        payoutPerPlayer = payoutPerPlayer,
        participants = #completedHeist.participants
    }
end

-- Function to add a participant to a heist
local function AddHeistParticipant(gangId, playerId)
    if not ActiveHeists[gangId] then
        return false, "not_active"
    end
    
    local heist = ActiveHeists[gangId]
    local heistConfig = Config.Heists[heist.type]
    
    -- Check if already a participant
    for _, id in ipairs(heist.participants) do
        if id == playerId then
            return false, "already_participant"
        end
    end
    
    -- Check max players
    if #heist.participants >= heistConfig.maxPlayers then
        return false, "too_many_players"
    end
    
    -- Add to participants
    table.insert(heist.participants, playerId)
    
    -- Update database
    MySQL.query("UPDATE heist_records SET participants = ? WHERE gang_id = ? AND end_time IS NULL",
        {json.encode(heist.participants), gangId})
    
    return true
end

-- Export functions for use in other scripts
exports('CheckHeistEligibility', CheckHeistEligibility)
exports('GetAvailableHeists', GetAvailableHeists)
exports('StartHeist', StartHeist)
exports('CompleteHeist', CompleteHeist)
exports('AddHeistParticipant', AddHeistParticipant)

-- Callback for getting the heist app data
lib.callback.register('qbx_heists:server:GetHeistData', function(source)
    local Player = QBX.Functions.GetPlayer(source)
    if not Player then return nil end
    
    local gangId = Player.PlayerData.gang.name
    if gangId == "none" then return {error = "not_in_gang"} end
    
    -- Get available heists
    local availableHeists = GetAvailableHeists(gangId)
    
    -- Get active heist if any
    local activeHeist = ActiveHeists[gangId]
    
    -- Get heist history
    local history = {}
    local result = MySQL.query.await("SELECT * FROM heist_records WHERE gang_id = ? ORDER BY start_time DESC LIMIT 10", {gangId})
    if result then
        history = result
    end
    
    -- Get gang stats
    local stats = {}
    local statsResult = MySQL.query.await("SELECT * FROM gang_heist_stats WHERE gang_id = ?", {gangId})
    if statsResult and statsResult[1] then
        stats = statsResult[1]
    else
        stats = {
            gang_id = gangId,
            heists_completed = 0,
            total_earnings = 0
        }
    end
    
    -- Get number of territories
    local territories = 0
    local territoryResult = MySQL.prepare.await("SELECT COUNT(*) as count FROM laptop_sprays WHERE gang_id = ?", {gangId})
    if territoryResult then
        territories = territoryResult
    end
    
    return {
        gang = {
            id = gangId,
            name = Player.PlayerData.gang.label,
            grade = Player.PlayerData.gang.grade.level
        },
        availableHeists = availableHeists,
        activeHeist = activeHeist,
        history = history,
        stats = stats,
        territories = territories
    }
end)

-- Callback for starting a heist
lib.callback.register('qbx_heists:server:StartHeist', function(source, heistType)
    local Player = QBX.Functions.GetPlayer(source)
    if not Player then return {success = false, message = "player_not_found"} end
    
    local gangId = Player.PlayerData.gang.name
    if gangId == "none" then return {success = false, message = "not_in_gang"} end
    
    -- Check if player has the required items
    local heistConfig = Config.Heists[heistType]
    if not heistConfig then
        return {success = false, message = "invalid_heist"}
    end
    
    -- Count players from same gang nearby
    local players = 1 -- Start with self
    local x, y, z = Player.PlayerData.position.x, Player.PlayerData.position.y, Player.PlayerData.position.z
    
    for _, playerId in ipairs(QBX.Functions.GetPlayers()) do
        if tonumber(playerId) ~= source then -- Skip self
            local OtherPlayer = QBX.Functions.GetPlayer(playerId)
            if OtherPlayer and OtherPlayer.PlayerData.gang.name == gangId then
                local distance = #(vector3(OtherPlayer.PlayerData.position.x, OtherPlayer.PlayerData.position.y, OtherPlayer.PlayerData.position.z) - vector3(x, y, z))
                if distance <= 30.0 then -- Within 30 units
                    players = players + 1
                end
            end
        end
    end
    
    -- Check minimum players
    if players < heistConfig.minPlayers then
        return {success = false, message = "not_enough_players", min = heistConfig.minPlayers, current = players}
    end
    
    -- Start the heist
    local success, result = StartHeist(gangId, heistType, source)
    if not success then
        if result == "already_active" then
            return {success = false, message = "already_active"}
        elseif result == "insufficient_level" then
            return {success = false, message = "insufficient_gang_level", current = result.current, required = result.required}
        elseif result == "cooldown" then
            return {success = false, message = "cooldown", cooldownType = result.type, time = result.time}
        elseif result == "police" then
            return {success = false, message = "not_enough_police"}
        else
            return {success = false, message = "unknown_error"}
        end
    end
    
    -- Broadcast to all gang members that a heist has started
    for _, playerId in ipairs(QBX.Functions.GetPlayers()) do
        local OtherPlayer = QBX.Functions.GetPlayer(playerId)
        if OtherPlayer and OtherPlayer.PlayerData.gang.name == gangId then
            TriggerClientEvent('qbx_heists:client:HeistStarted', playerId, {
                type = heistType,
                name = heistConfig.name,
                location = result.location,
                stage = 1,
                initiator = GetPlayerName(source)
            })
        end
    end
    
    return {success = true, message = "heist_started", heist = result}
end)

-- Callback to complete a heist stage
lib.callback.register('qbx_heists:server:CompleteStage', function(source, success)
    local Player = QBX.Functions.GetPlayer(source)
    if not Player then return {success = false, message = "player_not_found"} end
    
    local gangId = Player.PlayerData.gang.name
    if gangId == "none" then return {success = false, message = "not_in_gang"} end
    
    if not ActiveHeists[gangId] then
        return {success = false, message = "no_active_heist"}
    end
    
    local heist = ActiveHeists[gangId]
    
    if not success then
        -- Failed this stage
        local result = CompleteHeist(gangId, false)
        
        -- Notify all participants of failure
        for _, playerId in ipairs(heist.participants) do
            TriggerClientEvent('qbx_heists:client:HeistFailed', playerId)
        end
        
        return {success = false, message = "stage_failed", result = result}
    end
    
    -- Advance to next stage
    heist.stage = heist.stage + 1
    
    if heist.stage > heist.totalStages then
        -- All stages completed, finish the heist
        local result = CompleteHeist(gangId, true)
        
        -- Notify all participants of success
        for _, playerId in ipairs(heist.participants) do
            TriggerClientEvent('qbx_heists:client:HeistCompleted', playerId, result)
        end
        
        return {success = true, message = "heist_completed", result = result}
    end
    
    -- Update stage objective
    if heist.stage == 2 then
        heist.currentObjective = "execution"
    elseif heist.stage == 3 then
        heist.currentObjective = "escape"
    end
    
    -- Notify all participants of stage completion
    for _, playerId in ipairs(heist.participants) do
        TriggerClientEvent('qbx_heists:client:StageCompleted', playerId, {
            stage = heist.stage,
            objective = heist.currentObjective
        })
    end
    
    return {success = true, message = "stage_completed", stage = heist.stage, objective = heist.currentObjective}
end)

-- Callback to purchase heist items
lib.callback.register('qbx_heists:server:PurchaseItem', function(source, itemName)
    local Player = QBX.Functions.GetPlayer(source)
    if not Player then return {success = false, message = "player_not_found"} end
    
    -- Check if the item exists
    local itemConfig = Config.RequiredItems[itemName]
    if not itemConfig then
        return {success = false, message = "item_not_found"}
    end
    
    -- Check if player has enough money
    if Player.PlayerData.money.cash < itemConfig.price then
        return {success = false, message = "not_enough_money", price = itemConfig.price}
    end
    
    -- Attempt to add the item to inventory
    local canCarry = exports.ox_inventory:CanCarryItem(source, itemName, 1)
    if not canCarry then
        return {success = false, message = "inventory_full"}
    end
    
    -- Remove money and add item
    Player.Functions.RemoveMoney("cash", itemConfig.price, "heist-item-purchase")
    exports.ox_inventory:AddItem(source, itemName, 1)
    
    return {success = true, message = "item_purchased", item = itemConfig.label, price = itemConfig.price}
end)

-- Events from client

-- Event for when player uses a heist item
RegisterNetEvent('qbx_heists:server:UseHeistItem', function(itemName)
    local src = source
    local Player = QBX.Functions.GetPlayer(src)
    if not Player then return end
    
    local gangId = Player.PlayerData.gang.name
    if gangId == "none" then return end
    
    -- Check if there's an active heist
    if not ActiveHeists[gangId] then return end
    
    local heist = ActiveHeists[gangId]
    
    -- Update item usage in the heist state
    if not heist.items[itemName] then
        heist.items[itemName] = 1
    else
        heist.items[itemName] = heist.items[itemName] + 1
    end
    
    -- Notify all participants of item usage
    for _, playerId in ipairs(heist.participants) do
        TriggerClientEvent('qbx_heists:client:ItemUsed', playerId, {
            item = itemName,
            player = GetPlayerName(src)
        })
    end
end)

-- Event for when a player tries to join an active heist
RegisterNetEvent('qbx_heists:server:JoinHeist', function()
    local src = source
    local Player = QBX.Functions.GetPlayer(src)
    if not Player then return end
    
    local gangId = Player.PlayerData.gang.name
    if gangId == "none" then return end
    
    -- Check if there's an active heist
    if not ActiveHeists[gangId] then 
        TriggerClientEvent('QBX:Notify', src, Lang:t('error.no_active_heist'), 'error')
        return
    end
    
    -- Try to add player to heist
    local success, result = AddHeistParticipant(gangId, src)
    
    if not success then
        if result == "already_participant" then
            TriggerClientEvent('QBX:Notify', src, Lang:t('error.already_participating'), 'error')
        elseif result == "too_many_players" then
            TriggerClientEvent('QBX:Notify', src, Lang:t('error.too_many_players', {max = Config.Heists[ActiveHeists[gangId].type].maxPlayers}), 'error')
        end
        return
    end
    
    -- Send heist details to the new participant
    TriggerClientEvent('qbx_heists:client:JoinedHeist', src, {
        type = ActiveHeists[gangId].type,
        name = Config.Heists[ActiveHeists[gangId].type].name,
        location = ActiveHeists[gangId].location,
        stage = ActiveHeists[gangId].stage,
        objective = ActiveHeists[gangId].currentObjective
    })
    
    -- Notify all participants that a new player joined
    for _, playerId in ipairs(ActiveHeists[gangId].participants) do
        if playerId ~= src then -- Don't notify the player who just joined
            TriggerClientEvent('qbx_heists:client:PlayerJoined', playerId, {
                player = GetPlayerName(src)
            })
        end
    end
end)

-- Event for when a player cancels a heist
RegisterNetEvent('qbx_heists:server:CancelHeist', function()
    local src = source
    local Player = QBX.Functions.GetPlayer(src)
    if not Player then return end
    
    local gangId = Player.PlayerData.gang.name
    if gangId == "none" then return end
    
    -- Check if there's an active heist and if player is the first participant (initiator)
    if not ActiveHeists[gangId] or ActiveHeists[gangId].participants[1] ~= src then
        TriggerClientEvent('QBX:Notify', src, Lang:t('error.no_permission'), 'error')
        return
    end
    
    -- Mark heist as canceled in DB
    MySQL.update("UPDATE heist_records SET end_time = CURRENT_TIMESTAMP, status = 'canceled' WHERE gang_id = ? AND end_time IS NULL",
        {gangId})
    
    -- Get all participants to notify them
    local participants = ActiveHeists[gangId].participants
    
    -- Clean up the active heist state
    ActiveHeists[gangId] = nil
    
    -- Notify all participants that the heist is canceled
    for _, playerId in ipairs(participants) do
        TriggerClientEvent('qbx_heists:client:HeistCanceled', playerId)
    end
end)

-- Admin command to reset heist status
QBX.Commands.Add('resetheist', Lang:t('commands.reset_heist'), {{name = 'gangId', help = 'Gang ID'}}, true, function(source, args)
    if not args[1] then return end
    
    local gangId = args[1]
    
    -- Clean up active heist if exists
    if ActiveHeists[gangId] then
        ActiveHeists[gangId] = nil
    end
    
    -- Reset any ongoing heist in DB
    MySQL.update("UPDATE heist_records SET end_time = CURRENT_TIMESTAMP, status = 'reset' WHERE gang_id = ? AND end_time IS NULL",
        {gangId})
    
    -- Reset cooldowns
    cooldowns.gang[gangId] = nil
    
    TriggerClientEvent('QBX:Notify', source, 'Heist status reset for gang: ' .. gangId, 'success')
end, 'admin')

-- Load cooldowns from database when resource starts
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    -- Load gang cooldowns
    MySQL.query("SELECT gang_id, UNIX_TIMESTAMP(cooldown_until) as cooldown FROM gang_heist_stats WHERE cooldown_until IS NOT NULL", {}, function(result)
        if result then
            for _, row in ipairs(result) do
                if row.cooldown > os.time() then
                    cooldowns.gang[row.gang_id] = row.cooldown
                end
            end
        end
    end)
end)

-- Exports for use in other resources
exports('GetActiveHeists', function()
    return ActiveHeists
end)

exports('GetHeistParticipants', function(gangId)
    if not ActiveHeists[gangId] then
        return nil
    end
    
    return ActiveHeists[gangId].participants
end)

exports('IsPlayerInHeist', function(playerId)
    for gangId, heist in pairs(ActiveHeists) do
        for _, pid in ipairs(heist.participants) do
            if pid == playerId then
                return true, gangId
            end
        end
    end
    
    return false
end) 