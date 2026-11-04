#!/usr/bin/env bash
# Syntax check for our own Lua (resources/[som] and tests). FiveM allows
# backtick hash literals (`WEAPON_X`), which plain Lua rejects, so they are
# swapped for 0 before parsing. Third-party resources are not checked.
set -u
cd "$(dirname "$0")/.."
command -v luac5.4 >/dev/null || { echo "luac5.4 not found (apt-get install lua5.4)"; exit 2; }

fail=0
while IFS= read -r f; do
  if ! sed -E 's/`[^`]*`/0/g' "$f" | luac5.4 -p - 2>/tmp/check-lua.err; then
    echo "FAIL $f: $(head -1 /tmp/check-lua.err)"
    fail=1
  fi
done < <(git ls-files 'txData/*/resources/[[]som[]]/*.lua' 'tests/*.lua' 'tests/**/*.lua')

exit $fail
