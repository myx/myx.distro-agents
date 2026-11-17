#!/usr/bin/env bash
## Behavioural check on sh-lib/session/AgentsSessionParts.include, the small file the client hooks read instead of the session
## concern's whole store include: the sessions store's leaf and its builders, generated from
## sh-lib/session/AgentsTools.SessionStore.include by sh-scripts/AgentsSessionPartsMake.sh. Held:
##   1. the file is exactly what its generator prints from the store include, and the generator's --check says so
##   2. a store whose leaf moved, and nothing else, makes the check fail: the drift is caught rather than shipped
##   3. a store whose builder moved, and nothing else, makes the check fail: every block the parts file carries is watched
##   4. control: the untouched copy of both files passes, so the two failures above are the edit and not the instrument
##   5. the builders answer what the store include's own answer: one folder for one session, and one file of it
## Offline: two package copies under one temp tree, no operation of the real tooling, no network.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigScripts="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-scripts"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHere/session/AgentsSessionParts.include" ] || rigRefuse "the parts file is missing from the package: $rigHere/session/AgentsSessionParts.include"
[ -f "$rigScripts/AgentsSessionPartsMake.sh" ] || rigRefuse "the parts generator is missing from the package: $rigScripts/AgentsSessionPartsMake.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionPartsCheck )" || exit 1
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
## A package copy holding the two files this check compares, and the generator beside them: one `sh-lib/session` and one `sh-scripts`.
rigPackage(){ ## folder name
	local copyRoot="$rigTmp/$1"
	mkdir -p "$copyRoot/sh-lib/session" "$copyRoot/sh-scripts"
	cp "$rigHere/session/AgentsTools.SessionStore.include" "$rigHere/session/AgentsSessionParts.include" "$copyRoot/sh-lib/session/"
	cp "$rigScripts/AgentsSessionPartsMake.sh" "$copyRoot/sh-scripts/"
	printf '%s' "$copyRoot"
}
rigCheck(){ ## package copy -- the generator's --check, its rc
	bash "$1/sh-scripts/AgentsSessionPartsMake.sh" "$1" --check > "$rigTmp/check.out" 2> "$rigTmp/check.err"
	rigCheckRc=$?
}

echo "-- 1. the file is what the generator prints --"
rigCopy="$( rigPackage same )"
bash "$rigCopy/sh-scripts/AgentsSessionPartsMake.sh" "$rigCopy" --print > "$rigTmp/printed" 2> /dev/null
rigAssert "the generator prints the package's own parts file" \
	"$( cmp -s "$rigTmp/printed" "$rigHere/session/AgentsSessionParts.include" && printf same || printf differs )" "same"
rigCheck "$rigCopy"
rigAssert "and --check passes on that pair" "$rigCheckRc" "0"

echo "-- 2. the store's leaf moved alone --"
rigCopy="$( rigPackage leaf )"
LC_ALL=C sed 's|^agentsSessionStoreLeaf="\(.*\)"$|agentsSessionStoreLeaf="\1-moved"|' "$rigCopy/sh-lib/session/AgentsTools.SessionStore.include" > "$rigTmp/store.moved"
cmp -s "$rigTmp/store.moved" "$rigCopy/sh-lib/session/AgentsTools.SessionStore.include" && rigRefuse "the leaf is not where this check moves it: the store include names no agentsSessionStoreLeaf"
mv -f "$rigTmp/store.moved" "$rigCopy/sh-lib/session/AgentsTools.SessionStore.include"
rigCheck "$rigCopy"
rigAssert "the drift is caught: --check fails, and says the parts file is not what the store gives" \
	"$rigCheckRc:$( LC_ALL=C grep -c 'is not what the store include gives' "$rigTmp/check.err" )" "1:1"

echo "-- 3. a builder moved alone --"
rigCopy="$( rigPackage builder )"
LC_ALL=C sed 's|^AgentsSessionFolderInto(){|AgentsSessionFolderIntoRenamed(){|' "$rigCopy/sh-lib/session/AgentsTools.SessionStore.include" > "$rigTmp/store.renamed"
cmp -s "$rigTmp/store.renamed" "$rigCopy/sh-lib/session/AgentsTools.SessionStore.include" && rigRefuse "the builder is not where this check renames it: the store include defines no AgentsSessionFolderInto"
mv -f "$rigTmp/store.renamed" "$rigCopy/sh-lib/session/AgentsTools.SessionStore.include"
rigCheck "$rigCopy"
rigAssert "every block is watched, not the leaf alone: --check fails" "$rigCheckRc" "1"

echo "-- 4. control: the untouched copy passes --"
rigCopy="$( rigPackage control )"
rigCheck "$rigCopy"
rigAssert "control: the same two files, untouched, pass -- so 2 and 3 fail on the edit" "$rigCheckRc" "0"

echo "-- 5. the builders answer as the store's own do --"
rigCopy="$( rigPackage answer )"
rigAnswer="$( env -i PATH="/usr/bin:/bin" bash -c '
	. "$1/sh-lib/session/AgentsSessionParts.include" || exit 98
	. "$1/sh-lib/session/AgentsTools.SessionStore.include" || exit 97
	folder="" ; storeFolder="" ; part="" ; storePart=""
	AgentsSessionPartsFolderInto folder /ws rig-session || exit 1
	AgentsSessionFolderInto storeFolder /ws rig-session || exit 2
	AgentsSessionPartsPartInto part /ws rig-session tokens || exit 3
	AgentsSessionPartInto storePart /ws rig-session tokens || exit 4
	badFolder=no ; AgentsSessionPartsFolderInto badOut /ws "bad/name" || badFolder=refused
	printf "%s %s %s %s %s\n" "$folder" "$storeFolder" "$part" "$storePart" "$badFolder"
' rig "$rigCopy" 2> /dev/null )"
rigAssert "one folder and one file of it, as the store include builds them, and a name that is no bare id refused" \
	"$rigAnswer" "/ws/.local/agents/sessions/rig-session /ws/.local/agents/sessions/rig-session /ws/.local/agents/sessions/rig-session/tokens /ws/.local/agents/sessions/rig-session/tokens refused"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SESSION PARTS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_PARTS: OK (%d assertions, offline)\n' "$rigPassCount"
