#!/usr/bin/env bash
## Behavioural check on routine inheritance (F5.6 of the refactorings epic, open-names 24 and 25; its mix on the one nesting engine, Constraint 3): a routine
## names its kind, and the kind's own routine has its Opening and Closure steps mixed in, one level and no further. The mix-in is observable through
## F7.2's `--get-routine-text`, whose text is the merged document of `--intern-merge-md-files`, one mixin for each file and section, a section of its own
## named `<section> of <file stem>`:
##   Opening steps: the kind's routine first, then the routine's own; Steps: the routine's own, and only its own;
##   Closure steps: the routine's own first, then the kind's routine.
## A step of the kind's routine is a section under its Opening steps or Closure steps, named as the step; a step of the routine's own is `N. **<name>**: ...`.
## A mix-in never silently re-adds a step a routine says does not run: the routine declares it in `skips-inherited:`, and the engine's section-exclude
## leaves that section out of what the kind contributes.
## The expectations are read off the package's own kind routine, magic-team.coworking.routine.md, at run time.
## Held:
##   0. control: the kind routine has Opening steps and Closure steps of its own, each a section
##   1. --get-routine-text of a coworking routine: its Opening steps are the kind's, then its own
##   2. its Steps are its own, and none of the kind's
##   3. its Closure steps are its own, then the kind's
##   4. with `skips-inherited:` naming one of the kind's Opening steps, that step is left out, the others stay, and it comes back nowhere
##   5. a real routine of the coworking kind, magic-team.grooming.routine, gets the kind's steps around its own
##   6. advance and heartbeat: every step they skip is a step of the kind (a name that is none would skip nothing), it is not in their text, and the
##      others of the kind are; retro skips none and has them all
##   7. the text is reproducible: two runs, in two sessions and some seconds apart, give the same bytes
## Offline: the rig skillset carries a copy of the package's kind routine, of grooming, advance, heartbeat and retro, and the rig's own routines.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigTeamDir="$rigPackage/skillset/magic-team"
rigKind="$rigTeamDir/magic-team/magic-team.coworking.routine.md"
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
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigTmp/home" "$rigSkills/magic-team" "$rigSkills/keeper-rig" "$rigSkills/magic-coordinator"
printf 'rig\n' > "$rigSkills/keeper-rig/keeper-rig.basic.md" ; printf 'rig\n' > "$rigSkills/keeper-rig/keeper-rig.armed.md"
printf 'rig\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md" ; printf 'rig\n' > "$rigSkills/magic-coordinator/magic-coordinator.armed.md"
cp "$rigKind" "$rigTeamDir/magic-team/magic-team.grooming.routine.md" "$rigSkills/magic-team/"
for rigName in advance heartbeat retro ; do cp "$rigTeamDir/magic-coordinator/magic-coordinator.$rigName.routine.md" "$rigSkills/magic-coordinator/" ; done

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## The names of the steps of a section of the kind's own file, in order: its sections below the heading (## and deeper), a space between them.
rigFileSteps(){ ## file, heading
	LC_ALL=C awk -v want="$2" '
		/^# / { on = ( $0 == want ) ; next }
		on && /^##+ / { name = $0 ; sub( /^#+ /, "", name ) ; printf "%s%s", sep, name ; sep = " " }
	' "$1" 2> /dev/null
}
## The names of the steps of one section of a mixed text, in order: the sections of depth 3 and below (the kind's steps, the engine's form) and the
## numbered root steps `N. **name**` (a routine's own), a space between them. The section is named by its whole heading line.
rigSteps(){ ## file, heading
	LC_ALL=C awk -v want="$2" '
		/^# / { on = ( $0 == want ) ; next }
		on && /^###+ / { name = $0 ; sub( /^#+ /, "", name ) ; printf "%s%s", sep, name ; sep = " " ; next }
		on && /^[0-9]+\. \*\*[^*]+\*\*/ { name = $0 ; sub( /^[0-9]+\. \*\*/, "", name ) ; sub( /\*\*.*$/, "", name ) ; printf "%s%s", sep, name ; sep = " " }
	' "$1" 2> /dev/null
}
rigLine(){ ## file, heading -- the line number of that heading, or 0
	LC_ALL=C grep -n -x -F -- "$2" "$1" 2> /dev/null | LC_ALL=C sed -n '1s/:.*//p' | LC_ALL=C awk '{ print ( $1 == "" ) ? 0 : $1 }'
}
## The same without one step and everything under it (a skipped group takes its steps with it).
rigFileStepsWithout(){ ## file, heading, step
	LC_ALL=C awk -v want="$2" -v skip="$3" '
		/^# / { on = ( $0 == want ) ; skipping = 0 ; next }
		on && /^##+ / {
			name = $0 ; level = match( $0, /[^#]/ ) - 1 ; sub( /^#+ /, "", name )
			if ( skipping && level <= skipLevel ) { skipping = 0 }
			if ( name == skip ) { skipping = 1 ; skipLevel = level }
			if ( ! skipping ) { printf "%s%s", sep, name ; sep = " " }
		}
	' "$1" 2> /dev/null
}
rigKindOpening="$( rigFileSteps "$rigKind" '# Opening steps' )"
rigKindClosure="$( rigFileSteps "$rigKind" '# Closure steps' )"
rigFirstKindOpening="${rigKindOpening%% *}"
rigLeafKindOpening="$( printf '%s\n' $rigKindOpening | LC_ALL=C sed -n 2p )"
rigRoutine(){ ## short name, an extra frontmatter line or nothing
	{
		printf -- '---\ntype: routine\nexecutors: keeper-rig\nmaintainers: magic-coordinator\nrequires-session-kind: coworking\n'
		[ -z "$2" ] || printf '%s\n' "$2"
		printf -- '---\n# magic-team.%s.routine — the actual procedure\n\n# Summary\n\nA rig routine.\n\n# Opening steps\n\n1. **rig-own-open**: open.\n\n# Steps\n\n1. **rig-own-work**: work.\n\n# Closure steps\n\n1. **rig-own-close**: close.\n\n' "$1"
		printf "# Routine's local procedures\n\nNone.\n\n# Routine's local rules\n\nNone.\n\n# Routine-specific tooling\n\nNone.\n\n# Maintainer Notes\n\nNone.\n"
	} > "$rigSkills/magic-team/magic-team.$1.routine.md"
}
rigRoutine rigmixed ''
rigRoutine rigskipping "skips-inherited: ${rigLeafKindOpening:-none}"
rigRoutine rigskipgroup "skips-inherited: ${rigFirstKindOpening:-none}"
rigText(){ ## routine selector, [out name, session id] -- its mixed text, through --get-routine-text, in $rigTmp/<name>.text
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigSkills" ${3:+MDAT_SPAWN_SESSION_ID="$3"} bash "$rigSession" --get-routine-text "$1" ) > "$rigTmp/${2:-$1}.text" 2> "$rigTmp/${2:-$1}.err" < /dev/null
}
rigKindHead="# Opening steps of magic-team.coworking.routine"
rigKindClose="# Closure steps of magic-team.coworking.routine"

echo "-- 0. control: the kind routine has Opening and Closure steps of its own, each a section --"
rigAssert "Opening steps and Closure steps, each with a step"    "$( [ -n "$rigKindOpening" ] && echo opening || echo no-opening ) $( [ -n "$rigKindClosure" ] && echo closure || echo no-closure )" "opening closure"
rigText magic-team.rigmixed rigmixed
echo "-- 1. Opening: the kind's first, then its own --"
rigAssert "the kind's Opening steps"                              "$( rigSteps "$rigTmp/rigmixed.text" "$rigKindHead" )" "$rigKindOpening"
rigAssert "its own after them"                                    "$( rigSteps "$rigTmp/rigmixed.text" '# Opening steps of magic-team.rigmixed.routine' )" "rig-own-open"
rigAssert "in that order"                                         "$( [ "$( rigLine "$rigTmp/rigmixed.text" "$rigKindHead" )" -gt 0 ] && [ "$( rigLine "$rigTmp/rigmixed.text" "$rigKindHead" )" -lt "$( rigLine "$rigTmp/rigmixed.text" '# Opening steps of magic-team.rigmixed.routine' )" ] && echo kind-first )" "kind-first"
echo "-- 2. Steps: its own only --"
rigAssert "the Steps"                                             "$( rigSteps "$rigTmp/rigmixed.text" '# Steps of magic-team.rigmixed.routine' )" "rig-own-work"
rigAssert "none of the kind's Steps"                              "$( LC_ALL=C grep -c -x -F -- '# Steps of magic-team.coworking.routine' "$rigTmp/rigmixed.text" || : )" "0"
echo "-- 3. Closure: its own first, then the kind's --"
rigAssert "its own Closure steps"                                 "$( rigSteps "$rigTmp/rigmixed.text" '# Closure steps of magic-team.rigmixed.routine' )" "rig-own-close"
rigAssert "the kind's after them"                                 "$( rigSteps "$rigTmp/rigmixed.text" "$rigKindClose" ):$( [ "$( rigLine "$rigTmp/rigmixed.text" '# Closure steps of magic-team.rigmixed.routine' )" -gt 0 ] && [ "$( rigLine "$rigTmp/rigmixed.text" '# Closure steps of magic-team.rigmixed.routine' )" -lt "$( rigLine "$rigTmp/rigmixed.text" "$rigKindClose" )" ] && echo own-first )" "$rigKindClosure:own-first"
echo "-- 4. skips-inherited: leaves the named step out, and it comes back nowhere --"
rigText magic-team.rigskipping rigskipping
rigAssert "the kind's Opening steps without ${rigLeafKindOpening:-a step of the kind}, the others stay" "$( rigSteps "$rigTmp/rigskipping.text" "$rigKindHead" )" "$( rigFileStepsWithout "$rigKind" '# Opening steps' "$rigLeafKindOpening" )"
rigAssert "its own Opening step stays, and the skipped step is in no section of the text" "$( rigSteps "$rigTmp/rigskipping.text" '# Opening steps of magic-team.rigskipping.routine' ):$( LC_ALL=C grep -c -E "^#+ ${rigLeafKindOpening:-none}\$" "$rigTmp/rigskipping.text" || : )" "rig-own-open:0"
rigText magic-team.rigskipgroup rigskipgroup
rigAssert "a skipped group, ${rigFirstKindOpening:-the first step}, takes its steps with it" "$( rigSteps "$rigTmp/rigskipgroup.text" "$rigKindHead" )" "$( rigFileStepsWithout "$rigKind" '# Opening steps' "$rigFirstKindOpening" )"

echo "-- 5. a real routine of the coworking kind --"
rigText magic-team.grooming grooming
rigAssert "grooming runs the kind's Opening steps" "$( rigSteps "$rigTmp/grooming.text" "$rigKindHead" )" "$rigKindOpening"
rigAssert "its own Steps are there, and the kind's Closure steps come after them" "$( [ "$( rigLine "$rigTmp/grooming.text" '# Steps of magic-team.grooming.routine' )" -gt 0 ] && [ "$( rigLine "$rigTmp/grooming.text" '# Steps of magic-team.grooming.routine' )" -lt "$( rigLine "$rigTmp/grooming.text" "$rigKindClose" )" ] && echo own-then-kind )" "own-then-kind"

echo "-- 6. advance and heartbeat skip what they name; retro skips none --"
for rigName in advance heartbeat retro ; do
	rigText "magic-coordinator.$rigName" "co-$rigName"
	rigFile="$rigSkills/magic-coordinator/magic-coordinator.$rigName.routine.md"
	rigSkipped="$( LC_ALL=C sed -n 's/^skips-inherited: *//p' "$rigFile" | LC_ALL=C tr ',' '\n' | LC_ALL=C sed 's/^ *//; s/ *$//' | LC_ALL=C grep . | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )"
	rigAllKind="$rigKindOpening $rigKindClosure"
	rigNotKind="" ; rigStill="" ; rigWant=""
	for rigStep in $rigSkipped ; do
		case " $rigAllKind " in *" $rigStep "*) ;; *) rigNotKind="$rigNotKind $rigStep" ;; esac
	done
	for rigStep in $rigKindOpening ; do case " $rigSkipped " in *" $rigStep "*) ;; *) rigWant="$rigWant $rigStep" ;; esac ; done
	rigWantClose=""
	for rigStep in $rigKindClosure ; do case " $rigSkipped " in *" $rigStep "*) ;; *) rigWantClose="$rigWantClose $rigStep" ;; esac ; done
	for rigStep in $rigSkipped ; do rigStill="$rigStill$( LC_ALL=C grep -c -E "^#+ $rigStep\$" "$rigTmp/co-$rigName.text" || : )" ; done
	rigAssert "$rigName: every step it skips is a step of the kind"        "[${rigNotKind# }]" "[]"
	rigAssert "$rigName: none of them is in its text, all the others are"  "[$( printf '%s' "$rigStill" | LC_ALL=C tr -d '0' )]:$( rigSteps "$rigTmp/co-$rigName.text" "$rigKindHead" ):$( rigSteps "$rigTmp/co-$rigName.text" "$rigKindClose" )" "[]:${rigWant# }:${rigWantClose# }"
done
rigAssert "retro skips none: the frontmatter names no step"              "$( LC_ALL=C grep -c '^skips-inherited:' "$rigSkills/magic-coordinator/magic-coordinator.retro.routine.md" || : )" "0"

echo "-- 7. reproducible: two sessions, some seconds apart, the same bytes --"
rigText magic-coordinator.advance adv-one rig-session-one
sleep 2
rigText magic-coordinator.advance adv-two rig-session-two
rigAssert "the two texts are the same bytes, and not empty"             "$( [ -s "$rigTmp/adv-one.text" ] && cmp -s "$rigTmp/adv-one.text" "$rigTmp/adv-two.text" && echo identical )" "identical"
rigAssert "and the same as the text of a run in no session"             "$( cmp -s "$rigTmp/adv-one.text" "$rigTmp/co-advance.text" && echo identical )" "identical"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROUTINE MIX IN CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ROUTINE_MIX_IN: OK (%d assertions, offline)\n' "$rigPassCount"
