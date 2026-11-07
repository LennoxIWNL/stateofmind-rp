--- Calls ambulance staff to a player who stays down. The position is the server
--- ped's, the text never carries anything the client sent, and a character raises
--- at most one call per cooldown.

local core = exports['som-core']

local episodes, calls, lastCall, nextEpisode = {}, {}, {}, 0

---Fails closed: if the jail cannot be asked, nobody is called.
local function jailed(citizenid)
    if GetResourceState('som-jail') ~= 'started' then return false end
    local ok, row = pcall(function() return exports['som-jail']:activeFor(citizenid) end)
    return not ok or row ~= nil
end

---Raises the call for one down event if it still applies.
---@return number|nil callId
function Medical.RaiseCall(source, citizenid, episode)
    if episodes[citizenid] ~= episode or not Medical.IsDowned(citizenid) then return nil end

    local player = core:getPlayer(source)
    if not player or player.citizenid ~= citizenid then return nil end

    local at = os.time()
    if lastCall[citizenid] and at - lastCall[citizenid] < Config.EmsCall.cooldownSeconds then return nil end
    if jailed(citizenid) then return nil end

    local ped = GetPlayerPed(source)
    if ped == 0 then return nil end

    lastCall[citizenid] = at
    calls[citizenid] = exports['som-dispatch']:alert(nil, 'personDown', { coords = GetEntityCoords(ped), message = 'Person down' })
    return calls[citizenid]
end

AddEventHandler('som:server:playerDowned', function(source, citizenid)
    if type(citizenid) ~= 'string' then return end

    nextEpisode = nextEpisode + 1
    local episode = nextEpisode
    episodes[citizenid] = episode
    CreateThread(function()
        Wait(Config.EmsCall.delaySeconds * 1000)
        Medical.RaiseCall(source, citizenid, episode)
    end)
end)

---Revived, respawned or gone: the patient no longer needs anyone.
local function settle(_, citizenid)
    if type(citizenid) ~= 'string' then return end
    episodes[citizenid] = nil

    local id = calls[citizenid]
    calls[citizenid] = nil
    if id then exports['som-dispatch']:resolve(id, 'patient no longer down') end
end

AddEventHandler('som:server:playerRevived', settle)
AddEventHandler('som:server:playerUnloaded', settle)
