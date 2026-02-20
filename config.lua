Config = {}

Config.SmelterLocation = vec4(1110.81, -2007.85, 30.04, 209.47)
Config.MaxBatch = 20 -- maximum items per batch
Config.ClientCooldown = 2000 -- 2 seconds in milliseconds

Config.Fuel = {
    item = 'coal',
    burnTime = 50 -- seconds per fuel item
}

Config.Recipes = {
    iron = {
        label = "Iron",
        input = "iron_ore",
        output = "iron",
        baseTime = 50.0,
        optimalHeat = 'medium',
        heatDifficulty = 2,
        slagItem = 'slag'
    },
    copper = {
        label = "Copper",
        input = "copper_ore",
        output = "copper",
        baseTime = 24.0,
        optimalHeat = 'medium',
        heatDifficulty = 2,
        slagItem = 'slag'
    },
    gold = {
        label = "Gold",
        input = "gold_ore",
        output = "gold",
        baseTime = 75.0,
        optimalHeat = 'high',
        heatDifficulty = 3,
        slagItem = 'slag'
    }
}

-- Tier 3: Global quality multipliers (conservative)
Config.QualityMultipliers = {
    basic = 1.00,
    standard = 1.05,
    premium = 1.10,
    master = 1.15
}

-- Tier 3: Add heat settings to each recipe (fallback for any missing)
for _, recipe in pairs(Config.Recipes) do
    recipe.optimalHeat = recipe.optimalHeat or 'medium'
    recipe.heatDifficulty = recipe.heatDifficulty or 2
    recipe.slagItem = recipe.slagItem or 'slag'
end

Config.Target = {
    name = 'smelter',
    icon = 'fas fa-fire',
    label = 'Use Smelter',
    distance = 2.0
}
