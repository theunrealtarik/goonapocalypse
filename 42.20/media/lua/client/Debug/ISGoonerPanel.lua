-- i hate writing ui code, claude got this shit for me
local GA_Math = require("GA_Math")
local Catalog = require("GA_Catalog")

require "ISUI/ISPanel"
require "ISUI/ISTickBox"

local COLOR_BUFF = { r = 0.3, g = 1, b = 0.3 }
local COLOR_DEBUFF = { r = 1, g = 0.3, b = 0.3 }
local COLOR_PASSIVE = { r = 1, g = 1, b = 1 }

GoonerDebug = {
    deltas = {
        endurance = 0.0,
        discomfort = 0.0,
        temperature = 0.0,
        panic = 0.0,
    }
}

function GoonerDebug:reset()
    for k, _ in pairs(self.deltas) do
        self.deltas[k] = 0.0
    end
end

---@class Section
---@field panel ISPanel
---@field title string
---@field body_fn fun(sec: Section)
---@field line_height number
Section = {}
Section.__index = Section

---@param panel ISPanel
---@param title string
---@param body_fn fun(sec: Section)
function Section:new(panel, title, body_fn)
    return setmetatable({
        panel = panel,
        title = title,
        body_fn = body_fn,
        line_height = 16
    }, self)
end

function Section:text(str, r, g, b, a, font)
    font = font or UIFont.Small
    self.panel:drawText(str, self.x, self.y, r, g, b, a, font)
    self.y = self.y + self.line_height
end

function Section:coloredText(str, color, a, font)
    self:text(str, color.r, color.g, color.b, a or 1, font)
end

function Section:bar(width, height, value, max_value, variant)
    local bar_x = self.x
    self.panel:drawRect(bar_x, self.y, width, height, 0.6, 0.1, 0.1, 0.1)

    local frac = max_value > 0 and math.min(1.0, value / max_value) or 0.0
    local fill_w = math.floor(frac * width)

    local a, r, g, b
    if variant == "buff" then
        a, r, g, b = 0.9, 0.1, 0.3 + (0.7 * frac), 0.15
    else
        a, r, g, b = 0.9, math.min(1.0, frac * 1.5), math.max(0.0, 1.0 - frac), 0.1
    end

    self.panel:drawRect(bar_x, self.y, fill_w, height, a, r, g, b)
    self.panel:drawRectBorder(bar_x, self.y, width, height, 0.8, 0.4, 0.4, 0.4)

    self.y = self.y + height + 6
end

function Section:spacer(h)
    self.y = self.y + (h or 5)
end

function Section:body()
    if self.body_fn then
        self.body_fn(self)
    end
end

function Section:render(x, y, width)
    self.x = x
    self.y = y
    self.width = width

    self:coloredText(self.title, COLOR_PASSIVE, 0.8)
    self:body()

    self.height = self.y - y
    return self.height
end

---@class GooningDebugPanel : ISPanel
GooningDebugPanel = ISPanel:derive("GooningDebugPanel")

function GooningDebugPanel:initialise()
    ISPanel.initialise(self)

    -- Active Toggle TickBox
    self.active_tick_box = ISTickBox:new(
        self.width - 25, 2, 18, 18,
        "", self, self.onToggleActive
    )
    self.active_tick_box:initialise()
    local opt_idx = self.active_tick_box:addOption("")
    self.active_tick_box:setSelected(opt_idx, self.is_active)
    self:addChild(self.active_tick_box)
end

function GooningDebugPanel:onToggleActive(index, selected)
    self.is_active = selected
end

function GooningDebugPanel:prerender()
    ISPanel.prerender(self)
    self:drawRect(0, 0, self.width, 20, 0.4, 0.2, 0.2, 0.2)
end

---@param local_player IsoPlayer
---@return Section[]
function GooningDebugPanel:build_sections(local_player)
    local sections = {}

    -- Gather all the GoonerState/calc values used by the sections below.
    local g_lvl = GoonerState:get_perk_level(local_player)
    local h_val = GoonerState.Horniness:get(local_player)
    local horniness_lvl = GoonerState.Horniness:get_level(local_player)

    local c_duration = GoonerState.Clarity:get_duration(local_player)
    local c_overflow = GoonerState.Clarity:get_overflow(local_player)
    local has_trait = local_player:getCharacterTraits():get(GOONER_TRAIT)

    local decay_rate = GA_Math.CalcDecayRate(DecayInterval.TenMinutes, g_lvl, h_val) or 0

    local phi = GA_Math.CalcPhiBuff(c_duration, g_lvl)
    local gamma = GA_Math.CalcGammaDebuff(h_val, g_lvl)
    local final_mult = GA_Math.CalcOmegaMult(h_val, c_duration, g_lvl)

    local survived_days = math.floor(local_player:getHoursSurvived() / 24)
    local build_up_max_day = GA_Math.CalcDeprivedPeakDay(g_lvl)
    local build_up_days = survived_days % build_up_max_day

    local anim_potential_cycles = GA_Math.CalcCycles(
        GoonerState:get_perk_level(local_player),
        GoonerState.Horniness:get(local_player),
        local_player:getPerkLevel(Perks.Fitness))
    local anim_maximum_cycles = GA_Math.ANIMATION_MAX_CYCLES

    table.insert(sections, Section:new(self, "Trait & Perk Info", function(sec)
        local trait_text = has_trait and "ACTIVE" or "INACTIVE"
        local trait_color = has_trait and COLOR_DEBUFF or COLOR_BUFF
        sec:coloredText(string.format("Trait Status: %s", trait_text), trait_color)

        sec:coloredText(string.format("Perk Level (l): %d", g_lvl), COLOR_PASSIVE)
        sec:coloredText(string.format("Horniness (m): %.1f / 100 (Lvl %d)", h_val, horniness_lvl), COLOR_PASSIVE)
        sec:coloredText(string.format("Build up days: %d / %d", build_up_days, build_up_max_day), COLOR_PASSIVE)

        sec:bar(sec.width, 10, h_val, 100, "horniness")
    end))

    table.insert(sections, Section:new(self, "Clarity Pool", function(sec)
        sec:coloredText(string.format("Duration: %.1f / %.1f hr", c_duration, GA_Globals.RELIEF_MAX_DURATION),
            COLOR_PASSIVE)
        sec:coloredText(string.format("Overflow: %.1f", c_overflow), COLOR_PASSIVE)

        sec:bar(sec.width, 10, c_duration, GA_Globals.RELIEF_MAX_DURATION, "buff")
    end))

    table.insert(sections, Section:new(self, "Rates", function(sec)
        sec:coloredText(string.format("Decay (-10m): -%.2f", decay_rate), COLOR_BUFF)
    end))

    -- Multipliers
    table.insert(sections, Section:new(self, "Multipliers", function(sec)
        sec:coloredText(string.format(" - Phi (Buff): %.3f", phi), COLOR_BUFF)
        sec:coloredText(string.format(" - Gamma (Debuff): %.3f", gamma), COLOR_DEBUFF)

        local final_color = COLOR_PASSIVE
        if final_mult < 0.0 then
            final_color = COLOR_DEBUFF
        elseif final_mult > 0.0 then
            final_color = COLOR_BUFF
        end
        sec:coloredText(string.format(" - Omega: %.3fx", final_mult), final_color)
    end))

    if Catalog.StimulusKind then
        table.insert(sections, Section:new(self, "Stimuli Mults", function(sec)
            for kind_name, kind_val in pairs(Catalog.StimulusKind) do
                local mult = GoonerState.Stimuli:get(local_player, kind_val)
                sec:coloredText(string.format(" - %s: %.2f", tostring(kind_name), mult), COLOR_PASSIVE)
            end
        end))
    end

    table.insert(sections, Section:new(self, "Animation", function(sec)
        sec:coloredText(string.format(" - Potential cycles: %d", anim_potential_cycles), COLOR_PASSIVE)
        sec:coloredText(string.format(" - Maximum cycles: %d", anim_maximum_cycles), COLOR_PASSIVE)
    end))


    table.insert(sections, Section:new(self, "Deltas", function(sec)
        local d = GoonerDebug and GoonerDebug.deltas or {}

        local end_val = d.endurance or 0.0
        local end_color = end_val > 0 and COLOR_BUFF or COLOR_PASSIVE
        sec:coloredText(string.format(" - Endurance: %+.4f /s", end_val), end_color)

        local disc_val = d.discomfort or 0.0
        local disc_color = disc_val > 0 and COLOR_DEBUFF or COLOR_PASSIVE
        sec:coloredText(string.format(" - Discomfort: %+.4f /s", disc_val), disc_color)

        local temp_val = d.temperature or 0.0
        local temp_color = temp_val > 0 and COLOR_DEBUFF or COLOR_PASSIVE
        sec:coloredText(string.format(" - Temperature: %+.4f /s", temp_val), temp_color)

        local panic_val = d.panic or 0.0
        local panic_color = panic_val < 0 and COLOR_BUFF or (panic_val > 0 and COLOR_DEBUFF or COLOR_PASSIVE)
        sec:coloredText(string.format(" - Panic Delta: %+.2f /s", panic_val), panic_color)

        local equipped_weapon = local_player:getUseHandWeapon()
        if equipped_weapon and equipped_weapon:isAimedFirearm() then
            local hit_val = equipped_weapon:getHitChance()
            local hit_color = hit_val > 0 and COLOR_BUFF or (hit_val < 0 and COLOR_DEBUFF or COLOR_PASSIVE)
            sec:coloredText(string.format(" - Hit Chance: %d", hit_val), hit_color)
        end
    end))

    return sections
end

function GooningDebugPanel:render()
    ISPanel.render(self)

    local status_color = self.is_active and { r = 0.4, g = 1, b = 0.4 } or { r = 0.6, g = 0.6, b = 0.6 }
    self:drawText("GOONER STATE DEBUG", 8, 3, status_color.r, status_color.g, status_color.b, 1, UIFont.Small)

    if not self.is_active then
        self:setHeight(20)
        return
    end

    local local_player = getSpecificPlayer(0)
    if not local_player then return end

    local sections = self:build_sections(local_player)

    local section_gap = 12
    local y_pos = 25
    for _, section in ipairs(sections) do
        local h = section:render(10, y_pos, self.width - 20)
        y_pos = y_pos + h + section_gap
    end

    self:setHeight(y_pos + 5)
end

function GooningDebugPanel:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.85 }
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    o.moveWithMouse = true
    o.is_active = true

    return o
end

function GooningDebugPanel.create()
    if not getCore():getDebug() then
        return
    end

    local width = 250
    local height = 290
    local debug_panel = GooningDebugPanel:new(0, 0, width, height)
    debug_panel:initialise()
    debug_panel:addToUIManager()

    return debug_panel
end

Events.OnGameStart.Add(function()
    GooningDebugPanel.create()
end)
