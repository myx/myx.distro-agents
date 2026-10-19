#!/usr/bin/env awk

# A PreToolUse hook's answer (stdin), read ONCE for both of the fields
# AgentsHarnessHooks.sh decides on. Loaded after the field reader as a library:
#   LC_ALL=C awk -f AgentsHarnessJsonField.awk -f AgentsHarnessHookDecision.awk
# It answers exactly as the two reads it replaces did, one per field:
#   rc 1  not one JSON object (the reader's own rc 1)
#   rc 3  hookSpecificOutput.permissionDecision absent
#   rc 0  found; stdout is a separator line, then the decision with its trailing
#         newlines dropped -- what `$( reader )` held -- then the separator, then
#         hookSpecificOutput.permissionDecisionReason, "" where it is absent.
# The separator is chosen to occur in neither value, so the shell splits on it
# with builtins alone.
#
# LC_ALL=C IS REQUIRED, as it is for the reader this loads.

BEGIN {
	jfLibrary = 1
}

{
	hookDoc = (NR > 1) ? hookDoc "\n" $0 : $0
}

END {
	if (jfParseText(hookDoc) != 0) exit 1
	if (!("hookSpecificOutput.permissionDecision" in jfLeafSeen)) exit 3
	hookDecision = jfLeaf["hookSpecificOutput.permissionDecision"]
	while (substr(hookDecision, length(hookDecision), 1) == "\n") hookDecision = substr(hookDecision, 1, length(hookDecision) - 1)
	hookReason = ""
	if ("hookSpecificOutput.permissionDecisionReason" in jfLeafSeen) hookReason = jfLeaf["hookSpecificOutput.permissionDecisionReason"]
	hookSep = "\036\037"
	hookSepIndex = 0
	while (index(hookDecision, hookSep) || index(hookReason, hookSep)) {
		hookSepIndex++
		hookSep = "\036\037" hookSepIndex "\037"
	}
	printf("%s\n%s%s%s", hookSep, hookDecision, hookSep, hookReason)
	exit 0
}
