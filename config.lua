Config = {}

Config.SmelterLocation = vec4(1110.81, -2007.85, 30.04, 209.47)
Config.MaxBatch = 20 -- maximum items per batch
Config.ClientCooldown = 2000 -- 2 seconds in milliseconds

Config.Fuel = {
    item = "coal",
    burnTime = 10 -- seconds per fuel item
}

Config.Recipes = {
    iron = {
        label = "Iron",
        input = "iron_ore",
        output = "iron_ingot",
        baseTime = 5
    },
    copper = {
        label = "Copper",
        input = "copper_ore",
        output = "copper_ingot",
        baseTime = 6
    },
    gold = {
        label = "Gold",
        input = "gold_ore",
        output = "gold_ingot",
        baseTime = 8
    }
}

Config.Target = {
    name = 'smelter',
    icon = 'fas fa-fire',
    label = 'Use Smelter',
    distance = 2.0
}
