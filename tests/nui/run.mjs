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
    await phone.waitForSelector('.empty');
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
