#!/usr/bin/env node
// som-index: a tiny MCP server (stdio, no dependencies) that answers "does this
// export / event / table / item exist?" from the repo itself, so nothing is
// invented. Made by Lennox.
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs'
import { join, dirname, relative } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createInterface } from 'node:readline'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
const BASE = readdirSync(join(ROOT, 'txData')).map((d) => join(ROOT, 'txData', d)).find((d) => existsSync(join(d, 'resources')))
const RES = join(BASE, 'resources')
const SOM = join(RES, '[som]')

function* walk(dir) {
  for (const name of readdirSync(dir)) {
    if (name === 'node_modules' || name === 'html') continue
    const p = join(dir, name)
    const st = statSync(p)
    if (st.isDirectory()) yield* walk(p)
    else if (name.endsWith('.lua')) yield p
  }
}

const lines = (file) => readFileSync(file, 'utf8').split('\n')
const rel = (p) => relative(ROOT, p)

function scan(re, dir = SOM) {
  const out = []
  for (const f of walk(dir)) {
    lines(f).forEach((l, i) => { const m = re.exec(l); if (m) out.push({ file: rel(f), line: i + 1, text: l.trim().slice(0, 140), m }) })
  }
  return out
}

const tools = {
  find_export: {
    description: 'Where an export is defined (exports("name", ...)) and where it is called (exports["res"]:name / core:name).',
    schema: { name: 'string' },
    run: ({ name }) => {
      const esc = name.replace(/[^A-Za-z0-9_]/g, '')
      const defs = scan(new RegExp(`exports\\(\\s*['"]${esc}['"]`)).map(({ file, line }) => `${file}:${line}`)
      const calls = scan(new RegExp(`(exports\\[['"][^'"]+['"]\\]|exports\\.[A-Za-z_]+|\\bcore):${esc}\\b`)).map(({ file, line }) => `${file}:${line}`)
      return { defined: defs, calledFrom: calls.slice(0, 25), exists: defs.length > 0 }
    },
  },
  list_exports: {
    description: 'Every export a resource under [som] defines.',
    schema: { resource: 'string' },
    run: ({ resource }) => {
      const dir = join(SOM, resource.replace(/[^A-Za-z0-9_-]/g, ''))
      if (!existsSync(dir)) return { error: 'no such resource' }
      return scan(/exports\(\s*['"]([A-Za-z0-9_]+)['"]/, dir).map((r) => ({ export: r.m[1], at: `${r.file}:${r.line}` }))
    },
  },
  find_event: {
    description: 'Net events and lib.callbacks matching a substring.',
    schema: { text: 'string' },
    run: ({ text }) => scan(/(RegisterNetEvent|lib\.callback\.register|AddEventHandler)\(\s*['"]([^'"]+)['"]/)
      .filter((r) => r.m[2].includes(text)).slice(0, 40).map((r) => ({ kind: r.m[1], name: r.m[2], at: `${r.file}:${r.line}` })),
  },
  table_columns: {
    description: 'Columns of a table as declared in setup.sql.',
    schema: { table: 'string' },
    run: ({ table }) => {
      const sql = readFileSync(join(ROOT, 'setup.sql'), 'utf8')
      const m = new RegExp('CREATE TABLE IF NOT EXISTS `' + table.replace(/[^A-Za-z0-9_]/g, '') + '` \\(([\\s\\S]*?)\\) ENGINE').exec(sql)
      if (!m) return { error: 'no such table in setup.sql' }
      return m[1].split('\n').map((l) => l.trim()).filter((l) => l.startsWith('`')).map((l) => l.replace(/,$/, ''))
    },
  },
  item_info: {
    description: 'Whether an ox_inventory item exists and whether it has an icon.',
    schema: { name: 'string' },
    run: ({ name }) => {
      const ox = join(RES, '[standalone]', 'ox_inventory')
      const safe = name.replace(/[^A-Za-z0-9_]/g, '')
      const items = readFileSync(join(ox, 'data', 'items.lua'), 'utf8')
      const exists = new RegExp(`\\['${safe}'\\]\\s*=`).test(items)
      return { exists, icon: existsSync(join(ox, 'web', 'images', `${safe}.png`)) }
    },
  },
}

const send = (msg) => process.stdout.write(JSON.stringify({ jsonrpc: '2.0', ...msg }) + '\n')

export function handle(req) {
  if (req.method === 'initialize') {
    return { id: req.id, result: { protocolVersion: req.params?.protocolVersion || '2024-11-05', capabilities: { tools: {} }, serverInfo: { name: 'som-index', version: '0.1.0' } } }
  }
  if (req.method === 'tools/list') {
    return {
      id: req.id,
      result: {
        tools: Object.entries(tools).map(([name, t]) => ({
          name, description: t.description,
          inputSchema: { type: 'object', properties: Object.fromEntries(Object.entries(t.schema).map(([k, v]) => [k, { type: v }])), required: Object.keys(t.schema) },
        })),
      },
    }
  }
  if (req.method === 'tools/call') {
    const t = tools[req.params?.name]
    if (!t) return { id: req.id, error: { code: -32602, message: 'unknown tool' } }
    const args = req.params.arguments || {}
    for (const k of Object.keys(t.schema)) if (typeof args[k] !== 'string' || !args[k]) return { id: req.id, error: { code: -32602, message: `${k} must be a non-empty string` } }
    return { id: req.id, result: { content: [{ type: 'text', text: JSON.stringify(t.run(args), null, 1) }] } }
  }
  if (req.id !== undefined) return { id: req.id, error: { code: -32601, message: 'method not found' } }
  return null
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  createInterface({ input: process.stdin }).on('line', (line) => {
    if (!line.trim()) return
    let req
    try { req = JSON.parse(line) } catch { return send({ id: null, error: { code: -32700, message: 'parse error' } }) }
    const res = handle(req)
    if (res) send(res)
  })
}
