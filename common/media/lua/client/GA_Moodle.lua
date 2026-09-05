---@enum MoodleTag
MoodleTag = {
    Corny = "CornyMoodle",
    Relief = "ReliefMoodle",
}

---@enum MoodleNature
MoodleNature = {
    Good = 1,
    Bad = -1
}

---@enum MoodleLevel
MoodleLevel = {
    One = 1,
    Two = 2,
    Three = 3,
    Four = 4
}

---@param nature MoodleNature
---@param level MoodleLevel
---@return number
function ResolveMoodle(nature, level)
    return nature * level / 10 + 1 / 2
end

---@param tag MoodleTag
---@param playerNum number?
function DisableMoodle(MF, tag, playerNum)
    local moodle = MF.getMoodle(tag, playerNum)
    if moodle then
        moodle:setValue(0.5)
    end
end

---@param MF any
---@param player_num number?
---@param tag MoodleTag
---@param nature MoodleNature
---@param level MoodleLevel
function SetMoodle(MF, player_num, tag, nature, level)
    local moodle = MF.getMoodle(tag, player_num)
    if moodle then
        moodle:setValue(ResolveMoodle(nature, level))
    end
end

---@param cache table<number, table<string, number>>
---@param player_num number
---@param key string
---@param current number
---@param callback fun(prev: number, curr: number)
function UpdateMoodle(cache, player_num, key, current, callback)
    if not cache[player_num] then
        cache[player_num] = {}
    end

    local prev_modifier_lvl = cache[player_num][key]
    if prev_modifier_lvl and prev_modifier_lvl ~= current then
        return
    end

    callback(prev_modifier_lvl, current)
end
