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

AddEventHandler('som:client:playerLoaded', build)
CreateThread(function() Wait(3000); build() end)
AddEventHandler('onResourceStop', function(name) if name == GetCurrentResourceName() then clear() end end)
