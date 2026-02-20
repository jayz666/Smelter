-- Database setup for smelter jobs
exports.oxmysql:ready(function()
    exports.oxmysql:query([[CREATE TABLE IF NOT EXISTS smelter_jobs (
        license VARCHAR(50) PRIMARY KEY,
        recipe VARCHAR(50) NOT NULL,
        amount INT NOT NULL,
        finishTime INT NOT NULL,
        fuelUsed INT NOT NULL,
        heat_choice VARCHAR(10) DEFAULT 'medium',
        hold_mode TINYINT(1) DEFAULT 0,
        quality_tier VARCHAR(10) DEFAULT 'basic',
        is_slag TINYINT(1) DEFAULT 0,
        createdAt INT DEFAULT UNIX_TIMESTAMP()
    )]], {}, function(success)
        if success then
            print('[Smelter] Jobs table ready')
        else
            print('[Smelter] Failed to create jobs table')
        end
    end)
    
    -- Tier 1 skills table - simplified syntax with fuel_xp included
    exports.oxmysql:query('CREATE TABLE IF NOT EXISTS smelter_skills (license VARCHAR(60) PRIMARY KEY, xp INT NOT NULL DEFAULT 0, fuel_xp INT NOT NULL DEFAULT 0, total_items_smelted INT NOT NULL DEFAULT 0, total_fuel_used INT NOT NULL DEFAULT 0, total_jobs_completed INT NOT NULL DEFAULT 0)', {}, function(success)
        if success then
            print('[Smelter] Skills table ready')
        else
            print('[Smelter] Failed to create skills table')
        end
    end)
end)
