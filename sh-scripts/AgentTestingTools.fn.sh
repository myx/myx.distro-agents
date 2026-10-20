#!/usr/bin/env bash

##
## AgentTestingTools.fn.sh -- any member's personal tool for testing (F7.6): the way a member communicates a testing need or task to the testing
## system and to magic-tester. A tool that takes work in: nobody reads results from it. So far: --request-tests, which puts tests into the one
## retest queue of the machine (the options of --member-retest-queue) and files one inquiry into magic-tester's inbox naming the need. What the
## testing system hands out (the testbed, its lists, the runs) is DistroAgentsTesting.fn.sh's.
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

AgentTestingTools(){
	local MDSC_CMD='AgentTestingTools'
	## The common option set (F2.2): a run of --team-member, --session-id, --spawn-id, --select-workspace and --tooling-origin after the operation is taken here,
	## and the call is made again under what they resolve (sh-lib/common/AgentsTools.CommonOptions.include).
	case "${agentsCommonFronted:-}:${2:-}" in
		:--team-member|:--session-id|:--spawn-id|:--select-workspace|:--tooling-origin)
			local commonRc=0
			type AgentsToolsCommonRun > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.CommonOptions.include"
			AgentsToolsCommonRun AgentTestingTools AgentTestingTools.fn.sh "$@" || commonRc=$?
			return "$commonRc"
		;;
	esac
	case "$1" in

		## A testing need of the calling member: --why <text> and the queue's options, [--project <p>] [--file <changed-file>]... [--about <scratch-folder>]
		## [--wait|--no-wait] [<test>...]. The tests go into the retest queue, and one inquiry into magic-tester's inbox says who asked, why and for what.
		## With --wait the call stays until the batch has run them, and says how they came out. The outcome is read by the request's id, with
		## `--member-retest-result`.
		--request-tests)
			local requestOp="$1" requestMember requestWhy="" requestProject="" requestAbout="" requestPriority="no-wait" requestTests="" requestFiles=""
			local requestArgs=() requestWhat="" requestOut="" requestPid requestId="" requestText requestFile="" requestRc=0 requestLeft
			shift
			type AgentsToolsActingMember > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.CallerCheck.include"
			requestMember="$( AgentsToolsActingMember )"
			if [ -z "$requestMember" ] ; then
				echo "$MDSC_CMD: ⛔ ERROR: $requestOp: a testing need is raised by a member, and this call comes from no member's session -- a console user queues tests with --member-retest-queue --by <who>" >&2
				set +e ; return 1
			fi
			while [ $# -gt 0 ] ; do
				case "$1" in
					--why|--project|--file|--about)
						[ -n "${2:-}" ] || { echo "$MDSC_CMD: ⛔ ERROR: $requestOp: $1 takes a value" >&2 ; set +e ; return 1 ; }
						case "$1" in
							--why) requestWhy="$2" ;;
							--project) requestProject="$2" ;;
							--about) requestAbout="$2" ;;
							--file) requestFiles="$requestFiles${requestFiles:+, }$2" ;;
						esac
						requestArgs[${#requestArgs[@]}]="$1" ; requestArgs[${#requestArgs[@]}]="$2"
						shift 2
					;;
					--wait|--no-wait) requestPriority="${1#--}" ; requestArgs[${#requestArgs[@]}]="$1" ; shift ;;
					--by) echo "$MDSC_CMD: ⛔ ERROR: $requestOp: --by is not given: the request is the calling member's, $requestMember" >&2 ; set +e ; return 1 ;;
					-*) echo "$MDSC_CMD: ⛔ ERROR: $requestOp: unknown option: $1" >&2 ; set +e ; return 1 ;;
					*) requestTests="$requestTests${requestTests:+, }$1" ; requestArgs[${#requestArgs[@]}]="$1" ; shift ;;
				esac
			done
			if [ -z "$requestWhy" ] ; then
				echo "$MDSC_CMD: ⛔ ERROR: $requestOp: syntax is --why <text> [--project <p>] [--file <changed-file>]... [--about <scratch-folder>] [--wait|--no-wait] [<test>...]" >&2
				set +e ; return 1
			fi
			[ -z "$requestProject" ] || requestWhat="the tests registered for the project $requestProject"
			[ -z "$requestTests" ] || requestWhat="$requestWhat${requestWhat:+; }$requestTests"
			[ -z "$requestFiles" ] || requestWhat="$requestWhat${requestWhat:+; }every test not yet passed, for the changed files $requestFiles"
			[ -z "$requestAbout" ] || requestWhat="$requestWhat${requestWhat:+, }in the copy $requestAbout"
			type AgentsToolsEscalationNote > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/questions/AgentsTools.MemberEscalation.include" --definitions-only > /dev/null 2>&1 || :
			mkdir -p "$MMDAPP/.local/temp" 2> /dev/null
			requestOut="$( mktemp "$MMDAPP/.local/temp/agent-testing-tools.XXXXXX" )" || { set +e ; return 1 ; }
			## The queue checks the request first, and a refused one asks nobody. With --wait it stays until its batch is run, so it runs apart,
			## and the inquiry is filed as soon as it has said the request's id.
			( "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --member-retest-queue --by "$requestMember" "${requestArgs[@]}" > "$requestOut" 2> "$requestOut.err" < /dev/null ) &
			requestPid=$!
			requestLeft=300
			while [ "$requestLeft" -gt 0 ] ; do
				requestId="$( LC_ALL=C sed -n 's/^\(retest-[0-9A-Za-z-]*\)$/\1/p' "$requestOut" | LC_ALL=C sed -n 1p )"
				[ -z "$requestId" ] || break
				kill -0 "$requestPid" 2> /dev/null || break
				sleep 0.2 ; requestLeft=$(( requestLeft - 1 ))
			done
			if [ -n "$requestId" ] ; then
				requestText="$( ASKP_F_member="$requestMember" ASKP_F_why="$requestWhy" ASKP_F_what="${requestWhat:-the tests of the request}" ASKP_F_request="$requestId" ASKP_F_priority="$requestPriority" AgentsToolsEscalationNote "Testing/tests-wanted" )" || requestText=""
				if [ -n "$requestText" ] ; then
					requestFile="$( mktemp "$MMDAPP/.local/temp/agent-testing-tools.XXXXXX" )" && printf '%s\n' "$requestText" > "$requestFile" || requestFile=""
					if [ -z "$requestFile" ] || ! "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --member-upsert-member-inquiry magic-tester "inquiry-$( date -u +%Y%m%dT%H%MZ )-tests-wanted-${requestId##*-}.md" --from-member "$requestMember" --from-file "$requestFile" > /dev/null 2>&1 ; then
						echo "$MDSC_CMD: ⚠️ WARNING: $requestOp: the request $requestId is queued, but the inquiry to magic-tester could not be filed" >&2
					fi
					[ -z "$requestFile" ] || rm -f "$requestFile"
				else
					echo "$MDSC_CMD: ⚠️ WARNING: $requestOp: the request $requestId is queued, but its inquiry to magic-tester could not be filled from its template (tooling-note.post.format.md, Testing/tests-wanted)" >&2
				fi
			fi
			## The id is said as soon as the inquiry is filed, for a caller that stays; the rest once the queue has said all it does.
			[ -z "$requestId" ] || printf '%s\n' "$requestId"
			wait "$requestPid" ; requestRc=$?
			cat "$requestOut.err" >&2
			if [ -n "$requestId" ] ; then LC_ALL=C sed 1d "$requestOut" ; else cat "$requestOut" ; fi
			rm -f "$requestOut" "$requestOut.err"
			[ -n "$requestId" ] || [ "$requestRc" != 0 ] || requestRc=1
			set +e ; return "$requestRc"
		;;

		*)
			echo "$MDSC_CMD: ⛔ ERROR: invalid option: $1" >&2
			set +e ; return 1
		;;
	esac
}

case "$0" in
	*/myx/myx.distro-agents/sh-scripts/AgentTestingTools.fn.sh)

		set -e

		if [ -z "$MDLT_ORIGIN" ] || ! type DistroAgentsContext >/dev/null 2>&1 ; then
			. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib/harness/AgentsContext.include"
		fi
		DistroAgentsContext --run-from-detect
		DistroAgentsContext --distro-path-auto

		AgentTestingTools "$@"
	;;
	*)
		## Executed by an unrecognised path: error. Sourced ($0 differs from BASH_SOURCE[0]): stay silent.
		if [ "${BASH_SOURCE[0]:-}" = "$0" ] ; then
			echo "⛔ ERROR: AgentTestingTools.fn.sh: executed as '$0', which this file's own dispatch does not match, so nothing ran. Invoke it by a path ending in /myx/myx.distro-agents/sh-scripts/AgentTestingTools.fn.sh, or source it." >&2
			exit 1
		fi
	;;
esac
