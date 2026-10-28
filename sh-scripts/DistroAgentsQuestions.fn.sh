#!/usr/bin/env bash

##
## DistroAgentsQuestions.fn.sh -- every ask of the team (F1.4 of the refactorings epic).
## A subsystem interface: results are read from it by agent tools, the shell console and shell automation alike.
## Its operations: the escalations (questions, readbacks, permission requests, decisions) and the replies pending to them.
## They are the names of the front table, sh-lib/harness/AgentsContext.FrontTable.include, that name this file; a bare call or --help lists them.
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

DistroAgentsQuestions(){
	local MDSC_CMD='DistroAgentsQuestions' frontDone="" frontRc=0
	type AgentsToolsFrontKnows > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontTable.include"
	case "${1:-}" in
		'')
			AgentsToolsFrontHelp DistroAgentsQuestions "every ask of the team" >&2
			set +e ; return 1
		;;
		--help)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/help/Help.DistroAgentsQuestions.include"
			return 0
		;;
	esac
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontDoor.include"
	[ -z "$frontDone" ] || return "$frontRc"
	case "$1" in

		--amend-pending-reply|--read-pending-reply)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/questions/AgentsTools.MemberPendingReply.include"
			return $?
		;;

		## Stubs: the operations that moved to another tool file. The call goes on there, and the place is said.
		--settle-pending-reply)
			echo "$MDSC_CMD: $1 moved to DistroAgentsSession.fn.sh $1 -- this name still works" >&2
			DistroAgentsSession "$@"
			return $?
		;;

		--answer-escalation|--forward-escalation|--read-escalation|--readback-escalation)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/questions/AgentsTools.MemberEscalation.include"
			return $?
		;;

		--record-decision)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.InternOpDecisions.include"
			return $?
		;;

		--request-permission-set)
			echo "$MDSC_CMD: $1 moved to AgentDispatcherTools.fn.sh $1 -- this name still works" >&2
			AgentDispatcherTools "$@"
			return $?
		;;

		*)
			echo "$MDSC_CMD: ⛔ ERROR: invalid option: $1" >&2
			set +e ; return 1
		;;
	esac
}

case "$0" in
	*/myx/myx.distro-agents/sh-scripts/DistroAgentsQuestions.fn.sh)

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

		DistroAgentsQuestions "$@"
	;;
	*)
		## Executed by an unrecognised path: error. Sourced ($0 differs from BASH_SOURCE[0]): stay silent.
		if [ "${BASH_SOURCE[0]:-}" = "$0" ] ; then
			echo "⛔ ERROR: DistroAgentsQuestions.fn.sh: executed as '$0', which this file's own dispatch does not match, so nothing ran. Invoke it by a path ending in /myx/myx.distro-agents/sh-scripts/DistroAgentsQuestions.fn.sh." >&2
			exit 1
		fi
	;;
esac
