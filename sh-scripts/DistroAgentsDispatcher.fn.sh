#!/usr/bin/env bash

##
## DistroAgentsDispatcher.fn.sh -- TeamDispatcher (F7.4): the runs of the team, every session and dispatch, present and
## past, and the spawner console tool command over them. A subsystem interface: results are read from it, by agent
## tools, the shell console and shell automation alike. So far: the session lists (--all-sessions, --active-sessions,
## --waiting-sessions, each with --kind), --session-record, the predecessor question (--routine-completed), and the schedule
## (F7.5): --current-flags, --override-flag, the setters --set-country, --set-timezone, --set-worktime and --set-weekend, and
## --routine-due, and the runs and stats store (F7.11): --rebuild-stats, --stats-check, --run-stats, --run-history, --routine-stats and --token-stats. Dispatcher owns
## the runs and the policy deciding when a run starts; its one store is that index (.local/agents/stats), derived from the run records and never a source,
## and it reads the rows the console's list reads. Scheduling is a convention (a routine's runs-at and runs-after, a few settings) and this the
## interpreter of it, not a tool family.
##
## From DistroAgentsTools.fn.sh (F1.4): --shutdown-runs, --spawn-prompt, --spawn-session (sh-lib/harness/AgentsContext.FrontTable.include).
##
## NOTE:
## Designed to be able to run without distro context. Starts console sessions.
##

if [ -z "$MMDAPP" ] ; then
	set -e
	export MMDAPP="$( cd $(dirname "$0")/../../../.. ; pwd )"
	echo "$0: Working in: $MMDAPP" >&2
	[ -d "$MMDAPP/.local" ] || ( echo "⛔ ERROR: expecting '.local' directory." >&2 && exit 1 )
fi

## Every child finds the bash this runs in, as DistroAgentsTools.fn.sh does.
case "$BASH" in
	/*/bash)
		command -v bash > /dev/null 2>&1 || { PATH="${PATH:+$PATH:}${BASH%/*}" ; export PATH ; }
		export MDAT_BASH="$BASH"
	;;
esac

## The Dispatcher's operations (AgentsTools.Dispatcher.include), loaded where they are asked for.
DistroAgentsDispatcherTools(){
	type AgentsToolsDispatcherSessions > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.Dispatcher.include"
}

## The schedule's (AgentsTools.DispatcherSchedule.include): the flags, their setters and the autorun's decision.
DistroAgentsDispatcherSchedule(){
	DistroAgentsDispatcherTools
	type AgentsToolsScheduleDue > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.DispatcherSchedule.include"
}

## The operations that came here from DistroAgentsTools.fn.sh (F1.4): every one of them is asked what each name of the table is asked, in AgentsContext.FrontDoor.include.
DistroAgentsDispatcherMoved(){
	local MDSC_CMD='DistroAgentsDispatcher' frontDone="" frontRc=0
	type AgentsToolsFrontKnows > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontTable.include"
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontDoor.include"
	[ -z "$frontDone" ] || return "$frontRc"
	case "$1" in

		--shutdown-runs)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.InternOpReview.include"
			return $?
		;;

		--spawn-prompt)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicCoordinatorState.include"
			return $?
		;;

		--spawn-session)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicSpawnSession.include"
			return $?
		;;

		*)
			echo "$MDSC_CMD: ⛔ ERROR: invalid option: $1" >&2
			set +e ; return 1
		;;
	esac
}

DistroAgentsDispatcher(){
	local MDSC_CMD='DistroAgentsDispatcher'
	## The family's context, here and in this file's arm, for a console that calls this function.
	if [ -z "$MDLT_ORIGIN" ] || ! type DistroAgentsContext >/dev/null 2>&1 ; then
		. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib/harness/AgentsContext.include"
		DistroAgentsContext --run-from-detect
		DistroAgentsContext --distro-path-auto
	fi
	## F1.4: a name that came here from DistroAgentsTools.fn.sh runs its operation in the function below.
	type AgentsToolsFrontKnows > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontTable.include"
	if AgentsToolsFrontKnows DistroAgentsDispatcher "$@" ; then
		DistroAgentsDispatcherMoved "$@"
		return $?
	fi
	## The three help forms, as DistroAgentsTools.fn.sh has them: no word the default syntax (the entry points a reader
	## starts from), --help-syntax the syntax line of every operation of this file, --help the manual.
	case "${1:-}" in
		''|--help|--help-syntax)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/help/Help.DistroAgentsDispatcher.include"
			return $?
		;;
	esac
	## The common option set (F2.2): a run of --team-member, --session-id, --spawn-id, --select-workspace and --tooling-origin after the operation is taken here,
	## and the call is made again under what they resolve (sh-lib/common/AgentsTools.CommonOptions.include).
	case "${agentsCommonFronted:-}:${2:-}" in
		:--team-member|:--session-id|:--spawn-id|:--select-workspace|:--tooling-origin)
			local commonRc=0
			type AgentsToolsCommonRun > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.CommonOptions.include"
			AgentsToolsCommonRun DistroAgentsDispatcher DistroAgentsDispatcher.fn.sh "$@" || commonRc=$?
			return "$commonRc"
		;;
	esac
	## The skillset root, as every operation of the tooling settles it (AgentsContext.UseAgentsTools.include).
	if [ -z "${MDAT_SKILLSET_ROOT:-}" ] ; then
		MDAT_SKILLSET_ROOT="$MMDAPP/.local/agents/members"
		export MDAT_SKILLSET_ROOT
	fi
	case "$1" in

		## The sessions of this workspace with their runs, the rows --manager-session-list prints; those not finished
		## with --active-sessions, those that wait (the list's own `waiting` state) with --waiting-sessions. [--kind
		## standalone|coworking|ad-hoc] keeps one kind of session (F6.1), read from the routine its run records.
		--all-sessions|--active-sessions|--waiting-sessions)
			local sessionsOp="$1"
			shift
			DistroAgentsDispatcherTools
			AgentsToolsDispatcherSessions "$sessionsOp" "$@"
			return $?
		;;

		## The runs this session may see, bound to the session of the call (ThisSession): its sub-sessions, the public
		## coworking sessions and the caller's own -- never another member's private session, unless the call is made in it.
		--list-session-runs)
			shift
			type AgentsToolsThisSessionRuns > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.ThisSession.include"
			AgentsToolsThisSessionRuns "$@"
			return $?
		;;

		## The BPMN/DMN diagrams older than the newest definition file: <definitions-dir> <diagrams-dir>, read-only.
		--camunda-diagram-sync-stale)
			local camundaOp="$1"
			shift
			DistroAgentsDispatcherTools
			AgentsToolsCamundaDiagramSyncStale "$camundaOp" "$@"
			return $?
		;;

		## One session in full, or with --run one run of it, the rows --manager-session-read prints: <session-id> [--run].
		--session-record)
			local recordOp="$1"
			shift
			DistroAgentsDispatcherTools
			AgentsToolsDispatcherRecord "$recordOp" "$@"
			return $?
		;;

		## The predecessor question: whether a run of a routine closed spawn-succeeded at or after a time.
		## <routine> --since "<YYYY-MM-DD HH:MM>". Prints the run and ends 0, else a NOT-COMPLETED line and ends 1.
		--routine-completed)
			local completedOp="$1"
			shift
			DistroAgentsDispatcherTools
			AgentsToolsDispatcherCompleted "$completedOp" "$@"
			return $?
		;;

		## The flags of the schedule now, derived from the settings and the clock: worktime, weekend, holidays, emergency, overtime and
		## learning, a line each, `<flag>: yes|no`. Read-only.
		--current-flags)
			local flagsOp="$1"
			shift
			DistroAgentsDispatcherSchedule
			AgentsToolsScheduleCurrentFlags "$flagsOp" "$@"
			return $?
		;;

		## An override of a flag: [--no] <flag> [<ttl>], the flag emergency (with a TTL), overtime, holidays (with a TTL, or until cleared) or learning.
		--override-flag)
			local overrideOp="$1"
			shift
			DistroAgentsDispatcherSchedule
			AgentsToolsScheduleOverride "$overrideOp" "$@" || return $?
			## A flag set by hand asks the schedule thread once, so a flag that keeps duties starts them with no session live to ask.
			type AgentsToolsScheduleThreadAsk > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.ScheduleThread.include"
			AgentsToolsScheduleThreadAsk > /dev/null 2>&1 || :
			return 0
		;;

		## The stop of a rig, in order (S12.15): it refuses unless `holding` holds, so nothing starts again; then every live session is ended
		## with the console stop, and the schedule thread last. One line for each session ended.
		--stop-sessions)
			local stopOp="$1" stopId stopHolder stopRc=0 stopList=""
			shift
			[ $# -eq 0 ] || { echo "⛔ ERROR: $MDSC_CMD $stopOp: takes no argument, got: $1" >&2 ; return 1 ; }
			DistroAgentsDispatcherSchedule
			case "$( AgentsToolsScheduleCurrentFlags --current-flags )" in
				*"holding: yes"*) ;;
				*) echo "⛔ ERROR: $MDSC_CMD $stopOp: holding is not set -- set it first with --override-flag holding, so the schedule starts nothing again" >&2 ; return 1 ;;
			esac
			type DistroAgentsTools > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
			## A START STILL IN FLIGHT JOINS AFTER THE PASS: the pass is repeated while one was in flight, each start waited for up to 120s.
			local stopPass=0 stopFlight stopWaited
			while [ "$stopPass" -lt 3 ] ; do
				stopPass=$(( stopPass + 1 ))
				## THE LIST IS READ ONCE, AND A LIST THAT COULD NOT BE READ ENDS THE STOP: a call refused the sessions has ended none, and
				## answering 0 there reports a stop that never happened. Its refusal reaches the caller here, as one plain line.
				stopList="$( DistroAgentsDispatcher --active-sessions --scope all 2>&1 )" || {
					echo "⛔ ERROR: $MDSC_CMD $stopOp: no session was ended, since the live sessions could not be listed: $( printf '%s\n' "$stopList" | LC_ALL=C grep -m 1 -E 'ERROR|REFUS' | LC_ALL=C cut -c1-300 )" >&2 ; return 1
				}
				for stopId in $( printf '%s\n' "$stopList" | LC_ALL=C awk -F'\t' '$1 == "session" && $4 != "failed" && $4 != "finished" { print $2 }' ) ; do
					( DistroAgentsTools --manager-session-kill --session-id "$stopId" ) | LC_ALL=C grep '^finish' || { echo "⚠️ WARNING: $MDSC_CMD $stopOp: session $stopId could not be ended" >&2 ; stopRc=1 ; }
				done
				stopFlight="$( find "$MMDAPP/.local/agents/schedule/starting" -type f ! -name '*.hold' ! -name '*.out' ! -name '*.rc' 2> /dev/null )"
				[ -n "$stopFlight" ] || break
				stopWaited=0
				while [ -n "$stopFlight" ] && [ "$stopWaited" -lt 120 ] ; do
					sleep 5 ; stopWaited=$(( stopWaited + 5 ))
					stopFlight="$( find "$MMDAPP/.local/agents/schedule/starting" -type f ! -name '*.hold' ! -name '*.out' ! -name '*.rc' 2> /dev/null )"
				done
			done
			type AgentsToolsScheduleThreadDir > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.ScheduleThread.include"
			stopHolder="$( cat "$( AgentsToolsScheduleThreadDir )/thread.lock" 2> /dev/null )" || stopHolder=""
			if [ -n "$stopHolder" ] && AgentsToolsThreadLockHolderLives "$stopHolder" 2> /dev/null ; then
				kill -TERM "${stopHolder%% *}" 2> /dev/null && printf 'thread\t%s\tended\n' "${stopHolder%% *}"
			fi
			return "$stopRc"
		;;

		## The cleanup of the failed sessions of this workspace: each closed with the console kill, which reads it as finished from then on.
		--close-failed-sessions)
			local closeOp="$1" closeId closeDone=0 closeAll=0 closeRc=0 closeList=""
			shift
			[ $# -eq 0 ] || { echo "⛔ ERROR: $MDSC_CMD $closeOp: takes no argument, got: $1" >&2 ; return 1 ; }
			type DistroAgentsTools > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
			## THE SAME ONE READING, AND THE SAME REFUSAL: a list that could not be read closes nothing, and `closed 0 of 0` there reads as a
			## rig with no failed session rather than a call that never looked.
			closeList="$( DistroAgentsDispatcher --active-sessions --scope all 2>&1 )" || {
				echo "⛔ ERROR: $MDSC_CMD $closeOp: nothing was closed, since the sessions could not be listed: $( printf '%s\n' "$closeList" | LC_ALL=C grep -m 1 -E 'ERROR|REFUS' | LC_ALL=C cut -c1-300 )" >&2 ; return 1
			}
			for closeId in $( printf '%s\n' "$closeList" | LC_ALL=C awk -F'\t' '$1 == "session" && $4 == "failed" { print $2 }' ) ; do
				closeAll=$(( closeAll + 1 ))
				if ( DistroAgentsTools --manager-session-kill --session-id "$closeId" ) | LC_ALL=C grep '^finish' ; then
					closeDone=$(( closeDone + 1 ))
				else
					echo "⚠️ WARNING: $MDSC_CMD $closeOp: session $closeId could not be closed" >&2 ; closeRc=1
				fi
			done
			printf 'closed\t%s\tof\t%s\tfailed sessions\n' "$closeDone" "$closeAll"
			return "$closeRc"
		;;

		## The settings of the schedule, a person's configuration: --set-country <iso-code-2-or-3-letters>, --set-timezone <tz-spec>,
		## --set-worktime <start> <until> <days-of-week>, --set-weekend <days-of-week>.
		--set-country|--set-timezone|--set-worktime|--set-weekend)
			local setOp="$1"
			shift
			DistroAgentsDispatcherSchedule
			AgentsToolsScheduleSet "$setOp" "$@"
			return $?
		;;

		## Whether a routine is due to start now by its own autorun declaration (runs-at, runs-after): [--read-only] <routine>. rc 0 due, 1 not due,
		## 2 refused, naming the predecessor that has not completed, 3 a call that could not be understood.
		--routine-due)
			local dueOp="$1"
			shift
			DistroAgentsDispatcherSchedule
			AgentsToolsScheduleDue "$dueOp" "$@"
			return $?
		;;

		## The runs and stats store of .local/agents (F7.11), an index derived from the run records and never a source: --rebuild-stats derives it whole,
		## --stats-check compares it with a rebuild, and the readers --run-stats, --run-history, --routine-stats and --token-stats bring it up to date first.
		--rebuild-stats|--stats-check|--run-stats|--run-history|--routine-stats|--token-stats)
			local statsOp="$1"
			shift
			type AgentsToolsStatsDerive > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.DispatcherStats.include"
			case "$statsOp" in
				--rebuild-stats) AgentsToolsStatsRebuild "$statsOp" "$@" ;;
				--stats-check) AgentsToolsStatsCheck "$statsOp" "$@" ;;
				--run-stats) AgentsToolsStatsRuns "$statsOp" "$@" ;;
				--run-history) AgentsToolsStatsHistory "$statsOp" "$@" ;;
				--routine-stats) AgentsToolsStatsRoutines "$statsOp" "$@" ;;
				--token-stats) AgentsToolsStatsTokens "$statsOp" "$@" ;;
			esac
			return $?
		;;

		*)
			echo "$MDSC_CMD: ⛔ ERROR: invalid option: $1" >&2
			set +e ; return 1
		;;
	esac
}

## A relative or symlinked path to this very file dispatches too: it is resolved to the real file before the match, and only a path that
## resolves elsewhere is refused. Sourced ($0 differs from BASH_SOURCE[0]), nothing is resolved.
selfPath="$0"
case "$0" in
	*/myx/myx.distro-agents/sh-scripts/*.fn.sh) ;;
	*) [ "${BASH_SOURCE[0]:-}" != "$0" ] || selfPath="$( cd "$( dirname "$0" )" 2> /dev/null && pwd -P )/${0##*/}" ;;
esac
case "$selfPath" in
	*/myx/myx.distro-agents/sh-scripts/DistroAgentsDispatcher.fn.sh)

		set -e

		if [ -z "$MDLT_ORIGIN" ] || ! type DistroAgentsContext >/dev/null 2>&1 ; then
			. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib/harness/AgentsContext.include"
		fi
		DistroAgentsContext --run-from-detect
		DistroAgentsContext --distro-path-auto

		DistroAgentsDispatcher "$@"
	;;
	*)
		## Executed by an unrecognised path: error. Sourced ($0 differs from BASH_SOURCE[0]): stay silent.
		if [ "${BASH_SOURCE[0]:-}" = "$0" ] ; then
			echo "⛔ ERROR: DistroAgentsDispatcher.fn.sh: executed as '$0', which this file's own dispatch does not match, so nothing ran. Invoke it by a path ending in /myx/myx.distro-agents/sh-scripts/DistroAgentsDispatcher.fn.sh, or source it." >&2
			exit 1
		fi
	;;
esac
