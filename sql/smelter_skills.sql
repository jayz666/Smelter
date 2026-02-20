-- Smelter Skills Table
-- Stores player skill progression and statistics

CREATE TABLE IF NOT EXISTS smelter_skills (
    license VARCHAR(60) PRIMARY KEY,
    xp INT NOT NULL DEFAULT 0,
    total_items_smelted INT NOT NULL DEFAULT 0,
    total_fuel_used INT NOT NULL DEFAULT 0,
    total_jobs_completed INT NOT NULL DEFAULT 0
);
