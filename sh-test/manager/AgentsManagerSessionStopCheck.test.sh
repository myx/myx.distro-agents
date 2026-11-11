#!/usr/bin/env bash
## Behavioural check on --manager-session-stop --session-id <id> [--run] (S7.19, the soft stop; AgentsTools.ManagerSession.include),
## run rather than read, against a rig workspace built here with its own spawn records. A stop dismisses the live runs the id
## names the proper way (AgentsToolsRunDismiss): the mark `sessions/<run>/dismissed` holding who, and a DISMISSED block in the
## session's chat; no process is signalled. Held:
##   1. A session's id stops every live run of it: one `stop` row a run, `dismissed`, the mark written with the name of who stopped it,
##      and a finished run of the same session left alone.
##   2. The same call again says `already-dismissed` and writes nothing new.
##   3. `--run` takes the id as one run's own: that run alone.
##   4. An id no record names gives one `none` row, and an id that is no bare name is refused.
##   5. The syntax is refused with its line where --session-id is missing or has no value.
## Red before S7.19: the operation did not exist, so every row fails on `invalid option`.
## Offline: no process of this host is touched, and no message is posted.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerSessionStopCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigHome="$rigTmp/home" rigData="$rigTmp/data" rigSkills="$rigTmp/skills"
rigSp="$rigWs/.local/agents/spawned"
mkdir -p "$rigSp" "$rigWs/.local/agents/sessions" "$rigHome" "$rigData/board/pending" "$rigSkills/magic-coordinator" || exit 1
printf 'rig\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigRec(){ ## session id, spawn id, member, status
	mkdir -p "$rigSp/$2"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nowner: %s\nstatus: %s\nstart-context: spawned\nstarted-at: 2026-11-08 05:00 +0000\n---\n\n# Spawn session: %s\n' "$1" "$2" "$3" "$4" "$2" > "$rigSp/$2/$2.spawn.md"
}
rigRec sess-one sess-one magic-coordinator spawn-started
rigRec sess-one run-a keeper-rig spawn-started
rigRec sess-one run-z magic-tester spawn-succeeded
rigRec sess-two sess-two magic-coordinator spawn-started
rigRec sess-two run-x keeper-rig spawn-started
rigRc=0
rigRun(){ ## tool arguments... -- rc in rigRc, stdout in out, stderr in err
	rigRc=0
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" MDAT_TEAM_DATA_COMMIT_THREAD=off MDAT_COMMS_READER=off \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigRows(){ ## kind -- those rows of the last stdout, TAB as a space, sorted by the run
	LC_ALL=C awk -F'\t' -v kind="$1" '$1 == kind { gsub( /\t/, " " ) ; print }' "$rigTmp/out" | LC_ALL=C sort -k3,3
}
rigMark(){ ## spawn id -- who the mark names, or `none`
	cat "$rigWs/.local/agents/sessions/$1/dismissed" 2> /dev/null || printf 'none'
}
rigChat(){ ## session id -- how many DISMISSED blocks the session's chat holds, over every file of its folder
	LC_ALL=C grep -r -c -x 'DISMISSED' "$rigWs/.local/agents/sessions/$1" 2> /dev/null | LC_ALL=C awk -F: '{ n += $NF } END { print n + 0 }'
}

echo "-- 1. a session's id stops every live run of it --"
rigRun --manager-session-stop --session-id sess-one
rigAssert "rc 0, one stop row a live run, each dismissed, the finished run left alone" "$rigRc [$( rigRows stop | LC_ALL=C tr '\n' '|' )]" "0 [stop sess-one run-a keeper-rig dismissed|stop sess-one sess-one magic-coordinator dismissed|]"
rigWho="$( rigMark sess-one )"
rigAssert "the marks name who stopped them, one name for both, and the finished run has none" "$( [ -n "$rigWho" ] && [ "$rigWho" != none ] && printf named ) $( rigMark run-a ) $( rigMark run-z )" "named $rigWho none"
rigAssert "the session's chat holds the two DISMISSED blocks" "$( rigChat sess-one )" "2"
rigAssert "the other session is untouched" "$( rigMark sess-two ) $( rigMark run-x )" "none none"

echo "-- 2. the same call again --"
rigRun --manager-session-stop --session-id sess-one
rigAssert "each run reads already-dismissed, and no new block is written" "$rigRc [$( rigRows stop | LC_ALL=C awk '{ print $NF }' | LC_ALL=C tr '\n' ' ' )] $( rigChat sess-one )" "0 [already-dismissed already-dismissed ] 2"

echo "-- 3. --run takes the id as one run's own --"
rigRun --manager-session-stop --session-id run-x --run
rigAssert "that run alone is dismissed" "$rigRc [$( rigRows stop | LC_ALL=C tr '\n' '|' )] $( rigMark run-x ) $( rigMark sess-two )" "0 [stop run-x run-x keeper-rig dismissed|] $rigWho none"

echo "-- 4. an id nobody has, and one that is no name --"
rigRun --manager-session-stop --session-id sess-none
rigAssert "one none row, rc 0" "$rigRc [$( rigRows none | LC_ALL=C cut -d' ' -f1,2 )]" "0 [none sess-none]"
rigRun --manager-session-stop --session-id '../x'
rigAssert "a name with a slash is refused: rc 1, a word on stderr, no row" "$rigRc $( [ -s "$rigTmp/err" ] && printf said || printf silent ) $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" "1 said 0"

echo "-- 5. the syntax --"
rigRun --manager-session-stop
rigAssert "no --session-id is refused with the syntax" "$rigRc $( LC_ALL=C grep -c -F 'syntax is --session-id <id> [--run]' "$rigTmp/err" )" "1 1"
rigRun --manager-session-stop --session-id
rigAssert "--session-id with no value is refused" "$rigRc $( LC_ALL=C grep -c -F 'needs an id' "$rigTmp/err" )" "1 1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SESSION STOP CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	exit 1
fi
echo "MANAGER_SESSION_STOP: OK ($rigPassCount assertions, offline)"
