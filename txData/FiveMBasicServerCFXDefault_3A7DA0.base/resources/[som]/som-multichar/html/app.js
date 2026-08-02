const RESOURCE = window.location.hostname.replace('cfx-nui-', '');

const root = document.getElementById('root');
const slotsEl = document.getElementById('slots');
const subtitle = document.getElementById('subtitle');
const viewSlots = document.getElementById('view-slots');
const viewCreate = document.getElementById('view-create');
const form = document.getElementById('create-form');
const formError = document.getElementById('form-error');
const nationalitySelect = document.getElementById('nationality');

let maxSlots = 5;
let characters = [];
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

function money(n) {
    return typeof n === 'number' ? `$${n.toLocaleString('en-US')}` : '$0';
}

function lastPlayed(value) {
    if (!value) return 'Never played';
    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? 'Never played' : `Last played ${d.toLocaleDateString('en-GB')}`;
}

function renderSlots() {
    const frag = document.createDocumentFragment();
    const bySlot = new Map(characters.map((c) => [Number(c.slot), c]));

    for (let i = 1; i <= maxSlots; i++) {
        const character = bySlot.get(i);
        const card = document.createElement('div');
        card.className = 'slot';

        if (!character) {
            card.classList.add('slot--empty');
            card.tabIndex = 0;
            card.setAttribute('role', 'button');

            const plus = document.createElement('span');
            plus.className = 'slot__plus';
            plus.textContent = '+';

            const label = document.createElement('span');
            label.textContent = 'Create character';

            card.append(plus, label);
            const open = () => openCreate(i);
            card.addEventListener('click', open);
            card.addEventListener('keydown', (e) => {
                if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); open(); }
            });
            frag.appendChild(card);
            continue;
        }

        const index = document.createElement('span');
        index.className = 'slot__index';
        index.textContent = `Slot ${i}`;

        const name = document.createElement('span');
        name.className = 'slot__name';
        // textContent throughout: names are player-supplied and must never
        // be able to inject markup into this screen.
        name.textContent = `${character.firstname} ${character.lastname}`;

        const job = document.createElement('span');
        job.className = 'slot__job';
        job.textContent = character.job || 'unemployed';

        const meta = document.createElement('div');
        meta.className = 'slot__meta';
        const cash = document.createElement('span');
        cash.textContent = `Cash ${money(character.cash)}`;
        const bank = document.createElement('span');
        bank.textContent = `Bank ${money(character.bank)}`;
        const played = document.createElement('span');
        played.textContent = lastPlayed(character.last_played);
        meta.append(cash, bank, played);

        const actions = document.createElement('div');
        actions.className = 'slot__actions';

        const play = document.createElement('button');
        play.type = 'button';
        play.className = 'som-btn som-btn--primary';
        play.textContent = 'Play';
        play.addEventListener('click', () => selectCharacter(character.citizenid, play));

        const del = document.createElement('button');
        del.type = 'button';
        del.className = 'som-btn som-btn--danger';
        del.textContent = 'Delete';
        del.addEventListener('click', () => deleteCharacter(character, del));

        actions.append(play, del);
        card.append(index, name, job, meta, actions);
        frag.appendChild(card);
    }

    slotsEl.replaceChildren(frag);
}

async function selectCharacter(citizenid, button) {
    if (busy) return;
    busy = true;
    button.textContent = 'Loading...';

    const result = await post('selectCharacter', { citizenid });
    if (!result.success) {
        busy = false;
        button.textContent = 'Play';
        subtitle.textContent = result.error || 'Could not load that character';
    }
    // On success the game fades out and the UI is closed from Lua, so there is
    // deliberately nothing to do here.
}

async function deleteCharacter(character, button) {
    if (busy) return;

    // Two-step confirm rather than a modal: the second click is the commit.
    if (button.dataset.confirm !== '1') {
        button.dataset.confirm = '1';
        button.textContent = 'Sure?';
        setTimeout(() => {
            if (button.isConnected && button.dataset.confirm === '1') {
                button.dataset.confirm = '0';
                button.textContent = 'Delete';
            }
        }, 3000);
        return;
    }

    busy = true;
    button.textContent = '...';
    const result = await post('deleteCharacter', { citizenid: character.citizenid });
    busy = false;

    if (!result.success) {
        subtitle.textContent = result.error || 'Could not delete that character';
        button.dataset.confirm = '0';
        button.textContent = 'Delete';
    }
}

function openCreate(slot) {
    pendingSlot = slot;
    formError.textContent = '';
    form.reset();
    viewSlots.classList.add('hidden');
    viewCreate.classList.remove('hidden');
    subtitle.textContent = `Creating character in slot ${slot}`;
    form.elements.firstname.focus();
    post('previewGender', { gender: 0 });
}

function closeCreate() {
    pendingSlot = null;
    viewCreate.classList.add('hidden');
    viewSlots.classList.remove('hidden');
    subtitle.textContent = 'Select a character';
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
        formError.textContent = 'Please choose a date of birth.';
        return;
    }

    busy = true;
    formError.textContent = '';
    const result = await post('createCharacter', payload);
    busy = false;

    if (result.success) {
        closeCreate();
    } else {
        formError.textContent = result.error || 'Could not create that character.';
    }
});

form.addEventListener('change', (event) => {
    if (event.target.name === 'gender') {
        post('previewGender', { gender: Number(event.target.value) });
    }
});

form.querySelector('[data-action="back"]').addEventListener('click', closeCreate);

document.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape') return;
    if (!viewCreate.classList.contains('hidden')) closeCreate();
});

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || typeof data.action !== 'string') return;

    if (data.action === 'open') {
        characters = Array.isArray(data.characters) ? data.characters : [];
        maxSlots = Number(data.maxSlots) || 5;

        const options = Array.isArray(data.nationalities) ? data.nationalities : ['American'];
        nationalitySelect.replaceChildren(
            ...options.map((n) => {
                const opt = document.createElement('option');
                opt.value = n;
                opt.textContent = n;
                return opt;
            })
        );

        busy = false;
        subtitle.textContent = 'Select a character';
        closeCreate();
        renderSlots();
        root.classList.remove('hidden');
        return;
    }

    if (data.action === 'refresh') {
        characters = Array.isArray(data.characters) ? data.characters : [];
        renderSlots();
        return;
    }

    if (data.action === 'close') {
        root.classList.add('hidden');
        busy = false;
    }
});
