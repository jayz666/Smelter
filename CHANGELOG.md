# Changelog

All notable changes to the FiveM Smelter System will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-02-20

### Added
- **Fuel Efficiency Progression System**: Complete dual progression tree
- **Tabbed UI Interface**: Clean separation between Time and Fuel skills
- **Fuel Efficiency Calculation**: 3% reduction per level, max 15%
- **Unlock System**: Fuel skills unlock at Time Level 5
- **Dual XP System**: Separate XP pools for Time and Fuel progression
- **Linear Fuel XP Formula**: `fuelUsed * 10` for balanced progression
- **Fuel Efficiency Display**: Real-time efficiency indicators
- **Unlock Status Indicators**: Clear progression feedback

### Features
- **Dual Progression Architecture**: Time efficiency (27% max) + Fuel efficiency (15% max)
- **Economic Balance**: Combined max efficiency of 42% total improvement
- **Player Choice System**: Specialize in speed, efficiency, or balance
- **Database Schema Extension**: Added `fuel_xp` column to smelter_skills table
- **Server-Authoritative Fuel Calculations**: All fuel logic server-side
- **Defensive Programming**: Caps and minimums for fuel efficiency
- **Progression Control**: Fuel XP locked until Time Level 5

### Security
- **Server-Side Fuel Efficiency**: No client-side trust for fuel calculations
- **Input Validation**: Enhanced validation for fuel efficiency parameters
- **Economic Safety Nets**: Hard caps prevent excessive fuel reduction
- **Unlock Enforcement**: Server-side validation of unlock requirements

### Performance
- **Optimized Database Queries**: Updated to include fuel_xp in skill loading
- **Efficient UI Updates**: Tab-based interface reduces DOM manipulation
- **Cached Calculations**: Fuel efficiency cached during job processing

### Database Changes
- **ALTER TABLE**: Added `fuel_xp INT NOT NULL DEFAULT 0` to smelter_skills
- **Updated Queries**: Modified SELECT and INSERT statements for dual XP system
- **Backward Compatibility**: Existing records automatically get fuel_xp = 0

### UI Enhancements
- **Tab Navigation**: Switch between Time and Fuel skill panels
- **Dual Progress Bars**: Independent tracking for both skill branches
- **Status Indicators**: Lock/unlock status and efficiency displays
- **Responsive Design**: Maintained CEF-safe styling

### Economic Impact
- **Controlled Expansion**: Fuel efficiency limited to prevent inflation
- **Specialization Rewards**: Meaningful choices between speed and efficiency
- **Resource Stability**: Conservative caps maintain economic balance
- **Long-Term Sustainability**: Designed for persistent server economies

## [1.0.0] - 2026-02-20

### Added
- **Skill Progression System**: 10 levels with time efficiency (0% → 27% reduction)
- **MySQL Persistence**: License-based job storage, survives server restarts
- **Live UI**: Real-time countdown timer and skill display
- **Draggable Interface**: Move smelter UI anywhere on screen
- **Balanced Economy**: Time-only efficiency, fuel consumption unchanged
- **Server Authority**: All calculations server-side, exploit-resistant
- **CEF-Safe Rendering**: No blur effects, compatible with all clients

### Features
- **XP System**: `XP Gained = Amount × Recipe Base Time`
- **Level Requirements**: 0 XP (Level 1) to 2700 XP (Level 10)
- **Statistics Tracking**: Items smelted, fuel used, jobs completed
- **Database Caching**: Reduces MySQL queries for performance
- **Defensive Coding**: Input validation and error handling

### Security
- Server-authoritative time calculations
- License-based persistence prevents job sharing
- No client-side trust for critical data
- Parameterized MySQL queries prevent injection

### Performance
- Cached skill data reduces database load
- Debounced persistence writes
- Efficient MySQL queries with parameters
- Minimal memory footprint

### Database Schema
- `smelter_jobs`: Active job storage per license
- `smelter_skills`: Player progression and statistics

### Configuration
- Configurable smelter location
- Customizable recipes with base times
- Adjustable fuel consumption rates
- Maximum batch size limits

---

## [Unreleased]

### Planned
- Tier 3: Heat mechanics and quality tiers
- Tier 4: Furnace ownership and multi-node processing
- Advanced economic features and market integration
