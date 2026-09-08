#!/usr/bin/env bash

set -e

if [ -z "$MMDAPP" ] || [ ! -d "$MMDAPP" ] ; then
	MMDAPP="$( ( cd "$( dirname "$0" )" && pwd ) )" || MMDAPP=""
	if [ -z "$MMDAPP" ] ; then
		echo "⛔ ERROR: cannot resolve this console's own directory from '$0'." >&2
		exit 1
	fi
fi

[ -d "$MMDAPP/.local" ] || ( echo "⛔ ERROR: expecting '$MMDAPP/.local' directory." >&2 && exit 1 )

MDLT_CONSOLE_ORIGIN="$( ( \
	. "$MMDAPP/.local/MDLT.settings.env" ; \
	echo "${MDLT_CONSOLE_ORIGIN:-.local}" \
) )"
MDLC_INMODE="${MDLT_CONSOLE_ORIGIN#$MMDAPP/}"
case "$MDLC_INMODE" in
	.local)
		export MDLT_ORIGIN="$MMDAPP/.local"
	;;
	source)
		if [ -f "$MMDAPP/source/myx/myx.distro-agents/sh-lib/AgentsContext.include" ] ; then
			export MDLT_ORIGIN="$MMDAPP/$MDLC_INMODE"
		else
			export MDLT_ORIGIN="$MMDAPP/.local"
		fi
	;;
	/*)
		if [ -f "$MDLC_INMODE/myx/myx.distro-agents/sh-lib/AgentsContext.include" ] ; then
			export MDLT_ORIGIN="$MDLC_INMODE"
		else
			export MDLT_ORIGIN="$MMDAPP/.local"
		fi
	;;
	*)
		export MDLT_ORIGIN="$MMDAPP/.local"
	;;
esac
if [ ! -f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsContext.include" ] ; then
	echo "⛔ ERROR: AgentsContext.SetInputSpec: can't find/detect origin, spec: $MDLT_CONSOLE_ORIGIN, origin: $MDLT_ORIGIN" >&2
	exit 1
fi

cd "$MMDAPP"
export MMDAPP

DAGC_KNOWN_CLIS="copilot claude grok"
DAGC_NONINTERACTIVE_CLIS="copilot claude"
DAGC_CLI="copilot"
DAGC_CLI_GIVEN="false"
DAGC_CLI_AUTO="false"
DAGC_CLI_CONFIGURED="false"
while true ; do
	case "$1" in
		--cli-auto)
			DAGC_CLI_AUTO="true"
			shift
		;;
		--cli-configured)
			DAGC_CLI_AUTO="true"
			DAGC_CLI_CONFIGURED="true"
			shift
		;;
		--cli)
			if [ -z "$2" ] ; then
				echo "⛔ ERROR: DistroAgentsConsole: --cli requires a value (known: $DAGC_KNOWN_CLIS)" >&2
				exit 1
			fi
			DAGC_CLI="$2"
			DAGC_CLI_GIVEN="true"
			shift 2
		;;
		*)
			break
		;;
	esac
done
# --cli-auto takes magic-team's own SPAWN_CLI_SERVICE where it is set, else the first installed known CLI.
# --cli-configured takes the same setting and stops there: an unset setting means no external CLI was chosen,
# which is a different answer from "none could be started" and is reported as rc=5 so a caller can branch on it.
if [ "$DAGC_CLI_AUTO" = "true" ] ; then
	DAGC_CLI_GIVEN="false"
	## Tested, not bare: set -e would kill the console on an unreadable scope instead of falling through to the scan below.
	DAGC_CLI_SERVICE="$( "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --agents-config-option magic-team --select SPAWN_CLI_SERVICE 2>/dev/null )" || DAGC_CLI_SERVICE=""
	if [ -n "$DAGC_CLI_SERVICE" ] ; then
		# Its name, its non-interactive capability and its presence in PATH are each checked below, at their own use site.
		DAGC_CLI="$DAGC_CLI_SERVICE"
		DAGC_CLI_GIVEN="true"
	elif [ "$DAGC_CLI_CONFIGURED" = "true" ] ; then
		echo "⛔ ERROR: DistroAgentsConsole: SPAWN_CLI_SERVICE is not configured in this workspace, so no external agent CLI is selected here. rc=5 means exactly this -- nothing was chosen to start, which is distinct from rc=1 (something was chosen and could not be started). Spawn an internal agent instead, or select one with: $MMDAPP/.local/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh --owner-setup-claude --apply" >&2
		exit 5
	else
		for DAGC_AUTO_CLI in $DAGC_KNOWN_CLIS ; do
			if [ "$1" == "--non-interactive" ] ; then
				case " $DAGC_NONINTERACTIVE_CLIS " in
					*" $DAGC_AUTO_CLI "*) ;;
					*)
						continue
					;;
				esac
			fi
			if command -v "$DAGC_AUTO_CLI" >/dev/null 2>&1 ; then
				DAGC_CLI="$DAGC_AUTO_CLI"
				DAGC_CLI_GIVEN="true"
				break
			fi
		done
		if [ "$DAGC_CLI_GIVEN" != "true" ] && [ "$1" == "--non-interactive" ] ; then
			echo "⛔ ERROR: DistroAgentsConsole: --cli-auto found no supported non-interactive CLI in PATH (tried: $DAGC_NONINTERACTIVE_CLIS)." >&2
			exit 1
		fi
	fi
fi
case "$DAGC_CLI" in
	copilot|claude|grok) ;;
	*)
		echo "⛔ ERROR: DistroAgentsConsole: unsupported --cli: $DAGC_CLI (known: $DAGC_KNOWN_CLIS)" >&2
		exit 1
	;;
esac
if [ "$1" == "--non-interactive" ] ; then
	case " $DAGC_NONINTERACTIVE_CLIS " in
		*" $DAGC_CLI "*) ;;
		*)
			echo "⛔ ERROR: DistroAgentsConsole: --non-interactive is currently supported only for: $DAGC_NONINTERACTIVE_CLIS (got: $DAGC_CLI)." >&2
			exit 1
		;;
	esac
fi
if [ "$DAGC_CLI_GIVEN" = "true" ] ; then
	command -v "$DAGC_CLI" >/dev/null 2>&1 || {
		echo "⛔ ERROR: DistroAgentsConsole: '$DAGC_CLI' CLI not found in PATH -- install it first; it was selected explicitly (--cli, or magic-team's SPAWN_CLI_SERVICE), so this does not fall back to a bash session." >&2
		exit 1
	}
elif ! command -v "$DAGC_CLI" >/dev/null 2>&1 ; then
	for DAGC_FALLBACK_CLI in $DAGC_KNOWN_CLIS ; do
		if [ "$DAGC_FALLBACK_CLI" = "$DAGC_CLI" ] ; then
			continue
		fi
		if [ "$1" == "--non-interactive" ] ; then
			case " $DAGC_NONINTERACTIVE_CLIS " in
				*" $DAGC_FALLBACK_CLI "*) ;;
				*)
					continue
				;;
			esac
		fi
		if command -v "$DAGC_FALLBACK_CLI" >/dev/null 2>&1 ; then
			DAGC_CLI="$DAGC_FALLBACK_CLI"
			break
		fi
	done
	if command -v "$DAGC_CLI" >/dev/null 2>&1 ; then
		:
	else
		exec bash --rcfile "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/console-agents-bashrc.rc" -i
	fi
fi

DAGC_MYXROOT="$MDLT_ORIGIN/myx/myx.common/os-myx.common/host/tarball/share/myx.common"
if [ -x "$DAGC_MYXROOT/bin/setup/agentMcp.Common" ] ; then
	MYXROOT="$DAGC_MYXROOT" MYX_AGENTMCP_TARGET_CWD="$MMDAPP" "$DAGC_MYXROOT/bin/setup/agentMcp.Common" >/dev/null 2>&1 || :
elif command -v myx.common >/dev/null 2>&1 ; then
	MYX_AGENTMCP_TARGET_CWD="$MMDAPP" myx.common setup/agentMcp >/dev/null 2>&1 || :
fi

## Copilot and claude: read the prepared access fragment (the installer wrote
## it via DistroAgentsTools --install-copilot-access-fragment) into the CLI's
## launch argv as `--add-dir <root>` tokens, granting the same read/write
## directory access the claude settings writers grant. Claude takes the same
## tokens because its settings.json carries permission RULES for those roots
## but does not put the directories themselves in the session -- `--add-dir`
## is what does that, and both CLIs spell the flag identically. Absent/empty
## fragment -> no tokens added; grok gets nothing (out of scope). One token
## per line, so a root containing spaces survives being read back into the
## array intact. The DAGC_COPILOT_* names, the fragment's own filename and
## the installer op that writes it all predate claude being included here and
## are left exactly as they are: renaming them is its own change, across the
## installer and its help, not a side effect of widening this branch.
DAGC_COPILOT_ADDDIR=()
if [ "$DAGC_CLI" = "copilot" ] || [ "$DAGC_CLI" = "claude" ] ; then
	DAGC_COPILOT_FRAGMENT="$MMDAPP/.claude/copilot-add-dir.fragment"
	if [ -f "$DAGC_COPILOT_FRAGMENT" ] ; then
		while IFS= read -r DAGC_COPILOT_TOKEN ; do
			[ -n "$DAGC_COPILOT_TOKEN" ] || continue
			DAGC_COPILOT_ADDDIR+=( "$DAGC_COPILOT_TOKEN" )
		done < "$DAGC_COPILOT_FRAGMENT"
	fi
fi

## The selected CLI's own credential variables, out of this workspace's config
## and into the environment the exec below inherits. Nothing else hands a
## spawned CLI a credential -- the spawn proxy passes only MMDAPP -- so without
## this a workspace can be fully set up and still start an agent that cannot
## authenticate. Each name is the CLI's own documented variable, so the stored
## key and the exported name are one string. Only a non-empty stored value is
## exported: an empty one reads as set to the CLI and would defeat its own
## keychain or credential-store login on a machine configured that way. The
## value moves through a shell variable into a builtin export, so it reaches no
## process argv, no log and no output.
case "$DAGC_CLI" in
	claude)  DAGC_CLI_CREDENTIALS="ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN" ;;
	copilot) DAGC_CLI_CREDENTIALS="COPILOT_GITHUB_TOKEN" ;;
	*)       DAGC_CLI_CREDENTIALS="" ;;
esac
for DAGC_CREDENTIAL_NAME in $DAGC_CLI_CREDENTIALS ; do
	## Tested, not bare: set -e would kill the console on an unreadable scope.
	DAGC_CREDENTIAL_VALUE="$( "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --agents-config-option magic-team --select "$DAGC_CREDENTIAL_NAME" 2>/dev/null )" || DAGC_CREDENTIAL_VALUE=""
	[ -n "$DAGC_CREDENTIAL_VALUE" ] || continue
	export "$DAGC_CREDENTIAL_NAME=$DAGC_CREDENTIAL_VALUE"
done

## The spawn proxy mints this session uuid, records it on its own dispatch
## document and exports it here, so a hook's own session_id joins that record.
## Only claude takes the flag: on any other CLI it is reported and dropped
## rather than silently ignored, since the dispatch record would otherwise name
## a session nothing else ever reports.
DAGC_SESSION_ID_ARGS=()
if [ -n "$MDAT_SPAWN_SESSION_ID" ] ; then
	if [ "$DAGC_CLI" = "claude" ] ; then
		DAGC_SESSION_ID_ARGS=( --session-id "$MDAT_SPAWN_SESSION_ID" )
	else
		echo "🙋 WARNING: DistroAgentsConsole: MDAT_SPAWN_SESSION_ID is set but '$DAGC_CLI' has no --session-id flag -- this spawn runs without it, and its dispatch record will not join the agent's own session" >&2
	fi
fi

## The acting member, named by the spawn proxy. The agent is defined inline at
## spawn rather than as a standing file: members ship as skills, and a standing
## definition would make one member exist twice. `--agent` then selects it, so
## a hook reports the member name rather than the generic agent type. claude
## only, and the name is checked against a bare-token set before it is placed
## inside the JSON, so no member name can alter the document's structure.
DAGC_AGENT_ARGS=()
if [ -n "$MDAT_SPAWN_AGENT" ] ; then
	if [ "$DAGC_CLI" != "claude" ] ; then
		echo "🙋 WARNING: DistroAgentsConsole: MDAT_SPAWN_AGENT is set but '$DAGC_CLI' has no --agent/--agents flag -- this spawn runs without them, and its hooks report the generic agent type rather than $MDAT_SPAWN_AGENT" >&2
	else
		case "$MDAT_SPAWN_AGENT" in
			''|*[!a-zA-Z0-9._-]*)
				echo "⛔ ERROR: DistroAgentsConsole: MDAT_SPAWN_AGENT is not a bare member name: $MDAT_SPAWN_AGENT" >&2
				exit 1
			;;
		esac
		DAGC_AGENT_ARGS=(
			--agents "{\"$MDAT_SPAWN_AGENT\":{\"description\":\"magic-team member $MDAT_SPAWN_AGENT\",\"prompt\":\"You are $MDAT_SPAWN_AGENT, a magic-team member. Read your own skill files before acting.\"}}"
			--agent "$MDAT_SPAWN_AGENT"
		)
	fi
fi

## claude only: piping its own JSON-lines stream through the awk formatter is
## what makes -p's silent batch mode show live progress. exec'ing a pipeline
## would break the spawn proxy's PID-based timeout kill, so claude runs
## backgrounded with its real PID captured, and TERM/INT are forwarded to it.
DagcRunClaudeStreaming(){
	local claudePrompt="$1" streamAwkPath claudePid awkPid claudeStatus
	streamAwkPath="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsClaudeStreamJsonFormat.awk"
	exec 3> >( LC_ALL=C awk -f "$streamAwkPath" )
	awkPid=$!
	"$DAGC_CLI" --verbose --output-format stream-json "${DAGC_COPILOT_ADDDIR[@]}" "${DAGC_SESSION_ID_ARGS[@]}" "${DAGC_AGENT_ARGS[@]}" "${DAGC_PROMPT_ARGS[@]}" "$claudePrompt" >&3 &
	claudePid=$!
	## Installed immediately after capture, before anything else -- including
	## the otherwise-harmless `exec 3>&-` below -- so there is no window in
	## which a TERM/INT arriving here would fall through to bash's default
	## disposition and leave $claudePid running unsignaled.
	trap 'kill -TERM "$claudePid" 2>/dev/null' TERM INT
	exec 3>&-
	claudeStatus=0
	wait "$claudePid" || claudeStatus=$?
	while kill -0 "$claudePid" 2>/dev/null ; do
		claudeStatus=0
		wait "$claudePid" || claudeStatus=$?
	done
	wait "$awkPid" 2>/dev/null || :
	exit "$claudeStatus"
}

if [ "$1" == "--non-interactive" ] ; then
	shift
	## -- closes the option list for claude, whose prompt is positional; copilot's -p takes the body as its value.
	case "$DAGC_CLI" in
		copilot) DAGC_NONINTERACTIVE_PERM_FLAGS="--allow-all-tools" ; DAGC_PROMPT_ARGS=( -p ) ;;
		*) DAGC_NONINTERACTIVE_PERM_FLAGS="" ; DAGC_PROMPT_ARGS=( -p -- ) ;;
	esac
	## The launch signal, on its own channel: the stdout line below shares a stream with the agent's own output.
	[ -z "$MDAT_SPAWN_LAUNCH_MARKER" ] || printf '%s\n' "$DAGC_CLI" > "$MDAT_SPAWN_LAUNCH_MARKER"
	if [ $# -gt 0 ] ; then
		echo "DISTRO_CONSOLE_EXEC=$DAGC_CLI"
		if [ "$DAGC_CLI" = "claude" ] ; then
			DagcRunClaudeStreaming "$*"
		fi
		exec "$DAGC_CLI" $DAGC_NONINTERACTIVE_PERM_FLAGS "${DAGC_COPILOT_ADDDIR[@]}" "${DAGC_SESSION_ID_ARGS[@]}" "${DAGC_AGENT_ARGS[@]}" "${DAGC_PROMPT_ARGS[@]}" "$*"
	fi
	echo "DISTRO_CONSOLE_EXEC=$DAGC_CLI"
	if [ "$DAGC_CLI" = "claude" ] ; then
		DagcRunClaudeStreaming "$( cat )"
	fi
	exec "$DAGC_CLI" $DAGC_NONINTERACTIVE_PERM_FLAGS "${DAGC_COPILOT_ADDDIR[@]}" "${DAGC_SESSION_ID_ARGS[@]}" "${DAGC_AGENT_ARGS[@]}" "${DAGC_PROMPT_ARGS[@]}" "$( cat )"
fi

echo "DISTRO_CONSOLE_EXEC=$DAGC_CLI"
exec "$DAGC_CLI" "${DAGC_COPILOT_ADDDIR[@]}" "${DAGC_SESSION_ID_ARGS[@]}" "${DAGC_AGENT_ARGS[@]}" "$@"
