#!/usr/bin/env bash

##
## AgentExecutorTools.fn.sh -- the chair of a session: the operations that act on a session as its executor, whoever it is.
## Its operations: --set-session-topic, --set-session-chapter, --get-uninvited-participants and --list-session-runs, which came here
## from DistroAgentsSession.fn.sh and DistroAgentsDispatcher.fn.sh and keep working under their old names as stubs there.
## It owns no store: what it reads and writes is the session store's and the CheckList tool's, through their own readers and writers.
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

## The common library the team data's writers sync with, found as DistroAgentsTools.fn.sh finds it, and DistroAgentsTools itself: the
## announcers of the topic and the chapter reach both, as they did from DistroAgentsSession.fn.sh's own arm.
AgentExecutorToolsCommon(){
	if [ -n "${MYXROOT:-}" ] && [ -d "$MYXROOT" ] && [ -f "$MYXROOT/bin/lib/catMarkdown.Common" ] ; then
		export MYXROOT
	elif command -v myx.common > /dev/null 2>&1 && [ -n "$( myx.common which lib/catMarkdown 2> /dev/null )" ] ; then
		export MYXROOT="$( myx.common which lib/catMarkdown )"
		export MYXROOT="${MYXROOT%/bin/lib/catMarkdown*}"
	else
		export MYXROOT=''
	fi
	type DistroAgentsTools > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
}

AgentExecutorTools(){
	local MDSC_CMD='AgentExecutorTools' frontDone="" frontRc=0
	## The family's context, here and in this file's arm, for a console that calls this function.
	if [ -z "$MDLT_ORIGIN" ] || ! type DistroAgentsContext >/dev/null 2>&1 ; then
		. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib/harness/AgentsContext.include"
		DistroAgentsContext --run-from-detect
		DistroAgentsContext --distro-path-auto
	fi
	## The three help forms, as DistroAgentsTools.fn.sh has them.
	case "${1:-}" in
		''|--help|--help-syntax)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/help/Help.AgentExecutorTools.include"
			return $?
		;;
	esac
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontDoor.include"
	[ -z "$frontDone" ] || return "$frontRc"
	case "$1" in

		## The title of the session, what it is about, and its root post edited to match. Set by the session's executor, and a
		## participant's change escalates to it and up its chain; the person at the console sets it under the authority rule.
		--set-session-topic)
			shift
			AgentExecutorToolsCommon
			type AgentsToolsThisSessionSetTopic > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.ThisSession.include"
			AgentsToolsThisSessionSetTopic "$@"
			return $?
		;;

		## What the session does now, kept in its own store and announced in the thread. The same authority as the topic.
		--set-session-chapter)
			shift
			AgentExecutorToolsCommon
			type AgentsToolsThisSessionSetChapter > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.ThisSession.include"
			AgentsToolsThisSessionSetChapter "$@"
			return $?
		;;

		## The participants the session's record names that have no run in it yet, one a line: the chair's invite list.
		--get-uninvited-participants)
			shift
			type AgentsToolsThisSessionUninvited > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.ThisSession.include"
			AgentsToolsThisSessionUninvited "$@"
			return $?
		;;

		## The runs this session may see, bound to the session of the call: its own runs and sub-sessions, the public coworking
		## sessions of the team, and the caller's own -- never another member's private session, unless the caller is in it.
		--list-session-runs)
			shift
			type AgentsToolsThisSessionRuns > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.ThisSession.include"
			AgentsToolsThisSessionRuns "$@"
			return $?
		;;

		## The chair's read of its own session's queue: one block per participant, its open items, and whether it has a run.
		--executor-queue)
			shift
			type AgentsToolsExecutorQueue > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.ExecutorQueue.include"
			AgentsToolsExecutorQueue "$@"
			return $?
		;;

		## The chair puts work into a participant's queue: pending items at the end of that member's list, marked as the chair's.
		--executor-checklist-append)
			shift
			type AgentsToolsExecutorAppend > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.ExecutorAppend.include"
			AgentsToolsExecutorAppend "$@"
			return $?
		;;

		## Adding work to a stopped session's queue resumes its executor: the session's control thread is started where none lives.
		--executor-resume)
			shift
			type AgentsToolsExecutorResume > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.ExecutorResume.include"
			AgentsToolsExecutorResume "$@"
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
	*/myx/myx.distro-agents/sh-scripts/AgentExecutorTools.fn.sh)

		set -e

		if [ -z "$MDLT_ORIGIN" ] || ! type DistroAgentsContext >/dev/null 2>&1 ; then
			. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib/harness/AgentsContext.include"
		fi
		DistroAgentsContext --run-from-detect
		DistroAgentsContext --distro-path-auto


		AgentExecutorTools "$@"
	;;
	*)
		## Executed by an unrecognised path: error. Sourced ($0 differs from BASH_SOURCE[0]): stay silent.
		if [ "${BASH_SOURCE[0]:-}" = "$0" ] ; then
			echo "⛔ ERROR: AgentExecutorTools.fn.sh: executed as '$0', which this file's own dispatch does not match, so nothing ran. Invoke it by a path ending in /myx/myx.distro-agents/sh-scripts/AgentExecutorTools.fn.sh." >&2
			exit 1
		fi
	;;
esac
