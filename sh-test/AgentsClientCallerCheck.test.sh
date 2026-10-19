#!/usr/bin/env bash
## Behavioural check on who runs a --client-* operation, run rather than read, against a fixture machine built
## here in the form of AgentsClientSettingsFallbackCheck: one HOME, ws-here where everything is run from and which
## holds client-ndm's settings of all six systems, ws-there where client-ndm is set up. ONE RULE FOR THE WHOLE
## FAMILY -- Slack, mail, Google, Trello, Jira, Confluence and the sweep: a --client-* operation runs for the
## client-* member it names, in that member's own session, and for nobody else. magic-coordinator is no exception:
## its session is refused like any other, in one plain line that names the operation that is its own,
## --magic-client-operation-run; any other member's line says to ask magic-coordinator. That operation takes its
## caller's own name first, as every --magic-* operation does, then word for word the command line the client
## itself gives: the --client-* operation, the client member's name, that operation's arguments. It forwards
## them unchanged and the operation runs as that client: the same side, the same settings, the same calls,
## output and exit status as the client's own call, stdin handed on. It is a --magic-* operation, so it is
## magic-coordinator's alone by the rule of its prefix, and it refuses a caller named that is not
## magic-coordinator, an operation that is no --client-* one, a member name that does not start with client-
## and a member that does not exist, each in one plain line. A --magic-comms-* operation given a client is our own side, as for any other member: where
## our side holds nothing of a system for the client it says the line of the client's own --member-* operation,
## naming --magic-client-operation-run. A call from no session is the console's, and passes, as it does every
## check of who may call. The rule is asked in one place, where a --client-* operation is dispatched, and in no
## stub. Offline: the fake `curl` and `python3` of AgentsClientSystemsCheck, first on PATH, log each call with
## whose settings it carried. What the stubs cannot show: a real answer of any system.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
rigRealPython="$( command -v python3 )" || rigRefuse "no python3 on PATH to hand every other script to"
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsClientCallerCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## A loop in the code under test must end the check rather than hang it: nothing here legitimately runs long.
rigProcNote $$
( sleep 900 ; rigProcSignal TERM $$ ) > /dev/null 2>&1 &
rigDog=$! ; rigProcNote "$rigDog"
trap 'rigProcSignalWithChildren TERM "$rigDog" ; wait "$rigDog" 2> /dev/null ; chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWork="$rigTmp/work" ; rigHome="$rigTmp/home"
rigIndexFile="$rigHome/.agents/magic-team/members.registry"
rigListFile="$rigHome/.agents/magic-team/known-workspaces.registry"
mkdir -p "$rigTmp/bin"
for rigFake in curl python3 ; do
	cp "$rigTest/check-fixtures/client-systems-check.$rigFake.stub.sh" "$rigTmp/bin/$rigFake" \
		|| rigRefuse "the fake $rigFake fixture is missing from the package: $rigTest/check-fixtures/client-systems-check.$rigFake.stub.sh"
	chmod +x "$rigTmp/bin/$rigFake"
done
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] && [ "$( command -v python3 )" = "$rigTmp/bin/python3" ] \
	|| rigRefuse "the fake curl and python3 are not first on PATH, so this check would issue real requests"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

rigMemberFiles(){ ## directory, member, where -- a member directory with the files a help or an operation reads
	mkdir -p "$1"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$1/$2.basic.md"
	printf '# rig armed\n' > "$1/$2.armed.md"
	printf -- '---\nname: %s\n---\n\n# %s, set up in %s\n' "$2" "$2" "$3" > "$1/SKILL.md"
}
rigView(){ ## workspace -- its member set view, which holds its own members only
	printf '%s\n' "$rigWork/$1/.local/agents/members"
}
rigMemberAt(){ ## workspace, member -- that member set up in that workspace, linked into its view, and on the machine's index
	local atHome="$rigWork/$1/source/myx/pkg/skillset/$2"
	rigMemberFiles "$atHome" "$2" "$1"
	mkdir -p "$( rigView "$1" )"
	ln -sfn "$atHome" "$( rigView "$1" )/$2"
	printf '%s\t%s\tsource-symlink\tmyx/pkg/skillset/%s\t%s\n' "$2" "$rigWork/$1" "$2" "$atHome" >> "$rigIndexFile"
}
rigSettings(){ ## whose, system... -- the settings of those systems, each value named after whose it is
	local setWhose="$1" setLow setSystem ; shift
	setLow="$( printf '%s' "$setWhose" | LC_ALL=C tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz' )"
	for setSystem in "$@" ; do
		case "$setSystem" in
			SLACK) printf '%s\n' "SLACK_USER_TOKEN=rig-user-token-$setWhose" "SLACK_WORKSPACE_DOMAIN=$setLow.slack.invalid" 'SLACK_CONVERSATIONS=CNDM00001' ;;
			SLACKTEAM) printf '%s\n' "SLACK_BOT_TOKEN=rig-bot-token-$setWhose" "SLACK_WORKSPACE_DOMAIN=$setLow.slack.invalid" 'SLACK_CHANNEL_MAGIC_TEAM=CTEAM0001' 'SLACK_CHANNEL_HUMAN_OWNER=UTEAMOWNER' 'SLACK_CHANNEL_EVENT_TRACK=CTEAMTRCK' 'SLACK_CHANNEL_EVENT_ALERT=CTEAMALRT' ;;
			EMAIL) printf '%s\n' "EMAIL_IMAP_HOST=imap-$setLow.invalid" "EMAIL_SMTP_HOST=smtp-$setLow.invalid" 'EMAIL_SMTP_PORT=587' "EMAIL_USER=us@$setLow.invalid" "EMAIL_APP_PASSWORD=rig-mail-secret-$setWhose" ;;
			TRELLO) printf '%s\n' "TRELLO_KEY=rig-trello-key-$setWhose" "TRELLO_TOKEN=rig-trello-secret-$setWhose" ;;
			GOOGLE) printf '%s\n' "GOOGLE_CLIENT_ID=rig-google-client-$setWhose" "GOOGLE_CLIENT_SECRET=rig-google-secret-$setWhose" "GOOGLE_REFRESH_TOKEN=rig-google-refresh-$setWhose" ;;
			JIRA) printf '%s\n' "JIRA_SITE=jira-$setLow.invalid" "JIRA_USER=us@$setLow.invalid" "JIRA_API_TOKEN=rig-jira-secret-$setWhose" ;;
			CONFLUENCE) printf '%s\n' "CONFLUENCE_SITE=confluence-$setLow.invalid" "CONFLUENCE_USER=us@$setLow.invalid" "CONFLUENCE_API_TOKEN=rig-confluence-secret-$setWhose" ;;
		esac
	done
}
rigScopeOf(){ ## workspace, member -- that member's scope file in that workspace, its lines on stdin
	mkdir -p "$rigWork/$1/.local/.agents"
	cat > "$rigWork/$1/.local/.agents/$2.agent.env"
}
rigWorld(){ ## -- a fresh machine: this workspace holds the client's settings of all six systems
	rm -rf "$rigWork" "$rigHome"
	mkdir -p "${rigIndexFile%/*}" ; : > "$rigIndexFile"
	local wsName memberName
	for wsName in ws-here ws-there ; do mkdir -p "$rigWork/$wsName/.local/.agents" "$rigWork/$wsName/.local/agents/members" ; done
	for memberName in magic-team human-owner magic-coordinator keeper-here client-mel ; do rigMemberAt ws-here "$memberName" ; done
	for memberName in magic-team client-ndm keeper-there ; do rigMemberAt ws-there "$memberName" ; done
	printf '%s\n' "$rigWork/ws-here" "$rigWork/ws-there" > "$rigListFile"
	rigSettings TEAMHERE SLACKTEAM EMAIL TRELLO GOOGLE JIRA CONFLUENCE | rigScopeOf ws-here magic-team
	rigSettings TEAMTHERE SLACKTEAM EMAIL TRELLO GOOGLE JIRA CONFLUENCE | rigScopeOf ws-there magic-team
	rigSettings NDMTHERE SLACK EMAIL TRELLO GOOGLE JIRA CONFLUENCE | rigScopeOf ws-there client-ndm
	## a member that is no client, set up in the other workspace too: the fallback is any invited member's
	rigSettings KTHERE SLACK | rigScopeOf ws-there keeper-there
	rigSettings NDMHERE SLACK EMAIL TRELLO GOOGLE JIRA CONFLUENCE | rigScopeOf ws-here client-ndm
	rigClean
}
rigClean(){ ## -- the logs of the calls made so far, emptied
	: > "$rigTmp/calls" ; : > "$rigTmp/envs"
}
rigPre=()
rigStdin=/dev/null
rigRun(){ ## args... -- one dispatcher call from ws-here, its stdin from rigStdin; stdout in out, stderr in err, rc in rigRc
	rigClean
	rigRc=0
	( cd "$rigWork/ws-here" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/ws-here" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_REAL_PYTHON3="$rigRealPython" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < "$rigStdin" || rigRc=$?
}
rigN(){ ## file, fixed text -- how many lines hold it
	LC_ALL=C grep -c -F -- "$2" "$1" 2> /dev/null || :
}
rigLines(){ ## file -- how many lines it has
	LC_ALL=C awk 'END { print NR + 0 }' "$1" 2> /dev/null
}
rigCalls(){ ## -- the calls of the last run, in their order, joined by "; "
	LC_ALL=C awk '{ printf "%s%s", ( NR > 1 ? "; " : "" ), $0 }' "$rigTmp/calls"
}
rigFrom(){ ## whose -- how many calls of the last run carried a setting of that owner
	LC_ALL=C grep -c -i -F -- "$1" "$rigTmp/calls" || :
}

rigErrors(){ ## -- how many lines of the last run are an error or a warning
	LC_ALL=C grep -c -e '⛔' -e '🙋' "$rigTmp/err" || :
}
rigWhole(){ ## file, text -- how many lines of the file are that text, whole
	LC_ALL=C grep -c -x -F -- "$2" "$1" 2> /dev/null || :
}
## The rule in its own words, as every refused session is told it.
rigOwnOnly="a --client-* operation in the name of client-ndm is for client-ndm's own session only -- nothing was done"
rigRefusedLine(){ ## operation with no leading --, the member the session acts as -- how many lines of the last run are the one plain line of the rule, whole: the rule, then whom to ask
	rigWhole "$rigTmp/err" "DistroAgentsTools: $1: ⛔ ERROR: this session acts as $2, and $rigOwnOnly: ask the session's magic-coordinator, which can run it as client-ndm"
}
rigPointedLine(){ ## operation with no leading -- -- how many lines of the last run are the line magic-coordinator's session is told, whole: the rule, then the operation that is its own
	rigWhole "$rigTmp/err" "DistroAgentsTools: $1: ⛔ ERROR: this session acts as magic-coordinator, and $rigOwnOnly: magic-coordinator runs it with --magic-client-operation-run magic-coordinator --$1 client-ndm"
}
rigMagicOnlyLine(){ ## the member the session acts as -- how many lines of the last run are the refusal every --magic-* operation gives that session, whole
	rigWhole "$rigTmp/err" "DistroAgentsTools: magic-client-operation-run: ⛔ ERROR: this session acts as $1, and magic-client-operation-run is magic-coordinator's only -- nothing was done"
}
rigKeep(){ ## label -- the last run kept under that label: its exit status, what it printed on each stream, and its calls
	printf '%s\n' "$rigRc" > "$rigTmp/kept.$1.rc"
	cp "$rigTmp/out" "$rigTmp/kept.$1.out" ; cp "$rigTmp/err" "$rigTmp/kept.$1.err" ; cp "$rigTmp/calls" "$rigTmp/kept.$1.calls"
}
rigSame(){ ## label, label -- `same` where the two runs kept under them ended, printed and called alike, else the first part in which they differ
	local samePart
	for samePart in rc out err calls ; do
		cmp -s "$rigTmp/kept.$1.$samePart" "$rigTmp/kept.$2.$samePart" || { printf 'different-%s' "$samePart" ; return 0 ; }
	done
	printf same
}
## One --client-* operation of each family of stubs: <the family in a word>|<operation and arguments>
rigOps=(
	'Slack|--client-comms-slack-read client-ndm CNDM00001'
	'mail|--client-comms-email-check client-ndm'
	'Google|--client-comms-google-whoami client-ndm'
	'Trello|--client-comms-trello-whoami client-ndm'
	'Jira|--client-comms-jira-board-list client-ndm'
	'Confluence|--client-comms-confluence-space-list client-ndm'
	'the sweep|--client-sweep-config-check client-ndm'
)
## The rest of each family: the operations that write, the presence and the socket, the sweep itself.
rigRest=(
	'--client-comms-slack-send-message client-ndm CNDM00001 RIG-BODY'
	'--client-comms-slack-presence-status client-ndm'
	'--client-comms-slack-socket-status client-ndm'
	'--client-comms-email-send client-ndm person@ndm.invalid -- Subject -- Body.'
	'--client-comms-google-doc-write client-ndm RIGDOC0001 Text.'
	'--client-comms-trello-read client-ndm 5f0000000000000000000a01'
	'--client-comms-trello-post-comment client-ndm 5f0000000000000000000c01 Rig-comment.'
	'--client-comms-jira-issue-delete client-ndm RIG-1'
	'--client-comms-confluence-page-delete client-ndm 12345'
	'--client-sweep-input-scan client-ndm'
)
rigAllowed(){ ## who is calling, in words -- every family's operation from the session rigPre says: it runs, and reaches the other organisation with the client's own settings
	local allowedOp allowedCmd
	for allowedOp in "${rigOps[@]}" ; do
		allowedCmd="${allowedOp#*|}"
		rigRun $allowedCmd
		rigAssert "${allowedOp%%|*}: ${allowedCmd%% *} called by $1 runs, with the settings the client holds" "$rigRc $( [ "$( rigFrom NDMHERE )" -gt 0 ] && printf reached || printf no-call ) $( rigN "$rigTmp/err" 'this session acts as' )" "0 reached 0"
	done
}
rigRefused(){ ## the member the session rigPre says acts as -- every family's operation from that session: refused in the one line, and no call
	local refusedOp refusedCmd refusedName
	for refusedOp in "${rigOps[@]}" ; do
		refusedCmd="${refusedOp#*|}" ; refusedName="${refusedCmd%% *}"
		rigRun $refusedCmd
		rigAssert "${refusedOp%%|*}: $refusedName called by a session of $1 is refused in one plain line, and nothing is called" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigErrors ) $( rigRefusedLine "${refusedName#--}" "$1" )" "1 0 1 1"
	done
}
rigPointed(){ ## -- every family's operation from magic-coordinator's session: refused in the one line that names its own operation, and no call
	local pointedOp pointedCmd pointedName
	for pointedOp in "${rigOps[@]}" ; do
		pointedCmd="${pointedOp#*|}" ; pointedName="${pointedCmd%% *}"
		rigRun $pointedCmd
		rigAssert "${pointedOp%%|*}: $pointedName called by magic-coordinator's session is refused in one plain line that names --magic-client-operation-run, and nothing is called" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigErrors ) $( rigPointedLine "${pointedName#--}" )" "1 0 1 1"
	done
}
rigThrough(){ ## who is calling, in words -- every family's operation through --magic-client-operation-run from the session rigPre says: it reaches the other organisation with the client's own settings, and ends, prints and calls exactly as the client's own call of it does
	local throughOp throughCmd throughName throughPre=( ${rigPre[@]+"${rigPre[@]}"} )
	for throughOp in "${rigOps[@]}" ; do
		throughCmd="${throughOp#*|}" ; throughName="${throughCmd%% *}"
		rigPre=( MDAT_SPAWN_AGENT=client-ndm )
		rigRun $throughCmd
		rigKeep own
		rigPre=( ${throughPre[@]+"${throughPre[@]}"} )
		rigRun --magic-client-operation-run magic-coordinator $throughCmd
		rigKeep through
		rigAssert "${throughOp%%|*}: $throughName through --magic-client-operation-run, called by $1, reaches the other organisation with the settings the client holds, exactly as the client's own call does" "$rigRc $( [ "$( rigFrom NDMHERE )" -gt 0 ] && printf reached || printf no-call ) $( rigSame own through )" "0 reached same"
	done
}
rigThroughRefused(){ ## the member the session rigPre says acts as -- every family's operation through --magic-client-operation-run from that session: refused as every --magic-* operation is to it, and no call
	local refusedOp refusedCmd refusedName
	for refusedOp in "${rigOps[@]}" ; do
		refusedCmd="${refusedOp#*|}" ; refusedName="${refusedCmd%% *}"
		rigRun --magic-client-operation-run magic-coordinator $refusedCmd
		rigAssert "${refusedOp%%|*}: --magic-client-operation-run of $refusedName called by a session of $1 is refused, as every --magic-* operation is to it, and nothing is called" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigErrors ) $( rigMagicOnlyLine "$1" )" "1 0 1 1"
	done
}

rigWorld
rigRun --agents-config-option client-ndm --select TRELLO_KEY
[ "$rigRc" = 0 ] && [ "$( cat "$rigTmp/out" )" = "rig-trello-key-NDMHERE" ] || rigRefuse "the baseline read of the client's setting did not answer from the workspace everything is run from, so no row below would be measured: rc=$rigRc [$( cat "$rigTmp/out" )] $( LC_ALL=C grep -m1 -E 'ERROR|WARNING' "$rigTmp/err" )"

echo "-- 1. the client's own session runs a --client-* operation in its own name --"
rigPre=( MDAT_SPAWN_AGENT=client-ndm )
rigAllowed "the client's own session"

echo "-- 2. magic-coordinator is no exception: its session is refused, in one plain line that names the operation that is its own --"
rigPre=( MDAT_SPAWN_AGENT=magic-coordinator )
rigPointed

echo "-- 3. nobody else runs it: a session acting as another member of ours is refused in one plain line, and nothing is called --"
rigPre=( MDAT_SPAWN_AGENT=keeper-here )
rigRefused keeper-here

echo "-- 4. nor another client: one client's session does not act in another client's name --"
rigPre=( MDAT_SPAWN_AGENT=client-mel )
rigRefused client-mel

echo "-- 5. the rest of each family is under the same rule: the operations that write, the presence and the socket, the sweep itself --"
for rigOp in "${rigRest[@]}" ; do
	rigName="${rigOp%% *}"
	rigPre=( MDAT_SPAWN_AGENT=keeper-here )
	rigRun $rigOp
	rigAssert "$rigName called by a session of keeper-here is refused in the one line, and nothing is called or written" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigErrors ) $( rigRefusedLine "${rigName#--}" keeper-here )" "1 0 1 1"
	rigPre=( MDAT_SPAWN_AGENT=magic-coordinator )
	rigRun $rigOp
	rigAssert "$rigName called by magic-coordinator's session is refused in the line that names its own operation, and nothing is called or written" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigErrors ) $( rigPointedLine "${rigName#--}" )" "1 0 1 1"
done

echo "-- 6. magic-coordinator's own way: --magic-client-operation-run runs the --client-* operation as that client --"
rigPre=( MDAT_SPAWN_AGENT=magic-coordinator )
rigThrough "magic-coordinator's session"
printf '%s\n' '{"type":"doc","version":1,"content":[{"type":"paragraph","content":[{"type":"text","text":"Rig comment."}]}]}' > "$rigTmp/adf"
rigStdin="$rigTmp/adf"
rigPre=( MDAT_SPAWN_AGENT=client-ndm )
rigRun --client-comms-jira-comment-add client-ndm RIG-1 --body-adf-from-stdin
rigKeep own
rigPre=( MDAT_SPAWN_AGENT=magic-coordinator )
rigRun --magic-client-operation-run magic-coordinator --client-comms-jira-comment-add client-ndm RIG-1 --body-adf-from-stdin
rigKeep through
rigAssert "what is given on stdin reaches the operation: a comment whose body is read from stdin is added in the client's Jira, as in the client's own call" "$rigRc $( rigCalls ) $( rigSame own through )" "0 http jira-ndmhere.invalid us@ndmhere.invalid same"
rigStdin=/dev/null
rigRun --magic-client-operation-run magic-coordinator --client-comms-jira-comment-add client-ndm RIG-1 --body-adf-from-stdin
rigAssert "control: with nothing on stdin the same call adds nothing" "$( [ "$rigRc" -ne 0 ] && printf refused || printf done ) $( rigLines "$rigTmp/calls" )" "refused 0"
rigPre=( MDAT_SPAWN_AGENT=client-mel )
rigRun --client-comms-jira-board-list client-mel
rigKeep own
rigPre=( MDAT_SPAWN_AGENT=magic-coordinator )
rigRun --magic-client-operation-run magic-coordinator --client-comms-jira-board-list client-mel
rigKeep through
rigAssert "the operation's own refusal and its own exit status come back unchanged: a client that holds no Jira settings" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigN "$rigTmp/err" 'JIRA_SITE' ) $( rigSame own through )" "6 0 1 same"
rigPre=( MDAT_SPAWN_AGENT=client-ndm )
rigRun --client-comms-trello-post-comment client-ndm 5f0000000000000000000c01 Rig-comment.
rigKeep own
rigPre=( MDAT_SPAWN_AGENT=magic-coordinator )
rigRun --magic-client-operation-run magic-coordinator --client-comms-trello-post-comment client-ndm 5f0000000000000000000c01 Rig-comment.
rigKeep through
rigAssert "the Trello comment: through --magic-client-operation-run it is posted on the other organisation's card under the account the client holds, exactly as the client's own call posts it" "$rigRc $( rigCalls ) $( rigSame own through )" "0 trello cards/5f0000000000000000000c01/actions/comments rig-trello-key-NDMHERE same"
rigPre=()
rigRun --magic-client-operation-run magic-coordinator --client-comms-trello-whoami client-ndm
rigAssert "the console, a call from no session, passes, as it does every check of who may call" "$rigRc $( rigCalls )" "0 trello members/me rig-trello-key-NDMHERE"

echo "-- 7. that operation is magic-coordinator's alone, by the rule of its prefix: another member's session is refused --"
rigPre=( MDAT_SPAWN_AGENT=keeper-here )
rigThroughRefused keeper-here
rigPre=( MDAT_SPAWN_AGENT=client-ndm )
rigRun --magic-client-operation-run magic-coordinator --client-comms-trello-whoami client-ndm
rigAssert "the client's own session is refused too: its own way is the --client-* operation itself" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigErrors ) $( rigMagicOnlyLine client-ndm )" "1 0 1 1"

echo "-- 8. what the operation refuses itself, each in one plain line --"
rigPre=( MDAT_SPAWN_AGENT=magic-coordinator )
for rigOp in '--member-comms-slack-read client-ndm magic-team' '--magic-sweep-input-scan client-ndm' '--intern-op-slack-call client-ndm --api auth.test' '--agents-config-option client-ndm --select TRELLO_KEY' 'client-comms-trello-whoami client-ndm' '--client- client-ndm' ; do
	rigName="${rigOp%% *}"
	rigRun --magic-client-operation-run magic-coordinator $rigOp
	rigAssert "an operation that is no --client-* one is refused, and nothing is run: $rigName" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigErrors ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --magic-client-operation-run: runs a --client-* operation, and $rigName is not one -- nothing was done" ) $( rigLines "$rigTmp/out" )" "1 0 1 1 0"
done
rigRun --magic-client-operation-run keeper-here --client-comms-jira-board-list client-ndm
rigAssert "the member named first is the caller, as in every --magic-* operation: a name that is not magic-coordinator is refused, and nothing is run" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigErrors ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --magic-client-operation-run: runs only as magic-coordinator, and keeper-here is not it -- its syntax is <magic-coordinator> --client-<operation> <client-member-name> [<argument>...]" )" "1 0 1 1"
rigRun --magic-client-operation-run --client-comms-trello-whoami client-ndm
rigAssert "the client's command line with no caller named before it gives the syntax, and nothing is run" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigErrors ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --magic-client-operation-run: syntax is <magic-coordinator> --client-<operation> <client-member-name> [<argument>...]" )" "1 0 1 1"
rigRun --magic-client-operation-run magic-coordinator --client-comms-jira-board-list keeper-here
rigAssert "a member name that does not start with client- is refused, and nothing is run" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigErrors ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --magic-client-operation-run: runs a --client-* operation as a client-* member, and keeper-here is not one -- nothing was done" )" "1 0 1 1"
rigRun --magic-client-operation-run magic-coordinator --client-comms-jira-board-list client-nobody
rigAssert "a client member that does not exist, here or in any workspace of this machine, is refused, and nothing is run" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigErrors ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --magic-client-operation-run: no such member: client-nobody is set up neither in $rigWork/ws-here nor in another workspace of this machine -- nothing was done" )" "1 0 1 1"
rigRun --magic-client-operation-run magic-coordinator --client-comms-jira-board-list client-mel
rigAssert "control: a client set up in the workspace everything is run from exists, as the invited one does: its operation is reached, and answers for itself" "$rigRc $( rigN "$rigTmp/err" 'JIRA_SITE' ) $( rigN "$rigTmp/err" 'no such member' )" "6 1 0"
rigRun --magic-client-operation-run magic-coordinator --client-comms-trello-whoami
rigAssert "with no client named it gives its syntax, and nothing is run" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigErrors ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --magic-client-operation-run: syntax is <magic-coordinator> --client-<operation> <client-member-name> [<argument>...]" )" "1 0 1 1"

echo "-- 9. a --magic-comms-* operation given a client is our own side, as for any other member --"
rigPre=( MDAT_SPAWN_AGENT=magic-coordinator )
rigRun --magic-comms-slack-read client-ndm CTEAM0001
rigAssert "its Slack read in the client's name is in our own team's Slack, under the team's bot: nothing the client holds is used" "$rigRc $( rigCalls ) $( rigFrom NDMHERE )" "0 slack conversations.history rig-bot-token-TEAMHERE 0"
rigSideLine="client-ndm has no mail settings on our own organisation's side: what it holds is the other organisation's. For the other organisation use"
rigRun --magic-comms-email-mark-seen client-ndm 41
rigAssert "mail, where our side holds nothing for a client: the one plain line of the client's own --member-* operation, and it names --magic-client-operation-run with the --client-* operation; no call" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigErrors ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --member-comms-email-mark-seen: $rigSideLine --magic-client-operation-run magic-coordinator --client-comms-email-mark-seen client-ndm." )" "1 0 1 1"
rigRun --magic-comms-email-send client-ndm person@ndm.invalid -- Subject -- Body.
rigAssert "the same for a mail it would send: the line, and nothing is sent" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigErrors ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --member-comms-email-send: $rigSideLine --magic-client-operation-run magic-coordinator --client-comms-email-send client-ndm." )" "1 0 1 1"
rigRun --magic-comms-trello-post-comment client-ndm 5f0000000000000000000c01 Rig-comment.
rigAssert "Trello, where our side holds nothing for a client either: the same line for the comment, naming --magic-client-operation-run with its --client-* operation, and nothing is posted" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigErrors ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --magic-comms-trello-post-comment: client-ndm has no Trello settings on our own organisation's side: what it holds is the other organisation's. For the other organisation use --magic-client-operation-run magic-coordinator --client-comms-trello-post-comment client-ndm." )" "1 0 1 1"
rigRun --magic-client-operation-run magic-coordinator --client-comms-email-mark-seen client-ndm 41
rigAssert "and what the line names does mark the message in the mailbox the client holds" "$rigRc $( LC_ALL=C awk '{ print $1, $2, $3, $4, $5 }' "$rigTmp/calls" )" "0 imap imap-ndmhere.invalid us@ndmhere.invalid UID STORE"
rigPre=( MDAT_SPAWN_AGENT=client-ndm )
rigRun --member-comms-email-mark-seen client-ndm 41
rigAssert "control: the client's own --member-* operation says that line as it did, naming the --client-* operation that is its own" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --member-comms-email-mark-seen: $rigSideLine --client-comms-email-mark-seen." )" "1 0 1"

echo "-- 10. what the rule leaves as it was --"
rigPre=()
rigAllowed "the console, a call from no session"
rigPre=( MDAT_SPAWN_AGENT=keeper-here )
rigRun --client-comms-jira-board-list keeper-here
rigAssert "a name that is no client's is refused by the operation itself, as before: the family runs only as a client-* member" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigN "$rigTmp/err" '--client-comms-jira-board-list: runs only as a client-* member, and keeper-here is not one' ) $( rigN "$rigTmp/err" 'this session acts as' )" "1 0 1 0"
rigPre=( MDAT_SPAWN_AGENT=magic-coordinator )
rigRun --member-comms-slack-read client-ndm magic-team
rigAssert "a --member-* operation is not opened by this rule: magic-coordinator's session still cannot act as the client through it" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigN "$rigTmp/err" 'this session acts as magic-coordinator, so it cannot act as client-ndm -- nothing was done' )" "1 0 1"
rigPre=()

echo "-- 11. help: the operation is magic-coordinator's, and no --client-* entry names a caller but the client --"
rigRun --member-help magic-coordinator
rigAssert "magic-coordinator's help offers the operation: its syntax line, and its entry in the manual" "$rigRc $( cat "$rigTmp/out" "$rigTmp/err" | LC_ALL=C grep -c -F -e 'DistroAgentsTools.fn.sh --magic-client-operation-run <magic-coordinator> --client-<operation> <client-member-name> [<argument>...]' ) $( LC_ALL=C grep -c -e '^		--magic-client-operation-run <magic-coordinator> --client-<operation> <client-member-name> \[<argument>\.\.\.\]$' "$rigHere/help/Help.DistroAgentsTools.help.md" )" "0 1 1"
rigRun --member-help client-ndm
rigAssert "a client's help does not offer it" "$rigRc $( cat "$rigTmp/out" "$rigTmp/err" | LC_ALL=C grep -c -F -e '--magic-client-operation-run' )" "0 0"
rigAssert "no help text says magic-coordinator calls a --client-* operation, in the client's name or otherwise" "$( cat "$rigHere"/help/Help.DistroAgentsTools.help.md "$rigHere"/help/Help.DistroAgentsTools.include | LC_ALL=C grep -c -e 'magic-coordinator in its' -e 'by magic-coordinator' -e "in the client's name" )" 0
rigAssert "control: the manual does say who a --client-* operation is called by" "$( LC_ALL=C grep -c -e "member's own session; any other session" -e 'own session; any other' "$rigHere/help/Help.DistroAgentsTools.help.md" | LC_ALL=C awk '{ print ( $1 >= 1 ) ? "said" : "silent" }' )" said

echo "-- 12. static: the rule is asked in one place, and the new operation has no check of its own --"
rigAssert "where a --client-* operation is dispatched, once, and defined once" "$( LC_ALL=C grep -c -F -e '--client-*) AgentsToolsClientCallerCheck "${2:-}" "${1#--}" || { set +e ; return 1 ; } ;;' "$rigTool" || : ) $( cat "$rigHere"/*.include "$rigHere"/*.sh | LC_ALL=C grep -c -E '^[[:space:]]*AgentsToolsClientCallerCheck\(\)\{' || : )" "1 1"
rigAssert "and in no stub: no --client-* arm of the package carries a check of its own on who calls" "$( for rigFile in "$rigHere"/AgentsTools.*.include ; do LC_ALL=C awk '/^[[:space:]]*--client-[a-z|*-]*\)/ { on = 1 } on && /^[[:space:]]*--(member|intern|magic)-[a-z|*-]*\)/ { on = 0 } on && /AgentsToolsActingMemberCheck|AgentsToolsMagicCallerCheck/ { n++ } END { if ( n ) print FILENAME ": " n }' "$rigFile" ; done | LC_ALL=C sed 's|.*/||' | LC_ALL=C tr '\n' ' ' )" ""
rigAssert "control: the same search does find the arms of the client stubs" "$( for rigFile in "$rigHere"/AgentsTools.*.include ; do LC_ALL=C grep -c -E '^[[:space:]]*--client-[a-z|*-]*\)' "$rigFile" || : ; done | LC_ALL=C awk '{ n += $1 } END { print ( n >= 25 ) ? "found" : "blind " n }' )" found
rigAssert "the rule passes the named client's own session and the console, and no other member by name" "$( LC_ALL=C grep -c -F -e "case \"\$checkActing\" in ''|\"\$1\") return 0 ;; esac" "$rigHere/AgentsTools.CallerCheck.include" || : ) $( LC_ALL=C grep -c -F -e '|magic-coordinator) return 0' "$rigHere/AgentsTools.CallerCheck.include" || : )" "1 0"
rigAssert "--magic-client-operation-run asks nothing of its own about who calls: it is a --magic-* operation, asked where those are dispatched, once" "$( LC_ALL=C grep -c -E 'AgentsTools(ActingMember|MagicCaller|ClientCaller)Check[^A-Za-z]*\"' "$rigHere/AgentsTools.MagicClient.include" || : ) $( LC_ALL=C grep -c -F -e '--magic-*) AgentsToolsMagicCallerCheck "${1#--}" || { set +e ; return 1 ; } ;;' "$rigTool" || : )" "0 1"
rigAssert "no --magic-comms-* operation takes the client side from the member it is given: the family says our own side itself, once" "$( LC_ALL=C grep -c -F -e 'local -x MDAT_COMMS_SIDE=client' "$rigHere/AgentsTools.MagicComms.include" || : ) $( LC_ALL=C grep -c -F -e '--magic-comms-*) local -x MDAT_COMMS_SIDE=own MDAT_COMMS_OP="$1" ;;' "$rigHere/AgentsTools.MagicComms.include" || : )" "0 1"
if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ CLIENT CALLER CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'CLIENT_CALLER: OK (%d assertions, offline)\n' "$rigPasses"
