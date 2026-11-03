-- Test harness for server-side Lua that has no live FXServer to run against.
-- Loads real resource files (not reimplementations) into a sandboxed
-- environment backed by tests/mocks/*, and asserts on the result.
--
-- Run with: lua5.4 tests/run.lua

local dir = (arg[0]:match('(.*/)') or './')
dofile(dir .. 'mocks/fivem.lua')
dofile(dir .. 'mocks/exports.lua')
local mysql = dofile(dir .. 'mocks/mysql.lua')
local loader = dofile(dir .. 'loader.lua')

local REPO = dir .. '../txData/FiveMBasicServerCFXDefault_3A7DA0.base/resources/[som]/'

local results = { pass = 0, fail = 0 }

local function check(cond, msg)
    if cond then
        results.pass = results.pass + 1
    else
        results.fail = results.fail + 1
        print('FAIL: ' .. msg)
    end
end

local function resetDb()
    mysql.db.properties = {}
    mysql.db.owners = {}
    mysql.db.finance = {}
    mysql.db.nextId = { properties = 1, owners = 1, finance = 1 }
end

local function resetMocks()
    Mocks.calls = { payWith = 0, addMoney = 0, businessSpend = 0 }
    Mocks.players = {}
    Mocks.payWithFails = false
    Mocks.businessSpendFails = false
    FakePeds = {}
end

local function seedProperty(overrides)
    local id = mysql.db.nextId.properties
    mysql.db.nextId.properties = id + 1
    local p = {
        id = id, slug = 'test_prop_' .. id, label = 'Test Property', type = 'house',
        tier = 'standard', price = 100000, door_x = 0.0, door_y = 0.0, door_z = 0.0,
        for_sale = 1, realtor_only = 0, stash_slots = 50, stash_weight = 100000,
    }
    for k, v in pairs(overrides or {}) do p[k] = v end
    mysql.db.properties[#mysql.db.properties + 1] = p
    return p
end

local function placePed(source, x, y, z)
    FakePeds[source] = vec3(x, y, z)
end

local function loadHousing()
    resetDb()
    resetMocks()
    return loader.loadResource(REPO .. 'som-housing', {
        'shared/shells.lua',
        'shared/config.lua',
        'server/properties.lua',
        'server/ownership.lua',
        'server/finance.lua',
    })
end

----------------------------------------------------------------------
-- Properties.Claim / Release atomicity
----------------------------------------------------------------------
do
    local env = loadHousing()
    local p = seedProperty({})
    check(env.Properties.Claim(p.id) == true, 'Claim: first claim on a for-sale property should succeed')
    check(env.Properties.Claim(p.id) == false, 'Claim: second claim on the same property should fail')
    env.Properties.Release(p.id)
    check(env.Properties.Claim(p.id) == true, 'Claim: claim should succeed again after Release')
end

----------------------------------------------------------------------
-- som-housing:server:buy — race: second buyer refused before paying
----------------------------------------------------------------------
do
    local env = loadHousing()
    local p = seedProperty({ price = 50000 })
    placePed(1, p.door_x, p.door_y, p.door_z)
    placePed(2, p.door_x, p.door_y, p.door_z)
    Mocks.players[1] = { citizenid = 'CID_A' }
    Mocks.players[2] = { citizenid = 'CID_B' }

    local buy = RegisteredCallbacks['som-housing:server:buy']
    local r1 = buy(1, { slug = p.slug, account = 'bank' })
    check(r1.success == true, 'buy: first buyer should succeed')
    check(Mocks.calls.payWith == 1, 'buy: first buyer should be charged exactly once')

    local r2 = buy(2, { slug = p.slug, account = 'bank' })
    check(r2.success == false, 'buy: second buyer on the same property should be refused')
    check(Mocks.calls.payWith == 1, 'buy: second buyer must never be charged (payWith call count stays at 1)')
    check(env.Ownership.OwnerOf(p.id) == 'CID_A', 'buy: property should still belong to the first buyer')
end

----------------------------------------------------------------------
-- som-housing:server:buy — payment failure releases the claim
----------------------------------------------------------------------
do
    local env = loadHousing()
    local p = seedProperty({})
    placePed(1, p.door_x, p.door_y, p.door_z)
    Mocks.players[1] = { citizenid = 'CID_A' }
    Mocks.payWithFails = true

    local buy = RegisteredCallbacks['som-housing:server:buy']
    local r = buy(1, { slug = p.slug, account = 'bank' })
    check(r.success == false, 'buy: a failed payment should refuse the sale')
    check(env.Properties.Claim(p.id) == true,
        'buy: a failed payment must release the claim, so the property is for sale again')
end

----------------------------------------------------------------------
-- som-housing:server:mortgage — race: second signing refused before paying
----------------------------------------------------------------------
do
    local env = loadHousing()
    local p = seedProperty({ price = 100000 })
    placePed(10, p.door_x, p.door_y, p.door_z) -- realtor
    placePed(1, p.door_x, p.door_y, p.door_z)  -- buyer A
    placePed(2, p.door_x, p.door_y, p.door_z)  -- buyer B
    Mocks.players[10] = { citizenid = 'CID_REALTOR', job = { name = 'realtor', onduty = true } }
    Mocks.players[1] = { citizenid = 'CID_A' }
    Mocks.players[2] = { citizenid = 'CID_B' }

    local mortgage = RegisteredCallbacks['som-housing:server:mortgage']
    local r1 = mortgage(10, { buyer = 1, slug = p.slug, account = 'bank', cycles = 8 })
    check(r1.success == true, 'mortgage: first signing should succeed')
    local paidAfterFirst = Mocks.calls.payWith

    local r2 = mortgage(10, { buyer = 2, slug = p.slug, account = 'bank', cycles = 8 })
    check(r2.success == false, 'mortgage: a second signing on the same property should be refused')
    check(Mocks.calls.payWith == paidAfterFirst,
        'mortgage: the second buyer must never pay a deposit')
end

----------------------------------------------------------------------
-- Mortgage commission: debited from the business, paid only on success
----------------------------------------------------------------------
do
    local env = loadHousing()
    local p = seedProperty({ price = 100000 })
    placePed(10, p.door_x, p.door_y, p.door_z)
    placePed(1, p.door_x, p.door_y, p.door_z)
    Mocks.players[10] = { citizenid = 'CID_REALTOR', job = { name = 'realtor', onduty = true } }
    Mocks.players[1] = { citizenid = 'CID_A' }

    local mortgage = RegisteredCallbacks['som-housing:server:mortgage']
    local r = mortgage(10, { buyer = 1, slug = p.slug, account = 'bank', cycles = 8 })
    check(r.success == true, 'mortgage: signing should succeed')
    check(Mocks.calls.businessSpend == 1, 'mortgage: commission must debit the business account')
    check(r.commission > 0, 'mortgage: a successful debit should still pay the realtor')
end

do
    local env = loadHousing()
    local p = seedProperty({ price = 100000 })
    placePed(10, p.door_x, p.door_y, p.door_z)
    placePed(1, p.door_x, p.door_y, p.door_z)
    Mocks.players[10] = { citizenid = 'CID_REALTOR', job = { name = 'realtor', onduty = true } }
    Mocks.players[1] = { citizenid = 'CID_A' }
    Mocks.businessSpendFails = true
    local addMoneyBefore = Mocks.calls.addMoney

    local mortgage = RegisteredCallbacks['som-housing:server:mortgage']
    local r = mortgage(10, { buyer = 1, slug = p.slug, account = 'bank', cycles = 8 })
    check(r.success == true, 'mortgage: signing itself should still succeed even if commission fails')
    check(r.commission == 0, 'mortgage: commission should be reported as 0 when the business debit fails')
    check(Mocks.calls.addMoney == addMoneyBefore,
        'mortgage: the realtor must never be paid when the business debit fails (no minted money)')
end

----------------------------------------------------------------------
print(('%d passed, %d failed'):format(results.pass, results.fail))
os.exit(results.fail == 0 and 0 or 1)
