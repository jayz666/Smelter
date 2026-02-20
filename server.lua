local ox_inventory = exports.ox_inventory
local activeJobs = {}
local sourceToLicense = {}

-- License extraction utility
local function getLicense(src)
    for _, id in pairs(GetPlayerIdentifiers(src)) do
        if string.sub(id, 1, 8) == "license:" then
            return id
        end
    end
    return nil
end

-- Database functions
local function loadJobFromDatabase(license, callback)
    exports.oxmysql:query('SELECT * FROM smelter_jobs WHERE license = ?', {license}, function(result)
        if result and #result > 0 then
            local job = result[1]
            callback({
                recipe = job.recipe,
                amount = job.amount,
                finishTime = job.finishTime,
                fuelUsed = job.fuelUsed
            })
        else
            callback(nil)
        end
    end)
end

local function saveJobToDatabase(license, jobData)
    exports.oxmysql:query('INSERT INTO smelter_jobs (license, recipe, amount, finishTime, fuelUsed) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE recipe = ?, amount = ?, finishTime = ?, fuelUsed = ?', 
        {license, jobData.recipe, jobData.amount, jobData.finishTime, jobData.fuelUsed, jobData.recipe, jobData.amount, jobData.finishTime, jobData.fuelUsed})
end

local function deleteJobFromDatabase(license)
    exports.oxmysql:query('DELETE FROM smelter_jobs WHERE license = ?', {license})
end

-- Load job when player connects
AddEventHandler('playerConnecting', function()
    local src = source
    local license = getLicense(src)
    if license then
        sourceToLicense[src] = license
        loadJobFromDatabase(license, function(jobData)
            if jobData then
                activeJobs[license] = jobData
            end
        end)
    end
end)

RegisterNetEvent('smelter:startJob', function(recipeKey, amount)
    local src = source
    
    -- Get player license
    local license = getLicense(src)
    if not license then
        TriggerClientEvent('smelter:jobResponse', src, 'error', 'Unable to verify player identity')
        return
    end
    
    -- Cache license mapping
    sourceToLicense[src] = license
    
    -- Validate recipe exists
    local recipe = Config.Recipes[recipeKey]
    if not recipe then
        TriggerClientEvent('smelter:jobResponse', src, 'error', 'Invalid recipe')
        return
    end
    
    -- Validate amount
    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 or amount > Config.MaxBatch then
        TriggerClientEvent('smelter:jobResponse', src, 'error', 'Invalid amount')
        return
    end
    
    -- Check if player already has active job
    if activeJobs[license] then
        TriggerClientEvent('smelter:jobResponse', src, 'error', 'Already have active job')
        return
    end
    
    -- Calculate required fuel
    local totalTime = amount * recipe.baseTime
    local requiredFuel = math.ceil(totalTime / Config.Fuel.burnTime)
    
    -- Check inventory for materials
    local materialCount = ox_inventory:Search(src, 'count', recipe.input)
    if materialCount < amount then
        TriggerClientEvent('smelter:jobResponse', src, 'error', 'Not enough '..recipe.label..' ore')
        return
    end
    
    -- Check inventory for fuel
    local fuelCount = ox_inventory:Search(src, 'count', Config.Fuel.item)
    if fuelCount < requiredFuel then
        TriggerClientEvent('smelter:jobResponse', src, 'error', 'Not enough coal (need '..requiredFuel..')')
        return
    end
    
    -- Remove materials first
    local materialRemoved = ox_inventory:RemoveItem(src, recipe.input, amount)
    if not materialRemoved then
        TriggerClientEvent('smelter:jobResponse', src, 'error', 'Failed to remove materials')
        return
    end
    
    -- Remove fuel with rollback
    local fuelRemoved = ox_inventory:RemoveItem(src, Config.Fuel.item, requiredFuel)
    if not fuelRemoved then
        -- Rollback material removal
        ox_inventory:AddItem(src, recipe.input, amount)
        TriggerClientEvent('smelter:jobResponse', src, 'error', 'Failed to remove fuel')
        return
    end
    
    -- Create job
    local finishTime = os.time() + totalTime
    local jobData = {
        recipe = recipeKey,
        amount = amount,
        finishTime = finishTime,
        fuelUsed = requiredFuel
    }
    
    activeJobs[license] = jobData
    saveJobToDatabase(license, jobData)
    
    -- Send success response
    TriggerClientEvent('smelter:jobResponse', src, 'started', {
        recipe = recipeKey,
        amount = amount,
        finishTime = finishTime,
        fuelUsed = requiredFuel
    })
end)

RegisterNetEvent('smelter:collectJob', function()
    local src = source
    
    -- Get player license
    local license = getLicense(src)
    if not license then
        TriggerClientEvent('smelter:jobResponse', src, 'error', 'Unable to verify player identity')
        return
    end
    
    -- Cache license mapping
    sourceToLicense[src] = license
    
    -- Check if player has active job
    if not activeJobs[license] then
        TriggerClientEvent('smelter:jobResponse', src, 'error', 'No active job')
        return
    end
    
    local job = activeJobs[license]
    local recipe = Config.Recipes[job.recipe]
    local currentTime = os.time()
    
    -- Safety guard for recipe
    if not recipe then
        activeJobs[license] = nil
        deleteJobFromDatabase(license)
        TriggerClientEvent('smelter:jobResponse', src, 'error', 'Recipe no longer available')
        return
    end
    
    -- Check if job is finished
    if currentTime < job.finishTime then
        -- Job not finished, return remaining time
        local remaining = job.finishTime - currentTime
        TriggerClientEvent('smelter:jobResponse', src, 'waiting', {
            recipe = job.recipe,
            amount = job.amount,
            remaining = remaining
        })
        return
    end
    
    -- Job finished, give items
    ox_inventory:AddItem(src, recipe.output, job.amount)
    
    -- Clear job
    activeJobs[license] = nil
    deleteJobFromDatabase(license)
    
    -- Send success response
    TriggerClientEvent('smelter:jobResponse', src, 'collected', {
        recipe = job.recipe,
        amount = job.amount
    })
end)

-- Clean up license mapping on player disconnect
AddEventHandler('playerDropped', function()
    local src = source
    sourceToLicense[src] = nil
end)

-- Status request event
RegisterNetEvent('smelter:requestStatus', function()
    local src = source
    local license = sourceToLicense[src]
    
    if not license then
        license = getLicense(src)
        sourceToLicense[src] = license
    end
    
    if license and activeJobs[license] then
        local job = activeJobs[license]
        local recipe = Config.Recipes[job.recipe]
        local currentTime = os.time()
        
        if currentTime >= job.finishTime then
            -- Job is ready
            TriggerClientEvent('smelter:jobResponse', src, 'collected', {
                recipe = job.recipe,
                amount = job.amount
            })
        else
            -- Job still active
            TriggerClientEvent('smelter:jobResponse', src, 'active', {
                recipe = job.recipe,
                amount = job.amount,
                remaining = job.finishTime - currentTime
            })
        end
    else
        -- No active job
        TriggerClientEvent('smelter:jobResponse', src, 'idle')
    end
end)

-- Admin command to clear all jobs from database
RegisterCommand('smelter_clearall', function(source, args, rawCommand)
    if source == 0 or IsPlayerAceAllowed(source, 'command') then
        exports.oxmysql:query('DELETE FROM smelter_jobs', function()
            activeJobs = {}
            print('[Smelter] All jobs cleared from database and memory')
            if source ~= 0 then
                TriggerClientEvent('ox_lib:notify', source, {description = 'All smelter jobs cleared', type = 'success'})
            end
        end)
    else
        TriggerClientEvent('ox_lib:notify', source, {description = 'No permission', type = 'error'})
    end
end, false)
