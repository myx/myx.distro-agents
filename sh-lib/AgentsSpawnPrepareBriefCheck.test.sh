#!/usr/bin/env bash
## Behavioural check on --intern-op-spawn-prepare-brief (3288): the brief is the skillset
## template's Skeleton with its slots filled. No gate file gives `execution-gate: none`;
## a gate file's first line lands byte for byte; the old armed.md marker is never read;
## open warnings come from the five active board states only; a missing or unclosed
## template is a stated refusal. Temp skillset and data roots, under one `env -i` guard.
## RIG_OLD_BRIEF, when set, names a file holding the pre-template output for the no-gate
## case, which the new output must equal byte for byte.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigTemplate="$MDLT_ORIGIN/myx/myx.distro-agents/skillset/magic-team/magic-team/templates/spawn-brief.document.format.md"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
[ -f "$rigTemplate" ] || rigRefuse "the brief template is not in the package: $rigTemplate"
rigTmp="$( mktemp -d -t AgentsSpawnPrepareBriefCheck )" || exit 1
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

rigSkills="$rigTmp/skills"
rigData="$rigTmp/data"
mkdir -p "$rigSkills/magic-team/templates" "$rigSkills/rig-member" "$rigData/board" "$rigTmp/ws/.local"
cp "$rigTemplate" "$rigSkills/magic-team/templates/spawn-brief.document.format.md"
printf '# rig armed\n' > "$rigSkills/rig-member/rig-member.armed.md"
rigBrief(){ ## result file
	env -i HOME="$rigTmp" PATH="/usr/bin:/bin" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MDAT_SKILLSET_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-spawn-prepare-brief rig-member
		' > "$1" 2> "$1.err"
	printf '%s' "$?" > "$1.rc"
}

echo "-- no gate file, no warnings --"
rigBrief "$rigTmp/b1"
printf '%s\n' "SPAWN-PREPARE-BRIEF: rig-member" "tool-routing: use the tools and MCP this session was given, in the ways your instructions prescribe. Read --member-help rig-member when unsure how a tool works. Follow what a refused call says: the tool to use instead, or the REFUSAL-ID to escalate by. Report a blockage the prescribed way, so the tooling can be polished. Never hack around it. Do not research source code unless it is the task." \
	"scratchpad: your own files go in the output/ folder this dispatch's own \"## Your sandbox\" section names" \
	"execution-gate: none" "## open warning-* items" "(none open)" > "$rigTmp/b1.want"
rigAssert "the brief is the filled Skeleton, byte for byte" "$( cmp -s "$rigTmp/b1" "$rigTmp/b1.want" && printf same || printf differs )" same
rigAssert "no slot is left unfilled"                   "$( LC_ALL=C grep -c '{{' "$rigTmp/b1" )" 0
rigAssert "the header names the member"                "$( LC_ALL=C grep -c -x -F 'SPAWN-PREPARE-BRIEF: rig-member' "$rigTmp/b1" )" 1
rigAssert "and so does the tool-routing line"          "$( LC_ALL=C grep '^tool-routing: ' "$rigTmp/b1" | LC_ALL=C grep -c -F -- '--member-help rig-member ' )" 1
if [ -n "${RIG_OLD_BRIEF:-}" ] ; then
	rigAssert "and equals the pre-template output"      "$( cmp -s "$rigTmp/b1" "$RIG_OLD_BRIEF" && printf same || printf differs )" same
fi

echo "-- a gate file --"
printf '%s\n' 'A & B \ C' 'second line is not the gate' > "$rigSkills/rig-member/rig-member.execution-gate.md"
rigBrief "$rigTmp/b2"
rigAssert "its first line lands byte for byte"         "$( LC_ALL=C sed -n 's/^execution-gate: //p' "$rigTmp/b2" )" 'A & B \ C'
rm -f "$rigSkills/rig-member/rig-member.execution-gate.md"

echo "-- the old marker only --"
printf '# rig armed\n<!-- execution-gate: rig-old-marker -->\n' > "$rigSkills/rig-member/rig-member.armed.md"
rigBrief "$rigTmp/b3"
rigAssert "the marker is never read"                   "$( LC_ALL=C sed -n 's/^execution-gate: //p' "$rigTmp/b3" )" none

echo "-- open warnings --"
for rigState in backlog pending running blocked parked processed ; do
	mkdir -p "$rigData/board/$rigState"
	printf -- '---\ntype: warning\n---\n' > "$rigData/board/$rigState/warning-rig-$rigState.md"
done
rigBrief "$rigTmp/b4"
rigAssert "each active state's warning is listed"     "$( LC_ALL=C grep -c -E '^- warning-rig-(backlog|pending|running|blocked|parked)\.md \[(backlog|pending|running|blocked|parked)\]$' "$rigTmp/b4" || : )" 5
rigAssert "a processed warning is not"                 "$( LC_ALL=C grep -c 'warning-rig-processed' "$rigTmp/b4" || : )" 0
rigAssert "and (none open) is gone"                    "$( LC_ALL=C grep -c -x '(none open)' "$rigTmp/b4" || : )" 0

echo "-- a template that cannot be used --"
printf '# Skeleton\n\n```\nSPAWN-PREPARE-BRIEF: {{member}}\n' > "$rigSkills/magic-team/templates/spawn-brief.document.format.md"
rigBrief "$rigTmp/b5"
rigAssert "an unclosed Skeleton is refused with rc 1"  "$( cat "$rigTmp/b5.rc" ):$( LC_ALL=C grep -c 'has no complete Skeleton block' "$rigTmp/b5.err" || : )" "1:1"
rigAssert "and prints no partial brief"                "$( LC_ALL=C grep -c 'SPAWN-PREPARE-BRIEF' "$rigTmp/b5" || : )" 0
rm -f "$rigSkills/magic-team/templates/spawn-brief.document.format.md"
rigBrief "$rigTmp/b6"
rigAssert "a missing template is refused with rc 1"    "$( cat "$rigTmp/b6.rc" ):$( LC_ALL=C grep -c 'the brief template is missing' "$rigTmp/b6.err" || : )" "1:1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SPAWN PREPARE BRIEF CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_PREPARE_BRIEF: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
