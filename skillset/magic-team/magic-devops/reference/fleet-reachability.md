---
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
---
# A host that answers nothing

Read this when a fleet host answers no SSH, no ping and no port. It covers finding the cause from outside the host. Running commands on a host that answers is `myxdistro-pipeline.md`'s, and packet capture is `live-traffic-diagnostics.md`'s.

## Contents

- A silent host is read from the outside in

## A silent host is read from the outside in

- **A silent host is read from the outside in.** Traceroute to the address comes first, then the provider's own server and firewall record, then a rescue boot.
- **A traceroute ending at the provider's own block host names the cause.** The provider has locked the server, and no port, no ICMP and no rescue system will answer.
- **A rescue activation outlives a reset.** It is cleared with its own delete call, and the record is read back as off before anything boots the installed system.
