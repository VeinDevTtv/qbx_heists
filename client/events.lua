-- Events file for handling heist-related client events
local QBX = exports['qbx_core']:GetCoreObject()

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