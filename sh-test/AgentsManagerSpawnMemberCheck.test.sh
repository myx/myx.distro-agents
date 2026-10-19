#!/usr/bin/env bash
## Behavioural check on --manager-spawn-member, the operation of the console's own family --manager-* that starts one
## member with a prompt, run rather than read, against a rig machine built here: a workspace with its own members, a
## second workspace whose members the machine's members index names, a stand-in console that records the brief it is
## given, where it was started and as whom, and a fake `curl` that answers Slack. No real CLI is started. Held: the
## member named gets the prompt as its brief, behind the spawn brief block of the standing default routine, in a new
## coworking session of its own -- the id printed is the session's and the run's own; a prompt with a quote, a `%`, a
## backslash and a first line that starts with `-` arrives byte for byte, from standard input and from a file, and no
## word of it is ever an argument; the name or comment given is on the record, and so is the description; the start
## makes a dispatch item, and prints one `spawn` row and nothing else. Refused, each in one error line, with nothing
## started -- no sandbox, no record, no item, no console: an empty prompt, a name that is no member, a member whose
## SKILL.md says `status: reference-only`, human-owner among them, and that member alone, by that line alone. The
## member is resolved as every operation that names one resolves it where it is dispatched: one set up only in
## another workspace of the machine is started here, on its skillset from there, a reference-only one of that
## workspace is refused by its SKILL.md there, and one the index knows in no known workspace is refused in the
## resolution's own words, by the spawn proxy: the operation brings no member itself. A member started with no session id in the caller's environment outlives its starter: it
## leads a process group of its own, runs to its own end and records its close. The caller rule of the family holds,
## the operation's place in the family is one arm and one include, it starts through the spawn proxy and by no way
## of its own, and its help pair gives the form the row is checked against. Offline; only the rig's own tree is read
## or written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTest="$rigPackage/sh-test"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigOp="--manager-spawn-member"
rigSyntaxWords="<team-member> [--from-stdin|--from-file <path>] [--session-name-or-comment <text>] [--description <text>]"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
## A spawn of this rig that is not waited for starts the control thread of its session, a detached process that
## outlives this check: the rig ends it, before its tree is removed (the guard is in AgentsSessionControlStartCheck).
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerSpawnMemberCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigPassPid=""
trap '[ -z "$rigPassPid" ] || rigProcGroupSignal KILL "$rigPassPid" ; rigProcSignalKept KILL "$rigTmp"/sc/began.* ; chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp" 2> /dev/null || { sleep 3 ; rm -rf -- "$rigTmp" 2> /dev/null ; }' EXIT
rigWs="$rigTmp/ws-here" ; rigThere="$rigTmp/ws-there" ; rigHome="$rigTmp/home" ; rigData="$rigTmp/data" ; rigSc="$rigTmp/sc"
rigSkills="$rigWs/.local/agents/members"
rigThereSkills="$rigThere/.local/agents/members"
mkdir -p "$rigTmp/bin" "$rigSc" "$rigWs/.local/.agents" "$rigSkills" "$rigThere/.local/.agents" "$rigThereSkills" "$rigHome/.agents/magic-team" "$rigData/board"
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

## THE RIG MACHINE. ws-here is the workspace the console is in; ws-there holds two members ws-here does not.
rigMember(){ ## member set root, member, status ("" for no SKILL.md) -- a member's folder with the files a start of it reads
	mkdir -p "$1/$2"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$1/$2/$2.basic.md"
	printf '# rig armed\n' > "$1/$2/$2.armed.md"
	[ -z "$3" ] || printf -- '---\nname: %s\nstatus: %s\ninvocation_mode: auto\n---\n\n# %s\n' "$2" "$3" "$2" > "$1/$2/SKILL.md"
}
rigTeam(){ ## member set root -- the team's own folder there, with the one routine a coworking session names by default
	rigMember "$1" magic-team active
	printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator\ninvitees: magic-team\ndefault-for-session-kind: coworking\nsession: coworking\n---\n# rig coworking routine fixture\n' \
		> "$1/magic-team/magic-team.coworking.routine.md"
}
rigTeam "$rigSkills"
rigMember "$rigSkills" keeper-myx active
rigMember "$rigSkills" magic-coordinator ""
rigMember "$rigSkills" human-owner reference-only
rigMember "$rigSkills" keeper-ref reference-only
rigTeam "$rigThereSkills"
rigMember "$rigThereSkills" keeper-there active
rigMember "$rigThereSkills" keeper-thereref reference-only
{
	printf '%s\t%s\tsource-symlink\t%s\t%s\n' keeper-myx "$rigWs" myx/pkg/skillset/keeper-myx "$rigSkills/keeper-myx"
	printf '%s\t%s\tsource-symlink\t%s\t%s\n' keeper-there "$rigThere" myx/pkg/skillset/keeper-there "$rigThereSkills/keeper-there"
	printf '%s\t%s\tsource-symlink\t%s\t%s\n' keeper-thereref "$rigThere" myx/pkg/skillset/keeper-thereref "$rigThereSkills/keeper-thereref"
	printf '%s\t%s\tsource-symlink\t%s\t%s\n' keeper-lost "$rigTmp/ws-lost" myx/pkg/skillset/keeper-lost "$rigTmp/ws-lost/source/myx/pkg/skillset/keeper-lost"
} > "$rigHome/.agents/magic-team/members.registry"
printf 'ws-here\t%s\nws-there\t%s\n' "$rigWs" "$rigThere" > "$rigHome/.agents/magic-team/directories.registry"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
## The console a start runs. It keeps, under the id of its run: the brief it was given, where it was started, as
## whom and in which session, its own process and process group. It hands back, so no retry follows, and with
## RIG_RUN it stays for that many seconds, or until the file `release`.
rigConsoleWrite(){
	printf '%s\n' '#!/usr/bin/env bash' \
		'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records what it was given.' \
		'cat > "$RIG_SCENARIO/brief.$MDAT_SPAWN_SESSION_ID"' \
		'printf "%s\n" "$MMDAPP" > "$RIG_SCENARIO/where.$MDAT_SPAWN_SESSION_ID"' \
		'printf "%s %s %s\n" "${MDAT_SPAWN_AGENT:-none}" "${MDAT_SESSION_ID:-none}" "${MDAT_SKILLSET_ROOT:-unset}" > "$RIG_SCENARIO/who.$MDAT_SPAWN_SESSION_ID"' \
		'printf "📦 SubagentHandback\n"' \
		'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' \
		'ps -o pgid= -p $$ | tr -d " " > "$RIG_SCENARIO/pgid.$MDAT_SPAWN_SESSION_ID"' \
		'echo $$ > "$RIG_SCENARIO/pid.$MDAT_SPAWN_SESSION_ID"' \
		". '$rigTest/check-fixtures/rig-processes.include.sh' 2> /dev/null && rigProcNoteFile \"\$RIG_SCENARIO/began.\$MDAT_SPAWN_SESSION_ID\" \$\$" \
		'rigLeft="${RIG_RUN:-0}"' \
		'while [ "$rigLeft" -gt 0 ] && [ ! -e "$RIG_SCENARIO/release" ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done' \
		'echo finished > "$RIG_SCENARIO/done.$MDAT_SPAWN_SESSION_ID"' > "$rigWs/DistroAgentsConsole.sh"
	chmod +x "$rigWs/DistroAgentsConsole.sh"
}
rigConsoleWrite

rigPre=()
rigRun(){ ## the file standard input is, tool arguments... -- one dispatcher call from the rig workspace, as a console makes it; rc in rigRc, stdout in out, stderr in err
	local runInput="$1" ; shift
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigSc" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < "$runInput" || rigRc=$?
	rigId="$( LC_ALL=C awk -F'\t' '$1 == "spawn" { print $2 ; exit }' "$rigTmp/out" )"
}
rigErrors(){ ## -- how many lines of the last stderr are an error, but for the one every rig of this package gets
	LC_ALL=C grep -e 'ERROR' -e 'ASSERT' "$rigTmp/err" | LC_ALL=C grep -c -v -F -- 'SystemContext.SetInputSpec' || :
}
rigFirstError(){ ## file -- its first error line, but for that one
	LC_ALL=C grep -e 'ERROR' -e 'ASSERT' "$1" 2> /dev/null | LC_ALL=C grep -v -F -- 'SystemContext.SetInputSpec' | head -1
}
rigWhole(){ ## file, text -- how many lines of the file are that text, whole
	LC_ALL=C grep -c -x -F -- "$2" "$1" 2> /dev/null || :
}
rigMade(){ ## -- what the starts so far have made: sandboxes, run stores, board items, consoles started
	printf '%s %s %s %s\n' "$( ls "$rigWs/.local/agents/spawned" 2> /dev/null | LC_ALL=C grep -c . || : )" "$( ls "$rigWs/.local/agents/sessions" 2> /dev/null | LC_ALL=C grep -c . || : )" \
		"$( find "$rigData/board" -type f 2> /dev/null | LC_ALL=C grep -c . || : )" "$( ls "$rigSc" | LC_ALL=C grep -c '^brief\.' || : )"
}
rigRecord(){ ## run id -- the spawn record of that run
	printf '%s\n' "$rigWs/.local/agents/spawned/$1/$1.md"
}
rigHeader(){ ## run id, header -- that header of the run's record
	LC_ALL=C awk -v wantHeader="$2" '$0 == "---" { if ( ++fm > 1 ) exit ; next } fm == 1 && index( $0, wantHeader ": " ) == 1 { print substr( $0, length( wantHeader ) + 3 ) ; exit }' "$( rigRecord "$1" )" 2> /dev/null
}
rigPromptOf(){ ## brief file -- the prompt in it: what stands between the spawn brief block and the sandbox lines
	LC_ALL=C awk '
		! past && $0 == "When done, hand back; then Wait until dismissed." { past = 1 ; first = 1 ; next }
		past && first { first = 0 ; if ( $0 == "" ) next }
		past && $0 == "## Your sandbox" { exit }
		past { held[++n] = $0 }
		END { if ( n > 0 && held[n] == "" ) n-- ; for ( i = 1 ; i <= n ; i++ ) print held[i] }
	' "$1"
}
rigItemNamed(){ ## item name -- whether it is named as a dispatch item of the spawn proxy
	case "$1" in
		dispatch-*-spawn-proxy-*.md) echo named ;;
		*) echo "not a dispatch item: $1" ;;
	esac
}
rigClosed(){ ## run id -- whether that run recorded its own close
	LC_ALL=C grep -q -x 'status: spawn-succeeded' "$( rigRecord "$1" )" 2> /dev/null
}

printf 'first line of the prompt\nsecond line of it\n' > "$rigTmp/prompt.two"
: > "$rigTmp/prompt.empty"
printf '  \n\t\n\n' > "$rigTmp/prompt.blank"
## A quote of each kind, a %, a backslash, a dollar, a back quote, a tab, and a first line that starts with -.
printf '%s\n' '--routine "is no option here" and -x neither' "100% of it, a \\ and a \\n, 'single', \$HOME and \`tick\`" "a	tab, and a last line with trailing spaces  " > "$rigTmp/prompt.odd"

echo "-- 1. the member gets the prompt, in a session of its own --"
rigMadeBefore="$( rigMade )"
rigRun "$rigTmp/prompt.two" "$rigOp" keeper-myx
rigFirst="$rigId"
rigAssert "the start ends 0 with no error, and prints one line: a spawn row of five fields that names the member" "$rigRc $( rigErrors ) $( LC_ALL=C awk -F'\t' 'END { print NR }' "$rigTmp/out" ) $( LC_ALL=C awk -F'\t' '{ print $1, NF, $3 }' "$rigTmp/out" )" "0 0 1 spawn 5 keeper-myx"
rigWaitFor 30 test -s "$rigSc/done.$rigFirst" || rigRefuse "the stand-in console never ran for the first start: $( rigFirstError "$rigTmp/err" )"
rigAssert "a member started alone from the console has a control thread: the spawner made one start of the thread of its session, which the log of that thread holds" \
	"$( LC_ALL=C grep -c -E -- " a start of the control thread of session $rigFirst is made: pid [0-9]+" "$rigWs/.local/agents/sessions/$rigFirst/control/log" 2> /dev/null )" "1"
rigAssert "the console was started as that member, in the workspace the console is in" "$( LC_ALL=C awk '{ print $1 }' "$rigSc/who.$rigFirst" ) $( cat "$rigSc/where.$rigFirst" )" "keeper-myx $rigWs"
rigAssert "it received the prompt in its brief, both lines, whole and in order" "$( rigPromptOf "$rigSc/brief.$rigFirst" )" "$( cat "$rigTmp/prompt.two" )"
rigAssert "behind the spawn brief block of the standing default routine, which names the member and its duty file" \
	"$( head -1 "$rigSc/brief.$rigFirst" ) $( LC_ALL=C grep -c -x -F 'read-and-obey: read keeper-myx.armed.md and magic-team.coworking.routine.md, through the skillset reader, carefully and in full, before acting, and obey them.' "$rigSc/brief.$rigFirst" )" "SPAWN-PREPARE-BRIEF: keeper-myx 1"
rigAssert "the id printed is the run's own id and its session's: the session is the member's own, and new" \
	"$( LC_ALL=C awk '{ print $2 }' "$rigSc/who.$rigFirst" ) $( rigHeader "$rigFirst" session-id ) $( rigHeader "$rigFirst" spawn-id )" "$rigFirst $rigFirst $rigFirst"
rigAssert "its record names the member as its owner and the routine its session runs, and no session it was started from" \
	"$( rigHeader "$rigFirst" owner ) $( rigHeader "$rigFirst" routine ) $( rigHeader "$rigFirst" parent-spawn-id )" "keeper-myx magic-team.coworking.routine.md none"
rigItem="$( LC_ALL=C awk -F'\t' '{ print $5 }' "$rigTmp/out" )"
rigItemPath="$( find "$rigData/board" -type f -name "$rigItem" 2> /dev/null | head -1 )"
rigAssert "it made a dispatch item, the one the row names, whose brief holds the prompt" \
	"$( rigItemNamed "$rigItem" ) $( [ -n "$rigItemPath" ] && LC_ALL=C grep -c -x -F -e 'first line of the prompt' -e 'second line of it' "$rigItemPath" )" "named 2"
rigAssert "with no name given the row's name is -, and the record keeps no session-comment" "$( LC_ALL=C awk -F'\t' '{ print $4 }' "$rigTmp/out" ) [$( rigHeader "$rigFirst" session-comment )]" "- []"
rigAssert "one sandbox, one run store, one item and one console more than before" "$rigMadeBefore -> $( rigMade )" "0 0 0 0 -> 1 1 1 1"

echo "-- 2. the name given is on the record --"
rigRun "$rigTmp/prompt.two" "$rigOp" keeper-myx --session-name-or-comment "fix the index" --description "the index went stale"
rigNamed="$rigId"
rigAssert "the start ends 0, and its row carries the name as a registry writes it" "$rigRc $( LC_ALL=C awk -F'\t' '{ print $1, NF, $3, $4 }' "$rigTmp/out" )" "0 spawn 5 keeper-myx fix_the_index"
rigAssert "the spawn record of the run holds that text as its session-comment, and the description given" "[$( rigHeader "$rigNamed" session-comment )] [$( rigHeader "$rigNamed" description )]" "[fix the index] [the index went stale]"
rigAssert "it is another session than the first: each start is a session of its own" "$( [ -n "$rigNamed" ] && [ "$rigNamed" != "$rigFirst" ] && echo another ) $( rigHeader "$rigNamed" session-id | LC_ALL=C grep -c -x -F -- "$rigNamed" )" "another 1"
rigWaitFor 30 test -s "$rigSc/done.$rigNamed"

echo "-- 3. a prompt with odd characters arrives unchanged --"
rigRun "$rigTmp/prompt.odd" "$rigOp" keeper-myx
rigOdd="$rigId"
rigWaitFor 30 test -s "$rigSc/done.$rigOdd"
rigPromptOf "$rigSc/brief.$rigOdd" > "$rigTmp/prompt.odd.got" 2> /dev/null
rigAssert "a quote, a %, a backslash, a dollar, a back quote, a tab and a first line that starts with - reach the console byte for byte" "$rigRc $( cmp -s "$rigTmp/prompt.odd" "$rigTmp/prompt.odd.got" && echo same || echo other )" "0 same"
rigAssert "control: the prompt holds each of them" "$( for rigMark in '"' '%' '\' '$HOME' '`' "$rigTab" ; do LC_ALL=C grep -c -F -- "$rigMark" "$rigTmp/prompt.odd" | LC_ALL=C awk '{ printf "%s", ( $1 > 0 ) ? "y" : "n" }' ; done ) $( head -c 1 "$rigTmp/prompt.odd" )" "yyyyyy -"
rigRun /dev/null "$rigOp" keeper-myx --from-file "$rigTmp/prompt.odd"
rigOddFile="$rigId"
rigWaitFor 30 test -s "$rigSc/done.$rigOddFile"
rigPromptOf "$rigSc/brief.$rigOddFile" > "$rigTmp/prompt.odd.got" 2> /dev/null
rigAssert "and from a file, with standard input empty: the same bytes" "$rigRc $( cmp -s "$rigTmp/prompt.odd" "$rigTmp/prompt.odd.got" && echo same || echo other )" "0 same"
rigMadeBefore="$( rigMade )"
rigRun "$rigTmp/prompt.two" "$rigOp" keeper-myx the prompt as words
rigAssert "a prompt is never an argument: words after the member are refused in one line with the syntax, and nothing is started" \
	"$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: syntax is $rigSyntaxWords, got: the" ) $( rigErrors ) [$( rigMade )]" "1 0 1 1 [$rigMadeBefore]"

echo "-- 4. an empty prompt starts nothing --"
rigRun "$rigTmp/prompt.empty" "$rigOp" keeper-myx
rigAssert "standard input empty: rc 1, nothing on stdout, one error line, and no sandbox, no record, no item and no console" \
	"$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: the prompt is empty -- nothing was started" ) $( rigErrors ) [$( rigMade )]" "1 0 1 1 [$rigMadeBefore]"
rigRun "$rigTmp/prompt.blank" "$rigOp" keeper-myx --session-name-or-comment "a name is no prompt"
rigAssert "a prompt of blank lines alone is empty too, whatever else was given" "$rigRc $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: the prompt is empty -- nothing was started" ) [$( rigMade )]" "1 1 [$rigMadeBefore]"
rigRun "$rigTmp/prompt.two" "$rigOp" keeper-myx --from-file "$rigTmp/prompt.empty"
rigAssert "and so is an empty file, with a prompt on standard input that was not asked for" "$rigRc $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: the prompt is empty -- nothing was started" ) [$( rigMade )]" "1 1 [$rigMadeBefore]"

echo "-- 5. a member that is not to be started is refused --"
rigRefusedLine(){ ## member -- how many lines of the last stderr are the plain line that refuses a reference-only member, whole
	rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: $1 is an identity record, and an identity record is never started: its SKILL.md says status: reference-only -- nothing was started"
}
rigRun "$rigTmp/prompt.two" "$rigOp" human-owner
rigAssert "human-owner, whose SKILL.md says status: reference-only: rc 1, nothing on stdout, one error line with the reason, and nothing started" \
	"$( LC_ALL=C grep -c -x 'status: reference-only' "$rigSkills/human-owner/SKILL.md" ) $rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigRefusedLine human-owner ) $( rigErrors ) [$( rigMade )]" "1 1 0 1 1 [$rigMadeBefore]"
rigRun "$rigTmp/prompt.two" "$rigOp" keeper-ref
rigAssert "any member whose SKILL.md says so is refused the same, by that line and not by its name" "$rigRc $( rigRefusedLine keeper-ref ) [$( rigMade )]" "1 1 [$rigMadeBefore]"
rigAssert "the refusal is the one check every start makes, asked here once: the operation reads no SKILL.md itself and writes no line of its own for it (AgentsSpawnReferenceOnlyCheck holds the check)" \
	"$( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/manager/AgentsTools.ManagerSpawn.include" 2> /dev/null | LC_ALL=C grep -c -e 'AgentsToolsTeamMemberStartCheck "' || : ) $( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/manager/AgentsTools.ManagerSpawn.include" 2> /dev/null | LC_ALL=C grep -c -e 'reference-only' -e 'SKILL\.md' -e 'identity record' || : )" "1 0"
printf -- '---\nname: keeper-ref\nstatus: active\n---\n\n# keeper-ref\n' > "$rigSkills/keeper-ref/SKILL.md"
rigRun "$rigTmp/prompt.two" "$rigOp" keeper-ref
rigAssert "control: the same member with status: active is started" "$rigRc $( LC_ALL=C awk -F'\t' '{ print $1, $3 }' "$rigTmp/out" )" "0 spawn keeper-ref"
[ -z "$rigId" ] || rigWaitFor 30 test -s "$rigSc/done.$rigId"
rigRun "$rigTmp/prompt.two" "$rigOp" magic-coordinator
rigAssert "and so is a member with no SKILL.md at all: nothing says it is not to be started" "$( [ -e "$rigSkills/magic-coordinator/SKILL.md" ] && echo has-skill-file || echo no-skill-file ) $rigRc $( LC_ALL=C awk -F'\t' '{ print $1, $3 }' "$rigTmp/out" )" "no-skill-file 0 spawn magic-coordinator"
[ -z "$rigId" ] || rigWaitFor 30 test -s "$rigSc/done.$rigId"

echo "-- 6. a name that is no member is refused --"
rigMadeBefore="$( rigMade )"
rigRun "$rigTmp/prompt.two" "$rigOp" keeper-nowhere
rigAssert "a name no workspace of the machine holds: rc 1, nothing on stdout, one error line, nothing started" \
	"$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: no such team member: keeper-nowhere -- nothing was started" ) $( rigErrors ) [$( rigMade )]" "1 0 1 1 [$rigMadeBefore]"
rigRun "$rigTmp/prompt.two" "$rigOp" ../keeper-myx
rigAssert "a name that is no bare name never reaches a path: refused in one line" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( LC_ALL=C grep -c -F -- "DistroAgentsTools: ${rigOp#--}: ❗ ASSERT: <team-member> must be a bare name" "$rigTmp/err" || : ) $( rigErrors ) [$( rigMade )]" "1 0 1 1 [$rigMadeBefore]"
rigRun "$rigTmp/prompt.two" "$rigOp"
rigAssert "no member at all: one line with the syntax" "$rigRc $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: syntax is $rigSyntaxWords, got: no member" ) $( rigErrors ) [$( rigMade )]" "1 1 1 [$rigMadeBefore]"

echo "-- 7. the member is resolved as every operation that names one resolves it --"
rigRun "$rigTmp/prompt.two" "$rigOp" keeper-there
rigInvited="$rigId"
rigAssert "a member set up only in another workspace of the machine is started: rc 0, its row names it" "$rigRc $( rigErrors ) $( LC_ALL=C awk -F'\t' '{ print $1, NF, $3 }' "$rigTmp/out" )" "0 0 spawn 5 keeper-there"
rigWaitFor 30 test -s "$rigSc/done.$rigInvited" || rigRefuse "the stand-in console never ran for the invited member: $( rigFirstError "$rigTmp/err" )"
rigAssert "by the console of the workspace it was asked from, as that member, on the member set of the workspace it is set up in" \
	"$( cat "$rigSc/where.$rigInvited" ) $( LC_ALL=C awk '{ print $1, $3 }' "$rigSc/who.$rigInvited" )" "$rigWs keeper-there $rigThereSkills"
rigAssert "its record is in the workspace it was asked from, and names the member's own" "$( [ -f "$( rigRecord "$rigInvited" )" ] && echo here ) $( ls "$rigThere/.local/agents" | LC_ALL=C grep -c -x spawned || : ) $( rigHeader "$rigInvited" member-workspace )" "here 0 ws-there"
rigAssert "it received the prompt, behind a brief block that names it" "$( head -1 "$rigSc/brief.$rigInvited" ) | $( rigPromptOf "$rigSc/brief.$rigInvited" | head -1 )" "SPAWN-PREPARE-BRIEF: keeper-there | first line of the prompt"
rigMadeBefore="$( rigMade )"
rigRun "$rigTmp/prompt.two" "$rigOp" keeper-thereref
rigAssert "a reference-only member of that workspace is refused by its SKILL.md, read where it is set up, and nothing is started" \
	"$( [ -e "$rigSkills/keeper-thereref" ] && echo here || echo not-here ) $rigRc $( rigRefusedLine keeper-thereref ) $( rigErrors ) [$( rigMade )]" "not-here 1 1 1 [$rigMadeBefore]"
rigRun "$rigTmp/prompt.two" "$rigOp" keeper-lost
rigAssert "a member the machine's index knows in no workspace the machine knows is refused by the spawn proxy, in the words of the one resolution, and nothing is started" \
	"$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( LC_ALL=C grep -c -F -- "⛔ ERROR: DistroAgentsTools --intern-op-agent-spawn-proxy: member 'keeper-lost' is in the team members index but is present in no tracked workspace -- nothing was done." "$rigTmp/err" || : ) $( rigErrors ) [$( rigMade )]" "1 0 1 1 [$rigMadeBefore]"
rigAssert "the operation brings no member itself, a rule AgentsMemberWorkspaceCheck holds for the whole package: the bring is not named in its include at all, and it resolves no workspace" \
	"$( LC_ALL=C grep -c -e 'AgentsToolsMemberSkillsetBring "' "$rigHere/manager/AgentsTools.ManagerSpawn.include" 2> /dev/null || : ) $( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/manager/AgentsTools.ManagerSpawn.include" 2> /dev/null | LC_ALL=C grep -c -e 'AgentsToolsMemberSkillsetBring' -e 'AgentsToolsMemberWorkspaceResolve' -e 'AgentsToolsMemberInvited' -e 'members\.registry' || : )" "0 0"
rigAssert "it finds a member read only, by the two functions of the machine's directory of members, once each: the folder of one, and whether a name is in it" \
	"$( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/manager/AgentsTools.ManagerSpawn.include" 2> /dev/null | LC_ALL=C grep -c -e 'AgentsToolsTeamMemberDirectory "' || : ) $( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/manager/AgentsTools.ManagerSpawn.include" 2> /dev/null | LC_ALL=C grep -c -e 'AgentsToolsTeamMemberDirectoryText ' || : ) $( cat "$rigHere"/*/*.include | LC_ALL=C grep -c -E '^AgentsToolsTeamMemberDirectory(Text)?\(\)\{' || : )" "1 1 2"

echo "-- 8. a failed start says so, and prints no row --"
chmod -x "$rigWs/DistroAgentsConsole.sh"
rigRun "$rigTmp/prompt.two" "$rigOp" keeper-myx
chmod +x "$rigWs/DistroAgentsConsole.sh"
rigAssert "the console of the workspace cannot be run: rc 1, nothing on stdout, the one error line of the start, and nothing left behind" \
	"$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( LC_ALL=C grep -c -F -- "⛔ ERROR: DistroAgentsConsole.sh is not executable at $rigWs" "$rigTmp/err" || : ) $( rigErrors ) [$( rigMade )]" "1 0 1 1 [$rigMadeBefore]"

echo "-- 9. the options --"
rigRun "$rigTmp/prompt.two" "$rigOp" keeper-myx --wait
rigAssert "an option it does not take is refused in one line with the syntax: a start never waits" "$rigRc $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: syntax is $rigSyntaxWords, got: --wait" ) $( rigErrors ) [$( rigMade )]" "1 1 1 [$rigMadeBefore]"
rigRun "$rigTmp/prompt.two" "$rigOp" keeper-myx --from-file "$rigTmp/no-such-file"
rigAssert "a file that is not there is refused by name" "$rigRc $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: --from-file: file not found: $rigTmp/no-such-file" ) $( rigErrors ) [$( rigMade )]" "1 1 1 [$rigMadeBefore]"
rigRun "$rigTmp/prompt.two" "$rigOp" keeper-myx --from-stdin --from-file "$rigTmp/prompt.two"
rigAssert "standard input and a file together are refused: the prompt has one source" "$rigRc $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: use only one of --from-stdin | --from-file <path>" ) $( rigErrors ) [$( rigMade )]" "1 1 1 [$rigMadeBefore]"
rigRun "$rigTmp/prompt.two" "$rigOp" keeper-myx --session-name-or-comment
rigAssert "an option with no value is refused by name" "$rigRc $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: --session-name-or-comment requires <text>" ) $( rigErrors ) [$( rigMade )]" "1 1 1 [$rigMadeBefore]"
rigRun "$rigTmp/prompt.two" "$rigOp" keeper-myx --from-stdin
rigAssert "--from-stdin says what the default is: the prompt is standard input" "$rigRc $( LC_ALL=C awk -F'\t' '{ print $1, $3 }' "$rigTmp/out" )" "0 spawn keeper-myx"
[ -z "$rigId" ] || rigWaitFor 30 test -s "$rigSc/done.$rigId"

echo "-- 10. the caller rule, and the place in the family --"
rigMadeBefore="$( rigMade )"
rigPre=( "MDAT_SPAWN_AGENT=magic-coordinator" )
rigRun "$rigTmp/prompt.two" "$rigOp" keeper-myx
rigPre=()
rigAssert "from inside a member's session it is refused, rc 1, nothing on stdout, in the one line of the family's rule, and nothing is started" \
	"$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "DistroAgentsTools: ${rigOp#--}: ⛔ ERROR: this session acts as magic-coordinator, and a --manager-* operation is the console's own, never run from inside a member's session -- nothing was done" ) [$( rigMade )]" "1 0 1 [$rigMadeBefore]"
rigRun /dev/null --manager-spawn-no-such
rigAssert "an operation its subject does not have is refused by name, rc 1" "$rigRc $( rigWhole "$rigTmp/err" "DistroAgentsTools: ⛔ ERROR: invalid option: --manager-spawn-no-such" )" "1 1"
rigAssert "the family has one arm for the starts, which sources their include, and that include asks nobody who calls" \
	"$( LC_ALL=C grep -c -x -e '	--manager-spawn-\*)' "$rigHere/manager/AgentsTools.Manager.include" || : ) $( LC_ALL=C grep -c -F -e '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsTools.ManagerSpawn.include"' "$rigHere/manager/AgentsTools.Manager.include" || : ) $( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/manager/AgentsTools.ManagerSpawn.include" 2> /dev/null | LC_ALL=C grep -c -e 'AgentsToolsManagerCallerCheck' -e 'AgentsToolsActingMember' || : )" "1 1 0"
rigAssert "it starts through the spawn proxy, in one call, and by no way of its own: it names no console and starts no process itself" \
	"$( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/manager/AgentsTools.ManagerSpawn.include" 2> /dev/null | LC_ALL=C grep -c -e 'DistroAgentsTools --intern-op-agent-spawn-proxy ' || : ) $( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/manager/AgentsTools.ManagerSpawn.include" 2> /dev/null | LC_ALL=C grep -c -e 'DistroAgentsConsole' -e 'uuidgen' -e '[)] *&$' || : )" "1 0"

echo "-- 11. a member started from a bare console outlives its starter --"
rm -f "$rigSc/release"
ls "$rigSc" | LC_ALL=C grep '^pid\.' | LC_ALL=C sort > "$rigTmp/pids.before"
set -m
( cd "$rigWs" && exec env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigSc" RIG_RUN=90 \
	bash -c 'bash "$1" "$2" keeper-myx --session-name-or-comment "outlives its starter" < "$3" > "$4/pass.out" 2> "$4/pass.err" ; exec sleep 120' rig-console "$rigTool" "$rigOp" "$rigTmp/prompt.two" "$rigTmp" ) &
rigPassPid=$!
rigPassGroup="$rigPassPid"
set +m
rigProcNote "$rigPassPid"
rigPassStarted(){ [ -s "$rigTmp/pass.out" ] && [ -s "$rigSc/pid.$( LC_ALL=C awk -F'\t' '$1 == "spawn" { print $2 ; exit }' "$rigTmp/pass.out" )" ] ; }
rigWaitFor 40 rigPassStarted || rigRefuse "the stand-in console never started for the start from a bare console: $( rigFirstError "$rigTmp/pass.err" )"
rigLone="$( LC_ALL=C awk -F'\t' '$1 == "spawn" { print $2 ; exit }' "$rigTmp/pass.out" )"
rigLoneAlive(){ kill -0 "$( cat "$rigSc/pid.$rigLone" 2> /dev/null || echo 999999 )" 2> /dev/null && printf alive || printf gone ; }
rigAssert "the caller had no session id in its environment, and was returned to at once: its row is there while the member runs" "$( LC_ALL=C awk -F'\t' '{ print $1, $3, $4 }' "$rigTmp/pass.out" ) $( rigLoneAlive ) $( rigHeader "$rigLone" parent-spawn-id )" "spawn keeper-myx outlives_its_starter alive none"
rigOwnGroup="$( ps -o pgid= -p $$ | tr -d ' ' )"
rigLoneGroup="$( cat "$rigSc/pgid.$rigLone" 2> /dev/null || printf none )"
rigAssert "the member's run is in a process group of its own, not its starter's and not this check's" \
	"$( [ "$rigLoneGroup" != none ] && [ "$rigLoneGroup" != "$rigPassGroup" ] && [ "$rigLoneGroup" != "$rigOwnGroup" ] && printf own || printf 'group %s, its starter is group %s' "$rigLoneGroup" "$rigPassGroup" )" own
{ rigProcGroupSignal TERM "$rigPassPid" ; sleep 2 ; rigProcGroupSignal KILL "$rigPassPid" ; wait "$rigPassPid" ; } 2> /dev/null
rigAssert "the process group of its caller is ended, and the member's run goes on" "$( kill -0 "$rigPassPid" 2> /dev/null && printf alive || printf gone ) $( rigLoneAlive )" "gone alive"
rigPassPid=""
: > "$rigSc/release"
rigWaitFor 20 test -s "$rigSc/done.$rigLone"
rigAssert "it runs to its own end" "$( cat "$rigSc/done.$rigLone" 2> /dev/null )" finished
rigWaitFor 60 rigClosed "$rigLone"
rigAssert "and records its own close after its starter ended" "$( rigClosed "$rigLone" && printf yes || printf no )" yes

echo "-- 12. the help pair --"
rigHelpInclude="$rigHere/help/Help.DistroAgentsTools.include"
rigHelpMd="$rigHere/help/Help.DistroAgentsTools.help.md"
rigSyntax="📘 syntax: DistroAgentsTools.fn.sh $rigOp $rigSyntaxWords"
rigEntry(){ ## -- the operation's entry in the help.md, from under its heading to the next operation's
	LC_ALL=C awk -v head="$( printf '\t\t%s %s' "$rigOp" "$rigSyntaxWords" )" '$0 == head { on = 1 ; next } on && /^\t\t--/ { exit } on { print }' "$rigHelpMd"
}
rigAssert "the operation has its syntax echo, its syntax line and its entry, once each, and in no other form" "$( LC_ALL=C grep -c -x -F -- "echo \"$rigSyntax\" >&2" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -x -F -- "$rigSyntax" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -x -F -- "$( printf '\t\t%s %s' "$rigOp" "$rigSyntaxWords" )" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -F -- "syntax: DistroAgentsTools.fn.sh $rigOp" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -F -- "syntax: DistroAgentsTools.fn.sh $rigOp" "$rigHelpMd" || : )" "1 1 1 1 1"
rigForm="$( rigEntry | LC_ALL=C sed -n -e 's/^[[:space:]]*`\(spawn <.*>\)`$/\1/p' )"
rigAssert "its entry gives the form of the row" "$rigForm" "spawn <session-id> <member> <name> <dispatch-item>"
rigAssert "and the row a start printed has exactly the fields that form names" "$( LC_ALL=C awk -F'\t' -v wantFields="$( printf '%s\n' "$rigForm" | LC_ALL=C awk '{ print NF }' )" '{ rows++ ; if ( NF != wantFields ) bad++ ; } END { printf "%s:%s", ( rows > 0 ? "rows" : "none" ), bad + 0 }' "$rigTmp/pass.out" )" "rows:0"
rigAssert "the entry names the status that refuses a member, the member it gives as one, and the operation whose brief block the member gets" "$( for rigWord in 'status: reference-only' human-owner '--magic-spawn-session --routine-default' ; do rigEntry | LC_ALL=C grep -c -F -- "\`$rigWord\`" | LC_ALL=C awk '{ printf "%s", ( $1 > 0 ) ? "y" : "n" }' ; done )" "yyy"
rigAssert "control: the entry was cut up to the next operation's heading, and holds its own text" "$( rigEntry | LC_ALL=C grep -c -F -- 'TAB-separated' || : ) $( rigEntry | LC_ALL=C awk 'END { print ( NR > 0 && NR < 60 ) ? "cut" : "not cut: " NR " lines" }' )" "1 cut"
rigRun /dev/null --help-syntax
rigAssert "--help-syntax prints its line, once" "$rigRc $( LC_ALL=C grep -c -x -F -- "$rigSyntax" "$rigTmp/err" || : )" "0 1"

echo "-- 13. nothing but the rig's own Slack was asked --"
rigAssert "every request of this check went to the fake curl, and each was a Slack method" "$( [ -s "$rigSc/calls" ] && echo asked ) $( LC_ALL=C awk '$1 == "" { bad++ } END { print bad + 0 }' "$rigSc/calls" 2> /dev/null )" "asked 0"

## The runs started here close their records apart from this check: waited for, so none writes into a tree that is gone.
rigLeft=90
while LC_ALL=C grep -l -x 'status: spawn-started' "$rigWs"/.local/agents/spawned/*/*.md > /dev/null 2>&1 && [ "$rigLeft" -gt 0 ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MANAGER SPAWN MEMBER CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SPAWN_MEMBER: OK (%d assertions, offline)\n' "$rigPasses"
