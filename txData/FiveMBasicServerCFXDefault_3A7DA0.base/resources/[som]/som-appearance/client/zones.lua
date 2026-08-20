-- Barber and clothing store zones.
--
-- The editor itself was finished a long time before this file existed. What was
-- missing was any way into it: openEditor was called by som-multichar during
-- character creation and by nothing else in the tree, so a player built a face
-- once and then lived with it and with the clothes they were created in
-- forever. This is the way in.
--
-- Every zone is a SPHERE rather than an entity target, for the reason
-- som-interact's README gives: ox_target draws its indicator circle for zones
-- only, so a barber chair registered against a prop would have no marker at
-- all. The shops are static, so a sphere behaves the same and earns the circle.

local zones = {}
local blips = {}

---@param kind string 'barber' or 'clothing'
---@param def table Config.Locations entry
local function register(kind, def)
    for index, coords in ipairs(def.coords) do
        zones[#zones + 1] = exports['som-interact']:addSphereZone({
            name = ('som_appearance_%s_%d'):format(kind, index),
            coords = coords,
            radius = def.radius or 1.5,
            options = {
                {
                    name = ('som_appearance_%s'):format(kind),
                    label = def.prompt,
                    icon = def.icon,
                    distance = def.distance or 2.0,
                    -- The editor freezes the ped and takes the camera, so it
                    -- has no sensible answer for a player who is sitting in a
                    -- car or lying in the street. Guarded here rather than
                    -- inside the editor, so the option is not even offered.
                    canInteract = function()
                        if IsPedInAnyVehicle(cache.ped, false) then return false end

                        if GetResourceState('som-medical') == 'started'
                            and exports['som-medical']:isDowned() then
                            return false
                        end

                        return true
                    end,
                    -- openEditor rather than a local call, so this file goes
                    -- through the same entry point som-multichar does and there
                    -- is still only one way to open the editor.
                    onSelect = function() exports['som-appearance']:openEditor(kind) end,
                },
            },
        })

        if def.blip then
            local blip = AddBlipForCoord(coords.x, coords.y, coords.z)

            SetBlipSprite(blip, def.blip.sprite)
            SetBlipColour(blip, def.blip.colour)
            SetBlipScale(blip, def.blip.scale)
            SetBlipAsShortRange(blip, true)
            SetBlipDisplay(blip, 4)

            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(def.label)
            EndTextCommandSetBlipName(blip)

            blips[#blips + 1] = blip
        end
    end
end

CreateThread(function()
    if not Config.Locations then return end

    for kind, def in pairs(Config.Locations) do
        if Config.Scopes[kind] and type(def.coords) == 'table' then
            register(kind, def)
        end
    end
end)

-- The blips are ours and nothing else removes them, so a restart without this
-- leaves a second set on the map on top of the first.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for i = 1, #blips do RemoveBlip(blips[i]) end

    for i = 1, #zones do
        exports['som-interact']:removeZone(zones[i])
    end
end)
