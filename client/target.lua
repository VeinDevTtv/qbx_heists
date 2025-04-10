-- Target file for handling ox_target integration
local QBX = exports['qbx_core']:GetCoreObject()

-- Create dealer targets when resource starts
CreateThread(function()
    -- Add dealers from config
    for _, dealer in ipairs(Config.Dealers) do
        -- Add sphere zone for dealer
        exports.ox_target:addSphereZone({
            coords = dealer.location,
            radius = 1.5,
            debug = false,
            options = {
                {
                    name = 'heist_dealer_' .. _,
                    icon = 'fas fa-mask',
                    label = 'Talk to ' .. dealer.name,
                    canInteract = function()
                        -- Check if dealer is open based on time
                        local hour = GetClockHours()
                        if dealer.hours.start <= dealer.hours.finish then -- Normal hours
                            return hour >= dealer.hours.start and hour < dealer.hours.finish
                        else -- Overnight hours
                            return hour >= dealer.hours.start or hour < dealer.hours.finish
                        end
                    end,
                    onSelect = function()
                        -- Check if dealer is open based on time
                        local hour = GetClockHours()
                        local isOpen = false
                        
                        if dealer.hours.start <= dealer.hours.finish then -- Normal hours
                            isOpen = hour >= dealer.hours.start and hour < dealer.hours.finish
                        else -- Overnight hours
                            isOpen = hour >= dealer.hours.start or hour < dealer.hours.finish
                        end
                        
                        if not isOpen then
                            QBX.Functions.Notify(Lang:t('error.dealer_closed'), 'error')
                            QBX.Functions.Notify(Lang:t('info.dealer_hours', {start = dealer.hours.start, finish = dealer.hours.finish}), 'primary')
                            return
                        end
                        
                        -- Create dealer menu
                        local options = {}
                        
                        -- Add items from dealer
                        for _, itemName in ipairs(dealer.items) do
                            local item = Config.RequiredItems[itemName]
                            if item then
                                options[#options+1] = {
                                    title = item.label,
                                    description = Lang:t('info.item_details', {item = item.label, price = item.price}),
                                    icon = 'fa-solid fa-' .. (itemName:find('card') and 'credit-card' or (itemName:find('laptop') and 'laptop' or 'tools')),
                                    onSelect = function()
                                        -- Request to purchase item
                                        local result = lib.callback.await('qbx_heists:server:PurchaseItem', false, itemName)
                                        
                                        if not result.success then
                                            QBX.Functions.Notify(Lang:t('error.' .. result.message, {price = result.price}), 'error')
                                        else
                                            QBX.Functions.Notify(Lang:t('success.item_purchased', {item = result.item, price = result.price}), 'success')
                                        end
                                    end,
                                    arrow = true
                                }
                            end
                        end
                        
                        -- Show dealer menu
                        lib.registerContext({
                            id = 'heist_dealer_menu',
                            title = dealer.name,
                            options = options
                        })
                        
                        lib.showContext('heist_dealer_menu')
                    end
                }
            }
        })
        
        -- Create dealer blip
        local blip = AddBlipForCoord(dealer.location.x, dealer.location.y, dealer.location.z)
        SetBlipSprite(blip, 459) -- Mask blip
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.7)
        SetBlipColour(blip, 27) -- Purple
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(dealer.name)
        EndTextCommandSetBlipName(blip)
    end
end)

-- Create command for finding nearest dealer
RegisterCommand('finddealer', function()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local nearestDealer = nil
    local nearestDistance = 9999.9
    
    -- Find nearest dealer
    for _, dealer in ipairs(Config.Dealers) do
        local distance = #(playerCoords - dealer.location)
        if distance < nearestDistance then
            nearestDistance = distance
            nearestDealer = dealer
        end
    end
    
    if nearestDealer then
        QBX.Functions.Notify('Nearest dealer: ' .. nearestDealer.name, 'primary')
        
        -- Create waypoint
        SetNewWaypoint(nearestDealer.location.x, nearestDealer.location.y)
        
        -- Show hours
        QBX.Functions.Notify(Lang:t('info.dealer_hours', {start = nearestDealer.hours.start, finish = nearestDealer.hours.finish}), 'primary')
    else
        QBX.Functions.Notify('No dealers found', 'error')
    end
end, false) 