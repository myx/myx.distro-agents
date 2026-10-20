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

## Every child finds the bash this runs in. Where the PATH holds no `bash`, the directory of the running one
## goes at its END, once: where one is found nothing changes, and nothing on the PATH is ever shadowed. And a
## starter that is no shell (python) is handed the running bash itself, to start a script with (MDAT_BASH).
case "$BASH" in
	/*/bash)
		command -v bash > /dev/null 2>&1 || { PATH="${PATH:+$PATH:}${BASH%/*}" ; export PATH ; }
		export MDAT_BASH="$BASH"
	;;
esac

## The operations that implement a harness or an MCP tool (F7.8): the ones the harness's tools run, and the one behind
## execute. --mdat-output-format json, before the operation word, prints one of them as one JSON object,
## {"operation":<word>,"status":<rc>,"result":<its output>}; every other operation runs as without it.
## sh-test/harness/AgentsBatchToolsCheck.test.sh holds the list to the words the harness runs.
agentsToolOperations="--intern-mcp-execute --intern-op-agent-spawn-proxy --intern-op-escalation-permission-add --intern-op-escalation-read
	--intern-op-pending-reply-clarify --intern-op-pending-reply-collect --intern-op-permission-folder --intern-op-permission-grant-consume
	--intern-op-permission-place --intern-op-permission-route --intern-op-permission-set-ask --intern-op-permission-single-asks
	--intern-op-review-end --intern-op-review-handback --intern-op-spawn-prepare-brief --intern-op-tool-index
	--member-comms-slack-delete-message --member-comms-slack-send-message --member-upsert-member-inquiry --member-wait-for-input"

DistroAgentsTools(){
	local MDSC_CMD='DistroAgentsTools'
	if [ "${1:-}" = "--mdat-output-format" ] ; then
		case "${2:-}" in
			json) shift 2 ;;
			*) echo "⛔ ERROR: $MDSC_CMD: --mdat-output-format takes json, got: ${2:-<none>}" >&2 ; set +e ; return 1 ;;
		esac
		case " $( printf '%s' "$agentsToolOperations" | LC_ALL=C tr '\n\t' '  ' ) " in
			*" ${1:-} "*)
				local formatOut formatRc=0
				formatOut="$( DistroAgentsTools "$@" )" || formatRc=$?
				printf '{"operation":"%s","status":%s,"result":"%s"}\n' "$1" "$formatRc" "$( printf '%s' "$formatOut" | LC_ALL=C awk -f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/mcp/AgentsMcpJsonEscape.awk" )"
				return "$formatRc"
			;;
		esac
	fi
	## The common option set (F2.2): a run of --team-member, --session-id, --spawn-id, --select-workspace and --tooling-origin after the operation is taken here, and
	## the call is made again under what they resolve; where the operation takes a team member first and none is given, the implied one is placed
	## (sh-lib/common/AgentsTools.CommonOptions.include). Rc 9 is "nothing to do": the call goes on as it is.
	case "${agentsCommonFronted:-}:${1:-}:${2:-}" in
		:--intern-context-show:--team-member|:--intern-context-show:--session-id|:--intern-context-show:--spawn-id|:--intern-context-show:--select-workspace|:--intern-context-show:--tooling-origin)
			local commonRc=0
			type AgentsToolsCommonRun > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.CommonOptions.include"
			AgentsToolsCommonRun DistroAgentsTools DistroAgentsTools.fn.sh "$@" || commonRc=$?
			[ "$commonRc" = 9 ] || return "$commonRc"
		;;
		## The internal operations are the tooling's own plumbing, with options of their own (--intern-op-permission-grant-consume --session-id): not commands of the set.
		:--intern-*) ;;
		:*:--team-member|:*:--session-id|:*:--spawn-id|:*:--select-workspace|:*:--tooling-origin|:--member-*:|:--member-*:--*|:--magic-*:|:--magic-*:--*|:--client-*:|:--client-*:--*|:--librarian-*:|:--librarian-*:--*)
			local commonRc=0
			type AgentsToolsCommonRun > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.CommonOptions.include"
			AgentsToolsCommonRun DistroAgentsTools DistroAgentsTools.fn.sh "$@" || commonRc=$?
			[ "$commonRc" = 9 ] || return "$commonRc"
		;;
	esac
	type AgentsToolsMemberWorkspaceResolve > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.MemberWorkspace.include"
	## WE RUN FROM HERE: an operation naming a team member uses the workspace it is run from, for everything, and is carried to no other. A member set up only in another workspace on this machine is invited: only its skillset is read from there (AgentsToolsMemberSkillsetBring), and those of its own settings this workspace holds none of (AgentsToolsConfigOptionElsewhere), and it is stopped only when its skillset cannot be brought. A client-* member is invited like any other: which organisation its operation reaches is said by the operation's prefix and its address, never by a workspace. The spawn operations make the same check themselves, before they start anything.
	case "$1:${2:-}" in
		--intern-op-agent-spawn-proxy:*|--intern-merge-md-files:*|--magic-heartbeat-spawn-proxy:*|--magic-spawn-session:*|--intern-mcp-execute:*|--intern-op-decisions-append:*|--intern-op-review-*:*|--intern-directory-*:*|--member-directory-*:*|--member-namespace-list:*|--owner-workspace-*:*|--make-*:*|--manager-*:*|*:|*:-*) ;;
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
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.UseAgentsTools.include"

	## Every --magic-* op is magic-coordinator's, or the console's (AgentsToolsMagicCallerCheck).
	## One the skillset documents for any member stays open until the human-owner rules on its
	## name: MAGIC.md, "Who may call".
	## A --client-* op naming a client is that client's own session's, or the console's
	## (AgentsToolsClientCallerCheck): one rule for the whole family, asked here and in no
	## stub. magic-coordinator's own way to one is a --magic-* op, --magic-client-operation-run.
	## A --manager-* op is the console's own, and no member's session's, magic-coordinator's
	## among them (AgentsToolsManagerCallerCheck): one rule for the whole family, asked here
	## and in no arm of it.
	## The bare --manager is no --manager-* op: it starts the console app, and admits every
	## caller, exactly as the start of the screen always did. Its own rule, asked here.
	case "$1" in
		--magic-*) AgentsToolsMagicCallerCheck "${1#--}" || { set +e ; return 1 ; } ;;
		--client-*) AgentsToolsClientCallerCheck "${2:-}" "${1#--}" || { set +e ; return 1 ; } ;;
		--manager) ;;
		--manager-*) AgentsToolsManagerCallerCheck "${1#--}" || { set +e ; return 1 ; } ;;
	esac

	## A --client-* op reaches the other organisation of the client-* member it names. The
	## prefix says so here, once, for everything the op calls: the side, and the op's own
	## name for the heading of a refusal (AgentsTools.CommsSlack.include).
	case "$1" in
		--client-*) local -x MDAT_COMMS_SIDE=client MDAT_COMMS_OP="$1" ;;
	esac

	case "$1" in
		--console-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.ConsoleSession.include"
			return $?
		;;


		--agents-config-option)
			## A write into a preset, or of a key that belongs to presets or to the tiers, asks the write check first (AgentsToolsPresetWriteCheck, AgentsTools.Preset.include): the same writer, with its refusals. A value it takes from stdin is held by the check, and the writer is handed it again.
			case "${3:-}" in
				--upsert|--upsert-from-stdin|--upsert-if|--delete|--delete-if)
					case "$2:${4:-}" in
						preset-*:*|*:PRESET_*|*:SPAWN_TIER_*)
							type AgentsToolsPresetWriteCheck > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/config/AgentsTools.Preset.include"
							AgentsToolsPresetWriteCheck "${MMDAPP%/}" "$2" "$3" "${4:-}" "${5:-}" || { set +e ; return 1 ; }
							if [ -n "$agentsPresetStdinTaken" ] ; then
								agentsPresetStdinTaken=""
								. "$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/LocalTools.Config.include" <<< "$agentsPresetStdin"
								return $?
							fi
						;;
					esac
				;;
			esac
			## An option is this workspace's own, with the exceptions the reader below cannot know, being the sibling package's: a read of one names the workspace it comes from where that is another (AgentsToolsConfigOptionElsewhere, AgentsTools.MemberWorkspace.include), and is then made there, by the same reader.
			case "${3:-}" in
				--select|--select-default)
					## A spawn setting of the team, where tier settings are configured, is the preset's of the spawn (AgentsToolsPresetOverlay, AgentsTools.Preset.include): answered here, from the preset, ahead of the scope. Where none is set, the scope is read as ever.
					if [ "$2" = "magic-team" ] ; then
						local overlayOut overlayRc=0
						type AgentsToolsPresetOverlay > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/config/AgentsTools.Preset.include"
						overlayOut="$( AgentsToolsPresetOverlay "${4:-}" )" || overlayRc=$?
						case "$overlayRc" in
							0)
								if [ -n "$overlayOut" ] ; then printf '%s\n' "$overlayOut" ; elif [ "$3" = "--select-default" ] ; then printf '%s\n' "${5:-}" ; fi
								return 0
							;;
							1) ;;
							*) set +e ; return 1 ;;
						esac
					fi
					AgentsToolsConfigOptionElsewhere "$2" "${4:-}" || { set +e ; return 1 ; }
					if [ -n "$agentsConfigOptionElsewhere" ] ; then
						( MMDAPP="$agentsConfigOptionElsewhere" ; . "$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/LocalTools.Config.include" )
						return $?
					fi
				;;
				--upsert|--upsert-from-stdin|--upsert-if)
					## A write is this workspace's own, always, and is made as it was. Where it is the first setting of a system this workspace holds for an invited member, that system is read here alone from then on, and what the workspace the member is set up in holds of it is no longer read: said in one line, once the write is made (AgentsToolsMemberSettingsBorrowEndedSay). The reader shifts the arguments, so what the line needs is kept first.
					local optionScope="$2" optionKey="${4:-}" optionThere="" optionRc=0
					case "$optionScope" in
						magic-team) ;;
						*) AgentsToolsConfigOptionElsewhere "$optionScope" "$optionKey" 2> /dev/null && optionThere="$agentsConfigOptionElsewhere" ;;
					esac
					if [ -n "$optionThere" ] ; then
						. "$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/LocalTools.Config.include" || optionRc=$?
						[ "$optionRc" -ne 0 ] || AgentsToolsMemberSettingsBorrowEndedSay "$optionScope" "$optionKey" "$optionThere"
						return "$optionRc"
					fi
				;;
				--delete|--delete-if)
					## The mirror. Where the setting deleted is the last one of a system this workspace held for an invited member, that system is read from the workspace the member is set up in again, from then on: said in one line, once the delete is made (AgentsToolsMemberSettingsBorrowBegunSay). The reader shifts the arguments, so what the line needs is kept first.
					local optionScope="$2" optionKey="${4:-}" optionPrefix="" optionRc=0
					case "$optionScope" in
						magic-team) ;;
						*) optionPrefix="$( AgentsToolsMemberSettingSystemOf "$optionKey" )" ;;
					esac
					if [ -n "$optionPrefix" ] && AgentsToolsScopeHoldsKeys "${MMDAPP%/}" "$optionScope" "$optionPrefix" ; then
						. "$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/LocalTools.Config.include" || optionRc=$?
						if [ "$optionRc" -eq 0 ] ; then
							AgentsToolsConfigOptionElsewhere "$optionScope" "$optionKey" 2> /dev/null || :
							[ -z "$agentsConfigOptionElsewhere" ] || AgentsToolsMemberSettingsBorrowBegunSay "$optionScope" "$optionKey" "$agentsConfigOptionElsewhere"
						fi
						return "$optionRc"
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
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.MemberCommsSlack.include"
			return $?
		;;

		--magic-comms-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicComms.include"
			return $?
		;;

		## One --client-* op, run as the client-* member it names: magic-coordinator's own way
		## to the other organisation.
		--magic-client-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicClient.include"
			return $?
		;;

		--intern-op-slack-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.CommsSlack.include"
			return $?
		;;

		--intern-op-session-context-scan)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.InternOpSessionContextScan.include"
			return $?
		;;

		--member-git-repo-history)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.MemberRepoHistory.include"
			return $?
		;;

		--member-contact-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.MemberContact.include"
			return $?
		;;

		--member-comms-email-*|--client-comms-email-*|--intern-op-comms-email-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.MemberCommsEmail.include"
			return $?
		;;

		--member-comms-trello-*|--client-comms-trello-*|--intern-op-comms-trello-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.MemberCommsTrello.include"
			return $?
		;;

		--member-comms-google-*|--client-comms-google-*|--intern-op-comms-google-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.MemberCommsGoogle.include"
			return $?
		;;

		--member-comms-confluence-*|--intern-op-comms-confluence-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.MemberCommsConfluence.include"
			return $?
		;;

		--member-comms-jira-*|--intern-op-comms-jira-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.MemberCommsJira.include"
			return $?
		;;

		## Grouped with the Atlassian --member-comms-* arms above, as --intern-op-slack-* sits with the Slack routes.
		--intern-op-atlassian-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.InternOpAtlassianCall.include"
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

		## F7.7's stub of the librarian's skillset write, with no logic of its own: --librarian-skillset-upsert is AgentLibrarianTools.fn.sh --skillset-upsert.
		--librarian-skillset-upsert)
			shift
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/AgentLibrarianTools.fn.sh"
			AgentLibrarianTools --skillset-upsert "$@"
			return $?
		;;

		--librarian-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.Librarian.include"
			return $?
		;;

		## Ahead of the --member-* catch-all below, as every other --member-<service>
		## family is: the long-poll operation is its own file, not a Member.include arm.
		--member-wait-*|--intern-op-wait-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.MemberWait.include"
			return $?
		;;

		--member-escalation-*|--magic-escalation-*|--intern-op-escalation-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/questions/AgentsTools.MemberEscalation.include"
			return $?
		;;

		## Passing a held permission on, and a task's permission set: the permission store's own stubs.
		--member-permission-*|--magic-permission-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/grants/AgentsTools.InternOpPermission.include"
			return $?
		;;

		--member-pending-reply-*|--magic-pending-reply-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/questions/AgentsTools.MemberPendingReply.include"
			return $?
		;;

		## A board item's `## Decisions`: the tooling's append and the member stub.
		--intern-op-decisions-*|--member-decision-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.InternOpDecisions.include"
			return $?
		;;

		## A dispatched item's review: into review, the verdicts, the ordered endings.
		--intern-op-review-*|--member-review-*|--magic-review-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.InternOpReview.include"
			return $?
		;;

		## The members' read-only views of the places and the namespaces, beside the place ops.
		--member-directory-*|--member-namespace-list)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.InternDirectory.include"
			return $?
		;;

		## The retest queue: what a session asks to have tested again, the tester's batch of it, and a request's outcome.
		--member-retest-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.MemberRetest.include"
			return $?
		;;

		--member-*|--intern-op-member-work-session-input-scan)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.Member.include"
			return $?
		;;

		--make-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/config/AgentsTools.Make.include"
			return $?
		;;

		## The manager screen of the agents console, the console app, in this terminal: what the
		## console's --manager runs.
		--manager)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsTools.InternManager.include"
			return $?
		;;

		## The console's own operations, which a manager screen reads and acts through: never a member's.
		--manager-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsTools.Manager.include"
			return $?
		;;

		## The installer of the knowledge store's Python environment, beside the other installs.
		--install-knowledge-store)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/config/AgentsTools.InstallKnowledgeStore.include"
			return $?
		;;

		--install-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/config/AgentsTools.Install.include"
			return $?
		;;


		--owner-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/config/AgentsTools.Owner.include"
			return $?
		;;

		--intern-op-board-upsert-move-edit)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.InternOpBoardUpsertMoveEdit.include"
			return $?
		;;

		--intern-op-item-rename)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.InternOpItemRename.include"
			return $?
		;;

		--intern-op-board-rename)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.InternOpBoardRename.include"
			return $?
		;;

		--intern-op-board-trash)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.InternOpBoardTrash.include"
			return $?
		;;

		--intern-team-data-final-gc-deletion)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.InternTeamDataFinalGcDeletion.include"
			return $?
		;;

		--intern-op-inbox-to-processed)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/inbox/AgentsTools.InternOpInboxToProcessed.include"
			return $?
		;;

		--intern-op-member-inbox-upsert)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/inbox/AgentsTools.InternOpMemberInboxUpsert.include"
			return $?
		;;

		--intern-op-contact-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.InternContact.include"
			return $?
		;;

		--intern-op-check-configs)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/config/AgentsTools.InternOpCheckConfigs.include"
			return $?
		;;

		--intern-op-owner-setup)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/config/AgentsTools.InternOpOwnerSetup.include"
			return $?
		;;

		--intern-op-agent-spawn-proxy)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.InternOpAgentSpawnProxy.include"
			return $?
		;;

		--intern-op-spawn-prepare-brief)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.InternOpSpawnPrepareBrief.include"
			return $?
		;;

		## The tooling's own tracking posts, from the event-track post template: never a member's message.
		--intern-op-event-track-post)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.InternOpEventTrackPost.include"
			return $?
		;;

		--intern-op-vault-*|--intern-op-audit-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.InternOpVaultAudit.include"
			return $?
		;;

		--intern-op-pending-reply-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/questions/AgentsTools.InternOpPendingReply.include"
			return $?
		;;

		## A change held for the human-owner's approval: kept, shown to him, applied on his verdict.
		--intern-op-change-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/grants/AgentsTools.InternOpChange.include"
			return $?
		;;

		--intern-op-permission-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/grants/AgentsTools.InternOpPermission.include"
			return $?
		;;

		--intern-op-remote-bootstrap-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/config/AgentsTools.InternOpRemoteBootstrap.include"
			return $?
		;;

		--intern-mcp-server)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/mcp/AgentsTools.InternMcpServer.include"
			return $?
		;;

		## One request of that server, in a process of its own: started by the server only.
		--intern-mcp-request)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/mcp/AgentsTools.InternMcpRequest.include"
			return $?
		;;

		--intern-main-loop)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.InternMainLoop.include"
			return $?
		;;

		## The control thread of one coworking session, a sibling of --intern-main-loop above: a
		## shell process of the tooling that watches the runs of one session and keeps its state.
		--intern-session-control)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.InternSessionControl.include"
			return $?
		;;

		## The communications reader and writer of the workspace (F9.3), beside the control thread above: one shell process
		## of the tooling on a host that keeps the session chat files up to date with Slack, and Slack with them.
		--intern-session-comms)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.InternSessionComms.include"
			return $?
		;;

		## The background thread of the collection of the sources an input scan reads (F4.2): one shell process of the tooling on a host
		## that keeps the mail and the Trello notes of the members a scan reads up to date in their inboxes. A scan and the main loop
		## want it and start it; no agent calls it.
		--intern-source-collect)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.InternSourceCollect.include"
			return $?
		;;

		## Registered places: their registration and the tooling's resolvers.
		--intern-directory-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.InternDirectory.include"
			return $?
		;;

		## Member homes, and the members of workspaces without agents: beside the member scan it runs.
		--intern-member-home-register)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/config/AgentsTools.Install.include"
			return $?
		;;

		## Harness-layer sibling to --intern-main-loop above: bootstraps a root-harness
		## instance, interactive or not, with an optional payload routine to run meanwhile.
		--intern-root-harness)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsTools.InternRootHarness.include"
			return $?
		;;

		## Markdown files merged into one document, each by a mixin naming its section. Its consumer is
		## the Skill tool, which serves a member's basic and armed files as one read.
		--intern-merge-md-files)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsTools.InternMergeMdFiles.include"
			return $?
		;;

		## The one validator of a document, a rule set for each kind (`routine`, and `document`, the
		## self-check). Read-only; one row per fault, `<file>:<line>: <rule>: <text>`.
		--intern-doc-validate)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.InternDocValidate.include"
			return $?
		;;

		## F7.6's stub of the routine kind of that validator, with no logic of its own.
		--tester-skillset-validate-routine)
			shift
			DistroAgentsTools --intern-doc-validate routine "$@"
			return $?
		;;

		## F7.6's stubs of the testing system's operations (the `--tester-*` kind, approved in the refactorings epic), with no logic of their own:
		## --tester-<operation> is DistroAgentsTesting.fn.sh --<operation>.
		--tester-test-register|--tester-test-update|--tester-test-unregister|--tester-test-invalidate|--tester-test-list|--tester-run-oldest-untested|--tester-run-all-nightly-regressions)
			local testerOp="${1#--tester-}"
			shift
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTesting.fn.sh"
			DistroAgentsTesting "--$testerOp" "$@"
			return $?
		;;

		## The tool index, .local/agents/tool-index.md: every tool, and who may use what. A
		## member's Skill read of its own skill serves that member's section of it.
		--intern-op-tool-index)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.InternOpToolIndex.include"
			return $?
		;;

		## A document published to the team own place, numbered per type: the harness Artifact tool calls it.
		--intern-artifact-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.InternArtifact.include"
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


		## The input scans are tooling-internal: the spawner runs the one a routine declares in `input-scan-def:`, and no agent calls one (F6.4).
		--magic-grooming-*|--intern-op-grooming-input-scan)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicGrooming.include"
			return $?
		;;

		--magic-sweep-*|--intern-op-sweep-input-scan)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicSweep.include"
			return $?
		;;

		--client-sweep-*|--intern-op-client-sweep-input-scan)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/client/AgentsTools.ClientSweep.include"
			return $?
		;;

		--client-comms-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/client/AgentsTools.ClientComms.include"
			return $?
		;;

		--magic-contact-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.MagicContact.include"
			return $?
		;;

		## The update of the locked document of a session's routine (F6.2): ThisSession's --update-routine-state reaches it here.
		--intern-op-update-routine-state)
			shift
			type AgentsToolsRoutineSessionStateUpdate > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.RoutineLock.include"
			AgentsToolsRoutineSessionStateUpdate "$@"
			return $?
		;;

		--intern-op-routine-coworking-session-input-scan)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.RoutineCoworking.include"
			return $?
		;;

		--magic-heartbeat-*|--intern-op-heartbeat-input-scan|--intern-op-heartbeat-state-upsert)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicHeartbeat.include"
			return $?
		;;

		--magic-advance-*|--intern-op-advance-input-scan)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicAdvance.include"
			return $?
		;;

		## magic-librarian.morning-review.routine: its input scan. The cut-off is the routine's own state, updated with --update-routine-state.
		--intern-op-morning-review-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.InternOpMorningReview.include"
			return $?
		;;

		## The collection of the sources an input scan reads (F4.2): a member's mailbox and Trello into its inbox, read-only. The tooling's
		## own, called by the scans, the one background thread and the main loop; no agent calls it and no routine owns it.
		--intern-op-collect-sources)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.InternOpCollect.include"
			return $?
		;;

		## The work-duty input scan (F4.1): the spawner runs it from a routine's `input-scan-def: work-duty`; no member calls it.
		--intern-op-work-duty-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.InternOpWorkDuty.include"
			return $?
		;;

		--magic-daily-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicDaily.include"
			return $?
		;;

		--magic-retro-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicRetro.include"
			return $?
		;;

		--magic-board-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicBoard.include"
			return $?
		;;

		## The coordinator's append to any session's transcript, and the implementation both stubs call.
		--magic-append-session-transcript|--intern-op-append-session-transcript)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.Member.include"
			return $?
		;;

		--magic-team-roster-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicTeamRoster.include"
			return $?
		;;

		--magic-team-data-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicTeamData.include"
			return $?
		;;

		--magic-spawn-session)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicSpawnSession.include"
			return $?
		;;

		## The context this call resolves, a line each, `<name>: <value>` (F2.2): the common option set first, then the MDAT_* and MDLT_* variables. Read-only.
		--intern-context-show)
			type AgentsToolsContextShow > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.CommonOptions.include"
			AgentsToolsContextShow "$@"
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
			. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib/harness/AgentsContext.include"
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
