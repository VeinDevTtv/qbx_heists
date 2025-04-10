-- convenience_store.lua - Server-side implementation for convenience store heist

local QBX = exports['qbx_core']:GetCoreObject()

-- Register specific events for convenience store heist
RegisterNetEvent('qbx_heists:server:convenience_store:StartHeist', function(locationId)
    local src = source
    local Player = QBX.Functions.GetPlayer(src)
    if not Player then return end
    
    local gangId = Player.PlayerData.gang.name
    if gangId == "none" then return end
    
    -- Check if there's an active heist already
    if exports['qbx_heists']:GetActiveHeists()[gangId] then
        TriggerClientEvent('QBX:Notify', src, 'Your gang already has an active heist', 'error')
        return
    end
    
    -- Get the store location
    local location = nil
    for i, loc in ipairs(Config.Heists.convenience_store.locations) do
        if i == locationId then
            location = loc
            break
        end
    end
    
    if not location then
        TriggerClientEvent('QBX:Notify', src, 'Invalid location', 'error')
        return
    end
    
    -- Check for required items
    local hasItems = true
    local missingItems = {}
    
    for _, itemName in ipairs(Config.Heists.convenience_store.requiredItems) do
        local itemCount = exports.ox_inventory:GetItemCount(src, itemName)
        if itemCount <= 0 then
            hasItems = false
            table.insert(missingItems, Config.RequiredItems[itemName].label)
        end
    end
    
    if not hasItems then
        TriggerClientEvent('QBX:Notify', src, 'Missing items: ' .. table.concat(missingItems, ', '), 'error')
        return
    end
    
    -- Start the heist through the main system
    local success, result = exports['qbx_heists']:StartHeist(gangId, 'convenience_store', src)
    
    if not success then
        TriggerClientEvent('QBX:Notify', src, 'Failed to start heist: ' .. (result or 'Unknown error'), 'error')
        return
    end
    
    -- Alert police with a chance defined in config
    if math.random(1, 100) <= Config.PoliceAlertChance then
        -- Get all police officers
        local players = QBX.Functions.GetPlayers()
        for _, playerId in ipairs(players) do
            local PolicePlayer = QBX.Functions.GetPlayer(playerId)
            if PolicePlayer and PolicePlayer.PlayerData.job.name == 'police' and PolicePlayer.PlayerData.job.onduty then
                TriggerClientEvent('police:client:PoliceAlert', playerId, 'Possible robbery at ' .. location.label)
            end
        end
    end
    
    -- Trigger client-side setup for all gang members
    for _, playerId in ipairs(QBX.Functions.GetPlayers()) do
        local GangPlayer = QBX.Functions.GetPlayer(playerId)
        if GangPlayer and GangPlayer.PlayerData.gang.name == gangId then
            TriggerClientEvent('qbx_heists:client:convenience_store:SetupHeist', playerId, location)
        end
    end
end)

-- Handle stage completions
RegisterNetEvent('qbx_heists:server:convenience_store:CompleteStage', function(stage, success)
    local src = source
    local Player = QBX.Functions.GetPlayer(src)
    if not Player then return end
    
    local gangId = Player.PlayerData.gang.name
    if gangId == "none" then return end
    
    -- Get active heist for this gang
    local activeHeists = exports['qbx_heists']:GetActiveHeists()
    local heist = activeHeists[gangId]
    
    if not heist or heist.type ~= 'convenience_store' then
        TriggerClientEvent('QBX:Notify', src, 'No active convenience store heist', 'error')
        return
    end
    
    -- Call the main heist system to progress
    if not success then
        -- Heist failed
        TriggerClientEvent('QBX:Notify', src, 'Heist stage failed', 'error')
        exports['qbx_heists']:CompleteHeist(gangId, false)
        return
    end
    
    -- Update heist stage in main system via callback
    local result = lib.callback.await('qbx_heists:server:CompleteStage', src, true)
    
    if result.success then
        if result.message == "heist_completed" then
            -- Add some specific loot for convenience store
            local lootAmount = math.random(
                Config.Heists.convenience_store.payout.min,
                Config.Heists.convenience_store.payout.max
            )
            
            -- Add some specific items for convenience store heists
            if math.random(1, 100) <= 30 then
                -- 30% chance to get some cigarette packs
                exports.ox_inventory:AddItem(src, 'cigarette_pack', math.random(1, 5))
            end
            
            if math.random(1, 100) <= 20 then
                -- 20% chance to get a scratch card
                exports.ox_inventory:AddItem(src, 'scratch_card', math.random(1, 3))
            end
        end
    end
end)

-- Register specific callbacks for this heist type
lib.callback.register('qbx_heists:server:convenience_store:GetSafeCode', function(source)
    local src = source
    local Player = QBX.Functions.GetPlayer(src)
    if not Player then return nil end
    
    local gangId = Player.PlayerData.gang.name
    if gangId == "none" then return nil end
    
    -- Get active heist
    local activeHeists = exports['qbx_heists']:GetActiveHeists()
    local heist = activeHeists[gangId]
    
    if not heist or heist.type ~= 'convenience_store' then
        return nil
    end
    
    -- Generate a random 4-digit code if not already set
    if not heist.safeCode then
        heist.safeCode = tostring(math.random(1000, 9999))
    end
    
    return heist.safeCode
end) 