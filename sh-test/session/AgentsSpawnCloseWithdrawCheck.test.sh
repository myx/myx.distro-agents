#!/usr/bin/env bash
## Behavioural check on a run that ends with questions of its own still open, run rather than read: through the
## real spawn proxy on a stand-in console that asks, the real session list, and the real withdraw of an asker.
## Held:
##   1. THE CLOSE WITHDRAWS THE RUN'S OWN QUESTIONS. When the record of a run is closed, every question that run
##      asked and that still waits is withdrawn through the one withdraw an asker has (--settle-pending-reply
##      --withdraw): its record is closed as withdrawn, by the member that asked it, with the reason of the note
##      template's `# Reasons`, and no `reply-pending` record of the run's own is left in the store.
##   2. A QUESTION THE TOOLING ASKED ABOUT THE RUN IS NOT THE RUN'S. A review prompt (kind `review`) carries that
##      run's id as its asking session and still takes an answer: the close leaves it open.
##   3. THE STATE FOLLOWS THE STORE, AND NOTHING IS HIDDEN. The session reads waiting on that still-open question
##      though its only run has finished -- an ask left by a finished run is not ignored by the reader -- and it
##      reads finished, and out of the active ones, once nothing waits: the close withdrew the run's own question,
##      the check withdraws the review prompt, and the store holds no open ask at all.
##   4. THE WORDS ARE THE TEMPLATE'S: the withdraw reason of the run's own question is the line of
##      sh-lib/templates/tooling-note.post.format.md, `Reasons/asker-ended`, and no line of code holds it.
## Offline: a fake ps first on PATH answers the whole-host listing from the rig's own list, which holds no line, so
## no run of this rig is ever seen as a live process, and hands every other call to the real ps; a fake uptime gives
## the rig's own figure. The console is a stand-in, never a real CLI: it asks its questions through the real
## tooling and writes the deliverable. No Slack call is made, since the questions were recorded with no post of
## their own to read. The sandbox, the board and the workspace are this rig's own temp tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigNote="tooling-note.post.format.md"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
## A spawn of this rig that is not waited for starts the control thread of its session, a detached process that
## outlives this check: the rig ends it, before its tree is removed.
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSpawnCloseWithdrawCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
rigAgents="$rigWs/.local/agents" ; rigPend="$rigAgents/pending" ; rigFn="$rigTool"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigWs/source/rigrepo/rigpkg" "$rigHome" "$rigSkills/rig-member" "$rigData/board/running"
printf 'SLACK_BOT_TOKEN=rig-not-a-token\nSPAWN_TIER_NORMAL=rig-cli\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'PRESET_CLI_SERVICE=rig-cli\n' > "$rigWs/.local/.agents/preset-rig-cli.agent.env"
printf '# rigpkg\n' > "$rigWs/source/rigrepo/rigpkg/MAGIC.md"
printf '# workspace\n' > "$rigWs/MAGIC.md"
printf '# rig routine\n' > "$rigSkills/rig-member/magic-team.rig.routine.md"
printf '# rig armed\n' > "$rigSkills/rig-member/rig-member.armed.md"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/rig-member/rig-member.basic.md"
## THE RIG'S OWN PROCESS LIST: the ps first on PATH answers the whole-host listing from the rig's file, which holds
## no line at all, so no run of this rig is ever "running", and hands every other call to the real ps.
ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
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
printf '#!/bin/sh\ncat "${0%%/*}/../uptime.line" 2> /dev/null\n' > "$rigTmp/bin/uptime"
printf ' 2:54  up 4 days,  6:19, 12 users, load averages: 1.25 1.00 1.00\n' > "$rigTmp/uptime.line"
chmod +x "$rigTmp/bin/ps" "$rigTmp/bin/uptime"

## THE STAND-IN CONSOLE: it asks two questions of its own session and ends. The first is its own, of kind
## `question`, and the close of its record withdraws it; the second is a review prompt about the run, of kind
## `review`, which carries the same asking id and must still take an answer.
cat > "$rigWs/DistroAgentsConsole.sh" <<'RIGCLI'
#!/bin/sh
## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli)
cat > /dev/null
[ -z "$MDAT_SPAWN_LAUNCH_MARKER" ] || printf '%s\n' "rig-cli" > "$MDAT_SPAWN_LAUNCH_MARKER"
printf '%s\n' "$MDAT_SPAWN_SESSION_ID" > "$RIG_TMP/run-id"
printf '# Ask\n\nMay I?\n' | bash "$RIG_FN" --intern-op-pending-reply-open rig-member --to CRIG00001 \
	--session-id "$MDAT_SPAWN_SESSION_ID" --kind question --address-to URIGOWNER --addressees URIGOWNER \
	--asking-accounts ' URIGSELF1 ' --ask-identity member > "$RIG_TMP/ask-plain" 2> "$RIG_TMP/ask-plain.err"
printf '# Review\n\nWas it right?\n' | bash "$RIG_FN" --intern-op-pending-reply-open rig-member --to CRIG00001 \
	--session-id "$MDAT_SPAWN_SESSION_ID" --kind review --address-to human-owner --addressees URIGOWNER \
	--asking-accounts ' URIGSELF1 ' --ask-identity bot > "$RIG_TMP/ask-review" 2> "$RIG_TMP/ask-review.err"
: > "$RIG_TMP/asked-while-running"
for askId in "$( cat "$RIG_TMP/ask-plain" 2> /dev/null )" "$( cat "$RIG_TMP/ask-review" 2> /dev/null )" ; do
	LC_ALL=C sed -n -e 's/^status: /status: /p' -e 's/^session-id: /session-id: /p' -e 's/^kind: /kind: /p' \
		"$MMDAPP/.local/agents/pending/$askId.md" 2> /dev/null | LC_ALL=C tr '\n' ' ' >> "$RIG_TMP/asked-while-running"
	echo >> "$RIG_TMP/asked-while-running"
done
echo deliverable > "$MDAT_SPAWN_SANDBOX_ROOT/output/result.txt"
RIGCLI
chmod +x "$rigWs/DistroAgentsConsole.sh"

## ONE CALL OF THE TOOLING IN THE RIG, its stdout in stdin order and its stderr dropped: the same `env -i` the
## checks of this package use, so nothing of the host's own tooling reaches this rig.
rigRun(){ ## tool arguments...
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash "$rigTool" "$@" ) 2> "$rigTmp/err"
}
rigAsked(){ ## pending id, header -- its value, from the live store or from the one a close moved it to
	if [ -f "$rigPend/$1.md" ] ; then
		rigHeader "$rigPend/$1.md" "$2"
	else
		rigHeader "$rigPend/closed/$1.md" "$2"
	fi
}
rigBlockLine(){ ## block heading under `# Reasons` -- the one line of its code fence in the note template
	LC_ALL=C awk -v head="## $1" '$0 == head { on = 1 ; next } on && /^```/ { fence = ! fence ; next } on && fence && NF { print ; exit }' "$rigPackage/sh-lib/templates/$rigNote" 2> /dev/null
}
rigHeader(){ ## record file, header -- its value in the frontmatter, empty where absent
	[ -f "$1" ] || return 0
	LC_ALL=C awk -v want="$2" '$0 == "---" { if ( ++dashes > 1 ) exit ; next ; } dashes == 1 && index( $0, want ": " ) == 1 { print substr( $0, length( want ) + 3 ) ; exit ; }' "$1" 2> /dev/null
}
rigRows(){ ## row kind -- the rows of that kind in the last stdout, one a line
	LC_ALL=C awk -F'\t' -v want="$1" '$1 == want' "$rigTmp/out" 2> /dev/null
}
rigState(){ ## session id, further words of the list -- the state its session row reads, `not-listed` where it has none
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" bash "$rigTool" --manager-session-list ${2:-} ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null
	LC_ALL=C awk -F'\t' -v wantId="$1" '$1 == "session" && $2 == wantId { print $4 ; found = 1 } END { if ( ! found ) print "not-listed" }' "$rigTmp/out"
}

echo "-- 1. a run that ends with a question of its own open withdraws it --"
printf 'Work on rigrepo/rigpkg/file.sh following magic-team.rig.routine.md and rig-member.armed.md.\n' \
	| env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy rig-member --dispatch-doc:create --wait
		' > "$rigTmp/spawn.out" 2> "$rigTmp/spawn.err"
rigRunId="$( cat "$rigTmp/run-id" 2> /dev/null )"
rigPlain="$( cat "$rigTmp/ask-plain" 2> /dev/null )"
rigReview="$( cat "$rigTmp/ask-review" 2> /dev/null )"
[ -n "$rigRunId" ] && [ -n "$rigPlain" ] && [ -n "$rigReview" ] \
	|| rigRefuse "the stand-in console did not run as a session, or asked nothing: $( tail -3 "$rigTmp/spawn.err" 2> /dev/null ) $( tail -2 "$rigTmp/ask-plain.err" 2> /dev/null )"
rigRecord="$( ls "$rigAgents/spawned"/*/"$rigRunId.spawn.md" 2> /dev/null | head -1 )"
[ -n "$rigRecord" ] || rigRefuse "no spawn record was written for the run $rigRunId"
rigAssert "control: the run ended, and its record is closed" "$( rigHeader "$rigRecord" status )" "spawn-succeeded"
rigAssert "control: while it ran, the console asked two questions of it, both open, and the asker they carry is that run's own id" \
	"$( LC_ALL=C tr '\n' '/' < "$rigTmp/asked-while-running" 2> /dev/null )" \
	"status: reply-pending session-id: $rigRunId kind: question /status: reply-pending session-id: $rigRunId kind: review /"
rigAssert "the question the run asked is withdrawn through the one withdraw an asker has: closed as withdrawn, by the member that asked it, with the reason of the template" \
	"$( rigAsked "$rigPlain" status ) $( rigAsked "$rigPlain" withdrawn-by ) [$( rigAsked "$rigPlain" withdraw-reason )]" \
	"withdrawn rig-member [the run that asked it ended, so no answer is needed any more]"
rigAssert "and the reason is the template's own line: the record says what the block says" \
	"$( rigAsked "$rigPlain" withdraw-reason )" "$( rigBlockLine asker-ended )"
rigAssert "the collect that the close runs after it finds nothing of the run's own still open, as the receipt of the spawn says" \
	"$( LC_ALL=C sed -n 's/^PENDING_OPEN=//p' "$rigTmp/spawn.out" 2> /dev/null ):$( LC_ALL=C sed -n 's/^PENDING_ANSWERED=//p' "$rigTmp/spawn.out" 2> /dev/null )" "0:0"
rigAssert "no reply-pending record of the run's own is left behind: the only one still open is the review prompt about it" \
	"$( LC_ALL=C grep -l -x -F 'status: reply-pending' "$rigPend"/*.md 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ) $( rigAsked "$rigReview" status ) $( rigAsked "$rigReview" kind )" \
	"1 reply-pending review"

echo "-- 2. a question the tooling asked about the run is not the run's: it still takes an answer --"
rigAssert "the review prompt about the run is still open, with the same asking id, so a close never withdraws the question the tooling asked about a run" \
	"$( rigAsked "$rigReview" status ):$( rigAsked "$rigReview" kind ):$( rigAsked "$rigReview" session-id )" "reply-pending:review:$rigRunId"

echo "-- 3. the state follows the store: an open ask waits, and nothing is hidden --"
rigAssert "the session reads waiting on the question that still waits, though its only run has finished: a question left by a finished run is not ignored" \
	"$( rigState "$rigRunId" ) $( rigState "$rigRunId" --active ) $( rigHeader "$rigRecord" status )" "waiting waiting spawn-succeeded"
rigAssert "and the counters count that one open ask, from the store" "$( rigRows counters | LC_ALL=C awk '{ print $6 }' ) $( LC_ALL=C grep -l -x -F 'status: reply-pending' "$rigPend"/*.md 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "1 1"
( rigRun --settle-pending-reply rig-member "$rigReview" --reason "the review prompt no longer needs an answer in this check" --withdraw ) > /dev/null 2>&1 || :
rigAssert "the review prompt is withdrawn by the one withdraw, and the store holds no open ask at all" \
	"$( rigAsked "$rigReview" status ) $( LC_ALL=C grep -l -x -F 'status: reply-pending' "$rigPend"/*.md 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "withdrawn 0"
rigAssert "the same session now reads finished, and has left the active ones, because nothing waits -- not because a reader ignores an open ask" \
	"$( rigState "$rigRunId" ) $( rigState "$rigRunId" --active ) $( rigRows counters | LC_ALL=C awk '{ print $6 }' )" "finished not-listed 0"

echo "-- 4. the words are the template's --"
rigAssert "the reason block exists in the note template, once, and its line is not written in the tooling" \
	"$( LC_ALL=C grep -c -x -F '## asker-ended' "$rigPackage/sh-lib/templates/$rigNote" ) $( LC_ALL=C grep -c -x -F 'the run that asked it ended, so no answer is needed any more' "$rigPackage/sh-lib/templates/$rigNote" ) $( cat "$rigPackage"/sh-lib/*/*.include "$rigPackage"/sh-lib/*/*.sh 2> /dev/null | LC_ALL=C grep -v '^[[:space:]]*#' | LC_ALL=C grep -c -F 'the run that asked it ended' || : )" "1 1 0"

if [ "$rigFails" -gt 0 ] ; then
	echo "⛔ AGENT SPAWN CLOSE WITHDRAW CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2
	exit 1
fi
echo "AGENT SPAWN CLOSE WITHDRAW: OK ($rigPasses assertions, offline)"
