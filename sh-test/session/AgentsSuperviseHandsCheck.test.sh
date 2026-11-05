#!/usr/bin/env bash
## Behavioural check on four supervisor operations of epic S13, run against a rig workspace rather than read:
##   S13.4 `--supervise-read`: one run read by its id -- its record and liveness, its transcript's tail, its session
##         thread's last messages, its CheckList, and its session log with --log.
##   S13.5 `--supervise-guide` and `--supervise-checklist-add`: guidance posted into that run's session as its supervisor,
##         and pending items added to that run's own list.
##   S13.7 `--supervise-fault`: a tooling fault filed into the owning member's inbox with the run's own facts above the
##         evidence, and one line in the run's dispatch item linking the two.
##   S13.10 `--supervise-commit-transcripts`: the transcripts the store holds changed reach one commit and the store's
##         push debt is paid; a transcript nobody touched is not committed.
## WHY THESE AND NOT THE CONSOLE'S. `--manager-session-*` is the console's own and is refused from inside a member's
## session; a supervisor is such a session, so those reads were closed to it, and nothing read another run's thread at all.
## TWO RUNS, because the two ways a session keeps a message are two cases: a run with a Slack thread, whose thread the read
## shows, and a run with none, whose message is recorded in its chat file. A check posts in Slack to nobody.
## Held:
##   1. the read: the run row, the transcript's last lines only, the thread's last message only, the list's items, and
##      `--no-checklist` leaving that section out
##   2. the control, both directions: `--tail 40` gives what `--tail 2` cuts, and a count that is no number is refused
##   3. the guidance reaching a run with no thread, recorded from magic-coordinator to its member; empty guidance refused
##   4. the items on the run's own list, and in `<member>.checklist.md.added` so its next whole-list write keeps them
##   5. the fault's inquiry in the owner's inbox, with the run's member, session and item named; and the item's Decisions
##      carrying the link
##   6. the sweep: the changed transcript committed, an untouched one left alone, `--dry-run` committing nothing, and a
##      second sweep finding nothing
##   7. the operations are the supervisor's: another member's session is refused
## Red before these operations: each call is refused as an invalid option, so 1 to 7 fail.
## Offline: a rig workspace, its spawn records, its team data and its git store are this rig's own temp tree, and no
## process outlives the check.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigFn="$rigPkg/sh-scripts/AgentDispatcherTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigFn" ] || rigRefuse "the dispatcher is not at the origin: $rigFn"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSuperviseHandsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
rigHome="$rigTmp/home"
rigSkills="$rigTmp/skills"
rigAgents="$rigWs/.local/agents"
rigRun="rigrun1"
rigRunBare="rigrun2"
rigThread="C0RIG:1793000000.000100"
mkdir -p "$rigAgents/spawned" "$rigAgents/sessions" "$rigData/audit/2026-11" "$rigData/board/review" \
	"$rigData/inboxes/magic-tester/incoming" "$rigHome" "$rigSkills/magic-coordinator" "$rigSkills/magic-tester" "$rigSkills/magic-developer" \
	|| rigRefuse "the rig could not be made: $rigTmp"
printf 'rig\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
printf 'rig\n' > "$rigSkills/magic-tester/magic-tester.basic.md"
printf 'rig\n' > "$rigSkills/magic-developer/magic-developer.basic.md"
## A SLACK-SHAPED CURL, so the guidance path that posts into a run's thread is exercised too (S13.5): it opens no socket,
## and it keeps each posted body under `$rigTmp/slack`, one file a post.
mkdir -p "$rigTmp/bin" "$rigTmp/slack"
cat > "$rigTmp/bin/curl" <<'RIGCURL'
#!/bin/sh
rigBody=""
for rigArg in "$@" ; do
	case "$rigArg" in
		@-|@/dev/fd/*) rigBody="$( cat )" ;;
		@*) rigBody="$( cat "${rigArg#@}" 2> /dev/null )" ;;
	esac
done
case "$*" in
	*chat.postMessage*)
		rigPost=$(( $( cat "$RIG_SLACK/posts" 2> /dev/null || echo 0 ) + 1 ))
		printf '%s' "$rigPost" > "$RIG_SLACK/posts"
		printf '%s\n' "$rigBody" > "$RIG_SLACK/post.$rigPost"
		printf '{"ok":true,"channel":"CRIG00001","ts":"1793000001.00010%s","message":{"ts":"1793000001.00010%s","user":"URIGBOT01"}}\n' "$rigPost" "$rigPost"
	;;
	*auth.test*) printf '{"ok":true,"user_id":"URIGBOT01","url":"https://rig.invalid/"}\n' ;;
	*conversations.info*) printf '{"ok":true,"channel":{"id":"CRIG00001","is_im":false,"is_mpim":false}}\n' ;;
	*conversations.replies*) printf '{"ok":true,"messages":[]}\n' ;;
	*) printf '{"ok":true}\n' ;;
esac
RIGCURL
chmod +x "$rigTmp/bin/curl" || rigRefuse "the rig's curl could not be installed"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' \
	> "$rigWs/.local/.agents/magic-team.agent.env"
rigTranscript="$rigData/audit/2026-11/session-rig-$rigRun.log"

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

## ONE RUN: its record with the thread it is given, its session's transcript pointer and store, its list, and its chat file.
rigRunRecord(){ ## run id, session-thread or -
	local runDir="$rigAgents/spawned/$1"
	mkdir -p "$runDir" "$rigAgents/sessions/$1" || rigRefuse "the run could not be made: $1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nworkspace: ws-supervise-hands-rig\nowner: magic-developer\nstatus: spawn-started\nstarted-at: 2026-11-04 05:00 +0200\nsession-thread: %s\nspawns: dispatch-rig-item\n---\n' \
		"$1" "$1" "$( hostname -s 2> /dev/null )" "$2" > "$runDir/$1.spawn.md" || rigRefuse "the record could not be written: $1"
	printf '%s\n' "$rigTranscript" > "$rigAgents/sessions/$1/transcript"
	printf '%s\n' "$rigData" > "$rigAgents/sessions/$1/data-root"
	printf -- '- [~] Rig step one (in progress: Doing it)\n- [ ] Rig step two\n' > "$runDir/magic-developer.checklist.md"
}

## THE RUN WITH A THREAD: a transcript of four lines, of which a tail of two wants the last two, and a chat file of two messages.
rigRunRecord "$rigRun" "$rigThread"
printf '2026-11-04T05:00:00Z START session %s\n2026-11-04T05:01:00Z ROUND n=1 in=0 out=10\n2026-11-04T05:02:00Z TOOL Bash cmd=rig -> ok 1B/1L 1s\n2026-11-04T05:03:00Z LINE-THREE after the milestone\n' \
	"$rigRun" > "$rigTranscript"
printf '2026-11-04T05:02:00Z magic-developer -> all:\nhello from the run\n\n2026-11-04T05:03:00Z magic-coordinator -> all:\ncarry on with the check\n\n' \
	> "$rigAgents/sessions/$rigRun/session.chat"
printf '1\t-\t%s\town\t1\t-\n2\t-\t%s\town\t5\t-\n' "$rigThread" "$rigThread" > "$rigAgents/sessions/$rigRun/session.chat.index"
## THE RUN WITH NO THREAD: what a supervisor's guidance is recorded in when there is no Slack thread to post into.
rigRunRecord "$rigRunBare" -
printf '2026-11-04T05:00:00Z START session %s\n' "$rigRunBare" > "$rigData/audit/2026-11/session-rig-$rigRunBare.log"

printf -- '---\ntype: dispatch\nstatus: dispatch-started\nspawn-id: %s\nowner: magic-developer\ndate: 2026-11-04 05:00 +0200\n---\n\n# dispatch: the rig item\n' \
	"$rigRun" > "$rigData/board/review/dispatch-rig-item.md"
printf 'seed\n' > "$rigData/README.md"
git -C "$rigData" init -q || rigRefuse "the rig store could not be made"
git -C "$rigData" config user.email rig@example.invalid
git -C "$rigData" config user.name rig
git -C "$rigData" add -A && git -C "$rigData" commit -q -m seed || rigRefuse "the rig store could not be seeded"
## The line no milestone of the run ever carries: written after the commit, as a verdict or a death note is.
printf '2026-11-04T05:04:00Z VERDICT item=dispatch-rig-item kind=verdict by=magic-coordinator text=accepted\n' >> "$rigTranscript"

## A SECOND RIG (S13.10): another workspace on this machine, whose own store a supervisor commits by naming that workspace.
## Its store is where the one rule resolves a workspace's store with no setting: the workspace's own
## `.local/agents/team-data-root`, a repository of its own.
rigOtherWs="$rigTmp/other-ws"
rigOtherData="$rigOtherWs/.local/agents/team-data-root"
mkdir -p "$rigOtherData/audit/2026-11" || rigRefuse "the other rig could not be made: $rigTmp"
printf 'seed\n' > "$rigOtherData/README.md"
printf '2026-11-04T05:00:00Z START session rig-other\n' > "$rigOtherData/audit/2026-11/session-rig-other.log"
git -C "$rigOtherData" init -q || rigRefuse "the other rig's store could not be made"
git -C "$rigOtherData" config user.email rig@example.invalid
git -C "$rigOtherData" config user.name rig
git -C "$rigOtherData" add -A && git -C "$rigOtherData" commit -q -m seed || rigRefuse "the other rig's store could not be seeded"
printf '2026-11-04T05:04:00Z VERDICT item=dispatch-other kind=verdict text=accepted\n' >> "$rigOtherData/audit/2026-11/session-rig-other.log"

## The operations, as the supervisor of the rig runs them: as magic-coordinator, in the rig's workspace and store.
rigCall(){ ## operation, then its arguments
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" \
		MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_TEAM_DATA_COMMIT_THREAD=off MDAT_COMMS_READER=off MDAT_COLLECT_THREAD=off \
		RIG_SLACK="$rigTmp/slack" SLACK_BOT_TOKEN=rig-bot-token-TEAM MDAT_SPAWN_AGENT="${rigActing:-magic-coordinator}" \
		bash "$rigFn" "$@" 2>&1
}
rigRow(){ ## output, the leading word -- how many rows begin with it
	printf '%s\n' "$1" | LC_ALL=C awk -v want="$2" '$1 == want' | LC_ALL=C wc -l | LC_ALL=C tr -d ' '
}
rigField(){ ## output, the leading word, the field number -- that word of the first such row
	printf '%s\n' "$1" | LC_ALL=C awk -v want="$2" -v at="$3" -F'\t' '$1 == want { print $at ; exit }'
}
rigClean(){ ## none -- whether the rig store holds anything uncommitted under audit/
	[ -n "$( git -C "$rigData" status --porcelain -- audit 2> /dev/null )" ] && printf dirty || printf clean
}

echo "-- 1. one run read by its id --"
rigOut="$( rigCall --supervise-read "$rigRun" --tail 2 --thread-lines 1 )"
rigAssert "the run row names its member, session, status and liveness" \
	"$( rigField "$rigOut" run 3 ) $( rigField "$rigOut" run 4 ) $( rigField "$rigOut" run 5 ) $( rigField "$rigOut" run 6 )" \
	"magic-developer $rigRun spawn-started gone"
rigAssert "the transcript's pointer is given" "$( rigField "$rigOut" transcript 2 )" "$rigTranscript"
rigAssert "a tail of two gives two lines" "$( rigRow "$rigOut" tail )" "2"
rigAssert "and they are the last two, not the whole file" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'LINE-THREE' ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'START session' )" "1 0"
rigAssert "the thread is named" "$( rigField "$rigOut" thread 2 )" "$rigThread"
rigAssert "the thread's last message only is shown" "$( rigRow "$rigOut" message )" "1"
## --thread-lines: the same code as --tail, and one row of its own (S13.4).
rigAssert "a thread-lines of one shows one message, and a count that is no number is refused" \
	"$( rigCall --supervise-read "$rigRun" --thread-lines 1 | LC_ALL=C awk '$1 == "message"' | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ):$( rigCall --supervise-read "$rigRun" --thread-lines 0 2>&1 | LC_ALL=C grep -c 'a count must be a whole number above zero' )" "1:1"
rigAssert "and it is the newest one" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'carry on with the check' ) $( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'hello from the run' )" "1 0"
rigAssert "the list is given with its member" "$( rigField "$rigOut" checklist 2 )" "magic-developer"
rigAssert "and both of its items are shown" "$( rigRow "$rigOut" item )" "2"
rigAssert "the log is left out where it was not asked for" "$( rigRow "$rigOut" log )" "0"
rigOut="$( rigCall --supervise-read "$rigRun" --no-checklist )"
rigAssert "a read with --no-checklist shows no list" "$( rigRow "$rigOut" item )" "0"
rigAssert "and still shows the run" "$( rigRow "$rigOut" run )" "1"

echo "-- 2. the control, both directions: the count cuts the read, and a count that is no number is refused --"
rigOut="$( rigCall --supervise-read "$rigRun" --tail 40 )"
rigAssert "a tail of forty gives the whole transcript" "$( rigRow "$rigOut" tail )" "5"
rigAssert "including the line a tail of two cut" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'START session' )" "1"
rigOut="$( rigCall --supervise-read "$rigRun" --tail 0 )" ; rigRc=$?
rigAssert "a tail of zero is refused" "$rigRc $( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'count must be a whole number above zero' )" "1 1"
rigOut="$( rigCall --supervise-read rignosuchrun )" ; rigRc=$?
rigAssert "a run id no record carries is refused, naming it" "$rigRc $( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'rignosuchrun' )" "1 1"

echo "-- 3. guidance reaches the run --"
rigOut="$( printf 'check the exit status, then hand back\n' | rigCall --supervise-guide "$rigRunBare" )" ; rigRc=$?
rigAssert "the guidance reports where it went" "$rigRc $( rigField "$rigOut" guide 3 ) $( rigField "$rigOut" guide 5 )" "0 magic-developer chat-file"
rigAssert "and it is in the run's chat file, from magic-coordinator to its member" \
	"$( LC_ALL=C grep -c -F -e 'magic-coordinator -> magic-developer:' -e 'check the exit status, then hand back' "$rigAgents/sessions/$rigRunBare/session.chat" )" "2"
rigOut="$( printf ' \n' | rigCall --supervise-guide "$rigRunBare" )" ; rigRc=$?
rigAssert "empty guidance is refused, and posts nothing" "$rigRc $( LC_ALL=C grep -c -F 'check the exit status, then hand back' "$rigAgents/sessions/$rigRunBare/session.chat" )" "1 1"
## THE PATH WITH A THREAD (S13.5): a run whose session carries a thread is guided there, and its chat file is left alone.
: > "$rigTmp/slack/posts" 2> /dev/null
rigOut="$( printf 'read the failure, then hand back\n' | rigCall --supervise-guide "$rigRun" )" ; rigRc=$?
rigAssert "guidance to a run with a thread is posted into that thread, addressed to its member" \
	"$rigRc $( rigField "$rigOut" guide 5 ) $( LC_ALL=C grep -c -F "\"channel\":\"${rigThread%%:*}\"" "$rigTmp/slack/post.1" 2> /dev/null )$( LC_ALL=C grep -c -F "\"thread_ts\":\"${rigThread#*:}\"" "$rigTmp/slack/post.1" 2> /dev/null )$( LC_ALL=C grep -c -F '"text":"magic-developer"' "$rigTmp/slack/post.1" 2> /dev/null ) $( LC_ALL=C grep -c -F 'read the failure, then hand back' "$rigTmp/slack/post.1" 2> /dev/null )" \
	"0 thread 111 1"
printf '%s\n' "$rigOut" | LC_ALL=C grep -q '^guide' || printf '        guide said: %s\n' "$rigOut" >&2
rigAssert "and it is not written into the run's chat file as well" \
	"$( LC_ALL=C grep -c -F 'read the failure, then hand back' "$rigAgents/sessions/$rigRun/session.chat" )" "0"

echo "-- 4. items join the run's own list --"
rigOut="$( rigCall --supervise-checklist-add "$rigRunBare" --item "Re-run the check" --item "Report the count" )" ; rigRc=$?
rigAssert "two items are added" "$rigRc $( rigField "$rigOut" checklist 4 )" "0 2"
rigAssert "the list now ends with them" \
	"$( LC_ALL=C grep -c -e '^- \[ \] Re-run the check$' -e '^- \[ \] Report the count$' "$rigAgents/spawned/$rigRunBare/magic-developer.checklist.md" )" "2"
rigAssert "and the next whole-list write is told of them" \
	"$( LC_ALL=C grep -c -e '^- \[ \] Re-run the check$' -e '^- \[ \] Report the count$' "$rigAgents/spawned/$rigRunBare/magic-developer.checklist.md.added" )" "2"
rigAssert "the items already on the list are untouched" \
	"$( LC_ALL=C grep -c -e '^- \[~\] Rig step one' -e '^- \[ \] Rig step two$' "$rigAgents/spawned/$rigRunBare/magic-developer.checklist.md" )" "2"

echo "-- 5. a tooling fault filed with its evidence, and linked to the run --"
rigOut="$( printf 'the check fails at row 3\nstack: line 44\n' | rigCall --supervise-fault "$rigRun" --owner magic-tester --title "advance check reads a stale registry" )" ; rigRc=$?
rigFault="$( rigField "$rigOut" fault 4 )"
rigAssert "the fault is filed to its owner" "$rigRc $( rigField "$rigOut" fault 3 ) $( [ -n "$rigFault" ] && printf named )" "0 magic-tester named"
rigAssert "and it is in that member's inbox" "$( [ -f "$rigData/inboxes/magic-tester/incoming/$rigFault" ] && printf there || printf absent )" "there"
rigFacts=0
for rigFact in "$rigRun" magic-developer "$rigRun" dispatch-rig-item ; do
	[ "$( LC_ALL=C grep -c -F -- "$rigFact" "$rigData/inboxes/magic-tester/incoming/$rigFault" )" -gt 0 ] && rigFacts=$(( rigFacts + 1 ))
done
rigAssert "the fault names the run, its member, its session and its item" "$rigFacts" "4"
rigAssert "and carries the evidence it was filed with" \
	"$( LC_ALL=C grep -c -F -e 'the check fails at row 3' -e 'stack: line 44' "$rigData/inboxes/magic-tester/incoming/$rigFault" )" "2"
rigAssert "the item's Decisions link the fault to the run" \
	"$( LC_ALL=C awk -v fault="$rigFault" -v run="$rigRun" 'index( $0, fault ) && index( $0, "blocks run " run ) { n++ } END { print n + 0 }' "$rigData/board/review/dispatch-rig-item.md" )" "1"
rigAssert "and the link names the item" "$( rigField "$rigOut" linked 2 )" "dispatch-rig-item"

echo "-- 6. the transcripts nobody committed reach a commit --"
rigAssert "the store starts dirty under audit/" "$( rigClean )" "dirty"
rigOut="$( rigCall --supervise-commit-transcripts --dry-run )" ; rigRc=$?
rigAssert "a dry run names the transcript that would go" \
	"$rigRc $( rigField "$rigOut" commit 2 )" "0 audit/2026-11/session-rig-$rigRun.log"
rigAssert "and commits nothing" "$( rigClean )" "dirty"
rigOut="$( rigCall --supervise-commit-transcripts )" ; rigRc=$?
rigAssert "the sweep commits it" "$rigRc $( rigField "$rigOut" commit 2 )" "0 audit/2026-11/session-rig-$rigRun.log"
rigAssert "and the store is clean under audit/ after it" "$( rigClean )" "clean"
rigAssert "a second sweep finds nothing to commit" "$( rigCall --supervise-commit-transcripts | LC_ALL=C awk '$1 == "commit" { print $2 ; exit }' )" "none"
rigAssert "the transcript the sweep committed holds its seed and its sweep, and no more" \
	"$( git -C "$rigData" log --oneline -- "audit/2026-11/session-rig-$rigRun.log" | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "2"
rigAssert "and the transcript nobody touched is left at its one commit" \
	"$( git -C "$rigData" log --oneline -- "audit/2026-11/session-rig-$rigRunBare.log" | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "1"

echo "-- 6b. a store named by --workspace is that rig's, and never this call's own (S13.10) --"
rigOtherClean(){ [ -n "$( git -C "$rigOtherData" status --porcelain -- audit 2> /dev/null )" ] && printf dirty || printf clean ; }
rigAssert "the other rig's store starts dirty under audit/" "$( rigOtherClean )" "dirty"
rigOut="$( rigCall --supervise-commit-transcripts --workspace "$rigOtherWs" )" ; rigRc=$?
rigAssert "the sweep names the transcript of the rig it was given" "$rigRc $( rigField "$rigOut" commit 2 )" "0 audit/2026-11/session-rig-other.log"
rigAssert "and that rig's store is clean under audit/ after it" "$( rigOtherClean )" "clean"
rigAssert "and its transcript holds its seed and its sweep, and no more" \
	"$( git -C "$rigOtherData" log --oneline -- "audit/2026-11/session-rig-other.log" | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "2"
rigAssert "this rig's own store was not swept by that call" "$( rigClean )" "clean"

echo "-- 7. the operations are the supervisor's, and not another member's --"
rigOut="$( rigCall --supervise-read "$rigRun" )" ; rigRc=$?
rigAssert "a supervisor reads a run" "$rigRc $( rigRow "$rigOut" run )" "0 1"
rigOut="$( rigActing=magic-tester rigCall --supervise-read "$rigRun" )" ; rigRc=$?
rigAssert "another member's session is refused, and told whose it is" \
	"$rigRc $( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'runs only as magic-coordinator' )" "1 1"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SUPERVISE HANDS CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'SUPERVISE_HANDS: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
