const root = document.getElementById('root');
const fieldsEl = document.getElementById('fields');
const photoEl = document.getElementById('photo');

const LABELS = {
    name: 'Name',
    dob: 'Date of birth',
    sex: 'Sex',
    nationality: 'Nationality',
    citizenid: 'Citizen ID',
    issued: 'Issued',
};

// citizenid reads as a serial rather than a word, so it gets the mono face.
const MONO = new Set(['citizenid', 'dob', 'issued']);

function el(tag, cls, text) {
    const node = document.createElement(tag);
    if (cls) node.className = cls;
    // textContent throughout: every value here is player-authored.
    if (text !== undefined) node.textContent = text;
    return node;
}

function formatDate(value) {
    const d = new Date(value);
    if (Number.isNaN(d.getTime())) return String(value);
    return d.toLocaleDateString('en-GB', { day: '2-digit', month: '2-digit', year: 'numeric' });
}

function renderPhoto(url) {
    const mark = photoEl.querySelector('.photo__mark');
    const existing = photoEl.querySelector('img');
    if (existing) existing.remove();

    if (!url) {
        if (mark) mark.classList.remove('hidden');
        return;
    }

    const img = document.createElement('img');
    img.alt = '';
    // A broken URL must fall back to the silhouette rather than leaving a
    // torn image icon on an official-looking document.
    img.addEventListener('error', () => {
        img.remove();
        if (mark) mark.classList.remove('hidden');
    });
    img.addEventListener('load', () => {
        if (mark) mark.classList.add('hidden');
    });

    img.src = url;
    photoEl.appendChild(img);
}

function renderStatus(status) {
    const node = document.getElementById('card-status');

    if (!status) {
        node.classList.add('hidden');
        return;
    }

    const kind = status === 'VALID' ? 'valid' : (status === 'REVOKED' ? 'revoked' : 'none');
    node.className = `card__status card__status--${kind}`;
    node.textContent = status;
}

function render(card) {
    root.style.setProperty('--accent', card.accent || '#ff1493');

    document.getElementById('card-title').textContent = card.label || 'Document';
    document.getElementById('card-issuer').textContent = card.issuer || '';

    const frag = document.createDocumentFragment();
    (card.fields || []).forEach((key) => {
        const raw = card[key];
        if (raw === undefined || raw === null || raw === '') return;

        const value = (key === 'dob' || key === 'issued') ? formatDate(raw) : String(raw);

        frag.appendChild(el('dt', null, LABELS[key] || key));
        frag.appendChild(el('dd', MONO.has(key) ? 'is-mono' : null, value));
    });
    fieldsEl.replaceChildren(frag);

    renderPhoto(card.photo);
    renderStatus(card.status);
}

let leaveTimer = null;

window.addEventListener('message', (event) => {
    const msg = event.data;
    if (!msg || typeof msg.action !== 'string') return;

    if (msg.action === 'show') {
        clearTimeout(leaveTimer);
        render(msg.card || {});
        root.classList.remove('hidden', 'is-leaving');
        return;
    }

    if (msg.action === 'hide') {
        root.classList.add('is-leaving');
        leaveTimer = setTimeout(() => root.classList.add('hidden'), 240);
    }
});
