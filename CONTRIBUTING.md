# Contributing

This repo is a FiveM server. Each server auto-pulls its branch on push:
the beta server runs `BetaRelease`, the live server runs `main`. Both must
always boot.

## Branches

Two long-lived branches: `BetaRelease` (all work lands here and is tested)
and `main` (production, receives only `BetaRelease` after a beta pass).
Everything else is short-lived, cut from `BetaRelease`, and named for what it
does:

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

1. Branch from an up-to-date `BetaRelease`.
2. Read `CLAUDE.md` (the rules) and the relevant `AUDIT.md` section.
3. Keep the change to one logical unit. Add or extend tests for anything that
   touches money, ownership, sentencing or other persistence.
4. Run the checks locally (below).
5. Open a PR into `BetaRelease`. CI must pass. Merge, then delete the branch.

## Promoting to production

When the beta server has passed the in-game checklist in the PRs, the owner
opens a PR from `BetaRelease` into `main` and merges it with a merge commit
(not squash), so the branches never diverge. If production needs a fix before
the next promotion, open the `fix/` PR into `main` and merge `main` back into
`BetaRelease` straight after.

Never push directly to `BetaRelease` or `main` and never force-push either.

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
