local ox_inventory = exports.ox_inventory
local activeJobs = {}
local sourceToLicense = {}
local skillsCache = {} -- [license] = row

-- License extraction utility
local function getLicense(src)
    for _, id in pairs(GetPlayerIdentifiers(src)) do
        if string.sub(id, 1, 8) == "license:" then
            return id
        end
    end
    return nil
end

-- Level curve:
-- Next level thresholds: 100, 250, 450, 700, 1000, 1350, 1750, 2200, 2700 (cap 10)
local function getLevelAndThresholdsFromXP(xp)
    xp = math.floor(tonumber(xp) or 0)
    if xp < 0 then xp = 0 end

    local level = 1
    local prev = 0
    local next = 100

    while level < 10 and xp >= next do
        level = level + 1
        prev = next
        next = prev + (50 * (level + 1))
    end

    if level >= 10 then
        next = prev -- max level sentinel
    end

    return level, prev, next
end

-- Fuel efficiency curve (unlocks at time level 5, max level 5)
local function getFuelLevelAndThresholdsFromXP(fuelXp, timeLevel)
    fuelXp = math.floor(tonumber(fuelXp) or 0)
    if fuelXp < 0 then fuelXp = 0 end

    -- Fuel efficiency unlocks at time level 5
    if timeLevel < 5 then
        return 0, 0, 0 -- Locked
    end

    local level = 1
    local prev = 0
    local next = 50

    while level < 5 and fuelXp >= next do
        level = level + 1
        prev = next
        next = prev + (30 * level)
    end

    if level >= 5 then
        next = prev -- max level sentinel
    end

    return level, prev, next
end

-- Tier 3 Heat helpers
local HEAT_MAP = { low = 0, medium = 1, high = 2 }

local function sanitizeHeatChoice(choice)
    if type(choice) ~= 'string' then return 'medium' end
    choice = choice:lower()
    if HEAT_MAP[choice] == nil then return 'medium' end
    return choice
end

local function sanitizeHoldMode(val)
    -- accepts boolean/number/string
    if val == true then return 1 end
    local n = tonumber(val)
    if n and n >= 1 then return 1 end
    return 0
end

local function getHeatTolerance(timeLevel, fuelLevel)
    local tol = 0
    if (tonumber(timeLevel) or 1) >= 4 then tol = tol + 1 end
    if (tonumber(fuelLevel) or 1) >= 4 then tol = tol + 1 end
    return math.min(tol, 2)
end

local function calculateQuality(recipe, heatChoice, holdMode, timeLevel, fuelLevel)
    -- recipe fields w/ safe defaults
    local optimal = sanitizeHeatChoice(recipe.optimalHeat or 'medium')
    local difficulty = math.floor(tonumber(recipe.heatDifficulty) or 2)
    if difficulty < 1 then difficulty = 1 end
    if difficulty > 3 then difficulty = 3 end

    heatChoice = sanitizeHeatChoice(heatChoice)
    holdMode = sanitizeHoldMode(holdMode)

    local diff = math.abs((HEAT_MAP[heatChoice] or 1) - (HEAT_MAP[optimal] or 1))
    local tolerance = getHeatTolerance(timeLevel, fuelLevel)

    local isSlag = 0
    local tier = 'basic'

    if diff == 0 then
        tier = 'premium'
        if holdMode == 1 then
            tier = 'master'
        end
    elseif diff == 1 then
        tier = 'standard'
    else
        -- diff == 2
        if tolerance < difficulty then
            isSlag = 1
            tier = 'basic' -- tier still set, but ignored if slag
        else
            tier = 'basic'
        end
    end

    return tier, isSlag, optimal, diff, tolerance, difficulty
end

local function loadSkills(license, cb)
    if skillsCache[license] then
        cb(skillsCache[license])
        return
    end

    exports.oxmysql:query(
        "SELECT license, xp, fuel_xp, total_items_smelted, total_fuel_used, total_jobs_completed FROM smelter_skills WHERE license = ? LIMIT 1",
        { license },
        function(rows)
            local row = rows and rows[1]
            if not row then
                row = {
                    license = license,
                    xp = 0,
                    fuel_xp = 0,
                    total_items_smelted = 0,
                    total_fuel_used = 0,
                    total_jobs_completed = 0
                }
            end

            skillsCache[license] = row
            cb(row)
        end
    )
end

local function upsertSkills(license, timeXpAdd, fuelXpAdd, itemsAdd, fuelAdd, jobsAdd, cb)
    timeXpAdd = math.floor(tonumber(timeXpAdd) or 0)
    fuelXpAdd = math.floor(tonumber(fuelXpAdd) or 0)
    itemsAdd = math.floor(tonumber(itemsAdd) or 0)
    fuelAdd = math.floor(tonumber(fuelAdd) or 0)
    jobsAdd = math.floor(tonumber(jobsAdd) or 0)

    if timeXpAdd < 0 then timeXpAdd = 0 end
    if fuelXpAdd < 0 then fuelXpAdd = 0 end
    if itemsAdd < 0 then itemsAdd = 0 end
    if fuelAdd < 0 then fuelAdd = 0 end
    if jobsAdd < 0 then jobsAdd = 0 end

    exports.oxmysql:query(
        [[
        INSERT INTO smelter_skills (license, xp, fuel_xp, total_items_smelted, total_fuel_used, total_jobs_completed)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            xp = xp + VALUES(xp),
            fuel_xp = fuel_xp + VALUES(fuel_xp),
            total_items_smelted = total_items_smelted + VALUES(total_items_smelted),
            total_fuel_used = total_fuel_used + VALUES(total_fuel_used),
            total_jobs_completed = total_jobs_completed + VALUES(total_jobs_completed)
        ]],
        { license, timeXpAdd, fuelXpAdd, itemsAdd, fuelAdd, jobsAdd },
        function()
            -- Update cache locally (no extra SELECT)
            local c = skillsCache[license] or {
                license = license,
                xp = 0,
                fuel_xp = 0,
                total_items_smelted = 0,
                total_fuel_used = 0,
                total_jobs_completed = 0
            }

            c.xp = (c.xp or 0) + timeXpAdd
            c.fuel_xp = (c.fuel_xp or 0) + fuelXpAdd
            c.total_items_smelted = (c.total_items_smelted or 0) + itemsAdd
            c.total_fuel_used = (c.total_fuel_used or 0) + fuelAdd
            c.total_jobs_completed = (c.total_jobs_completed or 0) + jobsAdd

            skillsCache[license] = c

            if cb then cb(c) end
        end
    )
end

local function getProcessingTimeSeconds(baseTime, amount, level)
    baseTime = tonumber(baseTime) or 0
    amount = math.floor(tonumber(amount) or 0)

    if baseTime < 0 then baseTime = 0 end
    if amount < 1 then amount = 1 end

    local cappedLevel = math.min(math.max(level or 1, 1), 10)

    -- 3% per level starting from Level 2
    local reduction = (cappedLevel - 1) * 0.03
    
    -- Defensive caps prevent future config mistakes
    if reduction < 0 then reduction = 0 end
    if reduction > 0.27 then reduction = 0.27 end
    
    local efficiency = 1 - reduction

    local total = (baseTime * amount) * efficiency

    -- Always at least 1 second
    return math.max(1, math.ceil(total))
end

local function getFuelEfficiency(fuelLevel)
    -- 3% per level starting from Level 2, max 15%
    local reduction = (fuelLevel - 1) * 0.03
    
    -- Defensive caps
    if reduction < 0 then reduction = 0 end
    if reduction > 0.15 then reduction = 0.15 end
    
    return 1 - reduction
end

local function buildSkillsPayload(row)
    local timeLevel, timePrev, timeNext = getLevelAndThresholdsFromXP(row.xp or 0)
    local fuelLevel, fuelPrev, fuelNext = getFuelLevelAndThresholdsFromXP(row.fuel_xp or 0, timeLevel)

    return {
        xp = row.xp or 0,
        level = timeLevel,
        prevLevelXp = timePrev,
        nextLevelXp = timeNext,
        fuel_xp = row.fuel_xp or 0,
        fuel_level = fuelLevel,
        fuel_prevLevelXp = fuelPrev,
        fuel_nextLevelXp = fuelNext,
        total_items_smelted = row.total_items_smelted or 0,
        total_fuel_used = row.total_fuel_used or 0,
        total_jobs_completed = row.total_jobs_completed or 0
    }
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
                fuelUsed = job.fuelUsed,
                heatChoice = job.heat_choice,
                holdMode = job.hold_mode,
                qualityTier = job.quality_tier,
                isSlag = job.is_slag
            })
        else
            callback(nil)
        end
    end)
end

local function saveJobToDatabase(license, job)
    exports.oxmysql:query([[
        INSERT INTO smelter_jobs (license, recipe, amount, finishTime, fuelUsed, heat_choice, hold_mode, quality_tier, is_slag, createdAt)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, UNIX_TIMESTAMP())
        ON DUPLICATE KEY UPDATE
            recipe = VALUES(recipe),
            amount = VALUES(amount),
            finishTime = VALUES(finishTime),
            fuelUsed = VALUES(fuelUsed),
            heat_choice = VALUES(heat_choice),
            hold_mode = VALUES(hold_mode),
            quality_tier = VALUES(quality_tier),
            is_slag = VALUES(is_slag)
    ]], {
        license,
        job.recipe,
        job.amount,
        job.finishTime,
        job.fuelUsed,
        job.heatChoice or 'medium',
        tonumber(job.holdMode) or 0,
        job.qualityTier or 'basic',
        tonumber(job.isSlag) or 0
    })
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

-- Skills request event
RegisterNetEvent("smelter:requestSkills", function()
    local src = source
    local license = getLicense(src)
    if not license then return end

    loadSkills(license, function(row)
        TriggerClientEvent("smelter:skills", src, buildSkillsPayload(row))
    end)
end)

RegisterNetEvent('smelter:startJob', function(recipeKey, amount, heatChoice, holdMode)
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
    
    -- Validate inputs
    if not recipeKey or not amount or amount < 1 or amount > Config.MaxBatch then
        TriggerClientEvent('smelter:jobResponse', src, 'error', 'Invalid recipe or amount')
        return
    end
    
    -- Tier 3: Validate heat choice and hold mode
    heatChoice = sanitizeHeatChoice(heatChoice)
    holdMode = sanitizeHoldMode(holdMode)
    
    -- IMPORTANT: compute time using skills (server-side)
    loadSkills(license, function(skillRow)
        local timeLevel, _, _ = getLevelAndThresholdsFromXP(skillRow.xp or 0)
        local fuelLevel, _, _ = getFuelLevelAndThresholdsFromXP(skillRow.fuel_xp or 0, timeLevel)
        
        -- BASE time for fuel (no efficiency)
        local baseTotalTime = recipe.baseTime * amount
        
        -- Skill-adjusted time
        local totalTime = getProcessingTimeSeconds(recipe.baseTime, amount, timeLevel)
        
        -- Fuel calculated with efficiency (if unlocked)
        local fuelEfficiency = getFuelEfficiency(fuelLevel)
        local baseRequiredFuel = math.ceil(baseTotalTime / Config.Fuel.burnTime)
        local requiredFuel = math.max(1, math.ceil(baseRequiredFuel * fuelEfficiency))
        
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
            fuelUsed = requiredFuel,
            
            -- Tier 3
            heatChoice = heatChoice,
            holdMode = holdMode,
            qualityTier = 'basic',
            isSlag = 0
        }
        
        activeJobs[license] = jobData
        saveJobToDatabase(license, jobData)
        
        -- Send success response
        TriggerClientEvent('smelter:jobResponse', src, 'started', {
            recipe = recipeKey,
            amount = amount,
            finishTime = finishTime,
            fuelUsed = requiredFuel,
            
            -- Tier 3
            heatChoice = heatChoice,
            holdMode = holdMode
        })
    end)
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
    
    -- Load current skills to check unlock status
    loadSkills(license, function(skillRow)
        -- Calculate XP awards
        local timeXpGained = math.floor(job.amount * (recipe.baseTime or 0))
        local fuelXpGained = math.floor(job.fuelUsed * 10) -- Linear fuel XP
        
        -- Check if fuel efficiency is unlocked (time level >= 5)
        local timeLevel, _, _ = getLevelAndThresholdsFromXP(skillRow.xp or 0)
        local fuelLevel, _, _ = getFuelLevelAndThresholdsFromXP(skillRow.fuel_xp or 0, timeLevel)
        if timeLevel < 5 then
            fuelXpGained = 0 -- Fuel XP locked until time level 5
        end

        -- Tier 3: Calculate quality
        local qualityTier, isSlag = calculateQuality(recipe, job.heatChoice, job.holdMode, timeLevel, fuelLevel)
        
        -- Update job with quality results
        job.qualityTier = qualityTier
        job.isSlag = isSlag
        
        -- Calculate output based on quality
        local outputItem, outputAmount
        if isSlag == 1 then
            outputItem = recipe.slagItem or 'slag'
            outputAmount = math.max(1, math.ceil(job.amount * 0.5))
        else
            local mult = (Config.QualityMultipliers and Config.QualityMultipliers[qualityTier]) or 1.0
            outputItem = recipe.output
            outputAmount = math.max(1, math.ceil(job.amount * mult))
        end

        -- Give output
        ox_inventory:AddItem(src, outputItem, outputAmount)

        upsertSkills(license, timeXpGained, fuelXpGained, job.amount, job.fuelUsed, 1, function(updatedRow)
            -- Clear job
            activeJobs[license] = nil
            deleteJobFromDatabase(license)
            
            TriggerClientEvent('smelter:jobResponse', src, 'collected', {
                recipe = job.recipe,
                amount = job.amount,
                
                -- Tier 3 result
                qualityTier = qualityTier,
                isSlag = isSlag,
                outputItem = outputItem,
                outputAmount = outputAmount,
                
                -- skills payload
                skills = buildSkillsPayload(updatedRow)
            })
        end)
    end)
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
