# `project.inf` — the declaration idioms the shipped manuals do not carry

**The `project.inf` file itself has one home, and it is not this module.** That home is the
`myx.distro-.local` package's own `project.inf` file-format manual, reached through that package's help
pair — the property list, escaping, continuation, encoding, duplicate keys, the `Requires`↔`Provides`
matching rule with its colon-modifier fallback, and the `--` token opt-out. Read it first, before
authoring or editing any `project.inf`. The directive families are likewise documented by the two
packages that consume them: `image-prepare:*` by `myx.distro-source`, `image-install:*` by
`myx.distro-deploy`.

This module is the companion to that manual, not a second copy of it: it covers the install fragments
and the declared directive tokens, where the manual covers the file. Where the two subjects meet, the
statement lives in the manual and this module points at it — a rule stated twice drifts.

What follows is established from the working project population, not from a manual, and is what a
session otherwise re-derives or invents.

## A project is reachable by more names than it declares

- **The index adds the `Name` value and every trailing path-segment form of the project's location.** A
  project at `mel/infra/common-mel/setup.standard-freebsd-machine` resolves under that whole path, under
  `infra/common-mel/setup.standard-freebsd-machine`, and under the bare `setup.standard-freebsd-machine`,
  none of which appear in its own `Provides:`.
- **What `Provides:` adds on top is the abstract capability name** — the namespace-neutral alias a
  dependant actually writes in its `Requires:`, such as `cloud.all/setup.standard-freebsd-machine`. That
  alias is an arbitrary string matched byte-for-byte; it carries no relationship to where either project
  sits on disk.
- **So moving a project changes its implicit path names and nothing else.** Dependants keep resolving
  through the declared alias. Only the moved project's own path-bearing values — an `--ssh-home`, an
  `image-execute:` target, a hardcoded path inside its own scripts — need updating.
- **A name that resolves does not prove the argument was the right kind.** Some tools take a project
  name and some take a provide-name, and a string that is both resolves under either, which hides the
  mistake until the next call uses a name that is only one of them.

## The key set, and which keys do anything

- **The parsed key set — `Name`, `Requires`, `Provides`, `Declares`, `Keywords` — is the manual's own
  statement.** Read it there; it is not restated here.
- **`Info:` and `Title:` are both valid, and the estate is split on which to write.** Both spellings
  occur in every workspace checked: the infra and deploy projects lean towards `Info:`, the
  `myx.distro-*` packages towards `Title:`, which is the one `myx.distro-source`'s own README property
  list names. Neither reaches the stripped internal form. **Whether anything else reads either is not
  established** — a key the parser skips is not thereby a key nothing reads. Follow the surrounding
  tree rather than converting one spelling to the other.
- **`Augments:`, `Suggests:`, `Includes:`, `Installs:` and `Builders:` were not found to gate
  anything.** `myx.distro-source`'s README documents `Augments:` and `Suggests:` as non-gating, and its
  shell parser `ParseSourceProjectInfToCached.fn.include` drops both; its `MAGIC.md` records `Includes:`
  and `Builders:` as occurring in no `project.inf` in that tree. Whether anything reads any of the five
  is not established. A project that needs to vary a base is forked or sequenced; no non-forking
  specialisation mechanism was found behind any of them. A builder is discovered by its path under
  `builders/<stage>/`, never by a key.
- **Key order in the live population is `Name`, `Requires`, `Provides`, then `Keywords` where the
  project carries any.** Empty placeholder keys carried for symmetry are a minority form and are not
  the convention.

## Grouping inside a value

The continuation rule itself — every entry carrying its trailing backslash, the last one included, the
list closing with a blank line — is stated in the manual and in `myx.distro-source`'s own README. What
follows is only the grouping convention layered on top of it.

- **A line carrying only a backslash is a blank separator inside the value, and is how a long
  `Provides:` is grouped.** The parser collapses it away; it exists for the reader.
- **The established group order inside a `Provides:` is: the abstract capability alias, the
  `exec-update-*` fragments, the `context-variable` declarations, then the paired
  `sync-source-files`/`deploy-sync-files` lines, one blank-separated group per synced directory.**

The `--` token prefix that opts a project out of whatever would otherwise select it is the manual's own
"Stage Selectors and Opting Out" section. Read it there.

## Ordering is declaration order, and the `after` list is reversed

The single most-guessed-at property, and the one an installer's correctness rests on.

- **Fragments are emitted in build-sequence order across projects** — a dependency's fragments before
  its dependants' — and in **declaration order within one project**. Nothing is sorted at any stage.
- **The `exec-update-after` list is emitted reversed.** The `before` fragments run in sequence order and
  the `after` fragments unwind it, so the deepest dependency's `after` fragment runs last.
- **The `0.`/`1.`/`2.` digits in a fragment filename are a readability convention aligned with
  declaration order, never a sort key.** Renumbering a file changes nothing about when it runs;
  reordering its line in `project.inf` is what does. Two files sharing a digit run in the order their
  lines appear.
- **A dependant's fragment can therefore rely on an abstraction's fragment having already run**, which
  is what makes a thin per-host script's `test -x` guard on an abstraction-installed binary sound. Verify
  the position rather than assuming it when the guard matters.

## SSH target resolution is assembled, not read off one project

- **The host project's own `deploy-ssh-target:<name>:<port>` is filtered as an *own* provide** — it
  selects which projects are deploy targets at all, and a project inheriting one through `Requires:` is
  not thereby a target.
- **`deploy-ssh-client-settings:` is collected as a *merged* provide**, so the connection settings arrive
  from the whole `Requires:` chain: typically `--ssh-user` from a service or client project, `--ssh-host`
  from a location project, `--ssh-home` namespace-wide from the namespace's own deploy-client project.
- **One token may carry several flag/value pairs**, as `deploy-ssh-client-settings:--ssh-user:<user>:--ssh-home:<path>`.
- **`--ssh-home` is a workspace-relative path**, not an absolute one and not relative to the declaring
  project.
- **A `deploy-ssh-target:` value is a name and a port, not a reachable address.** Where the merged
  `--ssh-host` differs from it, the published port is commonly a NAT forward on the location host. A
  claim about how a host is reached, made from the host project alone, names the wrong host and no user.
- **Selector uniqueness is checked against `deploy-ssh-target:` lines**, never against host names in a
  namespace structure file: a name present in the topology is not thereby a selectable target.

## Synced data travels as a declared pair

- **A directory under the project's own `data/` reaches a host through two lines, not one**: an
  `image-prepare:sync-source-files:<sourceName>:data/<name>:<name>` that stages it, and an
  `image-install:deploy-sync-files:<name>:<targetPath>` that places it. Writing one without the other
  produces no error and no file on the host.
- **The `<sourceName>` selector decides whose `data/` is harvested**: `.` is the declaring project's own,
  `*` walks the sequence taking only projects whose own sequence contains the declaring project, and `**`
  takes every project in the sequence that holds the path.
- **A `**` harvest is why severing a project takes two conditions**, not one: the `Requires:` line
  removed *and* the project out of the build sequence. While it remains in the sequence its `data/`
  files still arrive.
- **A project declaring a `**` harvest for a directory it does not itself contain is declaring an
  extension point**, to be filled by a dependant. Landing such a project alone yields something that
  installs and cannot serve.

## Account and permission declaration lines

Both families are plain `Provides:`/`Declares:` tokens with no key of their own.

- **An account project declares its whole identity through tokens rather than files**:
  `install-user-username:`, `install-user-fullname:` (spaces written as `+`), `install-user-password-hash:`,
  `install-user-ssh-key:<path within the project>`, and in the wider population also
  `install-user-email:`, `install-user-google-oauth:` and `install-user-blocked:true`. One
  `install-user-ssh-key:` token per key file; an undeclared key file in the tree is inert.
- **Group membership is a `Requires:` token carrying a colon-modifier**, as `accounts/<user>:<role>`. The
  modifier is not part of the identity matched — the fallback strips it after an exact match fails — so
  the user project needs no knowledge of the group.
- **A user project may provide an alias alongside its own name**, which is how an identity owned by
  another namespace is admitted to a group without a second project.
- **A `project.inf` carrying `install-user-password-hash:` is credential-bearing.** The hash sits inline
  in cleartext for a real account on a live host.
- **The inline hash is the estate's declaration shape, not a leak.** Every namespace's accounts tree
  declares it this way, and the account's own install fragment carries the same value to the call that
  sets it. It is never reported as an exposure, moved to a secret store, or raised as a question.
- **The handling rule binds the values, not the file.** A real account's hash, key and oauth-id values are
  not reproduced outside the project declaring them — no other file, document, message, report or commit
  message. Editing such a project in place is ordinary work; an example uses an obvious placeholder.
- **Skillset registration is two `Declares:` token families**:
  `magic-team:team-member:<path to the member's folder>:<selector>` contributes a member from that
  project, and `magic-team:permissions:<scope>:<target>:<action>:<member>[:<glob>]` grants write access,
  with `*` accepted for target, member and workspace scope.

## Fragment file conventions

- **An abstraction's fragments live in `host/install/` and are named
  `<project basename without its `setup.` prefix>.<digit>.<topic>.txt`** — digit `0` for prepare, `1` for
  one subsystem each, `2` for the main body, with a `.after.txt` counterpart where an `exec-update-after`
  is declared. `host/scripts/` holds patch scripts, not install fragments.
- **A thin per-host script sits at the project root as `install-<host>.sh.txt`**, not under `host/install/`.
- **A fragment's own shebang does not select its interpreter.** The deploy transport pipes the generated
  aggregate to `bash`, and each fragment body is embedded as data inside it, so a bash-only construct runs
  whatever the header says. A portability argument about these fragments is usually about the wrong thing.
  A file installed as a real executable under `data/**` is the opposite case and does run under its own
  shebang: read how a file is executed before deciding which standard it is held to.
- **The aggregate carries no `set -e`.** A failing command inside a fragment does not stop the run unless
  that fragment opens with its own, and a host then comes up looking installed while under-configured.
- **A fragment runs non-interactively with stdin already consumed.** A `read` of any kind hits EOF
  immediately; under a fragment's own `set -e` that aborts the fragment while the outer script continues.
  A guard fails closed, it does not prompt.

## Reading list

- The `myx.distro-.local` package's own help pair for the `project.inf` file format — the grammar,
  escaping, encoding, the property list, the `Requires`↔`Provides` matching rule, and the `--` opt-out.
  **The home for the file itself; read it first.**
- `myx.distro-source`'s own README and `MAGIC.md` — the pipeline stages, the project and workspace
  folder layout, and the `image-prepare:*` directives.
- `myx.distro-deploy`'s own README and `MAGIC.md` — the `image-install:*` directives, the target
  selectors, and what a generated installer's exit status does and does not mean.
- `magic-developer/reference/shell.md` — the shell standard the fragment bodies are actually held to.
- `reference/mcp.md`, `reference/messaging.md` — sibling format modules, same axis.
