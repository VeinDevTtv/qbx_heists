Config = {}

-- Heist Requirements based on Gang Reputation
-- The reputation is calculated based on the number of territories controlled (graffiti)
Config.HeistLevels = {
    [1] = {
        requiredTerritories = 0, -- Any gang can do level 1 heists
        heistTypes = {'convenience_store', 'small_bank'},
        cooldownHours = 6
    },
    [2] = {
        requiredTerritories = 3, -- Need to control at least 3 territories
        heistTypes = {'jewelry_store', 'medium_bank'},
        cooldownHours = 12
    },
    [3] = {
        requiredTerritories = 6, -- Need to control at least 6 territories
        heistTypes = {'large_bank', 'train_robbery'},
        cooldownHours = 24
    },
    [4] = {
        requiredTerritories = 10, -- Need to control at least 10 territories
        heistTypes = {'yacht_heist', 'casino_heist'},
        cooldownHours = 48 
    }
}

-- Define heist locations and details
Config.Heists = {
    convenience_store = {
        name = "Convenience Store",
        level = 1,
        minPlayers = 1,
        maxPlayers = 3,
        requiredItems = {'lockpick', 'hacking_device'},
        payout = {
            min = 5000,
            max = 15000
        },
        successRate = 90, -- Percentage chance of success if all steps completed correctly
        locations = {
            -- Add locations with vector3 coordinates here
            -- Will be filled in by user later
            {
                label = "24/7 Supermarket - Sandy Shores",
                position = vector3(1961.5, 3740.3, 32.34), 
                heading = 120.0
            }
        }
    },
    small_bank = {
        name = "Small Bank",
        level = 1,
        minPlayers = 2,
        maxPlayers = 4,
        requiredItems = {'lockpick', 'hacking_device', 'drill'},
        payout = {
            min = 15000,
            max = 30000
        },
        successRate = 80,
        locations = {
            {
                label = "Fleeca Bank - Harmony",
                position = vector3(1175.0, 2706.0, 38.0),
                heading = 90.0
            }
        }
    },
    jewelry_store = {
        name = "Jewelry Store",
        level = 2,
        minPlayers = 2,
        maxPlayers = 4,
        requiredItems = {'thermite', 'hammer', 'hacking_device'},
        payout = {
            min = 30000,
            max = 60000
        },
        successRate = 75,
        locations = {
            {
                label = "Vangelico Jewelry Store",
                position = vector3(-630.9, -237.0, 38.0),
                heading = 35.0
            }
        }
    },
    medium_bank = {
        name = "Medium Bank",
        level = 2,
        minPlayers = 3,
        maxPlayers = 5,
        requiredItems = {'thermite', 'drill', 'hacking_device', 'c4'},
        payout = {
            min = 50000,
            max = 100000
        },
        successRate = 70,
        locations = {
            {
                label = "Pacific Standard Bank - Branch",
                position = vector3(253.4, 228.4, 101.7),
                heading = 70.0
            }
        }
    },
    large_bank = {
        name = "Large Bank",
        level = 3,
        minPlayers = 4,
        maxPlayers = 6,
        requiredItems = {'thermite', 'drill', 'laptop', 'c4', 'secure_card_01'},
        payout = {
            min = 100000,
            max = 200000
        },
        successRate = 65,
        locations = {
            {
                label = "Pacific Standard Bank - Main",
                position = vector3(254.0, 225.0, 101.87),
                heading = 340.0
            }
        }
    },
    train_robbery = {
        name = "Train Heist",
        level = 3,
        minPlayers = 3,
        maxPlayers = 5,
        requiredItems = {'thermite', 'hacking_device', 'c4', 'bolt_cutter'},
        payout = {
            min = 75000,
            max = 150000
        },
        successRate = 60,
        locations = {
            {
                label = "Train Tracks - Grand Senora Desert",
                position = vector3(2198.0, 3570.0, 45.4),
                heading = 15.0
            }
        }
    },
    yacht_heist = {
        name = "Yacht Heist",
        level = 4,
        minPlayers = 4,
        maxPlayers = 6,
        requiredItems = {'secure_card_02', 'laptop', 'bolt_cutter', 'scuba_gear', 'hacking_device'},
        payout = {
            min = 150000,
            max = 300000
        },
        successRate = 50,
        locations = {
            {
                label = "Luxury Yacht",
                position = vector3(-2030.0, -1030.0, 8.5),
                heading = 240.0
            }
        }
    },
    casino_heist = {
        name = "Casino Heist",
        level = 4,
        minPlayers = 4,
        maxPlayers = 8,
        requiredItems = {'secure_card_03', 'elite_laptop', 'drill', 'c4', 'thermal_charges', 'hacking_device'},
        payout = {
            min = 200000,
            max = 500000
        },
        successRate = 40,
        locations = {
            {
                label = "Diamond Casino & Resort",
                position = vector3(924.7, 47.0, 81.1),
                heading = 55.0
            }
        }
    }
}

-- Police alert settings
Config.PoliceAlertChance = 65 -- Percentage chance of police being alerted during a heist
Config.MinimumPolice = 0 -- Minimum number of police required for heists to be available

-- Cooldown settings
Config.GlobalCooldown = 30 -- Minutes between heists for all gangs
Config.GangCooldown = 120 -- Minutes between heists for the same gang

-- Item settings
Config.RequiredItems = {
    lockpick = {
        name = "Lockpick",
        label = "Lockpick",
        price = 500
    },
    hacking_device = {
        name = "Hacking Device",
        label = "Hacking Device",
        price = 2500
    },
    drill = {
        name = "Drill",
        label = "Drill",
        price = 3500
    },
    thermite = {
        name = "Thermite",
        label = "Thermite Charge",
        price = 5000
    },
    c4 = {
        name = "C4",
        label = "C4 Explosive",
        price = 7500
    },
    secure_card_01 = {
        name = "Secure Card A",
        label = "Secure Card Level A",
        price = 10000
    },
    secure_card_02 = {
        name = "Secure Card B",
        label = "Secure Card Level B",
        price = 15000
    },
    secure_card_03 = {
        name = "Secure Card C",
        label = "Secure Card Level C",
        price = 25000
    },
    bolt_cutter = {
        name = "Bolt Cutter",
        label = "Bolt Cutter",
        price = 4500
    },
    thermal_charges = {
        name = "Thermal Charges",
        label = "Thermal Charges",
        price = 20000
    },
    laptop = {
        name = "Specialized Laptop",
        label = "Specialized Laptop",
        price = 10000
    },
    elite_laptop = {
        name = "Elite Hacking Laptop",
        label = "Elite Hacking Laptop",
        price = 30000
    },
    scuba_gear = {
        name = "Scuba Gear",
        label = "Scuba Gear",
        price = 7500
    },
    hammer = {
        name = "Hammer",
        label = "Hammer",
        price = 1500
    }
}

-- Success rates for different minigames
Config.MinigameSuccess = {
    lockpicking = 70, -- 70% success rate for lockpicking
    hacking = 60,     -- 60% success rate for hacking
    drilling = 75,    -- 75% success rate for drilling
    thermite = 65     -- 65% success rate for thermite
}

-- Dealer locations (for buying heist equipment)
Config.Dealers = {
    {
        name = "Black Market Dealer",
        location = vector3(474.9, -1308.1, 29.2),
        hours = {start = 22, finish = 4}, -- Open from 10 PM to 4 AM
        items = {"lockpick", "hacking_device", "drill", "thermite", "bolt_cutter", "hammer"}
    },
    {
        name = "High-End Dealer",
        location = vector3(2488.0, 3722.1, 43.1),
        hours = {start = 0, finish = 23}, -- Open 24/7
        items = {"c4", "secure_card_01", "secure_card_02", "secure_card_03", "thermal_charges", "laptop", "elite_laptop", "scuba_gear"}
    }
} 