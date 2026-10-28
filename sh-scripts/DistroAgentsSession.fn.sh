#!/usr/bin/env bash

##
## DistroAgentsSession.fn.sh -- ThisSession (F7.2): what a running session asks of its own session.
## A subsystem interface: results are read from it. So far: --get-routine-text, --routine-run-inline and --update-routine-state, and the
## session channel's: --get-session-channel-id, --post-session-channel, --get-session-thread, --wait-session-channel and --get-dispatch-text
## (F7.2); and the standing directives, --standing-directives, --directive-set and --directive-end. A tool of its own: its session operations are
## locked to the session of the call, and none of them is a name that belongs to another tool.
##
## From DistroAgentsTools.fn.sh (F1.4): --append-transcript, --settle-pending-reply, --wait-for-input (sh-lib/harness/AgentsContext.FrontTable.include).
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

## The session channel's operations (AgentsTools.ThisSession.include), loaded where they are asked for.
DistroAgentsSessionThis(){
	type AgentsToolsThisSessionWait > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.ThisSession.include"
}

## The operations that came here from DistroAgentsTools.fn.sh (F1.4): every one of them is asked what each name of the table is asked, in AgentsContext.FrontDoor.include.
DistroAgentsSessionMoved(){
	local MDSC_CMD='DistroAgentsSession' frontDone="" frontRc=0
	type AgentsToolsFrontKnows > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontTable.include"
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontDoor.include"
	[ -z "$frontDone" ] || return "$frontRc"
	case "$1" in

		--append-transcript)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.Member.include"
			return $?
		;;

		--settle-pending-reply)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/questions/AgentsTools.MemberPendingReply.include"
			return $?
		;;

		--wait-for-input)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.MemberWait.include"
			return $?
		;;

		*)
			echo "$MDSC_CMD: ⛔ ERROR: invalid option: $1" >&2
			set +e ; return 1
		;;
	esac
}

DistroAgentsSession(){
	local MDSC_CMD='DistroAgentsSession'
	## F1.4: a name that came here from DistroAgentsTools.fn.sh runs its operation in the function below.
	type AgentsToolsFrontKnows > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontTable.include"
	if AgentsToolsFrontKnows DistroAgentsSession "$@" ; then
		DistroAgentsSessionMoved "$@"
		return $?
	fi
	## The three help forms, as DistroAgentsTools.fn.sh has them: no word the default syntax (the entry points a reader
	## starts from), --help-syntax the syntax line of every operation of this file, --help the manual.
	case "${1:-}" in
		''|--help|--help-syntax)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/help/Help.DistroAgentsSession.include"
			return $?
		;;
	esac
	## The common option set (F2.2): a run of --team-member, --session-id, --spawn-id, --select-workspace and --tooling-origin after the operation is taken here,
	## and the call is made again under what they resolve (sh-lib/common/AgentsTools.CommonOptions.include).
	case "${agentsCommonFronted:-}:${2:-}" in
		:--team-member|:--session-id|:--spawn-id|:--select-workspace|:--tooling-origin)
			local commonRc=0
			type AgentsToolsCommonRun > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.CommonOptions.include"
			AgentsToolsCommonRun DistroAgentsSession DistroAgentsSession.fn.sh "$@" || commonRc=$?
			return "$commonRc"
		;;
	esac
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
			## A harness run that read this text into its first message (the prefetch, F10.8) is told so in one line while it is unchanged.
			type AgentsToolsPrefetchRoutineSaid > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsTools.PrefetchRoutine.include"
			! AgentsToolsPrefetchRoutineSaid "$routineTextFile" || return 0
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

		## The thread of the session, <channel>:<ts>, the one the session-current alias names.
		--get-session-channel-id)
			shift
			DistroAgentsSessionThis
			AgentsToolsThisSessionChannelId "$@"
			return $?
		;;

		## A post to the session thread and to nowhere else: the team's Slack send as the calling member, with no target.
		--post-session-channel)
			shift
			DistroAgentsSessionTools
			DistroAgentsSessionThis
			AgentsToolsThisSessionPost "$@"
			return $?
		;;

		## The session thread read from the session chat file, all of it or with --own the caller's own traffic. No network call.
		--get-session-thread)
			shift
			DistroAgentsSessionThis
			AgentsToolsThisSessionThread "$@"
			return $?
		;;

		## Wait on the session channel alone: [--to-@me] [--to-@here] [--to-@any] [--wait-timeout <seconds>].
		--wait-session-channel)
			shift
			DistroAgentsSessionTools
			DistroAgentsSessionThis
			AgentsToolsThisSessionWait "$@"
			return $?
		;;

		## The dispatch of the session from the sandbox's input/: dispatch.md, the board item's copy and input-scan.md, mixed.
		--get-dispatch-text)
			shift
			DistroAgentsSessionThis
			AgentsToolsThisSessionDispatchText "$@"
			return $?
		;;

		## The participants the session's record names that have no run in it yet, one a line: the executor's default list to invite from.
		--get-uninvited-participants)
			shift
			DistroAgentsSessionThis
			AgentsToolsThisSessionUninvited "$@"
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

		## The executor's checkpoint operations (F10.5): a snapshot of the run's conversation, a return to one, and the end of both. They
		## write a request that the harness of the run reads at the end of the round; in the run of a native client, or where the routine does
		## not allow them, they take no checkpoint and say so.
		--executor-checkpoint-push|--executor-checkpoint-rewind|--executor-checkpoint-exit)
			local checkpointOp="${1#--executor-checkpoint-}"
			shift
			DistroAgentsSessionThis
			AgentsToolsThisSessionCheckpoint "$checkpointOp" "$@"
			return $?
		;;

		## Wait for new input, and on an arrival return to the run's checkpoint with it as the next input (F10.5): [--wait-timeout <seconds>].
		## It waits on the floor and the scans the routine declares. Where the run is a native client's, or the session has several
		## participants, nothing is waited on and nothing returned: a notice says so, and Wait is the way to wait there.
		--idle-wait)
			shift
			DistroAgentsSessionThis
			AgentsToolsThisSessionIdleWait "$@"
			return $?
		;;

		## The explicit timed removal of the run's delivery floor: <seconds>, after which the session channel is read from the start again.
		--session-floor-remove)
			shift
			DistroAgentsSessionThis
			AgentsToolsThisSessionFloorRemove "$@"
			return $?
		;;

		## The title of the session, what it is about (T4): the title in lists and statuses, and the thread's root post edited to
		## match. Set by the session's executor; a participant's change escalates to the executor and up its chain; the person at
		## the console sets it under the authority rule. [--escalate-wait [--timeout <s>]|--escalate-enqueue] are the rule's own.
		--set-session-topic)
			shift
			DistroAgentsSessionTools
			DistroAgentsSessionThis
			AgentsToolsThisSessionSetTopic "$@"
			return $?
		;;

		## What the session does now (T4): kept in its own store and announced in the session thread. The same authority as the topic.
		--set-session-chapter)
			shift
			DistroAgentsSessionTools
			DistroAgentsSessionThis
			AgentsToolsThisSessionSetChapter "$@"
			return $?
		;;

		## The standing directives in force, and an order of the human-owner entered or taken out, magic-coordinator's
		## (AgentsTools.CoordinatorSurface.include). AgentDispatcherTools.fn.sh keeps the three names as stubs of these.
		--standing-directives|--directive-set|--directive-end)
			DistroAgentsSessionTools
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.UseAgentsTools.include"
			type AgentsToolsSurfaceStanding > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.CoordinatorSurface.include"
			case "$1" in
				--standing-directives) AgentsToolsSurfaceCaller "$1" read || { set +e ; return 1 ; } ; AgentsToolsSurfaceStanding "$@" ;;
				--directive-set) AgentsToolsSurfaceDirectiveSet "$@" ;;
				--directive-end) AgentsToolsSurfaceDirectiveEnd "$@" ;;
			esac
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
