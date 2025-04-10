-- Server-side events handler for qbx_heists

local QBX = exports['qbx_core']:GetCoreObject()

-- Event handler for when a player drops (disconnects)
-- This handles cleanup when a player in a heist disconnects
AddEventHandler('playerDropped', function()
    local src = source
    local pData = QBX.Functions.GetPlayer(src)
    
    if not pData then return end
    
    -- Check if player is in any active heist
    local inHeist, gangId = exports['qbx_heists']:IsPlayerInHeist(src)
    if not inHeist then return end
    
    -- Get active heist for this gang
    local activeHeists = exports['qbx_heists']:GetActiveHeists()
    local heist = activeHeists[gangId]
    
    if not heist then return end
    
    -- Check if player is the heist leader (first participant)
    if heist.participants[1] == src then
        -- Leader disconnected, notify all participants and cancel heist
        for _, playerId in ipairs(heist.participants) do
            if playerId ~= src then -- Don't try to notify the disconnected player
                TriggerClientEvent('QBX:Notify', playerId, 'Heist leader disconnected. Heist canceled.', 'error')
                TriggerClientEvent('qbx_heists:client:HeistCanceled', playerId)
            end
        end
        
        -- Mark heist as canceled in database
        MySQL.update('UPDATE heist_records SET end_time = CURRENT_TIMESTAMP, status = ? WHERE gang_id = ? AND end_time IS NULL',
            {'leader_disconnected', gangId})
            
        -- Remove the heist from active heists
        activeHeists[gangId] = nil
    else
        -- Just a participant, remove them from the participants list
        local newParticipants = {}
        for _, playerId in ipairs(heist.participants) do
            if playerId ~= src then
                table.insert(newParticipants, playerId)
                -- Notify the remaining player that someone left
                TriggerClientEvent('QBX:Notify', playerId, 'A heist participant disconnected', 'primary')
            end
        end
        
        -- Update the participants list
        heist.participants = newParticipants
        
        -- Update the database
        MySQL.update('UPDATE heist_records SET participants = ? WHERE gang_id = ? AND end_time IS NULL',
            {json.encode(newParticipants), gangId})
    end
end)

-- Event for updating player's inventory after heist completion
-- This is used to synchronize inventory with the server when items are used
RegisterNetEvent('qbx_heists:server:UpdateInventory', function(items)
    local src = source
    local Player = QBX.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Process each item in the update
    for itemName, count in pairs(items) do
        if count > 0 then
            -- Add items
            exports.ox_inventory:AddItem(src, itemName, count)
        elseif count < 0 then
            -- Remove items
            exports.ox_inventory:RemoveItem(src, itemName, math.abs(count))
        end
    end
end)

-- Event for checking player's inventory for required items
RegisterNetEvent('qbx_heists:server:CheckItems', function(requiredItems, callback)
    local src = source
    local Player = QBX.Functions.GetPlayer(src)
    if not Player then 
        if callback then
            callback(false, "Player not found")
        end
        return 
    end
    
    -- Check each required item
    local hasAllItems = true
    local missingItems = {}
    
    for itemName, requiredCount in pairs(requiredItems) do
        local itemCount = exports.ox_inventory:GetItemCount(src, itemName)
        if itemCount < requiredCount then
            hasAllItems = false
            table.insert(missingItems, {
                name = itemName,
                required = requiredCount,
                have = itemCount
            })
        end
    end
    
    -- Return the result
    if callback then
        callback(hasAllItems, missingItems)
    end
end)

-- Event for logging heist activity
RegisterNetEvent('qbx_heists:server:LogHeistActivity', function(gangId, action, data)
    if not gangId or not action then return end
    
    -- Get information about the player who triggered the event
    local src = source
    local Player = QBX.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Format the log data
    local logData = {
        player = {
            id = src,
            name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
            citizenid = Player.PlayerData.citizenid
        },
        gang = gangId,
        action = action,
        timestamp = os.time(),
        data = data or {}
    }
    
    -- Print to console for now - can be extended to write to database or external logging
    print(json.encode(logData))
    
    -- Optional: Forward to Discord webhook for admin monitoring
    -- SendToDiscordWebhook(logData)
end)

-- Event for updating gang reputation after heist
RegisterNetEvent('qbx_heists:server:UpdateGangReputation', function(gangId, change)
    if not gangId or not change then return end
    
    -- Get current reputation
    local reputation = 0
    local result = MySQL.query.await('SELECT meta_value FROM gang_metadata WHERE gang_id = ? AND meta_key = "reputation"', {gangId})
    
    if result and result[1] then
        reputation = tonumber(result[1].meta_value) or 0
    end
    
    -- Update reputation
    reputation = reputation + change
    if reputation < 0 then reputation = 0 end
    
    -- Save to database
    MySQL.update('INSERT INTO gang_metadata (gang_id, meta_key, meta_value) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE meta_value = ?',
        {gangId, 'reputation', tostring(reputation), tostring(reputation)})
    
    -- Notify gang members
    local players = QBX.Functions.GetPlayers()
    for _, playerId in ipairs(players) do
        local Player = QBX.Functions.GetPlayer(playerId)
        if Player and Player.PlayerData.gang.name == gangId then
            if change > 0 then
                TriggerClientEvent('QBX:Notify', playerId, 'Your gang reputation increased by ' .. change, 'success')
            else
                TriggerClientEvent('QBX:Notify', playerId, 'Your gang reputation decreased by ' .. math.abs(change), 'error')
            end
        end
    end
end)

-- Event for handling territory rewards after successful heists
RegisterNetEvent('qbx_heists:server:HandleTerritoryRewards', function(gangId, heistType)
    if not gangId or not heistType then return end
    
    -- Check if this is a high-level heist
    local heistLevel = 1
    for name, data in pairs(Config.Heists) do
        if name == heistType then
            heistLevel = data.level
            break
        end
    end
    
    -- Only give territory rewards for higher-level heists
    if heistLevel < 3 then return end
    
    -- Calculate chance of gaining territory based on heist level
    local chanceToGain = 10 * heistLevel -- 30% for level 3, 40% for level 4
    
    -- Roll for territory gain
    if math.random(1, 100) <= chanceToGain then
        -- Territory gain logic would go here
        -- This would typically involve adding a new spray in qbx_graffiti
        -- For now, just notify players
        local players = QBX.Functions.GetPlayers()
        for _, playerId in ipairs(players) do
            local Player = QBX.Functions.GetPlayer(playerId)
            if Player and Player.PlayerData.gang.name == gangId then
                TriggerClientEvent('QBX:Notify', playerId, 'Your gang has earned a new territory opportunity!', 'success')
            end
        end
        
        -- Update gang reputation
        TriggerEvent('qbx_heists:server:UpdateGangReputation', gangId, 10)
    end
end)

-- Callback for getting item counts
lib.callback.register('qbx_heists:server:GetItemCount', function(source, itemName)
    return exports.ox_inventory:GetItemCount(source, itemName)
end)

-- Callback for checking police count
lib.callback.register('qbx_heists:server:GetPoliceCount', function(source)
    local policeCount = 0
    local players = QBX.Functions.GetPlayers()
    
    for _, playerId in ipairs(players) do
        local Player = QBX.Functions.GetPlayer(playerId)
        if Player and Player.PlayerData.job.name == 'police' and Player.PlayerData.job.onduty then
            policeCount = policeCount + 1
        end
    end
    
    return policeCount
end)

-- Function to send webhook notifications
function SendToDiscordWebhook(data)
    -- Implement Discord webhook functionality here if needed
end 