#!/usr/bin/env bash
## Behavioural check on the person at the console, the account every action of the console is recorded under (user-<account>): ONE PLACE says it, AgentsToolsConsoleAccount
## (sh-lib/member/AgentsTools.CallerCheck.include), and every caller takes it from there. Held: where sudo was used and SUDO_USER is set, that is the person, root included
## (a root login acting as the account mdci is told from the native mdci); else the effective account of the process (`id -un`; the USER or the LOGNAME of the environment where
## the system gives none); with no account at all, nothing and a refusal, never a name made up. Run with a stand-in `id` first on PATH, so that the effective account is the
## rig's own. Each caller: the team member the common options default to (--intern-context-show), the name a console answer or a message is recorded under
## (AgentsToolsManagerConsoleMember, AgentsToolsManagerConsoleUser), and the caller of the authority gate (agentsAuthorityCallerId); and no other file of these asks the system
## for the account itself. Offline.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTools="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTools" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTools"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsConsolePersonCheck )" || exit 1
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
mkdir -p "$rigWs/.local/temp" "$rigWs/.local/.agents" "$rigHome" "$rigBin"
## the effective account is whatever RIG_ID says; none where it is empty (the system gives no account)
printf '#!/bin/sh\n[ "$*" = "-un" ] || exec /usr/bin/id "$@"\n[ -n "${RIG_ID:-}" ] || exit 1\necho "$RIG_ID"\n' > "$rigBin/id"
chmod +x "$rigBin/id"
rigRun(){ ## effective account, USER, SUDO_USER, script -- the output of a script run in the rig's environment with exactly those, in the rig's workspace
	local runId="$1" runUser="$2" runSudo="$3" runScript="$4"
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$rigBin:$PATH" RIG_ID="$runId" ${runUser:+USER="$runUser"} ${runSudo:+SUDO_USER="$runSudo"} MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDSC_CMD=rig bash -c "$runScript" ) 2> /dev/null
}
rigAccount='. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.CallerCheck.include" ; AgentsToolsConsoleAccount ; echo "rc=$?"'
rigLine(){ rigRun "$@" | LC_ALL=C tr '\n' ' ' ; }

echo "-- the one place: sudo, root included, else the effective account, else nothing --"
rigAssert "a console reached with sudo from myx into the account mdci: the person is myx" "$( rigLine mdci mdci myx "$rigAccount" )" "myx rc=0 "
rigAssert "one reached from a root login by sudo into mdci: the person is root, told from the native mdci" "$( rigLine mdci mdci root "$rigAccount" )" "root rc=0 "
rigAssert "with no sudo: the account itself" "$( rigLine mdci mdci '' "$rigAccount" )" "mdci rc=0 "
rigAssert "where the system gives no account, the USER of the environment, and the LOGNAME after it" "$( rigLine '' nikitine '' "$rigAccount" ) $( rigRun '' '' '' 'LOGNAME=pat; export LOGNAME; '"$rigAccount" | LC_ALL=C tr '\n' ' ' )" "nikitine rc=0  pat rc=0 "
rigAssert "with none at all: nothing, and the refusal rc 1" "$( rigLine '' '' '' "$rigAccount" )" "rc=1 "
rigAssert "a blank in a name is one underscore" "$( rigLine mdci mdci 'my x' "$rigAccount" )" "my_x rc=0 "

echo "-- every caller takes it from there --"
rigContext(){ ## effective account, USER, SUDO_USER -- the team member the common options default to
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$rigBin:$PATH" RIG_ID="$1" ${2:+USER="$2"} ${3:+SUDO_USER="$3"} MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		bash "$rigTools" --intern-context-show ) 2> /dev/null | LC_ALL=C sed -n 's/^team-member: //p' | head -1
}
rigAssert "the team member of the common options: user-myx under sudo from myx, user-root under sudo from root, user-mdci with no sudo" "$( rigContext mdci mdci myx ) $( rigContext mdci mdci root ) $( rigContext mdci mdci '' )" "user-myx user-root user-mdci"
rigAssert "and none with no account: the call is refused for want of a member" "[$( rigContext '' '' '' )]" "[]"
rigMember='set -- --x ; . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsTools.ManagerSession.include" > /dev/null 2>&1 ; echo "$( AgentsToolsManagerConsoleMember ):$( AgentsToolsManagerConsoleUser ):$( AgentsToolsManagerConsoleAccount )"'
rigAssert "what a console answer, a message and a kill are recorded under: the member, the user and the account, from the person" "$( rigLine mdci mdci myx "$rigMember" ) $( rigLine mdci mdci root "$rigMember" ) $( rigLine mdci mdci '' "$rigMember" ) $( rigLine '' '' '' "$rigMember" )" "user-myx:myx:myx  user-root:root:root  user-mdci:mdci:mdci  :unknown: "
rigGate='. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/questions/AgentsTools.Authority.include" > /dev/null 2>&1 ; AgentsToolsAuthorityCaller ; echo "$agentsAuthorityCallerKind:$agentsAuthorityCallerId"'
rigAssert "the caller of the authority gate: the person, as user-<account>" "$( rigLine mdci mdci myx "$rigGate" ) $( rigLine mdci mdci root "$rigGate" ) $( rigLine mdci mdci '' "$rigGate" )" "person:user-myx  person:user-root  person:user-mdci "

echo "-- and no other place asks the system for the account --"
rigCount(){ ## file... -- how many lines that are no comment ask `id -un` or SUDO_USER
	cat "$@" | LC_ALL=C grep -v '^[[:space:]]*#' | LC_ALL=C grep -c -e 'id -un' -e 'SUDO_USER' || :
}
rigAssert "the layer of the callers holds the one reading of the account; the console's account, its member, the authority gate and the common options hold none of their own" \
	"$( rigCount "$rigPackage/sh-lib/member/AgentsTools.CallerCheck.include" ) $( rigCount "$rigPackage/sh-lib/manager/AgentsTools.ManagerSession.include" ) $( rigCount "$rigPackage/sh-lib/questions/AgentsTools.Authority.include" ) $( rigCount "$rigPackage/sh-lib/common/AgentsTools.CommonOptions.include" ) $( rigCount "$rigPackage/sh-lib/inbox/AgentsTools.InternOpMemberInboxUpsert.include" "$rigPackage/sh-lib/board/AgentsTools.InternOpBoardUpsertMoveEdit.include" )" "2 0 0 0 0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ CONSOLE PERSON CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'CONSOLE_PERSON: OK (%d assertions, offline)\n' "$rigPasses"
