#!/usr/bin/env bash
## setup.feature-mdci's install fragments warn and go on when an install step fails: a system is
## set up, not failed. common-mdci.3.sources.txt: a declared repository missing from the workspace
## after the sync, a failing sync, or a failing source prepare-and-pull ends it with exit 0, a
## warning naming the step (and the repositories), the public key printed (deploy-keys/<account>.pub,
## else .ssh/id_ed25519.pub), and the following steps still run; present repositories and an instance
## declaring no sources give exit 0 with no warning. common-mdci.5.workspace.txt: a failing
## integrations or restrictions op ends it with exit 0, a warning naming the step, the op's own error
## still shown, and the later steps still run. Each fragment runs under /bin/sh and under dash. A fake
## sudo (strips `-u <account> -H -s`, runs the rest), a fake chown, a stub source console and a stub
## agents tooling stand in for the host; every run is one `env -i` whose child refuses (99) unless sudo
## and chown resolve to the stubs and MDCI_HOME is inside this rig's temp tree. RIG_FRAGMENTS points at
## another directory holding the two fragments (the fail-first: a copy that stops the deploy).
## Temp tree only; no real sudo, chown, git or host.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFeature="$MDLT_ORIGIN/myx/mdci-packages-myx/setup.feature-mdci"
rigFrags="${RIG_FRAGMENTS:-$rigFeature/host/install}"
rigSources="$rigFrags/common-mdci.3.sources.txt"
rigWorkspace="$rigFrags/common-mdci.5.workspace.txt"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigSources" "$rigWorkspace" ; do
	[ -f "$rigFile" ] || rigRefuse "missing: $rigFile"
done
rigTmp="$( mktemp -d "${TMPDIR:-/tmp}/AgentsMdciInstallFailCheck.XXXXXX" )" || exit 1
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

## The fakes. sudo drops its own options up to the command; the source console records its
## stdin and answers per RIG_SYNC_RC / RIG_PREPARE_RC; the tooling answers per
## RIG_INTEGRATIONS_RC / RIG_RESTRICTIONS_RC with an error line of its own.
mkdir -p "$rigTmp/stubs"
cat > "$rigTmp/stubs/sudo" <<'RIGEOF'
#!/bin/sh
while [ $# -gt 0 ] ; do
	case "$1" in
		-u) shift 2 ;;
		-H|-s) shift ;;
		*) break ;;
	esac
done
exec "$@"
RIGEOF
printf '#!/bin/sh\nexit 0\n' > "$rigTmp/stubs/chown"
chmod +x "$rigTmp/stubs"/*
rigConsole="$rigTmp/console.stub"
cat > "$rigConsole" <<'RIGEOF'
#!/bin/sh
echo "console $*" >> "$RIG_LOG"
rigIn="$( cat )"
printf '%s\n' "$rigIn" >> "$RIG_LOG"
case "$rigIn" in
	*--execute-from-stdin-repo-list*)
		exit "${RIG_SYNC_RC:-0}" ;;
	*--execute-source-prepare-pull*)
		exit "${RIG_PREPARE_RC:-0}" ;;
esac
exit 0
RIGEOF
rigTools="$rigTmp/tools.stub"
cat > "$rigTools" <<'RIGEOF'
#!/bin/sh
echo "tools $*" >> "$RIG_LOG"
case "$1" in
	--install-workspace-integrations) [ "${RIG_INTEGRATIONS_RC:-0}" = 0 ] || { echo "⛔ ERROR: rig integrations op failed" >&2 ; exit "$RIG_INTEGRATIONS_RC" ; } ;;
	--install-workspace-restrictions) [ "${RIG_RESTRICTIONS_RC:-0}" = 0 ] || { echo "⛔ ERROR: rig restrictions op failed" >&2 ; exit "$RIG_RESTRICTIONS_RC" ; } ;;
esac
exit 0
RIGEOF
chmod +x "$rigConsole" "$rigTools"

rigNew(){ ## name, key files (both|own|none) -- a fresh MDCI_HOME in the rig, sets rigHome
	rigHome="$rigTmp/$1/home"
	mkdir -p "$rigHome/.ssh" "$rigHome/deploy-keys" "$rigHome/source" "$rigHome/.local/myx/myx.distro-agents/sh-scripts"
	cp "$rigConsole" "$rigHome/DistroSourceConsole.sh" ; chmod +x "$rigHome/DistroSourceConsole.sh"
	cp "$rigTools" "$rigHome/.local/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" ; chmod +x "$rigHome/.local/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
	: > "$rigHome/.ssh/id_ed25519"
	printf 'ssh-ed25519 OWNKEY-BBB rig\n' > "$rigHome/.ssh/id_ed25519.pub"
	[ "$2" != both ] || printf 'ssh-ed25519 DEPLOYKEY-AAA rig\n' > "$rigHome/deploy-keys/acct.pub"
	: > "$rigTmp/$1/log"
}
rigRun(){ ## name, shell, fragment, extra NAME=value... -- rc in rigRc, output in $rigTmp/<name>/out, calls in $rigTmp/<name>/log
	local runName="$1" runShell="$2" runFragment="$3" ; shift 3
	rigRc=0
	env -i PATH="$rigTmp/stubs:/bin:/usr/bin" HOME="$rigTmp" MDCI_HOME="$rigHome" MDCI_ACCOUNT=acct RIG_LOG="$rigTmp/$runName/log" RIG_TMP="$rigTmp" "$@" \
		/bin/sh -c '
			for t in sudo chown ; do case "$( command -v $t )" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; done
			case "$MDCI_HOME" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			exec "$0" "$1"
		' "$runShell" "$runFragment" > "$rigTmp/$runName/out" 2>&1 || rigRc=$?
}
rigN(){ ## file, fixed text -- how many lines hold it
	LC_ALL=C grep -c -F -- "$2" "$1" 2> /dev/null || :
}
rigLines(){ ## file -- how many lines it has
	LC_ALL=C awk 'END { print NR }' "$1"
}

rigRows(){ ## shell
	local sh="$1" sn="${1##*/}" rigDeclared
	rigDeclared="MDCI_SOURCE_ROOTS=rootA"
	rigNew "$sn-s1" both
	rigRun "$sn-s1" "$sh" "$rigSources" MDCI_SOURCE_ROOTS=rootA MDCI_SOURCE_REPOS='proj-missing,git@rig:proj-missing.git'
	echo "   [$sn] sources: a declared repository is missing after the sync"
	rigAssert "[$sn] exit 0, the deploy goes on"                 "$rigRc" 0
	rigAssert "[$sn] a warning, not an error"                    "$( LC_ALL=C grep -c 'WARNING: the repository sync did not complete' "$rigTmp/$sn-s1/out" || : )" 1
	rigAssert "[$sn] it names the repository"                    "$( LC_ALL=C grep -c 'repositories not in the workspace:.*proj-missing' "$rigTmp/$sn-s1/out" || : )" 1
	rigAssert "[$sn] the deploy key is printed"                  "$( rigN "$rigTmp/$sn-s1/out" 'DEPLOYKEY-AAA' )" 1
	rigAssert "[$sn] and the rig's own key is not"               "$( rigN "$rigTmp/$sn-s1/out" 'OWNKEY-BBB' )" 0
	rigAssert "[$sn] and no line is an error"                    "$( LC_ALL=C grep -c 'ERROR' "$rigTmp/$sn-s1/out" || : )" 0
	rigAssert "control: the sync really ran"                     "$( rigN "$rigTmp/$sn-s1/log" 'DistroImageSync --execute-from-stdin-repo-list' )" 1
	rigAssert "[$sn] and the prepare-and-pull ran after the warning" "$( rigN "$rigTmp/$sn-s1/log" 'execute-source-prepare-pull' )" 1

	rigNew "$sn-s2" own
	rigRun "$sn-s2" "$sh" "$rigSources" MDCI_SOURCE_ROOTS=rootA MDCI_SOURCE_REPOS='proj-missing,git@rig:proj-missing.git'
	echo "   [$sn] sources: only the rig's own key exists"
	rigAssert "[$sn] exit 0"                                     "$rigRc" 0
	rigAssert "[$sn] its own key is printed"                     "$( rigN "$rigTmp/$sn-s2/out" 'OWNKEY-BBB' )" 1
	rigAssert "[$sn] and no deploy key is invented"              "$( rigN "$rigTmp/$sn-s2/out" 'DEPLOYKEY' )" 0

	rigNew "$sn-s3" both
	mkdir -p "$rigHome/source/proj-here/.git"
	rigRun "$sn-s3" "$sh" "$rigSources" MDCI_SOURCE_ROOTS=rootA MDCI_SOURCE_REPOS='proj-here,git@rig:proj-here.git'
	echo "   [$sn] sources: the declared repository is present"
	rigAssert "[$sn] exit 0"                                     "$rigRc" 0
	rigAssert "[$sn] no output at all"                           "$( rigLines "$rigTmp/$sn-s3/out" )" 0
	rigAssert "control: the prepare-and-pull ran"                "$( rigN "$rigTmp/$sn-s3/log" 'execute-source-prepare-pull' )" 1

	rigNew "$sn-s4" both
	mkdir -p "$rigHome/source/proj-here/.git"
	rigRun "$sn-s4" "$sh" "$rigSources" MDCI_SOURCE_ROOTS=rootA MDCI_SOURCE_REPOS='proj-here,git@rig:proj-here.git' RIG_PREPARE_RC=3
	echo "   [$sn] sources: the prepare-and-pull fails"
	rigAssert "[$sn] exit 0"                                     "$rigRc" 0
	rigAssert "[$sn] a warning says which step"                  "$( LC_ALL=C grep -c 'WARNING: source prepare and pull did not complete' "$rigTmp/$sn-s4/out" || : )" 1
	rigAssert "[$sn] and prints the key"                         "$( rigN "$rigTmp/$sn-s4/out" 'DEPLOYKEY-AAA' )" 1
	rigAssert "control: the repository was present, so only the pull warned" "$( rigN "$rigTmp/$sn-s4/out" 'repositories not in the workspace' )" 0

	rigNew "$sn-s5" both
	mkdir -p "$rigHome/source/proj-here/.git"
	rigRun "$sn-s5" "$sh" "$rigSources" MDCI_SOURCE_ROOTS=rootA MDCI_SOURCE_REPOS='proj-here,git@rig:proj-here.git' RIG_SYNC_RC=1
	echo "   [$sn] sources: the sync exits non-zero though the repository is on disk"
	rigAssert "[$sn] exit 0 with the warning"                    "$rigRc $( LC_ALL=C grep -c 'WARNING: the repository sync did not complete' "$rigTmp/$sn-s5/out" || : )" "0 1"
	rigAssert "[$sn] and the pull still ran"                     "$( rigN "$rigTmp/$sn-s5/log" 'execute-source-prepare-pull' )" 1

	rigNew "$sn-s6" both
	rigRun "$sn-s6" "$sh" "$rigSources"
	echo "   [$sn] sources: the instance declares none"
	rigAssert "[$sn] exit 0"                                     "$rigRc" 0
	rigAssert "[$sn] it says so and does no sync"                "$( rigN "$rigTmp/$sn-s6/out" 'declares no MDCI_SOURCE_ROOTS' ) $( rigN "$rigTmp/$sn-s6/log" 'DistroImageSync' )" "1 0"

	echo "   [$sn] workspace: everything succeeds"
	rigNew "$sn-w0" none
	rigRun "$sn-w0" "$sh" "$rigWorkspace" MDCI_SOURCE_ROOTS=rootA MDCI_SOURCE_REPOS='proj-here,git@rig:proj-here.git' MDCI_TEAM_DATA_DIRECTORY=/rig/td
	rigAssert "[$sn] exit 0"                                     "$rigRc" 0
	rigAssert "[$sn] no output"                                  "$( rigLines "$rigTmp/$sn-w0/out" )" 0
	rigAssert "control: both ops ran, integrations first"        "$( LC_ALL=C awk '/^tools --install-workspace-(integrations|restrictions)/ { printf "%s ", $2 }' "$rigTmp/$sn-w0/log" )" "--install-workspace-integrations --install-workspace-restrictions "
	rigAssert "control: the team-data setting after them was written" "$( rigN "$rigTmp/$sn-w0/log" '--agents-config-option magic-coordinator --upsert-from-stdin TEAM_DATA_DIRECTORY' )" 1

	echo "   [$sn] workspace: integrations fail, sources declared"
	rigNew "$sn-w1" none
	rigRun "$sn-w1" "$sh" "$rigWorkspace" MDCI_SOURCE_ROOTS=rootA MDCI_SOURCE_REPOS='proj-here,git@rig:proj-here.git' RIG_INTEGRATIONS_RC=4 MDCI_TEAM_DATA_DIRECTORY=/rig/td
	rigAssert "[$sn] exit 0"                                     "$rigRc" 0
	rigAssert "[$sn] a warning naming the step"                  "$( rigN "$rigTmp/$sn-w1/out" 'WARNING: workspace integrations not reconciled' )" 1
	rigAssert "[$sn] the op's own error is still shown"          "$( rigN "$rigTmp/$sn-w1/out" 'rig integrations op failed' )" 1
	rigAssert "[$sn] the restrictions op still ran"              "$( rigN "$rigTmp/$sn-w1/log" 'install-workspace-restrictions' )" 1
	rigAssert "[$sn] and so did the team-data setting after it"  "$( rigN "$rigTmp/$sn-w1/log" 'TEAM_DATA_DIRECTORY' )" 1

	echo "   [$sn] workspace: integrations fail, no sources declared"
	rigNew "$sn-w2" none
	rigRun "$sn-w2" "$sh" "$rigWorkspace" RIG_INTEGRATIONS_RC=4
	rigAssert "[$sn] exit 0 with the same warning"               "$rigRc $( rigN "$rigTmp/$sn-w2/out" 'WARNING: workspace integrations not reconciled' )" "0 1"

	echo "   [$sn] workspace: restrictions fail"
	rigNew "$sn-w3" none
	rigRun "$sn-w3" "$sh" "$rigWorkspace" MDCI_SOURCE_ROOTS=rootA MDCI_SOURCE_REPOS='proj-here,git@rig:proj-here.git' RIG_RESTRICTIONS_RC=5 MDCI_TEAM_DATA_DIRECTORY=/rig/td
	rigAssert "[$sn] exit 0"                                     "$rigRc" 0
	rigAssert "[$sn] a warning naming the step"                  "$( rigN "$rigTmp/$sn-w3/out" 'WARNING: workspace restrictions not reconciled' )" 1
	rigAssert "[$sn] the op's own error is still shown"          "$( rigN "$rigTmp/$sn-w3/out" 'rig restrictions op failed' )" 1
	rigAssert "control: the integrations op ran first"           "$( rigN "$rigTmp/$sn-w3/log" 'install-workspace-integrations' )" 1
	rigAssert "[$sn] and the team-data setting after it was written" "$( rigN "$rigTmp/$sn-w3/log" 'TEAM_DATA_DIRECTORY' )" 1
}

echo "-- the fragments parse --"
for rigFrag in "$rigSources" "$rigWorkspace" ; do
	rigAssert "bash -n ${rigFrag##*/}"                       "$( bash -n "$rigFrag" 2>&1 && printf ok )" ok
	rigAssert "dash -n ${rigFrag##*/}"                       "$( /bin/dash -n "$rigFrag" 2>&1 && printf ok )" ok
done
echo "-- under /bin/sh --"
rigRows /bin/sh
echo "-- under dash --"
[ -x /bin/dash ] || rigRefuse "no /bin/dash on this machine, so the dash half cannot run"
rigRows /bin/dash

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MDCI INSTALL FAIL CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MDCI_INSTALL_FAIL: OK (%d assertions, offline, stubs only)\n' "$rigPassCount"
