ANIMATION_SNIFF_FRAMES = 120


---@class ISSniffAction : ISBaseTimedAction
---@field character IsoPlayer
---@field maxTime number
---@field onComplete fun()|nil
---@field stopOnWalk boolean
---@field stopOnRun boolean
---@field ignoreHandsWounds boolean
ISSniffAction = ISBaseTimedAction:derive("ISSniffAction")

function ISSniffAction:start()
    GoonerLines.RollDice(self.character, GoonerLines.Sniffing, 20)
    self:setActionAnim("Sniff")
end

function ISSniffAction:stop()
    ISBaseTimedAction.stop(self);
end

function ISSniffAction:perform()
    if self.onComplete then
        self.onComplete()
    end
    ISBaseTimedAction.perform(self);
end

function ISSniffAction:isValid()
    return instanceof(self.character, "IsoPlayer") and not self.character:isAsleep()
end

---@param character IsoPlayer
---@param on_complete fun()
---@return ISSniffAction
---@diagnostic disable-next-line
function ISSniffAction:new(character, on_complete)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.character = character
    o.stopOnWalk = true
    o.stopOnRun = true
    o.ignoreHandsWounds = false
    o.onComplete = on_complete

    o.maxTime = ANIMATION_SNIFF_FRAMES
    return o
end
