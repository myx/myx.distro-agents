#!/usr/bin/env bash
## Behavioural check on the READ/WRITE split of the access-root set.
## AgentsHarnessAccessRootsCheck.test.sh beside this asks where the set comes from, and
## AgentsHarnessContainmentCheck.test.sh asks whether a path is inside it. Neither asks
## which of the two sets a path is inside, which is this file's question.
##
## Why it exists. The two root flags do opposite things to the set they join, and
## neither name says so: any root flag replaces the default set, and a write flag
## NARROWS writes, where with no write flag writes are exactly as wide as reads.
## So the first caller to pass one write root in order to grant one directory
## takes away every other write in the same call, and the call reports success.
## A console that renders every root on the read flag has exactly that shape.
##
## Offline and unmetered by construction: --intern-tool reaches no endpoint and
## needs no credential, so the tool gate itself is the observation and no wire,
## no stub curl and no recorded request body are involved.
##
## Self-contained. Every fixture is built in its own mktemp -d and every root under
## test is PASSED explicitly, so the gate is satisfied by relocating it onto the
## fixture rather than by standing anything permissive in its place.
##
## Red recipe, run and not merely plausible: make the core's write set fall back to
## the read set unconditionally -- drop the guard on
##   [ -n "$harnessWriteRoots" ] || harnessWriteRoots="$harnessRoots"
## so it always assigns. The readable-but-not-writable assertion then reports OK
## where it must report a refusal, and this check fails.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"

rigHarness="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib/AgentsUniversalHarness.sh"

## Refusing to report is this block's whole job: a run that exercised nothing must
## never print a pass.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"

rigTmp="$( mktemp -d -t AgentsHarnessWriteSplitCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

## READABLE is granted for reading only; WRITABLE for both; OUTSIDE is granted on
## neither side. Write refuses an ungranted path and a read-only path with the SAME
## message, because it tests the write set first and never reaches the other one --
## so readability, not the refusal text, is what shows a read-only root was granted.
mkdir -p "$rigTmp/READABLE" "$rigTmp/WRITABLE" "$rigTmp/OUTSIDE"
printf 'rig-seed\n' > "$rigTmp/READABLE/seed.txt"
printf 'rig-seed\n' > "$rigTmp/OUTSIDE/seed.txt"

## What a provider stub sets. A tool call is not metered, so the token exists only
## to keep this file the same shape as its siblings; nothing here reads one.
export HARNESS_PROVIDER_NAME="write-split check rig"
export HARNESS_SELF_NAME="AgentsHarnessWriteSplitCheck.test.sh"
export HARNESS_ENDPOINT="https://harness-write-split-check.invalid/v1/chat/completions"
export HARNESS_HOST="harness-write-split-check.invalid"
export HARNESS_WIRE="OpenAiChat"
export HARNESS_CREDENTIAL_NAMES="none -- this check never reads one"
export HARNESS_MODEL_LIGHT="rig-light"
export HARNESS_MODEL_MAIN="rig-main"
export HARNESS_TOKEN_MAIN="rig-not-a-credential"

## One Write call through the real core, returning its verdict line and nothing else.
## A call that produced no verdict at all is a rig fault, never a result.
rigWrite(){ ## target path, then the root flags for this scenario
	local rigTarget="$1" rigLine ; shift
	rigLine="$( printf '{"path":"%s","content":"x"}' "$rigTarget" \
		| MMDAPP="$rigTmp" "$rigHarness" --intern-tool Write "$@" 2>/dev/null \
		| LC_ALL=C grep -m1 '^OK:\|^ERROR:' )" || rigLine=""
	[ -n "$rigLine" ] || rigRefuse "no verdict line from a Write call on $rigTarget, so the write gate was never exercised"
	printf '%s' "$rigLine"
}

## What the verdict says, as one word, so an assertion never matches a message it
## did not mean.
rigVerdict(){ ## verdict line
	case "$1" in
		'OK:'*)                                   printf 'wrote' ;;
		*'not in the allowed write-root set'*)    printf 'refused-not-writable' ;;
		*'not in the allowed access-root set'*)   printf 'refused-not-granted' ;;
		*)                                        printf 'other' ;;
	esac
}

## One Read call through the real core. Read tests the READ set, so this is what
## establishes that a root refused for writing is nonetheless granted.
rigRead(){ ## target path, then the root flags for this scenario
	local rigTarget="$1" rigOut ; shift
	## The status is discarded and the output kept: a refused tool call exits non-zero
	## BY DESIGN, so treating a non-zero status as "no output" throws away the very
	## answer being asked for and reports it as a rig fault.
	rigOut="$( printf '{"path":"%s"}' "$rigTarget" \
		| MMDAPP="$rigTmp" "$rigHarness" --intern-tool Read "$@" 2>/dev/null )" || :
	[ -n "$rigOut" ] || rigRefuse "no output from a Read call on $rigTarget, so the read gate was never exercised"
	case "$rigOut" in
		*'not in the allowed access-root set'*) printf 'refused-not-granted' ;;
		*rig-seed*)                            printf 'read' ;;
		*)                                     printf 'other' ;;
	esac
}

rigSplit=( --access-read-root "$rigTmp/READABLE" --access-read-root "$rigTmp/WRITABLE" --access-write-root "$rigTmp/WRITABLE" )
rigNoWriteFlag=( --access-read-root "$rigTmp/READABLE" --access-read-root "$rigTmp/WRITABLE" )

rigFails=0
rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1"
		rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
		rigFails=$(( rigFails + 1 ))
	fi
}

echo "-- a write root is given, so writes narrow to it and reads stay wider --"
## The defect this check exists to catch. A root on the read side only must refuse a
## write, and must refuse it AS a write -- a grant that vanished entirely would refuse
## it too, and that is a different fault wearing the same outcome.
rigAssert "a read-only root refuses a write, and says it is still readable" \
	"$( rigVerdict "$( rigWrite "$rigTmp/READABLE/x.txt" "${rigSplit[@]}" )" )" "refused-not-writable"
## The control that can return zero: without it the assertion above passes on a core
## that refuses every write for any reason at all.
rigAssert "a write root accepts a write" \
	"$( rigVerdict "$( rigWrite "$rigTmp/WRITABLE/x.txt" "${rigSplit[@]}" )" )" "wrote"
## What makes the first assertion mean what it says: the same root is readable, so
## its write was refused for being outside the WRITE set and not for being ungranted.
## Without this the first assertion passes on a core that dropped the grant entirely.
rigAssert "the root refused for writing is readable" \
	"$( rigRead "$rigTmp/READABLE/seed.txt" "${rigSplit[@]}" )" "read"
## The control that can return zero on the read gate: without it the assertion above
## passes on a core that reads anything at all, granted or not.
rigAssert "a root granted on neither side is not readable either" \
	"$( rigRead "$rigTmp/OUTSIDE/seed.txt" "${rigSplit[@]}" )" "refused-not-granted"

echo "-- no write root is given, so writes stay exactly as wide as reads --"
## Every console generated before the split passes this shape, so a change that made
## writes narrow by DEFAULT would take writes away from all of them silently.
rigAssert "with no write root, a read root accepts a write" \
	"$( rigVerdict "$( rigWrite "$rigTmp/READABLE/y.txt" "${rigNoWriteFlag[@]}" )" )" "wrote"

echo "-- the Claude Code session's own tool-results folder is never readable, member folders stay inside the workspace --"
## Claude Code saves an oversized tool result there, outside every workspace root, so no
## grant reaches it -- the real fix is a narrower reread, which AgentsHarnessDeniedHint's
## message names. HOME is the fixture's, so no real session folder is involved.
mkdir -p "$rigTmp/home/.claude/projects/rig-project/rig-session/tool-results" "$rigTmp/home/.claude/projects/rig-project/rig-other/tool-results"
printf 'rig-seed\n' > "$rigTmp/home/.claude/projects/rig-project/rig-session/tool-results/big.txt"
printf 'rig-seed\n' > "$rigTmp/home/.claude/projects/rig-project/rig-other/tool-results/big.txt"
rigAssert "this session's own tool result is not readable either" \
	"$( HOME="$rigTmp/home" CLAUDE_CODE_SESSION_ID=rig-session rigRead "$rigTmp/home/.claude/projects/rig-project/rig-session/tool-results/big.txt" "${rigNoWriteFlag[@]}" )" "refused-not-granted"
rigAssert "and refuses a write, with no write root given at all" \
	"$( rigVerdict "$( HOME="$rigTmp/home" CLAUDE_CODE_SESSION_ID=rig-session rigWrite "$rigTmp/home/.claude/projects/rig-project/rig-session/tool-results/x.txt" "${rigNoWriteFlag[@]}" )" )" "refused-not-writable"
## The controls that can return zero: another session's folder, and no session at all.
rigAssert "another session's tool result is not readable" \
	"$( HOME="$rigTmp/home" CLAUDE_CODE_SESSION_ID=rig-session rigRead "$rigTmp/home/.claude/projects/rig-project/rig-other/tool-results/big.txt" "${rigNoWriteFlag[@]}" )" "refused-not-granted"
rigAssert "with no session, no tool-results folder is readable" \
	"$( HOME="$rigTmp/home" CLAUDE_CODE_SESSION_ID="" rigRead "$rigTmp/home/.claude/projects/rig-project/rig-session/tool-results/big.txt" "${rigNoWriteFlag[@]}" )" "refused-not-granted"

echo "-- no root flag at all, as the MCP server calls it: writes narrow the way the console's do --"
## HOME is the fixture's, so its skills root and permissions registry are this rig's own.
## One declared Edit grant names GRANTED; nothing names the skills root or the source tree.
mkdir -p "$rigTmp/home/.claude/skills/rig-member" "$rigTmp/source" "$rigTmp/.local/temp/team" "$rigTmp/GRANTED"
printf 'rig-seed\n' > "$rigTmp/home/.claude/skills/rig-member/seed.txt"
printf 'rig:rig:rig:Edit(%s/**)\n' "$rigTmp/GRANTED" > "$rigTmp/home/.claude/skills/.linked.magic-team.permissions.txt"
rigAssert "the skills root stays readable" \
	"$( HOME="$rigTmp/home" MDAT_SKILLSET_ROOT="" CLAUDE_CODE_SESSION_ID="" rigRead "$rigTmp/home/.claude/skills/rig-member/seed.txt" )" "read"
rigAssert "and refuses a write" \
	"$( rigVerdict "$( HOME="$rigTmp/home" MDAT_SKILLSET_ROOT="" CLAUDE_CODE_SESSION_ID="" rigWrite "$rigTmp/home/.claude/skills/rig-member/x.txt" )" )" "refused-not-writable"
rigAssert "the workspace source tree refuses a write no grant declares" \
	"$( rigVerdict "$( HOME="$rigTmp/home" MDAT_SKILLSET_ROOT="" CLAUDE_CODE_SESSION_ID="" rigWrite "$rigTmp/source/x.txt" )" )" "refused-not-writable"
## The controls that can return zero: both halves of the console's write set still write.
rigAssert "the team scratchpad accepts a write" \
	"$( rigVerdict "$( HOME="$rigTmp/home" MDAT_SKILLSET_ROOT="" CLAUDE_CODE_SESSION_ID="" rigWrite "$rigTmp/.local/temp/team/x.txt" )" )" "wrote"
rigAssert "a declared Edit grant accepts a write" \
	"$( rigVerdict "$( HOME="$rigTmp/home" MDAT_SKILLSET_ROOT="" CLAUDE_CODE_SESSION_ID="" rigWrite "$rigTmp/GRANTED/x.txt" )" )" "wrote"

echo "-- a symlink as the last path element is judged by where it points --"
rigLeafIn="$rigTmp/LEAF-IN"
rigLeafOut="$rigTmp/LEAF-OUT"
mkdir -p "$rigLeafIn/sub" "$rigLeafOut"
rigLeaf=( --access-read-root "$rigLeafIn" --access-write-root "$rigLeafIn" )

rigEdit(){ ## target path, new text, then the root flags for this scenario
	local rigTarget="$1" rigNew="$2" rigLine ; shift 2
	rigLine="$( printf '{"path":"%s","old_text":"orig","new_text":"%s"}' "$rigTarget" "$rigNew" \
		| MMDAPP="$rigTmp" "$rigHarness" --intern-tool Edit "$@" 2>/dev/null \
		| LC_ALL=C grep -m1 '^OK:\|^ERROR:' )" || rigLine=""
	[ -n "$rigLine" ] || rigRefuse "no verdict line from an Edit call on $rigTarget, so the write gate was never exercised"
	printf '%s' "$rigLine"
}

rigBytes(){ ## path
	[ -f "$1" ] || { printf 'absent' ; return 0 ; }
	cat "$1"
}

printf 'orig' > "$rigLeafOut/target"
ln -s "$rigLeafOut/target" "$rigLeafIn/link"
rigAssert "Write through an in-root link to an outside file is refused" \
	"$( rigVerdict "$( rigWrite "$rigLeafIn/link" "${rigLeaf[@]}" )" )" "refused-not-writable"
rigAssert "and the outside file is unchanged" "$( rigBytes "$rigLeafOut/target" )" "orig"

printf 'orig' > "$rigLeafOut/target2"
ln -s "$rigLeafOut/target2" "$rigLeafIn/link2"
rigAssert "Edit through an in-root link to an outside file is refused" \
	"$( rigVerdict "$( rigEdit "$rigLeafIn/link2" rig-edited "${rigLeaf[@]}" )" )" "refused-not-writable"
rigAssert "and the outside file is unchanged" "$( rigBytes "$rigLeafOut/target2" )" "orig"

printf 'orig' > "$rigLeafOut/rt"
ln -s "../../LEAF-OUT/rt" "$rigLeafIn/sub/rel"
rigAssert "a relative link out is refused" \
	"$( rigVerdict "$( rigWrite "$rigLeafIn/sub/rel" "${rigLeaf[@]}" )" )" "refused-not-writable"
rigAssert "and the outside file is unchanged" "$( rigBytes "$rigLeafOut/rt" )" "orig"

printf 'orig' > "$rigLeafOut/ht"
ln -s "$rigLeafOut/ht" "$rigLeafIn/h2"
ln -s "$rigLeafIn/h2" "$rigLeafIn/h1"
rigAssert "a two-hop chain out is refused" \
	"$( rigVerdict "$( rigWrite "$rigLeafIn/h1" "${rigLeaf[@]}" )" )" "refused-not-writable"
rigAssert "and the outside file is unchanged" "$( rigBytes "$rigLeafOut/ht" )" "orig"

rigAssert "a plain in-root file is written" \
	"$( rigVerdict "$( rigWrite "$rigLeafIn/plain" "${rigLeaf[@]}" )" )" "wrote"
printf 'orig' > "$rigLeafIn/real"
ln -s "$rigLeafIn/real" "$rigLeafIn/lin"
rigAssert "an in-root link to an in-root file is written" \
	"$( rigVerdict "$( rigWrite "$rigLeafIn/lin" "${rigLeaf[@]}" )" )" "wrote"
rigAssert "and the write landed on its target" "$( rigBytes "$rigLeafIn/real" )" "x"
rigAssert "an outside path is refused and not created" \
	"$( rigVerdict "$( rigWrite "$rigLeafOut/direct" "${rigLeaf[@]}" )" )" "refused-not-writable"
rigAssert "and nothing was created there" "$( rigBytes "$rigLeafOut/direct" )" "absent"

ln -s "$rigLeafOut" "$rigLeafIn/dl"
rigAssert "a file under an in-root link to an outside directory is refused" \
	"$( rigVerdict "$( rigWrite "$rigLeafIn/dl/f" "${rigLeaf[@]}" )" )" "refused-not-writable"
rigAssert "and nothing was created outside" "$( rigBytes "$rigLeafOut/f" )" "absent"

ln -s "$rigLeafOut/new" "$rigLeafIn/dangling"
rigAssert "Write on a dangling link out replaces the link, via temp plus mv" \
	"$( rigVerdict "$( rigWrite "$rigLeafIn/dangling" "${rigLeaf[@]}" )" )" "wrote"
rigAssert "Write via temp plus mv: nothing was created outside" "$( rigBytes "$rigLeafOut/new" )" "absent"
rigAssert "Write via temp plus mv: the link is now a regular file" "$( [ -f "$rigLeafIn/dangling" ] && [ ! -L "$rigLeafIn/dangling" ] && printf yes || printf no )" yes
ln -s "$rigLeafOut/new2" "$rigLeafIn/dangedit"
rigAssert "Edit on a dangling link out fails as no such file" \
	"$( case "$( rigEdit "$rigLeafIn/dangedit" rig-edited "${rigLeaf[@]}" )" in (*'no such file'*) printf yes ;; (*) printf no ;; esac )" yes
rigAssert "Edit on a missing file: nothing was created outside" "$( rigBytes "$rigLeafOut/new2" )" "absent"
rigAssert "Edit on a missing file: the link is unchanged" "$( [ -L "$rigLeafIn/dangedit" ] && printf yes || printf no )" yes
ln -s "$rigLeafIn/new" "$rigLeafIn/dangin"
rigAssert "Write on a dangling link in replaces the link, via temp plus mv" \
	"$( rigVerdict "$( rigWrite "$rigLeafIn/dangin" "${rigLeaf[@]}" )" )" "wrote"
rigAssert "Write via temp plus mv: the in-root link is now a regular file" "$( [ -f "$rigLeafIn/dangin" ] && [ ! -L "$rigLeafIn/dangin" ] && printf yes || printf no )" yes
ln -s "$rigLeafIn/c2" "$rigLeafIn/c1"
ln -s "$rigLeafIn/c1" "$rigLeafIn/c2"
rigCycleStart="$( date +%s )"
rigAssert "Write on a link cycle replaces the link, via temp plus mv" \
	"$( rigVerdict "$( rigWrite "$rigLeafIn/c1" "${rigLeaf[@]}" )" )" "wrote"
rigAssert "Write on a link cycle returned rather than hanging" \
	"$( [ $(( $( date +%s ) - rigCycleStart )) -le 10 ] && printf yes || printf no )" yes
rigAssert "Write via temp plus mv: the cyclic link is now a regular file" "$( [ -f "$rigLeafIn/c1" ] && [ ! -L "$rigLeafIn/c1" ] && printf yes || printf no )" yes

echo "-- an unattended session never writes the team stores, whatever its roots grant --"
rigStoreData="$rigTmp/STORE-DATA"
rigStoreSessions="$rigTmp/.local/agents/sessions"
mkdir -p "$rigStoreData/board/running" "$rigStoreSessions/rig-session" "$rigTmp/STORE-PLAIN"
printf 'orig' > "$rigStoreData/board/running/dispatch-rig.md"
rigWide=( --access-read-root "$rigTmp" --access-write-root "$rigTmp" )

## One call with the three launch values stated outright, so nothing ambient decides it.
rigStoreCall(){ ## unattended marker, spawn session id, tool (write|edit), target; the client entrypoint is RIG_ENTRYPOINT
	local storeTool="$3" storeTarget="$4"
	if [ "$storeTool" = "edit" ] ; then
		env -u MDAT_SESSION_UNATTENDED -u MDAT_SPAWN_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT MDAT_DATA_ROOT="$rigStoreData" \
			${1:+MDAT_SESSION_UNATTENDED="$1"} ${2:+MDAT_SPAWN_SESSION_ID="$2"} ${RIG_ENTRYPOINT:+CLAUDE_CODE_ENTRYPOINT="$RIG_ENTRYPOINT"} \
			bash -c 'rigHarness="$1" rigTmp="$2" ; shift 2 ; printf "{\"path\":\"%s\",\"old_text\":\"orig\",\"new_text\":\"rig-edited\"}" "$1" | MMDAPP="$rigTmp" "$rigHarness" --intern-tool Edit "${@:2}" 2>/dev/null | LC_ALL=C grep -m1 "^OK:\|^ERROR:"' \
			rig "$rigHarness" "$rigTmp" "$storeTarget" "${rigWide[@]}"
	else
		env -u MDAT_SESSION_UNATTENDED -u MDAT_SPAWN_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT MDAT_DATA_ROOT="$rigStoreData" \
			${1:+MDAT_SESSION_UNATTENDED="$1"} ${2:+MDAT_SPAWN_SESSION_ID="$2"} ${RIG_ENTRYPOINT:+CLAUDE_CODE_ENTRYPOINT="$RIG_ENTRYPOINT"} \
			bash -c 'rigHarness="$1" rigTmp="$2" ; shift 2 ; printf "{\"path\":\"%s\",\"content\":\"x\"}" "$1" | MMDAPP="$rigTmp" "$rigHarness" --intern-tool Write "${@:2}" 2>/dev/null | LC_ALL=C grep -m1 "^OK:\|^ERROR:"' \
			rig "$rigHarness" "$rigTmp" "$storeTarget" "${rigWide[@]}"
	fi
}
rigStoreVerdict(){ ## verdict line
	case "$1" in
		'OK:'*)                          printf 'wrote' ;;
		*'unattended session never'*)    printf 'refused-team-store' ;;
		'')                              printf 'no-verdict' ;;
		*)                               printf 'other' ;;
	esac
}

rigAssert "marker set: Write into the board is refused" \
	"$( rigStoreVerdict "$( rigStoreCall true "" write "$rigStoreData/board/running/dispatch-rig.md" )" )" "refused-team-store"
rigAssert "marker set: Edit into the board is refused" \
	"$( rigStoreVerdict "$( rigStoreCall true "" edit "$rigStoreData/board/running/dispatch-rig.md" )" )" "refused-team-store"
rigAssert "and the board item is unchanged" "$( rigBytes "$rigStoreData/board/running/dispatch-rig.md" )" "orig"
rigAssert "spawn id set: Write into the session store is refused" \
	"$( rigStoreVerdict "$( rigStoreCall "" rig-session write "$rigStoreSessions/rig-session/grants" )" )" "refused-team-store"
rigAssert "and nothing was created there" "$( rigBytes "$rigStoreSessions/rig-session/grants" )" "absent"
rigAssert "spawn id set: Write into the board is refused" \
	"$( rigStoreVerdict "$( rigStoreCall "" rig-session write "$rigStoreData/board/running/x.md" )" )" "refused-team-store"
ln -s "$rigStoreData/board/running/dispatch-rig.md" "$rigTmp/STORE-PLAIN/link-into-board"
rigAssert "marker set: a link into the board is refused by where it points" \
	"$( rigStoreVerdict "$( rigStoreCall true "" write "$rigTmp/STORE-PLAIN/link-into-board" )" )" "refused-team-store"
rigAssert "and the board item is still unchanged" "$( rigBytes "$rigStoreData/board/running/dispatch-rig.md" )" "orig"
## The controls: the same widened root still writes an ordinary path, and an attended call writes the store.
rigAssert "marker set: an ordinary path under the same root is written" \
	"$( rigStoreVerdict "$( rigStoreCall true "" write "$rigTmp/STORE-PLAIN/x.txt" )" )" "wrote"
## Attended only from an interactive Claude Code client with neither marker nor spawn id.
printf 'orig' > "$rigStoreData/board/running/dispatch-attended.md"
rigAssert "an interactive cli session writes the board" \
	"$( RIG_ENTRYPOINT=cli rigStoreVerdict "$( RIG_ENTRYPOINT=cli rigStoreCall "" "" edit "$rigStoreData/board/running/dispatch-attended.md" )" )" "wrote"
rigAssert "and the edit landed" "$( rigBytes "$rigStoreData/board/running/dispatch-attended.md" )" "rig-edited"
rigAssert "the IDE client is attended too" \
	"$( rigStoreVerdict "$( RIG_ENTRYPOINT=claude-vscode rigStoreCall "" "" write "$rigStoreData/board/running/dispatch-ide.md" )" )" "wrote"
rigAssert "no entrypoint at all is unattended" \
	"$( rigStoreVerdict "$( rigStoreCall "" "" write "$rigStoreData/board/running/dispatch-none.md" )" )" "refused-team-store"
rigAssert "claude -p (sdk-cli) is unattended" \
	"$( rigStoreVerdict "$( RIG_ENTRYPOINT=sdk-cli rigStoreCall "" "" write "$rigStoreData/board/running/dispatch-sdk.md" )" )" "refused-team-store"
rigAssert "an unknown entrypoint is unattended" \
	"$( rigStoreVerdict "$( RIG_ENTRYPOINT=some-new-surface rigStoreCall "" "" write "$rigStoreData/board/running/dispatch-new.md" )" )" "refused-team-store"
rigAssert "cli with the unattended marker is unattended" \
	"$( rigStoreVerdict "$( RIG_ENTRYPOINT=cli rigStoreCall true "" write "$rigStoreData/board/running/dispatch-cli-marker.md" )" )" "refused-team-store"
rigAssert "cli with a spawn id is unattended" \
	"$( rigStoreVerdict "$( RIG_ENTRYPOINT=cli rigStoreCall "" rig-session write "$rigStoreData/board/running/dispatch-cli-spawn.md" )" )" "refused-team-store"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ WRITE SPLIT CHECK FAILED: $rigFails assertion(s)" >&2
	echo "  warn: the write-root set no longer narrows writes the way the flag says," >&2
	echo "        or it narrows them when no write root was given at all -- one leaves" >&2
	echo "        a granted root writable that must not be, the other takes writes from" >&2
	echo "        every caller that never asked for a narrower set" >&2
	echo "  fix:  repair the write-set derivation in sh-lib/AgentsUniversalHarness.sh --" >&2
	echo "        never the assertion, and never by widening a caller's grant to suit it" >&2
	exit 1
fi
echo "HARNESS_WRITE_SPLIT: OK ($rigPasses assertions, both polarities, offline)"
