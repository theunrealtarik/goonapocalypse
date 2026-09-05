---@class Lubricant
---@field cons number
---@field comf number
---@field requirement? fun(player: IsoPlayer): InventoryItem?
local Lubricant = {}
Lubricant.__index = Lubricant

---@param cons number
---@param comf number
---@param requirement? fun(player: IsoPlayer): InventoryItem
---@return Lubricant
function Lubricant:new(cons, comf, requirement)
    local instance = setmetatable({}, self) ---@type Lubricant
    instance.cons = math.max(0, math.min(100, cons))
    instance.comf = comf
    instance.requirement = requirement
    return instance
end

function Lubricant:consumption()
    return self.cons / 100
end

---@enum StimulusKind
local StimulusKind = {
    ReadingHottieZ = "ReadingHottieZ",
    SniffingPanties = "SniffingPanties",
}

---@class Stimulus
---@field kind StimulusKind
---@field base_gain number
---@field dec_delta number
---@field rec_delta number
---@field private valid_items_set table<string, boolean>
local Stimulus = {}
Stimulus.__index = Stimulus

---@param kind StimulusKind
---@param base_gain number
---@param dec_delta number
---@param rec_delta number
---@param valid_items string[]
---@return Stimulus
function Stimulus:new(kind, base_gain, dec_delta, rec_delta, valid_items)
    local valid_items_set = {}
    for _, item in ipairs(valid_items) do
        valid_items_set[item] = true
    end

    return setmetatable({
        kind = kind,
        base_gain = base_gain,
        dec_delta = dec_delta,
        rec_delta = rec_delta,
        valid_items_set = valid_items_set,
    }, self)
end

function Stimulus:is_valid_item(item_type)
    return self.valid_items_set[item_type] ~= nil
end

local Catalog = {
    StimulusKind = StimulusKind,
}

local lubricant_definitions = {
    ["Base.SpecialLubricant"] = Lubricant:new(5, 0.2),
    ["Base.OilOlive"] = Lubricant:new(10, 0.05),
    ["Base.OilVegetable"] = Lubricant:new(20, 0.01),
    ["Base.SesameOil"] = Lubricant:new(20, 0.005),
    ["Base.WaterBottle"] = Lubricant:new(100, -0.1),
    ["Base.Soap2"] = Lubricant:new(15, -0.1, function(local_player)
        return local_player:getInventory():getFirstType("Base.WaterBottle")
    end),
}

Catalog.Lubricants = {}

---@param item_type string
---@return Lubricant?
function Catalog.Lubricants.get(item_type)
    return lubricant_definitions[item_type]
end

local stimulus_definitions = {
    -- magazines
    [StimulusKind.ReadingHottieZ] = Stimulus:new(
        StimulusKind.ReadingHottieZ, 20, 0.1, 0.1,
        { "Base.HottieZ", "Base.HottieZ_New" }
    ),
    -- panties
    [StimulusKind.SniffingPanties] = Stimulus:new(
        StimulusKind.SniffingPanties, 5, 0.2, 0.1,
        {
            "Base.Bra_Straps_White",
            "Base.Bra_Straps_Black",
            "Base.Bra_Straps_FrillyRed",
            "Base.Bra_Straps_AnimalPrint",
            "Base.Bra_Straps_FrillyBlack",
            "Base.Bra_Straps_FrillyPink",
            "Base.Bra_Straps_Hide",

            "Base.Bra_Strapless_RedSpots",
            "Base.Bra_Strapless_FrillyBlack",
            "Base.Bra_Strapless_Black",
            "Base.Bra_Strapless_AnimalPrint",
            "Base.Bra_Strapless_FrillyRed",
            "Base.Bra_Strapless_White",
            "Base.Bra_Strapless_FrillyPink",
            "Base.Bra_Strapless_Hide",

            "Base.Underpants_White",
            "Base.FrillyUnderpants_Pink",
            "Base.Underpants_RedSpots",
            "Base.FrillyUnderpants_Red",
            "Base.Underpants_Black",
            "Base.Underpants_AnimalPrint",
            "Base.FrillyUnderpants_Black",
            "Base.Underpants_Hide",
        })
}

Catalog.Stimuli = {}

---@param kind StimulusKind
---@return Stimulus
function Catalog.Stimuli.get(kind)
    return assert(stimulus_definitions[kind], "Unknown stimulus: " .. tostring(kind))
end

---@param kind StimulusKind
---@return boolean
function Catalog.Stimuli.is_valid(kind)
    return stimulus_definitions[kind] ~= nil
end

---@return table<StimulusKind, Stimulus>
function Catalog.Stimuli.list()
    return stimulus_definitions
end

return Catalog
