-- Phone animation.
--
-- Purely cosmetic and purely local: nothing here decides anything, it only
-- makes the phone visible in the world so other players can see who is on it.
-- Everything is wrapped so a failed model or dict load degrades to no
-- animation rather than a broken open.

Anim = {}

local prop = nil
local playing = nil

---@param name string
---@return boolean loaded
local function loadDict(name)
    if HasAnimDictLoaded(name) then return true end

    RequestAnimDict(name)

    -- Bounded rather than a bare while: a missing dict would otherwise hang
    -- the open forever.
    local deadline = GetGameTimer() + 1000
    while not HasAnimDictLoaded(name) and GetGameTimer() < deadline do Wait(0) end

    return HasAnimDictLoaded(name)
end

local function destroyProp()
    if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
    prop = nil
end

local function createProp()
    if prop and DoesEntityExist(prop) then return end

    local model = joaat(Config.Animation.prop)
    if not IsModelValid(model) then return end

    RequestModel(model)
    local deadline = GetGameTimer() + 1000
    while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(0) end
    if not HasModelLoaded(model) then return end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    prop = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)

    local offset, rotation = Config.Animation.offset, Config.Animation.rotation
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, Config.Animation.bone),
        offset.x, offset.y, offset.z,
        rotation.x, rotation.y, rotation.z,
        true, true, false, true, 1, true)

    SetModelAsNoLongerNeeded(model)
end

---Plays one of the phone clips and puts the prop in the character's hand.
---@param clip string 'hold' or 'call'
function Anim.Play(clip)
    if not Config.Animation.enabled then return end

    local name = Config.Animation[clip]
    if not name or playing == clip then return end

    if not loadDict(Config.Animation.dict) then return end

    createProp()

    -- Flag 49 is looping and upper body only, so the character can still walk
    -- and drive while holding the phone.
    TaskPlayAnim(PlayerPedId(), Config.Animation.dict, name,
        Config.Animation.blendIn, Config.Animation.blendOut,
        -1, 49, 0, false, false, false)

    playing = clip
end

---Puts the phone away. Blending out is what reads as lowering the arm, so the
---prop is only removed once the blend has had time to run.
function Anim.Stop()
    if not playing then return end

    local wasPlaying = playing
    playing = nil

    local ped = PlayerPedId()
    StopAnimTask(ped, Config.Animation.dict, Config.Animation[wasPlaying],
        Config.Animation.blendOut)

    CreateThread(function()
        Wait(400)
        -- Guard against the phone being reopened during the blend out.
        if not playing then destroyProp() end
    end)
end

-- Dying clears the anim task but leaves the attached prop behind, and
-- respawning gives a new ped the old prop is no longer attached to. Both
-- events come from baseevents, which is ensured ahead of this resource.
local function drop()
    playing = nil
    destroyProp()
end

AddEventHandler('baseevents:onPlayerDied', drop)
AddEventHandler('baseevents:onPlayerKilled', drop)
AddEventHandler('playerSpawned', drop)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    destroyProp()
    if playing then
        StopAnimTask(PlayerPedId(), Config.Animation.dict, Config.Animation[playing], 1.0)
    end
end)

-- Exported so the call flow in 4b-2 can raise the phone to the ear without
-- reimplementing prop handling.
exports('setPhoneAnimation', function(clip)
    if clip then Anim.Play(clip) else Anim.Stop() end
end)
