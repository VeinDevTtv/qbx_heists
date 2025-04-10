local QBX = exports['qbx_core']:GetCoreObject()
local PlayerData = {}
local ActiveHeist = nil
local CurrentBlip = nil
local CurrentObjectiveBlip = nil
local CurrentHeistTargets = {}
local CanStartHeist = true

-- State variables
local activeHeist = nil
local currentStage = nil
local objectiveMarkers = {}
local heistBlips = {}
local isInitialized = false

-- Config
local Config = {
    debug = false,
    defaultBlipSprite = 161,
    defaultBlipColor = 1,
    defaultMarkerType = 1,
    defaultMarkerColor = {r = 255, g = 0, b = 0, a = 100},
    defaultMarkerSize = vector3(1.0, 1.0, 1.0)
}

-- Initialize player data
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBX.Functions.GetPlayerData()
    -- Register the heist app in the laptop if the player is in a gang
    if PlayerData.gang.name ~= 'none' then
        RegisterHeistApp()
    end
    Initialize()
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

-- Main client file for qbx_heists

-- Initialize heist system
local function Initialize()
    if isInitialized then return end
    
    -- Register all client-side events
    RegisterNetEvent('qbx_heists:client:JoinHeist', function(heistData)
        activeHeist = heistData
        currentStage = 1
        
        -- Create blips and markers for first stage
        CreateHeistBlips()
        CreateObjectiveMarkers()
        
        -- Notify player
        QBX.Functions.Notify('Heist started: ' .. heistData.name, 'success')
        
        -- Start proximity check loop
        StartProximityChecks()
        
        TriggerEvent('qbx_heists:client:HeistStarted', heistData)
    end)
    
    RegisterNetEvent('qbx_heists:client:StageCompleted', function(stageNumber, nextStage)
        -- Clear current stage markers
        ClearObjectiveMarkers()
        
        -- Update stage
        currentStage = stageNumber + 1
        
        if nextStage then
            -- Create markers for next stage
            CreateObjectiveMarkers()
            QBX.Functions.Notify('Stage completed! New objective available.', 'success')
        else
            QBX.Functions.Notify('Final stage completed!', 'success')
        end
        
        TriggerEvent('qbx_heists:client:HeistStageChanged', currentStage)
    end)
    
    RegisterNetEvent('qbx_heists:client:HeistCompleted', function(reward)
        -- Clean up heist data
        ClearHeistData()
        
        -- Notify player
        QBX.Functions.Notify('Heist completed! Reward: $' .. reward, 'success')
        
        TriggerEvent('qbx_heists:client:HeistEnded', 'completed', reward)
    end)
    
    RegisterNetEvent('qbx_heists:client:HeistFailed', function(reason)
        -- Clean up heist data
        ClearHeistData()
        
        -- Notify player
        QBX.Functions.Notify('Heist failed: ' .. reason, 'error')
        
        TriggerEvent('qbx_heists:client:HeistEnded', 'failed', reason)
    end)
    
    RegisterNetEvent('qbx_heists:client:HeistCanceled', function()
        -- Clean up heist data
        ClearHeistData()
        
        -- Notify player
        QBX.Functions.Notify('Heist canceled', 'primary')
        
        TriggerEvent('qbx_heists:client:HeistEnded', 'canceled')
    end)
    
    RegisterNetEvent('qbx_heists:client:SyncHeistData', function(heistData, stage)
        activeHeist = heistData
        currentStage = stage
        
        -- Clear existing markers and blips
        ClearObjectiveMarkers()
        ClearHeistBlips()
        
        -- Create new markers and blips
        CreateHeistBlips()
        CreateObjectiveMarkers()
    end)
    
    RegisterNetEvent('qbx_heists:client:PoliceAlert', function(coords, message)
        -- Show notification for police only
        local PlayerData = QBX.Functions.GetPlayerData()
        if PlayerData.job.name == 'police' then
            QBX.Functions.Notify(message, 'police')
            
            -- Create alert blip
            local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
            SetBlipSprite(blip, 161)
            SetBlipColour(blip, 3)
            SetBlipAsShortRange(blip, false)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString('Heist In Progress')
            EndTextCommandSetBlipName(blip)
            
            -- Flash blip
            SetBlipFlashes(blip, true)
            
            -- Remove blip after 60 seconds
            Citizen.SetTimeout(60000, function()
                RemoveBlip(blip)
            end)
        end
    end)
    
    -- Initialize command for testing if debug mode enabled
    if Config.debug then
        RegisterCommand('heist_test', function(source, args)
            local testHeist = {
                id = 'test_heist',
                name = 'Test Heist',
                stages = {
                    {
                        objectives = {
                            {
                                type = 'goto',
                                coords = GetEntityCoords(PlayerPedId()),
                                radius = 5.0,
                                label = 'Test Objective'
                            }
                        }
                    }
                }
            }
            
            TriggerEvent('qbx_heists:client:JoinHeist', testHeist)
        end)
    end
    
    isInitialized = true
end

-- Helper Functions
function CreateHeistBlips()
    if not activeHeist or not activeHeist.stages or not activeHeist.stages[currentStage] then
        return
    end
    
    -- Clear existing blips first
    ClearHeistBlips()
    
    -- Create blips for all objectives in current stage
    for i, objective in ipairs(activeHeist.stages[currentStage].objectives) do
        if objective.coords and objective.showBlip ~= false then
            local blip = AddBlipForCoord(objective.coords.x, objective.coords.y, objective.coords.z)
            
            SetBlipSprite(blip, objective.blipSprite or Config.defaultBlipSprite)
            SetBlipColour(blip, objective.blipColor or Config.defaultBlipColor)
            SetBlipScale(blip, objective.blipScale or 1.0)
            SetBlipAsShortRange(blip, true)
            
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(objective.label or "Heist Objective " .. i)
            EndTextCommandSetBlipName(blip)
            
            table.insert(heistBlips, blip)
        end
    end
end

function ClearHeistBlips()
    for _, blip in ipairs(heistBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    heistBlips = {}
end

function CreateObjectiveMarkers()
    if not activeHeist or not activeHeist.stages or not activeHeist.stages[currentStage] then
        return
    end
    
    -- Clear existing markers first
    ClearObjectiveMarkers()
    
    -- Create markers for all objectives in current stage
    for i, objective in ipairs(activeHeist.stages[currentStage].objectives) do
        if objective.coords and objective.showMarker ~= false then
            local markerId = "objective_" .. i
            
            objectiveMarkers[markerId] = {
                type = objective.markerType or Config.defaultMarkerType,
                coords = vector3(objective.coords.x, objective.coords.y, objective.coords.z),
                dir = vector3(0.0, 0.0, 0.0),
                rot = vector3(0.0, 0.0, 0.0),
                scale = objective.markerSize or Config.defaultMarkerSize,
                color = objective.markerColor or Config.defaultMarkerColor,
                bobUpAndDown = objective.bobUpAndDown or false,
                faceCamera = objective.faceCamera or true,
                p19 = false,
                rotate = false,
                textureDict = nil,
                textureName = nil,
                drawOnEnts = false
            }
        end
    end
    
    -- Start marker rendering loop if we have markers
    if next(objectiveMarkers) then
        if not renderingMarkers then
            renderingMarkers = true
            Citizen.CreateThread(RenderMarkers)
        end
    end
end

function ClearObjectiveMarkers()
    objectiveMarkers = {}
end

local renderingMarkers = false
function RenderMarkers()
    Citizen.CreateThread(function()
        while renderingMarkers and next(objectiveMarkers) do
            local ped = PlayerPedId()
            local pedCoords = GetEntityCoords(ped)
            
            for _, marker in pairs(objectiveMarkers) do
                local distance = #(pedCoords - marker.coords)
                
                if distance < 100.0 then
                    DrawMarker(
                        marker.type,
                        marker.coords.x, marker.coords.y, marker.coords.z,
                        marker.dir.x, marker.dir.y, marker.dir.z,
                        marker.rot.x, marker.rot.y, marker.rot.z,
                        marker.scale.x, marker.scale.y, marker.scale.z,
                        marker.color.r, marker.color.g, marker.color.b, marker.color.a,
                        marker.bobUpAndDown, marker.faceCamera, marker.p19, marker.rotate,
                        marker.textureDict, marker.textureName, marker.drawOnEnts
                    )
                end
            end
            
            Citizen.Wait(0)
        end
        
        renderingMarkers = false
    end)
end

function StartProximityChecks()
    Citizen.CreateThread(function()
        while activeHeist do
            local ped = PlayerPedId()
            local pedCoords = GetEntityCoords(ped)
            
            if activeHeist.stages and activeHeist.stages[currentStage] then
                local stageCompleted = true
                
                for i, objective in ipairs(activeHeist.stages[currentStage].objectives) do
                    if objective.coords and objective.type == 'goto' then
                        local distance = #(pedCoords - vector3(objective.coords.x, objective.coords.y, objective.coords.z))
                        
                        if distance <= (objective.radius or 2.0) then
                            -- If this is a 'goto' objective, mark it as complete
                            if not objective.completed then
                                objective.completed = true
                                QBX.Functions.Notify('Objective ' .. i .. ' completed!', 'success')
                                TriggerServerEvent('qbx_heists:server:ObjectiveCompleted', activeHeist.id, currentStage, i)
                                
                                -- Remove blip and marker for this objective
                                if heistBlips[i] and DoesBlipExist(heistBlips[i]) then
                                    RemoveBlip(heistBlips[i])
                                    heistBlips[i] = nil
                                end
                                
                                if objectiveMarkers["objective_" .. i] then
                                    objectiveMarkers["objective_" .. i] = nil
                                end
                            end
                        else
                            -- If player is not at this objective, mark stage as not completed
                            if not objective.completed then
                                stageCompleted = false
                            end
                        end
                    elseif not objective.completed then
                        -- If this objective is not a 'goto' type and not completed, stage is not complete
                        stageCompleted = false
                    end
                end
                
                -- If all objectives are completed, notify server
                if stageCompleted then
                    TriggerServerEvent('qbx_heists:server:StageCompleted', activeHeist.id, currentStage)
                    break -- Exit the loop as stage is completed
                end
            end
            
            Citizen.Wait(1000) -- Check every second
        end
    end)
end

function ClearHeistData()
    ClearObjectiveMarkers()
    ClearHeistBlips()
    
    activeHeist = nil
    currentStage = nil
    
    -- Stop any ongoing threads
    renderingMarkers = false
end

-- Interaction with world objects
function ShowInteractionPrompt(objectiveData)
    if not objectiveData or not objectiveData.interaction then return end
    
    local interaction = objectiveData.interaction
    local instructionalText = interaction.text or "Press [E] to interact"
    
    -- Show help text
    lib.showTextUI(instructionalText)
    
    Citizen.CreateThread(function()
        local promptShown = true
        
        while promptShown and activeHeist do
            if IsControlJustReleased(0, 38) then -- E key
                lib.hideTextUI()
                promptShown = false
                
                -- Process interaction
                ProcessInteraction(objectiveData)
            end
            
            -- Exit if player moves too far
            local ped = PlayerPedId()
            local pedCoords = GetEntityCoords(ped)
            local objCoords = vector3(objectiveData.coords.x, objectiveData.coords.y, objectiveData.coords.z)
            
            if #(pedCoords - objCoords) > (objectiveData.radius or 2.0) then
                lib.hideTextUI()
                promptShown = false
            end
            
            Citizen.Wait(0)
        end
    end)
end

function ProcessInteraction(objectiveData)
    local interaction = objectiveData.interaction
    local interactionType = interaction.type
    
    if interactionType == 'minigame' then
        -- Run minigame
        local minigameSuccess = lib.callback.await('qbx_heists:client:RunMinigame', false, 
            interaction.minigame, 
            interaction.difficulty or 'medium'
        )
        
        if minigameSuccess then
            QBX.Functions.Notify('Minigame completed successfully!', 'success')
            TriggerServerEvent('qbx_heists:server:ObjectiveCompleted', activeHeist.id, currentStage, objectiveData.index)
        else
            QBX.Functions.Notify('Minigame failed!', 'error')
            
            if interaction.failureConsequence == 'failHeist' then
                TriggerServerEvent('qbx_heists:server:HeistFailed', activeHeist.id, 'Failed at minigame')
            elseif interaction.failureConsequence == 'alertPolice' then
                TriggerServerEvent('qbx_heists:server:AlertPolice', activeHeist.id, GetEntityCoords(PlayerPedId()))
            end
        end
    elseif interactionType == 'animation' then
        -- Play animation
        local animSuccess = lib.callback.await('qbx_heists:client:PlayAnimation', false,
            interaction.animDict,
            interaction.animName,
            interaction.duration,
            interaction.flags
        )
        
        if animSuccess then
            Citizen.Wait(interaction.duration or 3000)
            TriggerServerEvent('qbx_heists:server:ObjectiveCompleted', activeHeist.id, currentStage, objectiveData.index)
        end
    elseif interactionType == 'placeObject' then
        -- Place object in the world
        local objectSuccess, object = lib.callback.await('qbx_heists:client:PlaceObject', false,
            interaction.objectModel,
            interaction.offset
        )
        
        if objectSuccess then
            QBX.Functions.Notify('Object placed successfully!', 'success')
            TriggerServerEvent('qbx_heists:server:ObjectiveCompleted', activeHeist.id, currentStage, objectiveData.index)
            
            -- Store object entity for cleanup later
            if activeHeist.placedObjects == nil then
                activeHeist.placedObjects = {}
            end
            table.insert(activeHeist.placedObjects, object)
        else
            QBX.Functions.Notify('Failed to place object', 'error')
        end
    elseif interactionType == 'collect' then
        -- Item collection
        QBX.Functions.Progressbar("collect_item", interaction.text or "Collecting...", interaction.duration or 5000, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = interaction.animDict or "mini@repair",
            anim = interaction.animName or "fixing_a_player",
            flags = interaction.animFlags or 49,
        }, {}, {}, function() -- Done
            TriggerServerEvent('qbx_heists:server:CollectItem', activeHeist.id, currentStage, objectiveData.index)
            TriggerServerEvent('qbx_heists:server:ObjectiveCompleted', activeHeist.id, currentStage, objectiveData.index)
        end, function() -- Cancel
            QBX.Functions.Notify('Canceled', 'error')
        end)
    end
end

-- Exported functions
function IsInHeist()
    return activeHeist ~= nil
end

function GetActiveHeist()
    return activeHeist
end

function GetCurrentStage()
    return currentStage
end

function GetHeistProgress()
    if not activeHeist then
        return nil
    end
    
    return {
        heistId = activeHeist.id,
        heistName = activeHeist.name,
        currentStage = currentStage,
        totalStages = #activeHeist.stages,
        stageObjectives = activeHeist.stages[currentStage].objectives
    }
end

-- Export the functions
exports('IsInHeist', IsInHeist)
exports('GetActiveHeist', GetActiveHeist)
exports('GetCurrentStage', GetCurrentStage)
exports('GetHeistProgress', GetHeistProgress)

-- Initialize on resource start
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        Initialize()
    end
end)

-- Cleanup on player unloaded
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    ClearHeistData()
end)

-- Handle resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        ClearHeistData()
    end
end) 