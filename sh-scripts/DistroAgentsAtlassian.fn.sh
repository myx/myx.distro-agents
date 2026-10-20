#!/usr/bin/env bash

##
## DistroAgentsAtlassian.fn.sh -- the team's Jira and Confluence operations (F1.4 of the refactorings epic). A subsystem interface: results are read from it, by agent tools,
## the shell console and shell automation alike. Its operations: boards, sprints, issues, spaces and pages. The names are the table of
## sh-lib/harness/AgentsContext.FrontForward.include, one line each.
## First stage: each operation goes on under the name it had in DistroAgentsTools.fn.sh, with every check and gate it had. The old names are
## deleted, and the operations move into this file, when the stubs leave DistroAgentsTools.fn.sh.
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

DistroAgentsAtlassian(){
	local MDSC_CMD='DistroAgentsAtlassian'
	type AgentsToolsFrontKnows > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontForward.include"
	if AgentsToolsFrontKnows DistroAgentsAtlassian "$@" ; then
		AgentsToolsFrontForward DistroAgentsAtlassian "$@"
		return $?
	fi
	case "${1:-}" in
		'')
			AgentsToolsFrontHelp DistroAgentsAtlassian "the team's Jira and Confluence operations" >&2
			set +e ; return 1
		;;
		--help)
			AgentsToolsFrontHelp DistroAgentsAtlassian "the team's Jira and Confluence operations" >&2
			return 0
		;;
		*)
			echo "$MDSC_CMD: ⛔ ERROR: invalid option: $1" >&2
			set +e ; return 1
		;;
	esac
}

case "$0" in
	*/myx/myx.distro-agents/sh-scripts/DistroAgentsAtlassian.fn.sh)

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

		DistroAgentsAtlassian "$@"
	;;
	*)
		## Executed by an unrecognised path: error. Sourced ($0 differs from BASH_SOURCE[0]): stay silent.
		if [ "${BASH_SOURCE[0]:-}" = "$0" ] ; then
			echo "⛔ ERROR: DistroAgentsAtlassian.fn.sh: executed as '$0', which this file's own dispatch does not match, so nothing ran. Invoke it by a path ending in /myx/myx.distro-agents/sh-scripts/DistroAgentsAtlassian.fn.sh." >&2
			exit 1
		fi
	;;
esac
