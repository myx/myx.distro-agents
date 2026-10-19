#!/usr/bin/env bash
## Behavioural check on which organisation an operation of a client-* member reaches in the systems other than Slack
## -- mail, Trello, Google, Jira and Confluence -- run rather than read, against a fixture machine built here in the
## form of AgentsClientSidesCheck: one HOME, ws-here where everything is run from, ws-there where client-ndm is set
## up. The rule held is that check's, for every system: THE PREFIX CHOOSES THE ORGANISATION, NEVER A CREDENTIAL. A
## --member-* operation of a client-* member, and an operation with no marker, are our own organisation's side. What
## such a member holds for a system is the other organisation's, so on our side it holds none: the operation says so
## in one plain line that names the --client-* operation of the same name, and no call is made. A --client-*
## operation reaches the other organisation with what the client itself holds, and with no fallback: not the team's
## settings and not another member's. The coordinator acting as a client and a
## client's own sweep stay on the client side, as they were. Offline: a fake `curl` and a fake `python3` first on
## PATH log each call with whose settings it carried, and nothing else in the package opens a connection for these
## systems. What the stubs cannot show: a real answer of any of the five systems, of either organisation.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigSideInclude="$rigHere/AgentsTools.CommsSide.include"
rigHelpInclude="$rigHere/help/Help.DistroAgentsTools.include"
rigManual="$rigHere/help/Help.DistroAgentsTools.help.md"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigSideInclude" ] || rigRefuse "the include that says the side is not at: $rigSideInclude"
rigRealPython="$( command -v python3 )" || rigRefuse "no python3 on PATH to hand every other script to"
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsClientSystemsCheck )" || exit 1
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

## ---- the fixture machine ----
## Every setting says whose it is. NDM is what client-ndm holds for the other organisation, in the workspace
## everything is run from. KHERE is a member of our own team, TEAM our team's shared scope: a client's operation must
## never fall back to either. Everything ending THERE is the other workspace's, and must never be seen in a call.
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
rigSystems(){ ## whose, mail domain -- the settings of all five systems, each named after whose they are
	printf '%s\n' \
		"EMAIL_IMAP_HOST=imap-$2" "EMAIL_SMTP_HOST=smtp-$2" 'EMAIL_SMTP_PORT=587' "EMAIL_USER=us@$2" "EMAIL_APP_PASSWORD=rig-mail-secret-$1" \
		"TRELLO_KEY=rig-trello-key-$1" "TRELLO_TOKEN=rig-trello-secret-$1" \
		"GOOGLE_CLIENT_ID=rig-google-client-$1" "GOOGLE_CLIENT_SECRET=rig-google-secret-$1" "GOOGLE_REFRESH_TOKEN=rig-google-refresh-$1" \
		"JIRA_SITE=jira-$2" "JIRA_USER=us@$2" "JIRA_API_TOKEN=rig-jira-secret-$1" \
		"CONFLUENCE_SITE=confluence-$2" "CONFLUENCE_USER=us@$2" "CONFLUENCE_API_TOKEN=rig-confluence-secret-$1"
}
rigScopeOf(){ ## workspace, member -- that member's scope file in that workspace, its lines on stdin
	mkdir -p "$rigWork/$1/.local/.agents"
	cat > "$rigWork/$1/.local/.agents/$2.agent.env"
}
rigWorld(){ ## -- a fresh machine
	rm -rf "$rigWork" "$rigHome"
	mkdir -p "${rigIndexFile%/*}" ; : > "$rigIndexFile"
	local wsName memberName
	for wsName in ws-here ws-there ; do mkdir -p "$rigWork/$wsName/.local/.agents" "$rigWork/$wsName/.local/agents/members" ; done
	for memberName in magic-team human-owner magic-coordinator keeper-here keeper-none client-mel ; do rigMemberAt ws-here "$memberName" ; done
	for memberName in magic-team client-ndm ; do rigMemberAt ws-there "$memberName" ; done
	printf '%s\n' "$rigWork/ws-here" "$rigWork/ws-there" > "$rigListFile"
	rigSystems TEAM team.here.invalid | rigScopeOf ws-here magic-team
	rigSystems KHERE keeper.here.invalid | rigScopeOf ws-here keeper-here
	rigSystems NDM ndm.invalid | rigScopeOf ws-here client-ndm
	## client-mel and keeper-none hold nothing of their own for any of the five systems
	: | rigScopeOf ws-here client-mel
	: | rigScopeOf ws-here keeper-none
	rigSystems TEAMTHERE team.THERE.invalid | rigScopeOf ws-there magic-team
	rigSystems NDMTHERE ndm.THERE.invalid | rigScopeOf ws-there client-ndm
	## the client's own contacts: a mail into the other organisation passes the outbound contact gate
	## (AgentsToolsContactAssertKnown) only for a listed recipient
	mkdir -p "$rigWork/ws-here/.local/agents/team-data-root/inboxes/client-ndm"
	printf '%s\n' \
		'| slack-id | contact | handle | email | organisation | permission level |' \
		'| --- | --- | --- | --- | --- | --- |' \
		'| UNDMPERSON | rig-ndm-person | @rig-ndm-person | person@ndm.invalid | rig | unset |' \
		> "$rigWork/ws-here/.local/agents/team-data-root/inboxes/client-ndm/note-rig-contacts.md"
	rigClean
}
rigClean(){ ## -- the logs of the calls made so far, emptied
	: > "$rigTmp/calls" ; : > "$rigTmp/envs"
}

## ---- running ----
## No member set root is given to a call: each reads its own workspace's view, as a session started there does. rigPre
## adds to a call's environment, the member a spawned session acts as among them.
rigPre=()
rigRun(){ ## args... -- one dispatcher call from ws-here; stdout in out, stderr in err, rc in rigRc
	rigClean
	rigRc=0
	( cd "$rigWork/ws-here" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/ws-here" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_REAL_PYTHON3="$rigRealPython" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
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
rigOurs(){ ## -- how many calls of the last run carried a setting of our own team: a member's or the shared scope's
	LC_ALL=C grep -c -E 'here\.invalid|KHERE|TEAM' "$rigTmp/calls" || :
}
rigElsewhere(){ ## -- how many calls of the last run carried anything of the other workspace
	LC_ALL=C grep -c 'THERE' "$rigTmp/calls" || :
}
rigSideLine(){ ## the --member-* operation that was run, the system in a word -- how many lines of the last run are the one plain line: no settings on our side, and the --client-* operation of the same name
	rigN "$rigTmp/err" "$1: client-ndm has no $2 settings on our own organisation's side: what it holds is the other organisation's. For the other organisation use --client-${1#--member-}."
}
rigOwnSide(){ ## the system in a word, the status wanted, a --member-* operation of client-ndm and its arguments... -- that operation is our own side: the one line, and no call
	local sideWord="$1" sideRc="$2" ; shift 2
	rigRun "$@"
	rigAssert "$1 of a client says in one line that it holds no $sideWord settings on our side, names --client-${1#--member-}, and makes no call" "$rigRc $( rigSideLine "$1" "$sideWord" ) $( rigLines "$rigTmp/calls" )" "$sideRc 1 0"
}
rigNames(){ ## file, family -- the --client-comms-<family>-<operation> names that file holds, sorted, one per line
	LC_ALL=C grep -o -E -e "--client-comms-$2-[a-z-]*[a-z]" "$1" | LC_ALL=C sort -u
}

rigWorld
rigRun --agents-config-option keeper-here --select TRELLO_KEY
[ "$rigRc" = 0 ] && [ "$( cat "$rigTmp/out" )" = "rig-trello-key-KHERE" ] || rigRefuse "the baseline config select did not answer from the workspace everything is run from, so no row below would be measured: rc=$rigRc $( LC_ALL=C grep -m1 -E 'ERROR|WARNING' "$rigTmp/err" )"
rigRun --member-comms-trello-whoami keeper-here
[ "$rigRc" = 0 ] && [ "$( rigCalls )" = "trello members/me rig-trello-key-KHERE" ] || rigRefuse "the baseline Trello lookup of a member set up here reached no call under its own key, so no row below would be measured: rc=$rigRc $( rigCalls ) $( LC_ALL=C grep -m1 ERROR "$rigTmp/err" )"
[ -d "$( rigView ws-there )/client-ndm" ] && [ ! -e "$( rigView ws-here )/client-ndm" ] || rigRefuse "the fixture does not hold client-ndm in the other workspace's view only, so no row below would show an invited client"

echo "-- 1. a --member-* operation of a client is our own organisation's side, where it holds no settings: one plain line, no call --"
rigOwnSide mail 1 --member-comms-email-check client-ndm
rigOwnSide mail 1 --member-comms-email-read client-ndm 41
rigOwnSide mail 1 --member-comms-email-mark-seen client-ndm 41
rigOwnSide mail 1 --member-comms-email-send client-ndm person@ndm.invalid -- 'Rig subject' -- 'Rig body.'
rigOwnSide Trello 1 --member-comms-trello-check client-ndm
rigOwnSide Trello 1 --member-comms-trello-read client-ndm 5f0000000000000000000a01
rigOwnSide Trello 1 --member-comms-trello-whoami client-ndm
rigOwnSide Google 1 --member-comms-google-whoami client-ndm
rigOwnSide Google 1 --member-comms-google-doc-read client-ndm RIGDOC0001
rigOwnSide Google 1 --member-comms-google-sheet-read client-ndm RIGSHEET01 A1:B2
rigOwnSide Jira 6 --member-comms-jira-board-list client-ndm
rigAssert "in Jira and Confluence it is the designed refusal of a member with no settings: the warning mark and its own status" "$( rigN "$rigTmp/err" '🙋 WARNING' ) $( rigN "$rigTmp/err" '⛔ ERROR' )" "1 0"
rigOwnSide Jira 6 --member-comms-jira-issue-read client-ndm RIG-1
rigOwnSide Confluence 6 --member-comms-confluence-space-list client-ndm
rigOwnSide Confluence 6 --member-comms-confluence-page-read client-ndm 12345
rigPre=( MDAT_COMMS_SIDE=client 'MDAT_COMMS_OP=--client-comms-email-check' )
rigOwnSide mail 1 --member-comms-email-check client-ndm
rigOwnSide Jira 6 --member-comms-jira-board-list client-ndm
rigPre=()
rigRun --intern-op-comms-email-check client-ndm
rigAssert "an operation with no marker is our own side too: the same line, and no call" "$rigRc $( rigSideLine --member-comms-email-check mail ) $( rigLines "$rigTmp/calls" )" "1 1 0"

echo "-- 2. the --client-* operation of the same name reaches the other organisation, with what the client itself holds --"
rigRun --client-comms-email-check client-ndm
rigAssert "its mailbox check is the mailbox the client holds, in the workspace it was called from" "$rigRc $( rigCalls ) $( LC_ALL=C awk '{ print $2 ; exit }' "$rigTmp/envs" )" "0 imap imap-ndm.invalid us@ndm.invalid STATUS INBOX (UNSEEN); imap imap-ndm.invalid us@ndm.invalid UID SEARCH UNSEEN MMDAPP=$rigWork/ws-here"
rigAssert "no call carried a setting of our own team, and none anything of the other workspace" "$( rigOurs ) $( rigElsewhere )" "0 0"
rigRun --client-comms-email-read client-ndm 41
rigAssert "its read of one message is of that mailbox" "$rigRc $( rigCalls ) $( rigN "$rigTmp/out" 'RIG MESSAGE' )" "0 imap-read imap-ndm.invalid us@ndm.invalid 41 1"
rigRun --client-comms-email-mark-seen client-ndm 41
rigAssert "its mark of one message is in that mailbox" "$rigRc $( LC_ALL=C awk '{ print $1, $2, $3, $4, $5 }' "$rigTmp/calls" )" "0 imap imap-ndm.invalid us@ndm.invalid UID STORE"
rigRun --client-comms-email-send client-ndm person@ndm.invalid -- 'Rig subject' -- 'Rig body.'
rigAssert "its mail to a listed contact of its own is sent from that mailbox" "$rigRc $( rigCalls )" "0 smtp smtp-ndm.invalid us@ndm.invalid person@ndm.invalid"
rigRun --client-comms-email-send client-ndm stranger@ndm.invalid -- 'Rig subject' -- 'Rig body.'
rigAssert "control: the gates of a mail hold on this side as on ours -- a recipient the client has not listed is refused, and nothing is sent" "$( [ "$rigRc" != 0 ] && printf refused || printf sent ) $( rigLines "$rigTmp/calls" )" "refused 0"
rigRun --client-comms-trello-check client-ndm
rigAssert "its Trello check is the account the client holds" "$rigRc $( rigCalls )" "0 trello members/me/notifications rig-trello-key-NDM"
rigRun --client-comms-trello-whoami client-ndm
rigAssert "its Trello lookup answers as that account" "$rigRc $( rigCalls ) $( rigN "$rigTmp/out" 'TRELLO_USERNAME=rig-NDM' )" "0 trello members/me rig-trello-key-NDM 1"
rigRun --client-comms-trello-read client-ndm 5f0000000000000000000a01
rigAssert "its read of one notification is under that account" "$rigRc $( rigCalls )" "0 trello notifications/5f0000000000000000000a01 rig-trello-key-NDM"
rigRun --client-comms-google-whoami client-ndm
rigAssert "its Google lookup is the account the client holds" "$rigRc $( rigCalls )" "0 google whoami rig-google-client-NDM"
rigRun --client-comms-google-doc-read client-ndm RIGDOC0001
rigAssert "its read of a document is under that account" "$rigRc $( rigCalls )" "0 google doc-read rig-google-client-NDM"
rigRun --client-comms-jira-board-list client-ndm
rigAssert "the Jira stub stays: the site and the user the client holds" "$rigRc $( rigCalls )" "0 http jira-ndm.invalid us@ndm.invalid"
rigRun --client-comms-confluence-space-list client-ndm
rigAssert "the Confluence stub stays: the site and the user the client holds" "$rigRc $( rigCalls )" "0 http confluence-ndm.invalid us@ndm.invalid"
rigAssert "across this whole section no call carried a setting of our own team or of the other workspace" "$( rigOurs ) $( rigElsewhere )" "0 0"

echo "-- 3. no fallback: a client that holds nothing for a system is told so by name, and no call is made --"
rigRun --client-comms-email-check client-mel
rigAssert "mail: the client's own scope is named as not set, and neither the team's mailbox nor another member's is read" "$rigRc $( rigN "$rigTmp/err" "EMAIL_IMAP_HOST/EMAIL_USER/EMAIL_APP_PASSWORD not fully set in client-mel's own scope" ) $( rigLines "$rigTmp/calls" )" "1 1 0"
rigRun --client-comms-trello-whoami client-mel
rigAssert "Trello: the same" "$rigRc $( rigN "$rigTmp/err" "TRELLO_KEY/TRELLO_TOKEN not fully set in client-mel's own scope" ) $( rigLines "$rigTmp/calls" )" "1 1 0"
rigRun --client-comms-google-whoami client-mel
rigAssert "Google: the same" "$rigRc $( rigN "$rigTmp/err" "GOOGLE_CLIENT_ID/GOOGLE_CLIENT_SECRET/GOOGLE_REFRESH_TOKEN not fully set in client-mel's own scope" ) $( rigLines "$rigTmp/calls" )" "1 1 0"
rigRun --client-comms-jira-board-list client-mel
rigAssert "Jira: the same, as its designed refusal" "$rigRc $( rigN "$rigTmp/err" 'JIRA_SITE' ) $( rigLines "$rigTmp/calls" )" "6 1 0"

echo "-- 4. who a --client-* operation of these systems is for --"
for rigOp in --client-comms-email-check --client-comms-trello-whoami --client-comms-google-whoami ; do
	rigRun "$rigOp" keeper-here
	rigAssert "$rigOp runs only as a client-* member: a member of our own team is refused, and its own settings are not used" "$rigRc $( rigN "$rigTmp/err" "$rigOp: runs only as a client-* member, and keeper-here is not one" ) $( rigLines "$rigTmp/calls" )" "1 1 0"
done
rigPre=( MDAT_SPAWN_AGENT=client-mel MDAT_SPAWN_SESSION_ID=rig-session-client )
for rigOp in --client-comms-email-check --client-comms-trello-whoami --client-comms-google-whoami ; do
	rigRun "$rigOp" client-ndm
	rigAssert "$rigOp from a session of another client is refused: a --client-* operation is the named client's own session's alone" "$rigRc $( rigN "$rigTmp/err" "this session acts as client-mel, and a --client-* operation in the name of client-ndm is for client-ndm's own session only -- nothing was done: ask the session's magic-coordinator, which can run it as client-ndm" ) $( rigLines "$rigTmp/calls" )" "1 1 0"
done
rigPre=()
for rigOp in --client-comms-email-bogus --client-comms-trello-bogus --client-comms-google-bogus ; do
	rigRun "$rigOp" client-ndm
	rigAssert "$rigOp is no operation: refused by name, and no call" "$( [ "$rigRc" != 0 ] && printf refused || printf ran ) $( rigN "$rigTmp/err" "$rigOp" ) $( rigLines "$rigTmp/calls" )" "refused 1 0"
done

echo "-- 5. control: a member of our own team is as it was --"
rigRun --member-comms-email-check keeper-here
rigAssert "its mailbox check is its own mailbox" "$rigRc $( LC_ALL=C awk 'NR == 1 { print $1, $2, $3 }' "$rigTmp/calls" ) $( rigLines "$rigTmp/calls" )" "0 imap imap-keeper.here.invalid us@keeper.here.invalid 2"
rigRun --member-comms-google-whoami keeper-here
rigAssert "its Google lookup is its own account" "$rigRc $( rigCalls )" "0 google whoami rig-google-client-KHERE"
rigRun --member-comms-jira-board-list keeper-here
rigAssert "its Jira listing is its own site" "$rigRc $( rigCalls )" "0 http jira-keeper.here.invalid us@keeper.here.invalid"
rigRun --member-comms-confluence-space-list keeper-here
rigAssert "its Confluence listing is its own site" "$rigRc $( rigCalls )" "0 http confluence-keeper.here.invalid us@keeper.here.invalid"
rigRun --member-comms-email-check keeper-none
rigAssert "a member of ours with no mailbox is told its own scope is not set, as before, and not the line of a client" "$rigRc $( rigN "$rigTmp/err" "not fully set in keeper-none's own scope" ) $( rigN "$rigTmp/err" 'on our own organisation' ) $( rigLines "$rigTmp/calls" )" "1 1 0 0"
rigRun --member-comms-jira-board-list keeper-none
rigAssert "and in Jira it is the designed refusal that names the missing settings, as before" "$rigRc $( rigN "$rigTmp/err" 'JIRA_SITE' ) $( rigN "$rigTmp/err" 'on our own organisation' ) $( rigLines "$rigTmp/calls" )" "6 1 0 0"

echo "-- 6. magic-coordinator reaches the client side through --magic-client-operation-run; a --magic-comms-* operation given a client is our own side --"
rigRun --magic-client-operation-run magic-coordinator --client-comms-email-mark-seen client-ndm 41
rigAssert "its mark of a message as client-ndm, through its own operation, is in the mailbox the client holds" "$rigRc $( LC_ALL=C awk '{ print $1, $2, $3, $4, $5 }' "$rigTmp/calls" )" "0 imap imap-ndm.invalid us@ndm.invalid UID STORE"
rigRun --magic-comms-email-mark-seen client-ndm 41
rigAssert "the --magic-comms- mark given a client is our own side, where a client holds no mail settings: the one line, naming --magic-client-operation-run, and no call" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --member-comms-email-mark-seen: client-ndm has no mail settings on our own organisation's side: what it holds is the other organisation's. For the other organisation use --magic-client-operation-run magic-coordinator --client-comms-email-mark-seen client-ndm." )" "1 0 1"
rigRun --magic-comms-email-mark-seen keeper-here 41
rigAssert "control: as a member of our own team it is that member's mailbox" "$rigRc $( LC_ALL=C awk '{ print $1, $2, $3 }' "$rigTmp/calls" )" "0 imap imap-keeper.here.invalid us@keeper.here.invalid"
rigRun --magic-client-operation-run magic-coordinator --client-comms-trello-post-comment client-ndm 5f0000000000000000000c01 'Rig comment.'
rigAssert "its Trello comment as client-ndm, through its own operation, is under the account the client holds" "$rigRc $( rigCalls )" "0 trello cards/5f0000000000000000000c01/actions/comments rig-trello-key-NDM"
rigRun --magic-comms-trello-post-comment client-ndm 5f0000000000000000000c01 'Rig comment.'
rigAssert "the --magic-comms- comment given a client is our own side, where a client holds no Trello settings: the one line, naming --magic-client-operation-run, and no call" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --magic-comms-trello-post-comment: client-ndm has no Trello settings on our own organisation's side: what it holds is the other organisation's. For the other organisation use --magic-client-operation-run magic-coordinator --client-comms-trello-post-comment client-ndm." )" "1 0 1"
rigRun --magic-comms-trello-post-comment keeper-here 5f0000000000000000000c01 'Rig comment.'
rigAssert "control: as a member of our own team it is posted under that member's own account, as before" "$rigRc $( rigCalls )" "0 trello cards/5f0000000000000000000c01/actions/comments rig-trello-key-KHERE"

echo "-- 7. a client's own sweep reads what the client holds, and a scan with no marker reads none of it --"
rigRun --client-sweep-input-scan client-ndm
rigAssert "the client's own sweep reads the mailbox and the Trello account the client holds" "$( rigCalls )" "imap-sweep imap-ndm.invalid us@ndm.invalid; trello members/me rig-trello-key-NDM; trello members/me/notifications rig-trello-key-NDM"
rigAssert "and nothing of our own team or of the other workspace" "$( rigOurs ) $( rigElsewhere )" "0 0"
rigRun --intern-op-session-context-scan client-ndm --all-types --do-email --do-trello
rigAssert "a scan of a client with no marker is our own side: no call, and each of the two sources says in the one line that the client holds none here, and names its own sweep" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigN "$rigTmp/out" "no scan was made -- client-ndm has no mail settings on our own organisation's side: what it holds is the other organisation's. For the other organisation use --client-sweep-input-scan." ) $( rigN "$rigTmp/out" "no scan was made -- client-ndm has no Trello settings on our own organisation's side: what it holds is the other organisation's. For the other organisation use --client-sweep-input-scan." )" "0 0 1 1"
rigRun --intern-op-session-context-scan keeper-here --all-types --do-email --do-trello
rigAssert "control: the same scan of a member of our own team reads that member's own" "$( rigCalls )" "imap-sweep imap-keeper.here.invalid us@keeper.here.invalid; trello members/me rig-trello-key-KHERE; trello members/me/notifications rig-trello-key-KHERE"
rigRun --intern-op-session-context-scan keeper-none --all-types --do-email --do-trello
rigAssert "control: and of a member of ours that holds none says its own scope is not set, as before" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigN "$rigTmp/out" "EMAIL_IMAP_HOST/EMAIL_USER/EMAIL_APP_PASSWORD are not all set in this member's own scope" ) $( rigN "$rigTmp/out" "TRELLO_KEY/TRELLO_TOKEN are not both set in this member's own scope" )" "0 0 1 1"

echo "-- 8. help --"
rigRun --member-help client-ndm
rigAssert "a client is offered the client operations of mail, Trello and Google, and the presence and socket ones of Slack" "$rigRc $( rigN "$rigTmp/out" 'DistroAgentsTools.fn.sh --client-comms-email-' ) $( rigN "$rigTmp/out" 'DistroAgentsTools.fn.sh --client-comms-trello-' ) $( rigN "$rigTmp/out" 'DistroAgentsTools.fn.sh --client-comms-google-' ) $( rigN "$rigTmp/out" 'DistroAgentsTools.fn.sh --client-comms-slack-presence-' ) $( rigN "$rigTmp/out" 'DistroAgentsTools.fn.sh --client-comms-slack-socket-' )" "0 6 6 11 3 3"
rigRun --member-help keeper-here
rigAssert "control: a member that is no client is offered none of them" "$rigRc $( rigN "$rigTmp/out" 'DistroAgentsTools.fn.sh --client-comms-' )" "0 0"
for rigFamily in email trello google ; do
	rigInclude="$rigHere/AgentsTools.MemberComms$( printf '%s' "$rigFamily" | LC_ALL=C awk '{ print toupper( substr( $0, 1, 1 ) ) substr( $0, 2 ) }' ).include"
	rigAssert "every --client-comms-$rigFamily-* operation the code holds has its syntax line, and no syntax line names one the code does not hold" "$( rigNames "$rigInclude" "$rigFamily" | LC_ALL=C tr '\n' ' ' )" "$( rigNames "$rigHelpInclude" "$rigFamily" | LC_ALL=C tr '\n' ' ' )"
	rigAssert "and each has its entry in the manual" "$( rigNames "$rigInclude" "$rigFamily" | while IFS= read -r rigName ; do LC_ALL=C grep -q -e "^		$rigName <team-member>" "$rigManual" || printf '%s ' "$rigName" ; done )" ""
	rigAssert "control: the search does find operations of that family in the code" "$( [ "$( rigNames "$rigInclude" "$rigFamily" | rigLines /dev/stdin )" -ge 3 ] && printf found || printf blind )" found
done

echo "-- 9. static: the side is said in one place for every system, and the settings are read by it --"
rigAssert "the questions every reader of a member's own settings asks are defined once, in the include of the side" "$( LC_ALL=C grep -c -E '^AgentsToolsComms(OwnSettingsApply|ClientSide|OwnSideLine|OwnSideCheck)\(\)\{' "$rigSideInclude" || : ) $( cat "$rigHere"/*.include "$rigHere"/*.sh | LC_ALL=C grep -c -E '^AgentsToolsComms(OwnSettingsApply|ClientSide|OwnSideLine|OwnSideCheck)\(\)\{' || : )" "4 4"
rigAssert "the Slack include asks the same two questions: its own two names hand on to them, once each" "$( LC_ALL=C grep -c -F -e 'AgentsToolsCommsOwnSettingsApply "$@"' "$rigHere/AgentsTools.CommsSlack.include" || : ) $( LC_ALL=C grep -c -F -e 'AgentsToolsCommsClientSide "$@"' "$rigHere/AgentsTools.CommsSlack.include" || : )" "1 1"
rigAssert "a --member- operation of each of the five systems says our own side itself, once, whatever it was called under" "$( for rigFamily in Email Trello Google Jira Confluence ; do LC_ALL=C grep -c -F -e 'local -x MDAT_COMMS_SIDE=own MDAT_COMMS_OP=""' "$rigHere/AgentsTools.MemberComms$rigFamily.include" || : ; done | LC_ALL=C tr '\n' ' ' )" "1 1 1 1 1 "
rigAssert "every file of the package that reads a member's own mail, Trello or Google secret by the member's name asks the side, or says it itself for a client" "$( for rigFile in "$rigHere"/*.include ; do LC_ALL=C grep -q -E -e '--agents-config-option "\$[A-Za-z]*" --select (EMAIL_APP_PASSWORD|TRELLO_TOKEN|GOOGLE_REFRESH_TOKEN)' "$rigFile" || continue ; LC_ALL=C grep -q -E -e 'AgentsToolsComms(OwnSideCheck|OwnSettingsApply)|:client-\*\) local -x MDAT_COMMS_SIDE=client' "$rigFile" || printf '%s ' "${rigFile##*/}" ; done )" ""
rigAssert "control: the same search does find files that read them" "$( for rigFile in "$rigHere"/*.include ; do LC_ALL=C grep -q -E -e '--agents-config-option "\$[A-Za-z]*" --select (EMAIL_APP_PASSWORD|TRELLO_TOKEN|GOOGLE_REFRESH_TOKEN)' "$rigFile" && printf 'x' ; done | LC_ALL=C awk '{ print ( length( $0 ) >= 4 ) ? "found" : "blind" }' )" found
rigAssert "the one reader of a member's Jira and Confluence settings asks it before it reads them" "$( LC_ALL=C awk '/AgentsToolsCommsOwnSettingsApply "\$actingMember"/ && ! asked { asked = NR } /--select "\$\{keyPrefix\}_SITE"/ && ! read { read = NR } END { print ( asked && read && asked < read ) ? "asked-first" : "not" }' "$rigHere/AgentsTools.InternOpAtlassianCall.include" )" asked-first
rigAssert "a client's own document stays where its own settings name it: the publish says the client side itself, once" "$( LC_ALL=C grep -c -F -e 'client-*) local -x MDAT_COMMS_SIDE=client ;;' "$rigHere/AgentsTools.InternArtifact.include" || : )" 1
rigAssert "a --magic-comms-* operation says our own side itself, once, whoever the member it is given is, and none says the client side" "$( LC_ALL=C grep -c -F -e 'local -x MDAT_COMMS_SIDE=client' "$rigHere/AgentsTools.MagicComms.include" || : ) $( LC_ALL=C grep -c -F -e '--magic-comms-*) local -x MDAT_COMMS_SIDE=own MDAT_COMMS_OP="$1" ;;' "$rigHere/AgentsTools.MagicComms.include" || : )" "0 1"
if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ CLIENT SYSTEMS CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'CLIENT_SYSTEMS: OK (%d assertions, offline)\n' "$rigPasses"
