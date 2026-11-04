# som-court

Cases, hearings, rulings and warrants. A case is the single authoritative record
that jail and bail read.

## Flow

```
filed -> accepted -> scheduled -> convicted -> sentenced
  |                      \-> acquitted
  \-> dismissed (a judge can also dismiss anything not yet sentenced)
```

Every arrow is a conditional `UPDATE ... WHERE status = <expected>`; the affected
row count decides who won, so two people acting on one case cannot both succeed.

- An officer files a case on a nearby player (class, charges). At most
  `Config.MaxOpenPerDefendant` open cases per person.
- A prosecutor accepts or drops it. A defender can take an unassigned case.
- A judge or clerk schedules a hearing from fixed offsets in config.
- Only after the hearing time has passed may a judge rule. A felony needs
  `Config.Grades.felony`. Months and fine are capped per class and a court can
  lower a sentence later but never raise it. A fine is billed through
  `som-economy` the moment it is ruled and credited to the `doj` business.
- A guilty ruling with custody is carried out by an officer in the jail booking
  dialog; the months come from the case row. A ruling with no custody completes
  when ruled.
- A hearing that passes with nobody present can be declared a failure to appear,
  which issues a warrant for `Config.WarrantHours`. Booking serves a warrant.

Exports used by `som-jail`: `casesFor`, `openCase`, `claimForSentence`,
`unclaimSentence`, `bailTerms`, `activeWarrants`, `serveWarrants`.

## Jobs

`judge`, `prosecutor` and `defender` are three separate jobs, not grades of one.
A single ladder would let a defender be promoted onto the bench. One grade
threshold per power lives in `Config.Grades`.

## Known limits

- ps-mdt is untouched. Its own warrant flag and these warrants coexist; these
  are the ones booking and bail use. Showing them inside the MDT is not done.
- No appeal, no jury, no unpaid-fine-to-warrant conversion (the phone bill
  already settles fines automatically after its due date).
- The courthouse desk coordinates are UNVERIFIED. Walk the building and correct
  `Config.Desk` (`/pdcoords` prints a position formatted for a config file).

## Prior art

Compared before writing: Project-Sloth/ps-mdt and two forks (separate DOJ jobs,
calendar, contest rulings that can lower but never raise, 7-day warrants),
XyraL/cipher-mdt (server re-checks permissions on every call), SolidCoreStudios
MDT (warrant filters), rayen-brigui/qb-doj and B4Store/b4-judgejob (single judge
job, no persistence or hearings), itsJarrett/FiveM-JailNJury (pause the sentence
while a trial is pending), and CoolBrad-Scripts/doj-forms (procedure
vocabulary). None combines filing, hearing, ruling, carrying out the sentence
and bail on one store, and several are GPL or AGPL, so only ideas were taken.
