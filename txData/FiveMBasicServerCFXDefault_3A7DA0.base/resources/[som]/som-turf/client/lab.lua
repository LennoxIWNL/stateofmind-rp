--- Lab points. The server checks the gang, distance, ingredients and time.

local zones = {}

local function say(result)
    if not result then return end
    TriggerEvent('som:client:notify', result.success and 'Done' or (result.error or 'Failed'), result.success and 'success' or 'error')
end

local function clear()
    for _, id in ipairs(zones) do exports['som-interact']:removeZone(id) end
    zones = {}
end

local function build()
    clear()
    local info = lib.callback.await('som-turf:server:labInfo', false)
    if type(info) ~= 'table' then return end

    for _, lab in ipairs(info.labs) do
        zones[#zones + 1] = exports['som-interact']:addSphereZone({
            name = 'som_lab_' .. lab.name,
            coords = vec3(lab.coords.x, lab.coords.y, lab.coords.z),
            radius = 1.5,
            options = {
                { name = 'som_lab_cook', label = 'Start a cook', icon = 'fa-solid fa-flask', distance = 2.0,
                  onSelect = function()
                      local options = {}
                      for _, r in ipairs(info.recipes) do options[#options + 1] = { value = r.id, label = r.label } end
                      local answer = lib.inputDialog('Start a cook', { { type = 'select', label = 'Recipe', options = options, required = true } })
                      if answer and answer[1] and lib.progressBar({ duration = 5000, label = 'Setting up', canCancel = true, disable = { move = true, combat = true } }) then
                          say(lib.callback.await('som-turf:server:labStart', false, lab.name, answer[1]))
                      end
                  end },
                { name = 'som_lab_collect', label = 'Collect', icon = 'fa-solid fa-box-open', distance = 2.0,
                  onSelect = function() say(lib.callback.await('som-turf:server:labCollect', false, lab.name)) end },
            },
        })
    end
end

local function supplier()
    local sup = lib.callback.await('som-turf:server:supplierInfo', false)
    if type(sup) ~= 'table' then return end
    zones[#zones + 1] = exports['som-interact']:addSphereZone({
        name = 'som_supplier',
        coords = vec3(sup.coords.x, sup.coords.y, sup.coords.z),
        radius = 1.5,
        options = { { name = 'som_supplier_buy', label = sup.label, icon = 'fa-solid fa-flask-vial', distance = 2.0,
            onSelect = function()
                local options = {}
                for _, r in ipairs(sup.stock) do options[#options + 1] = { value = r.item, label = ('%s ($%d)'):format(r.item:gsub('_', ' '), r.price) } end
                local answer = lib.inputDialog(sup.label, {
                    { type = 'select', label = 'Item', options = options, required = true },
                    { type = 'number', label = 'Amount', min = 1, max = sup.maxQty, default = 1, required = true },
                })
                if answer and answer[1] and answer[2] then
                    say(lib.callback.await('som-turf:server:supplierBuy', false, answer[1], answer[2]))
                end
            end } },
    })
end

local function rebuild() build(); supplier() end

AddEventHandler('som:client:playerLoaded', rebuild)
CreateThread(function() Wait(3000); rebuild() end)
AddEventHandler('onResourceStop', function(name) if name == GetCurrentResourceName() then clear() end end)
