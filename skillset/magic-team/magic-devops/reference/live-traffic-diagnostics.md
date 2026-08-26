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

## IPv4 packet loss on a dual-stack host says nothing about that host's IPv6 health, or vice versa

Reachability and loss on one address family is independent of the other, even on the exact same physical interface. A host that looks unreachable/lossy over IPv4 can be fully healthy and usable over IPv6 (or vice versa) — concluding "host down/degraded" from one family alone risks a wrong diagnosis, and the still-healthy family is itself a usable diagnostic channel while the other is down.

- Always test both families independently (e.g. `ping`/`ssh` over IPv4, then again over IPv6) before concluding anything about the host as a whole.
- If one family is healthy, use it as the working channel to keep diagnosing the other, rather than treating the host as fully unreachable.

## A firewall's own rule comments can reveal an allowed port beyond the one documented

A host's live firewall ruleset (e.g. `ipfw -a list`, `iptables -L -n -v`) sometimes allows more than the one documented/expected port for a service — a rule's own inline comment can name a second working port that isn't written down anywhere else. Treating the documented port as the sole truth, without reading the ruleset that actually governs the box, risks a false "host unreachable" conclusion when a working alternate port was sitting in the rule comment the whole time.

- When a documented port fails, read the actual ruleset's comments on the box before escalating to "host down."
- A rule covering multiple ports together, with one shared comment, is itself worth noting as a possible deliberate convention — don't assume it's an accident without checking whether the same pattern exists elsewhere in the fleet.

## A reachable guest VM on the same hypervisor as an unreachable host is a free second vantage point

Reachability from a guest sharing the target's physical hypervisor (or rack/location) distinguishes a host-level problem (the target host itself, or its own interface/ruleset) from a location-wide or upstream problem (the physical link, the location's router, the ISP) — the same distinction any second independent vantage point buys, at effectively no cost when one is already sitting right there.

- Guest reachable, target host not: problem is local to the target host (its own NIC, its own ruleset, its own OS).
- Guest also unreachable: problem is likely location-wide or upstream, not specific to the target host.

## A software bridge/VLAN interface's healthy state doesn't describe the physical NIC underneath it

`ifconfig <bridge-or-vlan-iface>` reports the software interface's own state, which can look fully healthy while the physical NIC underneath it is degraded, or vice versa — the two layers are worth checking as separate steps, not inferred from each other.

- Check the physical interface on its own: `ifconfig <physical-iface>` for negotiated link speed/duplex, `netstat -i` for interface error/drop counters.
- A qualitative condition worth naming ("this interface accumulates errors/drops under load") stays useful over time; an exact counter snapshot doesn't — it will already be a different number by the time anyone reads it.

## Cross-reference

- Fleet-execution/parallelism/console mechanics for the SSH plumbing around a sweep like this: `reference/myxdistro-pipeline.md`, "`ShellTo` for remote diagnosis" section.
- A denied/rejected tool call not being proof nothing executed: `magic-team/magic-team.armed.md`'s "Engineering & operating discipline" section (shared baseline rule, not repeated here).
