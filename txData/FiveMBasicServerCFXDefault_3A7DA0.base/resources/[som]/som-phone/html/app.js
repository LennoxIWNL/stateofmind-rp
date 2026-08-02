const RESOURCE = window.location.hostname.replace('cfx-nui-', '');

const root = document.getElementById('root');
const appsEl = document.getElementById('apps');

let themes = {};
let settings = { theme: 'default' };
let badges = {};
let bank = null;
let locked = true;

function post(endpoint, body) {
    return fetch(`https://${RESOURCE}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body ?? {}),
    })
        .then((r) => r.json())
        .catch((err) => {
            console.error(`${endpoint} failed:`, err);
            return { success: false, error: 'Connection failed' };
        });
}

const money = (n) => `$${Number(n || 0).toLocaleString('en-US')}`;

function el(tag, cls, text) {
    const node = document.createElement(tag);
    if (cls) node.className = cls;
    // textContent everywhere: reasons, names and labels are player-authored.
    if (text !== undefined) node.textContent = text;
    return node;
}

/* Inline SVG rather than an icon font or sprite sheet: NUI has no network
 * access, and letter glyphs in coloured squares were what made the home
 * screen read as a placeholder. */
const ICONS = {
    bank: '<path d="M3 10.5L12 4l9 6.5"/><path d="M5 10.5V19M9.7 10.5V19M14.3 10.5V19M19 10.5V19"/><path d="M3 19h18"/>',
    settings: '<circle cx="12" cy="12" r="3.1"/><path d="M19.4 15a1.6 1.6 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.6 1.6 0 0 0-1.8-.3 1.6 1.6 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1A1.6 1.6 0 0 0 9 19.4a1.6 1.6 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.6 1.6 0 0 0 .3-1.8 1.6 1.6 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1A1.6 1.6 0 0 0 4.6 9a1.6 1.6 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.6 1.6 0 0 0 1.8.3H9a1.6 1.6 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.6 1.6 0 0 0 1 1.5 1.6 1.6 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.6 1.6 0 0 0-.3 1.8V9a1.6 1.6 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.6 1.6 0 0 0-1.5 1z"/>',
    message: '<path d="M21 11.5a8.4 8.4 0 0 1-9 8.4 9.5 9.5 0 0 1-3.4-.6L3 21l1.8-5a8.2 8.2 0 0 1-.8-3.5 8.4 8.4 0 0 1 9-8.4 8.4 8.4 0 0 1 8 7.4z"/>',
    phone: '<path d="M22 16.9v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3.1 19.5 19.5 0 0 1-6-6A19.8 19.8 0 0 1 2.1 4.2 2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7c.1 1 .4 1.9.7 2.8a2 2 0 0 1-.5 2.1L8.1 9.9a16 16 0 0 0 6 6l1.3-1.3a2 2 0 0 1 2.1-.4c.9.3 1.8.6 2.8.7a2 2 0 0 1 1.7 2z"/>',
    contacts: '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.9"/><path d="M16 3.1a4 4 0 0 1 0 7.8"/>',
    camera: '<path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h3.5L8 3h8l1.5 3H21a2 2 0 0 1 2 2z"/><circle cx="12" cy="13" r="4"/>',
    twitter: '<path d="M22 4.5a8.4 8.4 0 0 1-2.4.7A4.2 4.2 0 0 0 21.4 3a8.4 8.4 0 0 1-2.7 1A4.2 4.2 0 0 0 11.5 7a4.5 4.5 0 0 0 .1 1A11.9 11.9 0 0 1 3 3.7a4.2 4.2 0 0 0 1.3 5.6 4.1 4.1 0 0 1-1.9-.5 4.2 4.2 0 0 0 3.4 4.1 4.2 4.2 0 0 1-1.9.1 4.2 4.2 0 0 0 3.9 2.9A8.4 8.4 0 0 1 2 17.6 11.9 11.9 0 0 0 8.4 19.5c7.6 0 11.8-6.4 11.8-11.9v-.5A8.5 8.5 0 0 0 22 4.5z"/>',
    dispatch: '<path d="M12 9v4M12 17h.01"/><path d="M10.3 3.9L1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/>',
    briefcase: '<rect x="2" y="7" width="20" height="14" rx="2"/><path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"/>',

    arrowDown: '<path d="M12 5v14M19 12l-7 7-7-7"/>',
    arrowUp: '<path d="M12 19V5M5 12l7-7 7 7"/>',
    check: '<path d="M20 6L9 17l-5-5"/>',
    inbox: '<path d="M22 12h-6l-2 3h-4l-2-3H2"/><path d="M5.5 5.1L2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.5-6.9A2 2 0 0 0 16.7 4H7.3a2 2 0 0 0-1.8 1.1z"/>',
    receipt: '<path d="M4 2v20l2.5-1.7L9 22l3-1.7L15 22l2.5-1.7L20 22V2l-2.5 1.7L15 2l-3 1.7L9 2 6.5 3.7z"/><path d="M8 8h8M8 12h8M8 16h5"/>',
};

/**
 * @param {string} name icon key, or any string to fall back to a glyph
 * @param {string} cls
 * @returns {SVGElement|HTMLElement}
 */
function icon(name, cls) {
    const path = ICONS[name];
    if (!path) {
        // Third-party apps registering an emoji or letter still render.
        return el('span', cls, name);
    }

    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('fill', 'none');
    svg.setAttribute('stroke', 'currentColor');
    svg.setAttribute('stroke-width', '1.9');
    svg.setAttribute('stroke-linecap', 'round');
    svg.setAttribute('stroke-linejoin', 'round');
    svg.innerHTML = path;
    if (cls) svg.setAttribute('class', cls);
    return svg;
}

function showView(id) {
    document.querySelectorAll('.view').forEach((v) => v.classList.add('hidden'));
    document.getElementById(`view-${id}`).classList.remove('hidden');
}

function applyTheme(name) {
    const theme = themes[name] || themes.default;
    root.style.setProperty('--accent', theme ? theme.accent : '#ff1493');
}

function toast(text, isError) {
    document.querySelectorAll('.toast').forEach((t) => t.remove());

    const node = el('div', `toast${isError ? ' toast--error' : ''}`, text);
    document.querySelector('.screen').appendChild(node);
    setTimeout(() => node.remove(), 3200);
}

// --- Clock --------------------------------------------------------------

function tick() {
    const now = new Date();
    const time = now.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' });

    document.getElementById('status-time').textContent = time;
    document.getElementById('lock-time').textContent = time;
    document.getElementById('lock-date').textContent = now.toLocaleDateString('en-GB', {
        weekday: 'long', day: 'numeric', month: 'long',
    });
}

// --- Home ---------------------------------------------------------------

function renderApps(apps) {
    const frag = document.createDocumentFragment();

    apps.forEach((app, i) => {
        const btn = el('button', 'app');
        btn.type = 'button';
        btn.style.animationDelay = `${35 * i}ms`;

        const tile = el('span', 'app__icon');
        const c = app.colour || '#ff1493';
        // Two-stop gradient off the registered colour, so an app only has to
        // declare one value but still gets a lit tile rather than a flat swatch.
        tile.style.background =
            `linear-gradient(155deg, color-mix(in srgb, ${c} 62%, #fff) 0%, ${c} 52%, ` +
            `color-mix(in srgb, ${c} 72%, #000) 100%)`;
        tile.appendChild(icon(app.icon, 'app__icon--glyph'));

        const count = badges[app.id];
        if (count) tile.appendChild(el('span', 'app__badge', count > 99 ? '99+' : String(count)));

        btn.append(tile, el('span', 'app__label', app.label));
        btn.addEventListener('click', () => openApp(app.id));
        frag.appendChild(btn);
    });

    appsEl.replaceChildren(frag);
}

async function openApp(id) {
    if (id === 'bank') {
        await loadBank();
        showView('bank');
        return;
    }
    if (id === 'settings') {
        renderThemes();
        showView('settings');
        return;
    }
    // Apps registered by other resources are not handled here yet; 4b-2 gives
    // them their own view container.
    toast('Not available yet');
}

// --- Bank ---------------------------------------------------------------

async function loadBank() {
    bank = await post('bank');
    if (!bank) return;

    document.getElementById('bank-balance').textContent = money(bank.money && bank.money.bank);
    document.getElementById('bank-cash').textContent =
        `${money(bank.money && bank.money.cash)} in cash`;
    document.getElementById('bank-account-no').textContent = bank.accountNo || '--------';

    const count = (bank.bills || []).length;
    badges.bank = count;

    const pill = document.getElementById('bill-count');
    pill.textContent = String(count);
    pill.classList.toggle('hidden', count === 0);

    renderHistory();
    renderBills();
    renderAccountOptions();
}

function emptyState(iconName, text) {
    const wrap = el('div', 'empty');
    wrap.appendChild(icon(iconName));
    wrap.appendChild(el('div', null, text));
    return wrap;
}

function renderHistory() {
    const pane = document.getElementById('tab-history');
    const rows = bank.history || [];

    if (!rows.length) {
        pane.replaceChildren(emptyState('receipt', 'No transactions yet'));
        return;
    }

    const list = el('div', 'list');
    rows.forEach((t) => {
        const isIn = t.direction === 'credit';
        const row = el('div', 'row');

        const glyph = el('span', `row__glyph row__glyph--${isIn ? 'in' : 'out'}`);
        glyph.appendChild(icon(isIn ? 'arrowDown' : 'arrowUp'));

        const main = el('div', 'row__main');
        main.appendChild(el('div', 'row__title', t.reason || 'Transaction'));

        const when = new Date(t.created_at);
        main.appendChild(el('div', 'row__sub',
            `${t.account}${Number.isNaN(when.getTime()) ? '' : ' · ' + when.toLocaleString('en-GB', {
                day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit',
            })}`));

        row.append(glyph, main, el('span', `row__amount row__amount--${isIn ? 'in' : 'out'}`,
            `${isIn ? '+' : '-'}${money(t.amount)}`));
        list.appendChild(row);
    });

    pane.replaceChildren(list);
}

function renderBills() {
    const wrap = document.getElementById('bills-list');
    const bills = bank.bills || [];

    if (!bills.length) {
        wrap.replaceChildren(emptyState('inbox', 'No outstanding bills'));
        return;
    }

    const list = el('div', 'list');
    bills.forEach((b) => {
        const row = el('div', 'row');

        const main = el('div', 'row__main');
        main.appendChild(el('div', 'row__title', b.reason));
        main.appendChild(el('div', 'row__sub', `${b.from_name} · ${money(b.amount)}`));

        const actions = el('div', 'row__actions');

        const pay = el('button', 'btn btn--primary btn--sm', 'Pay');
        pay.type = 'button';
        pay.addEventListener('click', async () => {
            pay.disabled = true;
            const res = await post('payBill', { id: b.id });
            if (!res.success) toast(res.error || 'Could not pay', true);
            await loadBank();
        });

        const decline = el('button', 'btn btn--danger btn--sm', 'Decline');
        decline.type = 'button';
        decline.addEventListener('click', async () => {
            decline.disabled = true;
            await post('declineBill', { id: b.id });
            await loadBank();
        });

        actions.append(pay, decline);
        row.append(main, actions);
        list.appendChild(row);
    });

    wrap.replaceChildren(list);
}

function renderAccountOptions() {
    const saved = bank.saved || [];
    const build = () =>
        saved.length
            ? saved.map((s) => {
                  const o = document.createElement('option');
                  o.value = s.account_no;
                  o.textContent = `${s.label} (${s.account_no})`;
                  return o;
              })
            : [Object.assign(document.createElement('option'), {
                  value: '', textContent: 'Nobody has shared their account with you',
              })];

    document.getElementById('bill-account').replaceChildren(...build());
    document.getElementById('send-account').replaceChildren(...build());
}

// --- Settings -----------------------------------------------------------

function renderThemes() {
    const wrap = document.getElementById('themes');
    const frag = document.createDocumentFragment();

    Object.entries(themes).forEach(([id, theme]) => {
        const btn = el('button', 'theme');
        btn.type = 'button';

        const swatch = el('span', 'theme__swatch');
        swatch.style.background = theme.accent;
        btn.append(swatch, el('span', 'theme__label', theme.label));

        if (id === settings.theme) {
            const check = el('span', 'theme__check');
            check.appendChild(icon('check'));
            btn.appendChild(check);
        } else if (theme.perk) {
            btn.appendChild(el('span', 'theme__lock', 'Supporter'));
        }

        btn.addEventListener('click', async () => {
            const res = await post('setTheme', { theme: id });
            if (!res.success) {
                btn.classList.add('is-locked');
                toast(res.error || 'That theme is not unlocked', true);
                return;
            }
            settings.theme = id;
            applyTheme(id);
            renderThemes();
        });

        frag.appendChild(btn);
    });

    wrap.replaceChildren(frag);
}

// --- Wiring -------------------------------------------------------------

function unlock() {
    if (!locked) return;
    locked = false;
    showView('home');
}

document.getElementById('view-lock').addEventListener('click', unlock);

document.querySelectorAll('[data-back]').forEach((b) =>
    b.addEventListener('click', () => showView('home')));

document.getElementById('home-btn').addEventListener('click', () => {
    if (locked) unlock(); else showView('home');
});

document.querySelectorAll('.segment__item').forEach((tab) =>
    tab.addEventListener('click', () => {
        document.querySelectorAll('.segment__item').forEach((t) => t.classList.remove('is-active'));
        tab.classList.add('is-active');
        document.querySelectorAll('.tabpane').forEach((p) => p.classList.add('hidden'));
        document.getElementById(`tab-${tab.dataset.tab}`).classList.remove('hidden');
    }));

document.getElementById('bank-account').addEventListener('click', async () => {
    const res = await post('shareAccount');
    toast(res.success ? `Shared with ${res.shared} nearby` : (res.error || 'Could not share'), !res.success);
});

document.getElementById('bill-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const res = await post('createBill', {
        accountNo: document.getElementById('bill-account').value,
        amount: Number(document.getElementById('bill-amount').value),
        reason: document.getElementById('bill-reason').value,
    });
    toast(res.success ? 'Bill sent' : (res.error || 'Could not send'), !res.success);
    if (res.success) e.target.reset();
});

document.getElementById('send-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const res = await post('transfer', {
        accountNo: document.getElementById('send-account').value,
        amount: Number(document.getElementById('send-amount').value),
    });
    toast(res.success ? 'Transfer sent' : (res.error || 'Could not transfer'), !res.success);
    if (res.success) { e.target.reset(); await loadBank(); }
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        post('close');
        root.classList.add('hidden');
        return;
    }
    if (e.key === 'Enter' && locked && !e.target.matches('input, select, textarea')) unlock();
});

tick();
setInterval(tick, 1000);

window.addEventListener('message', async (event) => {
    const msg = event.data;
    if (!msg || typeof msg.action !== 'string') return;

    if (msg.action === 'open') {
        const d = msg.data || {};
        themes = d.themes || {};
        settings = d.settings || { theme: 'default' };
        badges = d.badges || {};

        document.getElementById('lock-owner').textContent = d.owner || '';
        document.getElementById('lock-number').textContent = d.number || '';

        applyTheme(settings.theme);
        renderApps(d.apps || []);

        // Always opens locked. It is one click, and it is the difference
        // between a menu and something that reads as a phone.
        locked = true;
        showView('lock');
        tick();

        root.classList.remove('hidden');
        return;
    }

    if (msg.action === 'refresh') {
        if (!document.getElementById('view-bank').classList.contains('hidden')) await loadBank();
        return;
    }

    if (msg.action === 'close') root.classList.add('hidden');
});
