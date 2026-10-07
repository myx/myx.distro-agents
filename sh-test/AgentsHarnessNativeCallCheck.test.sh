#!/usr/bin/env bash
## Behavioural check that every rerouted tool answers a call written in the NATIVE client's own
## argument names and semantics, AS THE MCP SERVER SERVES IT: every call goes through the real
## server's tools/call, and every answer is read off the wire it writes. Each tool carries a
## control in this server's own names, so a FAIL on a native case is the gap and not a broken rig.
## The gate then fails every tool on the reroute list with no native case here, or a failing one.
## Offline: MMDAPP and HOME are this rig's own, and curl is a stub on PATH.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"

rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigField="$rigHere/AgentsHarnessJsonField.awk"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigPolicy="$rigHere/AgentsTools.ClientToolPolicy.include"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

for rigFile in "$rigHere/AgentsUniversalHarness.sh" "$rigField" "$rigTool" "$rigPolicy" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

## Read from the policy itself, in a subshell, so the rig never states the set a second time.
rigRerouted="$( . "$rigPolicy" && AgentsToolsClientToolPolicyRerouteToolNames )" || rigRefuse "the client tool policy did not state its reroute set"
[ -n "$rigRerouted" ] || rigRefuse "the client tool policy stated an empty reroute set"

rigTmp="$( mktemp -d -t "AgentsHarnessNativeCallCheck-XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigTmp="$( cd "$rigTmp" && pwd -P )"

## `.local/temp` is a write root and `source/` a read root the server computes for a workspace.
rigW="$rigTmp/.local/temp/team"
rigS="$rigTmp/source/fix"
rigG="$rigS/g"
mkdir -p "$rigW" "$rigG/sub" "$rigS/big" "$rigTmp/home" "$rigTmp/bin" "$rigTmp/data"
printf 'alpha\nbeta\n' > "$rigW/e-ctl.txt"
printf 'alpha\nbeta\n' > "$rigW/e-one.txt"
printf 'x\nx\nx\n' > "$rigW/e-all.txt"
printf 'x\nx\n' > "$rigW/e-dup.txt"
printf 'x\nx\n' > "$rigW/e-ctl-all.txt"
printf 'alpha\nbeta\ngamma\n' > "$rigS/a.txt"
printf 'Needle one\nneedle two\nother\nneedle three\n' > "$rigG/a.js"
printf 'needle in txt\n' > "$rigG/b.txt"
printf 'needle ts\n' > "$rigG/c.ts"
printf 'needle d\n' > "$rigG/sub/d.js"
LC_ALL=C awk 'BEGIN { for ( lineNo = 1 ; lineNo <= 300 ; lineNo++ ) printf "hit %03d\n", lineNo ; }' > "$rigS/big/big.txt"
## Kept out of the g tree, so a glob with a slash has a path to filter to without moving any other case's file set.
mkdir -p "$rigS/sl/src/deep"
printf 'needle e\n' > "$rigS/sl/src/deep/e.ts"
printf 'needle f\n' > "$rigS/sl/f.ts"
## The class-escape translation fixture, one line per class, plus a literal backslash-d.
mkdir -p "$rigS/tr"
printf 'id 42 here\nno digits\ntab\there\nback\\dslash\nfoo_bar baz\n' > "$rigS/tr/t.txt"

## The stub answers every request with HTTP 200: a search gets two results on two domains, anything else one body.
cat > "$rigTmp/bin/curl" <<'EOF'
#!/usr/bin/env bash
stubOut=/dev/null
while [ "$#" -gt 0 ] ; do
	[ "$1" != "-o" ] || { stubOut="$2" ; shift ; }
	stubUrl="$1"
	shift
done
case "$stubUrl" in
	*duckduckgo*) printf '%s\n' '{"Abstract":"","Results":[{"Text":"RIGALLOWED","FirstURL":"https://allowed.example/a"},{"Text":"RIGBLOCKED","FirstURL":"https://blocked.example/b"},{"Text":"RIGWIKI","FirstURL":"https://en.wikipedia.org/wiki/Rig"}],"RelatedTopics":[]}' > "$stubOut" ;;
	*) printf 'RIGFETCHBODY\n' > "$stubOut" ;;
esac
case "$stubUrl" in
	*duckduckgo*) printf '200' ;;
	https://fetch.example/redirect-cross) printf '302 https://unknown.example/landing' ;;
	https://fetch.example/redirect-same) printf '301 https://fetch.example/landed' ;;
	https://en.wikipedia.org/wiki/RedirectToDenied) printf '301 https://en.wikipedia.org/wiki/Denied' ;;
	*) printf '200 ' ;;
esac
EOF
chmod +x "$rigTmp/bin/curl"

## The web access lists: the stub fetch host is allowed by an extra prefix, one Wikipedia path is denied.
mkdir -p "$rigTmp/.local/.agents"
printf 'WEB_ALLOW_PREFIXES=https://fetch.example/\nWEB_DENY_PREFIXES=https://en.wikipedia.org/wiki/Denied\n' >> "$rigTmp/.local/.agents/magic-team.agent.env"

## A recording PreToolUse hook in the workspace's own settings: it appends each payload as one line and allows.
printf 'alpha\n' > "$rigW/h-ctl-e.txt"
printf 'alpha\n' > "$rigW/h-nat-e.txt"
mkdir -p "$rigTmp/.claude"
printf '{"hooks":{"PreToolUse":[{"matcher":"Write|Edit","hooks":[{"type":"command","command":"cat >> %s/hook.log ; echo >> %s/hook.log"}]}]}}\n' "$rigTmp" "$rigTmp" > "$rigTmp/.claude/settings.json"

rigCall(){ ## request id, tool name, arguments JSON -- one tools/call line
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"%s","arguments":%s}}\n' "$1" "$2" "$3"
}
{
	rigCall 2 Edit '{"path":"'"$rigW/e-ctl.txt"'","old_text":"alpha","new_text":"ALPHA"}'
	rigCall 3 Edit '{"file_path":"'"$rigW/e-one.txt"'","old_string":"alpha","new_string":"ALPHA"}'
	rigCall 4 Edit '{"file_path":"'"$rigW/e-all.txt"'","old_string":"x","new_string":"Y","replace_all":true}'
	rigCall 5 Edit '{"file_path":"'"$rigW/e-dup.txt"'","old_string":"x","new_string":"Y"}'
	rigCall 6 Edit '{"path":"'"$rigW/e-ctl-all.txt"'","old_text":"x","new_text":"Y","replace_all":true}'
	rigCall 7 Write '{"path":"'"$rigW/w-ctl.txt"'","content":"ctl\n"}'
	rigCall 8 Write '{"file_path":"'"$rigW/w-native.txt"'","content":"native line\nsecond\n"}'
	rigCall 9 Read '{"path":"'"$rigS/a.txt"'"}'
	rigCall 10 Read '{"file_path":"'"$rigS/a.txt"'","offset":2,"limit":1}'
	rigCall 11 Glob '{"pattern":"b.txt","path":"'"$rigG"'"}'
	rigCall 12 Glob '{"pattern":"**/*.ts","path":"'"$rigG"'"}'
	rigCall 13 Glob '{"pattern":"*.ts"}'
	rigCall 14 Grep '{"pattern":"needle","path":"'"$rigG"'","output_mode":"content"}'
	rigCall 15 Grep '{"pattern":"needle","path":"'"$rigG"'"}'
	rigCall 16 Grep '{"pattern":"needle","path":"'"$rigG"'","glob":"*.js","output_mode":"files_with_matches"}'
	rigCall 17 Grep '{"pattern":"needle","path":"'"$rigG"'","glob":"*.{ts,tsx}","output_mode":"files_with_matches"}'
	rigCall 18 Grep '{"pattern":"NEEDLE","path":"'"$rigG/a.js"'","ignore_case":true,"output_mode":"content"}'
	rigCall 19 Grep '{"pattern":"NEEDLE","path":"'"$rigG/a.js"'","-i":true,"output_mode":"content"}'
	rigCall 20 Grep '{"pattern":"other","path":"'"$rigG/a.js"'","output_mode":"content"}'
	rigCall 21 Grep '{"pattern":"other","path":"'"$rigG/a.js"'","-n":false,"output_mode":"content"}'
	rigCall 22 Grep '{"pattern":"need[a-z]*","path":"'"$rigG/b.txt"'","-o":true,"output_mode":"content"}'
	rigCall 23 Grep '{"pattern":"other","path":"'"$rigG/a.js"'","context":1,"output_mode":"content"}'
	rigCall 24 Grep '{"pattern":"other","path":"'"$rigG/a.js"'","-C":1,"output_mode":"content"}'
	rigCall 25 Grep '{"pattern":"other","path":"'"$rigG/a.js"'","context":1,"output_mode":"content"}'
	rigCall 26 Grep '{"pattern":"other","path":"'"$rigG/a.js"'","after":1,"output_mode":"content"}'
	rigCall 27 Grep '{"pattern":"other","path":"'"$rigG/a.js"'","-A":1,"output_mode":"content"}'
	rigCall 28 Grep '{"pattern":"other","path":"'"$rigG/a.js"'","before":1,"output_mode":"content"}'
	rigCall 29 Grep '{"pattern":"other","path":"'"$rigG/a.js"'","-B":1,"output_mode":"content"}'
	rigCall 30 Grep '{"pattern":"hit","path":"'"$rigS/big/big.txt"'","output_mode":"count"}'
	rigCall 31 Grep '{"pattern":"hit","path":"'"$rigS/big/big.txt"'","output_mode":"content"}'
	rigCall 32 Grep '{"pattern":"hit","path":"'"$rigS/big/big.txt"'","output_mode":"content","head_limit":0}'
	rigCall 33 Grep '{"pattern":"hit","path":"'"$rigS/big/big.txt"'","output_mode":"content","head_limit":5}'
	rigCall 34 Grep '{"pattern":"hit","path":"'"$rigS/big/big.txt"'","output_mode":"content","head_limit":5,"offset":10}'
	rigCall 35 Grep '{"pattern":"needle in txt","path":"'"$rigG"'","output_mode":"files_with_matches"}'
	rigCall 36 Grep '{"pattern":"needle in txt","output_mode":"files_with_matches"}'
	rigCall 37 Grep '{"pattern":"needle (two|three)","path":"'"$rigG/a.js"'","output_mode":"content"}'
	rigCall 38 Grep '{"pattern":"needle","path":"'"$rigG"'","type":"js","output_mode":"files_with_matches"}'
	rigCall 39 Grep '{"pattern":"two\\nother","path":"'"$rigG"'","multiline":true,"output_mode":"files_with_matches"}'
	rigCall 40 WebSearch '{"query":"rigquery"}'
	rigCall 41 WebSearch '{"query":"rigquery","allowed_domains":["allowed.example"]}'
	rigCall 42 WebSearch '{"query":"rigquery","blocked_domains":["blocked.example"]}'
	rigCall 43 WebFetch '{"url":"https://fetch.example/page"}'
	rigCall 44 WebFetch '{"url":"https://fetch.example/page","prompt":"Reply with the single word RIGPROMPTWORD"}'
	rigCall 45 TaskStop '{"handle":"rig-no-such-handle"}'
	rigCall 46 TaskStop '{"task_id":"rig-no-such-handle"}'
	rigCall 47 TaskStop '{"shell_id":"rig-no-such-handle"}'
	rigCall 48 Write '{"path":"'"$rigW/h-ctl-w.txt"'","content":"h\n"}'
	rigCall 49 Write '{"file_path":"'"$rigW/h-nat-w.txt"'","content":"h\n"}'
	rigCall 50 Edit '{"path":"'"$rigW/h-ctl-e.txt"'","old_text":"alpha","new_text":"ALPHA"}'
	rigCall 51 Edit '{"file_path":"'"$rigW/h-nat-e.txt"'","old_string":"alpha","new_string":"ALPHA"}'
	rigCall 52 Write '{"content":"h\n"}'
	rigCall 53 Edit '{"old_string":"alpha","new_string":"ALPHA"}'
	rigCall 54 Grep '{"pattern":"needle","path":"'"$rigS/sl"'","glob":"src/**/*.ts","output_mode":"files_with_matches"}'
	rigCall 55 WebSearch '{"query":"rigquery","allowed_domains":["example.com"]}'
	rigCall 56 WebSearch '{"query":"rigquery","blocked_domains":["wikipedia.org"]}'
	rigCall 57 WebFetch '{"url":"https://en.wikipedia.org/wiki/Rig"}'
	rigCall 58 WebFetch '{"url":"https://en.wikipedia.org/wiki/Denied"}'
	rigCall 59 WebFetch '{"url":"https://unknown.example/x"}'
	rigCall 60 WebFetch '{"url":"https://www.freebsd.org/"}'
	rigCall 61 WebFetch '{"url":"https://fetch.example/redirect-cross"}'
	rigCall 62 WebFetch '{"url":"https://fetch.example/redirect-same"}'
	rigCall 63 WebFetch '{"url":"https://en.wikipedia.org/wiki/RedirectToDenied"}'
	rigCall 65 Grep '{"pattern":"\\d+","path":"'"$rigS/tr/t.txt"'","output_mode":"content"}'
	rigCall 66 Grep '{"pattern":"[\\d]{2}","path":"'"$rigS/tr/t.txt"'","output_mode":"content"}'
	rigCall 67 Grep '{"pattern":"tab\\shere","path":"'"$rigS/tr/t.txt"'","output_mode":"content"}'
	rigCall 68 Grep '{"pattern":"\\w+_\\w+","path":"'"$rigS/tr/t.txt"'","output_mode":"content","-o":true}'
	rigCall 69 Grep '{"pattern":"^\\D+$","path":"'"$rigS/tr/t.txt"'","output_mode":"content"}'
	rigCall 70 Grep '{"pattern":"k\\\\d","path":"'"$rigS/tr/t.txt"'","output_mode":"content"}'
	rigCall 71 Grep '{"pattern":"[\\D]","path":"'"$rigS/tr/t.txt"'","output_mode":"content"}'
	rigCall 72 Grep '{"pattern":"needle","path":"'"$rigG"'","type":"js","glob":"a.*","output_mode":"files_with_matches"}'
	rigCall 73 Grep '{"pattern":"needle","path":"'"$rigG"'","type":"rignosuchtype"}'
	rigCall 74 Grep '{"pattern":"needle","path":"'"$rigG/a.js"'","type":"ts","output_mode":"files_with_matches"}'
	rigCall 75 execute '{"command":"printf RIGBASHOUT","description":"Print the rig marker"}'
	rigCall 76 execute '{"command":"printf RIGBASHFAIL ; exit 3","description":"Fail with exit code 3"}'
} | ( cd "$rigG" && MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" HOME="$rigTmp/home" MDAT_SKILLSET_ROOT="$rigTmp/home/.claude/skills" \
	MDAT_DATA_ROOT="$rigTmp/data" PATH="$rigTmp/bin:$PATH" bash "$rigTool" --intern-mcp-server --run ) > "$rigTmp/wire" 2> "$rigTmp/err" || :

## A second run with the policy file unreadable: WebFetch must refuse rather than fetch.
chmod 000 "$rigTmp/.local/.agents/magic-team.agent.env"
rigCall 64 WebFetch '{"url":"https://en.wikipedia.org/wiki/Rig"}' | ( cd "$rigG" && MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" HOME="$rigTmp/home" MDAT_SKILLSET_ROOT="$rigTmp/home/.claude/skills" \
	MDAT_DATA_ROOT="$rigTmp/data" PATH="$rigTmp/bin:$PATH" bash "$rigTool" --intern-mcp-server --run ) >> "$rigTmp/wire" 2>> "$rigTmp/err" || :
chmod 600 "$rigTmp/.local/.agents/magic-team.agent.env"

## A request the server never answered was never exercised, so the run stops there.
rigId=2
while [ "$rigId" -le 76 ] ; do
	LC_ALL=C grep -q "^{\"jsonrpc\":\"2.0\",\"id\":$rigId," "$rigTmp/wire" || {
		echo "-- the server left request $rigId unanswered, so its stderr follows --" >&2
		sed 's/^/    /' "$rigTmp/err" >&2
		rigRefuse "no tools/call answer for request $rigId"
	}
	rigId=$(( rigId + 1 ))
done

rigPart(){ ## request id, json path under result.content -- the decoded value, empty when absent
	LC_ALL=C grep -m1 "^{\"jsonrpc\":\"2.0\",\"id\":$1," "$rigTmp/wire" | LC_ALL=C awk -v path="result.content.$2" -v optional=1 -f "$rigField" 2>/dev/null || :
}

## The tool's own result: the last text part, since the head part goes first. A protocol-level
## error has no content part, so its message is returned instead and reads as a refusal.
rigResult(){ ## request id
	local partIndex
	partIndex="$( rigPart "$1" __count )"
	partIndex=$(( ${partIndex:-0} - 1 ))
	while [ "$partIndex" -ge 0 ] ; do
		[ "$( rigPart "$1" "$partIndex.type" )" != text ] || { rigPart "$1" "$partIndex.text" ; return 0 ; }
		partIndex=$(( partIndex - 1 ))
	done
	printf 'ERROR: %s' "$( LC_ALL=C grep -m1 "^{\"jsonrpc\":\"2.0\",\"id\":$1," "$rigTmp/wire" | LC_ALL=C awk -v path="error.message" -v optional=1 -f "$rigField" 2>/dev/null )"
}

rigHas(){ ## text, needle -- yes when the text holds it
	case "$1" in *"$2"*) printf 'yes' ;; *) printf 'no' ;; esac
}

rigIsError(){ ## text -- yes when it is a refusal
	case "$1" in ERROR*) printf 'yes' ;; *) printf 'no' ;; esac
}

## Every byte, one character per field, so a newline shows as \n; a missing file shows as MISSING.
rigBytes(){ ## file path
	[ -f "$1" ] || { printf 'MISSING' ; return 0 ; }
	od -An -c "$1" | tr -d ' \n'
}

## The lines naming a path under the rig, prefix stripped and sorted, as one space-joined set.
rigPathSet(){ ## text
	printf '%s\n' "$1" | LC_ALL=C awk -v rigRoot="$rigG/" 'index($0, rigRoot) == 1 { print substr($0, length(rigRoot) + 1) ; }' | LC_ALL=C sort | LC_ALL=C tr '\n' ' '
}

## The result lines that are exactly a path under the rig and nothing else.
rigOnlyPaths(){ ## text
	printf '%s\n' "$1" | LC_ALL=C awk -v rigRoot="$rigG/" 'NF { total++ ; if ( index($0, rigRoot) == 1 && index($0, ":") == 0 ) { bare++ ; } ; } END { print ( total > 0 && total == bare ) ? "yes" : "no" ; }'
}

rigHits(){ ## text -- how many "hit NNN" match lines it carries
	printf '%s\n' "$1" | LC_ALL=C awk 'BEGIN { hitCount = 0 ; } /hit [0123456789][0123456789][0123456789]/ { hitCount++ ; } END { print hitCount ; }'
}

rigFails=0
rigNativeTools=' '
rigNativeFailed=' '
rigAssert(){ ## what is asserted, got, want -- a tab prints as \t
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1"
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "${2//$'\t'/\\t}" "${3//$'\t'/\\t}"
		rigFails=$(( rigFails + 1 ))
	fi
}
rigNative(){ ## tool, what is asserted, got, want -- a native-call case, recorded for the gate
	case "$rigNativeTools" in *" $1 "*) ;; *) rigNativeTools="$rigNativeTools$1 " ;; esac
	[ "$3" = "$4" ] || case "$rigNativeFailed" in *" $1 "*) ;; *) rigNativeFailed="$rigNativeFailed$1 " ;; esac
	rigAssert "native $1: $2" "$3" "$4"
}
rigSkip(){ ## tool, what is asserted, reason -- never a PASS, and the gate counts it as not passing
	case "$rigNativeTools" in *" $1 "*) ;; *) rigNativeTools="$rigNativeTools$1 " ;; esac
	case "$rigNativeFailed" in *" $1 "*) ;; *) rigNativeFailed="$rigNativeFailed$1 " ;; esac
	printf '  SKIP  native %s: %s\n        why:  %s\n' "$1" "$2" "$3"
}

echo "-- Edit --"
rigAssert "control: path/old_text/new_text changes the file" "$( rigBytes "$rigW/e-ctl.txt" )" 'ALPHA\nbeta\n'
rigAssert "control: replace_all with path/old_text/new_text changes every occurrence" "$( rigBytes "$rigW/e-ctl-all.txt" )" 'Y\nY\n'
rigNative Edit "file_path/old_string/new_string changes the file" "$( rigBytes "$rigW/e-one.txt" )" 'ALPHA\nbeta\n'
rigNative Edit "replace_all true changes every occurrence" "$( rigBytes "$rigW/e-all.txt" )" 'Y\nY\nY\n'
rigText="$( rigResult 5 )"
rigNative Edit "a non-unique old_string without replace_all is refused as not unique, file untouched" \
	"$( rigIsError "$rigText" ) $( rigHas "$rigText" unique ) $( rigBytes "$rigW/e-dup.txt" )" 'yes yes x\nx\n'

echo "-- Write --"
rigAssert "control: path/content creates the file" "$( rigBytes "$rigW/w-ctl.txt" )" 'ctl\n'
rigNative Write "file_path/content creates the file with exact content" "$( rigBytes "$rigW/w-native.txt" )" 'nativeline\nsecond\n'

echo "-- Read --"
rigAssert "control: path returns cat -n text" "$( rigResult 9 )" $'     1\talpha\n     2\tbeta\n     3\tgamma'
rigText="$( rigResult 10 )"
rigNative Read "file_path with offset/limit starts at that cat -n line" "${rigText%%$'\n'*}" $'     2\tbeta'

echo "-- Glob --"
rigAssert "control: pattern/path finds the file" "$( rigPathSet "$( rigResult 11 )" )" 'b.txt '
rigNative Glob "pattern **/*.ts with path finds only the .ts file" "$( rigPathSet "$( rigResult 12 )" )" 'c.ts '
rigNative Glob "path omitted searches the cwd" "$( rigPathSet "$( rigResult 13 )" )" 'c.ts '

echo "-- Grep --"
rigText="$( rigResult 14 )"
rigAssert "control: pattern/path returns numbered content lines" "$( rigHas "$rigText" 'b.txt:1:needle in txt' )" yes
rigAssert "control: ignore_case matches case-insensitively" "$( rigHas "$( rigResult 18 )" 'Needle one' )" yes
rigAssert "control: a content line carries its number" "$( rigHas "$( rigResult 20 )" '3:other' )" yes
rigText="$( rigResult 23 )"
rigAssert "control: context 1 gives a line either side" "$( rigHas "$rigText" 'needle two' ) $( rigHas "$rigText" 'needle three' )" 'yes yes'
rigText="$( rigResult 26 )"
rigAssert "control: after 1 gives the line after only" "$( rigHas "$rigText" 'needle two' ) $( rigHas "$rigText" 'needle three' )" 'no yes'
rigText="$( rigResult 28 )"
rigAssert "control: before 1 gives the line before only" "$( rigHas "$rigText" 'needle two' ) $( rigHas "$rigText" 'needle three' )" 'yes no'
rigAssert "control: the fixture holds 300 hits the server can count" "$( rigHas "$( rigResult 30 )" 300 )" yes
rigAssert "control: files_with_matches with a path names the file" "$( rigPathSet "$( rigResult 35 )" )" 'b.txt '
rigText="$( rigResult 15 )"
rigNative Grep "default output_mode returns file paths only" "$( rigOnlyPaths "$rigText" ) $( rigPathSet "$rigText" )" 'yes a.js b.txt c.ts sub/d.js '
rigNative Grep "glob *.js filters the files" "$( rigPathSet "$( rigResult 16 )" )" 'a.js sub/d.js '
rigNative Grep "glob *.{ts,tsx} filters the files" "$( rigPathSet "$( rigResult 17 )" )" 'c.ts '
rigText="$( rigResult 19 )"
rigNative Grep "-i matches case-insensitively" "$( rigHas "$rigText" 'Needle one' ) $( rigHas "$rigText" 'needle two' )" 'yes yes'
rigText="$( rigResult 21 )"
rigNative Grep "-n false drops the line number" "$( rigHas "$rigText" other ) $( rigHas "$rigText" '3:other' )" 'yes no'
rigText="$( rigResult 22 )"
rigNative Grep "-o prints only the matching part" "$( rigHas "$rigText" needle ) $( rigHas "$rigText" 'in txt' )" 'yes no'
rigText="$( rigResult 24 )"
rigNative Grep "-C 1 gives a line either side" "$( rigHas "$rigText" 'needle two' ) $( rigHas "$rigText" 'needle three' )" 'yes yes'
rigText="$( rigResult 25 )"
rigNative Grep "context 1 in content mode gives a line either side" "$( rigHas "$rigText" 'needle two' ) $( rigHas "$rigText" 'needle three' )" 'yes yes'
rigText="$( rigResult 27 )"
rigNative Grep "-A 1 gives the line after only" "$( rigHas "$rigText" 'needle two' ) $( rigHas "$rigText" 'needle three' )" 'no yes'
rigText="$( rigResult 29 )"
rigNative Grep "-B 1 gives the line before only" "$( rigHas "$rigText" 'needle two' ) $( rigHas "$rigText" 'needle three' )" 'yes no'
rigNative Grep "head_limit omitted caps entries at 250" "$( rigHits "$( rigResult 31 )" )" 250
rigNative Grep "head_limit 0 is unlimited" "$( rigHits "$( rigResult 32 )" )" 300
rigNative Grep "head_limit 5 caps entries at 5" "$( rigHits "$( rigResult 33 )" )" 5
rigText="$( rigResult 34 )"
rigNative Grep "offset 10 skips ten entries before head_limit 5" "$( rigHits "$rigText" ) $( rigHas "$rigText" 'hit 010' ) $( rigHas "$rigText" 'hit 011' )" '5 no yes'
rigNative Grep "path omitted searches the cwd" "$( rigPathSet "$( rigResult 36 )" )" 'b.txt '
rigText="$( rigResult 37 )"
rigNative Grep "regex dialect: ( | ) alternation matches" "$( rigHas "$rigText" 'needle two' ) $( rigHas "$rigText" 'needle three' )" 'yes yes'
rigNative Grep "type js filters the files" "$( rigPathSet "$( rigResult 38 )" )" 'a.js sub/d.js '
rigNative Grep "type js with glob a.* keeps only files matching both" "$( rigPathSet "$( rigResult 72 )" )" 'a.js '
rigText="$( rigResult 73 )"
rigNative Grep "an unknown type is refused, naming the known types" "$( rigIsError "$rigText" ) $( rigHas "$rigText" 'unrecognized file type' ) $( rigHas "$rigText" 'Known types:' )" 'yes yes yes'
rigNative Grep "type does not filter a file given as path" "$( rigPathSet "$( rigResult 74 )" )" 'a.js '
rigNative Grep "multiline is refused, with a hint naming the native Grep" "$( rigIsError "$( rigResult 39 )" ) $( rigHas "$( rigResult 39 )" 'only by the native Grep tool' )" 'yes yes'
rigNative Grep "\\d matches a digit" "$( rigHas "$( rigResult 65 )" 'id 42 here' ) $( rigHas "$( rigResult 65 )" 'no digits' )" 'yes no'
rigNative Grep "\\d inside a bracket matches a digit" "$( rigHas "$( rigResult 66 )" 'id 42 here' ) $( rigHas "$( rigResult 66 )" 'no digits' )" 'yes no'
rigNative Grep "\\s matches a tab" "$( rigHas "$( rigResult 67 )" 'here' )" 'yes'
rigNative Grep "\\w matches a word character, underscore included" "$( rigHas "$( rigResult 68 )" 'foo_bar' ) $( rigHas "$( rigResult 68 )" 'baz' )" 'yes no'
rigNative Grep "\\D matches a non-digit" "$( rigHas "$( rigResult 69 )" 'no digits' ) $( rigHas "$( rigResult 69 )" 'id 42 here' )" 'yes no'
rigNative Grep "an escaped backslash stays literal, so a backslash then d matches" "$( rigHas "$( rigResult 70 )" 'back\dslash' ) $( rigHas "$( rigResult 70 )" 'id 42' )" 'yes no'
rigNative Grep "\\D inside a bracket is refused, with a hint" "$( rigIsError "$( rigResult 71 )" ) $( rigHas "$( rigResult 71 )" 'Use [^...] instead' )" 'yes yes'
rigText="$( rigResult 54 )"
rigNative Grep "glob with a slash src/**/*.ts filters to that path" "$( rigHas "$rigText" "$rigS/sl/src/deep/e.ts" ) $( rigHas "$rigText" "$rigS/sl/f.ts" )" 'yes no'

echo "-- WebSearch --"
rigText="$( rigResult 40 )"
rigAssert "control: query alone reaches the stub and returns both domains" "$( rigHas "$rigText" RIGALLOWED ) $( rigHas "$rigText" RIGBLOCKED )" 'yes yes'
if [ "$( rigHas "$rigText" RIGALLOWED )$( rigHas "$rigText" RIGBLOCKED )" = yesyes ] ; then
	rigText="$( rigResult 41 )"
	rigNative WebSearch "allowed_domains keeps only that domain" "$( rigHas "$rigText" RIGALLOWED ) $( rigHas "$rigText" RIGBLOCKED )" 'yes no'
	rigText="$( rigResult 42 )"
	rigNative WebSearch "blocked_domains drops that domain" "$( rigHas "$rigText" RIGALLOWED ) $( rigHas "$rigText" RIGBLOCKED )" 'yes no'
	rigAssert "wikipedia: allowed_domains example.com still keeps the en.wikipedia.org result" "$( rigHas "$( rigResult 55 )" RIGWIKI ) $( rigHas "$( rigResult 55 )" RIGALLOWED )" 'yes no'
	rigAssert "wikipedia: blocked_domains wikipedia.org drops it, the native exception" "$( rigHas "$( rigResult 56 )" RIGWIKI ) $( rigHas "$( rigResult 56 )" RIGALLOWED )" 'no yes'
else
	rigSkip WebSearch "allowed_domains keeps only that domain" "the stub curl was not reached, so domain filtering cannot be measured offline"
	rigSkip WebSearch "blocked_domains drops that domain" "the stub curl was not reached, so domain filtering cannot be measured offline"
fi

echo "-- WebFetch --"
rigAssert "control: url returns the stub body" "$( rigHas "$( rigResult 43 )" RIGFETCHBODY )" yes
rigAssert "wikipedia: a fetch of an en.wikipedia.org URL returns the body" "$( rigIsError "$( rigResult 57 )" ) $( rigHas "$( rigResult 57 )" RIGFETCHBODY )" 'no yes'
rigAssert "web lists: a default-allowed freebsd.org URL returns the body" "$( rigIsError "$( rigResult 60 )" ) $( rigHas "$( rigResult 60 )" RIGFETCHBODY )" 'no yes'
rigText="$( rigResult 58 )"
rigAssert "web lists: a Wikipedia URL under a deny entry is refused, not fetched" "$( rigHas "$rigText" 'matches a denied URL prefix' ) $( rigHas "$rigText" RIGFETCHBODY )" 'yes no'
rigAssert "web lists: its refusal carries the hint and a REFUSAL-ID" "$( rigHas "$rigText" 'accept that this URL will not be fetched' ) $( rigHas "$rigText" 'REFUSAL-ID:' )" 'yes yes'
rigText="$( rigResult 59 )"
rigAssert "web lists: an unknown URL is refused, not fetched" "$( rigHas "$rigText" 'matches no allowed URL prefix' ) $( rigHas "$rigText" RIGFETCHBODY )" 'yes no'
rigAssert "web lists: its refusal carries the hint and a REFUSAL-ID" "$( rigHas "$rigText" 'accept that this URL will not be fetched' ) $( rigHas "$rigText" 'REFUSAL-ID:' )" 'yes yes'
rigText="$( rigResult 61 )"
rigAssert "web lists: a cross-host 3xx comes back unfollowed, with its target" "$( rigHas "$rigText" 'redirect not followed: HTTP 302' ) $( rigHas "$rigText" 'https://unknown.example/landing' ) $( rigHas "$rigText" RIGFETCHBODY )" 'yes yes no'
rigText="$( rigResult 62 )"
rigAssert "web lists: a same-host 3xx is followed, and says so" "$( rigHas "$rigText" 'followed 1 same-host redirect(s) to: https://fetch.example/landed' ) $( rigHas "$rigText" RIGFETCHBODY )" 'yes yes'
rigText="$( rigResult 63 )"
rigAssert "web lists: a same-host hop into a denied prefix is refused" "$( rigHas "$rigText" 'https://en.wikipedia.org/wiki/Denied matches a denied URL prefix' ) $( rigHas "$rigText" RIGFETCHBODY )" 'yes no'
rigText="$( rigResult 64 )"
rigAssert "web lists: an unreadable policy is refused, nothing fetched" "$( rigHas "$rigText" 'the web access policy could not be read' ) $( rigHas "$rigText" RIGFETCHBODY )" 'yes no'
rigText="$( rigResult 44 )"
rigNative WebFetch "prompt is not ignored: the answer is not the plain raw-body answer" \
	"$( rigIsError "$rigText" ) $( rigHas "$rigText" 'raw body follows' )" 'no no'
rigNative WebFetch "prompt comes back marked as not applied, ahead of the body" \
	"$( rigHas "$rigText" 'PROMPT WAS NOT APPLIED' ) $( rigHas "$rigText" 'Reply with the single word RIGPROMPTWORD' ) $( rigHas "$rigText" RIGFETCHBODY )" 'yes yes yes'

## Bash is rerouted to this server's execute, not to a tool named Bash, so its native calls go there.
## NOT covered, because execute differs there: native timeout is milliseconds and execute's is
## seconds, and native run_in_background is execute's background. Both await a ruling.
echo "-- Bash (rerouted to execute) --"
rigNative Bash "command runs, description is accepted, stdout comes back" "$( rigResult 75 )" 'RIGBASHOUT'
rigText="$( rigResult 76 )"
rigNative Bash "a failing command returns its output and its exit code" "$( rigHas "$rigText" RIGBASHFAIL ) $( rigHas "$rigText" '[exit code: 3]' )" 'yes yes'

echo "-- TaskStop --"
rigAssert "control: handle reaches the lookup" "$( rigHas "$( rigResult 45 )" 'matches handle rig-no-such-handle' )" yes
rigNative TaskStop "task_id reaches the lookup" "$( rigHas "$( rigResult 46 )" 'matches handle rig-no-such-handle' )" yes
rigNative TaskStop "shell_id, the deprecated alias, reaches the lookup" "$( rigHas "$( rigResult 47 )" 'matches handle rig-no-such-handle' )" yes

echo "-- PreToolUse hooks see the file --"
rigHookLog="$( cat "$rigTmp/hook.log" 2>/dev/null )"
rigAssert "control: a Write with path reaches the hook as tool_input.file_path" "$( rigHas "$rigHookLog" '"tool_name":"Write","tool_input":{"file_path":"'"$rigW/h-ctl-w.txt"'"' )" yes
rigAssert "control: an Edit with path reaches the hook as tool_input.file_path" "$( rigHas "$rigHookLog" '"tool_name":"Edit","tool_input":{"file_path":"'"$rigW/h-ctl-e.txt"'"' )" yes
rigNative Write "file_path reaches the hook as tool_input.file_path" "$( rigHas "$rigHookLog" '"tool_name":"Write","tool_input":{"file_path":"'"$rigW/h-nat-w.txt"'"' )" yes
rigNative Edit "file_path reaches the hook as tool_input.file_path" "$( rigHas "$rigHookLog" '"tool_name":"Edit","tool_input":{"file_path":"'"$rigW/h-nat-e.txt"'"' )" yes

echo "-- no path given --"
rigText="$( rigResult 52 )"
rigNative Write "no file_path and no path is refused naming file_path, never as outside the write roots" \
	"$( rigIsError "$rigText" ) $( rigHas "$rigText" file_path ) $( rigHas "$rigText" 'allowed write-root set' )" 'yes yes no'
rigText="$( rigResult 53 )"
rigNative Edit "no file_path and no path is refused naming file_path, never as outside the write roots" \
	"$( rigIsError "$rigText" ) $( rigHas "$rigText" file_path ) $( rigHas "$rigText" 'allowed write-root set' )" 'yes yes no'

echo "-- gate: every rerouted tool has a native-call case here, and all of them pass --"
while IFS= read -r rigName ; do
	[ -n "$rigName" ] || continue
	case "$rigNativeTools" in
		*" $rigName "*)
			case "$rigNativeFailed" in
				*" $rigName "*) rigAssert "gate: $rigName native-call cases all pass" "failing or skipped" passing ;;
				*) rigAssert "gate: $rigName native-call cases all pass" passing passing ;;
			esac
		;;
		*) rigAssert "gate: $rigName has a native-call case" missing present ;;
	esac
done <<< "$rigRerouted"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ NATIVE CALL CHECK FAILED: $rigFails assertion(s)" >&2
	echo "  warn: a rerouted tool does not yet answer a call in the native client's names and semantics" >&2
	echo "  fix:  the tool's arm and body in sh-lib/AgentsUniversalHarness.sh, its declaration in" >&2
	echo "        sh-lib/AgentsOpenAiChatWire.sh -- or take the tool off the reroute list; never the assertion" >&2
	exit 1
fi
echo "HARNESS_NATIVE_CALL: OK (every rerouted tool answers native names and semantics, served)"
