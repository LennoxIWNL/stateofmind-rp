# Contributing

This repo is a FiveM server. `main` is what the VPS runs: a push to `main`
triggers an automatic pull on the live server, so `main` must always boot.

## Branches

One long-lived branch (`main`), everything else short-lived and named for what
it does:

| Prefix | Use | Example |
|---|---|---|
| `feature/` | new gameplay or system | `feature/jail-and-bail-system` |
| `fix/` | an isolated bug fix | `fix/housing-double-sale` |
| `chore/` | tooling, config, CI, cleanup | `chore/repo-workflow-setup` |
| `docs/` | documentation only | `docs/roadmap-refresh` |

Use lowercase kebab-case. The name describes the work, nothing else: no
personal names, no tool or session identifiers. Delete the branch after it is
merged.

## Making a change

1. Branch from an up-to-date `main`.
2. Read `CLAUDE.md` (the rules) and the relevant `AUDIT.md` section.
3. Keep the change to one logical unit. Add or extend tests for anything that
   touches money, ownership, sentencing or other persistence.
4. Run the checks locally (below).
5. Open a PR into `main`. CI must pass. Merge, then delete the branch.

Never push directly to `main` and never force-push it.

## Commits

Short imperative subject, then a body that says why. Commit as the repo
owner. Do not add co-author, tool, AI or session lines to commits, PR titles
or PR descriptions.

## Checks

```bash
sudo apt-get install -y lua5.4            # once
lua5.4 tests/run.lua                      # server Lua against mocked FiveM
node tests/nui/run.mjs                    # NUI in headless Chromium (needs playwright)
tools/check-lua.sh                        # syntax check our Lua
```

CI runs the same checks plus a scan for committed Discord webhook URLs.

## Schema changes

`setup.sql` is the single schema source of truth. Add new tables in a lettered
section next to the feature they belong to, make them safe to re-run
(`CREATE TABLE IF NOT EXISTS`), and note in the PR that the live database
needs the new section imported before the resource starts.

## Secrets

Never commit tokens, passwords or webhook URLs. Put them in `server.cfg`
(gitignored) and read them with `GetConvar`; document the convar in
`txData/FiveMBasicServerCFXDefault_3A7DA0.base/server.cfg.example`.
