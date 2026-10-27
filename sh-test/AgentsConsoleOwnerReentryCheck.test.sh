#!/usr/bin/env bash
## Behavioural check on the console-owner re-entry (sh-lib/manager/AgentsTools.ConsoleOwner.include): the launcher of the
## manager screen re-enters itself as the account that owns the workspace when the caller is someone else, so the console
## and everything it runs execute as the owner, entered as by sudo (SUDO_USER then names who entered, which
## AgentsToolsConsoleAccount reads). Held:
##   - the owner is the account the workspace root belongs to, read by stat, in one place (AgentsToolsConsoleOwnerAccount);
##   - the re-entry runs the launcher under sudo -u <owner> -H only where the effective account differs from the owner,
##     sudo is present and the path holds a slash; never where they are the same, the owner is unreadable, or there is no sudo;
##   - both starts of the screen (AgentsConsoleManager.fn.sh and --manager) call that one function, and no other place.
## Offline; stubs for stat, id and sudo.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigInclude="$rigPackage/sh-lib/manager/AgentsTools.ConsoleOwner.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the include is not at the origin this workspace resolves: $rigInclude"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsConsoleOwnerReentryCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigWs="$rigTmp/ws" rigHome="$rigTmp/home" rigBin="$rigTmp/bin"
mkdir -p "$rigWs" "$rigHome" "$rigBin"
## stat: the owner, by the flavour asked; RIG_STAT_BSD=1 makes -c fail so the -f arm answers, RIG_STAT_NONE=1 makes both fail.
printf '#!/bin/sh\ncase "$*" in\n\t*-c*) [ "${RIG_STAT_NONE:-}" != 1 ] || exit 1 ; [ "${RIG_STAT_BSD:-}" != 1 ] || exit 1 ; echo "${RIG_STAT_OWNER:-acct}" ;;\n\t*-f*) [ "${RIG_STAT_NONE:-}" != 1 ] || exit 1 ; [ "${RIG_STAT_BSD:-}" = 1 ] || exit 1 ; echo "${RIG_STAT_OWNER:-acct}" ;;\n\t*) exit 1 ;;\nesac\n' > "$rigBin/stat"
## id -un: the effective account; empty where the system gives none.
printf '#!/bin/sh\n[ "$*" = "-un" ] || exit 1\necho "${RIG_EFFECTIVE:-}"\n' > "$rigBin/id"
## sudo: logs its argv and ends, so the re-entry is read, never run.
printf '#!/bin/sh\nprintf "sudo: %%s\\n" "$*" >> "$RIG_SUDO_LOG"\nexit 7\n' > "$rigBin/sudo"
chmod +x "$rigBin/stat" "$rigBin/id" "$rigBin/sudo"
rigAccount='. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsTools.ConsoleOwner.include" ; AgentsToolsConsoleOwnerAccount ; echo "rc=$?"'
rigRun(){ ## script -- the output of a script run in the rig's environment, in the rig's workspace
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$rigBin:$PATH" \
		RIG_STAT_NONE="${RIG_STAT_NONE:-}" RIG_STAT_BSD="${RIG_STAT_BSD:-}" RIG_STAT_OWNER="${RIG_STAT_OWNER:-}" \
		MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDSC_CMD=rig \
		bash -c "$1" ) 2> /dev/null
}
rigLine(){ rigRun "$1" | LC_ALL=C tr '\n' ' ' ; }

echo "-- the one place the owner is read: stat, gnu then bsd --"
rigAssert "the owner of the workspace, by the gnu stat" "$( rigLine "$rigAccount" )" "acct rc=0 "
rigAssert "the same where only the bsd stat answers, after the gnu one fails" "$( RIG_STAT_BSD=1 rigLine "$rigAccount" )" "acct rc=0 "
rigAssert "nothing and rc 1 where no stat answers" "$( RIG_STAT_NONE=1 rigLine "$rigAccount" )" "rc=1 "

echo "-- the re-entry: only where the caller differs, sudo present, and a real path --"
rigReentry(){ ## effective account, owner word (empty = unreadable), path, argument
	local reentryEff="$1" reentryOwner="$2" reentryPath="$3" reentryArg="$4"
	: > "$rigTmp/sudo.log"
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$rigBin:$PATH" RIG_EFFECTIVE="$reentryEff" \
		RIG_STAT_NONE="$([ -n "$reentryOwner" ] && echo 0 || echo 1)" RIG_STAT_OWNER="$reentryOwner" \
		MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDSC_CMD=rig RIG_SUDO_LOG="$rigTmp/sudo.log" \
		bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsTools.ConsoleOwner.include" ; AgentsToolsConsoleOwnerReentry "$@"' _ "$reentryPath" "$reentryArg" ) 2> /dev/null
	rigReentryRc=$?
}
rigSudoLog(){ LC_ALL=C cat "$rigTmp/sudo.log" 2> /dev/null | LC_ALL=C tr '\n' ' ' ; }
rigReentry myx acct "$rigWs/DistroAgentsTools.fn.sh" --manager
rigAssert "a caller that is not the owner re-enters: sudo -u the owner -H, the launcher and its arguments" \
	"$rigReentryRc $( rigSudoLog )" "7 sudo: -u acct -H $BASH $rigWs/DistroAgentsTools.fn.sh --manager "
rigReentry acct acct "$rigWs/DistroAgentsTools.fn.sh" --manager
rigAssert "the owner itself does not re-enter: no sudo call" "$rigReentryRc $( rigSudoLog )" "0 "
rigReentry myx '' "$rigWs/DistroAgentsTools.fn.sh" --manager
rigAssert "an owner that cannot be read does not re-enter: no sudo call" "$rigReentryRc $( rigSudoLog )" "0 "
rigReentry myx acct "bareword" --manager
rigAssert "a path with no slash does not re-enter: no sudo call" "$rigReentryRc $( rigSudoLog )" "0 "

echo "-- on a rig the console runs with the HOME of the account that owns the workspace (mdci), not the caller's --"
## a sudo that does what sudo does with -H: the command runs as the account asked, with HOME that account's home; without -H the caller's HOME stays.
rigBin2="$rigTmp/bin2" rigOwnerHome="$rigTmp/owner-home"
mkdir -p "$rigBin2" "$rigOwnerHome"
printf '#!/bin/sh\nwhile [ $# -gt 0 ] ; do case "$1" in -u) shift 2 ;; -H) HOME="$RIG_OWNER_HOME" ; export HOME ; shift ;; *) break ;; esac ; done\nexec "$@"\n' > "$rigBin2/sudo"
printf '#!/bin/sh\necho "HOME=$HOME"\n' > "$rigWs/launcher.sh"
chmod +x "$rigBin2/sudo" "$rigWs/launcher.sh"
rigHomeAfter(){ ## the HOME the launcher sees after the re-entry, the caller being myx and the owner acct
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$rigBin2:$rigBin:$PATH" RIG_EFFECTIVE=myx RIG_STAT_NONE=0 RIG_STAT_OWNER=acct RIG_OWNER_HOME="$rigOwnerHome" \
		MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDSC_CMD=rig \
		bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsTools.ConsoleOwner.include" ; AgentsToolsConsoleOwnerReentry "$@"' _ "$rigWs/launcher.sh" ) 2> /dev/null
}
rigAssert "the launcher re-entered by the caller runs with HOME the owner's home, as sudo -H gives it" "$( rigHomeAfter | LC_ALL=C sed "s|$rigTmp|<rig>|" )" "HOME=<rig>/owner-home"
rigAssert "and the owner's home is not the caller's" "$( [ "$rigOwnerHome" != "$rigHome" ] && echo different )" "different"

echo "-- the two starts of the screen call the one function, and no other place reads the owner --"
rigCount(){ ## file... -- how many lines that are no comment read stat for the owner
	cat "$@" | LC_ALL=C grep -v '^[[:space:]]*#' | LC_ALL=C grep -c -e "stat -c '%U'" -e "stat -f '%Su'" || :
}
rigAssert "the launcher and --manager each source the one include and call the one re-entry" \
	"$( LC_ALL=C grep -c -F -- 'AgentsTools.ConsoleOwner.include' "$rigPackage/sh-scripts/AgentsConsoleManager.fn.sh" ) $( LC_ALL=C grep -c -F -- 'AgentsTools.ConsoleOwner.include' "$rigPackage/sh-lib/manager/AgentsTools.InternManager.include" ) $( LC_ALL=C grep -c -F -- 'AgentsToolsConsoleOwnerReentry' "$rigPackage/sh-scripts/AgentsConsoleManager.fn.sh" ) $( LC_ALL=C grep -c -F -- 'AgentsToolsConsoleOwnerReentry' "$rigPackage/sh-lib/manager/AgentsTools.InternManager.include" )" "1 1 1 1"
rigAssert "the one place holds the reading of the owner; the two starts hold none of their own" \
	"$( rigCount "$rigInclude" ) $( rigCount "$rigPackage/sh-scripts/AgentsConsoleManager.fn.sh" "$rigPackage/sh-lib/manager/AgentsTools.InternManager.include" )" "4 0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ CONSOLE OWNER RE-ENTRY CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'CONSOLE_OWNER_REENTRY: OK (%d assertions, offline)\n' "$rigPasses"
