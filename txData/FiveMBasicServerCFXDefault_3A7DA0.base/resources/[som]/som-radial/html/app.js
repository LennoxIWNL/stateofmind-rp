const RESOURCE = window.location.hostname.replace('cfx-nui-', '');
const NS = 'http://www.w3.org/2000/svg';

const root = document.getElementById('root');
const svg = document.getElementById('svg');
const hubLabel = document.getElementById('hub-label');
const hubHint = document.getElementById('hub-hint');

const R_OUTER = 190;
const R_INNER = 78;
const R_LABEL = 138;
const R_ICON = 108;

let colours = {};
let deadZone = 0.22;
let slices = [];
let activeIndex = -1;
let stack = [];          // breadcrumb of submenus
let cursor = { x: 0, y: 0 };
// Set on the first mousemove after opening. Until then nothing is selectable.
let moved = false;

function post(endpoint, body) {
    return fetch(`https://${RESOURCE}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body ?? {}),
    })
        .then((r) => r.json())
        .catch(() => ({}));
}

const ICONS = {
    car: '<path d="M5 17h14M6.5 17v2M17.5 17v2"/><path d="M3.5 13l1.4-4.6A2 2 0 0 1 6.8 7h10.4a2 2 0 0 1 1.9 1.4L20.5 13"/><rect x="3" y="13" width="18" height="4" rx="1.4"/><path d="M6.5 15h.01M17.5 15h.01"/>',
    door: '<rect x="5" y="3" width="14" height="18" rx="1.6"/><path d="M15 12h.01"/>',
    engine: '<path d="M6 12h2l2-3h4l2 3h2"/><rect x="3" y="9" width="18" height="9" rx="2"/><path d="M8 9V6h8v3"/>',
    hazard: '<path d="M12 3l9 16H3z"/><path d="M12 10v4M12 17h.01"/>',
    seat: '<path d="M7 4h4a3 3 0 0 1 3 3v7H7z"/><path d="M7 14h9a3 3 0 0 1 3 3v3"/><path d="M5 20h4"/>',
    badge: '<path d="M12 2l7 3v6c0 5-3 8-7 11-4-3-7-6-7-11V5z"/><path d="M9 12l2 2 4-4"/>',
    gang: '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.9"/>',
    person: '<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>',
    id: '<rect x="2" y="5" width="20" height="14" rx="2"/><circle cx="8" cy="11" r="2.2"/><path d="M4.8 16.4c.7-1.5 2-2.2 3.2-2.2s2.5.7 3.2 2.2"/><path d="M14.5 10h4M14.5 13.5h4"/>',
    phone: '<rect x="6" y="2" width="12" height="20" rx="2.6"/><path d="M10.5 18.4h3"/>',
    hands: '<path d="M7 13V6.5a1.5 1.5 0 0 1 3 0V12"/><path d="M10 12V5.5a1.5 1.5 0 0 1 3 0V12"/><path d="M13 12V7a1.5 1.5 0 0 1 3 0v7a7 7 0 0 1-7 7 6 6 0 0 1-6-6v-3a1.5 1.5 0 0 1 3 0"/>',
    back: '<path d="M19 12H5M12 19l-7-7 7-7"/>',
    dot: '<circle cx="12" cy="12" r="4"/>',
};

// --- Geometry -----------------------------------------------------------

const polar = (r, a) => [r * Math.cos(a), r * Math.sin(a)];

/** Wedge between two angles, with a hole in the middle for the hub. */
function wedge(a0, a1) {
    const [x0, y0] = polar(R_OUTER, a0);
    const [x1, y1] = polar(R_OUTER, a1);
    const [x2, y2] = polar(R_INNER, a1);
    const [x3, y3] = polar(R_INNER, a0);
    const large = a1 - a0 > Math.PI ? 1 : 0;

    return `M ${x0} ${y0} A ${R_OUTER} ${R_OUTER} 0 ${large} 1 ${x1} ${y1}`
         + ` L ${x2} ${y2} A ${R_INNER} ${R_INNER} 0 ${large} 0 ${x3} ${y3} Z`;
}

function el(tag, attrs, cls) {
    const node = document.createElementNS(NS, tag);
    if (cls) node.setAttribute('class', cls);
    for (const k in attrs) node.setAttribute(k, attrs[k]);
    return node;
}

/** Breaks a label onto two lines rather than letting it overflow its wedge. */
function labelLines(text) {
    if (text.length <= 12) return [text];
    const words = text.split(' ');
    if (words.length === 1) return [text];

    const mid = Math.ceil(words.length / 2);
    return [words.slice(0, mid).join(' '), words.slice(mid).join(' ')];
}

// --- Render -------------------------------------------------------------

function render(items) {
    slices = items;
    activeIndex = -1;
    svg.replaceChildren();

    if (!items.length) {
        hubLabel.textContent = 'Nothing here';
        hubHint.textContent = 'Release to close';
        return;
    }

    const step = (Math.PI * 2) / items.length;
    // Start at the top rather than at 3 o'clock, so the first entry is where
    // the eye already is.
    const offset = -Math.PI / 2 - step / 2;

    items.forEach((item, i) => {
        const a0 = offset + i * step;
        const a1 = a0 + step;
        const mid = a0 + step / 2;

        const group = el('g', {}, 'slice');
        group.dataset.index = String(i);
        group.style.setProperty('--slice-colour', colours[item.section] || colours.default || '#ff1493');

        group.appendChild(el('path', { d: wedge(a0, a1) }, 'slice__path'));

        // Icon
        const [ix, iy] = polar(R_ICON, mid);
        const icon = el('svg', {
            viewBox: '0 0 24 24', width: 26, height: 26, x: ix - 13, y: iy - 13,
            fill: 'none', stroke: 'currentColor', 'stroke-width': 1.8,
            'stroke-linecap': 'round', 'stroke-linejoin': 'round',
        }, 'slice__icon');
        icon.innerHTML = ICONS[item.icon] || ICONS.dot;
        group.appendChild(icon);

        // Label
        const [lx, ly] = polar(R_LABEL, mid);
        const lines = labelLines(item.label);
        lines.forEach((line, n) => {
            const text = el('text', {
                x: lx, y: ly + (n - (lines.length - 1) / 2) * 13,
            }, 'slice__label');
            text.textContent = line;
            group.appendChild(text);
        });

        if (item.menu) {
            const [cx, cy] = polar(R_OUTER - 13, mid);
            const chevron = el('circle', { cx, cy, r: 2.6 }, 'slice__more');
            group.appendChild(chevron);
        }

        // Clicking is supported as well as releasing the key. Holding a key and
        // releasing is the fast path, but a click is what everyone tries first.
        group.addEventListener('click', () => {
            activeIndex = i;
            confirm();
        });

        svg.appendChild(group);
    });

    updateActive();
}

function setHub(item) {
    if (!item) {
        hubLabel.textContent = stack.length ? 'Back' : 'Select';
        hubHint.textContent = stack.length ? 'Release to go back' : 'Release to close';
        return;
    }

    hubLabel.textContent = item.label;
    hubHint.textContent = item.menu ? 'Release to open' : 'Release to pick';
}

// --- Pointer ------------------------------------------------------------

function updateActive() {
    const rect = svg.getBoundingClientRect();

    // While the root is hidden the element has no box, so getBoundingClientRect
    // returns all zeros. Measuring against that put the centre at the top left
    // of the screen, which made an arbitrary slice active the moment the wheel
    // opened, and releasing the key then picked it.
    if (rect.width === 0) return;

    const cx = rect.left + rect.width / 2;
    const cy = rect.top + rect.height / 2;

    const dx = cursor.x - cx;
    const dy = cursor.y - cy;
    const dist = Math.hypot(dx, dy) / (rect.width / 2);

    let index = -1;

    // Nothing is selectable until the mouse has actually been moved. Holding
    // the key and letting go without aiming must never pick anything.
    if (moved && dist >= deadZone && slices.length) {
        const step = (Math.PI * 2) / slices.length;
        const offset = -Math.PI / 2 - step / 2;
        let angle = Math.atan2(dy, dx) - offset;
        angle = ((angle % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2);
        index = Math.floor(angle / step);
    }

    if (index === activeIndex) return;
    activeIndex = index;

    svg.querySelectorAll('.slice').forEach((s, i) =>
        s.classList.toggle('is-active', i === index));

    setHub(slices[index]);
}

document.addEventListener('mousemove', (e) => {
    if (root.classList.contains('hidden')) return;
    cursor = { x: e.clientX, y: e.clientY };
    moved = true;
    updateActive();
});

// --- Selection ----------------------------------------------------------

async function openSubmenu(item) {
    const res = await post('submenu', { menu: item.menu });
    if (!res || !res.items || !res.items.length) {
        post('select', {});
        return;
    }

    stack.push(slices);
    render([{ id: '__back', label: 'Back', icon: 'back', section: 'self' }, ...res.items]);
}

function confirm() {
    const item = slices[activeIndex];

    // Dead zone, or nothing hovered.
    if (!item) {
        if (stack.length) {
            render(stack.pop());
            return;
        }
        post('close');
        return;
    }

    if (item.id === '__back') {
        render(stack.pop() || []);
        return;
    }

    if (item.menu) {
        openSubmenu(item);
        return;
    }

    post('select', { id: item.id, export: item.export, door: item.door, seat: item.seat });
}

// Escape and right click both close without picking anything, which is what
// people expect from a radial even when it is normally a hold-and-release.
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !root.classList.contains('hidden')) {
        root.classList.add('hidden');
        post('close');
    }
});

document.addEventListener('contextmenu', (e) => {
    e.preventDefault();
    if (root.classList.contains('hidden')) return;
    root.classList.add('hidden');
    post('close');
});

window.addEventListener('message', (event) => {
    const msg = event.data;
    if (!msg || typeof msg.action !== 'string') return;

    if (msg.action === 'open') {
        const d = msg.data || {};
        colours = d.colours || {};
        deadZone = typeof d.deadZone === 'number' ? d.deadZone : 0.22;
        stack = [];

        // Unhide BEFORE rendering. render() measures the wheel to work out
        // which slice the cursor is over, and a hidden element has no box.
        moved = false;
        cursor = { x: window.innerWidth / 2, y: window.innerHeight / 2 };
        root.classList.remove('hidden');

        render(d.items || []);
        return;
    }

    if (msg.action === 'confirm') {
        confirm();
        return;
    }

    if (msg.action === 'close') {
        root.classList.add('hidden');
        stack = [];
    }
});
