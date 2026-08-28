#!/usr/bin/env bash

##
## NOTE:
## Designed to be able to run without distro context. Starts console sessions.
##

if [ -z "$MMDAPP" ] ; then
	set -e
	export MMDAPP="$( cd $(dirname "$0")/../../../.. ; pwd )"
	echo "$0: Working in: $MMDAPP"  >&2
	[ -d "$MMDAPP/.local" ] || ( echo "⛔ ERROR: expecting '.local' directory." >&2 && exit 1 )
fi

: "${MDLT_ORIGIN:=$MMDAPP/.local}"
export MDLT_ORIGIN

## Resolves alias|<channel>|<channel>:<ts> to CHANNEL= + THREAD_TS=; shared by every op taking a target.
DistroAgentsToolsResolveTarget(){
	local target="$1"
	local channel threadTs
	case "$target" in
		event-track|event-track:*)
			channel="$( DistroAgentsTools --agents-config-option magic-coordinator --select SLACK_CHANNEL_EVENT_TRACK )"
			case "$target" in *:*) threadTs="${target#*:}" ;; esac
		;;
		event-alert|event-alert:*)
			channel="$( DistroAgentsTools --agents-config-option magic-coordinator --select SLACK_CHANNEL_EVENT_ALERT )"
			case "$target" in *:*) threadTs="${target#*:}" ;; esac
		;;
		magic-team|magic-team:*)
			channel="$( DistroAgentsTools --agents-config-option magic-coordinator --select SLACK_CHANNEL_MAGIC_TEAM )"
			case "$target" in *:*) threadTs="${target#*:}" ;; esac
		;;
		human-owner|human-owner:*)
			channel="$( DistroAgentsTools --agents-config-option magic-coordinator --select SLACK_CHANNEL_HUMAN_OWNER )"
			case "$target" in *:*) threadTs="${target#*:}" ;; esac
		;;
		*:*)
			channel="${target%%:*}"
			threadTs="${target#*:}"
		;;
		## Bare uppercase id: a whole conversation, so THREAD_TS stays empty and the send posts at top level.
		## Must stay after `*:*`, and never a [A-Z] range -- bracket ranges are collation-dependent.
		?????????*)
			local bareRest="$target" bareChar bareFirst="true"
			while [ -n "$bareRest" ] ; do
				bareChar="${bareRest%"${bareRest#?}"}"
				bareRest="${bareRest#?}"
				case "$bareChar" in
					A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z) ;;
					0|1|2|3|4|5|6|7|8|9)
						[ "$bareFirst" = "false" ] || return 2
					;;
					*)
						return 2
					;;
				esac
				bareFirst="false"
			done
			channel="$target"
		;;
		*)
			return 2
		;;
	esac
	if [ -z "$channel" ] ; then
		return 1
	fi
	printf 'CHANNEL=%s\nTHREAD_TS=%s\n' "$channel" "$threadTs"
	return 0
}

## The bare-name gate for the whole family: one path segment of letters, digits, '.', '_', '-'.
## Reports and returns 1, never exits. Never a [a-z] range -- bracket ranges are collation-dependent.
AgentsToolsAssertBareName(){
	local nameValue="$1"
	local nameLabel="$2"
	local nameContext="$3"
	case "$nameValue" in
		''|.|..|-*|*/*)
			echo "$MDSC_CMD: $nameContext: ❗ ASSERT: $nameLabel must be a bare name -- one path segment of letters, digits, '.', '_' or '-', not '.'/'..', no leading '-', no '/': $nameValue" >&2
			return 1
		;;
	esac
	local nameRest="$nameValue" nameChar
	while [ -n "$nameRest" ] ; do
		nameChar="${nameRest%"${nameRest#?}"}"
		nameRest="${nameRest#?}"
		case "$nameChar" in
			a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z) ;;
			A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z) ;;
			0|1|2|3|4|5|6|7|8|9) ;;
			-|_|.) ;;
			*)
				echo "$MDSC_CMD: $nameContext: ❗ ASSERT: $nameLabel contains a character outside the allowed set (letters, digits, '.', '_', '-'): $nameValue" >&2
				return 1
			;;
		esac
	done
	return 0
}

DistroAgentsTools(){
	local MDSC_CMD='DistroAgentsTools'
	[ -z "$MDSC_DETAIL" ] || echo "> $MDSC_CMD $@" >&2
	set -e

	if [ "$1" != "--agents-config-option" ] ; then
		if [ -z "${MDAT_DATA_ROOT:-}" ] ; then
			local teamDataDir
			teamDataDir="$(
				set -- --agents-config-option magic-coordinator --select TEAM_DATA_DIRECTORY
				. "$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/LocalTools.Config.include"
			)" || teamDataDir=""
			if [ -n "$teamDataDir" ] ; then
				case "$teamDataDir" in
					/*) MDAT_DATA_ROOT="$teamDataDir" ;;
					*)
						if [ -d "$MMDAPP/$teamDataDir" ] ; then
							MDAT_DATA_ROOT="$MMDAPP/$teamDataDir"
						elif [ -d "$MMDAPP/source/$teamDataDir" ] ; then
							MDAT_DATA_ROOT="$MMDAPP/source/$teamDataDir"
						else
							MDAT_DATA_ROOT="$MMDAPP/$teamDataDir"
						fi
					;;
				esac
				export MDAT_DATA_ROOT
			fi
		fi
	fi

	case "$1" in
		--console-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.ConsoleSession.include"
			return $?
		;;


		--agents-config-option)
			. "$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/LocalTools.Config.include"
			return $?
		;;

		--member-config-option)
			shift
			: ${1:?"⛔ ERROR: --member-config-option requires <member-name> argument to follow!"}
			local scopeMemberName="$1"
			shift
			DistroAgentsTools --agents-config-option "$scopeMemberName" "$@"
			return $?
		;;

		--members)
			shift
			case "$1" in
				--backend)
					shift
					DistroAgentsTools --member-config-option "$@"
					return $?
				;;
				*)
					echo "⛔ ERROR: $MDSC_CMD --members expects: --backend <member-name> <operation> [args...]" >&2
					set +e ; return 1
				;;
			esac
		;;

		## These globs are safe only while every --member-comms-<service>-* op lives in its own platform include.
		## Must stay ahead of the --member-* route below, which would otherwise take every op they match.
		--member-comms-slack-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MemberCommsSlack.include"
			return $?
		;;

		--member-comms-email-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MemberCommsEmail.include"
			return $?
		;;

		--member-comms-trello-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MemberCommsTrello.include"
			return $?
		;;

		--member-comms-google-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MemberCommsGoogle.include"
			return $?
		;;

		--member-comms-confluence-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MemberCommsConfluence.include"
			return $?
		;;

		--member-comms-jira-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MemberCommsJira.include"
			return $?
		;;

		--magic-comms-slack-resolve-ids)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MagicComms.include"
			return $?
		;;

		--verify-permissions)
			shift
			local dir="$MMDAPP/.local/.agents"
			if [ ! -d "$dir" ] ; then
				echo "# $MDSC_CMD --verify-permissions: $dir does not exist yet (nothing to verify)" >&2
				return 0
			fi

			local failed=0
			local perm
			perm="$( stat -f '%Lp' "$dir" 2>/dev/null || stat -c '%a' "$dir" 2>/dev/null )"
			if [ "$perm" = "700" ] ; then
				echo "OK   700  $dir"
			else
				echo "BAD  ${perm:-?}  $dir  (expected 700)"
				failed=1
			fi

			local f
			for f in "$dir"/* ; do
				[ -e "$f" ] || continue
				perm="$( stat -f '%Lp' "$f" 2>/dev/null || stat -c '%a' "$f" 2>/dev/null )"
				if [ "$perm" = "600" ] ; then
					echo "OK   600  $f"
				else
					echo "BAD  ${perm:-?}  $f  (expected 600)"
					failed=1
				fi
			done

			if [ "$failed" = "1" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --verify-permissions: one or more paths under $dir are not hardened to 600/700" >&2
				set +e ; return 1
			fi
			echo "# $MDSC_CMD --verify-permissions: all paths under $dir are correctly hardened (700 dir / 600 files)" >&2
			return 0
		;;

		--self-test)
			shift
			echo "# $MDSC_CMD --self-test: exercising --agents-config-option permission-hardening under umask 022 (ignoring caller's ambient umask)" >&2

			local probeKey="DAT_SELFTEST_PROBE"
			local probeVal="selftest-$$-$( date +%s )"
			local failed=0

			if ! ( umask 022 ; DistroAgentsTools --agents-config-option magic-coordinator --upsert "$probeKey" "$probeVal" >/dev/null ) ; then
				echo "⛔ ERROR: $MDSC_CMD --self-test: --upsert under umask 022 failed" >&2
				set +e ; return 1
			fi

			DistroAgentsTools --verify-permissions || failed=1

			local readBack
			readBack="$( DistroAgentsTools --agents-config-option magic-coordinator --select "$probeKey" )"
			if [ "$readBack" != "$probeVal" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --self-test: probe key round-trip mismatch" >&2
				failed=1
			fi

			DistroAgentsTools --agents-config-option magic-coordinator --delete "$probeKey" >/dev/null

			if [ "$failed" = "1" ] ; then
				echo "⛔ $MDSC_CMD --self-test: FAILED" >&2
				set +e ; return 1
			fi
			echo "# $MDSC_CMD --self-test: PASSED -- permission hardening holds under umask 022" >&2
			return 0
		;;

		--purge-cleanup)
			shift
			if [ $# -gt 0 ] ; then
				echo "⛔ ERROR: $MDSC_CMD --purge-cleanup: takes no arguments -- always purges $MMDAPP/.local/.cleanup" >&2
				set +e ; return 1
			fi
			local cleanupDir="$MMDAPP/.local/.cleanup"
			if [ ! -d "$cleanupDir" ] ; then
				echo "# $MDSC_CMD --purge-cleanup: $cleanupDir does not exist -- nothing to purge" >&2
				return 0
			fi
			echo "# $MDSC_CMD --purge-cleanup: purging all contents of $cleanupDir (folder itself stays)" >&2
			local entry
			for entry in "$cleanupDir"/* "$cleanupDir"/.[!.]* ; do
				[ -e "$entry" ] || [ -L "$entry" ] || continue
				echo "  rm -rf $entry" >&2
				rm -rf -- "$entry"
			done
			echo "# $MDSC_CMD --purge-cleanup: done" >&2
			return 0
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

		--member-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.Member.include"
			return $?
		;;

		--write-inbox-note)
			shift
			DistroAgentsTools --member-upsert-inbox-note "$@" || return 1
			return 0
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

		--intern-op-session-context-scan)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpSessionContextScan.include"
			return $?
		;;

		--intern-op-board-trash)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpBoardTrash.include"
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

		--intern-op-item-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpItem.include"
			return $?
		;;

		--intern-op-slack-call)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpSlackCall.include"
			return $?
		;;

		--intern-op-slack-check)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpSlackCheck.include"
			return $?
		;;

		--intern-op-check-slack-scopes)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpCheckSlackScopes.include"
			return $?
		;;

		--intern-op-check-configs)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpCheckConfigs.include"
			return $?
		;;

		--intern-op-data-read)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpDataRead.include"
			return $?
		;;

		--intern-op-agent-spawn-proxy)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpAgentSpawnProxy.include"
			return $?
		;;

		--intern-mcp-server)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternMcpServer.include"
			return $?
		;;

		--intern-main-loop)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternMainLoop.include"
			return $?
		;;

		--intern-mcp-execute)
			shift
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
				echo "$MDSC_CMD: config-board-location: ⛔ ERROR: TEAM_DATA_DIRECTORY is not configured" >&2
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

		--magic-comms-trello-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MagicTrello.include"
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

		--magic-team-roster-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MagicTeamRoster.include"
			return $?
		;;


		--help|--help-syntax|'')
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

		if [ -z "$MDLT_OPTION" ] || ! type DistroAgentsContext >/dev/null 2>&1 ; then
			. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib/AgentsContext.include"
		fi
		DistroAgentsContext --run-from-detect

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

		if [ -z "$1" ] || [ "$1" = "--help" ] ; then
			DistroAgentsTools "${1:-"--help-syntax"}"
			exit 1
		fi

		DistroAgentsTools "$@"
	;;
esac
