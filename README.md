# QBX Heists

An advanced heist system for QBX Framework that integrates with qbx_laptop and qbx_graffiti for gang progression.

## Features

- **Territory-Based Progression**: Gangs unlock higher-tier heists as they control more territories through qbx_graffiti
- **Multi-Stage Heists**: Each heist follows a three-stage process (Preparation, Execution, Escape)
- **Laptop Integration**: Manage heists through a dedicated app in the qbx_laptop interface
- **Teamwork Required**: Heists require multiple participants based on difficulty
- **Dynamic Heist Types**: 8 different heist types with varying difficulty, requirements, and payouts
- **Specialized Equipment**: Purchase and use specialized equipment from dealers
- **Minigame Integration**: Uses existing minigames for a variety of challenges
- **Police Alert System**: Risk of police response during heists
- **Cooldown System**: Prevents spamming heists with configurable cooldowns
- **Comprehensive Statistics**: Track your gang's heist history and performance

## Dependencies

- [qbx_core](https://github.com/Qbox-project/qbx_core)
- [oxmysql](https://github.com/overextended/oxmysql)
- [qbx_laptop](https://github.com/Qbox-project/qbx_laptop)
- [qbx_graffiti](https://github.com/Qbox-project/qbx_graffiti)
- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_target](https://github.com/overextended/ox_target)
- [ox_inventory](https://github.com/overextended/ox_inventory)
- [ls_bolt_minigame](https://github.com/lsvMoretti/ls_bolt_minigame) (For lockpicking)
- [ultra-voltlab](https://github.com/ultrahacx/ultra-voltlab) (For hacking)

## Installation

1. Ensure you have all dependencies installed and updated
2. Place the `qbx_heists` folder in your resources directory
3. Add `ensure qbx_heists` to your server.cfg after all dependencies
4. Import the SQL file into your database (if using a fresh install)
5. Add the required items to your ox_inventory items.lua file
6. Configure the script as needed in the config.lua file
7. Start your server

## Configuration

The script is highly configurable through the `config.lua` file. Some key configurations include:

- **Heist Levels**: Requirements for unlocking different heist tiers
- **Heist Types**: Configure different heist locations and requirements
- **Item Settings**: Define required items for different heist types
- **Dealer Locations**: Set up dealers that sell heist equipment
- **Cooldown Settings**: Configure cooldown periods between heists
- **Police Settings**: Requirements for police presence and alert chances

## Heist Types and Progression

### Level 1 (0+ Territories)
- **Convenience Store**: Low-risk, low-reward heist suitable for beginners
- **Small Bank**: Entry-level bank robbery

### Level 2 (3+ Territories)
- **Jewelry Store**: Rob valuable jewelry from display cases
- **Medium Bank**: More challenging bank robbery with better rewards

### Level 3 (6+ Territories)
- **Large Bank**: High-security bank with significant rewards
- **Train Robbery**: Intercept and rob a cargo train

### Level 4 (10+ Territories)
- **Yacht Heist**: High-stakes robbery of a luxury yacht
- **Casino Heist**: The ultimate robbery with the highest difficulty and reward

## Gang Progression System

The heist progression is tied to the territories controlled by gangs:

1. Gangs need to control areas by spraying graffiti using qbx_graffiti
2. More territories = Access to higher-tier heists
3. Completing heists provides funds for expanding territory
4. Creates a natural progression and competition between gangs

## Usage

### For Players

1. Join or create a gang in the qbx_laptop
2. Gain territories using the qbx_graffiti system
3. Use the Laptop to access the Heists app
4. Purchase necessary equipment from dealers around the city
5. Select an available heist and gather your crew
6. Complete the heist and escape with the loot

### For Administrators

- Use `/resetheist [gangId]` to reset a gang's active heist if it gets stuck
- Configure the script in `config.lua` to balance the economy
- Set up dealer locations strategically around the map

## Commands

- `/joinheist` - Join an active heist for your gang
- `/heistinfo` - Check the status of your current heist
- `/finddealer` - Find the nearest heist equipment dealer

## Exports

The script provides several exports for advanced integration:

### Client-side

```lua
-- Check if a player is in a heist
exports['qbx_heists']:IsPlayerInHeist() -- Returns boolean

-- Get the current heist data
exports['qbx_heists']:GetCurrentHeist() -- Returns heist data
```

### Server-side

```lua
-- Get all active heists
exports['qbx_heists']:GetActiveHeists() -- Returns table of active heists

-- Get heist participants
exports['qbx_heists']:GetHeistParticipants(gangId) -- Returns table of participant IDs

-- Check if player is in a heist
exports['qbx_heists']:IsPlayerInHeist(playerId) -- Returns boolean and gangId if true
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Credits

- Developed for the QBX Framework
- Inspiration from various heist systems and real-world robbery scenarios
- Special thanks to the QBX development community 