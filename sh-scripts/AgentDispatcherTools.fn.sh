#!/usr/bin/env bash

##
## AgentDispatcherTools.fn.sh -- the coordinator's role surface (F7.9): one tool for magic-coordinator over the tasks, the spawns, the worktime flags, the standing
## directives, and the contacts with their access level and coordinates. A role surface, not a merge: it OWNS NO STATE and every operation delegates to the subject
## that owns the answer (DistroAgentsDispatcher.fn.sh, DistroAgentsContacts.fn.sh, the board, the coordinator's inbox). It declares no store; the one standing
## order of the human-owner it writes goes into the state-note, through that note's lock. Functions: sh-lib/session/AgentsTools.CoordinatorSurface.include.
##   --tasks, --spawns, --flags, --contacts, --contact       the views
##   --standing-directives, --directive-set, --directive-end  stubs of DistroAgentsSession.fn.sh (ThisSession), which owns them
##
## From DistroAgentsTools.fn.sh (F1.4): the names routed here are in sh-lib/harness/AgentsContext.FrontTable.include.
##
## NOTE:
## Designed to be able to run without distro context. Starts console sessions.
##

if [ -z "$MMDAPP" ] ; then
	set -e
	export MMDAPP="$( ( cd "$( dirname "$0" )/../../../.." && pwd ) )"
	## Derived from the place of this file, not given: --spawn-run then needs a workspace by --select-workspace (AgentsTools.CoordinatorSpawn.include).
	export MDAT_MMDAPP_IMPLIED=1
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

## The operations that came here from DistroAgentsTools.fn.sh (F1.4): every one of them is asked what each name of the table is asked, in AgentsContext.FrontDoor.include.
AgentDispatcherToolsMoved(){
	local MDSC_CMD='AgentDispatcherTools' frontDone="" frontRc=0
	type AgentsToolsFrontKnows > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontTable.include"
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontDoor.include"
	[ -z "$frontDone" ] || return "$frontRc"
	case "$1" in

		--advance-sleep-run)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicAdvance.include"
			return $?
		;;

		--client-operation-run)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicClient.include"
			return $?
		;;

		--config-check|--state-note-lock-acquire|--state-note-read)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicCoordinatorState.include"
			return $?
		;;

		--daily-lock-refresh)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicDaily.include"
			return $?
		;;

		--grooming-lock-refresh)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicGrooming.include"
			return $?
		;;

		--retro-lock-refresh)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicRetro.include"
			return $?
		;;

		--roster-upsert)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicTeamRoster.include"
			return $?
		;;

		## One session spawned, through DistroAgentsDispatcher --spawn-session; a root-harness session names its place (gate in AgentDispatcherTools below).
		--spawn-run)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.CoordinatorSpawn.include"
			AgentsToolsCoordinatorSpawn "$@"
			return $?
		;;

		--sweep-state-advance|--sweep-state-read|--sweep-state-upsert)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicSweep.include"
			return $?
		;;

		*)
			echo "$MDSC_CMD: ⛔ ERROR: invalid option: $1" >&2
			set +e ; return 1
		;;
	esac
}

AgentDispatcherTools(){
	local MDSC_CMD='AgentDispatcherTools'
	## F1.4: a name that came here from DistroAgentsTools.fn.sh runs its operation in the function below.
	type AgentsToolsFrontKnows > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontTable.include"
	## A root-harness session names the place of a spawn (epic S18.3), asked before the common options take --select-workspace out and run the call again in it.
	if [ "${1:-}" = "--spawn-run" ] && [ -z "${agentsCommonFronted:-}" ] ; then
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.CoordinatorSpawn.include"
		AgentsToolsCoordinatorSpawnGate "$@" || { set +e ; return 1 ; }
	fi
	if AgentsToolsFrontKnows AgentDispatcherTools "$@" ; then
		AgentDispatcherToolsMoved "$@"
		return $?
	fi
	## The three help forms, as DistroAgentsTools.fn.sh has them: no word the default syntax (the entry points a reader
	## starts from), --help-syntax the syntax line of every operation of this file, --help the manual.
	case "${1:-}" in
		''|--help|--help-syntax)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/help/Help.AgentDispatcherTools.include"
			return $?
		;;
	esac
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

		## The board as the coordinator reads it: the counts of each state and the active items.
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

		## The standing directives: stubs of the ThisSession tool, which owns them.
		--standing-directives|--directive-set|--directive-end)
			bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsSession.fn.sh" "$@"
			return $?
		;;

		## The epic file's own edit (W1): --set-status and --add-settled, so no routine edits an epic by hand.
		--epic-update)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicEpic.include"
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
