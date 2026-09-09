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

DAGC_KNOWN_CLIS="copilot claude grok scaleway"
## scaleway added here on a real, live-confirmed round-trip through this
## console itself (--cli scaleway --non-interactive, end to end) -- not
## speculatively. It has no interactive shape at all (no real binary, no
## REPL; the harness runs one request/response tool-calling cycle and
## exits), which is exactly why it belongs in this list and nowhere else:
## grok is the opposite case (a real interactive binary, not yet proven
## non-interactive), scaleway is proven non-interactive and categorically
## cannot be the other thing. See MAGIC.md.
DAGC_NONINTERACTIVE_CLIS="copilot claude scaleway"
DAGC_CLI="copilot"
DAGC_CLI_GIVEN="false"
DAGC_CLI_AUTO="false"
DAGC_CLI_CONFIGURED="false"
## scaleway has no real binary at all -- `command -v scaleway` can never
## succeed on any machine -- so every presence check in this file goes
## through here instead, exactly as `--owner-setup-scaleway`'s own
## install-probe already had to (a file test, not a PATH lookup; see
## AgentsTools.Owner.include and MAGIC.md).
DagcCliPresent(){
	case "$1" in
		scaleway) [ -f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsScalewayHarness.sh" ] ;;
		*) command -v "$1" >/dev/null 2>&1 ;;
	esac
}
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
			if DagcCliPresent "$DAGC_AUTO_CLI" ; then
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
	copilot|claude|grok|scaleway) ;;
	*)
		echo "⛔ ERROR: DistroAgentsConsole: unsupported --cli: $DAGC_CLI (known: $DAGC_KNOWN_CLIS)" >&2
		exit 1
	;;
esac
## scaleway has no interactive shape at all -- there is no real binary and no
## REPL, only a harness that runs one request/response tool-calling cycle to
## completion and exits -- so an explicit interactive request for it is
## refused here, with a stated reason, rather than falling through to a
## plain `exec scaleway` that the shell itself would reject as "not found"
## for a reason this console never explains.
if [ "$DAGC_CLI" = "scaleway" ] && [ "$1" != "--non-interactive" ] ; then
	echo "⛔ ERROR: DistroAgentsConsole: 'scaleway' has no interactive shape -- its harness runs one request/response tool-calling cycle and exits; use --non-interactive." >&2
	exit 1
fi
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
	DagcCliPresent "$DAGC_CLI" || {
		echo "⛔ ERROR: DistroAgentsConsole: '$DAGC_CLI' CLI not found in PATH -- install it first; it was selected explicitly (--cli, or magic-team's SPAWN_CLI_SERVICE), so this does not fall back to a bash session." >&2
		exit 1
	}
elif ! DagcCliPresent "$DAGC_CLI" ; then
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
		if DagcCliPresent "$DAGC_FALLBACK_CLI" ; then
			DAGC_CLI="$DAGC_FALLBACK_CLI"
			break
		fi
	done
	if DagcCliPresent "$DAGC_CLI" ; then
		:
	else
		exec bash --rcfile "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/console-agents-bashrc.rc" -i
	fi
fi

## The actual argv[0] `exec` below reaches for. Every other known CLI's own
## name IS the binary; scaleway's is not -- there is no `scaleway` on any
## PATH -- so this is the one substitution point where the harness script
## stands in for it. `$DAGC_CLI` itself stays the logical name everywhere
## else in this file (DISTRO_CONSOLE_EXEC=, the credential/flag case
## statements, the warnings), so reporting and dispatch never disagree about
## what was selected.
case "$DAGC_CLI" in
	scaleway) DAGC_CLI_EXEC="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsScalewayHarness.sh" ;;
	*)        DAGC_CLI_EXEC="$DAGC_CLI" ;;
esac

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
## fragment -> no tokens added; grok gets nothing (out of scope). scaleway
## also gets nothing here -- it has no real binary to hand a flag to, and its
## own harness (AgentsScalewayHarness.sh) reads this same fragment file
## itself instead; see MAGIC.md. One token
## per line, so a root containing spaces survives being read back into the
## array intact. The DAGC_COPILOT_* names, the fragment's own filename and
## the installer op that writes it all predate claude being included here and
## are left exactly as they are: renaming them is its own change, across the
## installer and its help, not a side effect of widening this branch.
## Fragment lines are `<tag>\t<path>`, tag one of own/explicit/wildcard (see
## AgentsTools.Install.include's --install-copilot-access-fragment and
## AgentsTools.ClientAccessRoots.include's AgentsToolsClientAccessRootTag).
## own/explicit are the installer's own guarantee -- created at install time,
## added here unconditionally, no filesystem check. wildcard was only ever
## matched because a workspace:* selector swept the WHOLE workspace registry,
## never created by the installer, and is checked for real existence right
## here at spawn time, since the registry can list a workspace that was never
## a real tooling install -- an --add-dir naming a directory that does not
## exist fails the whole spawn outright. An untagged line (the old two-line
## `--add-dir`/path format, from before this format existed, or a stray
## hand-edit) is treated as wildcard too: an entry with no recorded provenance
## is never trusted unconditionally.
DAGC_COPILOT_ADDDIR=()
if [ "$DAGC_CLI" = "copilot" ] || [ "$DAGC_CLI" = "claude" ] ; then
	DAGC_COPILOT_FRAGMENT="$MMDAPP/.claude/copilot-add-dir.fragment"
	DAGC_ADDDIR_GUARANTEED=0
	DAGC_ADDDIR_WILDCARD_TOTAL=0
	DAGC_ADDDIR_WILDCARD_ADDED=0
	if [ -f "$DAGC_COPILOT_FRAGMENT" ] ; then
		while IFS= read -r DAGC_COPILOT_LINE ; do
			[ -n "$DAGC_COPILOT_LINE" ] || continue
			case "$DAGC_COPILOT_LINE" in
				--add-dir)
					## Old two-line format's own flag marker; the next line is a
					## bare legacy path with no tag -- falls to the untagged case below.
					continue
				;;
				own$'\t'/*|explicit$'\t'/*)
					DAGC_COPILOT_ADDDIR+=( "--add-dir" "${DAGC_COPILOT_LINE#*$'\t'}" )
					DAGC_ADDDIR_GUARANTEED=$(( DAGC_ADDDIR_GUARANTEED + 1 ))
				;;
				wildcard$'\t'/*)
					DAGC_COPILOT_WILDCARD_PATH="${DAGC_COPILOT_LINE#*$'\t'}"
					DAGC_ADDDIR_WILDCARD_TOTAL=$(( DAGC_ADDDIR_WILDCARD_TOTAL + 1 ))
					if [ -d "$DAGC_COPILOT_WILDCARD_PATH" ] ; then
						DAGC_COPILOT_ADDDIR+=( "--add-dir" "$DAGC_COPILOT_WILDCARD_PATH" )
						DAGC_ADDDIR_WILDCARD_ADDED=$(( DAGC_ADDDIR_WILDCARD_ADDED + 1 ))
					fi
				;;
				/*)
					DAGC_ADDDIR_WILDCARD_TOTAL=$(( DAGC_ADDDIR_WILDCARD_TOTAL + 1 ))
					if [ -d "$DAGC_COPILOT_LINE" ] ; then
						DAGC_COPILOT_ADDDIR+=( "--add-dir" "$DAGC_COPILOT_LINE" )
						DAGC_ADDDIR_WILDCARD_ADDED=$(( DAGC_ADDDIR_WILDCARD_ADDED + 1 ))
					fi
				;;
			esac
		done < "$DAGC_COPILOT_FRAGMENT"
		if [ "$DAGC_ADDDIR_GUARANTEED" -gt 0 ] || [ "$DAGC_ADDDIR_WILDCARD_TOTAL" -gt 0 ] ; then
			echo "# console: copilot --add-dir: $DAGC_ADDDIR_GUARANTEED own+explicit (install-guaranteed) + $DAGC_ADDDIR_WILDCARD_ADDED of $DAGC_ADDDIR_WILDCARD_TOTAL wildcard candidates existed, added" >&2
		fi
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
	claude)   DAGC_CLI_CREDENTIALS="ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN" ;;
	copilot)  DAGC_CLI_CREDENTIALS="COPILOT_GITHUB_TOKEN" ;;
	scaleway) DAGC_CLI_CREDENTIALS="SCALEWAY_DEEPSEEK SCALEWAY_GEMMA" ;;
	*)        DAGC_CLI_CREDENTIALS="" ;;
esac
for DAGC_CREDENTIAL_NAME in $DAGC_CLI_CREDENTIALS ; do
	## Tested, not bare: set -e would kill the console on an unreadable scope.
	DAGC_CREDENTIAL_VALUE="$( "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --agents-config-option magic-team --select "$DAGC_CREDENTIAL_NAME" 2>/dev/null )" || DAGC_CREDENTIAL_VALUE=""
	[ -n "$DAGC_CREDENTIAL_VALUE" ] || continue
	export "$DAGC_CREDENTIAL_NAME=$DAGC_CREDENTIAL_VALUE"
done

## The spawn proxy mints this session uuid, records it on its own dispatch
## document and exports it here, so a hook's own session_id joins that record.
## claude and copilot both take the flag; any other CLI has it reported and
## dropped rather than silently ignored, since the dispatch record would
## otherwise name a session nothing else ever reports.
DAGC_SESSION_ID_ARGS=()
if [ -n "$MDAT_SPAWN_SESSION_ID" ] ; then
	if [ "$DAGC_CLI" = "claude" ] || [ "$DAGC_CLI" = "copilot" ] ; then
		DAGC_SESSION_ID_ARGS=( --session-id "$MDAT_SPAWN_SESSION_ID" )
	else
		echo "🙋 WARNING: DistroAgentsConsole: MDAT_SPAWN_SESSION_ID is set but '$DAGC_CLI' has no --session-id flag -- this spawn runs without it, and its dispatch record will not join the agent's own session" >&2
	fi
fi

## The acting member, named by the spawn proxy. The agent is defined inline at
## spawn rather than as a standing file: members ship as skills, and a standing
## definition would make one member exist twice. `--agent` then selects it, so
## a hook reports the member name rather than the generic agent type. claude
## takes the definition inline; copilot instead reads it from its own
## `~/.copilot/agents/<member>.agent.md` file, generated once per member by
## `--install-copilot-agent-files`, and only `--agent`s it when that file is
## actually there. The name is checked against a bare-token set before it is
## placed inside JSON or a path, so no member name can alter the document's
## structure or point outside the agents directory.
DAGC_AGENT_ARGS=()
if [ -n "$MDAT_SPAWN_AGENT" ] ; then
	case "$MDAT_SPAWN_AGENT" in
		''|*[!a-zA-Z0-9._-]*)
			echo "⛔ ERROR: DistroAgentsConsole: MDAT_SPAWN_AGENT is not a bare member name: $MDAT_SPAWN_AGENT" >&2
			exit 1
		;;
	esac
	case "$DAGC_CLI" in
		claude)
			DAGC_AGENT_ARGS=(
				--agents "{\"$MDAT_SPAWN_AGENT\":{\"description\":\"magic-team member $MDAT_SPAWN_AGENT\",\"prompt\":\"You are $MDAT_SPAWN_AGENT, a magic-team member. Read your own skill files before acting.\"}}"
				--agent "$MDAT_SPAWN_AGENT"
			)
		;;
		copilot)
			if [ -f "$HOME/.copilot/agents/$MDAT_SPAWN_AGENT.agent.md" ] ; then
				DAGC_AGENT_ARGS=( --agent "$MDAT_SPAWN_AGENT" )
			else
				echo "🙋 WARNING: DistroAgentsConsole: MDAT_SPAWN_AGENT is set but ~/.copilot/agents/$MDAT_SPAWN_AGENT.agent.md does not exist yet -- this spawn runs without --agent, and its hooks report the generic agent type rather than $MDAT_SPAWN_AGENT" >&2
			fi
		;;
		*)
			echo "🙋 WARNING: DistroAgentsConsole: MDAT_SPAWN_AGENT is set but '$DAGC_CLI' has no --agent/--agents flag -- this spawn runs without them, and its hooks report the generic agent type rather than $MDAT_SPAWN_AGENT" >&2
		;;
	esac
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
	## scaleway takes neither: AgentsScalewayHarness.sh's own arg parser knows
	## --tier/--access-root/--, and reads its prompt as plain trailing argv
	## (or stdin) exactly like claude/copilot's *own* prompt body does once
	## their flags are stripped -- a `-p`/`-p --` token would hit its default
	## `*) break` arm unconsumed and be read back as literal prompt text.
	case "$DAGC_CLI" in
		copilot)  DAGC_NONINTERACTIVE_PERM_FLAGS="--allow-all-tools" ; DAGC_PROMPT_ARGS=( -p ) ;;
		scaleway) DAGC_NONINTERACTIVE_PERM_FLAGS="" ; DAGC_PROMPT_ARGS=() ;;
		*)        DAGC_NONINTERACTIVE_PERM_FLAGS="" ; DAGC_PROMPT_ARGS=( -p -- ) ;;
	esac
	## The launch signal, on its own channel: the stdout line below shares a stream with the agent's own output.
	[ -z "$MDAT_SPAWN_LAUNCH_MARKER" ] || printf '%s\n' "$DAGC_CLI" > "$MDAT_SPAWN_LAUNCH_MARKER"
	if [ $# -gt 0 ] ; then
		echo "DISTRO_CONSOLE_EXEC=$DAGC_CLI"
		if [ "$DAGC_CLI" = "claude" ] ; then
			DagcRunClaudeStreaming "$*"
		fi
		exec "$DAGC_CLI_EXEC" $DAGC_NONINTERACTIVE_PERM_FLAGS "${DAGC_COPILOT_ADDDIR[@]}" "${DAGC_SESSION_ID_ARGS[@]}" "${DAGC_AGENT_ARGS[@]}" "${DAGC_PROMPT_ARGS[@]}" "$*"
	fi
	echo "DISTRO_CONSOLE_EXEC=$DAGC_CLI"
	if [ "$DAGC_CLI" = "claude" ] ; then
		DagcRunClaudeStreaming "$( cat )"
	fi
	exec "$DAGC_CLI_EXEC" $DAGC_NONINTERACTIVE_PERM_FLAGS "${DAGC_COPILOT_ADDDIR[@]}" "${DAGC_SESSION_ID_ARGS[@]}" "${DAGC_AGENT_ARGS[@]}" "${DAGC_PROMPT_ARGS[@]}" "$( cat )"
fi

echo "DISTRO_CONSOLE_EXEC=$DAGC_CLI"
exec "$DAGC_CLI_EXEC" "${DAGC_COPILOT_ADDDIR[@]}" "${DAGC_SESSION_ID_ARGS[@]}" "${DAGC_AGENT_ARGS[@]}" "$@"
