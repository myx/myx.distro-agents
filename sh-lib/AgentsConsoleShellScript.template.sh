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

DAGC_KNOWN_CLIS="copilot claude claude-native grok scaleway"
## claude-native is the VENDOR claude CLI under its own name. It is listed
## after claude deliberately: this string is also the --cli-auto scan order,
## and the scan takes the first PRESENT one, so a machine carrying the vendor
## binary must not have claude-native selected ahead of claude by accident.
## Its binary is `claude`, not its own name -- see DagcCliPresent() and the
## DAGC_CLI_EXEC case below, which are the two places that difference lives.
## scaleway added here on a real, live-confirmed round-trip through this
## console itself (--cli scaleway --non-interactive, end to end) -- not
## speculatively. It has no interactive shape at all (no real binary, no
## REPL; the harness runs one request/response tool-calling cycle and
## exits), which is exactly why it belongs in this list and nowhere else:
## grok is the opposite case (a real interactive binary, not yet proven
## non-interactive), scaleway is proven non-interactive and categorically
## cannot be the other thing. See MAGIC.md.
DAGC_NONINTERACTIVE_CLIS="copilot claude claude-native scaleway"
DAGC_CLI="copilot"
DAGC_CLI_GIVEN="false"
DAGC_CLI_AUTO="false"
DAGC_CLI_CONFIGURED="false"
## The one file the `scaleway` CLI name resolves to, resolved ONCE here and
## then read by both of this file's scaleway sites -- DagcCliPresent()'s
## existence test just below, and the DAGC_CLI_EXEC assignment further down.
## Those two must never disagree: presence-checking one file while exec'ing
## another is exactly how a console reports a CLI as available and then fails
## to start it, so they share this variable rather than repeating a path.
##
## Default -- MDAT_SCALEWAY_HARNESS unset or empty -- is AgentsScalewayHarness.sh,
## which is the SSE-STREAMING implementation: live text and per-tool progress on
## stderr as the model generates them. That is the production default; nothing
## needs to be set to get it.
##
## Setting this variable selects a different harness, per workspace. No
## alternative harness ships in sh-lib/ today, so nothing in this package is
## currently worth naming here. The variable's purpose is unchanged: one
## workspace can run a candidate implementation while every other workspace
## sharing this same MDLT_ORIGIN tree keeps the default, which is what makes a
## candidate testable for real without promoting it everywhere at once.
##
## Two accepted shapes, and why only these:
##  - a bare filename (no '/'), taken from this package's own sh-lib/ -- the
##    normal case, since the harness variants worth selecting ship there. A
##    value with no slash in it cannot traverse anywhere, so it needs no
##    containment check of its own.
##  - an absolute path, for a candidate harness still being developed outside
##    the package tree. Deliberately allowed rather than confined to sh-lib/:
##    the point of this variable is trying an implementation before it is
##    promoted, and that work does not always happen inside the package.
## A relative path containing '/' is refused rather than resolved, since it
## would silently resolve against $MMDAPP (this script cd's there above) --
## not against anything the caller writing "../x/harness.sh" meant.
##
## Whichever shape it takes, the file must exist and be executable, checked
## here at the top so a bad value fails on its own name. Otherwise it would
## surface far downstream: as an exec "not found", or -- worse, because it is
## silent -- as scaleway reported absent by DagcCliPresent() and quietly
## skipped by --cli-auto, which is indistinguishable from scaleway simply not
## being installed. An unset variable reaches none of this.
DAGC_SCALEWAY_HARNESS="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsScalewayHarness.sh"
if [ -n "$MDAT_SCALEWAY_HARNESS" ] ; then
	case "$MDAT_SCALEWAY_HARNESS" in
		.|..)
			echo "⛔ ERROR: DistroAgentsConsole: MDAT_SCALEWAY_HARNESS is not a harness filename: $MDAT_SCALEWAY_HARNESS" >&2
			exit 1
		;;
		/*)
			DAGC_SCALEWAY_HARNESS="$MDAT_SCALEWAY_HARNESS"
		;;
		*/*)
			echo "⛔ ERROR: DistroAgentsConsole: MDAT_SCALEWAY_HARNESS must be a bare filename in $MDLT_ORIGIN/myx/myx.distro-agents/sh-lib, or an absolute path -- a relative path is refused, because it would resolve against $MMDAPP rather than against anything you named: $MDAT_SCALEWAY_HARNESS" >&2
			exit 1
		;;
		*)
			DAGC_SCALEWAY_HARNESS="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/$MDAT_SCALEWAY_HARNESS"
		;;
	esac
	if [ ! -f "$DAGC_SCALEWAY_HARNESS" ] ; then
		echo "⛔ ERROR: DistroAgentsConsole: MDAT_SCALEWAY_HARNESS=$MDAT_SCALEWAY_HARNESS names no such file: $DAGC_SCALEWAY_HARNESS" >&2
		exit 1
	fi
	if [ ! -x "$DAGC_SCALEWAY_HARNESS" ] ; then
		echo "⛔ ERROR: DistroAgentsConsole: MDAT_SCALEWAY_HARNESS=$MDAT_SCALEWAY_HARNESS names a file that is not executable: $DAGC_SCALEWAY_HARNESS" >&2
		exit 1
	fi
fi
## scaleway has no real binary at all -- `command -v scaleway` can never
## succeed on any machine -- so every presence check in this file goes
## through here instead, exactly as `--owner-setup-scaleway`'s own
## install-probe already had to (a file test, not a PATH lookup; see
## AgentsTools.Owner.include and MAGIC.md).
DagcCliPresent(){
	case "$1" in
		scaleway) [ -f "$DAGC_SCALEWAY_HARNESS" ] ;;
		## claude-native's BINARY is `claude`; its own name is on no PATH. Without
		## this arm the default below would run `command -v claude-native`, find
		## nothing, and report the vendor CLI absent on a machine where it is
		## installed -- which --cli-auto reads as "not installed" and skips
		## silently, indistinguishable from it really being missing.
		claude-native) command -v claude >/dev/null 2>&1 ;;
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
		## Every spawn service is named, not one of them. This error reaches a
		## workspace that has chosen NOTHING yet, so naming a single flag steers
		## that choice by whichever name an error string happened to carry --
		## a policy nobody decided, expressed as an example. The reader picks.
		echo "⛔ ERROR: DistroAgentsConsole: SPAWN_CLI_SERVICE is not configured in this workspace, so no external agent CLI is selected here. rc=5 means exactly this -- nothing was chosen to start, which is distinct from rc=1 (something was chosen and could not be started). Spawn an internal agent instead, or choose one of the spawn services and select it with --apply: $MMDAPP/.local/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh --owner-setup-claude --apply (this package's own Claude harness), or --owner-setup-claude-native (the vendor claude CLI as installed on this machine), or --owner-setup-copilot, or --owner-setup-scaleway." >&2
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
	copilot|claude|claude-native|grok|scaleway) ;;
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
## what was selected. The harness file itself is NOT re-derived here: it is
## whatever DAGC_SCALEWAY_HARNESS resolved to at the top of this file, the same
## value DagcCliPresent() tested, so the file this exec's is always the file
## that was checked for.
case "$DAGC_CLI" in
	scaleway)      DAGC_CLI_EXEC="$DAGC_SCALEWAY_HARNESS" ;;
	## The second name whose binary is not itself. `claude-native` exists to say
	## WHICH claude is meant once this package ships a claude leg of its own; the
	## thing it launches is still the vendor binary, spelled `claude`. This arm is
	## what stops the exec below reaching for a `claude-native` that is on no PATH.
	claude-native) DAGC_CLI_EXEC="claude" ;;
	*)             DAGC_CLI_EXEC="$DAGC_CLI" ;;
esac

DAGC_MYXROOT="$MDLT_ORIGIN/myx/myx.common/os-myx.common/host/tarball/share/myx.common"
if [ -x "$DAGC_MYXROOT/bin/setup/agentMcp.Common" ] ; then
	MYXROOT="$DAGC_MYXROOT" MYX_AGENTMCP_TARGET_CWD="$MMDAPP" "$DAGC_MYXROOT/bin/setup/agentMcp.Common" >/dev/null 2>&1 || :
elif command -v myx.common >/dev/null 2>&1 ; then
	MYX_AGENTMCP_TARGET_CWD="$MMDAPP" myx.common setup/agentMcp >/dev/null 2>&1 || :
fi

## The team's own access-root set, collected by the installer, rendered into
## whichever spelling this client takes. The roots are team data: every client
## that can be told where it may work is told here, in its own flag.
## own/explicit are install-guaranteed and trusted unconditionally; wildcard and
## untagged carry no provenance and are existence-checked at spawn, since a root
## that does not exist fails the whole spawn.
DAGC_ACCESS_FLAG=""
case "$DAGC_CLI" in
	copilot|claude|claude-native) DAGC_ACCESS_FLAG="--add-dir" ;;
	scaleway)                     DAGC_ACCESS_FLAG="--access-read-root" ;;
esac
DAGC_ACCESS_ARGS=()
if [ -n "$DAGC_ACCESS_FLAG" ] ; then
	DAGC_ACCESS_FRAGMENT="$MMDAPP/.claude/copilot-add-dir.fragment"
	DAGC_ACCESS_GUARANTEED=0
	DAGC_ACCESS_WILDCARD_TOTAL=0
	DAGC_ACCESS_WILDCARD_ADDED=0
	if [ -f "$DAGC_ACCESS_FRAGMENT" ] ; then
		while IFS= read -r DAGC_ACCESS_LINE ; do
			[ -n "$DAGC_ACCESS_LINE" ] || continue
			case "$DAGC_ACCESS_LINE" in
				--add-dir)
					## Old two-line format's marker; its path is the untagged arm below.
					continue
				;;
				own$'\t'/*|explicit$'\t'/*)
					DAGC_ACCESS_ARGS+=( "$DAGC_ACCESS_FLAG" "${DAGC_ACCESS_LINE#*$'\t'}" )
					DAGC_ACCESS_GUARANTEED=$(( DAGC_ACCESS_GUARANTEED + 1 ))
				;;
				wildcard$'\t'/*)
					DAGC_ACCESS_WILDCARD_PATH="${DAGC_ACCESS_LINE#*$'\t'}"
					DAGC_ACCESS_WILDCARD_TOTAL=$(( DAGC_ACCESS_WILDCARD_TOTAL + 1 ))
					if [ -d "$DAGC_ACCESS_WILDCARD_PATH" ] ; then
						DAGC_ACCESS_ARGS+=( "$DAGC_ACCESS_FLAG" "$DAGC_ACCESS_WILDCARD_PATH" )
						DAGC_ACCESS_WILDCARD_ADDED=$(( DAGC_ACCESS_WILDCARD_ADDED + 1 ))
					fi
				;;
				/*)
					## No recorded provenance, so never trusted unconditionally.
					DAGC_ACCESS_WILDCARD_TOTAL=$(( DAGC_ACCESS_WILDCARD_TOTAL + 1 ))
					if [ -d "$DAGC_ACCESS_LINE" ] ; then
						DAGC_ACCESS_ARGS+=( "$DAGC_ACCESS_FLAG" "$DAGC_ACCESS_LINE" )
						DAGC_ACCESS_WILDCARD_ADDED=$(( DAGC_ACCESS_WILDCARD_ADDED + 1 ))
					fi
				;;
			esac
		done < "$DAGC_ACCESS_FRAGMENT"
		if [ "$DAGC_ACCESS_GUARANTEED" -gt 0 ] || [ "$DAGC_ACCESS_WILDCARD_TOTAL" -gt 0 ] ; then
			echo "# console: $DAGC_CLI $DAGC_ACCESS_FLAG: $DAGC_ACCESS_GUARANTEED install-guaranteed + $DAGC_ACCESS_WILDCARD_ADDED of $DAGC_ACCESS_WILDCARD_TOTAL live-checked candidates existed, added" >&2
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
	## Nothing of ours: claude-native runs on the machine's own claude sign-in.
	claude-native) DAGC_CLI_CREDENTIALS="" ;;
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
## claude, copilot and scaleway all take the flag; any other CLI has it
## reported and dropped rather than silently ignored, since the dispatch
## record would otherwise name a session nothing else ever reports. scaleway
## has no external hook observer of its own -- its harness just announces the
## id to stderr, the only "join" possible for it (see the harness
## DAGC_SCALEWAY_HARNESS resolved to above -- AgentsScalewayHarness.sh by
## default, and it announces the id itself).
DAGC_SESSION_ID_ARGS=()
if [ -n "$MDAT_SPAWN_SESSION_ID" ] ; then
	if [ "$DAGC_CLI" = "claude" ] || [ "$DAGC_CLI" = "claude-native" ] || [ "$DAGC_CLI" = "copilot" ] || [ "$DAGC_CLI" = "scaleway" ] ; then
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
## actually there. scaleway resolves the member itself, from its own skill
## directory (`$MDAT_SKILLSET_ROOT/<name>/<name>.basic.md`), so no
## pre-existing-file gate is needed here the way copilot's is. The name is
## checked against a bare-token set -- letters, digits, '.', '_' or '-' only,
## enumerated character-by-character rather than via a collation-dependent
## [a-zA-Z0-9._-] bracket range (see MAGIC.md's "A bracket range is never
## used in a `case` pattern" and AgentsToolsAssertBareName in
## sh-scripts/DistroAgentsTools.fn.sh, whose exact enumerated set this
## mirrors), with the literal tokens '.' and '..' rejected explicitly since
## both consist only of otherwise-allowed characters -- before it is placed
## inside JSON or a path, so no member name can alter the document's
## structure or point outside the agents directory.
DAGC_AGENT_ARGS=()
if [ -n "$MDAT_SPAWN_AGENT" ] ; then
	case "$MDAT_SPAWN_AGENT" in
		''|.|..)
			echo "⛔ ERROR: DistroAgentsConsole: MDAT_SPAWN_AGENT is not a bare member name: $MDAT_SPAWN_AGENT" >&2
			exit 1
		;;
	esac
	DAGC_AGENT_CHECK_REST="$MDAT_SPAWN_AGENT"
	while [ -n "$DAGC_AGENT_CHECK_REST" ] ; do
		DAGC_AGENT_CHECK_CHAR="${DAGC_AGENT_CHECK_REST%"${DAGC_AGENT_CHECK_REST#?}"}"
		DAGC_AGENT_CHECK_REST="${DAGC_AGENT_CHECK_REST#?}"
		case "$DAGC_AGENT_CHECK_CHAR" in
			a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z) ;;
			A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z) ;;
			0|1|2|3|4|5|6|7|8|9) ;;
			-|_|.) ;;
			*)
				echo "⛔ ERROR: DistroAgentsConsole: MDAT_SPAWN_AGENT is not a bare member name: $MDAT_SPAWN_AGENT" >&2
				exit 1
			;;
		esac
	done
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
		scaleway)
			DAGC_AGENT_ARGS=( --agent "$MDAT_SPAWN_AGENT" )
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
	local claudePrompt="$1" progressAwkPath streamAwkPath claudePid awkPid claudeStatus
	## Order is load-bearing: the formatter calls progressLineSafe() and does not
	## define it, and an undefined awk function is a fatal exit 2 at call time.
	progressAwkPath="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsProgressLineSafe.awk"
	streamAwkPath="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsClaudeStreamJsonFormat.awk"
	exec 3> >( LC_ALL=C awk -f "$progressAwkPath" -f "$streamAwkPath" )
	awkPid=$!
	## $DAGC_CLI_EXEC, not $DAGC_CLI: this launches a BINARY, and the two differ
	## for any CLI whose name is not its own executable. It read $DAGC_CLI safely
	## only while its sole callers were gated on `claude`, the one CLI where the
	## two strings coincide -- claude-native removes that coincidence. Every other
	## launch site in this file already uses $DAGC_CLI_EXEC for exactly this
	## reason; this one was the outlier. The failure it would have caused is
	## invisible: this runs backgrounded with stdout redirected into the awk
	## formatter, so a 127 surfaces through a stream formatter rather than as
	## "command not found".
	"$DAGC_CLI_EXEC" --verbose --output-format stream-json "${DAGC_ACCESS_ARGS[@]}" "${DAGC_SESSION_ID_ARGS[@]}" "${DAGC_AGENT_ARGS[@]}" "${DAGC_PROMPT_ARGS[@]}" "$claudePrompt" >&3 &
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
	## scaleway takes neither: the harness's own arg parser, in
	## AgentsScalewayHarness.sh, knows
	## --tier/--access-read-root/--, and reads its prompt as plain trailing argv
	## (or stdin) exactly like claude/copilot's *own* prompt body does once
	## their flags are stripped -- a `-p`/`-p --` token would hit its default
	## `*) break` arm unconsumed and be read back as literal prompt text.
	case "$DAGC_CLI" in
		copilot)  DAGC_NONINTERACTIVE_PERM_FLAGS="--allow-all-tools" ; DAGC_PROMPT_ARGS=( -p ) ;;
		scaleway) DAGC_NONINTERACTIVE_PERM_FLAGS="" ; DAGC_PROMPT_ARGS=() ;;
		## claude-native takes NO arm here on purpose, and the reason is worth
		## stating because the next reader will want to add one: the default IS
		## claude's shape, so the vendor CLI under either of its names lands here
		## correctly. An arm spelling out the same two values would be a second
		## copy to keep in step with this one. Correct-by-default is only safe
		## when it is deliberate, so this comment is the deliberateness.
		*)        DAGC_NONINTERACTIVE_PERM_FLAGS="" ; DAGC_PROMPT_ARGS=( -p -- ) ;;
	esac
	## The launch signal, on its own channel: the stdout line below shares a stream with the agent's own output.
	[ -z "$MDAT_SPAWN_LAUNCH_MARKER" ] || printf '%s\n' "$DAGC_CLI" > "$MDAT_SPAWN_LAUNCH_MARKER"
	if [ $# -gt 0 ] ; then
		echo "DISTRO_CONSOLE_EXEC=$DAGC_CLI"
		if [ "$DAGC_CLI" = "claude" ] || [ "$DAGC_CLI" = "claude-native" ] ; then
			DagcRunClaudeStreaming "$*"
		fi
		exec "$DAGC_CLI_EXEC" $DAGC_NONINTERACTIVE_PERM_FLAGS "${DAGC_ACCESS_ARGS[@]}" "${DAGC_SESSION_ID_ARGS[@]}" "${DAGC_AGENT_ARGS[@]}" "${DAGC_PROMPT_ARGS[@]}" "$*"
	fi
	echo "DISTRO_CONSOLE_EXEC=$DAGC_CLI"
	if [ "$DAGC_CLI" = "claude" ] || [ "$DAGC_CLI" = "claude-native" ] ; then
		DagcRunClaudeStreaming "$( cat )"
	fi
	exec "$DAGC_CLI_EXEC" $DAGC_NONINTERACTIVE_PERM_FLAGS "${DAGC_ACCESS_ARGS[@]}" "${DAGC_SESSION_ID_ARGS[@]}" "${DAGC_AGENT_ARGS[@]}" "${DAGC_PROMPT_ARGS[@]}" "$( cat )"
fi

echo "DISTRO_CONSOLE_EXEC=$DAGC_CLI"
exec "$DAGC_CLI_EXEC" "${DAGC_ACCESS_ARGS[@]}" "${DAGC_SESSION_ID_ARGS[@]}" "${DAGC_AGENT_ARGS[@]}" "$@"
