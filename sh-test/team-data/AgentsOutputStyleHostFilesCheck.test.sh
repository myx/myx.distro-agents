#!/usr/bin/env bash
## Behavioural check on the output-style audit files (sh-lib/comms/AgentsTools.OutputStyle.include): team data is merged between machines, so
## a file that several of them append to conflicts on every merge. The refusal and declaration logs are one file for each machine and each
## UTC day, <type>-<day>T0000Z-<host>-output-style.md, and a reader takes the union. Held, in a rig of two clones of one bare remote:
##   1. two machines write two files, each holding the rows of its own machine alone
##   2. the clones merge without a conflict, and the union of the day's files holds every row
##   3. control: the same two machines appending to one shared file do conflict, so the rig can tell
##   4. the declaration queue of 1000 is the union of the day's files, those of the days before the change (no host in the name) included
## Offline: git runs on this rig's own temp stores and temp bare remote only.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigOrigin="${MDLT_ORIGIN:=$MMDAPP/.local}"
rigInclude="$rigOrigin/myx/myx.distro-agents/sh-lib/comms/AgentsTools.OutputStyle.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the output-style include is not at the origin this workspace resolves: $rigInclude"
command -v git > /dev/null || rigRefuse "git is not installed"
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsOutputStyleHostFilesCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
export GIT_AUTHOR_NAME=rig GIT_AUTHOR_EMAIL=rig@example.invalid GIT_COMMITTER_NAME=rig GIT_COMMITTER_EMAIL=rig@example.invalid
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigDay="$( date -u +%Y%m%d )"

## The machines: a `hostname` first on PATH for each, answering its own short name.
for rigHost in host-a host-b ; do
	mkdir -p "$rigTmp/bin-$rigHost"
	printf '#!/bin/sh\necho %s\n' "$rigHost" > "$rigTmp/bin-$rigHost/hostname"
	chmod +x "$rigTmp/bin-$rigHost/hostname"
done
## A bare remote seeded with an audit folder, and one clone for each machine.
git init -q --bare "$rigTmp/remote.git" || rigRefuse "could not make the bare remote"
mkdir -p "$rigTmp/seed/audit" && : > "$rigTmp/seed/audit/README.md"
git -C "$rigTmp/seed" init -q && git -C "$rigTmp/seed" add -A && git -C "$rigTmp/seed" commit -q -m seed && git -C "$rigTmp/seed" remote add origin "$rigTmp/remote.git" \
	&& git -C "$rigTmp/seed" push -q -u origin HEAD 2> /dev/null || rigRefuse "could not seed the bare remote"
rigBranch="$( git -C "$rigTmp/seed" rev-parse --abbrev-ref HEAD )"
for rigHost in host-a host-b ; do
	git clone -q -b "$rigBranch" "$rigTmp/remote.git" "$rigTmp/clone-$rigHost" 2> /dev/null || rigRefuse "could not clone for $rigHost"
done
mkdir -p "$rigTmp/ws/.local/agents"

rigWrite(){ ## host, refusal|declaration, member, count -- that machine writes rows of that kind, as that member, `count` times
	local writeAt=0
	while [ "$writeAt" -lt "${4:-1}" ] ; do
		writeAt=$(( writeAt + 1 ))
		( cd "$rigTmp/ws" && export PATH="$rigTmp/bin-$1:$PATH" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigTmp/clone-$1" MDSC_CMD=rig ; . "$rigInclude"
			case "$2" in
				declaration) printf 'A declared text.\n' | AgentsToolsOutputStyleRefusal "$3" report rig-destination "" none ;;
				refusal) printf 'One clause; another clause.\n' | AgentsToolsOutputStyleRefusal "$3" "" rig-destination "" semicolon ;;
			esac ) > "$rigTmp/write.out" 2> "$rigTmp/write.err"
		rigWriteRc=$?
	done
}
rigFiles(){ ## clone host, type -- the day's files of that type, names only, one line
	ls "$rigTmp/clone-$1/audit" 2> /dev/null | LC_ALL=C grep -E "^$2-${rigDay}T0000Z-.*output-style\.md$" | LC_ALL=C tr '\n' ' '
}
rigRows(){ ## clone host, type, member -- the rows of that member in the day's files of that type
	cat "$rigTmp/clone-$1/audit/$2-${rigDay}T0000Z-"*"output-style.md" 2> /dev/null | LC_ALL=C grep -c "	$3	" || :
}

echo "-- 1. two machines, two files, each holding its own rows --"
rigWrite host-a refusal rig-a 2 ; rigWrite host-b refusal rig-b 3
rigWrite host-a declaration rig-a 2 ; rigWrite host-b declaration rig-b 1
rigAssert "each machine wrote the refusal log and the declaration log under its own name" \
	"$( rigFiles host-a refusal )|$( rigFiles host-b refusal )|$( rigFiles host-a declaration )|$( rigFiles host-b declaration )" \
	"refusal-${rigDay}T0000Z-host-a-output-style.md |refusal-${rigDay}T0000Z-host-b-output-style.md |declaration-${rigDay}T0000Z-host-a-output-style.md |declaration-${rigDay}T0000Z-host-b-output-style.md "
rigAssert "a file holds the rows of its own machine: a's refusals 2 of rig-a and none of rig-b; b's 3 of rig-b and none of rig-a" \
	"$( cat "$rigTmp/clone-host-a/audit/refusal-${rigDay}T0000Z-host-a-output-style.md" | LC_ALL=C grep -c '	rig-a	' || : ):$( cat "$rigTmp/clone-host-a/audit/refusal-${rigDay}T0000Z-host-a-output-style.md" | LC_ALL=C grep -c '	rig-b	' || : ):$( cat "$rigTmp/clone-host-b/audit/refusal-${rigDay}T0000Z-host-b-output-style.md" | LC_ALL=C grep -c '	rig-b	' || : ):$( cat "$rigTmp/clone-host-b/audit/refusal-${rigDay}T0000Z-host-b-output-style.md" | LC_ALL=C grep -c '	rig-a	' || : )" "2:0:3:0"

echo "-- 2. the clones merge without a conflict, and the union holds every row --"
git -C "$rigTmp/clone-host-a" push -q origin HEAD 2> /dev/null || rigRefuse "host-a could not push"
rigPullRc=0
git -C "$rigTmp/clone-host-b" pull -q --no-rebase --no-edit origin "$rigBranch" > /dev/null 2>&1 || rigPullRc=$?
rigAssert "host-b pulls what host-a pushed with no conflict and no merge left open" "$rigPullRc:$( [ -e "$rigTmp/clone-host-b/.git/MERGE_HEAD" ] && printf open || printf closed ):$( git -C "$rigTmp/clone-host-b" diff --name-only --diff-filter=U | LC_ALL=C grep -c . || : )" "0:closed:0"
rigAssert "the union of the day's files holds every row of both machines: 5 refusals, 3 declarations" \
	"$( rigRows host-b refusal rig-a ) + $( rigRows host-b refusal rig-b ) : $( rigRows host-b declaration rig-a ) + $( rigRows host-b declaration rig-b )" "2 + 3 : 2 + 1"

echo "-- 3. control: one shared file does conflict --"
git -C "$rigTmp/clone-host-b" push -q origin HEAD 2> /dev/null || rigRefuse "host-b could not push"
git -C "$rigTmp/clone-host-a" pull -q --no-rebase --no-edit origin "$rigBranch" > /dev/null 2>&1 || rigRefuse "host-a could not catch up"
for rigHost in host-a host-b ; do
	printf '2026-10-27T00:00:00Z\tshared\t%s\n' "$rigHost" >> "$rigTmp/clone-$rigHost/audit/shared.md"
	git -C "$rigTmp/clone-$rigHost" add -A && git -C "$rigTmp/clone-$rigHost" commit -q -m "shared append from $rigHost"
done
git -C "$rigTmp/clone-host-a" push -q origin HEAD 2> /dev/null
rigSharedRc=0
git -C "$rigTmp/clone-host-b" pull -q --no-rebase --no-edit origin "$rigBranch" > /dev/null 2>&1 || rigSharedRc=$?
rigAssert "two machines appending to one file: the merge conflicts" "$( [ "$rigSharedRc" != 0 ] && printf conflict || printf clean )" conflict
git -C "$rigTmp/clone-host-b" merge --abort > /dev/null 2>&1 || :

echo "-- 4. the declaration queue is the union of the day's files --"
rigQueue="$rigTmp/clone-host-a/audit"
rm -f "$rigQueue/declaration-${rigDay}T0000Z-"*
LC_ALL=C awk 'BEGIN { for ( n = 1 ; n <= 600 ; n++ ) printf "row\n" ; }' > "$rigQueue/declaration-${rigDay}T0000Z-output-style.md"
LC_ALL=C awk 'BEGIN { for ( n = 1 ; n <= 399 ; n++ ) printf "row\n" ; }' > "$rigQueue/declaration-${rigDay}T0000Z-host-b-output-style.md"
rigWrite host-a declaration rig-a 1
rigAssert "999 rows between a file of the days before the change and another machine's file: a declaration is still taken" "$rigWriteRc:$( LC_ALL=C grep -c 'THE DECLARATION QUEUE IS FULL' "$rigTmp/write.err" || : )" "0:0"
rigWrite host-a declaration rig-a 1
rigAssert "1000 rows or more across the files: it is refused, nothing is sent, and the error says why" "$rigWriteRc:$( LC_ALL=C grep -c 'THE DECLARATION QUEUE IS FULL' "$rigTmp/write.err" || : )" "1:1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ OUTPUT STYLE HOST FILES CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'OUTPUT_STYLE_HOST_FILES: OK (%d assertions, offline, temp stores only)\n' "$rigPassCount"
