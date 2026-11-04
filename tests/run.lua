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
    mysql.db.jailSentences = {}
    mysql.db.jailBail = {}
    mysql.db.courtCases = {}
    mysql.db.courtEvents = {}
    mysql.db.courtWarrants = {}
    mysql.db.service = {}
    mysql.db.evidence = {}
    mysql.db.custody = {}
    mysql.db.profiles = {}
    mysql.db.devices = {}
    mysql.db.characters = {}
    mysql.db.contacts = {}
    mysql.db.blocks = {}
    mysql.db.messages = {}
    mysql.db.phoneCalls = {}
    mysql.db.phoneAudit = {}
    mysql.db.notes = {}
    mysql.db.heist = { dongles = {}, runs = {} }
    mysql.db.turf = { zones = {}, events = {}, market = {} }
    mysql.db.whitelist = {}
    mysql.db.staff = { reports = {}, audit = {} }
    mysql.db.gangs = { chars = {}, log = {} }
    mysql.db.vehicles = {}
    mysql.db.social = { handles = {}, posts = {}, likes = {}, reports = {}, adverts = {}, optin = {}, people = {} }
    mysql.db.bills = {}
    mysql.db.orders = {}
    mysql.db.nextId = { properties = 1, owners = 1, finance = 1, jailSentences = 1, jailBail = 1,
                        courtCases = 1, courtEvents = 1, courtWarrants = 1, service = 1, evidence = 1, custody = 1, orders = 1 }
    mysql.fakeNow = nil
end

local function resetMocks()
    ResetHandlers()
    Mocks.calls = { payWith = 0, addMoney = 0, businessSpend = 0, dispatchAlert = 0, businessTransact = 0 }
    Mocks.players = {}
    Mocks.payWithFails = false
    Mocks.businessSpendFails = false
    Mocks.admins = {}
    Mocks.fines = {}
    Mocks.fineFails = false
    Mocks.exported = {}
    Mocks.perks = {}
    Mocks.treasury = 0
    Mocks.apps = {}
    Mocks.jobs = { police = { business = 'lspd' }, mechanic = { business = 'bennys' }, taxi = {}, ambulance = { business = 'ems' } }
    Mocks.businesses = { lspd = { label = 'LSPD' }, bennys = { label = "Benny's" } }
    Mocks.commands = {}
    Mocks.voice = {}
    Mocks.metadataRefused = false
    Mocks.paid = 0
    Mocks.lastPaid = nil
    Mocks.addMoneyFails = false
    Mocks.weapons = {}
    Mocks.clock = 0
    Mocks.downed = {}
    Mocks.inv = {}
    Mocks.invFull = {}
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

local courtEnv

local function loadCourt()
    resetDb()
    resetMocks()
    courtEnv = loader.loadResource(REPO .. 'som-court', {
        'shared/config.lua',
        'server/cases.lua',
        'server/warrants.lua',
        'server/rulings.lua',
    })
    return courtEnv
end

local dispEnv

local function loadDispatch()
    resetDb()
    resetMocks()
    dispEnv = loader.loadResource(REPO .. 'som-dispatch', {
        'shared/config.lua',
        'server/main.lua',
    })
    return dispEnv
end

local hackEnv

local function loadHack()
    resetDb()
    resetMocks()
    hackEnv = loader.loadResource(REPO .. 'som-hack', {
        'shared/config.lua',
        'server/hack.lua',
    })
    return hackEnv
end

local launderEnv

local function loadLaunder()
    resetDb()
    resetMocks()
    launderEnv = loader.loadResource(REPO .. 'som-launder', {
        'shared/config.lua',
        'server/ledger.lua',
        'server/wash.lua',
    })
    return launderEnv
end

local phoneEnv

local function loadPhone()
    resetDb()
    resetMocks()
    phoneEnv = loader.loadResource(REPO .. 'som-phone', {
        'shared/config.lua',
        'server/bank.lua',
        'server/core.lua',
        'server/device.lua',
        'server/apps.lua',
        'server/comms.lua',
        'server/social.lua',
        'server/city.lua',
        'server/main.lua',
    })
    return phoneEnv
end

local groupsEnv

local function loadGroups()
    resetDb()
    resetMocks()
    groupsEnv = loader.loadResource(REPO .. 'som-groups', { 'shared/config.lua', 'server/main.lua' })
    return groupsEnv
end

local evEnv

local function loadEvidence()
    loadCourt()
    evEnv = loader.loadResource(REPO .. 'som-evidence', {
        'shared/config.lua',
        'server/evidence.lua',
        'server/locker.lua',
    })
    return evEnv
end

local function loadJail()
    loadCourt()
    return loader.loadResource(REPO .. 'som-jail', {
        'shared/config.lua',
        'server/jail.lua',
        'server/bail.lua',
        'server/service.lua',
    })
end

local function addCase(overrides)
    local id = mysql.db.nextId.courtCases
    mysql.db.nextId.courtCases = id + 1
    local case = {
        id = id, defendant_cid = 'INMATE', filed_by = 'OFFICER', charges = 'Armed robbery',
        class = 'felony', status = 'convicted', sentence_months = 12, service_tasks = 0, fine = 0,
    }
    for k, v in pairs(overrides or {}) do case[k] = v end
    mysql.db.courtCases[#mysql.db.courtCases + 1] = case
    return case
end

local function setCuffed(source, cuffed)
    Mocks.players[source].metadata = Mocks.players[source].metadata or {}
    Mocks.players[source].metadata.cuffed = cuffed
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
-- som-jail: booking, sweep, abscond, bail
----------------------------------------------------------------------
local function jailScene(months)
    local env = loadJail()
    env.Config.BookCooldown = 0
    Mocks.players[1] = { citizenid = 'OFFICER', job = { name = 'police', onduty = true } }
    Mocks.players[2] = { citizenid = 'INMATE', job = { name = 'unemployed' } }
    placePed(1, 0.0, 0.0, 0.0)
    placePed(2, 1.0, 0.0, 0.0)
    setCuffed(2, true)
    local book = RegisteredCallbacks['som-jail:server:book']
    local res = months and book(1, { target = 2, months = months }) or nil
    return env, book, res
end

local function felonyScene(months)
    local env, book = jailScene()
    local case = addCase({ sentence_months = months or 12 })
    book(1, { target = 2, caseId = case.id })
    return env, book, case
end

do
    local env, book = jailScene()
    check(book(1, { target = 2, months = 0 }).success == false, 'book: 0 months should be refused')
    check(book(1, { target = 2, months = 25 }).success == false, 'book: over maxMonths should be refused')
    check(book(1, { target = 2, months = 'x' }).success == false, 'book: non-numeric months should be refused')
    check(book(1, 'junk').success == false, 'book: a non-table payload should be refused')
    check(#mysql.db.jailSentences == 0, 'book: refused requests must write no sentence')

    Mocks.players[1].job.onduty = false
    check(book(1, { target = 2, months = 3 }).success == false, 'book: an off duty officer should be refused')
    Mocks.players[1].job.onduty = true

    Mocks.players[1].job.name = 'unemployed'
    check(book(1, { target = 2, months = 3 }).success == false, 'book: a non officer should be refused')
    Mocks.players[1].job.name = 'police'

    placePed(2, 50.0, 0.0, 0.0)
    check(book(1, { target = 2, months = 3 }).success == false, 'book: a target out of reach should be refused')
    placePed(2, 1.0, 0.0, 0.0)

    setCuffed(2, false)
    check(book(1, { target = 2, months = 3 }).success == false, 'book: an uncuffed target should be refused')
    setCuffed(2, true)
    check(#mysql.db.jailSentences == 0, 'book: no refusal path may leave a sentence behind')
end

do
    local env, book, res = jailScene(3)
    check(res.success == true, 'book: a valid booking should succeed')
    local s = mysql.db.jailSentences[1]
    check(s and s.status == 'serving' and s.total_seconds == 3 * env.Config.Cell.secondsPerMonth,
        'book: sentence length must be derived server side from months')
    check(Mocks.players[2].metadata.cuffed == false, 'book: booking should clear the cuffed flag')

    setCuffed(2, true)
    check(book(1, { target = 2, months = 3 }).success == false, 'book: an inmate already serving cannot be booked twice')
    check(#mysql.db.jailSentences == 1, 'book: double booking must not add a second row')
end

do
    local env = jailScene(3)
    local s = mysql.db.jailSentences[1]
    mysql.fakeNow = s.booked_at + s.total_seconds - 1
    placePed(2, env.Config.Cell.yard.x, env.Config.Cell.yard.y, env.Config.Cell.yard.z)
    env.Jail.Sweep()
    check(s.status == 'serving', 'sweep: a sentence not yet served stays serving')

    mysql.fakeNow = s.booked_at + s.total_seconds
    env.Jail.Sweep()
    check(s.status == 'released', 'sweep: a served sentence is released')
end

do
    local env, book = jailScene(3)
    local s = mysql.db.jailSentences[1]
    placePed(2, 0.0, 0.0, 0.0)
    env.Jail.Sweep()
    check(s.status == 'absconded', 'sweep: leaving the yard radius flags the sentence absconded')
    check(Mocks.calls.dispatchAlert == 1 and Mocks.lastAlertType == env.Config.AbscondAlert,
        'sweep: an absconder raises exactly one dispatch alert')
    env.Jail.Sweep()
    check(Mocks.calls.dispatchAlert == 1, 'sweep: an absconded sentence is not alerted again')

    setCuffed(2, true)
    check(book(1, { target = 2, months = 2 }).success == true, 'book: an absconder can be booked again by an officer')
end

do
    local env, book = jailScene(2)
    local quote = RegisteredCallbacks['som-jail:server:bailQuote']
    local request = RegisteredCallbacks['som-jail:server:requestBail']
    check(quote(2).success == false, 'bail: a sentence under the felony threshold is not bailable')
    check(request(2).success == false and Mocks.calls.payWith == 0,
        'bail: an ineligible request must never charge')
end

do
    local env, book = felonyScene(12)
    local s = mysql.db.jailSentences[1]
    local cfg = env.Config
    local quote = RegisteredCallbacks['som-jail:server:bailQuote']
    local request = RegisteredCallbacks['som-jail:server:requestBail']

    local q = quote(2)
    local expected = math.max(cfg.Bail.minAmount, s.total_seconds * cfg.Bail.rateMultiplier)
    check(q.success and q.amount == expected, 'bail: the quote is derived from time remaining on the server')

    Mocks.payWithFails = true
    check(request(2).success == false, 'bail: a failed payment refuses bail')
    check(s.status == 'serving' and #mysql.db.jailBail == 0,
        'bail: a failed payment leaves the sentence serving and writes no bail row')
    Mocks.payWithFails = false

    local r = request(2)
    check(r.success == true and r.amount == expected, 'bail: a valid request posts at the server amount')
    check(s.status == 'bailed' and mysql.db.jailBail[1].status == 'posted', 'bail: sentence is bailed, bail row posted')
    check(Mocks.calls.payWith == 2 and Mocks.calls.businessTransact == 1
        and Mocks.lastTransact.name == cfg.Business and Mocks.lastTransact.amount == expected,
        'bail: the money is credited to the department exactly once')

    check(request(2).success == false and Mocks.calls.payWith == 2,
        'bail: a second request after release must not charge again')

    mysql.fakeNow = mysql.db.jailBail[1].appeal_due_at - 1
    env.Bail.Sweep()
    check(mysql.db.jailBail[1].status == 'posted', 'bail sweep: inside the appeal window the bail stays posted')
    mysql.fakeNow = mysql.db.jailBail[1].appeal_due_at
    env.Bail.Sweep()
    check(mysql.db.jailBail[1].status == 'cleared', 'bail sweep: after the appeal window the bail is cleared')
end

do
    local env, book = felonyScene(12)
    local request = RegisteredCallbacks['som-jail:server:requestBail']
    local s = mysql.db.jailSentences[1]
    env.Jail.Claim(s, 'released', nil)
    check(request(2).success == false and Mocks.calls.payWith == 0,
        'bail: a sentence the sweep already released must not be charged for')
end

do
    local env, book = felonyScene(12)
    local s = mysql.db.jailSentences[1]
    local request = RegisteredCallbacks['som-jail:server:requestBail']
    request(2)
    setCuffed(2, true)
    mysql.fakeNow = nil
    check(book(1, { target = 2, months = 3 }).success == true, 'book: re-arrest after bail should succeed')
    check(mysql.db.jailBail[1].status == 'forfeited', 'book: re-arrest inside the window forfeits the posted bail')
end

do
    local env, book = jailScene(3)
    local s = mysql.db.jailSentences[1]
    local status = RegisteredCallbacks['som-jail:server:myStatus']
    local yard = env.Config.Cell.yard

    placePed(2, yard.x, yard.y, yard.z)
    check(status(2).serving == true and status(2).spawn == nil, 'relog: an inmate inside the yard is not moved')
    placePed(2, 0.0, 0.0, 0.0)
    check(status(2).serving == true and status(2).spawn ~= nil, 'relog: an inmate outside the yard is sent back to a cell')

    Mocks.downed[2] = true
    env.Jail.Sweep()
    check(s.status == 'serving' and Mocks.calls.dispatchAlert == 0,
        'sweep: a downed inmate outside the yard is not flagged absconded')
    Mocks.downed[2] = nil

    local events = {}
    local realTrigger = _G.TriggerClientEvent
    _G.TriggerClientEvent = function(name, src) events[#events + 1] = name end
    env.Jail.ReturnToYard(2)
    check(events[#events] == 'som-jail:client:booked', 'revive: an inmate respawned outside the yard is returned to a cell')
    placePed(2, yard.x, yard.y, yard.z)
    events = {}
    env.Jail.ReturnToYard(2)
    check(#events == 0, 'revive: an inmate already in the yard is not moved')
    _G.TriggerClientEvent = realTrigger
end

do
    local env, book = jailScene(3)
    local s = mysql.db.jailSentences[1]
    local status = RegisteredCallbacks['som-jail:server:myStatus']
    local yard = env.Config.Cell.yard
    placePed(2, yard.x, yard.y, yard.z)

    local player = Mocks.players[2]
    Mocks.players[2] = nil
    mysql.fakeNow = s.booked_at + s.total_seconds
    env.Jail.Sweep()
    check(s.status == 'released' and s.release_pending == 1, 'offline release: the sentence ends and is marked pending delivery')

    Mocks.players[2] = player
    check(status(2).freedom ~= nil, 'offline release: the next login is sent to the gate')
    check(status(2).freedom == nil, 'offline release: the gate teleport is delivered only once')
end

do
    local env, book = jailScene()
    Mocks.inv[2] = {
        { name = 'money', count = 500, slot = 1 },
        { name = 'phone', count = 1, slot = 2 },
    }
    book(1, { target = 2, months = 3 })
    local stash = Mocks.inv['jail_INMATE']
    local function has(inv, name)
        for _, item in pairs(inv or {}) do if item.name == name then return true end end
        return false
    end
    check(has(stash, 'money') and not has(Mocks.inv[2], 'money'), 'property: cash is held in the jail stash on booking')
    check(has(Mocks.inv[2], 'phone') and not has(stash, 'phone'), 'property: kept items stay with the inmate')

    env.Jail.Release(mysql.db.jailSentences[1], 'released', nil)
    check(has(Mocks.inv[2], 'money') and not has(Mocks.inv['jail_INMATE'], 'money'),
        'property: held items are returned when the inmate is released while online')
end

do
    local env, book = jailScene()
    Mocks.inv[2] = { { name = 'money', count = 500, slot = 1 } }
    Mocks.invFull['jail_INMATE'] = true
    check(book(1, { target = 2, months = 3 }).success == true, 'property: a full stash does not block the booking')
    check(Mocks.inv[2][1] ~= nil, 'property: an item that cannot be held stays with the inmate')
end

do
    local env, book = jailScene(3)
    local s = mysql.db.jailSentences[1]
    local ok, err = env.Jail.Unjail(1, 2)
    check(ok == false and err == 'no permission' and s.status == 'serving', 'unjail: a non admin is refused')
    Mocks.admins[1] = true
    check(env.Jail.Unjail(1, 2) == true and s.status == 'released' and s.released_by == 'OFFICER',
        'unjail: an admin releases a serving inmate')
    ok, err = env.Jail.Unjail(0, 2)
    check(ok == false and err == 'they are not serving', 'unjail: console cannot release someone who is not serving')
    check(select(2, env.Jail.Unjail(0, 99)) == 'they are not here', 'unjail: an unknown target is refused')
end

do
    local env, book = jailScene()
    env.Config.BookCooldown = 60
    Mocks.players[3] = { citizenid = 'INMATE2', job = { name = 'unemployed' } }
    placePed(3, 1.0, 0.0, 0.0)
    setCuffed(3, true)
    check(book(1, { target = 2, months = 3 }).success == true, 'cooldown: the first booking goes through')
    check(book(1, { target = 3, months = 3 }).success == false, 'cooldown: a second booking inside the window is refused')
    check(#mysql.db.jailSentences == 1, 'cooldown: a refused booking writes nothing')
end

----------------------------------------------------------------------
-- som-court: filing, state machine, rulings, warrants
----------------------------------------------------------------------
local function courtScene()
    local env = loadCourt()
    mysql.fakeNow = os.time()
    Mocks.players[1] = { citizenid = 'OFFICER', job = { name = 'police', onduty = true, grade = 2 } }
    Mocks.players[2] = { citizenid = 'INMATE', job = { name = 'unemployed' } }
    Mocks.players[10] = { citizenid = 'JUDGE', job = { name = 'judge', onduty = true, grade = 2 } }
    Mocks.players[11] = { citizenid = 'DA', job = { name = 'prosecutor', onduty = true, grade = 1 } }
    Mocks.players[12] = { citizenid = 'PD', job = { name = 'defender', onduty = true, grade = 0 } }
    placePed(1, 0.0, 0.0, 0.0)
    placePed(2, 1.0, 0.0, 0.0)
    return env
end

local function cb(name) return RegisteredCallbacks['som-court:server:' .. name] end

-- Files a case and walks it to a hearing that is due now.
local function dueCase(class)
    local filed = cb('file')(1, { target = 2, class = class or 'misdemeanor', charges = 'Assault' })
    cb('accept')(11, filed.id)
    cb('schedule')(10, filed.id, 1)
    local case = mysql.db.courtCases[filed.id]
    mysql.fakeNow = case.hearing_at
    return case
end

do
    courtScene()
    local file = cb('file')
    local ok = { target = 2, class = 'felony', charges = 'Armed robbery' }
    check(file(1, 'junk').success == false, 'file: a non table payload is refused')
    check(file(2, ok).success == false, 'file: a civilian cannot file')
    Mocks.players[1].job.onduty = false
    check(file(1, ok).success == false, 'file: an off duty officer cannot file')
    Mocks.players[1].job.onduty = true
    check(file(1, { target = 1, class = 'felony', charges = 'x never' }).success == false, 'file: an officer cannot file on themselves')
    placePed(2, 90.0, 0.0, 0.0)
    check(file(1, ok).success == false, 'file: a target out of reach is refused')
    placePed(2, 1.0, 0.0, 0.0)
    check(file(1, { target = 2, class = 'treason', charges = 'Armed robbery' }).success == false, 'file: an unknown class is refused')
    check(file(1, { target = 2, class = 'felony', charges = 'x' }).success == false, 'file: empty charges are refused')
    check(#mysql.db.courtCases == 0, 'file: refusals write nothing')

    check(file(1, ok).success == true and mysql.db.courtCases[1].status == 'filed', 'file: a valid case is filed')
    check(#mysql.db.courtEvents == 1, 'file: filing leaves an audit event')
    file(1, ok); file(1, ok)
    check(file(1, ok).success == false and #mysql.db.courtCases == 3, 'file: a fourth open case is refused')
end

do
    courtScene()
    local filed = cb('file')(1, { target = 2, class = 'misdemeanor', charges = 'Assault' })
    check(cb('accept')(10, filed.id).success == false, 'accept: a judge cannot accept for the prosecution')
    check(cb('accept')(11, filed.id).success == true, 'accept: a prosecutor accepts a filed case')
    check(cb('accept')(11, filed.id).success == false, 'accept: a second accept loses the race')
    check(cb('accept')(11, 999).success == false, 'accept: an unknown case is refused')
    check(cb('schedule')(10, filed.id, 99).success == false, 'schedule: an unlisted hearing time is refused')
    check(cb('schedule')(11, filed.id, 1).success == false, 'schedule: a prosecutor cannot schedule')
    check(cb('schedule')(10, filed.id, 1).success == true and mysql.db.courtCases[1].hearing_at ~= nil,
        'schedule: a judge sets the hearing')
    check(cb('schedule')(10, filed.id, 1).success == false, 'schedule: a case is scheduled once')
    check(cb('defend')(12, filed.id).success == true and cb('defend')(12, filed.id).success == false,
        'defend: a case takes one defender')
end

do
    courtScene()
    local case = dueCase('misdemeanor')
    mysql.fakeNow = case.hearing_at - 1
    local rule = cb('rule')
    check(rule(10, { id = case.id, guilty = true, months = 1, fine = 0 }).success == false, 'rule: no ruling before the hearing')
    mysql.fakeNow = case.hearing_at
    check(rule(11, { id = case.id, guilty = true, months = 1, fine = 0 }).success == false, 'rule: a prosecutor cannot rule')
    check(rule(10, { id = case.id, guilty = true, months = 7, fine = 0 }).success == false, 'rule: months above the class cap are refused')
    check(rule(10, { id = case.id, guilty = true, months = 1, fine = 15001 }).success == false, 'rule: a fine above the class cap is refused')
    check(rule(10, { id = case.id, guilty = true, months = -1, fine = 0 }).success == false, 'rule: negative months are refused')
    check(rule(10, { id = case.id, guilty = true, months = 1, fine = 100, bail = 5000 }).success == false, 'rule: bail on a non felony is refused')
    local defendant = Mocks.players[2]
    Mocks.players[2] = nil
    check(rule(10, { id = case.id, guilty = true, months = 1, fine = 100 }).success == false,
        'rule: a fine needs the defendant present')
    check(case.status == 'scheduled', 'rule: a refused ruling leaves the case scheduled')
    Mocks.players[2] = defendant

    Mocks.fineFails = true
    check(rule(10, { id = case.id, guilty = true, months = 1, fine = 100 }).success == false and case.status == 'scheduled',
        'rule: a failed fine rolls the conviction back')
    Mocks.fineFails = false
    local r = rule(10, { id = case.id, guilty = true, months = 2, fine = 100 })
    check(r.success == true and case.status == 'convicted' and case.sentence_months == 2, 'rule: a guilty ruling convicts')
    check(#Mocks.fines == 1 and Mocks.fines[1].amount == 100, 'rule: the fine is issued once through som-economy')
    check(rule(10, { id = case.id, guilty = false }).success == false, 'rule: a decided case cannot be ruled on again')
end

do
    courtScene()
    local case = dueCase('infraction')
    check(cb('rule')(10, { id = case.id, guilty = true, months = 1, fine = 0 }).success == false, 'rule: an infraction carries no custody')
    check(cb('rule')(10, { id = case.id, guilty = true, months = 0, fine = 0 }).success == true and case.status == 'sentenced',
        'rule: a case with no custody is complete when ruled')
end

do
    courtScene()
    local case = dueCase('felony')
    Mocks.players[10].job.grade = 1
    check(cb('rule')(10, { id = case.id, guilty = false }).success == false, 'rule: a felony needs a senior judge')
    Mocks.players[10].job.grade = 2
    check(cb('rule')(10, { id = case.id, guilty = false }).success == true and case.status == 'acquitted', 'rule: not guilty acquits')
end

do
    courtScene()
    local case = dueCase('felony')
    cb('rule')(10, { id = case.id, guilty = true, months = 12, fine = 0, bail = 1 })
    check(case.status == 'scheduled', 'rule: bail below the minimum is refused')
    cb('rule')(10, { id = case.id, guilty = true, months = 12, fine = 0, bail = 50000 })
    check(case.status == 'convicted' and case.bail_amount == 50000, 'rule: a felony ruling can carry bail')
    check(cb('amend')(10, case.id, 20).success == false and case.sentence_months == 12, 'amend: a sentence cannot be raised')
    check(cb('amend')(10, case.id, 6).success == true and case.sentence_months == 6, 'amend: a sentence can be lowered')
    check(cb('dismiss')(10, case.id).success == true and case.status == 'dismissed', 'dismiss: a judge can vacate a conviction')
    check(cb('dismiss')(10, case.id).success == false, 'dismiss: a terminal case cannot be dismissed again')
end

do
    local env = courtScene()
    local case = dueCase('felony')
    check(cb('setBail')(10, case.id, 100).success == false, 'setBail: below the minimum is refused')
    check(cb('setBail')(10, case.id, 30000).success == true and case.bail_amount == 30000, 'setBail: a judge sets bail on an open felony')

    mysql.fakeNow = case.hearing_at + 60 * 10
    check(cb('failureToAppear')(10, case.id).success == false, 'failureToAppear: refused inside the grace period')
    mysql.fakeNow = case.hearing_at + 60 * (env.Config.FailureGraceMinutes + 1)
    check(cb('failureToAppear')(10, case.id).success == true and #mysql.db.courtWarrants == 1, 'failureToAppear: issues a warrant')
    check(cb('failureToAppear')(10, case.id).success == false and #mysql.db.courtWarrants == 1,
        'failureToAppear: one warrant per case')
    check(#env.Warrants.Active('INMATE') == 1, 'warrants: the new warrant is active')
    mysql.fakeNow = mysql.fakeNow + env.Config.WarrantHours * 3600
    check(#env.Warrants.Active('INMATE') == 0, 'warrants: an expired warrant is not active even before the sweep')
    env.Warrants.Sweep()
    check(mysql.db.courtWarrants[1].status == 'expired', 'warrants: the sweep tidies the status')
end

do
    courtScene()
    local own = cb('file')(1, { target = 2, class = 'felony', charges = 'Armed robbery' })
    check(#cb('docket')(11).cases == 1, 'docket: a prosecutor sees filed cases')
    check(#cb('docket')(10).cases == 0, 'docket: a judge does not see unaccepted cases')
    check(#cb('docket')(12).cases == 1, 'docket: a defender sees unassigned cases')
    check(#cb('docket')(1).cases == 1, 'docket: an officer sees their own filings')
    check(cb('docket')(2).success == false, 'docket: a civilian has no docket')
    check(#cb('myCases')(2).cases == 1 and #cb('myCases')(1).cases == 0, 'myCases: a defendant sees only their own')
end

----------------------------------------------------------------------
-- som-jail carrying out the court: custody, remand, bail, warrants
----------------------------------------------------------------------
do
    local env, book = jailScene()
    mysql.fakeNow = nil
    check(book(1, { target = 2, months = 4 }).success == false, 'book: a direct booking above the cap is refused')
    local convicted = addCase({ sentence_months = 8 })
    check(book(1, { target = 2, caseId = 999 }).success == false, 'book: an unknown case is refused')
    local r = book(1, { target = 2, caseId = convicted.id, months = 1 })
    local s = mysql.db.jailSentences[1]
    check(r.success == true and s.total_seconds == 8 * env.Config.Cell.secondsPerMonth,
        'book: custody length comes from the case, not the client')
    check(convicted.status == 'sentenced' and s.case_id == convicted.id, 'book: the case is claimed and linked')
    setCuffed(2, true)
    s.status = 'released'
    check(book(1, { target = 2, caseId = convicted.id }).success == false, 'book: a case is carried out only once')
end

do
    local env, book = jailScene()
    local convicted = addCase({ sentence_months = 8 })
    local real = MySQL.insert.await
    MySQL.insert = { await = function(q, p)
        if q:find('som_jail_sentences', 1, true) then error('db down') end
        return real(q, p)
    end }
    check(book(1, { target = 2, caseId = convicted.id }).success == false, 'book: a failed insert refuses the booking')
    MySQL.insert = { await = real }
    check(convicted.status == 'convicted', 'book: a failed insert gives the case back')
end

do
    local env, book = jailScene()
    local open = addCase({ status = 'accepted', sentence_months = 0 })
    local r = book(1, { target = 2, caseId = open.id })
    local s = mysql.db.jailSentences[1]
    check(r.success == true and r.remand == true and s.kind == 'remand'
        and s.total_seconds == env.Config.Jail.remandHours * 3600, 'remand: an open case holds a suspect for a limited time')
    check(open.status == 'accepted', 'remand: holding someone does not move the case')

    local quote = RegisteredCallbacks['som-jail:server:bailQuote']
    check(quote(2).success == false, 'remand bail: refused until a judge sets bail')
    open.bail_amount = 40000
    check(quote(2).success == true and quote(2).amount == 40000, 'remand bail: the judge set amount is charged')
    open.class = 'misdemeanor'
    check(quote(2).success == false, 'remand bail: a misdemeanor has no bail')

    mysql.fakeNow = s.booked_at + s.total_seconds
    env.Jail.Sweep()
    check(s.status == 'released', 'remand: it ends on its own when the window closes')
end

do
    local env, book = jailScene()
    courtEnv.Warrants.Issue('INMATE', nil, 'Test warrant', 'JUDGE')
    local opts = RegisteredCallbacks['som-jail:server:bookOptions'](1, 2)
    check(opts.success and opts.warrants == 1 and opts.directMax == env.Config.Jail.directMaxMonths,
        'bookOptions: the officer is told about an active warrant')
    book(1, { target = 2, months = 2 })
    check(mysql.db.courtWarrants[1].status == 'served', 'book: booking serves the warrant')
end

----------------------------------------------------------------------
-- Community service
----------------------------------------------------------------------
local function svcScene()
    local env = jailScene()
    mysql.fakeNow = os.time()
    env.Config.BookCooldown = 0
    return env
end

local function startService(env, tasks)
    return env.Service.IssueByOfficer(1, 2, tasks or 3, true)
end

local function workTask(env, spotId)
    local spot = env.Config.Service.spots[spotId or 1]
    placePed(2, spot.coords.x, spot.coords.y, spot.coords.z)
    local began = RegisteredCallbacks['som-jail:server:svc:begin'](2, spot.id)
    if began.success then Mocks.clock = Mocks.clock + began.duration end
    return began, RegisteredCallbacks['som-jail:server:svc:finish'](2)
end

do
    local env = svcScene()
    Mocks.inv[2] = { { name = 'money', count = 500, slot = 1 }, { name = 'phone', count = 1, slot = 2 } }
    local limit = env.Config.Service.officerMaxTasks
    check(select(1, env.Service.IssueByOfficer(2, 2, 3, true)) == false, 'service: a civilian cannot order service')
    Mocks.players[1].job.onduty = false
    check(select(1, env.Service.IssueByOfficer(1, 2, 3, true)) == false, 'service: an off duty officer cannot')
    Mocks.players[1].job.onduty = true
    check(select(1, startService(env, 0)) == false and select(1, startService(env, limit + 1)) == false,
        'service: task counts outside what an officer may order are refused')
    check(select(1, env.Service.IssueByOfficer(1, 1, 3, true)) == false, 'service: an officer cannot order their own')
    placePed(2, 90.0, 0.0, 0.0)
    check(select(1, startService(env)) == false, 'service: a target out of reach is refused')
    check(env.Service.IssueByOfficer(1, 2, 3, false) == true, 'service: the MDT path needs no reach')
    placePed(2, 1.0, 0.0, 0.0)
    env.Service.Cancel('INMATE')

    check(startService(env, 3) == true, 'service: a valid order starts service')
    check(mysql.db.service[2].tasks_total == 3 and mysql.db.service[2].status == 'active', 'service: the row records the tasks')
    local held, kept = false, false
    for _, item in pairs(Mocks.inv['jail_INMATE'] or {}) do held = held or item.name == 'money' end
    for _, item in pairs(Mocks.inv[2] or {}) do kept = kept or item.name == 'phone' end
    check(held and kept, 'service: items are held except phone and ID')
    check(select(1, startService(env, 3)) == false, 'service: a second order while working is refused')
end

do
    local env = svcScene()
    local begin = RegisteredCallbacks['som-jail:server:svc:begin']
    local finish = RegisteredCallbacks['som-jail:server:svc:finish']
    check(begin(2, 1).success == false, 'task: no service, no task')
    startService(env, 3)
    check(begin(2, 99).success == false, 'task: an unknown spot is refused')
    placePed(2, 500.0, 0.0, 0.0)
    check(begin(2, 1).success == false, 'task: too far from the spot is refused')
    local spot = env.Config.Service.spots[1]
    placePed(2, spot.coords.x, spot.coords.y, spot.coords.z)
    Mocks.downed[2] = true
    check(begin(2, 1).success == false, 'task: a downed worker cannot work')
    Mocks.downed[2] = nil
    check(finish(2).success == false, 'task: finishing without starting is refused')

    local r = begin(2, 1)
    check(r.success and r.duration == env.Config.Service.kinds[spot.kind].duration, 'task: the server sets the duration')
    check(finish(2).success == false and mysql.db.service[1].tasks_done == 0, 'task: an instant finish is refused')
    check(finish(2).success == false, 'task: a refused finish also spends the token')

    local _, done = workTask(env, 1)
    check(done.success and mysql.db.service[1].tasks_done == 1 and done.remaining == 2, 'task: a real task counts once')
    check(select(1, workTask(env, 1)).success == false, 'task: the same spot twice in a row is refused')
    local _, quick = workTask(env, 2)
    check(quick.success == false and mysql.db.service[1].tasks_done == 1, 'task: a task inside the minimum gap does not count')
    mysql.fakeNow = mysql.fakeNow + env.Config.Service.minGap + 1
    local _, second = workTask(env, 3)
    check(second.success == true and mysql.db.service[1].tasks_done == 2, 'task: a task after the gap counts')

    mysql.fakeNow = mysql.fakeNow + env.Config.Service.minGap + 1
    local _, last = workTask(env, 1)
    check(last.done == true and mysql.db.service[1].status == 'completed', 'task: the last task completes the service')
    local back = false
    for _, item in pairs(Mocks.inv[2] or {}) do back = back or item.name == 'money' end
    check(next(Mocks.inv['jail_INMATE'] or {}) == nil or back, 'task: completion returns held items')
    check(begin(2, 1).success == false, 'task: nothing to do once complete')
end

do
    local env = svcScene()
    startService(env, 5)
    local row = mysql.db.service[1]
    local zone = env.Config.Service.zone.center
    placePed(2, zone.x, zone.y, zone.z)
    env.Service.Sweep()
    check(row.tasks_total == 5, 'sweep: a worker in the zone is left alone')

    placePed(2, 900.0, 0.0, 0.0)
    Mocks.downed[2] = true
    env.Service.Sweep()
    check(row.tasks_total == 5, 'sweep: a downed worker is not penalised')
    Mocks.downed[2] = nil

    env.Service.Sweep()
    check(row.tasks_total == 5 + env.Config.Service.escapePenalty and row.strikes == 1, 'sweep: leaving the zone adds tasks')
    env.Service.Sweep()
    check(row.strikes == 1, 'sweep: penalties are rate limited')

    for _ = 1, env.Config.Service.maxStrikes do
        mysql.fakeNow = mysql.fakeNow + env.Config.Service.penaltyGap + 1
        env.Service.Sweep()
    end
    check(row.status == 'absconded' and Mocks.calls.dispatchAlert == 1, 'sweep: repeated escapes abscond and alert police')
    check(row.tasks_total <= env.Config.Service.maxTasks, 'sweep: the task count stays under the cap')
end

do
    local env, book = svcScene()
    local case = addCase({ class = 'misdemeanor', sentence_months = 0, service_tasks = 8 })
    book = RegisteredCallbacks['som-jail:server:book']
    local r = book(1, { target = 2, caseId = case.id })
    check(r.success == true and r.service == 8 and #mysql.db.jailSentences == 0, 'book: a service sentence starts service, not jail')
    check(case.status == 'sentenced' and mysql.db.service[1].tasks_total == 8, 'book: the case is claimed and the tasks come from it')

    setCuffed(2, true)
    local again = addCase({ class = 'misdemeanor', sentence_months = 0, service_tasks = 4 })
    check(book(1, { target = 2, caseId = again.id }).success == false and again.status == 'convicted',
        'book: service already running refuses another and gives the case back')

    setCuffed(2, true)
    check(book(1, { target = 2, months = 2 }).success == true and mysql.db.service[1].status == 'cancelled',
        'book: jailing someone cancels their service')
end

do
    local env = svcScene()
    startService(env, 4)
    local status = RegisteredCallbacks['som-jail:server:myStatus']
    placePed(2, 900.0, 0.0, 0.0)
    local r = status(2)
    check(r.service and r.service.remaining == 4 and r.spawn ~= nil, 'relog: a worker outside the zone is sent back with the count')

    local legacy = RegisteredEvents['qb-communityservice:server:StartCommunityService']
    env.Service.Cancel('INMATE')
    _G.source = 2
    legacy(2, 3)
    check(mysql.db.service[#mysql.db.service].status == 'cancelled', 'legacy: a civilian forging the MDT event does nothing')
    _G.source = 1
    legacy(2, 3)
    check(mysql.db.service[#mysql.db.service].status == 'active', 'legacy: an on duty officer can use the MDT event')
    _G.source = 1
    env.Service.Cancel('INMATE')
    legacy(2, 999)
    check(mysql.db.service[#mysql.db.service].status == 'cancelled', 'legacy: an oversized order is refused')
    _G.source = nil

    placePed(2, 1.0, 0.0, 0.0)
    startService(env, 2)
    check(select(1, env.Service.End(2, 2)) == false, 'endservice: a non admin is refused')
    Mocks.admins[1] = true
    check(env.Service.End(1, 2) == true and mysql.db.service[#mysql.db.service].status == 'cancelled', 'endservice: an admin ends it')
    check(select(1, env.Service.End(0, 2)) == false, 'endservice: nothing to end is reported')
end

do
    courtScene()
    local rule = cb('rule')
    local mis = dueCase('misdemeanor')
    check(rule(10, { id = mis.id, guilty = true, months = 1, tasks = 5 }).success == false, 'rule: custody and service together are refused')
    check(rule(10, { id = mis.id, guilty = true, months = 0, fine = 0, tasks = 41 }).success == false, 'rule: tasks above the class cap are refused')
    check(rule(10, { id = mis.id, guilty = true, months = 0, fine = 0, tasks = 10 }).success == true and mis.status == 'convicted' and mis.service_tasks == 10,
        'rule: a service sentence convicts and keeps the tasks')
    local fel = dueCase('felony')
    check(rule(10, { id = fel.id, guilty = true, months = 0, fine = 0, tasks = 1 }).success == false, 'rule: a felony cannot be sentenced to service')
end

----------------------------------------------------------------------
-- som-evidence: traces, collection, custody, lab, case links
----------------------------------------------------------------------
local function evScene()
    local env = loadEvidence()
    mysql.fakeNow = os.time()
    env.Config.Create.casingGap = 0
    env.Config.Scan.gap = 0
    env.Config.Collect.gap = 0
    Mocks.players[1] = { citizenid = 'OFFICER', job = { name = 'police', onduty = true, grade = 2 } }
    Mocks.players[2] = { citizenid = 'SUSPECT', job = { name = 'unemployed' } }
    Mocks.players[3] = { citizenid = 'OFFICER2', job = { name = 'police', onduty = true, grade = 2 } }
    placePed(1, 0.0, 0.0, 0.0)
    placePed(2, 1.0, 0.0, 0.0)
    placePed(3, 1.0, 1.0, 0.0)
    Mocks.inv[1] = {
        { name = 'empty_evidence_bag', count = 1, slot = 1 },
        { name = 'empty_evidence_bag', count = 1, slot = 2 },
        { name = 'empty_evidence_bag', count = 1, slot = 3 },
    }
    Mocks.inv[3] = { { name = 'empty_evidence_bag', count = 1, slot = 1 } }
    return env
end

local function ev(name, ...) return RegisteredCallbacks['som-evidence:server:' .. name](...) end
local function crime(source, alert) Handlers['som:server:crimeReported'](source, alert) end
local function shoot(serial)
    Mocks.weapons[2] = { name = 'WEAPON_PISTOL', metadata = { serial = serial or 'S-100' } }
    crime(2, 'shotsFired')
end
local function bagsFor(source, id)
    local n = 0
    for _, item in pairs(Mocks.inv[source] or {}) do
        if item.name == 'filled_evidence_bag' and item.metadata and item.metadata.evidence_id == id then n = n + 1 end
    end
    return n
end
local function atLocker(env, source)
    local at = env.Config.Stations.mrpd.locker
    placePed(source, at.x, at.y, at.z)
end
local function atLab(env, source)
    local at = env.Config.Stations.mrpd.lab
    placePed(source, at.x, at.y, at.z)
end

do
    local env = evScene()
    crime(2, 'shotsFired')
    check(#mysql.db.evidence == 0, 'traces: a shot with no weapon in hand leaves no casing')

    shoot('S-100')
    local casing = mysql.db.evidence[1]
    check(casing and casing.kind == 'casing' and casing.weapon_serial == 'S-100' and casing.status == 'scene',
        'traces: a shot with a weapon drops a casing carrying the serial')
    check(casing.x == 1.0 and casing.source_cid == 'SUSPECT', 'traces: the position is the server position')

    for _ = 1, 10 do shoot('S-100') end
    check(#mysql.db.evidence == env.Config.Create.areaCap, 'traces: casings in one area are capped per shooter')

    env.Config.Create.casingGap = 60
    placePed(2, 500.0, 0.0, 0.0)
    shoot('S-100')
    check(#mysql.db.evidence == env.Config.Create.areaCap, 'traces: casings from one shooter are rate limited')
    env.Config.Create.casingGap = 0
    shoot('S-100')
    check(#mysql.db.evidence == env.Config.Create.areaCap + 1, 'traces: a shooter elsewhere is not held to the old area cap')

    local before = #mysql.db.evidence
    Handlers['som:server:playerDowned'](2, 'SUSPECT')
    crime(2, 'vehicleTheft')
    check(#mysql.db.evidence == before + 2 and mysql.db.evidence[before + 1].kind == 'blood'
        and mysql.db.evidence[before + 2].kind == 'fingerprint', 'traces: being downed leaves blood and car theft a fingerprint')
    crime(2, 'meleeAttack')
    check(#mysql.db.evidence == before + 2, 'traces: other crimes leave nothing')
end

do
    local env = evScene()
    shoot('S-100')
    placePed(2, 300.0, 0.0, 0.0)
    shoot('S-200')
    check(ev('scan', 2).success == false, 'scan: a civilian cannot scan')
    local scan = ev('scan', 1)
    check(scan.success and #scan.evidence == 1 and scan.evidence[1].label == 'Bullet casing', 'scan: an officer sees only nearby traces')
    env.Config.Scan.gap = 60
    ev('scan', 1)
    check(ev('scan', 1).success == false, 'scan: scanning is rate limited')
end

do
    local env = evScene()
    shoot('S-100')
    local id = mysql.db.evidence[1].id
    check(ev('collect', 2, id).success == false, 'collect: a civilian cannot collect')
    Mocks.players[1].job.onduty = false
    check(ev('collect', 1, id).success == false, 'collect: an off duty officer cannot collect')
    Mocks.players[1].job.onduty = true
    check(ev('collect', 1, 999).success == false and ev('collect', 1, 'x').success == false, 'collect: unknown ids are refused')
    placePed(1, 50.0, 0.0, 0.0)
    check(ev('collect', 1, id).success == false and mysql.db.evidence[1].status == 'scene', 'collect: out of reach is refused')
    placePed(1, 0.0, 0.0, 0.0)

    Mocks.inv[3] = {}
    placePed(3, 1.0, 1.0, 0.0)
    check(ev('collect', 3, id).success == false and mysql.db.evidence[1].status == 'scene',
        'collect: no empty bag refuses and leaves the trace on the ground')

    Mocks.invFull[1] = true
    check(ev('collect', 1, id).success == false and mysql.db.evidence[1].status == 'scene', 'collect: a full pack gives the claim back')
    local bags = 0
    for _, item in pairs(Mocks.inv[1]) do if item.name == 'empty_evidence_bag' then bags = bags + 1 end end
    check(bags == 3, 'collect: a full pack keeps the empty bag')
    Mocks.invFull[1] = nil

    check(ev('collect', 1, id).success == true and bagsFor(1, id) == 1, 'collect: an officer bags a trace, the bag carries only the id')
    check(mysql.db.evidence[1].status == 'collected' and mysql.db.evidence[1].holder_cid == 'OFFICER', 'collect: the record names the holder')
    check(#mysql.db.custody == 1 and mysql.db.custody[1].action == 'collected', 'collect: custody records it')
    check(ev('collect', 1, id).success == false, 'collect: a second officer cannot take a collected trace')

    shoot('S-100')
    local gone = mysql.db.evidence[2]
    gone.expires_at = mysql.fakeNow - 1
    check(ev('collect', 1, gone.id).success == false, 'collect: a faded trace is gone')
    env.Evidence.Sweep()
    check(gone.status == 'destroyed', 'collect: the sweep tidies faded traces')
end

do
    local env = evScene()
    shoot('S-100')
    local id = mysql.db.evidence[1].id
    ev('collect', 1, id)
    atLocker(env, 1)

    check(ev('store', 1, 'nowhere', id).success == false, 'store: an unknown station is refused')
    check(ev('store', 3, 'mrpd', id).success == false, 'store: someone without the bag cannot lock it up')
    check(ev('store', 1, 'mrpd', 999).success == false, 'store: a bag for nothing is refused')
    mysql.db.evidence[1].holder_cid = 'OFFICER2'
    check(ev('store', 1, 'mrpd', id).success == false and mysql.db.evidence[1].status == 'collected',
        'store: evidence held by someone else cannot be locked up by the bag alone')
    mysql.db.evidence[1].holder_cid = 'OFFICER'

    placePed(1, 90.0, 0.0, 0.0)
    check(ev('store', 1, 'mrpd', id).success == false, 'store: away from the locker is refused')
    atLocker(env, 1)

    check(ev('store', 1, 'mrpd', id).success == true and mysql.db.evidence[1].status == 'stored', 'store: an officer locks evidence up')
    check(bagsFor(1, id) == 0 and mysql.db.evidence[1].holder_cid == nil, 'store: the bag leaves the inventory')

    check(ev('checkout', 3, 'mrpd', id).success == false, 'checkout: a civilian or far officer cannot check out')
    check(ev('checkout', 1, 'mrpd', id).success == true and bagsFor(1, id) == 1, 'checkout: an officer gets a bag back')
    check(ev('checkout', 1, 'mrpd', id).success == false, 'checkout: evidence that is out cannot be checked out twice')
    local actions = {}
    for _, row in ipairs(mysql.db.custody) do actions[#actions + 1] = row.action end
    check(table.concat(actions, ',') == 'collected,stored,checked out', 'custody: every change leaves a row, in order')
end

do
    local env = evScene()
    shoot('S-777')
    ev('collect', 1, mysql.db.evidence[1].id)
    Handlers['som:server:playerDowned'](2, 'SUSPECT')
    ev('collect', 1, mysql.db.evidence[2].id)
    Mocks.players[9] = { citizenid = 'OTHER', job = { name = 'unemployed' } }
    placePed(9, 1.0, 0.0, 0.0)
    Handlers['som:server:playerDowned'](9, 'OTHER')
    ev('collect', 1, mysql.db.evidence[3].id)
    local casingId, bloodId, otherId = mysql.db.evidence[1].id, mysql.db.evidence[2].id, mysql.db.evidence[3].id

    check(ev('analyse', 1, 'mrpd', casingId).success == false, 'lab: analysing away from the lab is refused')
    atLab(env, 1)
    check(ev('result', 1, 'mrpd', casingId).success == false, 'lab: no result before it is started')
    check(ev('analyse', 1, 'mrpd', casingId).success == true and ev('analyse', 1, 'mrpd', casingId).success == false,
        'lab: analysis starts once')
    check(ev('result', 1, 'mrpd', casingId).success == false, 'lab: the result is not readable before it is due')
    mysql.fakeNow = mysql.fakeNow + env.Config.Kinds.casing.lab * 60
    local r = ev('result', 1, 'mrpd', casingId)
    check(r.success and r.result.serial == 'S-777', 'lab: a casing reveals its weapon serial')

    ev('analyse', 1, 'mrpd', bloodId)
    ev('analyse', 1, 'mrpd', otherId)
    mysql.fakeNow = mysql.fakeNow + env.Config.Kinds.blood.lab * 60
    local unknown = ev('result', 1, 'mrpd', bloodId)
    check(unknown.success and unknown.result.match == nil and unknown.result.profile ~= nil, 'lab: blood with no sample on file stays unidentified')

    placePed(1, 0.0, 0.0, 0.0)
    placePed(2, 1.0, 0.0, 0.0)
    check(ev('sample', 1, 2, 'dna_sample').success == false, 'sample: an uncuffed person cannot be sampled')
    setCuffed(2, true)
    check(ev('sample', 1, 2, 'dna_sample').success == false, 'sample: no kit, no sample')
    Mocks.inv[1][#Mocks.inv[1] + 1] = { name = 'dnatestkit', count = 1, slot = 20 }
    Mocks.inv[1][#Mocks.inv[1] + 1] = { name = 'empty_evidence_bag', count = 1, slot = 21 }
    check(ev('sample', 1, 2, 'bone_sample').success == false, 'sample: only known sample kinds')
    check(ev('sample', 1, 2, 'dna_sample').success == true, 'sample: a cuffed person can be sampled')
    check(env.Evidence.Profile('SUSPECT') == mysql.db.evidence[#mysql.db.evidence].profile, 'sample: it carries the person\'s own code')

    atLab(env, 1)
    local match = ev('result', 1, 'mrpd', bloodId)
    check(match.success and match.result.match == 'SUSPECT', 'lab: blood matches the sample on file')
    local noMatch = ev('result', 1, 'mrpd', otherId)
    check(noMatch.success and noMatch.result.match == nil, 'lab: someone else\'s blood does not match')
end

do
    local env = evScene()
    shoot('S-100')
    local id = mysql.db.evidence[1].id
    ev('collect', 1, id)
    atLocker(env, 1)
    ev('store', 1, 'mrpd', id)
    local own = addCase({ class = 'misdemeanor', status = 'accepted', filed_by = 'OFFICER', sentence_months = 0 })
    local theirs = addCase({ class = 'misdemeanor', status = 'accepted', filed_by = 'OFFICER2', sentence_months = 0 })
    local closed = addCase({ class = 'misdemeanor', status = 'dismissed', filed_by = 'OFFICER', sentence_months = 0 })

    check(ev('link', 1, 'mrpd', id, theirs.id).success == false, 'link: another officer\'s case is refused')
    check(ev('link', 1, 'mrpd', id, closed.id).success == false, 'link: a closed case is refused')
    check(ev('link', 1, 'mrpd', id, 9999).success == false, 'link: a case that does not exist is refused')
    check(ev('link', 1, 'mrpd', id, own.id).success == true and mysql.db.evidence[1].case_id == own.id, 'link: an officer links evidence to their case')
    check(ev('link', 1, 'mrpd', id, own.id).success == false, 'link: evidence links once')
    check(#Mocks.exported.forCase(own.id) == 1 and #Mocks.exported.forCase(theirs.id) == 0, 'link: a case lists the evidence behind it')

    Mocks.players[10] = { citizenid = 'JUDGE', job = { name = 'judge', onduty = true, grade = 2 } }
    Mocks.players[20] = { citizenid = 'CIV', job = { name = 'unemployed' } }
    local view = RegisteredCallbacks['som-court:server:evidence']
    check(#view(10, own.id).evidence == 1, 'court: a judge sees the evidence behind a case')
    check(view(20, own.id).success == false, 'court: a civilian cannot')
    check(view(1, theirs.id).success == false and view(1, own.id).success == true, 'court: an officer sees only their own case')
end

do
    local env = evScene()
    Mocks.inv[1][#Mocks.inv[1] + 1] = { name = 'gsrtestkit', count = 1, slot = 30 }
    check(ev('gsr', 1, 2).success and ev('gsr', 1, 2).positive == nil, 'gsr: the kit is spent on the first test')
    Mocks.inv[1][#Mocks.inv[1] + 1] = { name = 'gsrtestkit', count = 1, slot = 31 }
    check(ev('gsr', 1, 2).positive == false, 'gsr: someone who has not fired tests negative')
    Mocks.inv[1][#Mocks.inv[1] + 1] = { name = 'gsrtestkit', count = 1, slot = 32 }
    shoot('S-100')
    check(ev('gsr', 1, 2).positive == true, 'gsr: someone who just fired tests positive')
    check(ev('gsr', 1, 2).success == false, 'gsr: no kit, no test')
    check(ev('gsr', 2, 1).success == false, 'gsr: a civilian cannot test')
end

----------------------------------------------------------------------
-- som-dispatch: merging, offsets, working a call, major incidents
----------------------------------------------------------------------
local function person(cid, job, onduty, grade)
    return {
        citizenid = cid,
        charinfo = { firstname = cid, lastname = 'Test' },
        job = { name = job, onduty = onduty, grade = grade or 0 },
    }
end

local function dispScene()
    local env = loadDispatch()
    for _, alert in pairs(env.Config.Alerts) do alert.chance = 1.0 end
    Mocks.players[21] = person('R1', 'unemployed', false)
    Mocks.players[22] = person('R2', 'unemployed', false)
    Mocks.players[23] = person('R3', 'unemployed', false)
    Mocks.players[31] = person('COP1', 'police', true, 1)
    Mocks.players[32] = person('SGT', 'police', true, 4)
    Mocks.players[33] = person('MEDIC', 'ambulance', true, 0)
    Mocks.players[34] = person('DISP', 'dispatcher', true, 0)
    Mocks.players[35] = person('CIV', 'unemployed', false)
    for _, id in ipairs({ 21, 22, 23 }) do placePed(id, 100.0 + id, 100.0, 30.0) end
    return env
end

local function report(source, alert)
    _G.source = source
    RegisteredEvents['som-dispatch:server:report'](alert, {})
    _G.source = nil
end

local function allCalls() return Mocks.exported.getCalls() end
local function firstCall()
    for _, call in pairs(allCalls()) do return call end
end

local function capture(fn)
    local seen = {}
    local real = _G.TriggerClientEvent
    _G.TriggerClientEvent = function(name, target, ...) seen[#seen + 1] = { name = name, target = target } end
    fn()
    _G.TriggerClientEvent = real
    return seen
end

local function sentTo(seen, name, target)
    for _, e in ipairs(seen) do
        if e.name == name and e.target == target then return true end
    end
    return false
end

do
    local env = dispScene()
    report(21, 'meleeAttack')
    local call = firstCall()
    check(call and call.count == 1 and call.priority == 2, 'merge: the first report raises a call')
    report(22, 'meleeAttack')
    check(call.count == 2, 'merge: a nearby repeat joins the call')
    local n = 0
    for _ in pairs(allCalls()) do n = n + 1 end
    check(n == 1, 'merge: a repeat does not make a second call')
    report(23, 'meleeAttack')
    check(call.count == 3 and call.priority == 1, 'merge: enough reports raise the priority one step')

    Mocks.players[24] = person('R4', 'unemployed', false)
    Mocks.players[25] = person('R5', 'unemployed', false)
    placePed(24, 5000.0, 5000.0, 30.0)
    report(24, 'meleeAttack')
    n = 0
    for _ in pairs(allCalls()) do n = n + 1 end
    check(n == 2, 'merge: a report far away is its own call')

    placePed(25, 100.0, 100.0, 30.0)
    call.createdAt = os.time() - env.Config.Merge.window - 5
    report(25, 'meleeAttack')
    n = 0
    for _ in pairs(allCalls()) do n = n + 1 end
    check(n == 3, 'merge: an old call is not merged into')
end

do
    local env = dispScene()
    placePed(21, 1000.0, 2000.0, 30.0)
    report(21, 'meleeAttack')
    local call = firstCall()
    local dx, dy = call.coords.x - 1000.0, call.coords.y - 2000.0
    check(call.offset == env.Config.Alerts.meleeAttack.offset and math.abs(dx) <= call.offset and math.abs(dy) <= call.offset,
        'offset: the shown position is within the search radius of the real one')
    check(dx ~= 0 or dy ~= 0, 'offset: the shown position is not the real one')
    placePed(22, 1000.0, 2000.0, 30.0)
    report(22, 'meleeAttack')
    check(call.count == 2, 'offset: repeats still merge on the real position')
    report(21, 'shotsFired')
    local shots
    for _, c in pairs(allCalls()) do if c.alertType == 'shotsFired' then shots = c end end
    check(shots and shots.coords.x == 1000.0, 'offset: other alert types are shown exactly')
end

do
    local env = dispScene()
    env.Config.ReportBudget = 2
    report(21, 'meleeAttack'); report(21, 'vehicleTheft'); report(21, 'explosion')
    local n = 0
    for _ in pairs(allCalls()) do n = n + 1 end
    check(n == 2, 'budget: a player over their reports per minute is ignored')
end

do
    local env = dispScene()
    local seen = capture(function() report(21, 'shotsFired') end)
    check(sentTo(seen, 'som-dispatch:client:call', 31) and sentTo(seen, 'som-dispatch:client:call', 34),
        'routing: on duty police and the dispatcher hear a call')
    check(not sentTo(seen, 'som-dispatch:client:call', 33) and not sentTo(seen, 'som-dispatch:client:call', 35),
        'routing: other services and civilians do not')
end

do
    dispScene()
    report(21, 'shotsFired')
    local call = firstCall()
    local attach, detach = RegisteredCallbacks['som-dispatch:server:attach'], RegisteredCallbacks['som-dispatch:server:detach']
    check(attach(35, call.id).success == false, 'attach: a civilian cannot')
    check(attach(34, call.id).success == false, 'attach: a dispatcher does not take the field')
    check(attach(33, call.id).success == false, 'attach: a service the call is not for cannot')
    check(attach(31, 999).success == false, 'attach: an unknown call is refused')
    check(attach(31, call.id).success == true and #call.units == 1 and call.services.police.status == 'responding',
        'attach: an officer responds')
    check(attach(31, call.id).success == false, 'attach: twice is refused')
    check(detach(31, call.id).success == true and #call.units == 0, 'detach: an officer can leave')
    check(detach(31, call.id).success == false, 'detach: leaving twice is refused')
end

do
    dispScene()
    report(21, 'shotsFired')
    local call = firstCall()
    local assign = RegisteredCallbacks['som-dispatch:server:assign']
    local attach = RegisteredCallbacks['som-dispatch:server:attach']
    check(assign(31, call.id, 32).success == false, 'assign: a plain officer cannot assign')
    check(assign(34, call.id, 35).success == false, 'assign: a civilian cannot be assigned')
    check(assign(34, call.id, 33).success == false, 'assign: a service not on the call cannot be assigned')
    check(assign(34, call.id, 31).success == true and #call.units == 1, 'assign: a dispatcher puts an officer on a call')
    check(assign(34, call.id, 31).success == false, 'assign: the same officer twice is refused')
    check(assign(32, call.id, 32).success == true, 'assign: a supervisor can assign')
    check(attach(32, call.id).success == false, 'assign: an assigned unit is already attached')
end

do
    dispScene()
    report(21, 'shotsFired')
    local call = firstCall()
    local close = RegisteredCallbacks['som-dispatch:server:close']
    local attach = RegisteredCallbacks['som-dispatch:server:attach']
    check(close(35, call.id).success == false, 'close: a civilian cannot')
    check(close(31, call.id).success == false, 'close: a unit not on the call cannot')
    attach(31, call.id)
    check(close(31, call.id).success == true and call.status == 'closed', 'close: a unit on the call closes it')
    check(close(31, call.id).success == false and attach(32, call.id).success == false, 'close: a closed call takes no more work')

    report(22, 'explosion')
    local blast
    for _, c in pairs(allCalls()) do if c.alertType == 'explosion' then blast = c end end
    attach(31, blast.id)
    close(31, blast.id)
    check(blast.status ~= 'closed' and blast.services.police.status == 'closed' and blast.services.ambulance.status ~= 'closed',
        'close: closing your own service leaves the other open')
    check(close(34, blast.id).success == true and blast.status == 'closed', 'close: a dispatcher closes every service')
end

do
    local env = dispScene()
    report(21, 'shotsFired')
    local call = firstCall()
    local major = RegisteredCallbacks['som-dispatch:server:major']
    local attach = RegisteredCallbacks['som-dispatch:server:attach']
    check(major(31, call.id, true).success == false, 'major: a plain officer cannot declare')
    attach(31, call.id)
    local seen = capture(function() check(major(32, call.id, true).success == true and call.major, 'major: a supervisor declares') end)
    check(sentTo(seen, 'som:client:notify', 31) and sentTo(seen, 'som:client:notify', 34), 'major: every on duty responder hears it')
    check(major(32, call.id, true).success == false, 'major: declaring twice is refused')

    placePed(22, 800.0, 800.0, 30.0)
    local routine = capture(function() report(22, 'meleeAttack') end)
    check(not sentTo(routine, 'som-dispatch:client:call', 31) and sentTo(routine, 'som-dispatch:client:call', 32),
        'major: units on the incident are spared routine calls')
    placePed(23, 1800.0, 1800.0, 30.0)
    local urgent = capture(function() report(23, 'explosion') end)
    check(sentTo(urgent, 'som-dispatch:client:call', 31), 'major: priority one traffic still reaches them')
    check(major(34, call.id, false).success == true and not call.major, 'major: a dispatcher can stand it down')
end

do
    local env = dispScene()
    report(21, 'shotsFired')
    placePed(22, 3000.0, 3000.0, 30.0)
    report(22, 'explosion')
    local board = RegisteredCallbacks['som-dispatch:server:board']
    check(board(35).success == false, 'board: a civilian has no board')
    check(#board(31).calls == 2 and #board(33).calls == 1, 'board: a unit sees only calls for its service')
    check(#board(34).calls == 2 and board(34).role == 'dispatcher', 'board: a dispatcher sees them all')
    check(board(31).calls[1].unattended == false, 'board: a fresh call is not unattended')
    for _, call in pairs(allCalls()) do call.createdAt = os.time() - env.Config.UnattendedAfter - 1 end
    check(board(31).calls[1].unattended == true, 'board: a call nobody took for too long is flagged')
end

----------------------------------------------------------------------
-- som-hack: challenges the server owns
----------------------------------------------------------------------
local function cellsInOrder(view)
    local marks = {}
    for _, m in ipairs(view.marks) do marks[#marks + 1] = m end
    table.sort(marks, function(a, b) return a.n < b.n end)
    local out = {}
    for _, m in ipairs(marks) do out[#out + 1] = m.cell end
    return out
end

-- The code a challenge will draw for a seed: two draws go on the token first.
local function codeFor(seed, length)
    math.randomseed(seed)
    math.random(0, 0x7fffffff); math.random(0, 0x7fffffff)
    local code = {}
    for i = 1, length do code[i] = math.random(0, 9) end
    return code
end

local function begin(env, source, kind, level, seed)
    if seed then math.randomseed(seed) end
    return env.Hack.Begin(source, kind, level)
end

do
    local env = loadHack()
    check(env.Hack.Begin(1, 'memory', 'impossible') == nil and env.Hack.Begin(1, 'nope', 'easy') == nil
        and env.Hack.Begin(1, 'memory', nil) == nil, 'hack: an unknown kind or level is refused')

    local view = begin(env, 1, 'memory', 'normal')
    check(view and view.size == 4 and #view.marks == 6 and view.showMs == 3000 and view.nonce ~= nil,
        'memory: the view carries the grid, the marks and a token')
    local cells, n = {}, 0
    for _, m in ipairs(view.marks) do
        if not cells[m.cell] then n = n + 1 end
        cells[m.cell] = true
    end
    check(n == 6, 'memory: every mark is on a different cell')
    check(env.Hack.Begin(1, 'crack', 'easy') == nil, 'hack: a player runs one challenge at a time')
    Mocks.clock = Mocks.clock + env.Config.ExpireMs + 1
    check(env.Hack.Begin(1, 'crack', 'easy') ~= nil, 'hack: an expired challenge no longer blocks a new one')
end

do
    local env = loadHack()
    local view = begin(env, 1, 'memory', 'easy')
    local answer = cellsInOrder(view)
    local minMs = view.showMs + #view.marks * env.Config.Memory.minClickMs

    check(env.Hack.Submit(1, 'nope', answer).solved == nil, 'memory: a wrong token is refused')
    check(env.Hack.Submit(2, view.nonce, answer).success == false, 'memory: another player cannot answer for you')
    Mocks.clock = Mocks.clock + minMs - 1
    check(env.Hack.Submit(1, view.nonce, answer).solved == false, 'memory: an answer faster than a person can pick is wrong')
    check(env.Hack.Submit(1, view.nonce, answer).success == false, 'memory: a token is spent by the first answer')

    local view2 = begin(env, 1, 'memory', 'easy')
    Mocks.clock = Mocks.clock + minMs
    local wrong = cellsInOrder(view2)
    wrong[1], wrong[2] = wrong[2], wrong[1]
    check(env.Hack.Submit(1, view2.nonce, wrong).solved == false, 'memory: the right cells in the wrong order are wrong')

    local view3 = begin(env, 1, 'memory', 'easy')
    Mocks.clock = Mocks.clock + minMs
    local short = cellsInOrder(view3)
    short[#short] = nil
    check(env.Hack.Submit(1, view3.nonce, short).solved == false, 'memory: too few picks are wrong')

    local view4 = begin(env, 1, 'memory', 'easy')
    Mocks.clock = Mocks.clock + minMs
    check(env.Hack.Submit(1, view4.nonce, 'x').solved == false, 'memory: a non table answer is wrong')

    local view5 = begin(env, 1, 'memory', 'easy')
    Mocks.clock = Mocks.clock + minMs
    check(env.Hack.Submit(1, view5.nonce, cellsInOrder(view5)).solved == true, 'memory: the right order after the floor time solves it')
    check(env.Hack.Submit(1, view5.nonce, cellsInOrder(view5)).success == false, 'memory: a solved challenge cannot be answered again')

    local view6 = begin(env, 1, 'memory', 'easy')
    Mocks.clock = Mocks.clock + env.Config.ExpireMs + 1
    check(env.Hack.Submit(1, view6.nonce, cellsInOrder(view6)).success == false, 'memory: an expired token is refused')
end

do
    local env = loadHack()
    local seed, code
    for candidate = 1, 500 do
        local c = codeFor(candidate, 4)
        local seen, dup = {}, false
        for _, d in ipairs(c) do
            if seen[d] then dup = true end
            seen[d] = true
        end
        if dup then seed, code = candidate, c; break end
    end

    local view = begin(env, 1, 'crack', 'easy', seed)
    check(view.length == 4 and view.attempts == 8, 'crack: the view carries only the length and attempts')
    check(view.code == nil and view.solution == nil, 'crack: the view never carries the code')

    local guess = env.Hack.Guess
    check(guess(1, view.nonce, { 1, 2 }).success == false, 'crack: a guess of the wrong length is refused')
    check(guess(1, view.nonce, { 1, 2, 3, 12 }).success == false and guess(1, view.nonce, { 1.5, 2, 3, 4 }).success == false,
        'crack: digits outside 0 to 9 and fractions are refused')
    check(guess(1, 'nope', { 1, 2, 3, 4 }).success == false, 'crack: a wrong token is refused')

    local dupDigit, positions = nil, {}
    for i, d in ipairs(code) do
        for j = i + 1, #code do
            if code[j] == d then dupDigit = d; positions = { i, j } end
        end
    end
    local other = 0
    for d = 0, 9 do
        local used = false
        for _, c in ipairs(code) do if c == d then used = true end end
        if not used then other = d; break end
    end
    local third
    for i = 1, #code do if i ~= positions[1] and i ~= positions[2] then third = i; break end end

    local probe = { other, other, other, other }
    probe[positions[1]], probe[positions[2]], probe[third] = dupDigit, dupDigit, dupDigit
    local r = guess(1, view.nonce, probe)
    check(r.success and r.feedback[positions[1]] == 'hit' and r.feedback[positions[2]] == 'hit' and r.feedback[third] == 'miss',
        'crack: a digit the code has twice cannot score a third time')
    check(r.left == view.attempts - 1 and r.solved == false, 'crack: a wrong guess costs one attempt')
    check(guess(1, view.nonce, code).error == 'slow down', 'crack: guesses faster than the gap are refused')

    Mocks.clock = Mocks.clock + env.Config.Crack.guessGapMs
    local rotated = {}
    for i = 1, #code do rotated[i] = code[(i % #code) + 1] end
    local nearish = guess(1, view.nonce, rotated)
    local near = 0
    for _, f in ipairs(nearish.feedback or {}) do if f == 'near' then near = near + 1 end end
    check(near >= 1, 'crack: a right digit in the wrong place is near')

    Mocks.clock = Mocks.clock + env.Config.Crack.guessGapMs
    local win = guess(1, view.nonce, code)
    check(win.solved == true and win.done == true, 'crack: the exact code solves it')
    check(guess(1, view.nonce, code).success == false, 'crack: a finished challenge takes no more guesses')
end

do
    local env = loadHack()
    local settings = env.Config.Crack.easy
    local view = begin(env, 1, 'crack', 'easy', 11)
    local code = codeFor(11, settings.length)
    local wrong = {}
    for i = 1, settings.length do wrong[i] = (code[i] + 1) % 10 end
    local last
    for _ = 1, settings.attempts do
        Mocks.clock = Mocks.clock + env.Config.Crack.guessGapMs
        last = env.Hack.Guess(1, view.nonce, wrong)
    end
    check(last.done == true and last.solved == false, 'crack: running out of attempts ends it')
    Mocks.clock = Mocks.clock + env.Config.Crack.guessGapMs
    check(env.Hack.Guess(1, view.nonce, code).success == false, 'crack: the right guess after lock out is too late')
end

do
    local env = loadHack()

    env.Hack.Play = function(source, view)
        Mocks.clock = Mocks.clock + view.showMs + #view.marks * env.Config.Memory.minClickMs
        env.Hack.Submit(source, view.nonce, cellsInOrder(view))
    end
    check(env.Hack.Run(1, 'memory', 'easy') == true, 'run: a player who solves it gets true')

    env.Hack.Play = function() end
    check(env.Hack.Run(1, 'memory', 'easy') == false, 'run: a player who never answers gets false')

    env.Hack.Play = function() return true, true end
    check(env.Hack.Run(1, 'memory', 'easy') == false, 'run: what the client says it did is ignored')

    env.Hack.Play = function(source, view)
        Mocks.clock = Mocks.clock + 60000
        env.Hack.Submit(source, 'made-up', cellsInOrder(view))
        env.Hack.Submit(2, view.nonce, cellsInOrder(view))
    end
    check(env.Hack.Run(1, 'memory', 'easy') == false, 'run: answers with a forged token or from another player do not count')

    env.Hack.Play = function() error('client gone') end
    check(env.Hack.Run(1, 'crack', 'easy') == false, 'run: a failing client is a failure, not a crash')

    env.Hack.Begin(1, 'memory', 'easy')
    local ok, err = env.Hack.Run(1, 'memory', 'easy')
    check(ok == false and err == 'busy', 'run: a second run while one is open is refused')
end

----------------------------------------------------------------------
-- som-launder: the bill ledger and the front
----------------------------------------------------------------------
local function wScene()
    local env = loadLaunder()
    mysql.fakeNow = os.time()
    env.Config.Fronts.laundromat.enabled = true
    env.Config.Fronts.laundromat.set = true
    Mocks.players[1] = { citizenid = 'C1', job = { name = 'unemployed' } }
    Mocks.players[2] = { citizenid = 'C2', job = { name = 'unemployed' } }
    placePed(1, 0.0, 0.0, 0.0)
    placePed(2, 0.0, 0.0, 0.0)
    Mocks.inv[1] = {}
    Mocks.inv[2] = {}
    return env
end

local function wl(name, ...) return RegisteredCallbacks['som-launder:server:' .. name] end
local function countOf(source, name)
    local n = 0
    for _, item in pairs(Mocks.inv[source] or {}) do if item.name == name then n = n + 1 end end
    return n
end

do
    local env = wScene()
    check(env.Ledger.Mint(1, {}, 't') == nil, 'mint: no bills is refused')
    check(env.Ledger.Mint(1, { 0 }, 't') == nil and env.Ledger.Mint(1, { 5001 }, 't') == nil, 'mint: worth outside the range is refused')
    check(env.Ledger.Mint(1, { 12.5 }, 't') == nil, 'mint: a fractional worth is refused')
    local many = {}
    for i = 1, 41 do many[i] = 100 end
    check(env.Ledger.Mint(1, many, 't') == nil, 'mint: too many bills in one call is refused')
    check(next(mysql.db.bills) == nil and countOf(1, 'markedbills') == 0, 'mint: refusals write nothing')

    local uids = env.Ledger.Mint(1, { 500, 700 }, 'store')
    check(uids and #uids == 2 and countOf(1, 'markedbills') == 2, 'mint: one item per bill')
    check(mysql.db.bills[uids[1]].worth == 500 and mysql.db.bills[uids[1]].status == 'issued', 'mint: each bill has a ledger row')
    local slot = env.Ledger.SlotOf(1, uids[2])
    check(slot and Mocks.inv[1][slot].metadata.uid == uids[2], 'mint: the item carries its uid')

    Mocks.invFull[1] = true
    local before = countOf(1, 'markedbills')
    check(env.Ledger.Mint(1, { 100, 100 }, 'store') == nil and countOf(1, 'markedbills') == before,
        'mint: a full pack gives nothing')
    local voided = 0
    for _, b in pairs(mysql.db.bills) do if b.status == 'void' then voided = voided + 1 end end
    check(voided >= 1, 'mint: a failed mint voids the rows it wrote')
    Mocks.invFull[1] = nil
end

do
    local env = wScene()
    local uids = env.Ledger.Mint(1, { 500, 700 }, 'store')
    env.Config.Fronts.laundromat.enabled = false
    check(wl('bills')(1, 'laundromat').success == false, 'front: a disabled front is closed')
    env.Config.Fronts.laundromat.enabled = true
    env.Config.Fronts.laundromat.set = false
    check(wl('bills')(1, 'laundromat').success == false, 'front: a front whose coordinates are not set is closed')
    env.Config.Fronts.laundromat.set = true
    check(wl('bills')(1, 'nowhere').success == false, 'front: an unknown front is refused')
    placePed(1, 50.0, 0.0, 0.0)
    check(wl('bills')(1, 'laundromat').success == false, 'front: away from the desk is refused')
    placePed(1, 0.0, 0.0, 0.0)

    Mocks.inv[1][#Mocks.inv[1] + 1] = { name = 'markedbills', count = 1, slot = 90, metadata = { uid = 'FFFFFFFFFFFFFFFF', worth = 99999 } }
    local slot = env.Ledger.SlotOf(1, uids[1])
    Mocks.inv[1][#Mocks.inv[1] + 1] = { name = 'markedbills', count = 1, slot = 91, metadata = { uid = uids[1], worth = 500 } }
    local list = wl('bills')(1, 'laundromat')
    check(list.success and #list.bills == 2, 'bills: forged and duplicated items are not listed')
end

do
    local env = wScene()
    local uids = env.Ledger.Mint(1, { 500, 700 }, 'store')
    local deposit = wl('deposit')
    check(deposit(1, 'laundromat', {}).success == false and deposit(1, 'laundromat', 'x').success == false, 'deposit: nothing chosen is refused')
    check(deposit(1, 'laundromat', { 'FFFFFFFFFFFFFFFF' }).success == false, 'deposit: a uid that is not in the ledger is refused')
    check(deposit(1, 'laundromat', { uids[1], uids[1] }).success == false, 'deposit: the same bill twice in one order is refused')
    check(deposit(2, 'laundromat', { uids[1] }).success == false, 'deposit: someone else cannot hand over a bill they do not carry')
    local tooMany = {}
    for i = 1, env.Config.Wash.maxBills + 1 do tooMany[i] = uids[1] end
    check(deposit(1, 'laundromat', tooMany).success == false, 'deposit: more bills than an order allows is refused')

    local slot = env.Ledger.SlotOf(1, uids[1])
    Mocks.inv[1][slot].metadata.worth = 99999
    local r = deposit(1, 'laundromat', { uids[1], uids[2] })
    check(r.success == true and r.face == 1200 and r.payout == math.floor(1200 * (1 - env.Config.Wash.cut)),
        'deposit: the payout comes from the ledger worth, not the item metadata, minus the cut')
    check(countOf(1, 'markedbills') == 0 and mysql.db.bills[uids[1]].status == 'washing', 'deposit: the bills are taken and claimed')
    check(deposit(1, 'laundromat', { uids[1] }).success == false, 'deposit: a bill that was handed over cannot be handed over again')

    local collect = wl('collect')
    check(collect(1, 'laundromat', r.orderId).success == false, 'collect: not ready yet')
    check(#wl('orders')(1, 'laundromat').orders == 1 and wl('orders')(1, 'laundromat').orders[1].ready == 0, 'orders: a pending order is listed as not ready')
    mysql.fakeNow = mysql.fakeNow + env.Config.Wash.delayMinutes * 60
    check(collect(2, 'laundromat', r.orderId).success == false, 'collect: someone else cannot collect it')
    Mocks.addMoneyFails = true
    check(collect(1, 'laundromat', r.orderId).success == false and mysql.db.orders[1].status == 'washing', 'collect: a failed payment leaves the order to retry')
    Mocks.addMoneyFails = false
    check(collect(1, 'laundromat', r.orderId).success == true and Mocks.paid == r.payout and Mocks.lastPaid.account == 'cash',
        'collect: the order pays once, in clean cash')
    check(collect(1, 'laundromat', r.orderId).success == false and Mocks.paid == r.payout, 'collect: a second collect pays nothing')
    check(mysql.db.bills[uids[1]].status == 'washed', 'collect: the bills end washed')
end

do
    local env = wScene()
    env.Config.Wash.dailyCap = 1500
    local uids = env.Ledger.Mint(1, { 1000, 600 }, 'store')
    check(wl('deposit')(1, 'laundromat', { uids[1] }).success == true, 'cap: a wash under the daily cap goes through')
    check(wl('deposit')(1, 'laundromat', { uids[2] }).success == false, 'cap: the daily cap stops the next one')
    mysql.fakeNow = mysql.fakeNow + 86400 + 5
    check(wl('deposit')(1, 'laundromat', { uids[2] }).success == true, 'cap: it resets after a day')
end

do
    local env = wScene()
    env.Config.Wash.hourlyBudget = 2000
    env.Config.Wash.dailyCap = 100000
    local a = env.Ledger.Mint(1, { 1000 }, 'store')
    local b = env.Ledger.Mint(2, { 1000 }, 'store')
    local c = env.Ledger.Mint(1, { 1000 }, 'store')
    local first = wl('deposit')(1, 'laundromat', { a[1] })
    local second = wl('deposit')(2, 'laundromat', { b[1] })
    check(first.payout == 700, 'budget: an empty hour pays the full rate')
    check(second.payout == 525, 'budget: a half used hour pays a lower rate for everyone')
    check(wl('deposit')(1, 'laundromat', { c[1] }).success == false, 'budget: a used up hour takes no more')
    mysql.fakeNow = mysql.fakeNow + 3600 + 5
    check(wl('deposit')(1, 'laundromat', { c[1] }).payout == 700, 'budget: it recovers after an hour')
end

do
    local env = loadLaunder()
    local open = 0
    for _, front in pairs(env.Config.Fronts) do
        if front.enabled or front.set then open = open + 1 end
    end
    check(open == 0, 'config: every shipped front is disabled until its coordinates are set')
end

----------------------------------------------------------------------
-- som-phone: the action pipeline, devices and the lock
----------------------------------------------------------------------
local function phoneScene()
    local env = loadPhone()
    Mocks.players[1] = { citizenid = 'P1', job = { name = 'unemployed' }, charinfo = { firstname = 'Ann', lastname = 'One', phone = '555-0001' } }
    Mocks.players[2] = { citizenid = 'P2', job = { name = 'police', onduty = true, grade = 1 }, charinfo = { firstname = 'Bo', lastname = 'Two', phone = '555-0002' } }
    Mocks.inv[1] = { { name = 'phone', count = 1, slot = 1, metadata = {} } }
    Mocks.inv[2] = { { name = 'phone', count = 1, slot = 1, metadata = {} } }
    -- The bank's own queries are tested with the bank; here it only has to be reachable.
    env.Bank.GetOverview = function() return { accountNo = '12345678' } end
    env.Bank.ShareAccount = function() return false, 'nobody nearby' end
    return env
end

local function act(source, app, action, payload) return RegisteredCallbacks['som-phone:server:action'](source, app, action, payload) end

do
    local env = phoneScene()
    local r = act(1, 'system', 'open', {})
    check(r.success == true and #r.apps >= 3 and r.number == '555-0001', 'phone: opening returns the apps the player may see')
    local imei = Mocks.inv[1][1].metadata.imei
    check(type(imei) == 'string' and #imei == 16 and mysql.db.devices[imei] ~= nil, 'device: the server writes an imei into the item and a row for it')
    act(1, 'system', 'open', {})
    check(Mocks.inv[1][1].metadata.imei == imei, 'device: the imei is kept, not reissued')

    Mocks.inv[1] = {}
    check(act(1, 'system', 'open', {}).success == false and act(1, 'bank', 'overview', {}).success == false,
        'phone: no phone item, nothing works, not even a bank read')
    Mocks.inv[1] = { { name = 'phone', count = 1, slot = 1, metadata = {} } }

    Mocks.metadataRefused = true
    check(act(2, 'system', 'open', {}).success == false, 'device: an inventory that refuses the imei write is not trusted')
    Mocks.metadataRefused = false
end

do
    local env = phoneScene()
    Mocks.players[9] = nil
    check(act(9, 'bank', 'overview', {}).success == false, 'pipeline: an unloaded player gets nothing')
    check(act(1, 5, 'overview', {}).success == false and act(1, 'bank', {}, {}).success == false, 'pipeline: non string app or action is refused')
    check(act(1, string.rep('a', 40), 'overview', {}).success == false, 'pipeline: an overlong app id is refused')
    check(act(1, 'bank', 'overview', 'x').success == false, 'pipeline: a non table payload is refused')
    check(act(1, 'nope', 'overview', {}).error == 'no such app', 'pipeline: an unknown app is refused')
    check(act(1, 'bank', 'nope', {}).error == 'no such action', 'pipeline: an unknown action is refused')

    local big = { text = string.rep('x', env.Config.Pipeline.maxPayload + 1) }
    check(act(1, 'bank', 'bill', big).success == false, 'pipeline: an oversize payload is refused before the app runs')
    local deep = { a = { b = { c = { d = { e = { f = { g = 1 } } } } } } }
    check(act(1, 'bank', 'bill', deep).success == false, 'pipeline: a deeply nested payload is refused')
    check(act(1, 'bank', 'bill', { [{}] = 1 }).success == false, 'pipeline: a table used as a key is refused')
    check(act(1, 'bank', 'bill', { f = function() end }).success == false, 'pipeline: a function value is refused')
end

do
    local env = phoneScene()
    Mocks.downed[1] = true
    check(act(1, 'system', 'open', {}).success == false and act(1, 'bank', 'overview', {}).success == false,
        'pipeline: a downed player cannot use the phone')
    Mocks.downed[1] = nil

    env.Phone.Register({ id = 'police_only', label = 'PD', jobs = { 'police' }, handler = function() return { data = 1 } end })
    check(act(1, 'police_only', 'x', {}).error == 'no such app', 'pipeline: an app for another job is hidden and refused')
    check(act(2, 'police_only', 'x', {}).success == true, 'pipeline: the right job reaches the app')
    local apps = act(1, 'system', 'open', {}).apps
    local seen = false
    for _, a in ipairs(apps) do if a.id == 'police_only' then seen = true end end
    check(not seen, 'pipeline: the home screen lists only apps the player may see')

    env.Phone.Register({ id = 'perked', label = 'P', perk = 'vip', handler = function() return {} end })
    check(act(1, 'perked', 'x', {}).success == false, 'pipeline: a perk app is refused without the perk')
    Mocks.perks[1] = { vip = true }
    check(act(1, 'perked', 'x', {}).success == true, 'pipeline: and allowed with it')

    check(env.Phone.Register({ id = 'bad id!' }) == false and env.Phone.Register('x') == false and env.Phone.Register({ id = 5 }) == false,
        'host: a malformed app registration is refused')
end

do
    local env = phoneScene()
    env.Config.Pipeline.writesPerMinute = 3
    env.Config.Pipeline.readsPerMinute = 5
    local reads = 0
    for _ = 1, 8 do if act(1, 'bank', 'overview', {}).success ~= false or true then reads = reads + 1 end end
    local limited = act(1, 'bank', 'overview', {})
    check(limited.error == 'slow down', 'pipeline: reads over the per minute limit are refused')

    local writes = 0
    for _ = 1, 5 do act(1, 'bank', 'share', {}) end
    check(act(1, 'bank', 'share', {}).error == 'slow down', 'pipeline: writes over the per minute limit are refused')
    check(act(2, 'bank', 'overview', {}).error ~= 'slow down', 'pipeline: one player hitting the limit does not limit another')
end

do
    local env = phoneScene()
    env.Phone.Register({ id = 'boom', label = 'B', actions = { go = { fn = function() error('bug') end } } })
    check(act(1, 'boom', 'go', {}).error == 'something went wrong', 'pipeline: a failing handler is a refusal, not a crash')

    env.Phone.Register({ id = 'ok', label = 'O', actions = {
        read = { fn = function() return { data = 1 } end },
        write = { writes = true, fn = function() return { data = 2 } end },
        refuse = { writes = true, fn = function() return { error = 'no' } end },
    } })
    act(1, 'ok', 'read', {})
    check(#mysql.db.phoneAudit == 0, 'audit: a read leaves no row')
    act(1, 'ok', 'write', {})
    act(1, 'ok', 'refuse', {})
    check(#mysql.db.phoneAudit == 2 and mysql.db.phoneAudit[1].ok == 1 and mysql.db.phoneAudit[2].ok == 0 and mysql.db.phoneAudit[1].citizenid == 'P1',
        'audit: a change leaves a row with the outcome, and a refused one is recorded as failed')

    local hostResult = act(2, 'ok', 'read', {})
    check(hostResult.success == true and hostResult.data == 1, 'pipeline: a handler result gains success when it did not set one')

    env.Phone.Register({ id = 'ext', label = 'E', reads = { list = true }, handler = function(source, action) return { data = action } end })
    act(1, 'ext', 'list', {})
    check(#mysql.db.phoneAudit == 2, 'host: an external app action marked as a read is not audited')
    act(1, 'ext', 'buy', {})
    check(#mysql.db.phoneAudit == 3, 'host: an external app action not marked as a read is audited')
end

do
    local env = phoneScene()
    check(act(1, 'settings', 'setPasscode', { passcode = '12' }).success == false and act(1, 'settings', 'setPasscode', { passcode = 'abcd' }).success == false,
        'lock: a passcode must be four digits')
    check(act(1, 'settings', 'setPasscode', { passcode = '1234' }).success == true, 'lock: a passcode can be set')
    local imei = Mocks.inv[1][1].metadata.imei
    check(mysql.db.devices[imei].pass_hash ~= nil and mysql.db.devices[imei].pass_hash ~= '1234',
        'lock: only a hash is stored')

    act(1, 'system', 'lock', {})
    local locked = act(1, 'bank', 'overview', {})
    check(locked.locked == true and locked.success == false, 'lock: a locked phone runs nothing')
    check(act(1, 'system', 'open', {}).success == true, 'lock: but it still opens so the code can be entered')

    for _ = 1, env.Config.Lock.failsBeforeLock - 1 do
        check(act(1, 'system', 'unlock', { passcode = '0000' }).error == 'Wrong passcode', 'lock: a wrong code is refused')
    end
    check(act(1, 'system', 'unlock', { passcode = '0000' }).success == false, 'lock: the last wrong code locks it out')
    check(act(1, 'system', 'unlock', { passcode = '1234' }).error == 'Try again shortly', 'lock: even the right code is refused during the lockout')
    check(act(1, 'bank', 'overview', {}).locked == true, 'lock: still locked')

    env.Phone.ResetFails = nil
end

do
    local env = phoneScene()
    act(1, 'settings', 'setPasscode', { passcode = '4321' })
    act(1, 'system', 'lock', {})
    check(act(1, 'system', 'unlock', { passcode = '9999' }).success == false, 'lock: a wrong code does not unlock')
    check(act(1, 'system', 'unlock', { passcode = 4321 }).success == false, 'lock: a number instead of a string is refused')
    check(act(1, 'system', 'unlock', { passcode = '4321' }).success == true and act(1, 'bank', 'overview', {}).locked ~= true,
        'lock: the right code opens it')
    check(act(2, 'bank', 'overview', {}).locked ~= true, 'lock: another phone is unaffected')

    act(1, 'system', 'lock', {})
    _G.source = 1
    Handlers['playerDropped']()
    _G.source = nil
    check(act(1, 'bank', 'overview', {}).locked == true, 'lock: unlocked state is dropped when the player leaves')

    act(1, 'system', 'unlock', { passcode = '4321' })
    check(act(1, 'settings', 'setPasscode', {}).success == true and act(1, 'bank', 'overview', {}).locked ~= true,
        'lock: the passcode can be removed')
end

do
    local env = phoneScene()
    check(act(1, 'settings', 'setTheme', { theme = 'nope' }).success == false, 'settings: an unknown theme is refused')
    check(act(1, 'settings', 'setTheme', { theme = 'midnight' }).success == false, 'settings: a perk theme is refused without the perk')
    Mocks.perks[1] = { phoneTheme = true }
    check(act(1, 'settings', 'setTheme', { theme = 'midnight' }).success == true, 'settings: and allowed with it')
end

do
    local env = phoneScene()
    local notified
    local real = _G.TriggerClientEvent
    _G.TriggerClientEvent = function(name, target, title, text, icon) if name == 'som-phone:client:banner' then notified = { target = target, title = title, text = text, icon = icon } end end
    check(Mocks.exported.notifyApp(1, 'bank', 'Hello') == true and notified.title == 'Bank' and notified.icon == 'bank',
        'exports: notifyApp still resolves a built-in app label and icon')
    env.Phone.Register({ id = 'jobs', label = 'Jobs', icon = 'briefcase', handler = function() return {} end })
    Mocks.exported.notifyApp(1, 'jobs', 'Offer')
    check(notified.title == 'Jobs' and notified.icon == 'briefcase', 'exports: notifyApp resolves a registered app')
    check(Mocks.exported.notifyApp(1, 'nope', 'x') == true and notified.title == 'System', 'exports: an unknown app falls back to System')
    check(Mocks.exported.notifyApp(1, 'bank', '') == false and Mocks.exported.notifyApp(0, 'bank', 'x') == false, 'exports: empty text or a bad source is refused')
    _G.TriggerClientEvent = real
    check(type(Mocks.exported.billCitizen) == 'function' and type(Mocks.exported.registerApp) == 'function',
        'exports: billCitizen and registerApp are still exported for other resources')
end

----------------------------------------------------------------------
-- som-phone: contacts, messages, calls
----------------------------------------------------------------------
local function commsScene()
    local env = phoneScene()
    mysql.db.characters = { ['555-0001'] = 'P1', ['555-0002'] = 'P2', ['555-0003'] = 'P3' }
    Mocks.players[3] = { citizenid = 'P3', job = { name = 'unemployed' }, charinfo = { firstname = 'Cy', lastname = 'Three', phone = '555-0003' } }
    Mocks.inv[3] = { { name = 'phone', count = 1, slot = 1, metadata = {} } }
    env.Config.Pipeline.writesPerMinute = 1000
    env.Config.Pipeline.readsPerMinute = 1000
    return env
end

local function pushes()
    local seen = {}
    local real = _G.TriggerClientEvent
    _G.TriggerClientEvent = function(name, target, payload)
        if name == 'som-phone:client:call' then seen[#seen + 1] = { target = target, state = payload.state, number = payload.number, name = payload.name } end
    end
    return seen, function() _G.TriggerClientEvent = real end
end

do
    commsScene()
    check(act(1, 'contacts', 'save', { name = '', number = '5550003' }).success == false, 'contacts: a name is required')
    check(act(1, 'contacts', 'save', { name = 'Cy', number = '123' }).success == false and act(1, 'contacts', 'save', { name = 'Cy', number = { 1 } }).success == false,
        'contacts: a bad number is refused')
    check(act(1, 'contacts', 'save', { name = '<b>Cy</b>', number = '555-0003' }).success == true, 'contacts: a contact can be saved with a dashed number')
    check(mysql.db.contacts['P1|555-0003'] == 'bCy/b', 'contacts: markup is stripped from names and numbers are stored one way')
    act(1, 'contacts', 'save', { name = 'Cyrus', number = '5550003' })
    check(mysql.db.contacts['P1|555-0003'] == 'Cyrus', 'contacts: saving the same number renames it')
    local list = act(1, 'contacts', 'list')
    check(#list.contacts == 1 and list.contacts[1].name == 'Cyrus', 'contacts: the list is the caller\'s own')
    check(#act(2, 'contacts', 'list').contacts == 0, 'contacts: nobody else sees them')
    act(1, 'contacts', 'remove', { number = '5550003' })
    check(#act(1, 'contacts', 'list').contacts == 0, 'contacts: a contact can be removed')

    phoneEnv.Config.Contacts.max = 2
    act(1, 'contacts', 'save', { name = 'A', number = '5550010' })
    act(1, 'contacts', 'save', { name = 'B', number = '5550011' })
    check(act(1, 'contacts', 'save', { name = 'C', number = '5550012' }).success == false, 'contacts: the contact limit holds')
    check(act(1, 'contacts', 'save', { name = 'B2', number = '5550011' }).success == true, 'contacts: renaming still works at the limit')
end

do
    commsScene()
    local sent = {}
    local real = _G.TriggerClientEvent
    _G.TriggerClientEvent = function(name, target, title, text) if name == 'som-phone:client:banner' then sent[#sent + 1] = { target = target, title = title, text = text } end end

    check(act(1, 'messages', 'send', { number = '5550002', body = '' }).success == false, 'messages: an empty message is refused')
    check(act(1, 'messages', 'send', { number = 'x', body = 'hi' }).success == false, 'messages: a bad number is refused')
    check(act(1, 'messages', 'send', { number = '555-0001', body = 'hi' }).success == false, 'messages: you cannot message yourself')
    check(act(1, 'messages', 'send', { number = '5559999', body = 'hi' }).error == 'no such number', 'messages: a number nobody has is refused')
    check(#mysql.db.messages == 0, 'messages: refusals store nothing')

    check(act(1, 'messages', 'send', { number = '5550002', body = 'hello <script>x</script>\nthere' }).success == true, 'messages: a message is sent')
    check(mysql.db.messages[1].body == 'hello scriptx/script there', 'messages: markup and control characters are stripped')
    check(#sent == 1 and sent[1].target == 2 and sent[1].title == 'Messages', 'messages: an online receiver with a phone is notified')

    act(1, 'messages', 'send', { number = '5550002', body = string.rep('x', 500) })
    check(#mysql.db.messages[2].body == phoneEnv.Config.Messages.maxLength, 'messages: a message is cut to the limit')

    Mocks.inv[2] = {}
    act(1, 'messages', 'send', { number = '5550002', body = 'no phone on them' })
    check(#sent == 2 and #mysql.db.messages == 3, 'messages: a receiver without a phone gets it stored but no banner')

    mysql.db.characters['555-0004'] = 'P4'
    check(act(1, 'messages', 'send', { number = '5550004', body = 'offline' }).success == true and #sent == 2, 'messages: an offline number stores it quietly')

    Mocks.inv[2] = { { name = 'phone', count = 1, slot = 1, metadata = {} } }
    local box = act(2, 'messages', 'threads')
    check(#box.threads == 1 and box.threads[1].other == '555-0001' and box.threads[1].unread == 3, 'messages: the inbox shows the thread with its unread count')
    local thread = act(2, 'messages', 'thread', { number = '5550001' })
    check(#thread.messages == 3 and thread.messages[1].mine == false and thread.messages[3].body == 'no phone on them', 'messages: a thread is oldest first')
    check(act(2, 'messages', 'threads').threads[1].unread == 0, 'messages: opening a thread marks it read')

    act(2, 'contacts', 'block', { number = '5550001' })
    local before = #mysql.db.messages
    check(act(1, 'messages', 'send', { number = '5550002', body = 'blocked?' }).success == true and #mysql.db.messages == before,
        'messages: a blocked sender is told it sent but nothing is stored')
    act(2, 'contacts', 'block', { number = '5550001', blocked = false })
    act(1, 'messages', 'send', { number = '5550002', body = 'unblocked' })
    check(#mysql.db.messages == before + 1, 'messages: unblocking lets messages through again')
    _G.TriggerClientEvent = real
end

do
    local env = commsScene()
    local seen, restore = pushes()
    check(act(1, 'phone', 'dial', { number = '123' }).success == false, 'calls: a bad number is refused')
    check(act(1, 'phone', 'dial', { number = '5550001' }).success == false, 'calls: you cannot call yourself')
    mysql.db.characters['555-0004'] = 'P4'
    check(act(1, 'phone', 'dial', { number = '5550004' }).error == 'that number is not available' and mysql.db.phoneCalls[1].status == 'unavailable',
        'calls: an offline number is unavailable and logged')
    Mocks.inv[2] = {}
    check(act(1, 'phone', 'dial', { number = '5550002' }).success == false, 'calls: someone without a phone cannot be reached')
    Mocks.inv[2] = { { name = 'phone', count = 1, slot = 1, metadata = {} } }

    act(2, 'contacts', 'block', { number = '5550001' })
    check(act(1, 'phone', 'dial', { number = '5550002' }).success == false, 'calls: a blocked caller cannot get through')
    act(2, 'contacts', 'block', { number = '5550001', blocked = false })

    check(act(1, 'phone', 'dial', { number = '5550002' }).success == true, 'calls: a call to a reachable number rings')
    check(#seen == 2 and seen[1].state == 'dialling' and seen[1].target == 1 and seen[2].state == 'ringing' and seen[2].target == 2 and seen[2].number == '555-0001',
        'calls: the caller sees dialling and the receiver sees ringing with the caller')
    check(Mocks.voice[1] == nil and Mocks.voice[2] == nil, 'calls: nobody is on a voice channel while it rings')
    check(act(1, 'phone', 'dial', { number = '5550003' }).error == 'you are already on a call', 'calls: you cannot start a second call')
    check(act(3, 'phone', 'dial', { number = '5550002' }).error == 'that line is busy' and mysql.db.phoneCalls[#mysql.db.phoneCalls].status == 'missed',
        'calls: a busy line is refused and logged as missed')
    check(act(1, 'phone', 'answer').success == false, 'calls: the caller cannot answer their own call')
    check(act(3, 'phone', 'answer').success == false, 'calls: a stranger cannot answer')

    check(act(2, 'phone', 'answer').success == true, 'calls: the receiver can answer')
    local channel = Mocks.voice[1]
    check(channel and channel == Mocks.voice[2] and channel >= env.Config.Calls.channelMin and channel <= env.Config.Calls.channelMax,
        'calls: both sides are put on one server chosen channel in the random range')
    check(channel ~= 1 and channel ~= 2, 'calls: the channel is not a player id')
    check(act(2, 'phone', 'answer').success == false, 'calls: a call is answered once')

    check(act(3, 'phone', 'hangup').success == false, 'calls: someone not on the call cannot end it')
    check(act(2, 'phone', 'hangup').success == true, 'calls: either side can hang up')
    check(Mocks.voice[1] == 0 and Mocks.voice[2] == 0, 'calls: ending frees the voice channel for both')
    local last = mysql.db.phoneCalls[#mysql.db.phoneCalls]
    check(last.status == 'answered' and last.answered == 1, 'calls: an answered call is logged as answered')
    check(seen[#seen].state == 'ended' and seen[#seen - 1].state == 'ended', 'calls: both sides are told it ended')
    check(act(1, 'phone', 'dial', { number = '5550003' }).success == true, 'calls: a line is free again after hanging up')
    act(1, 'phone', 'hangup')

    local recents = act(1, 'phone', 'recents').recents
    check(#recents >= 3 and recents[1].outgoing == true and recents[1].number == '555-0003' and recents[1].from_number == nil, 'calls: recents show the other number and direction')
    restore()
end

do
    local env = commsScene()
    local seen, restore = pushes()
    act(1, 'phone', 'dial', { number = '5550002' })
    local ring = PendingTimeouts[#PendingTimeouts]
    check(ring and ring.ms == env.Config.Calls.ringSeconds * 1000, 'calls: an unanswered call has a ring timeout')
    ring.fn()
    check(act(1, 'phone', 'hangup').success == false and mysql.db.phoneCalls[#mysql.db.phoneCalls].status == 'missed', 'calls: ringing out ends it as missed')

    act(1, 'phone', 'dial', { number = '5550002' })
    PendingTimeouts[#PendingTimeouts].fn()
    act(1, 'phone', 'dial', { number = '5550003' })
    act(3, 'phone', 'answer')
    local stale = PendingTimeouts[#PendingTimeouts - 1]
    stale.fn()
    check(Mocks.voice[1] ~= 0 and Mocks.voice[1] ~= nil, 'calls: an old ring timer does not end a call that was answered')

    _G.source = 3
    Handlers['playerDropped']()
    _G.source = nil
    check(Mocks.voice[1] == 0 and mysql.db.phoneCalls[#mysql.db.phoneCalls].status == 'answered', 'calls: a player who drops ends the call and frees the channel')

    act(1, 'phone', 'dial', { number = '5550002' })
    act(2, 'phone', 'answer')
    Handlers['som:server:playerDowned'](2)
    check(Mocks.voice[2] == 0 and act(1, 'phone', 'hangup').success == false, 'calls: going down ends the call')

    act(1, 'phone', 'dial', { number = '5550002' })
    act(2, 'phone', 'hangup')
    check(mysql.db.phoneCalls[#mysql.db.phoneCalls].status == 'declined', 'calls: declining a ring is logged as declined')
    restore()
end

----------------------------------------------------------------------

----------------------------------------------------------------------
-- som-phone: Chirp and Pages
----------------------------------------------------------------------
local function socialScene()
    local env = commsScene()
    local S = mysql.db.social
    S.people = {
        P1 = { firstname = 'Ann', lastname = 'One', phone = '555-0001' },
        P2 = { firstname = 'Bo', lastname = 'Two', phone = '555-0002' },
        P3 = { firstname = 'Cy', lastname = 'Three', phone = '555-0003' },
    }
    env.Config.Social.postGapSeconds = 20
    return env
end

local function age(seconds)
    for _, x in ipairs(mysql.db.social.posts) do x.ts = x.ts - seconds end
end

do
    local env = socialScene()
    local S = mysql.db.social
    local feed = act(1, 'chirp', 'feed')
    check(feed.me.handle:match('^annone%d%d$') ~= nil, 'chirp: a handle is made from the name on first use')
    check(act(1, 'chirp', 'feed').me.handle == feed.me.handle, 'chirp: the handle is kept')

    check(act(1, 'chirp', 'post', { body = '   ' }).success == false and act(1, 'chirp', 'post', { body = { 1 } }).success == false, 'chirp: an empty or non text post is refused')
    check(act(1, 'chirp', 'post', { body = 'hello <b>world</b>\nline' }).success == true, 'chirp: a post is accepted')
    check(S.posts[1].body == 'hello bworld/b line', 'chirp: markup and control characters are stripped')
    check(act(1, 'chirp', 'post', { body = 'again' }).error == 'slow down', 'chirp: the gap between posts holds')
    age(60)
    act(1, 'chirp', 'post', { body = string.rep('x', 500) })
    check(#S.posts[2].body == 280, 'chirp: a post is cut to the limit')

    age(60)
    check(act(1, 'chirp', 'post', { body = 'pic', image = 'https://evil.example/a.png' }).success == false, 'chirp: an image is refused while no host is allowed')
    env.Config.Social.imageHosts = { 'img.example.com' }
    check(act(1, 'chirp', 'post', { body = 'pic', image = 'http://img.example.com/a.png' }).success == false, 'chirp: a plain http image is refused')
    check(act(1, 'chirp', 'post', { body = 'pic', image = 'https://img.example.com/a.png"onerror=x' }).success == false, 'chirp: an image url with quotes is refused')
    check(act(1, 'chirp', 'post', { body = 'pic', image = 'https://img.example.com.evil.io/a.png' }).success == false, 'chirp: a lookalike host is refused')
    check(act(1, 'chirp', 'post', { body = 'pic', image = 'https://img.example.com/a.png' }).success == true and S.posts[3].image == 'https://img.example.com/a.png',
        'chirp: an image on an allowed host is kept')

    age(60)
    check(act(2, 'chirp', 'post', { body = 'reply', replyTo = 999 }).success == false, 'chirp: replying to nothing is refused')
    check(act(2, 'chirp', 'post', { body = 'a reply', replyTo = 1 }).success == true, 'chirp: a reply is accepted')
    age(60)
    check(act(1, 'chirp', 'post', { body = 'nested', replyTo = 4 }).success == false, 'chirp: replies do not nest')

    local list = act(2, 'chirp', 'feed').posts
    check(#list == 3 and list[1].id == 3 and list[3].replies == 1, 'chirp: the feed lists top level posts newest first with reply counts')
    check(list[1].citizenid == nil and list[1].mine == false and act(1, 'chirp', 'feed').posts[1].mine == true, 'chirp: ids of authors are never sent, ownership is a flag')
    local thread = act(2, 'chirp', 'thread', { id = 1 }).posts
    check(#thread == 2 and thread[1].id == 1 and thread[2].reply_to == 1, 'chirp: a thread is the post and its replies')
    check(act(2, 'chirp', 'thread', { id = 999 }).success == false, 'chirp: an unknown thread is refused')

    check(act(2, 'chirp', 'like', { id = 1 }).liked == true and S.posts[1].likes == 1, 'chirp: a like counts')
    check(act(2, 'chirp', 'like', { id = 1 }).liked == false and S.posts[1].likes == 0, 'chirp: liking again takes it back')
    act(2, 'chirp', 'like', { id = 1 })
    check(act(1, 'chirp', 'like', { id = 1 }).liked == true and S.posts[1].likes == 2, 'chirp: likes are per character')
    check(act(2, 'chirp', 'like', { id = 999 }).success == false, 'chirp: liking a missing post is refused')

    check(act(2, 'chirp', 'remove', { id = 1 }).success == false and S.posts[1].removed == false, 'chirp: only the author can remove a post')
    check(act(1, 'chirp', 'report', { id = 1 }).success == false, 'chirp: you cannot report your own post')
    check(act(2, 'chirp', 'report', { id = 1, reason = 'spam' }).success == true and S.reports['1|P2'] == 'spam', 'chirp: a report is recorded')
    local count = 0
    for _ in pairs(S.reports) do count = count + 1 end
    act(2, 'chirp', 'report', { id = 1, reason = 'again' })
    local after = 0
    for _ in pairs(S.reports) do after = after + 1 end
    check(count == after and S.reports['1|P2'] == 'spam', 'chirp: one report per character per post')
    check(act(1, 'chirp', 'remove', { id = 1 }).success == true and #act(2, 'chirp', 'feed').posts == 2, 'chirp: the author can remove their post and it leaves the feed')
end

do
    local env = socialScene()
    local S = mysql.db.social
    act(1, 'chirp', 'feed'); act(2, 'chirp', 'feed')
    check(act(1, 'chirp', 'setHandle', { handle = 'annie' }).success == false, 'chirp: a custom handle needs the supporter perk')
    Mocks.perks[1] = { twitterHandle = true }
    for _, bad in ipairs({ 'ab', 'has space', 'waytoolonghandle12345', 'Bad!', 'police', 'lspd_chief', 'admin1' }) do
        check(act(1, 'chirp', 'setHandle', { handle = bad }).success == false, 'chirp: handle "' .. bad .. '" is refused')
    end
    check(act(1, 'chirp', 'setHandle', { handle = { 1 } }).success == false, 'chirp: a non text handle is refused')
    Mocks.perks[2] = { twitterHandle = true }
    check(act(1, 'chirp', 'setHandle', { handle = 'Annie_1' }).success == true and S.handles.P1.handle == 'annie_1', 'chirp: a valid handle is saved lowercase')
    check(act(2, 'chirp', 'setHandle', { handle = 'annie_1' }).error == 'that handle is taken', 'chirp: two characters cannot share a handle')
    check(act(1, 'chirp', 'setHandle', { handle = 'annie_2' }).error == 'you changed your handle recently', 'chirp: handle changes are rate limited')

    check(act(1, 'chirp', 'setColour', { colour = '#ff6b9d' }).success == false, 'chirp: a colour needs the perk')
    Mocks.perks[1].twitterColour = 3
    check(act(1, 'chirp', 'setColour', { colour = '#2ecc71' }).success == true and S.handles.P1.colour == '#2ecc71', 'chirp: an unlocked colour is saved')
    check(act(1, 'chirp', 'setColour', { colour = '#f0932b' }).success == false, 'chirp: a colour beyond the tier is refused')
    check(act(1, 'chirp', 'setColour', { colour = 'red;x' }).success == false, 'chirp: an arbitrary colour string is refused')
    check(act(1, 'chirp', 'setColour', {}).success == true and S.handles.P1.colour == nil, 'chirp: the colour can be cleared')
end

do
    socialScene()
    local S = mysql.db.social
    Mocks.players[2].job = { name = 'police', onduty = true, isboss = false }
    act(2, 'chirp', 'feed')
    check(act(2, 'chirp', 'post', { body = 'official', asBusiness = true }).success == false, 'chirp: a non boss cannot post as a business')
    Mocks.players[2].job = { name = 'police', onduty = false, isboss = true }
    check(act(2, 'chirp', 'post', { body = 'official', asBusiness = true }).success == false, 'chirp: an off duty boss cannot post as a business')
    Mocks.players[2].job = { name = 'unemployed', onduty = true, isboss = true }
    check(act(2, 'chirp', 'post', { body = 'official', asBusiness = true }).success == false, 'chirp: a job with no business cannot post as one')
    Mocks.players[2].job = { name = 'police', onduty = true, isboss = true }
    check(act(2, 'chirp', 'post', { body = 'official', asBusiness = true }).success == true and S.posts[1].business == 'LSPD', 'chirp: an on duty boss posts as the business the server chose')
    age(60)
    act(2, 'chirp', 'post', { body = 'fake', business = 'Fake Co' })
    check(S.posts[2].business == nil, 'chirp: a business sent by the client is ignored')

    local day = socialScene()
    mysql.db.social.posts = {}
    day.Config.Social.postsPerDay = 2
    day.Config.Social.postGapSeconds = 0
    act(1, 'chirp', 'post', { body = 'one' }); act(1, 'chirp', 'post', { body = 'two' })
    check(act(1, 'chirp', 'post', { body = 'three' }).error == 'you have posted enough for today', 'chirp: the daily cap holds')
end

do
    local env = socialScene()
    local S = mysql.db.social
    act(1, 'chirp', 'feed')
    check(act(1, 'pages', 'post', { category = 'nope', title = 'x', body = 'y' }).success == false, 'pages: an unknown category is refused')
    check(act(1, 'pages', 'post', { category = 'for_sale', title = '', body = 'y' }).success == false, 'pages: a title is needed')
    check(act(1, 'pages', 'post', { category = 'for_sale', title = 'Bike <b>', body = 'Nice', price = '$500', showNumber = true }).success == true, 'pages: an advert is posted')
    check(S.adverts[1].title == 'Bike b' and S.adverts[1].show_number == 1 and S.adverts[1].hours == env.Config.Pages.expireHours, 'pages: text is cleaned and the expiry comes from config')
    check(act(1, 'pages', 'post', { category = 'for_sale', title = 'Another', body = 'Nice' }).error == 'you already have an advert in that category', 'pages: one advert per category')
    act(1, 'pages', 'post', { category = 'wanted', title = 'W', body = 'b' })
    act(1, 'pages', 'post', { category = 'services', title = 'S', body = 'b' })
    check(act(1, 'pages', 'post', { category = 'other', title = 'O', body = 'b' }).error == 'you already have the most adverts allowed', 'pages: the total cap holds')
    check(act(1, 'pages', 'post', { category = 'other', title = 'O', body = 'b', asBusiness = true }).success == false, 'pages: the cap applies to business adverts too')

    local list = act(2, 'pages', 'adverts', {})
    check(#list.adverts == 3 and list.adverts[3].number == '555-0001' and list.adverts[1].number == nil, 'pages: a number shows only when the poster chose to share it')
    check(list.adverts[1].citizenid == nil and list.adverts[3].mine == false, 'pages: poster ids are never sent')
    check(#act(2, 'pages', 'adverts', { category = 'wanted' }).adverts == 1, 'pages: a category filter works')
    check(#act(2, 'pages', 'adverts', { category = "x' OR 1=1" }).adverts == 3, 'pages: an unknown filter is ignored, not injected')

    S.adverts[2].expired = true
    check(#act(2, 'pages', 'adverts', {}).adverts == 2, 'pages: an expired advert disappears')
    check(act(1, 'pages', 'post', { category = 'wanted', title = 'W2', body = 'b' }).success == true, 'pages: an expired advert frees its category')

    check(act(2, 'pages', 'remove', { id = 1 }).success == false and S.adverts[1].status == 'active', 'pages: only the poster can remove an advert')
    check(act(1, 'pages', 'remove', { id = 1 }).success == true and S.adverts[1].status == 'removed', 'pages: the poster can remove their advert')

    local seen = {}
    local real = _G.TriggerClientEvent
    _G.TriggerClientEvent = function(name, target, title, text) if name == 'som-phone:client:banner' then seen[#seen + 1] = { target = target, text = text } end end
    check(act(1, 'pages', 'contact', { id = 3, body = 'mine?' }).success == false, 'pages: you cannot contact your own advert')
    check(act(2, 'pages', 'contact', { id = 3, body = '' }).success == false, 'pages: an empty message is refused')
    check(act(2, 'pages', 'contact', { id = 1, body = 'hi' }).success == false, 'pages: a removed advert cannot be contacted')
    check(act(2, 'pages', 'contact', { id = 3, body = 'still there?' }).success == true, 'pages: a buyer can message the poster')
    local m = mysql.db.messages[#mysql.db.messages]
    check(m.from_number == '555-0002' and m.to_number == '555-0001' and m.body == '[S] still there?', 'pages: the message carries the advert title and goes to the poster\'s number')
    check(#seen >= 1 and seen[1].target == 1, 'pages: an online poster is notified')
    _G.TriggerClientEvent = real
end

do
    local env = socialScene()
    local S = mysql.db.social
    check(act(1, 'pages', 'search', { q = 'Bo' }).success == false, 'white pages: a short search is refused')
    check(#act(1, 'pages', 'search', { q = 'Two' }).people == 0, 'white pages: nobody is listed until they opt in')
    check(act(2, 'pages', 'listing').listed == false, 'white pages: listing defaults to off')
    check(act(2, 'pages', 'list', { listed = true }).listed == true, 'white pages: a character can opt in')
    local found = act(1, 'pages', 'search', { q = 'bo tw' }).people
    check(#found == 1 and found[1].firstname == 'Bo' and found[1].phone == '555-0002' and found[1].citizenid == nil, 'white pages: search returns name and number only')
    check(#act(1, 'pages', 'search', { q = '%%%' }).people == 0 and #act(1, 'pages', 'search', { q = '___' }).people == 0, 'white pages: wildcards are literals')
    check(act(2, 'pages', 'list', { listed = false }).listed == false and #act(1, 'pages', 'search', { q = 'Two' }).people == 0, 'white pages: opting out removes the listing')
end

do
    socialScene()
    local S = mysql.db.social
    act(1, 'chirp', 'feed')
    act(1, 'chirp', 'post', { body = 'bad post' })
    local remove = Mocks.commands.removepost
    local said = {}
    local real = _G.TriggerClientEvent
    _G.TriggerClientEvent = function(name, target, text) if name == 'som:client:notify' then said[#said + 1] = text end end
    remove(2, { kind = 'post', id = 1 })
    check(S.posts[1].removed == false and said[1] == 'You do not have permission to do that', 'moderation: a non staff character cannot remove a post')
    Mocks.admins[2] = true
    remove(2, { kind = 'post', id = 1 })
    check(S.posts[1].removed == true and said[#said] == 'Removed', 'moderation: staff can remove any post')
    check(mysql.db.phoneAudit[#mysql.db.phoneAudit].action == 'remove post 1', 'moderation: a removal is written to the audit')
    remove(2, { kind = 'nope', id = 1 })
    check(said[#said] == 'Use post or advert', 'moderation: an unknown kind is refused')
    _G.TriggerClientEvent = real
end


----------------------------------------------------------------------
-- som-phone: Garage, Services, Notes
----------------------------------------------------------------------
do
    socialScene()
    mysql.db.vehicles = {
        { citizenid = 'P1', plate = 'AAA111', model = 'sultan', garage = 'legion', state = 'garaged' },
        { citizenid = 'P2', plate = 'BBB222', model = 'felon', garage = 'impound', state = 'impounded' },
    }
    local list = act(1, 'garage', 'list').vehicles
    check(#list == 1 and list[1].plate == 'AAA111' and list[1].state == 'garaged', 'garage: the list is the caller\'s own vehicles')
    check(#act(2, 'garage', 'list').vehicles == 1 and act(2, 'garage', 'list').vehicles[1].plate == 'BBB222', 'garage: nobody sees anyone else\'s')
    check(act(1, 'garage', 'move', { plate = 'AAA111' }).success == false, 'garage: it is read only')
end

do
    local env = socialScene()
    Mocks.players[3].job = { name = 'mechanic', onduty = true }
    Mocks.players[1].job = { name = 'mechanic', onduty = false }
    local rows = act(1, 'services', 'list').services
    local mech
    for _, r in ipairs(rows) do if r.job == 'mechanic' then mech = r end end
    check(mech and mech.onDuty == 1, 'services: a counted service shows who is on duty')
    local leaked = false
    for _, r in ipairs(rows) do if r.job == 'police' or r.job == 'ambulance' then leaked = true end end
    check(not leaked, 'services: police and ambulance staffing is never listed')
    check(#rows == 2, 'services: a service whose job does not exist is skipped')

    check(act(1, 'services', 'emergency', { message = '' }).success == false and act(1, 'services', 'emergency', { message = 'x' }).success == false, 'services: a call needs a message')
    check(act(1, 'services', 'emergency', { message = 'shots <b>fired</b> at legion' }).success == true, 'services: a 911 call is passed to dispatch')
    check(Mocks.lastAlertType == 'emergencyCall' and Mocks.lastAlertExtra.message == '911: shots bfired/b at legion', 'services: the message is cleaned and typed by the server')
    check(Mocks.lastAlertExtra.information == 'Caller: Ann One, 555-0001' and Mocks.lastAlertExtra.coords == nil, 'services: the caller is named and the position is left to dispatch')
    check(act(1, 'services', 'emergency', { message = 'again' }).error == 'you have already called that in', 'services: a second call inside the gap is refused')
    check(act(2, 'services', 'emergency', { message = string.rep('y', 400) }).success == true and #Mocks.lastAlertExtra.message == 5 + 140, 'services: the message is cut to the limit and callers are tracked separately')
    Mocks.alertFails = true
    check(act(3, 'services', 'emergency', { message = 'help' }).success == false, 'services: a refused alert is reported')
    Mocks.alertFails = false
    check(act(3, 'services', 'emergency', { message = 'help' }).success == true, 'services: a failed call does not start the cooldown')
end

do
    local env = socialScene()
    check(act(1, 'notes', 'save', { title = '  ', body = 'x' }).success == false, 'notes: a title is required')
    local id = act(1, 'notes', 'save', { title = 'Plan <b>1</b>', body = 'line one\nline <i>two</i>' }).id
    check(mysql.db.notes[id].title == 'Plan b1/b' and mysql.db.notes[id].body == 'line one\nline itwo/i', 'notes: markup is stripped and line breaks survive')
    check(act(1, 'notes', 'save', { title = 'Empty' }).success == true, 'notes: a note may have no body')
    local list = act(1, 'notes', 'list').notes
    check(#list == 2 and list[1].title == 'Empty', 'notes: the list is newest first')
    check(#act(2, 'notes', 'list').notes == 0, 'notes: they are private')
    check(act(2, 'notes', 'save', { id = id, title = 'hijack' }).success == false and mysql.db.notes[id].title == 'Plan b1/b', 'notes: nobody else can edit one')
    check(act(1, 'notes', 'save', { id = id, title = 'Plan 2', body = 'updated' }).success == true and mysql.db.notes[id].body == 'updated', 'notes: the owner can edit')
    check(act(1, 'notes', 'save', { id = 999, title = 'x' }).success == false, 'notes: editing a missing note is refused')
    check(act(2, 'notes', 'remove', { id = id }).success == false and #act(1, 'notes', 'list').notes == 2, 'notes: nobody else can delete one')
    check(act(1, 'notes', 'remove', { id = id }).success == true and #act(1, 'notes', 'list').notes == 1, 'notes: the owner can delete')
    env.Config.City.notes.max = 1
    check(act(1, 'notes', 'save', { title = 'Third' }).error == 'you have too many notes', 'notes: the limit holds')
    env.Config.City.notes.max = 30
    act(1, 'notes', 'save', { title = string.rep('t', 90), body = string.rep('b', 3000) })
    local last = mysql.db.notes[#mysql.db.notes]
    check(#last.title == 40 and #last.body == 2000, 'notes: title and body are cut to the limits')
end


----------------------------------------------------------------------
-- som-groups
----------------------------------------------------------------------
local function groupScene()
    local env = loadGroups()
    for i, n in ipairs({ { 'Ann', 'One' }, { 'Bo', 'Two' }, { 'Cy', 'Three' }, { 'Di', 'Four' } }) do
        Mocks.players[i] = { citizenid = 'P' .. i, job = { name = 'unemployed' }, charinfo = { firstname = n[1], lastname = n[2], phone = '555-000' .. i } }
        mysql.db.characters['555-000' .. i] = 'P' .. i
    end
    return env
end

local function g(source, action, payload)
    return Mocks.apps.groups.handler(source, action, payload or {})
end

local function rowsOf(source)
    local rows = {}
    for _, s in ipairs(g(source, 'view').view.sections) do
        for _, r in ipairs(s.rows or {}) do rows[#rows + 1] = r end
    end
    return rows
end

do
    local env = groupScene()
    check(Mocks.apps.groups ~= nil and Mocks.apps.groups.reads.view == true, 'groups: the app registers with the phone and marks view as a read')
    check(g(1, 'nope').success == false and g(1, 5).success == false and Mocks.apps.groups.handler(99, 'view', {}).success == false, 'groups: an unknown action, a bad action and an unloaded player are refused')
    check(#g(1, 'view').view.buttons == 1 and g(1, 'view').view.buttons[1].action == 'create', 'groups: with no group the only offer is to create one')
    check(g(1, 'leave').success == false and g(1, 'ready', { ready = true }).success == false and g(1, 'invite', { number = '5550002' }).success == false,
        'groups: nothing works without a group')

    check(g(1, 'create').success == true and g(1, 'create').success == false, 'groups: a group is created once')
    check(#rowsOf(1) == 1 and rowsOf(1)[1].title == 'Ann One (leader)' and rowsOf(1)[1].sub == 'Not ready', 'groups: the creator is the leader')
    check(g(2, 'invite', { number = '5550003' }).success == false, 'groups: a non member cannot invite')
    check(g(1, 'invite', { number = '5559' }).success == false and g(1, 'invite', { number = { 1 } }).success == false, 'groups: a bad number is refused')
    check(g(1, 'invite', { number = '5550001' }).error == 'that is you', 'groups: you cannot invite yourself')
    check(g(1, 'invite', { number = '5550009' }).error == 'that person is not around', 'groups: an unknown number is refused')
    Mocks.players[2] = nil
    check(g(1, 'invite', { number = '5550002' }).error == 'that person is not around', 'groups: an offline person is refused')
    Mocks.players[2] = { citizenid = 'P2', job = { name = 'unemployed' }, charinfo = { firstname = 'Bo', lastname = 'Two', phone = '555-0002' } }

    local told = {}
    Mocks.exported.notifyApp = function(source, app, text) told[#told + 1] = { source = source, app = app, text = text } return true end
    check(g(1, 'invite', { number = '555 0002' }).success == true and told[1].source == 2 and told[1].app == 'groups', 'groups: an invite notifies the person')
    check(g(2, 'view').view.sections[1].title == 'Invitation' and g(2, 'view').view.sections[1].rows[1].action == 'accept', 'groups: the invited person sees the invitation')
    check(g(3, 'accept').success == false, 'groups: only the invited can accept')
    check(g(2, 'accept').success == true and #rowsOf(2) == 2, 'groups: accepting joins')
    check(g(2, 'accept').success == false, 'groups: an invitation is used once')
    check(g(2, 'invite', { number = '5550003' }).success == false, 'groups: a member who is not the leader cannot invite')
    check(g(3, 'create').success == true and g(1, 'invite', { number = '5550003' }).error == 'they are already in a group', 'groups: someone in a group cannot be invited')
    g(3, 'leave')

    env.Config.maxSize = 2
    check(g(1, 'invite', { number = '5550003' }).error == 'the group is full', 'groups: the size limit holds')
    env.Config.maxSize = 6

    g(1, 'invite', { number = '5550003' })
    env.Config.inviteSeconds = 120
    local real = os.time
    os.time = function() return real() + 500 end
    check(g(3, 'accept').error == 'that invitation is gone', 'groups: an invitation expires')
    os.time = real
    g(1, 'invite', { number = '5550003' })
    check(g(3, 'decline').success == true and g(3, 'accept').success == false, 'groups: an invitation can be declined')

    check(g(2, 'ready', { ready = 'yes' }).success == false, 'groups: ready must be a boolean')
    check(g(2, 'ready', { ready = true }).success == true and rowsOf(1)[2].sub == 'Ready', 'groups: a member can ready up and the leader sees it')
    check(g(2, 'kick', { member = 1 }).success == false, 'groups: a member cannot remove anyone')
    check(g(1, 'kick', { member = 1 }).success == false, 'groups: the leader cannot remove themselves')
    check(g(1, 'kick', { member = 999 }).success == false, 'groups: removing a stranger is refused')
    check(g(2, 'view').view.sections[1].rows[1].action == nil and g(1, 'view').view.sections[1].rows[2].action == 'kick', 'groups: only the leader is offered removal')
    local memberId = g(1, 'view').view.sections[1].rows[2].payload.member
    check(g(1, 'kick', { member = memberId }).success == true and #rowsOf(2) == 0 and g(2, 'view').view.buttons[1].action == 'create', 'groups: the leader can remove a member')
    check(told[#told].source == 2 and told[#told].text == 'You were removed from the group', 'groups: the removed person is told')
end

do
    groupScene()
    local told = {}
    Mocks.exported.notifyApp = function(source, _, text) told[#told + 1] = { source = source, text = text } return true end
    g(1, 'create')
    for _, n in ipairs({ '5550002', '5550003' }) do g(1, 'invite', { number = n }) end
    g(2, 'accept'); g(3, 'accept')

    check(g(1, 'leave').success == true and g(2, 'view').view.sections[1].rows[1].title == 'Bo Two (leader)', 'groups: when the leader leaves the longest member leads')
    check(told[#told].source == 2 and told[#told].text == 'You are now the group leader', 'groups: the new leader is told')
    Handlers['som:server:playerUnloaded'](2, 'P2')
    check(g(3, 'view').view.sections[1].rows[1].title == 'Cy Three (leader)' and #rowsOf(3) == 1, 'groups: dropping out of the game leaves the group')
    Handlers['som:server:playerUnloaded'](3, 'P3')
    check(g(3, 'view').view.buttons[1].action == 'create', 'groups: an emptied group is gone')
    Handlers['som:server:playerUnloaded'](3, 5)
end

do
    groupScene()
    local getGroup, setBusy = Mocks.exported.getGroup, Mocks.exported.setBusy
    check(getGroup(1) == nil, 'groups exports: no group, no answer')
    g(1, 'create')
    g(1, 'invite', { number = '5550002' }); g(2, 'accept')
    local info = getGroup(2)
    check(info.leader == 1 and #info.members == 2 and info.allReady == false and info.members[1].source ~= nil, 'groups exports: a job resource can read the members and the leader')
    g(1, 'ready', { ready = true }); g(2, 'ready', { ready = true })
    check(getGroup(1).allReady == true, 'groups exports: allReady is true once everyone is ready')

    check(setBusy(info.id, 'Delivery run') == true and getGroup(1).busy == 'Delivery run', 'groups exports: a group can be marked busy')
    check(g(2, 'ready', { ready = false }).success == false and g(1, 'invite', { number = '5550003' }).success == false, 'groups: a busy group cannot change ready or invite')
    g(1, 'leave')
    check(setBusy(info.id, nil) == true and getGroup(2).busy == nil and getGroup(2).allReady == false, 'groups exports: clearing busy resets everyone to not ready')
    check(setBusy(999, 'x') == false, 'groups exports: an unknown group is refused')
end


----------------------------------------------------------------------
-- som-jobboard
----------------------------------------------------------------------
local boardEnv

local function boardScene()
    groupScene()
    Mocks.invoking = nil
    boardEnv = loader.loadResource(REPO .. 'som-jobboard', { 'shared/config.lua', 'server/main.lua' })
    Mocks.exported.notifyApp = function() return true end
    return boardEnv
end

local function j(source, action, payload) return Mocks.apps.jobs.handler(source, action, payload or {}) end

local function crew(size)
    g(1, 'create')
    for i = 2, size do
        g(1, 'invite', { number = '555000' .. i })
        g(i, 'accept')
    end
    for i = 1, size do g(i, 'ready', { ready = true }) end
end

local function provider(overrides)
    local started = {}
    local def = { id = 'courier', label = 'Courier run', minSize = 1, maxSize = 3, slots = 1,
        start = function(info) started[#started + 1] = info.id return true end }
    for k, v in pairs(overrides or {}) do def[k] = v end
    return def, started
end

do
    boardScene()
    local register = Mocks.exported.registerProvider
    check(register({}) == false and register({ id = 'x y', label = 'X', start = function() end }) == false and register({ id = 'x', label = 'X' }) == false,
        'board: a provider needs a clean id, a label and a start function')
    check(j(1, 'view').view.empty == 'Create or join a group in Groups first', 'board: without a group there is nothing to do')
    local def = provider()
    check(register(def) == true, 'board: a provider can register')
    crew(2)
    local rows = j(1, 'view').view.sections[1].rows
    check(#rows == 1 and rows[1].action == 'queue' and rows[1].payload.provider == 'courier', 'board: a ready group is offered the job to wait on')
    check(j(2, 'queue', { provider = 'courier' }).error == 'only the leader can do that', 'board: only the leader can queue')
    check(j(1, 'queue', { provider = 'nope' }).error == 'no such job' and j(1, 'queue', { provider = { 1 } }).success == false, 'board: an unknown provider is refused')
    g(2, 'ready', { ready = false })
    check(j(1, 'queue', { provider = 'courier' }).error == 'everyone must be ready', 'board: a group that is not ready cannot wait')
    check(j(1, 'view').view.sections[1].rows[1].action == nil, 'board: the view does not offer a job the group cannot wait on')
    g(2, 'ready', { ready = true })
    Mocks.exported.registerProvider(provider({ id = 'big', label = 'Big job', minSize = 4, maxSize = 6 }))
    check(j(1, 'queue', { provider = 'big' }).error == 'this job takes 4 to 6 people', 'board: group size must fit the job')
    check(j(1, 'queue', { provider = 'courier' }).success == true and j(1, 'queue', { provider = 'courier' }).success == false, 'board: a group waits once')
    check(j(1, 'view').view.sections[1].title == 'Waiting', 'board: the view shows the wait')
    g(2, 'ready', { ready = false })
    check(j(1, 'view').view.sections[1].title ~= 'Waiting', 'board: a member un-readying takes the group out of the queue')
    g(2, 'ready', { ready = true })
    j(1, 'queue', { provider = 'courier' })
    check(j(1, 'unqueue').success == true and j(1, 'view').view.sections[1].title ~= 'Waiting', 'board: the leader can stop waiting')
end

do
    boardScene()
    local def, started = provider()
    Mocks.exported.registerProvider(def)
    crew(2)
    check(boardEnv.JobBoard.Draw('courier') == nil, 'lottery: nobody waiting, nobody drawn')
    j(1, 'queue', { provider = 'courier' })
    local picked = boardEnv.JobBoard.Draw('courier')
    check(picked ~= nil and j(1, 'view').view.sections[1].title == 'Offer', 'lottery: a waiting group is drawn and offered the job')
    check(boardEnv.JobBoard.Draw('courier') == nil, 'lottery: a group with an offer is not drawn again')
    check(j(2, 'accept').success == false, 'lottery: only the leader can accept')
    check(j(1, 'accept').success == true and #started == 1 and started[1] == picked, 'lottery: accepting starts the job through the provider')
    check(Mocks.exported.getGroup(1).busy == 'Courier run' and j(1, 'view').view.sections[1].title == 'In progress', 'lottery: the group is marked busy while it runs')

    g(1, 'leave')
    g(2, 'create')
    g(3, 'create')
    g(2, 'ready', { ready = true }); g(3, 'ready', { ready = true })
    j(2, 'queue', { provider = 'courier' }); j(3, 'queue', { provider = 'courier' })
    check(boardEnv.JobBoard.Draw('courier') == nil, 'lottery: no slot is free while a job runs')

    Mocks.invoking = 'someone-else'
    check(Mocks.exported.finish(picked) == false, 'lottery: another resource cannot end a provider\'s job')
    Mocks.invoking = 'test'
    check(Mocks.exported.finish(picked) == true and Mocks.exported.finish(picked) == false, 'lottery: the provider ends its own job once')
    check(boardEnv.JobBoard.Draw('courier') ~= nil, 'lottery: the slot is free again after finish')
end

do
    boardScene()
    local def = provider({ slots = 1 })
    Mocks.exported.registerProvider(def)
    -- Two single groups; the longer waiter should be drawn far more often.
    local oldWins, trials = 0, 400
    local realTime = os.time
    for i = 1, trials do
        boardScene()
        Mocks.exported.registerProvider(provider())
        g(1, 'create'); g(2, 'create')
        g(1, 'ready', { ready = true }); g(2, 'ready', { ready = true })
        local now = realTime()
        os.time = function() return now - 40 * 60 end
        j(1, 'queue', { provider = 'courier' })
        os.time = function() return now end
        j(2, 'queue', { provider = 'courier' })
        local picked = boardEnv.JobBoard.Draw('courier')
        if Mocks.exported.getGroup(1).id == picked then oldWins = oldWins + 1 end
    end
    os.time = realTime
    check(oldWins > trials * 0.65 and oldWins < trials * 0.95, 'lottery: waiting raises the odds (4 to 1) but never makes a win certain, got ' .. oldWins .. ' of ' .. trials)
end

do
    local env = boardScene()
    local def, started = provider()
    Mocks.exported.registerProvider(def)
    crew(1)
    j(1, 'queue', { provider = 'courier' }); env.JobBoard.Draw('courier')
    check(j(1, 'decline').success == true and j(1, 'view').view.sections[1].title == 'Jobs for your group', 'offer: declining returns to the list')
    j(1, 'queue', { provider = 'courier' }); env.JobBoard.Draw('courier')
    j(1, 'decline')
    check(j(1, 'queue', { provider = 'courier' }).error == 'your group is locked out for a while' and j(1, 'view').view.empty:find('Try again in'), 'offer: two refusals lock the group out')
    local real = os.time
    os.time = function() return real() + env.Config.lockSeconds + 5 end
    check(j(1, 'queue', { provider = 'courier' }).success == true, 'offer: the lock lifts after its time')
    os.time = real

    env = boardScene()
    Mocks.exported.registerProvider(provider())
    crew(1)
    j(1, 'queue', { provider = 'courier' }); env.JobBoard.Draw('courier')
    os.time = function() return real() + env.Config.offerSeconds + 1 end
    check(j(1, 'accept').error == 'the offer ran out', 'offer: an old offer cannot be accepted')
    env.JobBoard.Tick()
    os.time = real
    check(j(1, 'view').view.sections[1].title ~= 'Offer', 'offer: the tick clears an expired offer and counts it as a refusal')

    env = boardScene()
    Mocks.exported.registerProvider(provider({ start = function() return false end }))
    crew(1)
    j(1, 'queue', { provider = 'courier' }); env.JobBoard.Draw('courier')
    check(j(1, 'accept').error == 'that job could not start' and Mocks.exported.getGroup(1).busy == nil, 'offer: a provider that cannot start leaves the group free')

    env = boardScene()
    Mocks.exported.registerProvider(provider({ start = function() error('boom') end }))
    crew(1)
    j(1, 'queue', { provider = 'courier' }); env.JobBoard.Draw('courier')
    check(j(1, 'accept').success == false and Mocks.exported.getGroup(1).busy == nil, 'offer: a provider that errors does not crash the board')

    env = boardScene()
    Mocks.exported.registerProvider(provider({ canStart = function() return false, 'the city is closed' end }))
    crew(1)
    check(j(1, 'queue', { provider = 'courier' }).error == 'the city is closed', 'board: a provider can refuse a group with a reason')

    env = boardScene()
    Mocks.exported.registerProvider(provider())
    crew(2)
    j(1, 'queue', { provider = 'courier' }); env.JobBoard.Draw('courier')
    g(2, 'leave'); g(1, 'leave')
    check(env.JobBoard.Draw('courier') == nil and j(1, 'view').view.empty ~= nil, 'board: a group that disbands loses its queue and offer')
end


----------------------------------------------------------------------
-- som-courier
----------------------------------------------------------------------
local courierEnv

local function courierScene(withRoute)
    boardScene()
    courierEnv = loader.loadResource(REPO .. 'som-courier', { 'shared/config.lua', 'server/main.lua' })
    if withRoute ~= false then
        courierEnv.Config.routes = { { label = 'Depot', pickup = vec3(0, 0, 0),
            drops = { vec3(100, 0, 0), vec3(200, 0, 0), vec3(300, 0, 0), vec3(400, 0, 0) } } }
    end
    local seen = {}
    local real = _G.TriggerClientEvent
    _G.TriggerClientEvent = function(name, target, payload)
        if name == 'som-courier:client:objective' then seen[#seen + 1] = { target = target, goal = payload } end
    end
    return courierEnv, seen, function() _G.TriggerClientEvent = real end
end

local function at(source, x) FakePeds[source] = vec3(x, 0, 0) end
local function interact(source, kind) return RegisteredCallbacks['som-courier:server:interact'](source, kind) end

local function startRun(size)
    crew(size or 1)
    j(1, 'queue', { provider = 'courier' })
    boardEnv.JobBoard.Draw('courier')
    return j(1, 'accept')
end

do
    local env, seen, restore = courierScene(false)
    crew(1)
    check(j(1, 'queue', { provider = 'courier' }).error == 'no routes are open yet', 'courier: with no routes set it refuses every group')
    check(env.Courier.Start({ id = 1, members = {} }) == false, 'courier: Start refuses without routes')
    env.Config.routes = { { label = 'Broken', drops = {} }, { label = 'NoPickup', drops = { vec3(1, 0, 0) } } }
    check(j(1, 'queue', { provider = 'courier' }).success == false, 'courier: a route missing a pickup or drops is not usable')
    restore()
end

do
    local env, seen, restore = courierScene()
    at(1, 0); at(2, 0)
    check(startRun(2).success == true, 'courier: an accepted offer starts a run')
    check(#seen == 2 and seen[1].goal.kind == 'pickup', 'courier: every member is sent the pickup objective')
    check(interact(1, 'drop').error == 'not yet', 'courier: a drop cannot be done before the pickup')
    check(interact(1, 'nope').success == false and interact(9, 'pickup').error == 'you have no delivery', 'courier: a bad kind or an outsider is refused')
    at(1, 500)
    check(interact(1, 'pickup').error == 'you are too far away', 'courier: the server checks the distance')
    FakePeds[1] = nil
    check(interact(1, 'pickup').success == false, 'courier: a player with no ped is refused')
    at(1, 0)
    local before = #seen
    check(interact(2, 'pickup').success == true and seen[#seen].goal.kind == 'drop' and #seen > before, 'courier: any member can load, and drop objectives follow')
    check(interact(1, 'pickup').error == 'not yet', 'courier: the pickup counts once')

    local paid0 = Mocks.calls.addMoney
    at(1, 100); at(2, 100)
    local first = seen[#seen].goal.coords.x
    FakePeds[1] = vec3(first, 0, 0); FakePeds[2] = vec3(first, 0, 0)
    check(interact(1, 'drop').success == true, 'courier: a drop at the right place completes')
    check(Mocks.calls.addMoney == paid0 + 2 and Mocks.lastPaid.amount == env.Config.payPerDrop and Mocks.lastPaid.account == 'bank', 'courier: both present members are paid from the business')
    check(Mocks.calls.businessSpend >= 2, 'courier: every payment is debited from the business first')

    FakePeds[2] = vec3(first + 1000, 0, 0)
    local goal = seen[#seen].goal.coords.x
    FakePeds[1] = vec3(goal, 0, 0)
    local paid1 = Mocks.calls.addMoney
    interact(1, 'drop')
    check(Mocks.calls.addMoney == paid1 + 1, 'courier: a member far from the drop is not paid')

    goal = seen[#seen].goal.coords.x
    FakePeds[1] = vec3(goal, 0, 0)
    check(interact(1, 'drop').success == true, 'courier: the last drop completes')
    check(Mocks.exported.getGroup(1).busy == nil and interact(1, 'drop').error == 'you have no delivery', 'courier: the run ends, the group is free and the objective is cleared')
    check(seen[#seen].goal == nil, 'courier: clients are told the objective is gone')
    restore()
end

do
    local env, seen, restore = courierScene()
    at(1, 0)
    startRun(1)
    interact(1, 'pickup')
    Mocks.businessSpendFails = true
    local paid = Mocks.calls.addMoney
    FakePeds[1] = seen[#seen].goal.coords
    interact(1, 'drop')
    check(Mocks.calls.addMoney == paid, 'courier: if the company cannot pay, no money is created')
    Mocks.businessSpendFails = false
    Mocks.addMoneyFails = true
    FakePeds[1] = seen[#seen].goal.coords
    local transacts = Mocks.calls.businessTransact
    interact(1, 'drop')
    check(Mocks.calls.businessTransact == transacts + 1 and Mocks.lastTransact.amount == env.Config.payPerDrop, 'courier: a failed credit returns the money to the business')
    Mocks.addMoneyFails = false
    restore()
end

do
    local env, seen, restore = courierScene()
    at(1, 0)
    startRun(1)
    local real = os.time
    os.time = function() return real() + env.Config.minutes * 60 + 5 end
    env.Courier.Sweep()
    os.time = real
    check(Mocks.exported.getGroup(1).busy == nil and interact(1, 'pickup').error == 'you have no delivery', 'courier: a run that runs out of time ends')

    startRun(1)
    g(1, 'leave')
    check(interact(1, 'pickup').error == 'you have no delivery' and seen[#seen].goal == nil, 'courier: a disbanded group loses its run')
    startRun(1)
    Handlers['som:server:playerUnloaded'](1, 'P1')
    check(interact(1, 'pickup').error == 'you have no delivery', 'courier: a player who drops out is no longer on the run')
    restore()
end

do
    local env, seen, restore = courierScene()
    at(1, 0); at(2, 0)
    startRun(2)
    g(2, 'leave')
    check(seen[#seen].target == 2 and seen[#seen].goal == nil and interact(2, 'pickup').error == 'you have no delivery', 'courier: a member who leaves the group is dropped from the run and cleared')
    check(interact(1, 'pickup').success == true, 'courier: the rest of the crew carries on')
    restore()
end


----------------------------------------------------------------------
-- som-heists
----------------------------------------------------------------------
local heistEnv

local function heistScene(open)
    boardScene()
    heistEnv = loader.loadResource(REPO .. 'som-heists', { 'shared/config.lua', 'server/main.lua' })
    Mocks.players[5] = { citizenid = 'P5', job = { name = 'police', onduty = true }, charinfo = { firstname = 'Po', lastname = 'Lice', phone = '555-0005' } }
    Mocks.treasury = 50000
    Mocks.inv[1], Mocks.inv[2] = {}, {}
    Mocks.hackResult = true
    Mocks.hacks, Mocks.doors, Mocks.minted = {}, {}, {}
    Mocks.exported.run = function(_, kind, level) Mocks.hacks[#Mocks.hacks + 1] = kind .. ':' .. level; return Mocks.hackResult end
    Mocks.exported.getDoorFromName = function(name) return { id = name == 'vault_door' and 7 or nil } end
    Mocks.exported.setDoorState = function(id, state) Mocks.doors[#Mocks.doors + 1] = { id = id, state = state } end
    Mocks.exported.mintBills = function(_, worths, tag) Mocks.minted[#Mocks.minted + 1] = { worths = worths, tag = tag }; return { 'x' } end
    if open ~= false then
        local site = heistEnv.Config.sites[1]
        site.enabled, site.terminal, site.doors = true, vec3(0, 0, 0), { 'vault_door' }
        site.lootPoints = { vec3(50, 0, 0), vec3(100, 0, 0) }
    end
    local seen = {}
    local real = _G.TriggerClientEvent
    _G.TriggerClientEvent = function(name, target, payload)
        if name == 'som-heists:client:objective' then seen[#seen + 1] = { target = target, goal = payload } end
    end
    return heistEnv, seen, function() _G.TriggerClientEvent = real end
end

local function hinteract(source, kind) return RegisteredCallbacks['som-heists:server:interact'](source, kind) end

local function heistCrew(size, withDongle)
    crew(size)
    if withDongle ~= false then Mocks.exported.mintDongle(1, 'test') end
end

do
    local env, _, restore = heistScene(false)
    heistCrew(1, true)
    check(j(1, 'queue', { provider = 'heist_store' }).error == 'no sites are open yet', 'heist: every site ships disabled, so nothing can start')
    restore()
end

do
    local env, seen, restore = heistScene()
    crew(1)
    check(j(1, 'queue', { provider = 'heist_store' }).error == 'the leader needs a Trojan USB', 'heist: a run needs a dongle')
    Mocks.inv[1][90] = { name = 'trojan_usb', count = 1, slot = 90, metadata = { uid = '0123456789ABCDEF' } }
    check(j(1, 'queue', { provider = 'heist_store' }).error == 'the leader needs a Trojan USB', 'heist: a forged dongle with no ledger row does nothing')
    Mocks.inv[1][90] = nil
    Mocks.inv[1][91] = { name = 'trojan_usb', count = 1, slot = 91, metadata = {} }
    check(j(1, 'queue', { provider = 'heist_store' }).error == 'the leader needs a Trojan USB', 'heist: a dongle with no uid does nothing')
    Mocks.inv[1][91] = nil

    Mocks.players[5] = nil
    Mocks.exported.mintDongle(1, 'test')
    check(j(1, 'queue', { provider = 'heist_store' }).error == 'the city is too quiet for this', 'heist: not enough police on duty means no heist')
    Mocks.players[5] = { citizenid = 'P5', job = { name = 'police', onduty = true }, charinfo = { firstname = 'Po', lastname = 'Lice', phone = '555-0005' } }
    check(j(1, 'queue', { provider = 'heist_store' }).success == true, 'heist: with a dongle, police and an open site a group can wait')

    local uid
    for u in pairs(mysql.db.heist.dongles) do uid = u end
    local picked = boardEnv.JobBoard.Draw('heist_store')
    check(j(1, 'accept').success == true and mysql.db.heist.dongles[uid].status == 'used', 'heist: starting spends the dongle in the ledger')
    check(Mocks.exported.getGroup(1).busy == 'Store robbery' and #seen == 1 and seen[1].goal.kind == 'hack', 'heist: the crew is sent to the terminal')
    local copies = 0
    for _, it in pairs(Mocks.inv[1]) do if it.name == 'trojan_usb' then copies = copies + 1 end end
    check(copies == 0, 'heist: the item is taken from the leader')
    Mocks.inv[1][92] = { name = 'trojan_usb', count = 1, slot = 92, metadata = { uid = uid } }
    check(Mocks.exported.finish(picked) == true, 'heist: (setup) end the run to test the copy')
    check(j(1, 'view').view.sections[1].rows[1].action == nil, 'heist: a duplicated, already used dongle cannot start another run')
    restore()
end

do
    local env, seen, restore = heistScene()
    heistCrew(1)
    j(1, 'queue', { provider = 'heist_store' }); boardEnv.JobBoard.Draw('heist_store'); j(1, 'accept')
    FakePeds[1] = vec3(0, 0, 0)

    check(hinteract(1, 'loot').error == 'not yet' and hinteract(1, 'nope').success == false and hinteract(9, 'hack').error == 'you are not on a job', 'heist: stages are in order and outsiders are refused')
    FakePeds[1] = vec3(500, 0, 0)
    check(hinteract(1, 'hack').error == 'you are too far away', 'heist: the server checks the distance to the terminal')
    FakePeds[1] = vec3(0, 0, 0)

    Mocks.hackResult = false
    check(hinteract(1, 'hack').error == 'that did not work', 'heist: a failed hack is a failed hack')
    check(Mocks.calls.dispatchAlert == 1 and Mocks.lastAlertType == 'heistInProgress' and Mocks.lastAlertExtra.coords.x == 0, 'heist: the alarm goes to dispatch at the site, once')
    Mocks.hackResult = true
    check(hinteract(1, 'hack').success == true and Mocks.calls.dispatchAlert == 1, 'heist: a later success does not raise a second alarm')
    check(Mocks.hacks[1] == 'memory:easy' and #Mocks.doors == 1 and Mocks.doors[1].id == 7 and Mocks.doors[1].state == 0, 'heist: the tier picks the puzzle and the vault door opens')
    check(seen[#seen].goal.kind == 'loot' and seen[#seen].goal.index == 1, 'heist: the loot objective follows the hack')
    check(hinteract(1, 'hack').error == 'not yet', 'heist: the hack cannot be repeated for free')

    local treasury0, paid0 = Mocks.treasury, Mocks.calls.addMoney
    FakePeds[1] = vec3(0, 0, 0)
    check(hinteract(1, 'loot').error == 'you are too far away', 'heist: loot needs you at the loot point')
    FakePeds[1] = vec3(50, 0, 0)
    check(hinteract(1, 'loot').success == true, 'heist: taking loot works at the loot point')
    local cleanPaid = treasury0 - Mocks.treasury
    check(cleanPaid > 0 and Mocks.calls.addMoney == paid0 + 1 and Mocks.lastPaid.amount == cleanPaid, 'heist: clean cash comes out of the treasury, exactly what the player receives')
    check(#Mocks.minted == 1 and Mocks.minted[1].worths[1] == 300 and Mocks.minted[1].tag == 'heist:store_1', 'heist: marked bills are minted through the launder ledger')
    check(Mocks.treasury == treasury0 - cleanPaid, 'heist: the treasury is not charged for marked bills')
    FakePeds[1] = vec3(100, 0, 0)
    hinteract(1, 'loot')
    check(Mocks.exported.getGroup(1).busy == nil and mysql.db.heist.runs[1].status == 'done', 'heist: the last point ends the run and frees the group')
    check(hinteract(1, 'loot').error == 'you are not on a job' and seen[#seen].goal == nil, 'heist: nothing more to take, clients are cleared')

    heistCrew(1, false)
    Mocks.exported.mintDongle(1, 'test')
    g(1, 'ready', { ready = true })
    check(j(1, 'queue', { provider = 'heist_store' }).success == true, 'heist: (setup) a second group queues')
    boardEnv.JobBoard.Draw('heist_store')
    check(j(1, 'accept').success == false and Mocks.exported.getGroup(1).busy == nil, 'heist: the site is on cooldown after a run')
    local spentAfter
    for _, d in pairs(mysql.db.heist.dongles) do if d.status == 'issued' then spentAfter = true end end
    check(spentAfter == true, 'heist: a dongle is not spent when no site could be claimed')
    restore()
end

do
    local env, seen, restore = heistScene()
    heistCrew(1)
    j(1, 'queue', { provider = 'heist_store' }); boardEnv.JobBoard.Draw('heist_store'); j(1, 'accept')
    FakePeds[1] = vec3(0, 0, 0)
    Mocks.hackResult = false
    hinteract(1, 'hack')
    check(hinteract(1, 'hack').error == 'the system locked you out' and mysql.db.heist.runs[1].status == 'failed' and Mocks.exported.getGroup(1).busy == nil,
        'heist: two failed hacks lock the crew out and end the run')
    restore()

    env, seen, restore = heistScene()
    env.Config.tiers.store.hourlyCleanCap = 100
    heistCrew(1)
    j(1, 'queue', { provider = 'heist_store' }); boardEnv.JobBoard.Draw('heist_store'); j(1, 'accept')
    FakePeds[1] = vec3(0, 0, 0); hinteract(1, 'hack')
    local t0 = Mocks.treasury
    FakePeds[1] = vec3(50, 0, 0); hinteract(1, 'loot')
    FakePeds[1] = vec3(100, 0, 0); hinteract(1, 'loot')
    check(t0 - Mocks.treasury == 100, 'heist: the hourly clean cash cap holds across a run')
    restore()

    env, seen, restore = heistScene()
    Mocks.treasury = 0
    heistCrew(1)
    j(1, 'queue', { provider = 'heist_store' }); boardEnv.JobBoard.Draw('heist_store'); j(1, 'accept')
    FakePeds[1] = vec3(0, 0, 0); hinteract(1, 'hack')
    local m0 = Mocks.calls.addMoney
    FakePeds[1] = vec3(50, 0, 0); hinteract(1, 'loot')
    check(Mocks.calls.addMoney == m0 and Mocks.treasury == 0 and #Mocks.minted == 1, 'heist: an empty treasury pays no clean cash and creates none, bills are unaffected')
    restore()

    env, seen, restore = heistScene()
    heistCrew(1)
    j(1, 'queue', { provider = 'heist_store' }); boardEnv.JobBoard.Draw('heist_store'); j(1, 'accept')
    FakePeds[1] = vec3(0, 0, 0); hinteract(1, 'hack')
    Mocks.addMoneyFails = true
    local before = Mocks.treasury
    FakePeds[1] = vec3(50, 0, 0); hinteract(1, 'loot')
    check(Mocks.treasury == before, 'heist: a failed credit returns the money to the treasury')
    Mocks.addMoneyFails = false
    restore()
end

do
    local env, seen, restore = heistScene()
    heistCrew(1)
    j(1, 'queue', { provider = 'heist_store' }); boardEnv.JobBoard.Draw('heist_store'); j(1, 'accept')
    local real = os.time
    os.time = function() return real() + env.Config.minutes * 60 + 5 end
    env.Heists.Sweep()
    os.time = real
    check(mysql.db.heist.runs[1].status == 'failed' and Mocks.exported.getGroup(1).busy == nil, 'heist: a run that runs out of time fails and frees the group')

    local cmd = Mocks.commands.givedongle
    local said
    local realT = _G.TriggerClientEvent
    _G.TriggerClientEvent = function(name, target, text) if name == 'som:client:notify' then said = text end end
    cmd(2, { target = 2 })
    check(said == 'You do not have permission to do that', 'heist: only an admin can issue a dongle')
    Mocks.admins[2] = true
    cmd(2, { target = 2 })
    check(said:find('Issued dongle'), 'heist: an admin can issue a ledger backed dongle')
    _G.TriggerClientEvent = realT
    restore()
end

-- ---------------------------------------------------------------------------
-- Turf and the street drug market
-- ---------------------------------------------------------------------------

local function turfScene(open)
    resetDb()
    local env = loader.loadResource(REPO .. 'som-turf', { 'shared/config.lua', 'server/main.lua' })
    Mocks.players = {
        [1] = { citizenid = 'T1', gang = { name = 'ballas', grade = 2 } },
        [2] = { citizenid = 'T2', gang = { name = 'vagos', grade = 2 } },
        [3] = { citizenid = 'T3', gang = { name = 'none', grade = 0 } },
        [4] = { citizenid = 'T4', gang = { name = 'ballas', grade = 0 } },
        [5] = { citizenid = 'T5', gang = { name = 'families', grade = 2 } },
    }
    Mocks.inv = { [1] = {}, [2] = {} }
    Mocks.minted = {}
    Mocks.exported.mintBills = function(_, worths, tag) Mocks.minted[#Mocks.minted + 1] = { worths = worths, tag = tag }; return { 'x' } end
    Mocks.calls.dispatchAlert = 0
    Mocks.clock = 1000000
    mysql.fakeNow = 5000000
    if open ~= false then
        local z = env.Config.zones[1]
        z.enabled, z.center, z.radius, z.tag = true, vec3(0, 0, 0), 50.0, vec3(10, 0, 0)
    end
    mysql.db.turf.zones.grove = { owner = nil }
    for _, id in ipairs({ 1, 2, 3, 4, 5 }) do FakePeds[id] = vec3(10, 0, 0) end
    return env
end

local function tagFor(source, name)
    local began = RegisteredCallbacks['som-turf:server:tagBegin'](source, name)
    if not began.success then return began end
    Mocks.clock = Mocks.clock + 20000
    return RegisteredCallbacks['som-turf:server:tagFinish'](source, name)
end

local function sell(source, name, item) return RegisteredCallbacks['som-turf:server:sell'](source, name, item) end

do
    local env = turfScene(false)
    check(RegisteredCallbacks['som-turf:server:tagBegin'](1, 'grove').error == 'there is nothing to claim here', 'turf: every zone ships disabled')
    check(#RegisteredCallbacks['som-turf:server:zones'](1).zones == 0, 'turf: disabled zones are not sent to clients')
end

do
    local env = turfScene()
    check(tagFor(3, 'grove').error == 'you are not in a gang', 'turf: a civilian cannot tag')
    check(tagFor(4, 'grove').error == 'your rank is too low to claim turf', 'turf: a recruit cannot claim turf')
    FakePeds[1] = vec3(500, 0, 0)
    check(tagFor(1, 'grove').error == 'you are too far away', 'turf: tagging needs you at the wall')
    FakePeds[1] = vec3(10, 0, 0)
    check(RegisteredCallbacks['som-turf:server:tagBegin'](1, 'nope').error == 'there is nothing to claim here', 'turf: an unknown zone is refused')

    check(RegisteredCallbacks['som-turf:server:tagFinish'](1, 'grove').error == 'you have not started tagging', 'turf: finishing without starting is refused')
    RegisteredCallbacks['som-turf:server:tagBegin'](1, 'grove')
    Mocks.clock = Mocks.clock + 2000
    check(RegisteredCallbacks['som-turf:server:tagFinish'](1, 'grove').error == 'you were too quick', 'turf: a skipped progress bar does not claim')

    check(tagFor(1, 'grove').success == true and mysql.db.turf.zones.grove.owner == 'ballas', 'turf: an unowned zone is claimed by the tagger\'s gang')
    check(mysql.db.turf.events[1].action == 'claim', 'turf: the claim is logged')
    check(tagFor(1, 'grove').error == 'this is already yours and nobody is contesting it', 'turf: tagging your own quiet turf does nothing')

    check(tagFor(2, 'grove').success == true and mysql.db.turf.zones.grove.contested_by == 'vagos' and mysql.db.turf.zones.grove.owner == 'ballas', 'turf: a rival tag only contests')
    check(tagFor(2, 'grove').error == 'it is not time yet', 'turf: the rival must wait out the hold window')
    check(tagFor(5, 'grove').error == 'another gang is already contesting this', 'turf: a third gang cannot jump the queue')

    mysql.fakeNow = mysql.fakeNow + env.Config.holdMinutes * 60 + 1
    check(tagFor(2, 'grove').success == true and mysql.db.turf.zones.grove.owner == 'vagos' and mysql.db.turf.zones.grove.contested_by == nil, 'turf: after the window a second tag takes the zone')

    tagFor(1, 'grove')
    check(mysql.db.turf.zones.grove.contested_by == 'ballas', 'turf: the old owner can contest back')
    check(tagFor(2, 'grove').success == true and mysql.db.turf.zones.grove.contested_by == nil and mysql.db.turf.zones.grove.owner == 'vagos', 'turf: the owner defending clears a contest')
end

do
    local env = turfScene()
    mysql.db.turf.zones.grove.owner = 'ballas'
    Mocks.inv[1][1] = { name = 'weed_ogkush', count = 1, slot = 1 }
    check(sell(3, 'grove', 'weed_ogkush').error == 'you are not in a gang', 'turf: a civilian cannot sell on a gang corner')
    check(sell(1, 'grove', 'iron_ore').error == 'nobody wants that', 'turf: only listed drugs sell')
    check(sell(2, 'grove', 'weed_ogkush').error == 'this is not your turf', 'turf: a rival gang cannot sell here')
    FakePeds[1] = vec3(500, 0, 0)
    check(sell(1, 'grove', 'weed_ogkush').error == 'you are too far away', 'turf: selling needs you inside the zone')
    FakePeds[1] = vec3(10, 0, 0)
    Mocks.inv[1] = {}
    check(sell(1, 'grove', 'weed_ogkush').error == 'you have nothing to sell', 'turf: you cannot sell what you do not carry')

    Mocks.clock = Mocks.clock + 60000
    Mocks.inv[1][1] = { name = 'weed_ogkush', count = 1, slot = 1 }
    local r = sell(1, 'grove', 'weed_ogkush')
    check(r.success == true and Mocks.minted[1].worths[1] == 110 and Mocks.minted[1].tag == 'turf:grove', 'turf: a sale pays base plus the owner bonus in marked bills')
    check(Mocks.inv[1][1] == nil and mysql.db.turf.market.weed_ogkush.units == 1, 'turf: the item is taken and the market records the unit')
    check(Mocks.calls.addMoney == 0 and Mocks.calls.dispatchAlert == 1, 'turf: no clean cash is created and dispatch is told')

    Mocks.inv[1][2] = { name = 'weed_ogkush', count = 1, slot = 2 }
    Mocks.clock = Mocks.clock + 1000
    check(sell(1, 'grove', 'weed_ogkush').error == 'wait a moment', 'turf: sales have a cooldown')

    Mocks.clock = Mocks.clock + 60000
    mysql.db.turf.market.weed_ogkush.units = 20
    sell(1, 'grove', 'weed_ogkush')
    check(Mocks.minted[2].worths[1] == 66, 'turf: a flooded market pays less, down to the floor')

    mysql.db.turf.market.weed_ogkush = { units = 20, ts = mysql.fakeNow - 7200 }
    Mocks.inv[1][3] = { name = 'weed_ogkush', count = 1, slot = 3 }
    Mocks.clock = Mocks.clock + 60000
    sell(1, 'grove', 'weed_ogkush')
    check(Mocks.minted[3].worths[1] == 110, 'turf: the price recovers with time')

    Mocks.inv[1][4] = { name = 'weed_ogkush', count = 1, slot = 4 }
    Mocks.clock = Mocks.clock + 60000
    Mocks.exported.mintBills = function() return nil, 'could not carry the bills' end
    local failed = sell(1, 'grove', 'weed_ogkush')
    local back = false
    for _, it in pairs(Mocks.inv[1]) do if it.name == 'weed_ogkush' and it.slot ~= 4 then back = true end end
    check(failed.success == false and (Mocks.inv[1][4] ~= nil or back), 'turf: the drug is returned when the bills cannot be issued')
end

-- ---------------------------------------------------------------------------
-- Whitelist
-- ---------------------------------------------------------------------------

do
    resetDb()
    local env = loader.loadResource(REPO .. 'som-staff', { 'shared/config.lua', 'server/whitelist.lua' })
    Mocks.identifiers = { [7] = { 'license:abc123', 'discord:555' } }
    Mocks.convars = {}
    Mocks.admins = {}

    local function connect(src)
        local out = { deferred = false }
        local deferrals = { defer = function() out.deferred = true end, done = function(msg) out.done = true; out.msg = msg end }
        _G.source = src
        Handlers['playerConnecting']('x', function() end, deferrals)
        return out
    end

    check(connect(7).deferred == false, 'whitelist: the gate is off unless the convar is set')
    Mocks.convars.som_whitelist = '1'
    local r = connect(7)
    check(r.done and r.msg == env.Config.deniedMessage, 'whitelist: an unlisted player is turned away')

    check(env.Whitelist.Add('License:ABC123', 'ok', 'console') == true and mysql.db.whitelist['license:abc123'] ~= nil, 'whitelist: identifiers are normalised on add')
    r = connect(7)
    check(r.done and r.msg == nil, 'whitelist: a listed player connects')
    check(env.Whitelist.Add('license:abc123') == false, 'whitelist: adding twice is refused')
    check(env.Whitelist.Add('ip:1.2.3.4') == false and env.Whitelist.Add("license:x' OR 1") == false and env.Whitelist.Add(5) == false, 'whitelist: only known identifier kinds with plain values are accepted')

    Mocks.identifiers[8] = { 'discord:555' }
    check(connect(8).msg == env.Config.deniedMessage, 'whitelist: an unlisted identifier does not match another')
    env.Whitelist.Add('discord:555')
    check(connect(8).msg == nil, 'whitelist: any listed identifier is enough')
    check(env.Whitelist.Remove('discord:555') == true and connect(8).msg ~= nil, 'whitelist: removing takes effect on the next connect')

    local said
    local realT = _G.TriggerClientEvent
    _G.TriggerClientEvent = function(name, target, text) if name == 'som:client:notify' then said = text end end
    Mocks.commands.whitelist(2, { action = 'add', identifier = 'license:zzz' })
    check(said == 'You do not have permission to do that' and mysql.db.whitelist['license:zzz'] == nil, 'whitelist: only an admin can change the list')
    Mocks.admins[2] = true
    Mocks.commands.whitelist(2, { action = 'add', identifier = 'license:zzz', note = 'n' })
    check(said == 'Added' and mysql.db.whitelist['license:zzz'].added_by == '2', 'whitelist: an admin can add and the list records who')
    _G.TriggerClientEvent = realT
    Mocks.convars = {}
end

-- ---------------------------------------------------------------------------
-- Staff tools
-- ---------------------------------------------------------------------------

do
    resetDb()
    loader.loadResource(REPO .. 'som-staff', { 'shared/config.lua', 'server/staff.lua' })
    Mocks.players = { [1] = { citizenid = 'P1' }, [2] = { citizenid = 'P2' }, [3] = { citizenid = 'P3' } }
    Mocks.admins = { [3] = true }
    FakePeds = { [1] = vec3(1, 2, 3), [2] = vec3(40, 50, 60), [3] = vec3(7, 8, 9) }
    Mocks.clock = 1000000
    Teleports = {}
    local said = {}
    local realT = _G.TriggerClientEvent
    _G.TriggerClientEvent = function(name, target, text) if name == 'som:client:notify' then said[target] = text end end
    local rep = RegisteredCallbacks['som-staff:server:reports']
    local act = RegisteredCallbacks['som-staff:server:reportAction']

    Mocks.commands.report(1, { message = '  my car\1 is stuck  ' })
    check(mysql.db.staff.reports[1].message == 'my car is stuck' and said[1] == 'Report #1 sent', 'staff: a report is cleaned and stored')
    check(said[3] == 'New report #1', 'staff: on duty staff are told')
    Mocks.clock = Mocks.clock + 120000
    Mocks.commands.report(1, { message = 'again' })
    check(#mysql.db.staff.reports == 1 and said[1] == 'You already have an open report', 'staff: one open report per character')
    Mocks.commands.report(2, { message = '   ' })
    check(#mysql.db.staff.reports == 1, 'staff: an empty report is refused')
    Mocks.commands.report(2, { message = string.rep('x', 500) })
    check(#mysql.db.staff.reports[2].message == 200, 'staff: report text is capped')

    check(rep(1) == nil and act(1, 1, 'claim').success == false, 'staff: players cannot read or work the queue')
    check(#rep(3) == 2, 'staff: staff see open reports')
    check(act(3, 'x', 'claim').error == 'bad request' and act(3, 1, 'drop').error == 'bad request', 'staff: report actions are validated')
    check(act(3, 1, 'claim').success == true and mysql.db.staff.reports[1].claimed_by == 'P3', 'staff: a report can be claimed')
    check(act(3, 1, 'claim').success == false, 'staff: a claimed report cannot be claimed twice')
    check(act(3, 1, 'close').success == true and #rep(3) == 1, 'staff: a closed report leaves the queue')
    check(mysql.db.staff.audit[1].action == 'report_claim' and mysql.db.staff.audit[2].action == 'report_close', 'staff: queue actions are audited')

    Mocks.commands['goto'](1, { target = 2 })
    check(#Teleports == 0 and said[1] == 'You do not have permission to do that', 'staff: a player cannot teleport')
    Mocks.commands['goto'](3, { target = 2 })
    check(Teleports[1].ped == 3 and Teleports[1].x == 40, 'staff: goto moves staff to the player')
    Mocks.commands.bring(3, { target = 2 })
    check(Teleports[2].ped == 2 and Teleports[2].x == 7, 'staff: bring moves the player to staff')
    Mocks.commands['goto'](3, { target = 3 })
    check(#Teleports == 2 and said[3] == 'No such player', 'staff: you cannot target yourself')
    check(mysql.db.staff.audit[3].action == 'goto' and mysql.db.staff.audit[3].target == 'P2' and mysql.db.staff.audit[4].action == 'bring', 'staff: teleports are audited')

    local spec
    _G.TriggerClientEvent = function(name, target, arg) if name == 'som-staff:client:spectate' then spec = { target = target, arg = arg } end end
    Mocks.commands.spectate(1, { target = 2 })
    check(spec == nil, 'staff: a player cannot spectate')
    Mocks.commands.spectate(3, { target = 2 })
    check(spec.target == 3 and spec.arg == 2 and mysql.db.staff.audit[5].action == 'spectate', 'staff: spectate sends the target to staff only and is audited')
    _G.TriggerClientEvent = realT
end

-- ---------------------------------------------------------------------------
-- Gang management
-- ---------------------------------------------------------------------------

local function gangScene()
    resetDb()
    local env = loader.loadResource(REPO .. 'som-turf', { 'shared/config.lua', 'server/gang.lua' })
    local function ballas(grade) return { name = 'ballas', label = 'Ballas', grade = grade, isboss = grade == 4 } end
    local none = { name = 'none', label = 'No Gang', grade = 0, isboss = false }
    local function char(first, last, phone, gang, grade)
        return { citizenid = 'G' .. phone, job = { name = 'unemployed' }, gang = gang, charinfo = { firstname = first, lastname = last, phone = phone } }
    end
    Mocks.players = {
        [1] = char('Big', 'Boss', '555-0001', ballas(4)),
        [2] = char('Mem', 'Ber', '555-0002', ballas(1)),
        [3] = char('New', 'Guy', '555-0003', none),
        [4] = char('Sec', 'Ond', '555-0004', ballas(4)),
    }
    mysql.db.characters = { ['555-0001'] = 'G555-0001', ['555-0002'] = 'G555-0002', ['555-0003'] = 'G555-0003', ['555-0004'] = 'G555-0004' }
    mysql.db.gangs.chars = {
        ['G555-0001'] = { gang = 'ballas', grade = 4, first = 'Big', last = 'Boss' },
        ['G555-0002'] = { gang = 'ballas', grade = 1, first = 'Mem', last = 'Ber' },
        ['G555-0003'] = { gang = 'none', grade = 0, first = 'New', last = 'Guy' },
        ['G555-0009'] = { gang = 'ballas', grade = 2, first = 'Off', last = 'Line' },
    }
    for i, p in pairs(Mocks.players) do p.source = i end
    Mocks.gangFunds, Mocks.bank, Mocks.gangLedger, Mocks.gangFails = {}, { [1] = 1000 }, {}, false
    for i = 1, 4 do FakePeds[i] = vec3(0, 0, 0) end
    return env
end

local function gact(source, action, payload) return Mocks.apps.gang.handler(source, action, payload or {}) end

do
    local env = gangScene()
    local v = gact(2, 'view').view
    check(#v.buttons == 1 and v.buttons[1].action == 'leave', 'gang: a member sees only leave')
    v = gact(1, 'view').view
    check(#v.sections[1].rows == 3 and v.sections[1].rows[1].title:find('Big Boss'), 'gang: a boss sees the roster, offline members included, boss first')
    check(#v.buttons == 6, 'gang: a boss gets the management buttons')
    check(gact(3, 'view').view.empty == 'You are not in a gang', 'gang: a civilian sees an empty state')

    check(gact(2, 'invite', { number = '5550003' }).error == 'only a boss can invite', 'gang: a member cannot invite')
    check(gact(1, 'invite', { number = 'abc' }).error == 'that is not a phone number', 'gang: the number is validated')
    check(gact(1, 'invite', { number = '5559999' }).error == 'that person is not around', 'gang: an unknown number is refused')
    check(gact(1, 'invite', { number = '5550002' }).error == 'they are already in a gang', 'gang: someone in a gang cannot be invited')
    FakePeds[3] = vec3(500, 0, 0)
    check(gact(1, 'invite', { number = '5550003' }).error == 'they need to be next to you', 'gang: invites need distance')
    FakePeds[3] = vec3(0, 0, 0)
    local inv = gact(1, 'invite', { number = '555-0003' })
    check(inv.success == true, 'gang: a boss can invite a nearby civilian')
    check(gact(3, 'view').view.sections[1].title == 'Invitation', 'gang: the invitee sees the invitation')
    check(gact(3, 'accept').success == true and mysql.db.gangs.chars['G555-0003'].gang == 'ballas' and Mocks.players[3].gang.name == 'ballas', 'gang: accepting joins at the lowest rank, in the database and live')
    check(gact(3, 'accept').error == 'you are already in a gang' and mysql.db.gangs.log[1].action == 'join', 'gang: joining is logged and not repeatable')

    gact(1, 'view')
    local rows = gact(1, 'view').view.sections[1].rows
    local function indexOf(name) for i, r in ipairs(rows) do if r.title:find(name) then return tostring(i) end end end
    local mem, off = indexOf('Mem Ber'), indexOf('Off Line')
    check(gact(1, 'rank', { step = 2, member = mem }).error == 'bad request', 'gang: rank steps are validated')
    check(gact(1, 'rank', { step = 1, member = mem }).success == true and mysql.db.gangs.chars['G555-0002'].grade == 2 and Mocks.players[2].gang.grade == 2, 'gang: a boss can promote an online member')
    check(gact(1, 'rank', { step = -1, member = off }).success == true and mysql.db.gangs.chars['G555-0009'].grade == 1, 'gang: an offline member can be demoted')
    check(gact(1, 'rank', { step = 1, member = indexOf('Big Boss') }).error == 'that is you', 'gang: a boss cannot rank themselves')
    check(gact(2, 'rank', { step = 1, member = mem }).error == 'only a boss can change ranks', 'gang: a member cannot rank anyone')
    check(gact(1, 'rank', { step = 1, member = '99' }).error == 'open the app again, then pick a member', 'gang: an unknown member number is refused')

    mysql.db.gangs.chars['G555-0002'].grade = 4
    Mocks.players[2].gang = { name = 'ballas', label = 'Ballas', grade = 4, isboss = true }
    check(gact(1, 'kick', { member = mem }).error == 'they outrank you or match your rank', 'gang: a boss cannot touch a peer')
    mysql.db.gangs.chars['G555-0002'].grade = 2
    Mocks.players[2].gang = { name = 'ballas', label = 'Ballas', grade = 2, isboss = false }
    rows = gact(1, 'view').view.sections[1].rows
    mem, off = indexOf('Mem Ber'), indexOf('Off Line')
    check(gact(1, 'kick', { member = mem }).success == true and mysql.db.gangs.chars['G555-0002'].gang == 'none' and Mocks.players[2].gang.name == 'none', 'gang: a boss can remove a member')
    check(gact(1, 'kick', { member = off }).success == true and mysql.db.gangs.chars['G555-0009'].gang == 'none', 'gang: an offline member can be removed')
    check(gact(1, 'kick', { member = off }).error == 'they are not in the gang any more', 'gang: a stale removal does nothing')

    check(gact(1, 'leave').error == 'promote someone to boss before you leave', 'gang: the last boss cannot walk away')
end

do
    local env = gangScene()
    check(gact(2, 'deposit', { amount = '100' }).error == 'only a boss can pay in', 'gang: a member cannot deposit')
    check(gact(1, 'deposit', { amount = '1.5' }).success == false and gact(1, 'deposit', { amount = '-5' }).success == false and gact(1, 'deposit', { amount = '999999' }).success == false, 'gang: deposit amounts are validated')
    check(gact(1, 'deposit', { amount = '5000' }).error == 'not enough in your bank', 'gang: you cannot deposit what you do not have')
    check(gact(1, 'deposit', { amount = '400' }).success == true and Mocks.bank[1] == 600 and Mocks.gangFunds.ballas == 400, 'gang: a deposit moves money from the boss to the account')
    Mocks.gangFails = true
    local paid0 = Mocks.paid or 0
    check(gact(1, 'deposit', { amount = '100' }).success == false and (Mocks.paid or 0) == paid0 + 100, 'gang: a failed credit refunds the boss')
    Mocks.gangFails = false
    check(mysql.db.gangs.log[#mysql.db.gangs.log].action == 'deposit', 'gang: deposits are logged')
    check(gact(1, 'leave').error ~= nil, 'gang: (setup) a lone boss cannot leave')
    gact(4, 'view')
    mysql.db.gangs.chars['G555-0004'] = { gang = 'ballas', grade = 4, first = 'Sec', last = 'Ond' }
    check(gact(1, 'leave').success == true and Mocks.players[1].gang.name == 'none', 'gang: a boss can leave when another boss remains')
end

print(('%d passed, %d failed'):format(results.pass, results.fail))
os.exit(results.fail == 0 and 0 or 1)
