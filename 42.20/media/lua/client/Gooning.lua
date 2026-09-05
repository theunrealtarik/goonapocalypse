local GA_Math = require("GA_Math")
local Catalog = require("GA_Catalog")
local GA_Cache = require("GA_Cache")

local TOC_Compat = require("TOC/API")
require("MF_ISMoodle")
MF.createMoodle(MoodleTag.Corny)
MF.createMoodle(MoodleTag.Relief)




Events.LevelPerk.Add(function(local_player, perk, level, increased)
    if Perks.Gooner:getName() ~= perk:getName() then
        return
    end


    print(perk:getName())
    local traits = local_player:getCharacterTraits()
    if increased and level >= GA_Globals.GOONER_TRAIT_LEVEL and not traits:get(GOONER_TRAIT) then
        traits:add(GOONER_TRAIT)
    end

    if not increased and level < GA_Globals.GOONER_TRAIT_LEVEL and traits:get(GOONER_TRAIT) then
        traits:remove(GOONER_TRAIT)
    end
end)

Events.OnFillInventoryObjectContextMenu.Add(function(player_num, context, ctx_items)
    local local_player = getSpecificPlayer(player_num)
    if not local_player then
        return
    end

    local g_lvl = GoonerState:get_perk_level(local_player)
    local stats = local_player:getStats()

    if GoonerState.Clarity:is_clear(local_player) then
        return
    end

    if TOC_Compat then
        if not TOC_Compat.hasHand(local_player, false) and not TOC_Compat.hasHand(local_player, true) then
            GoonerLines.RollDice(local_player, GoonerLines.Amputated, 50)
            return
        end
    end

    local inv_items = ISInventoryPane.getActualItems(ctx_items)
    for _, item in ipairs(inv_items) do
        -- sniffing
        local stimulus = assert(Catalog.Stimuli.get(Catalog.StimulusKind.SniffingPanties))
        if stimulus:is_valid_item(item:getFullType()) and GoonerState.Stimuli:can_use(local_player, stimulus.kind) then
            local underwear_condition = item:getCondition()
            local sniff_mult = GoonerState.Stimuli:get(local_player, stimulus.kind)

            local function on_complete_sniffing()
                GoonerState.Horniness:add(
                    local_player,
                    (stimulus.base_gain / 10) * underwear_condition
                    * GA_Math.CalcLevelMult(g_lvl, GA_Globals.STARTING_MULTIPLIER, GA_Globals.TARGET_MULTIPLIER)
                    * GA_Math.CalcPlayerCtxMult(local_player)
                    * sniff_mult)
                GoonerState.Stimuli:dec(local_player, stimulus.kind)
            end

            local sniff_action = ISSniffAction:new(local_player, on_complete_sniffing)
            stats:remove(CharacterStat.BOREDOM, 5 * sniff_mult)
            stats:set(
                CharacterStat.UNHAPPINESS,
                (underwear_condition * sniff_mult / 10) * CharacterStat.UNHAPPINESS:getMaximumValue()
            )

            context:addOption(
                getText("ContextMenu_action_Sniff"),
                player_num,
                function()
                    ISTimedActionQueue.add(sniff_action)
                end
            )
            break
        end

        -- gooning
        local lubricant = Catalog.Lubricants.get(item:getFullType())
        if lubricant and GoonerState.Horniness:get_level(local_player) >= 1 then
            local function on_complete_gooning(cycles)
                -- relief
                local use_delta = item:getUseDelta() - lubricant:consumption()
                item:setUseDelta(use_delta)
                if use_delta <= 0 then
                    item:Remove()
                end

                local horniness = GoonerState.Horniness:get(local_player)
                local relieved = (horniness * cycles)
                    * GA_Math.CalcLevelMult(g_lvl,
                        GA_Globals.RELIEF_MAX_DURATION / GA_Math.RELIEF_BASE_MIN,
                        GA_Globals.RELIEF_MIN_DURATION / GA_Math.RELIEF_BASE_MAX)

                GoonerState.Clarity:add(
                    local_player,
                    math.clamp(
                        relieved * (1 + lubricant.comf),
                        GA_Globals.RELIEF_MIN_DURATION,
                        GA_Globals.RELIEF_MAX_DURATION))

                GoonerState.Horniness:set(local_player, 0)

                local stat_value =
                    math.clamp(-1 * GoonerState:get_perk_level(local_player) / GA_Globals.PERK_LEVEL_MAX + 1, 0, 1)

                stats:remove(CharacterStat.UNHAPPINESS, stat_value)
                stats:remove(CharacterStat.BOREDOM, stat_value)
                stats:remove(CharacterStat.STRESS, stat_value)

                local cycles_ratio = cycles / GA_Math.CYCLES_MAX
                ---@param stat CharacterStat
                ---@param ratio number
                local function adjust_stat(stat, ratio)
                    stats:set(stat, ratio * stat:getMaximumValue())
                end

                adjust_stat(CharacterStat.ENDURANCE, cycles_ratio)
                if tostring(local_player:getCharacterGender()) == "Female" then
                    adjust_stat(CharacterStat.WETNESS, cycles_ratio)
                end

                local gooning_xp = GA_Globals.BASE_XP_GAIN
                    * GA_Math.CalcLevelMult(g_lvl, GA_Globals.STARTING_MULTIPLIER, GA_Globals.TARGET_MULTIPLIER)
                local_player:getXp():AddXP(Perks.Gooner, gooning_xp, true, false, false, true)
                GoonerLines.RollDice(local_player, GoonerLines.Relief, 20)
            end

            local gooning_action = ISGoonAction:new(
                local_player,

                lubricant.requirement,
                on_complete_gooning)
            context:addOption(
                getText("ContextMenu_action_Goon"),
                player_num,
                function()
                    if gooning_action:is_lowerbody_obstructed(local_player) then
                        GoonerLines.RollDice(local_player, GoonerLines.Pants, 100)
                    else
                        ISTimedActionQueue.add(gooning_action)
                    end
                end
            )
            break
        end
    end
end)

-- Events
local aw_cache = GA_Cache.new()

local function restore_aiming_weapon()
    local aiming_weapon = aw_cache:get("weapon")
    if aiming_weapon then
        aiming_weapon:setHitChance(aw_cache:get("base_hit_chance"))
        aw_cache:clear("weapon")
        aw_cache:clear("base_hit_chance")
    end
end

Events.OnPlayerUpdate.Add(function()
    local local_player = getPlayer()
    if not local_player then return end

    local stats = local_player:getStats()
    local dt = getGameTime():getGameWorldSecondsSinceLastUpdate()

    local g_lvl = GoonerState:get_perk_level(local_player)
    local h_val = GoonerState.Horniness:get(local_player)
    local h_lvl = GoonerState.Horniness:get_level(local_player)
    local r_dur = GoonerState.Clarity:get_duration(local_player)

    local omega = GA_Math.CalcOmegaMult(h_val, r_dur, g_lvl)


    ---@param multiplier number
    local function adjust_endurance(multiplier)
        local fitness_mult = 1.0 - 0.05 * local_player:getPerkLevel(Perks.Fitness)
        local endurance_delta = 0.0075 * multiplier * fitness_mult * dt
        stats:add(CharacterStat.ENDURANCE, endurance_delta)
        GoonerDebug.deltas.endurance = endurance_delta
    end

    if h_lvl >= 1 then
        local discomfort_delta = -1 * omega * 0.05 * dt
        local temp_delta = -1 * omega * (h_val / GA_Globals.MODIFIER_VALUE_MAX) * 0.08 * dt
        GoonerDebug.deltas.discomfort = discomfort_delta
        GoonerDebug.deltas.temperature = temp_delta
        stats:add(CharacterStat.DISCOMFORT, discomfort_delta)
        stats:add(CharacterStat.TEMPERATURE, temp_delta)

        local is_sprinting = local_player:isSprinting()
        local is_running = local_player:isRunning()

        -- drain endurance
        if is_running or is_sprinting then
            adjust_endurance(GA_Math.CalcGammaDebuff(h_val, g_lvl) * (is_sprinting and 1.0 or 0.5))
        end
    end

    if GoonerState.Clarity:is_clear(local_player) then
        -- recover endurance
        adjust_endurance(GA_Math.CalcPhiBuff(r_dur, g_lvl))
    end


    if h_lvl >= 1 or r_dur > 0 then
        local panic_delta = -1 * omega * 0.5 * dt
        stats:add(CharacterStat.PANIC, panic_delta)
        GoonerDebug.deltas.panic = panic_delta

        -- aiming
        if local_player:isAiming() then
            local equipped_weapon = local_player:getUseHandWeapon()
            if equipped_weapon and equipped_weapon:isAimedFirearm() then
                if aw_cache:get("weapon") ~= equipped_weapon then
                    restore_aiming_weapon()
                    aw_cache:set("weapon", equipped_weapon)
                    aw_cache:set("base_hit_chance", equipped_weapon:getHitChance())
                end

                local hit_base = aw_cache:get("base_hit_chance")
                local precision =
                    omega
                    * (25 - local_player:getPerkLevel(Perks.Aiming))
                    * GA_Math.CalcBezierInterp(g_lvl / GA_Globals.PERK_LEVEL_MAX, 1, 0, 0, 1)

                local adj_accuracy = math.max(0, hit_base + precision)
                equipped_weapon:setHitChance(adj_accuracy)
            else
                restore_aiming_weapon()
            end
        else
            restore_aiming_weapon()
        end
    else
        GoonerDebug.deltas.endurance = 0.0
        GoonerDebug.deltas.discomfort = 0.0
        GoonerDebug.deltas.temperature = 0.0
        GoonerDebug.deltas.panic = 0.0
        restore_aiming_weapon()
    end
end)


Events.EveryDays.Add(function()
    local local_player = getPlayer()
    if not local_player then
        return
    end

    local d_survived = math.floor(local_player:getHoursSurvived() / 24)
    local d_cycles = d_survived % GA_Globals.DEPRIVED_DAYS_PEAK
    if not GoonerState.Clarity:is_clear(local_player) and d_cycles < GA_Globals.DEPRIVED_DAYS_PEAK then
        local function dep_exp(d)
            return GA_Math.CalcDynExpInterp(d, 1,
                GA_Globals.DEPRIVED_DAYS_MODIFIER_PEAK + 1,
                GA_Globals.DEPRIVED_DAYS_PEAK) - 1
        end

        local dep_delta = dep_exp(d_cycles) - dep_exp(d_cycles - 1)
        GoonerState.Horniness:add(local_player, dep_delta)
    end
end)


Events.EveryTenMinutes.Add(function()
    local local_player = getPlayer()
    if not local_player then
        return
    end

    local g_lvl = GoonerState:get_perk_level(local_player)
    local h_val = GoonerState.Horniness:get(local_player)

    local traits = local_player:getCharacterTraits()
    if traits:get(GOONER_TRAIT) and not GoonerState.Clarity:is_clear(local_player) then
        GoonerState.Horniness:add(local_player, GA_Math.CalcRegainRate(DecayInterval.TenMinutes, g_lvl, h_val))
        return
    end

    -- GoonerState.Horniness:add(local_player, -GA_Math.CalcDecayRate(DecayInterval.TenMinutes, g_lvl, h_val))
end)

Events.EveryOneMinute.Add(function()
    local local_player = getPlayer()
    if not local_player then return end

    for kind, _ in pairs(Catalog.Stimuli.list()) do
        GoonerState.Stimuli:inc(local_player, kind)
    end

    local prev_clarity = GoonerState.Clarity:get_duration(local_player)
    if prev_clarity > 0 then
        local curr_clarity = GoonerState.Clarity:remove(local_player, 1 / 60)
        if math.ceil(curr_clarity) <= 0 then
            local stats = local_player:getStats()
            ---@param stat CharacterStat
            local function adjust_stat(stat)
                local value = stat:getMaximumValue() * 0.09 * GoonerState:get_perk_level(local_player) + 0.1
                stats:set(stat, value)
            end

            adjust_stat(CharacterStat.UNHAPPINESS)
            adjust_stat(CharacterStat.BOREDOM)
            adjust_stat(CharacterStat.STRESS)
        end
    end
end)

-- Sync moodels
local moodle_cache = GA_Cache.new()
Events.OnPlayerUpdate.Add(function(local_player)
    local player_num = local_player:getIndex()
    moodle_cache:on_change(
        GA_Globals.DATA_KEYS.HORNINESS,
        GoonerState.Horniness:get_level(local_player),
        function(_, curr)
            SetMoodle(
                MF,
                player_num,
                MoodleTag.Corny,
                MoodleNature.Bad,
                curr
            )
        end
    )

    local normalize_relief = function()
        local r_lvl = GoonerState.Clarity:get_duration_level(local_player)
        local r_dur = GoonerState.Clarity:get_duration(local_player)

        if r_lvl == 0 and r_dur > 0 then
            return 1
        end

        return r_lvl
    end

    moodle_cache:on_change(
        GA_Globals.DATA_KEYS.CLARITY,
        normalize_relief(),
        function(_, curr)
            SetMoodle(
                MF,
                player_num,
                MoodleTag.Relief,
                MoodleNature.Good,
                curr
            )
        end
    )
end)

-- Clean up
Events.OnPlayerDeath.Add(function(local_player)
    GoonerState:Reset(local_player)
end)
