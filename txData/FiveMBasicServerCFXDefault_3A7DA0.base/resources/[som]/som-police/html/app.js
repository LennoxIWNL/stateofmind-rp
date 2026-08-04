const RESOURCE = window.location.hostname.replace('cfx-nui-', '');

const root = document.getElementById('root');

let state = { issue: [], personal: [], payment: [], account: null };

function post(endpoint, body) {
    return fetch(`https://${RESOURCE}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body ?? {}),
    }).then((r) => r.json()).catch(() => ({ success: false }));
}

const money = (n) => `$${Number(n || 0).toLocaleString('en-US')}`;

function el(tag, cls, text) {
    const node = document.createElement(tag);
    if (cls) node.className = cls;
    // textContent, never innerHTML: labels come from config and are not markup.
    if (text !== undefined) node.textContent = text;
    return node;
}

function toast(text) {
    document.querySelectorAll('.toast').forEach((t) => t.remove());
    const node = el('div', 'toast', text);
    document.querySelector('.panel').appendChild(node);
    setTimeout(() => node.remove(), 3200);
}

/* One row. `free` items are department issue: no price, and affordability
 * never applies to them. */
function renderRow(entry, free) {
    const row = el('button', 'row');
    row.type = 'button';

    const left = el('div');
    left.append(
        el('div', 'row__name', entry.label),
        el('div', 'row__sub', entry.count > 1 ? `${entry.count} issued` : 'Single item'));

    row.append(left, el('span', 'row__price', free ? 'Issued' : money(entry.price)));

    if (!free) {
        // Unaffordable ON THE SELECTED ACCOUNT rather than hidden. Switching
        // account re-renders, so the list answers "can I pay for this with what
        // I just picked" instead of quietly hiding the item.
        const selected = state.payment.find((p) => p.account === state.account);
        if (!selected || selected.balance < entry.price) row.disabled = true;
    }

    row.addEventListener('click', async () => {
        row.disabled = true;
        const res = await post('take', { item: entry.item, account: state.account });

        // The server decides. A refusal re-enables the row rather than
        // pretending the click did something.
        if (!res.success) {
            row.disabled = false;
            toast(res.error || 'Could not take that');
        }
    });

    return row;
}

function render() {
    const issueFrag = document.createDocumentFragment();
    state.issue.forEach((entry) => issueFrag.appendChild(renderRow(entry, true)));
    document.getElementById('issue').replaceChildren(issueFrag);

    const personalFrag = document.createDocumentFragment();
    state.personal.forEach((entry) => personalFrag.appendChild(renderRow(entry, false)));
    document.getElementById('personal').replaceChildren(personalFrag);
}

/* Cash or card. The options and balances come from som-core, so every shop
 * offers the same choice and the server validates whatever comes back. */
function renderPayment() {
    const frag = document.createDocumentFragment();

    state.payment.forEach((option) => {
        const btn = el('button', 'pay__opt');
        btn.type = 'button';
        if (option.account === state.account) btn.classList.add('is-active');

        // Label only. Showing the balance turned a two-word choice into a
        // financial readout, and the player already knows what they have.
        btn.append(el('span', 'pay__label', option.label));

        btn.addEventListener('click', () => {
            state.account = option.account;
            renderPayment();
            render();
        });

        frag.appendChild(btn);
    });

    document.getElementById('pay').replaceChildren(frag);
}

function close() {
    show(null);
    post('close');
}

document.getElementById('close').addEventListener('click', close);

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !root.classList.contains('hidden')) close();
});

/* Two views on one page. Showing one always hides the other, so a stray message
 * can never leave both up at once. */
function show(which) {
    document.getElementById('armoury').classList.toggle('hidden', which !== 'armoury');
    document.getElementById('certs').classList.toggle('hidden', which !== 'certs');
    root.classList.toggle('hidden', which === null);
}

/* Certifications. Read-only by design: granting happens in the MDT, where the
 * rank check lives, and offering a control here that always refused would be
 * worse than offering none. */
function renderCerts(d) {
    const list = document.getElementById('cert-list');
    const frag = document.createDocumentFragment();

    const held = (d.certifications || []).filter((c) => c.held).length;
    const total = (d.certifications || []).length;

    document.getElementById('cert-name').textContent = d.name || 'Officer';
    document.getElementById('cert-badge').textContent = d.badge || 'LSPD';
    document.getElementById('cert-count').textContent = `${held}/${total}`;

    (d.certifications || []).forEach((cert) => {
        const row = el('div', 'cert');
        row.classList.add(cert.held ? 'cert--held' : 'cert--none');

        const mark = el('span', 'cert__mark', cert.held ? '✓' : '✕');

        const body = el('div', 'cert__body');
        body.append(
            el('span', 'cert__label', cert.label),
            // What it actually gates, not a restatement of the name. A
            // certification list nobody can act on has to at least explain
            // itself.
            el('span', 'cert__desc', cert.held ? (cert.description || '') : 'Not certified'));

        row.append(mark, body);
        frag.appendChild(row);
    });

    if (!total) frag.appendChild(el('p', 'cert__empty', 'No certifications defined.'));

    list.replaceChildren(frag);
}

document.getElementById('cert-close').addEventListener('click', () => {
    show(null);
    post('close');
});

window.addEventListener('message', (event) => {
    const msg = event.data;
    if (!msg || typeof msg.action !== 'string') return;

    if (msg.action === 'certs') {
        renderCerts(msg.data || {});
        show('certs');
        return;
    }

    if (msg.action === 'open') {
        const d = msg.data || {};
        const payment = d.payment || [];

        state = {
            issue: d.issue || [],
            personal: d.personal || [],
            payment: payment,
            // Defaults to an account that actually holds something, so an
            // officer with an empty wallet and a full bank is not told
            // everything is unaffordable.
            account: (payment.find((p) => p.balance > 0) || payment[0] || {}).account,
        };

        document.getElementById('title').textContent = d.label || 'Armoury';

        renderPayment();
        render();
        show('armoury');
        return;
    }

    if (msg.action === 'refresh') {
        const d = msg.data || {};
        state.issue = d.issue || state.issue;
        state.personal = d.personal || state.personal;
        state.payment = d.payment || state.payment;

        // The chosen account is kept across a refresh. Resetting it after every
        // purchase would silently move the officer back to cash mid-shop.
        renderPayment();
        render();
        return;
    }

    if (msg.action === 'close') show(null);
});
