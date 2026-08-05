/* The downed screen.
 *
 * Render only. It counts up because it was told when the player went down; it
 * never decides that they may get up. The server enforces the wait, so a player
 * editing this file gains a button that gets refused. */

const root = document.getElementById('down');
const clock = document.getElementById('clock');
const action = document.getElementById('action');
const holdfill = document.getElementById('holdfill');
const feeEl = document.getElementById('fee');
const waitEl = document.getElementById('wait');

let tickTimer = null;
let elapsed = 0;
let cfg = {};

const mmss = (s) => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, '0')}`;

function tick() {
    elapsed += 1;
    clock.textContent = mmss(elapsed);

    // The offer appears once, and the waiting line steps aside for it rather
    // than both competing for the same moment of attention.
    if (cfg.offeredAfter !== undefined && elapsed >= cfg.offeredAfter) {
        action.classList.remove('hidden');
        waitEl.classList.add('hidden');
    }
}

function show(data) {
    cfg = data || {};
    elapsed = 0;

    clock.textContent = '0:00';
    action.classList.add('hidden');
    waitEl.classList.remove('hidden');
    holdfill.style.width = '0%';

    feeEl.textContent = cfg.fee ? `Treatment costs $${Number(cfg.fee).toLocaleString('en-US')}` : '';

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
