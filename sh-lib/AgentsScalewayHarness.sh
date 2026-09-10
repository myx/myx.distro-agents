#!/usr/bin/env bash
set -e

## AgentsScalewayHarness.sh -- the tool-calling harness for Scaleway's
## Serverless Generative APIs, and the one the console runs by default. No
## real `scaleway` binary exists, so this script IS the CLI: it runs the
## whole request/tool-call/response loop itself. Standalone and
## self-contained -- see MAGIC.md for the full design.
##
## STREAMING: each round opens Scaleway's SSE stream (`"stream":true`) via
## `curl -N` and consumes it incrementally, so text and tool-call progress
## reach stderr as the model actually generates them, not only once the whole
## response has arrived. The stderr presentation layer this file owns -- the
## colour block below, the round rule, the per-tool icons in
## AgentsScalewayAnnounceTool -- is part of that same job, not decoration
## bolted onto it.
##
## `AgentsScalewayHarnessV1.sh`, beside this file, is the earlier BLOCKING
## implementation this one grew from: one plain POST per round, one complete
## JSON body parsed at the end, no streaming and no visual progress layer. It
## is preserved as an explicitly-selectable fallback and is reached only by
## asking for it by name (MDAT_SCALEWAY_HARNESS=AgentsScalewayHarnessV1.sh);
## nothing selects it on its own any more. The comments below call it "v1"
## where they name which behaviour came from where: every section from the
## tool definitions through message-history assembly started as a verbatim
## copy of it (the 5 tool-execution functions, access-root enforcement,
## credential resolution, --tier/--session-id/--agent handling, the
## AgentsScalewayJsonField.awk-based field reader, AgentsScalewayTruncateArg)
## and the two have not diverged there. What this file does NOT share with it
## is the transport below and the whole stderr presentation layer above.
## See MAGIC.md's own "Streaming transport, and `AgentsScalewayHarnessV1.sh`"
## section for the real SSE event shape and the full reasoning behind both
## design decisions summarized below.
##
## DESIGN DECISION 1 -- a mid-stream disconnect discards whatever partial
## state arrived (streamed content, per-tool-call id/name/arguments) and
## retries the whole round from scratch, bounded at 3 attempts
## (scalewayStreamMaxAttempts, see the attempt loop below). There is no
## resume primitive on this API -- no stream id, no partial-completion
## token -- so retrying the identical full conversation-so-far request v1
## already builds each round is the only next request this API accepts, not
## an approximation of resuming. Every accumulator resets to empty at the
## start of every attempt, including a retried one.
##
## DESIGN DECISION 2 -- a disconnect-triggered retry never consumes a round
## against the existing 25-round cap (scalewayMaxRounds): scalewayRound
## increments exactly once per pass through the OUTER round loop, before the
## streaming attempt loop begins, so a retried attempt -- living entirely
## inside one outer-loop iteration -- never touches it. The cap bounds a
## conversation that has actually GROWN (new tool results appended); a
## retry resends the identical request, so nothing grew and nothing was
## billed for a completed generation.

scalewayHere="$( cd "$( dirname -- "$0" )" && pwd )"

## Colour is chrome this script writes itself: every sequence below is a
## literal here, and every untrusted value printed beside one still passes
## AgentsScalewayTruncateArg first. The gate is myx.common's own
## lib/catMarkdown.Common one, moved from its stdout to this script's stderr,
## plus NO_COLOR. Emoji are deliberately not gated -- printable UTF-8, not
## escapes, readable in a captured log, and the only channel left without colour.
scalewayDim=""
scalewayTool=""
scalewayValue=""
scalewayWarn=""
scalewayBad=""
scalewayOff=""
if [ -t 2 ] && [ -z "${NO_COLOR:-}" ] && [ -n "${TERM-}" ] && [ "$TERM" != dumb ] && tput colors >/dev/null 2>&1 && [ "$( tput colors )" -ge 8 ] ; then
	scalewayDim=$'\033[2m'
	scalewayTool=$'\033[1;36m'
	scalewayValue=$'\033[32m'
	scalewayWarn=$'\033[1;33m'
	scalewayBad=$'\033[1;31m'
	scalewayOff=$'\033[0m'
fi

scalewayTier="normal"
scalewayAccessRoots=()
scalewaySessionId=""
scalewayAgent=""
while [ $# -gt 0 ] ; do
	case "$1" in
		--tier)
			case "${2:-}" in
				light|normal|heavy) scalewayTier="$2" ;;
				*)
					echo "${scalewayBad}⛔ ERROR:${scalewayOff} AgentsScalewayHarness.sh: --tier must be light, normal or heavy, got: ${2:-<none>}" >&2
					exit 1
				;;
			esac
			shift 2
		;;
		--access-root)
			if [ -z "${2:-}" ] ; then
				echo "${scalewayBad}⛔ ERROR:${scalewayOff} AgentsScalewayHarness.sh: --access-root: value required" >&2
				exit 1
			fi
			scalewayAccessRoots+=( "$2" )
			shift 2
		;;
		--session-id)
			## Light validation only -- this harness owns no uuid-format contract;
			## that belongs to whoever mints the id (the spawn proxy, via uuidgen).
			## A value is required, nothing more is checked.
			if [ -z "${2:-}" ] ; then
				echo "${scalewayBad}⛔ ERROR:${scalewayOff} AgentsScalewayHarness.sh: --session-id: value required" >&2
				exit 1
			fi
			scalewaySessionId="$2"
			shift 2
		;;
		--agent)
			## Same bare-token gate AgentsConsoleShellScript.template.sh applies to
			## MDAT_SPAWN_AGENT before it goes into JSON or a path -- reproduced
			## here rather than shared, since this harness is standalone and
			## sources no include of its own. Character-by-character
			## enumeration, never a collation-dependent [a-zA-Z0-9._-] bracket
			## range (see MAGIC.md's "A bracket range is never used in a `case`
			## pattern" and AgentsToolsAssertBareName in
			## sh-scripts/DistroAgentsTools.fn.sh, whose exact enumerated set
			## this mirrors). '.' and '..' are rejected explicitly: both consist
			## only of otherwise-allowed characters, and $scalewayAgent below is
			## used as a path segment fed to `cd` -- either would walk one
			## directory level outside $MDAT_SKILLSET_ROOT.
			case "${2:-}" in
				''|.|..)
					echo "${scalewayBad}⛔ ERROR:${scalewayOff} AgentsScalewayHarness.sh: --agent is not a bare member name: ${2:-<none>}" >&2
					exit 1
				;;
			esac
			scalewayAgentCheckRest="${2:-}"
			while [ -n "$scalewayAgentCheckRest" ] ; do
				scalewayAgentCheckChar="${scalewayAgentCheckRest%"${scalewayAgentCheckRest#?}"}"
				scalewayAgentCheckRest="${scalewayAgentCheckRest#?}"
				case "$scalewayAgentCheckChar" in
					a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z) ;;
					A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z) ;;
					0|1|2|3|4|5|6|7|8|9) ;;
					-|_|.) ;;
					*)
						echo "${scalewayBad}⛔ ERROR:${scalewayOff} AgentsScalewayHarness.sh: --agent is not a bare member name: ${2:-<none>}" >&2
						exit 1
					;;
				esac
			done
			scalewayAgent="$2"
			shift 2
		;;
		--)
			shift
			break
		;;
		*)
			break
		;;
	esac
done

## --session-id: Scaleway has no external hook observer the way claude/copilot
## do under Claude Code's own instrumented lifecycle (confirmed by
## investigation), so this announce line is the only "join" possible at all --
## the harness itself is the one thing that can surface the id anywhere.
if [ -n "$scalewaySessionId" ] ; then
	printf '%s\n' "🔗 ${scalewayDim}session${scalewayOff} ${scalewayValue}$scalewaySessionId${scalewayOff}" >&2
fi

## --agent: the member's own real identity, read from its own skill directory.
## Prepended into the system prompt below (scalewaySystemText), replacing the
## generic opener entirely. Missing/unreadable is a loud, immediate failure --
## never a silent fallback to the generic prompt, which would look like a
## successful --agent spawn while actually running as nobody in particular.
scalewayAgentBasicText=""
scalewayAgentRealDir=""
if [ -n "$scalewayAgent" ] ; then
	scalewayAgentDir="${MDAT_SKILLSET_ROOT:-}/$scalewayAgent"
	scalewayAgentBasicFile="$scalewayAgentDir/$scalewayAgent.basic.md"
	if [ -z "${MDAT_SKILLSET_ROOT:-}" ] || [ ! -f "$scalewayAgentBasicFile" ] || [ ! -r "$scalewayAgentBasicFile" ] ; then
		echo "${scalewayBad}⛔ ERROR:${scalewayOff} AgentsScalewayHarness.sh: --agent $scalewayAgent: no such file, or unreadable: ${MDAT_SKILLSET_ROOT:-<MDAT_SKILLSET_ROOT unset>}/$scalewayAgent/$scalewayAgent.basic.md" >&2
		exit 1
	fi
	scalewayAgentBasicText="$( cat "$scalewayAgentBasicFile" )"
	## Access roots are granted by real, symlink-resolved path
	## (AgentsToolsClientAccessRootsMembers's own `pwd -P`), while
	## AgentsScalewayPathAllowed does a raw string-prefix match with no symlink
	## resolution of its own (documented above it). $MDAT_SKILLSET_ROOT/<name>
	## is normally a symlink into that real location, so the armed.md path
	## handed to the model below must be resolved here too -- otherwise the
	## model's own read_file call on it is refused as outside the allowed
	## roots despite being the exact same file.
	scalewayAgentRealDir="$( cd "$scalewayAgentDir" 2>/dev/null && pwd -P )" || scalewayAgentRealDir="$scalewayAgentDir"
fi

## Remaining argv joined into one prompt, matching DistroAgentsConsole.sh's
## own --non-interactive convention exactly -- this is also the exact shape
## the console's own non-interactive dispatch calls this script with (see
## MAGIC.md). Stdin when no argv prompt was given.
scalewayPrompt="$*"
if [ -z "$scalewayPrompt" ] ; then
	scalewayPrompt="$( cat )"
fi
if [ -z "$scalewayPrompt" ] ; then
	echo "${scalewayBad}⛔ ERROR:${scalewayOff} AgentsScalewayHarness.sh: no prompt given -- pass it as trailing argv, or on stdin" >&2
	exit 1
fi

## Tier -> (model, reasoning_effort, preferred credential). Either
## SCALEWAY_DEEPSEEK or SCALEWAY_GEMMA reaches either model -- Scaleway scopes
## a key by Project+policy, not by model, confirmed live against this exact
## pairing -- so the "other" name is a real fallback, not a placeholder.
## gemma-4-26b-a4b-it is a live-confirmed stand-in for the originally-decided
## google/gemma-4-31b-it:bf16, which this API's own /v1/models does not list
## under any spelling -- see MAGIC.md; flagged back, not silently swapped.
##
## Mapping REVERSED from the first cut, on real evidence, not naming-vibes
## (see MAGIC.md's tier-reclassification section for the full numbers):
## gemma-4-26b-a4b-it is a 25.2B-total MoE model with only 3.8B parameters
## ACTIVE per token; deepseek-v4-flash-0731 -- despite "flash" in its name --
## is a 284B-total MoE model with 13B active per token, ~3.4x gemma's. Scaleway's
## own per-token price confirms the same order: gemma EUR0.25/EUR0.50 (in/out)
## per million tokens versus deepseek EUR0.40/EUR0.80, and independent
## benchmark comparison (Artificial Analysis) puts deepseek far ahead on
## intelligence (index 35 vs 17). Gemma is the genuinely light, cheap, less
## capable model; deepseek is the substantial, expensive, more capable one --
## the opposite of what "flash" suggested. light now anchors on gemma alone;
## normal/heavy split deepseek by its own reasoning_effort, mirroring the
## original shape (one model alone for the cheap tier, the other model's own
## effort levels for the top two) with the two models' roles swapped.
scalewayReasoningEffort=""
case "$scalewayTier" in
	light)
		scalewayModel="gemma-4-26b-a4b-it"
		scalewayToken="${SCALEWAY_GEMMA:-${SCALEWAY_DEEPSEEK:-}}"
	;;
	normal)
		scalewayModel="deepseek-v4-flash-0731"
		scalewayToken="${SCALEWAY_DEEPSEEK:-${SCALEWAY_GEMMA:-}}"
	;;
	heavy)
		scalewayModel="deepseek-v4-flash-0731"
		scalewayReasoningEffort="high"
		scalewayToken="${SCALEWAY_DEEPSEEK:-${SCALEWAY_GEMMA:-}}"
	;;
esac

if [ -z "$scalewayToken" ] ; then
	echo "${scalewayBad}⛔ ERROR:${scalewayOff} AgentsScalewayHarness.sh: neither SCALEWAY_DEEPSEEK nor SCALEWAY_GEMMA is set in this process's own environment -- scaleway reads these names itself, exactly as claude reads ANTHROPIC_API_KEY" >&2
	exit 1
fi

## What this run costs, said once: the tier picked the model, and the model is
## what is metered. Both are this script's own literals, never model output.
printf '%s\n' "🤖 ${scalewayDim}scaleway${scalewayOff} ${scalewayTool}$scalewayModel${scalewayOff} ${scalewayDim}· $scalewayTier tier${scalewayOff}" >&2

## Access roots: standalone --access-root override, or this workspace's own
## copilot-add-dir.fragment (own/explicit trusted unconditionally, wildcard
## live-checked) -- same tag semantics AgentsConsoleShellScript.template.sh
## reads for claude/copilot, deliberately re-read here rather than threaded
## through from it. See MAGIC.md on why this is a second reader, not a shared one.
##
## Four line shapes, matching the template's own parser exactly -- confirmed
## against a REAL fragment still in the old two-line format (found live in
## this exact workspace): a bare `--add-dir` marker line, own/explicit/
## wildcard tagged lines, and a bare `/*` untagged path (the old format's
## other half, and any stray hand-edit) -- treated as wildcard, i.e.
## existence-checked rather than trusted, since it carries no recorded
## provenance.
scalewayRoots=""
if [ "${#scalewayAccessRoots[@]}" -gt 0 ] ; then
	for scalewayRoot in "${scalewayAccessRoots[@]}" ; do
		scalewayRoots="${scalewayRoots}${scalewayRoot}"$'\n'
	done
else
	scalewayFragment="${MMDAPP:-}/.claude/copilot-add-dir.fragment"
	if [ -f "$scalewayFragment" ] ; then
		while IFS= read -r scalewayLine ; do
			[ -n "$scalewayLine" ] || continue
			case "$scalewayLine" in
				--add-dir)
					## Old two-line format's own flag marker; the next line is
					## the bare untagged path, handled by the `/*` arm below.
					continue
				;;
				own$'\t'/*|explicit$'\t'/*)
					scalewayRoots="${scalewayRoots}${scalewayLine#*$'\t'}"$'\n'
				;;
				wildcard$'\t'/*)
					scalewayWildcardPath="${scalewayLine#*$'\t'}"
					[ ! -d "$scalewayWildcardPath" ] || scalewayRoots="${scalewayRoots}${scalewayWildcardPath}"$'\n'
				;;
				/*)
					[ ! -d "$scalewayLine" ] || scalewayRoots="${scalewayRoots}${scalewayLine}"$'\n'
				;;
			esac
		done < "$scalewayFragment"
	fi
fi
if [ -z "$scalewayRoots" ] ; then
	echo "${scalewayBad}⛔ ERROR:${scalewayOff} AgentsScalewayHarness.sh: no access roots resolved -- refusing to run a tool-calling agent with nowhere it may touch. Pass --access-root, or run this inside a workspace whose .claude/copilot-add-dir.fragment already exists (DistroAgentsTools --make-workspace-integrations)." >&2
	exit 1
fi

scalewayScratch="$( mktemp -d -t "AgentsScalewayHarness-XXXXXXXX" )" || {
	echo "${scalewayBad}⛔ ERROR:${scalewayOff} AgentsScalewayHarness.sh: could not create a scratch directory" >&2
	exit 1
}
trap 'rm -rf -- "$scalewayScratch"' EXIT

## Absolute paths only, no `..` segment, prefix-matched against the resolved
## roots. Does not resolve symlinks inside the path -- an allowed root
## containing a symlink to outside itself is not defended against, the same
## trust level copilot's own --add-dir carries. See MAGIC.md.
AgentsScalewayPathAllowed(){
	local checkPath="$1" checkRoot
	case "$checkPath" in
		/*) ;;
		*) return 1 ;;
	esac
	case "/$checkPath/" in
		*/../*|*/./*) return 1 ;;
	esac
	while IFS= read -r checkRoot ; do
		[ -n "$checkRoot" ] || continue
		case "$checkPath" in
			"$checkRoot"|"$checkRoot"/*) return 0 ;;
		esac
	done <<< "$scalewayRoots"
	return 1
}

AgentsScalewayToolReadFile(){
	local toolPath="$1" toolBytes
	if ! AgentsScalewayPathAllowed "$toolPath" ; then
		printf 'ERROR: path not in the allowed access-root set: %s\n' "$toolPath" ; return 0
	fi
	if [ ! -f "$toolPath" ] ; then
		printf 'ERROR: no such file: %s\n' "$toolPath" ; return 0
	fi
	## Capped and said so, never silently -- a non-streaming request already
	## buffers the whole body, and an unbounded read risks the request itself.
	toolBytes="$( wc -c < "$toolPath" | tr -d ' ' )"
	if [ "$toolBytes" -gt 200000 ] ; then
		head -c 200000 "$toolPath"
		printf '\n... TRUNCATED at 200000 of %s bytes ...\n' "$toolBytes"
	else
		cat "$toolPath"
	fi
}

## Whole-file overwrite/create, never a partial patch -- this harness offers no
## diff/edit primitive of its own to reuse (AgentsBoardItemPatchApply.py is a
## different, board-item-specific grammar), so "edit" means the model reads the
## file first and writes the complete new content back. See MAGIC.md.
AgentsScalewayToolWriteFile(){
	local toolPath="$1" toolContent="$2" toolTemp
	if ! AgentsScalewayPathAllowed "$toolPath" ; then
		printf 'ERROR: path not in the allowed access-root set: %s\n' "$toolPath" ; return 0
	fi
	mkdir -p "$( dirname -- "$toolPath" )" 2>/dev/null || {
		printf 'ERROR: could not create the parent directory of: %s\n' "$toolPath" ; return 0
	}
	## An existing file is overwritten in place, never through a temp+rename:
	## `mv -f` carries the temp's own default-umask mode onto the target,
	## silently widening a file that was deliberately not world/group-readable.
	if [ -e "$toolPath" ] ; then
		if ! printf '%s' "$toolContent" > "$toolPath" ; then
			printf 'ERROR: could not write: %s\n' "$toolPath" ; return 0
		fi
		printf 'OK: wrote %s\n' "$toolPath"
		return 0
	fi
	toolTemp="$toolPath.tmp.$$"
	if ! printf '%s' "$toolContent" > "$toolTemp" ; then
		printf 'ERROR: could not write: %s\n' "$toolPath" ; rm -f "$toolTemp" ; return 0
	fi
	if ! mv -f "$toolTemp" "$toolPath" ; then
		printf 'ERROR: could not install: %s\n' "$toolPath" ; rm -f "$toolTemp" ; return 0
	fi
	printf 'OK: wrote %s\n' "$toolPath"
}

AgentsScalewayToolListDir(){
	local toolPath="$1"
	if ! AgentsScalewayPathAllowed "$toolPath" ; then
		printf 'ERROR: path not in the allowed access-root set: %s\n' "$toolPath" ; return 0
	fi
	if [ ! -d "$toolPath" ] ; then
		printf 'ERROR: no such directory: %s\n' "$toolPath" ; return 0
	fi
	ls -la -- "$toolPath"
}

AgentsScalewayToolGrep(){
	local toolPattern="$1" toolPath="$2"
	if ! AgentsScalewayPathAllowed "$toolPath" ; then
		printf 'ERROR: path not in the allowed access-root set: %s\n' "$toolPath" ; return 0
	fi
	if [ ! -e "$toolPath" ] ; then
		printf 'ERROR: no such path: %s\n' "$toolPath" ; return 0
	fi
	## `head` is the pipeline's last command and always exits 0, so a
	## no-match grep (its own rc 1) never trips this script's own set -e.
	grep -rn -- "$toolPattern" "$toolPath" 2>&1 | head -c 100000
}

## No sandboxing beyond the cwd bound below -- matches copilot's own
## --allow-all-tools trust model, not a gap this version closes. Output goes
## to a scratch file rather than $( ... ): a model-supplied command is
## arbitrary and may background a child that holds a capture pipe open
## forever (see MAGIC.md's "Capturing an arbitrary command's output").
## Containment mirrors --intern-mcp-execute's own set -e/exit-status pattern.
AgentsScalewayToolRunCommand(){
	local toolCwd="$1" toolCommand="$2" toolStatus=0
	if ! AgentsScalewayPathAllowed "$toolCwd" ; then
		printf 'ERROR: cwd not in the allowed access-root set: %s\n' "$toolCwd" ; return 0
	fi
	if [ ! -d "$toolCwd" ] ; then
		printf 'ERROR: no such directory: %s\n' "$toolCwd" ; return 0
	fi
	( cd "$toolCwd" && set -e && eval "$toolCommand" ) > "$scalewayScratch/run.out" 2>&1 || toolStatus=$?
	head -c 100000 "$scalewayScratch/run.out"
	printf '(exit status %s)\n' "$toolStatus"
}

## One named argument out of a tool_call's own `function.arguments` string --
## itself a JSON document once unescaped, so the same field reader runs again
## on it rather than a second parser being written for it.
AgentsScalewayArgValue(){
	printf '%s\n' "$1" | LC_ALL=C awk -v path="$2" -v optional=1 -f "$scalewayHere/AgentsScalewayJsonField.awk" 2>/dev/null || :
}

## Progress-announce support -- one line, every C0 byte and DEL folded to a
## space, cut at 120 bytes on a UTF-8 character boundary. Cut and fold are the
## one shared primitive in AgentsProgressLineSafe.awk, which is where claude's
## own progress lines get them too -- see MAGIC.md. Unrelated to this version's
## own streaming-text echo below, which is a different feature with a different
## job (see the comment beside AgentsScalewayStreamEchoContent).
AgentsScalewayTruncateArg(){
	printf '%s' "$1" | LC_ALL=C awk -v progressLineCap=120 -f "$scalewayHere/AgentsProgressLineSafe.awk"
}

## Announced immediately BEFORE the tool call actually executes (not after)
## -- the point is knowing what is about to happen, especially for a
## run_command that might hang. One icon per action, so reading, writing,
## listing, searching and running stay apart at a glance; the round is the
## rule line above this, not repeated per call.
##
## Every value on this line -- the function name included, since that is model
## output too -- passes AgentsScalewayTruncateArg, so the only escapes reaching
## the terminal are the $scaleway* literals placed around them here.
AgentsScalewayAnnounceTool(){
	local announceFuncName="$1" announceArgsRaw="$2" announceIcon="❓" announceDetail=""
	case "$announceFuncName" in
		read_file)
			announceIcon="📖"
			announceDetail="$scalewayValue$( AgentsScalewayTruncateArg "$( AgentsScalewayArgValue "$announceArgsRaw" path )" )$scalewayOff"
		;;
		write_file)
			announceIcon="📝"
			announceDetail="$scalewayValue$( AgentsScalewayTruncateArg "$( AgentsScalewayArgValue "$announceArgsRaw" path )" )$scalewayOff"
		;;
		list_dir)
			announceIcon="📂"
			announceDetail="$scalewayValue$( AgentsScalewayTruncateArg "$( AgentsScalewayArgValue "$announceArgsRaw" path )" )$scalewayOff"
		;;
		grep)
			announceIcon="🔍"
			announceDetail="$scalewayValue$( AgentsScalewayTruncateArg "$( AgentsScalewayArgValue "$announceArgsRaw" pattern )" )$scalewayDim in $scalewayOff$scalewayValue$( AgentsScalewayTruncateArg "$( AgentsScalewayArgValue "$announceArgsRaw" path )" )$scalewayOff"
		;;
		run_command)
			announceIcon="💻"
			announceDetail="$scalewayValue$( AgentsScalewayTruncateArg "$( AgentsScalewayArgValue "$announceArgsRaw" command )" )$scalewayDim in $scalewayOff$scalewayValue$( AgentsScalewayTruncateArg "$( AgentsScalewayArgValue "$announceArgsRaw" cwd )" )$scalewayOff"
		;;
	esac
	printf '   %s %s%-11s%s %s\n' "$announceIcon" "$scalewayTool" "$( AgentsScalewayTruncateArg "$announceFuncName" )" "$scalewayOff" "$announceDetail" >&2
}

## One field required to be present on the CURRENT $scalewayResponse (a
## tool_calls entry's own id/name/arguments) -- a stated, loud failure in its
## place, never the bare `set -e` kill an unguarded `x="$( ... )"` assignment
## produces when the awk reader's own rc is non-zero (rc 3 absent, rc 1
## malformed) and nothing downstream tests it. For this streaming version,
## $scalewayResponse is a document THIS script itself synthesizes once a
## round's stream completes (see AgentsScalewayStreamRunRound below) rather
## than a body Scaleway sent directly -- but it is built to the exact same
## shape a real non-streaming response has, so this reader and everything
## that calls it needs no change at all.
AgentsScalewayResponseField(){
	local fieldPath="$1" fieldRc=0 fieldValue
	fieldValue="$( printf '%s\n' "$scalewayResponse" | LC_ALL=C awk -v path="$fieldPath" -v optional=1 -f "$scalewayHere/AgentsScalewayJsonField.awk" 2>/dev/null )" || fieldRc=$?
	if [ "$fieldRc" != "0" ] ; then
		echo "${scalewayBad}⛔ ERROR:${scalewayOff} AgentsScalewayHarness.sh: round $scalewayRound: response is missing required field '$fieldPath' (rc=$fieldRc) -- the model/API returned a tool_calls shape this harness cannot use" >&2
		exit 1
	fi
	printf '%s' "$fieldValue"
}

scalewayToolsJson='[
{"type":"function","function":{"name":"read_file","description":"Read a UTF-8 text file and return its content.","parameters":{"type":"object","properties":{"path":{"type":"string","description":"Absolute path to the file."}},"required":["path"]}}},
{"type":"function","function":{"name":"write_file","description":"Create or overwrite a UTF-8 text file with the given complete content. Always writes the whole file -- read it first with read_file, then write back the full new content, to make a partial edit.","parameters":{"type":"object","properties":{"path":{"type":"string","description":"Absolute path to the file."},"content":{"type":"string","description":"The complete new content of the file."}},"required":["path","content"]}}},
{"type":"function","function":{"name":"list_dir","description":"List the contents of a directory.","parameters":{"type":"object","properties":{"path":{"type":"string","description":"Absolute path to the directory."}},"required":["path"]}}},
{"type":"function","function":{"name":"grep","description":"Recursively search a file or directory for a pattern.","parameters":{"type":"object","properties":{"pattern":{"type":"string","description":"A basic regular expression, as grep(1) reads one."},"path":{"type":"string","description":"Absolute path to the file or directory to search."}},"required":["pattern","path"]}}},
{"type":"function","function":{"name":"run_command","description":"Run a shell command with the given working directory.","parameters":{"type":"object","properties":{"cwd":{"type":"string","description":"Absolute path of the working directory the command runs in."},"command":{"type":"string","description":"The shell command line to run."}},"required":["cwd","command"]}}}
]'

scalewaySystemTail=" (no sandboxing beyond the paths below). You may only read, write, list, search or run commands with a working directory under one of these access roots:
$scalewayRoots
Use the given tools to accomplish the request, then reply with a final plain-text message once done. Do not ask the user a question -- there is no one to answer it; make the most reasonable choice and state what you did."

## --agent given: the member's own real identity opens the system prompt,
## replacing the generic "autonomous coding agent" opener entirely, not
## alongside it -- one clear identity, not two. The full .armed.md is
## deliberately NOT inlined here (some run to roughly 48K tokens, the wrong
## tradeoff for a metered, max_tokens-capped cheap-tier model); the model is
## told to read_file it itself, on the same access grant that already lets it
## reach its own .basic.md (AgentsTools.ClientAccessRoots.include's
## member-access-root grant).
if [ -n "$scalewayAgent" ] ; then
	scalewaySystemText="$scalewayAgentBasicText

If this task needs duty-level detail beyond the above, read_file your own $scalewayAgentRealDir/$scalewayAgent.armed.md yourself -- it is not included here.

You are running through a bespoke Scaleway harness$scalewaySystemTail"
else
	scalewaySystemText="You are an autonomous coding agent running through a bespoke Scaleway harness$scalewaySystemTail"
fi

scalewayMessages=(
	'{"role":"system","content":"'"$( printf '%s' "$scalewaySystemText" | LC_ALL=C awk -f "$scalewayHere/AgentsMcpJsonEscape.awk" )"'"}'
	'{"role":"user","content":"'"$( printf '%s' "$scalewayPrompt" | LC_ALL=C awk -f "$scalewayHere/AgentsMcpJsonEscape.awk" )"'"}'
)

## A round cap, not an implicit "keep going until final text" -- an
## unbounded tool-call loop against a metered API is unbounded spend, the
## same class of defect the MCP wire handler's own "a spin loop whose counter
## resets after each sleep is a pacing counter, not a limit" note names.
## See DESIGN DECISION 2 above: a mid-stream disconnect retry never touches
## this counter.
scalewayRound=0
scalewayMaxRounds=25

## ---------------------------------------------------------------------
## Streaming consumption of one round. Reads SSE off stdin (the pipe from
## curl -- see the call site below) and, on a clean `[DONE]`, leaves the
## round's own $scalewayResponse set to a synthesized document matching the
## EXACT shape v1's non-streaming response has (`choices.0.message.content`,
## `choices.0.message.tool_calls.N.{id,function.name,function.arguments}`,
## `choices.0.message.tool_calls.__count`, `choices.0.finish_reason`) -- so
## everything after the call site below (error checks, the tool-count
## branch, the final-answer print, the assistant tool_calls history build,
## the dispatch loop) is v1's own code, unchanged, reading a document it
## cannot tell apart from a real one.
##
## Why a synthesized full-document round-trip rather than a second,
## streaming-shaped dispatch path: v1's downstream code is proven, and a
## second parallel implementation of tool-call dispatch is a second place
## for the same bug to be fixed once and missed the other time. Re-parsing
## our own JSON through the same awk reader costs one extra pass over a
## string already in memory -- trivial next to one network round trip.
##
## This function's own accumulator state lives in files under
## $scalewayScratch, not shell variables: `curl -N ... | while read` puts
## the while loop on the right of a pipe, which bash always runs as a
## subshell (no `lastpipe`, a bash-4.2+ feature outside this file's own
## bash-3.2 floor) -- any variable the loop body sets is gone the moment the
## pipeline ends. Files are the one channel that survives that boundary,
## and this is the genuinely-earned case for one: bridging data across a
## subshell this script's own pipe structure requires, not a substitute for
## a variable that would have worked fine on its own.
AgentsScalewayStreamConsume(){
	local line payload deltaContent deltaToolCount tcIdx tcIndexField tcId tcName tcArgsFrag finishReason tcSeen
	: > "$scalewayScratch/stream.content"
	while IFS= read -r line ; do
		line="${line%$'\r'}"
		case "$line" in
			"")
				: ## SSE event separator
			;;
			:*|event:*|id:*|retry:*)
				: ## SSE comment/heartbeat or a named field this API doesn't use
			;;
			"data: "*)
				payload="${line#data: }"
				if [ "$payload" = "[DONE]" ] ; then
					: > "$scalewayScratch/stream.done"
					continue
				fi

				deltaContent="$( printf '%s\n' "$payload" | LC_ALL=C awk -v path=choices.0.delta.content -v optional=1 -v sentinel=1 -f "$scalewayHere/AgentsScalewayJsonField.awk" 2>/dev/null )" || :
				deltaContent="${deltaContent%X}"
				if [ -n "$deltaContent" ] ; then
					printf '%s' "$deltaContent" >> "$scalewayScratch/stream.content"
					## Live text echo -- the actual payoff of streaming. Bare,
					## undecorated, no per-chunk prefix: this is flowing prose,
					## not a discrete event like a tool-call announce, and a
					## repeated "# AgentsScalewayHarness.sh: ..." stamp on
					## every few characters would break it into an unreadable
					## wall of prefixes instead of readable running text. Not
					## routed through AgentsScalewayTruncateArg -- that helper
					## is sized for a single tool-call argument value (120
					## chars, collapsed to one line), the wrong shape entirely
					## for streamed prose that is meant to keep flowing. The
					## three bytes that can move a terminal's cursor -- ESC, CR
					## and BS -- are dropped here, in-expansion and fork-free,
					## so prose cannot forge this harness's own chrome; \n and
					## \t survive because prose is made of them, and the
					## accumulated copy above keeps every byte either way.
					printf '%s' "${deltaContent//[$'\033'$'\r'$'\b']/ }" >&2
				fi

				finishReason="$( printf '%s\n' "$payload" | LC_ALL=C awk -v path=choices.0.finish_reason -v optional=1 -f "$scalewayHere/AgentsScalewayJsonField.awk" 2>/dev/null )" || :
				[ -z "$finishReason" ] || printf '%s' "$finishReason" > "$scalewayScratch/stream.finish_reason"

				deltaToolCount="$( printf '%s\n' "$payload" | LC_ALL=C awk -v path=choices.0.delta.tool_calls.__count -v optional=1 -f "$scalewayHere/AgentsScalewayJsonField.awk" 2>/dev/null )" || deltaToolCount=0
				[ -n "$deltaToolCount" ] || deltaToolCount=0
				tcIdx=0
				while [ "$tcIdx" -lt "$deltaToolCount" ] 2>/dev/null ; do
					tcIndexField="$( printf '%s\n' "$payload" | LC_ALL=C awk -v path="choices.0.delta.tool_calls.$tcIdx.index" -v optional=1 -f "$scalewayHere/AgentsScalewayJsonField.awk" 2>/dev/null )" || :
					[ -n "$tcIndexField" ] || tcIndexField="$tcIdx"
					tcId="$( printf '%s\n' "$payload" | LC_ALL=C awk -v path="choices.0.delta.tool_calls.$tcIdx.id" -v optional=1 -f "$scalewayHere/AgentsScalewayJsonField.awk" 2>/dev/null )" || :
					tcName="$( printf '%s\n' "$payload" | LC_ALL=C awk -v path="choices.0.delta.tool_calls.$tcIdx.function.name" -v optional=1 -f "$scalewayHere/AgentsScalewayJsonField.awk" 2>/dev/null )" || :
					tcArgsFrag="$( printf '%s\n' "$payload" | LC_ALL=C awk -v path="choices.0.delta.tool_calls.$tcIdx.function.arguments" -v optional=1 -v sentinel=1 -f "$scalewayHere/AgentsScalewayJsonField.awk" 2>/dev/null )" || :
					tcArgsFrag="${tcArgsFrag%X}"

					[ -z "$tcId" ] || printf '%s' "$tcId" > "$scalewayScratch/stream.tool.$tcIndexField.id"
					[ -z "$tcName" ] || printf '%s' "$tcName" > "$scalewayScratch/stream.tool.$tcIndexField.name"
					[ -z "$tcArgsFrag" ] || printf '%s' "$tcArgsFrag" >> "$scalewayScratch/stream.tool.$tcIndexField.args"

					tcSeen="$( cat "$scalewayScratch/stream.tool.count" 2>/dev/null )" || tcSeen=0
					[ -n "$tcSeen" ] || tcSeen=0
					if [ "$tcIndexField" -ge "$tcSeen" ] 2>/dev/null ; then
						printf '%s' "$(( tcIndexField + 1 ))" > "$scalewayScratch/stream.tool.count"
					fi

					tcIdx=$(( tcIdx + 1 ))
				done
			;;
			*)
				## Not an SSE line shape at all -- most likely the WHOLE
				## response is a plain, non-streaming JSON error body.
				## Scaleway returns its flat {"status":n,"error":"CODE",
				## "message":"..."} shape with no SSE framing at all when a
				## request is rejected before any generation begins, even
				## though "stream":true was requested. Accumulated verbatim
				## so the call site can hand it to v1's own, unchanged,
				## error-parsing path.
				printf '%s\n' "$line" >> "$scalewayScratch/stream.rawother"
			;;
		esac
	done
}

while : ; do
	scalewayRound=$(( scalewayRound + 1 ))
	if [ "$scalewayRound" -gt "$scalewayMaxRounds" ] ; then
		echo "${scalewayBad}⛔ ERROR:${scalewayOff} AgentsScalewayHarness.sh: stopped after $scalewayMaxRounds request rounds with no final answer -- refusing to keep spending against a metered API on a conversation that has not converged" >&2
		exit 1
	fi

	## Where one round ends and the next begins, for a human watching prose and
	## tool calls scroll past for minutes at a time. Braces are load-bearing:
	## bash 3.2 reads the first byte of an abutting UTF-8 character as part of
	## an unbraced name, so `$scalewayDim──` expands to nothing and eats a byte.
	printf '%s\n' "${scalewayDim}── round $scalewayRound ─────────────────────────────────${scalewayOff}" >&2

	scalewayMessagesJson="$( IFS=, ; echo "[${scalewayMessages[*]}]" )"
	scalewayBody='{"model":"'"$scalewayModel"'","messages":'"$scalewayMessagesJson"',"tools":'"$scalewayToolsJson"',"tool_choice":"auto","max_tokens":8192,"stream":true'
	[ -z "$scalewayReasoningEffort" ] || scalewayBody="$scalewayBody"',"reasoning_effort":"'"$scalewayReasoningEffort"'"'
	scalewayBody="$scalewayBody"'}'

	## Token on curl's stdin, never argv -- the exact pattern
	## AgentsTools.CommsSlack.include already proves for Slack.
	scalewayAuthHeader="Authorization: Bearer $scalewayToken"

	## One round's worth of streaming attempts. See DESIGN DECISION 1/2 above
	## the round loop: every attempt starts from a clean accumulator (a
	## disconnect discards whatever arrived and the whole round is re-sent),
	## and a retry here never touches $scalewayRound above.
	scalewayStreamAttempt=0
	scalewayStreamMaxAttempts=3
	scalewayStreamOk=0
	while [ "$scalewayStreamAttempt" -lt "$scalewayStreamMaxAttempts" ] ; do
		scalewayStreamAttempt=$(( scalewayStreamAttempt + 1 ))
		rm -f "$scalewayScratch"/stream.* 2>/dev/null
		: > "$scalewayScratch/stream.content"

		## curl -N (--no-buffer) piped directly into the read loop, nothing
		## else in that pipe -- a `grep`/`sed`/`jq` stage in between would
		## reintroduce full block buffering and defeat real-time delivery.
		## --max-time is deliberately absent: a flat cap is wrong once total
		## generation time can legitimately run past it (heavy tier, a slow
		## but alive stream). --speed-limit/--speed-time is a STALL detector
		## instead -- abort only once throughput has been near zero for a
		## sustained window (45s; long enough that a heavy-reasoning model's
		## own thinking pause before its next chunk is not mistaken for a
		## dead connection, short enough that a genuinely dead connection
		## does not hang the whole harness indefinitely). --connect-timeout
		## is unrelated and kept from v1 unchanged -- it only bounds the
		## initial TCP+TLS handshake.
		##
		## `set +e` / `set -e` bracket exactly this one statement: once curl
		## is the left side of a pipe, `$?` after it reports the while loop's
		## own exit status, not curl's -- `${PIPESTATUS[0]}`, captured on the
		## very next line before anything else runs, is curl's real exit
		## status. v1's own `curl ... || { ...; exit 1; }` idiom cannot
		## survive that change as-is, hence the explicit toggle here instead.
		set +e
		curl -N -sS --connect-timeout 10 --speed-limit 1 --speed-time 45 -X POST https://api.scaleway.ai/v1/chat/completions \
			-H @- \
			-H "Content-type: application/json" \
			-d "$scalewayBody" <<< "$scalewayAuthHeader" 2>"$scalewayScratch/stream.curlerr" \
			| AgentsScalewayStreamConsume
		scalewayCurlRc="${PIPESTATUS[0]}"
		set -e

		if [ "$scalewayCurlRc" = "0" ] && [ -f "$scalewayScratch/stream.done" ] ; then
			scalewayStreamOk=1
			break
		fi

		if [ -s "$scalewayScratch/stream.rawother" ] && [ ! -f "$scalewayScratch/stream.done" ] ; then
			## A complete, non-streaming (error) body, not a disconnect --
			## handled below through v1's own unchanged error path, no retry.
			break
		fi

		echo "${scalewayWarn}🔁 RETRY:${scalewayOff} stream attempt $scalewayStreamAttempt/$scalewayStreamMaxAttempts disconnected mid-stream (curl rc=$scalewayCurlRc$( [ ! -s "$scalewayScratch/stream.curlerr" ] || printf ': %s' "$( cat "$scalewayScratch/stream.curlerr" )" )) -- discarding partial output and retrying the whole round" >&2
	done

	## Any accumulated live text this round ended without a trailing
	## newline of its own -- give stderr a clean line break before the next
	## thing (a tool announce, or nothing further this round) prints.
	[ ! -s "$scalewayScratch/stream.content" ] || printf '\n' >&2

	if [ "$scalewayStreamOk" != "1" ] && [ ! -s "$scalewayScratch/stream.rawother" ] ; then
		echo "${scalewayBad}⛔ ERROR:${scalewayOff} AgentsScalewayHarness.sh: round $scalewayRound: gave up after $scalewayStreamMaxAttempts stream attempts, none reached a clean [DONE] (see DESIGN DECISION 1: a partial stream is always discarded, never spliced) -- last curl rc=$scalewayCurlRc" >&2
		exit 1
	fi

	if [ -s "$scalewayScratch/stream.rawother" ] ; then
		## Non-streaming error body path -- fed to v1's own unchanged
		## error/malformed-JSON checks below exactly as a real one would be.
		scalewayResponse="$( cat "$scalewayScratch/stream.rawother" )"
	else
		## Clean stream: synthesize the exact document shape v1's own
		## downstream code already expects, from this round's own
		## accumulated state.
		scalewayToolCount="$( cat "$scalewayScratch/stream.tool.count" 2>/dev/null )" || scalewayToolCount=0
		[ -n "$scalewayToolCount" ] || scalewayToolCount=0
		scalewayStreamFinishReason="$( cat "$scalewayScratch/stream.finish_reason" 2>/dev/null )"
		if [ "$scalewayToolCount" -gt 0 ] ; then
			[ -n "$scalewayStreamFinishReason" ] || scalewayStreamFinishReason="tool_calls"
			scalewaySynthToolCalls=""
			scalewaySynthIdx=0
			while [ "$scalewaySynthIdx" -lt "$scalewayToolCount" ] ; do
				scalewaySynthId="$( cat "$scalewayScratch/stream.tool.$scalewaySynthIdx.id" 2>/dev/null )"
				scalewaySynthName="$( cat "$scalewayScratch/stream.tool.$scalewaySynthIdx.name" 2>/dev/null )"
				scalewaySynthArgs="$( cat "$scalewayScratch/stream.tool.$scalewaySynthIdx.args" 2>/dev/null )"
				scalewaySynthIdEsc="$( printf '%s' "$scalewaySynthId" | LC_ALL=C awk -f "$scalewayHere/AgentsMcpJsonEscape.awk" )"
				scalewaySynthNameEsc="$( printf '%s' "$scalewaySynthName" | LC_ALL=C awk -f "$scalewayHere/AgentsMcpJsonEscape.awk" )"
				scalewaySynthArgsEsc="$( printf '%s' "$scalewaySynthArgs" | LC_ALL=C awk -f "$scalewayHere/AgentsMcpJsonEscape.awk" )"
				scalewaySynthToolCalls="${scalewaySynthToolCalls}${scalewaySynthToolCalls:+,}{\"id\":\"$scalewaySynthIdEsc\",\"type\":\"function\",\"function\":{\"name\":\"$scalewaySynthNameEsc\",\"arguments\":\"$scalewaySynthArgsEsc\"}}"
				scalewaySynthIdx=$(( scalewaySynthIdx + 1 ))
			done
			scalewayResponse='{"choices":[{"index":0,"message":{"role":"assistant","content":null,"tool_calls":['"$scalewaySynthToolCalls"']},"finish_reason":"'"$scalewayStreamFinishReason"'"}]}'
		else
			[ -n "$scalewayStreamFinishReason" ] || scalewayStreamFinishReason="stop"
			scalewayStreamContent="$( cat "$scalewayScratch/stream.content" 2>/dev/null )"
			scalewayStreamContentEsc="$( printf '%s' "$scalewayStreamContent" | LC_ALL=C awk -f "$scalewayHere/AgentsMcpJsonEscape.awk" )"
			scalewayResponse='{"choices":[{"index":0,"message":{"role":"assistant","content":"'"$scalewayStreamContentEsc"'"},"finish_reason":"'"$scalewayStreamFinishReason"'"}]}'
		fi
	fi

	## ---------------------------------------------------------------------
	## Everything from here to the end of this round is v1's own code,
	## unchanged: the error/malformed-JSON checks, the tool-count branch,
	## the final-answer print, the assistant tool_calls history build, and
	## the dispatch loop. All of it reads $scalewayResponse, which above is
	## now either a real non-streaming error body or this round's own
	## synthesized document -- either way, a document this code cannot tell
	## apart from what v1 itself would have received directly from curl.

	## The response body decides success or failure, never curl's own exit
	## status -- curl succeeds transport-wise on a 4xx/5xx JSON error body.
	## Scaleway's own error shape is flat: {"status":n,"error":"CODE","message":"..."},
	## nothing like Slack's ok:false or OpenAI's nested error object.
	scalewayErrorRc=0
	scalewayErrorCode="$( printf '%s\n' "$scalewayResponse" | LC_ALL=C awk -v path=error -v optional=1 -f "$scalewayHere/AgentsScalewayJsonField.awk" 2>/dev/null )" || scalewayErrorRc=$?
	if [ "$scalewayErrorRc" = "0" ] ; then
		scalewayErrorDetail="$( AgentsScalewayArgValue "$scalewayResponse" message )"
		echo "${scalewayBad}⛔ ERROR:${scalewayOff} AgentsScalewayHarness.sh: api.scaleway.ai refused the request -- $scalewayErrorCode: ${scalewayErrorDetail:-<no message>}" >&2
		exit 1
	elif [ "$scalewayErrorRc" != "3" ] ; then
		echo "${scalewayBad}⛔ ERROR:${scalewayOff} AgentsScalewayHarness.sh: response was not a parseable JSON object (rc=$scalewayErrorRc): $scalewayResponse" >&2
		exit 1
	fi

	scalewayToolCountRc=0
	scalewayToolCount="$( printf '%s\n' "$scalewayResponse" | LC_ALL=C awk -v path=choices.0.message.tool_calls.__count -v optional=1 -f "$scalewayHere/AgentsScalewayJsonField.awk" 2>/dev/null )" || scalewayToolCountRc=$?
	[ "$scalewayToolCountRc" = "0" ] || scalewayToolCount=0

	if [ "$scalewayToolCount" -eq 0 ] 2>/dev/null ; then
		scalewayFinal="$( printf '%s\n' "$scalewayResponse" | LC_ALL=C awk -v path=choices.0.message.content -v optional=1 -v sentinel=1 -f "$scalewayHere/AgentsScalewayJsonField.awk" 2>/dev/null )" || :
		scalewayFinal="${scalewayFinal%X}"
		if [ -z "$scalewayFinal" ] ; then
			scalewayFinishReason="$( AgentsScalewayArgValue "$scalewayResponse" choices.0.finish_reason )"
			echo "${scalewayBad}⛔ ERROR:${scalewayOff} AgentsScalewayHarness.sh: no tool call and no final content came back (finish_reason=${scalewayFinishReason:-<none>}) -- refusing to print an empty answer as if it were one" >&2
			exit 1
		fi
		printf '%s\n' "$scalewayFinal"
		exit 0
	fi

	## The assistant's own tool_calls message goes into history verbatim
	## first -- the API's own required shape for a multi-turn tool exchange --
	## reconstructed from the same scalar fields this reader already pulls
	## out, since only a scalar leaf is addressable and the whole sub-object
	## cannot be re-extracted raw.
	scalewayToolCallsJson=""
	scalewayIndex=0
	while [ "$scalewayIndex" -lt "$scalewayToolCount" ] ; do
		scalewayCallId="$( AgentsScalewayResponseField "choices.0.message.tool_calls.$scalewayIndex.id" )"
		scalewayFuncName="$( AgentsScalewayResponseField "choices.0.message.tool_calls.$scalewayIndex.function.name" )"
		scalewayFuncArgsRaw="$( AgentsScalewayResponseField "choices.0.message.tool_calls.$scalewayIndex.function.arguments" )"
		## id and name go back into JSON this loop sends next round, exactly
		## like arguments/content below -- an OpenAI tool_call id/name is not
		## guaranteed free of `"`/`\` (confirmed: a valid, well-formed response
		## can carry either), and reusing either unescaped corrupts the next
		## request's own JSON rather than merely mis-rendering free text.
		scalewayCallIdEsc="$( printf '%s' "$scalewayCallId" | LC_ALL=C awk -f "$scalewayHere/AgentsMcpJsonEscape.awk" )"
		scalewayFuncNameEsc="$( printf '%s' "$scalewayFuncName" | LC_ALL=C awk -f "$scalewayHere/AgentsMcpJsonEscape.awk" )"
		scalewayFuncArgsEsc="$( printf '%s' "$scalewayFuncArgsRaw" | LC_ALL=C awk -f "$scalewayHere/AgentsMcpJsonEscape.awk" )"
		scalewayToolCallsJson="${scalewayToolCallsJson}${scalewayToolCallsJson:+,}{\"id\":\"$scalewayCallIdEsc\",\"type\":\"function\",\"function\":{\"name\":\"$scalewayFuncNameEsc\",\"arguments\":\"$scalewayFuncArgsEsc\"}}"
		scalewayIndex=$(( scalewayIndex + 1 ))
	done
	scalewayMessages+=( '{"role":"assistant","content":null,"tool_calls":['"$scalewayToolCallsJson"']}' )

	## Then one role:tool result per call, keyed by that exact tool_call_id --
	## passed through verbatim, never re-derived, matching the same discipline
	## the Slack target grammar applies to a conversation id.
	scalewayIndex=0
	while [ "$scalewayIndex" -lt "$scalewayToolCount" ] ; do
		scalewayCallId="$( AgentsScalewayResponseField "choices.0.message.tool_calls.$scalewayIndex.id" )"
		scalewayFuncName="$( AgentsScalewayResponseField "choices.0.message.tool_calls.$scalewayIndex.function.name" )"
		scalewayFuncArgsRaw="$( AgentsScalewayResponseField "choices.0.message.tool_calls.$scalewayIndex.function.arguments" )"

		AgentsScalewayAnnounceTool "$scalewayFuncName" "$scalewayFuncArgsRaw"

		case "$scalewayFuncName" in
			read_file)   scalewayResult="$( AgentsScalewayToolReadFile "$( AgentsScalewayArgValue "$scalewayFuncArgsRaw" path )" )" ;;
			write_file)  scalewayResult="$( AgentsScalewayToolWriteFile "$( AgentsScalewayArgValue "$scalewayFuncArgsRaw" path )" "$( AgentsScalewayArgValue "$scalewayFuncArgsRaw" content )" )" ;;
			list_dir)    scalewayResult="$( AgentsScalewayToolListDir "$( AgentsScalewayArgValue "$scalewayFuncArgsRaw" path )" )" ;;
			grep)        scalewayResult="$( AgentsScalewayToolGrep "$( AgentsScalewayArgValue "$scalewayFuncArgsRaw" pattern )" "$( AgentsScalewayArgValue "$scalewayFuncArgsRaw" path )" )" ;;
			run_command) scalewayResult="$( AgentsScalewayToolRunCommand "$( AgentsScalewayArgValue "$scalewayFuncArgsRaw" cwd )" "$( AgentsScalewayArgValue "$scalewayFuncArgsRaw" command )" )" ;;
			*)           scalewayResult="ERROR: unknown tool: $scalewayFuncName" ;;
		esac

		## tool_call_id is echoed back verbatim, JSON-escaped for the same
		## reason the assistant-history copy above now is.
		scalewayCallIdEsc="$( printf '%s' "$scalewayCallId" | LC_ALL=C awk -f "$scalewayHere/AgentsMcpJsonEscape.awk" )"
		scalewayResultEsc="$( printf '%s' "$scalewayResult" | LC_ALL=C awk -f "$scalewayHere/AgentsMcpJsonEscape.awk" )"
		scalewayMessages+=( '{"role":"tool","tool_call_id":"'"$scalewayCallIdEsc"'","content":"'"$scalewayResultEsc"'"}' )
		scalewayIndex=$(( scalewayIndex + 1 ))
	done
done
