#!/usr/bin/env bash
## Behavioural check on the identity a rig's team-data commits carry. A clean install ends with `TEAM_DATA_GIT_IDENTITY:
## FAIL` when the team-data root has a `.git` and either `user.name` or `user.email` is empty. Two settings close it, and
## this check holds the three places they must reach, in the order a reader needs them:
##   1. the fragment that writes the team scope, `mdci-packages-myx/setup.machine-mdci/host/install/common-mdci.5.team-config.txt`,
##      upserts `TEAM_DATA_GIT_USER_NAME` and `TEAM_DATA_GIT_USER_EMAIL`, the way it already upserts
##      `TEAM_DATA_GIT_REMOTE` and `TEAM_DATA_BRANCH`. It does not today, so nothing writes them and the install fails.
##   2. each takes its value from a variable the instance projects can declare, `MDCI_TEAM_DATA_GIT_USER_NAME` and
##      `MDCI_TEAM_DATA_GIT_USER_EMAIL`, which is how every other setting of that fragment takes its value.
##   3. the two names are the tooling's own settings, so the upsert lands: the option spec knows both, and the commit
##      reader reads both through `AgentsToolsConfigOption`. Rows 3 and 4 are the check's own controls: they pass on the
##      source as it stands, so a failure above is the fragment's and not the reader's.
## Not held here: what the identity's values are on any rig, and whether either instance project declares the two
## variables. Those are the instance projects' own rows.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigTree="$MDLT_ORIGIN"
rigFragment="$rigTree/myx/mdci-packages-myx/setup.machine-mdci/host/install/common-mdci.5.team-config.txt"
rigOptionSpec="$rigTree/myx/myx.distro-agents/sh-lib/config/AgentsTools.OwnerSetupOptionSpec.include"
rigCommitReader="$rigTree/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.TeamDataCommit.include"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigFragment" ] || rigRefuse "the team-config fragment is not at the origin: $rigFragment"
[ -f "$rigOptionSpec" ] || rigRefuse "the settings option spec is not at the origin: $rigOptionSpec"
[ -f "$rigCommitReader" ] || rigRefuse "the team-data commit reader is not at the origin: $rigCommitReader"
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigUpserts(){ ## key -- how many lines of the fragment upsert that key for the team scope
	LC_ALL=C grep -c -E "^[[:space:]]*MdciUpsertSetting[[:space:]]+magic-team[[:space:]]+$1[[:space:]]" "$rigFragment"
}

echo "-- 1. the fragment writes both identity settings, beside the remote and the branch --"
rigAssert "the fragment upserts TEAM_DATA_GIT_USER_NAME for the team scope: today nothing writes it" "$( rigUpserts TEAM_DATA_GIT_USER_NAME )" "1"
rigAssert "and TEAM_DATA_GIT_USER_EMAIL, beside it" "$( rigUpserts TEAM_DATA_GIT_USER_EMAIL )" "1"
rigAssert "the two settings it already writes are still there, so the new lines join them and do not replace them" \
	"$( rigUpserts TEAM_DATA_GIT_REMOTE ) $( rigUpserts TEAM_DATA_BRANCH )" "1 1"

echo "-- 2. each takes its value from a variable the instance can declare --"
rigAssert "the name comes from MDCI_TEAM_DATA_GIT_USER_NAME, as every other setting of the fragment takes its value" \
	"$( LC_ALL=C grep -c -E 'TEAM_DATA_GIT_USER_NAME[[:space:]]+"\$\{MDCI_TEAM_DATA_GIT_USER_NAME' "$rigFragment" )" "1"
rigAssert "and the email from MDCI_TEAM_DATA_GIT_USER_EMAIL" \
	"$( LC_ALL=C grep -c -E 'TEAM_DATA_GIT_USER_EMAIL[[:space:]]+"\$\{MDCI_TEAM_DATA_GIT_USER_EMAIL' "$rigFragment" )" "1"

echo "-- 3. the tooling owns both names, so the upsert lands (the check's own control) --"
rigAssert "the settings option spec knows TEAM_DATA_GIT_USER_NAME and TEAM_DATA_GIT_USER_EMAIL" \
	"$( LC_ALL=C grep -c -E '^[[:space:]]*TEAM_DATA_GIT_USER_NAME\)' "$rigOptionSpec" ) $( LC_ALL=C grep -c -E '^[[:space:]]*TEAM_DATA_GIT_USER_EMAIL\)' "$rigOptionSpec" )" "1 1"
rigAssert "and the commit reader reads both through AgentsToolsConfigOption" \
	"$( LC_ALL=C grep -c 'AgentsToolsConfigOption magic-team --select TEAM_DATA_GIT_USER_NAME' "$rigCommitReader" ) $( LC_ALL=C grep -c 'AgentsToolsConfigOption magic-team --select TEAM_DATA_GIT_USER_EMAIL' "$rigCommitReader" )" "1 1"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ TEAM DATA GIT IDENTITY CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'TEAM_DATA_GIT_IDENTITY: OK (%d assertions, offline, the fragment and the tooling read as they stand)\n' "$rigPasses"
