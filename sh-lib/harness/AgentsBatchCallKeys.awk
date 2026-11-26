#!/usr/bin/env awk

# Run AFTER the field reader, on the arguments of one BatchTools call:
#   LC_ALL=C awk -f AgentsHarnessJsonField.awk -f AgentsBatchCallKeys.awk
# Prints one line, the call's number (from 1), a TAB and the key, for the first key of each entry of `calls` that is neither `tool` nor `arguments`.
# rc 1, nothing printed, when the text does not parse. LC_ALL=C IS REQUIRED: its offsets are bytes.

BEGIN {
	jfLibrary = 1 ;
	jfDocReset() ;
}

{
	jfDocLine($0) ;
}

function jfNodeHook(hookPath, hookType, hookValue, hookFrom, hookTo,   hookPart, hookParts) {
	hookParts = split(hookPath, hookPart, ".") ;
	if (hookParts >= 3 && hookPart[1] == "calls" && hookPart[3] != "tool" && hookPart[3] != "arguments" && !((hookPart[2] SUBSEP hookPart[3]) in keysSeen)) {
		keysSeen[hookPart[2] SUBSEP hookPart[3]] = 1 ;
		printf "%d\t%s\n", hookPart[2] + 1, hookPart[3] ;
	}
}

END {
	if (jfDocConsume() != 0) exit 1 ;
}
