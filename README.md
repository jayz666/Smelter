# Smelter - Standalone FiveM Industrial Processing System

A production-grade smelting resource for FiveM servers featuring multi-recipe processing, fuel mechanics, and persistent job storage.

## Features

- **Multi-Recipe Processing**: Support for multiple ore types with configurable recipes
- **Fuel System**: Coal-based fuel requirements with burn time calculations
- **Server-Authoritative Timing**: Prevents client-side exploits with server-controlled job timing
- **Persistent Jobs**: Jobs survive server restarts with file-based persistence
- **CEF-Safe UI**: Modern left-side panel interface without blur effects
- **No Framework Dependencies**: Standalone implementation using ox_lib, ox_inventory, and ox_target

## Dependencies

- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_inventory](https://github.com/overextended/ox_inventory)  
- [ox_target](https://github.com/overextended/ox_target)

## Installation

1. Place the `smelter` folder inside your resources directory
2. Ensure dependencies are started before smelter:
   ```lua
   ensure ox_lib
   ensure ox_inventory
   ensure ox_target
   ```
3. Add to your server.cfg:
   ```lua
   ensure smelter
   ```

## Configuration

All recipes and fuel settings are configurable in `config.lua`:

```lua
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
    }
    -- Add more recipes as needed
}

## 🗄️ Database Persistence

Active smelting jobs are automatically saved to MySQL database and restored on server restart. The system uses license-based storage with automatic cleanup and recovery mechanisms.

### Database Schema
```sql
-- Import sql/smelter_jobs.sql
-- Import sql/smelter_skills.sql
```

## Security Features

- Server-side validation of all player inputs
- Atomic item removal with rollback on failure
- License-based job persistence prevents session hijacking
- No client-trusted timing or inventory calculations

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
