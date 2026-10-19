#!/usr/bin/env bash
## Behavioural check on the list form of Edit, `edits`: several edits to one file in one
## call, AS THE MCP SERVER SERVES IT -- every call goes through the real server's
## tools/call, and every answer is read off the wire it writes. Covers: edits applied in
## order; a later edit that matches what an earlier one wrote, and one that misses what an
## earlier one removed; one edit that cannot be applied leaving the file byte for byte as it
## was, named by its position in the single form's own wording; replace_all inside a list;
## both forms in one call, an empty list and a value that is no list, each refused; the
## checks the single form runs once running once here too; the single form itself, its
## result text unchanged; the declaration a client is served; and the line the transcript
## and the tracking post make of such a call.
## Offline: MMDAPP and HOME are this rig's own, and nothing here reaches an endpoint.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"

rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigField="$rigHere/AgentsHarnessJsonField.awk"
rigFormat="$rigHere/AgentsSessionTranscriptFormat.awk"
rigPost="$rigHere/AgentsTools.InternOpEventTrackPost.include"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

for rigFile in "$rigHere/AgentsUniversalHarness.sh" "$rigField" "$rigFormat" "$rigPost" "$rigTool" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessEditListCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigTmp="$( cd "$rigTmp" && pwd -P )"

## `.local/temp` is a write root and `source/` a read root the server computes for a workspace.
rigDir="$rigTmp/.local/temp/team"
rigRead="$rigTmp/source/fix"
mkdir -p "$rigDir" "$rigRead" "$rigTmp/home" "$rigTmp/keep"
printf 'alpha\nbeta\n' > "$rigDir/s-one"
printf 'x\nx\nx\n' > "$rigDir/s-all"
printf 'x\nx\n' > "$rigDir/s-dup"
printf 'alpha\n' > "$rigDir/s-miss"
printf 'alpha\n' > "$rigDir/s-empty"
printf 'one\ntwo\nthree\n' > "$rigDir/l-order"
printf 'alpha\n' > "$rigDir/l-one"
printf 'alpha\nbeta\n' > "$rigDir/l-chain"
printf 'a\nlast' > "$rigDir/l-end"
printf 'alpha\nbeta\n' > "$rigDir/l-alias"
printf 'alpha\nbeta\ngamma\n' > "$rigDir/l-miss"
printf 'alpha\nx\nx\n' > "$rigDir/l-dup"
printf 'alpha\nbeta\n' > "$rigDir/l-empty"
printf 'one two\n' > "$rigDir/l-gone"
printf 'alpha\nx\nx\nx\n' > "$rigDir/l-all"
printf 'alpha\nbeta\n' > "$rigDir/l-both"
printf 'alpha\nbeta\n' > "$rigDir/l-topall"
printf 'alpha\n' > "$rigDir/l-none"
printf 'alpha\n' > "$rigDir/l-scalar"
printf 'alpha\n' > "$rigDir/l-bare"
printf 'alpha\n' > "$rigRead/r-single"
printf 'alpha\n' > "$rigRead/r-list"
## Every file a refused call must leave alone, kept to compare byte for byte afterwards.
for rigName in l-miss l-dup l-empty l-gone l-both l-topall l-none l-scalar l-bare ; do
	cp "$rigDir/$rigName" "$rigTmp/keep/$rigName"
done
cp "$rigRead/r-list" "$rigTmp/keep/r-list"

## Values are passed already JSON-escaped, so the format itself carries no backslash.
rigCall(){ ## request id, arguments JSON -- one Edit tools/call line
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"Edit","arguments":%s}}\n' "$1" "$2"
}
rigEdits(){ ## request id, file path, edits JSON array, further members of the arguments object if any
	rigCall "$1" '{"file_path":"'"$2"'","edits":'"$3${4:+,$4}"'}'
}
{
	rigCall 2 '{"file_path":"'"$rigDir/s-one"'","old_string":"alpha","new_string":"ALPHA"}'
	rigCall 3 '{"file_path":"'"$rigDir/s-all"'","old_string":"x","new_string":"Y","replace_all":true}'
	rigCall 4 '{"file_path":"'"$rigDir/s-dup"'","old_string":"x","new_string":"Y"}'
	rigCall 5 '{"file_path":"'"$rigDir/s-miss"'","old_string":"nope","new_string":"N"}'
	rigCall 6 '{"file_path":"'"$rigDir/s-empty"'","old_string":"","new_string":"N"}'
	rigEdits 7 "$rigDir/l-order" '[{"old_string":"one","new_string":"1"},{"old_string":"two","new_string":"2"},{"old_string":"three","new_string":"3"}]'
	rigEdits 8 "$rigDir/l-one" '[{"old_string":"alpha","new_string":"ALPHA"}]'
	rigEdits 9 "$rigDir/l-chain" '[{"old_string":"alpha","new_string":"ALPHA one"},{"old_string":"ALPHA one\nbeta","new_string":"joined"}]'
	rigEdits 10 "$rigDir/l-end" '[{"old_string":"a\n","new_string":"A\n"},{"old_string":"last","new_string":"LAST"}]'
	rigCall 11 '{"path":"'"$rigDir/l-alias"'","edits":[{"old_text":"alpha","new_text":"ALPHA"},{"old_string":"beta","old_text":"alpha","new_string":"BETA","new_text":"nope"}],"old_string":"","description":"Raise both words"}'
	rigEdits 12 "$rigDir/l-miss" '[{"old_string":"alpha","new_string":"A"},{"old_string":"nope","new_string":"N"},{"old_string":"gamma","new_string":"C"}]'
	rigEdits 13 "$rigDir/l-dup" '[{"old_string":"alpha","new_string":"A"},{"old_string":"x","new_string":"Y"}]'
	rigEdits 14 "$rigDir/l-empty" '[{"old_string":"alpha","new_string":"A"},{"old_string":"","new_string":"N"}]'
	rigEdits 15 "$rigDir/l-gone" '[{"old_string":"one two","new_string":"three"},{"old_string":"one","new_string":"1"}]'
	rigEdits 16 "$rigDir/l-all" '[{"old_string":"alpha","new_string":"A"},{"old_string":"x","new_string":"Y","replace_all":true}]'
	rigEdits 17 "$rigDir/l-both" '[{"old_string":"beta","new_string":"B"}]' '"old_string":"alpha","new_string":"A"'
	rigEdits 18 "$rigDir/l-topall" '[{"old_string":"beta","new_string":"B"}]' '"replace_all":true'
	rigEdits 19 "$rigDir/l-none" '[]'
	rigEdits 20 "$rigDir/l-scalar" '"[{\"old_string\":\"alpha\",\"new_string\":\"A\"}]"'
	rigEdits 21 "$rigDir/l-bare" '{"old_string":"alpha","new_string":"A"}'
	rigCall 22 '{"file_path":"'"$rigRead/r-single"'","old_string":"alpha","new_string":"A"}'
	rigEdits 23 "$rigRead/r-list" '[{"old_string":"alpha","new_string":"A"}]'
	rigEdits 24 "$rigDir/l-absent" '[{"old_string":"alpha","new_string":"A"}]'
	rigCall 25 '{"edits":[{"old_string":"alpha","new_string":"A"}]}'
	printf '%s\n' '{"jsonrpc":"2.0","id":26,"method":"tools/list"}'
} | ( cd "$rigTmp" && MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" HOME="$rigTmp/home" \
	bash "$rigTool" --intern-mcp-server --run ) > "$rigTmp/wire" 2> "$rigTmp/err" || :

## A request the server never answered was never exercised, so the run stops there.
rigId=2
while [ "$rigId" -le 26 ] ; do
	LC_ALL=C grep -q "^{\"jsonrpc\":\"2.0\",\"id\":$rigId," "$rigTmp/wire" || {
		echo "-- the server left request $rigId unanswered, so its stderr follows --" >&2
		sed 's/^/    /' "$rigTmp/err" >&2
		rigRefuse "no answer for request $rigId"
	}
	rigId=$(( rigId + 1 ))
done

rigPart(){ ## request id, json path under result -- the decoded value, empty when absent
	LC_ALL=C grep -m1 "^{\"jsonrpc\":\"2.0\",\"id\":$1," "$rigTmp/wire" | LC_ALL=C awk -v path="result.$2" -v optional=1 -f "$rigField" 2>/dev/null || :
}

## The first line of the tool's own result: the last text part, since the head part goes first.
rigResult(){ ## request id
	local partIndex
	partIndex="$( rigPart "$1" content.__count )"
	partIndex=$(( ${partIndex:-0} - 1 ))
	while [ "$partIndex" -ge 0 ] ; do
		[ "$( rigPart "$1" "content.$partIndex.type" )" != text ] || { rigPart "$1" "content.$partIndex.text" | head -n 1 ; return 0 ; }
		partIndex=$(( partIndex - 1 ))
	done
}

## Every byte, one character per field, so a newline shows as \n and nothing is trimmed.
rigBytes(){ ## file path
	[ -f "$1" ] || { printf 'MISSING' ; return 0 ; }
	od -An -c "$1" | tr -d ' \n'
}

## Whether a refused call left its file byte for byte as it was.
rigKept(){ ## file path
	cmp -s "$1" "$rigTmp/keep/$( basename "$1" )" && printf 'unchanged' || printf 'CHANGED'
}

## The single form's own refusal, said of another file and of one edit in a list.
rigWording(){ ## the single form's result, its file name, the list's file name, position, count
	local wordingText="${1#ERROR: }"
	printf 'ERROR: edit %s of %s failed, none was applied: %s' "$4" "$5" "${wordingText//$rigDir\/$2/$rigDir/$3}"
}

rigHas(){ ## text, needle -- yes when the text holds it
	case "$1" in *"$2"*) printf 'yes' ;; *) printf 'no' ;; esac
}

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

echo "-- control: the single form, its result text as it always was --"
rigAssert "one edit changes the file"                    "$( rigBytes "$rigDir/s-one" )" 'ALPHA\nbeta\n'
rigAssert "and says so"                                  "$( rigResult 2 )" "OK: replaced one occurrence in $rigDir/s-one"
rigAssert "replace_all changes every occurrence"         "$( rigBytes "$rigDir/s-all" )" 'Y\nY\nY\n'
rigAssert "and says how many"                            "$( rigResult 3 )" "OK: replaced 3 occurrence(s) in $rigDir/s-all"
rigSingleDup="$( rigResult 4 )"
rigAssert "an old_string that occurs twice is refused"   "$rigSingleDup" "ERROR: old_string occurs 2 times in $rigDir/s-dup -- it must identify exactly one place. Nothing was written; extend old_string until it is unique, or pass replace_all to change every occurrence."
rigSingleMiss="$( rigResult 5 )"
rigAssert "an old_string that is not there is refused"   "$rigSingleMiss" "ERROR: old_string not found in $rigDir/s-miss -- nothing was written"
rigSingleEmpty="$( rigResult 6 )"
rigAssert "an empty old_string is refused"               "$rigSingleEmpty" "ERROR: old_string is empty -- an empty match has no unique position"

echo "-- several edits to one file, applied in order --"
rigAssert "three edits change three places"              "$( rigBytes "$rigDir/l-order" )" '1\n2\n3\n'
rigAssert "one OK line says how many were applied"       "$( rigResult 7 )" "OK: applied 3 edit(s) in $rigDir/l-order"
rigAssert "a list of one is a list"                      "$( rigBytes "$rigDir/l-one" ) $( rigResult 8 )" "ALPHA\\n OK: applied 1 edit(s) in $rigDir/l-one"
rigAssert "a later edit matches what an earlier one wrote" "$( rigBytes "$rigDir/l-chain" ) $( rigResult 9 )" "joined\\n OK: applied 2 edit(s) in $rigDir/l-chain"
rigAssert "a file with no final newline gains none"      "$( rigBytes "$rigDir/l-end" )" 'A\nLAST'
rigAssert "a list reads path, old_text and new_text too, old_string and new_string win where an edit gives both, and an empty top-level old_string is no second form" "$( rigBytes "$rigDir/l-alias" ) $( rigResult 11 )" "ALPHA\\nBETA\\n OK: applied 2 edit(s) in $rigDir/l-alias"

echo "-- one edit that cannot be applied: nothing is written, and it is named --"
rigAssert "the second of three is not there: named by position, in the single form's wording" "$( rigResult 12 )" "$( rigWording "$rigSingleMiss" s-miss l-miss 2 3 )"
rigAssert "and the file is byte for byte as it was, the first edit not applied" "$( rigKept "$rigDir/l-miss" )" unchanged
rigAssert "the second of two occurs twice: named, in the single form's wording" "$( rigResult 13 )" "$( rigWording "$rigSingleDup" s-dup l-dup 2 2 )"
rigAssert "and the file is as it was"                    "$( rigKept "$rigDir/l-dup" )" unchanged
rigAssert "the second of two has an empty old_string: named, in the single form's wording" "$( rigResult 14 )" "$( rigWording "$rigSingleEmpty" s-empty l-empty 2 2 )"
rigAssert "and the file is as it was"                    "$( rigKept "$rigDir/l-empty" )" unchanged
rigAssert "a later edit misses what an earlier one removed" "$( rigResult 15 )" "$( rigWording "$rigSingleMiss" s-miss l-gone 2 2 )"
rigAssert "and the file is as it was"                    "$( rigKept "$rigDir/l-gone" )" unchanged
rigAssert "no refused call left a temp file or a lock behind" "$( ls -A "$rigDir" | LC_ALL=C grep -c 'mdat-edit' ) $( ls -A "$rigTmp/.local/agents/locks" 2>/dev/null | LC_ALL=C grep -c . )" "0 0"

echo "-- replace_all inside a list --"
rigAssert "it changes every occurrence, the edit beside it one" "$( rigBytes "$rigDir/l-all" )" 'A\nY\nY\nY\n'
rigAssert "and the OK line says how many that edit replaced" "$( rigResult 16 )" "OK: applied 2 edit(s) in $rigDir/l-all -- edit 2 replaced 3 occurrence(s)"

echo "-- one form per call, and a list that is one --"
rigAssert "edits beside a top-level old_string and new_string is refused" "$( rigHas "$( rigResult 17 )" 'ERROR: edits was given together with a top-level old_string, new_string or replace_all' ) $( rigKept "$rigDir/l-both" )" "yes unchanged"
rigAssert "edits beside a top-level replace_all is refused" "$( rigHas "$( rigResult 18 )" 'ERROR: edits was given together with a top-level old_string, new_string or replace_all' ) $( rigKept "$rigDir/l-topall" )" "yes unchanged"
rigAssert "an empty list is refused"                     "$( rigHas "$( rigResult 19 )" 'ERROR: edits is an empty list' ) $( rigKept "$rigDir/l-none" )" "yes unchanged"
rigAssert "a list sent as one string is refused"         "$( rigHas "$( rigResult 20 )" 'ERROR: edits must be an array of edits' ) $( rigKept "$rigDir/l-scalar" )" "yes unchanged"
rigAssert "one edit sent bare, not in a list, is refused" "$( rigHas "$( rigResult 21 )" 'ERROR: edits must be an array of edits' ) $( rigKept "$rigDir/l-bare" )" "yes unchanged"

echo "-- the checks the single form runs once run once here too --"
rigSingleRefused="$( rigResult 22 )"
rigAssert "control: the single form is refused outside the write roots" "$rigSingleRefused" "ERROR: path not in the allowed write-root set -- it may still be readable: $rigRead/r-single"
rigAssert "a list is refused there in the same words"   "$( rigResult 23 )" "${rigSingleRefused%r-single}r-list"
rigAssert "and its file is as it was"                    "$( rigKept "$rigRead/r-list" )" unchanged
rigAssert "a list for a file that is not there says so"  "$( rigResult 24 )" "ERROR: no such file: $rigDir/l-absent"
rigAssert "a list with no path is refused before anything else" "$( rigHas "$( rigResult 25 )" 'ERROR: no path was given -- pass file_path, or path. Keys received: edits.' )" yes

echo "-- the declaration a client is served --"
rigEditAt=""
rigAt=0
while : ; do
	rigName="$( rigPart 26 "tools.$rigAt.name" )"
	[ -n "$rigName" ] || break
	[ "$rigName" != Edit ] || { rigEditAt="$rigAt" ; break ; }
	rigAt=$(( rigAt + 1 ))
done
[ -n "$rigEditAt" ] || rigRefuse "the server's tools/list names no Edit tool"
rigSchema="tools.$rigEditAt.inputSchema.properties"
rigAssert "edits is declared as a list of objects"       "$( rigPart 26 "$rigSchema.edits.type" ) $( rigPart 26 "$rigSchema.edits.items.type" )" "array object"
rigAssert "each with old_string, new_string and replace_all" "$( rigPart 26 "$rigSchema.edits.items.properties.old_string.type" ) $( rigPart 26 "$rigSchema.edits.items.properties.new_string.type" ) $( rigPart 26 "$rigSchema.edits.items.properties.replace_all.type" )" "string string boolean"
rigAssert "and with old_text and new_text, declared in the top level's own words" \
	"$( rigPart 26 "$rigSchema.edits.items.properties.old_text.description" )|$( rigPart 26 "$rigSchema.edits.items.properties.new_text.description" )" "$( rigPart 26 "$rigSchema.old_text.description" )|$( rigPart 26 "$rigSchema.new_text.description" )"
rigAssert "which state the precedence, and an edit requires neither name of a pair" "$( rigHas "$( rigPart 26 "$rigSchema.edits.items.properties.old_text.description" )" 'old_string wins when both are given' ) $( rigHas "$( rigPart 26 "$rigSchema.edits.items.properties.new_text.description" )" 'new_string wins when both are given' ) $( rigPart 26 "$rigSchema.edits.items.required.__count" )" "yes yes 0"
rigAssert "the tool description says where several changes go" "$( rigHas "$( rigPart 26 "tools.$rigEditAt.description" )" 'Several changes to one file that belong to one logical change go in one call with edits.' )" yes
rigAssert "every parameter of the single form is still declared" \
	"$( for rigName in file_path old_string new_string replace_all path old_text new_text description ; do printf '%s ' "$( rigPart 26 "$rigSchema.$rigName.type" )" ; done )" "string string string boolean string string string string "
rigAssert "and none of them became required"             "$( rigPart 26 "tools.$rigEditAt.inputSchema.required.__count" )" 0

echo "-- the transcript line of such a call --"
rigLine="$( printf '%s' '{"file_path":"/x/f.sh","edits":[{"old_string":"a, [b] {c} RIG-BODY","new_string":"d\"], x"},{"old_string":"e","new_string":"f","replace_all":true}],"description":"Two fixes"}' \
	| STL_TS=T0 STL_TOOL=mcp__myx_distro__Edit STL_OUTCOME=ok STL_BYTES=31 STL_LINES=1 STL_DUR_MS=12 LC_ALL=C awk -v stlStandalone=tool -f "$rigFormat" )"
rigAssert "it names the file and how many edits, and no edit's own replace_all or text" "$rigLine" 'T0 TOOL mcp__myx_distro__Edit path=/x/f.sh edits=2 -> ok 31B/1L 12ms | "Two fixes"'
rigLine="$( printf '%s' '{"path":"/x/f.sh","edits":[{"old_string":"a","new_string":"b"},{"old_string":"nope","new_string":"c"}]}' \
	| STL_TS=T0 STL_TOOL=Edit STL_OUTCOME=error STL_FIRST='ERROR: edit 2 of 2 failed, none was applied: old_string not found in /x/f.sh -- nothing was written' LC_ALL=C awk -v stlStandalone=tool -f "$rigFormat" )"
rigAssert "a refused list says which edit, and why"      "$rigLine" 'T0 TOOL Edit path=/x/f.sh edits=2 -> error "ERROR: edit 2 of 2 failed, none was applied: old_string not found in /x/f.sh -- nothing was written"'
rigLine="$( printf '%s' '{"file_path":"/x/f.sh","edits":[]}' | STL_TS=T0 STL_TOOL=Edit STL_OUTCOME=error STL_FIRST='ERROR: edits is an empty list' LC_ALL=C awk -v stlStandalone=tool -f "$rigFormat" )"
rigAssert "an empty list reads as none"                  "$rigLine" 'T0 TOOL Edit path=/x/f.sh edits=0 -> error "ERROR: edits is an empty list"'
rigLine="$( printf '%s' '{"file_path":"/x/f.sh","old_string":"\"edits\": [1, 2]","new_string":"b","replace_all":true}' | STL_TS=T0 STL_TOOL=Edit STL_OUTCOME=ok LC_ALL=C awk -v stlStandalone=tool -f "$rigFormat" )"
rigAssert "control: the single form's line is as it was, whatever its text holds" "$rigLine" 'T0 TOOL Edit path=/x/f.sh replace_all=true -> ok'

echo "-- the tracking post line of such a call --"
cat > "$rigTmp/lines" <<'RIG_LINES_EOF'
2030-01-01T00:01:03Z TOOL Edit path=/w/sh-lib/AgentsUniversalHarness.sh edits=3 -> ok 40B/1L 10ms
2030-01-01T00:01:04Z TOOL mcp__myx_distro__Edit path=/w/sh-lib/One.sh edits=1 -> ok 40B/1L 10ms | "Fix the one line"
2030-01-01T00:01:05Z TOOL Edit path=/w/sh-lib/Plain.sh -> ok 40B/1L 10ms
2030-01-01T00:01:06Z TOOL Edit path=/w/sh-lib/Bad.sh edits=2 -> error "ERROR: edit 2 of 2 failed, none was applied: old_string not found in /w/sh-lib/Bad.sh -- nothing was written" 120B/1L 3ms
RIG_LINES_EOF
mkdir -p "$rigTmp/render-ws/.local/.agents" "$rigTmp/post"
## Sourced with a first argument that names no op, the include only defines its functions.
(
	set -- --rig-none
	MDSC_CMD=rig
	unset MDAT_SKILLSET_ROOT
	. "$rigPost"
	MMDAPP="$rigTmp/render-ws" AgentsEventTrackPostRender feed magic-tester "abcdef01-2345-4000-8000-000000000001" "$rigTmp/post" "$rigTmp/lines"
) > /dev/null 2> "$rigTmp/post.err" || rigRefuse "the tracking post did not render: $( head -n 3 "$rigTmp/post.err" | tr '\n' ' ' )"
rigPlain="$rigTmp/post/000001.plain.001"
[ -f "$rigPlain" ] || rigRefuse "the tracking post rendered no plain text to read: $rigPlain"
rigCount(){ ## fixed line -- how many lines of the post are exactly it
	LC_ALL=C grep -c -x -F -- "$1" "$rigPlain" 2>/dev/null || :
}
rigAssert "a list names its file, and its outcome says how many edits" "$( rigCount '✏️ Edit `AgentsUniversalHarness.sh` → 3 edits' )" 1
rigAssert "one edit in a list is one edit"               "$( rigCount '✏️ Fix the one line — Edit `sh-lib/One.sh` → 1 edit' )" 1
rigAssert "control: the single form's line is as it was" "$( rigCount '✏️ Edit `sh-lib/Plain.sh` → ok' )" 1
rigAssert "a refused list renders as an error naming the edit" "$( rigCount '⛔ Edit `sh-lib/Bad.sh` → error: ERROR: edit 2 of 2 failed, none was applied: old_string not found in /w/sh-lib/Bad.sh -- nothing was written' )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ EDIT LIST CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  fix:  the list form in AgentsHarnessToolEdit, sh-lib/AgentsUniversalHarness.sh, its declaration in" >&2
	echo "        sh-lib/AgentsOpenAiChatWire.sh, or the Edit line of the two formatters -- never the assertion" >&2
	exit 1
fi
printf 'HARNESS_EDIT_LIST: OK (%d assertions, served, offline)\n' "$rigPassCount"
