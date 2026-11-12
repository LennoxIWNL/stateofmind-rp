#!/usr/bin/env node
// Builds ECONOMY-MAP.md from the real configs: where every item comes from and
// where it goes, and fails when something that is needed has no source.
//   node tools/economy-map.mjs          rewrite ECONOMY-MAP.md
//   node tools/economy-map.mjs --check  fail on dead ends or a stale file
// Items that are deliberately unsourced for now live in tools/economy-known.json.
// Made by Lennox.
import { readFileSync, writeFileSync, existsSync, readdirSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const base = readdirSync(join(root, 'txData')).map((d) => join(root, 'txData', d)).find((d) => existsSync(join(d, 'resources')))
const res = join(base, 'resources')
const som = (p) => readFileSync(join(res, '[som]', p), 'utf8')
const ox = (p) => readFileSync(join(res, '[standalone]', 'ox_inventory', p), 'utf8')

const sources = new Map()
const uses = new Map()
const add = (m, item, text) => { if (!m.has(item)) m.set(item, new Set()); m.get(item).add(text) }
const pairsOf = (block) => [...block.matchAll(/([A-Za-z0-9_]+)\s*=\s*(\d+(?:\.\d+)?)/g)].map((m) => [m[1], Number(m[2])])

for (const m of ox('data/shops.lua').matchAll(/name = '([A-Za-z0-9_]+)', price = (\d+)/g)) add(sources, m[1], `shop ($${m[2]})`)

for (const m of ox('data/crafting.lua').matchAll(/name = '([A-Za-z0-9_]+)',\s*ingredients = \{([^}]*)\}/g)) {
  add(sources, m[1], 'workshop craft')
  for (const [i] of pairsOf(m[2])) add(uses, i, `craft ${m[1]}`)
}

const turf = som('som-turf/shared/config.lua')
for (const m of turf.matchAll(/(\w+) = \{ label = '[^']*', enabled = true, minutes = \d+,(?: minLevel = \d+,)?\s*inputs = \{([^}]*)\}, outputs = \{([^}]*)\}/g)) {
  for (const [i] of pairsOf(m[2])) add(uses, i, `lab ${m[1]}`)
  for (const [o] of pairsOf(m[3])) add(sources, o, `lab ${m[1]}`)
}
const sup = /supplier = \{[\s\S]*?stock = \{([^}]*)\}/.exec(turf)
if (sup) for (const [i, p] of pairsOf(sup[1])) add(sources, i, `chemical supplier ($${p})`)
for (const m of turf.matchAll(/(weed_\w+_seed) = \{ label = '[^']*', bag = '([^']+)'/g)) {
  add(uses, m[1], 'planting')
  add(sources, m[2], 'bagging weed buds')
}
add(sources, 'weedbud', 'harvesting plants')
add(uses, 'weedbud', 'bagging')
add(uses, 'empty_weed_bag', 'bagging')
add(uses, 'water_bottle', 'watering plants')
add(uses, 'weed_nutrition', 'feeding plants')

const out = som('som-outdoors/shared/config.lua')
for (const m of out.matchAll(/\{ item = '(\w+)', weight/g)) add(sources, m[1], 'fishing')
add(uses, 'fishingrod', 'fishing')
add(uses, 'fishbait', 'fishing')
for (const m of out.matchAll(/\{ '(\w+)', \d+, \d+, [\d.]+ \}/g)) add(sources, m[1], 'hunting')
add(uses, 'hunting_knife', 'hunting')
const chop = /parts = \{([\s\S]*?)\},\s*dropoffs/.exec(out)
if (chop) for (const m of chop[1].matchAll(/\{ '(\w+)', \d+, \d+ \}/g)) add(sources, m[1], 'chopping vehicles')
for (const b of out.matchAll(/(\w+) = \{\s*label = '[^']*', enabled = false, coords = (?:nil|vec3\([^)]*\)), distance = [\d.]+, hourlyCap = (\d+),\s*prices = \{([^}]*)\}/g)) {
  for (const [i, p] of pairsOf(b[3])) add(uses, i, `sold to the ${b[1]} buyer ($${p}, cap $${b[2]}/h)`)
}

for (const m of out.matchAll(/ore = '(\w+)', min = \d+/g)) add(sources, m[1], 'mining')
add(uses, 'pickaxe', 'mining')
for (const m of out.matchAll(/input = \{ (\w+) = \d+ \}, output = \{ '(\w+)', \d+ \}/g)) {
  add(uses, m[1], `smelting ${m[2]}`)
  add(sources, m[2], 'smelting')
}

const mech = som('som-mechanic/shared/config.lua')
for (const m of mech.matchAll(/item = '(\w+)', count = \d+/g)) add(uses, m[1], 'vehicle repairs')
const trade = /trade = \{[\s\S]*?items = \{([\s\S]*?)\},\s*\},/.exec(mech)
if (trade) for (const m of trade[1].matchAll(/(\w+) = \{ min = (\d+), max = (\d+) \}/g)) add(uses, m[1], `sold by mechanics ($${m[2]} to $${m[3]})`)

// Buy low, sell high: an item a shop sells for less than a buyer will pay is free money.
// Shops give the cheapest price; buyers give the best price they can reach (a market buyer at its ceiling).
const shopPrice = new Map()
for (const m of ox('data/shops.lua').matchAll(/name = '([A-Za-z0-9_]+)', price = (\d+)/g)) {
  shopPrice.set(m[1], Math.min(shopPrice.get(m[1]) ?? Infinity, Number(m[2])))
}
const buyerPrice = new Map()
const bid = (item, who, price) => {
  if (!buyerPrice.has(item) || buyerPrice.get(item).price < price) buyerPrice.set(item, { who, price })
}
let buyers = 0
// Any enabled state or coordinates: a buyer that is switched on in config must still be read.
for (const b of out.matchAll(/(\w+) = \{\s*label = '[^']*',[^{}]*?hourlyCap = \d+,[^{}]*?prices = \{([^}]*)\}/g)) {
  buyers++
  for (const [i, p] of pairsOf(b[2])) bid(i, `the ${b[1]} buyer`, p)
}
const eco = som('som-economy/shared/config.lua')
const ceiling = Number(/ceilingRatio = ([\d.]+)/.exec(eco)?.[1] ?? 1)
for (const m of eco.matchAll(/\{ '(\w+)',\s*'[^']*',\s*'\w+',\s*(\d+),/g)) bid(m[1], 'the market', Math.floor(Number(m[2]) * ceiling))
const bonus = Number(/ownerBonus = ([\d.]+)/.exec(turf)?.[1] ?? 0)
for (const m of turf.matchAll(/(\w+) = \{ label = '[^']*', base = (\d+) \}/g)) bid(m[1], 'a turf sale', Math.floor(Number(m[2]) * (1 + bonus)))

const findLoops = (shops, buyers) => [...buyers]
  .filter(([item, b]) => shops.has(item) && shops.get(item) < b.price)
  .map(([item, b]) => `${item}: a shop sells it for $${shops.get(item)} and ${b.who} pays up to $${b.price}`)

// The detector must catch a loop, and must have read real data, or a broken pattern above would let one through silently.
const probe = findLoops(new Map([['x', 5]]), new Map([['x', { who: 'a buyer', price: 6 }], ['y', { who: 'a buyer', price: 1 }]]))
if (probe.length !== 1 || findLoops(new Map([['x', 6]]), new Map([['x', { who: 'a buyer', price: 6 }]])).length) throw new Error('loop check is broken')
if (buyers < 5 || buyerPrice.size < 20 || shopPrice.size < 10) throw new Error(`loop check read too little (${shopPrice.size} shop items, ${buyers} buyers, ${buyerPrice.size} buyer items)`)
const loops = findLoops(shopPrice, buyerPrice)

const known = JSON.parse(readFileSync(join(root, 'tools', 'economy-known.json'), 'utf8'))
const dead = []
for (const [item, where] of uses) {
  const needs = [...where].some((w) => /craft|lab|planting|bagging|fishing|hunting|repairs|watering|feeding|sold/.test(w))
  if (needs && !sources.has(item) && !(item in known)) dead.push(`${item} (${[...where].join('; ')})`)
}

const names = [...new Set([...sources.keys(), ...uses.keys()])].sort()
const rows = names.map((n) => {
  const from = [...(sources.get(n) || [])].join('; ') || (known[n] ? `not yet: ${known[n]}` : '-')
  const to = [...(uses.get(n) || [])].join('; ') || '-'
  return `| \`${n}\` | ${from} | ${to} |`
})
const doc = [
  '# Economy map',
  '',
  'Generated by `node tools/economy-map.mjs` from the shop, crafting, lab, fishing, hunting, chopping and mechanic configs. Do not edit by hand. CI fails when an item that something needs has no source (known gaps are listed in `tools/economy-known.json`).',
  '',
  '| Item | Comes from | Goes to |',
  '|---|---|---|',
  ...rows,
  '',
].join('\n')

const file = join(root, 'ECONOMY-MAP.md')
if (process.argv.includes('--check')) {
  let bad = false
  if (dead.length) { console.error('Items needed but with no source:\n  ' + dead.join('\n  ')); bad = true }
  if (loops.length) { console.error('Buy low, sell high (a shop sells it for less than a buyer pays):\n  ' + loops.join('\n  ')); bad = true }
  if (!existsSync(file) || readFileSync(file, 'utf8') !== doc) { console.error('ECONOMY-MAP.md is stale: run node tools/economy-map.mjs'); bad = true }
  process.exit(bad ? 1 : 0)
}
writeFileSync(file, doc)
console.log(`${names.length} items mapped, ${dead.length} dead ends, ${loops.length} buy-low-sell-high loops`)
if (dead.length) console.log('  ' + dead.join('\n  '))
if (loops.length) console.log('  ' + loops.join('\n  '))
