-- https://www.desmos.com/calculator/tdjfh0cuan


local GA_Math = {}

---@param mv number
---@return Duration, Duration
function GA_Math.GetDrainDuration(mv)
    if mv <= 25 then
        return 12, 40
    elseif mv <= 50 then
        return 20, 67
    elseif mv <= 75 then
        return 28, 96
    else
        return 36, 168
    end
end

---@param start_ord number
---@param target_ord number
function GA_Math.CalcGrowth(start_ord, target_ord, target_abs)
    return (target_ord / start_ord) ^ (1 / target_abs) - 1
end

---@param t number
---@param s number
---@param rate number
function GA_Math.CalcExpoInterp(t, s, rate)
    return s * (1 + rate) ^ t
end

---@param t number
---@param start_ord number
---@param target_ord number
---@param target_abs number
function GA_Math.CalcDynExpInterp(t, start_ord, target_ord, target_abs)
    local growth_rate = GA_Math.CalcGrowth(start_ord, target_ord, target_abs)
    return GA_Math.CalcExpoInterp(t, start_ord, growth_rate)
end

---@param m_lvl number
---@param i_mult number
---@param f_mult number
function GA_Math.CalcLevelMult(m_lvl, i_mult, f_mult)
    return GA_Math.CalcDynExpInterp(m_lvl, i_mult, f_mult, GA_Globals.PERK_LEVEL_MAX)
end

---@param t number
---@param p_init number
---@param c_0 number
---@param c_1 number
---@param p_final number
function GA_Math.CalcBezierInterp(t, p_init, c_0, c_1, p_final)
    if t < 0 or t > 1.0 then
        error("0 <= t <= 1.0")
    end

    return (1 - t) ^ 3 * p_init
        + (1 - t) ^ 2 * 3 * t * c_0
        + (1 - t) * t ^ 2 * 3 * c_1
        + t ^ 3 * p_final
end

---@param mv number
function GA_Math.CalcTimeBase(mv)
    return 0.32 * mv + 4
end

---@param amount number
---@param duration Duration
function GA_Math.CalcRate(amount, duration)
    return amount / duration
end

---@param ml number
---@param mv number
---@param sd number
---@param td number
---@return Duration
function GA_Math.CalcDecayTime(ml, mv, sd, td)
    return GA_Math.CalcTimeBase(mv) * GA_Math.CalcLevelMult(ml, 1.0, td / sd)
end

---@enum DecayInterval
DecayInterval = {
    Hour = 1,
    TenMinutes = 10 / 60,
    Minute = 1 / 60,
    Second = 1 / 3600,
}

--- Calculates the decay rate every hour (can be adjusted by the rate parameter)
---@param ml number
---@param mv number
---@param rate DecayInterval
function GA_Math.CalcDecayRate(rate, ml, mv)
    local di, df = GA_Math.GetDrainDuration(mv)
    local d_time = GA_Math.CalcDecayTime(ml, mv, di, df)

    return (mv / d_time) * rate
end

--- [0, 1]
---@param r number
---@param l number
---@return number
function GA_Math.CalcPhiBuff(r, l)
    r = math.clamp(r or 0, 0, GA_Globals.RELIEF_MAX_DURATION)
    l = math.clamp(l or 0, 0, GA_Globals.PERK_LEVEL_MAX)

    local k = 4
    local lambda = 0.00004

    local dip_term = lambda * l * ((GA_Globals.PERK_LEVEL_MAX - l) ^ k)
    local l_fac = l / GA_Globals.PERK_LEVEL_MAX
    local r_fac = r / GA_Globals.RELIEF_MAX_DURATION

    return r_fac * (1 - l_fac + dip_term)
end

--- [-1, 0]
---@param m number
---@param l number
---@return number
function GA_Math.CalcGammaDebuff(m, l)
    m = math.clamp(m or 0, 0, GA_Globals.MODIFIER_VALUE_MAX)
    l = math.clamp(l or 0, 0, GA_Globals.PERK_LEVEL_MAX)

    if m <= 0 or l <= 0 then
        return 0.0
    end

    local m_fac = (m / GA_Globals.MODIFIER_VALUE_MAX) ^ 2
    local l_fac = (l + math.log(l + 1, GA_Globals.PERK_LEVEL_MAX)) / GA_Globals.PERK_LEVEL_MAX
    return -1 * m_fac * l_fac
end

--- [-1, 1]
---@param m number
---@param r number
---@param l number
---@return number
function GA_Math.CalcOmegaMult(m, r, l)
    return GA_Math.CalcPhiBuff(r, l) + GA_Math.CalcGammaDebuff(m, l)
end

---@param m number
---@param r number
---@param l number
---@return number
function GA_Math.CalcActionTimeMult(m, r, l)
    local gamma_slope = -1.6
    local gamma_bezier = GA_Math.CalcBezierInterp(l / GA_Globals.PERK_LEVEL_MAX, 1.0, -0.45, 1.35, 1)
    local n_gamma =
        gamma_slope
        * (GA_Math.CalcGammaDebuff(m, l) * gamma_bezier)
        + (m / (4 * GA_Globals.MODIFIER_VALUE_MAX)) + 1

    local n_phi = -0.5 * GA_Math.CalcPhiBuff(r, l) + 1
    return n_phi * n_gamma
end

-- animation
---@param ml number
---@param mv number
---@param endur number
function GA_Math.CalcCycles(ml, mv, endur)
    if endur < 0 or endur > 10 then
        error("0 <= endur <= 10")
    end

    local c_num = 1.5 * (endur / GA_Globals.PERK_LEVEL_MAX) + (mv / GA_Globals.MODIFIER_VALUE_MAX)
    local c_den = ml ^ (1 / math.exp(1)) + 1
    return math.ceil(5 * (c_num / c_den))
end

---@param ml number
---@param mv number
---@param endur number
function GA_Math.CalcReliefBase(ml, mv, endur)
    return mv * GA_Math.CalcCycles(ml, mv, endur)
end

---@param ml number
---@param mv number
---@param cycles number
---@param start_dur number
---@param target_dur number
---@param br_0 number
---@param br_1 number
function GA_Math.CalcRelief(ml, mv, cycles, start_dur, target_dur, br_0, br_1)
    local rb = mv * cycles
    return math.floor((rb
        * GA_Math.CalcLevelMult(ml, start_dur / GA_Math.RELIEF_BASE_MIN, target_dur / GA_Math.RELIEF_BASE_MAX)
        * GA_Math.CalcBezierInterp(ml / GA_Globals.PERK_LEVEL_MAX, 1.0, br_0, br_1, 1.0)) + 0.5)
end

function GA_Math.CalcPlayerCtxMult(local_player)
    local modifier = 0

    if not local_player:isOutside() then
        modifier = modifier + 0.05
    end

    local worn_items = local_player:getWornItems()
    local is_naked =
        worn_items:getItem(ItemBodyLocation.FULL_TOP) == nil and
        worn_items:getItem(ItemBodyLocation.FULL_BOTTOM) == nil and
        worn_items:getItem(ItemBodyLocation.SHIRT) == nil and
        worn_items:getItem(ItemBodyLocation.SHOES) == nil

    if is_naked then
        modifier = modifier + 0.05
    end

    return 1 + modifier
end

---@param value number
---@param min number
---@param max number
---@param levels number
---@return number
function GA_Math.GetLevel(value, min, max, levels)
    local step = (max - min) / levels
    local clamped = math.clamp(value, min, max)
    local normalized = clamped - min
    return math.floor((normalized / step) + 0.5)
end

---@param ml number
function GA_Math.CalcDeprivedPeakDay(ml)
    return GA_Globals.DEPRIVED_DAYS_PEAK - 1.1 * ml
end

GA_Math.CYCLES_MAX = GA_Math.CalcCycles(GA_Globals.PERK_LEVEL_MIN, GA_Globals.MODIFIER_VALUE_MAX,
    GA_Globals.PERK_LEVEL_MAX)
GA_Math.RELIEF_BASE_MIN =
    GA_Math.CalcReliefBase(GA_Globals.PERK_LEVEL_MIN, GA_Globals.MODIFIER_VALUE_MAX, GA_Globals.PERK_LEVEL_MAX)
GA_Math.RELIEF_BASE_MAX =
    GA_Math.CalcReliefBase(GA_Globals.PERK_LEVEL_MAX, GA_Globals.MODIFIER_VALUE_MAX, GA_Globals.PERK_LEVEL_MAX)
GA_Math.ANIMATION_MAX_CYCLES = GA_Math.CalcCycles(0, 100, 10)

return GA_Math
