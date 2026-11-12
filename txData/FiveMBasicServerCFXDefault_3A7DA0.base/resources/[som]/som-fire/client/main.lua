--- Draws the flames the server says are burning, sends spray ticks and runs the
--- rescue progress bar. No fire logic lives here.

local core = exports['som-core']
local flames = {}
local busy = false

local function say(text, kind) TriggerEvent('som:client:notify', text, kind) end

local function apply(list)
    local seen = {}
    for _, inc in ipairs(list or {}) do
        for _, p in ipairs(inc.points) do
            seen[p.id] = true
            -- maxChildren 0: the game's own fire never spreads, the server decides that.
            if not flames[p.id] then flames[p.id] = { incident = inc.id, pos = vec3(p.x, p.y, p.z), handle = StartScriptFire(p.x, p.y, p.z, 0, false) } end
        end
    end
    for id, f in pairs(flames) do
        if not seen[id] then RemoveScriptFire(f.handle); flames[id] = nil end
    end
end

RegisterNetEvent('som-fire:client:sync', apply)

RegisterNetEvent('som-fire:client:moveTo', function(x, y, z)
    SetEntityCoords(cache.ped, x + 0.0, y + 0.0, z + 0.0, false, false, false, false)
end)

CreateThread(function()
    apply(lib.callback.await('som-fire:server:state', false))

    local lastTick = 0
    while true do
        if next(flames) == nil then
            Wait(1000)
        else
            Wait(250)
            local ped = cache.ped
            local spraying = IsPedShooting(ped) or (GetVehiclePedIsIn(ped, false) ~= 0 and IsControlPressed(0, 69))
            if spraying and GetGameTimer() - lastTick >= Config.sprayMinMs then
                local here, best, bestDist = GetEntityCoords(ped), nil, Config.sprayDistance
                for id, f in pairs(flames) do
                    local d = #(here - f.pos)
                    if d <= bestDist then best, bestDist = id, d end
                end
                if best then
                    lastTick = GetGameTimer()
                    local r = lib.callback.await('som-fire:server:douse', false, flames[best].incident, best)
                    if r and not r.success and r.error ~= 'too fast' then say(r.error, 'error') end
                end
            end
        end
    end
end)

local function rescue(ped)
    local index = NetworkGetPlayerIndexFromPed(ped)
    if index == -1 then return end
    local target = GetPlayerServerId(index)
    if target <= 0 then return end

    busy = true
    local began = lib.callback.await('som-fire:server:rescueBegin', false, target)
    if not began or not began.success then
        busy = false
        return say(began and began.error or 'Failed', 'error')
    end

    local ok = lib.progressBar({
        duration = began.seconds * 1000, label = 'Pulling them clear', canCancel = true,
        disable = { move = true, combat = true },
    })
    if not ok then
        busy = false
        return
    end

    local result = lib.callback.await('som-fire:server:rescueFinish', false, target)
    busy = false
    if result and not result.success then say(result.error or 'Failed', 'error') end
end

CreateThread(function()
    exports['som-interact']:addGlobalPlayer({
        {
            name = 'som_fire_rescue', label = 'Pull clear of the fire', icon = 'fa-solid fa-fire-extinguisher', distance = Config.rescue.distance,
            canInteract = function(entity)
                if busy or next(flames) == nil then return false end
                local job = core:getJob()
                if not job or job.name ~= Config.job or not job.onduty then return false end
                local index = NetworkGetPlayerIndexFromPed(entity)
                if index == -1 then return false end
                local down = Player(GetPlayerServerId(index)).state['som:downed']
                return down ~= nil and down ~= false
            end,
            onSelect = function(data)
                if data and data.entity then rescue(data.entity) end
            end,
        },
    })
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for _, f in pairs(flames) do RemoveScriptFire(f.handle) end
end)
