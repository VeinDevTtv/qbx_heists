-- convenience_store.lua - Client-side implementation for convenience store heist

local QBX = exports['qbx_core']:GetCoreObject()
local isHeistActive = false
local currentStage = 0
local heistLocation = nil
local heistBlip = nil
local safeOpen = false
local registerOpen = false

-- Event listener for setting up the heist
RegisterNetEvent('qbx_heists:client:convenience_store:SetupHeist', function(location)
    -- Store heist data
    isHeistActive = true
    currentStage = 1
    heistLocation = location
    
    -- Create blip for the heist location
    if heistBlip then RemoveBlip(heistBlip) end
    heistBlip = AddBlipForCoord(location.position.x, location.position.y, location.position.z)
    SetBlipSprite(heistBlip, 52) -- Dollar sign
    SetBlipDisplay(heistBlip, 4)
    SetBlipScale(heistBlip, 0.8)
    SetBlipColour(heistBlip, 1) -- Red
    SetBlipAsShortRange(heistBlip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Heist: " .. location.label)
    EndTextCommandSetBlipName(heistBlip)
    SetBlipRoute(heistBlip, true)
    
    -- Show notification
    QBX.Functions.Notify('Convenience store heist started at ' .. location.label, 'success')
    
    -- Start first stage: preparation
    TriggerEvent('qbx_heists:client:convenience_store:StartPreparation')
end)

-- Event for starting the preparation stage
RegisterNetEvent('qbx_heists:client:convenience_store:StartPreparation', function()
    -- Show objective
    QBX.Functions.Notify('Stage 1: Prepare by scouting the store. Find the cash register and safe.', 'primary')
    
    -- Create target zones for interaction
    exports.ox_target:addSphereZone({
        coords = vector3(
            heistLocation.position.x, 
            heistLocation.position.y, 
            heistLocation.position.z
        ),
        radius = 15.0,
        debug = false,
        options = {
            {
                name = 'heist_store_scout',
                icon = 'fas fa-eye',
                label = 'Scout the Location',
                canInteract = function()
                    return isHeistActive and currentStage == 1
                end,
                onSelect = function()
                    -- Start scouting animation
                    TaskStartScenarioInPlace(PlayerPedId(), 'WORLD_HUMAN_BINOCULARS', 0, true)
                    
                    -- Progress bar for scouting
                    if lib.progressBar({
                        duration = 10000,
                        label = 'Scouting the location...',
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
                        }
                    }) then
                        -- Successfully scouted
                        ClearPedTasks(PlayerPedId())
                        
                        -- Complete preparation stage
                        QBX.Functions.Notify('You have finished scouting. Ready to begin the heist.', 'success')
                        TriggerServerEvent('qbx_heists:server:convenience_store:CompleteStage', 1, true)
                        
                        -- Move to execution stage
                        currentStage = 2
                        TriggerEvent('qbx_heists:client:convenience_store:StartExecution')
                    else
                        -- Cancelled scouting
                        ClearPedTasks(PlayerPedId())
                        QBX.Functions.Notify('Scouting cancelled', 'error')
                    end
                end
            }
        }
    })
end)

-- Event for starting the execution stage
RegisterNetEvent('qbx_heists:client:convenience_store:StartExecution', function()
    -- Show objective
    QBX.Functions.Notify('Stage 2: Execute the heist - crack the register and safe', 'primary')
    
    -- Create register and safe zones
    local registerPos = vector3(
        heistLocation.position.x + 2.0, 
        heistLocation.position.y + 1.0, 
        heistLocation.position.z
    )
    
    local safePos = vector3(
        heistLocation.position.x - 2.0, 
        heistLocation.position.y - 2.0, 
        heistLocation.position.z
    )
    
    -- Add register target
    exports.ox_target:addSphereZone({
        coords = registerPos,
        radius = 1.0,
        debug = false,
        options = {
            {
                name = 'heist_register_crack',
                icon = 'fas fa-cash-register',
                label = 'Crack the Register',
                canInteract = function()
                    return isHeistActive and currentStage == 2 and not registerOpen
                end,
                onSelect = function()
                    -- Check if player has required item: lockpick
                    local hasLockpick = lib.callback.await('qbx_heists:server:GetItemCount', false, 'lockpick') > 0
                    
                    if not hasLockpick then
                        QBX.Functions.Notify('You need a lockpick to crack the register', 'error')
                        return
                    end
                    
                    -- Start cracking animation
                    TaskStartScenarioInPlace(PlayerPedId(), 'PROP_HUMAN_BUM_BIN', 0, true)
                    
                    -- Progress bar for cracking
                    if lib.progressBar({
                        duration = 15000,
                        label = 'Cracking the register...',
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
                        }
                    }) then
                        -- Successfully cracked
                        ClearPedTasks(PlayerPedId())
                        
                        -- Mark register as open
                        registerOpen = true
                        
                        -- Notify player
                        QBX.Functions.Notify('You cracked the register!', 'success')
                        
                        -- Check if both register and safe are open
                        if registerOpen and safeOpen then
                            -- Complete execution stage
                            TriggerServerEvent('qbx_heists:server:convenience_store:CompleteStage', 2, true)
                            
                            -- Move to escape stage
                            currentStage = 3
                            TriggerEvent('qbx_heists:client:convenience_store:StartEscape')
                        end
                    else
                        -- Cancelled cracking
                        ClearPedTasks(PlayerPedId())
                        QBX.Functions.Notify('Register cracking cancelled', 'error')
                    end
                end
            }
        }
    })
    
    -- Add safe target
    exports.ox_target:addSphereZone({
        coords = safePos,
        radius = 1.0,
        debug = false,
        options = {
            {
                name = 'heist_safe_crack',
                icon = 'fas fa-lock',
                label = 'Crack the Safe',
                canInteract = function()
                    return isHeistActive and currentStage == 2 and not safeOpen
                end,
                onSelect = function()
                    -- Check if player has required item: hacking device
                    local hasHackingDevice = lib.callback.await('qbx_heists:server:GetItemCount', false, 'hacking_device') > 0
                    
                    if not hasHackingDevice then
                        QBX.Functions.Notify('You need a hacking device to crack the safe', 'error')
                        return
                    end
                    
                    -- Get safe code from server
                    local safeCode = lib.callback.await('qbx_heists:server:convenience_store:GetSafeCode', false)
                    
                    -- Show input dialog for safe code
                    local input = lib.inputDialog('Safe Code', {
                        {type = 'input', label = 'Enter Code', placeholder = '****'}
                    })
                    
                    if not input or not input[1] then return end
                    
                    -- Check if code is correct
                    if input[1] == safeCode then
                        -- Start safe opening animation
                        TaskStartScenarioInPlace(PlayerPedId(), 'PROP_HUMAN_BUM_BIN', 0, true)
                        
                        -- Progress bar for opening safe
                        if lib.progressBar({
                            duration = 20000,
                            label = 'Opening the safe...',
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
                            }
                        }) then
                            -- Successfully opened
                            ClearPedTasks(PlayerPedId())
                            
                            -- Mark safe as open
                            safeOpen = true
                            
                            -- Notify player
                            QBX.Functions.Notify('You opened the safe!', 'success')
                            
                            -- Check if both register and safe are open
                            if registerOpen and safeOpen then
                                -- Complete execution stage
                                TriggerServerEvent('qbx_heists:server:convenience_store:CompleteStage', 2, true)
                                
                                -- Move to escape stage
                                currentStage = 3
                                TriggerEvent('qbx_heists:client:convenience_store:StartEscape')
                            end
                        else
                            -- Cancelled opening
                            ClearPedTasks(PlayerPedId())
                            QBX.Functions.Notify('Safe opening cancelled', 'error')
                        end
                    else
                        -- Incorrect code
                        QBX.Functions.Notify('Incorrect safe code!', 'error')
                    end
                end
            }
        }
    })
end)

-- Event for starting the escape stage
RegisterNetEvent('qbx_heists:client:convenience_store:StartEscape', function()
    -- Show objective
    QBX.Functions.Notify('Stage 3: Escape with the loot - reach the escape point!', 'primary')
    
    -- Create escape point 100-200m away from the store
    local playerPos = GetEntityCoords(PlayerPedId())
    local angle = math.random() * math.pi * 2
    local distance = math.random(100, 200)
    local escapePos = vector3(
        playerPos.x + math.cos(angle) * distance,
        playerPos.y + math.sin(angle) * distance,
        playerPos.z
    )
    
    -- Create blip for escape point
    if heistBlip then RemoveBlip(heistBlip) end
    heistBlip = AddBlipForCoord(escapePos.x, escapePos.y, escapePos.z)
    SetBlipSprite(heistBlip, 126) -- Car blip
    SetBlipDisplay(heistBlip, 4)
    SetBlipScale(heistBlip, 0.8)
    SetBlipColour(heistBlip, 2) -- Green
    SetBlipAsShortRange(heistBlip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Heist Escape Point")
    EndTextCommandSetBlipName(heistBlip)
    SetBlipRoute(heistBlip, true)
    
    -- Create escape zone
    exports.ox_target:addSphereZone({
        coords = escapePos,
        radius = 5.0,
        debug = false,
        options = {
            {
                name = 'heist_escape',
                icon = 'fas fa-running',
                label = 'Escape with Loot',
                canInteract = function()
                    return isHeistActive and currentStage == 3
                end,
                onSelect = function()
                    -- Complete escape stage
                    TriggerServerEvent('qbx_heists:server:convenience_store:CompleteStage', 3, true)
                    
                    -- Clean up
                    if heistBlip then RemoveBlip(heistBlip) end
                    isHeistActive = false
                    currentStage = 0
                    heistLocation = nil
                    safeOpen = false
                    registerOpen = false
                    
                    -- Notify player
                    QBX.Functions.Notify('Heist completed successfully!', 'success')
                end
            }
        }
    })
    
    -- Start police chase chance logic
    local policeChance = math.random(1, 100)
    if policeChance <= 70 then -- 70% chance of police chase
        -- Create NPC police chase (optional implementation)
        -- This would spawn police NPCs to chase the player
        QBX.Functions.Notify('The police are after you! Escape quickly!', 'error')
    end
end)

-- Helper function to reset the heist
function ResetConvenienceStoreHeist()
    if heistBlip then RemoveBlip(heistBlip) end
    isHeistActive = false
    currentStage = 0
    heistLocation = nil
    safeOpen = false
    registerOpen = false
end

-- Event for when the heist fails
RegisterNetEvent('qbx_heists:client:HeistFailed', function()
    QBX.Functions.Notify('The heist has failed!', 'error')
    ResetConvenienceStoreHeist()
end)

-- Event for when the heist completes
RegisterNetEvent('qbx_heists:client:HeistCompleted', function(result)
    QBX.Functions.Notify('The heist has been completed! Payout: $' .. result.payoutPerPlayer, 'success')
    ResetConvenienceStoreHeist()
end)

-- Create command for starting the heist (for testing)
RegisterCommand('convenientstore', function()
    local locations = Config.Heists.convenience_store.locations
    local locationId = 1 -- Use first location by default
    TriggerServerEvent('qbx_heists:server:convenience_store:StartHeist', locationId)
end, false) 