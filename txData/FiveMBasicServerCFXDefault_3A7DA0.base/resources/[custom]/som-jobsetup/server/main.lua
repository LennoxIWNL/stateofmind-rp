local QBCore = exports['qb-core']:GetCoreObject()

-- ---------------------------------------------------------------------------
--  Points database (persisted to data/points.json in this resource)
-- ---------------------------------------------------------------------------
local POINTS_FILE = 'data/points.json'
local points = {}        -- id -> point
local nextId = 1

local function loadPoints()
    local raw = LoadResourceFile(GetCurrentResourceName(), POINTS_FILE)
    if raw and raw ~= '' then
        local ok, data = pcall(json.decode, raw)
        if ok and type(data) == 'table' then
            for _, p in pairs(data) do
                points[p.id] = p
                if p.id >= nextId then nextId = p.id + 1 end
            end
        end
    end
end

local function savePoints()
    local list = {}
    for _, p in pairs(points) do list[#list + 1] = p end
    SaveResourceFile(GetCurrentResourceName(), POINTS_FILE,
        json.encode(list, { indent = true }), -1)
end

local function listPoints()
    local list = {}
    for _, p in pairs(points) do list[#list + 1] = p end
    return list
end

-- ---------------------------------------------------------------------------
--  Permission
-- ---------------------------------------------------------------------------
local function isAllowed(src)
    return IsPlayerAceAllowed(src, Config.AdminAce) or IsPlayerAceAllowed(src, 'command')
end

-- ---------------------------------------------------------------------------
--  Sync
-- ---------------------------------------------------------------------------
local function syncAll()
    TriggerClientEvent('som-jobsetup:client:sync', -1, listPoints())
end

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    loadPoints()
end)

RegisterNetEvent('som-jobsetup:server:requestSync', function()
    TriggerClientEvent('som-jobsetup:client:sync', source, listPoints())
end)

-- ---------------------------------------------------------------------------
--  Create / update / delete (all admin-gated)
-- ---------------------------------------------------------------------------
RegisterNetEvent('som-jobsetup:server:save', function(point)
    local src = source
    if not isAllowed(src) then return end
    if type(point) ~= 'table' then return end
    if type(point.coords) ~= 'table' or not tonumber(point.coords.x) or not tonumber(point.coords.y) or not tonumber(point.coords.z) then return end
    if point.label and type(point.label) ~= 'string' then return end
    if point.type and not Config.Types[point.type] then return end

    if not point.id or not points[point.id] then
        point.id = nextId
        nextId = nextId + 1
    end
    points[point.id] = point
    savePoints()
    syncAll()
    TriggerClientEvent('ox_lib:notify', src,
        { title = 'Job Setup', description = ('Saved "%s"'):format(point.label or point.type), type = 'success' })
end)

RegisterNetEvent('som-jobsetup:server:delete', function(id)
    local src = source
    if not isAllowed(src) then return end
    if points[id] then
        local label = points[id].label or points[id].type
        points[id] = nil
        savePoints()
        syncAll()
        TriggerClientEvent('ox_lib:notify', src,
            { title = 'Job Setup', description = ('Deleted "%s"'):format(label), type = 'inform' })
    end
end)

-- ---------------------------------------------------------------------------
--  Export the whole DB as a paste-able snippet (printed to the player's console)
-- ---------------------------------------------------------------------------
RegisterNetEvent('som-jobsetup:server:export', function()
    local src = source
    if not isAllowed(src) then return end
    local raw = LoadResourceFile(GetCurrentResourceName(), POINTS_FILE) or '[]'
    TriggerClientEvent('som-jobsetup:client:export', src, raw)
end)

