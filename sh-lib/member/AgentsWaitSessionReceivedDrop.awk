#!/usr/bin/env awk

# Leaves out of a rendering every message the member has already received through a session thread it took part in.
# The session source (`chat:`) hands such a message over and records its ts in schedule/seen/<member>.session, one a
# line (AgentsWaitSessionReceivedNote). A tagged, mention or DM read is then the same message a second time.
#   LC_ALL=C SEEN_SESSION_FILE=<path> awk -f AgentsWaitSessionReceivedDrop.awk < rendering
# A message is its head line, `<ts> | ...`, and the lines after it up to the next head line or `# ` line. A `# ` line
# whose part is left with no message is still printed: the reader of the rendering tells an empty part by its rows.

BEGIN {
	seenFile = ENVIRON["SEEN_SESSION_FILE"] ;
	if ( seenFile != "" ) {
		while ( ( getline seenLine < seenFile ) > 0 ) { sessionTs[ seenLine ] = 1 ; }
		close( seenFile ) ;
	}
	dropping = 0 ;
}
/^[0-9]+\.[0-9]+ \| / { headTs = $1 ; dropping = ( headTs in sessionTs ) ; if ( dropping ) { next ; } print ; next ; }
/^# / { dropping = 0 ; print ; next ; }
dropping { next ; }
{ print ; }
