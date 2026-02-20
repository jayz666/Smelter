-- Smelter Jobs Table
-- Stores active smelting jobs per player license

CREATE TABLE IF NOT EXISTS smelter_jobs (
    license VARCHAR(50) PRIMARY KEY,
    recipe VARCHAR(50) NOT NULL,
    amount INT NOT NULL,
    finishTime INT NOT NULL,
    fuelUsed INT NOT NULL,
    createdAt INT DEFAULT UNIX_TIMESTAMP()
);
