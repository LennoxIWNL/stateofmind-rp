const RESOURCE = window.location.hostname.replace('cfx-nui-', '');

const chat = document.getElementById('chat');
const log = document.getElementById('log');
const entry = document.getElementById('entry');
const input = document.getElementById('input');

const FADE_AFTER = 12000;
const MAX_LINES = 60;

// Commands typed this session, so the up arrow works like a terminal.
const sent = [];
let sentIndex = -1;

function post(endpoint, body) {
    return fetch(`https://${RESOURCE}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body ?? {}),
    }).catch((err) => console.error(`${endpoint} failed:`, err));
}

function render(message) {
    const line = document.createElement('div');
    line.className = `line line--${message.kind || 'system'}`;

    if (message.author) {
        const author = document.createElement('span');
        author.className = 'line__author';
        // textContent throughout: chat is player-authored by definition and
        // must never be able to inject markup.
        author.textContent = message.author;
        line.appendChild(author);
    }

    const text = document.createElement('span');
    text.textContent = message.text || '';
    if (message.colour) text.style.color = message.colour;
    line.appendChild(text);

    log.appendChild(line);
    while (log.children.length > MAX_LINES) log.removeChild(log.firstElementChild);

    // Fade once it has been on screen a while. Chat that never fades becomes
    // permanent clutter, but it comes back whenever chat is opened.
    setTimeout(() => line.classList.add('is-faded'), FADE_AFTER);
}

function open(history) {
    chat.classList.add('is-open');
    entry.classList.remove('hidden');

    if (Array.isArray(history) && !log.children.length) {
        history.forEach(render);
    }

    input.value = '';
    sentIndex = -1;
    input.focus();
}

function close() {
    chat.classList.remove('is-open');
    entry.classList.add('hidden');
    input.value = '';
    input.blur();
}

input.addEventListener('keydown', (event) => {
    if (event.key === 'Enter') {
        event.preventDefault();
        const text = input.value.trim();
        if (text) {
            sent.unshift(text);
            post('send', { text });
        }
        post('close');
        close();
        return;
    }

    if (event.key === 'Escape') {
        event.preventDefault();
        post('close');
        close();
        return;
    }

    // Terminal-style history, which matters most for repeating a command.
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

    if (data.action === 'open') return open(data.history);
    if (data.action === 'close') return close();
    if (data.action === 'message' && data.message) return render(data.message);
});
