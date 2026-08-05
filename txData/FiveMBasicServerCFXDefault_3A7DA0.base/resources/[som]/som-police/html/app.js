const RESOURCE = window.location.hostname.replace('cfx-nui-', '');

const root = document.getElementById('root');

let state = { issue: [], personal: [], payment: [], account: null };

/* Set the moment a draw succeeds and consumed by the next render, which is the
 * one that has the new balances. Held here rather than animated at the click,
 * because at the click the balance has not moved yet. */
let pending = null;

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
    // So the row that was drawn from can be found again after the redraw.
    row.dataset.item = entry.item;

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

        const before = balanceOf(state.account);
        const res = await post('take', { item: entry.item, account: state.account });

        // The server decides. A refusal re-enables the row rather than
        // pretending the click did something.
        if (!res.success) {
            row.disabled = false;
            toast(res.error || 'Could not take that');
            return;
        }

        // Acknowledge it. The refresh that follows redraws this row, so the
        // flash is applied to whatever replaces it rather than to this node,
        // and the pending spend is held for renderPayment to animate.
        pending = {
            item: entry.item,
            spent: res.price > 0 ? res.price : 0,
            before: before,
        };

        receipt(res, free);
    });

    return row;
}

/** Balance on an account right now, or null if it is not a known account. */
function balanceOf(account) {
    const option = state.payment.find((p) => p.account === account);
    return option ? option.balance : null;
}

/* The footer becomes a receipt after the first draw.
 *
 * Deliberately the footer and not a toast: a toast is for things that went
 * wrong and disappears before it is read. What you drew and what it cost is
 * worth leaving on screen while you keep shopping. */
function receipt(res, free) {
    const node = document.getElementById('receipt');
    const count = res.count > 1 ? `${res.count}x ` : '';
    const label = res.label || 'Item';

    node.textContent = free || !res.price
        ? `Drew ${count}${label} from department issue`
        : `Bought ${count}${label} for ${money(res.price)}`;

    node.classList.add('is-receipt');
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

    // Flash the row that was just drawn from. Applied after the redraw, to the
    // node that replaced the clicked one.
    if (pending) {
        const row = document.querySelector(`.row[data-item="${cssEscape(pending.item)}"]`);
        if (row) row.classList.add('is-taken');
    }
}

/* Attribute selectors need escaping and item names come from config. Quotes and
 * backslashes are the only characters that can break out of the selector. */
function cssEscape(value) {
    return String(value).replace(/["\\]/g, '\\$&');
}

/* Cash or card. The options and balances come from som-core, so every shop
 * offers the same choice and the server validates whatever comes back. */
function renderPayment() {
    const frag = document.createDocumentFragment();

    state.payment.forEach((option) => {
        const btn = el('button', 'pay__opt');
        btn.type = 'button';
        if (option.account === state.account) btn.classList.add('is-active');

        // Label AND balance. An earlier pass dropped the balance on the grounds
        // that the player already knows what they have, which was wrong in one
        // specific way: with it gone, nothing on screen moved when you bought
        // something, so a purchase and a refusal looked identical. The number
        // changing is the feedback.
        btn.append(
            el('span', 'pay__label', option.label),
            el('span', 'pay__value', money(option.balance)));

        btn.addEventListener('click', () => {
            state.account = option.account;
            renderPayment();
            render();
        });

        // The account that just paid gets the moving number, so the spend is
        // attached to the account it came out of rather than to the panel.
        if (pending && pending.spent > 0 && option.account === state.account
            && pending.before !== null && option.balance !== pending.before) {
            btn.querySelector('.pay__value').classList.add('is-spent');
        }

        frag.appendChild(btn);
    });

    document.getElementById('pay').replaceChildren(frag);

    if (pending && pending.spent > 0) {
        // The cost, floating up and out. Two balances a second apart do not
        // tell you what something cost; this does.
        const delta = el('span', 'pay__delta', `-${money(pending.spent)}`);
        document.querySelector('.panel__pay').appendChild(delta);
        setTimeout(() => delta.remove(), 1100);
    }
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

        // Cleared only once BOTH halves have used it. renderPayment animates
        // the balance and render flashes the row, in that order, so clearing it
        // inside either one would rob the other.
        pending = null;
        return;
    }

    if (msg.action === 'close') show(null);
});
