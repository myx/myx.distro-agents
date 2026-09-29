#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only

## AgentsHarnessMcpClient.sh -- MCP server enumeration, declaration and calling for
## the universal harness. Sourced by AgentsUniversalHarness.sh and never executed:
## everything here runs in the core's process, exactly as AgentsHarnessHooks.sh does.
## THE TOOL SET IS DYNAMIC. AgentsHarnessMcpEnumerate runs as this file loads and the
## core runs it again before every round after the first, so $harnessMcpToolsJson is
## whatever the registrations and the servers declare at that round. A round whose
## enumeration matches the last one sends the same bytes. On the Anthropic wire `tools`
## is bound by every thinking block produced after it, so a set that changes mid-leg
## there is a 400 at replay (AgentsAnthropicStub.sh, constraint 3).
## A SERVER IS SPAWNED ONLY BECAUSE harnessMcpServers HOLDS IT -- named by --mcp-server,
## or else the workspace's own mcp.servers.json minus myx.distro, read again by the
## core's AgentsHarnessMcpServerSet on every enumeration.
## A run holding none starts no process, opens no file and leaves this file inert,
## which is also what keeps the offline checks offline.

## The same newline-delimited, TAB-separated shape harnessHooksList carries, so the
## per-call lookup stays builtins-only: server, tool, declared name, and the file
## holding that tool's own inputSchema as the server sent it.
harnessMcpCatalogue=""
## The sentence a named-but-unavailable server owes the model, placed in the system
## prompt: nothing else in the run says why a tool it expected is not there.
harnessMcpUnavailableNote=""
## This run's own declarations, each already preceded by its separating comma, so
## AgentsWireRequestBody concatenates it straight into the wire's own literal set.
harnessMcpToolsJson=""
harnessMcpConfigFile=""
harnessMcpConfigFault=""
## Published by AgentsHarnessMcpRun/AgentsHarnessMcpReply for their callers, the way
## the core's own AgentsHarnessPathAllowed publishes $harnessResolvedPath.
harnessMcpFault=""
harnessMcpStatus=0
harnessMcpDiag=""
harnessMcpReply=""

## Explicit character enumeration rather than a bracket range, which is
## collation-dependent: `[a-z]` matched "A" under one locale on this estate.
AgentsHarnessMcpNameOk(){ ## the name, then the punctuation this kind of name may carry
	local nameRest="$1" namePunct="$2" nameChar
	[ -n "$nameRest" ] || return 1
	while [ -n "$nameRest" ] ; do
		nameChar="${nameRest%"${nameRest#?}"}"
		nameRest="${nameRest#?}"
		case "$nameChar" in
			a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z) continue ;;
			A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z) continue ;;
			0|1|2|3|4|5|6|7|8|9) continue ;;
		esac
		case "$namePunct" in
			'') return 1 ;;
			*"$nameChar"*) ;;
			*) return 1 ;;
		esac
	done
}

## The document arrives on this function's own stdin, so one shape reads a file
## and a single response line alike.
AgentsHarnessMcpField(){ ## key path
	LC_ALL=C awk -v path="$1" -v optional=1 -f "$harnessHere/AgentsHarnessJsonField.awk"
}

## One shape for every way a named server fails to become tools: the operator is
## told on stderr, and the sentence the model is owed is built from that same
## reason rather than from a second wording that could disagree with it.
AgentsHarnessMcpDegrade(){ ## server name, reason
	printf '%s\n' "${harnessWarn}🔌 mcp${harnessOff} ${harnessValue}$1${harnessOff} ${harnessBad}unavailable${harnessOff} ${harnessDim}-- $2${harnessOff}" >&2
	harnessMcpUnavailableNote="${harnessMcpUnavailableNote}The MCP server \`$1\` was named for this run and is unavailable: $2. Nothing from it is available to you, so work with the built-in tools alone, and say in your answer that it was unavailable.
"
}

## Resolves the named server out of mcp.servers.json and runs it once against the request
## document already written to $harnessScratch/mcp.req, leaving its answers in
## $harnessScratch/mcp.out. One process per exchange, and its whole conversation is
## written before it starts: bash 3.2 has no way to hold a bidirectional stdio session
## open without mkfifo plus statically allocated descriptors. The server reads, answers
## the awaited id, and then reaches EOF, which is what ends it. Non-zero sets
## $harnessMcpFault to the reason. The bound comes from the caller rather than from one
## global: enumeration happens at spawn time before the member works and is held to
## seconds, while a tool call is a deliberate operation and keeps the run bound.
AgentsHarnessMcpRun(){ ## server name, wall-clock bound in whole seconds, awaited request id
	local runName="$1" runBound="$2" runWant="$3" runCommand runArgCount runArgIndex runArgValue runEnvKeys runEnvKey runEnvValue runRc=0 runPid runWatchPid
	local runArgs=() runEnv=()
	harnessMcpFault=""
	harnessMcpStatus=0
	harnessMcpDiag=""
	if [ -n "$harnessMcpConfigFault" ] ; then
		harnessMcpFault="$harnessMcpConfigFault"
		return 1
	fi
	## A name reaching a config key, a process argument and a filename below, and a name
	## that fails is dropped saying so -- never quietly rewritten to fit.
	if ! AgentsHarnessMcpNameOk "$runName" "_.-" ; then
		harnessMcpFault="that is not a bare server name -- letters, digits, underscore, dot and hyphen only"
		return 1
	fi

	runCommand="$( AgentsHarnessMcpField "mcpServers.$runName.command" < "$harnessMcpConfigFile" )" || runRc=$?
	if [ "$runRc" = "3" ] ; then
		harnessMcpFault="no such server under \`mcpServers\` in $harnessMcpConfigFile"
		return 1
	elif [ "$runRc" != "0" ] ; then
		harnessMcpFault="$harnessMcpConfigFile did not read as one JSON object (rc=$runRc)"
		return 1
	fi
	## Absolute only: it is handed to `env` after the assignments, where the leading `/`
	## is what guarantees it can never be read as one of them, and a relative command
	## would resolve against whatever this leg's cwd happens to be.
	case "$runCommand" in
		/*) ;;
		*)
			harnessMcpFault="its \`command\` is not an absolute path: $runCommand"
			return 1
		;;
	esac

	runRc=0
	runArgCount="$( AgentsHarnessMcpField "mcpServers.$runName.args.__count" < "$harnessMcpConfigFile" )" || runRc=$?
	if [ "$runRc" = "0" ] ; then
		runArgIndex=0
		while [ "$runArgIndex" -lt "$runArgCount" ] 2>/dev/null ; do
			runArgValue="$( AgentsHarnessMcpField "mcpServers.$runName.args.$runArgIndex" < "$harnessMcpConfigFile" )" || runArgValue=""
			runArgs+=( "$runArgValue" )
			runArgIndex=$(( runArgIndex + 1 ))
		done
	elif [ "$runRc" != "3" ] ; then
		harnessMcpFault="its \`args\` did not read as an array (rc=$runRc)"
		return 1
	fi

	## Credentials live here and reach the child's environment; nothing from `env`
	## ever reaches argv, where every process on the box could read it.
	runRc=0
	runEnvKeys="$( LC_ALL=C awk -v path="mcpServers.$runName.env" -v mode=keys -f "$harnessHere/AgentsHarnessJsonSlice.awk" < "$harnessMcpConfigFile" 2>/dev/null )" || runRc=$?
	if [ "$runRc" != "0" ] && [ "$runRc" != "3" ] ; then
		harnessMcpFault="its \`env\` did not read as an object (rc=$runRc)"
		return 1
	fi
	while IFS= read -r runEnvKey ; do
		[ -n "$runEnvKey" ] || continue
		if ! AgentsHarnessMcpNameOk "$runEnvKey" "_" ; then
			printf '%s\n' "${harnessWarn}🔌 mcp${harnessOff} ${harnessDim}$runName: dropped the \`env\` entry named ${harnessOff}${harnessValue}$runEnvKey${harnessOff}${harnessDim} -- an environment variable name carries letters, digits and underscore only${harnessOff}" >&2
			continue
		fi
		runEnvValue="$( AgentsHarnessMcpField "mcpServers.$runName.env.$runEnvKey" < "$harnessMcpConfigFile" )" || runEnvValue=""
		runEnv+=( "$runEnvKey=$runEnvValue" )
	done <<< "$runEnvKeys"

	## Answers go to a file, never through `$( )`: a capture returns on pipe-EOF rather
	## than on process exit, so one child the server leaves behind would hang this leg
	## for that child's whole lifetime.
	## stdin stays open until the awaited answer is in, or the server has gone: EOF is a
	## stdio server's signal to shut down, and one answering a call from a background
	## job -- myx.common's lib_execShStdin does -- exits on it with that answer unwritten.
	: > "$harnessScratch/mcp.out"
	: > "$harnessScratch/mcp.err"
	rm -f "$harnessScratch/mcp.timedout" "$harnessScratch/mcp.exited"
	{
		cat "$harnessScratch/mcp.req"
		while [ ! -f "$harnessScratch/mcp.exited" ] && ! AgentsHarnessMcpReply "$runWant" ; do
			sleep 1
		done
	} | {
		runRc=0
		## A bound of 0 is none, as it is for Bash.
		if [ "$runBound" = 0 ] ; then
			env "${runEnv[@]}" "$runCommand" "${runArgs[@]}" \
				> "$harnessScratch/mcp.out" 2>"$harnessScratch/mcp.err" || runRc=$?
		elif [ -n "$harnessTimeoutCmd" ] ; then
			env "${runEnv[@]}" "$harnessTimeoutCmd" "$runBound" "$runCommand" "${runArgs[@]}" \
				> "$harnessScratch/mcp.out" 2>"$harnessScratch/mcp.err" || runRc=$?
			[ "$runRc" != 124 ] || : > "$harnessScratch/mcp.timedout"
		else
			## Watchdog where no `timeout` exists, the shape AgentsHarnessToolBash uses.
			## `<&0` is load-bearing: a background job's stdin is otherwise /dev/null.
			{
				env "${runEnv[@]}" "$runCommand" "${runArgs[@]}" \
					<&0 > "$harnessScratch/mcp.out" 2>"$harnessScratch/mcp.err" &
				runPid=$!
				## The >/dev/null is load-bearing: without it the orphaned `sleep` holds
				## this block's own pipe open for the whole bound.
				( sleep "$runBound" ; kill -TERM "$runPid" 2>/dev/null && : > "$harnessScratch/mcp.timedout" ) >/dev/null &
				runWatchPid=$!
				wait "$runPid" || runRc=$?
				kill -TERM "$runWatchPid" 2>/dev/null || :
				wait "$runWatchPid" 2>/dev/null || :
			} 2>/dev/null
		fi
		printf '%s' "$runRc" > "$harnessScratch/mcp.exited"
	}
	read -r harnessMcpStatus < "$harnessScratch/mcp.exited" || :

	[ ! -s "$harnessScratch/mcp.err" ] || harnessMcpDiag="$( LC_ALL=C awk -v progressLineCap=200 -f "$harnessHere/AgentsProgressLineSafe.awk" < "$harnessScratch/mcp.err" )"

	if [ -f "$harnessScratch/mcp.timedout" ] ; then
		harnessMcpFault="it did not answer within $runBound seconds and was killed${harnessMcpDiag:+ (it said: $harnessMcpDiag)}"
		return 1
	fi
}

## The transport is one JSON object per line, so the answers are told apart by the
## request id they carry rather than by their position: a banner line, a notification
## and a log line each sit in this stream too. Publishes $harnessMcpReply.
AgentsHarnessMcpReply(){ ## request id
	local replyWant="$1" replyLine replyId
	harnessMcpReply=""
	while IFS= read -r replyLine ; do
		[ -n "$replyLine" ] || continue
		replyId="$( AgentsHarnessMcpField id <<< "$replyLine" 2>/dev/null )" || replyId=""
		[ "$replyId" != "$replyWant" ] || harnessMcpReply="$replyLine"
	done < "$harnessScratch/mcp.out"
	[ -n "$harnessMcpReply" ]
}

## The three lines every exchange opens with; only the last request differs.
AgentsHarnessMcpHandshake(){
	printf '%s\n' \
		'{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"AgentsUniversalHarness","version":"1"}}}' \
		'{"jsonrpc":"2.0","method":"notifications/initialized"}'
}

## The per-call path. Its whole contract is that it always prints a tool result: a
## server that dies mid-run, refuses, or answers unreadably becomes an `ERROR: ...`
## the model reads and the round carries on -- never a silent restart and never an
## exit. Named outside the AgentsHarnessTool* family on purpose: that family is the
## STATIC tool class AgentsHarnessSelfCheck.test.awk matches site by site, and a runtime
## tool has no declaration in the sources for it to match against.
AgentsHarnessMcpCall(){ ## declared name, raw arguments JSON
	local callName="$1" callArgs="$2" callServer="" callTool="" callRow callRc=0 callCount callIndex callType callText callOut=""
	while IFS= read -r callRow ; do
		case "$callRow" in
			*$'\t'"$callName"$'\t'*)
				callServer="${callRow%%$'\t'*}"
				callTool="${callRow#*$'\t'}"
				callTool="${callTool%%$'\t'*}"
			;;
		esac
	done <<< "$harnessMcpCatalogue"
	if [ -z "$callServer" ] ; then
		printf 'ERROR: unknown tool: %s -- no MCP server this run enumerated declares it\n' "$callName"
		return 0
	fi

	## A JSON-RPC request is one line, and a decoded `arguments` may carry real newlines
	## between its tokens; a newline inside a string literal is not legal JSON, so
	## replacing one with a space can never change a value.
	[ -n "$callArgs" ] || callArgs='{}'
	callArgs="${callArgs//$'\n'/ }"
	callArgs="${callArgs//$'\r'/ }"
	printf '%s' "$callArgs" | LC_ALL=C awk -v path=__probe__ -v mode=raw -f "$harnessHere/AgentsHarnessJsonSlice.awk" >/dev/null 2>&1 || callRc=$?
	## rc 0 found it, rc 3 parsed and it is absent -- both prove one JSON object.
	case "$callRc" in
		0|3) ;;
		*)
			printf 'ERROR: %s: the arguments were not one JSON object, so nothing was sent to the server\n' "$callName"
			return 0
		;;
	esac

	{
		AgentsHarnessMcpHandshake
		printf '%s\n' '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"'"$callTool"'","arguments":'"$callArgs"'}}'
	} > "$harnessScratch/mcp.req"
	if ! AgentsHarnessMcpRun "$callServer" "$harnessRunTimeout" 3 ; then
		printf 'ERROR: %s: the MCP server `%s` could not be run: %s\n' "$callName" "$callServer" "$harnessMcpFault"
		return 0
	fi
	if ! AgentsHarnessMcpReply 3 ; then
		printf 'ERROR: %s: the MCP server `%s` returned no answer to this call (exit status %s)%s\n' "$callName" "$callServer" "$harnessMcpStatus" "${harnessMcpDiag:+ -- it said: $harnessMcpDiag}"
		return 0
	fi
	printf '%s\n' "$harnessMcpReply" > "$harnessScratch/mcp.result"

	callRc=0
	callText="$( AgentsHarnessMcpField error.message < "$harnessScratch/mcp.result" )" || callRc=$?
	if [ "$callRc" = "0" ] ; then
		printf 'ERROR: %s: the MCP server `%s` refused the call: %s\n' "$callName" "$callServer" "$callText"
		return 0
	fi

	callRc=0
	callCount="$( AgentsHarnessMcpField result.content.__count < "$harnessScratch/mcp.result" )" || callRc=$?
	if [ "$callRc" != "0" ] ; then
		## No `content` array at all: hand back whatever `result` the server did write,
		## rather than reporting nothing about an answer it considers successful.
		callOut="$( LC_ALL=C awk -v path=result -v mode=raw -f "$harnessHere/AgentsHarnessJsonSlice.awk" < "$harnessScratch/mcp.result" 2>/dev/null )" || callOut=""
		[ -n "$callOut" ] || callOut="ERROR: $callName: the MCP server \`$callServer\` answered with neither a result nor an error this harness can read"
		printf '%s\n' "$callOut"
		return 0
	fi

	callIndex=0
	while [ "$callIndex" -lt "$callCount" ] 2>/dev/null ; do
		callRc=0
		callType="$( AgentsHarnessMcpField "result.content.$callIndex.type" < "$harnessScratch/mcp.result" )" || callType=""
		callText="$( AgentsHarnessMcpField "result.content.$callIndex.text" < "$harnessScratch/mcp.result" )" || callRc=$?
		if [ "$callRc" = "0" ] ; then
			callOut="$callOut$callText"$'\n'
		else
			callOut="$callOut[the server returned a ${callType:-nameless} content item this harness cannot render as text]"$'\n'
		fi
		callIndex=$(( callIndex + 1 ))
	done
	[ -n "$callOut" ] || callOut="(the MCP server returned no content)"$'\n'

	## `isError` is the server saying its own call failed, which the model must read as
	## a failure rather than as content.
	callRc=0
	callText="$( AgentsHarnessMcpField result.isError < "$harnessScratch/mcp.result" )" || callRc=$?
	if [ "$callRc" = "0" ] && [ "$callText" = "true" ] ; then
		printf 'ERROR: %s: the MCP server `%s` reported the call failed: %s' "$callName" "$callServer" "$callOut"
		return 0
	fi
	printf '%s' "$callOut"
}

## Enumerates the server set as it stands now and rebuilds the catalogue, the
## declarations and the unavailable note from nothing. Run once as this file loads and
## again by the core before every round after the first.
AgentsHarnessMcpEnumerate(){
	harnessMcpCatalogue=""
	harnessMcpUnavailableNote=""
	harnessMcpToolsJson=""
	harnessMcpConfigFile=""
	harnessMcpConfigFault=""
	AgentsHarnessMcpServerSet
	if [ "${#harnessMcpServers[@]}" -gt 0 ] ; then
		## Enumeration runs before the member does any work, and a healthy stdio server
		## answers `initialize` in milliseconds, so it is bounded in seconds rather than by
		## the run bound a deliberate tool call keeps. The 30 is the human-owner's chosen
		## value, so a later reader tuning it is changing a policy decision, not a guess.
		harnessMcpEnumTimeout="${MDAT_HARNESS_MCP_ENUM_TIMEOUT:-30}"
		## Whole seconds, by explicit enumeration rather than a collation-dependent range.
		harnessMcpEnumTimeoutRest="$harnessMcpEnumTimeout"
		while [ -n "$harnessMcpEnumTimeoutRest" ] ; do
			harnessMcpEnumTimeoutChar="${harnessMcpEnumTimeoutRest%"${harnessMcpEnumTimeoutRest#?}"}"
			harnessMcpEnumTimeoutRest="${harnessMcpEnumTimeoutRest#?}"
			case "$harnessMcpEnumTimeoutChar" in
				0|1|2|3|4|5|6|7|8|9) ;;
				*)
					echo "${harnessBad}⛔ ERROR:${harnessOff} $harnessSelfName: MDAT_HARNESS_MCP_ENUM_TIMEOUT must be whole seconds, got: $harnessMcpEnumTimeout" >&2
					exit 1
				;;
			esac
		done

		## Named servers and no configuration is not the inert case: the inert case is a
		## spawn that named none, which never reaches here at all.
		## Our own registration, under the workspace's system-data root. A native
		## client's `.mcp.json` is installer output generated from this file, never a
		## source read here -- reading it would make something we publish the authority.
		harnessMcpConfigFile="${MMDAPP:-}/.local/agents/mcp.servers.json"
		if [ -z "${MMDAPP:-}" ] ; then
			harnessMcpConfigFault="MMDAPP is not set, so there is no mcp.servers.json to resolve it against"
		elif [ ! -f "$harnessMcpConfigFile" ] || [ ! -r "$harnessMcpConfigFile" ] ; then
			harnessMcpConfigFault="there is no readable $harnessMcpConfigFile to resolve it against"
		fi

		for harnessMcpName in "${harnessMcpServers[@]}" ; do
			{
				AgentsHarnessMcpHandshake
				printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
			} > "$harnessScratch/mcp.req" || {
				AgentsHarnessMcpDegrade "$harnessMcpName" "its request could not be written to $harnessScratch/mcp.req"
				continue
			}
			if ! AgentsHarnessMcpRun "$harnessMcpName" "$harnessMcpEnumTimeout" 2 ; then
				AgentsHarnessMcpDegrade "$harnessMcpName" "$harnessMcpFault"
				continue
			fi
			if ! AgentsHarnessMcpReply 1 ; then
				AgentsHarnessMcpDegrade "$harnessMcpName" "it never answered \`initialize\` (exit status $harnessMcpStatus)${harnessMcpDiag:+ -- it said: $harnessMcpDiag}"
				continue
			fi
			if ! AgentsHarnessMcpReply 2 ; then
				AgentsHarnessMcpDegrade "$harnessMcpName" "it answered \`initialize\` and then returned no \`tools/list\` result (exit status $harnessMcpStatus)${harnessMcpDiag:+ -- it said: $harnessMcpDiag}"
				continue
			fi
			printf '%s\n' "$harnessMcpReply" > "$harnessScratch/mcp.reply" || {
				AgentsHarnessMcpDegrade "$harnessMcpName" "its \`tools/list\` answer could not be written to $harnessScratch/mcp.reply"
				continue
			}

			harnessMcpRc=0
			harnessMcpToolCount="$( AgentsHarnessMcpField result.tools.__count < "$harnessScratch/mcp.reply" )" || harnessMcpRc=$?
			if [ "$harnessMcpRc" != "0" ] ; then
				AgentsHarnessMcpDegrade "$harnessMcpName" "its \`tools/list\` answer carries no \`result.tools\` array (rc=$harnessMcpRc)"
				continue
			fi

			printf '%s\n' "🔌 ${harnessDim}MCP${harnessOff} ${harnessValue}$harnessMcpName${harnessOff} ${harnessDim}-- $harnessMcpToolCount tool(s) enumerated${harnessOff}" >&2
			harnessMcpToolIndex=0
			while [ "$harnessMcpToolIndex" -lt "$harnessMcpToolCount" ] 2>/dev/null ; do
				harnessMcpToolPath="result.tools.$harnessMcpToolIndex"
				harnessMcpToolIndex=$(( harnessMcpToolIndex + 1 ))
				harnessMcpRc=0
				harnessMcpTool="$( AgentsHarnessMcpField "$harnessMcpToolPath.name" < "$harnessScratch/mcp.reply" )" || harnessMcpRc=$?
				if [ "$harnessMcpRc" != "0" ] ; then
					printf '%s\n' "${harnessWarn}🔌 mcp${harnessOff} ${harnessDim}$harnessMcpName: dropped $harnessMcpToolPath -- it declares no readable name${harnessOff}" >&2
					continue
				fi
				if ! AgentsHarnessMcpNameOk "$harnessMcpTool" "_.-" ; then
					printf '%s\n' "${harnessWarn}🔌 mcp${harnessOff} ${harnessDim}$harnessMcpName: dropped the tool named ${harnessOff}${harnessValue}$harnessMcpTool${harnessOff}${harnessDim} -- a tool name carries letters, digits, underscore, dot and hyphen only${harnessOff}" >&2
					continue
				fi
				harnessMcpSchemaFile="$harnessScratch/mcp.$harnessMcpName.$harnessMcpTool.schema.json"
				harnessMcpRc=0
				LC_ALL=C awk -v path="$harnessMcpToolPath.inputSchema" -v mode=raw -f "$harnessHere/AgentsHarnessJsonSlice.awk" < "$harnessScratch/mcp.reply" > "$harnessMcpSchemaFile" 2>/dev/null || harnessMcpRc=$?
				if [ "$harnessMcpRc" != "0" ] ; then
					rm -f "$harnessMcpSchemaFile"
					printf '%s\n' "${harnessWarn}🔌 mcp${harnessOff} ${harnessDim}$harnessMcpName: dropped the tool ${harnessOff}${harnessValue}$harnessMcpTool${harnessOff}${harnessDim} -- it declares no readable inputSchema (rc=$harnessMcpRc)${harnessOff}" >&2
					continue
				fi
				harnessMcpDesc="$( AgentsHarnessMcpField "$harnessMcpToolPath.description" < "$harnessScratch/mcp.reply" )" || harnessMcpDesc=""
				## A dot is a legal name here and a 400 on the wire, whose names are [A-Za-z0-9_-]:
				## it becomes `_`, the spelling mcp__myx_distro__execute already has everywhere.
				harnessMcpDeclared="mcp__${harnessMcpName//./_}__${harnessMcpTool//./_}"
				harnessMcpDeclaration="$( AgentsWireToolDeclaration "$harnessMcpDeclared" "$harnessMcpDesc" "$( cat "$harnessMcpSchemaFile" )" )" || {
					printf '%s\n' "${harnessWarn}🔌 mcp${harnessOff} ${harnessDim}$harnessMcpName: dropped the tool ${harnessOff}${harnessValue}$harnessMcpTool${harnessOff}${harnessDim} -- its declaration could not be rendered${harnessOff}" >&2
					continue
				}
				harnessMcpCatalogue="${harnessMcpCatalogue}${harnessMcpName}"$'\t'"${harnessMcpTool}"$'\t'"${harnessMcpDeclared}"$'\t'"${harnessMcpSchemaFile}"$'\n'
				harnessMcpToolsJson="${harnessMcpToolsJson},$harnessMcpDeclaration"
				printf '%s\n' "   ${harnessDim}·${harnessOff} ${harnessTool}${harnessMcpDeclared}${harnessOff} ${harnessDim}declared${harnessOff}" >&2
			done
		done
	fi
}

AgentsHarnessMcpEnumerate
