#!/usr/bin/env bash
## Equivalence check on the parse-once argument table: for a corpus of tool-call argument
## documents -- escapes, \u pairs, trailing newlines, duplicate keys, a dotted key beside
## a nested one, `-n`-style keys, arrays, malformed input -- every lookup the harness
## answers from AgentsHarnessArgTable.awk must be BYTE FOR BYTE what the field reader
## AgentsHarnessJsonField.awk answers for the same path, which is what every lookup was
## before the table existed. Covers AgentsHarnessArgValue on the cached and uncached
## paths, the harnessArgV_*/harnessArgD_* variables, and AgentsHarnessArgExact with and
## without its alias. The functions under test are lifted out of the harness by their
## own names, so this exercises the shipped code. Offline: no request, no host.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigHarness="$rigHere/AgentsUniversalHarness.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigHarness" "$rigHere/AgentsHarnessArgTable.awk" "$rigHere/AgentsHarnessJsonField.awk" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

## Each function from its own `Name(){` line to the first line that is a lone `}`.
rigLift="$( LC_ALL=C awk '
	/^(AgentsHarnessArgParse|AgentsHarnessArgFind|AgentsHarnessArgValue|AgentsHarnessArgExact)\(\)\{/ { inFn = 1 ; }
	inFn { print ; }
	inFn && /^\}$/ { inFn = 0 ; seen++ ; }
	END { if ( seen != 4 ) exit 1 ; }
' "$rigHarness" )" || rigRefuse "the four argument-table functions were not all found in $rigHarness"
harnessHere="$rigHere"
harnessArgRaw="" harnessArgParsed=0 harnessArgPaths=() harnessArgEncs=() harnessArgFound="" harnessArgExact=""
eval "$rigLift"

## The reference -- the differential side: AgentsHarnessArgValue's body exactly as every
## lookup ran it before the table, the field reader once per path.
rigRef(){ ## raw, path
	printf '%s\n' "$1" | LC_ALL=C awk -v path="$2" -v optional=1 -f "$rigHere/AgentsHarnessJsonField.awk" 2>/dev/null || :
}
rigRefExact(){ ## raw, key, alias
	local refRaw="$1" refKey="$2" refOut
	[ -z "$3" ] || printf '%s\n' "$refRaw" | LC_ALL=C awk -v path="$refKey" -v optional=1 -f "$rigHere/AgentsHarnessJsonField.awk" >/dev/null 2>&1 || refKey="$3"
	refOut="$( rigRef "$refRaw" "$refKey" ; printf 'x' )"
	refOut="${refOut%x}"
	printf '%sx' "${refOut%$'\n'}"
}

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPass=$(( rigPass + 1 ))
	else
		rigFail=$(( rigFail + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$( printf '%s' "$2" | od -An -c | tr -s ' \n' ' ' )" "$( printf '%s' "$3" | od -An -c | tr -s ' \n' ' ' )"
	fi
}

rigCorpus=()
rigCorpus+=( '{"pattern":"alpha","path":"/x/y","-n":true,"-A":3,"-C":"2","output_mode":"content"}' )
rigCorpus+=( '{"content":"line1\nline2\n\n","x":"tab\there","bs":"back\\slash\\n and \\c","q":"\"quoted\"","nl":"\n\n","pct":"%s %b %% \\0101"}' )
rigCorpus+=( '{"u":"\u00e9 \ud83d\ude00 \u0041","lone":"\ud83d x","slash":"a\/b","ctl":"\b\f\r"}' )
rigCorpus+=( '{"options":[{"label":"a","description":"A\n"},{"label":"b"}],"meta":{"k":"v","deep":{"z":[1,2,[]]}},"n":12.5e3,"t":true,"f":false,"z":null,"e":"","arr":[]}' )
rigCorpus+=( '{"a":"first","a":"second","b":{"c":1},"b":{"c":2}}' )
rigCorpus+=( '{"a.b":"top","a":{"b":"nested"}}' )
rigCorpus+=( '{"k	ey":"tab in key","new
line":"raw newline in key","":"empty key","-":"dash","-x-y":"dash-word","9lives":"digit"}' )
rigCorpus+=( '{
  "command": "ls -la\n",
  "cwd" : "/tmp" ,
  "trail": "x\\"
}' )
rigCorpus+=( '{"raw":"bytes é ü 日本 '$'\x80\xff''","cr":"a'$'\r''b"}' )
## A backslash right before a newline, and right before a TAB, in values and in keys --
## the encoding's own hard case, which an encoder built on split() got wrong on one awk.
rigCorpus+=( '{"c":"x\\\ny","bt":"\\\t|\\\\\n","k\\\ney":"v\\"}' )
rigCorpus+=( '{}' )
rigCorpus+=( '  {"padded":"yes"}  ' )
rigCorpus+=( '{"a":' )
rigCorpus+=( 'not json at all' )
rigCorpus+=( '' )
rigCorpus+=( '{"a":"\u12"}' )
rigCorpus+=( '{"a":1} trailing' )
rigCorpus+=( '{"a" 1}' )
rigCorpus+=( '[1,2]' )
rigCorpus+=( '{"unterminated":"abc}' )
## The optional description every tool declares, beside a tool's own arguments.
rigCorpus+=( '{"pattern":"needle","path":"/x","-n":true,"description":"Find the needle; \"why\" it matters\n"}' )

## Paths asked of every document: each it holds, plus ones it does not.
rigProbePaths=( c bt "k\\"$'\n'"ey" pattern path -n -A -C -o content x bs q nl pct u lone slash ctl options options.0.label options.0.description options.__count options.1.label meta meta.k meta.deep.z.__count meta.deep.z.2.__count n t f z e arr arr.__count a a.b b.c '' '-' -x-y 9lives command cwd trail raw cr padded missing k$'\t'ey new$'\n'line description )
rigVarPaths=( c bt pattern path content x bs q nl pct u lone slash ctl options meta n t f z e arr a b command cwd trail raw cr padded missing 9lives description )
rigDashPaths=( n A C o )

rigDocIndex=0
for rigDoc in "${rigCorpus[@]}" ; do
	rigDocIndex=$(( rigDocIndex + 1 ))
	## Uncached first: a different raw string must go to the reader itself.
	harnessArgParsed=0 harnessArgRaw=""
	for rigPath in "${rigProbePaths[@]}" ; do
		rigAssert "doc $rigDocIndex uncached [$rigPath]" "$( AgentsHarnessArgValue "$rigDoc" "$rigPath" ; printf x )" "$( rigRef "$rigDoc" "$rigPath" ; printf x )"
	done
	AgentsHarnessArgParse "$rigDoc"
	for rigPath in "${rigProbePaths[@]}" ; do
		rigAssert "doc $rigDocIndex cached [$rigPath]" "$( AgentsHarnessArgValue "$rigDoc" "$rigPath" ; printf x )" "$( rigRef "$rigDoc" "$rigPath" ; printf x )"
	done
	## Named outright rather than by a bracket range, which is collation-dependent.
	for rigPath in "${rigVarPaths[@]}" ; do
		eval "rigGot=\"\${harnessArgV_$rigPath-}\""
		rigAssert "doc $rigDocIndex var [$rigPath]" "${rigGot}x" "$( rigRef "$rigDoc" "$rigPath" )x"
	done
	for rigPath in "${rigDashPaths[@]}" ; do
		eval "rigGot=\"\${harnessArgD_$rigPath-}\""
		rigAssert "doc $rigDocIndex var [-$rigPath]" "${rigGot}x" "$( rigRef "$rigDoc" "-$rigPath" )x"
	done
	for rigPair in 'content:' 'nl:' 'missing:' 'content:nl' 'missing:nl' 'missing:content' 'e:nl' 'a:b' ; do
		AgentsHarnessArgExact "$rigDoc" "${rigPair%%:*}" "${rigPair#*:}"
		rigAssert "doc $rigDocIndex exact [$rigPair]" "${harnessArgExact}x" "$( rigRefExact "$rigDoc" "${rigPair%%:*}" "${rigPair#*:}" )"
	done
done

## A variable left from one call must not answer for the next.
AgentsHarnessArgParse '{"pattern":"one","-n":true}'
AgentsHarnessArgParse '{"path":"two"}'
rigAssert "a later call clears an earlier call's variables" "${harnessArgV_pattern-unset}:${harnessArgD_n-unset}:${harnessArgV_path-unset}" "unset:unset:two"

## The table is built once per raw string: a second parse of the same string forks nothing.
AgentsHarnessArgParse '{"pattern":"three"}'
harnessArgPaths+=( sentinel ) harnessArgEncs+=( kept )
AgentsHarnessArgParse '{"pattern":"three"}'
rigAssert "the same string is not parsed twice" "$( AgentsHarnessArgFind sentinel && printf '%s' "$harnessArgFound" )" kept

## The optional description every tool declares is one more key: held like any other, and
## every argument the tool acts on reads exactly as it does without it.
AgentsHarnessArgParse '{"pattern":"needle","path":"/x","-n":true,"head_limit":5}'
rigNoIntent="${harnessArgV_pattern-}|${harnessArgV_path-}|${harnessArgD_n-}|${harnessArgV_head_limit-}|${harnessArgV_description-unset}"
AgentsHarnessArgParse '{"description":"Find the needle","pattern":"needle","path":"/x","-n":true,"head_limit":5}'
rigAssert "a description leaves every other argument as it was" "${harnessArgV_pattern-}|${harnessArgV_path-}|${harnessArgD_n-}|${harnessArgV_head_limit-}" "${rigNoIntent%|*}"
rigAssert "and is held as harnessArgV_description, absent without one" "${harnessArgV_description-unset}:${rigNoIntent##*|}" "Find the needle:unset"

## The per-line mode, as the MCP client's AgentsHarnessMcpReply reads a server's stdout:
## the last whole line whose `id` is the awaited one, exactly as the one-awk-per-line loop
## it replaced found it.
rigReplyLift="$( LC_ALL=C awk '
	/^AgentsHarnessMcpReply\(\)\{/ { inFn = 1 ; }
	inFn { print ; }
	inFn && /^\}$/ { inFn = 0 ; seen++ ; }
	END { if ( seen != 1 ) exit 1 ; }
' "$rigHere/AgentsHarnessMcpClient.sh" )" || rigRefuse "AgentsHarnessMcpReply was not found in AgentsHarnessMcpClient.sh"
. "$rigHere/AgentsHarnessMcpConfig.include"
eval "$rigReplyLift"
rigReplyRef(){ ## request id -- the loop as it was
	local replyWant="$1" replyLine replyId replyFound=""
	while IFS= read -r replyLine ; do
		[ -n "$replyLine" ] || continue
		replyId="$( printf '%s\n' "$replyLine" | LC_ALL=C awk -v path=id -v optional=1 -f "$rigHere/AgentsHarnessJsonField.awk" 2>/dev/null )" || replyId=""
		[ "$replyId" != "$replyWant" ] || replyFound="$replyLine"
	done < "$harnessScratch/mcp.out"
	printf '%s' "$replyFound"
}
harnessScratch="$( mktemp -d -t AgentsHarnessArgTableCheck )" || exit 1
trap 'rm -rf -- "$harnessScratch"' EXIT
rigReplyCase(){ ## what, mcp.out content
	printf '%s' "$2" > "$harnessScratch/mcp.out"
	for rigWant in 1 2 3 4 ; do
		harnessMcpReply=""
		AgentsHarnessMcpReply "$rigWant" || :
		rigAssert "reply [$1] id $rigWant" "${harnessMcpReply}x" "$( rigReplyRef "$rigWant" )x"
	done
}
rigReplyCase "empty" ''
rigReplyCase "a banner and both answers" 'server starting
{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2024-11-05"}}
{"jsonrpc":"2.0","method":"notifications/message","params":{"id":2}}

{"jsonrpc":"2.0","id":2,"result":{"tools":[{"name":"t","description":"a\\b \"q\" é\n"}]}}
'
rigReplyCase "string, escaped and repeated ids" '{"id":"3","result":1}
{"id":"3","result":"escaped"}
{"id":3.0,"result":"float"}
{"result":{"id":3}}
{"id":3,"id":4,"result":"dup"}
{"id":"3\n","result":"trailing newline"}
'
rigReplyCase "an unfinished last line" '{"id":1,"result":"whole"}
{"id":2,"result":"whole"}
{"id":2,"result":"not finished'
rigReplyCase "no newline anywhere" '{"id":1,"result":"never finished"}'
rigReplyCase "carriage returns and junk" '{"id":1,"result":"cr"}'$'\r''
{"id":1 broken
not json {"id":1}
{"id":4,"result":"tab	inside"}
'

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ ARG TABLE CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	echo "  fix:  AgentsHarnessArgTable.awk or AgentsHarnessArgParse in sh-lib/AgentsUniversalHarness.sh -- never the assertion" >&2
	exit 1
fi
printf 'HARNESS_ARG_TABLE: OK (%d documents, %d assertions, every lookup byte-identical to the field reader, offline)\n' "${#rigCorpus[@]}" "$rigPass"
