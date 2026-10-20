#!/usr/bin/env bash
## Behavioural check on the two operations of the console's family --manager-* that speak to a session (F11.6 of the refactorings
## epic), run rather than read, against a rig machine built here: a workspace with its own spawn records, session folders and
## threads, its own members and a stand-in console, a fake `curl` that answers Slack, an `id` that names the account at the console, and
## a `ps` that lists the rig's runs only. Held:
##   1. --manager-session-message leaves a message for a session, from user-<account> (the account at the console, in the small letters,
##      digits and hyphens a name takes), never from a member. Where the session has a Slack thread the message is left in the inbox of
##      the session for the communications writer, `<from> -> <to>:` and the body byte for byte, from the standard input and never from an
##      argument; --to names the participants it is for, each once, and only a participant of the session. Where the session has no thread it
##      is recorded in the chat file itself with the conversation `local`, as a message of the console, and nothing is posted, and the row
##      and a note on standard error say so. A session with no folder and no thread, an id that is none, an empty message, a participant
##      that is none and an option the operation does not take are refused in one line each, with nothing left.
##   2. --manager-session-join brings magic-coordinator into a session that has finished, waits or is stuck (a record still open with no
##      process behind it), through the spawn proxy and with --session-id, so that it joins the session and starts none: the task it
##      starts on is the `assess-session` block of the tooling-note template, filled, and the line its joining says in the thread is the
##      `assess-session-why` block. A session that runs, one of another host, one with no thread and one that is none are refused, with
##      nothing started.
##   3. The caller rule of the family, the place of the operations (one arm, one include, ahead of the family's own arm), no text of the
##      task written in code, and their help pair, which gives the two row forms.
## Offline; only the rig's own tree is read or written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTest="$rigPackage/sh-test"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigMessageOp="--manager-session-message"
rigJoinOp="--manager-session-join"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
## A start of this rig that is not waited for starts the control thread of its session, a detached process that outlives this check: the rig ends it.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerSessionTalkCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigProcSignalKept KILL "$rigTmp"/sc/began.* ; chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp" 2> /dev/null || { sleep 3 ; rm -rf -- "$rigTmp" 2> /dev/null ; }' EXIT
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigData="$rigTmp/data" ; rigSc="$rigTmp/sc"
rigSkills="$rigWs/.local/agents/members"
rigAgents="$rigWs/.local/agents"
mkdir -p "$rigTmp/bin" "$rigSc" "$rigWs/.local/.agents" "$rigSkills" "$rigAgents/spawned" "$rigAgents/sessions" "$rigAgents/pending" "$rigHome/.agents/magic-team" "$rigData/board"
rigHost="$( hostname -s 2>/dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"

## The rig's own curl (it answers Slack and logs each call), `id` (the account at the console) and `ps` (the rig's runs only).
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
ln -s "$( command -v id )" "$rigTmp/bin/id.real" || rigRefuse "no id on PATH"
printf '#!/bin/sh\ncase "$*" in\n\t-un) echo Rig.Acct_7 ;;\n\t*) exec "${0%%/*}/id.real" "$@" ;;\nesac\n' > "$rigTmp/bin/id"
ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH"
: > "$rigTmp/ps.list"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*)
		case "$*" in
			*pid=*) cat "${0%/*}/../ps.list" 2> /dev/null ;;
			*) sed 's/^[^ ]* //' "${0%/*}/../ps.list" 2> /dev/null ;;
		esac
		exit 0
	;;
esac
exec "${0%/*}/ps.real" "$@"
RIGPS
chmod +x "$rigTmp/bin/curl" "$rigTmp/bin/id" "$rigTmp/bin/ps"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] && [ "$( command -v id )" = "$rigTmp/bin/id" ] && [ "$( command -v ps )" = "$rigTmp/bin/ps" ] \
	|| rigRefuse "the rig's own curl, id and ps are not first on PATH, so this check would issue a real request or read the host's process list"

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

## THE RIG MACHINE: a workspace with the team's own folder (and the one routine a coworking session names by default), magic-coordinator and two
## members, a registry that names them, and the stand-in console that keeps the brief it is started with.
rigMember(){ ## member -- a member's folder with the files a start of it reads
	mkdir -p "$rigSkills/$1"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$1/$1.basic.md"
	printf '# rig armed\n' > "$rigSkills/$1/$1.armed.md"
}
rigMember magic-team
printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator\ninvitees: magic-team\nrequires-session-kind: coworking\n---\n# rig coworking routine fixture\n' > "$rigSkills/magic-team/magic-team.coworking.routine.md"
for rigName in magic-coordinator keeper-rig keeper-two ; do
	rigMember "$rigName"
	printf '%s\t%s\tsource-symlink\t%s\t%s\n' "$rigName" "$rigWs" "myx/pkg/skillset/$rigName" "$rigSkills/$rigName" >> "$rigHome/.agents/magic-team/members.registry"
done
printf 'ws-here\t%s\n' "$rigWs" > "$rigHome/.agents/magic-team/directories.registry"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records what it was given.' \
	'cat > "$RIG_SCENARIO/brief.$MDAT_SPAWN_SESSION_ID"' \
	'printf "%s %s\n" "${MDAT_SPAWN_AGENT:-none}" "${MDAT_SESSION_ID:-none}" > "$RIG_SCENARIO/who.$MDAT_SPAWN_SESSION_ID"' \
	'printf "📦 SubagentHandback\n"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' \
	". '$rigTest/check-fixtures/rig-processes.include.sh' 2> /dev/null && rigProcNoteFile \"\$RIG_SCENARIO/began.\$MDAT_SPAWN_SESSION_ID\" \$\$" \
	'echo finished > "$RIG_SCENARIO/done.$MDAT_SPAWN_SESSION_ID"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"

rigTab="$( printf '\t' )"
rigAcct="user-rig-acct-7"
rigThread="CRIGSES01:1760000000.000010"
## One record of a run: sandbox and record named by the spawn id, its session, its member, its status, and the thread of the session where it has one.
rigRec(){ ## spawn id, session id, member, status, host, thread ("" for none)
	mkdir -p "$rigAgents/spawned/$1"
	{
		printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nworkspace: rigws\nowner: %s\nstatus: %s\nstarted-at: 2026-10-13 10:00 +0300\n' "$2" "$1" "$5" "$3" "$4"
		[ "$4" = "spawn-started" ] || printf 'resolved-at: 2026-10-13 10:30 +0300\n'
		[ -z "$6" ] || printf 'session-thread: %s\n' "$6"
		printf -- '---\n\n# Spawn session: %s\n' "$2"
	} > "$rigAgents/spawned/$1/$1.md"
}
rigFolder(){ ## session id, thread ("" for none) -- the session's folder, with its thread file where it has a thread
	mkdir -p "$rigAgents/sessions/$1"
	[ -z "$2" ] || printf '%s\n' "$2" > "$rigAgents/sessions/$1/session.thread"
}
rigLive(){ ## spawn id... -- the rig's process list: each a run by its own --session-id word
	local liveId livePid=900100
	: > "$rigTmp/ps.list"
	for liveId in "$@" ; do
		livePid=$(( livePid + 1 ))
		printf '%s claude --verbose --session-id %s --agent rig-member the brief\n' "$livePid" "$liveId" >> "$rigTmp/ps.list"
	done
}
## The sessions. finished: every record closed. unclosed (stuck): a record still open and nothing alive. waiting: an ask of it is open. running: a
## run of it is alive. foreign: an open record of another host. With a thread, with a folder and none, and with neither.
rigRec th-a s-thread keeper-rig spawn-succeeded "$rigHost" "$rigThread" ; rigRec th-b s-thread keeper-two spawn-succeeded "$rigHost" "$rigThread" ; rigRec s-thread s-thread magic-coordinator spawn-succeeded "$rigHost" "$rigThread"
rigFolder s-thread "$rigThread"
rigRec s-local s-local keeper-rig spawn-succeeded "$rigHost" "" ; rigFolder s-local ""
rigRec s-nowhere s-nowhere keeper-rig spawn-succeeded "$rigHost" ""
rigRec s-stuck s-stuck keeper-rig spawn-started "$rigHost" "$rigThread" ; rigFolder s-stuck "$rigThread"
rigRec s-wait s-wait keeper-rig spawn-succeeded "$rigHost" "$rigThread" ; rigFolder s-wait "$rigThread"
printf -- '---\nstatus: reply-pending\nowner: keeper-rig\nsession-id: s-wait\nkind: question\n---\nq\n' > "$rigAgents/pending/ask-wait.md"
rigRec s-run s-run keeper-rig spawn-started "$rigHost" "$rigThread" ; rigFolder s-run "$rigThread"
rigRec s-foreign s-foreign keeper-rig spawn-started "otherhost" "$rigThread" ; rigFolder s-foreign "$rigThread"
rigRec s-nothread s-nothread keeper-rig spawn-succeeded "$rigHost" "" ; rigFolder s-nothread ""
rigLive s-run

rigPre=()
rigRun(){ ## the file standard input is, tool arguments... -- one dispatcher call from the rig workspace, as a console makes it; rc in rigRc, stdout in out, stderr in err
	local runInput="$1" ; shift
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigSc" MDAT_COMMS_READER=off ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < "$runInput" || rigRc=$?
}
rigErrors(){ ## -- how many lines of the last stderr are an error, but for the one every rig of this package gets
	LC_ALL=C grep -e 'ERROR' -e 'ASSERT' "$rigTmp/err" | LC_ALL=C grep -c -v -F -- 'SystemContext.SetInputSpec' || :
}
rigWhole(){ ## file, text -- how many lines of the file are that text, whole
	LC_ALL=C grep -c -x -F -- "$2" "$1" 2> /dev/null || :
}
rigInbox(){ ## session -- the messages left in its inbox, how many
	ls "$rigAgents/sessions/$1/chat.inbox" 2> /dev/null | LC_ALL=C grep -c '\.msg$' || :
}
rigInboxFile(){ ## session -- the first message left in its inbox
	local inboxName
	inboxName="$( ls "$rigAgents/sessions/$1/chat.inbox" 2> /dev/null | LC_ALL=C grep '\.msg$' | LC_ALL=C sort | head -1 )"
	[ -z "$inboxName" ] || printf '%s' "$rigAgents/sessions/$1/chat.inbox/$inboxName"
}
rigMade(){ ## -- what the starts so far have made: run records, consoles started
	printf '%s %s\n' "$( ls "$rigAgents/spawned" 2> /dev/null | LC_ALL=C grep -c . || : )" "$( ls "$rigSc" | LC_ALL=C grep -c '^brief\.' || : )"
}
printf '%s\n' 'first line of the message' 'second line, with a "quote", a 100% and a \ and a $HOME and a `tick`' '--is no option here' > "$rigTmp/message.odd"
printf 'one line\n' > "$rigTmp/message.one"
: > "$rigTmp/message.empty"
printf '  \n\t\n' > "$rigTmp/message.blank"

echo "-- 1. a message to a session that has a thread --"
rigRun "$rigTmp/message.odd" "$rigMessageOp" --session-id s-thread
rigAssert "it ends 0 with no error, and prints one message row: the session, the sender, all, how, and the name it was left under" \
	"$rigRc $( rigErrors ) $( LC_ALL=C awk -F'\t' 'END { print NR }' "$rigTmp/out" ) $( LC_ALL=C awk -F'\t' '{ print $1, NF, $2, $3, $4, $5 }' "$rigTmp/out" )" "0 0 1 message 6 s-thread $rigAcct all thread"
rigAssert "the sender is the account at the console as a name takes it, in small letters: user-<account>, and no member's" "$( LC_ALL=C awk -F'\t' '{ print $3 }' "$rigTmp/out" )" "$rigAcct"
rigAssert "one message stands in the inbox of the session, the row names it" "$( rigInbox s-thread ) $( LC_ALL=C awk -F'\t' '{ print $6 }' "$rigTmp/out" | LC_ALL=C grep -c -x -F -- "$( rigInboxFile s-thread | LC_ALL=C sed 's#.*/##' )" )" "1 1"
rigAssert "its header is <from> -> <to>: and its body is the message byte for byte: a quote, a %, a backslash, a dollar, a back quote, and a line that starts with -" \
	"$( head -1 "$( rigInboxFile s-thread )" ) $( tail -n +2 "$( rigInboxFile s-thread )" | cmp -s - "$rigTmp/message.odd" && echo same || echo other )" "$rigAcct -> all: same"
rigCalls(){ ## -- how many posts the fake curl was asked for
	[ -f "$rigSc/calls" ] || { printf 0 ; return 0 ; }
	LC_ALL=C grep -c '^chat.postMessage ' "$rigSc/calls" || :
}
rigAssert "nothing is posted by the operation itself: the writer does it, and none was started here" "$( rigCalls )" "0"

echo "-- 2. to the participants --"
rigRun "$rigTmp/message.one" "$rigMessageOp" --session-id s-thread --to keeper-rig
rigAssert "one participant: the row and the header name it" "$rigRc $( LC_ALL=C awk -F'\t' '{ print $4 }' "$rigTmp/out" ) $( ls -t "$rigAgents/sessions/s-thread/chat.inbox"/*.msg | head -1 | { read -r inboxLast ; head -1 "$inboxLast" ; } )" "0 keeper-rig $rigAcct -> keeper-rig:"
rigRun "$rigTmp/message.one" "$rigMessageOp" --session-id s-thread --to keeper-rig --to keeper-two --to keeper-rig
rigAssert "two, each once, joined by a comma, in the order given" "$rigRc $( LC_ALL=C awk -F'\t' '{ print $4 }' "$rigTmp/out" )" "0 keeper-rig,keeper-two"
rigBefore="$( rigInbox s-thread )"
rigRun "$rigTmp/message.one" "$rigMessageOp" --session-id s-thread --to keeper-nobody
rigAssert "a name that is no participant of the session is refused in one line that lists them, with nothing left" "$rigRc $( rigErrors ) $( LC_ALL=C grep -c -e 'keeper-nobody is no participant of session s-thread (its participants: ' -e 'keeper-rig' -e 'keeper-two' -e 'magic-coordinator) -- nothing was left' "$rigTmp/err" | LC_ALL=C awk '{ print ( $1 >= 1 ) ? 1 : 0 }' ) $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigInbox s-thread ):$rigBefore" "1 1 1 0 $rigBefore:$rigBefore"

echo "-- 3. a session with a folder and no thread: the chat file alone --"
rigRun "$rigTmp/message.odd" "$rigMessageOp" --session-id s-local
rigAssert "the row says the chat file, and the block it was recorded as" "$rigRc $( rigErrors ) $( LC_ALL=C awk -F'\t' '{ print $1, $2, $3, $4, $5, $6 }' "$rigTmp/out" )" "0 0 message s-local $rigAcct all chat-file 1"
rigAssert "a note on standard error says that nothing is posted and the members read it in the chat file" "$( LC_ALL=C grep -c 'session s-local has no Slack thread, so the message is recorded in its chat file only (block 1) and nothing is posted; its members read it there' "$rigTmp/err" )" "1"
rigAssert "the chat file holds it: the header from the account to all, the body byte for byte" "$( LC_ALL=C sed -n '1s/^[0-9T:Z-]* //p' "$rigAgents/sessions/s-local/session.chat" ) $( LC_ALL=C sed -n '2,$p' "$rigAgents/sessions/s-local/session.chat" | LC_ALL=C sed '$d' | cmp -s - "$rigTmp/message.odd" && echo same || echo other )" "$rigAcct -> all: same"
rigAssert "its index line says it has no ts, that its conversation is local, and that it came from the console" "$( LC_ALL=C awk -F'\t' '{ print $1, $2, $3, $4 }' "$rigAgents/sessions/s-local/session.chat.index" )" "1 - local console"
rigAssert "nothing is left in an inbox, and no call was made to Slack" "$( rigInbox s-local ) $( rigCalls )" "0 0"
rigRun "$rigTmp/message.one" "$rigMessageOp" --session-id s-local --to keeper-rig
rigAssert "a second is the second block, to the participant" "$rigRc $( LC_ALL=C awk -F'\t' '{ print $4, $6 }' "$rigTmp/out" ) $( LC_ALL=C awk -F'\t' 'END { print NR }' "$rigAgents/sessions/s-local/session.chat.index" )" "0 keeper-rig 2 2"

echo "-- 4. what is refused leaves nothing --"
rigBefore="$( rigMade ) $( ls "$rigAgents/sessions" | LC_ALL=C grep -c . ) $( rigInbox s-thread )"
rigRun "$rigTmp/message.one" "$rigMessageOp" --session-id s-nowhere
rigAssert "a session with no folder and no thread has nowhere to keep it: refused plainly, and its folder is not made" "$rigRc $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigMessageOp: session s-nowhere has no chat file to keep a message in and no Slack thread to send it into -- nothing was left" ) $( [ -d "$rigAgents/sessions/s-nowhere" ] && echo made || echo none )" "1 1 none"
rigRun "$rigTmp/message.one" "$rigMessageOp" --session-id s-no-such-session
rigAssert "an id that no record carries is refused" "$rigRc $( LC_ALL=C grep -c "no record of this workspace carries 's-no-such-session' as the id of a session or the own id of a run -- nothing was left" "$rigTmp/err" )" "1 1"
rigRun "$rigTmp/message.empty" "$rigMessageOp" --session-id s-thread
rigAssert "an empty message is refused" "$rigRc $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigMessageOp: the message is empty -- nothing was left" )" "1 1"
rigRun "$rigTmp/message.blank" "$rigMessageOp" --session-id s-thread
rigAssert "so is one of blank lines" "$rigRc $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigMessageOp: the message is empty -- nothing was left" )" "1 1"
rigRun "$rigTmp/message.one" "$rigMessageOp"
rigAssert "no --session-id is refused, with the syntax" "$rigRc $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigMessageOp: syntax is --session-id <id> [--to <participant>]... < message, got no --session-id" )" "1 1"
rigRun "$rigTmp/message.one" "$rigMessageOp" --session-id s-thread the message as words
rigAssert "the message is never an argument: words after the options are refused" "$rigRc $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigMessageOp: syntax is --session-id <id> [--to <participant>]... < message, got: the" )" "1 1"
## The system giving no account: the person at the console has no name to send as, and a message is never left under a made-up one (F6.10).
mkdir -p "$rigTmp/noid"
printf '#!/bin/sh\nexit 1\n' > "$rigTmp/noid/id"
chmod +x "$rigTmp/noid/id"
rigPre=( PATH="$rigTmp/noid:$PATH" )
rigRun "$rigTmp/message.one" "$rigMessageOp" --session-id s-thread
rigPre=()
rigAssert "the system giving no account is refused plainly, with nothing on stdout" "$rigRc $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigMessageOp: the system gives no account for the person at the console, and a message is not sent under a made-up name -- nothing was left" ) $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" "1 1 0"
rigAssert "nothing was made by any of them: no record, no console, no folder, no message" "$rigBefore" "$( rigMade ) $( ls "$rigAgents/sessions" | LC_ALL=C grep -c . ) $( rigInbox s-thread )"
rigAssert "and no message names user-unknown" "$( LC_ALL=C grep -r -l -F -e 'user-unknown' "$rigAgents/sessions" 2> /dev/null | LC_ALL=C grep -c . || : )" "0"

echo "-- 5. magic-coordinator joined into a session --"
rigMadeBefore="$( rigMade )"
rigRun /dev/null "$rigJoinOp" --session-id s-thread
rigAssert "a finished session with a thread: ends 0 with no error and one join row, of the session, the coordinator and the dispatch item" \
	"$rigRc $( rigErrors ) $( LC_ALL=C awk -F'\t' 'END { print NR }' "$rigTmp/out" ) $( LC_ALL=C awk -F'\t' '{ print $1, NF, $2, $3 }' "$rigTmp/out" ) $( LC_ALL=C awk -F'\t' '{ print $4 }' "$rigTmp/out" | LC_ALL=C grep -c '^dispatch-.*spawn-proxy.*\.md$' )" "0 0 1 join 4 s-thread magic-coordinator 1"
rigWaitFor 30 test "$( ls "$rigSc" | LC_ALL=C grep -c '^done\.' )" -ge 1
rigNewRec="$( LC_ALL=C grep -l -x 'start-context: joined' "$rigAgents"/spawned/*/*.md 2> /dev/null | head -1 )"
rigBrief="$( ls "$rigSc"/brief.* 2> /dev/null | head -1 )"
rigAssert "one console was started more, as magic-coordinator, in the session it was joined into: it joined, and did not start a session of its own" "$( rigMade ) / $( LC_ALL=C awk '{ print $1, $2 }' "${rigBrief/brief./who.}" 2> /dev/null )" "${rigMadeBefore% *} 1 / magic-coordinator s-thread"
rigAssert "the new record names the session as its own and says that it joined" "$( LC_ALL=C grep -c -x -e 'session-id: s-thread' -e 'start-context: joined' -e 'owner: magic-coordinator' "$rigNewRec" 2> /dev/null || : )" "3"
rigAssert "the task it starts on is the template's block, filled: the account at the console, the session, and the words of the finished state" \
	"$( LC_ALL=C grep -c -x -F -e "You are joined, by Rig.Acct_7 at the console, to the session s-thread. Assess it, unblock it interactively, and report." -e "The session has ended: every participant of it has finished." -e "When you are done, post your report in the thread, hand back, and Wait until dismissed." "$rigBrief" )" "3"
rigAssert "and the line its joining says in the thread is the other block" "$( LC_ALL=C grep -c -F 'assess the session, unblock it interactively and report' "$rigSc/bodies" 2> /dev/null || : )" "1"
for rigWords in "Assess it, unblock it interactively, and report." "has ended: every participant" "assess the session, unblock it interactively and report" ; do
	rigAssert "no text of the task is written in the code: '$rigWords' stands in the template and not in the include or the screen" \
		"$( LC_ALL=C grep -c -F -- "$rigWords" "$rigHere/templates/tooling-note.post.format.md" ) $( LC_ALL=C grep -c -F -- "$rigWords" "$rigHere/manager/AgentsTools.ManagerSessionTalk.include" "$rigHere/manager/AgentsManagerScreen.Talk.py" 2> /dev/null | LC_ALL=C awk -F: '{ n += $NF } END { print n + 0 }' )" "1 0"
done
rigRun /dev/null "$rigJoinOp" --session-id s-stuck
rigAssert "a stuck session (an open record, nothing alive) is joined too" "$rigRc $( LC_ALL=C awk -F'\t' '{ print $1, $2, $3 }' "$rigTmp/out" )" "0 join s-stuck magic-coordinator"
rigWaitFor 30 test "$( ls "$rigSc" | LC_ALL=C grep -c '^done\.' )" -ge 2
rigAssert "its task says it is stuck" "$( LC_ALL=C grep -l -x -F 'The session is stuck: a run of it is still open, and no process carries it.' "$rigSc"/brief.* 2> /dev/null | LC_ALL=C grep -c . )" "1"
rigRun /dev/null "$rigJoinOp" --session-id s-wait
rigAssert "and one that waits" "$rigRc $( LC_ALL=C awk -F'\t' '{ print $1, $2, $3 }' "$rigTmp/out" )" "0 join s-wait magic-coordinator"
rigWaitFor 30 test "$( ls "$rigSc" | LC_ALL=C grep -c '^done\.' )" -ge 3

echo "-- 6. a session it is not offered for --"
rigMadeBefore="$( rigMade )"
rigRun /dev/null "$rigJoinOp" --session-id s-run
rigAssert "a session that runs: refused in one line, nothing started" "$rigRc $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigJoinOp: session s-run runs: its participants work on it, so nobody is joined into it to assess it -- nothing was started" ) $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) [$( rigMade )]" "1 1 0 [$rigMadeBefore]"
rigRun /dev/null "$rigJoinOp" --session-id s-foreign
rigAssert "one of another host: refused, and says what it reads" "$rigRc $( LC_ALL=C grep -c 'session s-foreign reads unknown-foreign, which is none of finished, waiting and unclosed, the states it is offered for -- nothing was started' "$rigTmp/err" ) [$( rigMade )]" "1 1 [$rigMadeBefore]"
rigRun /dev/null "$rigJoinOp" --session-id s-nothread
rigAssert "one with no Slack thread: refused, since a member is joined into a session by its thread" "$rigRc $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigJoinOp: session s-nothread has no Slack thread, and a member is joined into a session by its thread -- nothing was started" ) [$( rigMade )]" "1 1 [$rigMadeBefore]"
rigRun /dev/null "$rigJoinOp" --session-id s-no-such-session
rigAssert "an id that is none is refused" "$rigRc $( LC_ALL=C grep -c "no record of this workspace carries 's-no-such-session'" "$rigTmp/err" ) [$( rigMade )]" "1 1 [$rigMadeBefore]"
rigRun /dev/null "$rigJoinOp"
rigAssert "no --session-id is refused with the syntax" "$rigRc $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigJoinOp: syntax is --session-id <id>, got no --session-id" )" "1 1"

echo "-- 7. the caller rule, the place and the help pair --"
rigPre=( MDAT_SPAWN_AGENT=keeper-rig MDAT_SPAWN_SESSION_ID=rig-own-run )
rigRun "$rigTmp/message.one" "$rigMessageOp" --session-id s-thread
rigAssert "a call from inside a member's session is refused as every operation of the family is, and leaves nothing" "$rigRc $( rigErrors ) $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" "1 1 0"
rigPre=()
rigAssert "the operations are one arm of the family's dispatch, ahead of its own arm for sessions, and one include" \
	"$( LC_ALL=C grep -c -F -e '--manager-session-message|--manager-session-join)' "$rigHere/manager/AgentsTools.Manager.include" ) $( LC_ALL=C awk '/--manager-session-message\|--manager-session-join\)/ { a = NR } /^\t--manager-session-\*\)/ { b = NR } END { print ( a && b && a < b ) ? "ahead" : "wrong" }' "$rigHere/manager/AgentsTools.Manager.include" ) $( [ -f "$rigHere/manager/AgentsTools.ManagerSessionTalk.include" ] && echo include )" "1 ahead include"
rigHelp="$rigHere/help/Help.DistroAgentsTools.help.md"
rigAssert "each has its syntax line in both places of the help, and an entry" "$( for rigOne in message join ; do printf '%s%s%s ' "$( LC_ALL=C grep -c -e "^📘 syntax: DistroAgentsTools.fn.sh --manager-session-$rigOne" "$rigHelp" )" "$( LC_ALL=C grep -c -e "syntax: DistroAgentsTools.fn.sh --manager-session-$rigOne" "$rigHere/help/Help.DistroAgentsTools.include" )" "$( LC_ALL=C grep -c -e "^		--manager-session-$rigOne" "$rigHelp" )" ; done )" "111 111 "
rigAssert "the entries give the row forms the output is checked against" \
	"$( LC_ALL=C grep -c -F -e '`message <session-id> <from> <to> <how> <kept>`' -e '`join <session-id> <member> <dispatch-item>`' "$rigHelp" )" "2"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MANAGER SESSION TALK CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SESSION_TALK: OK (%d assertions, offline)\n' "$rigPasses"
