#!/usr/bin/env bash
## Behavioural check: the session permission index of a session that reads more than one grant
## store (AgentsToolsGrantsSessionText, AgentsTools.Grants.include). Every run of a member that
## joined a coworking session is one: it reads its own store, that session's and its parent's.
## The stores go to AgentsGrantsSessionIndex.awk in the environment, because a -v value takes no
## newline in every awk. Passed with -v, one-true-awk refused them: the index was never built,
## and every file tool call said so on stderr and was decided by the slower grant read.
## Proved through the real paths: a served Write decided by the harness gate, and the native
## client's PreToolUse hook (client-hooks/allow-granted-native-tool.sh), which decides by the
## session index alone and names what admitted the call.
##   1. the index of such a run is built, a store row for each store it reads, no error line;
##   2. it decides by a grant in each of the three stores, and sees a revoke in a joined one;
##   3. a session grant given to the member's earlier run on the same board item is a `runs` row
##      of the restarted run's index (AgentsToolsGrantsItemRuns): its coworking session and its
##      item are checked at the call, an allow answered after the restart is joined, a revoke
##      takes it, and it is never another member's, another item's or another session's;
##   4. the same for a run that started its own session, which has no session to end it;
##   5. the awk reads its stores from the environment, and one store named with -v.
## Red recipe: hand the stores to the awk with -v again in AgentsToolsGrantsSessionText, and
## section 1 fails on the index that is not there.
## Offline: a fake `curl` first on PATH logs each Slack call and opens no socket; a fake
## DistroAgentsConsole.sh stands in for the CLI; the board, sandboxes and workspace are this
## rig's own temp tree, guarded on every call. Never the live team data or .local/agents.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigHarness="$rigLib/AgentsUniversalHarness.sh"
rigHook="$rigLib/client-hooks/allow-granted-native-tool.sh"
rigFixture="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/slack-send-identity-check.curl.test.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
[ -f "$rigHarness" ] || rigRefuse "harness not found: $rigHarness"
[ -f "$rigHook" ] || rigRefuse "the native client's hook is missing: $rigHook"
[ -f "$rigFixture" ] || rigRefuse "the fake curl fixture is missing: $rigFixture"
## A spawn of this rig that is not waited for starts the control thread of its session, a detached process that
## outlives this check: the rig ends it, before its tree is removed (the guard is in AgentsSessionControlStartCheck).
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.test.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.test.sh"
rigTmp="$( mktemp -d -t AgentsSessionIndexJoinedStoresCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## The hold file keeps a restarted run alive; without it every fake console ends at once.
trap 'rm -f "$rigTmp/hold" ; sleep 2 ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data"
rigWs="$rigTmp/ws"
rigSpawned="$rigWs/.local/agents/spawned"
rigSessions="$rigWs/.local/agents/sessions"
mkdir -p "$rigData/board/running" "$rigData/board/review" "$rigData/board/processed" "$rigData/board/pending" \
	"$rigWs/.local/.agents" "$rigSpawned" "$rigSessions" "$rigTmp/bin" "$rigWs/ELSE" "$rigWs/COORD"
cp "$rigFixture" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl" || rigRefuse "could not install the fake curl"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
for rigMember in magic-coordinator keeper-myx magic-tester ; do
	mkdir -p "$rigWs/.local/agents/members/$rigMember"
	printf -- '---\nname: %s\ndescription: rig member\n---\n' "$rigMember" > "$rigWs/.local/agents/members/$rigMember/SKILL.md"
	printf 'rig\n' > "$rigWs/.local/agents/members/$rigMember/$rigMember.basic.md"
done
## The coordinator's standing write, which it passes on in section 2.
printf 'magic-coordinator:ws:workspace:Edit(/%s/COORD/**)\n' "$rigWs" > "$rigWs/.local/agents/permissions.registry"
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
rigRecord(){ ## spawn-id, status, coworking session id, owner, item link line (may be empty), folder, parent session id (default none)
	mkdir -p "$rigSpawned/$6"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-session-id: %s\ntracking-name: %s\nhost: %s\nowner: %s\nstatus: %s\nsession-thread: CSES00001:1700000000.000100\n%s---\n' \
		"$3" "$1" "${7:-none}" "$6" "$rigHost" "$4" "$2" "${5:+$5
}" > "$rigSpawned/$6/$1.md"
}
rigStatus(){ ## record file, new status
	LC_ALL=C sed -i.bak "s/^status: .*\$/status: $2/" "$1" && rm -f "$1.bak"
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
## How many times the last served call said its session index could not be built.
rigNotBuilt(){
	LC_ALL=C grep -c -F -- 'could not be built' "$rigTmp/write.out"
}
rigGrantOpen(){ ## approver, session, refusal id, kind -- prints the GRANT line's kind, or empty
	rigOp "$rigTmp/open.out" --intern-op-permission-grant-open "$1" --session-id "$2" --refusal-id "$3" --kind "$4"
	LC_ALL=C sed -n 's/^GRANT: \([a-z]*\) .*$/\1/p' "$rigTmp/open.out" | head -1
}
## The native client's PreToolUse hook asked about a Write, as one member's run. It decides by
## the session index alone: `allow <what admitted it>`, `none` when no row does, else `deny`.
rigHookWrite(){ ## member, session, path
	local hookOut
	printf '{"session_id":"%s","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"%s","content":"rig"}}' "$2" "$rigWs" "$3" > "$rigTmp/hook.in"
	hookOut="$( env -i HOME="$rigTmp" PATH=/usr/bin:/bin:/usr/sbin:/sbin MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SPAWN_AGENT="$1" MDAT_SPAWN_SESSION_ID="$2" bash "$rigHook" < "$rigTmp/hook.in" 2> "$rigTmp/hook.err" )"
	case "$hookOut" in
		'') printf 'none' ;;
		*'"permissionDecision": "allow"'*) printf 'allow %s' "$( printf '%s\n' "$hookOut" | LC_ALL=C sed -n "s/.*\"permissionDecisionReason\": \"granted to $1: \\(.*\\)\"\$/\\1/p" )" ;;
		*) printf 'deny' ;;
	esac
}
## One kind of rows of a run's session index, its fields after the first joined by `|`, a `;` after each row.
rigRows(){ ## session, member, kind
	LC_ALL=C awk -F'\t' -v kind="$3" '$1 == kind { for ( at = 2 ; at <= NF ; at++ ) printf "%s%s", ( at > 2 ? "|" : "" ), $at ; printf ";" ; }' "$rigSessions/$1/permissions.$2.index" 2> /dev/null
}
## The runs rows of a run's session index without their pattern: tool|grant|item|coworking session store, a `;` after each.
rigRunsRows(){ ## session, member
	LC_ALL=C awk -F'\t' '$1 == "runs" { printf "%s|%s|%s|%s;", $2, $4, $5, $6 ; }' "$rigSessions/$1/permissions.$2.index" 2> /dev/null
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

## ---------------------------------------------------------------- the index of a run that joined a session
echo "-- 1. a run that joined a coworking session reads three stores: its session index is built --"
## rig-cow and rig-up are root sessions: no spawn record. The coordinator's run and keeper-myx's
## both joined rig-cow, and both were spawned from rig-up.
rigItemA="dispatch-20261012T1200Z-index-a"
rigFileA="$rigWs/ELSE/a.txt"
rigRecord rig-coord spawn-started rig-cow magic-coordinator "" trk-rig-coord rig-up
rigRecord rig-run-1 spawn-started rig-cow keeper-myx "spawns: $rigItemA" trk-rig-a rig-up
rigItem running "$rigItemA" rig-run-1
rigIdA="$( rigRefusalOf keeper-myx rig-run-1 "$rigFileA" )"
[ -n "$rigIdA" ] || { cat "$rigTmp/write.out" >&2 ; rigRefuse "the harness gate recorded no refusal for the rig's Write" ; }
rigAssert "the gate's call says nothing of an index that could not be built" "$( rigNotBuilt )" 0
rigAssert "the index is there, in the run's own store"     "$( [ -f "$rigSessions/rig-run-1/permissions.keeper-myx.index" ] && printf built || printf absent )" built
rigAssert "a store row each: its own, the coworking session's, its parent's" "$( rigRows rig-run-1 keeper-myx store )" "$rigSessions/rig-run-1;$rigSessions/rig-cow;$rigSessions/rig-up;"
rigIdLate="$( rigRefusalOf keeper-myx rig-run-1 "$rigWs/ELSE/late.txt" )"
[ -n "$rigIdLate" ] || rigRefuse "the harness gate recorded no refusal for the rig's other Write"

## ---------------------------------------------------------------- a grant in each store
echo "-- 2. the index decides by a grant in each store, and sees a revoke in a joined store --"
rigAssert "control: nothing admits the refused call yet"   "$( rigHookWrite keeper-myx rig-run-1 "$rigFileA" )" none
rigAssert "allowed for the session: a grant in its own store" "$( rigGrantOpen human-owner rig-run-1 "$rigIdA" session )" session
rigAssert "the index admits the call, by that grant"       "$( rigHookWrite keeper-myx rig-run-1 "$rigFileA" )" "allow session $rigIdA"
rigAssert "and the served Write goes through, no error line" "$( rigWrite keeper-myx rig-run-1 "$rigFileA" own-store ):$( rigNotBuilt )" written:0
## The coordinator holds a standing write under COORD/ and passes two files on for the session:
## one in the coworking session it works in, one in the session both runs were spawned from.
rigPass(){ ## path, session -- the reference of the pass, or empty
	rigEnv=( MDAT_SPAWN_AGENT=magic-coordinator MDAT_SPAWN_SESSION_ID=rig-coord )
	rigOp "$rigTmp/pass.out" --member-permission-pass magic-coordinator --to keeper-myx --tool Write --target "$1" --kind session --session-id "$2"
	rigEnv=()
	LC_ALL=C sed -n 's/^GRANT: session \(pass-[0-9a-f-]*\)$/\1/p' "$rigTmp/pass.out" | head -1
}
rigPassCow="$( rigPass "$rigWs/COORD/cow.txt" rig-coord )"
[ -n "$rigPassCow" ] || { cat "$rigTmp/pass.out" >&2 ; rigRefuse "the coordinator's pass for the coworking session was not written" ; }
rigAssert "a write passed for the coworking session is kept in that session's store" "$( LC_ALL=C grep -c -F -- ":$rigPassCow" "$rigSessions/rig-cow/grants" 2> /dev/null )" 1
rigAssert "the index admits it, by that grant"             "$( rigHookWrite keeper-myx rig-run-1 "$rigWs/COORD/cow.txt" )" "allow session $rigPassCow"
rigPassUp="$( rigPass "$rigWs/COORD/up.txt" rig-up )"
[ -n "$rigPassUp" ] || { cat "$rigTmp/pass.out" >&2 ; rigRefuse "the coordinator's pass for the parent session was not written" ; }
rigAssert "one passed for the session that spawned both is kept in the parent's store" "$( LC_ALL=C grep -c -F -- ":$rigPassUp" "$rigSessions/rig-up/grants" 2> /dev/null )" 1
rigAssert "the index admits it too"                        "$( rigHookWrite keeper-myx rig-run-1 "$rigWs/COORD/up.txt" )" "allow session $rigPassUp"
rigAssert "the served Writes go through"                   "$( rigWrite keeper-myx rig-run-1 "$rigWs/COORD/cow.txt" cow-store ):$( rigWrite keeper-myx rig-run-1 "$rigWs/COORD/up.txt" parent-store )" written:written
rigAssert "a file no grant names is not admitted"          "$( rigHookWrite keeper-myx rig-run-1 "$rigWs/COORD/none.txt" )" none
## A revoke touches the store that holds the grant, and no other: the index is rebuilt because
## it lists that store.
rigOp "$rigTmp/revoke.out" --intern-op-permission-revoke "$rigPassCow"
rigAssert "the pass is revoked, in the coworking session's store" "$( cat "$rigTmp/revoke.out.rc" ):$( LC_ALL=C grep -c -x "REVOKED: $rigPassCow" "$rigTmp/revoke.out" ):$( [ -f "$rigSessions/rig-cow/revoked/$rigPassCow" ] && printf marker || printf none )" 0:1:marker
rigAssert "the index no longer admits it"                  "$( rigHookWrite keeper-myx rig-run-1 "$rigWs/COORD/cow.txt" )" none
rigAssert "nor does the gate"                              "$( rigWrite keeper-myx rig-run-1 "$rigWs/COORD/cow.txt" after-revoke | LC_ALL=C sed 's/ .*//' ):$( cat "$rigWs/COORD/cow.txt" )" refused:cow-store
rigAssert "the grants of the other two stores still stand" "$( rigHookWrite keeper-myx rig-run-1 "$rigFileA" ):$( rigHookWrite keeper-myx rig-run-1 "$rigWs/COORD/up.txt" )" "allow session $rigIdA:allow session $rigPassUp"

## ---------------------------------------------------------------- the restarted run
echo "-- 3. the session grant of the member's earlier run is a runs row of the restarted run's index --"
rigStatus "$rigSpawned/trk-rig-a/rig-run-1.md" spawn-succeeded
mv "$rigData/board/running/$rigItemA.md" "$rigData/board/review/$rigItemA.md"
: > "$rigTmp/hold"
rigRun2="$( rigReturn "$rigItemA" trk-rig-a "rig-run-1" )"
[ -n "$rigRun2" ] || { cat "$rigTmp/return.out" >&2 ; rigRefuse "the return started no new run" ; }
rigWaitFor 20 test -s "$rigTmp/console-in.$rigRun2"
rigAssert "control: a new run, in the same coworking session, on the same item, with no grant of its own" \
	"$( [ "$rigRun2" != rig-run-1 ] && printf new ):$( LC_ALL=C grep -c -x 'session-id: rig-cow' "$rigSpawned/trk-rig-a/$rigRun2.md" ):$( LC_ALL=C grep -c -x "spawned-by: $rigItemA" "$rigSpawned/trk-rig-a/$rigRun2.md" ):$( [ -s "$rigSessions/$rigRun2/grants" ] && printf has || printf none )" new:1:1:none
## A second on, so the index built next is strictly newer than every grant and stays current.
sleep 1
rigAssert "the restarted run's index admits the call, by the grant its earlier run was given" "$( rigHookWrite keeper-myx "$rigRun2" "$rigFileA" )" "allow session $rigIdA"
rigAssert "it is a runs row: the grant, the item, the coworking session's store" "$( rigRunsRows "$rigRun2" keeper-myx )" "Write|$rigIdA|$rigItemA|$rigSessions/rig-cow;"
rigAssert "and the earlier run's store is one the index lists" "$( rigRows "$rigRun2" keeper-myx store | LC_ALL=C tr ';' '\n' | LC_ALL=C grep -c -x -F -- "$rigSessions/rig-run-1" )" 1
## Its end is checked at the call: the session's end and the item's close touch no store.
sleep 1 ; : > "$rigTmp/marker" ; sleep 1
mkdir -p "$rigSessions/rig-cow" && : > "$rigSessions/rig-cow/ended"
rigAssert "the coworking session ended: not admitted, the index as it stood" \
	"$( rigHookWrite keeper-myx "$rigRun2" "$rigFileA" ):$( [ "$rigSessions/$rigRun2/permissions.keeper-myx.index" -nt "$rigTmp/marker" ] && printf rebuilt || printf kept )" none:kept
rm -f "$rigSessions/rig-cow/ended"
rigAssert "control: the session running again, admitted"   "$( rigHookWrite keeper-myx "$rigRun2" "$rigFileA" )" "allow session $rigIdA"
mv "$rigData/board/running/$rigItemA.md" "$rigData/board/processed/$rigItemA.md"
rigAssert "the item closed: not admitted, the index as it stood" \
	"$( rigHookWrite keeper-myx "$rigRun2" "$rigFileA" ):$( [ "$rigSessions/$rigRun2/permissions.keeper-myx.index" -nt "$rigTmp/marker" ] && printf rebuilt || printf kept )" none:kept
mv "$rigData/board/processed/$rigItemA.md" "$rigData/board/running/$rigItemA.md"
rigAssert "control: the item open again, admitted"         "$( rigHookWrite keeper-myx "$rigRun2" "$rigFileA" )" "allow session $rigIdA"
rigAssert "the served Write goes through, no error line"   "$( rigWrite keeper-myx "$rigRun2" "$rigFileA" second-run ):$( rigNotBuilt )" written:0
## An allow answered after the restart is written to the earlier run's store, which the index lists.
rigAssert "control: the earlier run's other refused call is not admitted yet" "$( rigHookWrite keeper-myx "$rigRun2" "$rigWs/ELSE/late.txt" )" none
rigAssert "an allow answered after the restart is joined"  "$( rigGrantOpen human-owner rig-run-1 "$rigIdLate" session ):$( rigHookWrite keeper-myx "$rigRun2" "$rigWs/ELSE/late.txt" )" "session:allow session $rigIdLate"
## Never beyond the member's own runs on that item in that session.
rigItemB="dispatch-20261012T1200Z-index-b"
rigItem running "$rigItemB" rig-run-b
rigRecord rig-run-other spawn-started rig-cow magic-tester "spawned-by: $rigItemA" trk-rig-other
rigRecord rig-run-b spawn-started rig-cow keeper-myx "spawned-by: $rigItemB" trk-rig-b
rigRecord rig-run-c spawn-started rig-cow-2 keeper-myx "spawned-by: $rigItemA" trk-rig-c
rigAssert "another member's run on the same item: not admitted, no runs row" "$( rigHookWrite magic-tester rig-run-other "$rigFileA" ):$( rigRunsRows rig-run-other magic-tester )" "none:"
rigAssert "the same member's run on another item: the same" "$( rigHookWrite keeper-myx rig-run-b "$rigFileA" ):$( rigRunsRows rig-run-b keeper-myx )" "none:"
rigAssert "the same member's run on that item in another session: the same" "$( rigHookWrite keeper-myx rig-run-c "$rigFileA" ):$( rigRunsRows rig-run-c keeper-myx )" "none:"
rigAssert "control: their indices were built"              "$( for rigOne in rig-run-other/permissions.magic-tester rig-run-b/permissions.keeper-myx rig-run-c/permissions.keeper-myx ; do [ -f "$rigSessions/$rigOne.index" ] && printf built || printf absent ; printf ' ' ; done )" "built built built "
rigOp "$rigTmp/revoke.out" --intern-op-permission-revoke "$rigIdA" --session-id "$rigRun2"
rigAssert "revoked by its id, named by the restarted run"  "$( cat "$rigTmp/revoke.out.rc" ):$( LC_ALL=C grep -c -x "REVOKED: $rigIdA" "$rigTmp/revoke.out" )" 0:1
rigAssert "revoked: not admitted, its row gone"            "$( rigHookWrite keeper-myx "$rigRun2" "$rigFileA" ):$( rigRunsRows "$rigRun2" keeper-myx )" "none:Write|$rigIdLate|$rigItemA|$rigSessions/rig-cow;"
rigAssert "nor is the served Write"                        "$( rigWrite keeper-myx "$rigRun2" "$rigFileA" after-revoke | LC_ALL=C sed 's/ .*//' ):$( cat "$rigFileA" )" refused:second-run
rigAssert "the other grant of that run still stands"       "$( rigHookWrite keeper-myx "$rigRun2" "$rigWs/ELSE/late.txt" )" "allow session $rigIdLate"
rm -f "$rigTmp/hold"
rigWaitFor 40 test -f "$rigData/board/review/$rigItemA.md"

## ---------------------------------------------------------------- a session the first run started
echo "-- 4. a run that started its own session: its grant is a runs row with no session to end it --"
rigItemL="dispatch-20261012T1200Z-index-l"
rigFileL="$rigWs/ELSE/l.txt"
rigRecord rig-lone-1 spawn-started rig-lone-1 keeper-myx "spawns: $rigItemL" trk-rig-l
rigItem running "$rigItemL" rig-lone-1
rigIdL="$( rigRefusalOf keeper-myx rig-lone-1 "$rigFileL" )"
[ -n "$rigIdL" ] || rigRefuse "the harness gate recorded no refusal for the lone run's Write"
rigAssert "allowed for the session, and admitted by its own index" "$( rigGrantOpen human-owner rig-lone-1 "$rigIdL" session ):$( rigHookWrite keeper-myx rig-lone-1 "$rigFileL" )" "session:allow session $rigIdL"
rigStatus "$rigSpawned/trk-rig-l/rig-lone-1.md" spawn-succeeded
mv "$rigData/board/running/$rigItemL.md" "$rigData/board/review/$rigItemL.md"
: > "$rigTmp/hold"
rigLone2="$( rigReturn "$rigItemL" trk-rig-l "rig-lone-1" )"
[ -n "$rigLone2" ] || { cat "$rigTmp/return.out" >&2 ; rigRefuse "the return of the lone run started no new run" ; }
rigWaitFor 20 test -s "$rigTmp/console-in.$rigLone2"
rigAssert "control: the new run joined the session its first run started" "$( LC_ALL=C grep -c -x 'session-id: rig-lone-1' "$rigSpawned/trk-rig-l/$rigLone2.md" )" 1
rigAssert "its index admits the call, by that grant"       "$( rigHookWrite keeper-myx "$rigLone2" "$rigFileL" )" "allow session $rigIdL"
rigAssert "a runs row that names no session"               "$( rigRunsRows "$rigLone2" keeper-myx )" "Write|$rigIdL|$rigItemL|-;"
rigAssert "and no session row: the run it was given to has ended" "$( rigRows "$rigLone2" keeper-myx session )" ""
mv "$rigData/board/running/$rigItemL.md" "$rigData/board/processed/$rigItemL.md"
rigAssert "until the item is closed"                       "$( rigHookWrite keeper-myx "$rigLone2" "$rigFileL" )" none
mv "$rigData/board/processed/$rigItemL.md" "$rigData/board/running/$rigItemL.md"
rm -f "$rigTmp/hold"
rigWaitFor 40 test -f "$rigData/board/review/$rigItemL.md"

## ---------------------------------------------------------------- the awk's own inputs
echo "-- 5. the awk reads its stores from the environment, and one store named with -v --"
printf 'myx.distro grants.index 1\trig\n' > "$rigTmp/awk.index"
rigAwkStores(){ ## awk arguments... -- the store rows it prints, a `;` after each, then its rc
	LC_ALL=C awk -v member=keeper-myx -v header=rig-header "$@" -f "$rigLib/AgentsGrantsPattern.awk" -f "$rigLib/AgentsGrantsSessionIndex.awk" "$rigTmp/awk.index" 2> "$rigTmp/awk.err" \
		| LC_ALL=C awk -F'\t' '$1 == "store" { printf "%s;", $2 ; }'
	printf 'rc=%s' "${PIPESTATUS[0]}"
}
rigAssert "two stores, in the environment"                 "$( agentsGrantsStores="/rig/s1"$'\n'"/rig/s2" rigAwkStores )" "/rig/s1;/rig/s2;rc=0"
rigAssert "one store, named with -v"                       "$( rigAwkStores -v stores=/rig/one )" "/rig/one;rc=0"
rigAssert "no store named: an index with no store row"     "$( rigAwkStores )" "rc=0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SESSION INDEX JOINED STORES CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_INDEX_JOINED_STORES: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
