#!/usr/bin/env bash
## Behavioural check on the caller-check layer lifted into a shared include (F1.2 of the refactorings epic): the three
## checks AgentsToolsMagicCallerCheck, AgentsToolsClientCallerCheck and AgentsToolsManagerCallerCheck move verbatim
## from `sh-lib/harness/AgentsContext.UseAgentsTools.include` (an entry-point include: it turns on `set -e`, runs `local`, and
## may clone the team data) into a side-effect-free `sh-lib/member/AgentsTools.CallerCheck.include`, which UseAgentsTools
## sources. A stand-in .fn.sh of this rig sources that include alone, and asks each check what the dispatcher asks
## for a --magic-*, a --client-* and a --manager-* operation.
## Held:
##   0. guard: sourcing the include has no side effect: no `set -e`, no variable set but the functions it defines,
##      no output, and no team-data access (no file of the data root made or changed, and no git started)
##   1. the include is there, and a .fn.sh that sources only it can call the three checks
##   2. --magic-*: the console and magic-coordinator's session pass; another member's session is refused
##   3. --client-*: the console and the named client's own session pass; another member's session is refused
##   4. --manager-*: the console passes; a member's session, magic-coordinator's among them, is refused
##   5. each refusal is word for word the refusal the dispatcher gives for that call
##   6. AgentsToolsActingMemberCheck's and AgentsToolsManagerCallerCheck's own refusals name who owns the operation
##      and how to ask, or where to run it instead (S18.1).
## Red before F1.2: no such include, so no .fn.sh but the dispatcher can ask (every case fails).
## Offline: a rig workspace and member set of this check's own; no operation of the tooling acts.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigInclude="$rigPackage/sh-lib/member/AgentsTools.CallerCheck.include"
rigFn="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigFn" ] || rigRefuse "the dispatcher is not at the origin this workspace resolves: $rigFn"
## It names the advance scan, only to be refused for it: the guard reads names, so the rig ends threads all the same.
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
rigTmp="$( mkdir -p "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsCallerCheckSharedCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws/.local/.agents" "$rigTmp/home" "$rigTmp/data"
for rigName in magic-coordinator keeper-myx client-ndm ; do
	mkdir -p "$rigTmp/skills/$rigName"
	printf 'rig\n' > "$rigTmp/skills/$rigName/$rigName.basic.md"
	printf 'rig\n' > "$rigTmp/skills/$rigName/$rigName.armed.md"
done
## The stand-in .fn.sh: the shared include alone, then the check its arguments name.
printf '#!/usr/bin/env bash\nMDSC_CMD=DistroAgentsTools\n. "%s" || exit 97\n"$@"\n' "$rigInclude" > "$rigTmp/RigStandIn.fn.sh"
## The guard's probe: what sourcing the include changes in a shell -- its options, its variables, its functions,
## its output -- with a git that notes any start first on PATH and a team-data root that holds one file.
mkdir -p "$rigTmp/bin" "$rigTmp/probe-data"
printf 'rig\n' > "$rigTmp/probe-data/rig-item.md"
printf '#!/bin/sh\necho "git $*" >> "%s/git.calls"\nexit 1\n' "$rigTmp" > "$rigTmp/bin/git" ; chmod +x "$rigTmp/bin/git"
printf '%s\n' '#!/usr/bin/env bash' \
	'rigVars(){ compgen -v | LC_ALL=C grep -v -x -E "_|BASH_.*|FUNCNAME|PIPESTATUS|LINENO|RANDOM|SECONDS|COMP_WORDBREAKS|rigVarsBefore|rigFnsBefore|rigOptsBefore" | LC_ALL=C sort ; }' \
	'rigVarsBefore="$( rigVars )" ; rigFnsBefore="$( compgen -A function | LC_ALL=C sort )" ; rigOptsBefore="$-"' \
	'. "$1" > "$RIG_TMP/probe.said" 2>&1 || echo "rc=$?" >> "$RIG_TMP/probe.said"' \
	'case "$-" in *e*) echo "options: set -e" ;; *) echo "options: as they were" ;; esac' \
	'echo "variables: $( comm -13 <( printf "%s\n" "$rigVarsBefore" ) <( rigVars ) | LC_ALL=C tr "\n" " " )"' \
	'echo "functions: $( comm -13 <( printf "%s\n" "$rigFnsBefore" ) <( compgen -A function | LC_ALL=C sort ) | LC_ALL=C tr "\n" " " )"' > "$rigTmp/probe.sh"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One call as a caller: the console (no session), or a member's session. rc in <name>.rc, stderr in <name>.err.
rigAs(){ ## result name, member or console, command...
	local asName="$1" asWho="$2" ; shift 2
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigTmp/data" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		$( [ "$asWho" = console ] || printf 'MDAT_SPAWN_AGENT=%s MDAT_SPAWN_SESSION_ID=rig-caller-%s' "$asWho" "$asWho" ) \
		bash -c 'cd "$MMDAPP" && exec bash "$@"' rig "$@" > "$rigTmp/$asName.out" 2> "$rigTmp/$asName.err" < /dev/null
	printf '%s' "$?" > "$rigTmp/$asName.rc"
}
rigRc(){ cat "$rigTmp/$1.rc" ; }
rigRefusalOf(){ ## result name -- its first error line, the tooling's own lines of start left out, or none
	local refusalLine
	refusalLine="$( LC_ALL=C grep -F '⛔' "$rigTmp/$1.err" | LC_ALL=C grep -v -e 'SetInputSpec' -e 'SystemContext' | head -1 )"
	printf '%s' "${refusalLine:-none}"
}

echo "-- 0. guard: sourcing the include has no side effect --"
( cd "$rigTmp/ws" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigTmp/probe-data" MDLT_ORIGIN="$MDLT_ORIGIN" \
	RIG_TMP="$rigTmp" bash "$rigTmp/probe.sh" "$rigInclude" ) > "$rigTmp/probe.out" 2>&1 < /dev/null
rigProbe(){ LC_ALL=C sed -n "s/^$1: //p" "$rigTmp/probe.out" | head -1 ; }
rigAssert "it sources cleanly, saying nothing"                ["$( [ -f "$rigInclude" ] && echo there || echo missing ):$( cat "$rigTmp/probe.said" 2> /dev/null | LC_ALL=C tr '\n' ' ' )]" "[there:]"
rigAssert "no set -e"                                         "$( rigProbe options )" "as they were"
rigAssert "no variable set"                                   "[$( rigProbe variables | LC_ALL=C sed -e 's/ $//' )]" "[]"
rigAssert "the three checks are among the functions it defines" "$( for rigFn in AgentsToolsMagicCallerCheck AgentsToolsClientCallerCheck AgentsToolsManagerCallerCheck ; do rigProbe functions | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c -x "$rigFn" ; done | LC_ALL=C tr '\n' ' ' )" "1 1 1 "
rigAssert "no team-data access: the data root as it was, and no git started" "$( ls -A "$rigTmp/probe-data" | LC_ALL=C tr '\n' ' ' ):$( [ -s "$rigTmp/git.calls" ] && echo git || echo none )" "rig-item.md :none"

echo "-- 1. the include is there, and a stand-in .fn.sh calls the three checks through it --"
rigAssert "the shared include exists"                         "$( [ -f "$rigInclude" ] && printf exists || printf missing )" exists
rigAs probe console "$rigTmp/RigStandIn.fn.sh" type AgentsToolsMagicCallerCheck AgentsToolsClientCallerCheck AgentsToolsManagerCallerCheck
rigAssert "the three checks are defined there, and nothing else is needed" "$( rigRc probe ):$( LC_ALL=C grep -c 'is a function' "$rigTmp/probe.out" )" "0:3"

echo "-- 1b. AgentsToolsActingMemberCheck: its refusal names who owns it and how to ask (S18.1) --"
rigAs a1 keeper-myx "$rigTmp/RigStandIn.fn.sh" AgentsToolsActingMemberCheck magic-coordinator advance-to-running
rigActingWay(){ ## refusal text -> whether it names the member and the coordinator's own way to ask: yes|no
	case "$1" in *"ask magic-coordinator to run it, or the session's magic-coordinator to spawn one that acts as magic-coordinator"*) printf yes ;; *) printf no ;; esac
}
rigAssert "it is refused, naming the member and the way to ask" "$( [ "$( rigRc a1 )" -ne 0 ] && printf refused || printf passed ):$( rigActingWay "$( rigRefusalOf a1 )" )" "refused:yes"

echo "-- 2. --magic-* --"
rigAs m1 console "$rigTmp/RigStandIn.fn.sh" AgentsToolsMagicCallerCheck advance-to-running
rigAs m2 magic-coordinator "$rigTmp/RigStandIn.fn.sh" AgentsToolsMagicCallerCheck advance-to-running
rigAs m3 keeper-myx "$rigTmp/RigStandIn.fn.sh" AgentsToolsMagicCallerCheck advance-to-running
rigAssert "the console and the coordinator pass, another member is refused" "$( rigRc m1 ):$( rigRc m2 ):$( [ "$( rigRc m3 )" -ne 0 ] && printf refused || printf passed )" "0:0:refused"

echo "-- 3. --client-* --"
rigAs c1 console "$rigTmp/RigStandIn.fn.sh" AgentsToolsClientCallerCheck client-ndm client-comms-slack-read
rigAs c2 client-ndm "$rigTmp/RigStandIn.fn.sh" AgentsToolsClientCallerCheck client-ndm client-comms-slack-read
rigAs c3 keeper-myx "$rigTmp/RigStandIn.fn.sh" AgentsToolsClientCallerCheck client-ndm client-comms-slack-read
rigAssert "the console and the client's own session pass, another member is refused" "$( rigRc c1 ):$( rigRc c2 ):$( [ "$( rigRc c3 )" -ne 0 ] && printf refused || printf passed )" "0:0:refused"

echo "-- 4. --manager-* --"
rigAs g1 console "$rigTmp/RigStandIn.fn.sh" AgentsToolsManagerCallerCheck manager-session-list
rigAs g2 magic-coordinator "$rigTmp/RigStandIn.fn.sh" AgentsToolsManagerCallerCheck manager-session-list
rigAs g3 keeper-myx "$rigTmp/RigStandIn.fn.sh" AgentsToolsManagerCallerCheck manager-session-list
rigRedirect(){ ## refusal text -> whether it says who owns the operation and how to ask: yes|no
	case "$1" in *"ask the session's magic-coordinator, which owns it, to run it"*) printf yes ;; *) printf no ;; esac
}
rigAssert "the refusal of a coordinator's operation says who owns it and how to ask, as the --client-* refusal does" "$( rigRedirect "$( rigRefusalOf m3 )" ):$( rigRedirect "$( rigRefusalOf c3 )" )" "yes:no"
rigAssert "control: a refusal with no redirect, as the line was before, does not pass for one" "$( rigRedirect "AgentsToolsMagicCallerCheck: x: ⛔ ERROR: this session acts as keeper-myx, and x is magic-coordinator's only -- nothing was done" )" "no"
rigClientWay(){ ## refusal text -> whether it names the coordinator that can run the operation as the client: yes|no
	case "$1" in *"ask the session's magic-coordinator, which can run it as "*) printf yes ;; *) printf no ;; esac
}
rigAssert "the --client-* refusal names its own way (the coordinator that can run it as the client)" "$( rigClientWay "$( rigRefusalOf c3 )" )" "yes"
rigAssert "the console passes; a member's session, the coordinator's among them, is refused" "$( rigRc g1 ):$( [ "$( rigRc g2 )" -ne 0 ] && printf refused || printf passed ):$( [ "$( rigRc g3 )" -ne 0 ] && printf refused || printf passed )" "0:refused:refused"
rigManagerWay(){ ## refusal text -> whether it says where the operation is run instead: yes|no
	case "$1" in *"run it at the console directly, outside any member's session"*) printf yes ;; *) printf no ;; esac
}
rigAssert "the --manager-* refusal says where it is run instead (S18.1)" "$( rigManagerWay "$( rigRefusalOf g3 )" )" yes

echo "-- 5. each refusal is the dispatcher's own, word for word --"
rigAs dm keeper-myx "$rigFn" --advance-to-running magic-coordinator
rigAs dc keeper-myx "$rigFn" --client-comms-slack-read client-ndm
rigAs dg magic-coordinator "$rigFn" --manager-session-list
rigAssert "control: the dispatcher refuses the three, each with a refusal" "$( [ "$( rigRc dm )" -ne 0 ] && [ "$( rigRc dc )" -ne 0 ] && [ "$( rigRc dg )" -ne 0 ] && printf refused || printf passed ):$( [ "$( rigRefusalOf dm )" != none ] && [ "$( rigRefusalOf dc )" != none ] && [ "$( rigRefusalOf dg )" != none ] && printf said || printf unsaid )" refused:said
rigAssert "the coordinator's own operations: the same refusal, but for the name of the tool file that says it" "$( rigRefusalOf m3 )" "$( rigRefusalOf dm | LC_ALL=C sed 's/^DistroAgentsItems:/DistroAgentsTools:/' )"
rigAssert "--client-*: the same refusal"                      "$( rigRefusalOf c3 )" "$( rigRefusalOf dc )"
rigAssert "--manager-*: the same refusal"                     "$( rigRefusalOf g2 )" "$( rigRefusalOf dg )"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ CALLER CHECK SHARED CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'CALLER_CHECK_SHARED: OK (%d assertions, offline)\n' "$rigPassCount"
