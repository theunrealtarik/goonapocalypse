local Catalog = require("GA_Catalog")

local GA_Math = require("GA_Math")

---@diagnostic disable: duplicate-set-field


-- SLEEP
Events.OnSleepingTick.Add(function(player_idx, time_of_day)
    local local_player = getSpecificPlayer(player_idx)
    if local_player then
        if GoonerState.Horniness:get_level(local_player) >= 1 then
            local_player:forceAwake()
            HaloTextHelper.addBadText(local_player, getText("UI_HaloText_GA_Sleep"))
            UIManager.getSpeedControls():SetCurrentGameSpeed(1)
        end
    end
end)


-- LOOTING
require "TimedActions/ISInventoryTransferAction"
local ISINVENTORYTRANSFERACTION_ORIGINAL = {
    ---@return ISInventoryTransferAction
    NEW = ISInventoryTransferAction.new,
}

---@param character IsoPlayer
---@param item InventoryItem
---@param srcContainer ItemContainer
---@param destContainer ItemContainer
---@param time number
function ISInventoryTransferAction:new(character, item, srcContainer, destContainer, time)
    local instance = ISINVENTORYTRANSFERACTION_ORIGINAL.NEW(
        self,
        character,
        item,
        srcContainer,
        destContainer,
        time
    )

    local transfer_mult = GA_Math.CalcActionTimeMult(
        GoonerState.Horniness:get(character),
        GoonerState.Clarity:get_duration(character),
        GoonerState:get_perk_level(character)
    )

    instance.maxTime = instance.maxTime * transfer_mult
    return instance
end

-- FITNESS
require "TimedActions/ISFitnessAction"
local ISFITNESSACTION_ORIGINAL = { UPDATE = ISFitnessAction.update }

function ISFitnessAction:update()
    local dt = getGameTime():getGameWorldSecondsSinceLastUpdate()
    local dih = dt / 3600 --- for the memes

    local g_lvl = GoonerState:get_perk_level(self.character)
    local h_val = GoonerState.Horniness:get(self.character)

    self.character:getXp():AddXPNoMultiplier(
        Perks.Gooner,
        -1
        * GA_Globals.BASE_XP_GAIN
        * GA_Math.CalcLevelMult(
            g_lvl,
            GA_Globals.RELIEF_MAX_DURATION / GA_Math.RELIEF_BASE_MIN,
            GA_Globals.RELIEF_MIN_DURATION / GA_Math.RELIEF_BASE_MAX
        )
    )

    GoonerState.Horniness:add(self.character, -GA_Math.CalcDecayRate(dih, g_lvl, h_val))
    ISFITNESSACTION_ORIGINAL.UPDATE(self)
end

-- READING
require "TimedActions/ISReadABook"
local ISREADBOOK_ORIGINAL = {
    NEW = ISReadABook.new,
    PERFORM = ISReadABook.perform,
    UPDATE = ISReadABook.update,
    GET_DURATION = ISReadABook.getDuration,
    STOP = ISReadABook.stop,
}

---@param character IsoPlayer
---@param item Literature
function ISReadABook:new(character, item)
    self.interrupt = false

    local gooner_level = character:getPerkLevel(Perks.Gooner)
    if gooner_level >= 1 then
        local interrupt_chance = 10 * gooner_level
        local dice = ZombRand(100)
        if dice < interrupt_chance
            and item:getFullType() ~= "Base.HottieZ"
            and item:getFullType() ~= "Base.HottieZ_New" then
            self.interrupt = true
        end
    end

    return ISREADBOOK_ORIGINAL.NEW(self, character, item)
end

function ISReadABook:perform()
    local stimulus = assert(Catalog.Stimuli.get(Catalog.StimulusKind.ReadingHottieZ))
    if not GoonerState.Clarity:is_clear(self.character) and stimulus:is_valid_item(self.item:getFullType()) then
        GoonerState.Horniness:add(
            self.character,
            stimulus.base_gain
            * GA_Math.CalcPlayerCtxMult(self.character)
            * GA_Math.CalcLevelMult(
                GoonerState:get_perk_level(self.character),
                GA_Globals.STARTING_MULTIPLIER,
                GA_Globals.TARGET_MULTIPLIER
            ) * GoonerState.Stimuli:get(self.character, stimulus.kind)
        )

        GoonerState.Stimuli:dec(self.character, stimulus.kind)
    end
    ISREADBOOK_ORIGINAL.PERFORM(self)
end

function ISReadABook:update()
    if self:getJobDelta() >= 0.5 and self.interrupt == true then
        GoonerLines.RollDice(self.character, GoonerLines.BookInterruption, 100)
        self:stop()
        ISTimedActionQueue.clear(self.character)
        return
    end

    ISREADBOOK_ORIGINAL.UPDATE(self)
end

function ISReadABook:getDuration()
    local original_time = ISREADBOOK_ORIGINAL.GET_DURATION(self)

    local player = self.character
    if not player then return original_time end
    local reading_mult = GA_Math.CalcActionTimeMult(
        GoonerState.Horniness:get(player),
        GoonerState.Clarity:get_duration(player),
        GoonerState:get_perk_level(player))
    return original_time * reading_mult
end

function ISReadABook:stop()
end
