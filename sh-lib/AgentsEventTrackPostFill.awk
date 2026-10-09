#!/usr/bin/env awk
# Renders one tracking post from the template sh-lib/templates/event-track.post.format.md
# (AgentsTools.InternOpEventTrackPost.include). Files: the template, then the lines file.
# Environment: ETP_KIND, ETP_MEMBER, ETP_SESSION, ETP_FIELDS (name=value per line, the last
# of a name wins), ETP_CAP (bytes per post), ETP_DIR (where post files 000001... are written).
# Exit 3: the template has no block for the kind. Run with LC_ALL=C: lengths are bytes.

## Slack's control characters, as the entities Slack decodes.
function esc( text ) {
	gsub( /&/, "\\&amp;", text ) ;
	gsub( /</, "\\&lt;", text ) ;
	gsub( />/, "\\&gt;", text ) ;
	return text ;
}

## A field value on one line, with no backtick to end a code span.
function cleanValue( text ) {
	gsub( /[\t\r\n]/, " ", text ) ;
	gsub( /`/, "%60", text ) ;
	return esc( text ) ;
}

## A slot's value: the tooling's own slots first, then the caller's fields.
function slotValue( name ) {
	if ( name == "member" ) { return esc( member ) ; }
	if ( name == "session" ) { return shortSession ; }
	if ( name == "part" ) { return partText ; }
	if ( name == "events" ) { return eventsText ; }
	if ( name == "span" ) { return spanText ; }
	if ( name in field ) { return field[name] ; }
	return "" ;
}

## One template line filled. Sets keepLine: 0 when it has slots and every one is empty.
## Slots are replaced by position, never gsub, so & and \ in a value pass through literally.
function fillLine( text,    done, rest, openAt, closeAt, name, value, slotCount, filledCount ) {
	done = "" ; rest = text ; slotCount = 0 ; filledCount = 0 ;
	while ( ( openAt = index( rest, "{{" ) ) > 0 ) {
		closeAt = index( substr( rest, openAt + 2 ), "}}" ) ;
		if ( closeAt == 0 ) { break ; }
		name = substr( rest, openAt + 2, closeAt - 1 ) ;
		value = slotValue( name ) ;
		slotCount++ ;
		if ( value != "" ) { filledCount++ ; } else { value = "-" ; }
		done = done substr( rest, 1, openAt - 1 ) value ;
		rest = substr( rest, openAt + closeAt + 3 ) ;
	}
	keepLine = ( slotCount == 0 || filledCount > 0 ) ;
	return done rest ;
}

## The post's text around its code block, for the current partText: sets headText and tailText.
function renderFrame(    lineNo, filled, inTail ) {
	headText = "" ; tailText = "" ; inTail = 0 ;
	for ( lineNo = 1 ; lineNo <= tmplCount ; lineNo++ ) {
		if ( tmpl[lineNo] == "{{lines}}" ) { inTail = 1 ; continue ; }
		filled = fillLine( tmpl[lineNo] ) ;
		if ( lineNo > 1 && ! keepLine ) { continue ; }
		if ( inTail ) { tailText = tailText ( tailText == "" ? "" : "\n" ) filled ; }
		else { headText = headText ( headText == "" ? "" : "\n" ) filled ; }
	}
}

function writePost( number, block,    text, path ) {
	text = headText ;
	if ( block != "" ) { text = text "\n```\n" block "\n```" ; }
	if ( tailText != "" ) { text = text "\n" tailText ; }
	path = outDir "/" sprintf( "%06d", number ) ;
	printf "%s", text > path ;
	close( path ) ;
}

BEGIN {
	kind = ENVIRON["ETP_KIND"] ;
	member = ENVIRON["ETP_MEMBER"] ;
	shortSession = cleanValue( substr( ENVIRON["ETP_SESSION"], 1, 8 ) ) ;
	if ( shortSession == "" ) { shortSession = "-" ; }
	cap = ENVIRON["ETP_CAP"] + 0 ;
	if ( cap <= 16 ) { cap = 3000 ; }
	outDir = ENVIRON["ETP_DIR"] ;
	fieldCount = split( ENVIRON["ETP_FIELDS"], fieldLines, "\n" ) ;
	for ( fieldNo = 1 ; fieldNo <= fieldCount ; fieldNo++ ) {
		eqAt = index( fieldLines[fieldNo], "=" ) ;
		if ( eqAt < 2 ) { continue ; }
		field[substr( fieldLines[fieldNo], 1, eqAt - 1 )] = cleanValue( substr( fieldLines[fieldNo], eqAt + 1 ) ) ;
	}
	headingWanted = "## " kind ;
}

## The template: the block after `## <kind>` under `# Skeleton`.
FNR == NR {
	if ( $0 ~ /^# / ) { inSkeleton = ( $0 ~ /^# Skeleton[ \t]*$/ ) ; inKind = 0 ; next ; }
	if ( ! inSkeleton || blockDone ) { next ; }
	if ( $0 ~ /^## / ) { inKind = ( $0 == headingWanted ) ; next ; }
	if ( ! inKind ) { next ; }
	if ( $0 ~ /^```/ ) { if ( inBlock ) { blockDone = 1 ; inBlock = 0 ; } else { inBlock = 1 ; } next ; }
	if ( inBlock ) { tmpl[++tmplCount] = $0 ; }
	next ;
}

## The lines: each kept escaped, a code fence inside one broken by zero-width spaces.
{
	lineText = $0 ;
	if ( lineText ~ /^[0123456789][0123456789][0123456789][0123456789]-[0123456789][0123456789]-[0123456789][0123456789]T[0123456789][0123456789]:[0123456789][0123456789]:[0123456789][0123456789]Z [ABCDEFGHIJKLMNOPQRSTUVWXYZ]/ ) {
		split( lineText, lineWords, " " ) ;
		if ( ! ( lineWords[2] in kindCount ) ) { kindOrder[++kindTotal] = lineWords[2] ; }
		kindCount[lineWords[2]]++ ;
		if ( firstAt == "" ) { firstAt = substr( lineText, 12, 8 ) ; }
		lastAt = substr( lineText, 12, 8 ) ;
	}
	gsub( /```/, "`\342\200\213`\342\200\213`", lineText ) ;
	lines[++lineCount] = esc( lineText ) ;
}

END {
	if ( ! blockDone || tmplCount == 0 ) { exit 3 ; }
	eventsText = "" ;
	for ( kindNo = 1 ; kindNo <= kindTotal ; kindNo++ ) {
		eventsText = eventsText ( kindNo > 1 ? ", " : "" ) kindOrder[kindNo] " " kindCount[kindOrder[kindNo]] ;
	}
	spanText = ( firstAt == "" ? "" : ( firstAt == lastAt ? firstAt : firstAt " to " lastAt ) ) ;
	if ( lineCount == 0 ) { partText = "" ; renderFrame() ; writePost( 1, "" ) ; exit 0 ; }
	## The room a part's lines have: the cap less the widest frame and the fence around them.
	partText = "999 of 999" ;
	renderFrame() ;
	room = cap - length( headText ) - ( tailText == "" ? 0 : length( tailText ) + 1 ) - 9 ;
	if ( room < 32 ) { room = 32 ; }
	## Lines into parts at line boundaries; a line longer than the room is cut into pieces.
	partTotal = 0 ; chunk = "" ;
	for ( lineNo = 1 ; lineNo <= lineCount ; lineNo++ ) {
		lineText = lines[lineNo] ;
		while ( length( lineText ) > room ) {
			if ( chunk != "" ) { part[++partTotal] = chunk ; chunk = "" ; }
			part[++partTotal] = substr( lineText, 1, room ) ;
			lineText = substr( lineText, room + 1 ) ;
		}
		if ( chunk != "" && length( chunk ) + 1 + length( lineText ) > room ) { part[++partTotal] = chunk ; chunk = "" ; }
		chunk = ( chunk == "" ? lineText : chunk "\n" lineText ) ;
	}
	if ( chunk != "" ) { part[++partTotal] = chunk ; }
	for ( partNo = 1 ; partNo <= partTotal ; partNo++ ) {
		partText = ( partTotal > 1 ? partNo " of " partTotal : "" ) ;
		renderFrame() ;
		writePost( partNo, part[partNo] ) ;
	}
	exit 0 ;
}
