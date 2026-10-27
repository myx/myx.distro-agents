#!/usr/bin/env bash

##
## DistroAgentsItems.fn.sh -- the items of the team's stores: board, inbox, audit and vault (F1.4 of the refactorings epic).
## A subsystem interface: results are read from it by agent tools, the shell console and shell automation alike.
## Its operations: the board items and their states, the review of a dispatched item, the inbox notes, reflections and inquiries, and the audit and vault items.
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

DistroAgentsItems(){
	local MDSC_CMD='DistroAgentsItems' frontDone="" frontRc=0
	type AgentsToolsFrontKnows > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontTable.include"
	case "${1:-}" in
		'')
			AgentsToolsFrontHelp DistroAgentsItems "the items of the team's stores: board, inbox, audit and vault" >&2
			set +e ; return 1
		;;
		--help)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/help/Help.DistroAgentsItems.include"
			return 0
		;;
	esac
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontDoor.include"
	[ -z "$frontDone" ] || return "$frontRc"
	case "$1" in

		--accept-review|--follow-up-review|--reject-review|--request-review|--return-review)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.InternOpReview.include"
			return $?
		;;

		--advance-batch-outcome|--advance-to-parked|--advance-to-running)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicAdvance.include"
			return $?
		;;

		--commit-pending)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicTeamData.include"
			return $?
		;;

		## The coordinator repairs the team-data checkout that diverged from origin:
		## <member> [--keep-merged|--take-remote]. The full repair: it trial-merges, applies
		## the mode, moves the flat inbox items by their processed stamp and pushes. Sourced,
		## it runs on this arm's own words.
		--repair-team-data-checkout)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicTeamDataCheckoutRepair.include"
			return $?
		;;

		--create-running|--move-to-backlog|--move-to-blocked|--move-to-parked|--move-to-pending|--move-to-processed)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicBoard.include"
			return $?
		;;

		--get-audit-item|--get-board-item|--get-inbox-item|--get-vault-item|--mark-inbox-processed|--trash-inbox-item|--upsert-inbox-inquiry|--upsert-inbox-note|--upsert-inbox-reflection)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.Member.include"
			return $?
		;;

		--grooming-create-backlog|--grooming-create-blocked|--grooming-create-pending|--grooming-create-processed|--grooming-create-running|--grooming-to-archived|--grooming-to-backlog|--grooming-to-blocked|--grooming-to-parked|--grooming-to-pending|--grooming-to-processed|--grooming-to-retained|--grooming-to-running)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicGrooming.include"
			return $?
		;;

		*)
			echo "$MDSC_CMD: ⛔ ERROR: invalid option: $1" >&2
			set +e ; return 1
		;;
	esac
}

case "$0" in
	*/myx/myx.distro-agents/sh-scripts/DistroAgentsItems.fn.sh)

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

		DistroAgentsItems "$@"
	;;
	*)
		## Executed by an unrecognised path: error. Sourced ($0 differs from BASH_SOURCE[0]): stay silent.
		if [ "${BASH_SOURCE[0]:-}" = "$0" ] ; then
			echo "⛔ ERROR: DistroAgentsItems.fn.sh: executed as '$0', which this file's own dispatch does not match, so nothing ran. Invoke it by a path ending in /myx/myx.distro-agents/sh-scripts/DistroAgentsItems.fn.sh." >&2
			exit 1
		fi
	;;
esac
