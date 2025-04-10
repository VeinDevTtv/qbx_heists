local QBX = exports['qbx_core']:GetCoreObject()
local PlayerData = {}
local ActiveHeist = nil
local CurrentBlip = nil
local CurrentObjectiveBlip = nil
local CurrentHeistTargets = {}
local CanStartHeist = true

-- Initialize player data
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBX.Functions.GetPlayerData()
    -- Register the heist app in the laptop if the player is in a gang
    if PlayerData.gang.name ~= 'none' then
        RegisterHeistApp()
    end
end)

-- Update player data on gang change
RegisterNetEvent('QBCore:Client:OnGangUpdate', function(gang)
    PlayerData.gang = gang
    
    -- If player joins a gang, register the app
    if gang.name ~= 'none' then
        RegisterHeistApp()
    end
end)

-- Function to register the heist app in the laptop
function RegisterHeistApp()
    -- Register the Heists app in the laptop
    SendNUIMessage({
        Action = "Laptop/AddApp",
        App = "heists",
        Data = {
            Name = "Gang Heists",
            Icon = "fas fa-mask",
            Color = "#7851a9", -- Purple color
            Job = false,
            Gang = true,
            RequiresVPN = false,
            Creator = "High Stakes",
            Description = Lang:t('info.heist_app_desc'),
            Notifications = 0,
        }
    })
end

-- Handle NUI callbacks for the heist app
RegisterNUICallback("Laptop/Apps/OpenHeists", function(Data, Cb)
    -- Fetch heist data from server
    local HeistData = lib.callback.await('qbx_heists:server:GetHeistData', false)
    
    if not HeistData then
        Cb({Error = "Failed to fetch heist data"})
        return
    end
    
    if HeistData.error then
        Cb({Error = Lang:t('error.' .. HeistData.error)})
        return
    end
    
    -- Return heist data to NUI
    Cb(HeistData)
end)

-- Callback to start a heist
RegisterNUICallback("Laptop/Apps/Heists/StartHeist", function(Data, Cb)
    if not Data.type then
        Cb({Error = "Invalid heist type"})
        return
    end
    
    -- Check if player can start a heist
    if not CanStartHeist then
        Cb({Error = "You must wait before starting another heist"})
        return
    end
    
    -- Set cooldown on starting heists (to prevent spam)
    CanStartHeist = false
    SetTimeout(10000, function() -- 10 second cooldown
        CanStartHeist = true
    end)
    
    -- Request server to start the heist
    local result = lib.callback.await('qbx_heists:server:StartHeist', false, Data.type)
    
    if not result.success then
        Cb({Error = Lang:t('error.' .. result.message, result)})
        return
    end
    
    -- Return success and close the laptop UI
    Cb({success = true, message = Lang:t('success.heist_started')})
    
    -- Close the laptop
    TriggerEvent('qbx_laptop:client:CloseApplication')
end)

-- Callback to cancel a heist
RegisterNUICallback("Laptop/Apps/Heists/CancelHeist", function(Data, Cb)
    -- Request server to cancel the heist
    TriggerServerEvent('qbx_heists:server:CancelHeist')
    
    -- Return success
    Cb({success = true})
end)

-- Callback to purchase heist items
RegisterNUICallback("Laptop/Apps/Heists/PurchaseItem", function(Data, Cb)
    if not Data.item then
        Cb({Error = "Invalid item"})
        return
    end
    
    -- Request server to purchase the item
    local result = lib.callback.await('qbx_heists:server:PurchaseItem', false, Data.item)
    
    if not result.success then
        Cb({Error = Lang:t('error.' .. result.message, result)})
        return
    end
    
    -- Return success
    Cb({success = true, message = Lang:t('success.item_purchased', {item = result.item, price = result.price})})
end)

-- Function to create blip for heist location
local function CreateHeistBlip(location, label, type)
    -- Remove any existing blip
    if CurrentBlip then
        RemoveBlip(CurrentBlip)
        CurrentBlip = nil
    end
    
    -- Create new blip
    CurrentBlip = AddBlipForCoord(location.position.x, location.position.y, location.position.z)
    SetBlipSprite(CurrentBlip, 161) -- Robbery blip
    SetBlipDisplay(CurrentBlip, 4)
    SetBlipScale(CurrentBlip, 1.0)
    SetBlipColour(CurrentBlip, 1) -- Red
    SetBlipAsShortRange(CurrentBlip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(label .. " Heist")
    EndTextCommandSetBlipName(CurrentBlip)
    
    -- Create route to the heist
    SetBlipRoute(CurrentBlip, true)
    SetBlipRouteColour(CurrentBlip, 1)
end

-- Function to create blip for current objective
local function CreateObjectiveBlip(position, label)
    -- Remove any existing objective blip
    if CurrentObjectiveBlip then
        RemoveBlip(CurrentObjectiveBlip)
        CurrentObjectiveBlip = nil
    end
    
    -- Create new blip
    CurrentObjectiveBlip = AddBlipForCoord(position.x, position.y, position.z)
    SetBlipSprite(CurrentObjectiveBlip, 1) -- Standard blip
    SetBlipDisplay(CurrentObjectiveBlip, 4)
    SetBlipScale(CurrentObjectiveBlip, 0.8)
    SetBlipColour(CurrentObjectiveBlip, 5) -- Yellow
    SetBlipAsShortRange(CurrentObjectiveBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(label)
    EndTextCommandSetBlipName(CurrentObjectiveBlip)
    
    -- Create route to the objective
    SetBlipRoute(CurrentObjectiveBlip, true)
    SetBlipRouteColour(CurrentObjectiveBlip, 5)
end

-- Function to setup heist targets based on stage
local function SetupHeistTargets(heistType, location, stage, objective)
    -- Clear existing targets
    for _, target in ipairs(CurrentHeistTargets) do
        exports.ox_target:removeZone(target)
    end
    CurrentHeistTargets = {}
    
    -- Get heist config for this type
    local heistConfig = Config.Heists[heistType]
    if not heistConfig then return end
    
    -- Define target positions and actions based on heist type and stage
    local targets = {}
    local basePosition = vector3(location.position.x, location.position.y, location.position.z)
    
    if stage == 1 then -- Preparation stage
        -- Add preparation targets - usually places to set up or get items
        table.insert(targets, {
            position = basePosition + vector3(math.random(-3, 3), math.random(-3, 3), 0),
            label = "Prepare Heist Equipment",
            icon = "fas fa-toolbox",
            event = "qbx_heists:client:PrepareEquipment",
            canInteract = function()
                return ActiveHeist and ActiveHeist.stage == 1
            end
        })
        
        -- Additional targets depending on heist type
        if heistType == "convenience_store" or heistType == "small_bank" then
            table.insert(targets, {
                position = basePosition + vector3(math.random(-5, 5), math.random(-5, 5), 0),
                label = "Scout Location",
                icon = "fas fa-binoculars",
                event = "qbx_heists:client:ScoutLocation",
                canInteract = function()
                    return ActiveHeist and ActiveHeist.stage == 1
                end
            })
        elseif heistType == "jewelry_store" or heistType == "medium_bank" then
            table.insert(targets, {
                position = basePosition + vector3(math.random(-5, 5), math.random(-5, 5), 0),
                label = "Disable Alarm System",
                icon = "fas fa-bell-slash",
                event = "qbx_heists:client:DisableAlarm",
                canInteract = function()
                    return ActiveHeist and ActiveHeist.stage == 1
                end
            })
        elseif heistType == "large_bank" or heistType == "train_robbery" then
            table.insert(targets, {
                position = basePosition + vector3(math.random(-5, 5), math.random(-5, 5), 0),
                label = "Hack Security System",
                icon = "fas fa-laptop-code",
                event = "qbx_heists:client:HackSecurity",
                canInteract = function()
                    return ActiveHeist and ActiveHeist.stage == 1
                end
            })
        elseif heistType == "yacht_heist" or heistType == "casino_heist" then
            table.insert(targets, {
                position = basePosition + vector3(math.random(-5, 5), math.random(-5, 5), 0),
                label = "Plant Explosives",
                icon = "fas fa-bomb",
                event = "qbx_heists:client:PlantExplosives",
                canInteract = function()
                    return ActiveHeist and ActiveHeist.stage == 1
                end
            })
        end
    elseif stage == 2 then -- Execution stage
        -- Add execution targets - safes to crack, items to steal, etc.
        table.insert(targets, {
            position = basePosition + vector3(math.random(-3, 3), math.random(-3, 3), 0),
            label = "Grab Loot",
            icon = "fas fa-hand-holding-usd",
            event = "qbx_heists:client:GrabLoot",
            canInteract = function()
                return ActiveHeist and ActiveHeist.stage == 2
            end
        })
        
        -- Additional targets depending on heist type
        if heistType == "convenience_store" or heistType == "small_bank" then
            table.insert(targets, {
                position = basePosition + vector3(math.random(-5, 5), math.random(-5, 5), 0),
                label = "Break Open Safe",
                icon = "fas fa-unlock",
                event = "qbx_heists:client:BreakSafe",
                canInteract = function()
                    return ActiveHeist and ActiveHeist.stage == 2
                end
            })
        elseif heistType == "jewelry_store" then
            table.insert(targets, {
                position = basePosition + vector3(math.random(-5, 5), math.random(-5, 5), 0),
                label = "Smash Display Cases",
                icon = "fas fa-hammer",
                event = "qbx_heists:client:SmashDisplays",
                canInteract = function()
                    return ActiveHeist and ActiveHeist.stage == 2
                end
            })
        elseif heistType == "medium_bank" or heistType == "large_bank" then
            table.insert(targets, {
                position = basePosition + vector3(math.random(-5, 5), math.random(-5, 5), 0),
                label = "Drill Vault",
                icon = "fas fa-wrench",
                event = "qbx_heists:client:DrillVault",
                canInteract = function()
                    return ActiveHeist and ActiveHeist.stage == 2
                end
            })
        elseif heistType == "train_robbery" then
            table.insert(targets, {
                position = basePosition + vector3(math.random(-5, 5), math.random(-5, 5), 0),
                label = "Detach Cargo",
                icon = "fas fa-train",
                event = "qbx_heists:client:DetachCargo",
                canInteract = function()
                    return ActiveHeist and ActiveHeist.stage == 2
                end
            })
        elseif heistType == "yacht_heist" then
            table.insert(targets, {
                position = basePosition + vector3(math.random(-5, 5), math.random(-5, 5), 0),
                label = "Access Hidden Room",
                icon = "fas fa-door-open",
                event = "qbx_heists:client:AccessHiddenRoom",
                canInteract = function()
                    return ActiveHeist and ActiveHeist.stage == 2
                end
            })
        elseif heistType == "casino_heist" then
            table.insert(targets, {
                position = basePosition + vector3(math.random(-5, 5), math.random(-5, 5), 0),
                label = "Hack Vault System",
                icon = "fas fa-server",
                event = "qbx_heists:client:HackVaultSystem",
                canInteract = function()
                    return ActiveHeist and ActiveHeist.stage == 2
                end
            })
        end
    elseif stage == 3 then -- Escape stage
        -- Add escape target - get to extraction point
        table.insert(targets, {
            position = basePosition + vector3(math.random(-20, 20), math.random(-20, 20), 0),
            label = "Escape Point",
            icon = "fas fa-running",
            event = "qbx_heists:client:ReachEscapePoint",
            canInteract = function()
                return ActiveHeist and ActiveHeist.stage == 3
            end
        })
    end
    
    -- Create all the targets
    for _, target in ipairs(targets) do
        local targetId = exports.ox_target:addSphereZone({
            coords = target.position,
            radius = 2.0,
            options = {
                {
                    name = 'heist_target_' .. #CurrentHeistTargets + 1,
                    icon = target.icon,
                    label = target.label,
                    canInteract = target.canInteract,
                    onSelect = function()
                        TriggerEvent(target.event, {
                            type = heistType,
                            stage = stage,
                            objective = objective
                        })
                    end
                }
            }
        })
        table.insert(CurrentHeistTargets, targetId)
    end
    
    -- Create an objective blip for the first target
    if #targets > 0 then
        CreateObjectiveBlip(targets[1].position, targets[1].label)
    end
end

-- Function to clean up heist targets and blips
local function CleanupHeist()
    -- Clear existing targets
    for _, target in ipairs(CurrentHeistTargets) do
        exports.ox_target:removeZone(target)
    end
    CurrentHeistTargets = {}
    
    -- Remove blips
    if CurrentBlip then
        RemoveBlip(CurrentBlip)
        CurrentBlip = nil
    end
    
    if CurrentObjectiveBlip then
        RemoveBlip(CurrentObjectiveBlip)
        CurrentObjectiveBlip = nil
    end
    
    -- Clear active heist
    ActiveHeist = nil
end

-- Event when a heist starts
RegisterNetEvent('qbx_heists:client:HeistStarted', function(data)
    -- Set active heist data
    ActiveHeist = {
        type = data.type,
        name = data.name,
        location = data.location,
        stage = data.stage,
        initiator = data.initiator
    }
    
    -- Create blip for the heist location
    CreateHeistBlip(data.location, data.name, data.type)
    
    -- Setup heist targets for the current stage
    SetupHeistTargets(data.type, data.location, data.stage, "preparation")
    
    -- Notify player
    QBX.Functions.Notify(Lang:t('info.heist_preparation', {name = data.name}), 'primary', 7500)
end)

-- Event when a heist stage is completed
RegisterNetEvent('qbx_heists:client:StageCompleted', function(data)
    if not ActiveHeist then return end
    
    -- Update active heist stage
    ActiveHeist.stage = data.stage
    
    -- Setup heist targets for the new stage
    SetupHeistTargets(ActiveHeist.type, ActiveHeist.location, data.stage, data.objective)
    
    -- Notify player
    QBX.Functions.Notify(Lang:t('success.stage_completed', {stage = data.stage - 1}), 'success', 5000)
    QBX.Functions.Notify(Lang:t('info.heist_stage', {stage = data.stage, total = 3}), 'primary', 5000)
end)

-- Event when a heist is completed
RegisterNetEvent('qbx_heists:client:HeistCompleted', function(data)
    if not ActiveHeist then return end
    
    -- Notify player of completion and payout
    QBX.Functions.Notify(Lang:t('success.heist_completed', {amount = data.payoutPerPlayer}), 'success', 10000)
    
    -- Clean up the heist
    CleanupHeist()
end)

-- Event when a heist fails
RegisterNetEvent('qbx_heists:client:HeistFailed', function()
    if not ActiveHeist then return end
    
    -- Notify player of failure
    QBX.Functions.Notify(Lang:t('error.canceled_heist'), 'error', 7500)
    
    -- Clean up the heist
    CleanupHeist()
end)

-- Event when a heist is canceled
RegisterNetEvent('qbx_heists:client:HeistCanceled', function()
    if not ActiveHeist then return end
    
    -- Notify player of cancellation
    QBX.Functions.Notify(Lang:t('error.canceled_heist'), 'error', 5000)
    
    -- Clean up the heist
    CleanupHeist()
end)

-- Event when a player joins an existing heist
RegisterNetEvent('qbx_heists:client:JoinedHeist', function(data)
    -- Set active heist data
    ActiveHeist = {
        type = data.type,
        name = data.name,
        location = data.location,
        stage = data.stage,
        objective = data.objective
    }
    
    -- Create blip for the heist location
    CreateHeistBlip(data.location, data.name, data.type)
    
    -- Setup heist targets for the current stage
    SetupHeistTargets(data.type, data.location, data.stage, data.objective)
    
    -- Notify player
    QBX.Functions.Notify('You joined the ongoing ' .. data.name .. ' heist', 'primary', 7500)
    QBX.Functions.Notify(Lang:t('info.heist_stage', {stage = data.stage, total = 3}), 'primary', 5000)
end)

-- Event when another player joins the heist
RegisterNetEvent('qbx_heists:client:PlayerJoined', function(data)
    -- Notify player
    QBX.Functions.Notify(data.player .. ' joined the heist', 'primary', 5000)
end)

-- Event when a player uses a heist item
RegisterNetEvent('qbx_heists:client:ItemUsed', function(data)
    -- Notify player
    QBX.Functions.Notify(data.player .. ' used ' .. data.item, 'primary', 5000)
end)

-- Export to check if player is in a heist
exports('IsPlayerInHeist', function()
    return ActiveHeist ~= nil
end)

-- Export to get current heist data
exports('GetCurrentHeist', function()
    return ActiveHeist
end) 