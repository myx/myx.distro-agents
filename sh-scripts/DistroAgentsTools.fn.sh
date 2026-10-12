#!/usr/bin/env bash

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

DistroAgentsTools(){
	local MDSC_CMD='DistroAgentsTools'
	type AgentsToolsMemberWorkspaceResolve > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MemberWorkspace.include"
	## WE RUN FROM HERE: an operation naming a team member uses the workspace it is run from, for everything, and is carried to no other. A member set up only in another workspace on this machine is invited: only its skillset is read from there (AgentsToolsMemberSkillsetBring), and those of its own settings this workspace holds none of (AgentsToolsConfigOptionElsewhere), and it is stopped only when its skillset cannot be brought. A client-* member is invited like any other: which organisation its operation reaches is said by the operation's prefix and its address, never by a workspace. The spawn operations make the same check themselves, before they start anything.
	case "$1:${2:-}" in
		--intern-op-agent-spawn-proxy:*|--magic-heartbeat-spawn-proxy:*|--magic-spawn-session:*|--intern-mcp-execute:*|--intern-op-decisions-append:*|--intern-op-review-*:*|--intern-directory-*:*|--member-directory-*:*|--member-namespace-list:*|--owner-workspace-*:*|*:|*:-*) ;;
		--*:*)
			## An invited member, set up only in another workspace on this machine: its operation runs here, and only its skillset, and those of its own settings this workspace holds none of, are read from the workspace it is set up in. The root is set for this one call, and a call that already reads that root goes on as it is.
			local memberBrought memberBroughtFrom
			memberBrought="$( AgentsToolsMemberSkillsetBring "$2" "$1" )" || { set +e ; return 1 ; }
			memberBroughtFrom="${memberBrought#*$'\t'}"
			memberBrought="${memberBrought%%$'\t'*}"
			if [ -n "$memberBrought" ] && [ "$memberBrought" != "${MDAT_SKILLSET_ROOT:-}" ] ; then
				## Said here, once for the whole operation, where the member is invited: which of its own settings are read from the workspace it is set up in.
				AgentsToolsMemberSettingsBorrowedSay "$2" "$1" "$memberBroughtFrom"
				( export MDAT_SKILLSET_ROOT="$memberBrought" ; DistroAgentsTools "$@" )
				return $?
			fi
		;;
	esac
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsContext.UseAgentsTools.include"

	## Every --magic-* op is magic-coordinator's, or the console's (AgentsToolsMagicCallerCheck).
	## One the skillset documents for any member stays open until the human-owner rules on its
	## name: MAGIC.md, "Who may call".
	case "$1" in
		--magic-*) AgentsToolsMagicCallerCheck "${1#--}" || { set +e ; return 1 ; } ;;
	esac

	## A --client-* op reaches the other organisation of the client-* member it names. The
	## prefix says so here, once, for everything the op calls: the side, and the op's own
	## name for the heading of a refusal (AgentsTools.CommsSlack.include).
	case "$1" in
		--client-*) local -x MDAT_COMMS_SIDE=client MDAT_COMMS_OP="$1" ;;
	esac

	case "$1" in
		--console-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.ConsoleSession.include"
			return $?
		;;


		--agents-config-option)
			## An option is this workspace's own, with the exceptions the reader below cannot know, being the sibling package's: a read of one names the workspace it comes from where that is another (AgentsToolsConfigOptionElsewhere, AgentsTools.MemberWorkspace.include), and is then made there, by the same reader.
			case "${3:-}" in
				--select|--select-default)
					AgentsToolsConfigOptionElsewhere "$2" "${4:-}" || { set +e ; return 1 ; }
					if [ -n "$agentsConfigOptionElsewhere" ] ; then
						( MMDAPP="$agentsConfigOptionElsewhere" ; . "$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/LocalTools.Config.include" )
						return $?
					fi
				;;
			esac
			. "$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/LocalTools.Config.include"
			return $?
		;;

		## No --member-config-option: a scope holds credentials, and no member reads one
		## through the tooling, so config is the tooling's and the console's op above.
		--members)
			shift
			case "$1" in
				--backend)
					shift
					DistroAgentsTools --agents-config-option "$@"
					return $?
				;;
				*)
					echo "⛔ ERROR: $MDSC_CMD --members expects: --backend <member-name> <operation> [args...]" >&2
					set +e ; return 1
				;;
			esac
		;;

		## Each comms family: the --member-* stubs and their --intern-op-comms-* implementation.
		## Slack, mail, Trello and Google carry their --client-* stubs in the same file as their
		## --member-* ones, ahead of the --client-comms-* arm below, which holds Jira and Confluence.
		--member-comms-slack-*|--client-comms-slack-*|--intern-op-comms-slack-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MemberCommsSlack.include"
			return $?
		;;

		--magic-comms-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MagicComms.include"
			return $?
		;;

		--intern-op-slack-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.CommsSlack.include"
			return $?
		;;

		--intern-op-session-context-scan)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpSessionContextScan.include"
			return $?
		;;

		--member-git-repo-history)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MemberRepoHistory.include"
			return $?
		;;

		--member-contact-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MemberContact.include"
			return $?
		;;

		--member-comms-email-*|--client-comms-email-*|--intern-op-comms-email-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MemberCommsEmail.include"
			return $?
		;;

		--member-comms-trello-*|--client-comms-trello-*|--intern-op-comms-trello-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MemberCommsTrello.include"
			return $?
		;;

		--member-comms-google-*|--client-comms-google-*|--intern-op-comms-google-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MemberCommsGoogle.include"
			return $?
		;;

		--member-comms-confluence-*|--intern-op-comms-confluence-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MemberCommsConfluence.include"
			return $?
		;;

		--member-comms-jira-*|--intern-op-comms-jira-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MemberCommsJira.include"
			return $?
		;;

		## Grouped with the Atlassian --member-comms-* arms above, as --intern-op-slack-* sits with the Slack routes.
		--intern-op-atlassian-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpAtlassianCall.include"
			return $?
		;;

		--intern-validate-json)
			shift
			local jsonPath="$1"
			if [ -n "$jsonPath" ] ; then
				if [ ! -f "$jsonPath" ] ; then
					echo "$MDSC_CMD: validate-json: ⛔ ERROR: file not found: $jsonPath" >&2
					set +e ; return 1
				fi
				if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$jsonPath" >/dev/null 2>&1 ; then
					echo "# $MDSC_CMD: validate-json: valid JSON: $jsonPath" >&2
					return 0
				else
					echo "$MDSC_CMD: validate-json: ⛔ ERROR: invalid JSON: $jsonPath" >&2
					set +e ; return 1
				fi
			else
				if python3 -c "import json,sys; json.load(sys.stdin)" >/dev/null 2>&1 ; then
					echo "# $MDSC_CMD: validate-json: valid JSON (stdin)" >&2
					return 0
				else
					echo "$MDSC_CMD: validate-json: ⛔ ERROR: invalid JSON (stdin)" >&2
					set +e ; return 1
				fi
			fi
		;;

		--librarian-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.Librarian.include"
			return $?
		;;

		## Ahead of the --member-* catch-all below, as every other --member-<service>
		## family is: the long-poll operation is its own file, not a Member.include arm.
		--member-wait-*|--intern-op-wait-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MemberWait.include"
			return $?
		;;

		--member-escalation-*|--magic-escalation-*|--intern-op-escalation-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MemberEscalation.include"
			return $?
		;;

		## Passing a held permission on, and a task's permission set: the permission store's own stubs.
		--member-permission-*|--magic-permission-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpPermission.include"
			return $?
		;;

		--member-pending-reply-*|--magic-pending-reply-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MemberPendingReply.include"
			return $?
		;;

		## A board item's `## Decisions`: the tooling's append and the member stub.
		--intern-op-decisions-*|--member-decision-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpDecisions.include"
			return $?
		;;

		## A dispatched item's review: into review, the verdicts, the ordered endings.
		--intern-op-review-*|--member-review-*|--magic-review-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpReview.include"
			return $?
		;;

		## The members' read-only views of the places and the namespaces, beside the place ops.
		--member-directory-*|--member-namespace-list)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternDirectory.include"
			return $?
		;;

		--member-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.Member.include"
			return $?
		;;

		--make-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.Make.include"
			return $?
		;;

		--install-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.Install.include"
			return $?
		;;


		--owner-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.Owner.include"
			return $?
		;;

		--intern-op-board-upsert-move-edit)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpBoardUpsertMoveEdit.include"
			return $?
		;;

		--intern-op-item-rename)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpItemRename.include"
			return $?
		;;

		--intern-op-board-rename)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpBoardRename.include"
			return $?
		;;

		--intern-op-board-trash)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpBoardTrash.include"
			return $?
		;;

		--intern-team-data-final-gc-deletion)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternTeamDataFinalGcDeletion.include"
			return $?
		;;

		--intern-op-inbox-to-processed)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpInboxToProcessed.include"
			return $?
		;;

		--intern-op-member-inbox-upsert)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpMemberInboxUpsert.include"
			return $?
		;;

		--intern-op-contact-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternContact.include"
			return $?
		;;

		--intern-op-check-configs)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpCheckConfigs.include"
			return $?
		;;

		--intern-op-owner-setup)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpOwnerSetup.include"
			return $?
		;;

		--intern-op-agent-spawn-proxy)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpAgentSpawnProxy.include"
			return $?
		;;

		--intern-op-spawn-prepare-brief)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpSpawnPrepareBrief.include"
			return $?
		;;

		## The tooling's own tracking posts, from the event-track post template: never a member's message.
		--intern-op-event-track-post)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpEventTrackPost.include"
			return $?
		;;

		--intern-op-vault-*|--intern-op-audit-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpVaultAudit.include"
			return $?
		;;

		--intern-op-pending-reply-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpPendingReply.include"
			return $?
		;;

		--intern-op-permission-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpPermission.include"
			return $?
		;;

		--intern-op-remote-bootstrap-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpRemoteBootstrap.include"
			return $?
		;;

		--intern-mcp-server)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternMcpServer.include"
			return $?
		;;

		## One request of that server, in a process of its own: started by the server only.
		--intern-mcp-request)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternMcpRequest.include"
			return $?
		;;

		--intern-main-loop)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternMainLoop.include"
			return $?
		;;

		## Registered places: their registration and the tooling's resolvers.
		--intern-directory-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternDirectory.include"
			return $?
		;;

		## Member homes, and the members of workspaces without agents: beside the member scan it runs.
		--intern-member-home-register)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.Install.include"
			return $?
		;;

		## Harness-layer sibling to --intern-main-loop above: bootstraps a root-harness
		## instance, interactive or not, with an optional payload routine to run meanwhile.
		--intern-root-harness)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternRootHarness.include"
			return $?
		;;

		## A document published to the team own place, numbered per type: the harness Artifact tool calls it.
		--intern-artifact-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternArtifact.include"
			return $?
		;;

		--intern-mcp-execute)
			shift
			case "$1" in
				--workspace)
					## Our own MDLT_ORIGIN is deliberately left untouched: the caller reached for
					## this tooling precisely because the target workspace's own may be stale,
					## broken, or absent. Only the workspace root moves.
					if [ -z "$2" ] ; then
						echo "$MDSC_CMD: mcp-execute: ⛔ ERROR: --workspace requires a value" >&2
						set +e ; return 1
					fi
					if [ ! -d "$2" ] ; then
						echo "$MDSC_CMD: mcp-execute: ⛔ ERROR: no such workspace: $2" >&2
						set +e ; return 1
					fi
					AgentsToolsWorkspaceSwitch "$2"
					shift 2
				;;
			esac
			if [ $# -gt 0 ] ; then
				echo "$MDSC_CMD: mcp-execute: ⛔ ERROR: takes no arguments" >&2
				set +e ; return 1
			fi
			local execStatus=0
			## tested, not bare: set -e would kill the process instead of returning the status
			( set -e ; eval "$( cat )" ) || execStatus=$?
			if [ "$execStatus" != "0" ] ; then
				set +e ; return $execStatus
			fi
			return 0
		;;

		--intern-config-board-location)
			shift
			if [ $# -gt 0 ] ; then
				echo "$MDSC_CMD: config-board-location: ⛔ ERROR: takes no arguments" >&2
				set +e ; return 1
			fi
			if [ -z "${MDAT_DATA_ROOT:-}" ] ; then
				echo "$MDSC_CMD: config-board-location: ⛔ ERROR: the team data store is not resolved -- fix with: $MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh --owner-setup-storage --apply" >&2
				set +e ; return 1
			fi
			printf '%s\n' "$MDAT_DATA_ROOT"
			return 0
		;;


		--magic-grooming-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MagicGrooming.include"
			return $?
		;;

		--magic-sweep-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MagicSweep.include"
			return $?
		;;

		--client-sweep-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.ClientSweep.include"
			return $?
		;;

		--client-comms-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.ClientComms.include"
			return $?
		;;

		--magic-contact-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MagicContact.include"
			return $?
		;;

		--routine-coworking-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.RoutineCoworking.include"
			return $?
		;;

		--magic-heartbeat-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MagicHeartbeat.include"
			return $?
		;;

		--magic-advance-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MagicAdvance.include"
			return $?
		;;

		## magic-librarian.morning-review.routine: its input scan and cut-off advance, implementation and stubs.
		--intern-op-morning-review-*|--magic-morning-review-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpMorningReview.include"
			return $?
		;;

		--magic-daily-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MagicDaily.include"
			return $?
		;;

		--magic-retro-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MagicRetro.include"
			return $?
		;;

		--magic-board-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MagicBoard.include"
			return $?
		;;

		## The coordinator's append to any session's transcript, and the implementation both stubs call.
		--magic-append-session-transcript|--intern-op-append-session-transcript)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.Member.include"
			return $?
		;;

		--magic-team-roster-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MagicTeamRoster.include"
			return $?
		;;

		--magic-team-data-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MagicTeamData.include"
			return $?
		;;

		--magic-spawn-session)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MagicSpawnSession.include"
			return $?
		;;

		## --help-setup-<domain> is routed by glob, so a domain gaining its own
		## setup document becomes readable without an arm being added here.
		--help|--help-syntax|--help-setup-*|'')
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/help/Help.DistroAgentsTools.include"
			return $?
		;;

		*)
			echo "$MDSC_CMD: ⛔ ERROR: invalid option: $1" >&2
			set +e ; return 1
		;;
	esac
}

case "$0" in
	*/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh)

		set -e

		if [ -z "$MDLT_ORIGIN" ] || ! type DistroAgentsContext >/dev/null 2>&1 ; then
			. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib/AgentsContext.include"
		fi
		DistroAgentsContext --run-from-detect
		DistroAgentsContext --distro-path-auto

		## Copied from DistroLocalTools.fn.sh: needed for catMarkdown and the JSON escaper.
		if   [ -d "$MYXROOT" ] && [ -f "$MYXROOT/bin/lib/catMarkdown.Common" ]; then
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

		## A bare call takes the default syntax, not --help-syntax: the whole
		## operation list is what --help-syntax is asked for by name.
		if [ -z "$1" ] || [ "$1" = "--help" ] ; then
			DistroAgentsTools "${1:-}"
			exit 1
		fi

		DistroAgentsTools "$@"
	;;
	*)
		## Executed by an unrecognised path: error. Sourced ($0 differs from BASH_SOURCE[0]): stay silent.
		if [ "${BASH_SOURCE[0]:-}" = "$0" ] ; then
			echo "⛔ ERROR: DistroAgentsTools.fn.sh: executed as '$0', which this file's own dispatch does not match, so nothing ran. Invoke it by a path ending in /myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh, or source it." >&2
			exit 1
		fi
	;;
esac
