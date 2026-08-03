-- Lazily-built members of QBCore.Shared.
--
-- Items, Weapons and Vehicles are all projected from somewhere else rather than
-- hand-maintained, and none of them can be built at file scope: ox_inventory
-- may not have started yet, and the vehicle label natives need the game to be
-- up. So each is registered here with a builder and produced on first read.
--
-- One registry rather than a metatable per member, because setmetatable
-- REPLACES the metatable. Two files each calling it on QBCore.Shared would mean
-- whichever ran last silently won and the other member returned nil.

SomCompatLazy = {}

-- Keyed by the table being extended, so a provider registered for the client's
-- QBCore.Shared cannot leak into the server's.
local registries = setmetatable({}, { __mode = 'k' })

---@param target table
---@return table providers, table cache
local function registryFor(target)
    local reg = registries[target]
    if reg then return reg.providers, reg.cache end

    reg = { providers = {}, cache = {} }
    registries[target] = reg

    setmetatable(target, {
        __index = function(_, key)
            local provider = reg.providers[key]
            if not provider then return nil end

            local cached = reg.cache[key]
            if cached ~= nil then return cached end

            -- A builder returns nil when its source is not ready yet. That is
            -- not cached, so the next read tries again rather than pinning
            -- every future caller to an empty result.
            local built = provider.build()
            if built == nil then return provider.default end

            reg.cache[key] = built
            return built
        end,
    })

    return reg.providers, reg.cache
end

---Registers a lazily-built member.
---
---The member must NOT already exist on the table: __index only fires for keys
---the table does not have, so a placeholder would shadow this permanently.
---@param target table usually QBCore.Shared
---@param key string
---@param build function returns the value, or nil if its source is not ready
---@param default any returned while build() keeps answering nil
function SomCompatLazy.provide(target, key, build, default)
    local providers = registryFor(target)
    providers[key] = { build = build, default = default }

    if rawget(target, key) ~= nil then
        -- Loud on purpose: this silently disables the provider, and the symptom
        -- (an empty table, far away, much later) gives no hint of the cause.
        print(('[som-compat] Shared.%s is set on the table, so its lazy provider will never run'):format(key))
    end
end
