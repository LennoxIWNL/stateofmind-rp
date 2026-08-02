const RESOURCE = window.location.hostname.replace('cfx-nui-', '');

const root = document.getElementById('root');
const railEl = document.getElementById('rail');
const toastEl = document.getElementById('toast');

let tabs = [];
let destinations = [];
let currentTab = 'map';
let toastTimer = null;

function post(endpoint, body) {
    return fetch(`https://${RESOURCE}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body ?? {}),
    })
        .then((r) => r.json())
        .catch((err) => {
            console.error(`${endpoint} failed:`, err);
            return { success: false };
        });
}

const money = (n) => `$${Number(n || 0).toLocaleString('en-US')}`;

function el(tag, cls, text) {
    const node = document.createElement(tag);
    if (cls) node.className = cls;
    // textContent throughout: character names and job labels are authored by
    // players and config, never trusted as markup.
    if (text !== undefined) node.textContent = text;
    return node;
}

const ICONS = {
    map: '<path d="M9 3L3 5.6v15.2l6-2.6 6 2.6 6-2.6V3l-6 2.6z"/><path d="M9 3v15.2M15 5.6v15.2"/>',
    user: '<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>',
    globe: '<circle cx="12" cy="12" r="9.2"/><path d="M2.8 12h18.4"/><path d="M12 2.8a14.2 14.2 0 0 1 0 18.4 14.2 14.2 0 0 1 0-18.4z"/>',
    shield: '<path d="M12 22s8-3.6 8-9.6V5.4L12 2.4 4 5.4v7c0 6 8 9.6 8 9.6z"/>',
    power: '<path d="M18.4 6.6a9 9 0 1 1-12.8 0"/><path d="M12 2.5v9"/>',
};

function icon(name) {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('fill', 'none');
    svg.setAttribute('stroke', 'currentColor');
    svg.setAttribute('stroke-width', '1.8');
    svg.setAttribute('stroke-linecap', 'round');
    svg.setAttribute('stroke-linejoin', 'round');
    svg.innerHTML = ICONS[name] || ICONS.globe;
    return svg;
}

function toast(text) {
    toastEl.textContent = text;
    toastEl.classList.add('is-shown');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toastEl.classList.remove('is-shown'), 2600);
}

// --- Tabs ---------------------------------------------------------------

function selectTab(id) {
    if (!tabs.some((t) => t.id === id)) return;
    currentTab = id;

    document.querySelectorAll('.panel').forEach((p) => p.classList.add('hidden'));
    const panel = document.getElementById(`panel-${id}`);
    if (panel) panel.classList.remove('hidden');

    document.querySelectorAll('.tab').forEach((t) =>
        t.classList.toggle('is-active', t.dataset.id === id));

    // Only the map tab wants the radar behind it; every other panel hides the
    // whole HUD so nothing bleeds through the cards.
    root.classList.toggle('is-map', id === 'map');
    post('tab', { id });
}

function renderTabs() {
    const frag = document.createDocumentFragment();

    tabs.forEach((tab) => {
        const btn = el('button', `tab${tab.id === 'disconnect' ? ' tab--danger' : ''}`);
        btn.type = 'button';
        btn.dataset.id = tab.id;
        btn.append(icon(tab.icon), el('span', null, tab.label));
        btn.addEventListener('click', () => selectTab(tab.id));
        frag.appendChild(btn);
    });

    railEl.replaceChildren(frag);
}

// --- Map ----------------------------------------------------------------

/* Config.Map is normalised and anchored left/bottom, which is the same
 * coordinate space CSS percentages use, so the frame can be placed directly
 * from the same numbers the Lua side gives the radar. */
function placeMapWindow(map) {
    if (!map) return;

    const win = document.getElementById('map-window');
    win.style.left = `${map.posX * 100}%`;
    win.style.bottom = `${map.posY * 100}%`;
    win.style.width = `${map.sizeX * 100}%`;
    win.style.height = `${map.sizeY * 100}%`;
}

function renderDestinations(filter) {
    const list = document.getElementById('dest-list');
    const needle = (filter || '').trim().toLowerCase();

    const matches = needle
        ? destinations.filter((d) => d.label.toLowerCase().includes(needle))
        : destinations;

    if (!matches.length) {
        list.replaceChildren(el('div', 'dest__group', 'No matches'));
        return;
    }

    const frag = document.createDocumentFragment();
    let group = null;

    matches.forEach((d) => {
        if (d.category !== group) {
            group = d.category;
            frag.appendChild(el('div', 'dest__group', group));
        }

        const btn = el('button', 'dest__item', d.label);
        btn.type = 'button';
        btn.addEventListener('click', async () => {
            const res = await post('waypoint', { index: d.index });
            if (!res.success) return;

            list.querySelectorAll('.dest__item').forEach((i) => i.classList.remove('is-set'));
            btn.classList.add('is-set');
            toast(`Waypoint set: ${res.label}`);
        });

        frag.appendChild(btn);
    });

    list.replaceChildren(frag);
}

// --- Panels -------------------------------------------------------------

function renderCharacter(c) {
    document.getElementById('meta-name').textContent = c.name || '-';
    document.getElementById('char-name').textContent = c.name || '-';
    document.getElementById('char-sub').textContent = c.citizenid || '';
    document.getElementById('char-cash').textContent = money(c.cash);
    document.getElementById('char-bank').textContent = money(c.bank);

    const kv = document.getElementById('char-kv');
    const rows = [
        ['Phone', c.phone],
        ['Date of birth', c.dob],
        ['Gender', c.gender],
        ['Gang', c.gang],
    ].filter(([, v]) => v);

    const frag = document.createDocumentFragment();
    rows.forEach(([k, v]) => {
        frag.appendChild(el('dt', null, k));
        frag.appendChild(el('dd', null, String(v)));
    });
    kv.replaceChildren(frag);

    const job = c.job || {};
    document.getElementById('char-job').textContent = job.label || 'Unemployed';
    document.getElementById('char-duty').classList.toggle('hidden', !job.onduty);

    const chips = document.getElementById('char-licences');
    const licences = c.licences || [];
    chips.replaceChildren(
        ...(licences.length
            ? licences.map((l) => el('span', 'chip', l.replace(/_/g, ' ')))
            : [el('span', 'chip chip--empty', 'No licences held')]));
}

function renderServer(s, cfg) {
    const count = s.players || 0;
    const max = s.maxPlayers || 48;

    document.getElementById('meta-players').textContent = `${count} / ${max}`;
    document.getElementById('server-players').textContent = `${count} / ${max}`;
    document.getElementById('server-bar').style.width = `${Math.min(100, (count / max) * 100)}%`;

    document.getElementById('server-name').textContent = cfg.name || 'State of Mind RP';
    document.getElementById('server-discord').textContent = cfg.discord || '';
    document.getElementById('server-tagline').textContent = cfg.tagline || '';
}

// --- Clock --------------------------------------------------------------

function tick() {
    document.getElementById('meta-clock').textContent =
        new Date().toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' });
}

// --- Wiring -------------------------------------------------------------

document.getElementById('dest-search').addEventListener('input', (e) =>
    renderDestinations(e.target.value));

document.getElementById('dest-clear').addEventListener('click', async () => {
    await post('clearWaypoint');
    document.querySelectorAll('.dest__item').forEach((i) => i.classList.remove('is-set'));
    toast('Waypoint cleared');
});

document.getElementById('quit-btn').addEventListener('click', () => post('quit'));

document.querySelectorAll('[data-tab-jump]').forEach((b) =>
    b.addEventListener('click', () => selectTab(b.dataset.tabJump)));

function close() {
    root.classList.add('hidden');
    post('close');
}

document.addEventListener('keydown', (e) => {
    if (e.target.matches('input, select, textarea')) {
        if (e.key === 'Escape') e.target.blur();
        return;
    }

    if (e.key === 'Escape') { close(); return; }

    const n = Number(e.key);
    if (n >= 1 && n <= tabs.length) selectTab(tabs[n - 1].id);
});

tick();
setInterval(tick, 1000);

window.addEventListener('message', (event) => {
    const msg = event.data;
    if (!msg || typeof msg.action !== 'string') return;

    if (msg.action === 'open') {
        const d = msg.data || {};

        tabs = d.tabs || [];
        destinations = d.destinations || [];

        if (d.overlay && d.overlay.tint) root.style.setProperty('--tint', d.overlay.tint);

        renderTabs();
        placeMapWindow(d.map);
        renderDestinations('');
        renderCharacter(d.character || {});
        renderServer(d.server || {}, d.config || {});

        document.getElementById('staff-tier').textContent =
            (d.staff && d.staff.tier) || 'None';

        document.getElementById('dest-search').value = '';
        tick();

        root.classList.remove('hidden');
        selectTab('map');
        return;
    }

    if (msg.action === 'close') root.classList.add('hidden');
});
