#!/usr/bin/env bash

##
## DistroAgentsMonitoring.fn.sh -- the monitoring of a workspace (epic S14, monitoring for magic-devops): the health reading over the
## assets S14 names, as pure tooling a human operator or a supervisor reads without a member in the loop. A subsystem interface: results
## are read from it, by agent tools, the shell console and shell automation alike. The functions are in sh-lib/monitoring/AgentsTools.Monitoring.include.
## A member's own tool for the same reading is AgentMonitoringTools.fn.sh.
##
## From DistroAgentsTools.fn.sh (F1.4): the names in sh-lib/harness/AgentsContext.FrontTable.include that name this file.
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

## The operations that came here from DistroAgentsTools.fn.sh (F1.4): every one of them is asked what each name of the table is asked, in AgentsContext.FrontDoor.include.
DistroAgentsMonitoringMoved(){
	local MDSC_CMD='DistroAgentsMonitoring' frontDone="" frontRc=0
	type AgentsToolsFrontKnows > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontTable.include"
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontDoor.include"
	[ -z "$frontDone" ] || return "$frontRc"
	case "$1" in

		## THE HEALTH READING of a workspace, this one by default: one line an asset, `health <workspace> <asset> <state> <detail>`, an
		## `alarm` line after a dead daemon or an outbox backlog, `muted` while the planned-maintenance flag holds. A one-off reading, no call path.
		--health)
			shift
			local healthWs="${MMDAPP%/}"
			while [ $# -gt 0 ] ; do
				case "$1" in
					--workspace)
						[ -n "${2:-}" ] || { echo "$MDSC_CMD: ⛔ ERROR: --health: --workspace takes a path" >&2 ; set +e ; return 1 ; }
						healthWs="${2%/}" ; shift 2
					;;
					*) echo "$MDSC_CMD: ⛔ ERROR: --health: unknown option: $1 -- syntax is --health [--workspace <path>]" >&2 ; set +e ; return 1 ;;
				esac
			done
			type AgentsToolsMonitoringHealth > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/monitoring/AgentsTools.Monitoring.include"
			AgentsToolsMonitoringHealth "$healthWs"
			return $?
		;;

		*)
			echo "$MDSC_CMD: ⛔ ERROR: invalid option: $1" >&2
			set +e ; return 1
		;;
	esac
}

DistroAgentsMonitoring(){
	local MDSC_CMD='DistroAgentsMonitoring'
	## The family's context, here and in this file's arm, for a console that calls this function.
	if [ -z "$MDLT_ORIGIN" ] || ! type DistroAgentsContext >/dev/null 2>&1 ; then
		. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib/harness/AgentsContext.include"
		DistroAgentsContext --run-from-detect
		DistroAgentsContext --distro-path-auto
	fi
	## F1.4: a name that came here from DistroAgentsTools.fn.sh runs its operation in the function above.
	type AgentsToolsFrontKnows > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontTable.include"
	if AgentsToolsFrontKnows DistroAgentsMonitoring "$@" ; then
		DistroAgentsMonitoringMoved "$@"
		return $?
	fi
	## The three help forms, as DistroAgentsTools.fn.sh has them: no word the default syntax, --help-syntax the syntax line of every
	## operation of this file, --help the manual.
	case "${1:-}" in
		''|--help|--help-syntax)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/help/Help.DistroAgentsMonitoring.include"
			return $?
		;;
	esac
	## The common option set (F2.2): a run of --team-member, --session-id, --spawn-id, --select-workspace and --tooling-origin after the first word is taken here,
	## and the call is made again under what they resolve (sh-lib/common/AgentsTools.CommonOptions.include).
	case "${agentsCommonFronted:-}:${2:-}" in
		:--team-member|:--session-id|:--spawn-id|:--select-workspace|:--tooling-origin)
			local commonRc=0
			type AgentsToolsCommonRun > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.CommonOptions.include"
			AgentsToolsCommonRun DistroAgentsMonitoring DistroAgentsMonitoring.fn.sh "$@" || commonRc=$?
			return "$commonRc"
		;;
	esac
	echo "$MDSC_CMD: ⛔ ERROR: invalid option: $1" >&2
	set +e ; return 1
}

## A relative or symlinked path to this very file dispatches too: it is resolved to the real file before the match, and only a path that
## resolves elsewhere is refused. Sourced ($0 differs from BASH_SOURCE[0]), nothing is resolved.
selfPath="$0"
case "$0" in
	*/myx/myx.distro-agents/sh-scripts/*.fn.sh) ;;
	*) [ "${BASH_SOURCE[0]:-}" != "$0" ] || selfPath="$( cd "$( dirname "$0" )" 2> /dev/null && pwd -P )/${0##*/}" ;;
esac
case "$selfPath" in
	*/myx/myx.distro-agents/sh-scripts/DistroAgentsMonitoring.fn.sh)

		set -e

		if [ -z "$MDLT_ORIGIN" ] || ! type DistroAgentsContext >/dev/null 2>&1 ; then
			. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib/harness/AgentsContext.include"
		fi
		DistroAgentsContext --run-from-detect
		DistroAgentsContext --distro-path-auto

		DistroAgentsMonitoring "$@"
	;;
	*)
		## Executed by an unrecognised path: error. Sourced ($0 differs from BASH_SOURCE[0]): stay silent.
		if [ "${BASH_SOURCE[0]:-}" = "$0" ] ; then
			echo "⛔ ERROR: DistroAgentsMonitoring.fn.sh: executed as '$0', which this file's own dispatch does not match, so nothing ran. Invoke it by a path ending in /myx/myx.distro-agents/sh-scripts/DistroAgentsMonitoring.fn.sh, or source it." >&2
			exit 1
		fi
	;;
esac
