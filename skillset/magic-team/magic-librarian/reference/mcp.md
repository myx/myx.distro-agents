# MCP (Model Context Protocol) / JSON-RPC 2.0

Read this for building, reviewing, or debugging a hand-rolled MCP server. It covers JSON-RPC message handling, tools/resources capabilities, and async execution and cancellation semantics. It is especially for the case where no framework or SDK is available. There JSON-RPC is parsed and emitted by hand (e.g. POSIX shell with no jq, python or node).

## Contents

- Existing servers in this estate
- Protocol shape
- Hand-rolling JSON in POSIX awk (no jq/python/node)
- Tool-call semantics
- Async execution and cancellation
- Testing

## Existing servers in this estate

`os-myx.common` carries one at `source/myx/myx.common/os-myx.common/host/tarball/share/myx.common/bin/lib/agentMcpServer.Common`, registered via `setup/agentMcp`. `myx.distro-agents` has its own, separate server. The two share no code: each tool family's server is independent, and changing one must never require changing the other. For portable-shell conventions beyond MCP itself (dispatcher patterns, OS-variant files, general POSIX gotchas), see `magic-developer`'s [reference/shell.md](../../magic-developer/reference/shell.md). That module and this one are meant to be used together for myx.common MCP work, not as substitutes for each other. For actually operating/deploying the real `agentMcpServer.Common` on myx.common hardware, that's `magic-devops`'s/the owning `keeper-*`'s territory, not this reference module.

If the target environment isn't POSIX shell (e.g. Python/Node is actually available there), the protocol knowledge below still applies. The hand-rolled-parsing advice does not hold, so use a real JSON/MCP library instead of reinventing this.

## Protocol shape

- JSON-RPC 2.0, one message per line, newline-delimited over stdio.
- **stdout is the protocol, stderr is the logs.** In any stdio server, nothing but framed JSON-RPC lines ever reaches stdout, and every diagnostic, trace, progress line or warning goes to stderr. One stray `echo` on stdout corrupts the stream for the rest of the session.
- **stdout is fully buffered when it is a pipe** — 4KB, not line-buffered. Any filter process placed in the response path (an external `printf`, `sed`, `tee`, a formatter) therefore holds a finished response until its own buffer fills. The client then stalls, waiting on a reply that was already written. Write responses from the shell process itself. Bash's `printf` builtin goes straight to the descriptor and is safe. A forked writer in that path is not.
- `initialize`'s response must advertise capabilities (`tools`, `resources`, etc.) that exactly match what's actually implemented. Don't advertise a capability with no handler behind it.
- A notification (no `id` field in the request) gets no response, ever. Examples are `notifications/initialized` and `notifications/cancelled`. Answering one is a protocol violation, not a harmless extra line.
- `resources/list` + `resources/read` are a separate capability from `tools/*` — for exposing read-only reference content (docs, config) without spending a tool call. Validate any caller-supplied URI server-side before touching the filesystem (reject `..`, absolute paths, unexpected characters). Never assume only your own `resources/list` will ever hand back a URI to `resources/read`.

## Hand-rolling JSON in POSIX awk (no jq/python/node)

- Small recursive-descent parser: path-based leaf callback (e.g. `params.arguments.command` → write to a file), reading one line at a time. Not a general JSON library — only implement the flat/one-level-nested shapes MCP messages actually use.
- The parser hands its decoded values back as files under a per-request scratch dir. This is `magic-developer`'s `reference/shell.md` earned-file case, not a variable that became a file. A separate process (awk) produces several values at once, and any of them may carry newlines or quotes. A forked handler and the wrapped command open those values later (`arg_stdin` is the command's stdin). A single plain value still goes in a variable. Never capture the *wrapped user command's* output with `$( )` at all. The reason is in "Async execution and cancellation" below.
- **AWK's uninitialized-variable gotcha bites here specifically.** A counter used to build a filename (`"prefix_" myCounter`) must be `BEGIN`-initialized to a real `0`. Awk's implicit uninitialized value is `0` in numeric context but `""` in string concatenation. So the very first use silently produces `"prefix_"` (no index) instead of `"prefix_0"`. It breaks only on the *first* entry of a multi-entry list, so a first round of testing passes straight over it.
- **AWK axiom.** Always put `;` before a closing `}` when a statement precedes it on the same line (`close(f); }`, not `close(f) }`). Some non-gawk AWK implementations hard-error on the missing-semicolon form, even though gawk, mawk and "one true awk" tolerate it. Don't trust "it ran fine on my dev box" as proof of portability across the actual target fleet. (Same axiom as `magic-developer`'s shell module — kept here too since it's the exact failure mode that bites a hand-rolled JSON-RPC parser first.)

## Tool-call semantics

- Check a wrapped command's actual documented exit-code convention before assuming it means what it usually means. One example is a "displayed help" convention that exits 1 even on success. A tool wrapper must not blindly treat non-zero exit as MCP `isError` without checking.
- If the host already gates tool calls behind its own permission-prompt/confirmation mechanism, don't duplicate that safety logic inside the server. A hard-coded destructive-command exclusion list is one example. That logic is redundant, and it gives the two another place to drift out of sync.

## Async execution and cancellation

**A server never blocks its read loop on anything a user command can influence.** The command's runtime, its output volume, and the lifetime of any child it leaves behind are all caller-controlled. Any of them held in the main loop is a permanent hang of the whole server, not a slow request. The specific way this happens in shell is command substitution. `x="$( cmd )"` returns when the capture pipe has no writers left, not when `cmd` exits. So one background child (`&`, a daemon, `nohup`) inheriting the write end freezes the server for as long as that child lives. An `execute` of `sleep 300 & echo STARTED-BG` is enough to hang the server permanently, taking every later request with it. Capture a user command by redirecting its output to a file. Background it directly, so `$!` is the real PID, and `wait "$pid"`. That waits on the process, never on the pipe. Full mechanism and the `( exec >&- ; cmd ) &` variant in `magic-developer`'s [reference/shell.md](../../magic-developer/reference/shell.md).

`notifications/cancelled` only means something if the request loop can still read/act on it while a long tool call is running. A naive synchronous "read line, fully handle it, read next line" loop makes cancellation a no-op by construction.

- **Fork the whole request handler, per request, and serialize only the wire.** The main loop reads a line, then snapshots every per-request field it needs (request id, scratch paths, arguments). It forks the handler after that snapshot, so a shared scratch directory cannot race between concurrent handlers. The child then does the work and writes its own response. Concurrency then costs nothing, and a command that leaves a lingering child delays only its own response rather than the server.
- **Serialize every response write through a portable mutex, held for exactly one `printf`.** `mkdir` is atomic on every POSIX filesystem and doesn't need `flock`/`lockf`, which are not guaranteed present on bare FreeBSD/Darwin. The shape is a tight-loop `mkdir "$lockDir" 2>/dev/null` retry, and `rmdir` to release. A bounded `sleep` fallback is purely a deadlock guard, not the expected path. JSON-RPC framing breaks completely if two response lines ever interleave mid-line. This isn't optional once any concurrency exists. Holding the lock across anything longer than the single write reintroduces the blocking it exists to prevent.
- **A workable POSIX-sh shape: one long-running call at a time, still cancellable.** Background the call, and track its PID and the request id it belongs to in two files. On a matching cancellation notification, send TERM immediately and clear the tracking right away. A follow-up call is then not held "busy" until the old one actually dies. Run the KILL escalation in its own detached background check, so the cancellation handler never blocks the main loop.
- **A hand-rolled wall-clock timeout with no GNU `timeout(1)`.** Background the target directly, not inside a `( ... )` subshell, so `$!` is the real killable PID rather than a wrapper. A watcher subshell polls `kill -0` and does TERM-then-KILL after the deadline. Then `wait` on the real PID in the foreground. PID-based, not process-group-based — document as a known tradeoff that a grandchild the target itself forks (e.g. `curl`) isn't guaranteed to die with it.
- **Building a dynamic argv (env vars + binary + args) without `eval`.** POSIX sh only gives you one `$@` array. Lean on `env`'s own parsing instead of string-building. `env` treats each leading argv token matching `identifier=value` as an assignment, and stops at the first token that doesn't match, then execs the rest. So append `NAME=value` pairs to `$@`, then the target binary's *absolute path*, then its args. The absolute path can never look like `identifier=value`, since it starts with `/`. Always invoke via `env "$@"`, a harmless no-op prefix when there are zero pairs, and no branching is needed. No injection risk: each `NAME=value` is one argv token, never re-parsed as a string by anything.

## Testing

- **A synchronous-looking test suite (`send request, sleep, read response, repeat`) cannot catch a request loop that's secretly still blocking.** Prove non-blocking behavior with real interleaved timing, not sequential calls.
- FIFO-based harness: `mkfifo`, start the server reading from it *first* (`&`), **then** open the write end (`exec 3>fifo`). Reversing that order deadlocks. A FIFO open blocks until both ends are open. Opening the write end before anything exists to open the read end therefore hangs forever.
- Interleave `sleep`s and writes to `&3` to actually prove three things. A fast reply arrives while a slow call is still in flight. A busy-rejection fires correctly for a second concurrent call. A cancellation kills the right process, checked with `ps` afterward for orphans, not just that *a* response arrived.
- **Test with a command that outlives its own request**, such as `cmd & echo done`. Do not test only with a slow foreground command. A server that hangs on a lingering writer passes every slow-command test, and dies on the first backgrounding one.
- Test the real dispatch path: pipe raw JSON-RPC through the actual server script. Testing internal functions directly with hand-built arguments is not enough. Parser bugs (like the awk uninitialized-counter gotcha above) only show up when real JSON goes through the real parser.
