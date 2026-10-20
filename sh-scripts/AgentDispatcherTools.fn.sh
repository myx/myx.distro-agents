#!/usr/bin/env bash

##
## AgentDispatcherTools.fn.sh -- the coordinator's role surface (F7.9): one tool for magic-coordinator over the tasks, the spawns, the worktime flags, the standing
## directives, and the contacts with their access level and coordinates. A role surface, not a merge: it OWNS NO STATE and every operation delegates to the subject
## that owns the answer (DistroAgentsDispatcher.fn.sh, DistroAgentsContacts.fn.sh, the board, the coordinator's inbox). It declares no store; the one standing
## order of the human-owner it writes goes into the heartbeat-state-note, through that note's lock. Functions: sh-lib/session/AgentsTools.CoordinatorSurface.include.
##   --tasks, --spawns, --flags, --contacts, --contact       the views
##   --standing-directives                                  the warnings, the coordinator notes and the orders in force, together
##   --directive-set, --directive-end                       an order of the human-owner entered, and taken out
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

AgentDispatcherTools(){
	local MDSC_CMD='AgentDispatcherTools'
	## The common option set (F2.2): a run of --team-member, --session-id, --spawn-id, --select-workspace and --tooling-origin after the operation is taken here,
	## and the call is made again under what they resolve (sh-lib/common/AgentsTools.CommonOptions.include).
	case "${agentsCommonFronted:-}:${2:-}" in
		:--team-member|:--session-id|:--spawn-id|:--select-workspace|:--tooling-origin)
			local commonRc=0
			type AgentsToolsCommonRun > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.CommonOptions.include"
			AgentsToolsCommonRun AgentDispatcherTools AgentDispatcherTools.fn.sh "$@" || commonRc=$?
			return "$commonRc"
		;;
	esac
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.UseAgentsTools.include"
	type AgentsToolsSurfaceStanding > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.CoordinatorSurface.include"
	case "$1" in

		## [--active|--waiting|--all]: the runs, the Dispatcher's rows.
		--spawns)
			AgentsToolsSurfaceCaller "$1" read || return 1
			AgentsToolsSurfaceSpawns "$@"
			return $?
		;;

		## The worktime flags now, the Dispatcher's lines.
		--flags)
			AgentsToolsSurfaceCaller "$1" read || return 1
			AgentsToolsSurfaceFlags "$@"
			return $?
		;;

		## The board as the heartbeat reads it: the counts of each state and the active items.
		--tasks)
			AgentsToolsSurfaceCaller "$1" read || return 1
			AgentsToolsSurfaceTasks "$@"
			return $?
		;;

		## [--organisation <slug>] [--reached-by <member>]: the contacts, Contacts' rows; --contact <id>: one, its record and its access.
		--contacts|--contact)
			AgentsToolsSurfaceCaller "$1" read || return 1
			AgentsToolsSurfaceContacts "$@"
			return $?
		;;

		## [--all]: the standing directives in force: open warnings, coordinator notes, the human-owner's orders.
		--standing-directives)
			AgentsToolsSurfaceCaller "$1" read || return 1
			AgentsToolsSurfaceStanding "$@"
			return $?
		;;

		## --text <text> --expires-at "<YYYY-MM-DD HH:MM>"|none [--id <id>] [--wait <seconds>]: an order entered, through the state note's lock.
		--directive-set)
			AgentsToolsSurfaceDirectiveSet "$@"
			return $?
		;;

		## --id <id> [--wait <seconds>]: an order taken out.
		--directive-end)
			AgentsToolsSurfaceDirectiveEnd "$@"
			return $?
		;;

		*)
			echo "$MDSC_CMD: ⛔ ERROR: invalid option: ${1:-}" >&2
			set +e ; return 1
		;;
	esac
}

case "$0" in
	*/myx/myx.distro-agents/sh-scripts/AgentDispatcherTools.fn.sh)

		set -e

		if [ -z "$MDLT_ORIGIN" ] || ! type DistroAgentsContext >/dev/null 2>&1 ; then
			. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib/harness/AgentsContext.include"
		fi
		DistroAgentsContext --run-from-detect
		DistroAgentsContext --distro-path-auto

		## Copied from DistroAgentsTools.fn.sh: the tools this one calls find myx.common by it.
		if   [ -d "${MYXROOT:-}" ] && [ -f "$MYXROOT/bin/lib/catMarkdown.Common" ]; then
			export MYXROOT
		elif   [ -f "$MDLT_ORIGIN/myx/myx.common/os-myx.common/host/tarball/share/myx.common/bin/lib/catMarkdown.Common" ]; then
			export MYXROOT="$MDLT_ORIGIN/myx/myx.common/os-myx.common/host/tarball/share/myx.common"
		elif [ -f "/usr/local/share/myx.common/bin/lib/catMarkdown.Common" ]; then
			export MYXROOT="/usr/local/share/myx.common"
		elif command -v myx.common 2>/dev/null && myx.common which lib/catMarkdown 2>/dev/null ; then
			export MYXROOT="$( myx.common which lib/catMarkdown )"
			export MYXROOT="${MYXROOT%/bin/lib/catMarkdown*}"
		else
			export MYXROOT=''
		fi

		AgentDispatcherTools "$@"
	;;
	*)
		## Executed by an unrecognised path: error. Sourced ($0 differs from BASH_SOURCE[0]): stay silent.
		if [ "${BASH_SOURCE[0]:-}" = "$0" ] ; then
			echo "⛔ ERROR: AgentDispatcherTools.fn.sh: executed as '$0', which this file's own dispatch does not match, so nothing ran. Invoke it by a path ending in /myx/myx.distro-agents/sh-scripts/AgentDispatcherTools.fn.sh." >&2
			exit 1
		fi
	;;
esac
