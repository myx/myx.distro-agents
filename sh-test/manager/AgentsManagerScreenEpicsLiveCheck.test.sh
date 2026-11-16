#!/usr/bin/env bash
## Behavioural check on `Epics` in the console app (S7 of the refactorings epic): the Magic Team block's epics page lists the
## team's own planning epics through the tooling, and one epic opens whole beside them. Run rather than read, against the REAL
## dispatcher: the screen's own code through the stand-in terminal of the driver (check-fixtures/manager-screen.driver.py), in a
## scratch workspace of this rig with its own team data (check-fixtures/manager-screen.live-rig.include.sh), holding two epic
## items of the rig's own vault, so `--epic-list` and `--epic-read` are the tooling's own.
## Held:
##   1. Epics stands under Magic-Team (Agents), after Routines
##   2. entering it reads `--epic-list`, and the rig's two epics are its rows
##   3. selecting one reads `--epic-read` of that item, and its text shows
## Red: with the part out of `sh-lib/config/screen-parts.list` there is no Epics root, so the drive cannot reach it and every
## assertion fails on an empty screen.
## Offline: no call leaves the rig, and the epics are the rig's own, never the estate's.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenEpicsLiveCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
export TZ=UTC
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-owner-writes.include.sh" || exit 1
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/manager-screen.live-rig.include.sh" || exit 1
rigLiveSetup
rigOwnerWs="$rigWs" rigOwnerData="$rigStore" rigOwnerHome="$rigHome" rigOwnerOrigin="$MDLT_ORIGIN"
trap 'rigLiveEnd ; rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## The fixture: two epic items of the rig's own vault, each with sections of its own, written by the vault's owner.
rigOwnerVaultPut epic-blueprint-20261001T0000Z-rig-one.md <<'EOF' || rigRefuse "the rig's first epic could not be written"
---
type: epic-blueprint
document-contract: vault-item.epic-blueprint
from: user-myx
date: 2026-10-01 10:00 +0200
---

# The rig's first epic

## Goal

A goal the check reads back.

## Scope

In: the rig.
EOF
rigOwnerVaultPut epic-blueprint-20261002T0000Z-rig-two.md <<'EOF' || rigRefuse "the rig's second epic could not be written"
---
type: epic-blueprint
document-contract: vault-item.epic-blueprint
from: user-myx
date: 2026-10-02 10:00 +0200
---

# The rig's second epic

## Goal

Another goal.
EOF

rigLiveWhere where
{
	printf 'turn\nturn\nturn\n'
	printf 'root magic-team\nturn\nget ROOT\n'
	printf 'at @epics\nwait list 120\nturn\nget LIST\n'
	printf 'select epic-blueprint-20261002T0000Z-rig-two.md\nwait view 120\nturn\nget VIEW\nshow PANE\n'
} | rigLiveDrive

rigAssert "Epics stands under Magic-Team (Agents), at a level of its own" \
	"$( rigLiveVal LIST path where )" "magic-team/epics"
rigAssert "entering it read --epic-list, the tooling's own" \
	"$( [ "$( rigLiveCalls '^--epic-list$' where )" -ge 1 ] && printf yes || printf no )" "yes"
rigAssert "the rig's two epics are its rows, beside the row that goes up" \
	"$( rigLiveVal LIST rows where )" "3"
rigAssert "selecting the second reads --epic-read of that item, and never of the other" \
	"$( [ "$( rigLiveCalls '^--epic-read epic-blueprint-20261002T0000Z-rig-two\.md$' where )" -ge 1 ] && printf read || printf none )$( rigLiveCalls '^--epic-read epic-blueprint-20261001T0000Z-rig-one\.md$' where )" "read0"
rigAssert "no read failed and no failure box opened" \
	"$( rigLiveVal VIEW failed where ) $( rigLiveVal VIEW dialogTitle where )" " "
rigAssert "the epic's own text shows beside the list" \
	"$( rigLiveHolds where "The rig's second epic" )" "yes"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN EPICS LIVE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SCREEN_EPICS_LIVE: OK (%d assertions, the real dispatcher)\n' "$rigPassCount"
