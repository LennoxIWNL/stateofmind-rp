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

    await browser.close();

    console.log(`${pass} passed, ${fail} failed`);
    process.exit(fail === 0 ? 0 : 1);
}

main();
