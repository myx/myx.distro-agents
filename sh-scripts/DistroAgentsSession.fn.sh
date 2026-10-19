#!/usr/bin/env bash

##
## DistroAgentsSession.fn.sh -- ThisSession (F7.2): what a running session asks of its own session.
## A subsystem interface: results are read from it. So far: --get-routine-text, --routine-run-inline and --update-routine-state.
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

## The tools a ThisSession operation calls into: the common library the team data's writers sync with, found as
## DistroAgentsTools.fn.sh finds it, and DistroAgentsTools itself.
DistroAgentsSessionTools(){
	## The common library the team data's writers sync with, found as DistroAgentsTools.fn.sh finds it.
	if [ -n "${MYXROOT:-}" ] && [ -d "$MYXROOT" ] && [ -f "$MYXROOT/bin/lib/catMarkdown.Common" ] ; then
		export MYXROOT
	elif [ -f "$MDLT_ORIGIN/myx/myx.common/os-myx.common/host/tarball/share/myx.common/bin/lib/catMarkdown.Common" ] ; then
		export MYXROOT="$MDLT_ORIGIN/myx/myx.common/os-myx.common/host/tarball/share/myx.common"
	elif [ -f "/usr/local/share/myx.common/bin/lib/catMarkdown.Common" ] ; then
		export MYXROOT="/usr/local/share/myx.common"
	elif command -v myx.common > /dev/null 2>&1 && [ -n "$( myx.common which lib/catMarkdown 2> /dev/null )" ] ; then
		export MYXROOT="$( myx.common which lib/catMarkdown )"
		export MYXROOT="${MYXROOT%/bin/lib/catMarkdown*}"
	else
		export MYXROOT=''
	fi
	type DistroAgentsTools > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
}

DistroAgentsSession(){
	local MDSC_CMD='DistroAgentsSession'
	## The skillset root, as every operation of the tooling settles it (AgentsContext.UseAgentsTools.include).
	if [ -z "${MDAT_SKILLSET_ROOT:-}" ] ; then
		MDAT_SKILLSET_ROOT="$MMDAPP/.local/agents/members"
		export MDAT_SKILLSET_ROOT
	fi
	case "$1" in

		## The text of a routine as its run reads it: the routine's file with the routine of its
		## kind mixed in by the tooling (AgentsToolsSpawnRoutineMixText), Opening steps, Steps and
		## Closure steps in the order the kind sets. The selector is a routine's file name or part
		## of one, exactly one file, as --routine takes it.
		--get-routine-text)
			if [ -z "${2:-}" ] || [ $# -gt 2 ] ; then
				echo "$MDSC_CMD: ⛔ ERROR: --get-routine-text: syntax is <routine-selector>" >&2
				set +e ; return 1
			fi
			type AgentsToolsSpawnRoutineMixText > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SpawnRoutine.include"
			local routineTextFile
			routineTextFile="$( AgentsToolsSpawnRoutineResolve "$2" )" || { set +e ; return 1 ; }
			AgentsToolsSpawnRoutineMixText "$routineTextFile"
			return $?
		;;

		## A routine run inline in this session (F6.6), like a call: the routine's steps without its frontmatter and its Maintainer
		## Notes, the Opening and Closure steps of `magic-team.inline.routine` in place of its session kind's, and the result of the
		## routine's own input scan, run now through the spawner's runner and presented as the spawner presents it.
		--routine-run-inline)
			if [ -z "${2:-}" ] || [ $# -gt 2 ] ; then
				echo "$MDSC_CMD: ⛔ ERROR: --routine-run-inline: syntax is <routine-selector>" >&2
				set +e ; return 1
			fi
			DistroAgentsSessionTools
			type AgentsToolsRoutineRunInline > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.RoutineRunInline.include"
			AgentsToolsRoutineRunInline "$2"
			return $?
		;;

		## The update of the locked document of the session's routine (F6.2): one general operation. The session knows its
		## routine and the document the spawner locked for it, so the call names neither; any participant of a locked session
		## may make it. The lock-owned fields stay as the spawner set them, and each update is committed, and pushed where a
		## remote is set, before it returns: [--document <note>] [--header:upsert:<name>:<value>]... [--header:remove:<name>]...
		## [--from-file <path>|--edit-patch-from-stdin], else the whole record on standard input.
		--update-routine-state)
			shift
			DistroAgentsSessionTools
			DistroAgentsTools --intern-op-update-routine-state "$@"
			return $?
		;;

		*)
			echo "$MDSC_CMD: ⛔ ERROR: invalid option: $1" >&2
			set +e ; return 1
		;;
	esac
}

case "$0" in
	*/myx/myx.distro-agents/sh-scripts/DistroAgentsSession.fn.sh)

		set -e

		if [ -z "$MDLT_ORIGIN" ] || ! type DistroAgentsContext >/dev/null 2>&1 ; then
			. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib/harness/AgentsContext.include"
		fi
		DistroAgentsContext --run-from-detect
		DistroAgentsContext --distro-path-auto

		DistroAgentsSession "$@"
	;;
	*)
		## Executed by an unrecognised path: error. Sourced ($0 differs from BASH_SOURCE[0]): stay silent.
		if [ "${BASH_SOURCE[0]:-}" = "$0" ] ; then
			echo "⛔ ERROR: DistroAgentsSession.fn.sh: executed as '$0', which this file's own dispatch does not match, so nothing ran. Invoke it by a path ending in /myx/myx.distro-agents/sh-scripts/DistroAgentsSession.fn.sh, or source it." >&2
			exit 1
		fi
	;;
esac
