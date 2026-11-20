#!/usr/bin/env awk

# Reads one MCP tools/list answer, with AgentsHarnessJsonField.awk given by -f before it, and prints one line a fault:
# a tool named twice, a schema key outside the subset of @deepseek-ai/dsh-tools assertSupportedJsonSchema, or a type that is
# not one name. Each fault makes DeepSeek Harness register no tool of the server. No output is an answer it takes.

BEGIN { jfLibrary = 1 ; }
{ shapeDoc = shapeDoc ( NR > 1 ? "\n" : "" ) $0 ; }

## A key is a keyword where its parent is a schema node: the root, a property, items, additionalProperties or a oneOf member.
function jfNodeHook(hookPath, hookType, hookValue, hookFrom, hookTo,   hookRel, hookParts, hookCount, hookAt) {
	if ( hookPath ~ /^result\.tools\.[0-9]+\.name$/ ) {
		if ( hookValue in shapeNames ) print hookValue " is named twice"
		shapeNames[hookValue] = 1
		shapeTool = hookValue
		return
	}
	if ( ! match( hookPath, /^result\.tools\.[0-9]+\.inputSchema\./ ) ) return
	hookRel = substr( hookPath, RLENGTH )
	hookCount = split( substr( hookRel, 2 ), hookParts, "." )
	hookAt = 1
	while ( hookAt < hookCount ) {
		if ( hookParts[hookAt] == "items" || hookParts[hookAt] == "additionalProperties" ) hookAt++
		else if ( hookParts[hookAt] == "properties" || hookParts[hookAt] == "oneOf" ) hookAt += 2
		else return
	}
	if ( hookAt != hookCount ) return
	if ( hookParts[hookCount] !~ /^(type|oneOf|properties|required|additionalProperties|items|enum|const|description|title|default|examples)$/ ) print shapeTool hookRel
	else if ( hookParts[hookCount] == "type" && hookType != "s" ) print shapeTool hookRel " is not one type name"
}

END { if ( jfConsumeText( shapeDoc ) != 0 ) print "the answer is not one JSON object" ; }
