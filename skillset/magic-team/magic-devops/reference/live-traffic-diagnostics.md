# Live-fleet network-traffic inspection methodology

Read this when inspecting live network traffic on a real fleet (e.g. `tcpdump`-based sweeps across multiple hosts) — a different sub-domain from `myxdistro-pipeline.md`'s fleet-execution/console mechanics, covering the traffic-capture and packet-content-classification layer itself, not the SSH/parallelism plumbing around it. `(draft)` — filename is a first-draft proposal, open to renaming.

## `tcpdump -A` + `grep -B<N>` context-matching to recover a packet's header line is fragile — a real bug class, not a one-off

Reconstructing "which source IP produced this payload match" by counting a fixed number of lines backward from a `grep -B<N>` hit on `tcpdump -A` output is unreliable: the number of intervening binary/hex garbage lines between a packet's header line and its ASCII payload varies with packet size, so a fixed `-B1`/`-B2` silently misses matches or attributes them to the wrong source IP. Real risk, not theoretical: this can silently break an embedded detector for dozens of consecutive check rounds with zero errors — reading the whole time as a clean "no hits" streak, not a failure.

Two known-good fixes, either one:
- **(a) Stateful parser**: track "current packet's source IP" as a state variable while scanning line-by-line; report it only when a content match is found afterward, regardless of how many lines away.
- **(b) Binary capture**: capture with `-xx` (full hex dump, no ASCII) and do binary pattern matching (e.g. in perl via `pack("H*", ...)` + regex) — avoids the ASCII-line-count problem entirely, and additionally allows extracting exact binary payload fields.

## Reverse-DNS-to-known-hosting-provider is not a legitimate-traffic signal

"Destination IP resolves to a known cloud/hosting provider (AWS/Hetzner/etc.) via reverse DNS" is NOT a reliable signal that traffic is legitimate corporate traffic rather than P2P — P2P peers are commonly hosted on exactly those same providers. Don't let this plausible-sounding alternative explanation wave off a stronger signal already in hand — e.g. dismissing a port-51413 sighting as "just ephemeral port coincidence" can hide a genuine hit; check it against the stronger method below before waving it off.

Reliable signals instead:
- **Protocol-specific content**, when the protocol is identifiable unencrypted even if the main transfer is encrypted — e.g. BitTorrent DHT's bencoded `find_node`/`get_peers`/`announce_peer` strings.
- **Destination port pattern** — well-known service ports suggest legitimate traffic; many distinct residential/hosting IPs on essentially random ports, especially UDP, suggests P2P.

## Cross-reference

- Fleet-execution/parallelism/console mechanics for the SSH plumbing around a sweep like this: `reference/myxdistro-pipeline.md`, "`ShellTo` for remote diagnosis" section.
- A denied/rejected tool call not being proof nothing executed: `magic-team/magic-team.armed.md`'s "Engineering & operating discipline" section (shared baseline rule, not repeated here).
