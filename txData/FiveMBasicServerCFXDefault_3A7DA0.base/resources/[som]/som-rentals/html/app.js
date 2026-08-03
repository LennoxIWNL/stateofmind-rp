const RESOURCE = window.location.hostname.replace('cfx-nui-', '');

const root = document.getElementById('root');
const listEl = document.getElementById('list');

let state = { deposit: 0, payment: [], account: null };

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
    // textContent: labels come from config, never trusted as markup.
    if (text !== undefined) node.textContent = text;
    return node;
}

function toast(text) {
    document.querySelectorAll('.toast').forEach((t) => t.remove());
    const node = el('div', 'toast', text);
    document.querySelector('.panel').appendChild(node);
    setTimeout(() => node.remove(), 3200);
}

function render(data) {
    const frag = document.createDocumentFragment();

    (data.vehicles || []).forEach((v) => {
        const total = v.price + state.deposit;
        const row = el('button', 'row');
        row.type = 'button';

        const left = el('div');
        left.append(
            el('div', 'row__name', v.label),
            el('div', 'row__sub', `${money(v.price)} hire + ${money(state.deposit)} deposit`));

        row.append(left, el('span', 'row__price', money(total)));

        // Unaffordable ON THE SELECTED ACCOUNT, rather than hidden. Switching
        // to the other one re-renders, so the list answers "can I pay for this
        // with what I just picked" instead of hiding the price.
        const selected = state.payment.find((p) => p.account === state.account);
        if (!selected || selected.balance < total) row.disabled = true;

        row.addEventListener('click', async () => {
            row.disabled = true;
            const res = await post('rent', { model: v.model, account: state.account });

            // The server decides. A refusal re-enables the row rather than
            // pretending the click did something.
            if (!res.success) {
                row.disabled = false;
                toast(res.error || 'Could not rent that');
            }
        });

        frag.appendChild(row);
    });

    listEl.replaceChildren(frag);
}

/* Cash or card. The options and balances come from som-core, so every shop
 * offers the same choice and the server validates whatever comes back. */
function renderPayment() {
    const wrap = document.getElementById('pay');
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
            // Re-rendered because affordability is per account: what you can
            // buy changes with how you are paying.
            render(state.catalogue);
        });

        frag.appendChild(btn);
    });

    wrap.replaceChildren(frag);
}

function close() {
    root.classList.add('hidden');
    post('close');
}

document.getElementById('close').addEventListener('click', close);

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !root.classList.contains('hidden')) close();
});

window.addEventListener('message', (event) => {
    const msg = event.data;
    if (!msg || typeof msg.action !== 'string') return;

    if (msg.action === 'open') {
        const d = msg.data || {};
        const payment = d.payment || [];

        state = {
            deposit: d.deposit || 0,
            payment: payment,
            // Defaults to whichever account can actually cover the cheapest
            // option, so a player with an empty wallet and a full bank is not
            // told everything is unaffordable.
            account: (payment.find((p) => p.balance > 0) || payment[0] || {}).account,
            catalogue: d,
        };

        document.getElementById('title').textContent = d.label || 'Vehicle Rental';
        document.getElementById('deposit-note').textContent =
            `${money(d.deposit)} deposit, returned with the vehicle`;

        renderPayment();
        render(d);
        root.classList.remove('hidden');
        return;
    }

    if (msg.action === 'close') root.classList.add('hidden');
});
