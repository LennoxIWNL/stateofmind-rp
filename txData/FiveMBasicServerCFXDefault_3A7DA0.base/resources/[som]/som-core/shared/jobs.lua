-- Job definitions. Data, not code: adding a job never means adding a resource.
--
-- Shape is seeded from the qbx_core jobs schema (label, type, defaultDuty,
-- offDutyPay, grades[n] = {name, payment, isboss}) and extended with the fields
-- Phase 4 and Phase 5 need:
--   business    business register entry payroll is drawn from, see som_businesses
--   whitelisted job requires an approved application, no /setjob
--   armoryGrade minimum grade for armoury access
--   radio       radio channel assigned on duty
--   commission  share of a sale the employee keeps, see below
--
-- PAYMENT IS PER HOUR. Paychecks run hourly (Config.Money.paycheckInterval),
-- and som-core caps every payout at Config.Money.maxHourlyPaycheck regardless
-- of what is written here.
--
-- TWO KINDS OF JOB
--
-- Government work (police, EMS) pays a real salary, because there is nothing
-- to sell and the city funds it.
--
-- Player-owned businesses pay a deliberately low base and make their money
-- through `commission`: a share of each sale that employee personally makes.
-- Standing around on the clock earns almost nothing; actually serving
-- customers earns well. That is the incentive worth having, and it is why a
-- burger flipper is on 300 an hour rather than a salary.

Jobs = {
    unemployed = {
        label = 'Civilian',
        defaultDuty = true,
        offDutyPay = true,
        grades = {
            -- A floor, not a living. Enough to not be stranded.
            [0] = { name = 'Unemployed', payment = 150 },
        },
    },

    police = {
        label = 'Los Santos Police Department',
        type = 'leo',
        business = 'lspd',
        whitelisted = true,
        defaultDuty = false,
        offDutyPay = false,
        armoryGrade = 0,
        radio = 1,
        -- Seven ranks on the LSPD ladder. Grades are zero indexed here, so the
        -- seventh rank is grade 6.
        --
        -- Rank is SENIORITY ONLY. It decides pay, who can promote whom, and who
        -- reads the command-level parts of the MDT. It deliberately does not
        -- decide what an officer is allowed to carry or drive: that is what
        -- certifications are for, and they are an independent axis, so a
        -- Lieutenant with no rifle certification still cannot draw a rifle.
        --
        -- Anything that gates on grade elsewhere has to be checked when this
        -- list changes. ps-mdt's four record-deletion permissions were pinned to
        -- grade 4 because that used to be the Chief; adding ranks would have
        -- quietly handed them to a Sergeant.
        grades = {
            [0] = { name = 'Cadet', payment = 1200 },
            [1] = { name = 'Officer', payment = 1600 },
            [2] = { name = 'Senior Officer', payment = 2000 },
            [3] = { name = 'Corporal', payment = 2400 },
            [4] = { name = 'Sergeant', payment = 2900 },
            [5] = { name = 'Lieutenant', payment = 3500, isboss = true },
            [6] = { name = 'Chief of Police', payment = 4200, isboss = true },
        },
    },

    ambulance = {
        label = 'San Andreas Medical Services',
        type = 'ems',
        business = 'ems',
        whitelisted = true,
        defaultDuty = false,
        offDutyPay = false,
        armoryGrade = 0,
        radio = 2,
        grades = {
            [0] = { name = 'Trainee', payment = 1200 },
            [1] = { name = 'Paramedic', payment = 1800 },
            [2] = { name = 'Doctor', payment = 2400 },
            [3] = { name = 'Surgeon', payment = 3200 },
            [4] = { name = 'Chief of Medicine', payment = 4200, isboss = true },
        },
    },

    firefighter = {
        label = 'San Andreas Fire Department',
        type = 'ems',
        business = 'fire',
        whitelisted = true,
        defaultDuty = false,
        offDutyPay = false,
        radio = 2,
        grades = {
            [0] = { name = 'Probationary Firefighter', payment = 1200 },
            [1] = { name = 'Firefighter', payment = 1700 },
            [2] = { name = 'Engineer', payment = 2200 },
            [3] = { name = 'Captain', payment = 2900 },
            [4] = { name = 'Fire Chief', payment = 3800 },
        },
    },

    -- Radio dispatch. Hears every call, and assigns, closes and declares major
    -- incidents through som-dispatch. Paid by the department it works for.
    dispatcher = {
        label = 'Emergency Dispatch',
        type = 'leo',
        business = 'lspd',
        whitelisted = true,
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            [0] = { name = 'Dispatcher', payment = 1500 },
            [1] = { name = 'Senior Dispatcher', payment = 2200 },
            [2] = { name = 'Dispatch Supervisor', payment = 2800, isboss = true },
        },
    },

    -- The DOJ is three jobs, not three grades of one. A single ladder lets a
    -- defender be promoted onto the bench, which is the separation of powers
    -- this department exists to keep. som-court gates each power with one
    -- grade threshold per job.
    judge = {
        label = 'Superior Court',
        type = 'doj',
        business = 'doj',
        whitelisted = true,
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            [0] = { name = 'Court Clerk', payment = 1400 },
            [1] = { name = 'Magistrate', payment = 2800 },
            [2] = { name = 'Judge', payment = 4200 },
            [3] = { name = 'Chief Judge', payment = 5200, isboss = true },
        },
    },

    prosecutor = {
        label = 'District Attorney',
        type = 'doj',
        business = 'doj',
        whitelisted = true,
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            [0] = { name = 'Assistant Prosecutor', payment = 2400 },
            [1] = { name = 'Prosecutor', payment = 3200 },
            [2] = { name = 'District Attorney', payment = 4500, isboss = true },
        },
    },

    defender = {
        label = 'Public Defender',
        type = 'doj',
        business = 'doj',
        whitelisted = true,
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            [0] = { name = 'Defender', payment = 2000 },
            [1] = { name = 'Senior Defender', payment = 3000 },
            [2] = { name = 'Chief Defender', payment = 3800, isboss = true },
        },
    },

    -- Player-owned from here down: low base, real money from commission.
    mechanic = {
        label = 'Los Santos Customs',
        business = 'lscustoms',
        whitelisted = true,
        defaultDuty = true,
        offDutyPay = false,
        radio = 3,
        commission = 0.12,
        grades = {
            [0] = { name = 'Apprentice', payment = 250 },
            [1] = { name = 'Mechanic', payment = 300 },
            [2] = { name = 'Lead Mechanic', payment = 380 },
            [3] = { name = 'Owner', payment = 450, isboss = true },
        },
    },

    -- Tow driver. No business and no salary on purpose: the only income is the per tow fee som-tow pays from
    -- the department, so standing on duty earns nothing. Not whitelisted; staff can make it so.
    tow = {
        label = 'Tow Driver',
        whitelisted = false,
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            [0] = { name = 'Driver', payment = 0 },
        },
    },

    -- Template civilian jobs. Copy either one to add a new civilian job: no
    -- new resource is needed, only a new entry here plus locations in som-jobs
    -- once Phase 5 lands.
    -- The dealership. Whitelisted, because a managed sale moves real money out
    -- of a business account as commission, and an open job would be a faucet
    -- anybody could turn on.
    --
    -- defaultDuty is FALSE here, unlike the mechanic. A dealer on duty is what
    -- makes the showroom sell at all, so going on shift has to be a deliberate
    -- act rather than a side effect of logging in: an AFK dealer standing in
    -- the showroom would otherwise be the only one who can serve anybody.
    cardealer = {
        label = 'Premium Deluxe Motorsport',
        business = 'pdm',
        whitelisted = true,
        defaultDuty = false,
        offDutyPay = false,
        -- Commission is the pay. The wage is a retainer, not a living, or a
        -- dealer earns the same standing still as selling.
        commission = 0.08,
        grades = {
            [0] = { name = 'Salesperson', payment = 200 },
            [1] = { name = 'Senior Salesperson', payment = 250 },
            [2] = { name = 'Sales Manager', payment = 300 },
            [3] = { name = 'Owner', payment = 350, isboss = true },
        },
    },

    -- Dynasty 8. The same shape as the dealership and for the same reasons.
    --
    -- defaultDuty is FALSE: an estate agent on duty is what makes the luxury
    -- tier sellable at all, and a mortgage cannot be written without one, so
    -- going on shift has to be a deliberate act rather than a side effect of
    -- logging in.
    --
    -- Commission is higher than the car dealer's because a property sells far
    -- less often. A dealer moves several cars a shift; an agent may write one
    -- contract a week.
    realtor = {
        label = 'Dynasty 8 Real Estate',
        business = 'dynasty8',
        whitelisted = true,
        defaultDuty = false,
        offDutyPay = false,
        commission = 0.12,
        grades = {
            [0] = { name = 'Agent', payment = 200 },
            [1] = { name = 'Senior Agent', payment = 250 },
            [2] = { name = 'Branch Manager', payment = 320 },
            [3] = { name = 'Broker', payment = 400, isboss = true },
        },
    },

    taxi = {
        label = 'Downtown Cab Co.',
        business = 'downtowncab',
        whitelisted = false,
        defaultDuty = true,
        offDutyPay = false,
        commission = 0.20,
        grades = {
            [0] = { name = 'Driver', payment = 250 },
            [1] = { name = 'Dispatcher', payment = 300 },
            [2] = { name = 'Manager', payment = 400, isboss = true },
        },
    },

    delivery = {
        label = 'Post OP',
        business = 'postop',
        whitelisted = false,
        defaultDuty = true,
        offDutyPay = false,
        commission = 0.18,
        grades = {
            [0] = { name = 'Courier', payment = 250 },
            [1] = { name = 'Driver', payment = 300 },
            [2] = { name = 'Depot Manager', payment = 400, isboss = true },
        },
    },

    -- Weazel News. Whitelisted and off duty by default: only an on duty reporter can publish, and
    -- each story pays from the city treasury under a cap (som-news), not from the wage below.
    news = {
        label = 'Weazel News',
        business = 'weazel',
        whitelisted = true,
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            [0] = { name = 'Reporter', payment = 150 },
            [1] = { name = 'Anchor', payment = 200 },
            [2] = { name = 'Editor', payment = 250, isboss = true },
        },
    },
}
