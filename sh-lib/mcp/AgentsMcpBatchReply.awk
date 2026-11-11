#!/usr/bin/awk -f
## AgentsMcpBatchReply.awk -- one read of a batch item's reply wire (AgentsMcpBatchCall, AgentsTools.InternMcpRequest.include).
## Loaded after AgentsHarnessJsonField.awk, as its library (jfLibrary): each line of the wire is parsed once, and for the first
## line that is a result or an error three things are printed -- line 1 the content count (empty for an error), line 2 the
## isError word (true or false, empty for an error or where absent), then the text of the last text part, or the error message,
## to the end of the output. Nothing is printed where no line is a reply. One awk process in place of the four to six field reads
## over the same wire that stood here (call-path audit row 14). LC_ALL=C is required, as the library says.
## Every closing `}` is preceded by a `;` (reference/shell.md's awk axiom).
BEGIN { jfLibrary = 1 ; batchDone = 0 ; }
batchDone { next ; }
{
	if ( jfParseText( $0 ) != 0 ) { next ; }
	if ( "error.message" in jfLeafSeen ) {
		printf "\n\n%s", jfLeaf["error.message"] ;
		batchDone = 1 ;
		next ;
	}
	if ( ! ( "result.content.__count" in jfLeafSeen ) ) { next ; }
	batchCount = jfLeaf["result.content.__count"] + 0 ;
	batchText = "" ;
	for ( batchAt = batchCount - 1 ; batchAt >= 0 ; batchAt-- ) {
		if ( jfLeaf["result.content." batchAt ".type"] == "text" ) { batchText = jfLeaf["result.content." batchAt ".text"] ; break ; }
	}
	batchIsError = ( "result.isError" in jfLeafSeen ) ? jfLeaf["result.isError"] : "" ;
	printf "%s\n%s\n%s", batchCount, batchIsError, batchText ;
	batchDone = 1 ;
}
