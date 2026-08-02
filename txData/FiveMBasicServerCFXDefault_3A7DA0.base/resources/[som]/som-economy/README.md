# som-economy

Market saturation, the business register, government departments, and fines.

Phase 4. Depends on `som-core`'s transaction bus: every movement here is
ledgered like any other, so nothing this resource does is invisible.

## Setup

Its tables live in `setup.sql` at the repo root. That import is additive and safe to
re-run: guarded `ALTER`s, `INSERT IGNORE`, and explicit corrections for rows the
base schema already seeded.

## The economy scale

Anchored to the owner's targets, not copied from another server:

| | |
|---|---|
| Cheapest vehicle, a work van | 2,000 |
| High-end car | 200,000 |
| Market ceiling | 350,000 |
| Cheapest house | 200,000 |

**Paychecks are hourly** and capped at `Config.Money.maxHourlyPaycheck` (5,000)
in `som-core`, enforced in payroll rather than trusted from job config, so a
mistake in a job definition cannot flood the economy.

## Two kinds of job

Government work pays a real salary, because there is nothing to sell.

Player-owned businesses pay a deliberately low base (~250 to 450/hour) and earn
through **commission**: a share of each sale that employee personally made.
Standing on the clock earns almost nothing; serving customers earns well.
Commission is paid **out of the business account**, so a shop that sells nothing
cannot pay anyone.

## Market

Selling pushes a price down, time pulls it back toward base.

- `saturation` is the fractional drop per unit sold, applied across the batch,
  so the hundredth unit is worth less than the first.
- `recovery` is the fraction of the gap back to base restored per hour.
- Floor and ceiling are fractions of base, so nothing crashes to nothing or
  spikes to an exploitable high.

Prices live in the database, not memory, so they survive a restart. An economy
that resets on reboot teaches players to wait for a restart rather than read the
market.

```lua
exports['som-economy']:getMarketPrice('weed_bag')
exports['som-economy']:quoteMarketSale('weed_bag', 25)   -- gross, unitAverage
exports['som-economy']:sellToMarket(source, 'weed_bag', 25, { business = 'lscustoms' })
```

`sellToMarket` **does not remove items**. The caller must already have taken the
goods. Mixing item removal and payment in one function is how double-pay bugs
happen.

Illegal goods saturate faster and recover slower, rewarding a fresh market over
grinding one flat. Crime pays roughly 1.5 to 2x legal per hour before losses,
deliberately: an economy where crime pays ten times better empties the legal
side of the server.

## Business register

Every business owns a real bank account. Three funding models:

| Funding | Meaning |
|---|---|
| `sales` | A shop or garage. Revenue from what it sells, taxed into the treasury. |
| `fines` | A police department. Revenue from penalties. |
| `treasury` | EMS. Funded by the city, sells nothing, because charging for medical care turns treatment into a paywall. |

Tax is charged on **business revenue**, not player wages: income tax is
invisible and feels punitive, while a business paying tax is something the city
can visibly spend.

## Departments

`lspd` is active. `bcso` and `sasp` exist with `active = 0`, so they can be
switched on by flipping a column when the population justifies them, rather than
needing a migration and a code change later.

### Armoury

Split on purpose:

- **Department issue** (IFAK, bandages, armour, radio, cuffs) is paid by the
  department. Free to the officer, because someone who cannot afford armour is a
  safety problem and charging for it pushes people to work unprotected.
- **Personal** (weapons, ammunition) is charged to the officer, so there is a
  real cost to spraying rounds around.

`Config.Armoury.departmentSubsidy` can shift that balance without code changes.

## Fines

**The officer receives nothing.** `Config.Fines.officerShare` is zero, and
`fines.lua` never pays the issuer, by design rather than omission.

Paying officers per ticket would make the incentive "write as many fines as
possible". Routing it to the department means the reason to fine is to fund the
department and enforce the law, and letting someone off costs the officer
nothing. The split is department 70 / treasury 30.

```lua
exports['som-economy']:issueFine(officerSource, targetSource, 500, 'Reckless driving')
exports['som-economy']:payFine(source, fineId)
exports['som-economy']:voidFine(source, fineId)     -- boss or admin only
```

## Sink and faucet instrumentation

Reports hourly from `som_transactions`, comparing money created against money
destroyed, against `Config.Balance.targetSinkFaucetRatio` (0.85: wealth
accumulates slowly).

**It only measures.** It deliberately does not auto-correct, because an economy
that silently retunes itself is impossible to reason about, and a bug in the
corrector would be indistinguishable from player behaviour.

`/economy` (som.admin) dumps treasury, business balances, market health and the
current ratio. It moves into `som-admin` at Phase 4d.

## Known gaps

- **No laundering yet.** The `dirty` account exists in `som-core` and is
  protected; the front-business cut is the next piece.
- **No drug production chains.** The market accepts sales but nothing produces
  goods yet.
- **No shops or vendors.** `sellToMarket` has no in-world caller until Phase 5.
- **Vehicle and house prices** are not implemented; the anchors above only
  inform wage and market scale so far.
- **Mayor and budgets** are roadmapped. `Config.Tax.minimum` already exists as
  the floor an elected official may never go below.
- Not verified against a live server: none of this has been executed.
