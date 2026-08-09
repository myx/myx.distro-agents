#!/usr/bin/env bash

##
## NOTE:
## Standard `.fn.sh` entry point, same shape as the rest of the
## Distro*Tools.fn.sh family (see myx.distro-agents/CLAUDE.md's "Command
## layout & help conventions"). Run it directly (bare, via PATH, or full
## path) from inside or outside any console — this tool's whole job is to
## START a new console session, so it can't rely on one already being open.
##
## Automates the manual Keep-Alive Workspace Console Session recipe
## documented in magic-coordinator's routines/console-sessions.md:
## a FIFO + a backgrounded `exec 9>fifo; sleep TTL` holder process keep a
## `Distro*Console.sh --non-interactive` session's stdin open indefinitely,
## so multiple rounds of commands can be piped in without re-paying the
## console bootstrap cost each time.
##
## Channel dirs are session plumbing ONLY (fifo/log/pid/meta) — never a
## place to drop secrets material. If/when magic-coordinator's consolidated
## secrets file ever moves under this tool's management, it should be
## sourced directly into the console's own environment, not staged as a
## file inside a channel dir, so `--console-stop`'s `rm -rf` (scoped to one
## mktemp-generated channel dir, never a fixed/shared path) can never take
## credentials down with it.
##
## Deliberately NOT built here: a queue/working/finished file-drop protocol.
## The FIFO + sentinel-in-log flow already IS the queue (commands arrive in
## order, a sentinel marks completion) for the single-producer case this
## tool serves today. No precedent for a 3-stage directory queue exists
## anywhere in myx.distro-*/myx.common; revisit only if/when multiple
## independent producers need to submit into one shared console out of band.
##
## Convention: brought in line with the rest of
## the Distro*Tools/Distro*Command family (DistroLocalTools.fn.sh,
## DistroSourceCommand.fn.sh, DistroImageCommand.fn.sh) — exactly ONE
## top-level function matching this file's own name (`DistroAgentsTools`),
## dispatching every operation via a single `case "$1" in ... esac`. Prior
## shape had a separate `DistroAgentsTools<OpName>` function per operation,
## called with all args forwarded from the dispatcher — that's the pattern
## no sibling tool uses, and it's also what made the earlier bare
## `DistroAgentsTools --agents-config-option ...` self-call bug possible in
## the first place (a function calling back into a sibling function that
## only exists because the op was split out to begin with). Genuinely
## shared, non-op-specific utility helpers (channel/workspace resolution)
## stay as small separate functions, same category as this family's own
## portable library primitives (GitClonePull/Prefix/CatMarkdown in
## DistroLocalTools.fn.sh) — reused plumbing, not "one function per op".
## One op invoking another (e.g. --self-test calling --verify-permissions,
## --sweep-read-incoming-comms's no-target sweep calling itself once per
## watched target) does so via self-recursion into `DistroAgentsTools`
## itself, matching DistroLocalTools.fn.sh's own `--upgrade-installed-tools`
## precedent (`DistroLocalTools --install-distro-$ITEM`), not via a private
## helper function.
##
## Convention: inline, especially single-liners. If a piece of logic is only ever used by one op, it goes
## inline in that op's own `case` arm — it does NOT become a new top-level
## helper just because it's a few lines long or "could be reused someday."
## The existing helpers above this line are already-established, genuinely
## multi-op-shared plumbing (channel/workspace/target resolution, perm
## checks) — that list is not license to keep adding more.
##

if [ -z "$MMDAPP" ] ; then
	set -e
	export MMDAPP="$( cd $(dirname "$0")/../../../.. ; pwd )"
	echo "$0: Working in: $MMDAPP"  >&2
	[ -d "$MMDAPP/.local" ] || ( echo "⛔ ERROR: expecting '.local' directory." >&2 && exit 1 )
fi

: "${MDLT_ORIGIN:=$MMDAPP/.local}"
export MDLT_ORIGIN

## Copied verbatim from DistroLocalTools.fn.sh's own bootstrap -- needed here
## for --agents-config-option (sources myx.distro-.local's shared
## LocalTools.Config.include) and --member-slack-send-message (reuses myx.common's
## agentMcpJsonEscape.awk rather than inventing another JSON escaper).
if   [ -d "$MYXROOT" ] && [ -f "$MYXROOT/share/myx.common/bin/lib/catMarkdown.Common" ]; then
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

## Channel dirs live at $TMPDIR (or /tmp)/$MDAT_CHANNEL_PREFIX.<workspace-slug>.<console> —
## a DETERMINISTIC id (workspace absolute path + console name, hashed with
## `cksum`), NOT a `mktemp -d` random suffix: the same (workspace, console)
## pair always resolves to the same channel dir/log path across restarts, so
## that path can be added once to an allowlist (e.g. Claude Code's
## settings.json) and stay valid forever — a random-per-invocation name can
## never be allowlisted. `--console-start` is idempotent: called again for a
## (workspace, console) pair that's already alive, it reuses the existing
## channel instead of minting a new one; if the channel dir exists but its
## processes are dead, it's wiped and recreated. One channel is naturally
## shared by all concurrent callers against the same workspace+console — safe
## since read/scan sessions are explicitly not ownership-gated. Default
## workspace is the tool's own ($MMDAPP);
## `--override-workspace` (on --console-start and --console-list alike) is
## the only escape hatch to point at a different workspace.
MDAT_CHANNEL_PREFIX="myx.distro-agent-console"
MDAT_DEFAULT_TTL="3600"

##
## Shared utility helpers -- genuinely reused across multiple unrelated ops
## below, same category as DistroLocalTools.fn.sh's GitClonePull/Prefix/
## CatMarkdown: reusable plumbing, not a stand-in for a dispatch case.
##

DistroAgentsToolsResolveChannelDir(){
	local ref="$1"
	if [ -z "$ref" ] ; then
		echo "⛔ ERROR: DistroAgentsTools: channel id or path required -- raised by the shared helper DistroAgentsToolsResolveChannelDir, which every channel-taking operation calls" >&2
		return 1
	fi
	case "$ref" in
		/*)
			if [ -d "$ref" ] ; then echo "$ref" ; return 0 ; fi
		;;
	esac
	local candidate="${TMPDIR:-/tmp}/$ref"
	if [ -d "$candidate" ] ; then echo "$candidate" ; return 0 ; fi
	candidate="${TMPDIR:-/tmp}/${MDAT_CHANNEL_PREFIX}.$ref"
	if [ -d "$candidate" ] ; then echo "$candidate" ; return 0 ; fi
	echo "⛔ ERROR: DistroAgentsTools: channel not found: $ref -- raised by the shared helper DistroAgentsToolsResolveChannelDir after trying the reference as an absolute path, as \${TMPDIR:-/tmp}/$ref, and as \${TMPDIR:-/tmp}/${MDAT_CHANNEL_PREFIX}.$ref" >&2
	return 1
}

## Deterministic workspace identity: same absolute path always yields the
## same short slug, so channel ids are stable across processes/restarts.
## `cksum` (POSIX, present on both macOS and Linux) needs no extra tooling.
DistroAgentsToolsResolveWorkspaceSlug(){
	printf '%s' "$1" | cksum | awk '{print $1}'
}

## Resolves a workspace argument (or $MMDAPP if empty) to an absolute path,
## erroring if it's not a directory. Used by both --console-start's
## --override-workspace and --console-list' --override-workspace so the two
## agree on what "own workspace" means.
DistroAgentsToolsResolveWorkspace(){
	local workspace="${1:-$MMDAPP}"
	if [ ! -d "$workspace" ] ; then
		echo "⛔ ERROR: DistroAgentsTools: workspace not found: $workspace -- raised by the shared helper DistroAgentsToolsResolveWorkspace, which resolves --override-workspace (or \$MMDAPP when none is given) for every console operation" >&2
		return 1
	fi
	( cd "$workspace" && pwd )
}

DistroAgentsToolsResolveConsoleShortName(){
	case "$1" in
		DistroSourceConsole.sh) echo "source" ;;
		DistroDeployConsole.sh) echo "deploy" ;;
		*) echo "⛔ ERROR: DistroAgentsTools: unrecognized console: $1 -- rejected by the default (*) branch of the shared helper DistroAgentsToolsResolveConsoleShortName, which accepts only DistroSourceConsole.sh or DistroDeployConsole.sh" >&2 ; return 1 ;;
	esac
}

## Resolves a --member-slack-send-message/--sweep-read-incoming-comms/--send-email-message
## style target (magic-team|human-owner|event-track|event-alert|<channel>:<ts>)
## to a channel id + optional thread ts. Shared resolution grammar across
## three ops -- kept as a utility helper (like the ones above) rather than
## duplicated three times.
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

## Shared bare-name assertion: <value> must be a single path segment made only
## of characters this family already uses for member names and item filenames.
## Called from the --from-inbox: arms and the --librarian-inbox-* stubs only.
##
## SIXTEEN inline `case "$x" in */*|.|..)` copies of this check already exist
## across sh-lib/. They are DELIBERATELY NOT retrofitted here -- retrofitting
## them is its own separate, independently reviewable item, not a side effect
## of adding an inbox source.
##
## NEVER a [a-z] bracket range in the case pattern below. Measured on this box:
## under en_US.UTF-8, `case "A" in [a-z])` MATCHES; under LC_ALL=C it does not.
## Bracket ranges are collation-dependent, so a range-based whitelist is not a
## whitelist at all. Every accepted character is enumerated explicitly.
AgentsToolsAssertBareName(){
	local nameValue="$1"
	local nameLabel="$2"
	local nameContext="$3"
	case "$nameValue" in
		''|.|..|-*|*/*)
			echo "⛔ ERROR: $nameContext: $nameLabel must be a bare name -- one path segment of letters, digits, '.', '_' or '-', not '.'/'..', no leading '-', no '/': $nameValue" >&2
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
				echo "⛔ ERROR: $nameContext: $nameLabel contains a character outside the allowed set (letters, digits, '.', '_', '-'): $nameValue" >&2
				return 1
			;;
		esac
	done
	return 0
}

##
## The one real dispatcher -- every operation lives in its own case branch,
## inline or via self-recursion into DistroAgentsTools itself, never a
## separate DistroAgentsTools<OpName> function.
##
DistroAgentsTools(){
	local MDSC_CMD='DistroAgentsTools'
	[ -z "$MDSC_DETAIL" ] || echo "> $MDSC_CMD $@" >&2
	set -e

	## NOT CACHE BUT MANDATED ENV CONTEXT VARIABLE
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
		--console-start)
			shift

			local workspaceArg consoleOverride ttl="$MDAT_DEFAULT_TTL"
			while [ $# -gt 0 ] ; do
				case "$1" in
					--override-workspace)
						[ -n "$2" ] || { echo "⛔ ERROR: $MDSC_CMD --console-start: --override-workspace requires a path" >&2 ; set +e ; return 1 ; }
						workspaceArg="$2" ; shift 2
					;;
					--console)
						[ -n "$2" ] || { echo "⛔ ERROR: $MDSC_CMD --console-start: --console requires a value" >&2 ; set +e ; return 1 ; }
						consoleOverride="$2" ; shift 2
					;;
					--ttl)
						[ -n "$2" ] || { echo "⛔ ERROR: $MDSC_CMD --console-start: --ttl requires seconds" >&2 ; set +e ; return 1 ; }
						ttl="$2" ; shift 2
					;;
					*)
						echo "⛔ ERROR: $MDSC_CMD --console-start: invalid option: $1" >&2
						set +e ; return 1
					;;
				esac
			done
			case "$ttl" in ''|*[!0-9]*) echo "⛔ ERROR: $MDSC_CMD --console-start: --ttl must be a positive integer" >&2 ; set +e ; return 1 ;; esac
			[ "$ttl" -gt 0 ] || { echo "⛔ ERROR: $MDSC_CMD --console-start: --ttl must be a positive integer" >&2 ; set +e ; return 1 ; }

			local workspace
			workspace="$( DistroAgentsToolsResolveWorkspace "$workspaceArg" )" || { set +e ; return 1 ; }

			local consoleName
			if [ -n "$consoleOverride" ] ; then
				case "$consoleOverride" in
					DistroSourceConsole.sh|DistroDeployConsole.sh) ;;
					*)
						echo "⛔ ERROR: $MDSC_CMD --console-start: --console must be DistroSourceConsole.sh or DistroDeployConsole.sh (Local/Remote not supported)" >&2
						set +e ; return 1
					;;
				esac
				if [ ! -x "$workspace/$consoleOverride" ] ; then
					echo "⛔ ERROR: $MDSC_CMD --console-start: $consoleOverride not found/executable in $workspace" >&2
					set +e ; return 1
				fi
				consoleName="$consoleOverride"
			elif [ -x "$workspace/DistroSourceConsole.sh" ] ; then
				consoleName="DistroSourceConsole.sh"
			elif [ -x "$workspace/DistroDeployConsole.sh" ] ; then
				consoleName="DistroDeployConsole.sh"
			else
				echo "⛔ ERROR: $MDSC_CMD --console-start: neither DistroSourceConsole.sh nor DistroDeployConsole.sh found in $workspace" >&2
				set +e ; return 1
			fi

			local consoleShortName
			consoleShortName="$( DistroAgentsToolsResolveConsoleShortName "$consoleName" )" || { set +e ; return 1 ; }

			local slug ; slug="$( DistroAgentsToolsResolveWorkspaceSlug "$workspace" )"
			local channelId="${MDAT_CHANNEL_PREFIX}.${slug}.${consoleShortName}"
			local channelDir="${TMPDIR:-/tmp}/$channelId"
			local fifo="$channelDir/fifo"
			local log="$channelDir/console.log"

			## Idempotent reuse: if this workspace+console already has a live
			## channel, hand back its details instead of minting a duplicate.
			## If the dir exists but its processes are dead, wipe and recreate —
			## never silently leave a half-dead channel behind.
			if [ -d "$channelDir" ] ; then
				local oldConsolePid oldHolderPid
				if [ -f "$channelDir/console.pid" ] ; then oldConsolePid="$( cat "$channelDir/console.pid" 2>/dev/null )" ; fi
				if [ -f "$channelDir/holder.pid" ] ; then oldHolderPid="$( cat "$channelDir/holder.pid" 2>/dev/null )" ; fi
				if [ -n "$oldConsolePid" ] && kill -0 "$oldConsolePid" 2>/dev/null \
					&& [ -n "$oldHolderPid" ] && kill -0 "$oldHolderPid" 2>/dev/null ; then
					echo "# $MDSC_CMD --console-start: reusing already-active channel for $workspace ($consoleName)" >&2
					echo "CHANNEL=$channelId"
					echo "CHANNEL_DIR=$channelDir"
					echo "FIFO=$fifo"
					echo "LOG=$log"
					echo "CONSOLE=$consoleName"
					echo "WORKSPACE=$workspace"
					echo "ORIGIN_SPEC=$MDLT_ORIGIN"
					echo "HOLDER_PID=$oldHolderPid"
					echo "CONSOLE_PID=$oldConsolePid"
					echo "# send a command:  DistroAgentsTools.fn.sh --console-send $channelId -- your command here"
					echo "# tail output:     tail -f \"$log\""
					echo "# stop session:    DistroAgentsTools.fn.sh --console-stop $channelId"
					return 0
				fi
				echo "# $MDSC_CMD --console-start: stale channel found (no live processes), recreating: $channelDir" >&2
				## NOTE: under `set -e` (active for this whole function), a bare
				## `kill` on an already-dead pid returns non-zero and would
				## silently abort here mid-recreate — hence the explicit
				## `|| true` guards, not just a redirected stderr.
				if [ -n "$oldConsolePid" ] ; then kill -9 "$oldConsolePid" 2>/dev/null || true ; fi
				if [ -n "$oldHolderPid" ] ; then kill -9 "$oldHolderPid" 2>/dev/null || true ; fi
				rm -rf "$channelDir"
			fi

			mkdir -p "$channelDir" || {
				echo "⛔ ERROR: $MDSC_CMD --console-start: can't create channel directory: $channelDir" >&2
				set +e ; return 1
			}

			mkfifo "$fifo" || {
				echo "⛔ ERROR: $MDSC_CMD --console-start: mkfifo failed" >&2
				rm -rf "$channelDir"
				set +e ; return 1
			}
			: > "$log"

			## Keep-alive FIFO-holder: opens the write end and sleeps, so the
			## console's read end never sees EOF between rounds. Same mechanism as
			## console-sessions.md's documented manual recipe. `sh -c`, not
			## `bash -c`: this subshell body is plain POSIX (fd-9 `exec`
			## redirect, `sleep`) with no bash-specific syntax, so it doesn't
			## need this file's own bash requirement -- this file's shebang
			## stays bash regardless, this is only about the disposable child
			## process's own interpreter.
			nohup sh -c "exec 9>\"$fifo\"; sleep \"$ttl\"" >/dev/null 2>&1 &
			local holderPid=$!
			disown 2>/dev/null || true
			echo "$holderPid" > "$channelDir/holder.pid"

			## Console self-locates its own workspace root from $0 (see
			## DistroSourceConsole.sh's own MMDAPP bootstrap), so an absolute path
			## here doesn't require changing this shell's cwd.
			nohup env MMDAPP="$workspace" "$workspace/$consoleName" --non-interactive < "$fifo" >> "$log" 2>&1 &
			local consolePid=$!
			disown 2>/dev/null || true
			echo "$consolePid" > "$channelDir/console.pid"

			{
				echo "MDAT_WORKSPACE=$workspace"
				echo "MDAT_CONSOLE=$consoleName"
				echo "MDAT_TTL=$ttl"
				echo "MDAT_CREATED=$( date -u +%Y-%m-%dT%H:%M:%SZ )"
			} > "$channelDir/meta.env"

			echo "CHANNEL=$channelId"
			echo "CHANNEL_DIR=$channelDir"
			echo "FIFO=$fifo"
			echo "LOG=$log"
			echo "CONSOLE=$consoleName"
			echo "WORKSPACE=$workspace"
			echo "DATA_WORKSPACE=$workspace"
			echo "RUNTIME_ORIGIN_SPEC=$MDLT_ORIGIN"
			echo "HOLDER_PID=$holderPid"
			echo "CONSOLE_PID=$consolePid"
			echo "# send a command:  printf '%s\n' 'your command' > \"$fifo\""
			echo "# or:              DistroAgentsTools.fn.sh --console-send $channelId -- your command here"
			echo "# tail output:     tail -f \"$log\""
			echo "# stop session:    DistroAgentsTools.fn.sh --console-stop $channelId"
			return 0
		;;

		--console-send)
			shift
			local ref="$1"
			shift || true
			local channelDir
			channelDir="$( DistroAgentsToolsResolveChannelDir "$ref" )" || { set +e ; return 1 ; }

			## Checks liveness and restarts rather than trusting the channel is
			## alive: a dead console still leaves its directory and FIFO special
			## file behind (only --console-stop's rm -rf removes them), so
			## writing here with no liveness check doesn't fail loud -- POSIX
			## FIFO semantics mean opening the write end with no reader on the
			## other end blocks indefinitely (see --console-stop's own comment
			## below for that exact hang). Same liveness test --console-start's own
			## idempotent-reuse logic already uses (kill -0 on both stored
			## PIDs); same recreate mechanism too (self-recursion into
			## --console-start, which already wipes a stale channel and mints a
			## fresh one under the same deterministic channel id -- not a
			## second, parallel restart implementation). meta.env (written by
			## --console-start) is the source of truth for which
			## workspace/console/ttl to restart with, since $ref may have been
			## a raw path rather than a channel id.
			local consolePid holderPid
			if [ -f "$channelDir/console.pid" ] ; then consolePid="$( cat "$channelDir/console.pid" 2>/dev/null )" ; fi
			if [ -f "$channelDir/holder.pid" ] ; then holderPid="$( cat "$channelDir/holder.pid" 2>/dev/null )" ; fi
			if [ -z "$consolePid" ] || ! kill -0 "$consolePid" 2>/dev/null \
				|| [ -z "$holderPid" ] || ! kill -0 "$holderPid" 2>/dev/null ; then
				echo "# $MDSC_CMD --console-send: console dead, auto-restarting: $channelDir" >&2
				if [ ! -f "$channelDir/meta.env" ] ; then
					echo "⛔ ERROR: $MDSC_CMD --console-send: console dead and no meta.env to restart from: $channelDir" >&2
					set +e ; return 1
				fi
				local MDAT_WORKSPACE MDAT_CONSOLE MDAT_TTL
				MDAT_WORKSPACE="$( sed -n 's/^MDAT_WORKSPACE=//p' "$channelDir/meta.env" | head -n 1 )"
				MDAT_CONSOLE="$( sed -n 's/^MDAT_CONSOLE=//p' "$channelDir/meta.env" | head -n 1 )"
				MDAT_TTL="$( sed -n 's/^MDAT_TTL=//p' "$channelDir/meta.env" | head -n 1 )"
				[ -n "$MDAT_WORKSPACE" ] || { echo "⛔ ERROR: $MDSC_CMD --console-send: missing MDAT_WORKSPACE in meta.env: $channelDir" >&2 ; set +e ; return 1 ; }
				case "$MDAT_CONSOLE" in DistroSourceConsole.sh|DistroDeployConsole.sh) ;; *) echo "⛔ ERROR: $MDSC_CMD --console-send: invalid MDAT_CONSOLE in meta.env: $channelDir" >&2 ; set +e ; return 1 ;; esac
				case "$MDAT_TTL" in ''|*[!0-9]*) echo "⛔ ERROR: $MDSC_CMD --console-send: invalid MDAT_TTL in meta.env: $channelDir" >&2 ; set +e ; return 1 ;; esac
				[ "$MDAT_TTL" -gt 0 ] || { echo "⛔ ERROR: $MDSC_CMD --console-send: invalid MDAT_TTL in meta.env: $channelDir" >&2 ; set +e ; return 1 ; }
				DistroAgentsTools --console-start --override-workspace "$MDAT_WORKSPACE" --console "$MDAT_CONSOLE" --ttl "$MDAT_TTL" >/dev/null || {
					echo "⛔ ERROR: $MDSC_CMD --console-send: auto-restart failed for $channelDir" >&2
					set +e ; return 1
				}
				## channelDir is deterministic (workspace+console hash), so
				## it's unchanged after restart -- no need to re-resolve $ref.
			fi

			local fifo="$channelDir/fifo"
			if [ ! -p "$fifo" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --console-send: fifo not found: $fifo" >&2
				set +e ; return 1
			fi
			if [ "$1" = "--" ] ; then shift ; fi
			if [ $# -gt 0 ] ; then
				printf '%s\n' "$*" > "$fifo"
			else
				cat > "$fifo"
			fi
			return 0
		;;

		--console-stop)
			shift
			local ref="$1"
			local channelDir
			channelDir="$( DistroAgentsToolsResolveChannelDir "$ref" )" || { set +e ; return 1 ; }

			## NOTE: under `set -e`, a bare `[ test ] && command` used as a plain
			## statement aborts this whole branch the moment the test (or the
			## command) fails — e.g. no fifo, or the process already exited on
			## its own. Every check below is an `if`/`|| true`, never a bare
			## `&&`, so a partial/already-dead session still reaches the final
			## `rm -rf` instead of leaving a half-cleaned channel dir behind.
			## Opening a FIFO for writing blocks indefinitely if there's no
			## reader on the other end (POSIX FIFO semantics, not a bash
			## quirk). A channel whose console process already died still
			## leaves the FIFO special file behind, so an unconditional write
			## here can hang --console-stop forever. Only attempt the graceful
			## "exit" nudge while the console process is confirmed alive -- if
			## it's already dead there's no reader to nudge, and the hard-kill
			## path below still runs either way.
			local pid
			if [ -f "$channelDir/console.pid" ] ; then
				pid="$( cat "$channelDir/console.pid" 2>/dev/null )"
			fi

			local fifo="$channelDir/fifo"
			if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && [ -p "$fifo" ] ; then
				printf 'exit\n' > "$fifo" 2>/dev/null || true
				sleep 1
			fi

			if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null ; then
				kill "$pid" 2>/dev/null || true
				sleep 1
				if kill -0 "$pid" 2>/dev/null ; then kill -9 "$pid" 2>/dev/null || true ; fi
			fi
			if [ -f "$channelDir/holder.pid" ] ; then
				pid="$( cat "$channelDir/holder.pid" )"
				if kill -0 "$pid" 2>/dev/null ; then
					kill "$pid" 2>/dev/null || true
					sleep 1
					if kill -0 "$pid" 2>/dev/null ; then kill -9 "$pid" 2>/dev/null || true ; fi
				fi
			fi

			local channelId ; channelId="${channelDir##*/}"
			rm -rf "$channelDir"
			echo "STOPPED=$channelId"
			return 0
		;;

		--console-list)
			shift
			local workspaceArg
			while [ $# -gt 0 ] ; do
				case "$1" in
					--override-workspace)
						workspaceArg="$2" ; shift 2
					;;
					*)
						echo "⛔ ERROR: $MDSC_CMD --console-list: invalid option: $1" >&2
						set +e ; return 1
					;;
				esac
			done

			## Default scope is the tool's own workspace — per design direction,
			## --console-list must not surface every workspace's channels by
			## default, only this one's (or an explicitly overridden one).
			local workspace
			workspace="$( DistroAgentsToolsResolveWorkspace "$workspaceArg" )" || { set +e ; return 1 ; }

			local base="${TMPDIR:-/tmp}"
			local dir found
			found=0
			for dir in "$base/${MDAT_CHANNEL_PREFIX}."* ; do
				[ -d "$dir" ] || continue
				local ws cons consoleAlive holderAlive
				ws="$( sed -n 's/^MDAT_WORKSPACE=//p' "$dir/meta.env" 2>/dev/null )"
				[ "$ws" = "$workspace" ] || continue
				found=1
				local id ; id="${dir##*/}"
				cons="$( sed -n 's/^MDAT_CONSOLE=//p' "$dir/meta.env" 2>/dev/null )"
				consoleAlive="dead"
				holderAlive="dead"
				[ -f "$dir/console.pid" ] && kill -0 "$( cat "$dir/console.pid" )" 2>/dev/null && consoleAlive="alive"
				[ -f "$dir/holder.pid" ] && kill -0 "$( cat "$dir/holder.pid" )" 2>/dev/null && holderAlive="alive"
				echo "$id  console=$consoleAlive holder=$holderAlive workspace=${ws:-?} console-script=${cons:-?}"
			done
			[ "$found" = "1" ] || echo "(no active channels for workspace: $workspace)"
			return 0
		;;

		--agents-config-option)
			. "$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/LocalTools.Config.include"
			return $?
		;;

		## Per-member config-scope selector -- friendly name for
		## `--agents-config-option <member-name> <operation> [args...]`
		## (this file's own real per-entity config engine, see that arm
		## above), reached via self-recursion into `DistroAgentsTools`
		## itself, per this file's own established convention (see header
		## comment) -- not a direct LocalTools.Config.include source.
		## `--members --backend <member-name> <operation> [args...]`
		## (mirrors myx.distro-remote's own `--backend` flag) is a synonym
		## that forwards here.
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

		## Real, standalone op -- not just an internal-only fallback. Direct
		## curl SMTP send (matches the curl --url smtp://... --ssl-reqd pattern
		## already verified working in this environment for outbound mail, not
		## a new untested mechanism), reusing the same EMAIL_* keys the comms
		## sweep already reads for IMAP. --member-slack-send-message's
		## exhausted-retry fallback calls this same branch via self-recursion.
		--send-email-message)
			shift
			local recipients subject bodyLines state="recipients" bodyFromStdin="false" bodyFromFile="false"
			while [ $# -gt 0 ] ; do
				case "$1" in
					--)
						if [ "$state" = "recipients" ] ; then state="subject"
						elif [ "$state" = "subject" ] ; then state="body"
						fi
						shift
					;;
					--from-stdin)
						## Standardized stdin-content flag (same name as
						## --member-slack-send-message's), only meaningful in the body state --
						## reads the whole body from stdin instead of trailing argv
						## lines, avoiding shell-escaping/quoting fragility from
						## multi-line free text as separate argv words. Outside the
						## body state it's treated as ordinary literal content
						## (matches this loop's existing catch-all behavior for any
						## other unrecognized token) since recipients/subject aren't
						## meant to come from stdin.
						if [ "$state" = "body" ] ; then
							if [ "$bodyFromFile" = "true" ] ; then
								echo "⛔ ERROR: $MDSC_CMD --send-email-message: --from-stdin given alongside --from-file -- use one or the other, not both" >&2
								set +e ; return 1
							fi
							bodyFromStdin="true" ; shift
						else
							case "$state" in
								recipients) recipients="$recipients $1" ;;
								subject) subject="$subject $1" ;;
							esac
							shift
						fi
					;;
					--from-file)
						## Same motivation as --member-slack-send-message's own --from-file (lets a
						## caller write the body to a plain temp file first, a normal
						## Write tool call, and still invoke this op as one
						## single-line command). Validated and consumed
						## directly here, at point of use, into the existing
						## bodyLines variable -- a separate bodyFromFile flag (not a
						## bodyFromFile="" sentinel checked later) records the source
						## only to gate the conflict checks against --from-stdin/
						## trailing argv above/below; bodyLines itself is never held
						## as an empty-default placeholder.
						if [ "$state" = "body" ] ; then
							if [ "$bodyFromStdin" = "true" ] ; then
								echo "⛔ ERROR: $MDSC_CMD --send-email-message: --from-file given alongside --from-stdin -- use one or the other, not both" >&2
								set +e ; return 1
							fi
							if [ -z "$2" ] || [ ! -f "$2" ] ; then
								echo "⛔ ERROR: $MDSC_CMD --send-email-message: --from-file: file not found: $2" >&2
								set +e ; return 1
							fi
							bodyLines="$( cat "$2" )"
							bodyFromFile="true"
							shift 2
						else
							case "$state" in
								recipients) recipients="$recipients $1" ;;
								subject) subject="$subject $1" ;;
							esac
							shift
						fi
					;;
					*)
						case "$state" in
							recipients) recipients="$recipients $1" ;;
							subject) subject="$subject $1" ;;
							body)
								if [ "$bodyFromFile" = "true" ] ; then
									echo "⛔ ERROR: $MDSC_CMD --send-email-message: --from-file given alongside trailing body argv -- use one or the other, not both" >&2
									set +e ; return 1
								fi
								bodyLines="$bodyLines
$1"
							;;
						esac
						shift
					;;
				esac
			done
			recipients="${recipients# }"
			subject="${subject# }"

			if [ "$bodyFromStdin" = "true" ] ; then
				if [ -n "$bodyLines" ] ; then
					echo "⛔ ERROR: $MDSC_CMD --send-email-message: --from-stdin given alongside trailing body argv -- use one or the other, not both" >&2
					set +e ; return 1
				fi
				bodyLines="$( cat )"
			fi

			if [ -z "$recipients" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --send-email-message: at least one <email@address> required" >&2
				set +e ; return 1
			fi
			if [ -z "$subject" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --send-email-message: syntax is <email@address>... -- <subject> -- <body...>" >&2
				set +e ; return 1
			fi

			local emailUser emailPass smtpHost smtpPort
			emailUser="$( DistroAgentsTools --agents-config-option magic-coordinator --select EMAIL_USER )"
			emailPass="$( DistroAgentsTools --agents-config-option magic-coordinator --select EMAIL_APP_PASSWORD )"
			smtpHost="$( DistroAgentsTools --agents-config-option magic-coordinator --select EMAIL_SMTP_HOST )"
			smtpPort="$( DistroAgentsTools --agents-config-option magic-coordinator --select EMAIL_SMTP_PORT )"

			if [ -z "$emailUser" ] || [ -z "$emailPass" ] || [ -z "$smtpHost" ] || [ -z "$smtpPort" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --send-email-message: EMAIL_USER/EMAIL_APP_PASSWORD/EMAIL_SMTP_HOST/EMAIL_SMTP_PORT not fully set in .local/.agents" >&2
				set +e ; return 1
			fi

			local msgFile
			msgFile="$( mktemp )" || { set +e ; return 1 ; }
			{
				printf 'From: %s\n' "$emailUser"
				printf 'To: %s\n' "$( printf '%s' "$recipients" | tr ' ' ',' )"
				printf 'Subject: %s\n' "$subject"
				printf '\n'
				printf '%s\n' "$bodyLines"
			} > "$msgFile"

			local netrcFile
			netrcFile="$( mktemp )" || { rm -f "$msgFile" ; set +e ; return 1 ; }
			chmod 600 "$netrcFile"
			printf 'machine %s login %s password %s\n' "$smtpHost" "$emailUser" "$emailPass" > "$netrcFile"

			local rcptArgs=() addr
			for addr in $recipients ; do
				rcptArgs+=( --mail-rcpt "$addr" )
			done

			echo "# $MDSC_CMD --send-email-message: sending via smtp://${smtpHost}:${smtpPort} to: $recipients" >&2
			curl -sS --url "smtp://${smtpHost}:${smtpPort}" --ssl-reqd \
				--netrc-file "$netrcFile" \
				--mail-from "$emailUser" "${rcptArgs[@]}" \
				--upload-file "$msgFile"
			local rc=$?

			rm -f "$msgFile" "$netrcFile"

			if [ "$rc" -eq 0 ] ; then
				echo "# $MDSC_CMD --send-email-message: sent to $recipients" >&2
			else
				echo "⛔ $MDSC_CMD --send-email-message: FAILED (curl exit $rc)" >&2
			fi
			return "$rc"
		;;

		## IMAP STATUS check (unseen count) plus a UID SEARCH UNSEEN (which
		## UIDs those are) -- not a full fetch, matches what the comms-sweep
		## routine's Check step needs. STATUS alone gives a count with no way
		## to discover which UID(s) to hand to --comms-email-read. UID SEARCH
		## returns a clean single-line response through curl --request
		## (unlike UID FETCH's literal-string body, which does not come
		## through this way -- that's why --comms-email-read uses curl's
		## URL-based ;UID= addressing instead, not --request).
		--comms-email-check)
			shift
			local imapHost imapUser imapPass
			imapHost="$( DistroAgentsTools --agents-config-option magic-coordinator --select EMAIL_IMAP_HOST )"
			imapUser="$( DistroAgentsTools --agents-config-option magic-coordinator --select EMAIL_USER )"
			imapPass="$( DistroAgentsTools --agents-config-option magic-coordinator --select EMAIL_APP_PASSWORD )"
			if [ -z "$imapHost" ] || [ -z "$imapUser" ] || [ -z "$imapPass" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --comms-email-check: EMAIL_IMAP_HOST/EMAIL_USER/EMAIL_APP_PASSWORD not fully set in .local/.agents" >&2
				set +e ; return 1
			fi
			curl -s --url "imaps://${imapHost}/INBOX" --user "${imapUser}:${imapPass}" \
				--request "STATUS INBOX (UNSEEN)"
			curl -s --url "imaps://${imapHost}/INBOX" --user "${imapUser}:${imapPass}" \
				--request "UID SEARCH UNSEEN"
			return $?
		;;

		## Same rationale as --comms-email-check above -- Trello's own read side of
		## the same precoded-tooling gap. Unread notifications only (matches
		## the comms-sweep routine's Check step), not a full board read.
		--comms-trello-check)
			shift
			local trelloKey trelloToken
			trelloKey="$( DistroAgentsTools --agents-config-option magic-coordinator --select TRELLO_KEY )"
			trelloToken="$( DistroAgentsTools --agents-config-option magic-coordinator --select TRELLO_TOKEN )"
			if [ -z "$trelloKey" ] || [ -z "$trelloToken" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --comms-trello-check: TRELLO_KEY/TRELLO_TOKEN not fully set in .local/.agents" >&2
				set +e ; return 1
			fi
			curl -s "https://api.trello.com/1/members/me/notifications?read_filter=unread&key=${trelloKey}&token=${trelloToken}"
			return $?
		;;

		## --check-*/--sweep-read-incoming-comms are deliberately lightweight scanning
		## tools (short/pretty descriptions) -- they will legitimately
		## truncate/summarize. --read-* is the different, complementary
		## concern: given one specific message/thread's own id/address,
		## retrieve its FULL content (all meta-info, reactions, formatting,
		## images/attachments) for actually processing that one item in
		## detail, not scanning for what's new. Always returns the full raw
		## API response (never pretty-formatted) -- "full" is the entire
		## point of this op, there is no lossy default here.
		--comms-slack-read)
			shift
			local target="$1"
			shift || true
			if [ -z "$target" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --comms-slack-read: target required -- <channel>:<ts> only. Unlike --comms-slack-check, this op does not accept the magic-team/human-owner/event-track/event-alert channel shortcuts: each of those names a channel, and this op retrieves one specific message, which needs its own <ts>. That constraint is enforced further down by this same arm's own '<ts> is required' check." >&2
				set +e ; return 1
			fi

			local wantThread="false"
			while [ $# -gt 0 ] ; do
				case "$1" in
					--thread)
						wantThread="true" ; shift
					;;
					*)
						echo "⛔ ERROR: $MDSC_CMD --comms-slack-read: invalid option: $1" >&2
						set +e ; return 1
					;;
				esac
			done

			local resolved rc channel threadTs
			resolved="$( DistroAgentsToolsResolveTarget "$target" )" && rc=0 || rc=$?
			case "$rc" in
				0)
					channel="$( printf '%s\n' "$resolved" | sed -n 's/^CHANNEL=//p' )"
					threadTs="$( printf '%s\n' "$resolved" | sed -n 's/^THREAD_TS=//p' )"
				;;
				*)
					echo "⛔ ERROR: $MDSC_CMD --comms-slack-read: could not resolve target '$target' -- pass <channel>:<ts> for a specific message" >&2
					set +e ; return 1
				;;
			esac
			if [ -z "$threadTs" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --comms-slack-read: a specific <ts> is required (magic-team/human-owner alone identify a channel, not one message) -- use <channel>:<ts>" >&2
				set +e ; return 1
			fi

			local token
			token="$( DistroAgentsTools --agents-config-option magic-coordinator --select SLACK_BOT_TOKEN )"
			if [ -z "$token" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --comms-slack-read: SLACK_BOT_TOKEN not set in .local/.agents" >&2
				set +e ; return 1
			fi

			local headerFile
			headerFile="$( mktemp )" || { set +e ; return 1 ; }
			chmod 600 "$headerFile"
			trap 'rm -f "$headerFile"' EXIT
			printf 'Authorization: Bearer %s\n' "$token" > "$headerFile"

			if [ "$wantThread" = "true" ] ; then
				## Full thread -- every reply, full detail (reactions/files/
				## blocks all come through untouched since this is raw, not
				## piped through the pretty formatter).
				echo "# $MDSC_CMD --comms-slack-read: GET conversations.replies channel=$channel ts=$threadTs (full thread)" >&2
				curl -sS -G "https://slack.com/api/conversations.replies" -H "@$headerFile" \
					--data-urlencode "channel=$channel" --data-urlencode "ts=$threadTs"
			else
				## Exactly one message -- latest=oldest=ts with inclusive+limit=1
				## pins conversations.history to that single message, not a
				## history window.
				echo "# $MDSC_CMD --comms-slack-read: GET conversations.history channel=$channel ts=$threadTs (single message)" >&2
				curl -sS -G "https://slack.com/api/conversations.history" -H "@$headerFile" \
					--data-urlencode "channel=$channel" --data-urlencode "latest=$threadTs" \
					--data-urlencode "oldest=$threadTs" --data-urlencode "inclusive=true" \
					--data-urlencode "limit=1"
			fi
			echo

			rm -f "$headerFile"
			trap - EXIT
			return 0
		;;

		## Full IMAP fetch (complete RFC822 message: headers + body + MIME
		## multipart, attachments included as their raw MIME parts) for one
		## specific message by UID -- contrast with --comms-email-check's
		## STATUS-only unread count. Uses curl's URL-based
		## ;UID=<uid> addressing (no ;SECTION= means the whole message, per
		## curl's own IMAP URL support) -- `--request "UID FETCH..."` does
		## not return literal-string FETCH bodies through stdout at all, so
		## this uses curl's URL-based addressing instead.
		## Reading is NOT a decision about the message. By default this op
		## leaves \Seen untouched: it fetches with BODY.PEEK[], which is the
		## IMAP-level way to say "give me the body without marking it read".
		## Marking seen is a separate, explicit choice the caller makes once it
		## knows what the message actually is -- which is why
		## --comms-email-mark-seen exists as its own op. Before this, the fetch
		## marked seen as a protocol side effect, so the two ops contradicted
		## each other and one of them was redundant.
		##
		## --seen is that choice expressed inline, for the common case where a
		## caller reads and immediately concludes. It runs AFTER a successful
		## read and delegates to --comms-email-mark-seen rather than issuing
		## its own STORE -- one mechanism for the mutation, already proven,
		## with this op owning only the decision to invoke it.
		##
		## Deliberately a decision applied after the read, not a fetch mode:
		## that is what keeps the extensible shape reachable. A later
		## "mark seen everything matching <subject pattern>" selector is the
		## same decision applied to a set, and can call the same mark step
		## without this op changing. A --seen implemented as a fetch flag
		## (BODY[] instead of BODY.PEEK[]) would have foreclosed that, by
		## welding the decision to the retrieval.
		--comms-email-read)
			shift
			local uid="$1"
			shift || true
			if [ -z "$uid" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --comms-email-read: UID required" >&2
				set +e ; return 1
			fi
			local markSeen="false"
			while [ $# -gt 0 ] ; do
				case "$1" in
					--seen)
						markSeen="true" ; shift
					;;
					*)
						echo "⛔ ERROR: $MDSC_CMD --comms-email-read: invalid option: $1" >&2
						set +e ; return 1
					;;
				esac
			done

			local imapHost imapUser imapPass
			imapHost="$( DistroAgentsTools --agents-config-option magic-coordinator --select EMAIL_IMAP_HOST )"
			imapUser="$( DistroAgentsTools --agents-config-option magic-coordinator --select EMAIL_USER )"
			imapPass="$( DistroAgentsTools --agents-config-option magic-coordinator --select EMAIL_APP_PASSWORD )"
			if [ -z "$imapHost" ] || [ -z "$imapUser" ] || [ -z "$imapPass" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --comms-email-read: EMAIL_IMAP_HOST/EMAIL_USER/EMAIL_APP_PASSWORD not fully set in .local/.agents" >&2
				set +e ; return 1
			fi

			echo "# $MDSC_CMD --comms-email-read: fetching full message UID=$uid (BODY.PEEK -- \\Seen not set by this read)" >&2
			## BODY.PEEK[] via --request against the mailbox URL, NOT curl's
			## own ;UID= URL addressing: that addressing issues a plain
			## FETCH BODY[], which sets \Seen as an unavoidable protocol side
			## effect and has no peek variant. The trade-off is real and is
			## recorded in this arm's own older comment above -- --request
			## FETCH has its own literal-string return behavior -- so if a
			## future change reverts to URL addressing for that reason, it
			## reintroduces the side effect and must say so out loud.
			curl -sS --url "imaps://${imapHost}/INBOX" --user "${imapUser}:${imapPass}" \
				--request "UID FETCH ${uid} BODY.PEEK[]"
			local readRc=$?
			if [ "$readRc" -ne 0 ] ; then
				echo "⛔ ERROR: $MDSC_CMD --comms-email-read: fetch failed for UID=$uid (rc=$readRc) -- \\Seen not touched" >&2
				set +e ; return "$readRc"
			fi
			## Mutation strictly after a successful read, never before: a
			## failed read must leave the message exactly as it was found.
			if [ "$markSeen" = "true" ] ; then
				DistroAgentsTools --comms-email-mark-seen "$uid" || {
					echo "⛔ ERROR: $MDSC_CMD --comms-email-read: message was read, but --seen failed to mark UID=$uid -- the read output above is still valid" >&2
					set +e ; return 1
				}
			fi
			return 0
		;;

		## Full detail for one specific Trello notification by id -- the
		## comms-sweep's own unit of "a message" for Trello (per
		## --comms-trello-check's own read_filter=unread notifications list).
		## Contrast with --comms-trello-check's unread-list-only scan.
		--comms-trello-read)
			shift
			local notificationId="$1"
			shift || true
			if [ -z "$notificationId" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --comms-trello-read: notification id required" >&2
				set +e ; return 1
			fi

			local trelloKey trelloToken
			trelloKey="$( DistroAgentsTools --agents-config-option magic-coordinator --select TRELLO_KEY )"
			trelloToken="$( DistroAgentsTools --agents-config-option magic-coordinator --select TRELLO_TOKEN )"
			if [ -z "$trelloKey" ] || [ -z "$trelloToken" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --comms-trello-read: TRELLO_KEY/TRELLO_TOKEN not fully set in .local/.agents" >&2
				set +e ; return 1
			fi

			echo "# $MDSC_CMD --comms-trello-read: fetching full notification id=$notificationId" >&2
			curl -sS "https://api.trello.com/1/notifications/${notificationId}?fields=all&member=true&memberCreator=true&card=true&card_fields=all&board=true&board_fields=all&key=${trelloKey}&token=${trelloToken}"
			return $?
		;;

		## Reads Slack activity for ONE specific target -- a required
		## <magic-team|human-owner|event-track|event-alert|<channel>:<ts>>,
		## no "check everything" mode (that's --sweep-read-incoming-comms's
		## job specifically, see its own comment below; conflating the two
		## is a real design bug). Deliberately
		## does NOT parse the Slack JSON response internally -- see the
		## --pretty/--raw handling near the bottom of this branch. Target
		## grammar mirrors --member-slack-send-message's
		## (magic-team|human-owner|event-track|event-alert|<channel>:<ts>) so a
		## bare channel name means "history" and a <channel>:<ts> pair means
		## "replies in that thread" -- no new addressing scheme invented.
		--comms-slack-check)
			shift
			local target="$1"
			shift || true

			if [ -z "$target" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --comms-slack-check: target required (magic-team|human-owner|event-track|event-alert|<channel>:<ts>)" >&2
				set +e ; return 1
			fi

			## Pretty (formatted "ts | user | text" lines) is the default, not
			## an opt-in. --raw is the escape hatch for the rare case the full raw JSON is
			## actually needed (e.g. inspecting reply_count/thread metadata
			## fields the pretty formatter doesn't surface).
			local oldest pretty="true"
			while [ $# -gt 0 ] ; do
				case "$1" in
					--oldest)
						oldest="$2" ; shift 2
					;;
					--raw)
						pretty="false" ; shift
					;;
					*)
						echo "⛔ ERROR: $MDSC_CMD --comms-slack-check: invalid option: $1" >&2
						set +e ; return 1
					;;
				esac
			done

			local resolved rc channel threadTs
			resolved="$( DistroAgentsToolsResolveTarget "$target" )" && rc=0 || rc=$?
			case "$rc" in
				0)
					channel="$( printf '%s\n' "$resolved" | sed -n 's/^CHANNEL=//p' )"
					threadTs="$( printf '%s\n' "$resolved" | sed -n 's/^THREAD_TS=//p' )"
				;;
				2)
					echo "⛔ ERROR: $MDSC_CMD --comms-slack-check: unrecognized target: $target" >&2
					set +e ; return 1
				;;
				*)
					echo "⛔ ERROR: $MDSC_CMD --comms-slack-check: could not resolve a channel for target '$target' -- check SLACK_CHANNEL_MAGIC_TEAM/SLACK_CHANNEL_HUMAN_OWNER in .local/.agents" >&2
					set +e ; return 1
				;;
			esac

			echo "## target=$target channel=$channel"

			local endpoint
			if [ -n "$threadTs" ] ; then
				endpoint="https://slack.com/api/conversations.replies"
			else
				endpoint="https://slack.com/api/conversations.history"
			fi

			echo "# $MDSC_CMD --comms-slack-check: GET $endpoint channel=$channel${threadTs:+ ts=$threadTs}${oldest:+ oldest=$oldest}" >&2

			local token
			token="$( DistroAgentsTools --agents-config-option magic-coordinator --select SLACK_BOT_TOKEN )"
			if [ -z "$token" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --comms-slack-check: SLACK_BOT_TOKEN not set (see --agents-config-option magic-coordinator --upsert)" >&2
				set +e ; return 1
			fi

			## Same private-header-file mechanism as --member-slack-send-message -- token never
			## touches argv/ps, header file is chmod 600 and trap-cleaned on exit.
			local headerFile
			headerFile="$( mktemp )" || { set +e ; return 1 ; }
			chmod 600 "$headerFile"
			trap 'rm -f "$headerFile"' EXIT
			printf 'Authorization: Bearer %s\n' "$token" > "$headerFile"

			local curlArgs=( -sS -G "$endpoint" -H "@$headerFile" --data-urlencode "channel=$channel" )
			[ -z "$threadTs" ] || curlArgs+=( --data-urlencode "ts=$threadTs" )
			[ -z "$oldest" ] || curlArgs+=( --data-urlencode "oldest=$oldest" )

			## No retry logic here, by design -- applies to the whole --check-*
			## family, not just this op: if a check fails, it fails, full stop.
			##
			## --pretty pipes the response through this repo's own
			## sh-lib/AgentSlackMessagesFormat.awk (reuses myx.common's
			## agentMcpJsonParseRequest.awk parsing engine verbatim, just a
			## different leaf-emission target -- lives here, not in
			## myx.common, since it's 100% specific to this tool's own
			## Slack-reading need) to print clean "ts | user | text" lines
			## directly -- this is the actual fix for the "why does every
			## caller keep hand-rolling a python3 -c 'import json...'
			## one-liner just to read a Slack reply" pattern, not another
			## one-off workaround.
			local awkStatus=0
			if [ "$pretty" = "true" ] ; then
				curl "${curlArgs[@]}" | LC_ALL=C awk -f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentSlackMessagesFormat.awk" || awkStatus=$?
			else
				curl "${curlArgs[@]}"
				echo
			fi

			rm -f "$headerFile"
			trap - EXIT

			if [ "$awkStatus" != "0" ] ; then
				set +e ; return 1
			fi
			return 0
		;;

		## Coordinator comms-id resolver extracted to dedicated include
		## (shared-tooling path, keeps dispatcher lean and keeps resolver's
		## parsing helpers out of this main script).
		--magic-comms-slack-resolve-ids)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MagicComms.include"
		;;

		## The `reactions.add` wrapper -- the per-message Slack-reaction-tracking
		## design (`routine-communication-sweep`, `routine-board-actualisation`'s
		## pending-reaction lookup) uses this as its sanctioned way to actually
		## post a reaction. Same target grammar as
		## --comms-slack-read/--comms-slack-check (<channel>:<ts>, via
		## DistroAgentsToolsResolveTarget) plus a required emoji name (no
		## colons, matches Slack's own reactions.add `name` field exactly).
		--comms-slack-react)
			shift
			local target="$1"
			shift || true
			local emoji="$1"
			shift || true

			if [ -z "$target" ] || [ -z "$emoji" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --comms-slack-react: syntax is <channel>:<ts> <emoji-name>" >&2
				set +e ; return 1
			fi

			local resolved rc channel threadTs
			resolved="$( DistroAgentsToolsResolveTarget "$target" )" && rc=0 || rc=$?
			case "$rc" in
				0)
					channel="$( printf '%s\n' "$resolved" | sed -n 's/^CHANNEL=//p' )"
					threadTs="$( printf '%s\n' "$resolved" | sed -n 's/^THREAD_TS=//p' )"
				;;
				*)
					echo "⛔ ERROR: $MDSC_CMD --comms-slack-react: could not resolve target '$target' -- pass <channel>:<ts>" >&2
					set +e ; return 1
				;;
			esac
			if [ -z "$threadTs" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --comms-slack-react: a specific <ts> is required -- use <channel>:<ts>" >&2
				set +e ; return 1
			fi

			local token
			token="$( DistroAgentsTools --agents-config-option magic-coordinator --select SLACK_BOT_TOKEN )"
			if [ -z "$token" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --comms-slack-react: SLACK_BOT_TOKEN not set in .local/.agents" >&2
				set +e ; return 1
			fi

			local headerFile
			headerFile="$( mktemp )" || { set +e ; return 1 ; }
			chmod 600 "$headerFile"
			trap 'rm -f "$headerFile"' EXIT
			printf 'Authorization: Bearer %s\n' "$token" > "$headerFile"

			echo "# $MDSC_CMD --comms-slack-react: POST reactions.add channel=$channel timestamp=$threadTs name=$emoji" >&2
			local response
			response="$( curl -sS -X POST "https://slack.com/api/reactions.add" -H @"$headerFile" \
				--data-urlencode "channel=$channel" --data-urlencode "timestamp=$threadTs" \
				--data-urlencode "name=$emoji" )"

			rm -f "$headerFile"
			trap - EXIT

			printf '%s\n' "$response"
			if printf '%s' "$response" | grep -q '"ok":true' ; then
				return 0
			fi
			## already_reacted is a harmless no-op per Slack's own API and per
			## this feature's own design doc, not a real failure to retry.
			if printf '%s' "$response" | grep -q '"error":"already_reacted"' ; then
				echo "# $MDSC_CMD --comms-slack-react: already reacted (no-op, not an error)" >&2
				return 0
			fi
			echo "⛔ $MDSC_CMD --comms-slack-react: FAILED -- $response" >&2
			set +e ; return 1
		;;

		## NOT a general-purpose "check any Slack target" op -- that's
		## --comms-slack-check, above. This op takes no target at all --
		## it always reads the exact same predefined, pre-configured set of
		## watched sources (both Slack targets, email, Trello) in one
		## optimized combined pass, producing one specific mixed output
		## meant as the initial text source for comms processing. It exists
		## for exactly one caller: magic-coordinator's communication-sweep
		## Check step. If you need to read one specific arbitrary Slack
		## target/thread, call --comms-slack-check directly instead.
		##
		## Thread-follow widening: beyond the plain "freshly active thread"
		## heuristic, this also follows a thread whose parent message (still
		## only within the two watched channels' own already-fetched history
		## page) was posted by Vane, already has Vane among its repliers, or
		## tags Vane in its own text -- see AgentSlackHistoryThreadTargets.awk's
		## own header for the exact selection rule. Still NOT a workspace-wide
		## mention search: a mention/participation outside these two watched
		## channels, or in an old thread parent outside the fetched page,
		## stays undiscoverable here.
		--sweep-read-incoming-comms)
			shift

			local oldest pretty="true"
			while [ $# -gt 0 ] ; do
				case "$1" in
					--oldest)
						oldest="$2" ; shift 2
					;;
					--raw)
						pretty="false" ; shift
					;;
					*)
						echo "⛔ ERROR: $MDSC_CMD --sweep-read-incoming-comms: invalid option: $1 (this op takes no target -- did you mean --comms-slack-check?)" >&2
						set +e ; return 1
					;;
				esac
			done

			local recurseArgs=()
			[ -z "$oldest" ] || recurseArgs+=( --oldest "$oldest" )
			[ "$pretty" = "false" ] && recurseArgs+=( --raw )

			## Resolve Vane's own Slack id once per sweep pass via the
			## existing identity-resolution op (--magic-comms-slack-resolve-ids),
			## never a fresh direct auth.test/$SLACK_BOT_TOKEN call here --
			## credential env vars stay isolated behind that op's own token
			## selection (native SLACK_USER_TOKEN if configured for the
			## member, else the shared bot token), not reached around by new
			## code even for a "cheap" one-off internal lookup. Feeds
			## AgentSlackHistoryThreadTargets.awk's vaneId widening below:
			## follow a thread Vane already posted/replied in, or was tagged
			## in, even when it isn't otherwise "fresh" by --oldest. This is
			## still bounded to whatever conversations.history already
			## returned for the two watched channels below -- NOT a
			## workspace-wide mention search (that needs a user token with
			## search:read, not confirmed available today; deliberately not
			## attempted here).
			local vaneId="" vaneResolveOutput
			## --magic-comms-slack-resolve-ids returns 1 whenever it can't confirm
			## a reachable human-owner target (e.g. a stale/mismatched DM channel
			## for this identity) even though AUTH_USER_ID is already printed and
			## perfectly usable -- that non-zero exit must never propagate here
			## under this script's own `set -e`, or it silently aborts this whole
			## sweep before any output at all. The `|| true` is what makes the
			## already-documented "not a hard failure" graceful-degradation
			## behavior below actually hold.
			vaneResolveOutput="$( DistroAgentsTools --magic-comms-slack-resolve-ids magic-coordinator )" || true
			vaneId="$( printf '%s\n' "$vaneResolveOutput" | sed -n 's/^AUTH_USER_ID=//p' | head -1 )"
			if [ -z "$vaneId" ] ; then
				echo "# $MDSC_CMD --sweep-read-incoming-comms: could not resolve Vane's own Slack user id via --magic-comms-slack-resolve-ids -- tag/thread-participation widening skipped this pass, base watched-channel/thread-freshness sweep unaffected" >&2
			fi

			local name anyChecked=0 resolved channel
			for name in magic-team human-owner ; do
				resolved="$( DistroAgentsToolsResolveTarget "$name" )" || {
					echo "# $MDSC_CMD --sweep-read-incoming-comms: skipping '$name' -- no channel id configured" >&2
					continue
				}
				anyChecked=1
				channel="$( printf '%s\n' "$resolved" | sed -n 's/^CHANNEL=//p' )"
				## Watched-channel pass stays the floor, but we now inspect that raw
				## history page for parent messages whose thread activity is newer
				## than --oldest and immediately follow them with the same
				## --comms-slack-check <channel>:<ts> path. This widens coverage to
				## freshly-active watched-channel threads that are not yet tracked on
				## the board, while keeping the same one-op namespace and output
				## style. It is still NOT a global mention search: old untracked
				## thread parents outside the returned history page remain invisible.
				local historyWithHeader historyHeader historyJson threadTargets threadTarget
				historyWithHeader="$( DistroAgentsTools --comms-slack-check "$channel:" --raw "${recurseArgs[@]}" )" || {
					echo "# $MDSC_CMD --sweep-read-incoming-comms: --comms-slack-check failed for '$name', see error above" >&2
					continue
				}

				historyHeader="$( printf '%s\n' "$historyWithHeader" | sed -n '1p' )"
				historyJson="$( printf '%s\n' "$historyWithHeader" | sed '1d' )"

				if [ "$pretty" = "true" ] ; then
					printf '%s\n' "$historyHeader"
					if ! printf '%s\n' "$historyJson" | LC_ALL=C awk -f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentSlackMessagesFormat.awk" ; then
						echo "# $MDSC_CMD --sweep-read-incoming-comms: pretty-format failed for '$name', see error above" >&2
					fi
				else
					printf '%s\n' "$historyWithHeader"
				fi

				threadTargets="$( printf '%s\n' "$historyJson" | LC_ALL=C awk -v channel="$channel" -v oldest="${oldest:-}" -v vaneId="$vaneId" -f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentSlackHistoryThreadTargets.awk" | sort -u )" || {
					echo "# $MDSC_CMD --sweep-read-incoming-comms: thread-target discovery failed for '$name', see error above" >&2
					threadTargets=""
				}

				while IFS= read -r threadTarget ; do
					[ -z "$threadTarget" ] && continue
					if ! DistroAgentsTools --comms-slack-check "$threadTarget" "${recurseArgs[@]}" ; then
						echo "# $MDSC_CMD --sweep-read-incoming-comms: --comms-slack-check failed for thread '$threadTarget', see error above" >&2
					fi
				done <<- EOF
				$threadTargets
				EOF
			done

			echo "## target=email"
			if ! DistroAgentsTools --comms-email-check ; then
				echo "# $MDSC_CMD --sweep-read-incoming-comms: --comms-email-check failed, see error above" >&2
			else
				anyChecked=1
			fi

			echo "## target=trello"
			if ! DistroAgentsTools --comms-trello-check ; then
				echo "# $MDSC_CMD --sweep-read-incoming-comms: --comms-trello-check failed, see error above" >&2
			else
				anyChecked=1
			fi

			if [ "$anyChecked" = "0" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --sweep-read-incoming-comms: no watched targets configured at all (Slack/email/Trello)" >&2
				set +e ; return 1
			fi
			return 0
		;;

		## Walks .local/.agents/* and flags anything not chmod 700 (dirs) /
		## 600 (files) -- standing defensive layer against a chmod-on-wrong-file
		## bug class (a real --upsert once landed a file at 644 because the old
		## code chmod'd the touched file instead of the temp file that actually
		## replaces it via mv). That root cause is already fixed in
		## LocalTools.Config.include's --upsert; this is the regression
		## guard, not a re-fix.
		--verify-permissions)
			shift
			local dir="$MMDAPP/.local/.agents"
			if [ ! -d "$dir" ] ; then
				echo "# $MDSC_CMD --verify-permissions: $dir does not exist yet (nothing to verify)" >&2
				return 0
			fi

			local failed=0
			local perm
			## BSD stat then GNU stat fallback, inlined here rather than a
			## shared helper function, per this file's actual convention:
			## logic stays inline within the case arm.
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

		## Exercises the --agents-config-option permission-hardening chain
		## under a DELIBERATELY permissive `umask 022`, not whatever the
		## caller's ambient umask happens to be -- testing only under the
		## caller's ambient umask can miss a chmod regression when that umask
		## happens to be restrictive by coincidence (confirmed: this escaped
		## hand testing once, only surfacing under a different umask against
		## the real secrets migration). Uses a disposable probe key (never
		## touches any real credential key) so it's safe to run against the
		## live settings file, and cleans the probe up unconditionally. Calls
		## --verify-permissions via self-recursion, not a private helper.
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

			## Always clean up the probe, pass or fail -- never leave test residue
			## in the real credentials file.
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
			## No path argument by design. Always operates on exactly
			## $MMDAPP/.local/.cleanup -- a fixed, code-determined path, never
			## caller input, which is what makes this safe to route around the
			## `Bash(rm *)` deny in the first place (see CLAUDE.md's
			## DistroAgentsTools gotchas section for why that deny can't be
			## carved into "except .cleanup/*" at the settings.json layer).
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
			## Validates a JSON file (path arg) or stdin (no arg) is
			## syntactically valid, before it's ever handed to curl/an API call.
			## Uses python3 (present on every supported OS here) rather than jq,
			## matching this tool family's existing jq-avoidance convention.
			shift
			local jsonPath="$1"
			if [ -n "$jsonPath" ] ; then
				if [ ! -f "$jsonPath" ] ; then
					echo "⛔ ERROR: $MDSC_CMD --intern-validate-json: file not found: $jsonPath" >&2
					set +e ; return 1
				fi
				if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$jsonPath" >/dev/null 2>&1 ; then
					echo "# $MDSC_CMD --intern-validate-json: valid JSON: $jsonPath" >&2
					return 0
				else
					echo "⛔ ERROR: $MDSC_CMD --intern-validate-json: invalid JSON: $jsonPath" >&2
					set +e ; return 1
				fi
			else
				if python3 -c "import json,sys; json.load(sys.stdin)" >/dev/null 2>&1 ; then
					echo "# $MDSC_CMD --intern-validate-json: valid JSON (stdin)" >&2
					return 0
				else
					echo "⛔ ERROR: $MDSC_CMD --intern-validate-json: invalid JSON (stdin)" >&2
					set +e ; return 1
				fi
			fi
		;;

		--list-md)
			## Replaces the hand-rolled `for f in ...; do wc -l "$f"; done`-style
			## Bash loop agents kept reaching for before editing a batch of
			## markdown/doc files -- each such loop is a fresh, non-matching
			## command string that costs its own permission prompt. Read-only,
			## no credentials, no network -- just
			## existence + line count for a caller-supplied list of paths (not
			## restricted to .md, despite the flag name -- any path works).
			shift
			if [ $# -eq 0 ] ; then
				echo "⛔ ERROR: $MDSC_CMD --list-md: at least one file path required" >&2
				set +e ; return 1
			fi
			local mdPath mdLines mdMissing
			mdMissing=0
			while [ $# -gt 0 ] ; do
				mdPath="$1"
				shift
				if [ -f "$mdPath" ] ; then
					mdLines="$( wc -l < "$mdPath" | tr -d '[:space:]' )"
					echo "$mdPath: $mdLines lines"
				else
					echo "$mdPath: MISSING"
					mdMissing=1
				fi
			done
			if [ "$mdMissing" -eq 1 ] ; then
				set +e ; return 1
			fi
			return 0
		;;

		## No sanctioned read-only listing op existed for skill-folder files
		## before this (--write-board-item/--member-upsert-* cover different,
		## specific
		## write targets, not this). find-based (not a hand-rolled directory
		## walk), pure path listing -- no per-file stat call, so this stays
		## fast even across the whole skill-root (measured: the mtime variant
		## below took ~3s over 678 files; this one is the no-stat fast path,
		## sub-second). Takes zero or more optional scope arguments, each
		## either a bare path relative to the skill-root
		## ($HOME/.claude/skills/) or an absolute path that must resolve
		## inside it (anything outside is rejected, not silently ignored); a
		## bare file scopes to just that file, a directory scopes
		## recursively. No arguments means the whole skill-root. Prints one
		## skill-root-relative path per matched file (never absolute),
		## sorted alphabetically. A missing or outside-skill-root scope
		## argument is reported and skipped, not a hard abort -- matches
		## --list-md's own per-path error handling, so one bad argument
		## among several doesn't lose the rest of the listing. See
		## --librarian-list-team-files-dates below for the same listing with
		## per-file modification dates (slower, real stat overhead).
		--librarian-list-team-files)
			shift
			local skillRoot="$HOME/.claude/skills"
			local hadError="false"
			local pathsTmp
			pathsTmp="$( mktemp )" || { set +e ; return 1 ; }
			trap 'rm -f "$pathsTmp"' EXIT

			if [ $# -eq 0 ] ; then
				find -L "$skillRoot" -type f 2>/dev/null > "$pathsTmp" || true
			else
				: > "$pathsTmp"
				while [ $# -gt 0 ] ; do
					local argPath="$1"
					shift
					local resolvedPath="$argPath"
					case "$resolvedPath" in
						/*) : ;;
						*) resolvedPath="$skillRoot/$resolvedPath" ;;
					esac
					case "$resolvedPath" in
						"$skillRoot"|"$skillRoot"/*) : ;;
						*)
							echo "⛔ ERROR: $MDSC_CMD --librarian-list-team-files: path outside skill-root, skipping: $argPath" >&2
							hadError="true"
							continue
						;;
					esac
					if [ ! -e "$resolvedPath" ] ; then
						echo "⛔ ERROR: $MDSC_CMD --librarian-list-team-files: not found, skipping: $resolvedPath" >&2
						hadError="true"
						continue
					fi
					find -L "$resolvedPath" -type f 2>/dev/null >> "$pathsTmp" || true
				done
			fi

			while IFS= read -r f ; do
				printf '%s\n' "${f#"$skillRoot"/}"
			done < "$pathsTmp" | sort

			rm -f "$pathsTmp"
			trap - EXIT
			if [ "$hadError" = "true" ] ; then
				set +e ; return 1
			fi
			return 0
		;;

		## Same as --librarian-list-team-files above (find-based scope
		## resolution/error handling, identical argument grammar), but with
		## a per-file modification date printed alongside each path -- the
		## real reason this is a separate op rather than a flag on the plain
		## version: the per-file stat call this needs is real, measured
		## overhead (~3s over the full 678-file skill-root vs. sub-second for
		## the plain listing), so a caller who only needs paths (the more
		## common case) shouldn't pay for dates it isn't asking for. BSD stat
		## then GNU stat fallback, inlined directly here rather than factored
		## into a shared helper function, per this file's actual convention:
		## logic stays inline within the case arm; a `source`d include file,
		## never a function, is the answer if an arm gets too long. Normalized to a common
		## "YYYY-MM-DD HH:MM:SS" width on both platforms -- GNU stat's own
		## %y includes sub-second precision + a timezone offset by default,
		## trimmed to the same 19 characters as BSD's explicit -t format so
		## output sorts/compares consistently regardless of which stat
		## flavor actually answered. Prints one line per matched file: mtime
		## ("YYYY-MM-DD HH:MM:SS") then two spaces then the path relative to
		## the skill-root (never absolute), sorted newest-first -- the most
		## useful order for the actual trigger case (confirming a
		## just-edited batch of files really did just change).
		--librarian-list-team-files-dates)
			shift
			local skillRoot="$HOME/.claude/skills"
			local hadError="false"
			local pathsTmp
			pathsTmp="$( mktemp )" || { set +e ; return 1 ; }
			trap 'rm -f "$pathsTmp"' EXIT

			if [ $# -eq 0 ] ; then
				find -L "$skillRoot" -type f 2>/dev/null > "$pathsTmp" || true
			else
				: > "$pathsTmp"
				while [ $# -gt 0 ] ; do
					local argPath="$1"
					shift
					local resolvedPath="$argPath"
					case "$resolvedPath" in
						/*) : ;;
						*) resolvedPath="$skillRoot/$resolvedPath" ;;
					esac
					case "$resolvedPath" in
						"$skillRoot"|"$skillRoot"/*) : ;;
						*)
							echo "⛔ ERROR: $MDSC_CMD --librarian-list-team-files-dates: path outside skill-root, skipping: $argPath" >&2
							hadError="true"
							continue
						;;
					esac
					if [ ! -e "$resolvedPath" ] ; then
						echo "⛔ ERROR: $MDSC_CMD --librarian-list-team-files-dates: not found, skipping: $resolvedPath" >&2
						hadError="true"
						continue
					fi
					find -L "$resolvedPath" -type f 2>/dev/null >> "$pathsTmp" || true
				done
			fi

			while IFS= read -r f ; do
				local mtime relPath
				mtime="$( stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$f" 2>/dev/null || stat -c '%y' "$f" 2>/dev/null | cut -c1-19 )"
				relPath="${f#"$skillRoot"/}"
				printf '%s  %s\n' "$mtime" "$relPath"
			done < "$pathsTmp" | sort -r

			rm -f "$pathsTmp"
			trap - EXIT
			if [ "$hadError" = "true" ] ; then
				set +e ; return 1
			fi
			return 0
		;;

		##
		## magic-librarian's own inbox-clearing pair. The --librarian-*
		## namespace is EXACT-MATCH in this dispatcher, not a `--librarian-*)`
		## glob route, so each of these needs its own arm here -- adding a third
		## one later means a third arm, not a pattern widening.
		##
		## One stub per routine step, each carrying its own validation even
		## where the two overlap, both over the one shared --intern-op-*
		## implementation -- the same convention --magic-board-to-* and
		## --magic-grooming-to-* already follow.
		##

		## <team-member> <item-filename> --from-inbox:<member>
		##
		## Discards one already-processed inbox item: <member>'s own inbox
		## processed/ area -> trash/. REVERSIBLE: trash/ relocates, it does not
		## delete -- but see --librarian-inbox-to-retained below, whose
		## direction is not.
		--librarian-inbox-item-trash)
			shift
			## <team-member> captured for future logging/validation, unused
			## today -- tooling operation discipline convention, same as every
			## --magic-board-* sibling.
			local callingMember="$1"
			shift || true
			local itemName="$1"
			shift || true
			if [ -z "$callingMember" ] || [ -z "$itemName" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --librarian-inbox-item-trash: syntax is <team-member> <item-filename> --from-inbox:<member>" >&2
				set +e ; return 1
			fi
			local fromInboxArg=""
			while [ $# -gt 0 ] ; do
				case "$1" in
					--from-inbox:*) fromInboxArg="$1" ; shift ;;
					*)
						echo "⛔ ERROR: $MDSC_CMD --librarian-inbox-item-trash: invalid option: $1" >&2
						set +e ; return 1
					;;
				esac
			done
			if [ -z "$fromInboxArg" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --librarian-inbox-item-trash: --from-inbox:<member> is required" >&2
				set +e ; return 1
			fi
			AgentsToolsAssertBareName "${fromInboxArg#--from-inbox:}" "--from-inbox: member name" "$MDSC_CMD --librarian-inbox-item-trash" || { set +e ; return 1 ; }
			AgentsToolsAssertBareName "$itemName" "<item-filename>" "$MDSC_CMD --librarian-inbox-item-trash" || { set +e ; return 1 ; }
			case "$itemName" in
				*.md) ;;
				*)
					echo "⛔ ERROR: $MDSC_CMD --librarian-inbox-item-trash: <item-filename> must end in .md -- every inbox item is a markdown document: $itemName" >&2
					set +e ; return 1
				;;
			esac
			DistroAgentsTools --intern-op-board-trash "$fromInboxArg" "$itemName" \
				--context --librarian-inbox-item-trash
			return $?
		;;

		## <team-member> <item-filename> --from-inbox:<member>
		##   [--header:<upsert|append|remove>:name[:value]]...
		##   [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]
		##
		## Promotes one already-processed inbox item into board/retained.
		##
		## ONE-WAY DOOR, and that is the load-bearing fact about this op:
		## --intern-op-board-upsert-move-edit's --from-inbox: source has no
		## --to-inbox: counterpart. A board->board move reverses by swapping the
		## two states; an inbox->board move has no inverse at all. The trash
		## sibling above is recoverable via --untrash; this one is not. Nothing
		## here is "undo-able later" -- treat every call as final.
		##
		## No auto-stamp, matching every --magic-board-to-* sibling: retained
		## has no established always-set field, and any provenance the caller
		## wants recorded rides the ordinary --header:* passthrough.
		--librarian-inbox-to-retained)
			shift
			## <team-member> captured for future logging/validation, unused
			## today -- same convention as the sibling above.
			local callingMember="$1"
			shift || true
			local itemName="$1"
			shift || true
			if [ -z "$callingMember" ] || [ -z "$itemName" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --librarian-inbox-to-retained: syntax is <team-member> <item-filename> --from-inbox:<member> [--header:<upsert|append|remove>:name[:value]]... [--upsert-from-stdin|--edit-script-from-stdin:<py|awk>|--edit-patch-from-stdin]" >&2
				set +e ; return 1
			fi
			local fromInboxArg=""
			local passthrough=()
			while [ $# -gt 0 ] ; do
				case "$1" in
					--from-inbox:*) fromInboxArg="$1" ; shift ;;
					--from-state:*)
						echo "⛔ ERROR: $MDSC_CMD --librarian-inbox-to-retained: --from-state: is not valid here -- this op moves an item out of a member inbox, never between board states. Use --magic-board-to-*/--magic-grooming-to-* for a board-to-board move." >&2
						set +e ; return 1
					;;
					--header:*|--upsert-from-stdin|--edit-script-from-stdin:*|--edit-patch-from-stdin)
						passthrough+=( "$1" ) ; shift
					;;
					*)
						echo "⛔ ERROR: $MDSC_CMD --librarian-inbox-to-retained: invalid option: $1" >&2
						set +e ; return 1
					;;
				esac
			done
			if [ -z "$fromInboxArg" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --librarian-inbox-to-retained: --from-inbox:<member> is required" >&2
				set +e ; return 1
			fi
			AgentsToolsAssertBareName "${fromInboxArg#--from-inbox:}" "--from-inbox: member name" "$MDSC_CMD --librarian-inbox-to-retained" || { set +e ; return 1 ; }
			AgentsToolsAssertBareName "$itemName" "<item-filename>" "$MDSC_CMD --librarian-inbox-to-retained" || { set +e ; return 1 ; }
			case "$itemName" in
				*.md) ;;
				*)
					echo "⛔ ERROR: $MDSC_CMD --librarian-inbox-to-retained: <item-filename> must end in .md -- every inbox item is a markdown document: $itemName" >&2
					set +e ; return 1
				;;
			esac
			DistroAgentsTools --intern-op-board-upsert-move-edit retained "$itemName" \
				"$fromInboxArg" \
				--context --librarian-inbox-to-retained \
				"${passthrough[@]}"
			return $?
		;;

		## **magic-coordinator-only by design** -- BOARD.md states plainly
		## "magic-coordinator's write authority is
		## exclusive over the board -- full stop... creating an Item, moving one
		## between these states, or scoring it -- is magic-coordinator-only." This op
		## is the sanctioned mechanism magic-coordinator itself uses to do that
		## writing/moving without going through a separate Edit/Write tool call --
		## it is NOT a general-purpose board-writing op for any member to call. Same
		## convention-based-trust model as every other op here (no caller-identity
		## enforcement exists in this tool at all) --
		## this is documented, not code-enforced, exactly like every other trust
		## boundary in this file.
		##
		## Same fixed-target-per-identifier shape as --purge-cleanup:
		## <state> must be one of the board's own real state-folder names (never a
		## free-form path), <item-filename> must be a bare filename (no '/', not
		## '.'/'..'). Content via stdin only (a board Item is a multi-paragraph
		## markdown document, not a single-line value). Writing to an
		## already-existing <state>/<item-filename> overwrites it in place (an
		## update to an existing Item's content) -- moving an Item between states is
		## two calls (write into the new state, then a separate cleanup of the old
		## file), not a single move op, since this tool has no existing "move/rename"
		## primitive anywhere else to mirror.
		--write-board-item)
			shift
			local boardState="$1"
			shift || true
			local itemName="$1"
			shift || true
			if [ -z "$boardState" ] || [ -z "$itemName" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --write-board-item: syntax is <state> <item-filename> -- content via stdin (magic-coordinator-only op)" >&2
				set +e ; return 1
			fi
			case "$boardState" in
				backlog|pending|running|blocked|parked|processed|archived|retained)
				;;
				*)
					echo "⛔ ERROR: $MDSC_CMD --write-board-item: unrecognized board state: $boardState (must be one of backlog/pending/running/blocked/parked/processed/archived/retained)" >&2
					set +e ; return 1
				;;
			esac
			case "$itemName" in
				*/*|.|..)
					echo "⛔ ERROR: $MDSC_CMD --write-board-item: item filename must be a bare filename, not a path: $itemName" >&2
					set +e ; return 1
				;;
			esac
			[ -n "${MDAT_DATA_ROOT:-}" ] || {
				echo "⛔ ERROR: $MDSC_CMD --write-board-item: MDAT_DATA_ROOT is not set" >&2
				set +e ; return 1
			}
			local boardDir="$MDAT_DATA_ROOT/board/$boardState"
			if [ ! -d "$boardDir" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --write-board-item: no such board state directory: $boardDir" >&2
				set +e ; return 1
			fi
			local target="$boardDir/$itemName"
			local content ; content="$( cat )"
			if [ -z "$content" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --write-board-item: empty stdin -- refusing to write an empty board item" >&2
				set +e ; return 1
			fi
			printf '%s\n' "$content" > "$target"
			echo "# $MDSC_CMD --write-board-item: wrote $target ($( printf '%s\n' "$content" | wc -l | tr -d '[:space:]' ) lines)" >&2
			return 0
		;;

		--member-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.Member.include"
			return $?
		;;

		## DEPRECATED -- superseded by --member-upsert-inbox-note
		## (identical behavior, --member-* prefix; see
		## --member-upsert-inbox-note's own comment in
		## sh-lib/AgentsTools.Member.include for the full rationale).
		## Removed from --help/--help.md
		## output; kept here, working, as a thin
		## backward-compatible shim (not a breaking removal) -- any existing
		## caller still using this name keeps working unchanged, indefinitely,
		## unless a real removal is separately proposed and approved.
		--write-inbox-note)
			shift
			DistroAgentsTools --member-upsert-inbox-note "$@" || return 1
			return 0
		;;

		--install-skillset-symlinks)
			shift

			local scope="workspace" workspaceArg scopeExplicit="false"
			while [ $# -gt 0 ] ; do
				case "$1" in
					--scope)
						case "$2" in
							workspace|user-home)
							;;
							*)
								echo "⛔ ERROR: $MDSC_CMD --install-skillset-symlinks: --scope must be workspace or user-home" >&2
								set +e ; return 1
							;;
						esac
						scope="$2" ; scopeExplicit="true" ; shift 2
					;;
					--workspace)
						if [ -z "$2" ] ; then
							echo "⛔ ERROR: $MDSC_CMD --install-skillset-symlinks: --workspace requires a value" >&2
							set +e ; return 1
						fi
						workspaceArg="$2" ; shift 2
					;;
					*)
						echo "⛔ ERROR: $MDSC_CMD --install-skillset-symlinks: invalid option: $1" >&2
						set +e ; return 1
					;;
				esac
			done

			local workspace="${workspaceArg:-$MMDAPP}"
			[ -d "$workspace" ] && workspace="$( cd "$workspace" && pwd )"

			if [ ! -f "$workspace/.local/myx/myx.distro-.local/sh-lib/LocalContext.include" ] ; then
				if [ "$scope" = "workspace" ] ; then
					if [ "$scopeExplicit" = "true" ] ; then
						echo "⛔ ERROR: $MDSC_CMD --install-skillset-symlinks: not a set-up myx.distro workspace: $workspace" >&2
						set +e ; return 1
					fi
					scope="user-home"
				fi
			fi

			local bundleRoot="$MDLT_ORIGIN/myx/myx.distro-agents/skillset/magic-team"
			if [ ! -d "$bundleRoot" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --install-skillset-symlinks: bundle directory does not exist: $bundleRoot" >&2
				set +e ; return 1
			fi

			local targetRoot
			case "$scope" in
				user-home) targetRoot="$HOME/.claude/skills" ;;
				workspace) targetRoot="$workspace/.claude/skills" ;;
			esac
			mkdir -p "$targetRoot" || {
				echo "⛔ ERROR: $MDSC_CMD --install-skillset-symlinks: can't create target directory: $targetRoot" >&2
				set +e ; return 1
			}

			local memberNames memberDir
			memberNames="$(
				for memberDir in "$bundleRoot"/*/ "$targetRoot"/*/ ; do
					[ -d "${memberDir%/}" ] || continue
					basename "${memberDir%/}"
				done | sort -u
			)"

			local hadError="false" memberName memberTarget memberBundled
			while IFS= read -r memberName ; do
				[ -n "$memberName" ] || continue
				[ "$memberName" != "trash" ] || continue
				case "$memberName" in
					keeper-*|partner-*|oncall-*|expert-*|warden-*) continue ;;
				esac
				memberTarget="$targetRoot/$memberName"
				memberBundled="$bundleRoot/$memberName"
				if [ -L "$memberTarget" ] ; then
					if [ "$( readlink "$memberTarget" )" = "$memberBundled" ] ; then
						continue
					fi
					echo "⛔ ERROR: $MDSC_CMD --install-skillset-symlinks: $memberTarget is a symlink but points elsewhere: $( readlink "$memberTarget" )" >&2
					hadError="true"
					continue
				fi
				if [ ! -e "$memberBundled" ] ; then
					echo "⛔ ERROR: $MDSC_CMD --install-skillset-symlinks: no content in bundle for $memberName: $memberBundled" >&2
					hadError="true"
					continue
				fi
				if [ -e "$memberTarget" ] ; then
					echo "⛔ ERROR: $MDSC_CMD --install-skillset-symlinks: real content at $memberTarget, won't overwrite (bundle already has $memberBundled)" >&2
					hadError="true"
					continue
				fi
				if ! ln -s "$memberBundled" "$memberTarget" ; then
					echo "⛔ ERROR: $MDSC_CMD --install-skillset-symlinks: failed to create symlink: $memberTarget" >&2
					hadError="true"
					continue
				fi
				echo "OK --install-skillset-symlinks linked $memberTarget -> $memberBundled" >&2
			done <<< "$memberNames"
			if [ "$hadError" = "true" ] ; then
				set +e ; return 1
			fi
			return 0
		;;

		--install-workspace-integrations)
			shift
			local scope workspaceArg
			while [ $# -gt 0 ] ; do
				case "$1" in
					--scope)
						scope="$2" ; shift 2
					;;
					--workspace)
						workspaceArg="$2" ; shift 2
					;;
					*)
						echo "⛔ ERROR: $MDSC_CMD --install-workspace-integrations: invalid option: $1" >&2
						set +e ; return 1
					;;
				esac
			done

			local workspace="${workspaceArg:-$MMDAPP}"
			if [ ! -d "$workspace" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --install-workspace-integrations: workspace not found: $workspace" >&2
				set +e ; return 1
			fi
			workspace="$( cd "$workspace" && pwd )"

			echo "# $MDSC_CMD --install-workspace-integrations: step 1/2 skillset symlinks" >&2
			if [ -n "$scope" ] ; then
				DistroAgentsTools --install-skillset-symlinks --scope "$scope" --workspace "$workspace" || { set +e ; return 1 ; }
			else
				## --install-skillset-symlinks itself requires an explicit
				## --scope (2026-08-06 correction) -- "both" is composed here,
				## at this caller's own level, not delegated to an implicit
				## no-scope mode on the child op. user-home only runs when
				## $HOME/.claude/skills actually exists (not explicitly
				## requested here, so skipped gracefully rather than erroring);
				## workspace always runs.
				[ ! -d "$HOME/.claude/skills" ] || DistroAgentsTools --install-skillset-symlinks --scope user-home --workspace "$workspace" || { set +e ; return 1 ; }
				DistroAgentsTools --install-skillset-symlinks --scope workspace --workspace "$workspace" || { set +e ; return 1 ; }
			fi

			echo "# $MDSC_CMD --install-workspace-integrations: step 2/2 vscode + mcp integrations" >&2
			DistroAgentsTools --owner-install-vscode-integrations --workspace "$workspace" || { set +e ; return 1 ; }

			echo "OK --install-workspace-integrations" >&2
			return 0
		;;

		--install-vscode-integrations)
			shift
			local workspaceArg
			while [ $# -gt 0 ] ; do
				case "$1" in
					--workspace)
						workspaceArg="$2" ; shift 2
					;;
					*)
						echo "⛔ ERROR: $MDSC_CMD --install-vscode-integrations: invalid option: $1" >&2
						set +e ; return 1
					;;
				esac
			done

			local workspace="${workspaceArg:-$MMDAPP}"
			if [ ! -d "$workspace" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --install-vscode-integrations: workspace not found: $workspace" >&2
				set +e ; return 1
			fi
			workspace="$( cd "$workspace" && pwd )"

			DistroAgentsTools --owner-install-vscode-integrations --workspace "$workspace" || { set +e ; return 1 ; }
			echo "OK --install-vscode-integrations" >&2
			return 0
		;;


		--owner-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.Owner.include"
			return $?
		;;

		## Internal plumbing, no --help entry -- see
		## AgentsTools.InternOpBoardUpsertMoveEdit.include's own header.
		## One primitive per file (not a wildcard): --intern-op-board-rename
		## below is a separate, unrelated op, not a sibling verb of this one.
		--intern-op-board-upsert-move-edit)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpBoardUpsertMoveEdit.include"
			return $?
		;;

		## Internal plumbing, no --help entry -- see
		## AgentsTools.InternOpBoardRename.include's own header.
		--intern-op-board-rename)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpBoardRename.include"
			return $?
		;;

		## Internal plumbing, no --help entry -- the shared generic
		## primitive underlying every --*-input-scan wrapper below. See
		## AgentsTools.InternOpSessionContextScan.include's own header.
		--intern-op-session-context-scan)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpSessionContextScan.include"
			return $?
		;;

		--intern-op-board-trash)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpBoardTrash.include"
			return $?
		;;

		## Internal plumbing, no --help entry -- the shared generic
		## primitive underlying --member-upsert-inbox-note/
		## --member-upsert-member-inquiry/--member-upsert-inbox-reflection.
		## See AgentsTools.InternOpMemberInboxUpsert.include's own header.
		--intern-op-member-inbox-upsert)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpMemberInboxUpsert.include"
			return $?
		;;

		## Internal plumbing, no --help entry -- backs --magic-heartbeat-config-check.
		--intern-op-check-configs)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpCheckConfigs.include"
			return $?
		;;

		## Internal plumbing, no --help entry -- shared generic file-read
		## primitive with optional line-range selection.
		--intern-op-data-read)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpDataRead.include"
			return $?
		;;

		## Internal plumbing, no --help entry -- shared spawn-proxy primitive
		## used by routine-specific wrappers (e.g. --magic-heartbeat-spawn-proxy).
		--intern-op-agent-spawn-proxy)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpAgentSpawnProxy.include"
			return $?
		;;

		--intern-config-board-location)
			shift
			if [ $# -gt 0 ] ; then
				echo "⛔ ERROR: $MDSC_CMD --intern-config-board-location: takes no arguments" >&2
				set +e ; return 1
			fi
			if [ -z "${MDAT_DATA_ROOT:-}" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --intern-config-board-location: TEAM_DATA_DIRECTORY is not configured -- set it first: DistroAgentsTools.fn.sh --agents-config-option magic-coordinator --upsert TEAM_DATA_DIRECTORY <path>" >&2
				set +e ; return 1
			fi
			printf '%s\n' "$MDAT_DATA_ROOT"
			return 0
		;;


		## routine-grooming's own operation group (--magic-grooming-to-*,
		## --magic-grooming-input-scan) -- see
		## AgentsTools.MagicGrooming.include's own header.
		--magic-grooming-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MagicGrooming.include"
			return $?
		;;

		## routine-communication-sweep's own operation group
		## (--magic-sweep-input-scan) -- see
		## AgentsTools.MagicSweep.include's own header.
		--magic-sweep-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MagicSweep.include"
			return $?
		;;

		## direct Trello write operations for process-flow steps
		## (--magic-trello-post-comment) -- see
		## AgentsTools.MagicTrello.include's own header.
		--magic-trello-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MagicTrello.include"
			return $?
		;;

		## routine-coworking's own operation group
		## (--routine-coworking-session-input-scan) -- see
		## AgentsTools.RoutineCoworking.include's own header.
		--routine-coworking-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.RoutineCoworking.include"
			return $?
		;;

		## routine-heartbeat's own operation group
		## (--magic-heartbeat-input-scan) -- see
		## AgentsTools.MagicHeartbeat.include's own header.
		--magic-heartbeat-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MagicHeartbeat.include"
			return $?
		;;

		## routine-advance's own operation group
		## (--magic-advance-input-scan, also consumed by routine-update-board)
		## -- see AgentsTools.MagicAdvance.include's own header.
		--magic-advance-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MagicAdvance.include"
			return $?
		;;

		## check-process-board's own operation group (--magic-board-to-pending,
		## --magic-board-to-blocked) -- first cross-routine namespace in this
		## family, since check-process-board is callable by any routine, not
		## owned by one. See AgentsTools.MagicBoard.include's own header.
		--magic-board-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MagicBoard.include"
			return $?
		;;

		## Marks a message read after it's been processed -- otherwise every
		## comms-sweep pass keeps re-seeing the same UIDs as unseen. IMAP UID
		## STORE with the \Seen flag, same curl --request pattern
		## --comms-email-check already uses for STATUS/SEARCH (not the URL-based ;UID=
		## addressing --comms-email-read uses, since this is a STORE command, not a
		## fetch).
		--comms-email-mark-seen)
			shift
			local uid="$1"
			shift || true
			if [ -z "$uid" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --comms-email-mark-seen: UID required" >&2
				set +e ; return 1
			fi

			local imapHost imapUser imapPass
			imapHost="$( DistroAgentsTools --agents-config-option magic-coordinator --select EMAIL_IMAP_HOST )"
			imapUser="$( DistroAgentsTools --agents-config-option magic-coordinator --select EMAIL_USER )"
			imapPass="$( DistroAgentsTools --agents-config-option magic-coordinator --select EMAIL_APP_PASSWORD )"
			if [ -z "$imapHost" ] || [ -z "$imapUser" ] || [ -z "$imapPass" ] ; then
				echo "⛔ ERROR: $MDSC_CMD --comms-email-mark-seen: EMAIL_IMAP_HOST/EMAIL_USER/EMAIL_APP_PASSWORD not fully set in .local/.agents" >&2
				set +e ; return 1
			fi

			echo "# $MDSC_CMD --comms-email-mark-seen: marking UID=$uid as \\Seen" >&2
			curl -sS --url "imaps://${imapHost}/INBOX" --user "${imapUser}:${imapPass}" \
				--request "UID STORE ${uid} +FLAGS (\Seen)"
			return $?
		;;

		--help|--help-syntax|'')
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/help/Help.DistroAgentsTools.include"
			return $?
		;;

		*)
			echo "⛔ ERROR: $MDSC_CMD: invalid option: $1 -- rejected by DistroAgentsTools.fn.sh's own top-level dispatcher default (*) branch: no route matched this operation name, so no operation include was sourced at all" >&2
			set +e ; return 1
		;;
	esac
}

case "$0" in
	*/sh-scripts/DistroAgentsTools.fn.sh)

		if [ -z "$1" ] || [ "$1" = "--help" ] || [ "$1" = "--help-syntax" ] ; then
			DistroAgentsTools "$@"
			exit 1
		fi

		set -e
		DistroAgentsTools "$@"
	;;
esac
