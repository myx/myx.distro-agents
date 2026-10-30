#!/usr/bin/env bash

##
## DistroAgentsKnowledge.fn.sh -- TeamKnowledge (F7.3): the query over what the team has written. A subsystem interface: results are read from it, by agent
## tools, the shell console and shell automation alike. A call is a selector of projects (the ListDistroProjects one, none: every project of the workspace),
## the sources added (--add-source-docs, --add-board-items, --add-vault-items, --add-inbox-items) and a query that starts with AND (--query-keyword,
## --query-pattern, --query-glob, and --query-open-and/--query-open-or ... --query-close for a group); its result is the text snippets that answer, each
## with its source: markdown, merged by the one nesting engine (--intern-merge-md-files), or under `--mdat-output-format json` before the first word, JSON.
## The three stores of the team, a project's, the workspace's and the team's own, are read as sources of one query. A LanceDB store beside each MAGIC.md
## (MAGIC.LanceDB, F8.2) is searched with the text, the store off, uninstalled or absent meaning the text alone. The functions are in
## sh-lib/team-data/AgentsTools.Knowledge.include.
##
## From DistroAgentsTools.fn.sh (F1.4): the names in sh-lib/harness/AgentsContext.FrontTable.include that name this file.
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

## The operations that came here from DistroAgentsTools.fn.sh (F1.4): every one of them is asked what each name of the table is asked, in AgentsContext.FrontDoor.include.
DistroAgentsKnowledgeMoved(){
	local MDSC_CMD='DistroAgentsKnowledge' frontDone="" frontRc=0
	type AgentsToolsFrontKnows > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontTable.include"
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontDoor.include"
	[ -z "$frontDone" ] || return "$frontRc"
	case "$1" in

		--get-path-history)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.MemberRepoHistory.include"
			return $?
		;;

		--get-place-path|--list-namespaces|--list-places)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.InternDirectory.include"
			return $?
		;;

		--get-roster)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicTeamRoster.include"
			return $?
		;;

		## The models the local server has installed: the local leg's own read, passed through with its rc.
		--local-models-list)
			if [ $# -ne 1 ] ; then
				echo "$MDSC_CMD: ⛔ ERROR: --local-models-list takes no arguments" >&2
				set +e ; return 1
			fi
			"$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsLocalHarness.sh" --list-models
			return $?
		;;

		--member-help)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.Member.include"
			return $?
		;;

		*)
			echo "$MDSC_CMD: ⛔ ERROR: invalid option: $1" >&2
			set +e ; return 1
		;;
	esac
}

DistroAgentsKnowledge(){
	local MDSC_CMD='DistroAgentsKnowledge'
	## F1.4: a name that came here from DistroAgentsTools.fn.sh runs its operation in the function below.
	type AgentsToolsFrontKnows > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontTable.include"
	if AgentsToolsFrontKnows DistroAgentsKnowledge "$@" ; then
		DistroAgentsKnowledgeMoved "$@"
		return $?
	fi
	## The three help forms, as DistroAgentsTools.fn.sh has them: no word the query's own syntax (the entry points a
	## reader starts from), --help-syntax the syntax line of every operation of this file, --help the manual.
	case "${1:-}" in
		''|--help|--help-syntax)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/help/Help.DistroAgentsKnowledge.include"
			return $?
		;;
	esac
	## The output format, before the first word: kept in a variable of the shell, since the common options below make the call again without it.
	[ -n "${agentsCommonFronted:-}" ] || agentsKnowledgeFormat=md
	if [ "${1:-}" = "--mdat-output-format" ] ; then
		case "${2:-}" in
			json) agentsKnowledgeFormat=json ; shift 2 ;;
			*) echo "⛔ ERROR: $MDSC_CMD: --mdat-output-format takes json, got: ${2:-<none>}" >&2 ; set +e ; return 1 ;;
		esac
	fi
	## The common option set (F2.2): a run of --team-member, --session-id, --spawn-id, --select-workspace and --tooling-origin after the first word is taken here,
	## and the call is made again under what they resolve (sh-lib/common/AgentsTools.CommonOptions.include).
	case "${agentsCommonFronted:-}:${2:-}" in
		:--team-member|:--session-id|:--spawn-id|:--select-workspace|:--tooling-origin)
			local commonRc=0
			type AgentsToolsCommonRun > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.CommonOptions.include"
			AgentsToolsCommonRun DistroAgentsKnowledge DistroAgentsKnowledge.fn.sh "$@" || commonRc=$?
			return "$commonRc"
		;;
	esac
	## The data root, the skillset root and the bare-name gate, as every operation of the tooling settles them.
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.UseAgentsTools.include"
	type AgentsToolsKnowledgeRun > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.Knowledge.include"
	AgentsToolsKnowledgeRun "${agentsKnowledgeFormat:-md}" "$@"
	return $?
}

case "$0" in
	*/myx/myx.distro-agents/sh-scripts/DistroAgentsKnowledge.fn.sh)

		set -e

		if [ -z "$MDLT_ORIGIN" ] || ! type DistroAgentsContext >/dev/null 2>&1 ; then
			. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib/harness/AgentsContext.include"
		fi
		DistroAgentsContext --run-from-detect
		DistroAgentsContext --distro-path-auto


		DistroAgentsKnowledge "$@"
	;;
	*)
		## Executed by an unrecognised path: error. Sourced ($0 differs from BASH_SOURCE[0]): stay silent.
		if [ "${BASH_SOURCE[0]:-}" = "$0" ] ; then
			echo "⛔ ERROR: DistroAgentsKnowledge.fn.sh: executed as '$0', which this file's own dispatch does not match, so nothing ran. Invoke it by a path ending in /myx/myx.distro-agents/sh-scripts/DistroAgentsKnowledge.fn.sh." >&2
			exit 1
		fi
	;;
esac
