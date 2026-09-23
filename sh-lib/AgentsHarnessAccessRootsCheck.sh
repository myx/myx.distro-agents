#!/usr/bin/env bash
## Behavioural check on WHERE the access-root set comes from when no --access-root flag
## was passed. AgentsHarnessContainmentCheck.sh beside this asks the other question --
## whether a path is inside the roots -- and neither answers this one.
##
## This path had no instrument at all, which is how it acquired a void control: the core
## exits at its HARNESS_* provider gate long before the root resolution is reached, so a
## probe that just runs the harness measures the gate and reports on nothing. Reaching it
## needs the dummy HARNESS_* a provider stub sets, plus a `curl` first on PATH -- the same
## technique the behaviour checks beside this one use. The resolved roots then travel to
## the wire inside the system prompt, so the RECORDED REQUEST BODY is the observation.
##
## The discriminator is a root that ONLY a copilot launch fragment names. Our own
## mechanism cannot yield it, so its presence in the body says the fragment was read and
## its absence says it was not. A second root our own mechanism always yields is asserted
## present, so an empty or truncated body cannot read as a pass.
##
## Offline by construction: the fake curl is first on PATH and that is asserted, not
## assumed. No host, no network, no credential. Every fixture is built here, so nothing
## outside this file has to exist for it to run.
set -u

rigHere="$( cd "$( dirname -- "$0" )" && pwd )"
rigHarness="$rigHere/AgentsUniversalHarness.sh"

## Refusing to report is this block's whole job: a run that exercised nothing must never
## print a pass. That property is what the void control this replaces did not have.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

[ -f "$rigHarness" ] || rigRefuse "harness not found beside this check: $rigHarness"

rigTmp="$( mktemp -d -t AgentsHarnessAccessRootsCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

## The scenario IS the workspace for this run, so no file of the real workspace is read
## and the fragment under test is this scenario's own.
mkdir -p "$rigTmp/bin" "$rigTmp/.claude" "$rigTmp/FRAGMENT-ONLY-ROOT" "$rigTmp/source"

## A root only the fragment names. Our own mechanism yields $workspace/source and never
## this, which is what makes one line of fixture a real discriminator.
printf 'own\t%s\n' "$rigTmp/FRAGMENT-ONLY-ROOT" > "$rigTmp/.claude/copilot-add-dir.fragment"

cat > "$rigTmp/bin/curl" <<'RIGFAKECURL'
#!/usr/bin/env bash
## Records the request body and replays one canned stop stream. It opens no socket, and
## being first on PATH is the whole of this check's offline guarantee.
set -u
cat > /dev/null
while [ $# -gt 0 ] ; do
	case "$1" in
		-d) printf '%s' "${2:-}" > "$RIG_SCENARIO/req" ; shift 2 ;;
		*)  shift ;;
	esac
done
printf 'data: {"choices":[{"index":0,"delta":{"content":"RIG-ANSWER"},"finish_reason":"stop"}],"usage":{"total_tokens":1}}\n'
printf 'data: [DONE]\n'
RIGFAKECURL
chmod +x "$rigTmp/bin/curl"

PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

## What a provider stub sets. The host is .invalid and the credential is not one: both
## exist only to get past the gate that guards the code under test.
export HARNESS_PROVIDER_NAME="access-roots check rig"
export HARNESS_SELF_NAME="AgentsHarnessAccessRootsCheck.sh"
export HARNESS_ENDPOINT="https://harness-access-roots-check.invalid/v1/chat/completions"
export HARNESS_HOST="harness-access-roots-check.invalid"
export HARNESS_WIRE="OpenAiChat"
export HARNESS_CREDENTIAL_NAMES="none -- this check never reads one"
export HARNESS_MODEL_LIGHT="rig-light"
export HARNESS_MODEL_MAIN="rig-main"
export HARNESS_TOKEN_MAIN="rig-not-a-credential"

## No --access-root of any kind: that absence is what selects the resolution under test.
RIG_SCENARIO="$rigTmp" MMDAPP="$rigTmp" \
	"$rigHarness" RIG-TASK-MARKER > "$rigTmp/out" 2> "$rigTmp/err" || :

[ -f "$rigTmp/req" ] || {
	echo "-- the harness never reached the wire, so its stderr follows --" >&2
	sed 's/^/    /' "$rigTmp/err" >&2
	rigRefuse "no request body was recorded, so the root resolution was never exercised"
}

rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1"
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
		rigFails=$(( rigFails + 1 ))
	fi
}

rigHas(){ ## needle -- yes when the recorded body carries it
	if LC_ALL=C grep -q -- "$1" "$rigTmp/req" ; then printf 'yes' ; else printf 'no' ; fi
}

echo "-- where the set came from, read off the request body the core actually sent --"
## The defect this check exists to catch. A client's published launch fragment is output
## we publish, never a source anything of ours consults.
rigAssert "no root that only a copilot launch fragment names reached the wire" "$( rigHas 'FRAGMENT-ONLY-ROOT' )" "no"
## The control that can return zero: without it an empty body would pass the assertion above.
rigAssert "a root this package's own access-root mechanism yields did reach the wire" "$( rigHas "$rigTmp/source" )" "yes"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ ACCESS ROOTS CHECK FAILED: $rigFails assertion(s)" >&2
	echo "  warn: the no-flag access-root set is no longer taken from" >&2
	echo "        sh-lib/AgentsTools.ClientAccessRoots.include, which is the one place" >&2
	echo "        it is defined -- a launch fragment is a rendered copy downstream of it" >&2
	echo "  fix:  repair the resolution in sh-lib/AgentsUniversalHarness.sh -- never the" >&2
	echo "        assertion, and never by reading a client's own published file" >&2
	exit 1
fi
echo "HARNESS_ACCESS_ROOTS: OK (own mechanism, not a client's published fragment, offline)"
