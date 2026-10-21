#!/usr/bin/env bash

##
## DistroAgentsTesting.fn.sh -- the testing, running and bookkeeping operations (F7.6), for
## magic-tester, console human users and the console app. A subsystem interface: results are
## read from it. --skillset-validate-routine, a thin stub of the one validator, --intern-doc-validate,
## with no logic of its own; and the testbed (.local/agents/testing): --test-register, --test-update,
## --test-unregister, --test-invalidate and --test-list over the metadata of the tests, and
## --run-oldest-untested and --run-all-nightly-regressions, which put tests into the retest queue.
## All testing machinery gathers here, the retest queue included, and there is no second queue: the
## queue is the one of the --retest-* operations (AgentsTools.MemberRetest.include). A member raises a testing need through AgentTestingTools.fn.sh.
##
## From DistroAgentsTools.fn.sh (F1.4): --retest-drain, --retest-queue, --retest-result, --send-report (sh-lib/harness/AgentsContext.FrontTable.include).
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

## The testbed's operations (AgentsTools.Testbed.include), loaded where they are asked for.
DistroAgentsTestingTestbed(){
	type AgentsToolsTestbedRegister > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.Testbed.include"
}

## The operations that came here from DistroAgentsTools.fn.sh (F1.4): every one of them is asked what each name of the table is asked, in AgentsContext.FrontDoor.include.
DistroAgentsTestingMoved(){
	local MDSC_CMD='DistroAgentsTesting' frontDone="" frontRc=0
	type AgentsToolsFrontKnows > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontTable.include"
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontDoor.include"
	[ -z "$frontDone" ] || return "$frontRc"
	case "$1" in

		--retest-drain|--retest-queue|--retest-result)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.MemberRetest.include"
			return $?
		;;

		--send-report)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicCoordinatorState.include"
			return $?
		;;

		*)
			echo "$MDSC_CMD: ⛔ ERROR: invalid option: $1" >&2
			set +e ; return 1
		;;
	esac
}

DistroAgentsTesting(){
	local MDSC_CMD='DistroAgentsTesting'
	## F1.4: a name that came here from DistroAgentsTools.fn.sh runs its operation in the function below.
	type AgentsToolsFrontKnows > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontTable.include"
	if AgentsToolsFrontKnows DistroAgentsTesting "$@" ; then
		DistroAgentsTestingMoved "$@"
		return $?
	fi
	## The common option set (F2.2): a run of --team-member, --session-id, --spawn-id, --select-workspace and --tooling-origin after the operation is taken here,
	## and the call is made again under what they resolve (sh-lib/common/AgentsTools.CommonOptions.include).
	case "${agentsCommonFronted:-}:${2:-}" in
		:--team-member|:--session-id|:--spawn-id|:--select-workspace|:--tooling-origin)
			local commonRc=0
			type AgentsToolsCommonRun > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.CommonOptions.include"
			AgentsToolsCommonRun DistroAgentsTesting DistroAgentsTesting.fn.sh "$@" || commonRc=$?
			return "$commonRc"
		;;
	esac
	case "$1" in

		## The metadata of the tests: <test-id> --project <p> --script <path> [--functionality <f>] [--keyword <k>]... [--rig <path>]
		## [--document <path>]... [--resource <path>]... [--nightly yes|no], or --from-folder <dir> --project <p> for every *.test.sh of a folder.
		--test-register)
			local testOp="$1"
			shift
			DistroAgentsTestingTestbed
			AgentsToolsTestbedRegister "$testOp" "$@"
			return $?
		;;

		## Changes the metadata of a registered test: <test-id> and the options of --test-register, a list replaced whole.
		--test-update)
			local testOp="$1"
			shift
			DistroAgentsTestingTestbed
			AgentsToolsTestbedUpdate "$testOp" "$@"
			return $?
		;;

		## Takes a test out of the testbed: <test-id>. The test, its script and its pass record stay.
		--test-unregister)
			local testOp="$1"
			shift
			DistroAgentsTestingTestbed
			AgentsToolsTestbedUnregister "$testOp" "$@"
			return $?
		;;

		## Drops the pass record of a registered test, so that the next batch runs it: <test-id>.
		--test-invalidate)
			local testOp="$1"
			shift
			DistroAgentsTestingTestbed
			AgentsToolsTestbedInvalidate "$testOp" "$@"
			return $?
		;;

		## The registered tests, with their stats and a short run history: [--project <p>] [--namespace <n>] [--keyword <k>].
		--test-list)
			local testOp="$1"
			shift
			DistroAgentsTestingTestbed
			AgentsToolsTestbedList "$testOp" "$@"
			return $?
		;;

		## The oldest untested registered test, or all that are eligible for the nightly, into the retest queue: [--wait|--no-wait].
		--run-oldest-untested|--run-all-nightly-regressions)
			local testOp="$1"
			shift
			DistroAgentsTestingTestbed
			AgentsToolsTestbedRun "$testOp" "$@"
			return $?
		;;

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

		## Copied from DistroAgentsTools.fn.sh: the test runner keys a pass by the myx.common it runs under, so the testbed
		## reads the pass record under the same one the retest queue's batch runs under, called from here or through the tool.
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
