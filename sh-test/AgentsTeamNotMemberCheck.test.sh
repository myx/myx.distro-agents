#!/usr/bin/env bash
## Behavioural check on the rule that THE TEAM IS NO MEMBER OF ITSELF, run rather than read, against a rig machine built
## here. magic-team is the team: its identifier and the persona of the whole team, with no work of its own. It has a folder
## in the member set as a member has, and its SKILL.md says `status: active`, so a start once took it for a member: it was
## started as a run, with its own process, and nothing refused it. Held, on each way a member is started: the spawn proxy
## (--intern-op-agent-spawn-proxy), which every start goes through, in every form of its call, the form a review return
## makes among them; --magic-spawn-session, with the team named alone, among five members, and with a routine whose
## executors list holds it; the harness tool Agent; --magic-heartbeat-spawn-proxy; a review return of an item the team
## owns; and --manager-spawn-member. Each is refused in one plain line that says it is the team itself and no member,
## and a refused start starts nobody and leaves nothing behind. A routine whose executors are `magic-team` still means
## any member: it starts with real members named, and reads not-startable, needing members, in --manager-routine-list.
## --manager-team-member-list keeps the team's row, as it keeps the row of an identity record, and says what it is in
## its status: `the-team`, where its SKILL.md says active. The registry of the members keeps its row too. A message to
## the team, and one addressed to it, goes out as before: the rule is about a run, never about a name in a message.
## THE RULE IS ONE: one function says what the team is, the one check of a start asks it, and no starter names the team.
## A stand-in console records each start, a fake `curl` answers Slack and logs each call. No real CLI is started.
## Offline; only the rig's own tree is read or written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTest="$rigPackage/sh-test"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigProxy="--intern-op-agent-spawn-proxy"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigHarness" ] || rigRefuse "the harness is not in the package: $rigHarness"
## A spawn of this rig that is not waited for starts the control thread of its session, a detached process that
## outlives this check: the rig ends it, before its tree is removed (the guard is in AgentsSessionControlStartCheck).
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsTeamNotMemberCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp" 2> /dev/null || { sleep 3 ; rm -rf -- "$rigTmp" 2> /dev/null ; }' EXIT
rigWs="$rigTmp/ws-here" ; rigHome="$rigTmp/home" ; rigData="$rigTmp/data" ; rigSc="$rigTmp/sc"
rigSkills="$rigWs/.local/agents/members"
mkdir -p "$rigTmp/bin" "$rigSc" "$rigWs/.local/.agents" "$rigSkills" "$rigHome/.agents/magic-team" "$rigData/board/running" "$rigData/board/review"
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigWaitFor(){ ## seconds, test command...
	local waitLeft="$1" ; shift
	while ! "$@" && [ "$waitLeft" -gt 0 ] ; do sleep 1 ; waitLeft=$(( waitLeft - 1 )) ; done
	"$@"
}

## THE RIG MACHINE: one workspace, whose member set holds the team's own folder beside its members', as a real one does.
rigMember(){ ## member, status ("" for no SKILL.md) -- a member's folder with the files a start of it reads
	mkdir -p "$rigSkills/$1"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$1/$1.basic.md"
	printf '# rig armed\n' > "$rigSkills/$1/$1.armed.md"
	[ -z "$2" ] || printf -- '---\nname: %s\nstatus: %s\ninvocation_mode: auto\n---\n\n# %s\n' "$1" "$2" "$1" > "$rigSkills/$1/SKILL.md"
}
rigRoutine(){ ## owner, short name, executors
	printf -- '---\nexecutors: %s\nmaintainers: magic-coordinator\n---\n# %s.%s.routine — the actual procedure\n' "$3" "$1" "$2" > "$rigSkills/$1/$1.$2.routine.md"
}
rigMember magic-team active
printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator\ninvitees: magic-team\ndefault-for-session-kind: coworking\n---\n# rig coworking routine fixture\n' > "$rigSkills/magic-team/magic-team.coworking.routine.md"
for rigName in keeper-myx keeper-one keeper-two keeper-three keeper-four magic-coordinator ; do rigMember "$rigName" active ; done
rigMember human-owner reference-only
rigRoutine keeper-myx solo keeper-myx
rigRoutine keeper-myx anyone magic-team
rigRoutine keeper-myx mixed 'keeper-myx, magic-team'
## This workspace's own member registry, the store its registry of the members is built from: the team's folder has a
## row in it as each member's has, and the team's rules file a row that is no member's.
for rigName in human-owner keeper-myx magic-coordinator magic-team ; do
	printf '%s\t%s\tsource-symlink\t%s\t%s\n' "$rigName" "$rigWs" "myx/pkg/skillset/magic-team/$rigName" "$rigSkills/$rigName"
done > "$rigWs/.local/agents/members.registry"
printf '%s\t%s\trules-symlink\t%s\t%s\n' magic-team.basic.md "$rigWs" myx/pkg/skillset/magic-team/magic-team/magic-team.basic.md "$rigSkills/magic-team/magic-team.basic.md" >> "$rigWs/.local/agents/members.registry"
cp "$rigWs/.local/agents/members.registry" "$rigHome/.agents/magic-team/members.registry"
printf 'ws-here\t%s\n' "$rigWs" > "$rigHome/.agents/magic-team/directories.registry"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
## The console a start runs: it keeps the brief it was given under the member it was started as, and hands back.
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records who was started, with what.' \
	'cat > "$RIG_SCENARIO/brief.$MDAT_SPAWN_AGENT.$MDAT_SPAWN_SESSION_ID"' \
	'printf "📦 SubagentHandback\n"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"

rigRun(){ ## tool arguments... -- one dispatcher call from the rig workspace, a brief on standard input; rc in rigRc, stdout in out, stderr in err
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigSc" \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" <<< "RIG-BRIEF-TEXT" || rigRc=$?
}
rigAgent(){ ## tool argument JSON -- the harness tool Agent, served: what it answers in out, what it traces of the call in err, its rc in rigRc
	rigRc=0
	printf '%s' "$1" | ( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		HARNESS_PROVIDER_NAME=rig HARNESS_SELF_NAME=rig RIG_SCENARIO="$rigSc" bash "$rigHarness" --intern-tool Agent --access-read-root "$rigTmp" ) > "$rigTmp/out" 2> "$rigTmp/err" || rigRc=$?
}
rigErrors(){ ## -- how many lines of the last stderr are an error, but for the one every rig of this package gets
	LC_ALL=C grep -e 'ERROR' -e 'ASSERT' "$rigTmp/err" | LC_ALL=C grep -c -v -F -- 'SystemContext.SetInputSpec' || :
}
rigWhole(){ ## file, text -- how many lines of the file are that text, whole
	LC_ALL=C grep -c -x -F -- "$2" "$1" 2> /dev/null || :
}
rigSays='magic-team is the team itself and no member of it, and the team is never started: a run is a member'"'"'s, so name the members -- nothing was started'
rigLine(){ ## the operation it was asked of -- the one plain line that refuses a start of the team
	printf '⛔ ERROR: DistroAgentsTools %s: %s' "$1" "$rigSays"
}
rigRefused(){ ## operation -- how many lines of the last stderr are that line, whole
	rigWhole "$rigTmp/err" "$( rigLine "$1" )"
}
rigSaid(){ ## file -- how many of its lines say it, whatever stands around it
	LC_ALL=C grep -c -F -- "$rigSays" "$1" 2> /dev/null || :
}
rigMade(){ ## -- what the starts so far have made: sandboxes, spawn records, board items, consoles started, posts
	printf '%s %s %s %s %s\n' "$( ls "$rigWs/.local/agents/spawned" 2> /dev/null | LC_ALL=C grep -c . || : )" "$( ls "$rigWs"/.local/agents/spawned/*/*.md 2> /dev/null | LC_ALL=C grep -c . || : )" \
		"$( find "$rigData/board" -type f 2> /dev/null | LC_ALL=C grep -c . || : )" "$( ls "$rigSc" | LC_ALL=C grep -c '^brief\.' || : )" "$( LC_ALL=C grep -c '^chat.postMessage ' "$rigSc/calls" 2> /dev/null || : )"
}
rigStores(){ ## -- how many run stores the workspace holds
	ls "$rigWs/.local/agents/sessions" 2> /dev/null | LC_ALL=C grep -c . || :
}
rigConsolesOf(){ ## member -- how many consoles were started as that member
	ls "$rigSc" | LC_ALL=C grep -c "^brief\.$1\." || :
}
rigConsolesAre(){ ## member, count -- whether that many consoles were started as that member by now
	[ "$( rigConsolesOf "$1" )" = "$2" ]
}
rigConsoles(){ ## -- how many consoles were started at all
	ls "$rigSc" | LC_ALL=C grep -c '^brief\.' || :
}
rigSettle(){ ## -- every run started so far has closed its record, so what a later scenario counts stands still
	local settleLeft=90
	while LC_ALL=C grep -l -x 'status: spawn-started' "$rigWs"/.local/agents/spawned/*/*.md > /dev/null 2>&1 && [ "$settleLeft" -gt 0 ] ; do sleep 1 ; settleLeft=$(( settleLeft - 1 )) ; done
	sleep 1
}

echo "-- 1. the spawn proxy, which every start goes through --"
rigRun "$rigProxy" keeper-myx --dispatch-doc:create --context rig-team-not-member
rigAssert "control: a member is started as before, with a session id, and the proxy does not wait" "$rigRc $( rigErrors ) $( LC_ALL=C grep -c -e '^SESSION_ID=.' -e '^STATUS=started$' -e '^DISPATCH_ITEM=dispatch-' "$rigTmp/out" )" "0 0 3"
rigWaitFor 30 rigConsolesAre keeper-myx 1 || rigRefuse "the stand-in console never ran for the control start: $( LC_ALL=C grep -e ERROR "$rigTmp/err" | LC_ALL=C grep -v -F SetInputSpec | head -1 )"
rigSettle
rigMadeBefore="$( rigMade )" ; rigStoresBefore="$( rigStores )"
rigAssert "control: that start made a sandbox with its record, a board item, a console and a post" "$rigMadeBefore" "1 1 1 1 1"
rigRun "$rigProxy" magic-team --dispatch-doc:create --context rig-team-not-member
rigAssert "the team, whose folder stands in the member set and whose SKILL.md says status: active, is refused: rc 1, nothing on stdout, one error line, which says it is the team itself and no member" \
	"$( [ -d "$rigSkills/magic-team" ] && echo has-folder ) $( LC_ALL=C grep -c -x 'status: active' "$rigSkills/magic-team/SKILL.md" ) $rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigRefused "$rigProxy" ) $( rigErrors )" "has-folder 1 1 0 1 1"
rigAssert "and it leaves nothing behind: no sandbox, no record, no item, no console, no post, and no run store" "$( rigMade ) / $( rigStores )" "$rigMadeBefore / $rigStoresBefore"
printf -- '---\ntype: dispatch\nowner: magic-team\nstatus: dispatch-started\n---\n\n# rig dispatch\n' > "$rigData/board/running/dispatch-20261013T1100Z-form.md"
rigMadeBefore="$( rigMade )"
rigFormsBad=""
for rigForm in "--dispatch-doc:none" "--dispatch-doc:none --wait" "--dispatch-doc:create --wait" "--dispatch-doc:create --session-new" "--dispatch-doc:create --routine-default" "--dispatch-doc:create --routine solo" "--from-stdin --dispatch-doc:create --calling-member magic-coordinator" "--dispatch-doc:create --session-thread:event-track" "--from-board dispatch-20261013T1100Z-form.md --board-state running --dispatch-doc:reuse" ; do
	rigRun "$rigProxy" magic-team $rigForm --context rig-team-not-member
	[ "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigRefused "$rigProxy" ) $( rigErrors ) $( rigMade ) / $( rigStores )" = "1 0 1 1 $rigMadeBefore / $rigStoresBefore" ] \
		|| rigFormsBad="$rigFormsBad [$rigForm: rc $rigRc, made $( rigMade ), $( LC_ALL=C grep -e ERROR "$rigTmp/err" | LC_ALL=C grep -v -F SetInputSpec | head -1 )]"
done
rigAssert "in every form of the call: waited for or not, with or without a dispatch item, a session of its own, a routine, a calling member, a session that starts alone, and the form a review return makes of an item on the board" "${rigFormsBad:-each refused, nothing left}" "each refused, nothing left"
rigSettle

echo "-- 2. --magic-spawn-session --"
rigMadeBefore="$( rigMade )" ; rigStoresBefore="$( rigStores )"
rigSession="--magic-spawn-session"
rigRun "$rigSession" --routine solo magic-team
rigAssert "the team named: refused in that line, rc 1, no session id, and nothing left behind" \
	"$rigRc $( LC_ALL=C grep -c '^SESSION_ID=' "$rigTmp/out" || : ) $( rigRefused "$rigSession" ) $( rigErrors ) $( rigMade ) / $( rigStores )" "1 0 1 1 $rigMadeBefore / $rigStoresBefore"
rigRun "$rigSession" --routine solo keeper-myx keeper-one keeper-two magic-team keeper-three keeper-four
rigAssert "a session asked for with five members and the team among them starts none: one line, no session id, no console, nothing left behind" \
	"$rigRc $( LC_ALL=C grep -c '^SESSION_ID=' "$rigTmp/out" || : ) $( rigRefused "$rigSession" ) $( rigErrors ) $( rigMade ) / $( rigStores )" "1 0 1 1 $rigMadeBefore / $rigStoresBefore"
rigRun "$rigSession" --routine mixed
rigAssert "a routine whose executors list holds the team beside a member, no member named: neither is started" \
	"$( LC_ALL=C grep -c -x 'executors: keeper-myx, magic-team' "$rigSkills/keeper-myx/keeper-myx.mixed.routine.md" ) $rigRc $( rigRefused "$rigSession" ) $( rigErrors ) $( rigMade ) / $( rigStores )" "1 1 1 1 $rigMadeBefore / $rigStoresBefore"
rigRun "$rigSession" --routine anyone
rigAssert "a routine whose executors are magic-team still means any member: with no member named it asks for members, as before, and says nothing of a start of the team" \
	"$( LC_ALL=C grep -c -x 'executors: magic-team' "$rigSkills/keeper-myx/keeper-myx.anyone.routine.md" ) $rigRc $( LC_ALL=C grep -c -F -- "is not a plain comma-separated list of existing members -- pass explicit <team-member>... instead" "$rigTmp/err" || : ) $( rigSaid "$rigTmp/err" ) $( rigMade )" "1 1 1 0 $rigMadeBefore"
rigRun "$rigSession" --routine anyone magic-team
rigAssert "and the team itself is no member to name for it: refused in that line, nothing left behind" "$rigRc $( rigRefused "$rigSession" ) $( rigErrors ) $( rigMade ) / $( rigStores )" "1 1 1 $rigMadeBefore / $rigStoresBefore"
rigConsolesBefore="$( rigConsolesOf keeper-myx )"
rigRun "$rigSession" --routine anyone keeper-myx
rigAssert "control: that routine is started with a real member named, as before" "$rigRc $( rigErrors ) $( LC_ALL=C grep -c -e '^SESSION_ID=.' -e '^MEMBERS=keeper-myx$' "$rigTmp/out" )" "0 0 2"
rigWaitFor 30 rigConsolesAre keeper-myx "$(( rigConsolesBefore + 1 ))"
rigAssert "and its console runs" "$(( $( rigConsolesOf keeper-myx ) - rigConsolesBefore ))" "1"
rigSettle

echo "-- 3. the harness tool Agent --"
rigMadeBefore="$( rigMade )"
rigAgent '{"agent":"magic-team","prompt":"RIG-AGENT-TASK"}'
rigAssert "the tool answers, once, that the spawn failed and no helper runs, with that line as what the operation reported" \
	"$( LC_ALL=C grep -c -F -- 'ERROR: the spawn failed (rc=1) and NO helper session is running.' "$rigTmp/out" || : ) $( rigWhole "$rigTmp/out" "$( rigLine "$rigProxy" )" ) $( LC_ALL=C grep -c -F -- 'Spawned as' "$rigTmp/out" || : )" "1 1 0"
rigAssert "and nothing is left behind: no sandbox, no record, no item, no console, no post" "$( rigMade )" "$rigMadeBefore"
rigConsolesBefore="$( rigConsolesOf keeper-myx )"
rigAgent '{"agent":"keeper-myx","prompt":"RIG-AGENT-TASK"}'
rigAssert "control: the tool starts a member as before" "$( LC_ALL=C grep -c -F -- 'Spawned as keeper-myx.' "$rigTmp/out" || : ) $( LC_ALL=C grep -c -F -- 'ERROR: the spawn failed' "$rigTmp/out" || : )" "1 0"
rigWaitFor 60 rigConsolesAre keeper-myx "$(( rigConsolesBefore + 1 ))"
rigSettle

echo "-- 4. the heartbeat's start and a review return --"
rigMadeBefore="$( rigMade )" ; rigStoresBefore="$( rigStores )"
rigRun --magic-heartbeat-spawn-proxy magic-team --description rig-team-not-member
rigAssert "--magic-heartbeat-spawn-proxy refuses in the same line, under its own name, and leaves nothing behind" \
	"$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigRefused --magic-heartbeat-spawn-proxy ) $( rigErrors ) $( rigMade ) / $( rigStores )" "1 0 1 1 $rigMadeBefore / $rigStoresBefore"
rigRun --magic-heartbeat-spawn-proxy keeper-myx --description rig-team-not-member
rigAssert "control: a member the heartbeat does not start for is refused as before, as an unsupported caller" "$rigRc $( LC_ALL=C grep -c -F -- 'unsupported caller: keeper-myx' "$rigTmp/err" || : ) $( rigSaid "$rigTmp/err" )" "1 1 0"
rigAssert "the main loop starts one member only, the coordinator, through that operation: it names no other" \
	"$( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/AgentsTools.InternRootHarness.include" | LC_ALL=C grep -c -F -- '--magic-heartbeat-spawn-proxy magic-coordinator ' || : ) $( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/AgentsTools.InternMainLoop.include" | LC_ALL=C grep -c -e 'spawn-proxy "' -e 'spawn-member' -e 'magic-spawn-session' || : )" "1 0"
printf -- '---\ntype: dispatch\nowner: magic-team\nstatus: dispatch-started\nreview-since-epoch: 1000\n---\n\n# rig dispatch\n' > "$rigData/board/review/dispatch-20261013T1200Z-team.md"
rigConsolesBefore="$( rigConsoles )"
rigRun --member-review-return magic-coordinator dispatch-20261013T1200Z-team --message "redo the rig step"
rigAssert "a review return of an item the team owns restarts nobody: it says the spawn of magic-team failed, with that line as the cause, and no console is started" \
	"$( cat "$rigTmp/out" "$rigTmp/err" | LC_ALL=C grep -c -F -- 'RETURN: not restarted: the spawn of magic-team for dispatch-20261013T1200Z-team failed (rc 1): ' || : ) $( cat "$rigTmp/out" "$rigTmp/err" | LC_ALL=C grep -F -- 'RETURN: not restarted' | LC_ALL=C grep -c -F -- "$rigSays" || : ) $(( $( rigConsoles ) - rigConsolesBefore )) $( rigConsolesOf magic-team )" "1 1 0 0"
rigSettle

echo "-- 5. the console's own operations --"
rigMadeBefore="$( rigMade )" ; rigStoresBefore="$( rigStores )"
rigRun --manager-spawn-member magic-team
rigAssert "--manager-spawn-member refuses in the same line, under its own name, and leaves nothing behind" \
	"$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigRefused --manager-spawn-member ) $( rigErrors ) $( rigMade ) / $( rigStores )" "1 0 1 1 $rigMadeBefore / $rigStoresBefore"
rigRun --manager-routine-list
rigRowOf(){ ## selector -- that routine's row in the last output: its <start>, its <executors>, its <reason> and what it needs
	LC_ALL=C awk -F'\t' -v wantName="$1" '$1 == "routine" && $2 == wantName { print $4, $5, $9, $10 }' "$rigTmp/out"
}
rigAssert "--manager-routine-list: a routine whose executors are magic-team is any member's, as before: not-startable by itself, and it needs members" \
	"$rigRc | $( rigRowOf keeper-myx.anyone.routine.md )" "0 | not-startable magic-team its_executors,_magic-team,_is_any_member:_the_session_spawner_starts_it_only_with_members_named members"
rigAssert "one whose executors list holds the team beside a member reads not-startable, with the reason in words; a routine of members alone reads startable" \
	"$( rigRowOf keeper-myx.mixed.routine.md ) | $( rigRowOf keeper-myx.solo.routine.md )" "not-startable keeper-myx,_magic-team its_executor_magic-team_is_the_team_itself_and_no_member_of_it,_which_is_never_started - | startable keeper-myx - -"
rigRun --manager-team-member-list
rigAssert "--manager-team-member-list keeps the team's row, as it keeps an identity record's, and its status says what it is: the-team, where its SKILL.md says active; a member's status is its file's" \
	"$rigRc $( LC_ALL=C awk -F'\t' '$1 == "member" && ( $2 == "magic-team" || $2 == "human-owner" || $2 == "keeper-myx" ) { printf "%s=%s ", $2, $10 }' "$rigTmp/out" )" "0 human-owner=reference-only keeper-myx=active magic-team=the-team "
rigAssert "the registry of the members, rebuilt by that call from this workspace's own store, keeps the team's row as it keeps each member's, and the rules file has none" \
	"$( LC_ALL=C awk '{ printf "%s ", $1 }' "$rigWs/.local/agents/team-members.registry" 2> /dev/null )" "human-owner keeper-myx magic-coordinator magic-team "
rigRun --manager-team-member-read magic-team
rigAssert "the read of the team shows it the same way" "$rigRc $( LC_ALL=C awk -F'\t' '$1 == "member" { print $2, $10 }' "$rigTmp/out" )" "0 magic-team the-team"

echo "-- 6. a message to the team --"
rigPostsBefore="$( LC_ALL=C grep -c '^chat.postMessage ' "$rigSc/calls" 2> /dev/null || : )"
: > "$rigSc/bodies"
rigRun --member-comms-slack-send-message keeper-myx magic-team --identity-bot --address-to magic-team --from-stdin
rigAssert "a message to the team's conversation, addressed to the team, goes out as before: rc 0, no error, one post, into that conversation" \
	"$rigRc $( rigErrors ) $(( $( LC_ALL=C grep -c '^chat.postMessage ' "$rigSc/calls" 2> /dev/null || : ) - rigPostsBefore )) $( LC_ALL=C grep -c -F -- 'CRIG00001' "$rigSc/bodies" || : ) $( LC_ALL=C grep -c -F -- 'RIG-BRIEF-TEXT' "$rigSc/bodies" || : )" "0 0 1 1 1"

echo "-- 7. the rule is one --"
rigCode(){ ## include name -- its lines that are no comment
	LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/$1" 2> /dev/null
}
rigAssert "one function says what the team is, defined once, in the include of the member directory, beside the one check of a start" \
	"$( cat "$rigHere"/*.include "$rigHere"/*.sh | LC_ALL=C grep -c -E '^AgentsToolsTeamMemberIsTeam\(\)\{' || : ) $( LC_ALL=C grep -c -E '^AgentsToolsTeamMember(IsTeam|StartCheck)\(\)\{' "$rigHere/AgentsTools.TeamRegistry.include" || : )" "1 2"
rigAssert "the refusal's line is written once, in that check, which asks that function" \
	"$( cat "$rigHere"/*.include "$rigHere"/*.sh | LC_ALL=C grep -c -F -- 'is the team itself and no member of it, and the team is never started' || : ) $( rigCode AgentsTools.TeamRegistry.include | LC_ALL=C awk '/^AgentsToolsTeamMemberStartCheck\(\)\{/ { inCheck = 1 } inCheck && /AgentsToolsTeamMemberIsTeam "/ { asked++ } inCheck && /^\}/ { inCheck = 0 } END { print asked + 0 }' )" "1 1"
rigAssert "no starter asks what the team is, or names it, itself: the proxy, --magic-spawn-session, --manager-spawn-member and the heartbeat's start each ask the one check of a start, once" \
	"$( for rigFile in InternOpAgentSpawnProxy MagicSpawnSession ManagerSpawn MagicHeartbeat ; do printf '%s:%s ' "$( rigCode "AgentsTools.$rigFile.include" | LC_ALL=C grep -c -e 'AgentsToolsTeamMemberStartCheck "' || : )" "$( rigCode "AgentsTools.$rigFile.include" | LC_ALL=C grep -c -e 'AgentsToolsTeamMemberIsTeam' || : )" ; done )" "1:0 1:0 1:0 1:0 "
rigAssert "--manager-routine-list and --manager-team-member-list ask that function, once each, and neither names the team" \
	"$( rigCode AgentsTools.ManagerRoutine.include | LC_ALL=C grep -c -e 'AgentsToolsTeamMemberIsTeam "' || : ) $( rigCode AgentsTools.ManagerTeamMember.include | LC_ALL=C grep -c -e 'AgentsToolsTeamMemberIsTeam "' || : ) $( rigCode AgentsTools.ManagerRoutine.include | LC_ALL=C grep -c -e 'magic-team' || : ) $( rigCode AgentsTools.ManagerTeamMember.include | LC_ALL=C grep -c -e 'magic-team' || : )" "1 1 0 0"

rigSettle
if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ TEAM NOT MEMBER CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'TEAM_NOT_MEMBER: OK (%d assertions, offline)\n' "$rigPasses"
