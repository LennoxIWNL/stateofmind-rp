import assert from 'node:assert/strict'
import { handle } from './index.mjs'

const call = (name, args) => JSON.parse(handle({ id: 1, method: 'tools/call', params: { name, arguments: args } }).result.content[0].text)

assert.ok(handle({ id: 1, method: 'tools/list' }).result.tools.length >= 5)
assert.equal(call('find_export', { name: 'treasuryTransact' }).exists, true)
assert.equal(call('find_export', { name: 'mintBills' }).exists, true)
assert.equal(call('find_export', { name: 'definitelyNotAnExport' }).exists, false)
assert.ok(call('list_exports', { resource: 'som-core' }).some((e) => e.export === 'gangTransact'))
assert.ok(call('find_event', { text: 'som-turf:server:sell' }).length >= 1)
assert.ok(call('table_columns', { table: 'som_heist_runs' }).some((c) => c.startsWith('`site`')))
assert.equal(call('item_info', { name: 'meth' }).exists, true)
assert.equal(call('item_info', { name: 'coke_leaf' }).icon, true)
assert.equal(call('item_info', { name: 'nopeitem' }).exists, false)
assert.ok(handle({ id: 2, method: 'tools/call', params: { name: 'find_export', arguments: {} } }).error)
console.log('som-index selftest ok')
