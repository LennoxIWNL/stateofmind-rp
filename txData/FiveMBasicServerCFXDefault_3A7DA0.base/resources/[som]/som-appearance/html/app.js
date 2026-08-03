const RESOURCE = window.location.hostname.replace('cfx-nui-', '');

const root = document.getElementById('root');
const tabsEl = document.getElementById('tabs');
const controlsEl = document.getElementById('controls');
const priceEl = document.getElementById('price');

let state = {};          // { scope, sections, appearance, limits, definitions, pricing }
let section = null;
let baseline = null;     // deep copy at open, so the price preview knows what changed

function post(endpoint, body) {
    return fetch(`https://${RESOURCE}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body ?? {}),
    }).then((r) => r.json()).catch(() => ({ success: false }));
}

const clone = (v) => JSON.parse(JSON.stringify(v));

function el(tag, cls, text) {
    const node = document.createElement(tag);
    if (cls) node.className = cls;
    // textContent: labels come from config, never trusted as markup.
    if (text !== undefined) node.textContent = text;
    return node;
}

function toast(text) {
    const node = document.getElementById('toast');
    node.textContent = text;
    node.classList.remove('hidden');
    setTimeout(() => node.classList.add('hidden'), 3200);
}

/* GTA's hair palette is not exposed to NUI, so these are approximations for
 * the swatch grid only. The value sent is the palette INDEX, which is what the
 * game actually uses, so a slightly wrong swatch colour is cosmetic. */
const HAIR_COLOURS = [
    '#3b3128', '#4a3728', '#5c4033', '#6f4e37', '#8b5a2b', '#a0522d', '#b8860b', '#c8a165',
    '#d4b483', '#e6cfa7', '#f0e2c0', '#faf0d7', '#8b0000', '#a52a2a', '#cd5c5c', '#e9967a',
    '#2f2f2f', '#4f4f4f', '#6e6e6e', '#8f8f8f', '#b0b0b0', '#d0d0d0', '#e8e8e8', '#ffffff',
];

// --- Value plumbing -----------------------------------------------------

function get(path) {
    let node = state.appearance;
    for (const key of path) {
        if (node == null) return undefined;
        node = node[key];
    }
    return node;
}

function set(path, value) {
    let node = state.appearance;
    for (let i = 0; i < path.length - 1; i++) node = node[path[i]];
    node[path[path.length - 1]] = value;

    post('update', { path, value });
    renderPrice();
}

// --- Control builders ---------------------------------------------------

const ARROW_L = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 18l-6-6 6-6"/></svg>';
const ARROW_R = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 18l6-6-6-6"/></svg>';

/**
 * @param {string} label
 * @param {Array} path
 * @param {number} max exclusive upper bound
 * @param {number} [min]
 */
function stepper(label, path, max, min = 0) {
    const wrap = el('div', 'control');

    const head = el('div', 'control__head');
    head.append(el('span', 'control__label', label),
        el('span', 'control__value', `${max - min} options`));
    wrap.appendChild(head);

    const row = el('div', 'stepper');
    const value = el('div', 'stepper__value', String(get(path) ?? min));

    const step = (dir) => {
        const count = max - min;
        if (count <= 0) return;
        // Wraps, so paging past the end returns to the start rather than
        // stopping dead on a slot with two options.
        let next = (Number(get(path) ?? min) - min + dir + count) % count + min;
        set(path, next);
        value.textContent = String(next);
    };

    const left = el('button', 'stepper__btn');
    left.type = 'button';
    left.innerHTML = ARROW_L;
    left.addEventListener('click', () => step(-1));

    const right = el('button', 'stepper__btn');
    right.type = 'button';
    right.innerHTML = ARROW_R;
    right.addEventListener('click', () => step(1));

    row.append(left, value, right);
    wrap.appendChild(row);
    return wrap;
}

function slider(label, path, min, max, stepSize) {
    const wrap = el('div', 'control');

    const head = el('div', 'control__head');
    const readout = el('span', 'control__value', Number(get(path) ?? 0).toFixed(2));
    head.append(el('span', 'control__label', label), readout);
    wrap.appendChild(head);

    const input = document.createElement('input');
    input.type = 'range';
    input.className = 'slider';
    input.min = String(min);
    input.max = String(max);
    input.step = String(stepSize);
    input.value = String(get(path) ?? 0);

    input.addEventListener('input', () => {
        const v = Number(input.value);
        readout.textContent = v.toFixed(2);
        set(path, v);
    });

    wrap.appendChild(input);
    return wrap;
}

function swatches(label, path, colours) {
    const wrap = el('div', 'control');
    wrap.appendChild(el('div', 'control__head')).appendChild(el('span', 'control__label', label));

    const grid = el('div', 'swatches');
    colours.forEach((hex, i) => {
        const dot = el('button', 'swatch');
        dot.type = 'button';
        dot.style.background = hex;
        if (Number(get(path)) === i) dot.classList.add('is-active');

        dot.addEventListener('click', () => {
            set(path, i);
            grid.querySelectorAll('.swatch').forEach((s) => s.classList.remove('is-active'));
            dot.classList.add('is-active');
        });

        grid.appendChild(dot);
    });

    wrap.appendChild(grid);
    return wrap;
}

// --- Sections -----------------------------------------------------------

function renderHeritage(frag) {
    frag.appendChild(el('div', 'group', 'Parents'));
    frag.appendChild(stepper('Mother', ['headBlend', 'shapeFirst'], 46));
    frag.appendChild(stepper('Father', ['headBlend', 'shapeSecond'], 46));
    frag.appendChild(slider('Resemblance', ['headBlend', 'shapeMix'], 0, 1, 0.01));

    frag.appendChild(el('div', 'group', 'Skin'));
    frag.appendChild(stepper('Mother', ['headBlend', 'skinFirst'], 46));
    frag.appendChild(stepper('Father', ['headBlend', 'skinSecond'], 46));
    frag.appendChild(slider('Skin tone', ['headBlend', 'skinMix'], 0, 1, 0.01));

    frag.appendChild(el('div', 'group', 'Eyes'));
    frag.appendChild(stepper('Eye colour', ['eyeColour'], 32));
}

function renderFeatures(frag) {
    let group = null;
    for (const f of state.definitions.faceFeatures) {
        if (f.group !== group) {
            group = f.group;
            frag.appendChild(el('div', 'group', group));
        }
        frag.appendChild(slider(f.label, ['faceFeatures', String(f.id)], -1, 1, 0.05));
    }
}

function renderHair(frag) {
    frag.appendChild(el('div', 'group', 'Hair'));
    frag.appendChild(stepper('Style', ['hair', 'style'], state.limits.hair || 1));
    frag.appendChild(swatches('Colour', ['hair', 'colour'], HAIR_COLOURS));
    frag.appendChild(swatches('Highlights', ['hair', 'highlight'], HAIR_COLOURS));
}

function renderOverlays(frag) {
    for (const o of state.definitions.headOverlays) {
        frag.appendChild(el('div', 'group', o.label));
        frag.appendChild(stepper('Style', ['headOverlays', o.key, 'style'], 40));
        frag.appendChild(slider('Strength', ['headOverlays', o.key, 'opacity'], 0, 1, 0.05));

        if (o.colourType) {
            frag.appendChild(swatches('Colour', ['headOverlays', o.key, 'colour'], HAIR_COLOURS));
        }
    }
}

/**
 * Stepper for a component or prop, addressed by its GAME id.
 *
 * Not by array position: Lua counts from one, JavaScript from zero, and a JSON
 * round trip turns one into the other. An id is the same number on both sides.
 */
function slotStepper(label, kind, id, max, min = 0) {
    const list = kind === 'prop' ? state.appearance.props : state.appearance.components;
    const key = kind === 'prop' ? 'prop_id' : 'component_id';

    let entry = list.find((e) => Number(e[key]) === id);
    if (!entry) {
        // -1 is the game's "nothing", so an unworn prop starts bare.
        entry = { [key]: id, drawable: kind === 'prop' ? -1 : 0, texture: 0 };
        list.push(entry);
    }

    const wrap = el('div', 'control');

    const head = el('div', 'control__head');
    head.append(el('span', 'control__label', label),
        el('span', 'control__value', `${max - min} options`));
    wrap.appendChild(head);

    const row = el('div', 'stepper');
    const value = el('div', 'stepper__value', String(entry.drawable));

    const step = (dir) => {
        const count = max - min;
        if (count <= 0) return;

        const next = (Number(entry.drawable) - min + dir + count) % count + min;
        entry.drawable = next;
        value.textContent = String(next);

        post('slot', { kind, id, field: 'drawable', value: next });
        renderPrice();
    };

    const left = el('button', 'stepper__btn');
    left.type = 'button';
    left.innerHTML = ARROW_L;
    left.addEventListener('click', () => step(-1));

    const right = el('button', 'stepper__btn');
    right.type = 'button';
    right.innerHTML = ARROW_R;
    right.addEventListener('click', () => step(1));

    row.append(left, value, right);
    wrap.appendChild(row);
    return wrap;
}

/* Which apparel sub-tab is showing. Remembered across re-renders so changing a
 * garment does not throw you back to the first group. */
let apparelGroup = null;

/* Clothing is split into sub-tabs rather than listed in one column.
 *
 * Fifteen steppers stacked together is a wall you have to read rather than a
 * menu you can use, and the slot you want is never the one on screen. The
 * grouping lives in the config so it can be re-cut without touching this.
 *
 * Server side this is still ONE `apparel` section, so pricing and the scope
 * merge do not know or care that the UI subdivides it.
 */
function renderApparel(frag) {
    const groups = state.definitions.apparelGroups || [];

    // Only groups that actually contain something, so an empty tab can never
    // be offered.
    const populated = groups.filter((g) =>
        state.definitions.components.some((c) => c.group === g.id) ||
        state.definitions.props.some((p) => p.group === g.id));

    if (!populated.length) return;

    if (!populated.some((g) => g.id === apparelGroup)) {
        apparelGroup = populated[0].id;
    }

    const nav = el('div', 'subtabs');
    for (const g of populated) {
        const tab = el('button', 'subtab', g.label);
        tab.type = 'button';
        if (g.id === apparelGroup) tab.classList.add('is-active');

        tab.addEventListener('click', () => {
            apparelGroup = g.id;
            renderSection();
        });

        nav.appendChild(tab);
    }
    frag.appendChild(nav);

    for (const c of state.definitions.components) {
        if (c.group !== apparelGroup) continue;
        const limit = state.limits.components[String(c.id)] || { drawables: 1 };
        frag.appendChild(slotStepper(c.label, 'component', c.id, limit.drawables || 1));
    }

    for (const p of state.definitions.props) {
        if (p.group !== apparelGroup) continue;
        const limit = state.limits.props[String(p.id)] || { drawables: 1 };
        frag.appendChild(slotStepper(p.label, 'prop', p.id, limit.drawables || 1, -1));
    }
}

const RENDERERS = {
    heritage: renderHeritage,
    features: renderFeatures,
    hair: renderHair,
    overlays: renderOverlays,
    apparel: renderApparel,
};

const SECTION_LABELS = {
    heritage: 'Heritage',
    features: 'Face',
    hair: 'Hair',
    overlays: 'Detail',
    apparel: 'Clothing',
};

function renderSection() {
    const frag = document.createDocumentFragment();
    (RENDERERS[section] || (() => {}))(frag);
    controlsEl.replaceChildren(frag);
    controlsEl.scrollTop = 0;
}

function selectSection(next) {
    section = next;
    tabsEl.querySelectorAll('.tab').forEach((t) =>
        t.classList.toggle('is-active', t.dataset.section === next));

    post('view', { section: next });
    renderSection();
}

function renderTabs() {
    const frag = document.createDocumentFragment();

    for (const s of state.sections) {
        const tab = el('button', 'tab', SECTION_LABELS[s] || s);
        tab.type = 'button';
        tab.dataset.section = s;
        tab.addEventListener('click', () => selectSection(s));
        frag.appendChild(tab);
    }

    tabsEl.replaceChildren(frag);
}

/* Price preview. Charged per section actually changed, so the player can see
 * what a visit will cost before they commit to it. */
function renderPrice() {
    if (state.scope === 'creator') {
        priceEl.textContent = '';
        return;
    }

    const keys = {
        heritage: ['headBlend'],
        features: ['faceFeatures'],
        hair: ['hair'],
        overlays: ['headOverlays'],
        apparel: ['components', 'props'],
    };

    let total = 0;
    for (const s of state.sections) {
        const changed = (keys[s] || []).some(
            (k) => JSON.stringify(baseline[k]) !== JSON.stringify(state.appearance[k]));
        if (changed) total += state.pricing.sections[s] || 0;
    }

    priceEl.textContent = total > 0 ? `$${total.toLocaleString('en-US')}` : 'No changes';
    priceEl.classList.toggle('is-charged', total > 0);
}

// --- Wiring -------------------------------------------------------------

document.getElementById('turn-left').addEventListener('click', () => post('rotate', { dir: -1 }));
document.getElementById('turn-right').addEventListener('click', () => post('rotate', { dir: 1 }));

/* Cash or card, the same control every SOM shop uses. som-core supplies the
 * options and balances; the server validates whatever comes back. Hidden for
 * creation, which is free. */
function renderPayment() {
    const wrap = document.getElementById('pay');

    if (state.scope === 'creator' || !(state.payment || []).length) {
        wrap.classList.add('hidden');
        return;
    }

    const frag = document.createDocumentFragment();
    state.payment.forEach((option) => {
        const btn = el('button', 'pay__opt');
        btn.type = 'button';
        if (option.account === state.account) btn.classList.add('is-active');

        btn.append(el('span', 'pay__label', option.label),
            el('span', 'pay__value', `$${Number(option.balance).toLocaleString('en-US')}`));

        btn.addEventListener('click', () => {
            state.account = option.account;
            renderPayment();
        });

        frag.appendChild(btn);
    });

    wrap.replaceChildren(frag);
    wrap.classList.remove('hidden');
}

document.getElementById('confirm').addEventListener('click', async () => {
    const res = await post('confirm', { account: state.account });
    if (!res.success) toast(res.error || 'Could not save');
});

document.getElementById('cancel').addEventListener('click', () => post('cancel'));

window.addEventListener('message', (event) => {
    const msg = event.data;
    if (!msg || typeof msg.action !== 'string') return;

    if (msg.action === 'open') {
        state = msg.data || {};
        baseline = clone(state.appearance);

        document.getElementById('title').textContent =
            state.scope === 'creator' ? 'Create Character' : 'Appearance';
        document.getElementById('subtitle').textContent =
            state.scope === 'creator'
                ? 'Set your face, then your clothes'
                : 'Changes are charged when you confirm';

        document.getElementById('cancel').classList.toggle('hidden', !state.canCancel);
        document.getElementById('confirm').textContent =
            state.scope === 'creator' ? 'Start Playing' : 'Confirm';

        state.account = (state.payment || []).find((p) => p.balance > 0)?.account
            || (state.payment || [])[0]?.account;

        renderTabs();
        selectSection(state.sections[0]);
        renderPayment();
        renderPrice();

        root.classList.remove('hidden');
        return;
    }

    if (msg.action === 'close') root.classList.add('hidden');
});
