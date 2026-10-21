---
maintainers: magic-coordinator, magic-librarian, magic-architect, keeper-myx, human-owner
---
# tool index — the fixed text of `.local/agents/tool-index.md`

Normative contract: this file's own `# Contract` section, at its end. Where it and the rest of this file disagree, `# Contract` wins.

Not a member/routine contract — this is the fixed text of the tool index the tooling generates (`--intern-op-tool-index`, `AgentsTools.InternOpToolIndex.include`, filled by `AgentsToolIndexFill.awk`). A member's Skill read of its own skill serves that member's section of it, as one section titled `Tool index`.

## Contents

- Summary
  - Goals
  - Scope
- Skeleton
  - head
  - member
  - shell
  - shell-file
  - shell-file-bare
  - op
  - op-bare
  - family-held
  - family-console
  - family-closed
  - calls
  - call
  - call-held
- Contract

# Summary

One section per team member: every shell operation and every harness and MCP call there is, the ones that member may use with their one-line description, every other one by its family or its name, with whom to ask for it.

## Goals

- A member knows a tool exists, and whom to ask for one it may not use.
- The index sits in a cached prefix: the same inputs give the same bytes, with no date or time in it.

## Scope

- Does: fix the text and the slots of the index's lines.
- Doesn't: decide who may use what. The caller checks of the dispatcher and the grants index decide that, and the generator reads them.

# Skeleton

## head

```
---
format: myx.distro tool-index 1
---
```

## member

```

# {{member}}

What {{member}} may use is described here. Anything else is named by its family or its name, with whom to ask for it.
```

## shell

```

## Shell operations
```

## shell-file

```

`{{file}}`, called as `{{command}} <operation>`, through `execute` where no shell is given: {{summary}}

```

## shell-file-bare

```

`{{file}}`, called as `{{command}} <operation>`: it carries no help to list its operations from.
```

## op

```
- `{{op}}`: {{description}}
```

## op-bare

```
- `{{op}}`: read `{{command}} --help-syntax {{op}}`
```

## family-held

```
- {{family}}, {{count}} operations, called by {{owners}} only: ask {{owners}}, or read `{{command}} --help-syntax{{hint}}`
```

## family-console

```
- {{family}}, {{count}} operations, the console's own, called from no member's session: read `{{command}} --help-syntax{{hint}}`
```

## family-closed

```
- {{family}}, {{count}} operations, called by no one here: read `{{command}} --help-syntax{{hint}}`
```

## calls

```

## Harness and MCP calls

Called by name, in the team harness and through the `myx.distro` MCP. A refused call says its REFUSAL-ID, to ask for it with RequestPermission.

```

## call

```
- `{{tool}}`: {{description}}
```

## call-held

```
- `{{tool}}`, held by {{owners}} only: ask {{owners}}, or ask for it with RequestPermission
```

# Contract

- rule: the index is `head`, then one `member` block per team member, by name in byte order, each followed by that member's `shell` and `calls` parts.
- rule: `{{member}}` is the member's bare name, the caption its section is cut from by.
- rule: under `shell`, each tool file of the package (`DistroAgents*.fn.sh`, `Agent*Tools.fn.sh`) is a `shell-file` block, or `shell-file-bare` where it has no help, then its operations in the order of its help's syntax lines, each once.
- rule: `{{file}}` is the file's name, `{{command}}` its function name, `{{summary}}` the first sentence of its help's Summary.
- rule: an operation the member may call is an `op` line, `{{description}}` the first sentence of its help entry, at most 120 characters; one with no help entry is an `op-bare` line.
- rule: the operations the member may not call are one line per family, where its first one would stand: `family-held` where some members may call them (`{{owners}}`, joined by ` or `), `family-console` where only a call from no member's session may, `family-closed` where no one may. `{{family}}` is the prefix the family is checked by, `{{count}}` how many operations it holds.
- rule: under `calls`, each harness tool, then each MCP tool not among them, by name: a `call` line, `{{description}}` the first sentence of its description, at most 120 characters, where no grant names the tool or one names the member; a `call-held` line where grants name it for other members only.
- rule: every line outside the slots is written exactly as here.
