-- Re-applies the ped after a wardrobe change.
--
-- Separate from the refresh export next door only because this is a net event
-- and that is an export; both do the same one thing, which is ask the server
-- what the character looks like now and apply it. The server is what decided,
-- so nothing here reads or holds wardrobe state.
--
-- THE ANIMATION IS WHY THIS FILE IS NOT TWO LINES.
--
-- Applying the appearance the instant the server says so makes garments pop on
-- and off, which is the thing that reads as cheap. The ped plays a motion
-- first and the change lands PART WAY THROUGH it, so the hands are already at
-- the collar when the shirt changes.
--
-- Every dictionary is checked with DoesAnimDictExist before it is requested.
-- These are the clothing-store try-on dictionaries and they should all exist,
-- but a name that does not costs the animation rather than the wardrobe: an
-- unguarded lib.requestAnimDict raises, and a raise here would mean the
-- garment never gets applied at all.

-- Component ids, matching som-appearance's own numbering.
local ANIMS = {
    component = {
        [3]  = { 'clothingshirt',    'try_shirt_positive_d' },
        [4]  = { 'clothingtrousers', 'try_trousers_positive_a' },
        [6]  = { 'clothingshoes',    'try_shoes_positive_a' },
        [7]  = { 'clothingtie',      'try_tie_negative_a' },
        [8]  = { 'clothingshirt',    'try_shirt_positive_d' },
        [11] = { 'clothingshirt',    'try_shirt_positive_d' },
    },
    prop = {
        [0] = { 'clothinghat', 'try_hat_positive_a' },
        [1] = { 'clothingspecs', 'take_off' },
    },
}

local FALLBACK = { 'clothingshirt', 'try_shirt_positive_d' }

local busy = false

local function pick(info)
    if type(info) ~= 'table' then return FALLBACK end

    local set = ANIMS[info.kind]
    local entry = set and info.id and set[info.id]

    return entry or FALLBACK
end

RegisterNetEvent('som-appearance:client:refresh', function(info)
    -- Re-entrancy guard. "Remove all" fires one of these per garment, and
    -- without this they stack into a ped twitching through six animations at
    -- once. The appearance still applies; only the animation is skipped.
    local animate = not busy

    if animate then
        busy = true

        local ped = cache.ped
        local entry = pick(info)
        local dict, clip = entry[1], entry[2]

        if DoesAnimDictExist(dict) and lib.requestAnimDict(dict, 1000) then
            TaskPlayAnim(ped, dict, clip, 3.0, 3.0, -1, 49, 0, false, false, false)
            -- Part way in, so the garment changes while the hands are moving
            -- rather than before the ped has started or after it has finished.
            Wait(600)
        end
    end

    local data = lib.callback.await('som-appearance:server:get', false)
    if data and data.appearance then Appearance.Apply(cache.ped, data.appearance) end

    if animate then
        Wait(350)
        ClearPedTasks(cache.ped)
        busy = false
    end
end)
