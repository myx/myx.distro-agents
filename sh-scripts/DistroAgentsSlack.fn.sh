#!/usr/bin/env bash

##
## DistroAgentsSlack.fn.sh -- the team's Slack operations (F1.4 of the refactorings epic). A subsystem interface: results are read from it, by agent tools,
## the shell console and shell automation alike. Its operations: reading, sending, reacting, files, profile, presence and the socket. They are the lines of
## sh-lib/harness/AgentsContext.FrontTable.include that name this file, and a bare call or --help lists them.
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

DistroAgentsSlack(){
	local MDSC_CMD='DistroAgentsSlack' frontDone="" frontRc=0
	type AgentsToolsFrontKnows > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontTable.include"
	case "${1:-}" in
		'')
			type AgentsToolsFrontHelp > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontTable.Help.include"
			AgentsToolsFrontHelp DistroAgentsSlack "the team's Slack operations" >&2
			set +e ; return 1
		;;
		--help)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/help/Help.DistroAgentsSlack.include"
			return 0
		;;
	esac
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontDoor.include"
	[ -z "$frontDone" ] || return "$frontRc"
	case "$1" in

		--slack-conversations-roster|--slack-resolve-ids)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicComms.include"
			return $?
		;;

		--slack-delete-message|--slack-edit-message|--slack-file-fetch|--slack-file-info|--slack-file-share|--slack-presence-keep|--slack-presence-status|--slack-presence-stop|--slack-profile-get|--slack-profile-set|--slack-react|--slack-read|--slack-search-messages|--slack-send-message|--slack-socket-start|--slack-socket-status|--slack-socket-stop)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.MemberCommsSlack.include"
			return $?
		;;

		*)
			echo "$MDSC_CMD: ⛔ ERROR: invalid option: $1" >&2
			set +e ; return 1
		;;
	esac
}

case "$0" in
	*/myx/myx.distro-agents/sh-scripts/DistroAgentsSlack.fn.sh)

		set -e

		if [ -z "$MDLT_ORIGIN" ] || ! type DistroAgentsContext >/dev/null 2>&1 ; then
			. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib/harness/AgentsContext.include"
		fi
		DistroAgentsContext --run-from-detect
		DistroAgentsContext --distro-path-auto


		DistroAgentsSlack "$@"
	;;
	*)
		## Executed by an unrecognised path: error. Sourced ($0 differs from BASH_SOURCE[0]): stay silent.
		if [ "${BASH_SOURCE[0]:-}" = "$0" ] ; then
			echo "⛔ ERROR: DistroAgentsSlack.fn.sh: executed as '$0', which this file's own dispatch does not match, so nothing ran. Invoke it by a path ending in /myx/myx.distro-agents/sh-scripts/DistroAgentsSlack.fn.sh." >&2
			exit 1
		fi
	;;
esac
