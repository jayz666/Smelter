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
            print('[Smelter] Database table ready')
        else
            print('[Smelter] Failed to create database table')
        end
    end)
end)
