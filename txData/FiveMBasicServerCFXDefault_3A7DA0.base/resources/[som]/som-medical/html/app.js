/* The downed screen.
 *
 * Render only. It counts because it was told when the player went down; it
 * never decides that they may get up. The server enforces the wait, so a player
 * editing this file gains a button that gets refused.
 *
 * Two phases, one clock, always counting DOWN:
 *
 *   1. Until treatment can be accepted. This is the window a medic has.
 *   2. Until the player is taken to hospital whether they chose it or not.
 *
 * The second phase used to be invisible. A player who waited out the ten
 * minutes was moved with no warning at all, which reads as the script breaking
 * rather than as the rule it is.
 */

const root = document.getElementById('down');
const clock = document.getElementById('clock');
const timerLabel = document.getElementById('timerlabel');
const action = document.getElementById('action');
const holdfill = document.getElementById('holdfill');
const feeEl = document.getElementById('fee');

/* Seconds left before the forced move at which the clock changes colour. */
const URGENT_AT = 30;

let tickTimer = null;
let elapsed = 0;
let cfg = {};

const mmss = (s) => {
    const whole = Math.max(0, Math.floor(s));
    return `${Math.floor(whole / 60)}:${String(whole % 60).padStart(2, '0')}`;
};

function paint() {
    const offerAt = Number(cfg.offeredAfter) || 0;
    const forceAt = Number(cfg.forcedAfter) || 0;

    if (elapsed < offerAt) {
        timerLabel.textContent = 'Treatment available in';
        clock.textContent = mmss(offerAt - elapsed);
        clock.classList.remove('is-urgent');
        action.classList.add('hidden');
        return;
    }

    // The offer appears once and stays. It is never taken away again, because a
    // prompt that vanishes while you are reaching for the key is worse than no
    // prompt.
    action.classList.remove('hidden');

    // A force time at or below the offer time would mean the player is moved the
    // instant they are allowed to choose, so there is nothing to count down to
    // and the clock says what it can honestly say instead.
    if (forceAt > offerAt) {
        const left = Math.max(0, forceAt - elapsed);
        timerLabel.textContent = 'Moved to hospital in';
        clock.textContent = mmss(left);
        clock.classList.toggle('is-urgent', left <= URGENT_AT);
    } else {
        timerLabel.textContent = 'Waiting for medical';
        clock.textContent = mmss(elapsed);
    }
}

function tick() {
    elapsed += 1;
    paint();
}

function show(data) {
    cfg = data || {};

    // Non-zero only for a player who reconnected while down. The server owns the
    // real elapsed time, so it sends it rather than the clock restarting here
    // and disagreeing with the server that refuses the respawn.
    elapsed = Number(cfg.elapsed) || 0;

    holdfill.style.width = '0%';

    feeEl.textContent = cfg.fee
        ? `Treatment costs $${Number(cfg.fee).toLocaleString('en-US')}, billed to your card`
        : '';

    paint();

    root.hidden = false;

    clearInterval(tickTimer);
    tickTimer = setInterval(tick, 1000);
}

function hide() {
    clearInterval(tickTimer);
    tickTimer = null;
    root.hidden = true;
    holdfill.style.width = '0%';
}

window.addEventListener('message', (event) => {
    const msg = event.data;
    if (!msg || typeof msg.action !== 'string') return;

    if (msg.action === 'down') return show(msg.data);
    if (msg.action === 'up') return hide();

    // Progress on the hold, driven by Lua so the bar and the thing it measures
    // cannot disagree.
    if (msg.action === 'hold') {
        const pct = Math.max(0, Math.min(100, Number(msg.percent) || 0));
        holdfill.style.width = `${pct}%`;
    }
});
