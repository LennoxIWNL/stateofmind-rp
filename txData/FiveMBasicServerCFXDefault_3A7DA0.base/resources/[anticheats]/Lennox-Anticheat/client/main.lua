-- =========================================================================
--  Lennox Anti-Cheat — Client
--  Created by Lennox — DO NOT MODIFY THIS FILE
-- =========================================================================

local LENNOX_SIG = 'Lennox'
local cfg = LACConfig

local function sigHash(s)
    local h = 0x5A3C
    for i = 1, #s do h = (h * 33 + string.byte(s, i)) % 0x7FFFFFFF end
    return h
end

local MAGIC = sigHash(LENNOX_SIG)
local EXPECTED_MAGIC = sigHash(string.char(76, 101, 110, 110, 111, 120))
local SEAL = (EXPECTED_MAGIC % 7919) + 1

local function deriveKey(base)
    return ('lac:%x'):format(sigHash(LENNOX_SIG .. ':' .. base))
end

-- =========================================================================
--  Heartbeat Responder
-- =========================================================================
local HB_CHALLENGE = deriveKey('hb:challenge')
local HB_RESPONSE  = deriveKey('hb:response')

RegisterNetEvent(HB_CHALLENGE, function(challenge)
    if type(challenge) ~= 'number' then return end
    local response = ((challenge * MAGIC) % 0x7FFFFFFF) + SEAL
    TriggerServerEvent(HB_RESPONSE, response)
end)

-- =========================================================================
--  Client Detectors
-- =========================================================================
local DETECT_GODMODE  = deriveKey('det:godmode')
local DETECT_RESOURCE = deriveKey('det:resource')

-- God Mode Detection
CreateThread(function()
    Wait(15000)
    while true do
        Wait(5000)
        if GetPlayerInvincible(PlayerId()) then
            TriggerServerEvent(DETECT_GODMODE, 'invincible_flag_enabled')
        end
    end
end)

-- Blacklisted Resource Scan
CreateThread(function()
    Wait(20000)
    local blacklist = cfg.BlacklistedResources or {}

    while true do
        local numRes = GetNumResources()
        for i = 0, numRes - 1 do
            local resName = GetResourceByFindIndex(i)
            if resName then
                local lower = resName:lower()
                for _, bl in ipairs(blacklist) do
                    if lower:find(bl, 1, true) then
                        TriggerServerEvent(DETECT_RESOURCE, resName)
                        Wait(60000)
                        break
                    end
                end
            end
        end
        Wait(30000)
    end
end)

-- Spectate / Freecam detection
CreateThread(function()
    Wait(15000)
    while true do
        Wait(3000)
        local ped = PlayerPedId()
        if not DoesEntityExist(ped) then goto skip end

        if IsEntityVisible(ped) == false and GetEntitySpeed(ped) > 2.0 then
            TriggerServerEvent(DETECT_GODMODE, 'invisible_while_moving')
        end

        ::skip::
    end
end)
