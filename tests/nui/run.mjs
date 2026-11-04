// NUI test harness: loads a resource's real HTML/JS in headless Chromium
// (the pre-installed Playwright, no live FXServer needed) and drives it
// through the real postMessage shape Lua's SendNUIMessage sends.
//
// Run with: node tests/nui/run.mjs

import { readFileSync } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(__dirname, '../../txData/FiveMBasicServerCFXDefault_3A7DA0.base/resources/[som]');
const SOM_UI_HTML = path.join(REPO, 'som-ui/html/index.html');
const SOM_ASSETS_TOKENS = path.join(REPO, 'som-assets/tokens.css');
const SOM_HACK_HTML = path.join(REPO, 'som-hack/html/index.html');
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

    await browser.close();

    console.log(`${pass} passed, ${fail} failed`);
    process.exit(fail === 0 ? 0 : 1);
}

main();
