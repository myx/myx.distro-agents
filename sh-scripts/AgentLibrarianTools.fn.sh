#!/usr/bin/env bash

##
## AgentLibrarianTools.fn.sh -- the librarian's personal tool (F7.7): what magic-librarian takes in as work, and its write of a skillset file. A tool that
## takes work in: nobody reads results from it but the one who asked.
##   --skillset-upsert        the whole text of a .md file of a team member's skill, saved into the skill's source copy (never an install, never
##                            the HOME skills folder) after the resulting version was checked; the librarian only, from a routine whose
##                            allows: names it, and only while learning is on
##   --request-update         any member's request that a document, the knowledge base or a skill file be updated, as a message, a whole text or
##                            a concrete edit: one inquiry into magic-librarian's inbox; --reply asks for a note with the outcome
##   --queue-list --queue-take --queue-done   the librarian's side of those requests, which are the inquiries of its inbox that carry an update-kind;
##                            --queue-done closes one with --apply, --refuse or --result
##   --request-result         where a request stands, for the member that made it
##   --doc-drift [<path>...] [--queue]   detects, by dates and checksums, a package whose code changed after its MAGIC.md, README or
##                            help files; with --queue, files the update request itself into magic-librarian's inbox
##   --queue-ask <name>       the librarian poses a waiting concrete edit to a person in Pending Questions, as well as deciding it itself
## The queue is the librarian's inbox itself; there is no store of its own. The functions are in sh-lib/member/AgentsTools.LibrarianWork.include.
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

AgentLibrarianTools(){
	local MDSC_CMD='AgentLibrarianTools'
	## The common option set (F2.2): a run of --team-member, --session-id, --spawn-id, --select-workspace and --tooling-origin after the operation is taken here,
	## and the call is made again under what they resolve (sh-lib/common/AgentsTools.CommonOptions.include).
	case "${agentsCommonFronted:-}:${2:-}" in
		:--team-member|:--session-id|:--spawn-id|:--select-workspace|:--tooling-origin)
			local commonRc=0
			type AgentsToolsCommonRun > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.CommonOptions.include"
			AgentsToolsCommonRun AgentLibrarianTools AgentLibrarianTools.fn.sh "$@" || commonRc=$?
			return "$commonRc"
		;;
	esac
	type AgentsToolsLibrarianSkillsetUpsert > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.LibrarianWork.include"
	case "$1" in

		''|--help|--help-syntax)
			set +e
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/help/Help.AgentLibrarianTools.include"
			return $?
		;;

		## <team-member> <pathname> (--from-stdin|--from-file <path>): the whole text of a .md file of a member's skill, below the skill's folder.
		--skillset-upsert)
			AgentsToolsLibrarianSkillsetUpsert "$@"
			return $?
		;;

		## --kind document|knowledge|skill --target <path|topic|member:pathname> --why <text>, and one of (--from-stdin|--from-file <path>), or
		## --whole-text with it, or (--old|--old-from-file) and (--new|--new-from-file); --reply asks for the outcome as a note. Prints the name of the request.
		--request-update)
			AgentsToolsLibrarianRequestUpdate "$@"
			return $?
		;;

		## <name>: where one request stands.
		--request-result)
			AgentsToolsLibrarianRequestResult "$@"
			return $?
		;;

		## The requests that wait, a row each.
		--queue-list)
			AgentsToolsLibrarianQueueList "$@"
			return $?
		;;

		## The requests that wait, whole, as one batch. Reads only.
		--queue-take)
			AgentsToolsLibrarianQueueTake "$@"
			return $?
		;;

		## <name> --apply | --refuse <reason> | --result <text>: one request decided and closed.
		--queue-done)
			AgentsToolsLibrarianQueueDone "$@"
			return $?
		;;

		## [<path>...] [--queue]: the tooling detects a package whose code changed after its MAGIC.md, README or help, and, with --queue, queues the update itself.
		--doc-drift)
			AgentsToolsLibrarianDocDrift "$@"
			return $?
		;;

		## <name>: the librarian poses a waiting concrete edit to a person in Pending Questions, as well as deciding it itself.
		--queue-ask)
			AgentsToolsLibrarianQueueAsk "$@"
			return $?
		;;

		*)
			echo "$MDSC_CMD: ⛔ ERROR: invalid option: $1" >&2
			set +e ; return 1
		;;
	esac
}

case "$0" in
	*/myx/myx.distro-agents/sh-scripts/AgentLibrarianTools.fn.sh)

		set -e

		if [ -z "$MDLT_ORIGIN" ] || ! type DistroAgentsContext >/dev/null 2>&1 ; then
			. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib/harness/AgentsContext.include"
		fi
		DistroAgentsContext --run-from-detect
		DistroAgentsContext --distro-path-auto

		## Copied from DistroAgentsTools.fn.sh: the validators call tools that find myx.common by it.
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

		AgentLibrarianTools "$@"
	;;
	*)
		## Executed by an unrecognised path: error. Sourced ($0 differs from BASH_SOURCE[0]): stay silent.
		if [ "${BASH_SOURCE[0]:-}" = "$0" ] ; then
			echo "⛔ ERROR: AgentLibrarianTools.fn.sh: executed as '$0', which this file's own dispatch does not match, so nothing ran. Invoke it by a path ending in /myx/myx.distro-agents/sh-scripts/AgentLibrarianTools.fn.sh, or source it." >&2
			exit 1
		fi
	;;
esac
