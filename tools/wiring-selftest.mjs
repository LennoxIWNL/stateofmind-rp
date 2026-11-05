import { spawnSync } from 'node:child_process'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import assert from 'node:assert/strict'

const here = dirname(fileURLToPath(import.meta.url))
const r = spawnSync('node', [join(here, 'wiring-check.mjs')], { env: { ...process.env, WIRING_FIXTURE: join(here, 'wiring-fixture') }, encoding: 'utf8' })
assert.equal(r.status, 1, 'the fixture must fail the check')
for (const bad of ['missingExport', 'alsoMissing', 'other:server:nope', 'som:client:nobody', 'som_missing', 'fakeitem']) assert.ok(r.stdout.includes(bad), `expected a finding for ${bad}`)
for (const good of ['realExport', 'other:server:real', 'other:client:real', 'som_real', 'realitem']) assert.ok(!r.stdout.includes(good), `unexpected finding for ${good}`)
console.log('wiring-check selftest ok')
