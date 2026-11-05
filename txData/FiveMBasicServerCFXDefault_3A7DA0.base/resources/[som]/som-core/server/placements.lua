--- Staff placed positions for content that ships disabled (heist sites, turf
--- zones, labs, spots, buyers, the supplier, drop-offs, the roadside desk). A row
--- in som_placements overrides one value in a resource's Config, by path, when
--- that resource starts: `zones.grove.tag`, `buyers.fish.coords`, `enabled`,
--- `radius`. A path walks lists by entry `name` (or `id`) and maps by key; a trailing `+`
--- appends a point to a list. Placing a point also switches the entry on.
--- Made by Lennox.

SomPlacements = {}

local ALLOWED = { center = true, coords = true, terminal = true, tag = true, radius = true, enabled = true }

local function child(container, key)
    if type(container) ~= 'table' then return nil end
    if container[key] ~= nil then return container, key end
    for i, entry in ipairs(container) do
        if type(entry) == 'table' and (entry.name == key or entry.id == key) then return container, i end
    end
end

---Applies one stored value to a config table. Returns true when the path existed.
---@param config table
---@param path string
---@param value any
function SomPlacements.ApplyOne(config, path, value)
    local parts = {}
    for part in tostring(path):gmatch('[^.]+') do parts[#parts + 1] = part end
    if #parts == 0 then return false end

    local appendTo = parts[#parts]:match('^(.-)%+$')
    if appendTo then parts[#parts] = appendTo end

    local node = config
    for i = 1, #parts - 1 do
        local container, key = child(node, parts[i])
        if not container then return false end
        node = container[key]
    end
    if type(node) ~= 'table' then return false end

    local field = parts[#parts]
    if appendTo then
        if type(node[field]) ~= 'table' then node[field] = {} end
        node[field][#node[field] + 1] = value
        return true
    end

    if not ALLOWED[field] then return false end
    node[field] = value

    -- A placed point turns its entry on (and marks a launder front as set).
    if type(value) == 'table' or type(value) == 'userdata' then
        if node.enabled == false then node.enabled = true end
        if node.set == false then node.set = true end
    end
    return true
end

local function decode(kind, raw)
    local ok, data = pcall(json.decode, raw)
    if not ok then return nil end
    if kind == 'point' and type(data) == 'table' and data.x and data.y and data.z then return vec3(data.x + 0.0, data.y + 0.0, data.z + 0.0) end
    if kind == 'number' and type(data) == 'number' then return data end
    if kind == 'bool' and type(data) == 'boolean' then return data end
end

---Applies every stored row for a resource. Returns how many applied and the missing paths.
function SomPlacements.Apply(config, resource)
    resource = resource or GetCurrentResourceName()
    local rows = MySQL.query.await('SELECT path, kind, value FROM som_placements WHERE resource = ? ORDER BY id', { resource }) or {}
    local applied, missing = 0, {}
    for _, r in ipairs(rows) do
        local value = decode(r.kind, r.value)
        if value ~= nil and SomPlacements.ApplyOne(config, r.path, value) then applied = applied + 1
        else missing[#missing + 1] = r.path end
    end
    if applied > 0 then print(('[som-placements] %s: applied %d placements'):format(resource, applied)) end
    if #missing > 0 then print(('[som-placements] %s: no such place for %s'):format(resource, table.concat(missing, ', '))) end
    return applied, missing
end
