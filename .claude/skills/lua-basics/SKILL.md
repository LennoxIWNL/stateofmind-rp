---
name: lua-basics
description: Lua 5.4 conventions for this repo's own code (local by default, early returns, FiveM literals, pitfalls found in tests).
---

# Lua basics

- `local` by default. Early return on failure. Config lives in `shared/config.lua`, logic elsewhere. Comments only where a line's purpose is non-obvious. No em dashes anywhere.
- FiveM allows backtick hash literals (`` `WEAPON_X` ``); `tools/check-lua.sh` swaps them for `0` before `luac -p`, so keep them out of anything else.
- `#vec3 - vec3` style distance: `#(a - b)` works in game; the test mocks implement `__sub` and `__len` on `vec3`.
- Integers: use `math.type(x) == 'integer'` or `tonumber(x)` plus `x % 1 == 0` to validate ids and counts from clients; strings that look numeric must not pass money checks.
- Patterns are not regex: escape `%`, and `[%c&&[^\n]]` is invalid. To strip control characters use `'[%z\1-\31\127]'`.
- `ipairs` stops at the first nil; use `pairs` for sparse tables and do not rely on `#` for tables with holes (tests that used slot keys of 100+ hit this).
- Never use globals except the deliberate resource tables (`Config`, `Turf`, `Buyer`, `Heists`). A typo'd name silently becomes nil.
- Run `lua5.4 tests/run.lua` and `tools/check-lua.sh` before every commit.
