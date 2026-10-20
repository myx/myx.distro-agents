#!/usr/bin/env bash
## Behavioural check on inline routine execution (F6.6 of the refactorings epic): ThisSession's `--routine-run-inline <routine>`
## hands the calling run a routine's steps like a call. The run gets the routine's Steps with the Opening steps, Closure steps,
## local rules of `magic-team.inline.routine` mixed in, in place of those of its session kind (steps designed for
## inline, none of a session's, such as the reflections), without the routine's frontmatter and without its Maintainer Notes; and
## the routine's own `input-scan-def:` scans are run through the spawner's one runner, the result saved to the caller's sandbox
## input/ folder and named in a line ahead of the steps, as the spawner presents the scan of a session it starts.
## Held:
##   1. the text: the first line names the routine; the routine's own Steps; the inline routine's Closure steps (it has no Opening steps); none of
##      its session kind's groups; no frontmatter; no Maintainer Notes
##   2. a routine of the coworking kind is mixed the same way (none of the coworking groups)
##   3. the scan: a declared scan is run for the calling member, its result is input/input-scan.<routine>.md of the sandbox and a line
##      names it; several lines run in order; `none` and no scan leave no line and no file; a scan that fails does not stop the
##      call, the file says it failed
##   4. from no sandbox the result follows the steps; from no member's session a routine that declares a scan is refused
##   5. refused, with a reason: no routine, two, a routine that matches no file, one that matches several
##   6. the inline routine is a valid routine of the package, and every routine of the package that runs another inline names the
##      operation, in its steps and in its tooling list (the callers' prose)
## Offline: rig trees; the permission-escalation scan reads the rig's own team data.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigSession="$rigPackage/sh-scripts/DistroAgentsSession.fn.sh"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigSession" ] || rigRefuse "ThisSession is not at the origin this workspace resolves: $rigSession"
rigInline="$rigPackage/skillset/magic-team/magic-team/magic-team.inline.routine.md"
rigStandalone="$rigPackage/skillset/magic-team/magic-team/magic-team.standalone.routine.md"
rigCoworking="$rigPackage/skillset/magic-team/magic-team/magic-team.coworking.routine.md"
for rigNeed in "$rigInline" "$rigStandalone" "$rigCoworking" ; do [ -f "$rigNeed" ] || rigRefuse "a routine of the package is missing: $rigNeed" ; done
mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsRoutineRunInlineCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigSkills="$rigTmp/skills" rigData="$rigTmp/data" rigSandbox="$rigTmp/sandbox"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned/keeper-rig" "$rigTmp/home" "$rigSkills/magic-team" "$rigSkills/keeper-rig" "$rigSkills/magic-coordinator" "$rigData/board" "$rigSandbox/input" "$rigSandbox/output"
for rigMember in keeper-rig magic-coordinator ; do
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md" ; printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
done
cp "$rigInline" "$rigStandalone" "$rigCoworking" "$rigSkills/magic-team/"
printf -- '---\nspawn-id: rig-run\nsession-id: rig-session\nowner: keeper-rig\n---\n\nrig\n' > "$rigWs/.local/agents/spawned/keeper-rig/rig-run.md"
rigRoutine(){ ## short name, kind, extra frontmatter lines (newline separated, may be empty)
	{
		printf -- '---\ntype: routine\nexecutors: keeper-rig\nmaintainers: SENT-FRONT\nrequires-session-kind: %s\n' "$2"
		[ -z "$3" ] || printf '%s\n' "$3"
		printf -- '---\n# keeper-rig.%s.routine — the actual procedure\n\n# Summary\n\nA rig routine.\n\n# Opening steps\n\n1. **rig-own-open**: open.\n\n# Steps\n\n1. **rig-own-work**: work.\n\n# Closure steps\n\n1. **rig-own-close**: close.\n\n' "$1"
		printf "# Routine's local procedures\n\nNone.\n\n# Routine's local rules\n\nNone.\n\n# Routine-specific tooling\n\nNone.\n\n# Maintainer Notes\n\nMAINT-SENTINEL\n"
	} > "$rigSkills/keeper-rig/keeper-rig.$1.routine.md"
}
rigRoutine scanned standalone 'input-scan-def: permission-escalation'
rigRoutine plain standalone 'input-scan-def: none'
rigRoutine cow coworking 'input-scan-def: none'
rigRoutine failing standalone 'input-scan-def: permission-escalation --bogus {{team-member}}'
rigRoutine twice standalone 'input-scan-def: permission-escalation
input-scan-def: member-work-session'

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One call: <name>.out, <name>.err and <name>.rc in $rigTmp. kind: member (a spawned member's run with a sandbox), nosandbox, console.
rigCall(){ ## name, kind, args...
	local callName="$1" callKind="$2" callRc=0 callEnv=()
	shift 2
	case "$callKind" in
		member) callEnv=( MDAT_SPAWN_AGENT=keeper-rig MDAT_SPAWN_SESSION_ID=rig-run MDAT_SPAWN_SANDBOX_ROOT="$rigSandbox" ) ;;
		nosandbox) callEnv=( MDAT_SPAWN_AGENT=keeper-rig MDAT_SPAWN_SESSION_ID=rig-run ) ;;
	esac
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_DATA_ROOT="$rigData" ${callEnv[@]+"${callEnv[@]}"} \
		perl -e 'alarm 120 ; exec @ARGV' bash "$rigSession" --routine-run-inline "$@" ) > "$rigTmp/$callName.out" 2> "$rigTmp/$callName.err" < /dev/null || callRc=$?
	printf '%s' "$callRc" > "$rigTmp/$callName.rc"
}
rigHas(){ ## name, fixed string -- how many lines of the output hold it
	LC_ALL=C grep -c -F -- "$2" "$rigTmp/$1.out" || :
}
rigSteps(){ ## name, heading -- the names of the steps of one section of the output (the engine's form: a mixin named `<section> of <file stem>`), joined: the numbered
	## root steps `N. **name**` of a routine's own, and the sections of depth 3 and below of the kind's
	LC_ALL=C awk -v want="$2" '
		/^# / { on = ( $0 == want ) ; next }
		on && /^###+ / { name = $0 ; sub( /^#+ /, "", name ) ; printf "%s%s", sep, name ; sep = " " ; next }
		on && /^[0-9]+\. \*\*[^*]+\*\*/ { name = $0 ; sub( /^[0-9]+\. \*\*/, "", name ) ; sub( /\*\*.*$/, "", name ) ; printf "%s%s", sep, name ; sep = " " }
	' "$rigTmp/$1.out"
}

echo "-- 1. the text of a routine run inline --"
rigCall scanned member keeper-rig.scanned
rigAssert "rc 0, and the first line names the routine"          "$( cat "$rigTmp/scanned.rc" ):$( head -1 "$rigTmp/scanned.out" )" "0:RUN-INLINE: keeper-rig.scanned.routine.md"
rigAssert "Opening: the routine's own only (the inline routine has none)" "$( rigSteps scanned '# Opening steps of keeper-rig.scanned.routine' ):$( rigSteps scanned '# Opening steps of magic-team.inline.routine' )" "rig-own-open:"
rigAssert "Steps: its own only"                                 "$( rigSteps scanned '# Steps of keeper-rig.scanned.routine' )" "rig-own-work"
rigAssert "Closure: its own, then the inline routine's"         "$( rigSteps scanned '# Closure steps of keeper-rig.scanned.routine' ) $( rigSteps scanned '# Closure steps of magic-team.inline.routine' ):$( [ "$( LC_ALL=C grep -n -x -F '# Closure steps of keeper-rig.scanned.routine' "$rigTmp/scanned.out" | LC_ALL=C sed 's/:.*//' )" -lt "$( LC_ALL=C grep -n -x -F '# Closure steps of magic-team.inline.routine' "$rigTmp/scanned.out" | LC_ALL=C sed 's/:.*//' )" ] && echo own-first )" "rig-own-close return-the-result:own-first"
rigAssert "none of the session kind's groups"                   "$( LC_ALL=C grep -c -E -- 'session-start|close-session|fold-in-learned-lessons|declare-session-type|secure-continuity' "$rigTmp/scanned.out" || : )" "0"
rigAssert "no frontmatter"                                      "$( LC_ALL=C grep -c -E -- '^(type|executors|maintainers|requires-session-kind|input-scan-def): |SENT-FRONT' "$rigTmp/scanned.out" || : )" "0"
rigAssert "no Maintainer Notes"                                 "$( LC_ALL=C grep -c -E -- 'MAINT-SENTINEL|^# Maintainer Notes' "$rigTmp/scanned.out" || : )" "0"
rigAssert "the inline routine's rules are mixed in"             "$( rigHas scanned 'An inline run is the caller'"'"'s own' )" "1"

echo "-- 2. a routine of the coworking kind is mixed the same way --"
rigCall cow member keeper-rig.cow
rigAssert "inline Closure and none of the coworking groups" "$( rigSteps cow '# Opening steps of keeper-rig.cow.routine' ) | $( rigSteps cow '# Closure steps of keeper-rig.cow.routine' ) $( rigSteps cow '# Closure steps of magic-team.inline.routine' ) | $( LC_ALL=C grep -c -E -- 'session-start|close-session|post-opening-broadcast|dismiss-participants' "$rigTmp/cow.out" || : )" "rig-own-open | rig-own-close return-the-result | 0"

echo "-- 3. the scan --"
rigAssert "a line names the saved file and the scan"            "$( rigHas scanned 'input-scan: input/input-scan.keeper-rig.scanned.md of your sandbox holds the result of this routine'"'"'s input scan (permission-escalation)' )" "1"
rigAssert "the file holds the scan's report, for the calling member (macros filled)" "$( [ -f "$rigSandbox/input/input-scan.keeper-rig.scanned.md" ] && echo saved || echo none ):$( LC_ALL=C grep -c -F 'permission asks addressed to' "$rigSandbox/input/input-scan.keeper-rig.scanned.md" 2> /dev/null )" "saved:1"
rigAssert "the session's own input-scan.md is not touched"      "$( [ -e "$rigSandbox/input/input-scan.md" ] && echo there || echo none )" "none"
rigCall plain member keeper-rig.plain
rigAssert "none: no line, no file"                               "$( cat "$rigTmp/plain.rc" ):$( rigHas plain 'input-scan:' ):$( ls "$rigSandbox/input" | LC_ALL=C grep -c 'plain' || : )" "0:0:0"
rigCall twice member keeper-rig.twice
rigAssert "two lines: both headings in the file, in order, both named" "$( LC_ALL=C grep '^## input scan: ' "$rigSandbox/input/input-scan.keeper-rig.twice.md" 2> /dev/null | LC_ALL=C tr '\n' '|' ):$( rigHas twice '(permission-escalation, member-work-session)' )" "## input scan: permission-escalation|## input scan: member-work-session|:1"
rigCall failing member keeper-rig.failing
rigAssert "a failing scan: the call goes on, the file says it failed and what it ran" "$( cat "$rigTmp/failing.rc" ):$( rigSteps failing '# Steps of keeper-rig.failing.routine' ):$( LC_ALL=C grep -c -F '## input scan failed' "$rigSandbox/input/input-scan.keeper-rig.failing.md" 2> /dev/null ):$( LC_ALL=C grep -c -F 'permission-escalation-input-scan keeper-rig --bogus keeper-rig' "$rigSandbox/input/input-scan.keeper-rig.failing.md" 2> /dev/null )" "0:rig-own-work:1:1"

echo "-- 4. no sandbox, no member --"
rigCall nosandbox nosandbox keeper-rig.scanned
rigAssert "no sandbox: the result follows the steps"             "$( cat "$rigTmp/nosandbox.rc" ):$( rigHas nosandbox 'follows the steps below under `## input scan result`' ):$( rigHas nosandbox '## input scan result' ):$( rigHas nosandbox 'permission asks addressed to' )" "0:1:2:1"
rigCall console console keeper-rig.scanned
rigAssert "from no member's session a routine with a scan is refused, nothing handed" "$( cat "$rigTmp/console.rc" ):$( LC_ALL=C grep -c -F 'comes from no member' "$rigTmp/console.err" ):$( wc -c < "$rigTmp/console.out" | tr -d ' ' )" "1:1:0"
rigCall consoleplain console keeper-rig.plain
rigAssert "a routine with no scan needs no member"               "$( cat "$rigTmp/consoleplain.rc" ):$( rigSteps consoleplain '# Steps of keeper-rig.plain.routine' )" "0:rig-own-work"

echo "-- 5. refusals --"
rigCall none member
rigAssert "no routine"                                           "$( cat "$rigTmp/none.rc" ):$( LC_ALL=C grep -c -F 'syntax is <routine-selector>' "$rigTmp/none.err" )" "1:1"
rigCall two member keeper-rig.plain keeper-rig.cow
rigAssert "two routines"                                         "$( cat "$rigTmp/two.rc" ):$( LC_ALL=C grep -c -F 'syntax is <routine-selector>' "$rigTmp/two.err" )" "1:1"
rigCall nomatch member keeper-rig.nosuch
rigAssert "a routine that matches no file"                       "$( cat "$rigTmp/nomatch.rc" ):$( LC_ALL=C grep -c -F 'matches no routine file' "$rigTmp/nomatch.err" )" "1:1"
rigCall several member keeper-rig
rigAssert "one that matches several"                             "$( cat "$rigTmp/several.rc" ):$( LC_ALL=C grep -c -F 'matches more than one routine file' "$rigTmp/several.err" )" "1:1"

echo "-- 6. the inline routine, and the callers' prose --"
rigValidate="$( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" MDAT_SKILLSET_ROOT="$rigSkills" bash "$rigTool" --intern-doc-validate routine "$rigInline" 2>&1 < /dev/null; echo "rc=$?" )"
rigAssert "the inline routine passes the routine validator"      "$( printf '%s\n' "$rigValidate" | LC_ALL=C grep -c '^rc=0$' ):$( printf '%s\n' "$rigValidate" | LC_ALL=C grep -c '^[^ ]*:[0-9]*: ' || : )" "1:0"
rigAssert "it is never started as a session, has no Opening step and no post of its own" "$( LC_ALL=C grep -c -x 'start-context: inline' "$rigInline" ):$( LC_ALL=C grep -c -E 'declare-inline-run|slack-send-message' "$rigInline" || : )" "1:0"
rigSkillset="$rigPackage/skillset/magic-team"
rigMissing=""
rigCallerOf(){ ## caller file (short), callee routine (full name) -- rc 0 where the caller names `--routine-run-inline <callee>` and lists the operation
	local callerFile
	callerFile="$( find "$rigSkillset" -name "$1" -type f | head -1 )"
	[ -n "$callerFile" ] || return 1
	LC_ALL=C grep -q -F -- "--routine-run-inline $2" "$callerFile" && LC_ALL=C grep -q -x -F -- '- `--routine-run-inline <routine>`' "$callerFile"
}
for rigPair in \
	magic-coordinator.advance.routine.md:magic-team.process-inbox.routine magic-coordinator.advance.routine.md:magic-team.handback-review.routine magic-coordinator.advance.routine.md:magic-coordinator.communication-sweep.routine \
	magic-coordinator.daily.routine.md:magic-coordinator.communication-sweep.routine magic-coordinator.daily.routine.md:magic-coordinator.advance.routine \
	magic-coordinator.coordination-session.routine.md:magic-coordinator.communication-sweep.routine magic-coordinator.coordination-session.routine.md:magic-coordinator.advance.routine \
	magic-coordinator.ingest-task.routine.md:magic-team.process-inbox.routine magic-coordinator.communication-sweep.routine.md:magic-team.process-inbox.routine \
	magic-team.brainstorm.routine.md:magic-team.process-inbox.routine magic-team.discuss.routine.md:magic-team.process-inbox.routine magic-team.proposal.routine.md:magic-team.process-inbox.routine \
	magic-team.interview.routine.md:magic-team.process-inbox.routine magic-team.grooming.routine.md:magic-team.process-inbox.routine magic-team.grooming.routine.md:magic-team.handback-review.routine \
	magic-team.process-reflections.routine.md:magic-team.process-inbox.routine magic-team.process-reflections.routine.md:magic-librarian.conventions-check.routine \
	magic-team.coworking.routine.md:magic-team.process-reflections.routine magic-team.coworking.routine.md:magic-team.process-inbox.routine \
	magic-team.standalone.routine.md:magic-team.process-reflections.routine magic-team.standalone.routine.md:magic-team.process-inbox.routine ; do
	rigCallerOf "${rigPair%%:*}" "${rigPair#*:}" || rigMissing="$rigMissing ${rigPair%%:*}>${rigPair#*:}"
done
rigAssert "every inline caller names the operation with its callee, and lists it" "[${rigMissing# }]" "[]"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROUTINE RUN INLINE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ROUTINE_RUN_INLINE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
