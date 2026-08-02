const container = document.getElementById('notifications');

const ICONS = {
    success: '✓',
    error: '✕',
    warning: '⚠',
    info: 'ℹ',
};

const VALID = Object.keys(ICONS);
const MAX_VISIBLE = 5;

function render(message, type, duration) {
    const kind = VALID.includes(type) ? type : 'info';

    const el = document.createElement('div');
    el.className = `notification notification--${kind}`;
    el.style.position = 'relative';

    const icon = document.createElement('span');
    icon.className = 'notification__icon';
    icon.textContent = ICONS[kind];

    const body = document.createElement('span');
    body.className = 'notification__body';
    // textContent, never innerHTML: notification text can originate from a
    // config, another resource, or a player name and must not inject markup.
    body.textContent = message;

    const timer = document.createElement('div');
    timer.className = 'notification__timer';
    timer.style.animationDuration = `${duration}ms`;

    el.append(icon, body, timer);
    container.appendChild(el);

    // Cap the stack so a burst of notifications cannot fill the screen.
    while (container.children.length > MAX_VISIBLE) {
        container.removeChild(container.firstElementChild);
    }

    const remove = () => {
        if (!el.isConnected) return;
        el.classList.add('leaving');
        el.addEventListener('animationend', () => el.remove(), { once: true });
    };

    setTimeout(remove, duration);
}

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || data.action !== 'notify') return;
    if (typeof data.message !== 'string') return;

    const duration = typeof data.duration === 'number' ? data.duration : 4000;
    render(data.message, data.type, duration);
});
