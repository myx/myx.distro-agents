#!/usr/bin/env bash
## Behavioural check on the orphan asks of magic-coordinator's work-duty scan (AgentsTools.OrphanAsks.include): an open ask
## the coordinator asked of a member with no live run is listed, with its item and age, and the two moves; the scan's own
## `orphan-ask` reading decides which. Held here, on a rig workspace and its own pending-replies registry:
##   1. an open ask of the coordinator to a member with no process is listed, by its id, addressee, item and age
##   2. the controls: the same ask to a member a process runs as, an ask to magic-coordinator, an ask another member asked,
##      a closed ask and an unposted one are not listed
##   3. a rig with no orphan ask reads `(none)`, and the duty's scan step calls the section
##   4. the one orphan-ask test both readers call (AgentsToolsOrphanAskTest), row by row: rc 0 for the orphan, 1 for a member
##      a process runs as, 2 for a coordinator, a human, a Slack user, no address and an unposted ask; and --supervise-scan calls it
## Red before the section: its include is absent, and the check refuses to report.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigPkg/sh-lib/questions/AgentsTools.OrphanAsks.include" ] || rigRefuse "the section is not at the origin: $rigPkg/sh-lib/questions/AgentsTools.OrphanAsks.include"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsOrphanAskSectionCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigPids=""
trap 'for rigOne in $rigPids ; do kill -KILL "$rigOne" 2> /dev/null ; done ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/agents/pending" "$rigTmp/home" "$rigTmp/data" || rigRefuse "the rig could not be made: $rigTmp"
rigNow="$( date -u +%s )"
rigAskedAt="$( date -u -r $(( rigNow - 5400 )) '+%Y-%m-%d %H:%M +0000' 2> /dev/null || date -u -d "@$(( rigNow - 5400 ))" '+%Y-%m-%d %H:%M +0000' )"

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
rigAsk(){ ## id, owner, address, status, question ts (may be empty)
	printf -- '---\nstatus: %s\nowner: %s\nblocked-on: reply from %s\nsession-id: rig-session\nkind: readback\naddress-to: %s\n%sitem: task-rig-item-%s\nasked-at: %s\n---\n' \
		"$4" "$2" "$3" "$3" "${5:+question-ts: $5
}" "$1" "$rigAskedAt" > "$rigWs/.local/agents/pending/$1.md" || rigRefuse "the ask could not be written: $1"
}
## The section, on this rig alone, after its registry is rebuilt by the registry's owner.
rigSection(){
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigTmp/data" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.Registries.include" || exit 1
		AgentsToolsRegistryRebuild pending-replies > /dev/null 2>&1 || exit 1
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/questions/AgentsTools.OrphanAsks.include" || exit 1
		AgentsToolsOrphanAskSection magic-coordinator' 2>&1
}

python3 -I -B -c 'import time; time.sleep(300)' -- --team-member rig-live-member --stand-in > /dev/null 2>&1 &
rigPids="$rigPids $!"
rigAsk rigorphan magic-coordinator rig-absent-member reply-pending 1.000001
rigAsk rigalive magic-coordinator rig-live-member reply-pending 1.000002
rigAsk rigtocoord magic-developer magic-coordinator reply-pending 1.000003
rigAsk rigother magic-developer rig-absent-member reply-pending 1.000004
rigAsk rigclosed magic-coordinator rig-absent-member reply-received 1.000005
rigAsk rigunposted magic-coordinator rig-absent-member reply-pending ""
rigOut="$( rigSection )"
[ -s "$rigWs/.local/agents/pending-replies.registry" ] || rigRefuse "the registry was not rebuilt on the rig: $rigOut"
rigAge="$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^- rigorphan .* age=\([0-9]*\)m$/\1/p' )"
rigAssert "the orphan ask is listed with its addressee, item and asked-at" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -F -x -- "- rigorphan to rig-absent-member item task-rig-item-rigorphan asked $rigAskedAt age=${rigAge}m" )" "1"
rigAssert "its age is the minutes since it was asked" "$( case "$rigAge" in 90|91) echo in-bound ;; *) echo "${rigAge:-none}" ;; esac )" "in-bound"
rigAssert "the section names the two moves" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -F -- 'Dispatch that member on its item, or close the ask: DistroAgentsSession.fn.sh --settle-pending-reply' )" "1"
for rigId in rigalive rigtocoord rigother rigclosed rigunposted ; do
	rigAssert "$rigId is no orphan ask of the coordinator" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -- "^- $rigId " )" "0"
done
rm -f "$rigWs/.local/agents/pending/rigorphan.md"
rigAssert "with no orphan ask the section reads (none)" "$( rigSection | LC_ALL=C grep -c -x '(none)' )" "1"
rigAssert "the duty's scan step calls the section" "$( LC_ALL=C grep -l -F -- '--intern-op-work-duty-input-scan)' "$rigPkg"/sh-lib/*/*.include | xargs LC_ALL=C grep -c -x -F -- '			AgentsToolsOrphanAskSection "$workMember"' )" "1"

## The test itself, in one process of the origin under test, on a process list of this check's own.
rigTestRows="$( env -i PATH="/usr/bin:/bin:/usr/sbin:/sbin" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/questions/AgentsTools.OrphanAsks.include" || exit 1
	rigList="python3 --team-member rig-live-member --stand-in"
	for rigRow in rig-absent-member:1.1 rig-live-member:1.1 magic-coordinator:1.1 human-owner:1.1 U0RIGUSER:1.1 :1.1 rig-absent-member: ; do
		rigRc=0 ; AgentsToolsOrphanAskTest "${rigRow%%:*}" "${rigRow#*:}" "$rigList" || rigRc=$?
		printf "%s=%s " "$rigRow" "$rigRc"
	done' 2>&1 )"
rigAssert "the orphan-ask test answers each row" "$rigTestRows" "rig-absent-member:1.1=0 rig-live-member:1.1=1 magic-coordinator:1.1=2 human-owner:1.1=2 U0RIGUSER:1.1=2 :1.1=2 rig-absent-member:=2 "
rigAssert "--supervise-scan calls the one orphan-ask test" "$( LC_ALL=C grep -l -F -- 'AgentsToolsSuperviseScan(){' "$rigPkg"/sh-lib/*/*.include | xargs LC_ALL=C grep -c -F -- 'AgentsToolsOrphanAskTest "$scanTo" "$scanTs" "$scanPs"' )" "1"

[ "$rigFail" = 0 ] || { printf 'ORPHAN_ASK_SECTION: FAIL (%d of %d assertions)\n' "$rigFail" "$(( rigPass + rigFail ))" ; exit 1 ; }
printf 'ORPHAN_ASK_SECTION: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
