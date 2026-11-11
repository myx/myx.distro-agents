#!/usr/bin/env bash

##
## AgentMonitoringTools.fn.sh -- any member's personal tool for monitoring (epic S14): the health reading of the workspace the member works
## in, the same reading DistroAgentsMonitoring.fn.sh gives an operator or a supervisor. So far: --health [--workspace <path>], one line an
## asset, as sh-lib/monitoring/AgentsTools.Monitoring.include describes it. Read only: nothing here changes a flag or starts anyone.
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

AgentMonitoringTools(){
	local MDSC_CMD='AgentMonitoringTools' frontDone="" frontRc=0
	## The family's context, here and in this file's arm, for a console that calls this function.
	if [ -z "$MDLT_ORIGIN" ] || ! type DistroAgentsContext >/dev/null 2>&1 ; then
		. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib/harness/AgentsContext.include"
		DistroAgentsContext --run-from-detect
		DistroAgentsContext --distro-path-auto
	fi
	## The common option set (F2.2): a run of --team-member, --session-id, --spawn-id, --select-workspace and --tooling-origin after the operation is taken here,
	## and the call is made again under what they resolve (sh-lib/common/AgentsTools.CommonOptions.include).
	## The front door every operation of this file passes, as the DistroAgents* tools pass it: the common options after the name taken, and the member
	## from the environment placed first for a member-first operation where no --team-member is given.
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontDoor.include"
	[ -z "$frontDone" ] || return "$frontRc"
	case "$1" in

		''|--help|--help-syntax)
			set +e
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/help/Help.AgentMonitoringTools.include"
			return $?
		;;

		## THE HEALTH READING of the workspace the member works in, or of the one named: one line an asset, `health <workspace> <asset>
		## <state> <detail>`, an `alarm` line after a dead daemon or an outbox backlog, `muted` while the planned-maintenance flag holds.
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

## A relative or symlinked path to this very file dispatches too: it is resolved to the real file before the match, and only a path that
## resolves elsewhere is refused. Sourced ($0 differs from BASH_SOURCE[0]), nothing is resolved.
selfPath="$0"
case "$0" in
	*/myx/myx.distro-agents/sh-scripts/*.fn.sh) ;;
	*) [ "${BASH_SOURCE[0]:-}" != "$0" ] || selfPath="$( cd "$( dirname "$0" )" 2> /dev/null && pwd -P )/${0##*/}" ;;
esac
case "$selfPath" in
	*/myx/myx.distro-agents/sh-scripts/AgentMonitoringTools.fn.sh)

		set -e

		if [ -z "$MDLT_ORIGIN" ] || ! type DistroAgentsContext >/dev/null 2>&1 ; then
			. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib/harness/AgentsContext.include"
		fi
		DistroAgentsContext --run-from-detect
		DistroAgentsContext --distro-path-auto

		AgentMonitoringTools "$@"
	;;
	*)
		## Executed by an unrecognised path: error. Sourced ($0 differs from BASH_SOURCE[0]): stay silent.
		if [ "${BASH_SOURCE[0]:-}" = "$0" ] ; then
			echo "⛔ ERROR: AgentMonitoringTools.fn.sh: executed as '$0', which this file's own dispatch does not match, so nothing ran. Invoke it by a path ending in /myx/myx.distro-agents/sh-scripts/AgentMonitoringTools.fn.sh, or source it." >&2
			exit 1
		fi
	;;
esac
