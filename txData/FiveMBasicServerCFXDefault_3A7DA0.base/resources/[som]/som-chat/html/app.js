const RESOURCE = window.location.hostname.replace('cfx-nui-', '');

const entry = document.getElementById('entry');
const input = document.getElementById('input');

// Commands typed this session, so the up arrow repeats them like a terminal.
// Kept in memory only: nothing about this is a chat log.
const sent = [];
let sentIndex = -1;

function post(endpoint, body) {
    return fetch(`https://${RESOURCE}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body ?? {}),
    }).catch((err) => console.error(`${endpoint} failed:`, err));
}

function open() {
    entry.classList.remove('hidden');
    input.value = '';
    sentIndex = -1;
    input.focus();
}

function close() {
    entry.classList.add('hidden');
    input.value = '';
    input.blur();
}

function submit() {
    const raw = input.value.trim();
    if (raw) {
        sent.unshift(raw);
        // Cap the history so a long session does not grow it forever.
        if (sent.length > 40) sent.pop();
        post('send', { text: raw });
    }
    post('close');
    close();
}

// Escape is handled on the document rather than the input. If focus has
// drifted off the field for any reason the input never sees the key, and the
// only way to close would be to submit an empty line.
document.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape') return;

    event.preventDefault();
    event.stopPropagation();
    post('close');
    close();
});

input.addEventListener('keydown', (event) => {
    if (event.key === 'Enter') {
        event.preventDefault();
        submit();
        return;
    }

    if (event.key === 'ArrowUp' && sent.length) {
        event.preventDefault();
        sentIndex = Math.min(sentIndex + 1, sent.length - 1);
        input.value = sent[sentIndex];
        return;
    }

    if (event.key === 'ArrowDown' && sentIndex >= 0) {
        event.preventDefault();
        sentIndex -= 1;
        input.value = sentIndex >= 0 ? sent[sentIndex] : '';
    }
});

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || typeof data.action !== 'string') return;

    if (data.action === 'open') return open();
    if (data.action === 'close') return close();
});
