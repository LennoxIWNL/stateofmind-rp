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

/* One row. `free` items are department issue: no price, and affordability never
 * applies to them.
 *
 * State is carried by the left rule and the mark, the way the certification
 * card does it, rather than by opacity. A dimmed row reads as broken; a marked
 * one reads as unavailable, which is what it is. */
function renderRow(entry, free) {
    const row = el('button', 'row');
    row.type = 'button';

    // Quantity is worth saying only when it is not one. "Single item" on every
    // row was noise that pushed the useful line out of view.
    const qty = entry.count > 1 ? `${entry.count} per draw` : '';

    let blocked = false;
    let reason = qty;

    if (!free) {
        // Unaffordable ON THE SELECTED ACCOUNT rather than hidden. Switching
        // account re-renders, so the list answers "can I pay for this with what
        // I just picked" instead of quietly hiding the item.
        const selected = state.payment.find((p) => p.account === state.account);

        if (!selected || selected.balance < entry.price) {
            blocked = true;
            row.disabled = true;
            // Says WHICH account is short, because the fix is usually to switch
            // rather than to earn. The old version disabled the row silently.
            reason = selected
                ? `Not enough on ${selected.label.toLowerCase()}`
                : 'No payment method';
        }
    }

    row.classList.add(free ? 'row--issue' : blocked ? 'row--blocked' : 'row--buy');

    row.append(el('span', 'row__mark', free ? '✓' : blocked ? '✕' : '+'));

    const body = el('div', 'row__body');
    body.append(el('span', 'row__name', entry.label));
    if (reason) body.append(el('span', 'row__sub', reason));
    row.append(body);

    row.append(el('span', 'row__price', free ? 'Issued' : money(entry.price)));

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

function fillList(id, entries, free) {
    const frag = document.createDocumentFragment();

    entries.forEach((entry) => frag.appendChild(renderRow(entry, free)));

    // An empty section with no explanation looks like a failed load. Personal
    // equipment can legitimately be empty when nothing is affordable or the
    // officer holds no certifications.
    if (!entries.length) {
        frag.appendChild(el('p', 'list__empty', 'Nothing stocked for you here.'));
    }

    document.getElementById(id).replaceChildren(frag);
}

function render() {
    fillList('issue', state.issue, true);
    fillList('personal', state.personal, false);

    // What this officer can actually draw, which is not the length of the
    // config: the server filters by certification and rank before sending.
    document.getElementById('stock-count').textContent =
        state.issue.length + state.personal.length;
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

        // The station name, under the fixed "Armoury" title. The badge carries
        // the department, so the heading no longer has to.
        document.getElementById('title').textContent = d.label || 'Mission Row';

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
