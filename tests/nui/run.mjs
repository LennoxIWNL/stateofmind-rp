// NUI test harness: loads a resource's real HTML/JS in headless Chromium
// (the pre-installed Playwright, no live FXServer needed) and drives it
// through the real postMessage shape Lua's SendNUIMessage sends.
//
// Run with: node tests/nui/run.mjs

import { readFileSync, readdirSync, existsSync } from 'fs';
import http from 'http';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(__dirname, '../../txData/FiveMBasicServerCFXDefault_3A7DA0.base/resources/[som]');
const SOM_UI_HTML = path.join(REPO, 'som-ui/html/index.html');
const SOM_ASSETS_TOKENS = path.join(REPO, 'som-assets/tokens.css');
const SOM_HACK_HTML = path.join(REPO, 'som-hack/html/index.html');
const SOM_PHONE_DIR = path.join(REPO, 'som-phone/html');
const PHONE_APPS_DIR = path.resolve(__dirname, '../../ui/apps/som-phone/src/apps');
const SCREENSHOT_DIR = path.join(__dirname, 'screenshots');

let pass = 0;
let fail = 0;

function check(cond, msg) {
    if (cond) {
        pass += 1;
    } else {
        fail += 1;
        console.log('FAIL: ' + msg);
    }
}

async function loadChromium() {
    let mod;
    try {
        mod = await import('playwright');
    } catch {
        // Not resolvable via a normal node_modules lookup when no local
        // `npm install playwright` has been done. Fall back to this dev
        // sandbox's pre-installed copy rather than requiring one.
        mod = await import('/opt/node-tools/node_modules/playwright/index.js');
    }
    // CJS-to-ESM interop only reliably exposes a default export.
    return mod.chromium || mod.default.chromium;
}

async function main() {
    const chromium = await loadChromium();
    const browser = await chromium.launch();
    const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });

    // The page's own <link> points at the cfx-nui-<resource> pseudo-protocol,
    // which only resolves inside the real game client. Serve the real file
    // from disk so the screenshot is faithful to how it actually renders,
    // the same way the Lua harness runs real files rather than copies.
    await page.route('https://cfx-nui-som-assets/tokens.css', (route) => {
        route.fulfill({
            status: 200,
            contentType: 'text/css',
            body: readFileSync(SOM_ASSETS_TOKENS, 'utf8'),
        });
    });

    await page.goto('file://' + SOM_UI_HTML);

    // --- som-ui notify: the ANPR plate-scan result (bridged from ps-mdt's
    // QBCore:Notify through som-compat into this same som:client:notify
    // path) renders through here, not a stock popup. ---
    await page.evaluate(() => {
        window.postMessage({
            action: 'notify',
            message: 'BOLO ID: 42 | Title: Stolen Vehicle | Registered Owner: J. Smith | Plate: ABC123',
            type: 'error',
            duration: 4000,
        }, '*');
    });

    await page.waitForSelector('.notification', { timeout: 2000 }).catch(() => {});

    const notification = await page.locator('.notification').first();
    const text = await notification.textContent().catch(() => null);

    check(text !== null, 'notify: a notification element should appear for a plate-scan hit');
    check(text !== null && text.includes('ABC123'), 'notify: the plate should be visible in the notification text');
    check(text !== null && text.includes('BOLO'), 'notify: the BOLO title should be visible in the notification text');

    const classes = await notification.getAttribute('class').catch(() => '');
    check(classes !== null && classes.includes('error'),
        'notify: a BOLO hit should render with the error style, not an unstyled default');

    // No leftover stock-toast chrome from whatever this was adapted from —
    // QBCore's own notify system uses the class "qb-notification".
    const stockLeftover = await page.locator('.qb-notification').count();
    check(stockLeftover === 0, 'notify: no leftover QBCore stock-notification markup should be present');

    await page.screenshot({ path: path.join(SCREENSHOT_DIR, 'anpr-notify.png') });

    // --- som-hack: the page only shows a puzzle and reports picks. The server
    // owns the answer, so these checks look at what the page sends and at the
    // fact that it never receives or reveals a solution. ---
    const hack = await browser.newPage({ viewport: { width: 1280, height: 720 } });
    await hack.route('https://cfx-nui-som-assets/tokens.css', (route) => {
        route.fulfill({ status: 200, contentType: 'text/css', body: readFileSync(SOM_ASSETS_TOKENS, 'utf8') });
    });

    const sent = [];
    let reply = {};
    await hack.route('https://som-hack/**', (route) => {
        const url = new URL(route.request().url());
        sent.push({ endpoint: url.pathname.slice(1), body: JSON.parse(route.request().postData() || '{}') });
        route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(reply) });
    });
    await hack.goto('file://' + SOM_HACK_HTML);

    await hack.evaluate(() => window.postMessage({ action: 'hack:start', view: { kind: 'memory' } }, '*'));
    check(await hack.locator('#hack').isHidden(), 'hack: a start message with no token shows nothing');

    await hack.evaluate(() => window.postMessage({
        action: 'hack:start',
        view: { kind: 'memory', nonce: 'n1', size: 3, showMs: 400, marks: [{ cell: 1, n: 2 }, { cell: 5, n: 1 }, { cell: 9, n: 3 }] },
    }, '*'));

    check(await hack.locator('.cell').count() === 9, 'hack memory: the grid has size x size cells');
    check((await hack.locator('.cell').nth(4).textContent()) === '1', 'hack memory: the numbers are shown first');
    check(await hack.locator('.cell').first().isDisabled(), 'hack memory: nothing can be picked while numbers are shown');
    await hack.screenshot({ path: path.join(SCREENSHOT_DIR, 'hack-memory-show.png') });

    await hack.waitForFunction(() => document.querySelector('.cell').textContent === '', null, { timeout: 2000 });
    check((await hack.locator('.cell').nth(4).textContent()) === '', 'hack memory: the numbers are hidden after the show time');
    check(!(await hack.locator('.cell').first().isDisabled()), 'hack memory: cells can be picked once hidden');

    reply = { success: true, solved: true };
    for (const index of [4, 0, 4, 8]) await hack.locator('.cell').nth(index).click();
    await hack.waitForFunction(() => document.getElementById('hack-status').textContent.includes('granted'), null, { timeout: 2000 });
    const submit = sent.find((s) => s.endpoint === 'submit');
    check(submit && submit.body.nonce === 'n1' && JSON.stringify(submit.body.answer) === '[5,1,9]',
        'hack memory: the picks go to the server in order, with the token, and a repeated click is ignored');
    await hack.screenshot({ path: path.join(SCREENSHOT_DIR, 'hack-memory-done.png') });

    await hack.waitForSelector('#hack', { state: 'hidden', timeout: 3000 });
    check(sent.some((s) => s.endpoint === 'done'), 'hack: the page tells the game when it closes');

    sent.length = 0;
    await hack.evaluate(() => window.postMessage({ action: 'hack:start', view: { kind: 'crack', nonce: 'n2', length: 4, attempts: 3 } }, '*'));
    check(await hack.locator('.slot').count() === 4, 'hack crack: one slot per digit');
    check(!(await hack.content()).includes('"code"'), 'hack crack: no solution is on the page');

    reply = { success: true, feedback: ['hit', 'near', 'miss', 'miss'], left: 2, solved: false, done: false };
    for (const key of ['1', '2', '3', '4', 'Enter']) await hack.keyboard.press(key);
    await hack.waitForSelector('.history .slot.hit', { timeout: 2000 });
    const guess = sent.find((s) => s.endpoint === 'guess');
    check(guess && JSON.stringify(guess.body.guess) === '[1,2,3,4]' && guess.body.nonce === 'n2',
        'hack crack: a guess is sent as digits with the token');
    check(await hack.locator('.history .slot.near').count() === 1 && await hack.locator('.history .slot.miss').count() === 2,
        'hack crack: the server feedback is drawn per digit');
    await hack.screenshot({ path: path.join(SCREENSHOT_DIR, 'hack-crack.png') });

    reply = { success: true, feedback: ['hit', 'hit', 'hit', 'hit'], left: 1, solved: true, done: true };
    for (const key of ['5', '6', '7', '8', 'Enter']) await hack.keyboard.press(key);
    await hack.waitForFunction(() => document.getElementById('hack-status').textContent.includes('granted'), null, { timeout: 2000 });
    check(true, 'hack crack: a solved reply is shown as access granted');

    sent.length = 0;
    await hack.evaluate(() => window.postMessage({ action: 'hack:start', view: { kind: 'crack', nonce: 'n3', length: 4, attempts: 3 } }, '*'));
    await hack.keyboard.press('Escape');
    await hack.waitForSelector('#hack', { state: 'hidden', timeout: 2000 });
    check(sent.some((s) => s.endpoint === 'done') && !sent.some((s) => s.endpoint === 'guess'),
        'hack: Escape leaves without sending a guess');

    // --- som-phone: the shell and its apps. The built page is a module script,
    // which Chromium will not load from file://, so it is served over http. ---
    const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.map': 'application/json' };
    const server = http.createServer((req, res) => {
        const rel = decodeURIComponent((req.url || '/').split('?')[0]);
        const file = path.join(SOM_PHONE_DIR, rel === '/' ? 'index.html' : rel);
        if (!file.startsWith(SOM_PHONE_DIR) || !existsSync(file)) { res.writeHead(404).end(); return; }
        res.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream' }).end(readFileSync(file));
    });
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    const phoneUrl = `http://127.0.0.1:${server.address().port}/`;

    const phone = await browser.newPage({ viewport: { width: 1280, height: 720 } });
    await phone.route('https://cfx-nui-som-assets/tokens.css', (route) => {
        route.fulfill({ status: 200, contentType: 'text/css', body: readFileSync(SOM_ASSETS_TOKENS, 'utf8') });
    });

    const calls = [];
    const answers = {};
    await phone.route('https://som-phone/**', (route) => {
        const url = new URL(route.request().url());
        const body = JSON.parse(route.request().postData() || '{}');
        calls.push({ endpoint: url.pathname.slice(1), body });
        const key = `${body.app}:${body.action}`;
        const answer = typeof answers[key] === 'function' ? answers[key](body) : answers[key];
        route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(answer ?? { success: true }) });
    });

    const openData = (over = {}) => ({
        apps: [
            { id: 'bank', label: 'Bank', icon: 'bank', colour: '#2ecc71', order: 10 },
            { id: 'properties', label: 'Properties', icon: 'briefcase', colour: '#e0a13b', order: 20 },
            { id: 'jobs', label: 'Jobs', icon: 'briefcase', colour: '#4a9eff', order: 30 },
            { id: 'settings', label: 'Settings', icon: 'settings', colour: '#8e8e93', order: 90 },
        ],
        settings: { theme: 'default', wallpaper: 'default' },
        themes: { default: { label: 'State of Mind', accent: '#ff1493' }, midnight: { label: 'Midnight', accent: '#4a9eff', perk: 'phoneTheme' } },
        owner: 'Ann One', number: '555-0001', hasPasscode: false, badges: { bank: 2 }, ...over,
    });
    const send = (msg) => phone.evaluate((m) => window.postMessage(m, '*'), msg);

    await phone.goto(phoneUrl);
    await phone.waitForSelector('#root', { state: 'attached' });
    check((await phone.locator('.phone').count()) === 0, 'phone: nothing is drawn until the game opens it');

    await send({ action: 'open', data: openData() });
    await phone.waitForSelector('.lock');
    check((await phone.locator('.lock__owner').textContent()) === 'Ann One' && (await phone.locator('.lock__number').textContent()) === '555-0001',
        'phone: the lock screen shows the owner and number');
    check((await phone.locator('.key').count()) === 0, 'phone: no keypad when there is no passcode');
    await phone.screenshot({ path: path.join(SCREENSHOT_DIR, 'phone-lock.png') });

    await phone.locator('.lock').click();
    await phone.waitForSelector('.apps .app');
    check((await phone.locator('.app').count()) === 4, 'phone: the home screen shows every app the server listed');
    check((await phone.locator('.app__badge').first().textContent()) === '2', 'phone: the bank tile carries its unread count');
    await phone.screenshot({ path: path.join(SCREENSHOT_DIR, 'phone-home.png') });

    answers['bank:overview'] = {
        success: true, accountNo: '48271930', money: { bank: 12500, cash: 300 },
        history: [{ id: 1, account: 'bank', amount: 450, direction: 'debit', label: 'Armoury', created_at: '2026-01-02 10:00:00' }],
        bills: [{ id: 7, from_name: 'LSPD (Bo Two)', amount: 500, reason: 'Speeding' }, { id: 8, from_name: 'Ann', amount: 20, reason: '<b>x</b>' }],
        saved: [{ account_no: '11112222', label: 'Cy' }],
    };
    await phone.locator('.app', { hasText: 'Bank' }).click();
    await phone.waitForSelector('.balance__value');
    check((await phone.locator('.balance__value').textContent()) === '$12,500' && (await phone.locator('.account__no').textContent()) === '48271930',
        'bank: the balance and account number come from the server');
    check((await phone.locator('.row__title').first().textContent()) === 'Armoury', 'bank: the statement shows the server label');
    await phone.screenshot({ path: path.join(SCREENSHOT_DIR, 'phone-bank.png') });

    await phone.locator('.segment__item', { hasText: 'Bills' }).click();
    check((await phone.locator('.row__title', { hasText: '<b>x</b>' }).count()) === 1 && (await phone.locator('.row__title b').count()) === 0,
        'bank: a bill reason is shown as text, never as markup');
    calls.length = 0;
    await phone.locator('.btn', { hasText: 'Pay' }).first().click();
    await phone.waitForTimeout(150);
    check(calls.some((c) => c.body.app === 'bank' && c.body.action === 'pay' && c.body.payload.id === 7),
        'bank: paying sends only the bill id to the server');

    calls.length = 0;
    await phone.locator('#bill-account').fill('1111-2222');
    await phone.locator('#bill-amount').fill('$1,5a0');
    await phone.locator('#bill-reason').fill('Lunch');
    await phone.locator('.btn', { hasText: 'Send bill' }).click();
    await phone.waitForTimeout(150);
    const billCall = calls.find((c) => c.body.action === 'bill');
    check(billCall && billCall.body.payload.accountNo === '11112222' && billCall.body.payload.amount === 150 && billCall.body.payload.reason === 'Lunch',
        'bank: number fields are reduced to digits before they are sent');

    await phone.locator('.back').click();
    await phone.waitForSelector('.apps .app');

    answers['jobs:view'] = { success: true, view: {
        sections: [{ title: 'Open', rows: [{ title: '<img src=x onerror=window.__pwned=1>', sub: 'sub', action: 'take', payload: { id: 3 } }] }],
        buttons: [{ label: 'Ready up', action: 'ready' }],
    } };
    await phone.locator('.app', { hasText: 'Jobs' }).click();
    await phone.waitForSelector('.list .row');
    check((await phone.locator('.row__title').textContent()) === '<img src=x onerror=window.__pwned=1>' && (await phone.locator('.row img').count()) === 0
        && !(await phone.evaluate(() => window.__pwned)), 'host: an app from another resource cannot inject markup');
    await phone.screenshot({ path: path.join(SCREENSHOT_DIR, 'phone-host-app.png') });
    calls.length = 0;
    await phone.locator('.btn', { hasText: 'Ready up' }).click();
    await phone.waitForTimeout(150);
    check(calls.some((c) => c.body.app === 'jobs' && c.body.action === 'ready'), 'host: a button sends its action back to the owning resource');

    answers['jobs:view'] = { success: false, error: 'locked' };
    await phone.locator('.back').click();
    await phone.locator('.app', { hasText: 'Jobs' }).click();
    await phone.waitForFunction(() => document.querySelector('.empty')?.textContent === 'locked', null, { timeout: 2000 }).catch(() => {});
    check((await phone.locator('.empty').textContent()) === 'locked', 'host: a refused view shows the reason');

    await send({ action: 'banner', title: 'Bank', text: 'Purchase  -$20', icon: 'bank' });
    check((await phone.locator('.banner__text').textContent()) === 'Purchase  -$20', 'phone: a notification banner appears');
    for (let i = 0; i < 4; i += 1) await send({ action: 'banner', title: 'T', text: `n${i}`, icon: 'bank' });
    check((await phone.locator('.banner').count()) === 3, 'phone: at most three banners show at once');

    await send({ action: 'close' });
    await phone.waitForSelector('.root.is-banners-only', { timeout: 2000 });
    check(true, 'phone: closing with banners still showing leaves only the banners');

    calls.length = 0;
    await send({ action: 'open', data: openData({ hasPasscode: true }) });
    await phone.waitForSelector('.keypad');
    answers['system:unlock'] = (body) => (body.payload.passcode === '1234' ? { success: true } : { success: false, error: 'Wrong passcode' });
    for (const k of ['9', '9', '9', '9']) await phone.locator('.key', { hasText: new RegExp(`^${k}$`) }).click();
    await phone.waitForFunction(() => document.querySelector('.lock__hint')?.textContent === 'Wrong passcode', null, { timeout: 2000 });
    check(true, 'lock: a wrong passcode is refused and says so');
    check(calls.filter((c) => c.body.action === 'unlock').length === 1, 'lock: the code is checked on the server, one request per attempt');
    for (const k of ['1', '2', '3', '4']) await phone.locator('.key', { hasText: new RegExp(`^${k}$`) }).click();
    await phone.waitForSelector('.apps .app');
    const unlockCall = calls.filter((c) => c.body.action === 'unlock').pop();
    check(unlockCall.body.app === 'system' && unlockCall.body.payload.passcode === '1234', 'lock: the right passcode unlocks through the server');
    await phone.screenshot({ path: path.join(SCREENSHOT_DIR, 'phone-unlocked.png') });

    await phone.keyboard.press('Escape');
    await phone.waitForFunction(() => !document.querySelector('.phone') || document.querySelector('.root.is-banners-only'), null, { timeout: 2000 });
    check(calls.some((c) => c.endpoint === 'close'), 'phone: Escape tells the game to close it');

    // --- som-phone comms: contacts, messages, the dialer and the call bar. ---
    await send({ action: 'open', data: openData({ apps: [
        { id: 'phone', label: 'Phone', icon: 'phone', colour: '#34c759', order: 5 },
        { id: 'messages', label: 'Messages', icon: 'message', colour: '#30d158', order: 15 },
        { id: 'contacts', label: 'Contacts', icon: 'contacts', colour: '#34c759', order: 30 },
    ] }) });
    await phone.locator('.lock').click();
    await phone.waitForSelector('.apps .app');

    answers['contacts:list'] = { success: true, contacts: [{ number: '555-0003', name: 'Cyrus' }] };
    await phone.locator('.app', { hasText: 'Contacts' }).click();
    await phone.waitForSelector('.row__title');
    check((await phone.locator('.row__title').textContent()) === 'Cyrus', 'contacts: the list comes from the server');
    calls.length = 0;
    await phone.locator('#contact-name').fill('Dee');
    await phone.locator('#contact-number').fill('555-0004');
    await phone.locator('.btn', { hasText: 'Save' }).click();
    await phone.waitForTimeout(150);
    const saveCall = calls.find((c) => c.body.action === 'save');
    check(saveCall && saveCall.body.payload.number === '5550004' && saveCall.body.payload.name === 'Dee', 'contacts: the number is reduced to digits before it is sent');
    calls.length = 0;
    await phone.locator('button[aria-label="Call Cyrus"]').click();
    await phone.waitForTimeout(150);
    check(calls.some((c) => c.body.app === 'phone' && c.body.action === 'dial' && c.body.payload.number === '555-0003'), 'contacts: the call button dials through the phone app');
    await phone.screenshot({ path: path.join(SCREENSHOT_DIR, 'phone-contacts.png') });

    calls.length = 0;
    await phone.locator('button[aria-label="Message Cyrus"]').click();
    await phone.waitForSelector('.chat');
    check(calls.some((c) => c.body.app === 'messages' && c.body.action === 'thread' && c.body.payload.number === '555-0003'),
        'contacts: the message button opens that thread');

    answers['messages:thread'] = { success: true, number: '555-0003', name: 'Cyrus', messages: [
        { id: 1, mine: false, body: 'hi <b>there</b>' }, { id: 2, mine: true, body: 'hello' },
    ] };
    answers['messages:threads'] = { success: true, threads: [{ other: '555-0003', name: 'Cyrus', body: 'hello', mine: true, unread: 2 }] };
    await phone.locator('.back', { hasText: 'All messages' }).click();
    await phone.waitForSelector('.rowbtn');
    check((await phone.locator('.rowbtn .pill').textContent()) === '2', 'messages: the inbox shows the unread count');
    await phone.locator('.rowbtn').click();
    await phone.waitForSelector('.bubble');
    check((await phone.locator('.bubble').first().textContent()) === 'hi <b>there</b>' && (await phone.locator('.bubble b').count()) === 0,
        'messages: a message body is text, never markup');
    check((await phone.locator('.bubble--mine').count()) === 1, 'messages: my messages sit on my side');
    calls.length = 0;
    await phone.locator('input[aria-label="Message"]').fill('on my way');
    await phone.locator('.btn', { hasText: 'Send' }).click();
    await phone.waitForTimeout(150);
    check(calls.some((c) => c.body.app === 'messages' && c.body.action === 'send' && c.body.payload.body === 'on my way' && c.body.payload.number === '555-0003'),
        'messages: sending names the number and the text only');
    await phone.screenshot({ path: path.join(SCREENSHOT_DIR, 'phone-messages.png') });

    await phone.locator('.back', { hasText: 'Home' }).click();
    answers['phone:recents'] = { success: true, recents: [{ number: '555-0003', name: 'Cyrus', status: 'missed', outgoing: false }] };
    await phone.locator('.app', { hasText: 'Phone' }).click();
    await phone.waitForSelector('.dialer');
    check((await phone.locator('.rowbtn .row__title').textContent()) === 'Cyrus', 'phone: recent calls show the contact name');
    check(await phone.locator('.key--call').isDisabled(), 'phone: the call key is off until seven digits are entered');
    for (const d of ['5', '5', '5', '0', '0', '0', '4']) await phone.locator('.dialer .key', { hasText: new RegExp(`^${d}$`) }).click();
    check((await phone.locator('.dialer__number').textContent()) === '5550004', 'phone: the keypad builds the number');
    calls.length = 0;
    await phone.locator('.key--call').click();
    await phone.waitForTimeout(150);
    check(calls.some((c) => c.body.app === 'phone' && c.body.action === 'dial' && c.body.payload.number === '5550004'), 'phone: dialling sends the number');
    await phone.screenshot({ path: path.join(SCREENSHOT_DIR, 'phone-dialer.png') });

    await send({ action: 'call', data: { state: 'ringing', number: '555-0003', name: 'Cyrus' } });
    await phone.waitForSelector('.callbar');
    check((await phone.locator('.callbar__state').textContent()) === 'Incoming call' && (await phone.locator('.callbar__name').textContent()) === 'Cyrus',
        'calls: an incoming call shows who is calling');
    calls.length = 0;
    await phone.locator('.callbar .btn', { hasText: 'Answer' }).click();
    await phone.waitForTimeout(150);
    check(calls.some((c) => c.body.app === 'phone' && c.body.action === 'answer'), 'calls: Answer goes to the server');
    await send({ action: 'call', data: { state: 'active', number: '555-0003', name: 'Cyrus' } });
    await phone.waitForFunction(() => document.querySelector('.callbar__state')?.textContent === 'On a call', null, { timeout: 2000 });
    check((await phone.locator('.callbar .btn', { hasText: 'Answer' }).count()) === 0, 'calls: an active call offers only End');
    await phone.screenshot({ path: path.join(SCREENSHOT_DIR, 'phone-call.png') });
    await phone.locator('.callbar .btn', { hasText: 'End' }).click();
    await phone.waitForTimeout(150);
    check(calls.some((c) => c.body.action === 'hangup'), 'calls: End goes to the server');
    await send({ action: 'call', data: { state: 'ended' } });
    await phone.waitForFunction(() => !document.querySelector('.callbar'), null, { timeout: 2000 });
    check(true, 'calls: the call bar goes when the server says it ended');

    // --- som-phone social: Chirp and Pages. ---
    await phone.locator('.back', { hasText: 'Home' }).click().catch(() => {});
    await send({ action: 'open', data: openData({ apps: [
        { id: 'chirp', label: 'Chirp', icon: 'twitter', colour: '#1da1f2', order: 25 },
        { id: 'pages', label: 'Pages', icon: 'inbox', colour: '#f2c94c', order: 28 },
    ] }) });
    await phone.locator('.lock').click();
    await phone.waitForSelector('.apps .app');

    answers['chirp:feed'] = { success: true, me: { handle: 'annone42', business: 'LSPD' }, posts: [
        { id: 2, handle: 'bo', colour: '#2ecc71', body: 'hi <img src=x onerror=alert(1)>', likes: 1, replies: 1, mine: false, liked: false },
        { id: 1, handle: 'annone42', body: 'my post', likes: 0, replies: 0, mine: true, liked: false },
    ] };
    await phone.locator('.app', { hasText: 'Chirp' }).click();
    await phone.waitForSelector('.post');
    check((await phone.locator('.post').count()) === 2, 'chirp: the feed lists the posts the server returned');
    check((await phone.locator('.post__body').first().textContent()) === 'hi <img src=x onerror=alert(1)>' && (await phone.locator('.post__body img').count()) === 0,
        'chirp: a post body is text, never markup');
    check((await phone.locator('.post__head strong').first().textContent()) === '@bo', 'chirp: the author shows as a handle');
    check((await phone.locator('.post').nth(1).locator('.link', { hasText: 'Delete' }).count()) === 1 &&
        (await phone.locator('.post').nth(0).locator('.link', { hasText: 'Report' }).count()) === 1, 'chirp: my post offers delete, anyone else\'s offers report');
    check((await phone.locator('.check', { hasText: 'As LSPD' }).count()) === 1, 'chirp: the business box shows only when the server says the character can speak for one');

    calls.length = 0;
    await phone.locator('textarea[aria-label="New post"]').fill('hello world');
    await phone.locator('.check input').check();
    await phone.locator('.btn', { hasText: 'Post' }).click();
    await phone.waitForTimeout(150);
    const postCall = calls.find((c) => c.body.app === 'chirp' && c.body.action === 'post');
    check(postCall && postCall.body.payload.body === 'hello world' && postCall.body.payload.asBusiness === true && postCall.body.payload.business === undefined,
        'chirp: a post sends text and a business flag, never a handle or a business name');
    await phone.screenshot({ path: path.join(SCREENSHOT_DIR, 'phone-chirp.png') });

    calls.length = 0;
    await phone.locator('.post').first().locator('.link').first().click();
    await phone.waitForTimeout(150);
    check(calls.some((c) => c.body.app === 'chirp' && c.body.action === 'like' && c.body.payload.id === 2), 'chirp: a like names the post id only');

    answers['chirp:thread'] = { success: true, posts: [
        { id: 2, handle: 'bo', body: 'root', likes: 1, replies: 1, mine: false, liked: false },
        { id: 3, handle: 'cy', body: 'a reply', likes: 0, replies: 0, reply_to: 2, mine: false, liked: false },
    ] };
    await phone.locator('.post').first().locator('.link').nth(1).click();
    await phone.waitForSelector('textarea[aria-label="Reply"]');
    check((await phone.locator('.post').count()) === 2, 'chirp: opening a post shows it with its replies');
    calls.length = 0;
    await phone.locator('textarea[aria-label="Reply"]').fill('thanks');
    await phone.locator('.btn', { hasText: 'Reply' }).click();
    await phone.waitForTimeout(150);
    check(calls.some((c) => c.body.action === 'post' && c.body.payload.replyTo === 2 && c.body.payload.body === 'thanks'), 'chirp: a reply names its parent');
    await phone.locator('.back', { hasText: 'Feed' }).click();

    await phone.locator('.back', { hasText: 'Home' }).click();
    answers['pages:adverts'] = { success: true, categories: ['for_sale', 'wanted'], business: null, adverts: [
        { id: 7, handle: 'bo', category: 'for_sale', title: 'Bike <b>x</b>', body: 'Nice bike', price: '$500', number: '555-0002', mine: false },
        { id: 8, handle: 'annone42', category: 'wanted', title: 'Need a ride', body: 'Please', mine: true },
    ] };
    await phone.locator('.app', { hasText: 'Pages' }).click();
    await phone.waitForSelector('.post');
    check((await phone.locator('.post').count()) === 2 && (await phone.locator('.post__head strong b').count()) === 0, 'pages: adverts render as text');
    check((await phone.locator('.post .muted').first().textContent()).includes('555-0002'), 'pages: a shared number is shown');
    check((await phone.locator('.check', { hasText: 'As ' }).count()) === 0, 'pages: no business option unless the server offers one');
    calls.length = 0;
    await phone.locator('.post').first().locator('.link', { hasText: 'Message' }).click();
    await phone.locator('input[aria-label="Message"]').fill('still available?');
    await phone.locator('.post .btn', { hasText: 'Send' }).click();
    await phone.waitForTimeout(150);
    check(calls.some((c) => c.body.app === 'pages' && c.body.action === 'contact' && c.body.payload.id === 7 && c.body.payload.body === 'still available?'),
        'pages: contacting an advert sends its id and the text only');
    await phone.screenshot({ path: path.join(SCREENSHOT_DIR, 'phone-pages.png') });

    calls.length = 0;
    await phone.locator('.btn', { hasText: 'Place an advert' }).click();
    await phone.locator('input[aria-label="Title"]').fill('Sofa');
    await phone.locator('textarea[aria-label="Description"]').fill('Comfy');
    await phone.locator('.btn', { hasText: 'Publish' }).click();
    await phone.waitForTimeout(150);
    const adCall = calls.find((c) => c.body.app === 'pages' && c.body.action === 'post');
    check(adCall && adCall.body.payload.title === 'Sofa' && adCall.body.payload.category === 'for_sale' && adCall.body.payload.showNumber === false,
        'pages: placing an advert keeps the number private by default');

    answers['pages:listing'] = { success: true, listed: false };
    await phone.locator('.segment__item', { hasText: 'People' }).click();
    await phone.waitForSelector('.check input');
    check(!(await phone.locator('.check input').isChecked()), 'white pages: listing is off by default');
    answers['pages:search'] = { success: true, people: [{ firstname: 'Bo', lastname: 'Two', phone: '555-0002' }] };
    await phone.locator('input[aria-label="Search by name"]').fill('Two');
    await phone.locator('.btn', { hasText: 'Search' }).click();
    await phone.waitForSelector('.row__title');
    check((await phone.locator('.row__title').textContent()) === 'Bo Two' && (await phone.locator('.row__sub').textContent()) === '555-0002',
        'white pages: a result shows the name and number');
    await phone.screenshot({ path: path.join(SCREENSHOT_DIR, 'phone-whitepages.png') });

    // --- som-phone city: Garage, Services, Notes. ---
    await phone.locator('.back', { hasText: 'Home' }).click();
    await send({ action: 'open', data: openData({ apps: [
        { id: 'garage', label: 'Garage', icon: 'car', colour: '#5e5ce6', order: 40 },
        { id: 'services', label: 'Services', icon: 'dispatch', colour: '#ff453a', order: 45 },
        { id: 'notes', label: 'Notes', icon: 'note', colour: '#ffd60a', order: 50 },
    ] }) });
    await phone.locator('.lock').click();
    await phone.waitForSelector('.apps .app');

    answers['garage:list'] = { success: true, vehicles: [
        { plate: 'AAA111', model: 'sultan', garage: 'legion', state: 'garaged' },
        { plate: 'BBB222', model: 'felon', garage: 'impound', state: 'impounded' },
    ] };
    await phone.locator('.app', { hasText: 'Garage' }).click();
    await phone.waitForSelector('.row__title');
    check((await phone.locator('.row').count()) === 2 && (await phone.locator('.row__sub').first().textContent()) === 'Stored at legion' &&
        (await phone.locator('.row__sub').nth(1).textContent()) === 'Impounded', 'garage: each vehicle shows where it is');
    check((await phone.locator('.row button, .row input').count()) === 0, 'garage: it offers no actions');
    await phone.screenshot({ path: path.join(SCREENSHOT_DIR, 'phone-garage.png') });

    await phone.locator('.back', { hasText: 'Home' }).click();
    answers['services:list'] = { success: true, services: [{ job: 'mechanic', label: 'Mechanic', onDuty: 2 }, { job: 'taxi', label: 'Taxi', onDuty: 0 }] };
    await phone.locator('.app', { hasText: 'Services' }).click();
    await phone.waitForSelector('.row__title');
    check((await phone.locator('.row__sub').first().textContent()) === '2 on duty' && (await phone.locator('.row__sub').nth(1).textContent()) === 'Nobody on duty',
        'services: counts come from the server');
    calls.length = 0;
    await phone.locator('input[aria-label="What is happening"]').fill('shots fired at legion');
    await phone.locator('.btn', { hasText: 'Call 911' }).click();
    await phone.waitForTimeout(150);
    const sos = calls.find((c) => c.body.app === 'services' && c.body.action === 'emergency');
    check(sos && sos.body.payload.message === 'shots fired at legion' && Object.keys(sos.body.payload).length === 1,
        'services: a 911 call sends the message only, no position or caller');
    await phone.screenshot({ path: path.join(SCREENSHOT_DIR, 'phone-services.png') });

    await phone.locator('.back', { hasText: 'Home' }).click();
    answers['notes:list'] = { success: true, notes: [{ id: 4, title: 'Plan <b>A</b>', body: 'first line\nsecond' }] };
    await phone.locator('.app', { hasText: 'Notes' }).click();
    await phone.waitForSelector('.rowbtn');
    check((await phone.locator('.row__title').textContent()) === 'Plan <b>A</b>' && (await phone.locator('.row__title b').count()) === 0 &&
        (await phone.locator('.row__sub').textContent()) === 'first line', 'notes: a title is text and the list shows the first line');
    await phone.locator('.rowbtn').click();
    await phone.waitForSelector('textarea[aria-label="Note"]');
    check((await phone.locator('textarea[aria-label="Note"]').inputValue()) === 'first line\nsecond', 'notes: opening a note loads its body');
    calls.length = 0;
    await phone.locator('textarea[aria-label="Note"]').fill('changed');
    await phone.locator('.btn', { hasText: 'Save' }).click();
    await phone.waitForTimeout(150);
    check(calls.some((c) => c.body.app === 'notes' && c.body.action === 'save' && c.body.payload.id === 4 && c.body.payload.body === 'changed'), 'notes: saving names the note and the new text');
    await phone.locator('.btn', { hasText: 'New note' }).click();
    calls.length = 0;
    await phone.locator('input[aria-label="Title"]').fill('Fresh');
    await phone.locator('.btn', { hasText: 'Save' }).click();
    await phone.waitForTimeout(150);
    check(calls.some((c) => c.body.action === 'save' && c.body.payload.id === undefined && c.body.payload.title === 'Fresh'), 'notes: a new note carries no id');
    await phone.screenshot({ path: path.join(SCREENSHOT_DIR, 'phone-notes.png') });

    // --- A host app button that asks for one line of text. ---
    await phone.locator('.back', { hasText: 'Home' }).click();
    await send({ action: 'open', data: openData({ apps: [{ id: 'groups', label: 'Groups', icon: 'contacts', colour: '#64d2ff', order: 60 }] }) });
    await phone.locator('.lock').click();
    await phone.waitForSelector('.apps .app');
    answers['groups:view'] = { success: true, view: {
        sections: [{ title: 'Your group', rows: [{ title: 'Ann One (leader)', sub: 'Ready' }, { title: 'Bo Two', sub: 'Not ready', action: 'kick', payload: { member: 2 } }] }],
        buttons: [{ label: 'Invite by number', action: 'invite', prompt: { field: 'number', label: 'Phone number', maxLength: 8 } }, { label: 'Leave group', action: 'leave', danger: true }],
    } };
    await phone.locator('.app', { hasText: 'Groups' }).click();
    await phone.waitForSelector('.row__title');
    calls.length = 0;
    await phone.locator('.btn', { hasText: 'Invite by number' }).click();
    check(calls.length === 0, 'host: a prompt button sends nothing until text is entered');
    await phone.locator('input[aria-label="Phone number"]').fill('555-0003');
    await phone.locator('.btn', { hasText: 'Send' }).click();
    await phone.waitForTimeout(150);
    check(calls.some((c) => c.body.app === 'groups' && c.body.action === 'invite' && c.body.payload.number === '555-0003'), 'host: the entered text is sent under the field name');
    await phone.screenshot({ path: path.join(SCREENSHOT_DIR, 'phone-groups.png') });

    // Apps may import only the SDK, React and the shared types, so an app can
    // never reach around the one door to the server.
    const allowed = /^(react|@som\/phone-sdk|\.\.\/types)$/;
    const offenders = [];
    for (const file of readdirSync(PHONE_APPS_DIR).filter((f) => f.endsWith('.tsx'))) {
        for (const m of readFileSync(path.join(PHONE_APPS_DIR, file), 'utf8').matchAll(/from\s+'([^']+)'/g)) {
            if (!allowed.test(m[1])) offenders.push(`${file}: ${m[1]}`);
        }
    }
    check(offenders.length === 0, 'phone apps: only the SDK, React and shared types are imported ' + offenders.join(', '));
    check(!readdirSync(PHONE_APPS_DIR).some((f) => /fetch\(/.test(readFileSync(path.join(PHONE_APPS_DIR, f), 'utf8'))), 'phone apps: none calls fetch itself');

    await new Promise((resolve) => server.close(resolve));

    await browser.close();

    console.log(`${pass} passed, ${fail} failed`);
    process.exit(fail === 0 ? 0 : 1);
}

main();
