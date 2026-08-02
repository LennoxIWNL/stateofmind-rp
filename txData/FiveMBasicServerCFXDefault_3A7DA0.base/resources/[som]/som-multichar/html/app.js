const RESOURCE = window.location.hostname.replace('cfx-nui-', '');

const root = document.getElementById('root');
const rosterEl = document.getElementById('roster');
const slotCountEl = document.getElementById('slot-count');
const viewRoster = document.getElementById('view-roster');
const viewCreate = document.getElementById('view-create');
const createSlotEl = document.getElementById('create-slot');
const form = document.getElementById('create-form');
const formError = document.getElementById('form-error');
const submitBtn = document.getElementById('create-submit');
const nationalitySelect = document.getElementById('nationality');
const genderGroup = document.getElementById('gender-group');

let maxSlots = 5;
let characters = [];
let activeSlot = null;
let pendingSlot = null;
let busy = false;

async function post(endpoint, body) {
    try {
        const res = await fetch(`https://${RESOURCE}/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(body ?? {}),
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return await res.json();
    } catch (err) {
        console.error(`${endpoint} failed:`, err);
        return { success: false, error: 'Connection to server failed' };
    }
}

const money = (n) =>
    typeof n === 'number' ? `$${n.toLocaleString('en-US')}` : '$0';

function lastPlayed(value) {
    if (!value) return 'Never';
    const d = new Date(value);
    if (Number.isNaN(d.getTime())) return 'Never';

    const days = Math.floor((Date.now() - d.getTime()) / 86400000);
    if (days <= 0) return 'Today';
    if (days === 1) return 'Yesterday';
    if (days < 30) return `${days}d ago`;
    return d.toLocaleDateString('en-GB');
}

function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    // textContent throughout: names are player-supplied and must never be able
    // to inject markup into this screen.
    if (text !== undefined) node.textContent = text;
    return node;
}

function buildDetail(character) {
    const detail = el('div', 'detail');
    detail.appendChild(el('div'));

    const body = el('div', 'detail__body');

    const stats = el('div', 'detail__stats');
    for (const [label, value] of [
        ['Cash', money(character.cash)],
        ['Bank', money(character.bank)],
        ['Played', lastPlayed(character.last_played)],
    ]) {
        const stat = el('div', 'detail__stat');
        stat.appendChild(el('b', null, value));
        stat.appendChild(document.createTextNode(label));
        stats.appendChild(stat);
    }

    const actions = el('div', 'detail__actions');

    const play = el('button', 'btn btn--primary', 'Play');
    play.type = 'button';
    play.addEventListener('click', (e) => {
        e.stopPropagation();
        selectCharacter(character.citizenid, play);
    });

    const del = el('button', 'btn btn--danger', 'Delete');
    del.type = 'button';
    del.addEventListener('click', (e) => {
        e.stopPropagation();
        deleteCharacter(character, del);
    });

    actions.append(play, del);
    body.append(stats, actions);
    detail.appendChild(body);
    return detail;
}

function renderRoster() {
    const frag = document.createDocumentFragment();
    const bySlot = new Map(characters.map((c) => [Number(c.slot), c]));

    slotCountEl.textContent = `${characters.length}/${maxSlots}`;

    for (let i = 1; i <= maxSlots; i++) {
        const character = bySlot.get(i);

        const row = el('button', 'slot');
        row.type = 'button';
        row.setAttribute('role', 'listitem');
        row.dataset.slot = String(i);

        row.appendChild(el('span', 'slot__index', String(i).padStart(2, '0')));

        const body = el('div', 'slot__body');
        if (character) {
            body.appendChild(el('div', 'slot__name', `${character.firstname} ${character.lastname}`));
            body.appendChild(el('div', 'slot__sub', character.job || 'unemployed'));
        } else {
            row.classList.add('slot--empty');
            body.appendChild(el('div', 'slot__name', 'Empty slot'));
            body.appendChild(el('div', 'slot__sub', 'Create a character'));
        }
        row.appendChild(body);

        if (character) {
            if (activeSlot === i) row.classList.add('is-active');
            row.addEventListener('click', () => {
                activeSlot = activeSlot === i ? null : i;
                renderRoster();
            });
        } else {
            row.addEventListener('click', () => openCreate(i));
        }

        frag.appendChild(row);

        if (character && activeSlot === i) frag.appendChild(buildDetail(character));
    }

    rosterEl.replaceChildren(frag);
}

async function selectCharacter(citizenid, button) {
    if (busy) return;
    busy = true;
    button.disabled = true;
    button.textContent = 'Loading';

    const result = await post('selectCharacter', { citizenid });
    if (!result.success) {
        busy = false;
        button.disabled = false;
        button.textContent = 'Play';
        formError.textContent = '';
        flash(result.error || 'Could not load that character');
    }
    // On success the game fades out and Lua closes the UI, so there is
    // deliberately nothing to do here.
}

async function deleteCharacter(character, button) {
    if (busy) return;

    // Two-step confirm rather than a modal. The second click commits.
    if (button.dataset.confirm !== '1') {
        button.dataset.confirm = '1';
        button.classList.add('is-confirming');
        button.textContent = 'Confirm';
        setTimeout(() => {
            if (button.isConnected && button.dataset.confirm === '1') {
                button.dataset.confirm = '0';
                button.classList.remove('is-confirming');
                button.textContent = 'Delete';
            }
        }, 3000);
        return;
    }

    busy = true;
    button.disabled = true;
    const result = await post('deleteCharacter', { citizenid: character.citizenid });
    busy = false;

    if (!result.success) {
        button.disabled = false;
        button.dataset.confirm = '0';
        button.classList.remove('is-confirming');
        button.textContent = 'Delete';
        flash(result.error || 'Could not delete that character');
    } else {
        activeSlot = null;
    }
}

function flash(message) {
    slotCountEl.textContent = message;
    setTimeout(() => { slotCountEl.textContent = `${characters.length}/${maxSlots}`; }, 2600);
}

function openCreate(slot) {
    pendingSlot = slot;
    formError.textContent = '';
    form.reset();
    genderGroup.dataset.value = '0';
    createSlotEl.textContent = `Slot ${String(slot).padStart(2, '0')}`;

    viewRoster.classList.add('hidden');
    viewCreate.classList.remove('hidden');
    form.elements.firstname.focus();
    post('previewGender', { gender: 0 });
}

function closeCreate() {
    pendingSlot = null;
    viewCreate.classList.add('hidden');
    viewRoster.classList.remove('hidden');
    renderRoster();
}

form.addEventListener('submit', async (event) => {
    event.preventDefault();
    if (busy || pendingSlot === null) return;

    const data = new FormData(form);
    const payload = {
        slot: pendingSlot,
        firstname: (data.get('firstname') || '').trim(),
        lastname: (data.get('lastname') || '').trim(),
        dob: data.get('dob'),
        gender: Number(data.get('gender')),
        nationality: data.get('nationality'),
    };

    // Client-side checks are for fast feedback only. som-core re-validates
    // every one of these and is the actual authority.
    if (payload.firstname.length < 2 || payload.lastname.length < 2) {
        formError.textContent = 'First and last name must be at least 2 characters.';
        return;
    }
    if (!payload.dob) {
        formError.textContent = 'Choose a date of birth.';
        return;
    }

    busy = true;
    submitBtn.disabled = true;
    formError.textContent = '';

    const result = await post('createCharacter', payload);

    busy = false;
    submitBtn.disabled = false;

    if (result.success) {
        closeCreate();
    } else {
        formError.textContent = result.error || 'Could not create that character.';
    }
});

form.addEventListener('change', (event) => {
    if (event.target.name !== 'gender') return;
    genderGroup.dataset.value = event.target.value;
    post('previewGender', { gender: Number(event.target.value) });
});

form.querySelector('[data-action="back"]').addEventListener('click', closeCreate);

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        if (!viewCreate.classList.contains('hidden')) closeCreate();
        return;
    }

    if (!viewCreate.classList.contains('hidden')) return;

    const rows = [...rosterEl.querySelectorAll('.slot')];
    if (!rows.length) return;

    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
        event.preventDefault();
        const current = rows.findIndex((r) => Number(r.dataset.slot) === activeSlot);
        const step = event.key === 'ArrowDown' ? 1 : -1;
        const next = current === -1
            ? (step === 1 ? 0 : rows.length - 1)
            : (current + step + rows.length) % rows.length;

        const slot = Number(rows[next].dataset.slot);
        const hasCharacter = characters.some((c) => Number(c.slot) === slot);
        activeSlot = hasCharacter ? slot : null;
        if (!hasCharacter) rows[next].focus();
        renderRoster();
        return;
    }

    if (event.key === 'Enter' && activeSlot !== null) {
        const play = rosterEl.querySelector('.detail__actions .btn--primary');
        if (play) play.click();
    }
});

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || typeof data.action !== 'string') return;

    if (data.action === 'open') {
        characters = Array.isArray(data.characters) ? data.characters : [];
        maxSlots = Number(data.maxSlots) || 5;
        activeSlot = characters.length ? Number(characters[0].slot) : null;
        busy = false;

        const options = Array.isArray(data.nationalities) ? data.nationalities : ['American'];
        nationalitySelect.replaceChildren(
            ...options.map((n) => {
                const opt = document.createElement('option');
                opt.value = n;
                opt.textContent = n;
                return opt;
            })
        );

        viewCreate.classList.add('hidden');
        viewRoster.classList.remove('hidden');
        renderRoster();
        root.classList.remove('hidden');
        return;
    }

    if (data.action === 'refresh') {
        characters = Array.isArray(data.characters) ? data.characters : [];
        renderRoster();
        return;
    }

    if (data.action === 'close') {
        root.classList.add('hidden');
        busy = false;
    }
});
