# som-evidence

Scene traces, collection, chain of custody, the lab, and links to court cases.

## The rule that shapes it

Nothing is believed because a client said so. A trace is created from the
server's own view of the ped, a bag carries only an evidence id, and everything
else (kind, place, time, holder, analysis) is a database row. A forged bag
points at nothing.

## Flow

1. A detected crime reaches `som-dispatch`, which fires the server-only event
   `som:server:crimeReported`. Shots with a weapon in hand leave a casing
   carrying the weapon's serial; vehicle theft leaves a fingerprint; being
   downed (`som:server:playerDowned`) leaves blood. Each is rate limited and
   capped per area.
2. An officer runs `/scene`, walks up to a trace and collects it. Collection is
   one conditional `UPDATE ... WHERE status = 'scene'`; the bag is only filled
   if that won, and the claim is given back if the pack is full.
3. At the locker the officer locks the bag up or checks it out. Stored evidence
   is a database state, so there is no stash name for a client to guess.
4. At the lab the officer starts an analysis; the database sets the finish time.
   A result is a profile code. It only names a citizen when a reference sample
   (DNA or fingerprints taken from a cuffed person) carries the same code.
5. The officer links evidence to a case they filed in `som-court`; a judge, the
   prosecutor and the defender can see what backs it.

Every change is an inserted row in `som_evidence_custody`; nothing is edited.

## Known limits

- Rain and water do not wash traces away; fade is time only.
- No firearm registry, bullet impacts, vehicle-bound evidence or camera.
- Station and lab coordinates are UNVERIFIED (`/pdcoords` prints a position
  formatted for a config file).
- GSR is held in memory, so a restart clears it.

## Prior art

Compared before writing: r14-evidence (paid, local source read), qb-policejob
(source read), qbx_police, noobsystems/evidences, renzu_evidence, SolidCore MDT,
xs-mdt, SL-EvidenceBag and ps-mdt. Every free option creates or bags evidence
from client messages, lets the client name the stash it opens, or keeps no
custody, and several are GPL, so only ideas were taken. r14-evidence stays off:
its server stores a client-supplied table as bag metadata and runs a client
chosen event name.
