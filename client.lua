local ox_lib = exports.ox_lib
local ox_target = exports.ox_target

local lastInteraction = 0
local hasActiveJob = false

-- NUI Functions
local function openSmelterUI()
    if GetGameTimer() - lastInteraction > Config.ClientCooldown then
        lastInteraction = GetGameTimer()
        
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'open',
            data = {
                recipes = Config.Recipes,
                fuel = Config.Fuel,
                maxBatch = Config.MaxBatch
            }
        })
        
        -- Request skills from server
        TriggerServerEvent('smelter:requestSkills')
    end
end

local function closeSmelterUI()
    SetNuiFocus(false, false)
    SendNUIMessage({action = 'hideUI'})
end

-- NUI Callbacks
RegisterNUICallback('closeUI', function(data, cb)
    closeSmelterUI()
    cb('ok')
end)

RegisterNUICallback('startJob', function(data, cb)
    local recipe = data.recipe
    local amount = tonumber(data.amount)
    
    if recipe and amount and amount >= 1 and amount <= Config.MaxBatch then
        TriggerServerEvent('smelter:startJob', recipe, amount)
    else
        exports.ox_lib:notify({description = 'Invalid input', type = 'error'})
    end
    cb('ok')
end)

RegisterNUICallback('collectJob', function(data, cb)
    TriggerServerEvent('smelter:collectJob')
    cb('ok')
end)

-- Server Events
RegisterNetEvent('smelter:jobResponse', function(status, data)
    if status == 'started' then
        hasActiveJob = true
        local recipe = Config.Recipes[data.recipe]
        SendNUIMessage({
            action = 'state',
            data = {
                mode = 'active',
                recipe = data.recipe,
                amount = data.amount,
                remaining = data.remaining or 0
            }
        })
        exports.ox_lib:notify({description = 'Smelting job started!', type = 'success'})
        
    elseif status == 'waiting' then
        SendNUIMessage({
            action = 'state',
            data = {
                mode = 'active',
                recipe = data.recipe,
                amount = data.amount,
                remaining = data.remaining
            }
        })
        exports.ox_lib:notify({description = 'Job not ready yet', type = 'info'})
        
    elseif status == 'collected' then
        hasActiveJob = false
        local recipe = Config.Recipes[data.recipe]
        SendNUIMessage({
            action = 'state',
            data = {
                mode = 'idle'
            }
        })
        exports.ox_lib:notify({description = 'Collected '..data.amount..' '..recipe.label..' ingots!', type = 'success'})
        
        -- Forward skills data to NUI
        if data.skills then
            SendNUIMessage({ action = 'skills', data = data.skills })
        end
        
    elseif status == 'error' then
        exports.ox_lib:notify({description = data or 'Unknown error', type = 'error'})
    end
end)

RegisterNetEvent('smelter:skills', function(skills)
    SendNUIMessage({
        action = 'skills',
        data = skills
    })
end)

-- Target Zone
ox_target:addBoxZone({
    coords = vec3(Config.SmelterLocation.x, Config.SmelterLocation.y, Config.SmelterLocation.z),
    size = vec3(1.0, 1.0, 2.0),
    rotation = Config.SmelterLocation.w,
    options = {
        {
            name = Config.Target.name,
            icon = Config.Target.icon,
            label = Config.Target.label,
            onSelect = function()
                openSmelterUI()
            end,
            distance = Config.Target.distance
        }
    }
})

-- Resource Cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        SetNuiFocus(false, false)
    end
end)

-- Escape key fallback
CreateThread(function()
    while true do
        Wait(0)
        if IsControlJustPressed(0, 322) then -- ESC
            SetNuiFocus(false, false)
            SendNUIMessage({action = 'hideUI'})
        end
    end
end)
