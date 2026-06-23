# State of Mind RP — Security Audit (Task #9)

**Date:** 2026-06-23
**Scope:** All resources under `txData/FiveMBasicServerCFXDefault_3A7DA0.base/resources`
**Method:** Static scan for remote code loaders, HTTP exfiltration, shell/RCE,
obfuscated/encoded payloads, leak/sabotage markers, escrow & bytecode files,
and privilege-escalation backdoors.

## TL;DR

**No active backdoor or malware was found in the plain-text code.** This is a
standard leaked Origen V2 base: the resources phone home only for version
checks (to their own authors' GitHub repos) and optional Discord webhook
logging that *you* configure. Nothing exfiltrates player identifiers, license
keys, or server info to an unknown third party.

The one genuinely **critical** issue is operational, not code: **secrets were
committed to the GitHub repo history** (see Finding C1).

---

## Findings

### C1 — CRITICAL: Secrets committed to GitHub history
- **Where:** commit `6c0f4f8` ("initial GitHub push") on `github.com/LennoxIWNL/stateofmind-rp`
- **What:** The initial push committed the entire server tree, including:
  - `Server/server-tls.key`, `Server/server-tls.crt`, `Server/server-monitor-token.key`
  - `txData/admins.json` (txAdmin master account `bcrypt` password hash + identifiers)
  - `server.cfg` containing `sv_licenseKey "cfxk_..."` and the MySQL connection string
- **Impact:** Phase 0 untracked these going forward, but they **remain in git history**
  and are already on GitHub. Anyone with repo access can read them.
- **Recommendation (do this now):**
  1. **Rotate the FiveM license key** at https://keymaster.fivem.net (revoke the old one).
  2. **Change the txAdmin master password** (invalidates the leaked hash).
  3. **Regenerate the server TLS cert/key + monitor token** (delete the files; txAdmin
     recreates them on next boot).
  4. If the repo is/was public, **purge history** with `git filter-repo` or BFG, then
     force-push. (Destructive — coordinate before doing this since the VM pulls from it.)

### W1 — BC_Wounding is escrow-protected (unauditable)
- **Path:** `[new]/BC_Wounding/.fxap`
- **What:** The only FiveM-escrow (`.fxap`) resource in the base. Its Lua is encrypted
  and cannot be statically audited. It is a known paid wounding script (legitimate
  product), but you cannot verify this copy's integrity without running it.
- **Note:** This is also the source of the Task #3 error (`No such export ResetAll`).
  The export call will be made self-contained in Phase A so the server does not depend
  on this resource at all. Consider not ensuring BC_Wounding unless you own a license.
- **Recommendation:** Leave un-ensured / patch the dependency out (Phase A). No evidence
  of malice, but treat any escrow resource you didn't buy as unverified.

### W2 — "Leaked by TC Leaks" watermark
- **Path:** `[jobs]/[chopshop]/elixir-thermite/fxmanifest.lua`, `client/main.lua`
- **What:** Comment banners reading `-- LEAKED BY TC LEAKS`. Cosmetic watermark from a
  leak distributor; **no malicious code** accompanies it in the scanned files.
- **Recommendation:** Patch (delete the comment lines) — harmless but confirms provenance.
  No removal of the resource required.

### I1 — Version-check / telemetry phone-homes (benign)
These make outbound GET requests on startup to check for updates or fetch assets.
All target the resource author's own repo or a known API. None send player data.
- `ox_lib` → `api.github.com` (releases) + optional Datadog logger
  (`http-intake.logs.*`, **off unless you set the `datadog` convar**)
- `jim_bridge`, `jim-notepad` → `raw.githubusercontent.com/jimathy/...` (version.txt)
- `cdn-fuel`, `kloud-farmjob`, `kloud-food-delivery` → `raw.githubusercontent.com/.../version`
- `2na_core` → `api.github.com/repos/tunasayin/2na_core` (version)
- `r14-evidence` → `raw.githubusercontent.com/regalonefour/...` (version)
- `loaf_lib` → `loaf-scripts.com/versions/` (version) + `steamcommunity.com` (avatar scrape)
- `qb-crypto` → `min-api.cryptocompare.com` (crypto prices — required for the feature)
- `qb-weathersync` → `worldtimeapi.org` (in-game time sync)
- **Recommendation:** Safe to leave. If you want zero outbound noise, the version-check
  blocks can be commented out later; not required.

### I2 — Configurable Discord webhook logging (benign, expected)
These POST to Discord webhooks **you** set in their configs (empty/placeholder by
default). They are the legitimate log channels — see Task #13 checklist.
- `qb-smallresources/server/logs.lua` (qb-core central logger)
- `loaf_lib/server/functions/logs.lua`
- `randol_billing`, `dream-postal`, `cs_fscanner`, `jim-notepad`, `r14-evidence`,
  `BakiTelli_hackermenu`, `jim-mechanic` (commented), `karma-reportsystem` (commented)

### I3 — `ExecuteCommand` usage (all legitimate)
No client-controlled shell/RCE. Notable patterns reviewed and cleared:
- `qb-core/server/functions.lua` + `commands.lua` — the QBCore ACE/principal permission
  system (`add_principal`/`add_ace`). This is core framework behavior, not a backdoor.
- `qb-target`, `qb-menu`, `qb-radialmenu`, `ps-adminmenu` — `ExecuteCommand(data.event)`
  runs **client-side** menu commands from server/config-defined menus (standard QB).
- `pma-voice`, `elixir-chat` — radio/chat command passthrough.

## What was checked and came back clean
- Lua bytecode files (`\x1bLua` / LuaJIT headers): **none** — all Lua is plain text.
- Remote Lua/JS loaders (`load(PerformHttpRequest…)`, `loadstring`, `RunString`): only
  legitimate uses (template engine, jim_bridge loading ox_core imports).
- `os.execute` / `io.popen`: only `ox_doorlock` listing a directory (standard Overextended).
- Base64/hex blobs decoding to URLs/commands: **none** found in Lua.
- Server-side Node `child_process` / `eval` / `node-fetch` / `axios`: only minified NUI
  front-end bundles (jQuery/Vue/etc.) and the cfx `yarn` builder — none run server-side.
- Leak/sabotage markers (`P4B4hYUujN`, "your server might be affected by leaks"): **none**
  (only the cosmetic TC Leaks watermark in W2).

---

## Action items
- [ ] **C1**: Rotate license key, txAdmin password, TLS cert/token (do this regardless of everything else).
- [ ] **C1**: Decide whether to purge git history of the secrets/binaries already pushed.
- [ ] **W1**: Keep BC_Wounding un-ensured; dependency patched out in Phase A.
- [ ] **W2**: (optional) strip leak watermark comments from elixir-thermite.
