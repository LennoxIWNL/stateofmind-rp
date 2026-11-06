--- Pump and jerry can options. Everything priced or granted is decided by the
--- server; this asks, shows the answer and runs the progress bar.

local stations = {}

local function say(text, kind) TriggerEvent('som:client:notify', text, kind) end

local function nearStation()
    local at = GetEntityCoords(cache.ped)
    for _, s in ipairs(stations) do
        if #(at - vec3(s.x, s.y, s.z)) <= Config.stationDistance then return true end
    end
    return false
end

local function vehicleNearby()
    return lib.getClosestVehicle(GetEntityCoords(cache.ped), Config.vehicleDistance, true)
end

local function accountPick()
    local options = {}
    for _, name in ipairs(Config.accounts) do options[#options + 1] = { value = name, label = name } end
    return options
end

local function refuel()
    local vehicle = vehicleNearby()
    if not vehicle then return say('No vehicle here', 'error') end
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local claimed = GetVehicleFuelLevel(vehicle)

    local quote = lib.callback.await('som-fuel:server:quote', false, netId, claimed)
    if not quote or not quote.success then return say(quote and quote.error or 'Failed', 'error') end
    if quote.room < 1 then return say('The tank is full', 'inform') end

    local answer = lib.inputDialog(('Refuel ($%d a litre)'):format(quote.price), {
        { type = 'number', label = 'Litres', min = 1, max = quote.room, default = quote.room, required = true },
        { type = 'select', label = 'Pay with', options = accountPick(), default = Config.accounts[#Config.accounts], required = true },
    })
    if not answer then return end
    local litres = math.floor(tonumber(answer[1]) or 0)

    local ok = lib.progressBar({ duration = litres * 400, label = 'Refuelling', canCancel = true, disable = { move = true, combat = true, car = true } })
    if not ok then return end

    local result = lib.callback.await('som-fuel:server:buy', false, netId, litres, claimed, answer[2])
    if result and result.success then
        say(('Added %d litres for $%d'):format(result.litres, result.total), 'success')
    else
        say(result and result.error or 'Failed', 'error')
    end
end

local function canAction(callback, label, ...)
    local result = lib.callback.await(callback, false, ...)
    if result and result.success then say(label, 'success') else say(result and result.error or 'Failed', 'error') end
end

local function buildOptions()
    exports['som-interact']:addModel(Config.pumpModels, {
        {
            name = 'som_fuel_refuel', label = 'Refuel vehicle', icon = 'fa-solid fa-gas-pump', distance = 2.5,
            canInteract = nearStation, onSelect = refuel,
        },
        {
            name = 'som_fuel_cabuy', label = ('Buy jerry can ($%d)'):format(Config.can.price), icon = 'fa-solid fa-oil-can', distance = 2.5,
            canInteract = nearStation,
            onSelect = function()
                canAction('som-fuel:server:canBuy', 'Jerry can bought', Config.accounts[#Config.accounts])
            end,
        },
        {
            name = 'som_fuel_canfill', label = 'Refill jerry can', icon = 'fa-solid fa-fill-drip', distance = 2.5,
            canInteract = nearStation,
            onSelect = function()
                canAction('som-fuel:server:canRefill', 'Jerry can refilled', Config.accounts[#Config.accounts])
            end,
        },
    })

    exports['som-interact']:addGlobalVehicle({
        {
            name = 'som_fuel_canuse', label = 'Pour jerry can', icon = 'fa-solid fa-gas-pump', distance = Config.can.distance,
            onSelect = function(data)
                local ok = lib.progressBar({ duration = 4000, label = 'Pouring fuel', canCancel = true, disable = { move = true, combat = true } })
                if not ok then return end
                canAction('som-fuel:server:canUse', 'Poured', NetworkGetNetworkIdFromEntity(data.entity))
            end,
        },
    })
end

local function load() stations = lib.callback.await('som-fuel:server:stations', false) or {} end

AddEventHandler('som:client:playerLoaded', load)
CreateThread(function() Wait(4000); load(); buildOptions() end)
