#!/usr/bin/env awk
# Prints each pending-reply record matching the owner/open filters, with an optional trailing count.
# With -v countLine=only it renders no record and prints only the number of those that match, a line.
# With -v askerHost, this host's name, each open record also says whether the run that asked it
# is alive, `asker-live: <live>`, before its question: no-session-id where the record names no
# asking session, host-unrecorded where it names no host, other-host where it was asked on
# another one -- none of which this host can measure -- else what was measured for its asking
# id (AgentsToolsRegistryAskersLive), read first from the first file, `-`, `<asking id> <live>`
# a line; not-measured where its id is not among those.
# With MDAT_PENDING_WHOLE set in the environment, as the read of one record by its id sets it,
# each record printed is followed by the whole of what the stores hold of that ask, from
# `PENDING-REPLY-STORED: <id>` to a blank line. Every line there is `<name>: <text>`. A text of
# several lines repeats its name on each of its lines, in order, an empty line being the name,
# the colon and one space, and it ends where a line has another name. A name that lists things
# has one of them a line. In this order, each only where the stores hold it:
#   <header field>      every header field of the record not printed above, as it stands there
#   posted              the question as it was posted, whole: the body under `# Question asked`
#   clarification       what the record keeps of its thread since, under `## Clarifications`
#   option              <id>.options: an option a line, with its words
#   field-<slot>        <id>.fields: a slot the post was filled with, its line breaks back
#   first-option, first-field-<slot>   the same of <id>.first.*: the question as first asked
#   set-<key>           <id>.set, a permission set's own record: scope, item, session-id,
#                       participants, entry, place, purpose, reason, held
#   answer-noted-<key>  <id>.answered/verdict: a verdict noted and not yet applied
#   refused-<key>, refused-place, refused-text   the refused call of a permission, from the
#                       refusal record MDAT_PENDING_REFUSAL names: its header fields, its
#                       places file, what the tool said
#   change-store, change-<key>, change-diff   a held change, from the folder
#                       MDAT_PENDING_CHANGE names: where it is kept, its own record, and the
#                       whole change as a diff
#   kept-beside         the names of what lies beside the record (MDAT_PENDING_BESIDE)
function askerLive(   askerId) {
	askerId = ( "session-id" in val ) ? val["session-id"] : "" ;
	if ( askerId == "" || askerId == "-" ) { return "no-session-id" ; }
	if ( ! ( "host" in val ) || val["host"] == "" ) { return "host-unrecorded" ; }
	if ( val["host"] != askerHost ) { return "other-host" ; }
	return ( askerId in askerOf ) ? askerOf[askerId] : "not-measured" ;
}
# A slot value as it was before it was packed: `\\` a backslash, `\n` a line break.
function storedUnpack(packedText,    plainText, charPos, charNow, charNext, textLength) {
	if ( index(packedText, "\\") == 0 ) { return packedText ; }
	plainText = "" ; textLength = length(packedText) ;
	for ( charPos = 1 ; charPos <= textLength ; charPos++ ) {
		charNow = substr(packedText, charPos, 1) ;
		if ( charNow == "\\" && charPos < textLength ) {
			charNext = substr(packedText, charPos + 1, 1) ;
			if ( charNext == "n" ) { plainText = plainText "\n" ; charPos++ ; continue ; }
			if ( charNext == "\\" ) { plainText = plainText "\\" ; charPos++ ; continue ; }
		}
		plainText = plainText charNow ;
	}
	return plainText ;
}
# One text under one name, a line of it a line.
function storedText(fieldName, fieldText,    lineTotal, lineIdx, textLines) {
	lineTotal = split(fieldText, textLines, "\n") ;
	for ( lineIdx = 1 ; lineIdx <= lineTotal ; lineIdx++ ) { printf "%s: %s\n", fieldName, textLines[lineIdx] ; }
}
# Lines kept in an array, under one name, the empty ones at either end left out.
function storedBlock(fieldName, blockLines, firstIdx, lastIdx,    lineIdx) {
	while ( firstIdx <= lastIdx && blockLines[firstIdx] ~ /^[ \t]*$/ ) { firstIdx++ ; }
	while ( lastIdx >= firstIdx && blockLines[lastIdx] ~ /^[ \t]*$/ ) { lastIdx-- ; }
	for ( lineIdx = firstIdx ; lineIdx <= lastIdx ; lineIdx++ ) { printf "%s: %s\n", fieldName, blockLines[lineIdx] ; }
}
# The lines of a file under one name: every one of them, or only those that are not empty.
function storedFileLines(filePath, fieldName, everyLine,    fileLine) {
	while ( ( getline fileLine < filePath ) > 0 ) {
		if ( everyLine != "" || fileLine != "" ) { printf "%s: %s\n", fieldName, fileLine ; }
	}
	close(filePath) ;
}
# The `<key>: <value>` lines of a file, each under its key behind a prefix.
function storedFileKeys(filePath, namePrefix,    fileLine) {
	while ( ( getline fileLine < filePath ) > 0 ) {
		if ( index(fileLine, ": ") > 1 ) { printf "%s%s\n", namePrefix, fileLine ; }
	}
	close(filePath) ;
}
# The `<slot><TAB><value>` lines of a file, each slot under its name behind a prefix.
function storedFileSlots(filePath, namePrefix,    fileLine, tabPos, slotName) {
	while ( ( getline fileLine < filePath ) > 0 ) {
		tabPos = index(fileLine, "\t") ;
		if ( tabPos < 2 ) { continue ; }
		slotName = substr(fileLine, 1, tabPos - 1) ;
		if ( slotName !~ /^[a-z_-]+$/ ) { continue ; }
		storedText(namePrefix slotName, storedUnpack(substr(fileLine, tabPos + 1))) ;
	}
	close(filePath) ;
}
# The refused call of a permission: its record's header fields, its places, what the tool said.
function storedRefusal(filePath,    fileLine, fenceCount, saidCount, saidLines, saidFirst, placesPath) {
	fenceCount = 0 ; saidCount = 0 ;
	while ( ( getline fileLine < filePath ) > 0 ) {
		if ( fenceCount < 2 && fileLine == "---" ) { fenceCount++ ; continue ; }
		if ( fenceCount == 1 ) {
			if ( index(fileLine, ": ") > 1 ) { printf "%s%s\n", ( index(fileLine, "refused-") == 1 ? "" : "refused-" ), fileLine ; }
			continue ;
		}
		if ( fenceCount >= 2 ) { saidLines[++saidCount] = fileLine ; }
	}
	close(filePath) ;
	placesPath = filePath ; sub(/\.md$/, ".places", placesPath) ;
	if ( placesPath != filePath ) { storedFileLines(placesPath, "refused-place", "") ; }
	for ( saidFirst = 1 ; saidFirst <= saidCount && saidLines[saidFirst] ~ /^[ \t]*$/ ; saidFirst++ ) { }
	if ( saidFirst <= saidCount && saidLines[saidFirst] == "# Refused" ) { saidFirst++ ; }
	storedBlock("refused-text", saidLines, saidFirst, saidCount) ;
}
# The whole of what the stores hold of the record just printed.
function stored(    keyIdx, keyName, recordBase, lineIdx, askedAt, clarAt) {
	printf "PENDING-REPLY-STORED: %s\n", fileId ;
	for ( keyIdx = 1 ; keyIdx <= keyOrderCount ; keyIdx++ ) {
		keyName = keyOrder[keyIdx] ;
		if ( ! ( keyName in printedKey ) ) { printf "%s: %s\n", keyName, val[keyName] ; }
	}
	askedAt = 0 ; clarAt = 0 ;
	for ( lineIdx = 1 ; lineIdx <= bodyCount ; lineIdx++ ) {
		if ( ! askedAt && ! clarAt && bodyLine[lineIdx] == "# Question asked" ) { askedAt = lineIdx ; }
		else if ( ! clarAt && bodyLine[lineIdx] == "## Clarifications" ) { clarAt = lineIdx ; }
	}
	storedBlock("posted", bodyLine, askedAt + 1, ( clarAt ? clarAt - 1 : bodyCount )) ;
	if ( clarAt ) { storedBlock("clarification", bodyLine, clarAt + 1, bodyCount) ; }
	recordBase = recordPath ; sub(/\.md$/, "", recordBase) ;
	storedFileLines(recordBase ".options", "option", "") ;
	storedFileSlots(recordBase ".fields", "field-") ;
	storedFileLines(recordBase ".first.options", "first-option", "") ;
	storedFileSlots(recordBase ".first.fields", "first-field-") ;
	storedFileKeys(recordBase ".set", "set-") ;
	storedFileKeys(recordBase ".answered/verdict", "answer-noted-") ;
	if ( ENVIRON["MDAT_PENDING_REFUSAL"] != "" ) { storedRefusal(ENVIRON["MDAT_PENDING_REFUSAL"]) ; }
	if ( ENVIRON["MDAT_PENDING_CHANGE"] != "" ) {
		printf "change-store: %s\n", ENVIRON["MDAT_PENDING_CHANGE"] ;
		storedFileKeys(ENVIRON["MDAT_PENDING_CHANGE"] "/change", "change-") ;
		storedFileLines(ENVIRON["MDAT_PENDING_CHANGE"] "/change.diff", "change-diff", 1) ;
	}
	if ( ENVIRON["MDAT_PENDING_BESIDE"] != "" ) { printf "kept-beside: %s\n", ENVIRON["MDAT_PENDING_BESIDE"] ; }
	printf "\n" ;
}
function resetRecord() {
	dashes = 0 ; first = "" ; haveRecord = 1 ; split("", val) ; keyOrderCount = 0 ; bodyCount = 0 ; recordPath = FILENAME ;
	fileId = FILENAME ; sub(/^.*\//, "", fileId) ; sub(/\.md$/, "", fileId) ;
}
function flush(   keyIdx, keyName) {
	if ( wantOwner != "" && val["owner"] != wantOwner ) { return ; }
	if ( openOnly != "" && val["status"] != "reply-pending" ) { return ; }
	if ( countLine == "only" ) { shown++ ; return ; }
	printf "PENDING-REPLY: %s\n", fileId ;
	for ( keyIdx = 1 ; keyIdx <= keyCount ; keyIdx++ ) {
		keyName = keys[keyIdx] ;
		if ( keyName in val ) { printf "%s: %s\n", keyName, val[keyName] ; }
	}
	if ( askerHost != "" && val["status"] == "reply-pending" ) { printf "asker-live: %s\n", askerLive() ; }
	printf "question: %s\n\n", first ;
	if ( wholeMode != "" ) { stored() ; }
	shown++ ;
}
BEGIN {
	keyCount = split("status owner kind question-tag channel question-ts thread-ts address-to session-id item asked-at resolved-at verdict answered-by amended-at amended-by amend-reason amended-from amended-from-answered-by", keys, " ") ;
	for ( keyIdx = 1 ; keyIdx <= keyCount ; keyIdx++ ) { printedKey[keys[keyIdx]] = 1 ; }
	wholeMode = ENVIRON["MDAT_PENDING_WHOLE"] ;
}
askerHost != "" && FILENAME == ARGV[1] {
	if ( NF >= 2 ) { askerOf[substr($0, 1, length($0) - length($NF) - 1)] = $NF ; }
	next ;
}
FNR == 1 { if ( haveRecord ) { flush() ; } resetRecord() ; }
wholeMode != "" && dashes >= 2 { bodyLine[++bodyCount] = $0 ; }
$0 == "---" { dashes++ ; next ; }
dashes == 1 {
	colon = index($0, ": ") ;
	if ( colon > 1 ) {
		keyName = substr($0, 1, colon - 1) ;
		if ( ! ( keyName in val ) ) { val[keyName] = substr($0, colon + 2) ; keyOrder[++keyOrderCount] = keyName ; }
	}
	next ;
}
dashes >= 2 && first == "" && $0 !~ /^#/ && $0 !~ /^[ \t]*$/ { first = $0 ; }
END {
	if ( haveRecord ) { flush() ; }
	if ( countLine == "only" ) { printf "%d\n", shown + 0 ; }
	else if ( countLine != "" ) { printf "PENDING-REPLIES: %d\n", shown + 0 ; }
}
