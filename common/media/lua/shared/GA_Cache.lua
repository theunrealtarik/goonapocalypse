local GA_Cache = {}
GA_Cache.__index = GA_Cache

function GA_Cache.new()
    local self = setmetatable({}, GA_Cache)
    return self
end

function GA_Cache:get(key)
    return self[key]
end

function GA_Cache:set(key, value)
    self[key] = value
end

function GA_Cache:clear(key)
    self[key] = nil
end

function GA_Cache:on_change(key, value, callback)
    local prev_value = self:get(key)
    if prev_value ~= value then
        callback(prev_value, value)
    end

    self:set(key, value)
end

return GA_Cache
