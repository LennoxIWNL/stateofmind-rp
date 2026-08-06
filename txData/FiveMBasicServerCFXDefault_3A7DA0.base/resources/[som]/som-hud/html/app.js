/* The HUD.
 *
 * Render only. Every number arrives from Lua already clamped and rounded; this
 * file decides nothing except how to draw it. There is no callback back to Lua,
 * so there is no surface here for an edited page to lie through.
 *
 * The rings are built once and then only mutated, never rebuilt. Replacing the
 * DOM ten times a second is what makes a HUD feel heavy, and it is invisible in
 * profiling because each individual rebuild is cheap.
 */

const hud = document.getElementById('hud');
const ringsEl = document.getElementById('rings');
const vehicleEl = document.getElementById('vehicle');
const speedEl = document.getElementById('speed');
const unitEl = document.getElementById('unit');
const gearEl = document.getElementById('gear');
const engineEl = document.getElementById('engine');
const engineWrap = document.getElementById('engine-wrap');

/* Icons are inline SVG paths on a 24x24 box with stroke-width 1.9, which is
 * som-phone's icon contract exactly. Matching it is deliberate: the phone and
 * the HUD are the two things a player looks at most and they have to be drawn
 * by the same hand.
 *
 * These are five geometric shapes written here, not a licensed icon set lifted
 * from somewhere. The icon question in the audit is about a COMPLETE set for
 * menus and items, which is a licensing decision and an owner's job; it is not
 * a reason for the HUD to have no icons at all. */
const GLYPHS = {
    health: '<path d="M20.8 6.6a5 5 0 0 0-7.1 0L12 8.3l-1.7-1.7a5 5 0 0 0-7.1 7.1l8.8 8.8 8.8-8.8a5 5 0 0 0 0-7.1z"/>',
    armour: '<path d="M12 2 4 5.4v6c0 5 3.4 9.7 8 10.8 4.6-1.1 8-5.7 8-10.8v-6z"/>',
    hunger: '<path d="M6 2v8a2.5 2.5 0 0 0 5 0V2"/><path d="M8.5 10v12"/><path d="M17.5 2c-1.4 0-2.5 2.2-2.5 5s1.1 5 2.5 5V2z"/><path d="M17.5 12v10"/>',
    thirst: '<path d="M12 2.7 6.8 9.5a7 7 0 1 0 10.4 0z"/>',
    voice: '<rect x="9" y="2" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0"/><path d="M12 18v4"/>',
};

/* Order is fixed. The two that can kill you first, then the two that kill you
 * slowly, then the one that is about whether other people can hear you. */
const RINGS = [
    { key: 'health', label: 'Health' },
    { key: 'armour', label: 'Armour' },
    { key: 'hunger', label: 'Food' },
    { key: 'thirst', label: 'Water' },
    { key: 'voice', label: 'Voice' },
];

/* r=15.5 on a 36-box leaves room for a 3px stroke without clipping. The
 * circumference is precomputed because it is the denominator of every update. */
const R = 15.5;
const CIRCUMFERENCE = 2 * Math.PI * R;

const built = {};

function buildRing(spec) {
    const wrap = document.createElement('div');
    wrap.className = 'ring';
    wrap.dataset.key = spec.key;

    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('viewBox', '0 0 36 36');
    svg.setAttribute('class', 'ring__svg');

    const track = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
    track.setAttribute('class', 'ring__track');
    track.setAttribute('cx', '18');
    track.setAttribute('cy', '18');
    track.setAttribute('r', String(R));

    const fill = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
    fill.setAttribute('class', 'ring__fill');
    fill.setAttribute('cx', '18');
    fill.setAttribute('cy', '18');
    fill.setAttribute('r', String(R));
    fill.setAttribute('stroke-dasharray', String(CIRCUMFERENCE));
    fill.setAttribute('stroke-dashoffset', String(CIRCUMFERENCE));

    svg.append(track, fill);

    const glyph = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    glyph.setAttribute('viewBox', '0 0 24 24');
    glyph.setAttribute('fill', 'none');
    glyph.setAttribute('stroke', 'currentColor');
    glyph.setAttribute('stroke-width', '1.9');
    glyph.setAttribute('stroke-linecap', 'round');
    glyph.setAttribute('stroke-linejoin', 'round');
    glyph.setAttribute('class', 'ring__glyph');
    glyph.innerHTML = GLYPHS[spec.key] || '';

    wrap.append(svg, glyph);
    ringsEl.append(wrap);

    built[spec.key] = { wrap, fill };
}

RINGS.forEach(buildRing);

/* @param {string} key
 * @param {number} percent 0-100
 * @param {boolean} visible
 * @param {string|null} tone 'low' | 'critical' | 'accent' | null */
function setRing(key, percent, visible, tone) {
    const ring = built[key];
    if (!ring) return;

    // Hidden by class, not removed. The row keeps its order, so a ring standing
    // down does not shuffle the others sideways under the player's eye.
    ring.wrap.classList.toggle('is-gone', !visible);
    if (!visible) return;

    const pct = Math.max(0, Math.min(100, percent));
    ring.fill.setAttribute('stroke-dashoffset', String(CIRCUMFERENCE * (1 - pct / 100)));

    ring.wrap.classList.toggle('is-low', tone === 'low');
    ring.wrap.classList.toggle('is-critical', tone === 'critical');
    ring.wrap.classList.toggle('is-accent', tone === 'accent');
}

// Mirrors Config.Low and Config.Critical. Kept in step by hand rather than sent
// with every payload, because they are constants and shipping two extra numbers
// ten times a second to say the same thing is waste.
const LOW = 35;
const CRITICAL = 15;

function tone(value) {
    if (value <= CRITICAL) return 'critical';
    if (value <= LOW) return 'low';
    return null;
}

function status(d) {
    setRing('health', d.health, true, tone(d.health));

    // Armour stands down at zero, which is most of the time for most players.
    setRing('armour', d.armour, d.armour > 0, tone(d.armour));

    setRing('hunger', d.hunger, d.hunger <= 90, tone(d.hunger));
    setRing('thirst', d.thirst, d.thirst <= 90, tone(d.thirst));

    // The voice ring is always full: it is a mode, not a quantity. What it
    // carries is whether the player is TRANSMITTING, and that is the one thing
    // on this HUD happening right now rather than merely being true, so it is
    // the one thing that gets the accent.
    setRing('voice', 100, true, (d.talking || d.radio) ? 'accent' : null);

    built.voice.wrap.classList.toggle('is-radio', d.radio === true);
    built.voice.wrap.dataset.mode = d.voiceMode || 'Normal';
}

function vehicle(d) {
    if (!d.inVehicle) {
        vehicleEl.hidden = true;
        return;
    }

    vehicleEl.hidden = false;

    speedEl.textContent = d.speed;
    unitEl.textContent = d.unit || 'mph';

    // GTA reports reverse as -1 and neutral as 0. Printing those raw puts a
    // minus sign on the dash, which reads as an error rather than as reverse.
    gearEl.textContent = d.gear > 0 ? String(d.gear) : (d.gear < 0 ? 'R' : 'N');

    // Same reasoning as the armour ring: an engine at full condition is telling
    // the player nothing.
    engineWrap.classList.toggle('is-gone', d.warn !== true);
    engineEl.style.width = `${Math.max(0, Math.min(100, d.engine))}%`;
}

window.addEventListener('message', (event) => {
    const d = event.data;
    if (!d || typeof d.action !== 'string') return;

    if (d.action === 'hud:visible') {
        hud.hidden = d.value !== true;
        // A hidden HUD keeps no vehicle panel: coming back on foot after being
        // hidden in a car would otherwise show a stale speed for one tick.
        if (hud.hidden) vehicleEl.hidden = true;
        return;
    }

    if (d.action === 'hud:status') return status(d);
    if (d.action === 'hud:vehicle') return vehicle(d);
});
