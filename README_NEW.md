# FiveM Smelter System

A production-grade industrial smelting system with skill progression, MySQL persistence, and balanced economy.

## 🚀 Features

- **Skill Progression**: 10 levels with time efficiency (0% → 27% reduction)
- **MySQL Persistence**: License-based job storage, survives server restarts
- **Balanced Economy**: Time-only efficiency, fuel consumption unchanged
- **Live UI**: Real-time countdown timer, skill display, draggable interface
- **Server Authority**: All calculations server-side, exploit-resistant
- **CEF-Safe**: No blur effects, compatible with all FiveM clients

## 📋 Requirements

- **ox_lib** - Framework and UI utilities
- **ox_inventory** - Item management
- **ox_target** - Interaction system  
- **oxmysql** - Database persistence

## 🛠️ Installation

1. **Place resource in server:**
   ```
   resources/smelter/
   ```

2. **Add to server.cfg:**
   ```lua
   ensure oxmysql
   ensure ox_lib
   ensure ox_inventory
   ensure ox_target
   ensure smelter
   ```

3. **Import SQL schema:**
   ```sql
   -- Import sql/smelter_jobs.sql
   -- Import sql/smelter_skills.sql
   ```

4. **Configure location and recipes in `config.lua`:**
   ```lua
   Config.SmelterLocation = vec4(1110.81, -2007.85, 30.04, 209.47)
   ```

## ⚙️ Configuration

### Smelter Location
```lua
Config.SmelterLocation = vec4(x, y, z, heading)
```

### Recipes
```lua
Config.Recipes = {
    copper = {
        label = "Copper",
        input = "copper_ore", 
        output = "copper",
        baseTime = 24.0
    }
}
```

### Fuel System
```lua
Config.Fuel = {
    item = "coal",
    burnTime = 50 -- seconds per fuel item
}
```

## 🎯 Skill System

- **XP Formula**: `XP Gained = Amount × Recipe Base Time`
- **Efficiency**: 3% reduction per level starting from Level 2
- **Max Level**: 10 (27% total time reduction)
- **Fuel**: Unaffected by skill level (economy balanced)

### Level Requirements
- Level 1: 0 XP
- Level 2: 100 XP  
- Level 3: 250 XP
- Level 4: 450 XP
- Level 5: 700 XP
- Level 6: 1000 XP
- Level 7: 1350 XP
- Level 8: 1750 XP
- Level 9: 2200 XP
- Level 10: 2700 XP

## 🗄️ Database Schema

### Jobs Table
```sql
CREATE TABLE IF NOT EXISTS smelter_jobs (
    license VARCHAR(50) PRIMARY KEY,
    recipe VARCHAR(50) NOT NULL,
    amount INT NOT NULL,
    finishTime INT NOT NULL,
    fuelUsed INT NOT NULL,
    createdAt INT DEFAULT UNIX_TIMESTAMP()
);
```

### Skills Table  
```sql
CREATE TABLE IF NOT EXISTS smelter_skills (
    license VARCHAR(60) PRIMARY KEY,
    xp INT NOT NULL DEFAULT 0,
    total_items_smelted INT NOT NULL DEFAULT 0,
    total_fuel_used INT NOT NULL DEFAULT 0,
    total_jobs_completed INT NOT NULL DEFAULT 0
);
```

## 🔧 Troubleshooting

### Black UI Background
- Clear FiveM cache
- Verify CSS transparency rules
- Check for conflicting resources

### oxmysql Errors
- Ensure oxmysql starts before smelter
- Verify MySQL connection
- Check database credentials

### Missing Items
- Confirm ox_inventory item names exist
- Check item registration in items.lua
- Verify spelling matches config

### UI Not Opening
- Check ox_target is working
- Verify smelter coordinates
- Look for JavaScript errors in F12 console

## 🎮 Usage

1. Approach smelter location
2. Press E to open interface
3. Select recipe and amount
4. Add required fuel (coal)
5. Start smelting
6. Wait for completion or collect when ready

## 🛡️ Security Features

- Server-authoritative calculations
- License-based persistence
- Input validation and sanitization
- No client-side trust for critical data
- Defensive coding guards

## 📈 Performance

- Cached skill data to reduce database queries
- Debounced persistence writes
- Efficient MySQL queries with parameters
- CEF-safe UI rendering

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Test thoroughly
4. Submit pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Dependencies

- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_inventory](https://github.com/overextended/ox_inventory) 
- [ox_target](https://github.com/overextended/ox_target)
- [oxmysql](https://github.com/overextended/oxmysql)

## 📞 Support

For issues and support:
- Create GitHub issue
- Check troubleshooting section
- Verify all dependencies are running

---

**Production-Grade FiveM Resource**  
*Built with controlled system engineering*
