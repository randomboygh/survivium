# Weekly audits

A weekly audit checks the whole project by the owner's rules (`weekly_audit.md` in the Claude
project's library): what changed in git, the architecture, the code, the game's systems, the bundles,
the balance, the client and server, security and anti-cheat, performance, tests and CI, dependencies
and the docs. It runs the checks, fixes what is confirmed and safe, plans the rest, and leaves a dated
report here. It runs on Fridays after 18:00 Moscow time. The reports are history: they are not
changed later but for plain slips in form or links. The problems still open are in
[OPEN_ISSUES.md](OPEN_ISSUES.md).

| Date | Report | Critical | High | Medium | Low | Fixed | Open | Critical or High open | Against the previous one |
|---|---|---|---|---|---|---|---|---|---|
| 2026-11-14 | [WEEKLY_AUDIT_2026-11-14.md](WEEKLY_AUDIT_2026-11-14.md) | 0 | 3 | 31 | 33 | 11 | 56 | High: 1 (WA-020) | the first: the baseline, against the stage audits of 2026-10-30…11-07 |

The counts are of the problems found by that audit (new and carried); «Fixed» are those fixed in it.
