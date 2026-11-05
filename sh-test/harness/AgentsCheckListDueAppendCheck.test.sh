#!/usr/bin/env bash
## RED CHECK for the one gap in S13.9's own promise: a due time that reaches the list by `append`
## is never validated, and the due reader then skips an unreadable one in silence.
## The code claims otherwise at AgentsHarnessBatch.include:289-292: "The mark is read by the one
## reader of a moment (LocalIsoToEpoch.awk), so a due time nothing can read is never silently
## skipped: it is refused by the CheckList tool when it is written." That holds for the tool's own
## whole-list write (:107-115). The append arm (:389-402) writes the item text verbatim, and the
## due reader drops an unreadable value at :308 with `continue`.
## Red today: 2 of 6. Green once an appended item's due mark is refused like a written one's.
## Offline: this rig's own trees only, no host reached.
set -u
: "${MMDAPP:?MMDAPP is not set}"
: "${MDLT_ORIGIN:?MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigHarness="$rigPkg/sh-lib/harness/AgentsUniversalHarness.sh"
[ -f "$rigHarness" ] || { echo "ERROR: no harness at $rigHarness" >&2 ; exit 1 ; }
mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsCheckListDueAppendCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigSp="$rigWs/.local/agents/spawned"
mkdir -p "$rigSp/parent-folder" "$rigSp/child-folder" "$rigTmp/skills" "$rigTmp/data"
for rigM in magic-coordinator magic-developer ; do
	mkdir -p "$rigTmp/skills/$rigM" ; printf 'rig\n' > "$rigTmp/skills/$rigM/$rigM.basic.md"
done
printf -- '---\nspawn-id: rig-parent\nsession-id: rig-parent\nowner: magic-coordinator\nparent-session-id: none\n---\n' > "$rigSp/parent-folder/rig-parent.spawn.md"
printf -- '---\nspawn-id: rig-child\nsession-id: rig-child\nowner: magic-developer\nparent-session-id: rig-parent\n---\n' > "$rigSp/child-folder/rig-child.spawn.md"
rigChildList="$rigSp/child-folder/magic-developer.checklist.md"
: > "$rigWs/quiet.txt"

rigPass=0 ; rigFail=0
rigAssert(){ if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 )) ; else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi ; }
rigHolds(){ case "$1" in *"$2"*) printf yes ;; *) printf no ;; esac ; }
rigCall(){ ## caller spawn id, caller member, JSON, tool
	( cd "$rigWs" && printf '%s' "$3" | env -u MDAT_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigTmp/data" MDAT_SPAWN_SESSION_ID="$1" \
		MDAT_SPAWN_AGENT="$2" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_HARNESS_WAIT_TIMEOUT=2 MDAT_WAIT_REMIND=off \
		bash "$rigHarness" --intern-tool "$4" 2> /dev/null )
}

echo "-- 1. the control: the child's own write refuses an unreadable due time --"
printf -- '- [ ] Keep me\n' > "$rigChildList"
rigOut="$( rigCall rig-child magic-developer '{"todos":[{"content":"Refresh the rig","status":"pending","activeForm":"Refreshing the rig","due":"next tuesday-ish"}]}' CheckList )"
rigAssert "the write is refused, naming the field" "$( rigHolds "$rigOut" 'due must be a date-time' )" "yes"

echo "-- 2. the same due time by append is refused too --"
rigOut="$( rigCall rig-parent magic-coordinator '{"append":["Refresh the rig (due: next tuesday-ish)"],"member":"magic-developer","session":"rig-child"}' CheckList )"
rigAssert "the append is refused, naming the field" "$( rigHolds "$rigOut" 'due must be a date-time' )" "yes"
rigAssert "and nothing is written" \
	"$( LC_ALL=C grep -c 'tuesday-ish' "$rigChildList" || : )" 0

echo "-- 3. with a readable past due mark by append, the Wait does return it --"
rigOut="$( rigCall rig-parent magic-coordinator '{"append":["Refresh the rig (due: 2020-01-01 00:00 +0000)"],"member":"magic-developer","session":"rig-child"}' CheckList )"
rigAssert "the readable append is accepted" "$( rigHolds "$rigOut" 'item(s) added' )" "yes"
rigOut="$( rigCall rig-child magic-developer '{"sources":"file:'"$rigWs"'/quiet.txt","timeout":2}' Wait )"
rigAssert "the Wait returns the appended item in the due block" "$( rigHolds "$rigOut" 'CheckList pending:' )" "yes"

if [ "$rigFail" -ne 0 ] ; then
	printf 'CHECKLIST DUE APPEND: FAILED, %d of %d assertions red\n' "$rigFail" "$(( rigPass + rigFail ))" >&2
	exit 1
fi
printf 'CHECKLIST DUE APPEND: OK (%d assertions)\n' "$rigPass"
