#!/usr/bin/env bash
## Behavioural check on --intern-op-spawn-prepare-brief (3288): the brief is the skillset
## template's Skeleton with its slots filled. Exactly one of --routine <selector> |
## --routine-default is required; the selector may be a full routine filename or part of
## one, matched over the skillset root's member folders, and must match exactly one file.
## A resolved routine's own executors/invitees fill the brief; a routine file that opens
## with no frontmatter block, or whose executors/maintainers are empty, is refused. Open
## warnings come from the five active board states only; a missing or unclosed template is
## a stated refusal. Temp skillset and data roots, under one `env -i` guard.
## RIG_OLD_BRIEF, when set, names a file holding the pre-routine-slots output for the
## --routine-default/no-warnings case, which the new output must equal byte for byte.
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

## The default routine, carrying the key --routine-default now resolves through.
printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator, magic-librarian\ninvitees: magic-team\ndefault-for-session-kind: coworking\n---\n# rig coworking routine fixture\n' \
	> "$rigSkills/magic-team/magic-team.coworking.routine.md"
## Two routine files sharing the substring "alpha", for the ambiguous-selector case; neither
## carries an invitees field, for the invitees-absent-reads-none case.
printf -- '---\nexecutors: rig-member\nmaintainers: rig-member\n---\n# rig alpha routine fixture\n' \
	> "$rigSkills/rig-member/rig-member.alpha.routine.md"
printf -- '---\nexecutors: rig-member\nmaintainers: rig-member\n---\n# rig alphabeta routine fixture\n' \
	> "$rigSkills/rig-member/rig-member.alphabeta.routine.md"
## A routine file that breaks the contract: no opening frontmatter block at all.
printf '%s\n' "# broken fixture: no frontmatter block at all" "executors: rig-member" "maintainers: rig-member" \
	> "$rigSkills/rig-member/rig-member.broken.routine.md"

rigBrief(){ ## result file, then --routine/--routine-default/--context args for the op
	local rigResultFile="$1" ; shift
	env -i HOME="$rigTmp" PATH="/usr/bin:/bin" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MDAT_SKILLSET_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-spawn-prepare-brief rig-member "$@"
		' rig-brief-wrapper "$@" > "$rigResultFile" 2> "$rigResultFile.err"
	printf '%s' "$?" > "$rigResultFile.rc"
}

echo "-- --routine-default, no warnings --"
rigBrief "$rigTmp/b1" --routine-default
printf '%s\n' "SPAWN-PREPARE-BRIEF: rig-member" "tool-routing: use the tools and MCP this session was given, in the ways your instructions prescribe. Read --member-help rig-member when unsure how a tool works. Follow what a refused call says: the tool to use instead, or the REFUSAL-ID to escalate by. Report a blockage the prescribed way, so the tooling can be polished. Never hack around it. Do not research source code unless it is the task." \
	"scratchpad: your own files go in the output/ folder this dispatch's own \"## Your sandbox\" section names" \
	"read-and-obey: read rig-member.armed.md and magic-team.coworking.routine.md, through the skillset reader, carefully and in full, before acting, and obey them." \
	"executors: magic-coordinator" "invitees: magic-team" \
	"## open warning-* items" "(none open)" > "$rigTmp/b1.want"
rigAssert "the brief is the filled Skeleton, byte for byte" "$( cmp -s "$rigTmp/b1" "$rigTmp/b1.want" && printf same || printf differs )" same
rigAssert "no slot is left unfilled"                   "$( LC_ALL=C grep -c '{{' "$rigTmp/b1" )" 0
rigAssert "the header names the member"                "$( LC_ALL=C grep -c -x -F 'SPAWN-PREPARE-BRIEF: rig-member' "$rigTmp/b1" )" 1
rigAssert "and so does the tool-routing line"          "$( LC_ALL=C grep '^tool-routing: ' "$rigTmp/b1" | LC_ALL=C grep -c -F -- '--member-help rig-member ' )" 1
rigAssert "the read-and-obey line names the duty file and routine" \
	"$( LC_ALL=C grep -c -x -F 'read-and-obey: read rig-member.armed.md and magic-team.coworking.routine.md, through the skillset reader, carefully and in full, before acting, and obey them.' "$rigTmp/b1" )" 1
if [ -n "${RIG_OLD_BRIEF:-}" ] ; then
	rigAssert "and equals the pre-routine-slots output"  "$( cmp -s "$rigTmp/b1" "$RIG_OLD_BRIEF" && printf same || printf differs )" same
fi

echo "-- open warnings --"
for rigState in backlog pending running blocked parked processed ; do
	mkdir -p "$rigData/board/$rigState"
	printf -- '---\ntype: warning\n---\n' > "$rigData/board/$rigState/warning-rig-$rigState.md"
done
rigBrief "$rigTmp/b4" --routine-default
rigAssert "each active state's warning is listed"     "$( LC_ALL=C grep -c -E '^- warning-rig-(backlog|pending|running|blocked|parked)\.md \[(backlog|pending|running|blocked|parked)\]$' "$rigTmp/b4" || : )" 5
rigAssert "a processed warning is not"                 "$( LC_ALL=C grep -c 'warning-rig-processed' "$rigTmp/b4" || : )" 0
rigAssert "and (none open) is gone"                    "$( LC_ALL=C grep -c -x '(none open)' "$rigTmp/b4" || : )" 0

echo "-- a routine selector matching part of one filename --"
rigBrief "$rigTmp/b5" --routine alphabeta
rigAssert "the brief lands"                            "$( cat "$rigTmp/b5.rc" )" 0
rigAssert "the read-and-obey line names the matched routine" \
	"$( LC_ALL=C grep -c -x -F 'read-and-obey: read rig-member.armed.md and rig-member.alphabeta.routine.md, through the skillset reader, carefully and in full, before acting, and obey them.' "$rigTmp/b5" )" 1
rigAssert "its executors fill the slot"                "$( LC_ALL=C grep -c -x -F 'executors: rig-member' "$rigTmp/b5" )" 1
rigAssert "an absent invitees field reads none"        "$( LC_ALL=C grep -c -x -F 'invitees: none' "$rigTmp/b5" )" 1

echo "-- a routine selector matching more than one filename --"
rigBrief "$rigTmp/b6" --routine alpha
rigAssert "an ambiguous selector is refused with rc 1" "$( cat "$rigTmp/b6.rc" )" 1
rigAssert "naming it as matching more than one"        "$( LC_ALL=C grep -c 'matches more than one routine file' "$rigTmp/b6.err" || : )" 1
rigAssert "and listing both matches"                   "$( LC_ALL=C grep -c -E 'rig-member\.alpha(beta)?\.routine\.md' "$rigTmp/b6.err" || : )" 2

echo "-- a routine selector matching no filename --"
rigBrief "$rigTmp/b7" --routine no-such-routine-selector
rigAssert "no match is refused with rc 1"              "$( cat "$rigTmp/b7.rc" )" 1
rigAssert "saying none matched"                        "$( LC_ALL=C grep -c 'matches no routine file' "$rigTmp/b7.err" || : )" 1

echo "-- a routine file that breaks the contract --"
rigBrief "$rigTmp/b8" --routine broken
rigAssert "a routine with no frontmatter block is refused with rc 1" "$( cat "$rigTmp/b8.rc" )" 1
rigAssert "saying so"                                  "$( LC_ALL=C grep -c 'does not open with a frontmatter block' "$rigTmp/b8.err" || : )" 1

echo "-- both routine options at once --"
rigBrief "$rigTmp/b9" --routine-default --routine alphabeta
rigAssert "is refused with rc 1"                       "$( cat "$rigTmp/b9.rc" )" 1
rigAssert "naming the conflict"                        "$( LC_ALL=C grep -c 'use only one of --routine' "$rigTmp/b9.err" || : )" 1

echo "-- neither routine option --"
rigBrief "$rigTmp/b10"
rigAssert "is refused with rc 1"                       "$( cat "$rigTmp/b10.rc" )" 1
rigAssert "saying exactly one is required"             "$( LC_ALL=C grep -c 'exactly one of --routine' "$rigTmp/b10.err" || : )" 1

echo "-- --routine with no value --"
rigBrief "$rigTmp/b13" --routine
rigAssert "is refused with rc 1"                       "$( cat "$rigTmp/b13.rc" )" 1
rigAssert "naming the one shared --routine wording"    "$( LC_ALL=C grep -c 'routine requires <selector>' "$rigTmp/b13.err" || : )" 1

echo "-- --routine-default, more than one default-for-session-kind: coworking routine --"
printf -- '---\nexecutors: rig-member\nmaintainers: rig-member\ndefault-for-session-kind: coworking\n---\n# rig second coworking routine fixture\n' \
	> "$rigSkills/rig-member/rig-member.coworking.routine.md"
rigBrief "$rigTmp/b14" --routine-default
rigAssert "is refused with rc 1"                       "$( cat "$rigTmp/b14.rc" )" 1
rigAssert "naming the default-for-session-kind cause"  "$( LC_ALL=C grep -c 'default-for-session-kind: coworking: 2 routine file' "$rigTmp/b14.err" || : )" 1
rigAssert "never falls through to the resolver's own ambiguous-match wording" \
	"$( LC_ALL=C grep -c 'matches more than one routine file' "$rigTmp/b14.err" || : )" 0
rm -f "$rigSkills/rig-member/rig-member.coworking.routine.md"

echo "-- a template that cannot be used --"
printf '# Skeleton\n\n```\nSPAWN-PREPARE-BRIEF: {{member}}\n' > "$rigSkills/magic-team/templates/spawn-brief.document.format.md"
rigBrief "$rigTmp/b11" --routine-default
rigAssert "an unclosed Skeleton is refused with rc 1"  "$( cat "$rigTmp/b11.rc" ):$( LC_ALL=C grep -c 'has no complete Skeleton block' "$rigTmp/b11.err" || : )" "1:1"
rigAssert "and prints no partial brief"                "$( LC_ALL=C grep -c 'SPAWN-PREPARE-BRIEF' "$rigTmp/b11" || : )" 0
rm -f "$rigSkills/magic-team/templates/spawn-brief.document.format.md"
rigBrief "$rigTmp/b12" --routine-default
rigAssert "a missing template is refused with rc 1"    "$( cat "$rigTmp/b12.rc" ):$( LC_ALL=C grep -c 'the brief template is missing' "$rigTmp/b12.err" || : )" "1:1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SPAWN PREPARE BRIEF CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_PREPARE_BRIEF: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
