#!/usr/bin/env bash
## Behavioural check on the keys the board writers write and a type contract once did not name (the F5.3 residue): `review-since-epoch` and
## `review-reason` (the review hold), `spawn-id`, `executing-workspace`, `paying-workspace`, `member-workspace` and `transcript` (a spawn that
## reuses an item as its tracking document), `follows-up` (the item a follow-up creates) and `comments` (an open approval). Held, run and not
## read, by the one validator (--intern-doc-validate) and by a writer:
##   1. EVERY BOARD TYPE but the dispatch names the eight tooling keys, and the approval alone names `comments`: a document carrying them
##      is accepted -- no key reported as not named, no value reported as out of its form.
##   2. A VALUE OUT OF ITS FORM is still said: whole seconds, a workspace's basename, one session id.
##   3. NOTHING INVENTED: `comments` stays unnamed on every type but the approval, and a key no writer writes stays unnamed.
##   4. A WRITER'S OWN KEYS pass the write gate without a word: a board create that carries the review hold's two keys says nothing of a key
##      not being named.
## Offline, a rig of this check's own; the validator reads the contracts of the package.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tooling is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsContractResidueKeysCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigWs="$rigTmp/ws" rigData="$rigTmp/data" rigHome="$rigTmp/home"
mkdir -p "$rigWs/.local/.agents" "$rigHome" "$rigData" "$rigTmp/skills/rig-member"
printf 'rig\n' > "$rigTmp/skills/rig-member/rig-member.basic.md"
printf 'MDAT_WORKSPACE_MODE=team-rig\n' > "$rigWs/.local/.agents/magic-team.agent.env"
rigTools="spawn-id executing-workspace paying-workspace member-workspace transcript review-since-epoch review-reason follows-up"
rigDoc(){ ## type, then extra frontmatter lines -- a document of that type, to $rigTmp/doc.md
	local docType="$1" docKeys="" docLine
	shift
	[ "$docType" != approval ] || docKeys="blocks: task-20261020T0100Z-rig"$'\n'
	for docLine in "$@" ; do docKeys="$docKeys$docLine"$'\n' ; done
	printf -- '---\ndocument-contract: board-item.%s\ntype: %s\nfrom: rig-member\nowner: rig-member\ndate: 2026-10-20 04:00 +0300\n%s---\n\n# %s: rig\n' "$docType" "$docType" "$docKeys" "$docType" > "$rigTmp/doc.md"
}
rigValidate(){ ## type -- the rows of the validator over $rigTmp/doc.md, in $rigTmp/rows
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_DATA_ROOT="$rigData" \
		bash "$rigTool" --intern-doc-validate "board-item.$1" "$rigTmp/doc.md" ) > "$rigTmp/rows" 2>&1 < /dev/null
}
rigRows(){ ## rule -- how many rows of that rule
	LC_ALL=C grep -c -e "contract-$1: " "$rigTmp/rows" || :
}

echo "-- 1 and 2. the eight tooling keys, on each board type but the dispatch --"
for rigType in approval change idea interview project proposal task warning ; do
	rigDoc "$rigType" 'spawn-id: 0d5ce2b0-1111-4222-8333-444455556666' 'executing-workspace: ws-rig' 'paying-workspace: ws-rig' 'member-workspace: ws-rig' \
		'transcript: audit/2026-10/session-20261020T010000Z-rig-member-0d5ce2b0.log' 'review-since-epoch: 1791485680' 'review-reason: handback' 'follows-up: task-20261020T0000Z-rig-before'
	rigValidate "$rigType"
	rigAssert "$rigType: the eight keys are named" "$( rigRows unknown-key )" 0
	rigAssert "$rigType: and in their form" "$( rigRows form )" 0
	rigDoc "$rigType" 'review-since-epoch: soon' 'executing-workspace: a b' 'spawn-id: two words'
	rigValidate "$rigType"
	rigAssert "$rigType: a value out of its form is said: seconds, a workspace, a session id" "$( rigRows form )" 3
done

echo "-- 1 and 3. comments, the approval's alone --"
rigDoc approval 'comments: asks for the cost estimate, then a late clarification'
rigValidate approval
rigAssert "approval: comments is named, and cascades nothing of its own" "$( rigRows unknown-key ):$( rigRows form )" 0:0
for rigType in change idea interview project proposal task warning ; do
	rigDoc "$rigType" 'comments: a comment'
	rigValidate "$rigType"
	rigAssert "$rigType: comments stays unnamed (nothing invented)" "$( rigRows unknown-key )" 1
done
rigDoc task 'follows-up: task-a' 'invented-key: x'
rigValidate task
rigAssert "a key no writer writes stays unnamed" "$( rigRows unknown-key )" 1

echo "-- 4. a writer's own keys --"
rigStdin=$'---\ntype: task\n---\n\nrig body\n'
printf '%s' "$rigStdin" | ( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
	bash "$rigTool" --intern-op-board-upsert-move-edit pending task-20261020T0100Z-rig-follow.md --create --acting-member:rig-member --upsert-from-stdin \
	--header:upsert:follows-up:task-20261020T0000Z-rig-before --header:upsert:review-since-epoch:1791485680 --header:upsert:review-reason:handback --context rig ) > "$rigTmp/w.out" 2> "$rigTmp/w.err"
rigAssert "the create is written" "$( [ -f "$rigData/board/pending/task-20261020T0100Z-rig-follow.md" ] && printf yes || printf no )" yes
rigAssert "and says nothing of a key the contract does not name" "$( LC_ALL=C grep -c 'is not named by the contract' "$rigTmp/w.err" || : )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ CONTRACT RESIDUE KEYS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'CONTRACT_RESIDUE_KEYS: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
