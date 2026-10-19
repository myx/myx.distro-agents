#!/usr/bin/env bash
## Behavioural check on routine inheritance (F5.6 of the refactorings epic, open-names 24 and 25): a routine names its
## kind, and the kind's own routine has its Opening and Closure steps mixed in, one level and no further. The mix-in is
## observable through F7.2's `--get-routine-text`:
##   Opening steps: the kind's routine first, then the routine's own; Steps: the routine's own, and only its own;
##   Closure steps: the routine's own first, then the kind's routine.
## A mix-in never silently re-adds a step a routine says does not run: the routine declares it in `skips-inherited:`.
## The expectations are read off the package's own kind routine, magic-team.coworking.routine.md, at run time.
## Held:
##   0. control: the kind routine has Opening steps and Closure steps of its own (the F6.7 sweep gives it the first)
##   1. --get-routine-text of a coworking routine: its Opening steps are the kind's, then its own
##   2. its Steps are its own, and none of the kind's
##   3. its Closure steps are its own, then the kind's
##   4. with `skips-inherited:` naming one of the kind's Opening steps, that step is left out and the others stay
## A step is read by its bold name, `1. **<name>**: ...`, at the top level of its section.
## Red before F5.6 and F7.2: no --get-routine-text, and the kind routine has no Opening steps (every case fails).
## Offline: the rig skillset carries a copy of the package's kind routine and the rig's own routines.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigKind="$rigPackage/skillset/magic-team/magic-team/magic-team.coworking.routine.md"
rigSession="$rigPackage/sh-scripts/DistroAgentsSession.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigKind" ] || rigRefuse "the coworking routine is not in the package: $rigKind"
mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsRoutineMixInCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigSkills="$rigTmp/skills"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigTmp/home" "$rigSkills/magic-team" "$rigSkills/keeper-rig"
printf 'rig\n' > "$rigSkills/keeper-rig/keeper-rig.basic.md" ; printf 'rig\n' > "$rigSkills/keeper-rig/keeper-rig.armed.md"
cp "$rigKind" "$rigSkills/magic-team/"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## The bold names of a section's top-level steps, a space between them.
rigSteps(){ ## file, heading
	LC_ALL=C awk -v want="$2" '
		/^# / { on = ( $0 == want ) ; next }
		on && /^[0-9]+\. \*\*[^*]+\*\*/ { name = $0 ; sub( /^[0-9]+\. \*\*/, "", name ) ; sub( /\*\*.*$/, "", name ) ; printf "%s%s", sep, name ; sep = " " }
	' "$1" 2> /dev/null
}
rigKindOpening="$( rigSteps "$rigKind" '# Opening steps' )"
rigKindSteps="$( rigSteps "$rigKind" '# Steps' )"
rigKindClosure="$( rigSteps "$rigKind" '# Closure steps' )"
rigFirstKindOpening="${rigKindOpening%% *}"
rigRoutine(){ ## short name, an extra frontmatter line or nothing
	{
		printf -- '---\ntype: routine\nexecutors: keeper-rig\nmaintainers: magic-coordinator\nrequires-session-kind: coworking\n'
		[ -z "$2" ] || printf '%s\n' "$2"
		printf -- '---\n# magic-team.%s.routine — the actual procedure\n\n# Summary\n\nA rig routine.\n\n# Opening steps\n\n1. **rig-own-open**: open.\n\n# Steps\n\n1. **rig-own-work**: work.\n\n# Closure steps\n\n1. **rig-own-close**: close.\n\n' "$1"
		printf "# Routine's local procedures\n\nNone.\n\n# Routine's local rules\n\nNone.\n\n# Routine-specific tooling\n\nNone.\n\n# Maintainer Notes\n\nNone.\n"
	} > "$rigSkills/magic-team/magic-team.$1.routine.md"
}
rigRoutine rigmixed ''
rigRoutine rigskipping "skips-inherited: ${rigFirstKindOpening:-none}"
rigText(){ ## routine short name -- its mixed text, through --get-routine-text, in $rigTmp/<name>.text
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigSkills" bash "$rigSession" --get-routine-text "magic-team.$1" ) > "$rigTmp/$1.text" 2> "$rigTmp/$1.err" < /dev/null
}

echo "-- 0. control: the kind routine has Opening and Closure steps of its own --"
rigAssert "Opening steps and Closure steps, each with a step"    "$( [ -n "$rigKindOpening" ] && echo opening || echo no-opening ) $( [ -n "$rigKindClosure" ] && echo closure || echo no-closure )" "opening closure"
rigText rigmixed
echo "-- 1. Opening: the kind's first, then its own --"
rigAssert "the Opening steps"                                    "$( rigSteps "$rigTmp/rigmixed.text" '# Opening steps' )" "${rigKindOpening:+$rigKindOpening }rig-own-open"
echo "-- 2. Steps: its own only --"
rigAssert "the Steps"                                            "$( rigSteps "$rigTmp/rigmixed.text" '# Steps' )" "rig-own-work"
echo "-- 3. Closure: its own first, then the kind's --"
rigAssert "the Closure steps"                                    "$( rigSteps "$rigTmp/rigmixed.text" '# Closure steps' )" "rig-own-close${rigKindClosure:+ $rigKindClosure}"
echo "-- 4. skips-inherited: leaves the named step out --"
rigText rigskipping
rigWantSkipped="$( printf '%s\n' $rigKindOpening | LC_ALL=C grep -v -x -F -- "${rigFirstKindOpening:-none}" | LC_ALL=C tr '\n' ' ' )rig-own-open"
rigAssert "the Opening steps without ${rigFirstKindOpening:-the first of the kind}" "$( rigSteps "$rigTmp/rigskipping.text" '# Opening steps' )" "$rigWantSkipped"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROUTINE MIX IN CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ROUTINE_MIX_IN: OK (%d assertions, offline)\n' "$rigPassCount"
