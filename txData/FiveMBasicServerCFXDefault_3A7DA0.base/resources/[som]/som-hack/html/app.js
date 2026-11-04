const RESOURCE = window.location.hostname.replace('cfx-nui-', '') || 'som-hack';

const root = document.getElementById('hack');
const titleEl = document.getElementById('hack-title');
const noteEl = document.getElementById('hack-note');
const bodyEl = document.getElementById('hack-body');
const statusEl = document.getElementById('hack-status');

let session = null;

function post(endpoint, body) {
    return fetch(`https://${RESOURCE}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body ?? {}),
    }).then((r) => r.json()).catch(() => ({}));
}

function el(tag, cls, text) {
    const node = document.createElement(tag);
    if (cls) node.className = cls;
    // textContent, never innerHTML.
    if (text !== undefined && text !== null) node.textContent = text;
    return node;
}

function say(text, kind) {
    statusEl.textContent = text || '';
    statusEl.className = 'hack__status' + (kind ? ` is-${kind}` : '');
}

function close() {
    if (!session) return;
    session.cancel?.();
    session = null;
    root.hidden = true;
    bodyEl.replaceChildren();
    say('');
    post('done');
}

/* The server answers, this page only reports what it sees. A short pause lets
 * the result be read before the page goes. */
function finishSoon() {
    const mine = session;
    setTimeout(() => { if (session === mine) close(); }, 1300);
}

function startMemory(view) {
    titleEl.textContent = 'Memorise';
    const grid = el('div', 'grid');
    grid.style.gridTemplateColumns = `repeat(${view.size}, 64px)`;

    const cells = [];
    const marks = new Map(view.marks.map((m) => [m.cell, m.n]));
    const picked = [];
    let picking = false;

    for (let i = 1; i <= view.size * view.size; i += 1) {
        const cell = el('button', 'cell');
        cell.type = 'button';
        cell.disabled = true;
        cell.setAttribute('aria-label', `cell ${i}`);
        if (marks.has(i)) {
            cell.textContent = String(marks.get(i));
            cell.classList.add('is-shown');
        }
        cell.addEventListener('click', () => {
            if (!picking || picked.includes(i)) return;
            picked.push(i);
            cell.classList.add('is-picked');
            noteEl.textContent = `${picked.length} / ${view.marks.length}`;

            if (picked.length === view.marks.length) {
                picking = false;
                cells.forEach((c) => { c.disabled = true; });
                post('submit', { nonce: view.nonce, answer: picked }).then((res) => {
                    if (!session) return;
                    say(res.solved ? 'Access granted' : 'Access denied', res.solved ? 'ok' : 'bad');
                    finishSoon();
                });
            }
        });
        cells.push(cell);
        grid.appendChild(cell);
    }

    bodyEl.replaceChildren(grid);
    noteEl.textContent = `${view.marks.length} numbers`;
    say('Remember the order');

    const timer = setTimeout(() => {
        cells.forEach((c) => {
            c.textContent = '';
            c.classList.remove('is-shown');
            c.disabled = false;
        });
        picking = true;
        titleEl.textContent = 'Pick in order';
        noteEl.textContent = `0 / ${view.marks.length}`;
        say('Lowest number first');
    }, view.showMs);

    session = { cancel: () => clearTimeout(timer) };
}

function startCrack(view) {
    titleEl.textContent = 'Crack the code';
    noteEl.textContent = `${view.attempts} attempts`;

    let guess = [];
    let busy = false;
    let left = view.attempts;

    const slots = el('div', 'slots');
    const history = el('div', 'history');
    const pad = el('div', 'keypad');

    const paint = () => {
        slots.replaceChildren();
        for (let i = 0; i < view.length; i += 1) {
            slots.appendChild(el('div', 'slot', guess[i] === undefined ? '' : String(guess[i])));
        }
    };

    const submit = async () => {
        if (busy || guess.length !== view.length) return;
        busy = true;

        const res = await post('guess', { nonce: view.nonce, guess });
        busy = false;
        if (!session) return;

        if (res.error) { say(res.error === 'slow down' ? 'Slow down' : 'Rejected', 'bad'); return; }

        const row = el('div', 'slots');
        res.feedback.forEach((kind, i) => row.appendChild(el('div', `slot ${kind}`, String(guess[i]))));
        history.prepend(row);

        left = res.left;
        noteEl.textContent = `${left} attempts`;
        guess = [];
        paint();

        if (res.solved) { say('Access granted', 'ok'); finishSoon(); }
        else if (res.done) { say('Locked out', 'bad'); finishSoon(); }
    };

    const press = (digit) => {
        if (busy || guess.length >= view.length) return;
        guess.push(digit);
        paint();
    };

    for (let d = 0; d <= 9; d += 1) {
        const key = el('button', 'key', String(d));
        key.type = 'button';
        key.addEventListener('click', () => press(d));
        pad.appendChild(key);
    }
    const back = el('button', 'key', '⌫');
    back.type = 'button';
    back.setAttribute('aria-label', 'delete');
    back.addEventListener('click', () => { guess.pop(); paint(); });
    const go = el('button', 'key key--go', 'OK');
    go.type = 'button';
    go.addEventListener('click', submit);
    pad.append(back, go);

    const onKey = (event) => {
        if (/^[0-9]$/.test(event.key)) press(Number(event.key));
        else if (event.key === 'Backspace') { guess.pop(); paint(); }
        else if (event.key === 'Enter') submit();
    };
    window.addEventListener('keydown', onKey);

    bodyEl.replaceChildren(slots, pad, history);
    paint();
    say('Green is right, amber is the wrong place');

    session = { cancel: () => window.removeEventListener('keydown', onKey) };
}

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data) return;

    if (data.action === 'hack:start' && data.view && typeof data.view.nonce === 'string') {
        if (session) close();
        root.hidden = false;
        if (data.view.kind === 'memory') startMemory(data.view);
        else if (data.view.kind === 'crack') startCrack(data.view);
        return;
    }

    if (data.action === 'hack:stop') {
        session?.cancel?.();
        session = null;
        root.hidden = true;
        bodyEl.replaceChildren();
    }
});

window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && session) close();
});
