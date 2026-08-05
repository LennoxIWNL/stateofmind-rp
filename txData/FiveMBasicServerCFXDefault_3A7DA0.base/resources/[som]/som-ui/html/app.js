const container = document.getElementById('notifications');

const ICONS = {
    success: '✓',
    error: '✕',
    warning: '⚠',
    info: 'ℹ',
};

const VALID = Object.keys(ICONS);
const MAX_VISIBLE = 5;

/* Live notifications, keyed by what they say.
 *
 * An identical notification arriving again does not stack a second card: it
 * increments a count on the one already up and restarts its timer. Five refused
 * clicks used to push everything else off the screen, which is exactly when the
 * message you actually needed was the one evicted. */
const live = new Map();

function bump(entry, duration) {
    entry.count += 1;

    let badge = entry.el.querySelector('.notification__count');

    if (!badge) {
        badge = document.createElement('span');
        badge.className = 'notification__count';
        entry.el.appendChild(badge);
    }

    badge.textContent = entry.count;

    // Restart the count animation, which needs the class removed and a reflow
    // or a second identical message never replays it.
    badge.classList.remove('is-bumped');
    void badge.offsetWidth;
    badge.classList.add('is-bumped');

    // The timer restarts too, so a repeating message stays up while it is still
    // repeating rather than expiring on the first one's clock.
    clearTimeout(entry.timer);
    entry.timer = setTimeout(entry.remove, duration);

    const bar = entry.el.querySelector('.notification__timer');

    if (bar) {
        bar.style.animation = 'none';
        void bar.offsetWidth;
        bar.style.animation = '';
        bar.style.animationDuration = `${duration}ms`;
    }
}

function render(message, type, duration) {
    const kind = VALID.includes(type) ? type : 'info';

    // Same words and same severity means the same event happening again.
    const key = `${kind}:${message}`;
    const existing = live.get(key);

    if (existing) {
        bump(existing, duration);
        return;
    }

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

    // Cap the stack so a burst of DIFFERENT notifications cannot fill the
    // screen. Repeats no longer reach here at all, so this is now the rare case
    // rather than the common one.
    while (container.children.length > MAX_VISIBLE) {
        const evicted = container.firstElementChild;
        // Forget the evicted one, or its key would keep bumping a card that is
        // no longer on screen and nothing would ever be drawn for it again.
        for (const [k, v] of live) {
            if (v.el === evicted) {
                clearTimeout(v.timer);
                live.delete(k);
                break;
            }
        }
        container.removeChild(evicted);
    }

    const remove = () => {
        live.delete(key);
        if (!el.isConnected) return;
        el.classList.add('leaving');
        el.addEventListener('animationend', () => el.remove(), { once: true });
    };

    live.set(key, { el, count: 1, remove, timer: setTimeout(remove, duration) });
}

// ---------------------------------------------------------------------------
// Progress
//
// Render only. Every decision (whether it completed, whether it was cancelled,
// the animation, the controls) is made in Lua. This draws what it is told and
// reports nothing back, so there is no NUI callback to trust.
// ---------------------------------------------------------------------------

const progress = document.getElementById('progress');
const progressLabel = document.getElementById('progress-label');
const progressFill = document.getElementById('progress-fill');
const progressCancel = document.getElementById('progress-cancel');

let progressLeaveTimer = null;
let progressDeadman = null;

// Grace before the bar removes itself with no instruction to.
//
// The Lua side normally sends progress:stop. It cannot if the calling resource
// is restarted mid-action, and the fill holds at 100% forever, so a full card
// would sit on screen until som-ui itself was restarted. This is the backstop
// for that, not the usual path.
const PROGRESS_DEADMAN_GRACE = 3000;

function progressStart(label, duration, canCancel) {
    clearTimeout(progressLeaveTimer);
    clearTimeout(progressDeadman);

    progressDeadman = setTimeout(
        () => progressStop(true),
        duration + PROGRESS_DEADMAN_GRACE
    );

    progress.className = 'progress';
    progress.hidden = false;

    progressLabel.textContent = typeof label === 'string' ? label : '';
    progressCancel.classList.toggle('is-hidden', canCancel !== true);

    // Restarting the animation needs the class removed and the element
    // reflowed, or a second progress of the same duration never replays.
    progressFill.classList.remove('is-running');
    void progressFill.offsetWidth;

    progressFill.style.animationDuration = `${duration}ms`;
    progressFill.classList.add('is-running');
}

function progressStop(cancelled) {
    clearTimeout(progressDeadman);

    if (progress.hidden) return;

    progress.classList.add(cancelled ? 'progress--cancelled' : 'progress--done');
    progress.classList.add('progress--leaving');

    progressLeaveTimer = setTimeout(() => {
        progress.hidden = true;
        progress.className = 'progress';
        progressFill.classList.remove('is-running');
    }, 180);
}

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data) return;

    if (data.action === 'notify') {
        if (typeof data.message !== 'string') return;
        const duration = typeof data.duration === 'number' ? data.duration : 4000;
        render(data.message, data.type, duration);
        return;
    }

    if (data.action === 'progress:start') {
        const duration = typeof data.duration === 'number' ? data.duration : 1000;
        progressStart(data.label, duration, data.canCancel);
        return;
    }

    if (data.action === 'progress:stop') {
        progressStop(data.cancelled === true);
    }
});
