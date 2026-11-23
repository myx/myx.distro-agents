#!/usr/bin/env bash
## Behavioural check on what a Bash-tool command inherits from the harness that runs it: a leg's own
## settings never reach a member's shell. A leg stub exports the model table, the models and the
## credential it runs on, and the core becomes that process, so a command started from a member's
## shell used to inherit another service's family table and another service's credential. Held, on a
## real call through `--intern-tool Bash` against the harness entered with a leg's settings:
##   1. the call runs, and a variable that is no leg setting still reaches the command (the control:
##      a command that sees nothing at all cannot pass 2 and 3 for the right reason)
##   2. no HARNESS_ variable of the leg reaches the command, the model table by name included
##   3. the leg's credential reaches neither the command nor anything the call printed
## Red before the fix: the command sees the table, the model and the credential. Offline: a shell of
## this box, no endpoint, no network.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigOrigin="${MDLT_ORIGIN:-$MMDAPP/.local}"
rigMember="rig-a"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin this workspace resolves: $rigHarness"
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessBashEnvCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws/.local/.agents" "$rigTmp/skills/$rigMember" "$rigTmp/home" || exit 1
printf -- '---\nmaintainers: rig\n---\nRIG-A-BASIC own words\n' > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
printf -- '---\nname: %s\n---\nmember skill\n' "$rigMember" > "$rigTmp/skills/$rigMember/SKILL.md"
rigPath="/usr/bin:/bin:/usr/sbin:/sbin"
## The leg's settings, as a stub of this service exports them. The token is a sentinel: nothing of it
## may stand in what the call prints.
rigTable='*rig-flash*|1048576|32768|thinking:disabled|the rig service, a sentinel row'
rigSentinel="rig-sentinel-$$-LEG-TOKEN"
## The command: how many leg variables the shell holds, then the control, the table and the credential.
rigCmd='printf "legcount=%s\n" "$( env | LC_ALL=C grep -c "^HARNESS_" || : )" ; printf "control=[%s]\n" "${RIG_KEPT:-gone}" ; printf "table=[%s]\n" "${HARNESS_MODEL_TABLE:-none}" ; printf "token=[%s]\n" "${HARNESS_TOKEN_MAIN:-none}"'

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One real Bash-tool call, the harness entered with a leg's own settings, as the leg stub leaves them.
rigCall(){ ## call name
	( cd "$rigTmp/ws" && printf '{"command":"%s","cwd":"%s"}' "$rigCmdEscaped" "$rigTmp/ws" | env -i HOME="$rigTmp/home" PATH="$rigPath" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_AGENT="$rigMember" MDAT_SPAWN_SESSION_ID="rig-session" \
		HARNESS_PROVIDER_NAME="bash env rig" HARNESS_SELF_NAME="AgentsHarnessBashEnvCheck.test.sh" \
		HARNESS_MODEL_MAIN="rig-main" HARNESS_MODEL_LIGHT="rig-light" HARNESS_MODEL_TABLE="$rigTable" \
		HARNESS_TOKEN_MAIN="$rigSentinel" HARNESS_EFFORT="normal" HARNESS_WIRE="OpenAiChat" \
		RIG_KEPT="rig-kept-value" \
		python3 -I -B "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 60 -- bash "$rigHarness" --intern-tool Bash --access-read-root "$rigTmp" --access-write-root "$rigTmp" ) \
		> "$rigTmp/$1.out" 2> "$rigTmp/$1.err" || :
}
## The command as the tool's JSON argument takes it: a quote and a backslash escaped.
rigCmdEscaped="$( printf '%s' "$rigCmd" | LC_ALL=C awk '{ gsub( /\\/, "\\\\" ) ; gsub( /"/, "\\\"" ) ; printf "%s", $0 ; }' )"

echo "-- 1. the call runs, and one variable that is no leg setting still reaches the command --"
rigCall one
rigAssert "the control value reaches the command, so a command that inherited nothing cannot pass by seeing nothing" \
	"$( LC_ALL=C grep -c -F 'control=[rig-kept-value]' "$rigTmp/one.out" )" 1

echo "-- 2. none of the leg's settings reaches the command --"
rigAssert "the command holds no HARNESS_ variable of the leg at all" \
	"$( LC_ALL=C grep -o 'legcount=[0-9]*' "$rigTmp/one.out" | LC_ALL=C sed 's/legcount=//' )" 0
rigAssert "the leg's model table is not in the command's environment" \
	"$( LC_ALL=C grep -c -F 'table=[none]' "$rigTmp/one.out" )" 1

echo "-- 3. the leg's credential reaches neither the command nor the printed call --"
rigAssert "the credential is not in the command's environment" \
	"$( LC_ALL=C grep -c -F 'token=[none]' "$rigTmp/one.out" )" 1
rigAssert "and nothing of the credential stands in what the call printed" \
	"$( cat "$rigTmp/one.out" "$rigTmp/one.err" 2> /dev/null | LC_ALL=C grep -c -F -- "$rigSentinel" || : )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HARNESS BASH ENV CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: a command of a member's shell inherits the leg's model table, models and credential" >&2
	echo "  fix:  repair sh-lib/harness/AgentsHarnessToolsBash.include -- never the assertion" >&2
	exit 1
fi
printf 'HARNESS_BASH_ENV: OK (%d assertions, offline)\n' "$rigPassCount"
