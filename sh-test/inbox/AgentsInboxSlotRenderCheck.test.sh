#!/usr/bin/env bash
## Behavioural check of the inbox writer's --upsert-from-slots body mode: the member gives only the
## slot values, and the writer renders the document's body from the type's template
## (sh-lib/templates/inbox-item.<type>.document.format.md), the front matter stamped as on any create.
## Covers the one-line title (`matter`) and a simple `body` slot, for each inbox type (note,
## reflection, inquiry), and an unknown inbox type refused. Temp stores only, in a temp workspace, and
## every op goes through one `env -i` whose child refuses to run outside it.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
[ -f "$rigHere/inbox/AgentsInboxItemDocumentFill.awk" ] || rigRefuse "the inbox document filler is not there: $rigHere/inbox/AgentsInboxItemDocumentFill.awk"
[ -f "$rigHere/templates/inbox-item.note.document.format.md" ] || rigRefuse "the tool-side note template is not there"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsInboxSlotRenderCheck )" || exit 1
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
rigDir="" ; rigStore=""
rigScenario(){ ## name
	rigDir="$rigTmp/$1" ; rigStore="$rigDir/store"
	mkdir -p "$rigDir/ws/.local/.agents" "$rigDir/home/skills/keeper-myx"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigDir/home/skills/keeper-myx/keeper-myx.basic.md"
}
## One op, guarded; stdin is the caller's. The store is $rigStore.
rigOp(){ ## result file, op and its arguments...
	local rigResult="$1" ; shift
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigDir/home" PATH="/usr/bin:/bin" MMDAPP="$rigDir/ws" MDAT_DATA_ROOT="$rigStore" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigDir/home/skills" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac
			case "${MDAT_DATA_ROOT:-$RIG_TMP/}" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MDAT_DATA_ROOT outside the rig tree" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$rigResult" 2> "$rigResult.err"
	printf '%s' "$?" > "$rigResult.rc"
}

echo "-- a note from its slots --"
rigScenario note
printf -- 'matter: Rig the widget\nbody:\n  The widget drops its last line.\n  Make it keep it.\n' \
	| rigOp "$rigDir/c" --intern-op-member-inbox-upsert keeper-myx note-20261014T0101Z-rig.md --upsert-from-slots --no-commit --context rig
rigAssert "the create succeeds"                              "$( cat "$rigDir/c.rc" )" 0
rigAssert "the type and contract are stamped"               "$( LC_ALL=C grep -c -e '^type: note$' -e '^document-contract: inbox-item.note$' -e '^owner: keeper-myx$' "$rigStore/inboxes/keeper-myx/incoming/note-20261014T0101Z-rig.md" 2>/dev/null )" 3
rigAssert "the title is rendered from matter"               "$( LC_ALL=C grep -c '^# Note: Rig the widget$' "$rigStore/inboxes/keeper-myx/incoming/note-20261014T0101Z-rig.md" 2>/dev/null )" 1
rigAssert "the body is rendered, no stray indent"           "$( LC_ALL=C grep -c -e '^The widget drops its last line\.$' -e '^Make it keep it\.$' "$rigStore/inboxes/keeper-myx/incoming/note-20261014T0101Z-rig.md" 2>/dev/null )" 2

echo "-- a reflection from its slots --"
rigScenario reflection
printf -- 'matter: The loader crashed\nbody:\n  It crashed at start.\n  Guard the missing file.\n' \
	| rigOp "$rigDir/c" --intern-op-member-inbox-upsert keeper-myx reflection-20261014T0102Z-rig.md --upsert-from-slots --no-commit --context rig
rigAssert "the reflection create succeeds"                  "$( cat "$rigDir/c.rc" )" 0
rigAssert "the reflection contract is stamped"              "$( LC_ALL=C grep -c -e '^type: reflection$' -e '^document-contract: inbox-item.reflection$' "$rigStore/inboxes/keeper-myx/incoming/reflection-20261014T0102Z-rig.md" 2>/dev/null )" 2
rigAssert "the reflection title is rendered"                "$( LC_ALL=C grep -c '^# Reflection: The loader crashed$' "$rigStore/inboxes/keeper-myx/incoming/reflection-20261014T0102Z-rig.md" 2>/dev/null )" 1

echo "-- an inquiry from its slots --"
rigScenario inquiry
printf -- 'matter: Which loader\nbody:\n  Pick the loader.\n' \
	| rigOp "$rigDir/c" --intern-op-member-inbox-upsert keeper-myx inquiry-20261014T0103Z-rig.md --upsert-from-slots --no-commit --context rig
rigAssert "the inquiry create succeeds"                     "$( cat "$rigDir/c.rc" )" 0
rigAssert "the inquiry contract is stamped"                 "$( LC_ALL=C grep -c -e '^type: inquiry$' -e '^document-contract: inbox-item.inquiry$' "$rigStore/inboxes/keeper-myx/incoming/inquiry-20261014T0103Z-rig.md" 2>/dev/null )" 2
rigAssert "the inquiry title is rendered"                   "$( LC_ALL=C grep -c '^# Inquiry: Which loader$' "$rigStore/inboxes/keeper-myx/incoming/inquiry-20261014T0103Z-rig.md" 2>/dev/null )" 1

echo "-- an unknown inbox type is refused --"
rigScenario unknown
printf -- 'matter: X\nbody: Y\n' \
	| rigOp "$rigDir/c" --intern-op-member-inbox-upsert keeper-myx mystery-20261014T0105Z-rig.md --upsert-from-slots --no-commit --context rig
rigAssert "a type with no template is refused"              "$( cat "$rigDir/c.rc" )" 1
rigAssert "and nothing is written"                          "$( [ -e "$rigStore/inboxes/keeper-myx/incoming/mystery-20261014T0105Z-rig.md" ] && printf made || printf none )" none

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ INBOX SLOT RENDER CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'INBOX_SLOT_RENDER: OK (%d assertions, offline, temp stores only)\n' "$rigPassCount"
