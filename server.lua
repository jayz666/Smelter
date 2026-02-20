local ox_inventory = exports.ox_inventory
local activeJobs = {}
local sourceToLicense = {}
local jobsDirty = false
local saveTimerActive = false

local JOB_EXPIRY_SECONDS = 604800 -- 7 days
local SAVE_DEBOUNCE_MS = 2000 -- 2 seconds

-- License extraction utility
local function getLicense(src)
    for _, id in pairs(GetPlayerIdentifiers(src)) do
        if string.sub(id, 1, 8) == "license:" then
            return id
        end
    end
    return nil
end

-- File storage functions
local function saveToDisk(force)
    if not jobsDirty and not force then return end
    
    local success, json = pcall(json.encode, activeJobs)
    if not success then
        -- Failed to encode, don't clear dirty flag
        return
    end
    
    local saved = SaveResourceFile(GetCurrentResourceName(), "data/jobs.json", json, -1)
    if saved then
        jobsDirty = false
    end
    -- If save failed, keep jobsDirty = true for retry
end

local function markJobsDirty()
    jobsDirty = true
    if not saveTimerActive then
        saveTimerActive = true
        SetTimeout(SAVE_DEBOUNCE_MS, function()
            if jobsDirty then
                saveToDisk(false)
            end
            saveTimerActive = false
        end)
    end
end

local function loadFromDisk()
    local data = LoadResourceFile(GetCurrentResourceName(), "data/jobs.json")
    
    if not data then
        activeJobs = {}
        return
    end
    
    local success, loaded = pcall(json.decode, data)
    if not success then
        -- Backup corrupted file
        local timestamp = os.time()
        local corruptName = string.format("data/jobs_corrupt_%d.json", timestamp)
        SaveResourceFile(GetCurrentResourceName(), corruptName, data, -1)
        activeJobs = {}
        return
    end
    
    activeJobs = loaded or {}
    local currentTime = os.time()
    local modified = false
    
    -- Validate and cleanup jobs
    for license, job in pairs(activeJobs) do
        -- Validate job structure
        if not job or not job.recipe or not job.amount or not job.finishTime then
            activeJobs[license] = nil
            modified = true
        elseif not Config.Recipes[job.recipe] then
            -- Recipe no longer exists
            activeJobs[license] = nil
            modified = true
        elseif job.amount <= 0 or type(job.finishTime) ~= "number" then
            -- Invalid data
            activeJobs[license] = nil
            modified = true
        elseif currentTime > job.finishTime + JOB_EXPIRY_SECONDS then
            -- Job expired (finished more than 7 days ago)
            activeJobs[license] = nil
            modified = true
        end
    end
    
    -- Save if we cleaned up invalid jobs
    if modified then
        saveToDisk(true)
    end
end

-- Initialize on resource start
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        loadFromDisk()
    end
end)

-- Save on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        saveToDisk(true) -- Force immediate save
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
    activeJobs[license] = {
        recipe = recipeKey,
        amount = amount,
        finishTime = finishTime,
        fuelUsed = requiredFuel
    }
    
    -- Mark for saving
    markJobsDirty()
    
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
        markJobsDirty()
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
    markJobsDirty()
    
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
