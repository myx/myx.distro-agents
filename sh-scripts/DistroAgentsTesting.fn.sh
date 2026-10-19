#!/usr/bin/env bash

##
## DistroAgentsTesting.fn.sh -- the testing, running and bookkeeping operations (F7.6), for
## magic-tester, console human users and the console app. A subsystem interface: results are
## read from it. First slice: --skillset-validate-routine, a thin stub of the one validator,
## --intern-doc-validate, with no logic of its own.
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

DistroAgentsTesting(){
	local MDSC_CMD='DistroAgentsTesting'
	case "$1" in

		## Checks a routine file's frontmatter and required headers, and reports what is missing or
		## wrong, a row each; exit non-zero where any. <routine-file|--from-stdin>. Read-only.
		--skillset-validate-routine)
			shift
			if [ -z "${1:-}" ] || [ $# -gt 1 ] ; then
				echo "$MDSC_CMD: ⛔ ERROR: --skillset-validate-routine: syntax is <routine-file|--from-stdin>" >&2
				set +e ; return 1
			fi
			"$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-doc-validate routine "$1"
			return $?
		;;

		*)
			echo "$MDSC_CMD: ⛔ ERROR: invalid option: $1" >&2
			set +e ; return 1
		;;
	esac
}

case "$0" in
	*/myx/myx.distro-agents/sh-scripts/DistroAgentsTesting.fn.sh)

		set -e

		if [ -z "$MDLT_ORIGIN" ] || ! type DistroAgentsContext >/dev/null 2>&1 ; then
			. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib/harness/AgentsContext.include"
		fi
		DistroAgentsContext --run-from-detect
		DistroAgentsContext --distro-path-auto

		DistroAgentsTesting "$@"
	;;
	*)
		## Executed by an unrecognised path: error. Sourced ($0 differs from BASH_SOURCE[0]): stay silent.
		if [ "${BASH_SOURCE[0]:-}" = "$0" ] ; then
			echo "⛔ ERROR: DistroAgentsTesting.fn.sh: executed as '$0', which this file's own dispatch does not match, so nothing ran. Invoke it by a path ending in /myx/myx.distro-agents/sh-scripts/DistroAgentsTesting.fn.sh, or source it." >&2
			exit 1
		fi
	;;
esac
