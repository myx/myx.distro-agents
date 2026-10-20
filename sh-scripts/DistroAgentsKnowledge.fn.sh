#!/usr/bin/env bash

##
## DistroAgentsKnowledge.fn.sh -- TeamKnowledge (F7.3): the query over what the team has written. A subsystem interface: results are read from it, by agent
## tools, the shell console and shell automation alike. A call is a selector of projects (the ListDistroProjects one, none: every project of the workspace),
## the sources added (--add-source-docs, --add-board-items, --add-vault-items, --add-inbox-items) and a query that starts with AND (--query-keyword,
## --query-pattern, --query-glob, and --query-open-and/--query-open-or ... --query-close for a group); its result is the text snippets that answer, each
## with its source: markdown, merged by the one nesting engine (--intern-merge-md-files), or under `--mdat-output-format json` before the first word, JSON.
## The three stores of the team, a project's, the workspace's and the team's own, are read as sources of one query. No vector store: the query reads the
## texts themselves (F8.2 and F8.3 are of the next epic). The functions are in sh-lib/team-data/AgentsTools.Knowledge.include.
##
## From DistroAgentsTools.fn.sh (F1.4, first stage): --get-path-history, --get-place-path, --get-roster, --list-namespaces, --list-places, --member-help. They go on under their old names (sh-lib/harness/AgentsContext.FrontForward.include).
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

DistroAgentsKnowledge(){
	local MDSC_CMD='DistroAgentsKnowledge'
	## F1.4, first stage: an operation that came here under a new name goes on under its old one (sh-lib/harness/AgentsContext.FrontForward.include).
	type AgentsToolsFrontKnows > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontForward.include"
	if AgentsToolsFrontKnows DistroAgentsKnowledge "$@" ; then
		AgentsToolsFrontForward DistroAgentsKnowledge "$@"
		return $?
	fi
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
	if [ $# -eq 0 ] ; then
		echo "$MDSC_CMD: ⛔ ERROR: syntax is [--mdat-output-format json] [<project selector>] --add-source-docs|--add-board-items|--add-vault-items|--add-inbox-items... --query-keyword|--query-pattern|--query-glob|--query-open-and|--query-open-or|--query-close..." >&2
		set +e ; return 1
	fi
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
