local GA_Math = require("GA_Math")

local ANIMATION_ENTRY_FRAMES = 30
local ANIMATION_LOOP_FRAMES = 290
local ANIMATION_FINISH_FRAMES = 90

local TOC_Compat = require("TOC/API")

---@alias GooningAnimationGender "Male" | "Female"
---@alias GooningAnimationHand "Right" | "Left"
---@enum GooningAnimationPhase
local GooningAnimationPhase = {
    Entry = "Entry",
    Loop = "Loop",
    Finish = "Finish"
}



---@class ISGooningAction : ISBaseTimedAction
---@field character IsoPlayer
---@field phase GooningAnimationPhase
---@field entryDuration number
---@field finishDuration number
---@field loopDuration number
---@field cycles number
---@field maxTime number
---@field onComplete fun(cycles: number)|nil
---@field requirement fun(player: IsoPlayer): InventoryItem|nil
---@field stopOnWalk boolean
---@field stopOnRun boolean
---@field ignoreHandsWounds boolean
---@field skipTOC boolean
ISGoonAction = ISBaseTimedAction:derive("ISGoonAction")


function ISGoonAction:start()
    local primary = self.character:getPrimaryHandItem()
    if primary then
        ISTimedActionQueue.add(ISUnequipAction:new(self.character, primary, 50))
    end

    local secondary = self.character:getSecondaryHandItem()
    if secondary then
        ISTimedActionQueue.add(ISUnequipAction:new(self.character, secondary, 50))
    end


    GoonerLines.RollDice(self.character, GoonerLines.Perform, 20)
    self.phase = GooningAnimationPhase.Entry
    self:setActionAnim(ISGoonAction:resolve_animation(self.character, GooningAnimationPhase.Entry))
end

function ISGoonAction:stop()
    ISBaseTimedAction.stop(self);
end

function ISGoonAction:perform()
    if self.requirement then
        local required_item = self.requirement(self.character)
        if not required_item then
            GoonerLines.RollDice(self.character, GoonerLines.LubricantFailure, 20)
            ISGoonAction.stop(self)
            return
        end
        self.character:getInventory():Remove(required_item)
    end

    if self.onComplete then
        self.onComplete(self.cycles)
    end
    ISBaseTimedAction.perform(self);
end

function ISGoonAction:update()
    local elapsed_time = self:getJobDelta() * self.maxTime
    local loop_start = self.entryDuration
    local loop_end = loop_start + self.loopDuration * self.cycles

    if elapsed_time < loop_start then
        if self.phase ~= GooningAnimationPhase.Entry then
            self.phase = GooningAnimationPhase.Entry
        end
    elseif elapsed_time >= loop_start and elapsed_time < loop_end then
        if self.phase ~= GooningAnimationPhase.Loop then
            self.phase = GooningAnimationPhase.Loop
        end
    else
        if self.phase ~= GooningAnimationPhase.Finish then
            self.phase = GooningAnimationPhase.Finish
        end
    end

    if getCore():getDebug() then
        print("[GA] MaxTime: " .. tostring(self.maxTime))
        print("[GA] Phase: " .. tostring(self.phase))
        print("[GA] Start: " .. tostring(loop_start) .. " End: " .. tostring(loop_end))
        print("[GA] Elapsed: " .. tostring(elapsed_time) .. " | " .. tostring(self.maxTime))
    end

    local anim = ISGoonAction:resolve_animation(self.character, self.phase)
    self:setActionAnim(anim)
end

function ISGoonAction:isValid()
    return instanceof(self.character, "IsoPlayer") and not self.character:isAsleep()
end

---@param local_player IsoPlayer
---@return boolean
function ISGoonAction:is_lowerbody_obstructed(local_player)
    local blockedLocations = {
        ItemBodyLocation.PANTS,
        ItemBodyLocation.PANTS_EXTRA,
        ItemBodyLocation.PANTS_SKINNY,
        ItemBodyLocation.SHORT_PANTS,
        ItemBodyLocation.SHORTS_SHORT,
        ItemBodyLocation.UNDERWEAR,
        ItemBodyLocation.UNDERWEAR_BOTTOM,
        ItemBodyLocation.DRESS,
        ItemBodyLocation.LONG_DRESS,
        ItemBodyLocation.LONG_SKIRT,
        ItemBodyLocation.SKIRT,
    }

    for _, location in ipairs(blockedLocations) do
        if local_player:getWornItem(location) ~= nil then
            return true
        end
    end

    return false
end

---@param local_player IsoPlayer
---@param phase GooningAnimationPhase
---@return string
function ISGoonAction:resolve_animation(local_player, phase)
    local gooning_animations = {
        Male = {
            Right = { Entry = "GMR_Entry", Loop = "GMR_Loop", Finish = "GMR_Finish" },
            Left = { Entry = "GML_Entry", Loop = "GML_Loop", Finish = "GML_Finish" }
        },
        Female = {
            Right = { Entry = "GFR_Entry", Loop = "GFR_Loop", Finish = "GFR_Finish" },
            Left = { Entry = "GFL_Entry", Loop = "GFL_Loop", Finish = "GFL_Finish" }
        }
    }

    local hand = "Left" ---@type GooningAnimationHand
    if TOC_Compat then
        if TOC_Compat.hasHand(local_player, false) then
            hand = "Right"
        elseif TOC_Compat.hasHand(local_player, true) then
            hand = "Left"
        end
    end

    local gender = tostring(local_player:getCharacterGender())
    return gooning_animations[gender][hand][phase]
end

---@param character IsoPlayer
---@param requirement? fun(player: IsoPlayer): InventoryItem
---@param on_complete fun(cycles: number)
---@return ISGooningAction
---@diagnostic disable-next-line
function ISGoonAction:new(character, requirement, on_complete)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.character = character
    o.stopOnWalk = true
    o.stopOnRun = true
    o.ignoreHandsWounds = false
    o.onComplete = on_complete
    o.requirement = requirement
    o.skipTOC = true

    o.phase = GooningAnimationPhase.Entry
    o.entryDuration = ANIMATION_ENTRY_FRAMES
    o.finishDuration = ANIMATION_FINISH_FRAMES
    o.loopDuration = ANIMATION_LOOP_FRAMES

    local cycles = GA_Math.CalcCycles(
        GoonerState:get_perk_level(character),
        GoonerState.Horniness:get(character),
        character:getPerkLevel(Perks.Fitness)
    )

    local total_frames = o.entryDuration + o.finishDuration + o.loopDuration * cycles
    o.cycles = cycles
    o.maxTime = total_frames
    return o
end
