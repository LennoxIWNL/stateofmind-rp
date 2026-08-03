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
                // The ped in the scene follows whoever is highlighted, so the
                // roster and the character on screen never disagree.
                if (activeSlot === i) post('previewGender', { gender: Number(character.gender) || 0 });
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

const MIN_AGE = 18;
const MAX_AGE = 90;

// Today's date shifted back by N years, as YYYY-MM-DD.
function dateYearsAgo(years) {
    const d = new Date();
    d.setFullYear(d.getFullYear() - years);
    // toISOString would apply the timezone offset and can roll the date back a
    // day, so build it from the local parts instead.
    const pad = (n) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

function openCreate(slot) {
    pendingSlot = slot;
    formError.textContent = '';
    form.reset();
    genderGroup.dataset.value = '0';

    // Default to exactly the minimum age rather than today, so the picker
    // opens on a plausible birth year instead of one that is never valid.
    // min and max bound it; som-core re-checks the age server side regardless.
    const dob = form.elements.dob;
    dob.value = dateYearsAgo(MIN_AGE);
    dob.max = dateYearsAgo(MIN_AGE);
    dob.min = dateYearsAgo(MAX_AGE);
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
    if (payload.dob > dateYearsAgo(MIN_AGE)) {
        formError.textContent = `Characters must be at least ${MIN_AGE} years old.`;
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

// --- Scene tuning -------------------------------------------------------
//
// The character screen holds NUI focus, so the game never sees the keyboard
// and Lua keybinds cannot fire. The browser DOES receive every keystroke, so
// tuning input is handled here and forwarded to Lua.
//
// Only arrow keys, PageUp/PageDown and a few letters are used: no numpad, since
// plenty of keyboards do not have one.

let tuning = false;

// dx is screen-right, dy is away from the camera. Lua converts these into
// world axes using the camera's facing, so the controls stay intuitive
// regardless of which way the scene points.
//
// Height has letter aliases because PageUp/PageDown are not delivered
// reliably inside the CEF layer, and plenty of keyboards make them awkward.
const TUNE_KEYS = {
    ArrowLeft:  { dx: -1, dy: 0, dz: 0 },
    ArrowRight: { dx: 1, dy: 0, dz: 0 },
    ArrowUp:    { dx: 0, dy: 1, dz: 0 },
    ArrowDown:  { dx: 0, dy: -1, dz: 0 },
    PageUp:     { dx: 0, dy: 0, dz: 1 },
    PageDown:   { dx: 0, dy: 0, dz: -1 },
    z:          { dx: 0, dy: 0, dz: 1 },
    Z:          { dx: 0, dy: 0, dz: 1 },
    x:          { dx: 0, dy: 0, dz: -1 },
    X:          { dx: 0, dy: 0, dz: -1 },
};

async function handleTuningKey(event) {
    const key = event.key;

    if (key === 'F10') {
        event.preventDefault();
        const res = await post('tuningToggle');
        tuning = !!(res && res.active);
        // Drop focus out of any text field, or nudges would type into it.
        if (tuning && document.activeElement) document.activeElement.blur();
        return true;
    }

    if (key === 'F11') {
        event.preventDefault();
        post('tuningCoords');
        return true;
    }

    if (!tuning) return false;

    const move = TUNE_KEYS[key];
    if (move) {
        event.preventDefault();
        post('tuningNudge', move);
        return true;
    }

    // Zoom. '=' and '+' narrow the field of view, which reads as moving closer;
    // '-' widens it. Clamped in Lua.
    if (key === '=' || key === '+') {
        event.preventDefault();
        post('tuningFov', { dir: -1 });
        return true;
    }
    if (key === '-' || key === '_') {
        event.preventDefault();
        post('tuningFov', { dir: 1 });
        return true;
    }

    // Aim height on the character. Lowering it tilts the shot down and brings
    // more of the body into frame.
    if (key === ',' || key === '<') {
        event.preventDefault();
        post('tuningLook', { dir: -1 });
        return true;
    }
    if (key === '.' || key === '>') {
        event.preventDefault();
        post('tuningLook', { dir: 1 });
        return true;
    }

    const lower = key.toLowerCase();
    if (lower === 'q' || lower === 'e') {
        event.preventDefault();
        post('tuningRotate', { dir: lower === 'q' ? -1 : 1 });
        return true;
    }
    if (lower === 'r') {
        event.preventDefault();
        post('tuningCycle');
        return true;
    }
    if (lower === 'p') {
        event.preventDefault();
        post('tuningPrint');
        return true;
    }

    return false;
}

document.addEventListener('keydown', (event) => {
    // Tuning takes the keyboard first, so roster navigation does not also fire
    // and drift the camera while moving between characters.
    handleTuningKey(event).then((handled) => {
        if (handled) return;
        handleUiKey(event);
    });
});

function handleUiKey(event) {
    if (tuning) return;

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
}

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
