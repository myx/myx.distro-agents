#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on S16 stage 2 item 5: the two hold keys `owner-session` and `owner-session-since`
## leave the board item, so a hold is a function of the document and never a key an agent sets.
## Read over the package's own tree. Held:
##   1. control: the probe reads a population of files, and finds a key that is still there
##   2. neither key stands in any contract of the board item, nor in the model reference
##   3. no code of the package reads either key
##   4. the three routines that used to set and read the hold read the digest's `held` line instead
##   5. controls: the same probe finds a planted key and a planted reader, so no assertion above is
##      always green, and reports a file without either as clean
## Offline: the package's own tree read as text, and two planted files under this rig.
set -u
## Every probe here classifies bytes, and a `VAR=value` prefix on `find -exec` is no assignment: exported once.
export LC_ALL=C
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -d "$rigPackage/skillset/magic-team/magic-team" ] || rigRefuse "the package's skillset is not at the origin this workspace resolves: $rigPackage"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsOwnerSessionKeysLeaveCheck )" || exit 1
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
## How many files of a named set carry a word, as text: the set is every file the walk reaches, so the
## answer is about that set and never about a list written here.
rigKeyFiles(){ ## key, directory...
	find -L "$@" -type f \( -name '*.md' -o -name '*.sh' -o -name '*.include' -o -name '*.awk' -o -name '*.py' \) \
		-exec grep -l -F -- "$1" {} + 2> /dev/null | awk 'END { print NR + 0 ; }'
}
## The files of a named set that carry a word, one a line.
rigKeyFileNames(){ ## key, directory...
	find -L "$@" -type f \( -name '*.md' -o -name '*.sh' -o -name '*.include' -o -name '*.awk' -o -name '*.py' \) \
		-exec grep -l -F -- "$1" {} + 2> /dev/null | sed 's|.*/||' | sort
}
## How many files of a named set the walk reaches, so a probe that reached nothing cannot read as a clean tree.
rigFileCount(){ ## directory...
	find -L "$@" -type f \( -name '*.md' -o -name '*.sh' -o -name '*.include' -o -name '*.awk' -o -name '*.py' \) 2> /dev/null | awk 'END { print NR + 0 ; }'
}

rigContracts="$rigPackage/skillset/magic-team/magic-team/contracts"
rigReference="$rigPackage/skillset/magic-team/magic-team/reference"
rigRoutines="$rigPackage/skillset/magic-team"

echo "-- 1. control: the probe reads a population, and finds a key that is still there --"
rigPopulation="$( rigFileCount "$rigContracts" "$rigReference" )"
rigAssert "control: the walk reaches the contracts and the reference" \
	"$(( rigPopulation > 20 ? 1 : 0 ))" 1
rigAssert "control: and it finds a key that stands there today, so the probe looks at all" \
	"$(( $( rigKeyFiles 'recheck-date' "$rigContracts" "$rigReference" ) > 5 ? 1 : 0 ))" 1

echo "-- 2. neither hold key stands in a contract or the model reference --"
rigAssert "owner-session stands in no contract and no reference" \
	"$( rigKeyFileNames 'owner-session' "$rigContracts" "$rigReference" | LC_ALL=C tr '\n' ' ' )" ""
rigAssert "owner-session-since stands in no contract and no reference" \
	"$( rigKeyFileNames 'owner-session-since' "$rigContracts" "$rigReference" | LC_ALL=C tr '\n' ' ' )" ""

echo "-- 3. no code of the package reads either key --"
## One search answers for both keys: `owner-session-since` carries `owner-session` as its own prefix.
rigAssert "control: the walk reaches the package's code" \
	"$(( $( rigFileCount "$rigPackage/sh-lib" "$rigPackage/sh-scripts" ) > 100 ? 1 : 0 ))" 1
rigAssert "neither key stands in a file of sh-lib or sh-scripts" \
	"$( rigKeyFileNames 'owner-session' "$rigPackage/sh-lib" "$rigPackage/sh-scripts" | LC_ALL=C tr '\n' ' ' )" ""

echo "-- 4. the hold these routines read is the digest's held line --"
rigGrooming="$rigRoutines/magic-team/magic-team.grooming.routine.md"
rigInterview="$rigRoutines/magic-team/magic-team.interview.routine.md"
rigWorkDuty="$rigRoutines/magic-coordinator/magic-coordinator.work-duty.routine.md"
for rigRoutineFile in "$rigGrooming" "$rigInterview" "$rigWorkDuty" ; do
	[ -f "$rigRoutineFile" ] || rigRefuse "a routine this statement names is not in the tree: $rigRoutineFile"
done
rigAssert "the grooming routine reads the digest's held line" \
	"$( LC_ALL=C grep -c -F -- 'the digest marks the item `held`' "$rigGrooming" )" 1
rigAssert "the interview routine reads the scan's held line and says no key is set by hand" \
	"$( LC_ALL=C grep -c -F -- 'so no key is set or refreshed by hand' "$rigInterview" )" 1
rigAssert "the work-duty names the held reason among its no-action reasons" \
	"$( LC_ALL=C grep -c -F -- 'the digest marks the item `held`' "$rigWorkDuty" )" 1

echo "-- 5. controls: the probe answers both ways --"
mkdir -p "$rigTmp/with-key" "$rigTmp/with-reader" "$rigTmp/clean"
printf 'owner-session: rig-sess\n' > "$rigTmp/with-key/planted-key.md"
printf 'heldKey="$( AgentsToolsFrontmatterKey "$itemPath" owner-session )"\n' > "$rigTmp/with-reader/planted-reader.sh"
printf -- '---\ntype: task\nrecheck-date: 2026-11-20 10:00 +0200\n---\n\nbody\n' > "$rigTmp/clean/recheck-item.md"
rigAssert "control: the probe finds a planted key" \
	"$( rigKeyFiles 'owner-session' "$rigTmp/with-key" )" 1
rigAssert "control: the probe finds a planted reader in code" \
	"$( rigKeyFiles 'owner-session' "$rigTmp/with-reader" )" 1
rigAssert "control: and reports a file that carries neither as clean" \
	"$( rigKeyFiles 'owner-session' "$rigTmp/clean" )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	printf 'RESULT: FAIL (%s passed, %s failed)\n' "$rigPassCount" "$rigFailCount" ; exit 1
fi
printf 'OWNER_SESSION_KEYS_LEAVE: OK (%s assertions, offline)\n' "$rigPassCount"
