local DataAccessor = require("GA_Accessor")
local GA_Math = require("GA_Math")
local Catalog = require("GA_Catalog")

---@class ClarityPool
---@field size number
---@field duration number
---@field overflow number
ClarityPool = {}
ClarityPool.__index = ClarityPool

---@return ClarityPool
function ClarityPool.new()
    return setmetatable({
        size = GA_Globals.RELIEF_MAX_DURATION,
        duration = 0,
        overflow = 0,
    }, ClarityPool)
end

---@class StateData<Value>
---@field accessor DataAccessor<Value>
local GoonerStateData = {}
GoonerStateData.__index = GoonerStateData

---@generic Value
---@param accessor DataAccessor<Value>
---@return StateData<Value>
function GoonerStateData.new(accessor)
    return setmetatable({ accessor = accessor }, GoonerStateData)
end

---@generic Value
---@param player IsoPlayer
---@return Value
function GoonerStateData:get(player)
    return self:internal():get(player)
end

---@generic Value
---@return DataAccessor<Value>
function GoonerStateData:internal()
    return self.accessor
end

---@param player IsoPlayer
function GoonerStateData:reset(player)
    self.accessor:reset(player)
end

---@class HorninessState: StateData<number>
local HorninessState = setmetatable({}, GoonerStateData)
HorninessState.__index = HorninessState

---@param accessor DataAccessor<number>
---@return HorninessState
function HorninessState.new(accessor)
    return setmetatable({ accessor = accessor }, HorninessState)
end

---@param player IsoPlayer
---@return number
function HorninessState:get(player)
    return self.accessor:get(player)
end

---@param player IsoPlayer
---@param value number
function HorninessState:set(player, value)
    self.accessor:set(player, math.clamp(value, GA_Globals.MODIFIER_VALUE_MIN, GA_Globals.MODIFIER_VALUE_MAX))
end

---@param player IsoPlayer
---@param value number
function HorninessState:add(player, value)
    self:set(player, self:get(player) + value)
end

---@param player IsoPlayer
---@return number
function HorninessState:get_level(player)
    return GA_Math.GetLevel(
        self:get(player),
        GA_Globals.MODIFIER_VALUE_MIN,
        GA_Globals.MODIFIER_VALUE_MAX,
        4
    )
end

---@class ClarityState: StateData<ClarityPool>
local ClarityState = setmetatable({}, GoonerStateData)
ClarityState.__index = ClarityState

---@param accessor DataAccessor<ClarityPool>
---@return ClarityState
function ClarityState.new(accessor)
    return setmetatable({ accessor = accessor }, ClarityState)
end

---@param player IsoPlayer
---@return ClarityPool
function ClarityState:get(player)
    return self.accessor:get(player)
end

---@param player IsoPlayer
---@param value ClarityPool
function ClarityState:set(player, value)
    self.accessor:set(player, value)
end

---@param player IsoPlayer
---@return boolean
function ClarityState:is_clear(player)
    local pool = self:get(player)
    return pool.duration > 0
end

---@param player IsoPlayer
---@return number
function ClarityState:get_duration(player)
    local pool = self:get(player)
    return pool.duration
end

---@param player IsoPlayer
---@return number
function ClarityState:get_duration_level(player)
    return GA_Math.GetLevel(self:get_duration(player), 0, GA_Globals.RELIEF_MAX_DURATION, 4)
end

---@param player IsoPlayer
---@return number
function ClarityState:get_overflow(player)
    local pool = self:get(player)
    return pool.overflow
end

---@param player IsoPlayer
---@return number
function ClarityState:get_pool_size(player)
    local pool = self:get(player)
    return pool.size
end

---@param player IsoPlayer
---@param amount number
function ClarityState:add(player, amount)
    local pool = self:get(player) ---@type ClarityPool
    local available = math.max(0, pool.size - pool.duration)
    local added = math.min(amount, available)

    pool.duration = pool.duration + added
    pool.overflow = pool.overflow + amount - added
    self:set(player, pool)
end

---@param player IsoPlayer
---@param amount number
---@return number
function ClarityState:remove(player, amount)
    local pool = self:get(player) ---@type ClarityPool
    local removed = math.clamp(math.abs(amount), 0, pool.duration)
    pool.duration = pool.duration - removed
    self:set(player, pool)
    return pool.duration
end

---@class StimuliState: StateData<table<string, number>>
local StimuliState = setmetatable({}, GoonerStateData)
StimuliState.__index = StimuliState

---@param accessor DataAccessor<table<string, number>>
---@return StimuliState
function StimuliState.new(accessor)
    return setmetatable({ accessor = accessor }, StimuliState)
end

---@param player IsoPlayer
---@param kind string
---@return number
function StimuliState:get(player, kind)
    local stimuli = self.accessor:get(player)
    if not stimuli[kind] then
        stimuli[kind] = 1.0
    end

    return stimuli[kind]
end

---@param player IsoPlayer
---@param kind StimulusKind
---@param value number
function StimuliState:set(player, kind, value)
    local stimuli = self.accessor:get(player)
    stimuli[kind] = value
    self.accessor:set(player, stimuli)
end

---@param player IsoPlayer
---@param kind StimulusKind
---@return boolean
function StimuliState:can_use(player, kind)
    return self:get(player, kind) > 0
end

---@param player IsoPlayer
---@param kind StimulusKind
function StimuliState:inc(player, kind)
    local value = self:get(player, kind)
    self:set(player, kind, math.clamp(value * (1 + Catalog.Stimuli.get(kind).dec_delta), 0, 1))
end

---@param player IsoPlayer
---@param kind StimulusKind
function StimuliState:dec(player, kind)
    local value = self:get(player, kind)
    self:set(player, kind, math.clamp(value * (1 - Catalog.Stimuli.get(kind).dec_delta), 0, 1))
end

---@class GoonerState
---@field Horniness HorninessState
---@field Clarity ClarityState
---@field Stimuli StimuliState
GoonerState = {
    Horniness = HorninessState.new(DataAccessor.new(GA_Globals.DATA_KEYS.HORNINESS, 0)),
    Clarity = ClarityState.new(DataAccessor.new(GA_Globals.DATA_KEYS.CLARITY, ClarityPool.new())),
    Stimuli = StimuliState.new(DataAccessor.new(GA_Globals.DATA_KEYS.STIMULI, {})),
}

---@param player IsoPlayer
---@return number
function GoonerState:get_perk_level(player)
    return player:getPerkLevel(Perks.Gooner) or 0
end

---@param player IsoPlayer
function GoonerState:Reset(player)
    self.Stimuli:reset(player)
    self.Clarity:reset(player)
    self.Horniness:reset(player)
end
