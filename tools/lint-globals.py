#!/usr/bin/env python3
"""Flags accidental globals in our Lua using luac's own bytecode listing.

Two checks, no dependencies beyond luac5.4:
  * a global WRITE to a lowercase name (the classic forgotten `local`, which
    leaks state between files; PascalCase names are module tables and allowed);
  * a global READ of a lowercase name that is not Lua or FiveM (a typo).
Known writes and reads live in the sets below. Run: python3 tools/lint-globals.py
"""
import re
import subprocess
import sys

ROOT = subprocess.check_output(['git', 'rev-parse', '--show-toplevel'], text=True).strip()
files = subprocess.check_output(
    ['git', 'ls-files', 'txData/*/resources/[[]som[]]/*.lua', 'tests/*.lua', 'tests/**/*.lua'],
    cwd=ROOT, text=True).split()
files = [f for f in files if not f.endswith('fxmanifest.lua')]

LUA = set('''assert collectgarbage error getmetatable ipairs load next pairs pcall print rawequal rawget rawlen
rawset require select setmetatable tonumber tostring type xpcall string table math os io utf8 coroutine debug
package arg dofile _G _ENV _VERSION unpack'''.split())
FIVEM = set('''exports lib source json vec vec3 vector3 vec4 vector2 vec2 joaat cache locale shared
MySQL Citizen msgpack Entity LocalPlayer Player GlobalState promise'''.split())
# Resource-level tables and test globals that are deliberately global.
WRITES = set('''Config Turf Buyer Heists Gangs Jobs Money Players Permissions Ledger Dispatch Bank Properties Phone
JobBoard Whitelist Mocks RegisteredCallbacks Handlers FakePeds Vehicles Animals Deleted Teleports PendingTimeouts
RegisteredEvents source'''.split())

pat = re.compile(r'\b(GETTABUP|SETTABUP)\b.*?_ENV "([A-Za-z_][A-Za-z0-9_]*)"')
bad = []
for f in files:
    try:
        src = open(f'{ROOT}/{f}', encoding='utf-8').read()
    except OSError:
        continue
    src = re.sub(r'`[^`]*`', '0', src)
    p = subprocess.run(['luac5.4', '-l', '-l', '-p', '-'], input=src, capture_output=True, text=True)
    if p.returncode != 0:
        continue
    seen = set()
    for line in p.stdout.splitlines():
        m = pat.search(line)
        if not m:
            continue
        kind, name = m.groups()
        if (kind, name) in seen:
            continue
        seen.add((kind, name))
        if kind == 'SETTABUP' and name not in WRITES and name[0].islower():
            bad.append(f'{f}: writes global "{name}" (missing local?)')
        elif kind == 'GETTABUP' and name[0].islower() and name not in LUA and name not in FIVEM and name not in WRITES:
            bad.append(f'{f}: reads unknown lowercase global "{name}"')
for b in bad:
    print(b)
print(f'{len(bad)} findings in {len(files)} files')
sys.exit(1 if bad else 0)
