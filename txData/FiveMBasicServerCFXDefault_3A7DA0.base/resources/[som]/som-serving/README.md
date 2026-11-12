# som-serving

A legal job: serve court papers. The `Papers` phone app lists court cases with a hearing still
ahead (defendant name, time to the hearing and the fee, nothing else). A player holds one paper at
a time and has to find that person in the world; a "Serve court papers" option then appears on that
player only. After a progress bar the defendant is told, the courts pay the server, and the
court docket shows the case as served.

The server owns everything that matters:

- The paper is chosen from `som_court_cases`; a case never shows to its defendant, filer, judge,
  prosecutor or defender, and a case is served once (`som_court_service.case_id` is UNIQUE).
- At the final step the server re-checks the held paper, that the defendant is the named person,
  loaded and within `Config.distance`, and that the serving time passed (the client bar is cosmetic).
- One atomic `INSERT IGNORE ... SELECT ... WHERE NOT EXISTS` is the claim and also enforces the
  per-defendant cooldown and the server's hourly cap, all read from the table. Only then does money
  move: `businessSpend` on `doj` first, `addMoney` second, and a failure deletes the claim row and
  returns the money.
- The fee comes from the `doj` business (funded by the fines share). The Papers list refuses up
  front when that account cannot cover a fee.

Service is shown, not enforced: the court can still declare a failure to appear.

See `LAUNCH-TODO.md` for the table import and what is untuned or unverified.
