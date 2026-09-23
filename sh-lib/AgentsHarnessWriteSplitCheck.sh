#!/usr/bin/env bash
## Behavioural check on the READ/WRITE split of the access-root set.
## AgentsHarnessAccessRootsCheck.sh beside this asks where the set comes from, and
## AgentsHarnessContainmentCheck.sh asks whether a path is inside it. Neither asks
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

rigHere="$( cd "$( dirname -- "$0" )" && pwd )"
rigHarness="$rigHere/AgentsUniversalHarness.sh"

## Refusing to report is this block's whole job: a run that exercised nothing must
## never print a pass.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

[ -f "$rigHarness" ] || rigRefuse "harness not found beside this check: $rigHarness"

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
export HARNESS_SELF_NAME="AgentsHarnessWriteSplitCheck.sh"
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
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1"
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
echo "HARNESS_WRITE_SPLIT: OK (5 assertions, both polarities, offline)"
