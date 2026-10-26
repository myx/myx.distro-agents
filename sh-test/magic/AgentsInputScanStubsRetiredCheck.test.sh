#!/usr/bin/env bash
## Behavioural check on retiring the member input-scan stubs (F6.4 of the refactorings epic): an input scan stops
## being an operation an agent calls directly; the spawner reads it from routine spec (F6.3). `--intern-op-*` stays,
## and may be renamed `--intern-*`. Done when no agent-callable input-scan operation remains.
## Held:
##   1. each of the nine published input-scan operation names is no operation any more: the dispatcher answers
##      `invalid option` naming it, as the console calls it; and as a member's session calls it, for the eight
##      a member's session passes the caller check of (a --magic-* one as magic-coordinator's session, the others
##      as keeper-rig's; --client-sweep-input-scan is a client's own, so the console's call stands for it)
##   2. control, green before and after: the two `--intern-op-*-input-scan` implementations still answer as
##      operations, never `invalid option`
##   3. every scan keeps the `--intern-op-<scan>-input-scan` form (open-names 37), the seven missing ones added in it:
##      <scan> is the published name without its `--`, its `-input-scan` and a leading `magic-`, as the two that stand
##      today show (`--magic-morning-review-input-scan` and `--intern-op-morning-review-input-scan`)
## Red before F6.4: every one of the nine answers with its own syntax refusal, as an operation, and seven of the nine
## have no `--intern-op-*` form (1 and 3 fail).
## Not tested, for want of a name: that every scan the system needs is declared by a routine (F6.3's
## `input-scan-def:` form is open). Builder note: AgentsInputScanPureReadCheck and AgentsInputScanCacheCheck (F3.1,
## F3.2) and many checks today call --magic-advance-input-scan; they are reconciled in the same feature.
## Since F13.1 each call is made in a team rig (MDAT_WORKSPACE_MODE=team-rig): in a workspace that keeps no team data the gate of that mode answers a --magic-* name before the
## dispatcher can call it an invalid option. Since F7.12 the heartbeat scan and the advance scan are retired: their published names stay refused (1), their
## --intern-op-* forms are gone (3 does not ask for them; the advance one is held to be no operation).
## Offline: each call is made with no argument, so each stops at its syntax; git, curl, ssh, rsync and scp are
## stand-ins that note any start and fail.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigTool="$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the dispatcher is not at the origin this workspace resolves: $rigTool"
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
rigTmp="$( mkdir -p "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsInputScanStubsRetiredCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/agents" "$rigTmp/home" "$rigTmp/bin"
for rigMember in keeper-rig magic-coordinator ; do
	mkdir -p "$rigTmp/skills/$rigMember"
	printf 'rig\n' > "$rigTmp/skills/$rigMember/$rigMember.basic.md" ; printf 'rig\n' > "$rigTmp/skills/$rigMember/$rigMember.armed.md"
done
for rigCommand in git curl ssh rsync scp ; do
	printf '#!/bin/sh\necho "%s $*" >> "%s/network"\nexit 1\n' "$rigCommand" "$rigTmp" > "$rigTmp/bin/$rigCommand"
	chmod +x "$rigTmp/bin/$rigCommand"
done

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigCaller=()
rigCall(){ ## operation -- one call with no argument, as the console unless rigCaller names a member; both streams in $rigTmp/said
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" USER=rigacct PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" ${rigCaller[@]+"${rigCaller[@]}"} python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 30 -- bash "$rigTool" "$1" ) > "$rigTmp/said" 2>&1 < /dev/null
}
rigInvalid(){ ## operation -- yes where the last call answered `invalid option` naming it
	if LC_ALL=C grep -q -F -- "invalid option: $1" "$rigTmp/said" ; then printf 'yes' ; else printf 'no' ; fi
}
rigNine="--client-sweep-input-scan --magic-advance-input-scan --magic-grooming-input-scan --magic-heartbeat-input-scan --magic-morning-review-input-scan --magic-permission-escalation-input-scan --magic-sweep-input-scan --member-work-session-input-scan --routine-coworking-session-input-scan"

echo "-- 1. the nine published names are no operations: invalid option --"
rigConsoleLeft="" ; rigMemberLeft=""
for rigOp in $rigNine ; do
	rigCaller=()
	rigCall "$rigOp"
	[ "$( rigInvalid "$rigOp" )" = yes ] || rigConsoleLeft="$rigConsoleLeft $rigOp"
	case "$rigOp" in
		--client-*) continue ;;
		--magic-*) rigCaller=( MDAT_SPAWN_AGENT=magic-coordinator MDAT_SPAWN_SESSION_ID=rig-run-coordinator ) ;;
		*) rigCaller=( MDAT_SPAWN_AGENT=keeper-rig MDAT_SPAWN_SESSION_ID=rig-run-keeper ) ;;
	esac
	rigCall "$rigOp"
	[ "$( rigInvalid "$rigOp" )" = yes ] || rigMemberLeft="$rigMemberLeft $rigOp"
done
rigCaller=()
rigAssert "as the console calls them: the names still answering as operations" "[${rigConsoleLeft# }]" "[]"
rigAssert "as a member's session calls them: the names still answering as operations" "[${rigMemberLeft# }]" "[]"

echo "-- 2. control: the --intern-op-* implementations stay --"
rigInternGone=""
for rigStem in morning-review-input-scan permission-escalation-input-scan ; do
	rigCall "--intern-op-$rigStem"
	[ "$( rigInvalid "--intern-op-$rigStem" )" = no ] || rigInternGone="$rigInternGone $rigStem"
done
rigAssert "each answers as an operation, by its --intern-op-* name" "[${rigInternGone# }]" "[]"

echo "-- 3. every scan has its --intern-op-<scan>-input-scan --"
rigInternMissing=""
for rigOp in $rigNine ; do
	rigStem="${rigOp#--}" ; rigStem="${rigStem%-input-scan}" ; rigStem="${rigStem#magic-}"
	## The two scans retired since (the heartbeat's with the heartbeat, the advance's with F7.12) have no implementation, by design.
	case "$rigStem" in heartbeat|advance) continue ;; esac
	rigCall "--intern-op-$rigStem-input-scan"
	[ "$( rigInvalid "--intern-op-$rigStem-input-scan" )" = no ] || rigInternMissing="$rigInternMissing --intern-op-$rigStem-input-scan"
done
rigAssert "the internal operations still missing" "[${rigInternMissing# }]" "[]"
rigCall "--intern-op-advance-input-scan"
rigAssert "the advance scan is retired (F7.12): its --intern-op-* form is no operation either" "$( rigInvalid "--intern-op-advance-input-scan" )" "yes"
rigAssert "and nothing reached for the network"                  "$( [ -s "$rigTmp/network" ] && echo reached || echo none )" "none"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ INPUT SCAN STUBS RETIRED CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'INPUT_SCAN_STUBS_RETIRED: OK (%d assertions, offline)\n' "$rigPassCount"
