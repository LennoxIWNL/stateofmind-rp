const RESOURCE = window.location.hostname.replace('cfx-nui-', '');

const root = document.getElementById('root');
const listEl = document.getElementById('list');
const searchEl = document.getElementById('search');

let state = {
    vehicles: [], catalogue: [], payment: [], account: null, tab: 'owned',
    // 'garage' or 'shop'. A shop has no owned vehicles and a much longer
    // catalogue, and at a managed one the buy button asks a person rather than
    // a terminal.
    mode: 'garage', shopType: null, dealer: false,
    deliverLabel: null, testDrive: null,
};

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
    // textContent, never innerHTML: plates and labels are player and config
    // data, not markup.
    if (text !== undefined) node.textContent = text;
    return node;
}

function toast(text) {
    const node = document.getElementById('toast');
    node.textContent = text;
    node.classList.remove('hidden');
    clearTimeout(node._t);
    node._t = setTimeout(() => node.classList.add('hidden'), 3200);
}

/* A condition bar. body and engine arrive as percentages already. */
/* The vehicle shot on a list row.
 *
 * Same treatment as the shop card: contained rather than cropped, lifted off
 * the panel with a drop shadow, and keyed by SPAWN NAME so one folder in
 * som-assets serves the garage, the rental counter and anything else that has
 * to draw a car.
 *
 * A missing file is expected while the set is filled in, so the image removes
 * itself and the plate underneath shows through. A broken-image glyph on every
 * row would read as the garage being broken. */
function thumb(model) {
    const wrap = el('div', 'row__thumb');
    wrap.append(el('span', 'row__thumbplate', String(model || '').toUpperCase()));

    const img = document.createElement('img');
    img.src = `https://cfx-nui-som-assets/img/vehicles/${model}.png`;
    img.alt = '';
    img.loading = 'lazy';
    img.addEventListener('error', () => img.remove());

    wrap.appendChild(img);
    return wrap;
}

function meter(label, value) {
    const wrap = el('div', 'meter');
    wrap.append(el('span', 'meter__label', label));

    const track = el('div', 'meter__track');
    const fill = el('div', 'meter__fill');
    fill.style.width = `${Math.max(0, Math.min(100, value))}%`;

    // Colour carries the same information as the width, so the state is
    // readable at a glance rather than needing to be measured.
    if (value < 35) fill.classList.add('is-bad');
    else if (value < 70) fill.classList.add('is-warn');

    track.appendChild(fill);
    wrap.append(track);
    return wrap;
}

/* Which row is selected. Selecting PREVIEWS; taking is a separate, deliberate
 * button.
 *
 * Clicking a row used to pull the car straight out, which meant browsing the
 * fleet was impossible: every look cost you a spawn. */
let selectedId = null;

function renderOwned(filter) {
    const frag = document.createDocumentFragment();

    const rows = state.vehicles.filter((v) =>
        !filter
        || v.plate.toLowerCase().includes(filter)
        || v.model.toLowerCase().includes(filter)
        || (v.label || '').toLowerCase().includes(filter));

    if (!rows.length) {
        frag.appendChild(el('p', 'empty', 'Nothing here.'));
        listEl.replaceChildren(frag);
        return;
    }

    rows.forEach((v) => {
        const row = el('div', 'row');
        if (v.locked) row.classList.add('is-locked');
        if (v.id === selectedId) row.classList.add('is-selected');

        row.appendChild(thumb(v.model));

        const head = el('div', 'row__head');
        head.append(
            el('span', 'row__name', v.label || v.model),
            el('span', 'row__plate', v.plate));
        row.appendChild(head);

        if (v.locked) {
            row.appendChild(el('div', 'row__note', v.lockReason || 'Unavailable'));
        } else {
            const meters = el('div', 'row__meters');
            meters.append(meter('Body', v.body), meter('Engine', v.engine));
            row.appendChild(meters);
        }

        if (v.shared) row.appendChild(el('span', 'tag', 'Pool'));

        // Selecting only previews. A locked car still previews: seeing what you
        // cannot have yet is the reason to show it at all.
        row.addEventListener('click', () => {
            selectedId = v.id;
            post('select', { model: v.model, props: v.props });
            render();
        });

        // The take button, shown only on the selected row so the list stays a
        // list rather than a wall of buttons.
        if (v.id === selectedId && !v.locked) {
            const take = el('button', 'row__take', 'Take out');
            take.type = 'button';

            take.addEventListener('click', async (e) => {
                e.stopPropagation();
                take.disabled = true;

                const res = await post('take', { id: v.id });

                if (!res.success) {
                    take.disabled = false;
                    toast(res.error || 'Could not take that');
                }
            });

            row.appendChild(take);
        }

        frag.appendChild(row);
    });

    listEl.replaceChildren(frag);
}

/* Which catalogue row is selected. Same idea as selectedId on the owned tab:
 * clicking PREVIEWS and the action is a separate, deliberate button. */
let selectedModel = null;

function renderBuy(filter) {
    const frag = document.createDocumentFragment();

    const rows = state.catalogue.filter((v) =>
        !filter
        || v.model.toLowerCase().includes(filter)
        || (v.label || '').toLowerCase().includes(filter)
        || (v.categoryLabel || '').toLowerCase().includes(filter));

    if (!rows.length) {
        frag.appendChild(el('p', 'empty', 'Nothing for sale here.'));
        listEl.replaceChildren(frag);
        return;
    }

    const shop = state.mode === 'shop';
    const managed = shop && state.shopType === 'managed';
    const account = state.payment.find((p) => p.account === state.account);

    rows.forEach((v) => {
        // A DIV rather than a button, because a row now carries buttons of its
        // own and a button inside a button is not valid markup. It is also what
        // fixes browsing: a disabled button fires no mouse events in this
        // engine, so an unaffordable car could not even be previewed, which on
        // a shop floor is the one thing you most want to do.
        const row = el('div', 'row');
        if (v.model === selectedModel) row.classList.add('is-selected');

        row.appendChild(thumb(v.model));

        const head = el('div', 'row__head');
        head.append(el('span', 'row__name', v.label || v.model),
            el('span', 'row__price', money(v.price)));
        row.appendChild(head);

        row.appendChild(el('div', 'row__note', shop
            ? 'Delivered to ' + (state.deliverLabel || 'your garage')
            : 'Yours to keep and modify. Stays at this department.'));

        if (shop && v.categoryLabel) row.appendChild(el('span', 'tag', v.categoryLabel));

        row.addEventListener('click', () => {
            selectedModel = v.model;
            post('select', { model: v.model });
            render();
        });

        if (v.model === selectedModel) {
            const actions = el('div', 'row__actions');

            // Test drives are the shop's, not the department's, and only for
            // cars under the cap. Above it the car is looked at, which is also
            // how it works in a real showroom.
            const drivable = shop && state.testDrive && state.testDrive.allowed
                && (!state.testDrive.maxPrice || v.price <= state.testDrive.maxPrice);

            if (drivable) {
                const drive = el('button', 'row__take row__take--ghost', 'Test drive');
                drive.type = 'button';

                drive.addEventListener('click', async (e) => {
                    e.stopPropagation();
                    drive.disabled = true;

                    const res = await post('testDrive', { model: v.model });
                    if (!res.success) {
                        drive.disabled = false;
                        toast(res.error || 'Could not bring it round');
                    }
                });

                actions.appendChild(drive);
            }

            // At a managed shop a dealer SELLS and everybody else is told who
            // to ask. The button says which of the two is about to happen.
            const affordable = !managed && account && account.balance >= v.price;
            const label = managed
                ? (state.dealer ? 'Sell to nearby' : 'Ask a member of staff')
                : (affordable ? 'Buy' : 'Cannot afford');

            const buy = el('button', 'row__take', label);
            buy.type = 'button';
            buy.disabled = managed ? !state.dealer : !affordable;

            buy.addEventListener('click', async (e) => {
                e.stopPropagation();
                buy.disabled = true;

                const res = await post('buy', { model: v.model, account: state.account });

                if (!res.success) {
                    buy.disabled = false;
                    toast(res.error || 'Could not buy that');
                }
            });

            actions.appendChild(buy);
            row.appendChild(actions);
        }

        frag.appendChild(row);
    });

    listEl.replaceChildren(frag);
}

function render() {
    const filter = searchEl.value.trim().toLowerCase();
    if (state.tab === 'buy') renderBuy(filter); else renderOwned(filter);
}

/* Cash or card. Label only: the balance turned a two-word choice into a
 * financial readout. */
function renderPayment() {
    const wrap = document.getElementById('pay');
    const frag = document.createDocumentFragment();

    state.payment.forEach((option) => {
        const btn = el('button', 'pay__opt');
        btn.type = 'button';
        if (option.account === state.account) btn.classList.add('is-active');
        btn.append(el('span', 'pay__label', option.label));

        btn.addEventListener('click', () => {
            state.account = option.account;
            renderPayment();
            render();
        });

        frag.appendChild(btn);
    });

    wrap.replaceChildren(frag);
}

/* Rotation. The drag is tracked here and the delta posted per move, so the
 * camera follows the mouse rather than snapping when the button is released. */
(function dragToRotate() {
    const stage = document.getElementById('stage');
    let last = null;

    stage.addEventListener('mousedown', (e) => { last = e.clientX; });

    window.addEventListener('mousemove', (e) => {
        if (last === null) return;
        const delta = e.clientX - last;
        last = e.clientX;
        if (delta) post('rotate', { delta: delta });
    });

    window.addEventListener('mouseup', () => {
        if (last === null) return;
        last = null;
        post('rotateEnd');
    });
})();

function setTab(tab) {
    state.tab = tab;
    document.getElementById('tab-owned').classList.toggle('is-active', tab === 'owned');
    document.getElementById('tab-buy').classList.toggle('is-active', tab === 'buy');
    document.getElementById('pay').classList.toggle('hidden', tab !== 'buy');
    render();
}

document.getElementById('tab-owned').addEventListener('click', () => setTab('owned'));
document.getElementById('tab-buy').addEventListener('click', () => setTab('buy'));
searchEl.addEventListener('input', render);

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

        const shop = d.mode === 'shop';

        state = {
            vehicles: d.vehicles || [],
            catalogue: d.catalogue || [],
            payment: payment,
            account: (payment.find((p) => p.balance > 0) || payment[0] || {}).account,
            tab: shop ? 'buy' : 'owned',
            mode: shop ? 'shop' : 'garage',
            shopType: d.shopType || null,
            dealer: d.dealer === true,
            deliverLabel: d.deliverLabel || null,
            testDrive: d.testDrive || null,
        };

        selectedId = (state.vehicles[0] || {}).id ?? null;
        selectedModel = (state.catalogue[0] || {}).model ?? null;

        document.getElementById('title').textContent = d.label || 'Garage';
        // A shop has nothing of yours parked in it, so the tab that would list
        // it goes rather than sitting there empty.
        document.getElementById('tab-owned').classList.toggle('hidden', shop);
        document.getElementById('tab-buy').classList.toggle('hidden', !state.catalogue.length);
        searchEl.placeholder = shop ? 'Search the stock' : 'Search';
        searchEl.value = '';

        renderPayment();
        setTab(state.tab);
        root.classList.remove('hidden');
        return;
    }

    if (msg.action === 'close') root.classList.add('hidden');
});
