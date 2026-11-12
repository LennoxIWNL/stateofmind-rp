-- Vehicle interactions: impound, plate flagging, plate check.
--
-- All three are police only and all three are requests. The eye showing
-- "Impound" on a car does not make it impoundable.

local function handle(res, failure)
    if not res or not res.success then
        TriggerEvent('som:client:notify',
            (res and res.error) or failure or 'That did not work', 'error')
        return false
    end
    return true
end

---@param entity number
---@return number|nil netId
local function netIdOf(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end
    return NetworkGetNetworkIdFromEntity(entity)
end

local function onDuty() return Duty.IsOnDuty() end

CreateThread(function()
    exports['som-interact']:addGlobalVehicle({
        {
            name = 'police:checkplate',
            icon = 'fa-solid fa-magnifying-glass',
            label = 'Run the plate',
            distance = 3.0,
            canInteract = onDuty,
            onSelect = function(data)
                local netId = netIdOf(data.entity)
                if not netId then return end

                local res = lib.callback.await('som-police:server:checkPlate', false, netId)
                if not handle(res) then return end

                lib.registerContext({
                    id = 'som_police_plate',
                    title = res.plate,
                    options = {
                        { title = 'Registered to', description = res.owner, icon = 'user' },
                        res.registration and {
                            title = res.registration == 'expired' and 'REGISTRATION EXPIRED' or 'Registration valid',
                            icon = res.registration == 'expired' and 'triangle-exclamation' or 'circle-check',
                        } or nil,
                        {
                            title = res.flagged and 'FLAGGED' or 'Not flagged',
                            description = res.flagged or 'No active flag on this plate',
                            icon = res.flagged and 'triangle-exclamation' or 'circle-check',
                        },
                    },
                })

                lib.showContext('som_police_plate')
            end,
        },
        {
            name = 'police:flagplate',
            icon = 'fa-solid fa-flag',
            label = 'Flag or clear the plate',
            distance = 3.0,
            canInteract = onDuty,
            onSelect = function(data)
                local netId = netIdOf(data.entity)
                if not netId then return end

                -- A reason is only needed to RAISE a flag. The server decides
                -- which of the two this is, since it is the one that knows
                -- whether an active flag already exists, so the reason is
                -- collected up front and ignored when clearing.
                local input = lib.inputDialog('Flag plate', {
                    { type = 'input', label = 'Reason',
                      description = 'Ignored if you are clearing an existing flag',
                      max = 160 },
                })

                if not input then return end

                local res = lib.callback.await('som-police:server:flagPlate', false, {
                    netId = netId, reason = input[1] or '',
                })

                if not handle(res) then return end

                TriggerEvent('som:client:notify',
                    res.flagged and ('%s flagged'):format(res.plate)
                        or ('Flag cleared on %s'):format(res.plate),
                    'success')
            end,
        },
        {
            name = 'police:impound',
            icon = 'fa-solid fa-truck-ramp-box',
            label = 'Impound',
            distance = 3.0,
            canInteract = onDuty,
            onSelect = function(data)
                local netId = netIdOf(data.entity)
                if not netId then return end

                local function pickReason(tow)
                    local options = {}
                    for index, reason in ipairs(Config.Impound.reasons) do
                        options[#options + 1] = {
                            title = reason,
                            icon = 'truck-ramp-box',
                            onSelect = function()
                                local ok = lib.progressBar({
                                    duration = 5000,
                                    label = 'Arranging a tow',
                                    canCancel = true,
                                    disable = { move = true, combat = true },
                                })

                                if not ok then return end

                                local res = lib.callback.await('som-police:server:impound', false, {
                                    netId = netId, reason = index, tow = tow,
                                })

                                if not handle(res) then return end

                                TriggerEvent('som:client:notify',
                                    res.towed and ('Tow requested for %s'):format(res.plate)
                                        or ('%s impounded'):format(res.plate), 'success')
                            end,
                        }
                    end

                    lib.registerContext({
                        id = 'som_police_impound_reason',
                        title = 'Reason for impound',
                        options = options,
                    })

                    lib.showContext('som_police_impound_reason')
                end

                lib.registerContext({
                    id = 'som_police_impound_mode',
                    title = 'Impound',
                    options = {
                        { title = 'Ask for a tow truck', description = 'A tow driver on duty collects it. Impounded at once if nobody is on.', icon = 'truck-ramp-box', onSelect = function() pickReason(true) end },
                        { title = 'Impound now', icon = 'ban', onSelect = function() pickReason(false) end },
                    },
                })

                lib.showContext('som_police_impound_mode')
            end,
        },
    })
end)

-- ---------------------------------------------------------------------------
-- Voiding a fine.
--
-- A COMMAND on purpose, and the only one in this resource. AUDIT §10.1 exists
-- to delete commands like /cuff and /escort, all of which name a target you are
-- looking at and so belong on the eye. This one names a fine by ID, which is
-- read off the MDT or the phone and cannot be pointed at, so a command is the
-- honest shape for it rather than a menu that would have to list every fine on
-- the server.
--
-- Restricted to command staff by the server, not by this registration.
-- ---------------------------------------------------------------------------

RegisterCommand('voidfine', function(_, args)
    local fineId = tonumber(args[1])
    if not fineId then
        return TriggerEvent('som:client:notify', 'Usage: /voidfine <fine id>', 'error')
    end

    local res = lib.callback.await('som-police:server:voidFine', false, fineId)
    if not handle(res) then return end

    TriggerEvent('som:client:notify', ('Fine #%d voided'):format(fineId), 'success')
end, false)
