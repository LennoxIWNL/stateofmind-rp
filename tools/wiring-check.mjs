#!/usr/bin/env node
// Finds wiring mistakes the mock tests cannot: calls to exports, callbacks,
// events, SQL tables and items that nothing defines. Run: node tools/wiring-check.mjs
// Known, reviewed exceptions live in tools/wiring-known.json (name -> reason).
// Made by Lennox.
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs'
import { join, dirname, relative } from 'node:path'
import { fileURLToPath } from 'node:url'

const repo = join(dirname(fileURLToPath(import.meta.url)), '..')
// WIRING_FIXTURE points at a tiny fake tree, used only by the self-test.
const root = process.env.WIRING_FIXTURE || repo
const base = process.env.WIRING_FIXTURE
  ? join(root, 'base')
  : readdirSync(join(root, 'txData')).map((d) => join(root, 'txData', d)).find((d) => existsSync(join(d, 'resources')))
const SOM = join(base, 'resources', '[som]')
const knownFile = join(repo, 'tools', 'wiring-known.json')
const known = !process.env.WIRING_FIXTURE && existsSync(knownFile) ? JSON.parse(readFileSync(knownFile, 'utf8')) : {}

function* walk(dir) {
  for (const name of readdirSync(dir)) {
    if (name === 'node_modules' || name === 'html') continue
    const p = join(dir, name)
    if (statSync(p).isDirectory()) yield* walk(p)
    else if (name.endsWith('.lua') && !name.endsWith('fxmanifest.lua')) yield p
  }
}

const files = [...walk(SOM)].map((f) => ({ f, rel: relative(root, f), src: readFileSync(f, 'utf8'), res: relative(SOM, f).split(/[\\/]/)[0] }))
const strip = (s) => s.replace(/--\[\[[\s\S]*?\]\]/g, '').replace(/--[^\n]*/g, '')
for (const x of files) x.code = strip(x.src)

const findings = []
const report = (key, rel, text) => { if (!(key in known)) findings.push(`${rel}: ${text}`) }

// Exports defined by each own resource.
const defined = new Map()
for (const x of files) for (const m of x.code.matchAll(/\bexports\(\s*['"]([A-Za-z0-9_]+)['"]/g)) {
  if (!defined.has(x.res)) defined.set(x.res, new Set())
  defined.get(x.res).add(m[1])
}
// Resources that provide one export to a Mocks-style registry or to ox hooks are not own exports.
// som-interact (and similar) export a whole table in a loop: every `function T.name` counts.
for (const x of files) if (/for\s+\w+\s*,\s*\w+\s+in\s+pairs\((\w+)\)\s+do\s+exports\(/.test(x.code)) {
  const t = /for\s+\w+\s*,\s*\w+\s+in\s+pairs\((\w+)\)\s+do\s+exports\(/.exec(x.code)[1]
  for (const m of x.code.matchAll(new RegExp(`function\\s+${t}\\.([A-Za-z0-9_]+)`, 'g'))) {
    if (!defined.has(x.res)) defined.set(x.res, new Set())
    defined.get(x.res).add(m[1])
  }
}
const ownResources = new Set(files.map((x) => x.res))

for (const x of files) {
  // Aliases: local core = exports['som-core']
  const alias = new Map()
  for (const m of x.code.matchAll(/local\s+([A-Za-z_]\w*)\s*=\s*exports\[['"]([\w-]+)['"]\]/g)) alias.set(m[1], m[2])
  const calls = []
  for (const m of x.code.matchAll(/exports\[['"]([\w-]+)['"]\]:([A-Za-z_]\w*)\s*\(/g)) calls.push([m[1], m[2]])
  for (const m of x.code.matchAll(/exports\.([\w]+):([A-Za-z_]\w*)\s*\(/g)) calls.push([m[1], m[2]])
  for (const [name, res] of alias) for (const m of x.code.matchAll(new RegExp(`\\b${name}:([A-Za-z_]\\w*)\\s*\\(`, 'g'))) calls.push([res, m[1]])
  for (const [res, fn] of calls) {
    if (!ownResources.has(res)) continue
    if (!defined.get(res)?.has(fn)) report(`export:${res}:${fn}`, x.rel, `calls export ${res}:${fn} which ${res} does not define`)
  }
}

// Callbacks: every await needs a register.
const registered = new Set()
for (const x of files) for (const m of x.code.matchAll(/lib\.callback\.register\(\s*['"]([^'"]+)['"]/g)) registered.add(m[1])
for (const x of files) for (const m of x.code.matchAll(/lib\.callback(?:\.await)?\(?\s*['"]?/g)) void m
for (const x of files) for (const m of x.code.matchAll(/lib\.callback\.await\(\s*['"]([^'"]+)['"]/g)) {
  if (!registered.has(m[1])) report(`callback:${m[1]}`, x.rel, `awaits callback "${m[1]}" that nobody registers`)
}

// Events: own-namespace trigger needs a handler somewhere.
const handled = new Set()
for (const x of files) for (const m of x.code.matchAll(/(?:RegisterNetEvent|AddEventHandler|RegisterServerEvent)\(\s*['"]([^'"]+)['"]/g)) handled.add(m[1])
for (const x of files) for (const m of x.code.matchAll(/Trigger(?:Client|Server)Event\(\s*['"]([^'"]+)['"]/g)) {
  const n = m[1]
  if (!/^(som|som-[\w]+)[:]/.test(n) && !/^som:/.test(n)) continue
  if (!handled.has(n)) report(`event:${n}`, x.rel, `triggers event "${n}" that nothing handles`)
}

// SQL tables.
const setup = readFileSync(join(root, 'setup.sql'), 'utf8')
const tables = new Set([...setup.matchAll(/CREATE TABLE IF NOT EXISTS `([a-z0-9_]+)`/g)].map((m) => m[1]))
for (const x of files) for (const m of x.code.matchAll(/\b(?:FROM|INTO|UPDATE|JOIN)\s+(som_[a-z0-9_]+)/gi)) {
  if (!tables.has(m[1].toLowerCase())) report(`table:${m[1]}`, x.rel, `uses table ${m[1]} that setup.sql does not create`)
}

// Item literals.
const items = readFileSync(join(base, 'resources', '[standalone]', 'ox_inventory', 'data', 'items.lua'), 'utf8')
const weapons = existsSync(join(base, 'resources', '[standalone]', 'ox_inventory', 'data', 'weapons.lua')) ? readFileSync(join(base, 'resources', '[standalone]', 'ox_inventory', 'data', 'weapons.lua'), 'utf8') : ''
const itemKnown = (n) => new RegExp(`\\['${n}'\\]\\s*=`).test(items) || new RegExp(`\\['${n}'\\]\\s*=`).test(weapons) || new RegExp(`\\b${n}\\s*=\\s*\\{`).test(weapons)
for (const x of files) {
  if (x.rel.includes('/tests/')) continue
  for (const m of x.code.matchAll(/(?:AddItem|RemoveItem|Search)\(\s*[\w.]+\s*,\s*(?:'(?:slots|count)'\s*,\s*)?['"]([A-Za-z0-9_]+)['"]/g)) {
    if (m[1] === 'slots' || m[1] === 'count') continue
    if (!itemKnown(m[1])) report(`item:${m[1]}`, x.rel, `uses item "${m[1]}" that ox_inventory does not define`)
  }
}

findings.sort()
for (const f of findings) console.log(f)
console.log(`${findings.length} wiring findings in ${files.length} files`)
process.exit(findings.length ? 1 : 0)
