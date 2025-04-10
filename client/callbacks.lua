-- Client-side callbacks for qbx_heists

local QBX = exports['qbx_core']:GetCoreObject()

-- Callback to check if player is in a heist
lib.callback.register('qbx_heists:client:IsInHeist', function()
    return exports['qbx_heists']:IsInHeist()
end)

-- Callback to get active heist data
lib.callback.register('qbx_heists:client:GetActiveHeist', function()
    return exports['qbx_heists']:GetActiveHeist()
end)

-- Callback to check if player is near a specific location
lib.callback.register('qbx_heists:client:IsNearLocation', function(coords, maxDistance)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local distance = #(playerCoords - vector3(coords.x, coords.y, coords.z))
    return distance <= maxDistance
end)

-- Callback for checking player state
lib.callback.register('qbx_heists:client:GetPlayerState', function()
    local playerPed = PlayerPedId()
    local state = {
        health = GetEntityHealth(playerPed),
        armor = GetPedArmour(playerPed),
        inVehicle = IsPedInAnyVehicle(playerPed, false),
        isDead = IsPlayerDead(PlayerId()),
        isCuffed = IsPedCuffed(playerPed),
        isSwimming = IsPedSwimming(playerPed),
        isRunning = IsPedRunning(playerPed),
        weapon = GetSelectedPedWeapon(playerPed)
    }
    return state
end)

-- Callback to verify player can perform an action at their current position
lib.callback.register('qbx_heists:client:CanPerformAction', function(actionType, requiredItems)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    -- Check basic conditions
    if IsPlayerDead(PlayerId()) or IsPedCuffed(playerPed) then
        return false, "You can't perform this action in your current state"
    end
    
    -- Check action-specific conditions
    if actionType == 'drill' and IsPedSwimming(playerPed) then
        return false, "You can't use a drill while swimming"
    elseif actionType == 'hack' and IsPedRunning(playerPed) then
        return false, "You need to be stationary to hack"
    elseif actionType == 'lockpick' and IsPedInAnyVehicle(playerPed, false) then
        return false, "You can't lockpick from inside a vehicle"
    end
    
    -- Check for required items if specified
    if requiredItems and #requiredItems > 0 then
        local hasAllItems = true
        local missingItem = nil
        
        for _, item in ipairs(requiredItems) do
            local hasItem = QBX.Functions.HasItem(item)
            if not hasItem then
                hasAllItems = false
                missingItem = item
                break
            end
        end
        
        if not hasAllItems then
            return false, "You don't have a " .. missingItem
        end
    end
    
    return true, "Action can be performed"
end)

-- Callback to get player's gang/territory info
lib.callback.register('qbx_heists:client:GetGangInfo', function()
    local PlayerData = QBX.Functions.GetPlayerData()
    
    -- If player isn't in a gang, return minimal data
    if not PlayerData.gang or PlayerData.gang.name == 'none' then
        return {
            inGang = false,
            gangName = nil,
            gangGrade = nil,
            isLeader = false,
            territories = {}
        }
    end
    
    -- Get gang territories from qbx_graffiti if available
    local territories = {}
    if exports['qbx_graffiti'] and exports['qbx_graffiti'].GetGangTerritories then
        territories = exports['qbx_graffiti']:GetGangTerritories(PlayerData.gang.name)
    end
    
    return {
        inGang = true,
        gangName = PlayerData.gang.name,
        gangGrade = PlayerData.gang.grade.level,
        isLeader = PlayerData.gang.isboss,
        territories = territories
    }
end)

-- Callback to scan surroundings for other players
lib.callback.register('qbx_heists:client:ScanSurroundings', function(radius)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local radius = radius or 50.0
    
    local players = {}
    local foundPlayers = 0
    
    -- Scan for other players within radius
    for _, player in ipairs(GetActivePlayers()) do
        local targetPed = GetPlayerPed(player)
        
        if targetPed ~= playerPed then
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(playerCoords - targetCoords)
            
            if distance <= radius then
                foundPlayers = foundPlayers + 1
                local serverId = GetPlayerServerId(player)
                
                players[foundPlayers] = {
                    serverId = serverId,
                    distance = math.floor(distance),
                    heading = GetEntityHeading(targetPed),
                    isVisible = HasEntityClearLosToEntity(playerPed, targetPed, 17)
                }
            end
        end
    end
    
    return players
end)

-- Callback to check police presence within an area
lib.callback.register('qbx_heists:client:CheckPoliceInArea', function(coords, radius)
    local playerCoords = coords or GetEntityCoords(PlayerPedId())
    local radius = radius or 100.0
    
    local policeCount = 0
    
    for _, player in ipairs(GetActivePlayers()) do
        local targetPed = GetPlayerPed(player)
        local targetCoords = GetEntityCoords(targetPed)
        local distance = #(playerCoords - targetCoords)
        
        if distance <= radius then
            local serverId = GetPlayerServerId(player)
            
            -- Use the server callback to check if this player is police
            -- This is more secure than checking on client only
            local isPolice = lib.callback.await('qbx_heists:server:IsPlayerPolice', false, serverId)
            
            if isPolice then
                policeCount = policeCount + 1
            end
        end
    end
    
    return policeCount
end)

-- Callback for running a minigame and returning the result
lib.callback.register('qbx_heists:client:RunMinigame', function(minigameType, difficulty)
    local p = promise.new()
    
    if minigameType == 'lockpick' then
        exports['lockpick']:StartLockpick(difficulty, function(success)
            p:resolve(success)
        end)
    elseif minigameType == 'hacking' then
        exports['hacking']:StartHackingGame(difficulty, function(success)
            p:resolve(success)
        end)
    elseif minigameType == 'thermite' then
        exports['thermite']:StartThermiteGame(difficulty, function(success)
            p:resolve(success)
        end)
    elseif minigameType == 'voltlab' then
        exports['ultra-voltlab']:StartGame(function(result)
            p:resolve(result)
        end)
    elseif minigameType == 'bolt' then
        local time = difficulty == 'easy' and 10 or (difficulty == 'medium' and 7 or 5)
        exports['ls_bolt_minigame']:StartMinigame(time, function(result)
            p:resolve(result)
        end)
    else
        p:resolve(false)
    end
    
    return Citizen.Await(p)
end)

-- Callback to interact with an object in the world
lib.callback.register('qbx_heists:client:InteractWithObject', function(objectModel, coords, interactionType)
    local objectFound = false
    local nearbyObject = nil
    
    -- Try to find the object
    if coords then
        nearbyObject = GetClosestObjectOfType(
            coords.x, coords.y, coords.z,
            2.0, -- radius
            GetHashKey(objectModel),
            false, false, false
        )
    end
    
    if nearbyObject and DoesEntityExist(nearbyObject) then
        objectFound = true
        
        -- Perform the requested interaction
        if interactionType == 'delete' then
            SetEntityAsMissionEntity(nearbyObject, true, true)
            DeleteObject(nearbyObject)
            return true, "Object deleted"
        elseif interactionType == 'door_open' then
            local doorHeading = GetEntityHeading(nearbyObject)
            SetEntityHeading(nearbyObject, doorHeading + 90.0)
            return true, "Door opened"
        elseif interactionType == 'explosion' then
            local objectCoords = GetEntityCoords(nearbyObject)
            AddExplosion(objectCoords.x, objectCoords.y, objectCoords.z, 2, 0.5, true, false, 1.0)
            SetEntityAsMissionEntity(nearbyObject, true, true)
            DeleteObject(nearbyObject)
            return true, "Object exploded"
        end
    end
    
    if not objectFound then
        return false, "Object not found"
    end
    
    return false, "Interaction not supported"
end)

-- Callback to place an object in the world
lib.callback.register('qbx_heists:client:PlaceObject', function(objectModel, offset)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local playerHeading = GetEntityHeading(playerPed)
    
    -- Calculate position in front of player
    local offsetDist = offset and offset.distance or 1.0
    local offsetHeight = offset and offset.height or 0.0
    
    local radians = math.rad(playerHeading)
    local newX = playerCoords.x + offsetDist * math.sin(-radians)
    local newY = playerCoords.y + offsetDist * math.cos(-radians)
    local newZ = playerCoords.z - 1.0 + offsetHeight
    
    -- Request the model
    local modelHash = GetHashKey(objectModel)
    RequestModel(modelHash)
    local attempts = 0
    
    while not HasModelLoaded(modelHash) and attempts < 100 do
        attempts = attempts + 1
        Wait(10)
    end
    
    if not HasModelLoaded(modelHash) then
        return false, "Failed to load object model"
    end
    
    -- Create the object
    local object = CreateObject(
        modelHash,
        newX, newY, newZ,
        true, false, false
    )
    
    if not DoesEntityExist(object) then
        return false, "Failed to create object"
    end
    
    -- Set object properties
    SetEntityHeading(object, playerHeading)
    PlaceObjectOnGroundProperly(object)
    SetModelAsNoLongerNeeded(modelHash)
    
    return true, object
end)

-- Callback to play an animation
lib.callback.register('qbx_heists:client:PlayAnimation', function(animDict, animName, duration, flags)
    local playerPed = PlayerPedId()
    local duration = duration or 3000
    local flags = flags or 49
    
    -- Request the animation dictionary
    RequestAnimDict(animDict)
    local attempts = 0
    
    while not HasAnimDictLoaded(animDict) and attempts < 100 do
        attempts = attempts + 1
        Wait(10)
    end
    
    if not HasAnimDictLoaded(animDict) then
        return false, "Failed to load animation"
    end
    
    -- Play the animation
    TaskPlayAnim(playerPed, animDict, animName, 8.0, 8.0, duration, flags, 0, false, false, false)
    
    -- Free the animation dictionary
    RemoveAnimDict(animDict)
    
    return true, "Animation played"
end)

-- Callback to enable/disable robbery mode (police dispatch)
lib.callback.register('qbx_heists:client:SetRobberyMode', function(enable, duration)
    if enable then
        -- Call the dispatch system if available
        if exports['ps-dispatch'] then
            -- Set robbery mode active, disable automatic calls
            exports['ps-dispatch']:DisableDispatchAlerts({'bankrobbery', 'storerobbery', 'houserobbery'})
            
            if duration then
                -- Set a timer to revert after duration
                Citizen.SetTimeout(duration, function()
                    exports['ps-dispatch']:EnableDispatchAlerts({'bankrobbery', 'storerobbery', 'houserobbery'})
                end)
            end
            
            return true, "Robbery mode enabled"
        elseif exports['cd_dispatch'] then
            -- Alternative dispatch system
            exports['cd_dispatch']:BlockCalls({'bankrobbery', 'storerobbery', 'houserobbery'})
            
            if duration then
                Citizen.SetTimeout(duration, function()
                    exports['cd_dispatch']:UnblockCalls({'bankrobbery', 'storerobbery', 'houserobbery'})
                end)
            end
            
            return true, "Robbery mode enabled"
        end
    else
        -- Disable robbery mode, re-enable automatic calls
        if exports['ps-dispatch'] then
            exports['ps-dispatch']:EnableDispatchAlerts({'bankrobbery', 'storerobbery', 'houserobbery'})
            return true, "Robbery mode disabled"
        elseif exports['cd_dispatch'] then
            exports['cd_dispatch']:UnblockCalls({'bankrobbery', 'storerobbery', 'houserobbery'})
            return true, "Robbery mode disabled"
        end
    end
    
    return false, "Dispatch system not found"
end) 