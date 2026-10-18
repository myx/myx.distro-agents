#!/usr/bin/env bash
## Behavioural check: a session grant survives a restart (AgentsToolsGrantsItemRuns,
## AgentsTools.Grants.include). An allow for the session is given to one run of a member. A
## review return starts that run again under a new spawn id, and what was allowed must hold for
## it: for every run of the same member on the same board item in the same coworking session,
## until the item is closed or that session ends, and never for another member, another item
## or another session.
## Proved through the real path: a served Write refused by the harness gate and recorded, the
## grant opened on that refusal, the item returned by `--member-review-return`, the spawn proxy
## starting the new run, and that run's served Write decided by the gate's own grant read
## (`--intern-op-permission-grant-read`).
## Red recipe: drop the AgentsToolsPermissionItemRunsScan call from
## --intern-op-permission-grant-read, and section 2 fails on the restarted run's call.
## Offline: a fake `curl` first on PATH logs each Slack call and opens no socket; a fake
## DistroAgentsConsole.sh stands in for the CLI; the board, sandboxes and workspace are this
## rig's own temp tree, guarded on every call. Never the live team data or .local/agents.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigHarness="$rigLib/AgentsUniversalHarness.sh"
rigFixture="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/slack-send-identity-check.curl.stub.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
[ -f "$rigHarness" ] || rigRefuse "harness not found: $rigHarness"
[ -f "$rigFixture" ] || rigRefuse "the fake curl fixture is missing: $rigFixture"
## A spawn of this rig that is not waited for starts the control thread of its session, a detached process that
## outlives this check: the rig ends it, before its tree is removed (the guard is in AgentsSessionControlStartCheck).
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
rigTmp="$( mktemp -d -t AgentsSessionGrantRestartCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## The hold file keeps a restarted run alive; without it every fake console ends at once.
trap 'rm -f "$rigTmp/hold" ; sleep 2 ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data"
rigWs="$rigTmp/ws"
rigSpawned="$rigWs/.local/agents/spawned"
rigSessions="$rigWs/.local/agents/sessions"
mkdir -p "$rigData/board/running" "$rigData/board/review" "$rigData/board/processed" "$rigData/board/pending" \
	"$rigWs/.local/.agents" "$rigSpawned" "$rigSessions" "$rigTmp/bin" "$rigWs/ELSE"
cp "$rigFixture" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl" || rigRefuse "could not install the fake curl"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
for rigMember in magic-coordinator keeper-myx magic-tester ; do
	mkdir -p "$rigWs/.local/agents/members/$rigMember"
	printf -- '---\nname: %s\ndescription: rig member\n---\n' "$rigMember" > "$rigWs/.local/agents/members/$rigMember/SKILL.md"
	printf 'rig\n' > "$rigWs/.local/agents/members/$rigMember/$rigMember.basic.md"
done
## The fake console: the vintage strings the proxy greps for; its stdin kept per spawn; it runs
## while the rig's hold file is there, so a restarted run can be asked as a running one.
printf '#!/bin/sh\n## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli)\ncat >> "$RIG_TMP/console-in.$MDAT_SPAWN_SESSION_ID"\necho rig-child-output\nwhile [ -e "$RIG_TMP/hold" ] ; do sleep 1 ; done\nexit 0\n' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"
rigHost="$( hostname -s 2> /dev/null )" || rigHost="unknown"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One command in the rig, guarded to its own trees, the fake curl first on PATH. Extra
## environment as NAME=value words in rigEnv. Output into <result>, rc into <result>.rc.
rigEnv=()
rigRun(){ ## result file, command...
	local runOut="$1" ; shift
	: > "$rigTmp/calls" ; : > "$rigTmp/bodies"
	env -i HOME="$rigTmp" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_SCENARIO="$rigTmp" "${rigEnv[@]+"${rigEnv[@]}"}" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			[ "$( command -v curl )" = "$RIG_TMP/bin/curl" ] || exit 98
			cd "$MMDAPP" && exec "$@"
		' rig "$@" > "$runOut" 2>&1
	printf '%s' "$?" > "$runOut.rc"
}
rigOp(){ ## result file, DistroAgentsTools.fn.sh args...
	local opOut="$1" ; shift
	rigRun "$opOut" bash "$rigFn" "$@"
}
rigTool(){ ## result file, tool name, arguments JSON -- one served harness tool call
	printf '%s\n' "$3" > "$rigTmp/tool.args"
	rigRun "$1" bash -c 'exec bash "$0" --intern-tool "$1" < "$2"' "$rigHarness" "$2" "$rigTmp/tool.args"
}
rigItem(){ ## state, item stem, spawn-id
	printf -- '---\ntype: dispatch\nowner: keeper-myx\nstatus: dispatch-started\nspawn-id: %s\n---\n\n# rig dispatch\n' "$3" > "$rigData/board/$1/$2.md"
}
rigRecord(){ ## spawn-id, status, coworking session id, owner, item link line (may be empty), folder
	mkdir -p "$rigSpawned/$6"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-session-id: none\ntracking-name: %s\nhost: %s\nowner: %s\nstatus: %s\nsession-thread: CSES00001:1700000000.000100\n%s---\n' \
		"$3" "$1" "$6" "$rigHost" "$4" "$2" "${5:+$5
}" > "$rigSpawned/$6/$1.md"
}
rigStatus(){ ## record file, new status
	LC_ALL=C sed -i.bak "s/^status: .*\$/status: $2/" "$1" && rm -f "$1.bak"
}
rigLoc(){ ## item stem -- the board state holding it, or not-found
	local stateDir
	for stateDir in "$rigData"/board/*/ ; do
		[ -f "$stateDir$1.md" ] && { basename "$stateDir" ; return 0 ; }
	done
	printf 'not-found'
}
rigWaitFor(){ ## seconds, test command...
	local waitLeft="$1" ; shift
	while ! "$@" && [ "$waitLeft" -gt 0 ] ; do sleep 1 ; waitLeft=$(( waitLeft - 1 )) ; done
}
## A served Write as one member's run: prints `written` when the file then holds the content,
## `refused <refusal id>` when the gate recorded a refusal, else `failed`.
rigWrite(){ ## member, session, path, content
	rigEnv=( MDAT_SPAWN_AGENT="$1" MDAT_SPAWN_SESSION_ID="$2" )
	rigTool "$rigTmp/write.out" Write "{\"file_path\":\"$3\",\"content\":\"$4\"}"
	rigEnv=()
	if [ -f "$3" ] && [ "$( cat "$3" )" = "$4" ] ; then printf 'written' ; return 0 ; fi
	rigWriteId="$( LC_ALL=C sed -n 's/^REFUSAL-ID: \(refusal-[0-9a-f-]*\)$/\1/p' "$rigTmp/write.out" | head -1 )"
	if [ -n "$rigWriteId" ] ; then printf 'refused %s' "$rigWriteId" ; else printf 'failed' ; fi
}
## The refusal id of a served Write the gate refuses, or empty.
rigRefusalOf(){ ## member, session, path
	local refusalSaid
	refusalSaid="$( rigWrite "$1" "$2" "$3" rig-asked )"
	case "$refusalSaid" in 'refused '*) printf '%s' "${refusalSaid#refused }" ;; esac
}
rigGrantOpen(){ ## approver, session, refusal id, kind -- prints the GRANT line's kind, or empty
	rigOp "$rigTmp/open.out" --intern-op-permission-grant-open "$1" --session-id "$2" --refusal-id "$3" --kind "$4"
	LC_ALL=C sed -n 's/^GRANT: \([a-z]*\) .*$/\1/p' "$rigTmp/open.out" | head -1
}
rigGrantRead(){ ## member, session, path -- prints the kind a Write there is granted by, or empty
	rigOp "$rigTmp/read.out" --intern-op-permission-grant-read "$1" --session-id "$2" --tool Write --target "$3"
	LC_ALL=C sed -n 's/^GRANT: \([a-z]*\) .*$/\1/p' "$rigTmp/read.out" | head -1
}
## The item returned from review by the coordinator: the run its return started, by its spawn id.
rigReturn(){ ## item stem, sandbox folder, spawn ids known so far (space-separated)
	local returnRecord returnId
	rigOp "$rigTmp/return.out" --member-review-return magic-coordinator "$1" --message "redo the rig step"
	for returnRecord in "$rigSpawned/$2"/*.md ; do
		[ -f "$returnRecord" ] || continue
		returnId="${returnRecord##*/}" ; returnId="${returnId%.md}"
		case " $3 " in *" $returnId "*) continue ;; esac
		printf '%s' "$returnId"
		return 0
	done
}

## ---------------------------------------------------------------- the grant, in the run it was given to
echo "-- 1. a session grant is given to one run: its refused Write is allowed for the session --"
## The coworking session rig-cow is a root session: no spawn record, ended by its own marker.
rigItemA="dispatch-20261011T1200Z-grant-a"
rigFileA="$rigWs/ELSE/a.txt"
rigRecord rig-run-1 spawn-started rig-cow keeper-myx "spawns: $rigItemA" trk-rig-a
rigItem running "$rigItemA" rig-run-1
rigIdA="$( rigRefusalOf keeper-myx rig-run-1 "$rigFileA" )"
[ -n "$rigIdA" ] || { cat "$rigTmp/write.out" >&2 ; rigRefuse "the harness gate recorded no refusal for the rig's Write" ; }
rigIdLate="$( rigRefusalOf keeper-myx rig-run-1 "$rigWs/ELSE/late.txt" )"
rigIdOnce="$( rigRefusalOf keeper-myx rig-run-1 "$rigWs/ELSE/once.txt" )"
[ -n "$rigIdLate" ] && [ -n "$rigIdOnce" ] || rigRefuse "the harness gate recorded no refusal for the rig's other Writes"
rigAssert "nothing is granted before the answer"           "$( rigGrantRead keeper-myx rig-run-1 "$rigFileA" )" ""
rigAssert "the human-owner allows it for the session"      "$( rigGrantOpen human-owner rig-run-1 "$rigIdA" session )" session
rigAssert "it is kept in that run's own store"             "$( LC_ALL=C grep -c -F -- ":$rigIdA" "$rigSessions/rig-run-1/grants" 2> /dev/null )" 1
rigAssert "the run's call goes through"                    "$( rigWrite keeper-myx rig-run-1 "$rigFileA" first-run )" written

## ---------------------------------------------------------------- the restarted run
echo "-- 2. the item is returned, the run restarted under a new id: the same call goes through --"
rigStatus "$rigSpawned/trk-rig-a/rig-run-1.md" spawn-succeeded
mv "$rigData/board/running/$rigItemA.md" "$rigData/board/review/$rigItemA.md"
: > "$rigTmp/hold"
rigRun2="$( rigReturn "$rigItemA" trk-rig-a "rig-run-1" )"
rigAssert "the return restarted the member"                "$( cat "$rigTmp/return.out.rc" ):$( LC_ALL=C grep -c "^RETURN: restarted keeper-myx on $rigItemA" "$rigTmp/return.out" )" 0:1
[ -n "$rigRun2" ] || { cat "$rigTmp/return.out" >&2 ; rigRefuse "the return started no new run" ; }
rigWaitFor 20 test -s "$rigTmp/console-in.$rigRun2"
rigAssert "the new run has a new id, in the same coworking session, on the same item" \
	"$( [ "$rigRun2" != rig-run-1 ] && printf new ):$( LC_ALL=C grep -c -x 'session-id: rig-cow' "$rigSpawned/trk-rig-a/$rigRun2.md" ):$( LC_ALL=C grep -c -x "spawned-by: $rigItemA" "$rigSpawned/trk-rig-a/$rigRun2.md" )" new:1:1
rigAssert "control: it is running, and its own store holds no grant" \
	"$( LC_ALL=C grep -c -x 'status: spawn-started' "$rigSpawned/trk-rig-a/$rigRun2.md" ):$( rigLoc "$rigItemA" ):$( [ -s "$rigSessions/$rigRun2/grants" ] && printf has || printf none )" 1:running:none
rigAssert "the grant read admits the restarted run's call" "$( rigGrantRead keeper-myx "$rigRun2" "$rigFileA" )" session
rigAssert "and names the grant it was given"               "$( LC_ALL=C grep -c -x "GRANT: session $rigIdA" "$rigTmp/read.out" )" 1
rigAssert "the restarted run's served Write goes through"  "$( rigWrite keeper-myx "$rigRun2" "$rigFileA" second-run )" written
rigOp "$rigTmp/holds.out" --intern-op-permission-holds keeper-myx Write "$rigFileA" --session-id "$rigRun2"
rigAssert "the member holds it in the restarted run"       "$( LC_ALL=C grep -E '^(HOLDS|NOT-HOLDS)' "$rigTmp/holds.out" | head -1 )" "HOLDS granted session $rigIdA"
rigOp "$rigTmp/list.out" --intern-op-permission-list keeper-myx --session-id "$rigRun2"
rigAssert "its list shows the grant, and when it ends"     "$( LC_ALL=C awk -F'\t' -v item="$rigItemA" '$1 == "session" && $2 == "Write" && $6 == "while item " item " is open and session rig-cow runs" { hit++ ; } END { print hit + 0 ; }' "$rigTmp/list.out" )" 1
rigOp "$rigTmp/list-all.out" --intern-op-permission-list keeper-myx
rigAssert "and so does its list over every session"        "$( LC_ALL=C awk -F'\t' -v item="$rigItemA" '$1 == "session" && $2 == "Write" && $6 == "while item " item " is open and session rig-cow runs" { hit++ ; } END { print hit + 0 ; }' "$rigTmp/list-all.out" )" 1
rigAssert "the run that ended holds nothing any more"      "$( rigGrantRead keeper-myx rig-run-1 "$rigFileA" )" ""

## ---------------------------------------------------------------- never beyond
echo "-- 3. it never extends to another member, another item or another session --"
rigItemB="dispatch-20261011T1200Z-grant-b"
rigItem running "$rigItemB" rig-run-b
rigRecord rig-run-other spawn-started rig-cow magic-tester "spawned-by: $rigItemA" trk-rig-other
rigRecord rig-run-b spawn-started rig-cow keeper-myx "spawned-by: $rigItemB" trk-rig-b
rigRecord rig-run-c spawn-started rig-cow-2 keeper-myx "spawned-by: $rigItemA" trk-rig-c
rigRecord rig-run-d spawn-started rig-cow keeper-myx "" trk-rig-d
rigAssert "another member's run on the same item is not let through" "$( rigGrantRead magic-tester rig-run-other "$rigFileA" )" ""
rigAssert "nor is its served Write"                        "$( rigWrite magic-tester rig-run-other "$rigFileA" other-member | LC_ALL=C sed 's/ .*//' ):$( cat "$rigFileA" )" refused:second-run
rigAssert "nor the member itself under another member's run" "$( rigGrantRead keeper-myx rig-run-other "$rigFileA" )" ""
rigAssert "the same member's run on another item is not let through" "$( rigGrantRead keeper-myx rig-run-b "$rigFileA" )" ""
rigAssert "nor is its served Write"                        "$( rigWrite keeper-myx rig-run-b "$rigFileA" other-item | LC_ALL=C sed 's/ .*//' ):$( cat "$rigFileA" )" refused:second-run
rigAssert "the same member's run on that item in another session is not let through" "$( rigGrantRead keeper-myx rig-run-c "$rigFileA" )" ""
rigAssert "nor a run of that member in the session that works no item" "$( rigGrantRead keeper-myx rig-run-d "$rigFileA" )" ""
rigAssert "control: the restarted run is still let through" "$( rigGrantRead keeper-myx "$rigRun2" "$rigFileA" )" session

## ---------------------------------------------------------------- answered late, once, every restart
echo "-- 4. an allow answered after the restart reaches the new run; an allow-once stays the old run's --"
rigAssert "the earlier run's other refused call is not granted yet" "$( rigGrantRead keeper-myx "$rigRun2" "$rigWs/ELSE/late.txt" )" ""
rigAssert "it is allowed for the session after the restart" "$( rigGrantOpen human-owner rig-run-1 "$rigIdLate" session )" session
rigAssert "and the restarted run's served Write goes through" "$( rigWrite keeper-myx "$rigRun2" "$rigWs/ELSE/late.txt" late-run )" written
rigAssert "an allow-once is opened on the earlier run's third call" "$( rigGrantOpen human-owner rig-run-1 "$rigIdOnce" once )" once
rigAssert "and is not the restarted run's"                 "$( rigGrantRead keeper-myx "$rigRun2" "$rigWs/ELSE/once.txt" )" ""

echo "-- 5. every restart: the run restarted a second time is let through too --"
rm -f "$rigTmp/hold"
rigWaitFor 40 test -f "$rigData/board/review/$rigItemA.md"
rigAssert "the second run ended, its item back in review"  "$( rigLoc "$rigItemA" )" review
rigAssert "the grant holds while the item waits in review" "$( rigGrantRead keeper-myx "$rigRun2" "$rigFileA" )" session
: > "$rigTmp/hold"
rigRun3="$( rigReturn "$rigItemA" trk-rig-a "rig-run-1 $rigRun2" )"
[ -n "$rigRun3" ] || { cat "$rigTmp/return.out" >&2 ; rigRefuse "the second return started no new run" ; }
rigWaitFor 20 test -s "$rigTmp/console-in.$rigRun3"
rigAssert "a third run, two ids on from the grant"         "$( [ "$rigRun3" != "$rigRun2" ] && [ "$rigRun3" != rig-run-1 ] && printf new ):$( LC_ALL=C grep -c -x 'session-id: rig-cow' "$rigSpawned/trk-rig-a/$rigRun3.md" )" new:1
rigAssert "its call goes through"                          "$( rigGrantRead keeper-myx "$rigRun3" "$rigFileA" ):$( rigWrite keeper-myx "$rigRun3" "$rigFileA" third-run )" session:written

## ---------------------------------------------------------------- its end
echo "-- 6. it ends when the coworking session ends, when the item is closed, and when it is revoked --"
mkdir -p "$rigSessions/rig-cow" && : > "$rigSessions/rig-cow/ended"
rigAssert "the coworking session ended: not let through"   "$( rigGrantRead keeper-myx "$rigRun3" "$rigFileA" )" ""
rigAssert "nor is the served Write"                        "$( rigWrite keeper-myx "$rigRun3" "$rigFileA" after-session | LC_ALL=C sed 's/ .*//' ):$( cat "$rigFileA" )" refused:third-run
rm -f "$rigSessions/rig-cow/ended"
rigAssert "control: the session running again, let through" "$( rigGrantRead keeper-myx "$rigRun3" "$rigFileA" )" session
mv "$rigData/board/running/$rigItemA.md" "$rigData/board/processed/$rigItemA.md"
rigAssert "the item closed: not let through"               "$( rigGrantRead keeper-myx "$rigRun3" "$rigFileA" )" ""
rigAssert "nor is the served Write"                        "$( rigWrite keeper-myx "$rigRun3" "$rigFileA" after-close | LC_ALL=C sed 's/ .*//' ):$( cat "$rigFileA" )" refused:third-run
rigOp "$rigTmp/list-closed.out" --intern-op-permission-list keeper-myx --session-id "$rigRun3"
rigAssert "and its list no longer shows it"                "$( LC_ALL=C awk -F'\t' '$1 == "session" { hit++ ; } END { print hit + 0 ; }' "$rigTmp/list-closed.out" )" 0
mv "$rigData/board/processed/$rigItemA.md" "$rigData/board/running/$rigItemA.md"
rigAssert "control: the item open again, let through"      "$( rigGrantRead keeper-myx "$rigRun3" "$rigFileA" )" session
rigOp "$rigTmp/revoke.out" --intern-op-permission-revoke "$rigIdA" --session-id "$rigRun3"
rigAssert "revoked by its id, named by the restarted run"  "$( cat "$rigTmp/revoke.out.rc" ):$( LC_ALL=C grep -c -x "REVOKED: $rigIdA" "$rigTmp/revoke.out" )" 0:1
rigAssert "revoked: not let through"                       "$( rigGrantRead keeper-myx "$rigRun3" "$rigFileA" )" ""
rigAssert "nor is the served Write"                        "$( rigWrite keeper-myx "$rigRun3" "$rigFileA" after-revoke | LC_ALL=C sed 's/ .*//' ):$( cat "$rigFileA" )" refused:third-run
rigAssert "the other grant of that run still stands"       "$( rigGrantRead keeper-myx "$rigRun3" "$rigWs/ELSE/late.txt" )" session
rm -f "$rigTmp/hold"
rigWaitFor 40 test -f "$rigData/board/review/$rigItemA.md"

## ---------------------------------------------------------------- a session the first run started
echo "-- 7. a run that started its own session: the restart joins that session, and is let through --"
rigItemL="dispatch-20261011T1200Z-grant-l"
rigFileL="$rigWs/ELSE/l.txt"
rigRecord rig-lone-1 spawn-started rig-lone-1 keeper-myx "spawns: $rigItemL" trk-rig-l
rigItem running "$rigItemL" rig-lone-1
rigIdL="$( rigRefusalOf keeper-myx rig-lone-1 "$rigFileL" )"
[ -n "$rigIdL" ] || rigRefuse "the harness gate recorded no refusal for the lone run's Write"
rigAssert "allowed for the session"                        "$( rigGrantOpen human-owner rig-lone-1 "$rigIdL" session ):$( rigGrantRead keeper-myx rig-lone-1 "$rigFileL" )" session:session
rigStatus "$rigSpawned/trk-rig-l/rig-lone-1.md" spawn-succeeded
mv "$rigData/board/running/$rigItemL.md" "$rigData/board/review/$rigItemL.md"
: > "$rigTmp/hold"
rigLone2="$( rigReturn "$rigItemL" trk-rig-l "rig-lone-1" )"
[ -n "$rigLone2" ] || { cat "$rigTmp/return.out" >&2 ; rigRefuse "the return of the lone run started no new run" ; }
rigWaitFor 20 test -s "$rigTmp/console-in.$rigLone2"
rigAssert "the new run joined the session its first run started" "$( LC_ALL=C grep -c -x 'session-id: rig-lone-1' "$rigSpawned/trk-rig-l/$rigLone2.md" )" 1
rigAssert "its call goes through"                          "$( rigGrantRead keeper-myx "$rigLone2" "$rigFileL" ):$( rigWrite keeper-myx "$rigLone2" "$rigFileL" lone-second )" session:written
mv "$rigData/board/running/$rigItemL.md" "$rigData/board/processed/$rigItemL.md"
rigAssert "until the item is closed"                       "$( rigGrantRead keeper-myx "$rigLone2" "$rigFileL" )" ""
mv "$rigData/board/processed/$rigItemL.md" "$rigData/board/running/$rigItemL.md"
rm -f "$rigTmp/hold"
rigWaitFor 40 test -f "$rigData/board/review/$rigItemL.md"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SESSION GRANT RESTART CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_GRANT_RESTART: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
