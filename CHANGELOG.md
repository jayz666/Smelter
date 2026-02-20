# Changelog

All notable changes to the FiveM Smelter System will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-20

### Added
- **Skill Progression System**: 10 levels with time efficiency (0% → 27% reduction)
- **MySQL Persistence**: License-based job storage survives server restarts
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
- Efficient CEF-safe UI rendering
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
- Tier 2: Fuel efficiency progression branch
- Tier 3: Heat mechanics and quality tiers
- Tier 4: Furnace ownership and multi-node processing
