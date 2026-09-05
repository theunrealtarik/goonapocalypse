---@generic Value
---@class DataAccessor<Value>
---@field key string
---@field default Value
local DataAccessor = {}
DataAccessor.__index = DataAccessor

---@generic Value
---@param key string
---@param default Value
---@return DataAccessor<Value>
function DataAccessor.new(key, default)
    local self = setmetatable({}, DataAccessor)

    self.key = key
    self.default = default

    return self
end

---@private
---@param player IsoPlayer
---@return table
function DataAccessor:_root(player)
    local mod_data = player:getModData()
    mod_data[GA_Globals.DATA_KEYS.ROOT] = mod_data[GA_Globals.DATA_KEYS.ROOT] or {}
    return mod_data[GA_Globals.DATA_KEYS.ROOT]
end

---@param player IsoPlayer
---@return Value
function DataAccessor:get(player)
    local root = self:_root(player)

    if root[self.key] == nil then
        root[self.key] = self.default
    end

    return root[self.key]
end

---@param player IsoPlayer
---@param value Value
function DataAccessor:set(player, value)
    local root = self:_root(player)
    root[self.key] = value
end

---@param player IsoPlayer
function DataAccessor:clear(player)
    local root = self:_root(player)
    root[self.key] = nil
end

---@param player IsoPlayer
function DataAccessor:reset(player)
    self:clear(player)
    self:set(player, self.default)
end

return DataAccessor
