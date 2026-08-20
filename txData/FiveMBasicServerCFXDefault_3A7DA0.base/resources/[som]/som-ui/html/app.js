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

// ---------------------------------------------------------------------------
// Context menus
//
// Render only, exactly like the progress bar. This page decides nothing about
// what a row means: it draws what it is told and posts back the row id it was
// given. The resource that owns the menu resolves that id against the real
// options table, re-checks that the row is selectable, and runs the callback.
//
// So an edited copy of this file buys a player rows it can click and a server
// that ignores them.
// ---------------------------------------------------------------------------

const RESOURCE = window.location.hostname.replace('cfx-nui-', '');

const context = document.getElementById('context');
const contextTitle = document.getElementById('context-title');
const contextOptions = document.getElementById('context-options');
const contextBack = document.getElementById('context-back');
const contextClose = document.getElementById('context-close');
const contextBackdrop = document.getElementById('context-backdrop');

let contextCanClose = true;

function postNui(endpoint, body) {
    return fetch(`https://${RESOURCE}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body ?? {}),
    }).catch(() => {});
}

function ctxEl(tag, cls, text) {
    const node = document.createElement(tag);
    if (cls) node.className = cls;
    // textContent, never innerHTML. Menu titles carry player names, plate
    // numbers and typed fine reasons.
    if (text !== undefined && text !== null) node.textContent = text;
    return node;
}

function contextRow(option) {
    const selectable = option.selectable === true;

    // A button when it does something, a div when it does not. Read-only rows
    // are a real case (the ID check and the plate lookup are facts with nothing
    // to press) and rendering them as buttons that ignore the click is how a
    // menu starts feeling broken.
    const row = ctxEl(selectable ? 'button' : 'div', 'ctx');
    if (selectable) row.type = 'button';

    row.classList.add(selectable ? 'ctx--action' : 'ctx--info');
    if (option.disabled) row.classList.add('is-disabled');

    // The icon NAME, not a glyph. SOM has no licensed icon set yet, and the
    // accent rule below stands in for one. When a set lands this attribute is
    // the hook: one rule here lights every menu on the server at once.
    if (option.icon) row.dataset.icon = option.icon;

    const rule = ctxEl('span', 'ctx__rule');
    if (option.iconColor) rule.style.background = option.iconColor;
    row.append(rule);

    const body = ctxEl('div', 'ctx__body');
    body.append(ctxEl('span', 'ctx__title', option.title || ''));

    if (option.description) {
        body.append(ctxEl('span', 'ctx__desc', option.description));
    }

    if (Array.isArray(option.metadata) && option.metadata.length) {
        const meta = ctxEl('div', 'ctx__meta');

        option.metadata.forEach((entry) => {
            const line = ctxEl('span', 'ctx__metaline');
            line.append(ctxEl('span', 'ctx__metalabel', entry.label || ''));
            if (entry.value !== undefined && entry.value !== null) {
                line.append(ctxEl('span', 'ctx__metavalue', entry.value));
            }
            meta.append(line);
        });

        body.append(meta);
    }

    if (typeof option.progress === 'number') {
        const track = ctxEl('div', 'ctx__track');
        const fill = ctxEl('div', 'ctx__fill');
        fill.style.width = `${Math.max(0, Math.min(100, option.progress))}%`;
        track.append(fill);
        body.append(track);
    }

    row.append(body);

    if (option.image) {
        const img = document.createElement('img');
        img.className = 'ctx__image';
        img.src = option.image;
        img.alt = '';
        img.addEventListener('error', () => img.remove());
        row.append(img);
    }

    if (option.arrow) row.append(ctxEl('span', 'ctx__arrow', '›'));

    if (selectable && !option.disabled) {
        row.addEventListener('click', () => postNui('contextSelect', { id: option.id }));
    }

    return row;
}

function contextShow(data) {
    const d = data || {};

    contextCanClose = d.canClose !== false;

    contextTitle.textContent = d.title || '';
    contextBack.hidden = d.back !== true;
    contextClose.hidden = !contextCanClose;

    const frag = document.createDocumentFragment();
    const options = Array.isArray(d.options) ? d.options : [];

    options.forEach((option) => frag.append(contextRow(option)));

    if (!options.length) {
        frag.append(ctxEl('p', 'ctx__empty', 'Nothing here.'));
    }

    contextOptions.replaceChildren(frag);
    // Reset between menus, or a submenu opens already scrolled to wherever the
    // parent was.
    contextOptions.scrollTop = 0;

    // Replay the entrance on every show, including a submenu replacing its
    // parent, so moving between menus reads as movement.
    context.hidden = false;
    context.classList.remove('is-open');
    void context.offsetWidth;
    context.classList.add('is-open');
}

function contextHide() {
    context.hidden = true;
    context.classList.remove('is-open');
    contextOptions.replaceChildren();
}

contextClose.addEventListener('click', () => postNui('contextClose'));
contextBack.addEventListener('click', () => postNui('contextBack'));

// Clicking off the menu closes it, which is what every menu on every other
// server does and what a player will try first.
contextBackdrop.addEventListener('click', () => postNui('contextClose'));

document.addEventListener('keydown', (event) => {
    // The skill check owns the keyboard while it is up, and it is never up at
    // the same time as a menu: it takes focus without a cursor, a menu takes
    // focus with one, and the Lua side refuses a second check.
    if (!skill.hidden) {
        if (event.repeat) return;
        skillPress(String(event.key).toLowerCase());
        return;
    }

    if (context.hidden) return;

    if (event.key === 'Escape') {
        // Posted even when canClose is false. The Lua side refuses it there,
        // because the rule belongs with the menu and not with the page.
        postNui('contextClose');
        return;
    }

    if (event.key === 'Backspace' && !contextBack.hidden) {
        postNui('contextBack');
    }
});


// ---------------------------------------------------------------------------
// Skill check
//
// Render and input only, like everything else on this page. The Lua side holds
// the token and decides when a check is over; this reports a hit or a miss and
// nothing else. It is a client side minigame either way, and no server action
// rests on the answer.
//
// The needle sweeps clockwise from the top. A round is passed by pressing the
// round's key while the needle is inside the arc, and failed by pressing the
// wrong key, pressing outside the arc, or letting the needle run past the arc.
// That is ox_lib's model, kept deliberately: the muscle memory is worth more
// than an improvement here would be.
// ---------------------------------------------------------------------------

const skill = document.getElementById('skillcheck');
const skillArea = document.getElementById('skill-area');
const skillNeedle = document.getElementById('skill-needle');
const skillKey = document.getElementById('skill-key');
const skillRounds = document.getElementById('skill-rounds');

// r=52 in the markup. Hard-coded rather than measured: getTotalLength on a
// hidden SVG element returns 0 in this CEF build, which draws no arc at all.
const SKILL_CIRCUMFERENCE = 2 * Math.PI * 52;

// Degrees per second at speedMultiplier 1, so one revolution is 1.8s on easy.
// The Lua side sizes its deadman timer off this same number.
const SKILL_BASE_SPEED = 200;

// How long the hit or miss colour stays before the next round or the exit.
const SKILL_FLASH = 220;

let skillToken = null;
let skillState = null;
let skillFrame = null;
let skillFlashTimer = null;
// True between reporting a result and the hit or miss colour finishing. The
// Lua side sends skillcheck:hide as soon as it has the result, which arrives
// well inside that window, so without this the flash is never seen.
let skillFlashing = false;

function skillStopLoop() {
    if (skillFrame !== null) {
        cancelAnimationFrame(skillFrame);
        skillFrame = null;
    }
}

function skillDraw() {
    const s = skillState;
    if (!s) return;

    skillNeedle.setAttribute('transform', `rotate(${s.angle} 60 60)`);
}

function skillRender(round, index, total) {
    const arc = (round.areaSize / 360) * SKILL_CIRCUMFERENCE;

    skillArea.setAttribute('stroke-dasharray', `${arc} ${SKILL_CIRCUMFERENCE - arc}`);
    // -90 puts zero at the top, where the needle starts.
    skillArea.setAttribute('transform', `rotate(${round.areaStart - 90} 60 60)`);

    skillKey.textContent = round.input.toUpperCase();
    // A single round says nothing rather than "1/1", which is noise.
    skillRounds.textContent = total > 1 ? `${index + 1} / ${total}` : '';

    skillDraw();
}

function skillFinish(success) {
    skillStopLoop();

    const token = skillToken;
    skillState = null;
    skillToken = null;

    skill.classList.remove('is-hit', 'is-miss');
    skill.classList.add(success ? 'is-hit' : 'is-miss');

    clearTimeout(skillFlashTimer);
    skillFlashing = true;
    skillFlashTimer = setTimeout(() => {
        skillFlashing = false;
        skill.hidden = true;
        skill.classList.remove('is-open', 'is-hit', 'is-miss');
    }, SKILL_FLASH);

    postNui('skillCheckOver', { token, success });
}

function skillBeginRound(index) {
    const s = skillState;
    const source = s.rounds[index];

    // The arc is placed away from the needle's start so every round has a
    // run-up. Without it a hard round can be over before the dial is drawn.
    const areaStart = 70 + Math.random() * 200;

    s.index = index;
    s.angle = 0;
    s.round = {
        areaSize: source.areaSize,
        speedMultiplier: source.speedMultiplier,
        areaStart,
        areaEnd: areaStart + source.areaSize,
        input: s.inputs[Math.floor(Math.random() * s.inputs.length)],
    };

    skillRender(s.round, index, s.rounds.length);
}

function skillStep(now) {
    const s = skillState;
    if (!s) return;

    if (s.last === null) s.last = now;
    const delta = (now - s.last) / 1000;
    s.last = now;

    s.angle += SKILL_BASE_SPEED * s.round.speedMultiplier * delta;

    // Past the arc without a press is a miss. Checked before the wrap, or a
    // fast needle laps the dial and starts a second free attempt.
    if (s.angle > s.round.areaEnd) {
        skillFinish(false);
        return;
    }

    skillDraw();
    skillFrame = requestAnimationFrame(skillStep);
}

function skillShow(token, data) {
    const rounds = Array.isArray(data && data.rounds) ? data.rounds : [];
    if (!rounds.length) return;

    skillStopLoop();
    clearTimeout(skillFlashTimer);
    skillFlashing = false;

    skillToken = token;
    skillState = {
        rounds,
        inputs: Array.isArray(data.inputs) && data.inputs.length ? data.inputs : ['e'],
        index: 0,
        angle: 0,
        last: null,
        round: null,
    };

    skillBeginRound(0);

    skill.hidden = false;
    skill.classList.remove('is-open', 'is-hit', 'is-miss');
    void skill.offsetWidth;
    skill.classList.add('is-open');

    skillFrame = requestAnimationFrame(skillStep);
}

function skillHide() {
    skillStopLoop();

    // A result already reported is mid-flash and hides itself when it ends.
    // This path is the other two: a cancel, and the Lua deadman.
    if (skillFlashing) {
        skillState = null;
        skillToken = null;
        return;
    }

    clearTimeout(skillFlashTimer);

    skillState = null;
    skillToken = null;
    skill.hidden = true;
    skill.classList.remove('is-open', 'is-hit', 'is-miss');
}

function skillPress(key) {
    const s = skillState;
    if (!s || !s.round) return;

    if (key !== s.round.input) {
        skillFinish(false);
        return;
    }

    if (s.angle < s.round.areaStart || s.angle > s.round.areaEnd) {
        skillFinish(false);
        return;
    }

    const next = s.index + 1;

    if (next >= s.rounds.length) {
        skillFinish(true);
        return;
    }

    // A passed round flashes green without ending the check, so a three round
    // lockpick reads as three separate wins rather than one long dial.
    //
    // Through skillFlashTimer rather than its own timer, so a fast round
    // followed by the last one cannot have a stale timeout wipe the final
    // colour off mid-flash.
    skill.classList.add('is-hit');
    clearTimeout(skillFlashTimer);
    skillFlashTimer = setTimeout(() => skill.classList.remove('is-hit'), SKILL_FLASH);

    skillStopLoop();
    skillBeginRound(next);
    s.last = null;
    skillFrame = requestAnimationFrame(skillStep);
}

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data) return;

    if (data.action === 'context:show') {
        contextShow(data.data);
        return;
    }

    if (data.action === 'context:hide') {
        contextHide();
        return;
    }

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
        return;
    }

    if (data.action === 'skillcheck:show') {
        skillShow(data.token, data.data);
        return;
    }

    if (data.action === 'skillcheck:hide') {
        skillHide();
    }
});
