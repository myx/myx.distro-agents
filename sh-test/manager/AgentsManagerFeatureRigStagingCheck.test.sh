#!/usr/bin/env bash
## Behavioural check on the two things a rig needs before its console's `Optional Features` can list anything, in the
## order they depend on each other:
##   1. the feature family is where the lister's folder fallback looks, `<workspace>/.local/myx/mdci-packages-myx/`, and
##      with it there `--manager-feature-list` names `setup.feature-lancedb` and `setup.feature-local-ai`, each an eleven
##      field row with a state word the screen colours. Family placed by this check, so this row says the lister answers
##      that shape. It is also the row that makes row 3 worth reading: the predicate is seen to pass.
##   2. the same list through the console's own tool, `DistroLocalTools --manager-feature-list`, the operation the screen's
##      `list:features` read calls.
##   3. the installer fragment that clones the source, `common-mdci.3.sources.txt`, puts the family at that same `.local`
##      path. Nothing else on a rig does, and without it the two rows above answer nothing on the rig itself.
## Measured before this check was written, at 15:56 +0200 by magic-devops: with the family at
## `<workspace>/.local/myx/mdci-packages-myx/` the names printed, and with it only in `source/myx/` they did not, because
## the declares path is prefixed with `$MDLT_ORIGIN`, which is the workspace's `.local` on a rig.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigTree="$MDLT_ORIGIN"
rigFragment="$rigTree/myx/mdci-packages-myx/setup.machine-mdci/host/install/common-mdci.3.sources.txt"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTree/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" ] || \
	rigRefuse "the tool is not at the origin this workspace resolves: $rigTree"
[ -d "$rigTree/myx/mdci-packages-myx" ] || rigRefuse "the mdci packages are not at the origin: $rigTree/myx/mdci-packages-myx"
[ -f "$rigFragment" ] || rigRefuse "the sources fragment is not at the origin: $rigFragment"
. "$rigTree/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerFeatureRigStagingCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}

## THE RIG: the packages the console runs on in `.local/myx`, no mdci-packages-myx anywhere until this check puts it where
## the installer must, and a source that holds one repository and no feature project.
rigOrigin="$rigTmp/origin" rigWs="$rigTmp/ws" rigHome="$rigTmp/home"
mkdir -p "$rigOrigin/myx" "$rigWs/.local/myx" "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigWs/.local/system-index" \
	"$rigWs/source/rig-repository" "$rigHome/.agents" || exit 1
for rigEntry in "$rigTree/myx"/* ; do
	[ -d "$rigEntry" ] || continue
	case "${rigEntry##*/}" in mdci-packages-myx) continue ;; esac
	rigCopyTree "$rigEntry" "$rigOrigin/myx/${rigEntry##*/}" || exit 1
done
for rigEntry in "$rigOrigin/myx"/* ; do
	case "${rigEntry##*/}" in myx.*|mdci-packages-*) rigCopyTree "$rigEntry" "$rigWs/.local/myx/${rigEntry##*/}" || exit 1 ;; esac
done
: > "$rigWs/.local/system-index/distro-declares.txt" || exit 1
printf 'Name: rig-repository\n' > "$rigWs/source/rig-repository/repository.inf" || exit 1

rigRun(){ ## tool path, arguments... -- one console call from the rig workspace, its streams in $rigTmp/out and err
	local runTool="$1" ; shift
	rigRc=0
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDLT_ORIGIN="$rigWs/.local" MDLT_OPTION="--run-from-path $rigWs/.local" \
		bash "$runTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigNamesBoth(){ ## -- `both` when the last stdout names both features, else the names it gave
	rigHeld="$( LC_ALL=C awk -F'\t' '$1 == "feature" { print $2 ; }' "$rigTmp/out" | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )"
	case "$rigHeld" in
		*setup.feature-lancedb*setup.feature-local-ai*|*setup.feature-local-ai*setup.feature-lancedb*) printf 'both' ;;
		*) printf '%s' "$rigHeld" ;;
	esac
}

echo "-- 0. the rig before the family is placed, which is the rig today --"
rigRun "$rigWs/.local/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --manager-feature-list
rigAssert "with no family under the origin, the list names nothing: this is the state the console reports as empty" \
	"$( printf '%s' "$rigRc" ) $( rigNamesBoth )" "0 "

echo "-- 1. the family where the folder fallback looks --"
rigCopyTree "$rigTree/myx/mdci-packages-myx" "$rigWs/.local/myx/mdci-packages-myx" || exit 1
rigAssert "the family is now at .local/myx/mdci-packages-myx, as an installed rig's must be" \
	"$( [ -f "$rigWs/.local/myx/mdci-packages-myx/setup.feature-lancedb/project.inf" ] && echo present || echo absent )" "present"
rigRun "$rigWs/.local/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --manager-feature-list
rigAssert "the console's own tool ends 0 and names both features" "$( printf '%s' "$rigRc" ) $( rigNamesBoth )" "0 both"
rigAssert "each of the two is a feature row of eleven fields carrying a state word the screen colours" \
	"$( LC_ALL=C awk -F'\t' '$1 != "feature" { next ; } $2 == "setup.feature-lancedb" || $2 == "setup.feature-local-ai" { seen++ ; if ( NF == 11 && ( $4 == "installed" || $4 == "not-installed" || $4 == "broken" || $4 == "unsupported" ) ) { held++ ; } ; } END { printf "%s %s", seen+0, held+0 ; ;}' "$rigTmp/out" )" "2 2"
echo "-- 2. and through the console's own tool --"
rigRun "$rigWs/.local/myx/myx.distro-.local/sh-scripts/DistroLocalTools.fn.sh" --manager-feature-list
rigAssert "DistroLocalTools --manager-feature-list ends 0 and names the same two features" \
	"$( printf '%s' "$rigRc" ) $( rigNamesBoth )" "0 both"

echo "-- 3. the installer places the family there, so a rig reaches row 1 by itself --"
rigAssert "common-mdci.3.sources.txt copies the family into the workspace's own .local/myx" \
	"$( LC_ALL=C grep -c -E '(\.local/myx|MDCI_HOME.*\.local).*mdci-packages-myx|mdci-packages-myx.*\.local' "$rigFragment" )" "1"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MANAGER FEATURE RIG STAGING CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_FEATURE_RIG_STAGING: OK (%d assertions, offline, rig tree only, no rig touched)\n' "$rigPasses"
