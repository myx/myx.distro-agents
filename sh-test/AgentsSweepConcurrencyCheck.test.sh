#!/usr/bin/env bash
## 1495: the sweep reads its sources and accounts concurrently, and that changes nothing
## it reports. One --magic-sweep-input-scan runs against the timing instrument's fixture
## (a fake Slack with a fixed latency) twice: as built, and from a copy of the package
## with every Parallel held to one worker. The two documents must be byte-identical once
## dates and times are masked, and neither run may leave an mdat-* temp file. Both runs
## are timed and the times are printed, never asserted. Temp trees only, under one
## `env -i` guard.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-test/check-fixtures/sweep-concurrency.curl.test.sh" ] || rigRefuse "the sweep-concurrency fixture is missing from the package"
rigTmp="$( mktemp -d -t AgentsSweepConcurrencyCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## The serial origin: the package copied, every Parallel call given one worker, the
## other packages linked beside it.
rigSerial="$rigTmp/serial-origin"
mkdir -p "$rigSerial/myx"
for rigEntry in "$MDLT_ORIGIN"/* ; do
	[ "${rigEntry##*/}" = myx ] || ln -s "$rigEntry" "$rigSerial/${rigEntry##*/}"
done
for rigEntry in "$MDLT_ORIGIN"/myx/* ; do
	[ "${rigEntry##*/}" = myx.distro-agents ] || ln -s "$rigEntry" "$rigSerial/myx/${rigEntry##*/}"
done
cp -R "$rigPackage" "$rigSerial/myx/myx.distro-agents"
sed -i.rig -E 's/Parallel( --workers [0-9]+)? AgentsToolsMagicSweepAccountOne/Parallel --workers 1 AgentsToolsMagicSweepAccountOne/' "$rigSerial/myx/myx.distro-agents/sh-lib/AgentsTools.MagicSweep.include"
sed -i.rig -E 's/Parallel( --workers [^ ]+)? AgentsSessionContextSourceFetchOne/Parallel --workers 1 AgentsSessionContextSourceFetchOne/' "$rigSerial/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpSessionContextScan.include"
rigHeld="$( cat "$rigSerial/myx/myx.distro-agents/sh-lib/AgentsTools.MagicSweep.include" "$rigSerial/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpSessionContextScan.include" | LC_ALL=C grep -c 'Parallel --workers 1' || : )"
[ "$rigHeld" = 2 ] || rigRefuse "the serial copy did not hold both Parallel sites to one worker (found $rigHeld), so no serial run could be compared"

## The control that the identity assertion can fail: a copy that consumes the prefetched
## results in the order the reads finished, not the sources' own order. Held to one
## worker the two orders agree; side by side they do not, so only concurrency shows it.
rigMisordered="$rigTmp/misordered-origin"
mkdir -p "$rigMisordered/myx"
for rigEntry in "$MDLT_ORIGIN"/* ; do
	[ "${rigEntry##*/}" = myx ] || ln -s "$rigEntry" "$rigMisordered/${rigEntry##*/}"
done
for rigEntry in "$MDLT_ORIGIN"/myx/* ; do
	[ "${rigEntry##*/}" = myx.distro-agents ] || ln -s "$rigEntry" "$rigMisordered/myx/${rigEntry##*/}"
done
cp -R "$rigPackage" "$rigMisordered/myx/myx.distro-agents"
sed -i.rig -e 's/^\([[:space:]]*\)printf .read\\n. > "\$sourcePrefetchDir\/state\.\$1"$/&\
\1printf "%s\\n" "$1" >> "$sourcePrefetchDir\/finished"/' \
	-e 's/^\([[:space:]]*\)sourceIndex=\$(( sourceIndex + 1 ))$/&\
\1sourceRead="$( sed -n "$(( sourceIndex + 1 ))p" "$sourcePrefetchDir\/finished" 2>\/dev\/null )" ; [ -n "$sourceRead" ] || sourceRead=$sourceIndex/' \
	"$rigMisordered/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpSessionContextScan.include"
LC_ALL=C grep -q 'sourcePrefetchDir/finished"$' "$rigMisordered/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpSessionContextScan.include" \
	|| rigRefuse "the misordered copy does not record the order its reads finished in"
sed -i.rig 's/\$sourcePrefetchDir\/\([a-z]*\)\.\$sourceIndex/$sourcePrefetchDir\/\1.$sourceRead/g' \
	"$rigMisordered/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpSessionContextScan.include"
rigReordered="$( LC_ALL=C grep -c 'sourcePrefetchDir/[a-z]*\.\$sourceRead' "$rigMisordered/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpSessionContextScan.include" || : )"
[ "$rigReordered" -gt 0 ] || rigRefuse "the misordered copy reads no prefetched file out of order, so it could not show the identity check failing"

## Histories carry a message stamped now, inside any cut-off the scan applies.
rigNow="$( date +%s )"

## One sweep from the given origin, in a fresh fixture tree, guarded.
rigSweep(){ ## name, origin
	local sweepDir="$rigTmp/$1" sweepClient
	mkdir -p "$sweepDir/bin" "$sweepDir/ws/.local/.agents" "$sweepDir/ws/.local/temp" "$sweepDir/ws/.local/agents/members/magic-coordinator" \
		"$sweepDir/data/inboxes/magic-coordinator" "$sweepDir/data/board/running" "$sweepDir/data/audit"
	cp "$rigPackage/sh-test/check-fixtures/sweep-concurrency.curl.test.sh" "$sweepDir/bin/curl" && chmod +x "$sweepDir/bin/curl"
	printf '# fixture\n' > "$sweepDir/ws/.local/agents/members/magic-coordinator/SKILL.md"
	printf 'SLACK_BOT_TOKEN=xoxb-fixture\nSLACK_CHANNEL_MAGIC_TEAM=CFIXTEAM001\nSLACK_CHANNEL_HUMAN_OWNER=UFIXOWNER01\n' > "$sweepDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=xoxp-fixture-coordinator\n' > "$sweepDir/ws/.local/.agents/magic-coordinator.agent.env"
	for sweepClient in 1 2 ; do
		mkdir -p "$sweepDir/ws/.local/agents/members/client-fix$sweepClient" "$sweepDir/data/inboxes/client-fix$sweepClient"
		printf '# fixture\n' > "$sweepDir/ws/.local/agents/members/client-fix$sweepClient/SKILL.md"
		printf 'SLACK_USER_TOKEN=xoxp-fixture-client%s\nSLACK_CONVERSATIONS=CFIXAAAA00%s,CFIXBBBB00%s,CFIXCCCC00%s\n' \
			"$sweepClient" "$sweepClient" "$sweepClient" "$sweepClient" > "$sweepDir/ws/.local/.agents/client-fix$sweepClient.agent.env"
	done
	local sweepStart sweepRc=0
	sweepStart="$( date +%s )"
	env -i HOME="$sweepDir/home" PATH="$sweepDir/bin:/usr/bin:/bin" MMDAPP="$sweepDir/ws" MDAT_DATA_ROOT="$sweepDir/data" TMPDIR="$sweepDir/ws/.local/temp" \
		MDLT_ORIGIN="$2" MDLT_OPTION="--run-from-path $2" FIX_DIR="$sweepDir" FIX_LATENCY=0.3 FIX_DMS=30 FIX_TS="$rigNow" RIG_TMP="$rigTmp" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$( command -v curl )" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --magic-sweep-input-scan magic-coordinator
		' > "$sweepDir/out" 2> "$sweepDir/err" || sweepRc=$?
	printf '%s' "$sweepRc" > "$sweepDir/rc"
	printf '%s' "$(( $( date +%s ) - sweepStart ))" > "$sweepDir/seconds"
	[ -s "$sweepDir/out" ] || rigRefuse "the $1 sweep printed no document: $( tail -3 "$sweepDir/err" )"
	## Dates, times, epoch stamps and temp paths are all that may differ between two runs.
	LC_ALL=C sed -E -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2}([ T][0-9]{2}:[0-9]{2}(:[0-9]{2})?( ?[+-][0-9]{4})?Z?)?/<date>/g' \
		-e 's/(^|[^0-9])1[0-9]{9}(\.[0-9]+)?/\1<epoch>/g' -e "s|$sweepDir|<dir>|g" "$sweepDir/out" > "$sweepDir/masked"
}

echo "-- one sweep as built, one held to one worker --"
rigSweep concurrent "$MDLT_ORIGIN"
rigSweep serial "$rigSerial"
rigAssert "the two sweeps end alike"                   "$( cat "$rigTmp/concurrent/rc" )" "$( cat "$rigTmp/serial/rc" )"
rigAssert "the documents are byte-identical, dates masked" "$( cmp -s "$rigTmp/concurrent/masked" "$rigTmp/serial/masked" && printf same || printf "differs at: $( cmp "$rigTmp/concurrent/masked" "$rigTmp/serial/masked" 2>&1 | head -1 )" )" same
rigAssert "control: the document has per-source content" "$( [ "$( LC_ALL=C grep -c -E 'CFIX|DFIX|client-fix' "$rigTmp/concurrent/masked" )" -gt 0 ] && printf yes || printf no )" yes
rigAssert "control: at least two sources' own messages are in it" "$( [ "$( LC_ALL=C grep -o -E 'RIG-MSG-[A-Z0-9]+' "$rigTmp/concurrent/masked" | LC_ALL=C sort -u | LC_ALL=C grep -c . )" -ge 2 ] && printf yes || printf no )" yes
rigSweep misordered "$rigMisordered"
rigAssert "control: the same identity check fails on a copy that consumes in finish order" "$( cmp -s "$rigTmp/misordered/masked" "$rigTmp/serial/masked" && printf same || printf differs )" differs
rigAssert "the concurrent sweep leaves no mdat-* file" "$( ls -1 "$rigTmp/concurrent/ws/.local/temp" | LC_ALL=C grep -c '^mdat-' || : )" 0
rigAssert "the serial sweep leaves none either"        "$( ls -1 "$rigTmp/serial/ws/.local/temp" | LC_ALL=C grep -c '^mdat-' || : )" 0
printf '        timing, not asserted: concurrent %ss, one worker %ss (latency 0.3s, 30 DMs, 2 clients)\n' "$( cat "$rigTmp/concurrent/seconds" )" "$( cat "$rigTmp/serial/seconds" )"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SWEEP CONCURRENCY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SWEEP_CONCURRENCY: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
