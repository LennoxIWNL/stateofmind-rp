--- Shows plants and the grow and bag points. The server decides whether a
--- seed can go here, whether a plant is ready and what a harvest yields.

local zones, objects = {}, {}
local info

local function say(result)
    if not result then return end
    if result.success then
        TriggerEvent('som:client:notify', result.count and ('Harvested %d'):format(result.count) or 'Done', 'success')
    elseif result.error then
        TriggerEvent('som:client:notify', result.error, 'error')
    end
end

local function pickStrain(title)
    local options = {}
    for _, st in ipairs(info.strains) do options[#options + 1] = { value = st.seed, label = st.label } end
    local answer = lib.inputDialog(title, { { type = 'select', label = 'Strain', options = options, required = true } })
    return answer and answer[1]
end

local function clearAll()
    for _, id in ipairs(zones) do exports['som-interact']:removeZone(id) end
    for _, obj in ipairs(objects) do if DoesEntityExist(obj) then DeleteObject(obj) end end
    zones, objects = {}, {}
end

local function refresh()
    info = info or lib.callback.await('som-turf:server:growInfo', false)
    if type(info) ~= 'table' then return end

    local plants = lib.callback.await('som-turf:server:plants', false) or {}
    clearAll()

    local model = joaat('prop_weed_01')
    RequestModel(model)
    local waited = 0
    while not HasModelLoaded(model) and waited < 50 do Wait(50); waited = waited + 1 end

    for _, p in ipairs(plants) do
        if HasModelLoaded(model) then
            local obj = CreateObject(model, p.x, p.y, p.z - 1.0, false, false, false)
            FreezeEntityPosition(obj, true)
            objects[#objects + 1] = obj
        end
        zones[#zones + 1] = exports['som-interact']:addSphereZone({
            name = 'som_plant_' .. p.id,
            coords = vec3(p.x, p.y, p.z),
            radius = 1.2,
            options = {
                { name = 'som_plant_water', label = 'Water', icon = 'fa-solid fa-droplet', distance = 2.0,
                  onSelect = function() say(lib.callback.await('som-turf:server:tend', false, p.id, 'water')) end },
                { name = 'som_plant_feed', label = 'Feed', icon = 'fa-solid fa-seedling', distance = 2.0,
                  onSelect = function() say(lib.callback.await('som-turf:server:tend', false, p.id, 'feed')) end },
                { name = 'som_plant_harvest', label = p.stage == 'ready' and 'Harvest' or 'Not ready yet', icon = 'fa-solid fa-scissors', distance = 2.0,
                  onSelect = function()
                      if lib.progressBar({ duration = 5000, label = 'Harvesting', canCancel = true, disable = { move = true, combat = true } }) then
                          say(lib.callback.await('som-turf:server:harvest', false, p.id))
                          refresh()
                      end
                  end },
            },
        })
    end

    for _, sp in ipairs(info.spots) do
        zones[#zones + 1] = exports['som-interact']:addSphereZone({
            name = 'som_grow_' .. sp.name,
            coords = vec3(sp.center.x, sp.center.y, sp.center.z),
            radius = sp.radius,
            options = { { name = 'som_grow_plant', label = 'Plant a seed', icon = 'fa-solid fa-seedling', distance = sp.radius,
                onSelect = function()
                    local seed = pickStrain('Plant a seed')
                    if seed then say(lib.callback.await('som-turf:server:plant', false, seed)); refresh() end
                end } },
        })
    end

    for _, t in ipairs(info.tables) do
        zones[#zones + 1] = exports['som-interact']:addSphereZone({
            name = 'som_bag_' .. t.name,
            coords = vec3(t.coords.x, t.coords.y, t.coords.z),
            radius = 1.5,
            options = { { name = 'som_bag_weed', label = 'Bag the weed', icon = 'fa-solid fa-bag-shopping', distance = 2.0,
                onSelect = function()
                    local seed = pickStrain('Bag the weed')
                    if seed and lib.progressBar({ duration = 4000, label = 'Bagging', canCancel = true, disable = { move = true, combat = true } }) then
                        say(lib.callback.await('som-turf:server:bag', false, seed))
                    end
                end } },
        })
    end
end

RegisterNetEvent('som-turf:client:planted', refresh)
AddEventHandler('som:client:playerLoaded', refresh)
CreateThread(function()
    Wait(2500)
    while true do
        refresh()
        Wait(60000)
    end
end)
AddEventHandler('onResourceStop', function(name) if name == GetCurrentResourceName() then clearAll() end end)
