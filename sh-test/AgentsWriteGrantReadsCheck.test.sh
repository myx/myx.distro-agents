#!/usr/bin/env bash
## Behavioural check: a grant to Edit or Write a place reads that place
## (AgentsToolsGrantsToolCovers, AgentsTools.Grants.include). A member that holds a session or
## task grant to Edit or Write a path may Read, Grep and Glob it too, in the same scope and for
## as long as that grant holds: nobody can edit what they cannot read. Never the other way: a
## grant to read changes nothing. An Allow once stays one call of its own tool.
## Seen live as a Permission set that gave Edit and Write of a folder, whose Read of a file in
## it was still refused: every grant matched a call by its exact tool.
## Proved through the real paths: served Read, Grep, Glob, Edit and Write calls decided by the
## harness gate, its grant read (`--intern-op-permission-grant-read`), what the member holds
## (`--intern-op-permission-holds`), and the session index (the native client's hook).
##   1. an approved permission set, an Edit of a folder for a task: Read, Grep and Glob inside
##      it are allowed, outside it refused; the planned allow a later dispatch carries too;
##   2. for as long as the grant holds: its item closed, and revoked;
##   3. a Write passed on for the session reads too, and ends with the session;
##   4. a grant answering one refusal is that one file;
##   5. never the other way: a Read grant gives no Edit and no Write;
##   6. an Allow once for an Edit is not used up by a Read, and admits none;
##   7. a routine's allow reads what it lets its executor edit.
## Red recipe: make AgentsToolsGrantsToolCovers answer for the same tool only, and section 1
## fails on the first Read.
## Offline: a fake `curl` first on PATH logs each Slack call and opens no socket; the board and
## the workspace are this rig's own temp tree, guarded on every call. Never the live team data
## or .local/agents.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigHarness="$rigLib/harness/AgentsUniversalHarness.sh"
rigHook="$rigLib/client-hooks/allow-granted-native-tool.sh"
rigFixture="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/slack-send-identity-check.curl.stub.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
[ -f "$rigHarness" ] || rigRefuse "harness not found: $rigHarness"
[ -f "$rigHook" ] || rigRefuse "the native client's hook is missing: $rigHook"
[ -f "$rigFixture" ] || rigRefuse "the fake curl fixture is missing: $rigFixture"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWriteGrantReadsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data"
rigWs="$rigTmp/ws"
rigSpawned="$rigWs/.local/agents/spawned"
rigSessions="$rigWs/.local/agents/sessions"
mkdir -p "$rigData/board/running" "$rigData/board/processed" "$rigWs/.local/.agents" "$rigWs/.local/agents/pending" "$rigSpawned" "$rigSessions" "$rigTmp/bin" \
	"$rigWs/WORK/in/sub" "$rigWs/WORK/out" "$rigWs/PASS/in" "$rigWs/PASS/out" "$rigWs/ONE" "$rigWs/RO" "$rigWs/ONCE" "$rigWs/ROUT" "$rigWs/ELSE"
cp "$rigFixture" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl" || rigRefuse "could not install the fake curl"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
for rigMember in magic-coordinator keeper-myx magic-tester ; do
	mkdir -p "$rigWs/.local/agents/members/$rigMember"
	printf -- '---\nname: %s\ndescription: rig member\n---\n' "$rigMember" > "$rigWs/.local/agents/members/$rigMember/SKILL.md"
	printf 'rig\n' > "$rigWs/.local/agents/members/$rigMember/$rigMember.basic.md"
done
## The coordinator's standing write, which it passes on in section 3.
printf 'magic-coordinator:ws:workspace:Edit(/%s/PASS/**)\n' "$rigWs" > "$rigWs/.local/agents/permissions.registry"
for rigOne in WORK/in/a.txt WORK/in/sub/b.txt WORK/out/c.txt PASS/in/p.txt PASS/out/q.txt ONE/f.txt ONE/g.txt RO/r.txt ONCE/o.txt ROUT/a.txt ELSE/e.txt ; do
	printf 'rig-seed %s\n' "$rigOne" > "$rigWs/$rigOne"
done
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
rigItem(){ ## item stem, front matter lines after its owner
	printf -- '---\nowner: keeper-myx\n%s\n---\n\n# rig item\n' "$2" > "$rigData/board/running/$1.md"
}
rigRecord(){ ## spawn-id, coworking session id, owner, extra front matter line (may be empty)
	mkdir -p "$rigSpawned/trk-$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: trk-%s\nhost: %s\nowner: %s\nstatus: spawn-started\nsession-thread: CSES00001:1700000000.000100\n%s---\n' \
		"$2" "$1" "$1" "$rigHost" "$3" "${4:+$4
}" > "$rigSpawned/trk-$1/$1.md"
}
## One served call as one member's run; its output in call.out.
rigCall(){ ## member, session, tool, arguments JSON
	rigEnv=( MDAT_SPAWN_AGENT="$1" MDAT_SPAWN_SESSION_ID="$2" )
	rigTool "$rigTmp/call.out" "$3" "$4"
	rigEnv=()
}
## What the last served call came to: `refused` by a gate, else the word given when its output holds the text given.
rigCame(){ ## word, text
	case "$( cat "$rigTmp/call.out" )" in
		*'not in the allowed access-root set'*|*'not in the allowed write-root set'*) printf 'refused' ;;
		*"$2"*) printf '%s' "$1" ;;
		*) printf 'other:%s' "$( head -1 "$rigTmp/call.out" )" ;;
	esac
}
rigRead(){ ## member, session, file
	rigCall "$1" "$2" Read "{\"file_path\":\"$3\"}" ; rigCame read rig-seed
}
rigGrep(){ ## member, session, folder
	rigCall "$1" "$2" Grep "{\"pattern\":\"rig-seed\",\"path\":\"$3\",\"output_mode\":\"files_with_matches\"}" ; rigCame found .txt
}
rigGlob(){ ## member, session, folder
	rigCall "$1" "$2" Glob "{\"pattern\":\"*.txt\",\"path\":\"$3\"}" ; rigCame found .txt
}
rigEdit(){ ## member, session, file -- one more word after its seed
	rigCall "$1" "$2" Edit "{\"file_path\":\"$3\",\"old_string\":\"rig-seed\",\"new_string\":\"rig-seed edited\"}" ; rigCame edited 'OK: replaced'
}
rigWrite(){ ## member, session, file
	rigCall "$1" "$2" Write "{\"file_path\":\"$3\",\"content\":\"rig-seed written\\n\"}" ; rigCame wrote 'OK: wrote'
}
rigRefusalId(){ ## -- the refusal id the last served call recorded
	LC_ALL=C sed -n 's/^REFUSAL-ID: \(refusal-[0-9a-f-]*\)$/\1/p' "$rigTmp/call.out" | head -1
}
rigGrantOpen(){ ## session, refusal id, kind -- prints the GRANT line's kind, or empty
	rigOp "$rigTmp/open.out" --intern-op-permission-grant-open human-owner --session-id "$1" --refusal-id "$2" --kind "$3"
	LC_ALL=C sed -n 's/^GRANT: \([a-z]*\) .*$/\1/p' "$rigTmp/open.out" | head -1
}
rigGrantRead(){ ## member, session, tool, path -- what grants that call, as its GRANT line says it, or empty
	rigOp "$rigTmp/read.out" --intern-op-permission-grant-read "$1" --session-id "$2" --tool "$3" --target "$4"
	LC_ALL=C sed -n 's/^GRANT: //p' "$rigTmp/read.out" | head -1
}
rigHolds(){ ## member, session, tool, path -- the HOLDS or NOT-HOLDS line
	rigOp "$rigTmp/holds.out" --intern-op-permission-holds "$1" "$3" "$4" --session-id "$2"
	LC_ALL=C grep -E '^(HOLDS|NOT-HOLDS)' "$rigTmp/holds.out" | head -1
}
## The native client's PreToolUse hook asked about one call, as one member's run. It decides by
## the session index alone: `allow <what admitted it>`, `none` when no row does, else `deny`.
rigHook(){ ## member, session, tool, path
	local hookOut hookKey=file_path
	case "$3" in Grep|Glob) hookKey=path ;; esac
	printf '{"session_id":"%s","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":{"pattern":"rig","%s":"%s","old_string":"a","new_string":"b","content":"rig"}}' "$2" "$rigWs" "$3" "$hookKey" "$4" > "$rigTmp/hook.in"
	hookOut="$( env -i HOME="$rigTmp" PATH=/usr/bin:/bin:/usr/sbin:/sbin MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SPAWN_AGENT="$1" MDAT_SPAWN_SESSION_ID="$2" bash "$rigHook" < "$rigTmp/hook.in" 2> "$rigTmp/hook.err" )"
	case "$hookOut" in
		'') printf 'none' ;;
		*'"permissionDecision": "allow"'*) printf 'allow %s' "$( printf '%s\n' "$hookOut" | LC_ALL=C sed -n "s/.*\"permissionDecisionReason\": \"granted to $1: \\(.*\\)\"\$/\\1/p" )" ;;
		*) printf 'deny' ;;
	esac
}
## An in-context helper (no operation of its own), run by --intern-mcp-execute inside the tool's own context.
rigHelper(){ ## result file, include, function, arguments...
	local helperOut="$1" helperInclude="$2" helperCall="$3" ; shift 3
	{ printf '. "$MDLT_ORIGIN"/myx/myx.distro-*/sh-lib/*/%s\n%s' "$helperInclude" "$helperCall" ; [ $# -eq 0 ] || printf ' %q' "$@" ; printf '\n' ; } > "$rigTmp/helper.in"
	rigRun "$helperOut" bash -c 'exec bash "$0" --intern-mcp-execute < "$1"' "$rigFn" "$rigTmp/helper.in"
}

## ---------------------------------------------------------------- an Edit of a folder, by a permission set
echo "-- 1. a permission set gives an Edit of a folder for a task: the member reads what it may edit --"
## rig-cow is a root session: no spawn record. keeper-myx's run joined it, on its dispatch item.
rigTask="task-20261012T1400Z-rig-edit"
rigItemA="dispatch-20261012T1400Z-reads-a"
rigIn="$rigWs/WORK/in"
rigItem "$rigTask" "status: task"
rigItem "$rigItemA" "status: dispatch-started"$'\n'"spawn-id: rig-run-1"
rigRecord rig-run-1 rig-cow keeper-myx "spawns: $rigItemA"
rigAssert "control: before the grant its Read and its Edit there are refused" "$( rigRead keeper-myx rig-run-1 "$rigIn/a.txt" ):$( rigEdit keeper-myx rig-run-1 "$rigIn/a.txt" )" refused:refused
printf 'scope: task\nitem: %s\nsession-id: rig-run-1\nparticipants: keeper-myx\nentry: Edit:%s/**\n' "$rigTask" "$rigIn" > "$rigWs/.local/agents/pending/set-ask-rig.set"
rigHelper "$rigTmp/set.out" AgentsTools.InternOpPermission.include AgentsToolsPermissionSetApply set-ask-rig human-owner
rigSet="$( LC_ALL=C sed -n 's/^task:Edit:[^:]*:human-owner:[^:]*:\(set-[0-9a-f-]*\)$/\1/p' "$rigSessions/rig-cow/grants" 2> /dev/null | head -1 )"
[ -n "$rigSet" ] || { cat "$rigTmp/set.out" >&2 ; rigRefuse "the rig's permission set was not granted" ; }
rigAssert "control: the set is one grant, an Edit of the folder, and the item's planned allow" \
	"$( LC_ALL=C grep -c . "$rigSessions/rig-cow/grants" ):$( LC_ALL=C grep -c -x -F -- "task:Edit:$rigIn/**:human-owner:$( LC_ALL=C sed -n 's/^task:Edit:[^:]*:human-owner:\([^:]*\):set-.*$/\1/p' "$rigSessions/rig-cow/grants" ):$rigSet" "$rigSessions/rig-cow/grants" ):$( LC_ALL=C grep -c "^allows: task:Edit:$rigIn/\*\*:human-owner:" "$rigData/board/running/$rigTask.md" )" 1:1:1
rigAssert "control: the Edit it was asked for goes through" "$( rigEdit keeper-myx rig-run-1 "$rigIn/a.txt" )" edited
rigAssert "a Read inside the folder is allowed"            "$( rigRead keeper-myx rig-run-1 "$rigIn/a.txt" ):$( rigRead keeper-myx rig-run-1 "$rigIn/sub/b.txt" )" read:read
rigAssert "a Grep inside it is allowed"                    "$( rigGrep keeper-myx rig-run-1 "$rigIn" ):$( rigGrep keeper-myx rig-run-1 "$rigIn/sub" )" found:found
rigAssert "a Glob inside it is allowed"                    "$( rigGlob keeper-myx rig-run-1 "$rigIn" ):$( rigGlob keeper-myx rig-run-1 "$rigIn/sub" )" found:found
rigAssert "by that grant, as the grant read says it"       "$( rigGrantRead keeper-myx rig-run-1 Read "$rigIn/a.txt" )|$( rigGrantRead keeper-myx rig-run-1 Grep "$rigIn" )|$( rigGrantRead keeper-myx rig-run-1 Glob "$rigIn/sub" )" "task $rigSet|task $rigSet|task $rigSet"
rigAssert "and the member holds the read through it"       "$( rigHolds keeper-myx rig-run-1 Read "$rigIn/a.txt" )" "HOLDS set task $rigSet"
rigAssert "its session index admits the three, for that task" "$( rigHook keeper-myx rig-run-1 Read "$rigIn/a.txt" )|$( rigHook keeper-myx rig-run-1 Grep "$rigIn" )|$( rigHook keeper-myx rig-run-1 Glob "$rigIn/sub" )" "allow task $rigTask|allow task $rigTask|allow task $rigTask"
rigAssert "a Read outside the folder is still refused"     "$( rigRead keeper-myx rig-run-1 "$rigWs/WORK/out/c.txt" ):$( rigRead keeper-myx rig-run-1 "$rigWs/ELSE/e.txt" )" refused:refused
rigAssert "so are a Grep and a Glob outside it, and of the folder above it" \
	"$( rigGrep keeper-myx rig-run-1 "$rigWs/WORK/out" ):$( rigGlob keeper-myx rig-run-1 "$rigWs/WORK/out" ):$( rigGrep keeper-myx rig-run-1 "$rigWs/WORK" ):$( rigGlob keeper-myx rig-run-1 "$rigWs/WORK" )" refused:refused:refused:refused
rigAssert "nor does the session index admit them"          "$( rigHook keeper-myx rig-run-1 Read "$rigWs/WORK/out/c.txt" )|$( rigHook keeper-myx rig-run-1 Grep "$rigWs/WORK" )" "none|none"
rigAssert "an Edit grant is still no Write grant"          "$( rigWrite keeper-myx rig-run-1 "$rigIn/new.txt" ):$( rigGrantRead keeper-myx rig-run-1 Write "$rigIn/new.txt" )" refused:
rigAssert "another member reads nothing by it"             "$( rigGrantRead magic-tester rig-run-1 Read "$rigIn/a.txt" )" ""
## The planned allow: a later dispatch of the member that tracks the item carries the set.
rigItem "dispatch-20261012T1400Z-reads-later" "status: dispatch-started"$'\n'"session-id: rig-later"$'\n'"tracks: $rigTask"
rigAssert "a later dispatch tracking the item reads by its planned allow" "$( rigGrantRead keeper-myx rig-later Read "$rigIn/a.txt" ):$( rigRead keeper-myx rig-later "$rigIn/a.txt" ):$( rigGrep keeper-myx rig-later "$rigIn" )" "planned dispatch-20261012T1400Z-reads-later.md:read:found"
rigAssert "and nothing outside it"                         "$( rigGrantRead keeper-myx rig-later Read "$rigWs/WORK/out/c.txt" ):$( rigRead keeper-myx rig-later "$rigWs/WORK/out/c.txt" )" ":refused"

## ---------------------------------------------------------------- for as long as the grant holds
echo "-- 2. for as long as that grant holds: its item closed, and revoked --"
mv "$rigData/board/running/$rigTask.md" "$rigData/board/processed/$rigTask.md"
rigAssert "the item closed: the Read, the Grep and the Glob are refused" "$( rigRead keeper-myx rig-run-1 "$rigIn/a.txt" ):$( rigGrep keeper-myx rig-run-1 "$rigIn" ):$( rigGlob keeper-myx rig-run-1 "$rigIn" ):$( rigHook keeper-myx rig-run-1 Read "$rigIn/a.txt" )" refused:refused:refused:none
mv "$rigData/board/processed/$rigTask.md" "$rigData/board/running/$rigTask.md"
rigAssert "control: the item open again, read"             "$( rigRead keeper-myx rig-run-1 "$rigIn/a.txt" )" read
rigOp "$rigTmp/revoke.out" --intern-op-permission-revoke "$rigSet"
rigAssert "the set is revoked"                             "$( cat "$rigTmp/revoke.out.rc" ):$( LC_ALL=C grep -c -x "REVOKED: $rigSet" "$rigTmp/revoke.out" )" 0:1
rigAssert "revoked: the Read is refused, as the Edit is"   "$( rigRead keeper-myx rig-run-1 "$rigIn/a.txt" ):$( rigEdit keeper-myx rig-run-1 "$rigIn/a.txt" ):$( rigHook keeper-myx rig-run-1 Read "$rigIn/a.txt" )" refused:refused:none

## ---------------------------------------------------------------- a Write passed on for the session
echo "-- 3. a Write passed on for the session reads too, and ends with the session --"
rigRecord rig-coord rig-cow magic-coordinator ""
rigEnv=( MDAT_SPAWN_AGENT=magic-coordinator MDAT_SPAWN_SESSION_ID=rig-coord )
rigOp "$rigTmp/pass.out" --member-permission-pass magic-coordinator --to keeper-myx --tool Write --target "$rigWs/PASS/in/**" --kind session
rigEnv=()
rigPass="$( LC_ALL=C sed -n 's/^GRANT: session \(pass-[0-9a-f-]*\)$/\1/p' "$rigTmp/pass.out" | head -1 )"
[ -n "$rigPass" ] || { cat "$rigTmp/pass.out" >&2 ; rigRefuse "the coordinator's pass was not written" ; }
rigAssert "control: the Write it was passed goes through"  "$( rigWrite keeper-myx rig-run-1 "$rigWs/PASS/in/new.txt" )" wrote
rigAssert "a Read, a Grep and a Glob inside it are allowed" "$( rigRead keeper-myx rig-run-1 "$rigWs/PASS/in/p.txt" ):$( rigGrep keeper-myx rig-run-1 "$rigWs/PASS/in" ):$( rigGlob keeper-myx rig-run-1 "$rigWs/PASS/in" )" read:found:found
rigAssert "by that grant, and by the session index"        "$( rigGrantRead keeper-myx rig-run-1 Read "$rigWs/PASS/in/p.txt" )|$( rigHook keeper-myx rig-run-1 Read "$rigWs/PASS/in/p.txt" )|$( rigHook keeper-myx rig-run-1 Glob "$rigWs/PASS/in" )" "session $rigPass|allow session $rigPass|allow session $rigPass"
rigAssert "what the coordinator holds beside it was not passed: refused" "$( rigRead keeper-myx rig-run-1 "$rigWs/PASS/out/q.txt" ):$( rigGrep keeper-myx rig-run-1 "$rigWs/PASS" )" refused:refused
rigAssert "a Write grant is no Edit grant"                 "$( rigEdit keeper-myx rig-run-1 "$rigWs/PASS/in/p.txt" )" refused
mkdir -p "$rigSessions/rig-cow" && : > "$rigSessions/rig-cow/ended"
rigAssert "the session ended: the Read is refused, as the Write is" "$( rigRead keeper-myx rig-run-1 "$rigWs/PASS/in/p.txt" ):$( rigWrite keeper-myx rig-run-1 "$rigWs/PASS/in/new2.txt" ):$( rigHook keeper-myx rig-run-1 Read "$rigWs/PASS/in/p.txt" )" refused:refused:none
rm -f "$rigSessions/rig-cow/ended"

## ---------------------------------------------------------------- one refusal, one file
echo "-- 4. a grant answering one refusal is that one file: its Read is allowed, nothing beside it --"
rigEdit keeper-myx rig-run-1 "$rigWs/ONE/f.txt" > /dev/null
rigIdF="$( rigRefusalId )"
[ -n "$rigIdF" ] || rigRefuse "the harness gate recorded no refusal for the rig's Edit"
rigAssert "the Edit of one file is allowed for the session" "$( rigGrantOpen rig-run-1 "$rigIdF" session ):$( rigEdit keeper-myx rig-run-1 "$rigWs/ONE/f.txt" )" session:edited
rigAssert "a Read of that file is allowed, by that grant"  "$( rigRead keeper-myx rig-run-1 "$rigWs/ONE/f.txt" )|$( rigGrantRead keeper-myx rig-run-1 Read "$rigWs/ONE/f.txt" )|$( rigHook keeper-myx rig-run-1 Read "$rigWs/ONE/f.txt" )" "read|session $rigIdF|allow session $rigIdF"
rigAssert "the file beside it and its folder are not"      "$( rigRead keeper-myx rig-run-1 "$rigWs/ONE/g.txt" ):$( rigGrep keeper-myx rig-run-1 "$rigWs/ONE" ):$( rigGlob keeper-myx rig-run-1 "$rigWs/ONE" )" refused:refused:refused

## ---------------------------------------------------------------- never the other way
echo "-- 5. never the other way: a grant to read gives no Edit and no Write --"
rigRead keeper-myx rig-run-1 "$rigWs/RO/r.txt" > /dev/null
rigIdR="$( rigRefusalId )"
[ -n "$rigIdR" ] || rigRefuse "the harness gate recorded no refusal for the rig's Read"
rigAssert "the Read of a file is allowed for the session"  "$( rigGrantOpen rig-run-1 "$rigIdR" session ):$( rigRead keeper-myx rig-run-1 "$rigWs/RO/r.txt" )" session:read
rigAssert "its Edit and its Write are refused"             "$( rigEdit keeper-myx rig-run-1 "$rigWs/RO/r.txt" ):$( rigWrite keeper-myx rig-run-1 "$rigWs/RO/r.txt" ):$( cat "$rigWs/RO/r.txt" )" "refused:refused:rig-seed RO/r.txt"
rigAssert "nothing grants them, nor does the member hold them" "$( rigGrantRead keeper-myx rig-run-1 Edit "$rigWs/RO/r.txt" )|$( rigGrantRead keeper-myx rig-run-1 Write "$rigWs/RO/r.txt" )|$( rigHolds keeper-myx rig-run-1 Edit "$rigWs/RO/r.txt" )|$( rigHolds keeper-myx rig-run-1 Write "$rigWs/RO/r.txt" )" "||NOT-HOLDS|NOT-HOLDS"
rigAssert "nor does the session index admit them"          "$( rigHook keeper-myx rig-run-1 Edit "$rigWs/RO/r.txt" )|$( rigHook keeper-myx rig-run-1 Write "$rigWs/RO/r.txt" )" "none|none"
rigAssert "a Read grant opens no other read tool either"   "$( rigGrep keeper-myx rig-run-1 "$rigWs/RO/r.txt" )" refused

## ---------------------------------------------------------------- an Allow once
echo "-- 6. an Allow once is one call of its own tool: a Read neither uses it up nor is admitted by it --"
rigEdit keeper-myx rig-run-1 "$rigWs/ONCE/o.txt" > /dev/null
rigIdO="$( rigRefusalId )"
[ -n "$rigIdO" ] || rigRefuse "the harness gate recorded no refusal for the rig's other Edit"
rigAssert "the Edit is allowed once"                       "$( rigGrantOpen rig-run-1 "$rigIdO" once )" once
rigAssert "a Read of that file is refused, by the gate and the session index" "$( rigRead keeper-myx rig-run-1 "$rigWs/ONCE/o.txt" ):$( rigGrantRead keeper-myx rig-run-1 Read "$rigWs/ONCE/o.txt" ):$( rigHook keeper-myx rig-run-1 Read "$rigWs/ONCE/o.txt" )" refused::none
rigAssert "and the Edit still has its one call"            "$( rigEdit keeper-myx rig-run-1 "$rigWs/ONCE/o.txt" ):$( rigEdit keeper-myx rig-run-1 "$rigWs/ONCE/o.txt" )" edited:refused

## ---------------------------------------------------------------- a routine's allow
echo "-- 7. a routine's allow reads what it lets its executor edit --"
printf -- '---\nexecutors: magic-tester\nmaintainers: human-owner\nallows: magic-tester:Edit:ROUT/**\n---\n# rig routine\n' > "$rigWs/.local/agents/members/magic-tester/magic-tester.rig-edit.routine.md"
rigRecord rig-rout rig-rout magic-tester "routine: magic-tester.rig-edit.routine.md"
rigAssert "control: its executor holds the Edit, in that routine's session" "$( rigHolds magic-tester rig-rout Edit "$rigWs/ROUT/a.txt" )" "HOLDS routine magic-tester.rig-edit.routine"
rigAssert "and the Read with it"                           "$( rigHolds magic-tester rig-rout Read "$rigWs/ROUT/a.txt" ):$( rigRead magic-tester rig-rout "$rigWs/ROUT/a.txt" ):$( rigGrep magic-tester rig-rout "$rigWs/ROUT" )" "HOLDS routine magic-tester.rig-edit.routine:read:found"
rigAssert "nothing outside it"                             "$( rigHolds magic-tester rig-rout Read "$rigWs/ELSE/e.txt" ):$( rigRead magic-tester rig-rout "$rigWs/ELSE/e.txt" )" "NOT-HOLDS:refused"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WRITE GRANT READS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WRITE_GRANT_READS: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
