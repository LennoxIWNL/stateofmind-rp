-- Pause menu server.
--
-- Everything the menu shows is assembled here. The staff tab in particular is
-- filtered server side: sending it and hiding it in CSS would let the client
-- decide what it is allowed to see.

---@param source number
---@return table[] tabs this player may see
local function tabsFor(source)
    local list = {}

    for _, tab in ipairs(Config.Tabs) do
        if not tab.ace or exports['som-core']:hasPermission(source, tab.ace) then
            list[#list + 1] = { id = tab.id, label = tab.label, icon = tab.icon }
        end
    end

    return list
end

lib.callback.register('som-pause:server:overview', function(source)
    local player = exports['som-core']:getPlayer(source)
    if not player then return nil end

    local charinfo = player.charinfo or {}
    local metadata = player.metadata or {}

    local jobs = exports['som-core']:getJobs() or {}
    local jobDef = jobs[player.job and player.job.name]

    local licences = {}
    for name, held in pairs(metadata.licenses or {}) do
        if held then licences[#licences + 1] = name end
    end
    table.sort(licences)

    local tier = exports['som-core']:getPermissionTier(source)

    return {
        tabs = tabsFor(source),

        character = {
            name = ('%s %s'):format(charinfo.firstname or '', charinfo.lastname or ''),
            citizenid = player.citizenid,
            phone = charinfo.phone,
            dob = charinfo.birthdate,
            gender = charinfo.gender,
            cash = (player.money and player.money.cash) or 0,
            bank = (player.money and player.money.bank) or 0,
            job = {
                label = (jobDef and jobDef.label) or (player.job and player.job.name) or 'Unemployed',
                grade = player.job and player.job.grade,
                onduty = player.job and player.job.onduty or false,
            },
            gang = player.gang and player.gang.name ~= 'none' and player.gang.name or nil,
            licences = licences,
        },

        server = {
            players = #GetPlayers(),
            maxPlayers = GetConvarInt('sv_maxclients', 48),
        },

        -- nil for everyone below moderator, so the tab has nothing to render
        -- even if the client asks for it.
        staff = tier and { tier = tier } or nil,
    }
end)

RegisterNetEvent('som-pause:server:quit', function()
    local source = source
    if not exports['som-core']:getPlayer(source) then return end

    DropPlayer(source, 'Disconnected from the pause menu.')
end)
