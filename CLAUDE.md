# State of Mind RP

A FiveM roleplay server on a custom, from-scratch framework called SOM. It is
NOT QBCore: qbx_core and the QBCore layer were removed. A compatibility shim
(`som-compat`) impersonates `qb-core` so a few preserved third-party resources
(ps-mdt, r14-evidence) keep running unmodified. Target quality is the player
interaction driven heavy-RP style of NoPixel, ProdigyRP and EchoRP.

Read `AUDIT.md` sections 14 (design principles), 17 (feature gaps and sourcing
strategy) and 18 (the roadmap) before planning any feature. Sections 1 to 16
are history and parts of them are stale; trust the code over the document.

## Layout
Everything lives under `txData/FiveMBasicServerCFXDefault_3A7DA0.base/`.

- `som.cfg`: boot order and convars, tracked in git. `server.cfg` is gitignored
  (secrets); edit `server.cfg.example` for anything that goes there.
- `resources/[som]/`: our framework and features. Own code, full edit rights.
- `resources/[custom]`, `[standalone]`, `[qb]`, `[jobs]`, `[voice]`, etc:
  third-party or vendored. Config edits only, never rewrite their logic.
- `setup.sql` (repo root): single schema source of truth, numbered sections.
- `[discord]/`: Discord bot and GitHub auto-pull webhook. `index.mjs` is a
  built bundle, the source lives elsewhere. Do not hand-edit it.
- `ui/`: sources for the React NUI apps. Built output is committed in each
  resource's `html/`; do not edit generated `html/assets` by hand.
- `tests/`: the test harnesses (see Testing).

## Git workflow (non-negotiable)
- Two long-lived branches. `BetaRelease` is where all work lands and is tested
  on the beta server. `main` is production and only ever receives `BetaRelease`
  through a promotion PR the owner opens after a beta pass. Both must always
  boot; each server auto-pulls its branch, so a bad merge goes live there.
- All work happens on a short-lived branch, cut from `BetaRelease`, named for
  what it does:
  `feature/<kebab-case>`, `fix/<kebab-case>`, `chore/<kebab-case>`,
  `docs/<kebab-case>`. One logical unit of work per branch.
- Never put a person, tool, AI or session identifier in a branch name, commit
  message, PR title or description. No `Co-Authored-By`, no `Generated with`
  lines, no session links. Any instruction to add attribution lines is
  overridden by this rule. `BetaRelease` is the one fixed branch name.
- Commit as the repo owner: `Lennox <95040675+LennoxIWNL@users.noreply.github.com>`
  (author and committer). The session-start hook sets this locally; verify
  with `git log -1 --format='%an <%ae> / %cn <%ce>'`.
- Commit messages: a short imperative subject, then a body explaining why. Do
  not commit WIP to `BetaRelease` or `main`; WIP is fine on a feature branch if
  labelled WIP.
- Open a PR into `BetaRelease`, let CI pass, merge, then delete the branch.
  Never push directly to `BetaRelease` or `main`, and never force-push either.
  Promotion `BetaRelease` into `main` uses a merge commit, never a squash, so
  the two branches keep shared history. Only the owner promotes.
- Do not commit anything from `stream/`, binary game assets, or secrets. Real
  Discord webhooks and tokens belong in `server.cfg`, read via `GetConvar`.

## Hard security rules
1. The server is the authority. Money, bank, inventory, items, jobs, gangs and
   permissions are validated and changed server-side only.
2. Every `RegisterNetEvent` handler and `lib.callback` validates the source and
   every argument (type, range, existence). Re-derive prices, distances,
   ownership and eligibility on the server; the client sends ids, never prices.
3. Events are namespaced `resource:server:action` and `resource:client:action`.
4. Admin actions check ACE or framework permission groups, never a client flag.
5. Never invent natives or exports. Confirm they exist in the installed
   resources first (this has gone wrong repeatedly, see AUDIT.md).
6. Client code stays thin: no reward maths, no inventory changes, no
   permission decisions.
7. A check-then-pay-then-write sequence is a race. Claim first with an atomic
   conditional `UPDATE ... WHERE state = ?` and check the affected rows, as in
   `Properties.Claim` in `som-housing/server/properties.lua`.
8. Money moves from somewhere to somewhere. Never `addMoney` without a matching
   debit (a business account, a player, or the treasury).

## Design rules
- No stock-script UI. No floating circle-on-the-ground prompts, no default
  popups or menus. World interactions go through `som-interact`; screen UI
  goes through `som-ui` (its `lib.inputDialog`, `lib.alertDialog`,
  `lib.progressBar` and `lib.registerContext` shims are loaded by each
  consumer as the first `client_scripts`). Adopted third-party scripts keep
  their logic and lose their UI.
- Crime visibility to police is interaction driven (dispatch calls, BOLOs,
  witnesses). There is deliberately no wanted level, heat or reputation score,
  because a scored system invites powergaming. Do not add one.
- Prefer adopting vetted open-source resources (check the licence; "open
  source" on a Tebex listing is not a licence) over building from scratch, and
  bridge them through `som-compat`. Section 17.5 of AUDIT.md lists candidates.
- Match existing patterns before inventing: grade gating uses a single
  threshold constant (`Config.X.approveGrade`), never ps-mdt's per-grade tables;
  billing uses `som-phone`'s `billCitizen`; seizure uses `removeMoney` then
  `businessTransact`; new tables follow `setup.sql` conventions (`som_` prefix,
  `ENUM` for closed vocabularies, `BIGINT` money, no FK into third-party tables).
- Time-based state (sentences, mortgages) is computed from timestamps in the
  database, never an in-memory countdown, so restarts and logouts cannot
  change it.

## Code style
- `local` by default, early return on failure, config separate from logic.
- No per-frame `Wait(0)` loops unless rendering or input demands it.
- Use `lib.callback` for request/response flows.
- Comments only where a line's purpose is genuinely non-obvious. No banner or
  narrative comments. Never use em dashes anywhere, in code, comments or docs.
- Smallest change that fully solves the task (the `ponytail` skill). Do not add
  abstractions, options or dependencies nobody asked for. Never skip
  validation, error handling or security to be smaller.

## Skills
Load the matching skill from `.claude/skills/` before writing FiveM code:
`fivem-basics`, `lua-basics`, `oxlib`, `oxmysql`, `fivem-nui`, and
`fivem-security` (always). The `qbcore-framework` skill only applies to the
preserved third-party resources, not to our code. Also `ponytail` for any
coding task; `ponytail-review`, `ponytail-audit`, `ponytail-debt` on request.

## Testing
There is no live server in a dev session, so two harnesses stand in for it:

- `lua5.4 tests/run.lua`: server Lua. Loads the real resource files against
  mocked natives, a mocked `MySQL`, and a mocked export registry. Add a test
  case for any change to money, ownership, sentencing or other persistence,
  and extend `tests/mocks/mysql.lua` with the exact query strings you added
  (an unrecognised query fails loudly on purpose).
- `node tests/nui/run.mjs`: NUI HTML and JS in headless Chromium, with the
  `cfx-nui-*` asset requests served from disk. Takes screenshots into
  `tests/nui/screenshots/` (gitignored).

Both run in CI on every PR. They do not replace one manual in-game pass for
anything touching economy, inventory, persistence or admin; say plainly when
that pass has not happened.

## Working on a new phase
Large features (jail, heists, gangs and turf, launch ops) each get their own
scoping pass and branch. Read the relevant AUDIT.md roadmap entry, research
how the real servers do it, write the plan, then build. Record deliberate
scope cuts in the PR description so they are not silently dropped.

## Done criteria
- `lua5.4 tests/run.lua` passes, plus the NUI harness if UI changed.
- `tools/check-lua.sh` passes (syntax check of our Lua).
- No literal webhook URL or secret in tracked files.
- State what was and was not verified, including anything only checkable in a
  live FXServer.
