#!/usr/bin/env bash
set -e

## AgentsScalewayHarness.sh -- the tool-calling harness for Scaleway's
## Serverless Generative APIs. No real `scaleway` binary exists, so this
## script IS the CLI: it runs the whole request/tool-call/response loop
## itself. Standalone and self-contained -- see MAGIC.md for the full design.

scalewayHere="$( cd "$( dirname -- "$0" )" && pwd )"

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
					echo "⛔ ERROR: AgentsScalewayHarness.sh: --tier must be light, normal or heavy, got: ${2:-<none>}" >&2
					exit 1
				;;
			esac
			shift 2
		;;
		--access-root)
			if [ -z "${2:-}" ] ; then
				echo "⛔ ERROR: AgentsScalewayHarness.sh: --access-root: value required" >&2
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
				echo "⛔ ERROR: AgentsScalewayHarness.sh: --session-id: value required" >&2
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
					echo "⛔ ERROR: AgentsScalewayHarness.sh: --agent is not a bare member name: ${2:-<none>}" >&2
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
						echo "⛔ ERROR: AgentsScalewayHarness.sh: --agent is not a bare member name: ${2:-<none>}" >&2
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
	echo "# AgentsScalewayHarness.sh: session-id: $scalewaySessionId" >&2
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
		echo "⛔ ERROR: AgentsScalewayHarness.sh: --agent $scalewayAgent: no such file, or unreadable: ${MDAT_SKILLSET_ROOT:-<MDAT_SKILLSET_ROOT unset>}/$scalewayAgent/$scalewayAgent.basic.md" >&2
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
	echo "⛔ ERROR: AgentsScalewayHarness.sh: no prompt given -- pass it as trailing argv, or on stdin" >&2
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
	echo "⛔ ERROR: AgentsScalewayHarness.sh: neither SCALEWAY_DEEPSEEK nor SCALEWAY_GEMMA is set in this process's own environment -- scaleway reads these names itself, exactly as claude reads ANTHROPIC_API_KEY" >&2
	exit 1
fi

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
## provenance. The first cut of this parser had only the two tagged-line
## arms and silently resolved to NO roots at all against an untagged
## fragment -- a fragment shape that turned out to already exist live, not a
## hypothetical -- which made every spawn in such a workspace refuse with
## "no access roots resolved" despite the workspace being fully set up for
## claude/copilot. Fixed to parse the identical four shapes the template does.
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
	echo "⛔ ERROR: AgentsScalewayHarness.sh: no access roots resolved -- refusing to run a tool-calling agent with nowhere it may touch. Pass --access-root, or run this inside a workspace whose .claude/copilot-add-dir.fragment already exists (DistroAgentsTools --make-workspace-integrations)." >&2
	exit 1
fi

scalewayScratch="$( mktemp -d -t "AgentsScalewayHarness-XXXXXXXX" )" || {
	echo "⛔ ERROR: AgentsScalewayHarness.sh: could not create a scratch directory" >&2
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

## Whole-file overwrite/create, never a partial patch -- v1 offers no diff/edit
## primitive of its own to reuse (AgentsBoardItemPatchApply.py is a different,
## board-item-specific grammar), so "edit" means the model reads the file
## first and writes the complete new content back. See MAGIC.md.
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

## One field required to be present on the CURRENT $scalewayResponse (a
## tool_calls entry's own id/name/arguments) -- a stated, loud failure in its
## place, never the bare `set -e` kill an unguarded `x="$( ... )"` assignment
## produces when the awk reader's own rc is non-zero (rc 3 absent, rc 1
## malformed) and nothing downstream tests it. A response shape missing one
## of these is exactly "a model/API returns garbage instead of valid
## tool_calls JSON" -- this makes that a diagnosed exit 1, not a silent one.
AgentsScalewayResponseField(){
	local fieldPath="$1" fieldRc=0 fieldValue
	fieldValue="$( printf '%s\n' "$scalewayResponse" | LC_ALL=C awk -v path="$fieldPath" -v optional=1 -f "$scalewayHere/AgentsScalewayJsonField.awk" 2>/dev/null )" || fieldRc=$?
	if [ "$fieldRc" != "0" ] ; then
		echo "⛔ ERROR: AgentsScalewayHarness.sh: round $scalewayRound: response is missing required field '$fieldPath' (rc=$fieldRc) -- the model/API returned a tool_calls shape this harness cannot use" >&2
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
scalewayRound=0
scalewayMaxRounds=25

while : ; do
	scalewayRound=$(( scalewayRound + 1 ))
	if [ "$scalewayRound" -gt "$scalewayMaxRounds" ] ; then
		echo "⛔ ERROR: AgentsScalewayHarness.sh: stopped after $scalewayMaxRounds request rounds with no final answer -- refusing to keep spending against a metered API on a conversation that has not converged" >&2
		exit 1
	fi

	scalewayMessagesJson="$( IFS=, ; echo "[${scalewayMessages[*]}]" )"
	scalewayBody='{"model":"'"$scalewayModel"'","messages":'"$scalewayMessagesJson"',"tools":'"$scalewayToolsJson"',"tool_choice":"auto","max_tokens":8192'
	[ -z "$scalewayReasoningEffort" ] || scalewayBody="$scalewayBody"',"reasoning_effort":"'"$scalewayReasoningEffort"'"'
	scalewayBody="$scalewayBody"'}'

	## Token on curl's stdin, never argv -- the exact pattern
	## AgentsTools.CommsSlack.include already proves for Slack.
	scalewayAuthHeader="Authorization: Bearer $scalewayToken"
	scalewayResponse="$( curl -sS --connect-timeout 10 --max-time 120 -X POST https://api.scaleway.ai/v1/chat/completions \
		-H @- \
		-H "Content-type: application/json" \
		-d "$scalewayBody" <<< "$scalewayAuthHeader" 2>&1 )" || {
		echo "⛔ ERROR: AgentsScalewayHarness.sh: transport failure calling api.scaleway.ai: $scalewayResponse" >&2
		exit 1
	}

	## The response body decides success or failure, never curl's own exit
	## status -- curl succeeds transport-wise on a 4xx/5xx JSON error body.
	## Scaleway's own error shape is flat: {"status":n,"error":"CODE","message":"..."},
	## nothing like Slack's ok:false or OpenAI's nested error object.
	scalewayErrorRc=0
	scalewayErrorCode="$( printf '%s\n' "$scalewayResponse" | LC_ALL=C awk -v path=error -v optional=1 -f "$scalewayHere/AgentsScalewayJsonField.awk" 2>/dev/null )" || scalewayErrorRc=$?
	if [ "$scalewayErrorRc" = "0" ] ; then
		scalewayErrorDetail="$( AgentsScalewayArgValue "$scalewayResponse" message )"
		echo "⛔ ERROR: AgentsScalewayHarness.sh: api.scaleway.ai refused the request -- $scalewayErrorCode: ${scalewayErrorDetail:-<no message>}" >&2
		exit 1
	elif [ "$scalewayErrorRc" != "3" ] ; then
		echo "⛔ ERROR: AgentsScalewayHarness.sh: response was not a parseable JSON object (rc=$scalewayErrorRc): $scalewayResponse" >&2
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
			echo "⛔ ERROR: AgentsScalewayHarness.sh: no tool call and no final content came back (finish_reason=${scalewayFinishReason:-<none>}) -- refusing to print an empty answer as if it were one" >&2
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
