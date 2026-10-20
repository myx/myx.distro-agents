#!/usr/bin/env bash
## Behavioural check on the rule that NOTHING RUNS AS AN IDENTITY RECORD, run rather than read, against a rig machine
## built here: a member whose SKILL.md says `status: reference-only` is the record of a person (human-owner is one) and
## no acting member, and no start starts it. Held, on each of the three ways a member is started: the spawn proxy
## (--intern-op-agent-spawn-proxy), which every start goes through, in every form of its call; --magic-spawn-session,
## with the member named and with a routine whose executors name it; and the harness tool Agent. Each is refused in
## one plain line that names the member and says an identity record is never started, and a refused start leaves
## nothing behind: no sandbox and no spawn record, no run store, no board item, no console, and no post, so no session
## thread. A call that would start several members and names one such member starts none of them. A member set up
## only in another workspace of the machine is refused by its SKILL.md there. The refusal is by that status line and
## not by a name: the same member with `status: active` starts, and so does every member that was started before --
## one with `status: active`, one with no SKILL.md, and a caller that is no member. The team's own entry magic-team is
## no identity record either, and is refused by a rule of its own, in a line of its own (AgentsTeamNotMemberCheck).
## --manager-spawn-member refuses in the same line, under its own name, and --manager-routine-list says not-startable,
## with the reason in words, for a routine whose executors name such a member. THE CHECK IS ONE: one function says
## what a reference-only member is, one function refuses a start, the spawn proxy asks it before it makes anything,
## and the two operations that would otherwise make something first ask that same function. A stand-in console
## records each start, a fake `curl` answers Slack and logs each call. No real CLI is started. Offline; only the
## rig's own tree is read or written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTest="$rigPackage/sh-test"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
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
rigTmp="$( rigTempDir AgentsSpawnReferenceOnlyCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp" 2> /dev/null || { sleep 3 ; rm -rf -- "$rigTmp" 2> /dev/null ; }' EXIT
rigWs="$rigTmp/ws-here" ; rigThere="$rigTmp/ws-there" ; rigHome="$rigTmp/home" ; rigData="$rigTmp/data" ; rigSc="$rigTmp/sc"
rigSkills="$rigWs/.local/agents/members"
rigThereSkills="$rigThere/.local/agents/members"
mkdir -p "$rigTmp/bin" "$rigSc" "$rigWs/.local/.agents" "$rigSkills" "$rigThere/.local/.agents" "$rigThereSkills" "$rigHome/.agents/magic-team" "$rigData/board/running"
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"
rigTab="$( printf '\t' )"

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

## THE RIG MACHINE. ws-here is the workspace every call is made from; ws-there holds a member ws-here does not.
rigMember(){ ## member set root, member, status ("" for no SKILL.md) -- a member's folder with the files a start of it reads
	mkdir -p "$1/$2"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$1/$2/$2.basic.md"
	printf '# rig armed\n' > "$1/$2/$2.armed.md"
	[ -z "$3" ] || printf -- '---\nname: %s\nstatus: %s\ninvocation_mode: auto\n---\n\n# %s\n' "$2" "$3" "$2" > "$1/$2/SKILL.md"
}
rigRoutine(){ ## member set root, owner, short name, executors
	printf -- '---\nexecutors: %s\nmaintainers: magic-coordinator\nrequires-session-kind: standalone\n---\n# %s.%s.routine — the actual procedure\n' "$4" "$2" "$3" > "$1/$2/$2.$3.routine.md"
}
for rigRoot in "$rigSkills" "$rigThereSkills" ; do
	rigMember "$rigRoot" magic-team active
	printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator\ninvitees: magic-team\nrequires-session-kind: coworking\n---\n# rig coworking routine fixture\n' > "$rigRoot/magic-team/magic-team.coworking.routine.md"
done
rigMember "$rigSkills" keeper-myx active
rigMember "$rigSkills" keeper-plain ""
rigMember "$rigSkills" magic-coordinator active
rigMember "$rigSkills" human-owner reference-only
rigMember "$rigSkills" keeper-ref reference-only
rigMember "$rigThereSkills" keeper-thereref reference-only
rigRoutine "$rigSkills" keeper-myx solo keeper-myx
rigRoutine "$rigSkills" keeper-myx owner human-owner
rigRoutine "$rigSkills" keeper-myx both 'keeper-myx, human-owner'
{
	printf '%s\t%s\tsource-symlink\t%s\t%s\n' keeper-myx "$rigWs" myx/pkg/skillset/keeper-myx "$rigSkills/keeper-myx"
	printf '%s\t%s\tsource-symlink\t%s\t%s\n' keeper-thereref "$rigThere" myx/pkg/skillset/keeper-thereref "$rigThereSkills/keeper-thereref"
} > "$rigHome/.agents/magic-team/members.registry"
printf 'ws-here\t%s\nws-there\t%s\n' "$rigWs" "$rigThere" > "$rigHome/.agents/magic-team/directories.registry"
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
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigSc" \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" <<< "RIG-BRIEF-TEXT" || rigRc=$?
}
rigAgent(){ ## tool argument JSON -- the harness tool Agent, served: what it answers in out, what it traces of the call in err, its rc in rigRc
	rigRc=0
	printf '%s' "$1" | ( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		HARNESS_PROVIDER_NAME=rig HARNESS_SELF_NAME=rig RIG_SCENARIO="$rigSc" bash "$rigHarness" --intern-tool Agent --access-read-root "$rigTmp" ) > "$rigTmp/out" 2> "$rigTmp/err" || rigRc=$?
}
rigErrors(){ ## -- how many lines of the last stderr are an error, but for the one every rig of this package gets
	LC_ALL=C grep -e 'ERROR' -e 'ASSERT' "$rigTmp/err" | LC_ALL=C grep -c -v -F -- 'SystemContext.SetInputSpec' || :
}
rigWhole(){ ## file, text -- how many lines of the file are that text, whole
	LC_ALL=C grep -c -x -F -- "$2" "$1" 2> /dev/null || :
}
rigLine(){ ## member, the operation it was asked of -- the one plain line that refuses its start
	printf '⛔ ERROR: DistroAgentsTools %s: %s is an identity record, and an identity record is never started: its SKILL.md says status: reference-only -- nothing was started' "$2" "$1"
}
rigRefused(){ ## member, operation -- how many lines of the last stderr are that line, whole
	rigWhole "$rigTmp/err" "$( rigLine "$1" "$2" )"
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
rigSettle(){ ## -- every run started so far has closed its record, so what a later scenario counts stands still
	local settleLeft=90
	while LC_ALL=C grep -l -x 'status: spawn-started' "$rigWs"/.local/agents/spawned/*/*.md > /dev/null 2>&1 && [ "$settleLeft" -gt 0 ] ; do sleep 1 ; settleLeft=$(( settleLeft - 1 )) ; done
	sleep 1
}

echo "-- 1. the spawn proxy, which every start goes through --"
rigRun "$rigProxy" keeper-myx --dispatch-doc:create --context rig-reference-only
rigAssert "control: a member whose SKILL.md says status: active is started as before, with a session id, and the proxy does not wait" \
	"$( LC_ALL=C grep -c -x 'status: active' "$rigSkills/keeper-myx/SKILL.md" ) $rigRc $( rigErrors ) $( LC_ALL=C grep -c -e '^SESSION_ID=.' -e '^STATUS=started$' -e '^DISPATCH_ITEM=dispatch-' "$rigTmp/out" )" "1 0 0 3"
rigWaitFor 30 rigConsolesAre keeper-myx 1 || rigRefuse "the stand-in console never ran for the control start: $( LC_ALL=C grep -e ERROR "$rigTmp/err" | LC_ALL=C grep -v -F SetInputSpec | head -1 )"
rigAssert "its console received the brief" "$( cat "$rigSc"/brief.keeper-myx.* 2> /dev/null | LC_ALL=C grep -c -x 'RIG-BRIEF-TEXT' )" "1"
rigSettle
rigMadeBefore="$( rigMade )" ; rigStoresBefore="$( rigStores )"
rigAssert "control: that start made a sandbox with its record, a board item, a console and a post" "$rigMadeBefore" "1 1 1 1 1"
rigRun "$rigProxy" human-owner --dispatch-doc:create --context rig-reference-only
rigAssert "human-owner, whose SKILL.md says status: reference-only, is refused: rc 1, nothing on stdout, one error line, which names it and says an identity record is never started" \
	"$( LC_ALL=C grep -c -x 'status: reference-only' "$rigSkills/human-owner/SKILL.md" ) $rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigRefused human-owner "$rigProxy" ) $( rigErrors )" "1 1 0 1 1"
rigAssert "and it leaves nothing behind: no sandbox, no record, no item, no console, no post, and no run store" "$( rigMade ) / $( rigStores )" "$rigMadeBefore / $rigStoresBefore"
rigFormsBad=""
for rigForm in "--dispatch-doc:none" "--dispatch-doc:none --wait" "--dispatch-doc:create --wait" "--dispatch-doc:create --session-new" "--dispatch-doc:create --routine-default" "--dispatch-doc:create --routine solo" "--from-stdin --dispatch-doc:create --calling-member magic-coordinator" "--dispatch-doc:create --session-thread:event-track" ; do
	rigRun "$rigProxy" human-owner $rigForm --context rig-reference-only
	[ "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigRefused human-owner "$rigProxy" ) $( rigErrors ) $( rigMade ) / $( rigStores )" = "1 0 1 1 $rigMadeBefore / $rigStoresBefore" ] \
		|| rigFormsBad="$rigFormsBad [$rigForm: rc $rigRc, made $( rigMade ), $( LC_ALL=C grep -e ERROR "$rigTmp/err" | LC_ALL=C grep -v -F SetInputSpec | head -1 )]"
done
rigAssert "in every form of the call: waited for or not, with or without a dispatch item, a session of its own, a routine, a calling member, a session that starts alone" "${rigFormsBad:-each refused, nothing left}" "each refused, nothing left"
rigRun "$rigProxy" keeper-ref --dispatch-doc:create --context rig-reference-only
rigAssert "any member whose SKILL.md says so is refused the same: by that line of its file, not by its name" "$rigRc $( rigRefused keeper-ref "$rigProxy" ) $( rigMade )" "1 1 $rigMadeBefore"
rigRun "$rigProxy" keeper-thereref --dispatch-doc:create --context rig-reference-only
rigAssert "a member set up only in another workspace of the machine is refused by its SKILL.md there" \
	"$( [ -e "$rigSkills/keeper-thereref" ] && echo here || echo not-here ) $( LC_ALL=C grep -c -x 'status: reference-only' "$rigThereSkills/keeper-thereref/SKILL.md" ) $rigRc $( rigRefused keeper-thereref "$rigProxy" ) $( rigErrors ) $( rigMade )" "not-here 1 1 1 1 $rigMadeBefore"
printf -- '---\nname: keeper-ref\nstatus: active\n---\n\n# keeper-ref\n' > "$rigSkills/keeper-ref/SKILL.md"
rigRun "$rigProxy" keeper-ref --dispatch-doc:create --context rig-reference-only
rigAssert "control: the same member with status: active starts" "$rigRc $( rigErrors ) $( LC_ALL=C grep -c -e '^STATUS=started$' "$rigTmp/out" )" "0 0 1"
printf -- '---\nname: keeper-ref\nstatus: reference-only\n---\n\n# keeper-ref\n' > "$rigSkills/keeper-ref/SKILL.md"
rigRun "$rigProxy" keeper-plain --dispatch-doc:create --context rig-reference-only
rigAssert "control: a member with no SKILL.md starts as before: nothing says it is an identity record" "$( [ -e "$rigSkills/keeper-plain/SKILL.md" ] && echo has-skill-file || echo no-skill-file ) $rigRc $( LC_ALL=C grep -c -e '^STATUS=started$' "$rigTmp/out" )" "no-skill-file 0 1"
rigRun "$rigProxy" magic-team --dispatch-doc:create --context rig-reference-only
rigAssert "the team's own entry, whose status is active, is no identity record and is not refused as one: the rule of its own refuses it, in its own line, and nothing is started" \
	"$( LC_ALL=C grep -c -x 'status: active' "$rigSkills/magic-team/SKILL.md" ) $rigRc $( rigRefused magic-team "$rigProxy" ) $( LC_ALL=C grep -c -F -- 'magic-team is the team itself and no member of it' "$rigTmp/err" || : ) $( LC_ALL=C grep -c -e '^STATUS=started$' "$rigTmp/out" || : )" "1 1 0 1 0"
rigRun "$rigProxy" rig-meta-caller --dispatch-doc:none --context rig-reference-only
rigAssert "control: a caller that is no member, with no folder at all, starts as before" "$( [ -e "$rigSkills/rig-meta-caller" ] && echo has-folder || echo no-folder ) $rigRc $( LC_ALL=C grep -c -e '^STATUS=started$' "$rigTmp/out" )" "no-folder 0 1"
rigSettle

echo "-- 2. --magic-spawn-session --"
rigMadeBefore="$( rigMade )" ; rigStoresBefore="$( rigStores )"
rigSession="--magic-spawn-session"
rigRun "$rigSession" --routine solo human-owner
rigAssert "the member named: refused in that line, rc 1, no session id, and nothing left behind" \
	"$rigRc $( LC_ALL=C grep -c '^SESSION_ID=' "$rigTmp/out" || : ) $( LC_ALL=C grep -c -F -- 'human-owner is an identity record, and an identity record is never started: its SKILL.md says status: reference-only -- nothing was started' "$rigTmp/err" || : ) $( rigErrors ) $( rigMade ) / $( rigStores )" "1 0 1 1 $rigMadeBefore / $rigStoresBefore"
rigRun "$rigSession" --routine owner
rigAssert "no member named, and a routine whose executors name it: refused in that line, and nothing left behind" \
	"$( LC_ALL=C grep -c -x 'executors: human-owner' "$rigSkills/keeper-myx/keeper-myx.owner.routine.md" ) $rigRc $( LC_ALL=C grep -c '^SESSION_ID=' "$rigTmp/out" || : ) $( rigRefused human-owner "$rigSession" ) $( rigErrors ) $( rigMade ) / $( rigStores )" "1 1 0 1 1 $rigMadeBefore / $rigStoresBefore"
rigRun "$rigSession" --routine solo keeper-myx human-owner
rigAssert "two members named, the second an identity record: neither is started, the first one too, and nothing is left behind" \
	"$rigRc $( LC_ALL=C grep -c '^SESSION_ID=' "$rigTmp/out" || : ) $( rigRefused human-owner "$rigSession" ) $( rigErrors ) $( rigMade ) / $( rigStores )" "1 0 1 1 $rigMadeBefore / $rigStoresBefore"
rigRun "$rigSession" --routine both
rigAssert "a routine whose executors are an acting member and an identity record: neither is started" \
	"$( LC_ALL=C grep -c -x 'executors: keeper-myx, human-owner' "$rigSkills/keeper-myx/keeper-myx.both.routine.md" ) $rigRc $( rigRefused human-owner "$rigSession" ) $( rigErrors ) $( rigMade ) / $( rigStores )" "1 1 1 1 $rigMadeBefore / $rigStoresBefore"
rigConsolesBefore="$( rigConsolesOf keeper-myx )"
rigRun "$rigSession" --routine solo
rigAssert "control: a routine whose executor is an acting member starts it as before" "$rigRc $( rigErrors ) $( LC_ALL=C grep -c -e '^SESSION_ID=.' -e '^MEMBERS=keeper-myx$' "$rigTmp/out" )" "0 0 2"
rigWaitFor 30 rigConsolesAre keeper-myx "$(( rigConsolesBefore + 1 ))"
rigAssert "and its console runs" "$(( $( rigConsolesOf keeper-myx ) - rigConsolesBefore ))" "1"
rigSettle

echo "-- 3. the harness tool Agent --"
rigMadeBefore="$( rigMade )"
rigAgent '{"agent":"human-owner","prompt":"RIG-AGENT-TASK"}'
rigAssert "the tool answers, once, that the spawn failed and no helper runs, with that line as what the operation reported" \
	"$( LC_ALL=C grep -c -F -- 'ERROR: the spawn failed (rc=1) and NO helper session is running.' "$rigTmp/out" || : ) $( rigWhole "$rigTmp/out" "$( rigLine human-owner "$rigProxy" )" ) $( LC_ALL=C grep -c -F -- 'Spawned as' "$rigTmp/out" || : )" "1 1 0"
rigAssert "and nothing is left behind: no sandbox, no record, no item, no console, no post" "$( rigMade )" "$rigMadeBefore"
rigConsolesBefore="$( rigConsolesOf keeper-myx )"
rigAgent '{"agent":"keeper-myx","prompt":"RIG-AGENT-TASK"}'
rigAssert "control: the tool starts an acting member as before" "$( LC_ALL=C grep -c -F -- 'Spawned as keeper-myx.' "$rigTmp/out" || : ) $( LC_ALL=C grep -c -F -- 'ERROR: the spawn failed' "$rigTmp/out" || : )" "1 0"
rigWaitFor 60 rigConsolesAre keeper-myx "$(( rigConsolesBefore + 1 ))"
rigAssert "and its console receives the prompt" "$(( $( rigConsolesOf keeper-myx ) - rigConsolesBefore )) $( cat "$rigSc"/brief.keeper-myx.* 2> /dev/null | LC_ALL=C grep -c -x 'RIG-AGENT-TASK' )" "1 1"
rigSettle

echo "-- 4. the console's own operations --"
rigMadeBefore="$( rigMade )" ; rigStoresBefore="$( rigStores )"
rigRun --manager-spawn-member human-owner
rigAssert "--manager-spawn-member refuses in the same line, under its own name, and leaves nothing behind" \
	"$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigRefused human-owner --manager-spawn-member ) $( rigErrors ) $( rigMade ) / $( rigStores )" "1 0 1 1 $rigMadeBefore / $rigStoresBefore"
rigRun --manager-routine-list
rigRowOf(){ ## selector -- that routine's row in the last output: its <start>, its <executors> and its <reason>
	LC_ALL=C awk -F'\t' -v wantName="$1" '$1 == "routine" && $2 == wantName { print $4, $5, $9 }' "$rigTmp/out"
}
rigAssert "--manager-routine-list says not-startable, with the reason in words, for a routine whose executors name an identity record" \
	"$rigRc | $( rigRowOf keeper-myx.owner.routine.md )" "0 | not-startable human-owner its_executor_human-owner_is_an_identity_record,_which_is_never_started"
rigAssert "and for one whose executors name it beside an acting member; a routine of acting members alone reads startable" \
	"$( rigRowOf keeper-myx.both.routine.md ) | $( rigRowOf keeper-myx.solo.routine.md )" "not-startable keeper-myx,_human-owner its_executor_human-owner_is_an_identity_record,_which_is_never_started | startable keeper-myx -"

echo "-- 5. the check is one --"
rigCode(){ ## include name -- its lines that are no comment
	LC_ALL=C grep -v '^[[:space:]]*#' "$( ls -d "$rigHere"/*/"$1" "$rigHere"/../../myx.distro-.local/sh-lib/*/"$1" 2> /dev/null | head -1 )" 2> /dev/null
}
rigAssert "one function says what a reference-only member is and one refuses a start, each defined once, in the include of the member directory" \
	"$( cat "$rigHere"/*/*.include "$rigHere"/*/*.sh | LC_ALL=C grep -c -E '^AgentsToolsTeamMemberReferenceOnly\(\)\{' || : ) $( cat "$rigHere"/*/*.include "$rigHere"/*/*.sh | LC_ALL=C grep -c -E '^AgentsToolsTeamMemberStartCheck\(\)\{' || : ) $( LC_ALL=C grep -c -E '^AgentsToolsTeamMember(ReferenceOnly|StartCheck)\(\)\{' "$rigHere/team-data/AgentsTools.TeamRegistry.include" || : )" "1 1 2"
rigAssert "the refusal's line is written once, in that function" "$( cat "$rigHere"/*/*.include "$rigHere"/*/*.sh | LC_ALL=C grep -c -F -- 'an identity record is never started' || : )" "1"
rigAssert "the spawn proxy asks it once, of the member it is about to start, before it reads its brief or makes anything" \
	"$( rigCode AgentsTools.InternOpAgentSpawnProxy.include | LC_ALL=C grep -c -e 'AgentsToolsTeamMemberStartCheck "\$callerName"' || : ) $( rigCode AgentsTools.InternOpAgentSpawnProxy.include | LC_ALL=C awk '/^\t--intern-op-agent-spawn-proxy\)/ { arm = 1 } ! arm { next } /AgentsToolsTeamMemberStartCheck "/ && ! asked { asked = NR } /spawnContext="\$\( cat \)"/ && ! read { read = NR } /mkdir -p/ && ! made { made = NR } END { print ( asked && read && made && asked < read && asked < made ) ? "first" : "not first: asked " asked ", brief " read ", made " made }' )" "1 first"
rigAssert "--manager-spawn-member and --magic-spawn-session ask the same function, once each, and neither reads a SKILL.md itself" \
	"$( rigCode AgentsTools.ManagerSpawn.include | LC_ALL=C grep -c -e 'AgentsToolsTeamMemberStartCheck "' || : ) $( rigCode AgentsTools.MagicSpawnSession.include | LC_ALL=C grep -c -e 'AgentsToolsTeamMemberStartCheck "' || : ) $( rigCode AgentsTools.ManagerSpawn.include | LC_ALL=C grep -c -e 'reference-only' -e 'SKILL\.md' || : ) $( rigCode AgentsTools.MagicSpawnSession.include | LC_ALL=C grep -c -e 'reference-only' -e 'SKILL\.md' || : )" "1 1 0 0"
rigAssert "--manager-routine-list asks the function that says what such a member is, and reads no SKILL.md itself" \
	"$( rigCode AgentsTools.ManagerRoutine.include | LC_ALL=C grep -c -e 'AgentsToolsTeamMemberReferenceOnly "' || : ) $( rigCode AgentsTools.ManagerRoutine.include | LC_ALL=C grep -c -e 'reference-only' -e 'SKILL\.md' || : )" "1 0"

rigSettle
if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SPAWN REFERENCE ONLY CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_REFERENCE_ONLY: OK (%d assertions, offline)\n' "$rigPasses"
