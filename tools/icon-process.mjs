#!/usr/bin/env node
// Turns a generated product photo (object on a near-white background) into an
// inventory icon: background removed by flood fill from the edges, cropped to
// the object, padded square and scaled to 100x100 with a transparent
// background. Usage: node tools/icon-process.mjs <in.png> <out.png> [size]
// Cutouts that already have transparency are only cropped and scaled. Pass `dark` as a
// fourth argument for dark objects so soft cast shadows are removed too.
// Made by Lennox.
import { readFileSync, writeFileSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createRequire } from 'node:module'

const [input, output, sizeArg, mode] = process.argv.slice(2)
if (!input || !output) { console.error('usage: icon-process.mjs in.png out.png [size]'); process.exit(2) }
const size = Number(sizeArg) || 100
const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const require = createRequire(join(root, 'package.json'))
let chromium
for (const p of [join(root, 'node_modules', 'playwright'), join(root, '..', 'stateofmind', 'node_modules', 'playwright'), 'playwright']) {
  try { ({ chromium } = require(p)); break } catch {}
}

const browser = await chromium.launch()
const page = await browser.newPage()
const dataUrl = 'data:image/png;base64,' + readFileSync(input).toString('base64')
const result = await page.evaluate(async ({ dataUrl, size, mode }) => {
  const img = new Image()
  img.src = dataUrl
  await img.decode()
  const w = img.naturalWidth, h = img.naturalHeight
  const c = document.createElement('canvas')
  c.width = w; c.height = h
  const ctx = c.getContext('2d', { willReadFrequently: true })
  ctx.drawImage(img, 0, 0)
  const d = ctx.getImageData(0, 0, w, h)
  const px = d.data
  // Background is near white, or a soft grey cast shadow: light and almost colourless.
  const near = (i) => {
    const mx = Math.max(px[i], px[i + 1], px[i + 2]), mn = Math.min(px[i], px[i + 1], px[i + 2])
    return mode === 'dark' ? mn > 118 && mx - mn < 30 : mn > 232 && mx - mn < 16
  }
  const hasAlpha = px[3] < 8 && px[(w - 1) * 4 + 3] < 8
  const seen = new Uint8Array(w * h)
  const stack = []
  if (!hasAlpha) {
    for (let x = 0; x < w; x++) { stack.push(x, 0, x, h - 1) }
    for (let y = 0; y < h; y++) { stack.push(0, y, w - 1, y) }
  }
  for (let k = 0; k < stack.length; k += 2) {
    const x = stack[k], y = stack[k + 1]
    const p = y * w + x
    if (seen[p] || !near(p * 4)) continue
    seen[p] = 1
    if (x > 0) stack.push(x - 1, y)
    if (x < w - 1) stack.push(x + 1, y)
    if (y > 0) stack.push(x, y - 1)
    if (y < h - 1) stack.push(x, y + 1)
  }
  // Soft shadow: grey pixels touching the background fade out instead of vanishing.
  let minX = w, minY = h, maxX = 0, maxY = 0
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const p = y * w + x, i = p * 4
    if (seen[p]) { px[i + 3] = 0; continue }
    const lum = (px[i] + px[i + 1] + px[i + 2]) / 3
    const sat = Math.max(px[i], px[i + 1], px[i + 2]) - Math.min(px[i], px[i + 1], px[i + 2])
    const edge = (x > 0 && seen[p - 1]) || (x < w - 1 && seen[p + 1]) || (y > 0 && seen[p - w]) || (y < h - 1 && seen[p + w])
    if (!hasAlpha && edge && lum > 200 && sat < 20) px[i + 3] = Math.max(0, Math.round((255 - lum) * 4))
    if (px[i + 3] > 24) { if (x < minX) minX = x; if (x > maxX) maxX = x; if (y < minY) minY = y; if (y > maxY) maxY = y }
  }
  ctx.putImageData(d, 0, 0)
  const bw = maxX - minX + 1, bh = maxY - minY + 1
  const side = Math.max(bw, bh) * 1.1
  const out = document.createElement('canvas')
  out.width = out.height = size
  const o = out.getContext('2d')
  o.imageSmoothingQuality = 'high'
  const scale = size / side
  o.drawImage(c, minX, minY, bw, bh, (size - bw * scale) / 2, (size - bh * scale) / 2, bw * scale, bh * scale)
  return out.toDataURL('image/png')
}, { dataUrl, size, mode })
writeFileSync(output, Buffer.from(result.split(',')[1], 'base64'))
await browser.close()
console.log(`wrote ${output}`)
