#!/usr/bin/env bash
## Behavioural check on arm-before-acting (6127) in the harness's own model loop: in a
## spawned session a mutating call is redirected until the member's duty file has been
## read to its end with Skill; read-only calls never are; only a read reaching the last
## line arms; the redirect is posted to event-track once; the spawn's close record says
## armed yes, no or unknown. A served call and a loop with no spawn id are never gated.
## Offline: a fake curl replays canned model rounds and answers Slack; every run goes
## through one `env -i` whose child refuses to start outside this rig's mktemp tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="rig-member"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found: $rigHarness"
rigTmp="$( mktemp -d -t AgentsHarnessArmGateCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigTmp/skills/$rigMember"
cp "$rigTest/check-fixtures/harness-arm-gate.curl.test.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
## The duty file: ten short lines, so a range ending on the last one is line 10.
LC_ALL=C awk 'BEGIN { for ( lineNo = 1 ; lineNo <= 10 ; lineNo++ ) printf "rig duty line %d\n", lineNo ; }' > "$rigTmp/skills/$rigMember/$rigMember.armed.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigYes(){ "$@" && printf yes || printf no ; }

rigDir=""
rigRounds=0
rigScenario(){ ## name
	rigDir="$rigTmp/$1"
	mkdir -p "$rigDir/ws/.local/.agents" "$rigDir/ws/OUT" "$rigDir/sandbox/input" "$rigDir/sandbox/output"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-not-a-token\n' > "$rigDir/ws/.local/.agents/magic-team.agent.env"
	printf '0' > "$rigDir/round"
	: > "$rigDir/curl.log"
	rigRounds=0
}
## The next canned round: one tool call, or plain text ending the run.
rigCall(){ ## tool name, arguments JSON
	rigRounds=$(( rigRounds + 1 ))
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"rig-call-%s","type":"function","function":{"name":"%s","arguments":"%s"}}]},"finish_reason":null}]}\n' \
		"$rigRounds" "$1" "$( printf '%s' "$2" | sed 's/\\/\\\\/g; s/"/\\"/g' )" > "$rigDir/res.$rigRounds"
	printf 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\n' >> "$rigDir/res.$rigRounds"
	printf 'data: [DONE]\n' >> "$rigDir/res.$rigRounds"
}
rigEnd(){
	rigRounds=$(( rigRounds + 1 ))
	printf 'data: {"choices":[{"index":0,"delta":{"content":"RIG-DONE"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\ndata: [DONE]\n' > "$rigDir/res.$rigRounds"
}
## The model loop, guarded. A spawn id is set unless the scenario asks for none.
rigLoop(){ ## spawn id or empty
	env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" ${1:+MDAT_SPAWN_SESSION_ID="$1"} MDAT_SPAWN_SANDBOX_ROOT="$rigDir/sandbox" \
		RIG_SCENARIO="$rigDir" RIG_CURL_LOG="$rigDir/curl.log" RIG_TMP="$rigTmp" RIG_HARNESS="$rigHarness" \
		HARNESS_PROVIDER_NAME="arm-gate rig" HARNESS_SELF_NAME="AgentsHarnessArmGateCheck.test.sh" \
		HARNESS_ENDPOINT="https://harness-arm-gate-check.invalid/v1/chat/completions" HARNESS_HOST="harness-arm-gate-check.invalid" \
		HARNESS_WIRE="OpenAiChat" HARNESS_CREDENTIAL_NAMES="none" HARNESS_MODEL_LIGHT="rig-light" HARNESS_MODEL_MAIN="rig-main" \
		HARNESS_TOKEN_LIGHT="rig-not-a-credential" HARNESS_TOKEN_MAIN="rig-not-a-credential" MDAT_HARNESS_CONTEXT_TOKENS=0 MDAT_HARNESS_MAX_RESTARTS=1 \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac
			case "$( command -v curl )" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: curl is not the rig fake" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_HARNESS" --access-read-root "$MMDAPP" --access-read-root "$MDAT_SKILLSET_ROOT" --access-write-root "$MMDAPP/OUT" --agent rig-member RIG-TASK
		' > "$rigDir/out" 2> "$rigDir/err"
	[ "$( cat "$rigDir/round" )" != 0 ] || rigRefuse "the harness made no model request: $( tail -3 "$rigDir/err" )"
}
## The newest tool result in the request for round N+1, which answers round N's call.
rigResult(){ ## round whose call it answers
	LC_ALL=C awk '
		{
			restText = $0 ;
			while ( ( roleAt = index( restText, "\"role\":\"tool\"" ) ) > 0 ) {
				restText = substr( restText, roleAt + 13 ) ;
				contentAt = index( restText, "\"content\":\"" ) ;
				if ( contentAt > 0 ) { lastText = substr( restText, contentAt + 11, 400 ) ; }
			}
		}
		END { print lastText ; }
	' "$rigDir/req.$(( $1 + 1 ))" 2>/dev/null
}
rigRedirected(){ ## round
	case "$( rigResult "$1" )" in "ERROR: read your duty file first: Skill name=$rigMember file=$rigMember.armed.md"*) printf yes ;; *) printf no ;; esac
}

echo "-- a spawned loop: gated until the duty file is read to its end --"
rigScenario arm
rigCall Write "{\"path\":\"$rigTmp/arm/ws/OUT/a.txt\",\"content\":\"rig\"}"
rigCall Read "{\"path\":\"$rigTmp/skills/$rigMember/$rigMember.basic.md\"}"
rigCall Glob "{\"pattern\":\"*.md\",\"path\":\"$rigTmp/skills/$rigMember\"}"
rigCall mcp__rig__Write "{\"path\":\"$rigTmp/arm/ws/OUT/m.txt\",\"content\":\"rig\"}"
rigCall mcp__rig__SendMessage "{\"to\":\"magic-team\",\"message\":\"rig\"}"
rigCall Skill "{\"name\":\"$rigMember\",\"file\":\"$rigMember.armed.md\"}"
rigCall Write "{\"path\":\"$rigTmp/arm/ws/OUT/a.txt\",\"content\":\"rig\"}"
rigCall mcp__rig__Write "{\"path\":\"$rigTmp/arm/ws/OUT/m.txt\",\"content\":\"rig\"}"
rigEnd
rigLoop rig-session-arm
rigAssert "the loop wrote its .harness marker"         "$( rigYes test -e "$rigDir/sandbox/rig-session-arm.harness" )" yes
rigAssert "an unarmed Write is redirected"             "$( rigRedirected 1 )" yes
rigAssert "a Read is not redirected"                   "$( rigRedirected 2 )" no
rigAssert "a Glob is not redirected"                   "$( rigRedirected 3 )" no
rigAssert "an unarmed mcp__*__Write is redirected"     "$( rigRedirected 4 )" yes
rigAssert "an unarmed mcp__*__SendMessage is redirected" "$( rigRedirected 5 )" yes
rigAssert "after a full read, the Write lands"         "$( cat "$rigDir/ws/OUT/a.txt" 2>/dev/null )" rig
rigAssert "and mcp__*__Write is no longer redirected"  "$( rigRedirected 8 )" no
rigAssert "the .armed file holds when"                 "$( rigYes test -s "$rigDir/sandbox/rig-session-arm.armed" )" yes
rigAssert "the redirects were posted to event-track once" "$( LC_ALL=C grep -c 'Unarmed call redirected' "$rigDir/slack.bodies" 2>/dev/null || : )" 1
rigAssert "naming the member and the tool"             "$( rigYes env LC_ALL=C grep -q -F "*$rigMember* · refusal · \`rig-sess\`\\nwhat: Unarmed call redirected\\ntool: \`Write\`" "$rigDir/slack.bodies" )" yes

echo "-- what counts as arming: ranges must cover every line --"
rigScenario ranged
rigCall Skill "{\"name\":\"$rigMember\",\"file\":\"$rigMember.armed.md\",\"offset\":10,\"limit\":1}"
rigCall Write "{\"path\":\"$rigTmp/ranged/ws/OUT/r.txt\",\"content\":\"rig\"}"
rigCall Skill "{\"name\":\"$rigMember\",\"file\":\"$rigMember.armed.md\",\"offset\":1,\"limit\":1}"
rigCall Write "{\"path\":\"$rigTmp/ranged/ws/OUT/r.txt\",\"content\":\"rig\"}"
rigCall Skill "{\"name\":\"$rigMember\",\"file\":\"$rigMember.armed.md\",\"offset\":2,\"limit\":8}"
rigCall Write "{\"path\":\"$rigTmp/ranged/ws/OUT/r.txt\",\"content\":\"rig\"}"
rigEnd
rigLoop rig-session-ranged
rigAssert "the last line alone does not arm"           "$( rigRedirected 2 )" yes
rigAssert "the first and last lines alone do not arm"  "$( rigRedirected 4 )" yes
rigAssert "ranges that together cover every line arm" "$( cat "$rigDir/ws/OUT/r.txt" 2>/dev/null )" rig

echo "-- what counts as arming: a cut read and its continuation --"
rigScenario truncated
## 6000 numbered lines: the loop's 200000-byte cap cuts at 3922; a continuation from 4001 skips 79 lines.
rigBig="$rigTmp/skills/$rigMember/$rigMember.armed.md"
cp "$rigBig" "$rigTmp/armed.small"
LC_ALL=C awk 'BEGIN { for ( lineNo = 1 ; lineNo <= 6000 ; lineNo++ ) printf "rig duty line %05d padding-padding-padding-paddin\n", lineNo ; }' > "$rigBig"
rigCall Skill "{\"name\":\"$rigMember\",\"file\":\"$rigMember.armed.md\"}"
rigCall Write "{\"path\":\"$rigTmp/truncated/ws/OUT/t.txt\",\"content\":\"rig\"}"
rigCall Skill "{\"name\":\"$rigMember\",\"file\":\"$rigMember.armed.md\",\"offset\":4001}"
rigCall Write "{\"path\":\"$rigTmp/truncated/ws/OUT/t.txt\",\"content\":\"rig\"}"
rigCall Skill "{\"name\":\"$rigMember\",\"file\":\"$rigMember.armed.md\",\"offset\":3922,\"limit\":79}"
rigCall Write "{\"path\":\"$rigTmp/truncated/ws/OUT/t.txt\",\"content\":\"rig\"}"
rigEnd
rigLoop rig-session-truncated
cp "$rigTmp/armed.small" "$rigBig"
rigAssert "the full read was cut, at the offset this rig expects" "$( LC_ALL=C grep -o -E 'TRUNCATED[^.]*continue with offset [0-9]+' "$rigDir/req.2" | head -1 | LC_ALL=C sed 's/.*offset /offset /' )" "offset 3922"
rigAssert "a cut read does not arm"                    "$( rigRedirected 2 )" yes
rigAssert "a continuation that skips lines does not arm" "$( rigRedirected 4 )" yes
rigAssert "filling the skipped lines arms"             "$( cat "$rigDir/ws/OUT/t.txt" 2>/dev/null )" rig

echo "-- controls: never gated --"
rigScenario nospawn
rigCall Write "{\"path\":\"$rigTmp/nospawn/ws/OUT/n.txt\",\"content\":\"rig\"}"
rigEnd
rigLoop ""
rigAssert "a loop with no spawn id writes unarmed"     "$( cat "$rigDir/ws/OUT/n.txt" 2>/dev/null )" rig
rigScenario served
printf '{"path":"%s","content":"rig"}' "$rigDir/ws/OUT/s.txt" | env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" \
	MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_SESSION_ID=rig-session-served MDAT_SPAWN_AGENT="$rigMember" \
	RIG_TMP="$rigTmp" RIG_HARNESS="$rigHarness" \
	bash -c '
		case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
		cd "$MMDAPP" && exec bash "$RIG_HARNESS" --intern-tool Write --access-read-root "$MMDAPP" --access-write-root "$MMDAPP/OUT"
	' > "$rigDir/out" 2> "$rigDir/err"
rigAssert "a served call with a spawn id writes unarmed" "$( cat "$rigDir/ws/OUT/s.txt" 2>/dev/null )" rig

echo "-- the close record --"
rigScenario close
mkdir -p "$rigDir/data"
printf 'SPAWN_CLI_SERVICE=rig-cli\n' >> "$rigDir/ws/.local/.agents/magic-team.agent.env"
## The fake console leaves what a harness loop would: .harness, and .armed once armed.
printf '#!/bin/sh\n## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli)\ncat > /dev/null\ncase "$RIG_ARM" in yes) : > "$MDAT_SPAWN_SANDBOX_ROOT/$MDAT_SPAWN_SESSION_ID.harness" ; echo "2026-09-29 10:00 +0300" > "$MDAT_SPAWN_SANDBOX_ROOT/$MDAT_SPAWN_SESSION_ID.armed" ;; no) : > "$MDAT_SPAWN_SANDBOX_ROOT/$MDAT_SPAWN_SESSION_ID.harness" ;; esac\n' > "$rigDir/ws/DistroAgentsConsole.sh"
chmod +x "$rigDir/ws/DistroAgentsConsole.sh"
rigClose(){ ## armed mode (yes|no|unknown); prints the tracking record's armed lines
	printf 'rig context' | env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigDir/ws" MDAT_DATA_ROOT="$rigDir/data" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigTmp/skills" RIG_ARM="$1" RIG_SCENARIO="$rigDir" RIG_CURL_LOG="$rigDir/curl.log" \
		RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy rig-member --dispatch-doc:none --wait
		' > "$rigDir/close.$1" 2>&1
	LC_ALL=C cat "$rigDir/ws/.local/agents/spawned"/*/*.md 2>/dev/null | LC_ALL=C grep -E '^armed(-at)?: ' | LC_ALL=C sort | tr '\n' ' '
	rm -rf "$rigDir/ws/.local/agents/spawned"
}
rigAssert "armed yes, with armed-at"                   "$( rigClose yes )" "armed-at: 2026-09-29 10:00 +0300 armed: yes "
rigAssert "armed no, a harness loop that never armed"  "$( rigClose no )" "armed: no "
rigAssert "armed unknown, no harness marker at all"    "$( rigClose unknown )" "armed: unknown "

rigAssert "no request went anywhere but the fake's two kinds" "$( cat "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C grep -v -c -E '^(https://slack.com/api/|https://harness-arm-gate-check.invalid/)' || : )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ARM GATE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_ARM_GATE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
