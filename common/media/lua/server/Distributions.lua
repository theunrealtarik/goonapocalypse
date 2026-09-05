---@param item_type string
---@param loc string
---@param chance number
local function SetDistro(item_type, loc, chance)
    table.insert(ProceduralDistributions.list[loc].items, item_type)
    table.insert(ProceduralDistributions.list[loc].items, chance)
end


local function GADistributionMerge()
    SetDistro("SpecialLubricant", "BathroomCounter", 1)
    SetDistro("SpecialLubricant", "SafehouseMedical", 10)
    SetDistro("SpecialLubricant", "SafehouseMedical_Mid", 5)
    SetDistro("SpecialLubricant", "PharmacyCosmetics", 2)
end

Events.OnPreDistributionMerge.Add(GADistributionMerge)
