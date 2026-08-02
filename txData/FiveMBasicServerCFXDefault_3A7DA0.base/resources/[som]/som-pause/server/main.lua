-- Pause bar server.
--
-- The bar shows who you are and how busy the server is. Both are resolved here
-- rather than on the client, because a client asking itself who it is would be
-- answering its own question.

lib.callback.register('som-pause:server:overview', function(source)
    local player = exports['som-core']:getPlayer(source)
    if not player then return nil end

    local charinfo = player.charinfo or {}

    local jobs = exports['som-core']:getJobs() or {}
    local jobDef = jobs[player.job and player.job.name]

    return {
        character = {
            name = ('%s %s'):format(charinfo.firstname or '', charinfo.lastname or ''),
            job = (jobDef and jobDef.label) or (player.job and player.job.name) or 'Unemployed',
            onduty = (player.job and player.job.onduty) or false,
        },
        server = {
            players = #GetPlayers(),
            maxPlayers = GetConvarInt('sv_maxclients', 48),
        },
    }
end)

RegisterNetEvent('som-pause:server:quit', function()
    local source = source
    if not exports['som-core']:getPlayer(source) then return end

    DropPlayer(source, 'Disconnected from the pause menu.')
end)
