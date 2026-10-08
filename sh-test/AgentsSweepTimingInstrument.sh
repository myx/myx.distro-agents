#!/usr/bin/env bash
## A timing instrument, not a rig: it asserts nothing and is never part of a test sweep.
## It times one --magic-sweep-input-scan against a fixture workspace -- the team member,
## client-* members each with three configured conversations, and a roster of direct
## conversations -- behind a fake `curl` that answers Slack after a fixed latency.
##
## Usage: AgentsSweepTimingInstrument.sh [<latency-seconds> [<dms> [<clients>]]]
##   defaults 0.3 30 2. Prints rc, seconds, the Slack calls made (in total and per
##   method), and the mdat-* temp files the sweep left behind. INST_KEEP=<dir> also
##   copies the sweep's own stdout and stderr there. rc 3 is expected: the fixture's human-owner DM
##   discovery is not modelled, so that one source reads as partial on every run.
##
## Offline and contained: a temp HOME, workspace and data store, and the fake curl
## first on PATH. Nothing of the real workspace or store is read. Member skill
## directories sit where the tool looks when MDAT_SKILLSET_ROOT is unset, the
## fixture workspace's own .local/agents/members/.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
instHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-test"
instTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
[ -f "$instTool" ] || { echo "⛔ ERROR: the tool is not at the origin this workspace resolves: $instTool" >&2 ; exit 1 ; }
instLatency="${1:-0.3}" instDms="${2:-30}" instClients="${3:-2}"

instTmp="$( mktemp -d "${TMPDIR:-/tmp}/AgentsSweepTimingInstrument.XXXXXX" )" || exit 1
trap 'rm -rf -- "$instTmp"' EXIT
mkdir -p "$instTmp/bin" "$instTmp/ws/.local/.agents" "$instTmp/ws/.local/agents/members/magic-coordinator" \
	"$instTmp/data/inboxes/magic-coordinator" "$instTmp/data/board/running" "$instTmp/data/audit"
cp "$instHere/check-fixtures/sweep-timing.curl.test.sh" "$instTmp/bin/curl" \
	|| { echo "⛔ ERROR: the fake curl fixture is missing: $instHere/check-fixtures/sweep-timing.curl.test.sh" >&2 ; exit 1 ; }
chmod +x "$instTmp/bin/curl"
[ "$( PATH="$instTmp/bin:$PATH" command -v curl )" = "$instTmp/bin/curl" ] \
	|| { echo "⛔ ERROR: the fake curl is not first on PATH, so this would issue real requests" >&2 ; exit 1 ; }

printf '# fixture\n' > "$instTmp/ws/.local/agents/members/magic-coordinator/SKILL.md"
printf 'SLACK_BOT_TOKEN=xoxb-fixture\nSLACK_CHANNEL_MAGIC_TEAM=CFIXTEAM001\nSLACK_CHANNEL_HUMAN_OWNER=UFIXOWNER01\n' > "$instTmp/ws/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=xoxp-fixture-coordinator\n' > "$instTmp/ws/.local/.agents/magic-coordinator.agent.env"
instClient=1
while [ "$instClient" -le "$instClients" ] ; do
	mkdir -p "$instTmp/ws/.local/agents/members/client-fix$instClient" "$instTmp/data/inboxes/client-fix$instClient"
	printf '# fixture\n' > "$instTmp/ws/.local/agents/members/client-fix$instClient/SKILL.md"
	printf 'SLACK_USER_TOKEN=xoxp-fixture-client%s\nSLACK_CONVERSATIONS=CFIXAAAA00%s,CFIXBBBB00%s,CFIXCCCC00%s\n' \
		"$instClient" "$instClient" "$instClient" "$instClient" > "$instTmp/ws/.local/.agents/client-fix$instClient.agent.env"
	instClient=$(( instClient + 1 ))
done

instStart="$( date +%s )"
instRc=0
( cd "$instTmp/ws" && env -u MDAT_SKILLSET_ROOT PATH="$instTmp/bin:$PATH" HOME="$instTmp/home" MMDAPP="$instTmp/ws" \
	MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_DATA_ROOT="$instTmp/data" TMPDIR="$instTmp/ws/.local/temp" \
	FIX_DIR="$instTmp" FIX_LATENCY="$instLatency" FIX_DMS="$instDms" \
	bash "$instTool" --magic-sweep-input-scan magic-coordinator ) > "$instTmp/out" 2> "$instTmp/err" || instRc=$?
instEnd="$( date +%s )"
instLeft="$( ls -1 "$instTmp/ws/.local/temp" 2>/dev/null | grep -c '^mdat-' )"
printf 'SWEEP_TIMING: rc=%s seconds=%s calls=%s mdat-left=%s (latency %ss, %s DMs, %s clients)\n' \
	"$instRc" "$(( instEnd - instStart ))" "$( wc -l < "$instTmp/calls.log" 2>/dev/null | tr -d ' ' )" "$instLeft" \
	"$instLatency" "$instDms" "$instClients"
## The calls by Slack method, most frequent first: where the time went.
[ ! -f "$instTmp/calls.log" ] || LC_ALL=C awk '{ n[$2]++ } END { for (m in n) printf("SWEEP_CALLS: %5d %s\n", n[m], m) }' "$instTmp/calls.log" | LC_ALL=C sort -k2,2nr -k3
[ -z "${INST_KEEP:-}" ] || { mkdir -p "$INST_KEEP" && cp "$instTmp/out" "$instTmp/err" "$INST_KEEP/" 2>/dev/null ; }
