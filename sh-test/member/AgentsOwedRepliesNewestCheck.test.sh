#!/usr/bin/env bash
## Behavioural check on AgentsToolsOwedRepliesNewest (sh-lib/member/AgentsTools.OwedReplies.include), the one reader of the owed store for a place to answer. Held:
##   1. NO STORE: the call returns 1, sets nothing and makes no folder. The store is tested with [ -s ] before anything else runs.
##   2. THE NEWEST LINE wins. A tie goes to the later line. The channel filter and the user filter each narrow the pick.
##   3. THE AGE BOUND skips a line older than the bound and keeps a younger one. A bound of 0 or an empty bound means none.
##   4. A LINE OF ANOTHER DRIVER is skipped silently. A slack line that is malformed is said once on stderr and dropped from the store.
##   5. NO FORK: the whole read works in a shell whose PATH holds no program, so it used no awk, no mkdir and no subshell.
## Red before the change: the function does not exist, so every call answers 127 and no assertion holds.
## Offline: a temp workspace, no Slack.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-lib/member/AgentsTools.OwedReplies.include" ] || rigRefuse "the owed-replies include is not in the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsOwedRepliesNewestCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 )) ; printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}
export MMDAPP="$rigTmp"
. "$rigPackage/sh-lib/member/AgentsTools.OwedReplies.include" || exit 1
rigFolder="$rigTmp/.local/agents/schedule/owed"
rigFile="$rigFolder/keeper-rig"
rigErr="$rigTmp/newest.err"
## One call: prints `<rc>:<value>`, the value empty where nothing was set. The stderr of the call is kept in rigErr.
rigNewest(){ ## the arguments after the out variable
	local newestOut="" newestRc=0
	AgentsToolsOwedRepliesNewest newestOut "$@" 2> "$rigErr" || newestRc=$?
	printf '%s:%s' "$newestRc" "$newestOut"
}
rigStore(){ ## the lines of the store, each a TAB-separated epoch, address, user, text
	mkdir -p "$rigFolder" && : > "$rigFile" || rigRefuse "the rig could not make its owed store"
	local storeLine
	for storeLine in "$@" ; do printf '%b\n' "$storeLine" >> "$rigFile" ; done
}

echo "-- 1. no store: 1, nothing set, no folder made --"
rigAssert "no store answers 1 with no value" "$( rigNewest keeper-rig )" "1:"
rigAssert "and made no folder" "$( [ -d "$rigFolder" ] && printf made || printf none )" none
rigAssert "a bad member name answers 1" "$( rigNewest 'Bad Name' )" "1:"
rigStore
rigAssert "an empty store answers 1" "$( rigNewest keeper-rig )" "1:"

echo "-- 2. the newest line wins, filters narrow --"
rigStore '100\tslack:C0RIG0001:1.100000\tUPERSON1\tfirst' '300\tslack:C0RIG0002:3.300000\tUPERSON2\tthird' '200\tslack:C0RIG0001:2.200000\tUPERSON1\tsecond'
rigAssert "the newest line of the store" "$( rigNewest keeper-rig )" "0:C0RIG0002:3.300000"
rigAssert "the channel filter picks the newest of that channel" "$( rigNewest keeper-rig C0RIG0001 )" "0:C0RIG0001:2.200000"
rigAssert "a channel with no line answers 1" "$( rigNewest keeper-rig C0RIG0009 )" "1:"
rigAssert "the user filter picks the newest of that account" "$( rigNewest keeper-rig '' UPERSON1 )" "0:C0RIG0001:2.200000"
rigAssert "both filters together" "$( rigNewest keeper-rig C0RIG0002 UPERSON1 )" "1:"
rigStore '400\tslack:C0RIG0001:4.400000\tUPERSON1\tolder line' '400\tslack:C0RIG0001:5.500000\tUPERSON1\tlater line'
rigAssert "a tie goes to the later line" "$( rigNewest keeper-rig )" "0:C0RIG0001:5.500000"

echo "-- 3. the age bound --"
rigStore '1000\tslack:C0RIG0001:1.100000\tUPERSON1\told' '1900\tslack:C0RIG0002:2.200000\tUPERSON1\tyoung'
rigAssert "a bound of 500 at 2000 drops the line 1000 seconds old" "$( rigNewest keeper-rig C0RIG0001 '' 500 2000 )" "1:"
rigAssert "and keeps the line 100 seconds old" "$( rigNewest keeper-rig C0RIG0002 '' 500 2000 )" "0:C0RIG0002:2.200000"
rigAssert "a bound of 1500 keeps both, the newest wins" "$( rigNewest keeper-rig '' '' 1500 2000 )" "0:C0RIG0002:2.200000"
rigAssert "a bound of 0 means none" "$( rigNewest keeper-rig C0RIG0001 '' 0 999999 )" "0:C0RIG0001:1.100000"
rigAssert "an empty bound means none" "$( rigNewest keeper-rig C0RIG0001 '' '' 999999 )" "0:C0RIG0001:1.100000"
rigAssert "a line exactly at the bound is kept" "$( rigNewest keeper-rig C0RIG0001 '' 1000 2000 )" "0:C0RIG0001:1.100000"
rigAssert "a line one second past the bound is dropped" "$( rigNewest keeper-rig C0RIG0001 '' 999 2000 )" "1:"

echo "-- 4. another driver is skipped silently, a malformed slack line is said once --"
rigStore '100\temail:someone@example.com\tUPERSON1\tmail' '200\tslack:C0RIG0001:2.200000\tUPERSON1\tgood'
rigAssert "the other driver is skipped and the slack line is found" "$( rigNewest keeper-rig )" "0:C0RIG0001:2.200000"
rigAssert "and nothing was said" "$( wc -c < "$rigErr" | tr -d ' ' )" "0"
rigStore '900\tslack:C0RIG0001\tUPERSON1\tno ts' '800\tslack:c0rig0001:1.100000\tUPERSON1\tlowercase channel' '700\tslack:C0RIG0001:1.2.3\tUPERSON1\ttwo dots' '200\tslack:C0RIG0001:2.200000\tUPERSON1\tgood'
rigAssert "the malformed lines never win" "$( rigNewest keeper-rig )" "0:C0RIG0001:2.200000"
rigAssert "each is said once on stderr" "$( LC_ALL=C grep -c '^WARNING: the owed store of keeper-rig held the line slack:' "$rigErr" )" "3"
rigAssert "and each is dropped from the store" "$( wc -l < "$rigFile" | tr -d ' ' ):$( LC_ALL=C grep -c 'good' "$rigFile" )" "1:1"
rigAssert "the second call says nothing" "$( rigNewest keeper-rig >/dev/null ; wc -c < "$rigErr" | tr -d ' ' )" "0"

echo "-- 5. no fork: a shell with no program on its PATH still answers --"
rigStore '100\tslack:C0RIG0001:1.100000\tUPERSON1\tfirst' '300\tslack:C0RIG0002:3.300000\tUPERSON2\tthird' '1000\tslack:C0RIG0003:4.400000\tUPERSON3\tfourth'
rigAssert "the newest line, with an empty PATH" "$( PATH="$rigTmp/no-program" ; rigNewest keeper-rig C0RIG0002 UPERSON2 )" "0:C0RIG0002:3.300000"
rigAssert "the age bound with the epoch given, with an empty PATH" "$( PATH="$rigTmp/no-program" ; rigNewest keeper-rig C0RIG0003 '' 100 1050 )" "0:C0RIG0003:4.400000"
rigAssert "no store, with an empty PATH, answers 1" "$( PATH="$rigTmp/no-program" ; rigNewest keeper-nobody )" "1:"
printf '%s: %s passed, %s failed\n' "${0##*/}" "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" = 0 ]
