#!/usr/bin/env bash

##
## AgentsConsoleManager.fn.sh -- the manager screen of the agents console, opened straight. It is what
## `DistroAgentsTools.fn.sh --manager` runs, with the D5 start options beside it: with no arguments it opens
## the screen as `--manager` does; --component <path> opens the list at that level (its ids, `/` between them);
## --view list|view gives one window the keys; --filter <text> narrows the table of the left window and gives
## it the keys; --dialog <name> shows that one dialog and ends when it is closed (single-dialog mode), --text
## <text> the words it holds. --style <name> is the interface style of the start, as --manager takes it.
## The screen itself is sh-lib/manager/AgentsManagerScreen.py, started by Python; --manager is unchanged.
##
## NOTE:
## Designed to be able to run without distro context.
##

if [ -z "$MMDAPP" ] ; then
	set -e
	export MMDAPP="$( ( cd "$( dirname "$0" )/../../../.." && pwd ) )"
	echo "$0: Working in: $MMDAPP"  >&2
	[ -d "$MMDAPP/.local" ] || ( echo "⛔ ERROR: expecting '.local' directory." >&2 && exit 1 )
fi

: "${MDLT_ORIGIN:=$MMDAPP/.local}"
export MDLT_ORIGIN
export MDLC_INMODE=".local"
export MDLT_OPTION="--run-from-.local"
export MDSC_INMODE=".local"
export MDSC_OPTION="--run-from-.local"

## Every child finds the bash this runs in, as DistroAgentsTools.fn.sh does.
case "$BASH" in
	/*/bash)
		command -v bash > /dev/null 2>&1 || { PATH="${PATH:+$PATH:}${BASH%/*}" ; export PATH ; }
		export MDAT_BASH="$BASH"
	;;
esac

## The manager screen, the same start `--manager` makes, with the D5 options handed on.
AgentsConsoleManager(){
	local MDSC_CMD='AgentsConsoleManager'
	local managerStyle="" managerComponent="" managerView="" managerFilter="" managerDialog="" managerText=""
	local managerScreenFile="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsManagerScreen.py"
	local managerToolsFile="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

	while [ $# -gt 0 ] ; do
		case "$1" in
			--style|--component|--view|--filter|--dialog|--text)
				if [ $# -lt 2 ] ; then
					echo "$MDSC_CMD: ⛔ ERROR: $1 takes a value" >&2
					set +e ; return 1
				fi
				case "$1" in
					--style) managerStyle="$2" ;;
					--component) managerComponent="$2" ;;
					--view) managerView="$2" ;;
					--filter) managerFilter="$2" ;;
					--dialog) managerDialog="$2" ;;
					--text) managerText="$2" ;;
				esac
				shift 2
			;;
			--help|--help-syntax)
				set +e
				. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/help/Help.AgentsConsoleManager.include"
				return $?
			;;
			*)
				echo "$MDSC_CMD: ⛔ ERROR: invalid option: $1" >&2
				set +e ; return 1
			;;
		esac
	done

	## --view is one of the two windows, or nothing; the screen refuses another name, but say it
	## before anything is started.
	case "$managerView" in
		''|list|view) ;;
		*) echo "$MDSC_CMD: ⛔ ERROR: --view takes list or view, got: $managerView" >&2 ; set +e ; return 1 ;;
	esac

	if [ ! -r "$managerScreenFile" ] ; then
		echo "$MDSC_CMD: ⛔ ERROR: the manager screen is missing or unreadable: $managerScreenFile" >&2
		return 1
	fi
	if ! command -v python3 > /dev/null 2>&1 ; then
		echo "$MDSC_CMD: ⛔ ERROR: the manager screen needs python3, and none is in PATH." >&2
		return 1
	fi

	## THE STYLE OF THIS START, as --manager resolves it: the one named on the command; the one the
	## environment names (MDLT_MANAGER_STYLE), which the screen reads itself; the one the user saved,
	## handed on as --style; else the screen's own default. The saved one is asked of the digest of the
	## settings, whose line of the style says where its value comes from: it reads `user` only where the
	## environment names no style and the user saved one. The style is a console interface setting of .local,
	## declared with the mouse and the spacers in its LocalTools.ManagerInterface.include, which the digest
	## reads. Where the digest cannot be read, nothing is handed on.
	if [ -z "$managerStyle" ] ; then
		managerStyle="$( "$BASH" "$managerToolsFile" --manager-config-digest interface 2> /dev/null < /dev/null | LC_ALL=C awk -F'\t' '$1 == "line" && $4 == "MDLT_MANAGER_STYLE" && $7 == "user" { print $6 ; exit ; }' )" || managerStyle=""
	fi

	## THE SPACERS AND THE MOUSE OF THIS START, as --manager sets them in the screen's environment alone:
	## MDLT_MANAGER_SPACERS and MDLT_MANAGER_MOUSE, console settings of .local, the user's own. The one the
	## environment names comes first, which the screen reads itself; else the one the user saved.
	if [ -z "${MDLT_MANAGER_SPACERS:-}" ] ; then
		local managerSpacers
		managerSpacers="$( set -- --.local-config-option-select-default MDLT_MANAGER_SPACERS "" ; . "$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/LocalTools.Config.include" 2> /dev/null < /dev/null )" || managerSpacers=""
		[ -z "$managerSpacers" ] || local -x MDLT_MANAGER_SPACERS="$managerSpacers"
	fi
	if [ -z "${MDLT_MANAGER_MOUSE:-}" ] ; then
		local managerMouse
		managerMouse="$( set -- --.local-config-option-select-default MDLT_MANAGER_MOUSE "" ; . "$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/LocalTools.Config.include" 2> /dev/null < /dev/null )" || managerMouse=""
		[ -z "$managerMouse" ] || local -x MDLT_MANAGER_MOUSE="$managerMouse"
	fi

	set +e

	set -- --workspace "$MMDAPP" --tools "$managerToolsFile"
	[ -z "$managerStyle" ] || set -- "$@" --style "$managerStyle"
	[ -z "$managerComponent" ] || set -- "$@" --component "$managerComponent"
	[ -z "$managerView" ] || set -- "$@" --view "$managerView"
	[ -z "$managerFilter" ] || set -- "$@" --filter "$managerFilter"
	[ -z "$managerDialog" ] || set -- "$@" --dialog "$managerDialog"
	[ -z "$managerText" ] || set -- "$@" --text "$managerText"

	## -I: nothing of the caller's own Python setup reaches the screen. -B: no bytecode is written into the source tree.
	python3 -I -B "$managerScreenFile" "$@"
	return $?
}

case "$0" in
	*/myx/myx.distro-agents/sh-scripts/AgentsConsoleManager.fn.sh)
		## THE OWNER RE-ENTRY: where the caller is someone else, this launcher runs again as the account that owns
		## the workspace, entered as by sudo, so the screen and every operation it runs execute as the owner, while
		## SUDO_USER keeps the person who entered known (AgentsToolsConsoleAccount reads it).
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsTools.ConsoleOwner.include"
		AgentsToolsConsoleOwnerReentry "$0" "$@"
		AgentsConsoleManager "$@"
	;;
	*)
		## Executed by an unrecognised path: error. Sourced ($0 differs from BASH_SOURCE[0]): stay silent.
		if [ "${BASH_SOURCE[0]:-}" = "$0" ] ; then
			echo "⛔ ERROR: AgentsConsoleManager.fn.sh: executed as '$0', which this file's own dispatch does not match, so nothing ran. Invoke it by a path ending in /myx/myx.distro-agents/sh-scripts/AgentsConsoleManager.fn.sh, or source it." >&2
			exit 1
		fi
	;;
esac
