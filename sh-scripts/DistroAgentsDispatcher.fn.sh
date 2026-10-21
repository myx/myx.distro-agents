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
## From DistroAgentsTools.fn.sh (F1.4, first stage): --shutdown-runs, --spawn-prompt, --spawn-session. They go on under their old names (sh-lib/harness/AgentsContext.FrontForward.include).
##
## NOTE:
## Designed to be able to run without distro context. Starts console sessions.
##

if [ -z "$MMDAPP" ] ; then
	set -e
	export MMDAPP="$( ( cd "$( dirname "$0" )/../../../.." && pwd ) )"
	echo "$0: Working in: $MMDAPP"  >&2
	[ -d "$MMDAPP/.local" ] || ( echo "⛔ ERROR: expecting '.local' directory." >&2 && exit 1 )
fi

: "${MDLT_ORIGIN:=$MMDAPP/.local}"
export MDLT_ORIGIN

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

DistroAgentsDispatcher(){
	local MDSC_CMD='DistroAgentsDispatcher'
	## F1.4, first stage: an operation that came here under a new name goes on under its old one (sh-lib/harness/AgentsContext.FrontForward.include).
	type AgentsToolsFrontKnows > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontForward.include"
	if AgentsToolsFrontKnows DistroAgentsDispatcher "$@" ; then
		AgentsToolsFrontForward DistroAgentsDispatcher "$@"
		return $?
	fi
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
			AgentsToolsScheduleOverride "$overrideOp" "$@"
			return $?
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

case "$0" in
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
