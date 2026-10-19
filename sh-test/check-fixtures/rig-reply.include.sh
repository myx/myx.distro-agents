#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
##
## The one way a check of sh-test takes a tool's own result back out of the whole reply of a call.
## Sourced by the check:
##   . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-reply.include.sh"
##
## WHY. Every reply -- of a served call (AgentsUniversalHarness.sh --intern-tool), of the MCP server's
## own tools, and every tool result the harness's model loop hands its model -- passes through the one
## reply layer (sh-lib/AgentsTools.SessionTranscript.include; F2.3 and F2.4 of the refactorings epic).
## It adds the host's time as one `current-date:` line, which is the time of the call, so no
## expectation can hold it. And it keeps a result over 8 KB in the session's results/ folder, the
## reply naming the file with a preview. A check that compares what a tool gives, its caps included,
## takes the tool's own result first, and keeps its expectation as it was. What the reply layer adds
## is asserted in its own checks: sh-test/harness/AgentsReplyCurrentDateCheck.test.sh and
## sh-test/harness/AgentsReplyLongResultCheck.test.sh.
##
##   rigReplyBare      stdin to stdout: the tool's own result, with no newline after its last line,
##                     as a captured result has none. A reply naming a kept file gives that file.
##                     Any other reply passes as it is, the current-date line left out: the line of
##                     its own, and the same line inside a JSON string, written there as
##                     \ncurrent-date: ...
##

rigReplyBare(){
	local bareText bareKept
	bareText="$( cat )"
	bareKept="$( printf '%s\n' "$bareText" | LC_ALL=C sed -n 's/^\.\.\. KEPT: the whole result, [0-9]* bytes in [0-9]* lines, is in \(\/[^ ]*\) -- .*/\1/p' | head -1 )"
	if [ -n "$bareKept" ] && [ -f "$bareKept" ] ; then
		printf '%s' "$( cat "$bareKept" )"
		return 0
	fi
	printf '%s' "$( printf '%s\n' "$bareText" | LC_ALL=C sed \
		-e '/^current-date: [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9] [+-][0-9][0-9][0-9][0-9]$/d' \
		-e 's/\\ncurrent-date: [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9] [+-][0-9][0-9][0-9][0-9]//g' )"
}
