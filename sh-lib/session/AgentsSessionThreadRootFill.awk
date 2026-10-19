#!/usr/bin/env awk
# Fills the root post of a coworking session's thread (sh-lib/templates/session-thread.root.format.md):
# its `## root` block under `# Skeleton`, one line. The slots are filled by the one shared
# filler, loaded ahead of this file (AgentsToolsToolingTemplateFill, AgentsToolingTemplateFill.awk).
# What it fills with travels in the environment, never -v, which would decode backslashes in
# a value: STR_SESSION_NAME, STR_STARTED_BY.
# Exit 3: the template has no such block. Exit 4: the session has no name to show.

## A value as Slack shows it: its control characters as the entities Slack decodes, and a
## line break or a tab as one space, since the root is one line.
function strValue( text ) {
	gsub( /[\r\n\t]+/, " ", text ) ;
	gsub( /&/, "\\&amp;", text ) ;
	gsub( /</, "\\&lt;", text ) ;
	gsub( />/, "\\&gt;", text ) ;
	return text ;
}
## The value the shared filler asks for (AgentsToolingTemplateFill.awk): a slot of the root.
function ttSlot( name ) {
	if ( name == "session-name" ) { return strValue( ENVIRON["STR_SESSION_NAME"] ) ; }
	if ( name == "started-by" ) { return strValue( ENVIRON["STR_STARTED_BY"] ) ; }
	return "" ;
}
BEGIN {
	if ( ! ttRead( ARGV[1] ) || ! ( ( "Skeleton" SUBSEP "root" ) in ttHas ) ) { exit 3 ; }
	strText = ttFill( ttBlock["Skeleton", "root"] ) ;
	if ( ttRequiredEmpty ) { exit 4 ; }
	print strText ;
	exit 0 ;
}
