#!/usr/bin/env bash
## Behavioural check on the harness READ gate. Read, Grep and Glob are checked against the
## acting member's own read set -- the workspace's own roots, that member's own allow-read
## and allow-write rows and every row declared for `*` -- and then against its grants. A
## path outside is refused the way a Write outside the write set is: the same recorded
## refusal and REFUSAL-ID, the same escalation, and the same allow-once, session and task
## grants, with the tool and the resolved path in the record.
## AgentsHarnessPermissionCheck.test.sh beside this holds that flow for Write and Edit;
## AgentsPermissionHoldsCheck.test.sh holds the layers a member holds.
##
## Offline and self-contained: the Slack-shaped fake curl is first on PATH and no
## event-track is configured. HOME, the workspace, the team data and the member set are
## all this check's own, so no live grant row, team store or skillset is read or written.
##
## Red recipe, run: make AgentsHarnessReadGate in sh-lib/AgentsUniversalHarness.sh print
## the bare ERROR line and return 1, skipping AgentsHarnessGranted and AgentsHarnessRefusal:
## the refused read then names no REFUSAL-ID and no grant opens it. Drop `|| $1 == "*"`
## from AgentsToolsClientAccessGrantRootsOf (sh-lib/AgentsTools.ClientAccessRoots.include):
## a `*` row then reaches no named member. Pass the harness no grant member for
## AgentsToolsClientAccessRoots: the developer's own row then opens reads for the tester.
## Each fails this check; the unchanged tree before `*` rows were honoured failed 8.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

## Refusing to report is this block's whole job: a run that exercised nothing must never
## print a pass.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"
[ -f "$rigTools" ] || rigRefuse "the tooling is not found at the origin this workspace resolves: $rigTools"

rigTmp="$( mktemp -d -t AgentsHarnessReadGateCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/harness-ask-check.curl.test.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigTest/check-fixtures/harness-ask-check.curl.test.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check could issue real requests"
RIG_CURL_LOG="$rigTmp/curl.log"
export RIG_CURL_LOG
: > "$RIG_CURL_LOG"

## The rig's own HOME: no shared grant pointers, so the rig workspace's rows are the whole
## grant set. The rig's own member set, real folders, so identity resolves without the
## live skillset.
rigHome="$rigTmp/home"
rigSkills="$rigTmp/skills"
mkdir -p "$rigHome"
for rigName in magic-tester magic-developer magic-coordinator magic-librarian ; do
	mkdir -p "$rigSkills/$rigName"
	printf '# %s\n' "$rigName" > "$rigSkills/$rigName/$rigName.basic.md"
done

## The rig workspace, agents installed. source/ is no member's floor: magic-librarian reads it
## by its standing row, as --make-agents-indices writes it, and every member its MAGIC.md,
## README.md and docs/**.md. OUT/ is granted to the coordinator only, which is what lets it
## approve a read there. DEVR/ is the developer's own allow-read row. ALL/ and ALLW/ are an
## allow-read and an allow-write row declared for `*`.
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigData/board/running" "$rigData/board/processed" "$rigWs/source/p/docs"
for rigDir in source OUT DEVR ALL ALLW ; do
	mkdir -p "$rigWs/$rigDir"
	printf 'rig-seed %s\n' "$rigDir" > "$rigWs/$rigDir/seed.txt"
done
for rigDir in p/MAGIC.md p/README.md p/docs/a.md ; do printf 'rig-seed %s\n' "$rigDir" > "$rigWs/source/$rigDir" ; done
: > "$rigWs/.local/agents/members.registry"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\n' > "$rigWs/.local/.agents/magic-team.agent.env"
{
	printf 'magic-coordinator:ws:workspace:Edit(/%s/OUT/**)\n' "$rigWs"
	printf 'magic-developer:ws:workspace:Read(/%s/DEVR/**)\n' "$rigWs"
	printf '*:ws:workspace:Read(/%s/ALL/**)\n' "$rigWs"
	printf '*:ws:workspace:Edit(/%s/ALLW/**)\n' "$rigWs"
	printf 'magic-librarian:ws:builtin:Read(/%s/source/**)\n' "$rigWs"
} > "$rigWs/.local/agents/permissions.registry"
printf -- '---\nstatus: task\nowner: magic-tester\n---\n\n# Task\n' > "$rigData/board/running/task-rig.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHas(){ ## file, text
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	case "$( cat "$1" )" in *"$2"*) printf yes ;; *) printf no ;; esac
}

## The rig's launch values, stated outright, so nothing ambient decides a call.
rigEnv=( env -u MDAT_SESSION_UNATTENDED -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT
	-u MDAT_SPAWN_SANDBOX_ROOT -u MDAT_SPAWN_SANDBOX_ROOT_REAL -u MDAT_HARNESS_RUN_TIMEOUT
	HOME="$rigHome" MDAT_SKILLSET_ROOT="$rigSkills" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" RIG_SCENARIO="$rigTmp" )

## One served call, as the MCP server makes it: no root flag. Output in out, stderr in err.
rigCall(){ ## acting member (empty: none), session id (empty: none), tool, argument object
	( cd "$rigWs" && printf '%s' "$4" | "${rigEnv[@]}" ${1:+MDAT_SPAWN_AGENT="$1"} ${2:+MDAT_SPAWN_SESSION_ID="$2"} \
		bash "$rigHarness" --intern-tool "$3" ) > "$rigTmp/out" 2> "$rigTmp/err"
}
## What the last call did, as one word: refused first, since a refusal names the path.
rigVerdict(){
	case "$( cat "$rigTmp/out" )" in
		*'not in the allowed access-root set'*) printf refused ;;
		*rig-seed*|*/seed.txt*) printf read ;;
		*) printf other ;;
	esac
}
rigRead(){ ## member, session, path
	rigCall "$1" "$2" Read "{\"path\":\"$3\"}" ; rigVerdict
}
rigGrep(){ ## member, session, directory
	rigCall "$1" "$2" Grep "{\"pattern\":\"rig-seed\",\"path\":\"$3\",\"output_mode\":\"content\"}" ; rigVerdict
}
rigGlob(){ ## member, session, directory
	rigCall "$1" "$2" Glob "{\"pattern\":\"*.txt\",\"path\":\"$3\"}" ; rigVerdict
}
rigFirstLine(){
	LC_ALL=C awk 'NR == 1 { print ; }' "$rigTmp/out"
}
rigRefusalId(){
	LC_ALL=C sed -n 's/^REFUSAL-ID: \(refusal-[0-9a-f-]*\)$/\1/p' "$rigTmp/out" | head -1
}
rigRecordField(){ ## session, refusal id, field
	local recordFile="$rigWs/.local/agents/sessions/$1/$2.md"
	[ -n "$2" ] && [ -f "$recordFile" ] || { printf 'no-record' ; return 0 ; }
	LC_ALL=C awk -F': ' -v wantField="$3" '$1 == wantField { print substr( $0, length( wantField ) + 3 ) ; exit ; }' "$recordFile"
}
rigRecordCount(){
	local recordCount=0 recordFile
	for recordFile in "$rigWs/.local/agents/sessions"/*/refusal-*.md ; do
		[ -f "$recordFile" ] || continue
		recordCount=$(( recordCount + 1 ))
	done
	printf '%s' "$recordCount"
}
## One team operation in the rig; out and err kept.
rigOp(){
	( cd "$rigWs" && "${rigEnv[@]}" bash "$rigTools" "$@" ) > "$rigTmp/op.out" 2> "$rigTmp/op.err"
}
rigGrant(){ ## approver, session, refusal id, kind, [task] -- the granted kind, or nothing
	rigOp --intern-op-permission-grant-open "$1" --session-id "$2" --refusal-id "$3" --kind "$4" ${5:+--task "$5"}
	LC_ALL=C sed -n 's/^GRANT: \([a-z]*\) .*$/\1/p' "$rigTmp/op.out" | head -1
}
rigHolds(){ ## member, tool, target
	rigOp --intern-op-permission-holds "$1" "$2" "$3"
	head -1 "$rigTmp/op.out"
}
rigLineOf(){ ## prefix
	LC_ALL=C awk -v wantPrefix="$1" 'index( $0, wantPrefix ) == 1 { print ; found = 1 ; exit ; } END { if ( ! found ) { print "no-" wantPrefix "line" ; } }' "$rigTmp/out"
}

echo "-- the floor and the standing rows: an allowed read passes and records nothing --"
rigAssert "magic-librarian reads the workspace source"     "$( rigRead magic-librarian rig-lib "$rigWs/source/seed.txt" )" read
rigAssert "its Grep there passes"                          "$( rigGrep magic-librarian rig-lib "$rigWs/source" )" read
rigAssert "its Glob there passes"                          "$( rigGlob magic-librarian rig-lib "$rigWs/source" )" read
rigAssert "every member reads MAGIC.md, README.md and docs/**.md under source" "$( rigRead magic-tester rig-session "$rigWs/source/p/MAGIC.md" ):$( rigRead magic-tester rig-session "$rigWs/source/p/README.md" ):$( rigRead magic-tester rig-session "$rigWs/source/p/docs/a.md" )" "read:read:read"
printf 'rig-seed member\n' > "$rigSkills/magic-developer/seed.txt"
rigAssert "a member folder is readable"                    "$( rigRead magic-tester rig-session "$rigSkills/magic-developer/seed.txt" )" read
rigAssert "no refusal is recorded"                         "$( rigRecordCount )" 0
rigAssert "another member does not read the rest of source" "$( rigRead magic-tester rig-src "$rigWs/source/seed.txt" ):$( rigGrep magic-tester rig-src "$rigWs/source" ):$( rigGlob magic-tester rig-src "$rigWs/source" )" "refused:refused:refused"
rm -rf "$rigWs/.local/agents/sessions/rig-src"

echo "-- a read outside the set is refused, recorded, and escalatable --"
rigTarget="$rigWs/OUT/seed.txt"
rigAssert "a Read outside the set is refused"              "$( rigRead magic-tester rig-session "$rigTarget" )" refused
rigAssert "the original ERROR line opens the result"       "$( rigFirstLine )" "ERROR: path not in the allowed access-root set: $rigTarget"
rigId="$( rigRefusalId )"
rigAssert "a refusal id is named"                          "$( [ -n "$rigId" ] && printf yes || printf no )" yes
rigAssert "the record is in the session's own store"       "$( rigRecordField rig-session "$rigId" status )" refused
rigAssert "it carries the tool"                            "$( rigRecordField rig-session "$rigId" tool )" Read
rigAssert "it carries the resolved path"                   "$( rigRecordField rig-session "$rigId" target )" "$rigTarget"
rigAssert "it carries the asking member"                   "$( rigRecordField rig-session "$rigId" owner )" magic-tester
rigAssert "the result says it is not a verdict"            "$( rigHas "$rigTmp/out" 'This is a refusal, not a verdict' )" yes
rigAssert "the result names how to ask"                    "$( rigHas "$rigTmp/out" "kind=permission, refusal_id=$rigId" )" yes
rigAssert "nothing of the file came back"                  "$( rigHas "$rigTmp/out" 'rig-seed OUT' )" no
## The escalation, answered allow-once by the human-owner's account in the question's thread.
printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGBOT01","text":"opener"},{"ts":"1700000001.000102","user":"URIGBOT01","text":"question","thread_ts":"1700000001.000101"},{"ts":"1700000001.000200","user":"URIGOWNER","text":"allow-once","thread_ts":"1700000001.000101"}],"has_more":false}\n' > "$rigTmp/replies.json"
rm -f "$rigTmp/posts"
rigCall magic-tester rig-session AskUserQuestion "{\"to\":\"magic-team\",\"question\":\"May this task read the refused file?\",\"address_to\":\"URIGOWNER\",\"kind\":\"permission\",\"refusal_id\":\"$rigId\",\"reason\":\"the task input is there\",\"task_ref\":\"task-rig\"}"
rigAssert "the escalation's answer arrived"                "$( rigFirstLine )" "ASK-RESULT: RECEIVED"
rigAssert "the verdict is allow-once"                      "$( rigLineOf 'VERDICT: ' )" "VERDICT: allow-once"
rigAssert "the tooling wrote the grant from the record"    "$( rigLineOf 'GRANT: ' )" "GRANT: once $rigId"
rigAssert "the question showed the refused read"           "$( rigHas "$rigTmp/post.2" "$rigTarget" )" yes
rigAssert "the exact retry is admitted"                    "$( rigRead magic-tester rig-session "$rigTarget" )" read
rigAssert "the next one is refused"                        "$( rigRead magic-tester rig-session "$rigTarget" )" refused
rigAssert "under a new refusal id"                         "$( rigIdNext="$( rigRefusalId )" ; [ -n "$rigIdNext" ] && [ "$rigIdNext" != "$rigId" ] && printf yes || printf no )" yes
rigAssert "with no session, refused and said unrecorded"   "$( rigRead magic-tester "" "$rigTarget" ):$( rigHas "$rigTmp/out" 'REFUSAL-ID: none' )" "refused:yes"
rigAssert "a relative path is refused and recorded as given" "$( rigRead magic-tester rig-session "OUT/seed.txt" ):$( rigRecordField rig-session "$( rigRefusalId )" target )" "refused:OUT/seed.txt"

echo "-- allow-once, session and task grants open a read --"
rigTarget="$rigWs/OUT/once.txt"
printf 'rig-seed once\n' > "$rigTarget"
rigRead magic-tester rig-session "$rigTarget" > /dev/null
rigAssert "allow-once is granted from the record"          "$( rigGrant magic-coordinator rig-session "$( rigRefusalId )" once )" once
rigAssert "another session cannot use it"                  "$( rigRead magic-tester rig-other "$rigTarget" )" refused
rigAssert "the exact retry is admitted once"               "$( rigRead magic-tester rig-session "$rigTarget" )" read
rigAssert "and only once"                                  "$( rigRead magic-tester rig-session "$rigTarget" )" refused
rigTarget="$rigWs/OUT/session.txt"
printf 'rig-seed session\n' > "$rigTarget"
rigRead magic-tester rig-session "$rigTarget" > /dev/null
rigAssert "allow-session is granted from the record"       "$( rigGrant magic-coordinator rig-session "$( rigRefusalId )" session )" session
rigAssert "every retry in the session is admitted"         "$( rigRead magic-tester rig-session "$rigTarget" ):$( rigRead magic-tester rig-session "$rigTarget" )" "read:read"
rigAssert "a path beside it is not"                        "$( rigRead magic-tester rig-session "$rigWs/OUT/seed.txt" )" refused
rigAssert "another session is not"                         "$( rigRead magic-tester rig-other "$rigTarget" )" refused
rigTarget="$rigWs/OUT/task.txt"
printf 'rig-seed task\n' > "$rigTarget"
rigRead magic-tester rig-session "$rigTarget" > /dev/null
rigAssert "allow-task is granted from the record"          "$( rigGrant magic-coordinator rig-session "$( rigRefusalId )" task task-rig )" task
rigAssert "the retry is admitted while the item is open"   "$( rigRead magic-tester rig-session "$rigTarget" )" read
mv "$rigData/board/running/task-rig.md" "$rigData/board/processed/task-rig.md"
rigAssert "and refused once it is processed"               "$( rigRead magic-tester rig-session "$rigTarget" )" refused
mv "$rigData/board/processed/task-rig.md" "$rigData/board/running/task-rig.md"
rigAssert "the approver grants only what it holds"         "$( rigRead magic-tester rig-session "$rigWs/DEVR/seed.txt" >/dev/null ; rigGrant magic-coordinator rig-session "$( rigRefusalId )" session )" ""

echo "-- a member's own grant does not open reads for another member --"
rigAssert "the developer reads under its own allow-read row" "$( rigRead magic-developer rig-dev "$rigWs/DEVR/seed.txt" )" read
rigAssert "the tester does not"                            "$( rigRead magic-tester rig-session "$rigWs/DEVR/seed.txt" )" refused
rigAssert "nor a spawned coordinator"                      "$( rigRead magic-coordinator rig-coord "$rigWs/DEVR/seed.txt" )" refused
rigAssert "the developer's Grep and Glob there pass"       "$( rigGrep magic-developer rig-dev "$rigWs/DEVR" ):$( rigGlob magic-developer rig-dev "$rigWs/DEVR" )" "read:read"
rigAssert "the tester's Grep and Glob there are refused"   "$( rigGrep magic-tester rig-session "$rigWs/DEVR" ):$( rigGlob magic-tester rig-session "$rigWs/DEVR" )" "refused:refused"
rigAssert "the coordinator's own row opens no read for the tester" "$( rigRead magic-tester rig-session "$rigWs/OUT/seed.txt" )" refused
rigAssert "the tester's session grant opens no read for the developer in that session" "$( rigRead magic-developer rig-session "$rigWs/OUT/session.txt" )" refused
rigAssert "the human-owner's own session keeps every member's rows" "$( rigRead "" "" "$rigWs/DEVR/seed.txt" )" read

echo "-- rows declared for \`*\` reach every member --"
for rigName in magic-tester magic-developer magic-coordinator ; do
	rigAssert "$rigName reads under the \`*\` allow-read row"  "$( rigRead "$rigName" "rig-$rigName" "$rigWs/ALL/seed.txt" )" read
	rigAssert "$rigName reads under the \`*\` allow-write row" "$( rigRead "$rigName" "rig-$rigName" "$rigWs/ALLW/seed.txt" )" read
done
rigAssert "Grep and Glob reach them too"                   "$( rigGrep magic-tester rig-session "$rigWs/ALL" ):$( rigGlob magic-tester rig-session "$rigWs/ALLW" )" "read:read"
rigAssert "every member holds them, standing"              "$( rigHolds magic-tester Read "$rigWs/ALL/seed.txt" ):$( rigHolds magic-developer Glob "$rigWs/ALLW" )" "HOLDS standing:HOLDS standing"
rigAssert "control: a member holds no other member's row"  "$( rigHolds magic-tester Read "$rigWs/DEVR/seed.txt" )" "NOT-HOLDS"

echo "-- Grep and Glob are refused, recorded and granted the same way --"
rigAssert "Grep outside the set is refused"                "$( rigGrep magic-tester rig-session "$rigWs/OUT" )" refused
rigIdGrep="$( rigRefusalId )"
rigAssert "its record carries Grep and the resolved path"  "$( rigRecordField rig-session "$rigIdGrep" tool ):$( rigRecordField rig-session "$rigIdGrep" target )" "Grep:$rigWs/OUT"
rigAssert "Glob outside the set is refused"                "$( rigGlob magic-tester rig-session "$rigWs/OUT" )" refused
rigIdGlob="$( rigRefusalId )"
rigAssert "its record carries Glob and the resolved path"  "$( rigRecordField rig-session "$rigIdGlob" tool ):$( rigRecordField rig-session "$rigIdGlob" target )" "Glob:$rigWs/OUT"
rigAssert "allow-once opens the Glob"                      "$( rigGrant magic-coordinator rig-session "$rigIdGlob" once )" once
rigAssert "the Grep stays refused: another tool"           "$( rigGrep magic-tester rig-session "$rigWs/OUT" )" refused
rigAssert "the Glob retry is admitted once"                "$( rigGlob magic-tester rig-session "$rigWs/OUT" ):$( rigGlob magic-tester rig-session "$rigWs/OUT" )" "read:refused"
rigAssert "allow-session opens the Grep"                   "$( rigGrant magic-coordinator rig-session "$rigIdGrep" session )" session
rigAssert "every Grep retry in the session is admitted"    "$( rigGrep magic-tester rig-session "$rigWs/OUT" ):$( rigGrep magic-tester rig-session "$rigWs/OUT" )" "read:read"
rigAssert "the Grep grant opens no Read beneath it"        "$( rigRead magic-tester rig-session "$rigWs/OUT/seed.txt" )" refused

rigAssert "no request left this box"                       "$( LC_ALL=C awk '/^url:/ || $0 == "no-method" { hitCount++ ; } END { print hitCount + 0 ; }' "$RIG_CURL_LOG" )" 0
rigAssert "the escalation's two posts are the only ones"   "$( LC_ALL=C awk '$0 == "chat.postMessage" { hitCount++ ; } END { print hitCount + 0 ; }' "$RIG_CURL_LOG" )" 2

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ READ GATE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: a read outside the acting member's own read set is not refused, recorded" >&2
	echo "        and grantable the way a Write is, or another member's grant opens it" >&2
	echo "  fix:  repair the read gate in sh-lib/AgentsUniversalHarness.sh, or the per-member" >&2
	echo "        read set in sh-lib/AgentsTools.ClientAccessRoots.include -- never the assertion" >&2
	exit 1
fi
printf 'HARNESS_READ_GATE: OK (%d assertions, offline)\n' "$rigPassCount"
