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
    mysql.db.nextId = { properties = 1, owners = 1, finance = 1, jailSentences = 1, jailBail = 1,
                        courtCases = 1, courtEvents = 1, courtWarrants = 1, service = 1, evidence = 1, custody = 1 }
    mysql.fakeNow = nil
end

local function resetMocks()
    Mocks.calls = { payWith = 0, addMoney = 0, businessSpend = 0, dispatchAlert = 0, businessTransact = 0 }
    Mocks.players = {}
    Mocks.payWithFails = false
    Mocks.businessSpendFails = false
    Mocks.admins = {}
    Mocks.fines = {}
    Mocks.fineFails = false
    Mocks.exported = {}
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
print(('%d passed, %d failed'):format(results.pass, results.fail))
os.exit(results.fail == 0 and 0 or 1)
