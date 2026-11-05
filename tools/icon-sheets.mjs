#!/usr/bin/env node
// Renders every ox_inventory icon onto numbered contact sheets so the art style
// can be reviewed by eye. Usage: node tools/icon-sheets.mjs <outDir> [perSheet] [namesFile]
// With namesFile (one icon name per line) only those are rendered. Made by Lennox.
import { readdirSync, readFileSync, mkdirSync, writeFileSync, existsSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { createRequire } from 'node:module'

const here = dirname(fileURLToPath(import.meta.url))
const root = join(here, '..')
const base = readdirSync(join(root, 'txData')).map((d) => join(root, 'txData', d)).find((d) => existsSync(join(d, 'resources')))
const imgs = join(base, 'resources', '[standalone]', 'ox_inventory', 'web', 'images')
const out = process.argv[2] || 'icon-sheets'
const per = Number(process.argv[3]) || 80
const namesFile = process.argv[4]

const require = createRequire(join(root, 'package.json'))
let chromium
for (const p of [join(root, 'node_modules', 'playwright'), join(root, '..', 'stateofmind', 'node_modules', 'playwright'), 'playwright']) {
  try { ({ chromium } = require(p)); break } catch {}
}
if (!chromium) { console.error('playwright not found'); process.exit(2) }

let names = readdirSync(imgs).filter((f) => f.endsWith('.png')).sort()
if (namesFile) { const want = new Set(readFileSync(namesFile, 'utf8').split('\n').map((s) => s.trim()).filter(Boolean)); names = names.filter((n) => want.has(n.replace(/\.png$/, ''))) }
mkdirSync(out, { recursive: true })

const browser = await chromium.launch()
const page = await browser.newPage({ viewport: { width: 1400, height: 1000 } })
let n = 0
for (let i = 0; i < names.length; i += per) {
  const chunk = names.slice(i, i + per)
  const cells = chunk.map((f) => `<div class="c"><div class="i"><img src="${pathToFileURL(join(imgs, f))}"></div><span>${f.replace(/\.png$/, '')}</span></div>`).join('')
  const htmlFile = join(out, 'sheet.html')
  writeFileSync(htmlFile, `<style>body{margin:0;background:#2b2d31;font:11px sans-serif;color:#ddd}.g{display:grid;grid-template-columns:repeat(10,130px);gap:6px;padding:8px}.c{text-align:center}.i{width:120px;height:120px;background:#1e1f22;margin:0 auto;display:flex;align-items:center;justify-content:center}img{max-width:110px;max-height:110px}span{display:block;overflow:hidden;white-space:nowrap;text-overflow:ellipsis}</style><div class="g">${cells}</div>`)
  await page.goto(pathToFileURL(htmlFile).href)
  await page.waitForLoadState('load')
  await page.waitForTimeout(300)
  const file = join(out, `sheet-${String(++n).padStart(2, '0')}.png`)
  await page.screenshot({ path: file, fullPage: true })
  writeFileSync(join(out, `sheet-${String(n).padStart(2, '0')}.txt`), chunk.join('\n') + '\n')
}
await browser.close()
console.log(`${names.length} icons on ${n} sheets in ${out}`)
