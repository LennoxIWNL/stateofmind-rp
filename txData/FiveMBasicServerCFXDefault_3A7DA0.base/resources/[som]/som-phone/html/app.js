const RESOURCE = window.location.hostname.replace('cfx-nui-', '');

const root = document.getElementById('root');
const appsEl = document.getElementById('apps');
const ownerEl = document.getElementById('status-owner');
const timeEl = document.getElementById('status-time');

let themes = {};
let settings = { theme: 'default' };
let bank = null;

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

function showView(id) {
    document.querySelectorAll('.view').forEach((v) => v.classList.add('hidden'));
    document.getElementById(`view-${id}`).classList.remove('hidden');
}

function applyTheme(name) {
    const theme = themes[name] || themes.default;
    root.style.setProperty('--accent', theme ? theme.accent : '#ff1493');
}

// --- Home ---------------------------------------------------------------

function renderApps(apps) {
    const frag = document.createDocumentFragment();

    apps.forEach((app, i) => {
        const btn = el('button', 'app');
        btn.type = 'button';
        btn.style.animationDelay = `${40 * i}ms`;

        const icon = el('span', 'app__icon', app.icon || '?');
        icon.style.background = app.colour || 'var(--accent)';

        btn.append(icon, el('span', 'app__label', app.label));
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
    showView('home');
}

// --- Bank ---------------------------------------------------------------

async function loadBank() {
    bank = await post('bank');
    if (!bank) return;

    document.getElementById('bank-balance').textContent = money(bank.money && bank.money.bank);
    document.getElementById('bank-account-no').textContent = bank.accountNo || '---';

    const count = (bank.bills || []).length;
    const pill = document.getElementById('bill-count');
    pill.textContent = String(count);
    pill.classList.toggle('hidden', count === 0);

    renderHistory();
    renderBills();
    renderAccountOptions();
}

function renderHistory() {
    const pane = document.getElementById('tab-history');
    const rows = bank.history || [];

    if (!rows.length) {
        pane.replaceChildren(el('p', 'empty', 'No transactions yet'));
        return;
    }

    const frag = document.createDocumentFragment();
    rows.forEach((t) => {
        const row = el('div', 'row');

        const main = el('div', 'row__main');
        main.appendChild(el('div', 'row__title', t.reason || 'Transaction'));
        const when = new Date(t.created_at);
        main.appendChild(el('div', 'row__sub',
            `${t.account} · ${Number.isNaN(when.getTime()) ? '' : when.toLocaleString('en-GB')}`));

        const isIn = t.direction === 'credit';
        const amount = el('span', `row__amount row__amount--${isIn ? 'in' : 'out'}`,
            `${isIn ? '+' : '-'}${money(t.amount)}`);

        row.append(main, amount);
        frag.appendChild(row);
    });

    pane.replaceChildren(frag);
}

function renderBills() {
    const list = document.getElementById('bills-list');
    const bills = bank.bills || [];

    if (!bills.length) {
        list.replaceChildren(el('p', 'empty', 'No outstanding bills'));
        return;
    }

    const frag = document.createDocumentFragment();
    bills.forEach((b) => {
        const row = el('div', 'row');

        const main = el('div', 'row__main');
        main.appendChild(el('div', 'row__title', b.reason));
        main.appendChild(el('div', 'row__sub', `${b.from_name} · ${money(b.amount)}`));

        const actions = el('div', 'row__actions');

        const pay = el('button', 'btn btn--primary btn--sm', 'Pay');
        pay.addEventListener('click', async () => {
            pay.disabled = true;
            const res = await post('payBill', { id: b.id });
            if (!res.success) alertLine(res.error || 'Could not pay');
            await loadBank();
        });

        const decline = el('button', 'btn btn--danger btn--sm', 'Decline');
        decline.addEventListener('click', async () => {
            decline.disabled = true;
            await post('declineBill', { id: b.id });
            await loadBank();
        });

        actions.append(pay, decline);
        row.append(main, actions);
        frag.appendChild(row);
    });

    list.replaceChildren(frag);
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

function alertLine(text) {
    const pane = document.querySelector('.tabpane:not(.hidden)');
    if (!pane) return;
    const note = el('p', 'empty', text);
    pane.prepend(note);
    setTimeout(() => note.remove(), 4000);
}

// --- Settings -----------------------------------------------------------

function renderThemes() {
    const wrap = document.getElementById('themes');
    const frag = document.createDocumentFragment();

    Object.entries(themes).forEach(([id, theme]) => {
        const btn = el('button', 'theme');
        btn.type = 'button';
        if (id === settings.theme) btn.classList.add('is-active');

        const swatch = el('span', 'theme__swatch');
        swatch.style.background = theme.accent;

        btn.append(swatch, el('span', 'theme__label', theme.label));
        if (theme.perk) btn.appendChild(el('span', 'theme__lock', 'supporter'));

        btn.addEventListener('click', async () => {
            const res = await post('setTheme', { theme: id });
            if (!res.success) {
                btn.disabled = true;
                btn.appendChild(el('span', 'theme__lock', res.error || 'locked'));
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

document.querySelectorAll('[data-back]').forEach((b) =>
    b.addEventListener('click', () => showView('home')));

document.getElementById('home-btn').addEventListener('click', () => showView('home'));

document.querySelectorAll('.tab').forEach((tab) =>
    tab.addEventListener('click', () => {
        document.querySelectorAll('.tab').forEach((t) => t.classList.remove('is-active'));
        tab.classList.add('is-active');
        document.querySelectorAll('.tabpane').forEach((p) => p.classList.add('hidden'));
        document.getElementById(`tab-${tab.dataset.tab}`).classList.remove('hidden');
    }));

document.getElementById('bank-account').addEventListener('click', async () => {
    const res = await post('shareAccount');
    alertLine(res.success ? `Shared with ${res.shared} nearby` : (res.error || 'Could not share'));
});

document.getElementById('bill-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const res = await post('createBill', {
        accountNo: document.getElementById('bill-account').value,
        amount: Number(document.getElementById('bill-amount').value),
        reason: document.getElementById('bill-reason').value,
    });
    alertLine(res.success ? 'Bill sent' : (res.error || 'Could not send'));
    if (res.success) e.target.reset();
});

document.getElementById('send-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const res = await post('transfer', {
        accountNo: document.getElementById('send-account').value,
        amount: Number(document.getElementById('send-amount').value),
    });
    alertLine(res.success ? 'Transfer sent' : (res.error || 'Could not transfer'));
    if (res.success) { e.target.reset(); await loadBank(); }
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') { post('close'); root.classList.add('hidden'); }
});

setInterval(() => {
    timeEl.textContent = new Date().toLocaleTimeString('en-GB', {
        hour: '2-digit', minute: '2-digit',
    });
}, 1000);

window.addEventListener('message', async (event) => {
    const msg = event.data;
    if (!msg || typeof msg.action !== 'string') return;

    if (msg.action === 'open') {
        const d = msg.data || {};
        themes = d.themes || {};
        settings = d.settings || { theme: 'default' };
        ownerEl.textContent = d.owner || '';

        applyTheme(settings.theme);
        renderApps(d.apps || []);
        showView('home');
        root.classList.remove('hidden');
        return;
    }

    if (msg.action === 'refresh') {
        if (!document.getElementById('view-bank').classList.contains('hidden')) await loadBank();
        return;
    }

    if (msg.action === 'close') root.classList.add('hidden');
});
