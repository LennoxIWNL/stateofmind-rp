--- Menus and a waypoint. Questions arrive without their answers and every
--- verdict, checkpoint and fault is the server's.

local core = exports['som-core']
local blip

local function notify(text, kind) TriggerEvent('som:client:notify', text, kind or 'error') end

local function showQuestion(q)
    lib.registerContext({
        id = 'som_licences_question',
        title = ('Question %d of %d'):format(q.n, q.total),
        description = q.text,
        canClose = false,
        options = (function()
            local out = {}
            for i, label in ipairs(q.options) do
                out[i] = {
                    title = label,
                    onSelect = function()
                        local r = lib.callback.await('som-licences:server:answer', false, i)
                        if not r or not r.success then return notify(r and r.error or 'The test was cancelled') end
                        if r.question then return showQuestion(r.question) end

                        lib.alertDialog({
                            header = r.passed and 'Theory test passed' or 'Theory test failed',
                            content = ('You scored %d of %d.%s'):format(r.score, r.total,
                                r.passed and ' Speak to the desk to start the driving test.' or ' Come back later to try again.'),
                        })
                    end,
                }
            end
            return out
        end)(),
    })
    lib.showContext('som_licences_question')
end

local function clear()
    if blip then RemoveBlip(blip) end
    blip = nil
end

RegisterNetEvent('som-licences:client:practical', function(data)
    clear()
    if type(data) ~= 'table' then return end

    if data.netId then
        local found, vehicle = pcall(lib.waitFor, function()
            if NetworkDoesNetworkIdExist(data.netId) then return NetToVeh(data.netId) end
        end, nil, 5000)
        if found and vehicle then SetPedIntoVehicle(cache.ped, vehicle, -1) end
    end

    local c = data.checkpoint
    if not c then return end
    blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipRoute(blip, true)
    SetBlipColour(blip, 5)
end)

RegisterNetEvent('som-licences:client:weaponOffer', function(fee)
    if type(fee) ~= 'number' then return end
    local accepted = lib.alertDialog({
        header = 'Weapon licence',
        content = ('The police are offering you a weapon licence for $%d from your bank.'):format(fee),
        cancel = true,
    }) == 'confirm'
    lib.callback.await('som-licences:server:answerWeapon', false, accepted)
end)

CreateThread(function()
    local s = Config.school
    if not s.enabled or not s.coords then return end

    exports['som-interact']:addSphereZone({
        name = 'som_licences_school',
        coords = s.coords,
        radius = s.radius,
        options = {
            {
                name = 'som_licences_theory',
                label = 'Take the theory test',
                icon = 'fa-solid fa-book',
                distance = s.radius,
                onSelect = function()
                    local r = lib.callback.await('som-licences:server:beginTheory', false)
                    if not r or not r.success then return notify(r and r.error or 'Not available') end
                    showQuestion(r.question)
                end,
            },
            {
                name = 'som_licences_practical',
                label = 'Start the driving test',
                icon = 'fa-solid fa-car',
                distance = s.radius,
                onSelect = function()
                    local r = lib.callback.await('som-licences:server:startPractical', false)
                    if not r or not r.success then notify(r and r.error or 'Not available') end
                end,
            },
        },
    })
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then clear() end
end)
