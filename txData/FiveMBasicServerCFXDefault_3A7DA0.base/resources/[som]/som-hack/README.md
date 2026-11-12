# som-hack

Hacking challenges whose answer the server holds and checks.

## Why not a normal minigame

Every FiveM hacking minigame found reports its result from the client (`gameFinished {result}`,
a boolean callback, a returned `true`). A modified client can send "won" without playing, so a
heist that waits on one can be skipped. Here the puzzle lives on the server:

- `Hack.Begin` returns a token and the view the player needs. For **memory** the numbers are
  necessarily visible (the player has to memorise them). For **crack** the code never leaves the
  server; the page only ever receives per-digit feedback.
- `Hack.Submit` (memory) and `Hack.Guess` (crack) are single use per challenge, bound to the
  player, expire after `Config.ExpireMs`, and enforce a floor on how fast a person can answer.
- `exports['som-hack']:run(source, kind, level)` waits for the player and returns a boolean
  **read from the server's own record**, not from anything the client returned. It must be
  called from a thread, since it waits.

A puzzle shown on a screen can still be solved by a bot. This stops skipping, repeating and
lying about the result, not automation.

## Kinds

- `memory` (`easy`, `normal`, `hard`): numbers appear on some cells, are hidden, and the player
  picks the cells in ascending number order. A correct answer sent before the show time plus a
  per-pick floor has elapsed is wrong.
- `crack` (`easy`, `normal`, `hard`): guess a digit code. Each guess returns `hit`, `near` or
  `miss` per digit, scored like Mastermind (a digit the code has once cannot score twice), with an
  attempt limit and a gap between guesses.

## Prior art

Compared before writing: MrKnights1/fivem-minigames (ten minigames, NUI `start` and
`gameFinished` messages, client reported), JoeSzymkowiczFiveM/varhack and casinohack (the
NoPixel VAR shape, a boolean callback), dnelyk/Hacking_Minigames, kieranirving/hacking-minigame,
utkuali/datacrack, utk_hackdependency (on disk), cdt_marketrobbery_light's dial safe, and
qb-bankrobbery, whose thermite check is the one server-side consumption in that script. The
pattern shapes were taken as ideas; none of the code was, since several are GPL or of unclear origin.

## Known limits

- Two kinds only. A dial or drill game can be added as another kind with its own server rules.
- The page is checked by the NUI harness (`tests/nui/run.mjs`) in headless Chromium, never in the game.
