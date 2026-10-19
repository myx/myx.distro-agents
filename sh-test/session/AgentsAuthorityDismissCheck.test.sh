#!/usr/bin/env bash
## Behavioural check on the authority to dismiss a session or one of its runs (F6.10 of the refactorings epic): it is
## held by the run's reports-to (F6.8), for a whole session by its founding run's reports-to; by the owners role at the
## top of every chain (F6.11); and by anyone the owners role grants it to by a recorded permission. A person at a
## console acts as `user-<account>`, never as the owners role: an account mapped to an owner only sends a confirmation
## to that owner's authenticated channel. Without the authority the operation fails by default, naming the authority
## it needs and its two options: `--escalate-wait [--timeout <s>]` (no timeout by default; exit 0 approved and acted,
## 1 denied, 124 at the timeout) and `--escalate-enqueue` (`PENDING <id>` on its first line, exit 0). A served tool, TaskStop or
## a SendMessage with DISMISSED, answers with the same first lines as the console.
## The mapping of a console account to an owner is one rig setting (rigOwnerKey, below), the only place its name is
## spelled, until the owner names the real one.
## Held, through --manager-session-kill (the console) and the served TaskStop and SendMessage of a member's run:
##   1. the console caller who is the founding run's reports-to ends the session at once
##   2. a console caller who is not: the bare call fails, naming the authority and both options; every run lives
##   3. --escalate-enqueue: PENDING, a request to the founding run's reports-to; every run lives
##   4. --run of one run that reports to the owners role: enqueued, the request goes to human-owner; the run lives
##   5. a console account mapped to an owner: the run lives until the owner confirms in its own channel, then it ends
##   6. --escalate-wait: approved by the holder, exit 0 and the run is gone; at --timeout, exit 124 and the run lives
##   7. TaskStop from a member's run that is not the target's reports-to: refused with the same lines; with
##      `escalate: "enqueue"`, as the console's --escalate-enqueue, PENDING; from the reports-to, the target is stopped
##   8. a DISMISSED SendMessage from a member's run that is not the target's reports-to: refused and not posted; from
##      the reports-to it is posted
##   9. a deploy-like script, a stand-in of this rig, that calls an operation needing the authority with
##      --escalate-wait: it waits there; approved, it goes on to its next step; denied, it stops with exit 1 and its
##      next step never runs
## Red before F6.10: the console and any member's run end or dismiss any run at once (2-8 fail but the controls).
## Offline: a Slack-shaped fake curl first on PATH; every run is a stand-in process of this rig carrying its own spawn
## id, which no other process carries; everything runs in a workspace under this check's temp tree.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTools="${rigHere%/sh-lib}/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
## THE ONE PLACE the setting that maps a console account to an owner is named.
rigOwnerKey="HUMAN_OWNER_CONSOLE_ACCOUNT"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTools" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTools"
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin this workspace resolves: $rigHarness"
## The one way a check signals a process it started: sourced before the rig puts anything on PATH.
. "$rigTest/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsAuthorityDismissCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigRunPids="" rigKept=""
trap 'rigProcSignal KILL $rigRunPids ; rigProcGroupSignal KILL $rigKept ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/served" "$rigTmp/skills"
cp "$rigTest/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTmp/served/curl" && chmod +x "$rigTmp/served/curl" || rigRefuse "the fake curl fixture is missing from the package"
for rigModel in claude codex ; do
	printf '#!/bin/sh\necho "%s $*" >> "%s/model-calls"\nexit 1\n' "$rigModel" "$rigTmp" > "$rigTmp/served/$rigModel"
done
chmod +x "$rigTmp/served/"*
for rigName in magic-coordinator magic-tester keeper-myx ; do
	mkdir -p "$rigTmp/skills/$rigName"
	printf -- '---\nmaintainers: rig\n---\n%s\n' "$rigName" > "$rigTmp/skills/$rigName/$rigName.basic.md"
done

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## ---------------------------------------------------------------- the workspace, its sessions and runs
rigAcct="$( id -un 2>/dev/null )" || rigAcct=""
rigAcct="$( printf '%s' "$rigAcct" | LC_ALL=C tr -s ' \t\r\n' '_' )"
[ -n "$rigAcct" ] || rigAcct="unknown"
rigWs="$rigTmp/ws"
rigData="$rigWs/DATA"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned" "$rigWs/.local/agents/sessions" "$rigData/board/running"
rigHost="$( hostname -s 2>/dev/null || echo unknown )"
rigTag="${rigTmp##*.}"
rigMapOwnerTo(){ ## account -- the console account an owner is mapped to
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\n%s=%s\n' "$rigOwnerKey" "$1" > "$rigWs/.local/.agents/magic-team.agent.env"
}
rigMapOwnerTo rig-owner-account
rigThreadOf(){ ## session
	printf 'CAUTH0001:1700000002.0002%02d' "$( printf '%s' "$1" | LC_ALL=C cksum | LC_ALL=C awk '{ print $1 % 100 }' )"
}
rigRunNo=0
rigRun(){ ## variable to set, session, member, start-context, reports-to (empty: none) -- a run: its record and its live process
	local runId
	rigRunNo=$(( rigRunNo + 1 ))
	runId="rig-auth-run-$rigTag-$rigRunNo-$RANDOM"
	mkdir -p "$rigWs/.local/agents/spawned/$2" "$rigWs/.local/agents/sessions/$2"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\nstart-context: %s\n%shost: %s\nowner: %s\nstatus: spawn-started\nsession-thread: %s\n---\n' \
		"$2" "$runId" "$4" "${5:+reports-to: $5$'\n'}" "$rigHost" "$3" "$( rigThreadOf "$2" )" > "$rigWs/.local/agents/spawned/$2/$runId.md"
	rigThreadOf "$2" > "$rigWs/.local/agents/sessions/$2/session.thread"
	perl -e 'sleep 600' -- --session-id "$runId" > /dev/null 2>&1 &
	eval "${1}Pid=\$!"
	rigRunPids="$rigRunPids $!" ; rigProcNote "$!" ; disown "$!" 2> /dev/null || :
	eval "$1=\$runId"
}
rigAlive(){ ## pid
	kill -0 "$1" 2> /dev/null && printf alive || printf gone
}
rigMarked(){ ## session, run id -- whether its record says it was killed
	LC_ALL=C grep -q '^killed-by: ' "$rigWs/.local/agents/spawned/$1/$2.md" 2> /dev/null && printf marked || printf unmarked
}
rigEnv=( MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigTmp/skills" RIG_SCENARIO="$rigTmp" RIG_CURL_LOG="$rigTmp/curl.log" )
rigOpRc=0
rigOp(){ ## operation and its arguments, as the console calls them -- out in $rigTmp/op.out, rc in rigOpRc
	rigOpRc=0
	( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_ID -u harnessAgent -u harnessSessionId \
		PATH="$rigTmp/served:$PATH" "${rigEnv[@]}" bash "$rigTools" "$@" ) > "$rigTmp/op.out" 2> "$rigTmp/op.err" < /dev/null || rigOpRc=$?
}
rigMemberOp(){ ## run id, member, operation and its arguments -- the same, as a member's run calls it
	local memberRun="$1" memberName="$2" ; shift 2
	rigOpRc=0
	( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID PATH="$rigTmp/served:$PATH" "${rigEnv[@]}" MDAT_SPAWN_SESSION_ID="$memberRun" MDAT_SPAWN_AGENT="$memberName" \
		bash "$rigTools" "$@" ) > "$rigTmp/op.out" 2> "$rigTmp/op.err" < /dev/null || rigOpRc=$?
}
rigCall(){ ## caller run id, its member, its session, tool, arguments JSON -- one served call of a member's run, out in $rigTmp/op.out
	rigOpRc=0
	( cd "$rigWs" && printf '%s' "$5" | env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u ANTHROPIC_API_KEY -u OPENAI_API_KEY -u MDAT_SPAWN_CALLER_WAITS \
		PATH="$rigTmp/served:/usr/bin:/bin" MDLT_ORIGIN="$MDLT_ORIGIN" "${rigEnv[@]}" MDAT_SESSION_ID="$3" MDAT_SESSION_THREAD="$( rigThreadOf "$3" )" MDAT_SPAWN_SESSION_ID="$1" MDAT_SPAWN_AGENT="$2" \
		bash "$rigHarness" --intern-tool "$4" ) > "$rigTmp/op.out" 2> "$rigTmp/op.err"
}
rigField(){ ## file, field
	LC_ALL=C awk -F': ' -v wantField="$2" '$1 == wantField { print substr( $0, length( wantField ) + 3 ) ; exit ; }' "$1" 2>/dev/null
}
rigRecordOf(){ ## pending id -- its record, wherever its subsystem keeps it under .local
	[ -n "$1" ] || return 0
	find "$rigWs/.local" -type f -name "$1.md" 2> /dev/null | head -1
}
rigPendingId(){ LC_ALL=C sed -n '1s/^PENDING \([^ ]*\).*/\1/p' "$rigTmp/op.out" ; }
rigAddressed(){ ## pending id -- who that request is addressed to, or none
	local addressedFile
	addressedFile="$( rigRecordOf "$1" )"
	[ -n "$addressedFile" ] && rigField "$addressedFile" address-to || printf none
}
## The refusal of a bare call: `refused:names-it:wait:enqueue` where it failed naming the authority and both options.
rigRefusal(){ ## authority it must name, exit status to read (default: rigOpRc)
	local refusalText refusalRc="${2:-$rigOpRc}"
	refusalText="$( cat "$rigTmp/op.out" "$rigTmp/op.err" 2> /dev/null )"
	printf '%s' "$refusalText" | LC_ALL=C grep -q -F -- '--escalate-enqueue' || [ "$refusalRc" -ne 0 ] || { printf 'acted' ; return 0 ; }
	printf 'refused:%s:%s:%s' "$( printf '%s' "$refusalText" | LC_ALL=C grep -q -F -- "$1" && printf names-it || printf names-not )" \
		"$( printf '%s' "$refusalText" | LC_ALL=C grep -q -F -- '--escalate-wait' && printf wait || printf no-wait )" \
		"$( printf '%s' "$refusalText" | LC_ALL=C grep -q -F -- '--escalate-enqueue' && printf enqueue || printf no-enqueue )"
}
rigSeen=""
rigSeenMark(){ rigSeen=" $( find "$rigWs/.local" -type f -name '*.md' 2> /dev/null | LC_ALL=C tr '\n' ' ' )" ; }
rigNewRequest(){ ## -- the id of a request record made since rigSeenMark, whose address-to is set
	local newFile
	for newFile in $( find "$rigWs/.local" -type f -name '*.md' 2> /dev/null ) ; do
		case "$rigSeen" in *" $newFile "*) continue ;; esac
		[ -n "$( rigField "$newFile" address-to )" ] || continue
		basename "$newFile" .md ; return 0
	done
}
rigHasNew(){ [ -n "$( rigNewRequest )" ] ; }
rigBg(){ ## operation and its arguments -- the console's call in the background, as a group of its own: its pid in rigBgPid
	set -m
	( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_ID -u harnessAgent -u harnessSessionId \
		PATH="$rigTmp/served:$PATH" "${rigEnv[@]}" bash "$rigTools" "$@" ; printf '%s' "$?" > "$rigTmp/bg.rc" ) > "$rigTmp/bg.out" 2> "$rigTmp/bg.err" < /dev/null &
	rigBgPid=$! ; rm -f "$rigTmp/bg.rc" ; rigBgRc="$rigTmp/bg.rc"
	set +m
	rigProcNote "$rigBgPid" ; rigKept="$rigKept $rigBgPid"
}
rigBgEnd(){ ## pid, guard seconds -- its exit status once it ends, `still-running` where the guard ran out first
	local endLeft="$2" endRc=0
	while [ -n "$( rigProcStill "$1" )" ] && [ "$endLeft" -gt 0 ] ; do sleep 1 ; endLeft=$(( endLeft - 1 )) ; done
	if [ -n "$( rigProcStill "$1" )" ] ; then
		rigProcGroupSignal TERM "$1" ; sleep 1 ; rigProcGroupSignal KILL "$1"
		wait "$1" 2> /dev/null || :
		printf still-running ; return 0
	fi
	wait "$1" 2> /dev/null || endRc=$?
	## Called in a $( ) subshell, whose wait cannot read the status of its parent's job: the call kept its own.
	[ ! -s "${rigBgRc:-/nonexistent}" ] || endRc="$( cat "$rigBgRc" )"
	printf '%s' "$endRc"
}
rigWaitFor(){ ## seconds, test command...
	local waitLeft="$1" ; shift
	while ! "$@" && [ "$waitLeft" -gt 0 ] ; do sleep 1 ; waitLeft=$(( waitLeft - 1 )) ; done
}
rigSettle(){ sleep 2 ; }
## The magic-coordinator's own run, the holder of the requests below: it answers one.
rigRun rigHolder "rig-auth-holder-$rigTag" magic-coordinator spawned human-owner
rigHolderAnswers(){ ## request id, verdict
	rigMemberOp "$rigHolder" magic-coordinator --magic-escalation-answer magic-coordinator "${1:-none}" "$2"
}

echo "-- 1. the console caller who is the founding run's reports-to ends the session at once --"
rigS1="rig-auth-own-$rigTag"
rigRun rigOwnFounder "$rigS1" magic-coordinator spawned "user-$rigAcct"
rigRun rigOwnMember "$rigS1" keeper-myx joined magic-coordinator
rigOp --manager-session-kill --session-id "$rigS1"
rigSettle
rigAssert "exit 0, no PENDING, both runs gone"                "$rigOpRc:$( rigPendingId ):$( rigAlive "$rigOwnFounderPid" ):$( rigAlive "$rigOwnMemberPid" )" "0::gone:gone"
[ "$( rigAlive "$rigOwnFounderPid" )" = gone ] || rigRefuse "the console's kill ended no run, so nothing below would be measured: $( head -3 "$rigTmp/op.err" | LC_ALL=C tr '\n' ' ' )"

echo "-- 2. a console caller who is not: the bare call fails, every run lives --"
rigS2="rig-auth-coord-$rigTag"
rigRun rigFounder "$rigS2" keeper-myx spawned magic-coordinator
rigRun rigMember "$rigS2" magic-tester joined "user-$rigAcct"
rigOp --manager-session-kill --session-id "$rigS2"
rigSettle
rigAssert "refused, naming the founding run's reports-to and both options" "$( rigRefusal magic-coordinator )" "refused:names-it:wait:enqueue"
rigAssert "both runs live, and neither record is marked"      "$( rigAlive "$rigFounderPid" ):$( rigAlive "$rigMemberPid" ):$( rigMarked "$rigS2" "$rigFounder" ):$( rigMarked "$rigS2" "$rigMember" )" "alive:alive:unmarked:unmarked"

echo "-- 3. --escalate-enqueue: PENDING, a request to the founding run's reports-to, every run lives --"
rigOp --manager-session-kill --session-id "$rigS2" --escalate-enqueue
rigSettle
rigAssert "PENDING, exit 0, a request to magic-coordinator"   "$rigOpRc:$( rigAddressed "$( rigPendingId )" )" "0:magic-coordinator"
rigAssert "both runs live"                                    "$( rigAlive "$rigFounderPid" ):$( rigAlive "$rigMemberPid" )" "alive:alive"

echo "-- 4. --run of a run that reports to the owners role: the request goes to human-owner --"
rigS4="rig-auth-owner-$rigTag"
rigRun rigOwned "$rigS4" keeper-myx spawned human-owner
rigOp --manager-session-kill --session-id "$rigOwned" --run --escalate-enqueue
rigSettle
rigAssert "PENDING, a request to human-owner"                 "$rigOpRc:$( rigAddressed "$( rigPendingId )" )" "0:human-owner"
rigAssert "the run lives"                                     "$( rigAlive "$rigOwnedPid" )" alive

echo "-- 5. a console account mapped to an owner: the run ends only once the owner confirms in its own channel --"
rigMapOwnerTo "$rigAcct"
rigRun rigOwned5 "$rigS4" keeper-myx spawned human-owner
rm -f "$rigTmp"/post.* "$rigTmp/posts"
rigSeenMark
rigOp --manager-session-kill --session-id "$rigOwned5" --run
rigSettle
rigConfirm="$( rigNewRequest )"
rigAssert "not at once: the run lives"                        "$( rigAlive "$rigOwned5Pid" )" alive
rigAssert "a confirmation is made and posted to the owner's own channel" "$( [ -n "$rigConfirm" ] && printf made || printf none ):$( cat "$rigTmp"/post.* 2> /dev/null | LC_ALL=C grep -c -F 'URIGOWNER' | LC_ALL=C awk '{ print ( $1 >= 1 ) ? "posted" : "not-posted" }' )" "made:posted"
rigConfirmTs="$( rigField "$( rigRecordOf "$rigConfirm" )" question-ts 2> /dev/null )"
[ -z "$rigConfirmTs" ] || printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGBOT01","text":"Confirm?"},{"ts":"1700000600.000001","user":"URIGOWNER","text":"yes","thread_ts":"%s"}],"has_more":false}\n' "$rigConfirmTs" "$rigConfirmTs" > "$rigTmp/replies.$rigConfirmTs.json"
rigOp --intern-op-pending-reply-collect --ended --context rig-authority
rigSettle
rigAssert "the owner confirms in Slack: then the run is gone" "$( rigAlive "$rigOwned5Pid" )" gone
rigMapOwnerTo rig-owner-account

echo "-- 6. --escalate-wait: approved by the holder, or the timeout --"
rigS6="rig-auth-wait-$rigTag"
rigRun rigWaited "$rigS6" keeper-myx spawned magic-coordinator
rigSeenMark
rigBg --manager-session-kill --session-id "$rigWaited" --run --escalate-wait
rigWaitFor 20 rigHasNew
rigW1="$( rigNewRequest )"
rigAssert "it waits, its request made, the run alive"         "$( [ -n "$rigW1" ] && [ -n "$( rigProcStill "$rigBgPid" )" ] && printf waiting || printf not-waiting ):$( rigAlive "$rigWaitedPid" )" "waiting:alive"
rigHolderAnswers "$rigW1" allow-once
rigAssert "approved by the holder: exit 0"                    "$( rigBgEnd "$rigBgPid" 30 )" 0
rigSettle
rigAssert "and acted: the run is gone"                        "$( rigAlive "$rigWaitedPid" )" gone
rigRun rigWaited2 "$rigS6" keeper-myx spawned magic-coordinator
rigSeenMark
rigBg --manager-session-kill --session-id "$rigWaited2" --run --escalate-wait --timeout 4
sleep 2
rigAssert "it waits, its request made"                        "$( [ -n "$( rigNewRequest )" ] && [ -n "$( rigProcStill "$rigBgPid" )" ] && printf waiting || printf not-waiting )" waiting
rigAssert "no answer: exit 124 at the timeout"                "$( rigBgEnd "$rigBgPid" 30 )" 124
rigAssert "and the run lives"                                 "$( rigAlive "$rigWaited2Pid" )" alive

echo "-- 7. TaskStop from a member's run: refused with the same lines unless it is the target's reports-to --"
rigS7="rig-auth-stop-$rigTag"
rigRun rigLead "$rigS7" magic-coordinator spawned human-owner
rigRun rigTarget "$rigS7" magic-tester joined magic-coordinator
rigRun rigBystander "$rigS7" keeper-myx joined magic-coordinator
rigCall "$rigBystander" keeper-myx "$rigS7" TaskStop "{\"task_id\":\"$rigTarget\"}"
rigSettle
rigAssert "from a member that is not its reports-to: refused, as the console is" "$( rigRefusal magic-coordinator 1 )" "refused:names-it:wait:enqueue"
rigAssert "and the target lives"                              "$( rigAlive "$rigTargetPid" )" alive
rigCall "$rigBystander" keeper-myx "$rigS7" TaskStop "{\"task_id\":\"$rigTarget\",\"escalate\":\"enqueue\"}"
rigSettle
rigAssert "with escalate: "enqueue", as the console's --escalate-enqueue: PENDING, a request to the reports-to" "$( rigAddressed "$( rigPendingId )" )" magic-coordinator
rigAssert "and the target still lives"                        "$( rigAlive "$rigTargetPid" )" alive
rigRun rigTarget7 "$rigS7" magic-tester joined magic-coordinator
rigCall "$rigLead" magic-coordinator "$rigS7" TaskStop "{\"task_id\":\"$rigTarget7\"}"
rigSettle
rigAssert "from its reports-to: stopped, no PENDING"          "$( rigPendingId ):$( rigAlive "$rigTarget7Pid" )" ":gone"

echo "-- 8. a DISMISSED from a member's run: refused and not posted unless from the target's reports-to --"
rm -f "$rigTmp"/post.* "$rigTmp/posts"
rigCall "$rigBystander" keeper-myx "$rigS7" SendMessage "{\"to\":\"session-current\",\"address_to\":\"magic-tester\",\"message\":\"DISMISSED\"}"
rigAssert "from a member that is not its reports-to: not posted, refused as the console is" \
	"$( cat "$rigTmp"/post.* 2> /dev/null | LC_ALL=C grep -c 'DISMISSED' ):$( rigRefusal magic-coordinator 1 )" "0:refused:names-it:wait:enqueue"
rm -f "$rigTmp"/post.* "$rigTmp/posts"
rigCall "$rigLead" magic-coordinator "$rigS7" SendMessage "{\"to\":\"session-current\",\"address_to\":\"magic-tester\",\"message\":\"DISMISSED\"}"
rigAssert "from its reports-to: posted"                       "$( cat "$rigTmp"/post.* 2> /dev/null | LC_ALL=C grep -c 'DISMISSED' )" 1

echo "-- 9. a deploy-like script waits for the approval, and goes on only once approved --"
## The stand-in deploy: one step needing the authority, waited for, then its next step.
printf '#!/usr/bin/env bash\nbash "$RIG_TOOLS" --manager-session-kill --session-id "$1" --run --escalate-wait --timeout 60 || exit $?\necho DEPLOY-NEXT-STEP\n' > "$rigTmp/deploy.rig.sh"
rigDeploy(){ ## run id -- the stand-in deploy in the background, as a group of its own: its pid in rigBgPid
	set -m
	( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_ID -u harnessAgent -u harnessSessionId \
		PATH="$rigTmp/served:$PATH" "${rigEnv[@]}" RIG_TOOLS="$rigTools" bash "$rigTmp/deploy.rig.sh" "$1" ; printf '%s' "$?" > "$rigTmp/deploy.rc" ) > "$rigTmp/deploy.out" 2> "$rigTmp/deploy.err" < /dev/null &
	rigBgPid=$! ; rm -f "$rigTmp/deploy.rc" ; rigBgRc="$rigTmp/deploy.rc"
	set +m
	rigProcNote "$rigBgPid" ; rigKept="$rigKept $rigBgPid"
}
rigS9="rig-auth-deploy-$rigTag"
rigRun rigDeployed "$rigS9" keeper-myx spawned magic-coordinator
rigSeenMark
rigDeploy "$rigDeployed"
rigWaitFor 20 rigHasNew
rigAssert "it waits at that step, its request made"           "$( [ -n "$( rigNewRequest )" ] && [ -n "$( rigProcStill "$rigBgPid" )" ] && printf waiting || printf not-waiting ):$( LC_ALL=C grep -c DEPLOY-NEXT-STEP "$rigTmp/deploy.out" )" "waiting:0"
rigHolderAnswers "$( rigNewRequest )" allow-once
rigAssert "approved: it goes on to its next step, exit 0"     "$( rigBgEnd "$rigBgPid" 30 ):$( LC_ALL=C grep -c DEPLOY-NEXT-STEP "$rigTmp/deploy.out" )" "0:1"
rigRun rigDeployed2 "$rigS9" keeper-myx spawned magic-coordinator
rigSeenMark
rigDeploy "$rigDeployed2"
rigWaitFor 20 rigHasNew
rigHolderAnswers "$( rigNewRequest )" deny
rigAssert "denied: it stops with exit 1, its next step never run" "$( rigBgEnd "$rigBgPid" 30 ):$( LC_ALL=C grep -c DEPLOY-NEXT-STEP "$rigTmp/deploy.out" )" "1:0"
rigAssert "and the run lives"                                 "$( rigAlive "$rigDeployed2Pid" )" alive

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ AUTHORITY DISMISS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'AUTHORITY_DISMISS: OK (%d assertions, offline)\n' "$rigPassCount"
