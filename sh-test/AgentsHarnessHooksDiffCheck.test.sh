#!/usr/bin/env bash
## Differential check on AgentsHarnessHooks.sh's AgentsHarnessHooksRefusal: the payload a
## PreToolUse hook receives on stdin is byte for byte what the previous implementation
## sent, and the refusal printed for each answer a hook can give is byte for byte the
## same -- now that session_id and cwd are escaped once at source time, the arguments come
## from the already-parsed table, and the decision and its reason are read in one pass.
## The previous file is kept ONLY here, as check-fixtures/AgentsHarnessHooks.legacy.sh.
## Each case runs both implementations in their own subshell against a recording hook
## that answers from a canned document. Offline: the hook is a local script, the
## workspace is a temp directory, nothing is requested anywhere.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/AgentsUniversalHarness.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigHarness" "$rigHere/AgentsHarnessHooks.sh" "$rigHere/AgentsHarnessHookDecision.awk" \
	"$rigTest/check-fixtures/AgentsHarnessHooks.legacy.sh" "$rigTest/check-fixtures/AgentsHarnessJsonField.legacy.awk" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

rigTmp="$( mktemp -d "${TMPDIR:-/tmp}/AgentsHarnessHooksDiffCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

## The argument-table functions the refusal reads through, lifted out of the harness.
rigLift="$( LC_ALL=C awk '
	/^(AgentsHarnessWholeNumber|AgentsHarnessArgParse|AgentsHarnessArgFind|AgentsHarnessArgValue)\(\)\{/ { inFn = 1 ; }
	inFn { print ; }
	inFn && /^\}$/ { inFn = 0 ; seen++ ; }
	END { if ( seen != 4 ) exit 1 ; }
' "$rigHarness" )" || rigRefuse "the argument-table functions were not all found in $rigHarness"

## A workspace whose one hook records its stdin and answers with the canned document.
## The directory name carries a quote, a backslash and a space, so cwd needs escaping.
rigWorkspace="$rigTmp/work \"q\" \\ é"
mkdir -p "$rigWorkspace/.claude"
cat > "$rigTmp/hook.sh" <<'EOF'
#!/usr/bin/env bash
cat > "$RIG_HOOK_DIR/payload"
[ ! -f "$RIG_HOOK_DIR/answer" ] || cat "$RIG_HOOK_DIR/answer"
exit "$( cat "$RIG_HOOK_DIR/status" 2>/dev/null || echo 0 )"
EOF
chmod +x "$rigTmp/hook.sh"
printf '{"hooks":{"PreToolUse":[{"matcher":"","hooks":[{"type":"command","command":"bash \\"$RIG_HOOK_SCRIPT\\""}]}]}}\n' > "$rigWorkspace/.claude/settings.json"

rigPass=0
rigFail=0

rigRefusal(){ ## legacy|current, tool name, raw args, pre-parse (1/0), out dir, cd-after-source dir or ""
	mkdir -p "$5"
	(
		cd "$rigWorkspace" || exit 1
		MMDAPP="$rigWorkspace" harnessHere="$rigHere" harnessScratch="$5" harnessSelfName=rig
		harnessSessionId='sess "id" \ with	tab'
		harnessDim='' harnessTool='' harnessValue='' harnessWarn='' harnessBad='' harnessOff=''
		harnessTimeoutCmd=""
		harnessArgRaw="" harnessArgParsed=0 harnessArgPaths=() harnessArgEncs=() harnessArgFound=""
		rigLegacyField="$rigTest/check-fixtures/AgentsHarnessJsonField.legacy.awk"
		export RIG_HOOK_DIR="$5" RIG_HOOK_SCRIPT="$rigTmp/hook.sh"
		eval "$rigLift"
		if [ "$1" = legacy ] ; then
			. "$rigTest/check-fixtures/AgentsHarnessHooks.legacy.sh" 2> "$5/source.err"
		else
			. "$rigHere/AgentsHarnessHooks.sh" 2> "$5/source.err"
		fi
		[ -z "$6" ] || cd "$6" || exit 1
		[ "$4" != 1 ] || AgentsHarnessArgParse "$3"
		printf '%s' "$( AgentsHarnessHooksRefusal "$2" "$3" )" > "$5/refusal"
	)
}

rigCase(){ ## title, tool name, raw args, answer document ("-" for none), hook status, pre-parse, cd-after-source dir
	local caseDir="$rigTmp/case.$(( rigPass + rigFail ))" caseSide
	for caseSide in legacy current ; do
		mkdir -p "$caseDir/$caseSide"
		[ "$4" = - ] || printf '%s' "$4" > "$caseDir/$caseSide/answer"
		printf '%s' "$5" > "$caseDir/$caseSide/status"
		rigRefusal "$caseSide" "$2" "$3" "$6" "$caseDir/$caseSide" "$7"
	done
	if cmp -s "$caseDir/legacy/payload" "$caseDir/current/payload" \
		&& cmp -s "$caseDir/legacy/refusal" "$caseDir/current/refusal" \
		&& cmp -s "$caseDir/legacy/source.err" "$caseDir/current/source.err" \
		&& [ -s "$caseDir/legacy/payload" ] ; then
		rigPass=$(( rigPass + 1 ))
	else
		rigFail=$(( rigFail + 1 ))
		printf '  FAIL  %s\n' "$1"
		printf '        payload  legacy: %s\n        payload current: %s\n' "$( cat "$caseDir/legacy/payload" 2>/dev/null )" "$( cat "$caseDir/current/payload" 2>/dev/null )"
		printf '        refusal  legacy: %s\n        refusal current: %s\n' "$( cat "$caseDir/legacy/refusal" )" "$( cat "$caseDir/current/refusal" )"
	fi
}

rigAllow='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
rigDeny='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"memory is off-limits \"here\"\nsecond line\n\n"}}'
rigAsk='{"hookSpecificOutput":{"permissionDecision":"ask"}}'
rigOdd='{"hookSpecificOutput":{"permissionDecision":"maybe\n\n","permissionDecisionReason":"r"}}'
rigSepInside='{"hookSpecificOutput":{"permissionDecision":"deny","permissionDecisionReason":"has \u001e\u001f inside"}}'
rigNoDecision='{"hookSpecificOutput":{"permissionDecisionReason":"no decision"}}'
rigReadArgs='{"file_path":"/x/\"q\"/é\\n\n","offset":3,"limit":"x"}'

echo "-- every shaped tool, its payload and the refusal for each answer --"
rigCase "Read, deny with a multi-line reason"        Read '{"file_path":"/a/b","offset":10,"limit":20}' "$rigDeny" 0 1 ""
rigCase "Read, odd path, non-numeric limit, allow"   Read "$rigReadArgs" "$rigAllow" 0 1 ""
rigCase "Read via path alias, ask"                    Read '{"path":"/alias"}' "$rigAsk" 0 1 ""
rigCase "Write, unknown decision with newlines"      Write '{"file_path":"/w","content":"c"}' "$rigOdd" 0 1 ""
rigCase "Edit via path alias, no decision field"     Edit '{"path":"/e","old_string":"a","new_string":"b"}' "$rigNoDecision" 0 1 ""
rigCase "Glob, silent allow"                          Glob '{"pattern":"*","path":"/g"}' - 0 1 ""
rigCase "Grep, separator bytes inside the reason"    Grep '{"pattern":"x","path":"/gr"}' "$rigSepInside" 0 1 ""
rigCase "Bash, deny"                                  Bash '{"cwd":"/","command":"echo \"hi\" \\\\ there\n"}' "$rigDeny" 0 1 ""
rigCase "Monitor, deny"                               Monitor '{"command":"sleep 1","cwd":"/m","handle":"h1"}' "$rigDeny" 0 1 ""
rigCase "WebSearch, allow"                            WebSearch '{"query":"bhyve"}' "$rigAllow" 0 1 ""
rigCase "WebFetch, deny"                              WebFetch '{"url":"https://example.invalid/?a=\"b\""}' "$rigDeny" 0 1 ""
rigCase "SendMessage, ask"                            SendMessage '{"to":"magic-team","message":"line\nline2"}' "$rigAsk" 0 1 ""
rigCase "ListAgents, deny"                            ListAgents '{}' "$rigDeny" 0 1 ""
rigCase "Wait, empty sources, deny"                   Wait '{}' "$rigDeny" 0 1 ""
rigCase "an MCP tool's arguments passed through"     mcp__srv__tool '{"a":[1,{"b":"c"}]}' "$rigDeny" 0 1 ""
rigCase "an MCP tool with unparseable arguments"     mcp__srv__tool 'not json' "$rigDeny" 0 1 ""
echo "-- the answer itself --"
rigCase "a hook that fails"                           Read '{"file_path":"/f"}' "$rigDeny" 3 1 ""
rigCase "an answer that is not JSON"                  Read '{"file_path":"/f"}' 'Not JSON at all' 0 1 ""
rigCase "an answer that is truncated JSON"            Read '{"file_path":"/f"}' '{"hookSpecificOutput":{"permissionDecision":"deny"' 0 1 ""
rigCase "an answer over two lines"                    Read '{"file_path":"/f"}' $'{"hookSpecificOutput":\n {"permissionDecision":"deny","permissionDecisionReason":"two\\nlines"}}\n' 0 1 ""
rigCase "a reason that is only newlines"              Read '{"file_path":"/f"}' '{"hookSpecificOutput":{"permissionDecision":"deny","permissionDecisionReason":"\n\n"}}' 0 1 ""
echo "-- where the arguments were not parsed first, and where cwd moved after sourcing --"
rigCase "Read, arguments not parsed beforehand"      Read "$rigReadArgs" "$rigDeny" 0 0 ""
rigCase "Bash, arguments not parsed beforehand"      Bash '{"command":"ls"}' "$rigDeny" 0 0 ""
mkdir -p "$rigTmp/moved \"there\""
rigCase "cwd changed after the hooks were sourced"   Read '{"file_path":"/f"}' "$rigDeny" 0 1 "$rigTmp/moved \"there\""

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ HOOKS DIFF CHECK FAILED: $rigFail of $(( rigPass + rigFail )) case(s)" >&2 ; exit 1
fi
printf 'HOOKS_DIFF: OK (%d cases, hook payload and refusal byte for byte against the previous implementation, offline)\n' "$rigPass"
