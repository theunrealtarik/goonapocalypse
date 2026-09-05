---@class LineBank
---@field lines string[]
LineBank = {}
LineBank.__index = LineBank

---@param lines string[]
---@return LineBank
function LineBank.new(lines)
    local self = setmetatable({}, LineBank)
    self.lines = lines or {}
    return self
end

---@return string
function LineBank:get_random_line()
    if #self.lines == 0 then
        return ""
    end

    local index = ZombRand(#self.lines) + 1
    return self.lines[index]
end

GoonerLines = {}

---@param local_player IsoPlayer
---@param bank LineBank
---@param chance number
function GoonerLines.RollDice(local_player, bank, chance)
    if chance < 0 then
        error("chance must be non-negative")
    end

    if ZombRand(100) < chance then
        local_player:Say(bank:get_random_line())
    end
end

-- TODO: Translation :/

GoonerLines.Perform = LineBank.new({
    "Well, time to make another mistake",
    "Hehe. Here we go again.",
    "For fuck's sake, why not?",
    "Time to disappoint myself again",
    "Ah shit, here we go again",
    "Let's get this over with",
    "Ah shit, round two.",
    "I have absolutely no self-control",
    "Back to the old reliable",
    "What could possibly go wrong?",
    "Another day, another bad decision",
    "Fuck it. I'm already here",
    "This is probably healthy",
    "Surely this time it'll be different",
    "God, I'm pathetic.",
    "Alright, let's ruin the afternoon",
})

GoonerLines.Relief = LineBank.new({
    "Ahh... what a fucking waste of time",
    "Finally. It's over",
    "Why the fuck do I keep doing this?",
    "My hands fucking hurt",
    "There goes another hour of my life",
    "Fantastic. I've accomplished nothing",
    "Jesus Christ...",
    "Well, that was fucking pointless",
    "I need to get a life",
    "Same shit, different day",
    "I feel absolutely nothing",
    "Wonderful. Now I hate myself again",
    "That's enough degeneracy for today",
    "Cool. Back to being miserable",
    "What the fuck is wrong with me?",
    "Perhaps a walker next?",
})

GoonerLines.BookInterruption = LineBank.new({
    "I'm bored already!",
    "I'm pretending to be productive now",
    "Alright, where were we?",
    "I guess my reading session can be postponed",
    "Meh, I will finish it later",
    "Why am I reading this anyway?",
    "I can think about being a niche performative individual later on",
    "I'm supposed to be reading. So why can't I stop thinking about it?",
})

GoonerLines.LubricantFailure = LineBank.new({
    "I can't use this as a lub on its own",
    "I don't have anything I can use",
    "Unprepared as fucking usual",
    "Even bad decisions require good setup",
})

GoonerLines.Sniffing = LineBank.new({
    "Brain might be broken but at least the nose isn't",
    "Some panties on the face wouldn't hurt",
    "Just one more sniff",
})

GoonerLines.Amputated = LineBank.new({
    "Well, shit...",
    "Ugh, I didn't plan for this shit",
    "Ugh, two out of three are gone so...",
    "Ugh, guess I'll have to improvise somehow",
})


GoonerLines.Pants = LineBank.new({
    "Hah, pants on, why even",
    "Ugh, can't jerk with pants",
    "Hah, pants on, time to quit.",
    "Ugh, pants are in the way",
    "Hah, pants on, fuck it",
})
