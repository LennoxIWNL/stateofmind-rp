-- Job definitions. Data, not code: adding a job never means adding a resource.
--
-- Shape is seeded from the qbx_core jobs schema (label, type, defaultDuty,
-- offDutyPay, grades[n] = {name, payment, isboss}) and extended with the fields
-- Phase 4 and Phase 5 need:
--   business    business register entry payroll is drawn from, see som_businesses
--   whitelisted job requires an approved application, no /setjob
--   armoryGrade minimum grade for armoury access
--   radio       radio channel assigned on duty
--
-- payment is per paycheck interval (Config.Money.paycheckInterval), not per hour.

Jobs = {
    unemployed = {
        label = 'Civilian',
        defaultDuty = true,
        offDutyPay = true,
        grades = {
            [0] = { name = 'Unemployed', payment = 10 },
        },
    },

    police = {
        label = 'Law Enforcement',
        type = 'leo',
        business = 'lspd',
        whitelisted = true,
        defaultDuty = false,
        offDutyPay = false,
        armoryGrade = 1,
        radio = 1,
        grades = {
            [0] = { name = 'Cadet', payment = 75 },
            [1] = { name = 'Officer', payment = 100 },
            [2] = { name = 'Sergeant', payment = 125 },
            [3] = { name = 'Lieutenant', payment = 150 },
            [4] = { name = 'Chief', payment = 200, isboss = true },
        },
    },

    ambulance = {
        label = 'Emergency Medical Services',
        type = 'ems',
        business = 'pillbox',
        whitelisted = true,
        defaultDuty = false,
        offDutyPay = false,
        armoryGrade = 0,
        radio = 2,
        grades = {
            [0] = { name = 'Trainee', payment = 75 },
            [1] = { name = 'Paramedic', payment = 100 },
            [2] = { name = 'Doctor', payment = 140 },
            [3] = { name = 'Surgeon', payment = 170 },
            [4] = { name = 'Chief of Medicine', payment = 200, isboss = true },
        },
    },

    mechanic = {
        label = 'Mechanic',
        business = 'lscustoms',
        whitelisted = true,
        defaultDuty = true,
        offDutyPay = false,
        radio = 3,
        grades = {
            [0] = { name = 'Apprentice', payment = 50 },
            [1] = { name = 'Mechanic', payment = 80 },
            [2] = { name = 'Lead Mechanic', payment = 110 },
            [3] = { name = 'Owner', payment = 150, isboss = true },
        },
    },

    -- Template civilian jobs. Copy either one to add a new civilian job:
    -- no new resource is needed, only a new entry here plus locations in
    -- som-jobs once Phase 5 lands.
    taxi = {
        label = 'Downtown Cab Co.',
        business = 'downtowncab',
        whitelisted = false,
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = { name = 'Driver', payment = 40 },
            [1] = { name = 'Dispatcher', payment = 60 },
            [2] = { name = 'Manager', payment = 90, isboss = true },
        },
    },

    delivery = {
        label = 'Postal Delivery',
        business = 'postop',
        whitelisted = false,
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = { name = 'Courier', payment = 40 },
            [1] = { name = 'Driver', payment = 60 },
            [2] = { name = 'Depot Manager', payment = 90, isboss = true },
        },
    },
}
