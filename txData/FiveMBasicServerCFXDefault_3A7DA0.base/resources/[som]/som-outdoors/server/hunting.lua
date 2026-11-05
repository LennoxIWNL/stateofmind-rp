--- Hunting. A kill is not trusted from the client: the server reads the animal
--- itself (model, death, and who killed it) and marks the carcass as skinned on
--- the entity, in the same tick it checks, so two hunters cannot both take it.

local core = exports['som-core']
local ox = exports.ox_inventory
local H = Config.hunting

local last = {}
local models = {}
for name, def in pairs(H.animals) do models[joaat(name)] = def end

local function done(ok, err, extra) return Buyer.Done(ok, err, extra) end

lib.callback.register('som-outdoors:server:skin', function(source, netId)
    local player = core:getPlayer(source)
    if not player then return done(false, 'not available') end

    netId = tonumber(netId)
    if not netId or netId % 1 ~= 0 then return done(false, 'bad request') end

    local animal = NetworkGetEntityFromNetworkId(netId)
    if not animal or animal == 0 or not DoesEntityExist(animal) or GetEntityType(animal) ~= 1 then
        return done(false, 'there is nothing to skin')
    end

    local def = models[GetEntityModel(animal)]
    if not def then return done(false, 'there is nothing to skin') end

    local ped = GetPlayerPed(source)
    if ped == 0 or #(GetEntityCoords(ped) - GetEntityCoords(animal)) > H.distance then return done(false, 'you are too far away') end
    if GetEntityHealth(animal) > 0 then return done(false, 'it is still alive') end
    if GetPedSourceOfDeath(animal) ~= ped then return done(false, 'that is not your kill') end

    if H.requireLicense and (ox:Search(source, 'count', H.license) or 0) < 1 then return done(false, 'you need a hunting licence') end
    if (ox:Search(source, 'count', H.knife) or 0) < 1 then return done(false, 'you need a hunting knife') end

    local now = GetGameTimer()
    if last[player.citizenid] and now - last[player.citizenid] < H.cooldown * 1000 then return done(false, 'give it a moment') end

    local state = Entity(animal).state
    if state.skinned then return done(false, 'it has been skinned already') end
    state:set('skinned', true, true)
    last[player.citizenid] = now

    -- Trophies (chance under 1) turn up 2% more often per hunting level above 1.
    local bonus = 0.02 * (Buyer.Level(source, 'hunting') - 1)
    local got = {}
    for _, d in ipairs(def.drops) do
        if math.random() <= (d[4] < 1 and math.min(1, d[4] + bonus) or d[4]) then
            local n = math.random(d[2], d[3])
            if ox:AddItem(source, d[1], n) then got[#got + 1] = { item = d[1], count = n } end
        end
    end
    Buyer.Xp(source, 'hunting', 25)
    return done(true, nil, { items = got })
end)

AddEventHandler('som:server:playerUnloaded', function(_, citizenid)
    if type(citizenid) == 'string' then last[citizenid] = nil end
end)
