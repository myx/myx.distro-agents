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
		export MDLT_OPTION="--run-from-.local"
	;;
	source)
		if [ -f "$MMDAPP/source/myx/myx.distro-agents/sh-lib/AgentsContext.include" ] ; then
			export MDLT_ORIGIN="$MMDAPP/$MDLC_INMODE"
			export MDLT_OPTION="--run-from-source"
		else
			export MDLT_ORIGIN="$MMDAPP/.local"
			export MDLT_OPTION="--run-from-.local"
		fi
	;;
	/*)
		if [ -f "$MDLC_INMODE/myx/myx.distro-agents/sh-lib/AgentsContext.include" ] ; then
			export MDLT_ORIGIN="$MDLC_INMODE"
			export MDLT_OPTION="--run-from-path $MDLT_ORIGIN"
		else
			export MDLT_ORIGIN="$MMDAPP/.local"
			export MDLT_OPTION="--run-from-.local"
		fi
	;;
	*)
		export MDLT_ORIGIN="$MMDAPP/.local"
		export MDLT_OPTION="--run-from-.local"
	;;
esac
if [ ! -f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsContext.include" ] ; then
	echo "⛔ ERROR: AgentsContext.SetInputSpec: can't find/detect origin, spec: $MDLT_CONSOLE_ORIGIN, origin: $MDLT_ORIGIN" >&2
	exit 1
fi

cd "$MMDAPP"
export MMDAPP

DAGC_KNOWN_CLIS="copilot copilot-native claude claude-native grok grok-native scaleway"
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
## grok-native is the opposite case (a real interactive binary, not yet proven
## non-interactive), scaleway is proven non-interactive and categorically
## cannot be the other thing. See MAGIC.md.
DAGC_NONINTERACTIVE_CLIS="copilot copilot-native claude claude-native grok scaleway"
DAGC_CLI="copilot"
DAGC_CLI_GIVEN="false"
DAGC_CLI_AUTO="false"
DAGC_CLI_CONFIGURED="false"
## Where DAGC_CLI came from, for the message a bash console prints when it cannot start it.
DAGC_CLI_BY="the default"
## ---- harness legs, one mechanism for every provider ---------------------
## A harness leg is a FILE, not a name in a list. sh-lib/Agents<Name>Harness.sh
## IS the leg <name>: it declares one provider's endpoint, models, wire and
## credential names, then execs the universal core which holds the logic.
## Adding a leg -- deepseek, or any future one -- is adding that one file, and
## no name in this console changes.
##
## What marks a file as a leg is that it DECLARES HARNESS_PROVIDER_NAME. The
## core only reads that variable, so the same glob that finds every leg leaves
## the core out by a property of the file rather than by its name.
##
## The leg's filename IS its selection name: `claude`, `copilot`, `grok` and `scaleway`
## each select this package's own harness leg for that service. DAGC_VENDOR_CLIS
## is the complement -- the names that mean the vendor's own CLI, which is what
## `-native` says. It wins over leg resolution, so a leg can never shadow a
## vendor name, and none of the seven names in this file needs an arm of its own
## anywhere below.
##
## MDAT_<NAME>_HARNESS, per leg, points that one leg at a different file: one
## workspace runs a candidate implementation while every other workspace
## sharing this same MDLT_ORIGIN tree keeps the default, which is what makes a
## candidate testable for real without promoting it everywhere at once.
## MDAT_SCALEWAY_HARNESS is that variable for the scaleway leg and is
## unchanged; its name is now derived, so a new leg gets the same lever free.
##
## Two accepted shapes for that value, and why only these:
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
## silent -- as that leg reported absent by DagcCliPresent() and quietly
## skipped by --cli-auto, which is indistinguishable from it simply not being
## installed. An unset variable reaches none of this.
DAGC_VENDOR_CLIS="copilot-native claude-native grok-native"
DAGC_LEG_DIR="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
## Leg name, then its resolved file, one per line. Resolved ONCE here, so every
## later site -- presence, exec, access flag, credential names, prompt shape --
## reads the SAME path that was checked for. Presence-checking one file while
## exec'ing another is exactly how a console reports a CLI as available and
## then fails to start it.
DAGC_LEG_TABLE=""
for DAGC_LEG_FILE in "$DAGC_LEG_DIR/"Agents*Harness.sh ; do
	[ -f "$DAGC_LEG_FILE" ] || continue
	grep -q '^HARNESS_PROVIDER_NAME=' "$DAGC_LEG_FILE" || continue
	DAGC_LEG_NAME="${DAGC_LEG_FILE##*/}"
	DAGC_LEG_NAME="${DAGC_LEG_NAME#Agents}"
	DAGC_LEG_NAME="${DAGC_LEG_NAME%Harness.sh}"
	[ -n "$DAGC_LEG_NAME" ] || continue
	DAGC_LEG_NAME="$( printf '%s' "$DAGC_LEG_NAME" | LC_ALL=C tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz' )"
	DAGC_LEG_LEVER="MDAT_$( printf '%s' "$DAGC_LEG_NAME" | LC_ALL=C tr 'abcdefghijklmnopqrstuvwxyz-' 'ABCDEFGHIJKLMNOPQRSTUVWXYZ_' )_HARNESS"
	DAGC_LEG_OVERRIDE="${!DAGC_LEG_LEVER}"
	if [ -n "$DAGC_LEG_OVERRIDE" ] ; then
		case "$DAGC_LEG_OVERRIDE" in
			.|..)
				echo "⛔ ERROR: DistroAgentsConsole: $DAGC_LEG_LEVER is not a harness filename: $DAGC_LEG_OVERRIDE" >&2
				exit 1
			;;
			/*)
				DAGC_LEG_FILE="$DAGC_LEG_OVERRIDE"
			;;
			*/*)
				echo "⛔ ERROR: DistroAgentsConsole: $DAGC_LEG_LEVER must be a bare filename in $DAGC_LEG_DIR, or an absolute path -- a relative path is refused, because it would resolve against $MMDAPP rather than against anything you named: $DAGC_LEG_OVERRIDE" >&2
				exit 1
			;;
			*)
				DAGC_LEG_FILE="$DAGC_LEG_DIR/$DAGC_LEG_OVERRIDE"
			;;
		esac
		if [ ! -f "$DAGC_LEG_FILE" ] ; then
			echo "⛔ ERROR: DistroAgentsConsole: $DAGC_LEG_LEVER=$DAGC_LEG_OVERRIDE names no such file: $DAGC_LEG_FILE" >&2
			exit 1
		fi
		if [ ! -x "$DAGC_LEG_FILE" ] ; then
			echo "⛔ ERROR: DistroAgentsConsole: $DAGC_LEG_LEVER=$DAGC_LEG_OVERRIDE names a file that is not executable: $DAGC_LEG_FILE" >&2
			exit 1
		fi
	fi
	DAGC_LEG_TABLE="$DAGC_LEG_TABLE$DAGC_LEG_NAME
$DAGC_LEG_FILE
"
done

## The one place a name becomes a leg: prints that leg's resolved file, or
## returns 1 for every name that is not one. Name and file are two lines rather
## than one delimited line, because a path may legally contain any separator a
## single line would have to choose.
DagcLegFileFor(){
	local legSought="$1" legLine legPending=""
	case " $DAGC_VENDOR_CLIS " in
		*" $legSought "*) return 1 ;;
	esac
	[ -n "$legSought" ] || return 1
	while IFS= read -r legLine ; do
		[ -n "$legLine" ] || continue
		if [ -z "$legPending" ] ; then
			legPending="$legLine"
		else
			if [ "$legPending" = "$legSought" ] ; then
				printf '%s\n' "$legLine"
				return 0
			fi
			legPending=""
		fi
	done <<< "$DAGC_LEG_TABLE"
	return 1
}
DagcCliIsLeg(){
	DagcLegFileFor "$1" >/dev/null
}
## The auto-scan order, and the set this console advertises. DAGC_KNOWN_CLIS
## above stays the explicit ranking, unchanged and still mirrored by
## AgentsTools.Owner.include; every discovered leg not already named there is
## appended AFTER it, so a new leg joins --cli-auto at the tail without an edit
## and no existing name moves position.
## Every leg is non-interactive-capable and interactive-incapable, by
## construction: no binary, no REPL, one request/response tool-calling cycle to
## completion and exit. So the same append builds the non-interactive set,
## whose vendor-CLI half stays DAGC_NONINTERACTIVE_CLIS, unchanged.
DAGC_SELECTABLE_CLIS="$DAGC_KNOWN_CLIS"
DAGC_SELECTABLE_NONINTERACTIVE="$DAGC_NONINTERACTIVE_CLIS"
DAGC_LEG_PENDING=""
while IFS= read -r DAGC_LEG_LINE ; do
	[ -n "$DAGC_LEG_LINE" ] || continue
	if [ -z "$DAGC_LEG_PENDING" ] ; then
		DAGC_LEG_PENDING="$DAGC_LEG_LINE"
		continue
	fi
	DAGC_LEG_SELECTABLE="$DAGC_LEG_PENDING"
	DAGC_LEG_PENDING=""
	case " $DAGC_SELECTABLE_NONINTERACTIVE " in
		*" $DAGC_LEG_SELECTABLE "*) ;;
		*) DAGC_SELECTABLE_NONINTERACTIVE="$DAGC_SELECTABLE_NONINTERACTIVE $DAGC_LEG_SELECTABLE" ;;
	esac
	case " $DAGC_SELECTABLE_CLIS " in
		*" $DAGC_LEG_SELECTABLE "*) ;;
		*) DAGC_SELECTABLE_CLIS="$DAGC_SELECTABLE_CLIS $DAGC_LEG_SELECTABLE" ;;
	esac
done <<< "$DAGC_LEG_TABLE"
## A leg has no real binary at all -- `command -v scaleway` can never succeed on
## any machine, and nor can any other leg's name -- so every presence check for
## one goes through its file instead, exactly as `--owner-setup-scaleway`'s own
## install-probe already had to (a file test, not a PATH lookup; see
## AgentsTools.Owner.include and MAGIC.md). The leg table is built from files
## that exist, so membership IS presence.
DagcCliPresent(){
	if DagcCliIsLeg "$1" ; then
		return 0
	fi
	case "$1" in
		## claude-native's BINARY is `claude`; its own name is on no PATH. Without
		## this arm the default below would run `command -v claude-native`, find
		## nothing, and report the vendor CLI absent on a machine where it is
		## installed -- which --cli-auto reads as "not installed" and skips
		## silently, indistinguishable from it really being missing.
		claude-native) command -v claude >/dev/null 2>&1 ;;
		copilot-native) command -v copilot >/dev/null 2>&1 ;;
		grok-native) command -v grok >/dev/null 2>&1 ;;
		*) command -v "$1" >/dev/null 2>&1 ;;
	esac
}
## Every bash console this file opens goes through here, so each one says why.
## console-agents-bashrc.rc prints the reason and forgets it.
DagcExecBashConsole(){ ## the reason this is a bash console and not an agent CLI
	export MDAT_CONSOLE_FALLBACK_REASON="$1"
	exec bash --rcfile "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/console-agents-bashrc.rc" -i
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
				echo "⛔ ERROR: DistroAgentsConsole: --cli requires a value (known: $DAGC_SELECTABLE_CLIS)" >&2
				exit 1
			fi
			DAGC_CLI="$2"
			DAGC_CLI_GIVEN="true"
			DAGC_CLI_BY="--cli"
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
## An explicit --cli on an interactive start is the person's own choice and is honoured: it skips this block,
## which would otherwise replace it with SPAWN_CLI_SERVICE or the scan whenever --cli-auto came first
## (Agents --start-console always puts it first). A spawn (--non-interactive) takes the block as before.
if { [ "$DAGC_CLI_AUTO" = "true" ] || [ "$DAGC_CLI_GIVEN" != "true" ] ; } && ! { [ "$DAGC_CLI_GIVEN" = "true" ] && [ "$1" != "--non-interactive" ] ; } ; then
	DAGC_CLI_GIVEN="false"
	## Tested, not bare: set -e would kill the console on an unreadable scope instead of falling through to the scan below.
	DAGC_CLI_SERVICE="$( "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --agents-config-option magic-team --select SPAWN_CLI_SERVICE 2>/dev/null )" || DAGC_CLI_SERVICE=""
	if [ -n "$DAGC_CLI_SERVICE" ] ; then
		# Its name, its non-interactive capability and its presence in PATH are each checked below, at their own use site.
		DAGC_CLI="$DAGC_CLI_SERVICE"
		DAGC_CLI_GIVEN="true"
		DAGC_CLI_BY="SPAWN_CLI_SERVICE"
	elif [ "$DAGC_CLI_CONFIGURED" = "true" ] ; then
		## Every spawn service is named, not one of them. This error reaches a
		## workspace that has chosen NOTHING yet, so naming a single flag steers
		## that choice by whichever name an error string happened to carry --
		## a policy nobody decided, expressed as an example. The reader picks.
		echo "⛔ ERROR: DistroAgentsConsole: SPAWN_CLI_SERVICE is not configured in this workspace, so no external agent CLI is selected here. rc=5 means exactly this -- nothing was chosen to start, which is distinct from rc=1 (something was chosen and could not be started). Spawn an internal agent instead, or choose one of the spawn services and select it with --apply: $MMDAPP/.local/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh --owner-setup-claude --apply (this package's own Claude harness), or --owner-setup-claude-native (the vendor claude CLI as installed on this machine), or --owner-setup-copilot, or --owner-setup-copilot-native (the vendor copilot CLI as installed on this machine), or --owner-setup-grok (this package's own xAI Grok harness), or --owner-setup-scaleway." >&2
		exit 5
	else
		for DAGC_AUTO_CLI in $DAGC_SELECTABLE_CLIS ; do
			if [ "$1" == "--non-interactive" ] ; then
				case " $DAGC_SELECTABLE_NONINTERACTIVE " in
					*" $DAGC_AUTO_CLI "*) ;;
					*)
						continue
					;;
				esac
			fi
			if DagcCliPresent "$DAGC_AUTO_CLI" ; then
				DAGC_CLI="$DAGC_AUTO_CLI"
				DAGC_CLI_GIVEN="true"
				DAGC_CLI_BY="the PATH scan"
				break
			fi
		done
		if [ "$DAGC_CLI_GIVEN" != "true" ] && [ "$1" == "--non-interactive" ] ; then
			echo "⛔ ERROR: DistroAgentsConsole: --cli-auto found no supported non-interactive CLI in PATH (tried: $DAGC_SELECTABLE_NONINTERACTIVE)." >&2
			exit 1
		fi
	fi
fi
## One membership test over the computed set, rather than a literal arm listing
## every provider: the set already carries every vendor CLI and every leg, and
## a leg's own -harness spelling is accepted here even though only its canonical
## name is advertised above.
case " $DAGC_SELECTABLE_CLIS " in
	*" $DAGC_CLI "*) ;;
	*)
		if ! DagcCliIsLeg "$DAGC_CLI" ; then
			echo "⛔ ERROR: DistroAgentsConsole: unsupported --cli: $DAGC_CLI (known: $DAGC_SELECTABLE_CLIS)" >&2
			exit 1
		fi
	;;
esac
## An interactive launch (no --non-interactive) of a harness leg (claude, copilot,
## scaleway) runs the existing `DistroAgentsTools.fn.sh --intern-root-harness`, with
## no option of its own, started as it is by hand; this terminal is only where its
## output goes. No vendor binary is run and nothing is renamed to -native. That
## operation resolves the CLI itself from SPAWN_CLI_SERVICE, so it is run only for a
## leg that setting named; a leg chosen any other way (--cli, the PATH scan) cannot
## be what it would run, and opens the bash console and says what happened.
if [ "$1" != "--non-interactive" ] && DagcCliIsLeg "$DAGC_CLI" ; then
	DAGC_ROOT_HARNESS_TOOLS="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
	if [ "$DAGC_CLI_BY" = "SPAWN_CLI_SERVICE" ] && [ -x "$DAGC_ROOT_HARNESS_TOOLS" ] ; then
		exec "$DAGC_ROOT_HARNESS_TOOLS" --intern-root-harness
	fi
	DagcExecBashConsole "nothing was started: '$DAGC_CLI' is a harness leg (chosen by $DAGC_CLI_BY), and an interactive start of a leg runs --intern-root-harness, which takes its CLI from SPAWN_CLI_SERVICE and needs $DAGC_ROOT_HARNESS_TOOLS to be executable."
fi
if [ "$1" == "--non-interactive" ] ; then
	## The leg test comes first, and is not covered by the set above: that set
	## advertises each leg under ONE name, while a leg is selectable under its
	## -harness spelling too. Testing membership alone would refuse the alias
	## this console itself accepted at the --cli gate, two branches earlier.
	case " $DAGC_SELECTABLE_NONINTERACTIVE " in
		*" $DAGC_CLI "*) ;;
		*)
			if ! DagcCliIsLeg "$DAGC_CLI" ; then
				echo "⛔ ERROR: DistroAgentsConsole: --non-interactive is currently supported only for: $DAGC_SELECTABLE_NONINTERACTIVE (got: $DAGC_CLI)." >&2
				exit 1
			fi
		;;
	esac
fi
if [ "$DAGC_CLI_GIVEN" = "true" ] ; then
	DagcCliPresent "$DAGC_CLI" || {
		echo "⛔ ERROR: DistroAgentsConsole: '$DAGC_CLI' CLI not found in PATH -- install it first; it was selected explicitly (--cli, or magic-team's SPAWN_CLI_SERVICE), so this does not fall back to a bash session." >&2
		exit 1
	}
elif ! DagcCliPresent "$DAGC_CLI" ; then
	for DAGC_FALLBACK_CLI in $DAGC_SELECTABLE_CLIS ; do
		if [ "$DAGC_FALLBACK_CLI" = "$DAGC_CLI" ] ; then
			continue
		fi
		if [ "$1" == "--non-interactive" ] ; then
			case " $DAGC_SELECTABLE_NONINTERACTIVE " in
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
		DagcExecBashConsole "no agent CLI was started: '$DAGC_CLI' and every other known CLI ($DAGC_SELECTABLE_CLIS) was looked for by 'command -v' in PATH and none was found."
	fi
fi

## The actual argv[0] `exec` below reaches for. A vendor CLI's own name IS the
## binary; a leg's is not -- `claude`, `copilot`, `grok` and `scaleway` name files, not
## PATH -- so the leg branch is the one substitution point where the harness
## script stands in for the name. `$DAGC_CLI` itself stays the logical name
## everywhere else in this file (DISTRO_CONSOLE_EXEC=, the credential/flag
## branches, the warnings), so reporting and dispatch never disagree about what
## was selected. The harness file is NOT re-derived here: it is whatever the leg
## table resolved at the top of this file, the same value DagcCliPresent()
## tested, so the file this exec's is always the file that was checked for.
if DagcCliIsLeg "$DAGC_CLI" ; then
	DAGC_CLI_EXEC="$( DagcLegFileFor "$DAGC_CLI" )"
else
	case "$DAGC_CLI" in
		## The name whose binary is not itself. `claude-native` exists to say
		## WHICH claude is meant once this package ships a claude leg of its own; the
		## thing it launches is still the vendor binary, spelled `claude`. This arm is
		## what stops the exec below reaching for a `claude-native` that is on no PATH.
		claude-native) DAGC_CLI_EXEC="claude" ;;
		copilot-native) DAGC_CLI_EXEC="copilot" ;;
		grok-native) DAGC_CLI_EXEC="grok" ;;
		*)             DAGC_CLI_EXEC="$DAGC_CLI" ;;
	esac
fi

DAGC_MYXROOT="$MDLT_ORIGIN/myx/myx.common/os-myx.common/host/tarball/share/myx.common"
if [ -x "$DAGC_MYXROOT/bin/setup/agentMcp.Common" ] ; then
	MYXROOT="$DAGC_MYXROOT" MYX_AGENTMCP_TARGET_CWD="$MMDAPP" "$DAGC_MYXROOT/bin/setup/agentMcp.Common" >/dev/null 2>&1 || :
elif command -v myx.common >/dev/null 2>&1 ; then
	MYX_AGENTMCP_TARGET_CWD="$MMDAPP" myx.common setup/agentMcp >/dev/null 2>&1 || :
fi

## The team's own access-root set. Where this client's flag carries a verb the set
## comes from this package's own definition, AgentsTools.ClientAccessRoots.include,
## and read and write are rendered separately. Where the flag carries no verb the
## launch fragment beside it still serves that client's own integration, unchanged.
## own/explicit are install-guaranteed and trusted unconditionally; wildcard and
## untagged carry no provenance and are existence-checked at spawn, since a root
## that does not exist fails the whole spawn.
## Why the split is rendered at all: with no write flag the core makes writes exactly
## as wide as reads, so the first caller to pass one write root collapses every other
## write in the same call and still reports success.
DAGC_ACCESS_FLAG=""
DAGC_ACCESS_WRITE_FLAG=""
if DagcCliIsLeg "$DAGC_CLI" ; then
	## One spelling for every leg: they all reach the same universal core, which
	## is what parses it, so this is a property of the harness and not of a provider.
	DAGC_ACCESS_FLAG="--access-read-root"
	DAGC_ACCESS_WRITE_FLAG="--access-write-root"
else
	case "$DAGC_CLI" in
		## One flag, no verb, so a root granted for reading is granted for writing.
		## That is this vendor CLI's own interface and not a gap here.
		copilot|copilot-native|claude|claude-native) DAGC_ACCESS_FLAG="--add-dir" ;;
	esac
fi
DAGC_ACCESS_ARGS=()
DAGC_ACCESS_GUARANTEED=0
DAGC_ACCESS_WILDCARD_TOTAL=0
DAGC_ACCESS_WILDCARD_ADDED=0
if [ -n "$DAGC_ACCESS_FLAG" ] ; then
	DAGC_ACCESS_INCLUDE="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.ClientAccessRoots.include"
	if [ ! -f "$DAGC_ACCESS_INCLUDE" ] ; then
		echo "⛔ ERROR: DistroAgentsConsole: the access-root mechanism is missing: $DAGC_ACCESS_INCLUDE -- refusing rather than falling back to a rendered copy of it" >&2
		exit 1
	fi
	. "$DAGC_ACCESS_INCLUDE"
fi
## One append site for both sets, so no root is admitted by one rule on the read
## side and a different one on the write side.
DagcAccessAppend(){
	case "$( AgentsToolsClientAccessRootTag "$2" )" in
		own|explicit)
			DAGC_ACCESS_ARGS+=( "$1" "$2" )
			DAGC_ACCESS_GUARANTEED=$(( DAGC_ACCESS_GUARANTEED + 1 ))
		;;
		*)
			DAGC_ACCESS_WILDCARD_TOTAL=$(( DAGC_ACCESS_WILDCARD_TOTAL + 1 ))
			if [ -d "$2" ] ; then
				DAGC_ACCESS_ARGS+=( "$1" "$2" )
				DAGC_ACCESS_WILDCARD_ADDED=$(( DAGC_ACCESS_WILDCARD_ADDED + 1 ))
			fi
		;;
	esac
}
: "${MDAT_SPAWN_AGENT:=magic-coordinator}"
if [ -n "$DAGC_ACCESS_WRITE_FLAG" ] ; then
	## The include reaches the config store through this name. This console otherwise
	## calls the tool by path, so without this the machine's own extra read roots are
	## dropped in silence and a narrower grant looks exactly like a full one.
	if ! type DistroAgentsTools >/dev/null 2>&1 ; then
		DistroAgentsTools(){ "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" "$@" ; }
	fi
	## Reads stay the full union, which is what every console generated before this
	## already passed. Writes narrow to what may actually be written: the work
	## directories, plus the roots a declared Edit grant names.
	## Captured with its status and stderr, so a failed producer refuses the spawn with
	## its reason: read through the herestring directly, a short set passes as whole.
	if ! DAGC_ACCESS_ROOTS="$( AgentsToolsClientAccessRoots "$MMDAPP" "$MDAT_SPAWN_AGENT" 2>&1 )" ; then
		echo "⛔ ERROR: DistroAgentsConsole: the access-root set could not be computed, refusing rather than starting $DAGC_CLI on a partial set: $DAGC_ACCESS_ROOTS" >&2
		exit 1
	fi
	while IFS= read -r DAGC_ACCESS_LINE ; do
		case "$DAGC_ACCESS_LINE" in /*) DagcAccessAppend "$DAGC_ACCESS_FLAG" "$DAGC_ACCESS_LINE" ;; esac
	done <<< "$DAGC_ACCESS_ROOTS"
	while IFS= read -r DAGC_ACCESS_LINE ; do
		case "$DAGC_ACCESS_LINE" in /*) DagcAccessAppend "$DAGC_ACCESS_WRITE_FLAG" "$DAGC_ACCESS_LINE" ;; esac
	done <<< "$( { AgentsToolsClientAccessReferenceRoots write "$MMDAPP" "$MDAT_SPAWN_AGENT" ; AgentsToolsClientAccessGrantRoots ; } | LC_ALL=C sort -u )"
	## This spawn's own sandbox, per-spawn and named by its tracking id: input/ is
	## readable and output/ is writable. ADDED to the two sets above rather than
	## replacing them, which is the whole reason the write set is rendered on its own
	## flag -- one write root passed alone would take every other write away.
	## The sandbox ROOT itself is granted on neither side on purpose: the session
	## tracking file lives there, and a record the session can reach is one it can forge.
	if [ -n "${MDAT_SPAWN_SANDBOX_ROOT:-}" ] ; then
		DagcAccessAppend "$DAGC_ACCESS_FLAG" "$MDAT_SPAWN_SANDBOX_ROOT/input"
		DagcAccessAppend "$DAGC_ACCESS_WRITE_FLAG" "$MDAT_SPAWN_SANDBOX_ROOT/output"
	fi
	## Said because a partial set is otherwise silent: the member roots drop out
	## where the skillset root is unresolved, and a narrower grant then looks
	## exactly like a full one.
	echo "# console: $DAGC_CLI access roots: $DAGC_ACCESS_GUARANTEED install-guaranteed + $DAGC_ACCESS_WILDCARD_ADDED of $DAGC_ACCESS_WILDCARD_TOTAL live-checked candidates existed, added; member set from ${MDAT_SKILLSET_ROOT:-<unresolved>}" >&2
elif [ -n "$DAGC_ACCESS_FLAG" ] ; then
	DAGC_ACCESS_FRAGMENT="$MMDAPP/.claude/copilot-add-dir.fragment"
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
	## The sandbox on a flag that carries no verb: both halves are granted alike, and input/
	## stays read-only by its own file mode, set when it is filled. The root stays ungranted.
	if [ -n "${MDAT_SPAWN_SANDBOX_ROOT:-}" ] ; then
		DagcAccessAppend "$DAGC_ACCESS_FLAG" "$MDAT_SPAWN_SANDBOX_ROOT/input"
		DagcAccessAppend "$DAGC_ACCESS_FLAG" "$MDAT_SPAWN_SANDBOX_ROOT/output"
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
if DagcCliIsLeg "$DAGC_CLI" ; then
	## A leg declares its own credential names, in HARNESS_CREDENTIAL_NAMES, and
	## the universal core refuses by that same declaration when none of them is
	## set. Reading the names out of the leg file is what keeps the gate a caller
	## meets and the names exported here one single statement -- a console copy
	## per provider is how the two drift, and a leg whose key is never exported
	## fails at the gate for a reason that is true of the console, not of the key.
	## Only upper-case tokens are taken, so a declaration reading
	## "SCALEWAY_DEEPSEEK or SCALEWAY_GEMMA" yields the two names and not the word.
	DAGC_CLI_CREDENTIALS="$( LC_ALL=C awk -F= '
		$1 == "HARNESS_CREDENTIAL_NAMES" {
			sub( /^[^=]*=/, "", $0 )
			gsub( /[^A-Za-z0-9_]/, " ", $0 )
			credentialCount = split( $0, credentialParts, " " )
			credentialNames = ""
			for ( credentialIndex = 1 ; credentialIndex <= credentialCount ; credentialIndex ++ ) {
				if ( credentialParts[ credentialIndex ] !~ /^[A-Z][A-Z0-9_]*$/ ) { continue ; }
				if ( credentialNames != "" ) { credentialNames = credentialNames " " ; }
				credentialNames = credentialNames credentialParts[ credentialIndex ]
			}
			print credentialNames
			exit
		}
	' "$DAGC_CLI_EXEC" )" || DAGC_CLI_CREDENTIALS=""
	if [ -z "$DAGC_CLI_CREDENTIALS" ] ; then
		echo "🙋 WARNING: DistroAgentsConsole: harness leg '$DAGC_CLI' declares no HARNESS_CREDENTIAL_NAMES in $DAGC_CLI_EXEC -- this spawn exports no credential for it, and the leg's own refusal is what a caller will see" >&2
	fi
else
	## Every remaining name here is a vendor CLI, and none of them takes a
	## credential from us: a -native CLI runs on the machine's own sign-in, and
	## grok-native has no credential of ours either. The arms that once named
	## ANTHROPIC_API_KEY and COPILOT_GITHUB_TOKEN for `claude` and `copilot`
	## are gone with those names: both are harness legs now, and each declares
	## its own credential names in the branch above.
	DAGC_CLI_CREDENTIALS=""
fi
for DAGC_CREDENTIAL_NAME in $DAGC_CLI_CREDENTIALS ; do
	## Tested, not bare: set -e would kill the console on an unreadable scope.
	DAGC_CREDENTIAL_VALUE="$( "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --agents-config-option magic-team --select "$DAGC_CREDENTIAL_NAME" 2>/dev/null )" || DAGC_CREDENTIAL_VALUE=""
	[ -n "$DAGC_CREDENTIAL_VALUE" ] || continue
	export "$DAGC_CREDENTIAL_NAME=$DAGC_CREDENTIAL_VALUE"
done

## claude-native: a signed-out spawn uses a configured key, else rc 6; an interactive console is only warned. MAGIC.md, "Claude sign-in".
DagcClaudeAuthProbe(){
	case "$( claude auth status </dev/null 2>/dev/null | LC_ALL=C tr -d ' \t' )" in
		*'"loggedIn":true'*)  printf 'in' ;;
		*'"loggedIn":false'*) printf 'out' ;;
		*)                    printf 'unknown' ;;
	esac
}
if [ "$DAGC_CLI" = "claude-native" ] && [ "$( DagcClaudeAuthProbe )" = "out" ] ; then
	if [ "$1" == "--non-interactive" ] ; then
		DAGC_CLAUDE_KEY=""
		for DAGC_CREDENTIAL_NAME in ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN ; do
			DAGC_CREDENTIAL_VALUE="$( "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --agents-config-option magic-team --select "$DAGC_CREDENTIAL_NAME" 2>/dev/null )" || DAGC_CREDENTIAL_VALUE=""
			[ -n "$DAGC_CREDENTIAL_VALUE" ] || continue
			export "$DAGC_CREDENTIAL_NAME=$DAGC_CREDENTIAL_VALUE"
			DAGC_CLAUDE_KEY="$DAGC_CREDENTIAL_NAME"
			echo "# DistroAgentsConsole: claude is not signed in on this machine, so the configured $DAGC_CREDENTIAL_NAME is used for this spawn" >&2
			break
		done
		if [ -z "$DAGC_CLAUDE_KEY" ] ; then
			echo "⛔ ERROR: DistroAgentsConsole: claude is installed and selected but not signed in on this machine, and no ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN is configured for a spawn to use. rc=6 means exactly this -- the CLI is present and cannot act -- distinct from rc=5 (none selected) and rc=1 (could not start). Sign in with claude, or set one of those keys with --owner-setup-claude-native." >&2
			exit 6
		fi
	else
		echo "🙋 WARNING: DistroAgentsConsole: claude is not signed in on this machine -- sign in with /login once it starts" >&2
	fi
fi

## The spawn proxy mints this session uuid, records it on its own dispatch
## document and exports it here, so a hook's own session_id joins that record.
## claude, copilot and every harness leg take the flag; any other CLI has it
## reported and dropped rather than silently ignored, since the dispatch
## record would otherwise name a session nothing else ever reports. A leg has
## no external hook observer of its own -- the universal core just announces
## the id to stderr, which is the only "join" possible for it.
DAGC_SESSION_ID_ARGS=()
if [ -n "$MDAT_SPAWN_SESSION_ID" ] ; then
	## MDAT_SPAWN_RESUME: set by the spawn proxy's own one-shot handback-enforcement
	## retry (AgentsToolsSpawnProxyHandbackWarn) to continue the SAME transcript
	## rather than open a new one, so the model gets a real second turn instead
	## of a session it has no memory of. Only claude/claude-native carry a real
	## --resume; every other CLI refuses rather than silently starting a plain
	## new session that would be reported as a resume and is not one.
	if [ "${MDAT_SPAWN_RESUME:-false}" = "true" ] ; then
		case "$DAGC_CLI" in
			claude|claude-native)
				DAGC_SESSION_ID_ARGS=( --resume "$MDAT_SPAWN_SESSION_ID" )
			;;
			*)
				echo "⛔ ERROR: DistroAgentsConsole: MDAT_SPAWN_RESUME is true but '$DAGC_CLI' has no --resume flag -- refusing rather than starting a session that would look resumed and is not one" >&2
				exit 1
			;;
		esac
	elif DagcCliIsLeg "$DAGC_CLI" || [ "$DAGC_CLI" = "claude" ] || [ "$DAGC_CLI" = "claude-native" ] || [ "$DAGC_CLI" = "copilot" ] || [ "$DAGC_CLI" = "copilot-native" ] ; then
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
## actually there. A harness leg resolves the member itself, from its own skill
## directory (`$MDAT_SKILLSET_ROOT/<name>/<name>.basic.md`), so no
## pre-existing-file gate is needed for one the way copilot's is. The name is
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
	if DagcCliIsLeg "$DAGC_CLI" ; then
		DAGC_AGENT_ARGS=( --agent "$MDAT_SPAWN_AGENT" )
	else
		case "$DAGC_CLI" in
			## claude-native joins claude's own arm, never a copy of it: its BINARY
			## is claude (DAGC_CLI_EXEC="claude", set above), so the same
			## --agents/--agent pair the vendor CLI accepts under the "claude" name
			## is accepted under this name too. Before this fix MDAT_SPAWN_AGENT hit
			## the `*)` warning arm here, so a claude-native spawn's hooks reported
			## the generic agent type instead of the real member name.
			claude|claude-native)
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
fi

## The vendor claude binary only: piping its own JSON-lines stream through the awk formatter is
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

## The vendor copilot CLI's own memory tools are hidden from its model, interactive or
## not: the set is the client tool policy's (AgentsToolsClientToolPolicyCopilotExcludedTools).
## One `--excluded-tools=a,b` token, never the variadic spelling, which would swallow the
## arguments after it. Refused when the policy cannot say, rather than launched without it.
DAGC_POLICY_ARGS=()
if [ "$DAGC_CLI" = "copilot-native" ] ; then
	DAGC_POLICY_INCLUDE="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.ClientToolPolicy.include"
	DAGC_COPILOT_EXCLUDED=""
	[ ! -f "$DAGC_POLICY_INCLUDE" ] || { . "$DAGC_POLICY_INCLUDE" && DAGC_COPILOT_EXCLUDED="$( AgentsToolsClientToolPolicyCopilotExcludedTools )" ; }
	if [ -z "$DAGC_COPILOT_EXCLUDED" ] ; then
		echo "⛔ ERROR: DistroAgentsConsole: the client tool policy could not name copilot's memory tools to exclude: $DAGC_POLICY_INCLUDE -- refusing rather than launching copilot with them" >&2
		exit 1
	fi
	DAGC_POLICY_ARGS=( "--excluded-tools=$DAGC_COPILOT_EXCLUDED" )
fi

if [ "$1" == "--non-interactive" ] ; then
	shift
	## No human answers this run, so the harness gates it as unattended.
	export MDAT_SESSION_UNATTENDED=true
	## -- closes the option list for claude, whose prompt is positional; copilot's -p takes the body as its value.
	## A harness leg takes neither: the universal core's own arg parser knows
	## --tier/--access-read-root/--, and reads its prompt as plain trailing argv
	## (or stdin) exactly like claude/copilot's *own* prompt body does once
	## their flags are stripped -- a `-p`/`-p --` token would hit its default
	## `*) break` arm unconsumed and be read back as literal prompt text.
	if DagcCliIsLeg "$DAGC_CLI" ; then
		DAGC_NONINTERACTIVE_PERM_FLAGS="" ; DAGC_PROMPT_ARGS=()
		## The tier this workspace asks of every harness leg. Unset passes nothing and
		## the harness keeps its own default; a value it does not know it refuses itself.
		DAGC_HARNESS_TIER="$( "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --agents-config-option magic-team --select SPAWN_HARNESS_TIER 2>/dev/null )" || DAGC_HARNESS_TIER=""
		[ -z "$DAGC_HARNESS_TIER" ] || DAGC_PROMPT_ARGS=( --tier "$DAGC_HARNESS_TIER" )
	else
		case "$DAGC_CLI" in
			copilot|copilot-native)  DAGC_NONINTERACTIVE_PERM_FLAGS="--allow-all-tools" ; DAGC_PROMPT_ARGS=( -p ) ;;
			## claude-native takes NO arm here on purpose, and the reason is worth
			## stating because the next reader will want to add one: the default IS
			## claude's shape, so the vendor CLI under either of its names lands here
			## correctly. An arm spelling out the same two values would be a second
			## copy to keep in step with this one. Correct-by-default is only safe
			## when it is deliberate, so this comment is the deliberateness.
			*)        DAGC_NONINTERACTIVE_PERM_FLAGS="" ; DAGC_PROMPT_ARGS=( -p -- ) ;;
		esac
	fi
	## The launch signal, on its own channel: the stdout line below shares a stream with the agent's own output.
	[ -z "$MDAT_SPAWN_LAUNCH_MARKER" ] || printf '%s\n' "$DAGC_CLI" > "$MDAT_SPAWN_LAUNCH_MARKER"
	## Gated on the vendor binary, never on the name: `claude` is a harness leg, and a
	## leg reads the streaming flags as its prompt, dropping every flag after them.
	if [ $# -gt 0 ] ; then
		echo "DISTRO_CONSOLE_EXEC=$DAGC_CLI"
		if [ "$DAGC_CLI_EXEC" = "claude" ] ; then
			DagcRunClaudeStreaming "$*"
		fi
		exec "$DAGC_CLI_EXEC" $DAGC_NONINTERACTIVE_PERM_FLAGS "${DAGC_POLICY_ARGS[@]}" "${DAGC_ACCESS_ARGS[@]}" "${DAGC_SESSION_ID_ARGS[@]}" "${DAGC_AGENT_ARGS[@]}" "${DAGC_PROMPT_ARGS[@]}" "$*"
	fi
	echo "DISTRO_CONSOLE_EXEC=$DAGC_CLI"
	if [ "$DAGC_CLI_EXEC" = "claude" ] ; then
		DagcRunClaudeStreaming "$( cat )"
	fi
	exec "$DAGC_CLI_EXEC" $DAGC_NONINTERACTIVE_PERM_FLAGS "${DAGC_POLICY_ARGS[@]}" "${DAGC_ACCESS_ARGS[@]}" "${DAGC_SESSION_ID_ARGS[@]}" "${DAGC_AGENT_ARGS[@]}" "${DAGC_PROMPT_ARGS[@]}" "$( cat )"
fi

echo "DISTRO_CONSOLE_EXEC=$DAGC_CLI"
exec "$DAGC_CLI_EXEC" "${DAGC_POLICY_ARGS[@]}" "${DAGC_ACCESS_ARGS[@]}" "${DAGC_SESSION_ID_ARGS[@]}" "${DAGC_AGENT_ARGS[@]}" "$@"
