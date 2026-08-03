const RESOURCE = window.location.hostname.replace('cfx-nui-', '');

const root = document.getElementById('root');
const listEl = document.getElementById('list');

let state = { deposit: 0, balance: 0 };

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

        // Shown as unaffordable rather than hidden, so the price stays
        // information rather than becoming a mystery.
        if (state.balance < total) row.disabled = true;

        row.addEventListener('click', async () => {
            row.disabled = true;
            const res = await post('rent', { model: v.model });

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
        state = { deposit: d.deposit || 0, balance: d.balance || 0 };

        document.getElementById('title').textContent = d.label || 'Vehicle Rental';
        document.getElementById('balance').textContent = money(d.balance);
        document.getElementById('deposit-note').textContent =
            `${money(d.deposit)} deposit, returned with the vehicle`;

        render(d);
        root.classList.remove('hidden');
        return;
    }

    if (msg.action === 'close') root.classList.add('hidden');
});
