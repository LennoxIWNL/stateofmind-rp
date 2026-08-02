const RESOURCE = window.location.hostname.replace('cfx-nui-', '');

const root = document.getElementById('root');
const actionsEl = document.getElementById('actions');

let actions = [];

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

function el(tag, cls, text) {
    const node = document.createElement(tag);
    if (cls) node.className = cls;
    // textContent throughout: character names and job labels come from players
    // and config, never trusted as markup.
    if (text !== undefined) node.textContent = text;
    return node;
}

const ICONS = {
    map: '<path d="M9 3L3 5.6v15.2l6-2.6 6 2.6 6-2.6V3l-6 2.6z"/><path d="M9 3v15.2M15 5.6v15.2"/>',
    settings: '<circle cx="12" cy="12" r="3.1"/><path d="M19.4 15a1.6 1.6 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.6 1.6 0 0 0-1.8-.3 1.6 1.6 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1A1.6 1.6 0 0 0 9 19.4a1.6 1.6 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.6 1.6 0 0 0 .3-1.8 1.6 1.6 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1A1.6 1.6 0 0 0 4.6 9a1.6 1.6 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.6 1.6 0 0 0 1.8.3H9a1.6 1.6 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.6 1.6 0 0 0 1 1.5 1.6 1.6 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.6 1.6 0 0 0-.3 1.8V9a1.6 1.6 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.6 1.6 0 0 0-1.5 1z"/>',
    power: '<path d="M18.4 6.6a9 9 0 1 1-12.8 0"/><path d="M12 2.5v9"/>',
};

/* stroke is set explicitly rather than inherited: currentColor depends on a
 * cascade that a rejected declaration elsewhere can quietly break. */
function icon(name) {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('fill', 'none');
    svg.setAttribute('stroke', 'currentColor');
    svg.setAttribute('stroke-width', '1.8');
    svg.setAttribute('stroke-linecap', 'round');
    svg.setAttribute('stroke-linejoin', 'round');
    svg.innerHTML = ICONS[name] || ICONS.map;
    return svg;
}

function renderActions() {
    const frag = document.createDocumentFragment();

    actions.forEach((action, i) => {
        const btn = el('button', `action${action.id === 'disconnect' ? ' action--danger' : ''}`);
        btn.type = 'button';
        btn.dataset.id = action.id;
        btn.append(icon(action.icon), el('span', null, action.label),
            el('span', 'action__key', String(i + 1)));
        btn.addEventListener('click', () => run(action.id));
        frag.appendChild(btn);
    });

    actionsEl.replaceChildren(frag);
}

function run(id) {
    // Map and settings hand back to the native frontend, so the bar is dropped
    // immediately rather than waiting for a round trip.
    root.classList.add('hidden');
    post('action', { id });
}

function tick() {
    document.getElementById('meta-clock').textContent =
        new Date().toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' });
}

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        root.classList.add('hidden');
        post('close');
        return;
    }

    const n = Number(e.key);
    if (n >= 1 && n <= actions.length) run(actions[n - 1].id);
});

// A logo that fails to load leaves a broken image icon, which looks worse than
// the wordmark it replaced.
document.getElementById('logo').addEventListener('error', function () {
    const mark = el('span', 'bar__name', 'SOM');
    mark.style.cssText = 'font-size:1.5rem;font-weight:800;color:var(--som-pink);letter-spacing:.14em';
    this.replaceWith(mark);
});

tick();
setInterval(tick, 1000);

window.addEventListener('message', (event) => {
    const msg = event.data;
    if (!msg || typeof msg.action !== 'string') return;

    if (msg.action === 'open') {
        const d = msg.data || {};
        const c = d.character || {};
        const s = d.server || {};

        actions = d.actions || [];
        if (d.overlay && d.overlay.tint) root.style.setProperty('--tint', d.overlay.tint);

        document.getElementById('server-name').textContent = (d.config && d.config.name) || '';
        document.getElementById('meta-name').textContent = c.name || '-';
        document.getElementById('meta-job').textContent = c.job || 'Unemployed';
        document.getElementById('meta-duty').classList.toggle('hidden', !c.onduty);
        document.getElementById('meta-players').textContent =
            `${s.players || 0} / ${s.maxPlayers || 48}`;

        renderActions();
        tick();
        root.classList.remove('hidden');
        return;
    }

    if (msg.action === 'close') root.classList.add('hidden');
});
