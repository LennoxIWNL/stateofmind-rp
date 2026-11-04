--- Finding and collecting traces, and the verbs on a person. The client only
--- shows what the server returns and asks for an id to be collected.

local zones = {}

local function clear()
    for _, id in ipairs(zones) do exports['som-interact']:removeZone(id) end
    zones = {}
end

local function collect(trace)
    local ok = lib.progressBar({ duration = 3000, label = 'Collecting', canCancel = true,
        disable = { move = true, car = true, combat = true } })
    if not ok then return end

    local res = lib.callback.await('som-evidence:server:collect', false, trace.id)
    TriggerEvent('som:client:notify', res and (res.success and 'Bagged' or res.error) or 'Request failed',
        res and res.success and 'success' or 'error')
end

local function scan()
    local res = lib.callback.await('som-evidence:server:scan', false)
    if not res or not res.success then
        return TriggerEvent('som:client:notify', res and res.error or 'Request failed', 'error')
    end

    clear()

    for _, trace in ipairs(res.evidence) do
        zones[#zones + 1] = exports['som-interact']:addSphereZone({
            name = 'evidence:' .. trace.id,
            coords = vec3(trace.x, trace.y, trace.z),
            radius = Config.Collect.range,
            options = {
                {
                    name = 'evidence:' .. trace.id,
                    icon = 'fa-solid fa-magnifying-glass',
                    label = ('Collect: %s'):format(trace.label),
                    distance = Config.Collect.range,
                    onSelect = function() collect(trace) end,
                },
            },
        })
    end

    TriggerEvent('som:client:notify', ('%d traces nearby'):format(#res.evidence), 'inform')
    SetTimeout(Config.Scan.show, clear)
end

RegisterCommand('scene', scan, false)

local function serverIdOf(entity)
    local player = NetworkGetPlayerIndexFromPed(entity)
    if not player or player == -1 then return nil end
    return GetPlayerServerId(player)
end

local function onPerson(label, icon, run)
    return {
        name = 'evidence:' .. label,
        icon = icon,
        label = label,
        distance = 3.0,
        onSelect = function(data)
            local target = serverIdOf(data.entity)
            if target then run(target) end
        end,
    }
end

local function sample(kind)
    return function(target)
        local res = lib.callback.await('som-evidence:server:sample', false, target, kind)
        TriggerEvent('som:client:notify', res and (res.success and 'Sample bagged' or res.error) or 'Request failed',
            res and res.success and 'success' or 'error')
    end
end

CreateThread(function()
    exports['som-interact']:addGlobalPlayer({
        onPerson('Take a DNA sample', 'fa-solid fa-vial', sample('dna_sample')),
        onPerson('Take fingerprints', 'fa-solid fa-fingerprint', sample('print_sample')),
        onPerson('GSR test', 'fa-solid fa-hand', function(target)
            local res = lib.callback.await('som-evidence:server:gsr', false, target)
            if not res or not res.success then
                return TriggerEvent('som:client:notify', res and res.error or 'Request failed', 'error')
            end
            TriggerEvent('som:client:notify', res.positive and 'GSR: positive' or 'GSR: negative', 'inform')
        end),
    })
end)
