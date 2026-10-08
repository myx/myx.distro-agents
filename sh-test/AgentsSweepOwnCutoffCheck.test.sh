#!/usr/bin/env bash
## Every caller keeps its OWN cut-off. One --magic-sweep-input-scan runs against the sweep
## fixture (a fake Slack) with two client members: the team part must resume from the
## calling member's own stored last_swept_ts, client-fix1 from its own, client-fix2 (none
## stored) from the default window, and no member's value may show up in another's part.
## A stated cut-off moves the team part only. Then --magic-sweep-state-advance: creates,
## advances, keeps the body, refuses backwards and future values, is a no-op on the same
## value, and the next scan resumes from the advanced pointer.
## Offline: temp trees only, under one `env -i` guard; no real store, no network.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-test/check-fixtures/sweep-concurrency.curl.test.sh" ] || rigRefuse "the sweep fixture is missing from the package"
rigTmp="$( mktemp -d -t AgentsSweepOwnCutoffCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

rigNow="$( date +%s )"
rigTeamTs="$(( rigNow - 1000 )).000100"
rigClientTs="$(( rigNow - 2000 )).000200"
rigExplicitTs="$(( rigNow - 3000 )).000300"
rigDir="$rigTmp/fix"
mkdir -p "$rigDir/bin" "$rigDir/home" "$rigDir/ws/.local/.agents" "$rigDir/ws/.local/temp" "$rigDir/ws/.local/agents/members/magic-coordinator" \
	"$rigDir/data/inboxes/magic-coordinator" "$rigDir/data/board/running" "$rigDir/data/audit"
cp "$rigPackage/sh-test/check-fixtures/sweep-concurrency.curl.test.sh" "$rigDir/bin/curl" && chmod +x "$rigDir/bin/curl"
printf '# fixture\n' > "$rigDir/ws/.local/agents/members/magic-coordinator/SKILL.md"
printf 'SLACK_BOT_TOKEN=xoxb-fixture\nSLACK_CHANNEL_MAGIC_TEAM=CFIXTEAM001\nSLACK_CHANNEL_HUMAN_OWNER=UFIXOWNER01\n' > "$rigDir/ws/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=xoxp-fixture-coordinator\n' > "$rigDir/ws/.local/.agents/magic-coordinator.agent.env"
for rigClient in 1 2 ; do
	mkdir -p "$rigDir/ws/.local/agents/members/client-fix$rigClient" "$rigDir/data/inboxes/client-fix$rigClient"
	printf '# fixture\n' > "$rigDir/ws/.local/agents/members/client-fix$rigClient/SKILL.md"
	printf 'SLACK_USER_TOKEN=xoxp-fixture-client%s\nSLACK_CONVERSATIONS=CFIXAAAA00%s\n' "$rigClient" "$rigClient" > "$rigDir/ws/.local/.agents/client-fix$rigClient.agent.env"
done
rigNote="note-20260812T231137Z-sweep-state.md"
printf -- '---\nlast_swept_ts: %s\n---\n\n# sweep-state-note\n\nteam body line\n' "$rigTeamTs" > "$rigDir/data/inboxes/magic-coordinator/$rigNote"
printf -- '---\nlast_swept_ts: %s\n---\n\n# sweep-state-note\n' "$rigClientTs" > "$rigDir/data/inboxes/client-fix1/$rigNote"

## One tooling call in the fixture tree, guarded.
rigRun(){ ## out-name, args...
	local runName="$1" ; shift
	local runRc=0
	env -i HOME="$rigDir/home" PATH="$rigDir/bin:/usr/bin:/bin" MMDAPP="$rigDir/ws" MDAT_DATA_ROOT="$rigDir/data" TMPDIR="$rigDir/ws/.local/temp" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" FIX_DIR="$rigDir" FIX_LATENCY=0 FIX_DMS=2 FIX_TS="$rigNow" RIG_TMP="$rigTmp" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$( command -v curl )" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" "$@"
		' rig "$@" > "$rigTmp/$runName.out" 2> "$rigTmp/$runName.err" || runRc=$?
	printf '%s' "$runRc" > "$rigTmp/$runName.rc"
}
## One member's own part of a sweep document.
rigPart(){ ## out-name, member
	LC_ALL=C awk -v want="# Incoming Communications Sweep -- $2" '
		/^# Incoming Communications Sweep -- / { inPart = ( $0 == want ) }
		inPart { print }
	' "$rigTmp/$1.out"
}
## The team part: everything before the first client heading.
rigTeamPart(){ ## out-name
	LC_ALL=C awk '/^# Incoming Communications Sweep -- client-/ { exit } { print }' "$rigTmp/$1.out"
}
rigHas(){ ## text, fixed string
	case "$1" in *"$2"*) printf yes ;; *) printf no ;; esac
}

echo "-- a sweep with no cut-off stated: every member resumes from its own --"
rigRun plain --magic-sweep-input-scan magic-coordinator
[ -s "$rigTmp/plain.out" ] || rigRefuse "the sweep printed no document: $( tail -3 "$rigTmp/plain.err" )"
rigTeam="$( rigTeamPart plain )" ; rigC1="$( rigPart plain client-fix1 )" ; rigC2="$( rigPart plain client-fix2 )"
rigAssert "control: both client parts are in the document" "$( [ -n "$rigC1" ] && [ -n "$rigC2" ] && printf yes || printf no )" yes
rigAssert "team resumes from its own stored position"       "$( rigHas "$( cat "$rigTmp/plain.err" )" "magic-coordinator: resuming from its own stored sweep position $rigTeamTs" )" yes
rigAssert "team part reads at its own cut-off"              "$( rigHas "$rigTeam" "cut-off --comms-since-utime $rigTeamTs" )" yes
rigAssert "client-fix1 resumes from its own stored position" "$( rigHas "$rigC1" "resumed-from: $rigClientTs (this member's own stored sweep position)" )" yes
rigAssert "client-fix1 reads at its own cut-off"            "$( rigHas "$rigC1" "cut-off --comms-since-utime $rigClientTs" )" yes
rigAssert "client-fix2, none stored, falls back to the default window" "$( rigHas "$rigC2" "resumed-from: none (none stated and none stored" )" yes
rigAssert "client-fix2 reads at the default window"         "$( rigHas "$rigC2" "cut-off defaulted to the last" )" yes
rigAssert "no shared cut-off: the team value is in no client part" "$( rigHas "$rigC1$rigC2" "$rigTeamTs" )" no
rigAssert "no shared cut-off: client-fix1 value is not in the team part or client-fix2" "$( rigHas "$rigTeam$rigC2" "$rigClientTs" )" no

echo "-- a stated cut-off moves the team part only --"
rigRun stated --magic-sweep-input-scan magic-coordinator --comms-since-utime "$rigExplicitTs"
rigTeam="$( rigTeamPart stated )" ; rigC1="$( rigPart stated client-fix1 )"
rigAssert "team part reads at the stated cut-off"           "$( rigHas "$rigTeam" "cut-off --comms-since-utime $rigExplicitTs" )" yes
rigAssert "client-fix1 still reads at its own"              "$( rigHas "$rigC1" "cut-off --comms-since-utime $rigClientTs" )" yes
rigAssert "the stated cut-off reaches no client"            "$( rigHas "$rigC1$( rigPart stated client-fix2 )" "$rigExplicitTs" )" no

echo "-- a client record that cannot be read is not a fallback --"
printf 'no frontmatter here\n' > "$rigDir/data/inboxes/client-fix2/$rigNote"
rigRun broken --client-sweep-input-scan client-fix2
rigAssert "the scan refuses"                                "$( cat "$rigTmp/broken.rc" )" 1
rigAssert "and says why"                                    "$( rigHas "$( cat "$rigTmp/broken.err" )" "no frontmatter block" )" yes
rm -f "$rigDir/data/inboxes/client-fix2/$rigNote"

echo "-- --magic-sweep-state-advance --"
rigState(){ cat "$rigDir/data/inboxes/$1/$rigNote" 2>/dev/null ; }
rigWm(){ LC_ALL=C awk -f "$rigPackage/sh-lib/AgentsMagicSweepStateWatermark.awk" < "$rigDir/data/inboxes/$1/$rigNote" 2>/dev/null ; }
rigNewTeam="$(( rigNow - 500 )).000001"
printf -- '---\nlast_swept_ts: %s\nsource-UA-DB-last-swept-ts: 1.0\n---\n\n# sweep-state-note\n\nteam body line\n' "$rigTeamTs" > "$rigDir/data/inboxes/magic-coordinator/$rigNote"
rigRun adv1 --magic-sweep-state-advance magic-coordinator "$rigNewTeam"
rigAssert "advance succeeds"                                "$( cat "$rigTmp/adv1.rc" )" 0
rigAssert "the pointer moved"                               "$( rigWm magic-coordinator )" "$rigNewTeam"
rigAssert "the body is kept"                                "$( rigHas "$( rigState magic-coordinator )" "team body line" )" yes
rigAssert "stale per-source pointers are dropped"           "$( rigHas "$( rigState magic-coordinator )" "source-UA-DB-last-swept-ts" )" no
rigAssert "the other members' records are untouched"        "$( rigWm client-fix1 )" "$rigClientTs"
rigRun adv2 --magic-sweep-state-advance magic-coordinator "$rigTeamTs"
rigAssert "backwards is refused"                            "$( cat "$rigTmp/adv2.rc" )" 1
rigAssert "and the pointer stays"                           "$( rigWm magic-coordinator )" "$rigNewTeam"
rigRun adv3 --magic-sweep-state-advance magic-coordinator "$rigNewTeam"
rigAssert "the same value is a no-op"                       "$( cat "$rigTmp/adv3.rc" ):$( rigHas "$( cat "$rigTmp/adv3.err" )" "nothing written" )" 0:yes
rigRun adv4 --magic-sweep-state-advance magic-coordinator "$(( rigNow + 86400 )).000000"
rigAssert "a future value is refused"                       "$( cat "$rigTmp/adv4.rc" ):$( rigWm magic-coordinator )" "1:$rigNewTeam"
rigRun adv5 --magic-sweep-state-advance magic-coordinator "12x4"
rigAssert "a malformed value is refused"                    "$( cat "$rigTmp/adv5.rc" )" 1
rigNewClient="$(( rigNow - 100 )).5"
rigRun adv6 --magic-sweep-state-advance client-fix2 "$rigNewClient"
rigAssert "a missing record is created"                     "$( cat "$rigTmp/adv6.rc" ):$( rigWm client-fix2 )" "0:$rigNewClient"

echo "-- the next pass resumes from the advanced pointers --"
rigRun next --magic-sweep-input-scan magic-coordinator
rigAssert "team resumes from its advanced pointer"          "$( rigHas "$( rigTeamPart next )" "cut-off --comms-since-utime $rigNewTeam" )" yes
rigAssert "client-fix2 resumes from its advanced pointer"   "$( rigHas "$( rigPart next client-fix2 )" "resumed-from: $rigNewClient (this member's own stored sweep position)" )" yes

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SWEEP OWN-CUTOFF CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SWEEP_OWN_CUTOFF: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
