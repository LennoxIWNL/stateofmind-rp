-- Re-applies the ped after a wardrobe change.
--
-- Separate from the refresh export next door only because this is a net event
-- and that is an export; both do the same one thing, which is ask the server
-- what the character looks like now and apply it. The server is what decided,
-- so nothing here reads or holds wardrobe state.
RegisterNetEvent('som-appearance:client:refresh', function()
    local data = lib.callback.await('som-appearance:server:get', false)
    if data and data.appearance then Appearance.Apply(cache.ped, data.appearance) end
end)
