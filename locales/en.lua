local Translations = {
    error = {
        not_enough_police = "Not enough police in the city",
        no_permission = "You don't have permission to do this",
        not_in_gang = "You need to be in a gang to perform heists",
        insufficient_gang_level = "Your gang doesn't control enough territories for this heist",
        heist_cooldown = "This heist is currently on cooldown",
        gang_cooldown = "Your gang has recently performed a heist and must wait",
        global_cooldown = "Another gang has recently completed a heist, wait a bit",
        missing_item = "You are missing required item: %{item}",
        not_enough_players = "You need at least %{min} players for this heist",
        too_many_players = "Maximum of %{max} players allowed for this heist",
        heist_already_active = "Your gang already has an active heist",
        inventory_full = "Your inventory is full",
        dealer_closed = "This dealer is currently closed",
        not_enough_money = "You don't have enough money",
        minigame_failed = "You failed the %{minigame}",
        canceled_heist = "Heist has been canceled",
        invalid_heist = "Invalid heist type",
        item_purchase_failed = "Failed to purchase item"
    },
    success = {
        heist_started = "Heist started successfully",
        heist_completed = "Heist completed successfully. Earned: $%{amount}",
        item_purchased = "You purchased %{item} for $%{price}",
        lockpick_success = "Lockpicking successful",
        hack_success = "Hacking successful",
        drill_success = "Drilling successful",
        thermite_success = "Thermite placement successful",
        stage_completed = "Stage %{stage} completed",
        territory_gained = "Your gang has gained control of a new territory",
        gained_reputation = "Your gang has gained %{rep} reputation"
    },
    info = {
        heist_level_info = "Heist Level %{level} requires %{territories} controlled territories",
        dealer_hours = "This dealer is open from %{start}:00 to %{finish}:00",
        item_details = "%{item} - $%{price}",
        heist_details = "Name: %{name}\nLevel Required: %{level}\nPlayers Needed: %{min}-%{max}\nPayout Range: $%{min_payout}-$%{max_payout}",
        cooldown_active = "Cooldown active for another %{time} minutes",
        police_alert = "The police have been alerted to suspicious activity",
        heist_preparation = "You are preparing for a %{name} heist",
        heist_stage = "Current Stage: %{stage}/%{total}",
        required_items = "Required Items:",
        heist_instruction = "Instructions: %{instruction}",
        stage_timer = "Time remaining: %{time} seconds",
        heist_app_desc = "Plan and execute high-stakes heists with your gang"
    },
    commands = {
        heist_status = "Check the status of your current heist",
        reset_heist = "Reset a heist (Admin Only)",
        add_territory = "Add a territory to a gang (Admin Only)",
        set_cooldown = "Set heist cooldown (Admin Only)"
    },
    menu = {
        heist_app = "Gang Heists",
        available_heists = "Available Heists",
        active_heist = "Active Heist",
        heist_history = "Heist History",
        shop_items = "Shop Items",
        start_heist = "Start Heist",
        cancel_heist = "Cancel Heist",
        view_details = "View Details",
        back = "Back",
        close = "Close",
        buy = "Buy for $%{price}",
        gang_stats = "Gang Statistics",
        required_items = "Required Items",
        tier = "Tier %{tier} Heist",
        level_locked = "Locked (Requires Tier %{tier})",
        members = "Members: %{current}/%{max}",
        territories = "Territories: %{count}/%{required}",
        preparation = "Preparation",
        execution = "Execution",
        escape = "Escape",
        payout = "Expected Payout: $%{min}-$%{max}",
        police_risk = "Police Response Risk: %{risk}%",
        difficulty = "Difficulty: %{difficulty}",
        cooldown = "Cooldown: %{hours} hours"
    }
}

Lang = Locale:new({
    phrases = Translations,
    warnOnMissing = true
}) 