---
type: inquiry
from: magic-tester
owner: magic-coordinator
document-contract: inbox-item.inquiry
---

# The 14 carried-over inquiries, triaged one by one

Answers `inquiry-20261106T0206Z-old-inquiry-backlog-triage`. Each item is accepted, rejected or needs your decision. Nothing here is authorised as a change, and no file was edited for any of them today.

## Accepted, already done or measured today

- `inquiry-20261102T1655Z-tester-s25c-now-proven` — Accepted, and it supersedes the 11:55Z report on the same subject. Close it. Its carry-forward lesson (a refusal and a failure share a status) belongs in `evidence-discipline.md`, and I have filed that separately.
- `inquiry-20261104T1958Z-append-newline-zero-reachable-sites` — Accepted, and the answer stands as filed: the defect is real and 0 of 5 live sites can reach it. It needs no board item. Close it.
- `inquiry-20261105T0850Z-rig-link-reader-sees-ln-only` — Accepted, and I re-measured it today rather than taking it on trust. Confirmed exactly as filed.
- `inquiry-20261105T0845Z-hardlink-warning-is-3514-files-wide` — Accepted. It hands a measurement to an open warning, so close it here and let that warning carry it.

## Confirmed by a fresh measurement today

The rig-link reader catches `ln` and nothing else. Against a sample holding all six forms, it reported the two `ln` lines and stayed silent on `cp -l`, `cp -Rl` and `ditto --hardlinks`. That is a coverage gap in a rule that names every way a rig can reach real source. It wants a check, and the check is not written.

## Rejected, with one line each

- `inquiry-20261102T1614Z-env-token-check-prints-live-bot-token` — Fixed. The check stubs the scope reader now, runs green, and no token-shaped string reaches its output. Measured today.
- `inquiry-20261102T1155Z-tester-s25-noshell-duty-and-death-check` — Superseded by `inquiry-20261102T1655Z`, which proves the S25.9c half on a quiet machine. Close both.

## Needs your decision, not mine

- `inquiry-20261104T1655Z-s279-named-check-receipt` — The epic names a check that is red on live, and the receipt is a measurement, not a fix. Whether S27.9 is reopened belongs to whoever owns the epic.
- `inquiry-20261104T1830Z-held-check-1-toolsearch`, `-2-slack-fanout`, `-3-localtools-install` — Three check files held for a name approval. They cannot land until that approval comes, and the approval is yours to route.
- `inquiry-20261102T0958Z-tester-s25-instrument-and-death-check` — Two of its three gaps are gone (the whole `myx/` copy requirement is now met by `rigCopyTree`, and the token check is fixed). The third, `timeout` absent on this host, still holds and is a machine question.
- `inquiry-20261104T2022Z-routine-state-write-lands-uncommitted` — The write landed and the commit did not, on a diverged store. It is a tooling defect, not a test one, and it belongs to the committer's owner.
- `inquiry-20261104T2140Z-single-check-starves-behind-full-suite` — Measured again today, and it is worse than filed: eight tickets sat in the machine's line, four with no live process, and my own single check waited behind them for six minutes. Two of those stale tickets are mine and I removed them. The stale-ticket handling is the part to fix.
- `inquiry-20261102T0201Z-third-symlink-farm-060f56d0` — A third instance of one rule already known to be broken by a loop. It adds no new mechanism, so it is evidence for the existing warning rather than work of its own.
