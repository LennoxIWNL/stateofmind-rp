-- som-medical configuration.
--
-- DESIGN, decided by the owner and deliberately not the qb/qbx model:
--
--   Down is down.
--
-- No crawling. No last stand. No second down after being helped up. You are on
-- the ground, you can talk, and that is the whole of it. The qbx_medical and
-- qb-ambulancejob loop of crawl, recover, get downed again turns a shooting
-- into a negotiation about hit points, and it is the thing this deliberately
-- does not do.
--
-- Everything here decides what is OFFERED. The server re-derives every number
-- before it acts on it.

Config = {}

-- ---------------------------------------------------------------------------
-- Being down
-- ---------------------------------------------------------------------------

-- Health the ped is held at while down. Above zero so the ped is technically
-- alive, which is what keeps voice working: a dead ped cannot talk, and being
-- able to talk is the entire point of the state.
Config.DownedHealth = 150

-- A downed player cannot be killed again. Without this a body on the floor is
-- a free killstreak, and "no second death" stops meaning anything.
Config.InvincibleWhileDown = true

-- ---------------------------------------------------------------------------
-- Getting up again
-- ---------------------------------------------------------------------------

-- Seconds before the hospital respawn is OFFERED.
--
-- This is the window in which a medic, or anyone with a defibrillator later,
-- can reach you. Long enough that calling for help is worth doing, short
-- enough that nobody is staring at a grey screen resenting it.
Config.RespawnOfferedAfter = 120

-- Seconds before the player is taken to hospital whether they chose it or not.
-- A body nobody came for should not pin that player out of the server forever.
Config.ForceRespawnAfter = 600

-- What the hospital charges to put you back together.
--
-- Set by the owner at 350 precisely because EMS will be thin at the start: the
-- fee has to sting enough to make being downed a real setback while the
-- ambulance service does not reliably exist. Revisit it upward once there are
-- medics to call.
Config.RespawnFee = 350

-- Where the fee is taken from, in order. Cash first, so a player with money in
-- their pocket does not go into bank debt for it.
Config.FeeAccounts = { 'cash', 'bank' }

-- A player who cannot pay is still treated. The debt is not pursued, because a
-- player stuck on the floor because they are broke is a player who logs off.
-- The shortfall is simply not collected, and the treatment still happens.
Config.TreatWhenBroke = true

-- ---------------------------------------------------------------------------
-- Where you wake up
--
-- UNVERIFIED COORDINATE. Pillbox Hill Medical Center's ground entrance. Walk it
-- and correct it before trusting it; nothing else in this resource depends on
-- the value being exactly right.
-- ---------------------------------------------------------------------------

Config.Hospitals = {
    pillbox = {
        label = 'Pillbox Hill Medical Center',
        coords = vec4(298.6, -584.6, 43.26, 60.0),
    },
}

-- Health restored on waking up. Not full: you were just shot, and walking out
-- of a hospital at 100% removes the last trace of consequence.
Config.RespawnHealth = 150

-- ---------------------------------------------------------------------------
-- Controls
-- ---------------------------------------------------------------------------

-- Held to accept the hospital respawn, so it cannot be triggered by a stray
-- keypress while a medic is on the way.
Config.RespawnKey = 38          -- E
Config.RespawnHoldMs = 1200
