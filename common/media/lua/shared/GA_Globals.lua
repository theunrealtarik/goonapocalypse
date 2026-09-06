---@alias Duration number

GA_Globals = {
    DATA_KEYS = {
        ROOT = "GOONAPOCALYPSE",
        HORNINESS = "GA_Gooning",
        CLARITY = "GA_Clarity",
        STIMULI = "GA_Stimuli",
    },

    -- Trait
    GOONER_TRAIT_LEVEL = 5,

    -- Default mood changes
    DEFAULT_UNHAPPINESS_INCREASE = ZomboidGlobals.UnhappinessIncrease,
    DEFAULT_BOREDOM_INCREASE = ZomboidGlobals.BoredomIncrease,
    DEFAULT_BOREDOM_DECREASE = ZomboidGlobals.BoredomDecrease,

    -- BALANCE

    -- Modifier values
    MODIFIER_VALUE_MIN = 0,
    MODIFIER_VALUE_MAX = 100,
    MODIFIER_VALUE_STEP = 25,

    -- Perk levels
    PERK_LEVEL_MIN = 0,
    PERK_LEVEL_MAX = 10,

    -- Gooner multiplier
    STARTING_MULTIPLIER = 1.0,
    TARGET_MULTIPLIER = 2.25,

    -- XP
    BASE_XP_GAIN = 7.5,

    -- Relief duration (game hours)
    RELIEF_MAX_DURATION = 48, ---@type Duration
    RELIEF_MIN_DURATION = 4, ---@type Duration

    DEPRIVED_DAYS_MODIFIER_PEAK = 100,
}
