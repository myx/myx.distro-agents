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
## {"operation":<word>,"status":<rc>,"result":<its output>}; every other operation runs as without it. The list is in
## that branch of the dispatcher, not at file scope. The ones of the tool files are in agentsFrontJsonOps
## (sh-lib/harness/AgentsContext.FrontTable.include). sh-test/harness/AgentsBatchToolsCheck.test.sh holds both lists to the
## words the harness runs, and reads this one out of its branch.

## The tester family of sketch 10.6: every operation DistroAgentsTesting.fn.sh serves, by its own name, so `--tester-<operation>` is
## that operation and nothing else. One list, in the family's own arm, held to the testing tool's help by
## sh-test/member/AgentsTesterFamilyCheck.test.sh, which reads it out of that arm.

DistroAgentsTools(){
	local MDSC_CMD='DistroAgentsTools'
	## The one rule for the operations of the tool files (F1.4): a name of the table (sh-lib/harness/AgentsContext.FrontTable.include) runs in the file that owns it.
	type AgentsToolsFrontAny > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontTable.include"
	if AgentsToolsFrontAny "$@" ; then
		AgentsToolsFrontRoute "$@"
		return $?
	fi
	## A name an operation had before it moved into a tool file is refused with its new place.
	case "${1:-}" in
		--member-*|--magic-*)
			type AgentsToolsFrontRetired > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontTable.Retired.include"
			if AgentsToolsFrontRetired "$1" >&2 ; then set +e ; return 1 ; fi
		;;
	esac
	if [ "${1:-}" = "--mdat-output-format" ] ; then
		local agentsToolOperations="--intern-mcp-execute --intern-op-agent-spawn-proxy --intern-op-escalation-permission-add --intern-op-escalation-read
			--intern-op-pending-reply-clarify --intern-op-pending-reply-collect --intern-op-permission-folder --intern-op-permission-grant-consume
			--intern-op-permission-place --intern-op-permission-route --intern-op-permission-set-ask --intern-op-permission-single-asks
			--intern-op-review-end --intern-op-review-handback --intern-op-spawn-prepare-brief --intern-op-tool-index"
		case "${2:-}" in
			json) shift 2 ;;
			*) echo "⛔ ERROR: $MDSC_CMD: --mdat-output-format takes json, got: ${2:-<none>}" >&2 ; set +e ; return 1 ;;
		esac
		case " $agentsToolOperations " in
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
		:*:--team-member|:*:--session-id|:*:--spawn-id|:*:--select-workspace|:*:--tooling-origin|:--client-*:|:--client-*:--*|:--librarian-*:|:--librarian-*:--*|:--tester-*:|:--tester-*:--*)
			local commonRc=0
			type AgentsToolsCommonRun > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.CommonOptions.include"
			AgentsToolsCommonRun DistroAgentsTools DistroAgentsTools.fn.sh "$@" || commonRc=$?
			[ "$commonRc" = 9 ] || return "$commonRc"
		;;
	esac
	type AgentsToolsMemberWorkspaceResolve > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.MemberWorkspace.include"
	## We run from here: a member named by an operation uses this workspace; one set up elsewhere only has its skillset brought (AgentsToolsMemberSkillsetBring).
	case "$1:${2:-}" in
		--intern-op-agent-spawn-proxy:*|--intern-op-routine-lock-*:*|--intern-merge-md-files:*|--intern-mcp-execute:*|--intern-op-decisions-append:*|--intern-op-review-*:*|--intern-directory-*:*|--owner-workspace-*:*|--make-*:*|--manager-*:*|--session-floor-remove:*|--camunda-diagram-sync-stale:*|*:|*:-*) ;;
		--*:*)
			## An invited member, set up only in another workspace: its operation runs here; only its skillset, and the settings this workspace lacks, are read from there.
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

	## An operation of a tool file that was a --magic-* operation is magic-coordinator's, or the console's: asked in the tool file
	## (AgentsContext.FrontDoor.include, AgentsToolsMagicCallerCheck).
	## A --client-* op naming a client is that client's own session's, or the console's
	## (AgentsToolsClientCallerCheck): one rule for the whole family, asked here and in no
	## stub. magic-coordinator's own way to one is --client-operation-run (AgentDispatcherTools.fn.sh).
	## A --manager-* op is the console's own, and no member's session's, magic-coordinator's
	## among them (AgentsToolsManagerCallerCheck): one rule for the whole family, asked here
	## and in no arm of it.
	## The bare --manager is no --manager-* op: it starts the console app, and admits every
	## caller, exactly as the start of the screen always did. Its own rule, asked here.
	case "$1" in
		--client-*) AgentsToolsClientCallerCheck "${2:-}" "${1#--}" || { set +e ; return 1 ; } ;;
		--manager) ;;
		--manager-*) AgentsToolsManagerCallerCheck "${1#--}" || { set +e ; return 1 ; } ;;
	esac

	## THE JUST-AGENTS GATE (F13.1): a workspace whose mode is no team rig keeps no team data, and refuses the operations that create or change
	## it. The list, and what that mode must not do, are in AgentsTools.TeamDataGate.include. One place, here, before an arm makes a folder
	## or says a word; a write that reaches the team data another way asks the gate itself where it writes.
	type AgentsToolsTeamDataGate > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.TeamDataGate.include"
	AgentsToolsTeamDataGate "$1" || { set +e ; return 1 ; }

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
			## A write into a preset, or of a key that belongs to presets or to the tiers, asks the write check first.
			case "${3:-}" in
				--upsert|--upsert-from-stdin|--upsert-if|--delete|--delete-if)
					case "$2:${4:-}" in
						preset-*:*|*:PRESET_*|*:SPAWN_TIER_*|*:SPAWN_CLI_SERVICE)
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
			## An option is this workspace's own; a read of one that is another workspace's names that workspace (AgentsToolsConfigOptionElsewhere).
			case "${3:-}" in
				--select|--select-default)
					## A spawn setting of the team, where tier settings are configured, is the preset's of the spawn (AgentsToolsPresetOverlay, AgentsTools.Preset.include).
					if [ "$2" = "magic-team" ] ; then
						local overlayOut overlayRc=0
						type AgentsToolsPresetOverlay > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/config/AgentsTools.Preset.include"
						overlayOut="$( AgentsToolsPresetOverlay "${4:-}" )" || overlayRc=$?
						case "$overlayRc" in
							0)
								if [ -n "$overlayOut" ] ; then printf '%s\n' "$overlayOut" ; elif [ "$3" = "--select-default" ] ; then printf '%s\n' "${5:-}" ; fi
								return 0
							;;
							1)
								## The CLI service is the tier's preset's alone: no tier is no CLI service, whatever an old line of the scope still holds (it is not read).
								if [ "${4:-}" = "SPAWN_CLI_SERVICE" ] ; then
									if [ "$3" = "--select-default" ] ; then printf '%s\n' "${5:-}" ; fi
									return 0
								fi
							;;
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
					## A write is this workspace's own; the first setting of a borrowed system ends the borrowing, said once (AgentsToolsMemberSettingsBorrowEndedSay).
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
					## The mirror: the last setting of a system deleted begins the borrowing again, said once (AgentsToolsMemberSettingsBorrowBegunSay).
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

		## Each comms family: the --intern-op-comms-* implementation and the --client-* stubs; the stubs of the members are
		## in the tool files (DistroAgentsSlack, DistroAgentsMail, DistroAgentsTrello, DistroAgentsGoogle, DistroAgentsAtlassian),
		## and the --client-comms-* arm below holds Jira and Confluence.
		--client-comms-slack-*|--intern-op-comms-slack-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.MemberCommsSlack.include"
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

		## The session's title and chapter (F7.2): the implementation behind DistroAgentsSession.fn.sh's
		## --set-session-topic / --set-session-chapter. Lives in AgentsTools.ThisSession.include, same as the
		## other ThisSession operations.
		--intern-op-set-session-topic|--intern-op-set-session-chapter)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.ThisSession.include"
			return $?
		;;

		--client-comms-email-*|--intern-op-comms-email-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.MemberCommsEmail.include"
			return $?
		;;

		--client-comms-trello-*|--intern-op-comms-trello-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.MemberCommsTrello.include"
			return $?
		;;

		--client-comms-google-*|--intern-op-comms-google-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.MemberCommsGoogle.include"
			return $?
		;;

		--intern-op-comms-confluence-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.MemberCommsConfluence.include"
			return $?
		;;

		--intern-op-comms-jira-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.MemberCommsJira.include"
			return $?
		;;

		## Grouped with the Atlassian arms above, as --intern-op-slack-* sits with the Slack routes.
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

		## Sketch 10.6's tester family: `--tester-<operation>` is DistroAgentsTesting.fn.sh `--<operation>`, one thin stub an operation,
		## as the librarian family fronts its own. A name outside the list is refused with the list, so no stub is invented here.
		--tester-*)
			local agentsTesterOperations="apply-tool retest-drain retest-queue retest-result run-all-nightly-regressions run-oldest-untested send-report
				skillset-validate-routine test-invalidate test-list test-register test-unregister test-update"
			testerOperation="${1#--tester-}"
			case " $agentsTesterOperations " in
				*" $testerOperation "*) ;;
				*)
					echo "⛔ ERROR: $MDSC_CMD: --tester-$testerOperation is no testing operation; the family is: $agentsTesterOperations" >&2
					set +e ; return 1
				;;
			esac
			shift
			"$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTesting.fn.sh" --"$testerOperation" "$@"
			return $?
		;;

		## F7.7's stub of the librarian's skillset write, with no logic of its own: --librarian-skillset-upsert is AgentLibrarianTools.fn.sh --skillset-upsert.
		--librarian-skillset-upsert)
			shift
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/AgentLibrarianTools.fn.sh"
			AgentLibrarianTools --skillset-upsert "$@"
			return $?
		;;

		## K2's stub of the librarian's queue close, with no logic of its own: --queue-done is AgentLibrarianTools.fn.sh --queue-done, so a pending
		## question's allow answer applies the edit through AgentsToolsAuthorityRequestAct (the action it keeps beside it).
		--queue-done)
			shift
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/AgentLibrarianTools.fn.sh"
			AgentLibrarianTools --queue-done "$@"
			return $?
		;;

		--librarian-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.Librarian.include"
			return $?
		;;

		## The long-poll operation is its own file, not a Member.include arm.
		--intern-op-wait-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.MemberWait.include"
			return $?
		;;

		--intern-op-escalation-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/questions/AgentsTools.MemberEscalation.include"
			return $?
		;;

		## A board item's `## Decisions`: the tooling's append and the member stub.
		--intern-op-decisions-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.InternOpDecisions.include"
			return $?
		;;

		## A dispatched item's review: into review, the verdicts, the ordered endings.
		--intern-op-review-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.InternOpReview.include"
			return $?
		;;

		--intern-op-member-work-session-input-scan)
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

		## The librarian's spread and retire of the knowledge store (F8.3), beside the installer.
		--knowledge-store-spread|--knowledge-store-retire)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.KnowledgeStore.include"
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

		--intern-team-data-reflection-sweep)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.InternTeamDataReflectionSweep.include"
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
			local execStatus=0 execFile
			## The tool files (the table of sh-lib/harness/AgentsContext.FrontTable.include) are commands of the script, as DistroAgentsTools is: each stands
			## as a function that loads its file at its first call.
			type AgentsToolsFrontAny > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontTable.include"
			for execFile in $( printf '%s\n' "$agentsFrontTable" | LC_ALL=C awk -F'\t' 'NF == 3 && $1 !~ /^--/ { print $1 }' | LC_ALL=C sort -u ) ; do
				type "$execFile" > /dev/null 2>&1 || eval "$execFile(){ unset -f $execFile ; . \"\$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/$execFile.fn.sh\" ; $execFile \"\$@\" ; }"
			done
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
		--intern-op-grooming-input-scan)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicGrooming.include"
			return $?
		;;

		--intern-op-sweep-input-scan)
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

		## The update of the locked document of a session's routine (F6.2): ThisSession's --update-routine-state reaches it here.
		--intern-op-update-routine-state)
			shift
			type AgentsToolsRoutineSessionStateUpdate > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.RoutineLock.include"
			AgentsToolsRoutineSessionStateUpdate "$@"
			return $?
		;;

		## A member's own delivery floor, removed for a while (timed): while the seconds last, the session chat floor is not delivered
		## (AgentsToolsSessionChatFloorRemove, AgentsTools.SessionChat.include). The member is the run's own, as the served harness takes
		## it; a native root caller is magic-coordinator's. Prints `FLOOR-REMOVED <member> <seconds>`.
		--session-floor-remove)
			shift
			local floorRemoveSeconds="${1:-}" floorRemoveMember floorRemoveKey
			shift 2>/dev/null || shift $#
			case "$floorRemoveSeconds" in
				''|*[!0123456789]*|0|0[0123456789]*)
					echo "$MDSC_CMD: ⛔ ERROR: --session-floor-remove takes whole seconds, 1 or more, got: ${floorRemoveSeconds:-<none>}" >&2
					set +e ; return 1
				;;
			esac
			type AgentsToolsSessionChatFloorRemove > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionChat.include"
			floorRemoveKey="$( AgentsToolsSessionChatKey )"
			floorRemoveMember="${harnessAgent:-${MDAT_SPAWN_AGENT:-magic-coordinator}}"
			if [ -z "$floorRemoveKey" ] ; then
				echo "$MDSC_CMD: ⛔ ERROR: --session-floor-remove: the call belongs to no session, so there is no floor to remove" >&2
				set +e ; return 1
			fi
			AgentsToolsSessionChatFloorRemove "$floorRemoveKey" "$floorRemoveMember" "$floorRemoveSeconds" || { set +e ; return 1 ; }
			printf 'FLOOR-REMOVED %s %s\n' "$floorRemoveMember" "$floorRemoveSeconds"
			return 0
		;;

		## partner-ndm-camunda's diagram sync (routine-camunda-diagram-sync), made mechanical: the newest team-definition
		## mtime against each diagram's, the stale diagrams printed. <definitions-dir> <diagrams-dir>. The agent only decides.
		--camunda-diagram-sync-stale)
			shift
			local camundaDefs="${1:-}" camundaDiagrams="${2:-}"
			shift 2 2>/dev/null || shift $#
			if [ -z "$camundaDefs" ] || [ -z "$camundaDiagrams" ] ; then
				echo "$MDSC_CMD: ⛔ ERROR: --camunda-diagram-sync-stale: syntax is <definitions-dir> <diagrams-dir>" >&2
				set +e ; return 1
			fi
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.CamundaDiagramSync.include"
			AgentsToolsCamundaDiagramSyncStale "$camundaDefs" "$camundaDiagrams" || {
				echo "$MDSC_CMD: ⛔ ERROR: --camunda-diagram-sync-stale: both arguments must be directories: $camundaDefs, $camundaDiagrams" >&2
				set +e ; return 1
			}
			return 0
		;;

		## The take and the giving back of the standing lock of a routine (advance, daily, grooming or retro) are the spawner's own: its functions, and these two
		## operations for the shell and the checks. <routine word> <team-member> [<owner label>].
		--intern-op-routine-lock-take|--intern-op-routine-lock-close)
			local routineLockOp="$1" routineLockFn
			shift
			type AgentsToolsRoutineLockTakeOwn > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.RoutineLock.include"
			case "$routineLockOp" in
				--intern-op-routine-lock-take) routineLockFn=AgentsToolsRoutineLockTakeOwn ;;
				*) routineLockFn=AgentsToolsRoutineLockCloseOwn ;;
			esac
			"$routineLockFn" "$@"
			return $?
		;;

		## The console's release of a lock whose holder has no record (F6.2): <value> [<reason>]. Refuses where the lock
		## is finished or holds no session, or where a spawn record still names its holder; else gives the lock back.
		--intern-op-routine-lock-release)
			shift
			type AgentsToolsRoutineLockReleaseConsole > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.RoutineLock.include"
			AgentsToolsRoutineLockReleaseConsole "$@"
			return $?
		;;

		--intern-op-routine-coworking-session-input-scan)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.RoutineCoworking.include"
			return $?
		;;

		--intern-op-state-note-upsert)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicCoordinatorState.include"
			return $?
		;;

		## magic-librarian.morning-review.routine: its input scan. The cut-off is the routine's own state, updated with --update-routine-state.
		--intern-op-morning-review-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.InternOpMorningReview.include"
			return $?
		;;

		## The per-member sync of a member's own incoming (T2): its mailbox and Trello refilled at once into its inbox, and its tags, its
		## DMs and its session chat force-read through their readers, whatever their TTLs, one line a source. The tooling's own; the
		## spawner calls it at a member's start (the `start` scope, the personal mail alone), and a member or the console can call it to
		## sync at once. Takes the member first.
		--intern-op-member-incoming-sync)
			shift
			local incomingMember="${1:-}"
			if [ -z "$incomingMember" ] ; then
				echo "$MDSC_CMD: member-incoming-sync: ⛔ ERROR: syntax is <team-member>" >&2
				set +e ; return 1
			fi
			AgentsToolsAssertBareName "$incomingMember" "<team-member>" member-incoming-sync || { set +e ; return 1 ; }
			if [ ! -d "$MDAT_SKILLSET_ROOT/$incomingMember" ] ; then
				echo "$MDSC_CMD: member-incoming-sync: ⛔ ERROR: no such member skill directory: $MDAT_SKILLSET_ROOT/$incomingMember" >&2
				set +e ; return 1
			fi
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.Incoming.include"
			AgentsToolsIncomingSync "$incomingMember"
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

		## The coordinator's append to any session's transcript, and the implementation both stubs call.
		--intern-op-append-session-transcript)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.Member.include"
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

		## A bare call takes the default syntax, not --help-syntax: the whole
		## operation list is what --help-syntax is asked for by name. A bare call
		## names no operation, so it ends 1; --help asked for the manual, so it ends 0.
		if [ -z "$1" ] ; then
			DistroAgentsTools
			exit 1
		fi
		if [ "$1" = "--help" ] ; then
			DistroAgentsTools --help
			exit 0
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
