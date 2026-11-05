#!/usr/bin/env bash
## Behavioural check on S13.6: `--supervise-copy <from-run> <source> <to-run> <destination>` copies a file from one
## session sandbox to another, always a real copy and never a link. Run against a rig workspace, red first: before the
## operation, every call is refused as an invalid option.
## Held:
##   1. the copy lands, its row names both runs and both paths, and its body is the source's
##   2. it is a real copy: a regular file, no link, and an inode of its own, not the source's
##   3. IT REACHES THE READ-ONLY input/ FOLDER of a sandbox, which is the case tonight's run could not do, and that
##      folder carries no write bit again when the call is over
##   3b. a destination that names a subfolder the sandbox does not hold yet: the folder the copy makes carries no write
##      bit either, so a read-only input/ is never widened by a copy into it. The control is the same call into a
##      writable output/, where the folder it makes IS writable
##   4. the control, both directions: a second copy over the same destination reads `replaced`, and a plain copy into
##      the same folder is refused -- so the folder really is read-only and only this operation lifts it
##   5. a source that is missing, a path with `..`, an absolute path, a source that is a link, and a source that is the
##      destination itself are each refused and write nothing
##   6. the operation is the supervisor's: another member's session is refused
## Offline: a rig workspace, its two sandboxes and its spawn records are this rig's own temp tree, and no process
## outlives the check.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigFn="$rigPkg/sh-scripts/AgentDispatcherTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigFn" ] || rigRefuse "the dispatcher is not at the origin: $rigFn"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSuperviseCopyCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
rigHome="$rigTmp/home"
rigSkills="$rigTmp/skills"
rigAgents="$rigWs/.local/agents"
rigFrom="rigcopyfrom"
rigTo="rigcopyto"
rigFresh="rigcopyfresh"
mkdir -p "$rigAgents/spawned" "$rigAgents/sessions" "$rigData/audit/2026-11" "$rigHome" \
	"$rigSkills/magic-coordinator" "$rigSkills/magic-tester" || rigRefuse "the rig could not be made: $rigTmp"
printf 'rig\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
printf 'rig\n' > "$rigSkills/magic-tester/magic-tester.basic.md"

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
rigField(){ ## output, the leading word, the field number -- that word of the first such row
	printf '%s\n' "$1" | LC_ALL=C awk -v want="$2" -v at="$3" -F'\t' '$1 == want { print $at ; exit }'
}
## `-ef` is the shell's own answer to "are these one file", and it needs no stat(1): `stat` differs by platform, and its
## `bsd || gnu` retry is forbidden by this package's MAGIC.md. The count of names is read off `ls -i` instead, which is
## POSIX and gives the inode of every name in one listing.
rigSameFile(){ ## two paths -- yes where the shell says they are one file
	[ "$1" -ef "$2" ] && printf yes || printf no
}
rigLinks(){ ## path -- how many names that inode has in its own folder
	local rigWant
	rigWant="$( LC_ALL=C ls -i "$1" 2> /dev/null | LC_ALL=C awk '{ print $1 }' )" || rigWant=""
	LC_ALL=C ls -i "$( dirname "$1" )" 2> /dev/null | LC_ALL=C awk -v want="$rigWant" '$1 == want { n++ } END { print n + 0 }'
}
rigWritable(){ ## folder -- yes where a write bit is on for its owner
	[ -w "$1" ] && printf yes || printf no
}

## THE TWO SANDBOXES, as the spawn proxy makes them: input/ carrying no write bit at all, and output/ writable.
rigSandbox(){ ## run id, member
	local boxDir="$rigAgents/spawned/$1"
	mkdir -p "$boxDir/input" "$boxDir/output" || rigRefuse "the sandbox could not be made: $1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nworkspace: ws-supervise-copy-rig\nowner: %s\nstatus: spawn-started\nstarted-at: 2026-11-04 05:00 +0200\n---\n' \
		"$1" "$1" "$( hostname -s 2> /dev/null )" "$2" > "$boxDir/$1.spawn.md" || rigRefuse "the record could not be written: $1"
	printf 'brief of %s\n' "$1" > "$boxDir/input/brief.md"
	printf 'step one\n' > "$boxDir/output/plan.md"
	chmod -R a-w "$boxDir/input"
}
rigSandbox "$rigFrom" magic-developer
rigSandbox "$rigTo" magic-tester
rigSrc="$rigAgents/spawned/$rigFrom/output/plan.md"

rigCall(){ ## operation, then its arguments
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" \
		MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_TEAM_DATA_COMMIT_THREAD=off MDAT_COMMS_READER=off MDAT_COLLECT_THREAD=off \
		MDAT_SPAWN_AGENT="${rigActing:-magic-coordinator}" \
		bash "$rigFn" "$@" 2>&1
}

echo "-- 1. the copy lands, and its row names both sides --"
rigOut="$( rigCall --supervise-copy "$rigFrom" output/plan.md "$rigTo" input/plan.md )" ; rigRc=$?
rigAssert "the copy reports itself" "$rigRc $( rigField "$rigOut" copy 1 )" "0 copy"
rigAssert "and names the run and the path it came from" \
	"$( rigField "$rigOut" copy 2 ) $( rigField "$rigOut" copy 3 )" "$rigFrom output/plan.md"
rigAssert "and the run and the path it went to" \
	"$( rigField "$rigOut" copy 4 ) $( rigField "$rigOut" copy 5 )" "$rigTo input/plan.md"
rigAssert "it was a new file there" "$( rigField "$rigOut" copy 6 )" "new"
rigAssert "its body is the source's, byte for byte" \
	"$( cmp -s "$rigSrc" "$rigAgents/spawned/$rigTo/input/plan.md" && printf same || printf different )" "same"
rigAssert "and its size is the copy's own count" \
	"$( rigField "$rigOut" copy 7 )" "$( LC_ALL=C wc -c < "$rigSrc" | LC_ALL=C tr -d ' ' )"

echo "-- 2. a real copy, never a link --"
rigAssert "the destination is a regular file" \
	"$( [ -f "$rigAgents/spawned/$rigTo/input/plan.md" ] && [ ! -L "$rigAgents/spawned/$rigTo/input/plan.md" ] && printf regular || printf not-regular )" "regular"
rigAssert "with an inode of its own, not the source's" \
	"$( rigSameFile "$rigSrc" "$rigAgents/spawned/$rigTo/input/plan.md" )" "no"
rigAssert "and one name only, so it is no hardlink" \
	"$( rigLinks "$rigAgents/spawned/$rigTo/input/plan.md" )" "1"

echo "-- 3. the read-only input folder is reached, and left as read-only as it was --"
## The "before" row is taken on a sandbox NOTHING has copied into yet, so it measures the rule the spawn proxy makes
## rather than the state its own copy left (the reviewer's finding on the earlier form of this check).
rigSandbox "$rigFresh" magic-tester
rigAssert "a fresh sandbox's input folder carries no write bit before any copy" \
	"$( rigWritable "$rigAgents/spawned/$rigFresh/input" )" "no"
rigAssert "and carries none after one" "$( rigWritable "$rigAgents/spawned/$rigTo/input" )" "no"
rigAssert "nor does the file it now holds" \
	"$( [ -w "$rigAgents/spawned/$rigTo/input/plan.md" ] && printf writable || printf read-only )" "read-only"

echo "-- 3b. a copy that makes a subfolder never widens a read-only folder --"
rigOut="$( rigCall --supervise-copy "$rigFrom" output/plan.md "$rigTo" input/notes/plan.md )" ; rigRc=$?
rigAssert "the copy into a folder that was not there is made" "$rigRc $( rigField "$rigOut" copy 1 )" "0 copy"
rigAssert "its body is the source's" \
	"$( cmp -s "$rigSrc" "$rigAgents/spawned/$rigTo/input/notes/plan.md" && printf same || printf different )" "same"
rigAssert "the folder it made carries no write bit, in a read-only input/" \
	"$( rigWritable "$rigAgents/spawned/$rigTo/input/notes" )" "no"
rigAssert "nor does the file inside it" \
	"$( [ -w "$rigAgents/spawned/$rigTo/input/notes/plan.md" ] && printf writable || printf read-only )" "read-only"
rigAssert "so a plain copy beside it is still refused" \
	"$( cp "$rigSrc" "$rigAgents/spawned/$rigTo/input/notes/plain.md" 2> /dev/null && printf copied || printf refused )" "refused"
## The control, the other way: the same call into a writable output/, where the folder it makes IS writable, so the
## row above is matching the rule rather than matching anything.
rigOut="$( rigCall --supervise-copy "$rigFrom" output/plan.md "$rigTo" output/notes/plan.md )" ; rigRc=$?
rigAssert "the same call into a writable output/ is made" "$rigRc $( rigField "$rigOut" copy 1 )" "0 copy"
rigAssert "and the folder it made there is writable, as that folder's rule allows" \
	"$( rigWritable "$rigAgents/spawned/$rigTo/output/notes" )" "yes"

echo "-- 4. the control, both directions --"
rigAssert "a plain copy into that folder is refused, so it really is read-only" \
	"$( cp "$rigSrc" "$rigAgents/spawned/$rigTo/input/plain.md" 2> /dev/null && printf copied || printf refused )" "refused"
rigAssert "and nothing was left behind by it" \
	"$( [ -e "$rigAgents/spawned/$rigTo/input/plain.md" ] && printf there || printf absent )" "absent"
rigOut="$( rigCall --supervise-copy "$rigFrom" output/plan.md "$rigTo" input/plan.md )" ; rigRc=$?
rigAssert "a second copy over the same place says it replaced it" \
	"$rigRc $( rigField "$rigOut" copy 6 )" "0 replaced"
rigAssert "and the body is still the source's" \
	"$( cmp -s "$rigSrc" "$rigAgents/spawned/$rigTo/input/plan.md" && printf same || printf different )" "same"

echo "-- 5. what is refused, and writes nothing --"
rigOut="$( rigCall --supervise-copy "$rigFrom" output/nothing.md "$rigTo" input/nothing.md )" ; rigRc=$?
rigAssert "a source that is not there is refused, naming the path" \
	"$rigRc $( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'no file at output/nothing.md' ) $( [ -e "$rigAgents/spawned/$rigTo/input/nothing.md" ] && printf there || printf absent )" "1 1 absent"
rigOut="$( rigCall --supervise-copy "$rigFrom" ../../escape.md "$rigTo" input/escape.md )" ; rigRc=$?
rigAssert "a path with .. in it is refused, before any run is read" \
	"$rigRc $( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'no .. part' )" "1 1"
rigOut="$( rigCall --supervise-copy "$rigFrom" "$rigSrc" "$rigTo" input/abs.md )" ; rigRc=$?
rigAssert "an absolute source path is refused" "$rigRc $( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'never absolute' )" "1 1"
ln -s "$rigSrc" "$rigAgents/spawned/$rigFrom/output/alias.md" || rigRefuse "the rig's link could not be made"
rigOut="$( rigCall --supervise-copy "$rigFrom" output/alias.md "$rigTo" input/alias.md )" ; rigRc=$?
rigAssert "a source that is a link is refused, and nothing is written" \
	"$rigRc $( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'is a link' ) $( [ -e "$rigAgents/spawned/$rigTo/input/alias.md" ] && printf there || printf absent )" "1 1 absent"
rigOut="$( rigCall --supervise-copy "$rigFrom" output/plan.md "$rigFrom" output/plan.md )" ; rigRc=$?
rigAssert "a copy of a file onto itself is refused" "$rigRc $( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'one path' )" "1 1"
ln "$rigSrc" "$rigAgents/spawned/$rigTo/output/same-inode.md" 2> /dev/null || rigRefuse "the rig's hardlink could not be made"
rigOut="$( rigCall --supervise-copy "$rigFrom" output/plan.md "$rigTo" output/same-inode.md )" ; rigRc=$?
rigAssert "and so is a copy onto another name for the same file" \
	"$rigRc $( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'one file' )" "1 1"
rigOut="$( rigCall --supervise-copy "$rigFrom" output/plan.md rignosuchrun input/plan.md )" ; rigRc=$?
rigAssert "a run id no record carries is refused, naming it" \
	"$rigRc $( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'rignosuchrun' )" "1 1"
rigOut="$( rigCall --supervise-copy "$rigFrom" output/plan.md )" ; rigRc=$?
rigAssert "a call short of its four words is refused" \
	"$rigRc $( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'syntax is' )" "1 1"

echo "-- 6. the operation is the supervisor's --"
rigOut="$( rigActing=magic-tester rigCall --supervise-copy "$rigFrom" output/plan.md "$rigTo" input/by-tester.md )" ; rigRc=$?
rigAssert "another member's session is refused, and told whose the operation is" \
	"$rigRc $( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'runs only as magic-coordinator' ) $( [ -e "$rigAgents/spawned/$rigTo/input/by-tester.md" ] && printf there || printf absent )" "1 1 absent"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SUPERVISE COPY CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'SUPERVISE_COPY: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
