# som-launder

Marked bills and the front that washes them.

## How it works

- **The ledger.** `exports['som-launder']:mintBills(source, worths, tag)` is how any
  server resource issues marked bills. It writes one `som_marked_bills` row per bill and
  gives the player one `markedbills` item per bill carrying only `{ uid, worth }`. Either
  every bill arrives or none do. The worth and status that count are the row's, never the
  item's metadata.
- **The front.** A desk (disabled until its coordinates are set). The player hands over
  bills, the server claims each one in the ledger (`UPDATE ... WHERE status = 'issued'`),
  takes the items, and queues an order that is ready after `Config.Wash.delayMinutes`
  by the database clock. Collecting claims the order, pays clean cash through `addMoney`,
  and marks the bills washed.
- **Throttles.** Laundering is where this money enters the economy, so it is limited:
  a cut (value that is never created), a per-citizen daily cap, a global hourly budget with
  a payout factor that falls as the hour fills, a bill count per order, and the delay.

## Why the ledger, not the item

An item can be duplicated by an inventory bug or forged by a modified client. Here a
duplicated bill shares a uid with its original, so it washes at most once, a made-up uid
does not exist, and a lying `worth` is ignored.

## Money accounting

Marked bills are goods, not a debit from any account: they are worth nothing until washed,
and the clean cash is created at the wash, the same way the market creates cash when a
player sells weed. It is a measured faucet for `som-economy`'s sink and faucet report.

## Known limits

- Seizing bills (status `seized`) by police is not built.
- No police alert when a wash happens, and no pause when police are near the front.
- Every front ships disabled; see `LAUNCH-TODO.md`.

## Prior art

Compared before writing: HasanAga69/FiveM-QBCore-Money-Wash (batch of up to 10 bills, a
10 minute cycle, 80 percent back), rumaier/r_moneywash (timed dynamic tax, cooldown),
Randolio/randol_moneywash (sums `info.worth` from the item), D40G/boii-moneylaunderer-qb
(cancel returns what was handed over, the front moves when service jobs are near),
tony041989/asr-advanced-moneywash (history, police alerts, daily limits listed),
gitfuzion/fz-moneywash (keycard requirement, timer grows with the amount),
s4t4n667/s4t4n667_moneywash, VoidHubScripts/vhs-moneywash and ScrachStack/qb-moneywash.
Most READMEs describe features without showing source, so validation could not be compared
line by line; the ones that read a bill's value from item metadata trust the client's
inventory, which this resource does not. Several are GPL or restrictive, so only ideas were taken.
