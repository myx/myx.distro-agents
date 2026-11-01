#!/usr/bin/env awk

# Adds the arguments every tool takes (epic S20, AgentsTools.ToolTask.include) to the schema of each tool declaration on stdin, one declaration a line:
# `background`, `sync`, `async`, `timeout` and `timeout_action`. A tool that already declares its own `timeout` (Bash, WorkspaceContextExecute) keeps it and gets the others.
# The tools that block by design on their own bound, the handback and BatchTools are left as they are: the dispatcher does not wrap them.
# A line that is no declaration, or whose schema has no properties object, is passed on as it is.

BEGIN {
	split("Wait AskQuestion ConfirmReadback EscalateDecision RequestPermission ProposeApprove ThisSession TaskOutput TaskStop SubagentHandback BatchTools", skipName, " ") ;
	for (skipAt in skipName) { skip[skipName[skipAt]] = 1 ; }
	background = "\"background\":{\"type\":\"boolean\",\"description\":\"true returns at once with TASK-ID=process-N and the call goes on as a task: Wait sources=process:process-N, TaskOutput handle=process-N and TaskStop handle=process-N work on it.\"}" ;
	timeout = "\"timeout\":{\"type\":\"integer\",\"description\":\"Seconds after which the call returns early as a task, or is ended with timeout_action kill. With none, the call returns early at the window of this tool, 10 to 300 seconds.\"}" ;
	syncFlag = "\"sync\":{\"type\":\"boolean\",\"description\":\"true overrides the window and waits with no window at all: the call runs to its own end before this returns.\"}" ;
	asyncFlag = "\"async\":{\"type\":\"boolean\",\"description\":\"true overrides the window and returns at once with TASK-ID=process-N, without waiting for the window of this tool.\"}" ;
	action = "\"timeout_action\":{\"type\":\"string\",\"enum\":[\"return\",\"kill\"],\"description\":\"What happens at timeout: return (the default) hands back TASK-ID=process-N and the call goes on, kill ends it and returns what it wrote.\"}" ;
}

{
	line = $0 ;
	if ( ! match(line, /"name":"[A-Za-z0-9_]+"/) ) { print line ; next ; }
	name = substr(line, RSTART + 8, RLENGTH - 9) ;
	if ( name in skip ) { print line ; next ; }
	at = index(line, "\"properties\":{") ;
	if ( at == 0 ) { print line ; next ; }
	head = substr(line, 1, at + 13) ;
	tail = substr(line, at + 14) ;
	add = background ;
	if ( index(line, "\"timeout\":") == 0 ) { add = add "," timeout ; }
	add = add "," action "," syncFlag "," asyncFlag ;
	if ( substr(tail, 1, 1) != "}" ) { add = add "," ; }
	print head add tail ;
}
