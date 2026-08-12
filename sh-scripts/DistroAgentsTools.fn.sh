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
## --magic-sweep-input-scan's two-phase board scan calling
## --intern-op-session-context-scan once for phase 1 and again for phase 2)
## does so via self-recursion into `DistroAgentsTools` itself, matching
## DistroLocalTools.fn.sh's own `--upgrade-installed-tools` precedent
## (`DistroLocalTools --install-distro-$ITEM`), not via a private helper
## function.
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
## LocalTools.Config.include) and --member-comms-slack-send-message (reuses myx.common's
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

##
## Shared utility helpers -- genuinely reused across multiple unrelated ops
## below, same category as DistroLocalTools.fn.sh's GitClonePull/Prefix/
## CatMarkdown: reusable plumbing, not a stand-in for a dispatch case.
##

## Resolves a --member-comms-slack-send-message/--intern-op-slack-check style target
## (magic-team|human-owner|event-track|event-alert|<channel>|<channel>:<ts>) to
## a channel id + optional thread ts. Shared resolution grammar across every
## op that takes one -- --member-comms-slack-read, --intern-op-slack-check,
## --member-comms-slack-react, --member-comms-slack-send-message,
## --magic-comms-slack-resolve-ids and --intern-op-session-context-scan --
## kept as a utility helper (like the ones above) rather than duplicated
## once per op.
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
		##
		## BARE CONVERSATION ID -- names a WHOLE conversation, so a send against
		## it is a NEW TOP-LEVEL message, never a threaded reply. It emits the id
		## VERBATIM as CHANNEL= and leaves THREAD_TS EMPTY, and the empty thread
		## ts is exactly what makes the send path post at top level.
		##
		## WHY IT EXISTS: an alias exists only for the four conversations this
		## team configured for itself. Before this arm a member could REPLY
		## anywhere (<channel>:<ts> has always been accepted) but could only START
		## a conversation where an alias happened to exist -- so a workspace whose
		## channels carry no alias was reachable for replies and unreachable for a
		## first message.
		##
		## WHY IT CANNOT COLLIDE WITH THE ARMS ABOVE, which is why its position is
		## load-bearing and must stay last-but-one: every alias arm has already had
		## its turn, and so has `*:*`. A token carrying a ':' was therefore already
		## consumed as <channel>:<ts> and can never arrive here; a token that does
		## arrive here carries no ':' and so can never be read as <channel>:<ts>.
		## The two grammars are disjoint by construction, not by inspection.
		##
		## WHAT IT ACCEPTS, and nothing else: at least 9 characters, every one of
		## them an UPPERCASE letter or a digit, the first one an uppercase letter.
		## The `?????????*` pattern carries the length; the loop carries the
		## alphabet, one character at a time.
		##
		## WHY UPPERCASE-ONLY rather than a C/D/G prefix test: all four aliases are
		## lowercase-with-hyphen, so an uppercase-only token cannot collide with an
		## alias that exists today NOR with a lowercase alias added later -- the
		## disambiguation survives the alias list growing, which a prefix test does
		## not. Not hardcoding C/D/G also means a future Slack id shape keeps
		## resolving here instead of silently becoming an unrecognized target.
		##
		## WHAT IT REJECTS, deliberately, all of which fall through to `return 2`
		## and stay unrecognized targets exactly as today: anything lowercase (a
		## mistyped alias, or an id typed in lower case); anything shorter than 9
		## characters; anything holding a character outside {uppercase letter,
		## digit} -- a space, ';', '#', '/', '-', '.' -- so `#general`,
		## `--identity-bot`, `D0BHQ3VTL B1`, `D0BHQ3VTLB1;ls` and a bare
		## `1234567890.123456` are all refused; and anything not starting with a
		## letter.
		##
		## NEVER a [A-Z]/[0-9] bracket range in the patterns below, for the reason
		## AgentsToolsAssertBareName states at length above: bracket ranges are
		## collation-dependent under en_US.UTF-8, so a range-based whitelist is not
		## a whitelist at all. Every accepted character is enumerated explicitly.
		##
		## The id is passed through VERBATIM -- no trim, no substitution, no
		## extraction. A message posted into an unintended conversation cannot be
		## recalled, so this arm either accepts the caller's exact token or refuses
		## it outright; it never repairs one.
		##
		## THE SIBLING OPS INHERIT THIS GRAMMAR, and that is the intent: the target
		## grammar lives in this one function, and a widened copy pasted into a
		## single op is how two copies drift into a disambiguation bug. The ops
		## that need a <ts> refuse an empty THREAD_TS with their own error already,
		## so no mutating call is reached with a bare id; the conversation-level
		## ops answer for a bare id the same question they already answer for an
		## alias.
		?????????*)
			local bareRest="$target" bareChar bareFirst="true"
			while [ -n "$bareRest" ] ; do
				bareChar="${bareRest%"${bareRest#?}"}"
				bareRest="${bareRest#?}"
				case "$bareChar" in
					A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z) ;;
					0|1|2|3|4|5|6|7|8|9)
						## Positive test on the position, not a negation: a digit is
						## accepted only when something already preceded it, so a
						## digit-leading token is not an id shape and is refused here
						## rather than deeper in.
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

## Shared bare-name assertion: <value> must be a single path segment made only
## of characters this family already uses for member names and item filenames --
## letters, digits, '.', '_' and '-'. Rejects the empty string, '.', '..', any
## leading '-', any '/', and any character outside that set.
##
## This is THE bare-name gate for the whole family: every op taking a member
## name, item filename, document name, or board/vault/audit item name validates
## through here, in this file and across sh-lib/. A new op of that shape calls
## this -- it never re-inlines a `case "$x" in */*|.|..)` copy. Those copies are
## what this replaced, and they were strictly weaker: each one caught only '/',
## '.' and '..', silently accepting spaces, ':' and a leading '-' that this
## rejects. Deliberately NO count of call sites is recorded here -- a hard
## number in this comment is exactly the thing that goes stale and misleads.
##
## Contract: <value> <label> <context>. This helper only reports and returns 1;
## it never exits, so callers own their own `set -e` state and handle failure
## with `|| { set +e ; return 1 ; }`.
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
		## Console-session operation group -- see
		## sh-lib/AgentsTools.ConsoleSession.include. Glob route, so a new
		## --console-* op needs no dispatcher edit.
		--console-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.ConsoleSession.include"
			return $?
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

		## The comms operation group, ONE INCLUDE PER PLATFORM: every op here
		## takes <team-member> as its first argument, and that member IS the
		## acting identity -- which is why `comms` is a namespace layer UNDER
		## the member prefix, --member-comms-<service>-<verb>, and not a prefix
		## of its own. The `<service>` segment is what these three routes split
		## on, so the route a name takes and the file that implements it are
		## the same fact read twice.
		##
		## THESE ARE GLOBS, AND THAT IS NEWLY SAFE. The single enumeration
		## these three replaced had to name every op by hand because two ops
		## did NOT live in the included file: --member-comms-slack-send-message
		## sat in AgentsTools.Member.include and --member-comms-email-send sat
		## inline in this dispatcher, so any --member-comms-* glob would have
		## silently stolen both away from the code that implemented them. Both
		## now live with their own platform, which is the whole precondition
		## these globs rest on. A --member-comms-<service>-* op therefore costs
		## no dispatcher line -- and moving one back out to some other include
		## would break the route silently, not loudly.
		##
		## --intern-op-slack-check is deliberately NOT reached here any more.
		## It carries the --intern-op-* prefix rather than a member-facing one,
		## and it has its own include alongside its --intern-op-* siblings
		## further down. Routing it here would mean pinning one exact name onto
		## a --member-comms-slack-* glob, which is exactly the by-name coupling
		## these routes exist to retire.
		##
		## Listed AHEAD of the --member-* route further down, which is what
		## makes these three the ones that win -- without that position the
		## --member-* glob would take every op they match.
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

		## Coordinator comms-id resolver extracted to dedicated include
		## (shared-tooling path, keeps dispatcher lean and keeps resolver's
		## parsing helpers out of this main script).
		--magic-comms-slack-resolve-ids)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MagicComms.include"
			return $?
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

		## magic-librarian own operation group -- see
		## sh-lib/AgentsTools.Librarian.include. Glob route, so a new
		## --librarian-* op needs no dispatcher edit.
		--librarian-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.Librarian.include"
			return $?
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

		## Workspace/skillset install operation group -- see
		## sh-lib/AgentsTools.Install.include. Glob route, so a new
		## --install-* op needs no dispatcher edit.
		--install-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.Install.include"
			return $?
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
		## Path-addressed rename for items in ANY store (board/, inboxes/,
		## audit/), as against --intern-op-board-rename below which resolves a
		## bare name across board/<state>/ only and cannot reach the other two.
		## Separate op, not an extension: this one hard-errors on every
		## unresolvable condition instead of rewriting references anyway and
		## returning 0. See AgentsTools.InternOpItemRename.include's own header.
		--intern-op-item-rename)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpItemRename.include"
			return $?
		;;

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

		## Internal plumbing, no --help entry -- the shared lock implementation
		## (acquire/refresh/release/status) underlying
		## --magic-{heartbeat,advance,grooming,daily,retro}-lock-*. One unified mechanism:
		## frontmatter + git when TEAM_DATA_GIT_REMOTE is configured, the
		## `mkdir` mutex when it is not. Glob route, so a new verb needs no
		## dispatcher edit. See AgentsTools.InternOpLock.include's own header.
		--intern-op-lock-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpLock.include"
			return $?
		;;

		## Internal plumbing, no --help entry -- the shared implementation
		## underlying --magic-grooming-state-and-lock-upsert/
		## --magic-advance-state-and-lock-upsert. Writes a routine's fixed
		## `*-state-and-lock.md` note, then commits and pushes THAT ONE FILE
		## when a git remote is configured for the board: the push result is
		## the lock verdict. See AgentsTools.InternOpStateAndLockUpsert.include's
		## own header.
		--intern-op-state-and-lock-upsert)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpStateAndLockUpsert.include"
			return $?
		;;

		## Internal plumbing, no --help entry -- THE one place Slack is called.
		## Identity selection, token handling and per-identity DM resolution live
		## there and nowhere else; see that file's own header.
		--intern-op-slack-call)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpSlackCall.include"
			return $?
		;;

		## The sweep machinery's own Slack reader. Routed by exact name here,
		## among its --intern-op-* siblings rather than with the
		## --member-comms-slack-* ops it reads alongside: the name carries the
		## --intern-op-* prefix, and one internal primitive per include is this
		## dispatcher's own unbroken convention. See
		## AgentsTools.InternOpSlackCheck.include's own header.
		--intern-op-slack-check)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpSlackCheck.include"
			return $?
		;;

		## Internal plumbing, no --help entry -- verifies GRANTED Slack scopes for
		## the identity each op ACTUALLY runs under (asked of --intern-op-slack-call,
		## never re-derived) against what that op declares it needs. Holds no
		## scope list of its own; see that file's own header.
		--intern-op-check-slack-scopes)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.InternOpCheckSlackScopes.include"
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
		## (--magic-comms-trello-post-comment) -- see
		## AgentsTools.MagicTrello.include's own header.
		--magic-comms-trello-*)
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

		## routine-daily's own operation group (--magic-daily-lock-*) -- see
		## AgentsTools.MagicDaily.include's own header.
		--magic-daily-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MagicDaily.include"
			return $?
		;;

		## routine-retro's own operation group (--magic-retro-lock-*) -- see
		## AgentsTools.MagicRetro.include's own header.
		--magic-retro-*)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MagicRetro.include"
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
