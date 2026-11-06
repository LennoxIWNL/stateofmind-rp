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

-- The pose.
--
-- Replaces the ragdoll placeholder. Ragdoll needed no dict and could not fail
-- to stream, which is why it shipped first, but it also let the body slide,
-- settle into geometry and read as a physics glitch rather than as a person.
--
-- `missarmenian2` / `drunk_loop` is a looping, full body, face up collapse. It
-- is stock GTA V and is already used on this server by dpemotes' "passout", so
-- it is known present rather than assumed.
--
-- flag 1 is repeat ONLY. Deliberately not 49: 49 carries 16 (player retains
-- movement) and 32 (cancellable), which are the two bits that let a player walk
-- out of their own down animation.
Config.DownAnim = {
    dict = 'missarmenian2',
    clip = 'drunk_loop',
    flag = 1,

    -- Gentle the first time, so it reads as collapsing.
    blendIn = 2.0,

    -- Instant on every re-assert after that. A player who cancels the emote is
    -- put back with no visible travel, which is what makes spamming it pointless
    -- rather than merely difficult.
    reblendIn = 8.0,

    blendOut = 4.0,
}

-- How far the body may drift from where it fell before it is put back.
--
-- The exploit this closes is the one most servers running animated downs have:
-- the emote cancel keybind clears the task, and RegisterKeyMapping commands are
-- NOT stopped by DisableControlAction, so the player gets a frame or two of
-- control. Spammed, that is a walk. Re-asserting the animation every frame
-- takes the animation back; this takes the ground back.
--
-- Loose enough that ordinary animation root motion and a nudge from a passing
-- car do not fight it, tight enough that no sequence of cancels adds up to
-- travel.
Config.AnchorRadius = 0.75

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

-- Where the fee is taken from, in order.
--
-- Bank only, and deliberately not cash first. A hospital bill is a bill: it
-- arrives on the card, and som-phone's card alerts are configured for the bank
-- account, so charging cash produced a silent deduction with nothing on the
-- phone to explain it. Billing the card is what makes the notification and the
-- statement line exist at all.
Config.FeeAccounts = { 'bank' }

-- The business account the respawn fee is paid into.
Config.FeeBusiness = 'ems'

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

-- ---------------------------------------------------------------------------
-- New life
--
-- Respawning at the hospital is a new life: the character forgets how they
-- died. How long they must keep away from where it happened depends on how they
-- died, derived on the server (never from the client's label). A medic revive
-- is not a new life. Nothing is enforced in code beyond telling the player and
-- recording it for staff.
-- ---------------------------------------------------------------------------
Config.NewLife = {
    violence = 15,   -- minutes, killed by another player
    accident = 0,    -- fall, vehicle, fire, environment, an NPC: remember it
    radius = 200.0,
}
