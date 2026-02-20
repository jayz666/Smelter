-- Database setup for smelter jobs
exports.oxmysql:ready(function()
    exports.oxmysql:query([[CREATE TABLE IF NOT EXISTS smelter_jobs (
        license VARCHAR(50) PRIMARY KEY,
        recipe VARCHAR(50) NOT NULL,
        amount INT NOT NULL,
        finishTime INT NOT NULL,
        fuelUsed INT NOT NULL,
        createdAt INT DEFAULT UNIX_TIMESTAMP()
    )]], {}, function(success)
        if success then
            print('[Smelter] Jobs table ready')
        else
            print('[Smelter] Failed to create jobs table')
        end
    end)
    
    -- Tier 1 skills table - simplified syntax
    exports.oxmysql:query('CREATE TABLE IF NOT EXISTS smelter_skills (license VARCHAR(60) PRIMARY KEY, xp INT NOT NULL DEFAULT 0, total_items_smelted INT NOT NULL DEFAULT 0, total_fuel_used INT NOT NULL DEFAULT 0, total_jobs_completed INT NOT NULL DEFAULT 0)', {}, function(success)
        if success then
            print('[Smelter] Skills table ready')
        else
            print('[Smelter] Failed to create skills table')
        end
    end)
    
    -- Tier 2: Add fuel_xp column if not exists
    exports.oxmysql:query([[
        ALTER TABLE smelter_skills 
        ADD COLUMN IF NOT EXISTS fuel_xp INT NOT NULL DEFAULT 0
    ]], {}, function(success)
        if success then
            print('[Smelter] Fuel XP column ready')
        else
            print('[Smelter] Fuel XP column already exists or failed')
        end
    end)
end)
