-- Events file for handling heist-related client events
local QBX = exports['qbx_core']:GetCoreObject()
local activeHeist = nil
local currentStage = 0
local heistBlips = {}
local objectiveMarkers = {}

-- Common function to handle minigames with different difficulty levels based on heist type
local function HandleMinigame(data, minigameType)
    -- Default difficulty
    local difficulty = 'medium'
    
    -- Adjust difficulty based on heist type
    if data.type == 'convenience_store' or data.type == 'small_bank' then
        difficulty = 'easy'
    elseif data.type == 'large_bank' or data.type == 'yacht_heist' or data.type == 'casino_heist' then
        difficulty = 'hard'
    end
    
    -- Success rates from config
    local successRate = Config.MinigameSuccess[minigameType] or 70
    
    -- Handle different minigame types
    local success = false
    
    if minigameType == 'lockpicking' then
        -- Lockpicking minigame
        if exports['ls_bolt_minigame']:StartBoltGame(5, difficulty, 5) then
            success = true
        end
    elseif minigameType == 'hacking' then
        -- Hacking minigame
        exports['ultra-voltlab']:StartGame({
            difficulty = difficulty
        }, function(result)
            success = result
        end)
        
        -- Wait for minigame to complete (with timeout)
        local timeout = 30000 -- 30 seconds timeout
        local startTime = GetGameTimer()
        
        while success == false and GetGameTimer() - startTime < timeout do
            Wait(100)
        end
    elseif minigameType == 'drilling' then
        -- Drilling minigame - simulate with skillcheck
        exports['ox_lib']:skillCheck({'easy', 'medium', 'easy'})
    elseif minigameType == 'thermite' then
        -- Thermite minigame - simulate with skillcheck
        success = exports['ox_lib']:skillCheck({'hard', 'medium', 'hard'})
    else
        -- Default to skillcheck for any other type
        success = exports['ox_lib']:skillCheck({'easy', 'medium', 'hard'})
    end
    
    return success
end

-- Function to complete a stage and send success to server
local function CompleteStage(success)
    local result = lib.callback.await('qbx_heists:server:CompleteStage', false, success)
    return result
end

-- Preparation stage events

-- Event for preparing heist equipment
RegisterNetEvent('qbx_heists:client:PrepareEquipment', function(data)
    -- Check if the player has the required items
    local heistConfig = Config.Heists[data.type]
    if not heistConfig then return end
    
    -- Show a progress bar for preparing equipment
    if lib.progressBar({
        duration = 10000,
        label = 'Preparing heist equipment...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'mini@repair',
            clip = 'fixing_a_ped'
        },
    }) then
        -- Send success to server
        local result = CompleteStage(true)
        
        if result and result.success then
            QBX.Functions.Notify('Equipment prepared successfully!', 'success')
        else
            QBX.Functions.Notify('Something went wrong...', 'error')
        end
    else
        QBX.Functions.Notify('Preparation cancelled', 'error')
    end
end)

-- Event for scouting location
RegisterNetEvent('qbx_heists:client:ScoutLocation', function(data)
    -- Show a progress bar for scouting
    if lib.progressBar({
        duration = 7500,
        label = 'Scouting the area...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
        },
        anim = {
            dict = 'amb@world_human_binoculars@male@idle_a',
            clip = 'idle_c',
            flags = 49,
        },
        prop = {
            model = `prop_binoc_01`,
            bone = 28422,
            pos = vec3(0.0, 0.0, 0.0),
            rot = vec3(0.0, 0.0, 0.0)
        },
    }) then
        -- Show some information about the location
        QBX.Functions.Notify('You have identified potential entry points', 'success')
        Wait(1000)
        QBX.Functions.Notify('Security level appears to be moderate', 'primary')
        Wait(1000)
        QBX.Functions.Notify('Scouting completed successfully!', 'success')
        
        -- Send success to server
        CompleteStage(true)
    else
        QBX.Functions.Notify('Scouting cancelled', 'error')
    end
end)

-- Event for disabling alarm system
RegisterNetEvent('qbx_heists:client:DisableAlarm', function(data)
    -- Start lockpicking minigame
    QBX.Functions.Notify('You need to disable the alarm system', 'primary')
    
    local success = HandleMinigame(data, 'lockpicking')
    
    if success then
        -- Show success message
        QBX.Functions.Notify(Lang:t('success.lockpick_success'), 'success')
        
        -- Start a progress bar for disabling the alarm
        if lib.progressBar({
            duration = 5000,
            label = 'Cutting wires...',
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true,
                combat = true
            },
            anim = {
                dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
                clip = 'machinic_loop_mechandplayer',
            },
            prop = {
                model = `prop_tool_pliers`,
                bone = 28422,
                pos = vec3(0.0, 0.05, 0.0),
                rot = vec3(0.0, 0.0, 0.0)
            },
        }) then
            -- Send success to server
            CompleteStage(true)
        else
            QBX.Functions.Notify('Alarm system disabling cancelled', 'error')
        end
    else
        -- Show failure message
        QBX.Functions.Notify(Lang:t('error.minigame_failed', {minigame = 'lockpicking'}), 'error')
        
        -- Check if should alert police
        if math.random(1, 100) <= Config.PoliceAlertChance then
            -- Alert police
            exports['qbx_dispatch']:StoreRobbery()
            QBX.Functions.Notify(Lang:t('info.police_alert'), 'error')
        end
    end
end)

-- Event for hacking security system
RegisterNetEvent('qbx_heists:client:HackSecurity', function(data)
    -- Start hacking minigame
    QBX.Functions.Notify('You need to hack the security system', 'primary')
    
    local success = HandleMinigame(data, 'hacking')
    
    if success then
        -- Show success message
        QBX.Functions.Notify(Lang:t('success.hack_success'), 'success')
        
        -- Start a progress bar for planting a backdoor
        if lib.progressBar({
            duration = 7500,
            label = 'Planting backdoor in system...',
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true,
                combat = true
            },
            anim = {
                dict = 'anim@heists@ornate_bank@hack',
                clip = 'hack_loop',
            },
            prop = {
                model = `prop_laptop_01a`,
                bone = 28422,
                pos = vec3(0.0, -0.15, 0.0),
                rot = vec3(0.0, 0.0, 0.0)
            },
        }) then
            -- Send success to server
            CompleteStage(true)
        else
            QBX.Functions.Notify('Security system hacking cancelled', 'error')
        end
    else
        -- Show failure message
        QBX.Functions.Notify(Lang:t('error.minigame_failed', {minigame = 'hacking'}), 'error')
        
        -- Check if should alert police
        if math.random(1, 100) <= Config.PoliceAlertChance then
            -- Alert police
            exports['qbx_dispatch']:StoreRobbery()
            QBX.Functions.Notify(Lang:t('info.police_alert'), 'error')
        end
    end
end)

-- Event for planting explosives
RegisterNetEvent('qbx_heists:client:PlantExplosives', function(data)
    -- Check if player has required items
    local hasExplosives = lib.callback.await('ox_inventory:getItemCount', false, 'c4') > 0
    
    if not hasExplosives then
        QBX.Functions.Notify('You need C4 explosives', 'error')
        return
    end
    
    -- Start a progress bar for planting explosives
    if lib.progressBar({
        duration = 10000,
        label = 'Planting explosives...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'anim@heists@ornate_bank@thermal_charge',
            clip = 'thermal_charge',
        },
        prop = {
            model = `prop_c4_final_green`,
            bone = 28422,
            pos = vec3(0.0, 0.0, 0.0),
            rot = vec3(0.0, 0.0, 0.0)
        },
    }) then
        -- Remove C4 from inventory
        TriggerServerEvent('ox_inventory:removeItem', 'c4', 1)
        
        -- Start a timer for detonation
        QBX.Functions.Notify('Explosives planted! Detonating in 10 seconds...', 'primary')
        
        -- Create prop
        local coords = GetEntityCoords(PlayerPedId())
        local prop = CreateObject(`prop_c4_final_green`, coords.x, coords.y, coords.z, true, false, false)
        SetEntityHeading(prop, GetEntityHeading(PlayerPedId()))
        PlaceObjectOnGroundProperly(prop)
        
        -- Wait for detonation
        Wait(10000)
        
        -- Explosion effect
        AddExplosion(coords.x, coords.y, coords.z, 'EXPLOSION_GRENADE', 0.5, true, false, 1.0)
        
        -- Delete prop
        DeleteObject(prop)
        
        -- Show success message
        QBX.Functions.Notify(Lang:t('success.thermite_success'), 'success')
        
        -- Send success to server
        CompleteStage(true)
    else
        QBX.Functions.Notify('Explosive planting cancelled', 'error')
    end
end)

-- Execution stage events

-- Event for grabbing loot
RegisterNetEvent('qbx_heists:client:GrabLoot', function(data)
    -- Start a progress bar for grabbing loot
    if lib.progressBar({
        duration = 7500,
        label = 'Grabbing loot...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'mp_common',
            clip = 'givetake1_a',
        },
    }) then
        -- Show success message
        QBX.Functions.Notify('You grabbed some valuable items!', 'success')
        
        -- Give some random items
        TriggerServerEvent('ox_inventory:addItem', 'money', math.random(500, 2000))
        
        -- Send success to server
        CompleteStage(true)
    else
        QBX.Functions.Notify('Loot grabbing cancelled', 'error')
    end
end)

-- Event for breaking open safe
RegisterNetEvent('qbx_heists:client:BreakSafe', function(data)
    -- Check if player has required items
    local hasDrill = lib.callback.await('ox_inventory:getItemCount', false, 'drill') > 0
    
    if not hasDrill then
        QBX.Functions.Notify('You need a drill to break open the safe', 'error')
        return
    end
    
    -- Start drilling minigame
    QBX.Functions.Notify('You need to drill the safe', 'primary')
    
    local success = HandleMinigame(data, 'drilling')
    
    if success then
        -- Show success message
        QBX.Functions.Notify(Lang:t('success.drill_success'), 'success')
        
        -- Start a progress bar for opening the safe
        if lib.progressBar({
            duration = 10000,
            label = 'Breaking open safe...',
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true,
                combat = true
            },
            anim = {
                dict = 'anim@heists@fleeca_bank@drilling',
                clip = 'drill_straight_idle',
            },
            prop = {
                model = `prop_tool_drill`,
                bone = 28422,
                pos = vec3(0.0, 0.0, 0.0),
                rot = vec3(0.0, 0.0, 0.0)
            },
        }) then
            -- Send success to server
            CompleteStage(true)
        else
            QBX.Functions.Notify('Safe breaking cancelled', 'error')
        end
    else
        -- Show failure message
        QBX.Functions.Notify(Lang:t('error.minigame_failed', {minigame = 'drilling'}), 'error')
        
        -- Check if should alert police
        if math.random(1, 100) <= Config.PoliceAlertChance then
            -- Alert police
            exports['qbx_dispatch']:StoreRobbery()
            QBX.Functions.Notify(Lang:t('info.police_alert'), 'error')
        end
    end
end)

-- Event for smashing display cases
RegisterNetEvent('qbx_heists:client:SmashDisplays', function(data)
    -- Check if player has required items
    local hasHammer = lib.callback.await('ox_inventory:getItemCount', false, 'hammer') > 0
    
    if not hasHammer then
        QBX.Functions.Notify('You need a hammer to smash the displays', 'error')
        return
    end
    
    -- Start a progress bar for smashing displays
    if lib.progressBar({
        duration = 5000,
        label = 'Smashing display cases...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'melee@large_wpn@streamed_core',
            clip = 'ground_attack_on_spot',
        },
        prop = {
            model = `prop_tool_hammer`,
            bone = 28422,
            pos = vec3(0.0, 0.0, 0.0),
            rot = vec3(0.0, 0.0, 0.0)
        },
    }) then
        -- Show success message
        QBX.Functions.Notify('You smashed the display cases!', 'success')
        
        -- Play sound effect
        TriggerServerEvent('InteractSound_SV:PlayOnSource', 'breaking_display_glass', 0.25)
        
        -- Send success to server
        CompleteStage(true)
    else
        QBX.Functions.Notify('Display smashing cancelled', 'error')
    end
end)

-- Event for drilling vault
RegisterNetEvent('qbx_heists:client:DrillVault', function(data)
    -- Check if player has required items
    local hasDrill = lib.callback.await('ox_inventory:getItemCount', false, 'drill') > 0
    
    if not hasDrill then
        QBX.Functions.Notify('You need a drill to break into the vault', 'error')
        return
    end
    
    -- Start drilling minigame
    QBX.Functions.Notify('You need to drill into the vault', 'primary')
    
    local success = HandleMinigame(data, 'drilling')
    
    if success then
        -- Show success message
        QBX.Functions.Notify(Lang:t('success.drill_success'), 'success')
        
        -- Start a progress bar for drilling vault
        if lib.progressBar({
            duration = 15000,
            label = 'Drilling vault...',
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true,
                combat = true
            },
            anim = {
                dict = 'anim@heists@fleeca_bank@drilling',
                clip = 'drill_straight_idle',
            },
            prop = {
                model = `prop_tool_drill`,
                bone = 28422,
                pos = vec3(0.0, 0.0, 0.0),
                rot = vec3(0.0, 0.0, 0.0)
            },
        }) then
            -- Send success to server
            CompleteStage(true)
        else
            QBX.Functions.Notify('Vault drilling cancelled', 'error')
        end
    else
        -- Show failure message
        QBX.Functions.Notify(Lang:t('error.minigame_failed', {minigame = 'drilling'}), 'error')
        
        -- Check if should alert police
        if math.random(1, 100) <= Config.PoliceAlertChance then
            -- Alert police
            exports['qbx_dispatch']:StoreRobbery()
            QBX.Functions.Notify(Lang:t('info.police_alert'), 'error')
        end
    end
end)

-- Event for detaching cargo
RegisterNetEvent('qbx_heists:client:DetachCargo', function(data)
    -- Check if player has required items
    local hasBoltCutter = lib.callback.await('ox_inventory:getItemCount', false, 'bolt_cutter') > 0
    
    if not hasBoltCutter then
        QBX.Functions.Notify('You need bolt cutters to detach the cargo', 'error')
        return
    end
    
    -- Start a progress bar for detaching cargo
    if lib.progressBar({
        duration = 10000,
        label = 'Detaching cargo...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'mini@repair',
            clip = 'fixing_a_ped',
        },
        prop = {
            model = `prop_tool_cut`,
            bone = 28422,
            pos = vec3(0.0, 0.0, 0.0),
            rot = vec3(0.0, 0.0, 0.0)
        },
    }) then
        -- Show success message
        QBX.Functions.Notify('You detached the cargo!', 'success')
        
        -- Send success to server
        CompleteStage(true)
    else
        QBX.Functions.Notify('Cargo detaching cancelled', 'error')
    end
end)

-- Event for accessing hidden room
RegisterNetEvent('qbx_heists:client:AccessHiddenRoom', function(data)
    -- Check if player has required items
    local hasCard = lib.callback.await('ox_inventory:getItemCount', false, 'secure_card_02') > 0
    
    if not hasCard then
        QBX.Functions.Notify('You need a security card to access the hidden room', 'error')
        return
    end
    
    -- Start a progress bar for accessing hidden room
    if lib.progressBar({
        duration = 7500,
        label = 'Accessing hidden room...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'anim@heists@keycard@',
            clip = 'exit',
        },
        prop = {
            model = `prop_cs_credit_card`,
            bone = 28422,
            pos = vec3(0.0, 0.0, 0.0),
            rot = vec3(0.0, 0.0, 0.0)
        },
    }) then
        -- Show success message
        QBX.Functions.Notify('You accessed the hidden room!', 'success')
        
        -- Send success to server
        CompleteStage(true)
    else
        QBX.Functions.Notify('Hidden room access cancelled', 'error')
    end
end)

-- Event for hacking vault system
RegisterNetEvent('qbx_heists:client:HackVaultSystem', function(data)
    -- Check if player has required items
    local hasLaptop = lib.callback.await('ox_inventory:getItemCount', false, 'elite_laptop') > 0
    
    if not hasLaptop then
        QBX.Functions.Notify('You need an elite hacking laptop to hack the vault system', 'error')
        return
    end
    
    -- Start hacking minigame
    QBX.Functions.Notify('You need to hack the vault system', 'primary')
    
    local success = HandleMinigame(data, 'hacking')
    
    if success then
        -- Show success message
        QBX.Functions.Notify(Lang:t('success.hack_success'), 'success')
        
        -- Start a progress bar for hacking vault system
        if lib.progressBar({
            duration = 15000,
            label = 'Hacking vault system...',
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true,
                combat = true
            },
            anim = {
                dict = 'anim@heists@ornate_bank@hack',
                clip = 'hack_loop',
            },
            prop = {
                model = `prop_laptop_01a`,
                bone = 28422,
                pos = vec3(0.0, -0.15, 0.0),
                rot = vec3(0.0, 0.0, 0.0)
            },
        }) then
            -- Send success to server
            CompleteStage(true)
        else
            QBX.Functions.Notify('Vault system hacking cancelled', 'error')
        end
    else
        -- Show failure message
        QBX.Functions.Notify(Lang:t('error.minigame_failed', {minigame = 'hacking'}), 'error')
        
        -- Check if should alert police
        if math.random(1, 100) <= Config.PoliceAlertChance then
            -- Alert police
            exports['qbx_dispatch']:StoreRobbery()
            QBX.Functions.Notify(Lang:t('info.police_alert'), 'error')
        end
    end
end)

-- Escape stage events

-- Event for reaching escape point
RegisterNetEvent('qbx_heists:client:ReachEscapePoint', function(data)
    -- Start a progress bar for escaping
    if lib.progressBar({
        duration = 5000,
        label = 'Escaping with loot...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
        },
    }) then
        -- Show success message
        QBX.Functions.Notify('You escaped with the loot!', 'success')
        
        -- Send success to server
        CompleteStage(true)
    else
        QBX.Functions.Notify('Escape cancelled', 'error')
    end
end)

-- Command to join an active heist
RegisterCommand('joinheist', function()
    -- Check if player can join a heist
    if exports['qbx_heists']:IsPlayerInHeist() then
        QBX.Functions.Notify('You are already in a heist', 'error')
        return
    end
    
    -- Request to join a heist
    TriggerServerEvent('qbx_heists:server:JoinHeist')
end, false)

-- Create commands for common actions
RegisterCommand('heistinfo', function()
    -- Check if player is in a heist
    local heistData = exports['qbx_heists']:GetCurrentHeist()
    if not heistData then
        QBX.Functions.Notify('You are not in a heist', 'error')
        return
    end
    
    -- Show heist info
    QBX.Functions.Notify('Current Heist: ' .. heistData.name, 'primary')
    QBX.Functions.Notify('Stage: ' .. heistData.stage .. '/3', 'primary')
end, false)

-- Event triggered when a player joins a heist
RegisterNetEvent('qbx_heists:client:JoinHeist', function(heistData)
    activeHeist = heistData
    currentStage = 1
    
    -- Display notification
    lib.notify({
        title = 'Heist Joined',
        description = string.format('You joined a %s heist', heistData.type),
        type = 'success'
    })
    
    -- Create objective markers and blips
    CreateHeistBlips()
    SetupObjectiveMarkers()
    
    -- Start tracking progress
    StartHeistTracking()
end)

-- Event triggered when a heist is completed
RegisterNetEvent('qbx_heists:client:HeistCompleted', function(rewards)
    -- Clear active heist data
    ClearHeistData()
    
    -- Display reward notification
    lib.notify({
        title = 'Heist Completed',
        description = string.format('You earned $%s', rewards.money),
        type = 'success'
    })
    
    -- Add rewards animation/sound
    PlaySoundFrontend(-1, "PICK_UP", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
    
    -- Trigger laptop app update
    TriggerEvent('qbx_laptop:client:updateHeistData')
end)

-- Event triggered when a heist stage is completed
RegisterNetEvent('qbx_heists:client:StageCompleted', function(stageNum, nextStage)
    -- Update current stage
    currentStage = stageNum + 1
    
    -- Display notification
    lib.notify({
        title = 'Stage Completed',
        description = string.format('Moving to stage %s: %s', currentStage, nextStage.name),
        type = 'success'
    })
    
    -- Update objective markers
    ClearObjectiveMarkers()
    SetupObjectiveMarkers()
    
    -- Play success sound
    PlaySoundFrontend(-1, "Mission_Pass_Notify", "DLC_HEISTS_GENERAL_FRONTEND_SOUNDS", 1)
end)

-- Event triggered when a heist is failed
RegisterNetEvent('qbx_heists:client:HeistFailed', function(reason)
    -- Clear active heist data
    ClearHeistData()
    
    -- Display failure notification
    lib.notify({
        title = 'Heist Failed',
        description = reason,
        type = 'error'
    })
    
    -- Play failure sound
    PlaySoundFrontend(-1, "Fail", "DLC_HEISTS_GENERAL_FRONTEND_SOUNDS", 1)
    
    -- Trigger laptop app update
    TriggerEvent('qbx_laptop:client:updateHeistData')
end)

-- Event triggered when a heist is canceled
RegisterNetEvent('qbx_heists:client:HeistCanceled', function()
    -- Clear active heist data
    ClearHeistData()
    
    -- Display cancellation notification
    lib.notify({
        title = 'Heist Canceled',
        description = 'The heist has been canceled',
        type = 'primary'
    })
    
    -- Trigger laptop app update
    TriggerEvent('qbx_laptop:client:updateHeistData')
end)

-- Event for police alerts
RegisterNetEvent('qbx_heists:client:PoliceAlert', function(coords, heistType)
    -- Only trigger for police officers
    local PlayerData = QBX.Functions.GetPlayerData()
    if PlayerData.job.name ~= 'police' or not PlayerData.job.onduty then return end
    
    -- Display notification
    lib.notify({
        title = 'Heist Alert',
        description = string.format('Possible %s in progress', heistType),
        type = 'inform'
    })
    
    -- Create alert blip
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 161) -- Robbery blip sprite
    SetBlipColour(blip, 1) -- Red
    SetBlipAsShortRange(blip, false)
    SetBlipScale(blip, 1.2)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Heist in Progress")
    EndTextCommandSetBlipName(blip)
    
    -- Flash blip
    SetBlipFlashes(blip, true)
    
    -- Remove blip after 60 seconds
    Citizen.SetTimeout(60000, function()
        RemoveBlip(blip)
    end)
    
    -- Add route to the location
    SetNewWaypoint(coords.x, coords.y)
end)

-- Event for syncing heist timers
RegisterNetEvent('qbx_heists:client:SyncTimer', function(startTime, endTime)
    if not activeHeist then return end
    
    activeHeist.startTime = startTime
    activeHeist.endTime = endTime
    
    -- Update any UI elements displaying time
end)

-- Event for objective updates
RegisterNetEvent('qbx_heists:client:UpdateObjective', function(objectiveId, status)
    if not activeHeist then return end
    
    -- Find and update the objective
    for i, objective in ipairs(activeHeist.stages[currentStage].objectives) do
        if objective.id == objectiveId then
            objective.status = status
            
            -- Update any UI elements
            break
        end
    end
    
    -- If all objectives are complete, check if stage should advance
    CheckStageProgression()
end)

-- Event for updating gang territories (integration with qbx_graffiti)
RegisterNetEvent('qbx_heists:client:UpdateTerritories', function(territories)
    -- Update territory data in local state
    exports['qbx_heists']:SetTerritories(territories)
    
    -- Refresh any UI elements displaying territory information
    TriggerEvent('qbx_laptop:client:refreshTerritories')
end)

-- Event for displaying minigame
RegisterNetEvent('qbx_heists:client:StartMinigame', function(minigameType, difficulty, callback)
    -- Handle different minigame types
    if minigameType == 'lockpick' then
        exports['lockpick']:StartLockpick(difficulty, function(success)
            if callback then
                TriggerEvent(callback, success)
            end
        end)
    elseif minigameType == 'hacking' then
        exports['hacking']:StartHackingGame(difficulty, function(success)
            if callback then
                TriggerEvent(callback, success)
            end
        end)
    elseif minigameType == 'thermite' then
        exports['thermite']:StartThermiteGame(difficulty, function(success)
            if callback then
                TriggerEvent(callback, success)
            end
        end)
    elseif minigameType == 'voltlab' then
        exports['ultra-voltlab']:StartGame(function(result)
            if callback then
                TriggerEvent(callback, result)
            end
        end)
    elseif minigameType == 'bolt' then
        local time = difficulty == 'easy' and 10 or (difficulty == 'medium' and 7 or 5)
        exports['ls_bolt_minigame']:StartMinigame(time, function(result)
            if callback then
                TriggerEvent(callback, result)
            end
        end)
    end
end)

-- Helper functions
function CreateHeistBlips()
    if not activeHeist then return end
    
    -- Create blip for heist location
    local blip = AddBlipForCoord(activeHeist.location.x, activeHeist.location.y, activeHeist.location.z)
    SetBlipSprite(blip, 161) -- Robbery blip sprite
    SetBlipColour(blip, 5) -- Yellow
    SetBlipAsShortRange(blip, true)
    SetBlipScale(blip, 1.0)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(activeHeist.type .. " Heist")
    EndTextCommandSetBlipName(blip)
    
    table.insert(heistBlips, blip)
end

function SetupObjectiveMarkers()
    if not activeHeist or not activeHeist.stages[currentStage] then return end
    
    for _, objective in ipairs(activeHeist.stages[currentStage].objectives) do
        -- Only create markers for objectives that have positions and aren't completed
        if objective.position and objective.status ~= 'completed' then
            -- Create marker
            local markerId = CreateMarker(
                2, -- Type: ChevronUpCircle
                objective.position.x, 
                objective.position.y, 
                objective.position.z, 
                0.0, 0.0, 0.0, -- Dir
                0.0, 0.0, 0.0, -- Rot
                1.0, 1.0, 1.0, -- Scale
                100, 255, 100, 100, -- Color (RGBA)
                false, -- Bob
                false, -- Face camera
                2, -- p19
                false, -- Rotate
                nil, -- Texture dictionary
                nil, -- Texture name
                false -- Draw on entities
            )
            
            table.insert(objectiveMarkers, {
                id = markerId,
                objectiveId = objective.id,
                position = objective.position
            })
        end
    end
end

function ClearObjectiveMarkers()
    for _, marker in ipairs(objectiveMarkers) do
        DeleteMarker(marker.id)
    end
    objectiveMarkers = {}
end

function ClearHeistBlips()
    for _, blip in ipairs(heistBlips) do
        RemoveBlip(blip)
    end
    heistBlips = {}
end

function ClearHeistData()
    activeHeist = nil
    currentStage = 0
    ClearHeistBlips()
    ClearObjectiveMarkers()
    StopHeistTracking()
end

function StartHeistTracking()
    -- Start a thread to track heist progress
    Citizen.CreateThread(function()
        while activeHeist do
            -- Check player distance to objectives
            CheckObjectiveProximity()
            
            -- Check for heist timeout if applicable
            if activeHeist.timeout and GetGameTimer() > activeHeist.timeout then
                TriggerEvent('qbx_heists:client:HeistFailed', 'Time limit exceeded')
            end
            
            Citizen.Wait(1000) -- Check every second
        end
    end)
end

function StopHeistTracking()
    -- This is handled by setting activeHeist to nil, which will stop the tracking thread
end

function CheckObjectiveProximity()
    if not activeHeist or not activeHeist.stages[currentStage] then return end
    
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    for _, marker in ipairs(objectiveMarkers) do
        local distance = #(playerCoords - vector3(marker.position.x, marker.position.y, marker.position.z))
        
        -- If player is within 2.0 units of an objective marker
        if distance < 2.0 then
            -- Find the corresponding objective
            for _, objective in ipairs(activeHeist.stages[currentStage].objectives) do
                if objective.id == marker.objectiveId and objective.status ~= 'completed' then
                    -- Display help text
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName('Press ~INPUT_CONTEXT~ to ' .. objective.description)
                    EndTextCommandDisplayHelp(0, false, true, 5000)
                    
                    -- Check for interaction
                    if IsControlJustPressed(0, 38) then -- E key
                        TriggerServerEvent('qbx_heists:server:StartObjective', activeHeist.id, currentStage, objective.id)
                    end
                end
            end
        end
    end
end

function CheckStageProgression()
    if not activeHeist or not activeHeist.stages[currentStage] then return end
    
    local allCompleted = true
    for _, objective in ipairs(activeHeist.stages[currentStage].objectives) do
        if objective.status ~= 'completed' then
            allCompleted = false
            break
        end
    end
    
    if allCompleted then
        TriggerServerEvent('qbx_heists:server:StageCompleted', activeHeist.id, currentStage)
    end
end

-- Export helper functions
exports('GetActiveHeist', function()
    return activeHeist
end)

exports('GetCurrentStage', function()
    return currentStage
end)

exports('IsInHeist', function()
    return activeHeist ~= nil
end) 