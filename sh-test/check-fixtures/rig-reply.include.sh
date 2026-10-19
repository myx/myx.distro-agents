#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
##
## The one way a check of sh-test takes a tool's own result back out of the whole reply of a call.
## Sourced by the check:
##   . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-reply.include.sh"
##
## WHY. Every reply -- of the MCP server's own tools and of the harness tools it serves, and every tool
## result the harness's model loop hands its model -- passes through the one reply layer
## (sh-lib/session/AgentsTools.SessionTranscript.include; F2.3 and F2.4 of the refactorings epic). It adds the
## host's time as a content part of its own beside the result: a second text item of an MCP result's
## content, a separate part of the model loop's tool message. The part is the time of the call, so no
## expectation can hold it, and it is never inside a tool's output, which a served call prints as it is.
## And it keeps a result over 8 KB in the session's results/ folder, the reply naming the file with a
## preview. A check that compares what a tool gives, its caps included, takes the tool's own result
## first, and keeps its expectation as it was. What the reply layer adds is asserted in its own checks:
## sh-test/harness/AgentsReplyCurrentDateCheck.test.sh and sh-test/harness/AgentsReplyLongResultCheck.test.sh.
##
##   rigReplyBare      stdin to stdout: the tool's own result, with no newline after its last line,
##                     as a captured result has none. A reply naming a kept file gives that file.
##                     Any other reply passes as it is, the date part left out: the text item
##                     `{"type":"text","text":"current-date: ..."}` of an MCP reply or a tool message,
##                     and where the result is then the tool message's only part, the part folded
##                     back to the string `"content":"..."` the tool message had before it.
##

rigReplyBare(){
	local bareText bareKept
	bareText="$( cat )"
	bareKept="$( printf '%s\n' "$bareText" | LC_ALL=C sed -n 's/^\.\.\. KEPT: the whole result, [0-9]* bytes in [0-9]* lines, is in \(\/[^ ]*\) -- .*/\1/p' | head -1 )"
	if [ -n "$bareKept" ] && [ -f "$bareKept" ] ; then
		printf '%s' "$( cat "$bareKept" )"
		return 0
	fi
	printf '%s' "$( printf '%s\n' "$bareText" | LC_ALL=C sed -E \
		-e 's/,\{"type":"text","text":"current-date: [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} [+-][0-9]{4}"\}//g' \
		-e 's/("(tool_call_id|tool_use_id)":"[^"]*","content":)\[\{"type":"text","text":("([^"\\]|\\.)*")\}\]/\1\3/g' )"
}
