#!/usr/bin/env awk
# Renders one tracking post from the template sh-lib/templates/event-track.post.format.md
# (AgentsTools.InternOpEventTrackPost.include), as its `# Contract` says: blocks, each a
# subject then its lines; every operation one line by its own template, from its parsed
# fields only, so no line given is ever posted as it came and nothing is a code block. A post
# is written as Slack blocks, each block one box (a `container` block: a title, a subtitle
# with the time of its first line, its lines in sections, its context lines small and grey),
# with the short text that goes beside them, and once more as plain text, each block under
# its header line, for a Slack that refuses the blocks.
# Loaded after the transcript formatter, for its redaction and its tool names, and after the
# Slack date helper, for every time a post shows (a subtitle's date; a plain-text header's
# span; a date token a field gives):
#   LC_ALL=C awk -f AgentsSessionTranscriptFormat.awk -f AgentsSlackDate.awk -f AgentsEventTrackPostFill.awk <template> <lines>
# Environment: ETP_KIND, ETP_MEMBER, ETP_MEMBERS (" <name> ... ", the team's members),
# ETP_SESSION, ETP_FIELDS (name=value per line, the last of a name wins), ETP_DIR (where each
# post's files are written: 000001.blocks, its boxes as a JSON array; 000001.text, its short
# text for a notification; 000001.plain.001..., the same post as plain text), ETP_USERS
# (" <slack id>=<name> ...", who a message's author is), ETP_WAIT_STATE (a file holding the
# session's previous Wait set, read first and left holding this post's last one; empty for
# none), ETP_NOW (epoch seconds, the moment the post is made: the time of a kind's own lines).
# Fixed here, Slack's limits, counted in characters as Slack counts: a section's text is at
# most 3000, a box has at most 10 children, a post at most 50 blocks with every box's children
# counted too, and a plain-text post is at most 4000, a message's `text`.
# Exit 3: the template has no block for the kind. Run with LC_ALL=C: lengths are bytes, and
# charLength() counts the UTF-8 characters.

## Slack's control characters, as the entities Slack decodes.
function esc( text ) {
	gsub( /&/, "\\&amp;", text ) ;
	gsub( /</, "\\&lt;", text ) ;
	gsub( />/, "\\&gt;", text ) ;
	return text ;
}

## A value on one line, with no backtick to end a code span.
function cleanValue( text ) {
	gsub( /[\t\r\n]/, " ", text ) ;
	gsub( /`/, "%60", text ) ;
	return esc( text ) ;
}

## The characters of a UTF-8 text: its bytes, less the continuation bytes, and a character
## outside the BMP (an emoji) counted twice, as UTF-16 counts it, so never fewer than Slack.
function charLength( text,    astral ) {
	gsub( /[\200-\277]/, "", text ) ;
	astral = gsub( /[\360-\367]/, "", text ) ;
	return length( text ) + 2 * astral ;
}

## A text cut to capBytes at a character boundary, with an ellipsis; never inside a Slack
## date token, which goes whole or not at all (sldCutAt).
function cutBytes( text, capBytes ) {
	if ( capBytes <= 0 || length( text ) <= capBytes ) { return text ; }
	text = substr( text, 1, sldCutAt( text, capBytes ) ) ;
	sub( /[\300-\377][\200-\277]*$/, "", text ) ;
	return text "\342\200\246" ;
}

## An operation's text: one line, token-like values redacted as the transcript redacts them,
## then cut.
function cutText( text, capBytes ) {
	gsub( /[\001-\037\177]/, " ", text ) ;
	text = stlRedact( text ) ;
	sub( /^ +/, "", text ) ;
	sub( / +$/, "", text ) ;
	return cutBytes( text, capBytes ) ;
}

function lastSlash( text,    slashAt, found ) {
	found = 0 ;
	while ( ( slashAt = index( substr( text, found + 1 ), "/" ) ) > 0 ) { found += slashAt ; }
	return found ;
}

## A path as its last component, with its parent when that is 10 bytes or shorter.
function shortPath( pathText,    slashAt, baseText, parentText ) {
	sub( /\/+$/, "", pathText ) ;
	slashAt = lastSlash( pathText ) ;
	if ( slashAt == 0 ) { return cutText( pathText, 60 ) ; }
	baseText = substr( pathText, slashAt + 1 ) ;
	parentText = substr( pathText, 1, slashAt - 1 ) ;
	parentText = substr( parentText, lastSlash( parentText ) + 1 ) ;
	if ( length( baseText ) <= 10 && parentText != "" ) { baseText = parentText "/" baseText ; }
	return cutText( baseText, 60 ) ;
}

function trimZero( text ) {
	sub( /\.0$/, "", text ) ;
	return text ;
}

function sizeText( byteCount ) {
	if ( byteCount !~ /^[0-9]+$/ ) { return "" ; }
	byteCount = byteCount + 0 ;
	if ( byteCount < 1024 ) { return byteCount " B" ; }
	if ( byteCount < 10240 ) { return trimZero( sprintf( "%.1f", byteCount / 1024 ) ) " KB" ; }
	if ( byteCount < 1048576 ) { return int( byteCount / 1024 + 0.5 ) " KB" ; }
	if ( byteCount < 10485760 ) { return trimZero( sprintf( "%.1f", byteCount / 1048576 ) ) " MB" ; }
	return int( byteCount / 1048576 + 0.5 ) " MB" ;
}

function countText( countValue ) {
	if ( countValue !~ /^[0-9]+$/ ) { return "" ; }
	countValue = countValue + 0 ;
	if ( countValue < 1000 ) { return countValue "" ; }
	if ( countValue < 10000 ) { return trimZero( sprintf( "%.1f", countValue / 1000 ) ) "K" ; }
	if ( countValue < 1000000 ) { return int( countValue / 1000 + 0.5 ) "K" ; }
	if ( countValue < 10000000 ) { return trimZero( sprintf( "%.1f", countValue / 1000000 ) ) "M" ; }
	return int( countValue / 1000000 + 0.5 ) "M" ;
}

## The formatter's duration (2ms, 1.2s, <1s, 1m05s) with its unit spaced.
function durationText( durText ) {
	if ( durText ~ /^[0-9]+ms$/ ) { return substr( durText, 1, length( durText ) - 2 ) " ms" ; }
	if ( durText ~ /^<?[0-9.]+s$/ ) { return substr( durText, 1, length( durText ) - 1 ) " s" ; }
	if ( durText ~ /^[0-9]+m[0-9]+s$/ ) { sub( /m0?/, " m ", durText ) ; sub( /s$/, " s", durText ) ; }
	return durText ;
}

function plural( countValue, oneWord, manyWord ) {
	if ( countValue !~ /^[0-9]+$/ ) { return "" ; }
	return countValue " " ( countValue + 0 == 1 ? oneWord : manyWord ) ;
}

## `in=… cache-read=… cache-write=… out=…` as `in … · cache … · out …`, the rest kept.
function tokensText( text,    wordCount, words, wordNo, inCount, cacheCount, outCount, restText, seenCount ) {
	wordCount = split( text, words, " " ) ;
	inCount = 0 ; cacheCount = 0 ; outCount = 0 ; restText = "" ; seenCount = 0 ;
	for ( wordNo = 1 ; wordNo <= wordCount ; wordNo++ ) {
		if ( words[wordNo] ~ /^in=[0-9]+$/ ) { inCount = substr( words[wordNo], 4 ) + 0 ; seenCount++ ; }
		else if ( words[wordNo] ~ /^cache-(read|write)=[0-9]+$/ ) { cacheCount += substr( words[wordNo], index( words[wordNo], "=" ) + 1 ) + 0 ; seenCount++ ; }
		else if ( words[wordNo] ~ /^out=[0-9]+$/ ) { outCount = substr( words[wordNo], 5 ) + 0 ; seenCount++ ; }
		else { restText = restText " " words[wordNo] ; }
	}
	if ( seenCount == 0 ) { return text ; }
	return "in " countText( inCount ) " \302\267 cache " countText( cacheCount ) " \302\267 out " countText( outCount ) restText ;
}

## ---- the transcript line, parsed ----

function isEventLine( text ) {
	return text ~ /^[0123456789][0123456789][0123456789][0123456789]-[0123456789][0123456789]-[0123456789][0123456789]T[0123456789][0123456789]:[0123456789][0123456789]:[0123456789][0123456789]Z [ABCDEFGHIJKLMNOPQRSTUVWXYZ]/ ;
}

## A quoted value from the `"` at `at`, unescaped; sets quotedEnd past its closing quote.
function quoted( text, at,    outText, textLength, oneChar ) {
	outText = "" ; textLength = length( text ) ; at++ ;
	while ( at <= textLength ) {
		oneChar = substr( text, at, 1 ) ;
		if ( oneChar == "\\" && at < textLength ) { outText = outText substr( text, at + 1, 1 ) ; at += 2 ; continue ; }
		if ( oneChar == "\"" ) { at++ ; break ; }
		outText = outText oneChar ; at++ ;
	}
	quotedEnd = at ;
	return outText ;
}

## The next bare word from `at`; sets wordEnd past it.
function nextWord( text, at,    spaceAt ) {
	while ( substr( text, at, 1 ) == " " ) { at++ ; }
	spaceAt = index( substr( text, at ), " " ) ;
	if ( spaceAt == 0 ) { wordEnd = length( text ) + 1 ; return substr( text, at ) ; }
	wordEnd = at + spaceAt ;
	return substr( text, at, spaceAt - 1 ) ;
}

## The key=value fields from `at` into evField, up to the first bare word; sets fieldsEnd.
function parseFields( text, at,    textLength, keyStart, keyName, valueText ) {
	textLength = length( text ) ;
	while ( 1 ) {
		while ( substr( text, at, 1 ) == " " ) { at++ ; }
		if ( at > textLength ) { break ; }
		keyStart = at ;
		while ( at <= textLength && substr( text, at, 1 ) ~ /[A-Za-z0-9_-]/ ) { at++ ; }
		if ( at == keyStart || substr( text, at, 1 ) != "=" ) { at = keyStart ; break ; }
		keyName = substr( text, keyStart, at - keyStart ) ;
		at++ ;
		if ( substr( text, at, 1 ) == "\"" ) { valueText = quoted( text, at ) ; at = quotedEnd ; }
		else { valueText = nextWord( text, at ) ; at = wordEnd ; }
		if ( ! ( keyName in evField ) ) { evField[keyName] = valueText ; evKeys[++evKeyCount] = keyName ; }
	}
	fieldsEnd = at ;
}

## `<ts> TOOL <name> key=val ... -> <outcome> ["first"] [<b>B/<l>L] [<dur>] [| "<comment>"]`
function parseTool( text,    at, oneWord ) {
	evToolName = nextWord( text, 27 ) ;
	parseFields( text, wordEnd ) ;
	at = fieldsEnd ;
	if ( substr( text, at, 2 ) != "->" ) { return ; }
	evOutcome = nextWord( text, at + 2 ) ; at = wordEnd ;
	while ( substr( text, at, 1 ) == " " ) { at++ ; }
	if ( substr( text, at, 1 ) == "\"" ) { evFirst = quoted( text, at ) ; at = quotedEnd ; }
	while ( at <= length( text ) ) {
		oneWord = nextWord( text, at ) ; at = wordEnd ;
		if ( oneWord ~ /^[0-9]+B(\/[0-9]+L)?$/ ) {
			evBytes = substr( oneWord, 1, index( oneWord, "B" ) - 1 ) ;
			if ( index( oneWord, "/" ) > 0 ) { evLines = substr( oneWord, index( oneWord, "/" ) + 1 ) ; sub( /L$/, "", evLines ) ; }
		} else if ( oneWord ~ /^(<1s|[0-9]+ms|[0-9]+(\.[0-9]+)?s|[0-9]+m[0-9]+s)$/ ) {
			evDur = oneWord ;
		} else if ( oneWord == "|" ) {
			while ( substr( text, at, 1 ) == " " ) { at++ ; }
			if ( substr( text, at, 1 ) == "\"" ) { evComment = quoted( text, at ) ; }
			break ;
		}
	}
}

function firstBody(    bodyNo ) {
	for ( bodyNo = 1 ; bodyNo <= curBodyCount ; bodyNo++ ) { if ( curBody[bodyNo] !~ /^[ \t]*$/ ) { return curBody[bodyNo] ; } }
	return "" ;
}

function bodyValue( prefix,    bodyNo ) {
	for ( bodyNo = 1 ; bodyNo <= curBodyCount ; bodyNo++ ) { if ( index( curBody[bodyNo], prefix ) == 1 ) { return substr( curBody[bodyNo], length( prefix ) + 1 ) ; } }
	return "" ;
}

function bodyText(    bodyNo, outText ) {
	outText = "" ;
	for ( bodyNo = 1 ; bodyNo <= curBodyCount ; bodyNo++ ) { outText = outText ( bodyNo > 1 ? "\n" : "" ) curBody[bodyNo] ; }
	return outText ;
}

## ---- what a Wait waited on, and what it got ----

## A Slack message's text as a reader wants its first line: a date token as its fallback text,
## Slack's own entities decoded (the post escapes them again), a link as its label, and the
## member send's author line -- [sender: …], its emoji, its *_name_* and its `@from → @to.` --
## left out. Sets slackSender to the member a [sender: …] tag names.
function slackText( text,    linkText, labelAt ) {
	slackSender = "" ;
	text = sldFallbacks( text ) ;
	gsub( /&lt;/, "<", text ) ; gsub( /&gt;/, ">", text ) ; gsub( /&amp;/, "\\&", text ) ;
	sub( /^[ \t]+/, "", text ) ;
	if ( match( text, /^\[sender: [^]]*\]/ ) ) { slackSender = substr( text, 10, RLENGTH - 10 ) ; text = substr( text, RLENGTH + 1 ) ; sub( /^[ \t]+/, "", text ) ; }
	sub( /^:[A-Za-z0-9_+-]+:[ \t]*/, "", text ) ;
	sub( /^\*_[^*]*_\*[ \t]*/, "", text ) ;
	sub( /^@[^ ]+ \342\206\222 [^ ]+[.][ \t]*/, "", text ) ;
	while ( match( text, /<(https?|mailto):[^>]*>/ ) ) {
		linkText = substr( text, RSTART + 1, RLENGTH - 2 ) ;
		labelAt = index( linkText, "|" ) ;
		if ( labelAt > 0 ) { linkText = substr( linkText, labelAt + 1 ) ; }
		text = substr( text, 1, RSTART - 1 ) linkText substr( text, RSTART + RLENGTH ) ;
	}
	return text ;
}

## The messages a Wait result holds, `<ts> | <author> | <text>` lines, a text going on over
## the lines after it: waitMsgCount, the first one's author (its [sender: …] member, else
## its account by ETP_USERS) and first line of text, and each one's author by its ts.
function waitRead(    bodyNo, lineText, barAt, tsText, authorText, msgText, firstOpen ) {
	waitMsgCount = 0 ; waitMsgFrom = "" ; waitMsgFirst = "" ; firstOpen = 0 ;
	delete waitAuthorOfTs ;
	for ( bodyNo = 1 ; bodyNo <= curBodyCount ; bodyNo++ ) {
		lineText = curBody[bodyNo] ;
		if ( lineText ~ /^[0-9]+\.[0-9]+ \| [^|]* \|/ ) {
			barAt = index( lineText, " | " ) ;
			tsText = substr( lineText, 1, barAt - 1 ) ;
			msgText = substr( lineText, barAt + 3 ) ;
			barAt = index( msgText, " |" ) ;
			authorText = substr( msgText, 1, barAt - 1 ) ;
			msgText = slackText( substr( msgText, barAt + 2 ) ) ;
			if ( slackSender != "" ) { authorText = slackSender ; }
			else if ( authorText in userName ) { authorText = userName[authorText] ; }
			waitAuthorOfTs[tsText] = authorText ;
			if ( ++waitMsgCount == 1 ) { waitMsgFrom = authorText ; waitMsgFirst = msgText ; firstOpen = ( msgText !~ /[^ \t]/ ) ; }
			continue ;
		}
		if ( substr( lineText, 1, 1 ) == "#" ) { firstOpen = 0 ; continue ; }
		if ( firstOpen && lineText ~ /[^ \t]/ ) { waitMsgFirst = slackText( lineText ) ; firstOpen = 0 ; }
	}
}

## One Wait source as a short name: ask: and the id's first 8 characters; a named
## conversation by its name; a thread as thread (any post in it) or reply (a reply to me),
## DM before it in a direct message; inbox; board:<state>; file:<name>.
function sourceDigest( sourceText,    parts, partCount, dmText ) {
	partCount = split( sourceText, parts, ":" ) ;
	if ( parts[1] == "ask" ) { return "ask:" substr( parts[2], 1, 8 ) ; }
	if ( parts[1] == "inbox" ) { return "inbox" ; }
	if ( parts[1] == "board" ) { return "board:" parts[2] ; }
	if ( parts[1] == "file" ) { return "file:" shortPath( substr( sourceText, 6 ) ) ; }
	if ( parts[1] == "slack" && partCount >= 2 ) {
		if ( parts[2] !~ /^[CDG][A-Z0-9]+$/ ) { return cutText( parts[2], 30 ) ; }
		dmText = ( substr( parts[2], 1, 1 ) == "D" ) ? "DM " : "" ;
		if ( partCount == 2 ) { return ( dmText != "" ? "DM" : "channel" ) ; }
		return dmText ( parts[4] == "conversation" ? "thread" : "reply" ) ;
	}
	return cutText( sourceText, 30 ) ;
}

## A Wait set, space-separated sources, as its short names, each once, `|`-joined.
function waitDigest( setText,    sourceCount, sources, sourceNo, digestText, outText, seenDigest ) {
	sourceCount = split( setText, sources, " " ) ;
	outText = "" ;
	for ( sourceNo = 1 ; sourceNo <= sourceCount ; sourceNo++ ) {
		digestText = sourceDigest( sources[sourceNo] ) ;
		if ( digestText == "" || ( digestText in seenDigest ) ) { continue ; }
		seenDigest[digestText] = 1 ;
		outText = outText ( outText == "" ? "" : "|" ) digestText ;
	}
	return outText ;
}

## The difference of two digested sets, `+added −removed`; "" when they hold the same.
function waitDiff( wasSet, nowSet,    wasCount, wasList, nowCount, nowList, itemNo, inWas, inNow, outText ) {
	wasCount = split( wasSet, wasList, "|" ) ;
	nowCount = split( nowSet, nowList, "|" ) ;
	for ( itemNo = 1 ; itemNo <= wasCount ; itemNo++ ) { inWas[wasList[itemNo]] = 1 ; }
	for ( itemNo = 1 ; itemNo <= nowCount ; itemNo++ ) { inNow[nowList[itemNo]] = 1 ; }
	outText = "" ;
	for ( itemNo = 1 ; itemNo <= nowCount ; itemNo++ ) { if ( ! ( nowList[itemNo] in inWas ) ) { outText = outText ( outText == "" ? "" : " " ) "+" nowList[itemNo] ; } }
	for ( itemNo = 1 ; itemNo <= wasCount ; itemNo++ ) { if ( ! ( wasList[itemNo] in inNow ) ) { outText = outText ( outText == "" ? "" : " " ) "\342\210\222" wasList[itemNo] ; } }
	return outText ;
}

## ---- operations ----

function newOp( name, toolName, subject, who ) {
	opCount++ ;
	opName[opCount] = name ;
	opTool[opCount] = toolName ;
	opSubject[opCount] = subject ;
	opMember[opCount] = who ;
	opCall[opCount] = 0 ;
	opFirstAt[opCount] = evAt ;
	opLastAt[opCount] = evAt ;
	return opCount ;
}

function setField( op, key, value ) {
	if ( value != "" ) { opF[op, key] = value ; }
}

## The member an operation is regarding: its by= where that names a member of the team.
function actorOf(    byName ) {
	byName = evField["by"] ;
	if ( byName != "" && index( teamMembers, " " byName " " ) > 0 ) { return byName ; }
	return member ;
}

## The call a TOOL line or a message event belongs to: the operation just before, when it is
## the same tool's and does not hold this line's kind yet.
function sameTo( op ) {
	if ( evField["to"] == "" || ! ( ( op, "to" ) in opF ) ) { return 1 ; }
	return opF[op, "to"] == cutText( evField["to"], 60 ) ;
}

function targetOf(    keyNo, keyName ) {
	if ( evField["path"] != "" ) { return shortPath( evField["path"] ) ; }
	for ( keyNo = 1 ; keyNo <= targetTotal ; keyNo++ ) {
		if ( targetKeys[keyNo] == "cmd" && evField["cmd"] != "" ) { return cutText( stlCompactCmd( evField["cmd"] ), 60 ) ; }
		if ( evField[targetKeys[keyNo]] != "" ) { return cutText( evField[targetKeys[keyNo]], 60 ) ; }
	}
	for ( keyNo = 1 ; keyNo <= evKeyCount ; keyNo++ ) {
		keyName = evKeys[keyNo] ;
		if ( keyName == "args" || keyName == "message" || evField[keyName] == "" ) { continue ; }
		if ( keyName ~ /(path|cwd|workspace|file)$/ ) { return shortPath( evField[keyName] ) ; }
		return cutText( evField[keyName], 60 ) ;
	}
	return "" ;
}

function takeTool(    toolName, op, pathValue, keyNo, startLine, exitText ) {
	toolName = stlBaseTool( evToolName ) ;
	op = 0 ;
	if ( opCount > 0 && opTool[opCount] == toolName && ! opCall[opCount] && sameTo( opCount ) ) { op = opCount ; }
	if ( op == 0 ) { op = newOp( toolName, toolName, "member", actorOf() ) ; }
	opCall[op] = 1 ;
	opLastAt[op] = evAt ;
	opF[op, "tool"] = cutText( toolName, 60 ) ;
	opF[op, "outcome"] = cutText( evOutcome, 20 ) ;
	if ( evOutcome == "error" ) { opName[op] = "tool error" ; }
	else if ( evOutcome == "refused" ) { opName[op] = "tool refused" ; }
	pathValue = evField["path"] ;
	if ( pathValue == "" ) { pathValue = evField["file"] ; }
	setField( op, "file", shortPath( pathValue ) ) ;
	setField( op, "where", shortPath( evField["path"] ) ) ;
	setField( op, "pattern", cutText( evField["pattern"], 60 ) ) ;
	## A command without the boilerplate that opens it, then cut.
	if ( evField["cmd"] != "" ) { setField( op, "cmd", cutText( stlCompactCmd( evField["cmd"] ), 80 ) ) ; }
	setField( op, "to", cutText( evField["to"], 60 ) ) ;
	## A send's first line from its own line, where no MSG-OUT gave it: one that failed has none.
	if ( toolName == "SendMessage" && ! ( ( op, "message" ) in opF ) ) { setField( op, "message", cutText( evField["message"], 100 ) ) ; }
	## The set a Wait asked for; the set it read, where its result names one, wins.
	if ( toolName == "Wait" && evField["sources"] != "" ) { opWaitAsked[op] = evField["sources"] ; }
	setField( op, "agent", cutText( evField["agent"] != "" ? evField["agent"] : evField["subagent_type"], 60 ) ) ;
	setField( op, "name", cutText( evField["name"] != "" ? evField["name"] : evField["skill"], 60 ) ) ;
	setField( op, "section", cutText( evField["section"], 60 ) ) ;
	setField( op, "url", cutText( evField["url"], 80 ) ) ;
	setField( op, "uri", cutText( evField["uri"], 80 ) ) ;
	setField( op, "query", cutText( evField["query"], 60 ) ) ;
	setField( op, "sources", cutText( evField["sources"], 60 ) ) ;
	setField( op, "headline", cutText( evField["headline"], 100 ) ) ;
	setField( op, "subject", cutText( evField["subject"], 100 ) ) ;
	for ( keyNo = 1 ; keyNo <= simpleTotal ; keyNo++ ) { setField( op, simpleKeys[keyNo], cutText( evField[simpleKeys[keyNo]], 40 ) ) ; }
	if ( evField["background"] == "true" ) { opF[op, "background"] = "background" ; }
	## The lines asked for: from offset, limit of them.
	if ( evField["limit"] ~ /^[0-9]+$/ ) {
		startLine = ( evField["offset"] ~ /^[0-9]+$/ && evField["offset"] + 0 > 0 ) ? evField["offset"] + 0 : 1 ;
		opF[op, "range"] = startLine "\342\200\223" ( startLine + evField["limit"] - 1 ) ;
	} else if ( evField["offset"] ~ /^[0-9]+$/ ) {
		opF[op, "range"] = ( evField["offset"] + 0 ) "\342\200\223" ;
	}
	setField( op, "size", sizeText( evBytes ) ) ;
	setField( op, "result-lines", plural( evLines, "line", "lines" ) ) ;
	setField( op, "entries", plural( evLines, "entry", "entries" ) ) ;
	setField( op, "duration", durationText( evDur ) ) ;
	setField( op, "comment", cutText( evComment, 100 ) ) ;
	if ( evOutcome != "ok" ) { setField( op, "reason", cutText( evFirst != "" ? evFirst : firstBody(), 160 ) ) ; }
	## A command's exit: 0 when it came out ok, else the code its error names.
	if ( toolName == "execute" || toolName == "Bash" ) {
		if ( evOutcome == "ok" && evField["background"] != "true" && evField["job"] == "" ) { opF[op, "exit"] = "0" ; }
		else if ( match( evFirst, /exit code:? *[0-9]+/ ) ) { exitText = substr( evFirst, RSTART, RLENGTH ) ; sub( /^[^0-9]*/, "", exitText ) ; opF[op, "exit"] = exitText ; }
	}
	setField( op, "target", targetOf() ) ;
}

function takeCompanion( eventKind,    toolName, op, resultLine, resultWords, resultText, verdictText, dismissText, dismissTs, byText, whyText, jsonText, summaryText ) {
	toolName = companionTool[eventKind] ;
	if ( eventKind == "MSG-OUT" && evField["tool"] != "" ) { toolName = evField["tool"] ; }
	op = 0 ;
	if ( opCount > 0 && opTool[opCount] == toolName && ! ( ( opCount, eventKind ) in opHas ) && sameTo( opCount ) ) { op = opCount ; }
	if ( op == 0 ) {
		op = newOp( toolName, toolName, "member", actorOf() ) ;
		opF[op, "tool"] = cutText( toolName, 60 ) ;
		opF[op, "outcome"] = "ok" ;
	}
	opHas[op, eventKind] = 1 ;
	opLastAt[op] = evAt ;
	if ( eventKind in sessionKind ) { opSubject[op] = "session" ; }
	setField( op, "to", cutText( evField["to"], 60 ) ) ;
	if ( eventKind == "MSG-OUT" ) {
		if ( toolName == "SendMessage" ) { setField( op, "message", cutText( firstBody(), 100 ) ) ; }
		else {
			## The message tools' own arguments are the body: only their named fields are read.
			jsonText = bodyText() ;
			setField( op, "subject", cutText( stlJsonStr( jsonText, "subject" ), 100 ) ) ;
			setField( op, "headline", cutText( stlJsonStr( jsonText, "headline" ), 100 ) ) ;
			setField( op, "severity", cutText( stlJsonStr( jsonText, "severity" ), 40 ) ) ;
			setField( op, "url", cutText( stlJsonStr( jsonText, "url" ), 80 ) ) ;
			if ( ! ( ( op, "to" ) in opF ) ) { setField( op, "to", cutText( stlJsonStr( jsonText, "to" ), 60 ) ) ; }
		}
	} else if ( eventKind == "HANDBACK" ) {
		summaryText = bodyValue( "outcome: " ) ;
		if ( summaryText ~ /^[ \t]*$/ ) { summaryText = bodyValue( "task: " ) ; }
		if ( summaryText ~ /^[ \t]*$/ ) { summaryText = firstBody() ; }
		setField( op, "summary", cutText( summaryText, 100 ) ) ;
	} else if ( eventKind == "WAIT-RESULT" || eventKind == "DISMISSED" ) {
		## How it resolved: RECEIVED, TIMEOUT with its bound, DISMISSED, CLOSED, or an ask it
		## waited on answered with a verdict.
		resultLine = bodyValue( "WAIT-RESULT: " ) ;
		split( resultLine, resultWords, " " ) ;
		resultText = resultWords[1] ;
		if ( resultText == "TIMEOUT" && match( resultLine, /\([0-9]+s\)/ ) ) { resultText = "TIMEOUT " substr( resultLine, RSTART + 1, RLENGTH - 3 ) " s" ; }
		verdictText = bodyValue( "VERDICT: " ) ;
		if ( resultText == "RECEIVED" && verdictText != "" && verdictText != "UNCLASSIFIED" ) { resultText = "answered " verdictText ; }
		setField( op, "result", cutText( resultText, 40 ) ) ;
		waitRead() ;
		if ( resultText == "DISMISSED" ) {
			## By whom: the author of the message it names, else its first word, with what
			## follows in parentheses as why.
			dismissText = bodyValue( "WAIT-DISMISSED-BY: " ) ;
			byText = dismissText ; whyText = "" ;
			if ( dismissText ~ /^[A-Za-z0-9]+:[0-9]+\.[0-9]+$/ ) {
				dismissTs = substr( dismissText, index( dismissText, ":" ) + 1 ) ;
				if ( dismissTs in waitAuthorOfTs ) { byText = waitAuthorOfTs[dismissTs] ; }
			} else if ( match( dismissText, /[ \t]*\(.*\)$/ ) ) {
				byText = substr( dismissText, 1, RSTART - 1 ) ;
				whyText = substr( dismissText, RSTART, RLENGTH ) ;
				sub( /^[ \t]*\(/, "", whyText ) ; sub( /\)$/, "", whyText ) ;
			}
			setField( op, "by", cutText( byText, 40 ) ) ;
			setField( op, "first", cutText( whyText, 100 ) ) ;
		} else if ( waitMsgCount > 0 ) {
			## From whom, and the first line of what came, with how many more came with it.
			setField( op, "from", cutText( waitMsgFrom, 40 ) ) ;
			setField( op, "first", cutText( waitMsgFirst, 100 ) ) ;
			if ( waitMsgCount > 1 ) { opF[op, "more"] = waitMsgCount - 1 ; }
		}
		## The set it waited on, as its result names it.
		if ( bodyValue( "# sources: " ) != "" ) { opWaitRead[op] = bodyValue( "# sources: " ) ; }
		if ( eventKind == "DISMISSED" && opName[op] != "tool error" && opName[op] != "tool refused" ) { opName[op] = "Wait" ; }
	} else if ( eventKind == "ASK" ) {
		setField( op, "kind", cutText( evField["kind"], 40 ) ) ;
		setField( op, "question", cutText( firstBody(), 100 ) ) ;
	} else if ( eventKind == "SPAWN" ) {
		setField( op, "agent", cutText( evField["agent"], 60 ) ) ;
		setField( op, "session", cutText( substr( bodyValue( "SESSION_ID=" ), 1, 8 ), 8 ) ) ;
		setField( op, "status", cutText( bodyValue( "STATUS=" ), 40 ) ) ;
	}
}

function takeOther( eventKind,    name, op, keyNo, text ) {
	name = eventKind ;
	if ( eventKind == "ENDING" ) { name = "DISMISSED" ; }
	if ( eventKind == "RESULT" && evField["outcome"] == "error" ) { name = "ERROR" ; }
	op = newOp( name, "", ( eventKind in sessionKind ) ? "session" : "member", actorOf() ) ;
	opF[op, "event"] = tolower( eventKind ) ;
	for ( keyNo = 1 ; keyNo <= eventTotal ; keyNo++ ) { setField( op, eventKeys[keyNo], cutText( evField[eventKeys[keyNo]], 60 ) ) ; }
	if ( eventKind == "ROUND" || eventKind == "RESULT" ) {
		opF[op, "in"] = countText( evField["in"] + 0 ) ;
		opF[op, "out"] = countText( evField["out"] + 0 ) ;
		opF[op, "cache"] = countText( evField["cache-read"] + evField["cache-write"] ) ;
	}
	if ( evField["summary"] ~ /^[0-9]+B$/ ) { setField( op, "summary", sizeText( substr( evField["summary"], 1, length( evField["summary"] ) - 1 ) ) ) ; }
	if ( evField["tokens"] != "" ) { setField( op, "tokens", tokensText( cutText( evField["tokens"], 200 ) ) ) ; }
	text = evField["text"] ;
	if ( text == "" ) { text = firstBody() ; }
	setField( op, "text", cutText( text, 120 ) ) ;
	if ( name == "ERROR" ) {
		setField( op, "reason", cutText( firstBody(), 160 ) ) ;
		if ( eventKind == "RESULT" ) { opF[op, "source"] = "result" ; }
	}
}

## The event read so far, with its body, as an operation.
function takeEvent(    eventKind ) {
	if ( curKind == "" ) { return ; }
	eventKind = curKind ;
	curKind = "" ;
	delete evField ;
	evKeyCount = 0 ; evToolName = "" ; evOutcome = "" ; evFirst = "" ; evBytes = "" ; evLines = "" ; evDur = "" ; evComment = "" ;
	## The line's own moment, whole (`YYYY-MM-DDTHH:MM:SSZ`): a span's date token needs the day too.
	evAt = substr( curLine, 1, 20 ) ;
	if ( eventKind == "TOOL" ) { parseTool( curLine ) ; takeTool() ; return ; }
	parseFields( curLine, 23 + length( eventKind ) ) ;
	if ( eventKind in companionTool ) { takeCompanion( eventKind ) ; return ; }
	takeOther( eventKind ) ;
}

## ---- filling ----

## A slot's value: an operation's field while one fills, else the post's. In a title the
## member and the session are sent as they are, since a title's text is not mrkdwn.
function slotValue( name ) {
	if ( fillOp > 0 ) { return ( ( fillOp, name ) in opF ) ? cleanValue( opF[fillOp, name] ) : "" ; }
	if ( name == "member" ) { return ( fillTitle ? titleValue( fillMember != "" ? fillMember : member ) : esc( fillMember != "" ? fillMember : member ) ) ; }
	if ( name == "session" ) { return ( fillTitle ? titleSession : shortSession ) ; }
	if ( name == "span" ) { return fillSpan ; }
	if ( name == "date" ) { return fillDate ; }
	if ( name == "subjects" ) { return fillSubjects ; }
	if ( name == "line-count" ) { return fillLineCount ; }
	if ( name in field ) { return field[name] ; }
	return "" ;
}

## The slots of a text replaced by position, never gsub, so & and \ in a value pass through.
## Counts slotTotal and slotFilled; sets slotsEmpty for this text. An empty slot reads as
## nothing, never a placeholder; outside a group it is required, counted in requiredEmpty.
function fillSlots( text, outside,    done, rest, openAt, closeAt, name, value ) {
	done = "" ; rest = text ; slotsEmpty = 0 ;
	while ( ( openAt = index( rest, "{{" ) ) > 0 ) {
		closeAt = index( substr( rest, openAt + 2 ), "}}" ) ;
		if ( closeAt == 0 ) { break ; }
		name = substr( rest, openAt + 2, closeAt - 1 ) ;
		value = slotValue( name ) ;
		slotTotal++ ;
		if ( value != "" ) { slotFilled++ ; }
		else { slotsEmpty++ ; if ( outside ) { requiredEmpty++ ; } }
		done = done substr( rest, 1, openAt - 1 ) value ;
		rest = substr( rest, openAt + closeAt + 3 ) ;
	}
	return done rest ;
}

## A template line filled: `[[ … ]]` kept only when every slot in it has a value. A line
## whose first field was left out opens with the next one, not with its ` · ` or ` / `.
function fillText( text,    done, rest, openAt, closeAt, inner ) {
	done = "" ; rest = text ; slotTotal = 0 ; slotFilled = 0 ; requiredEmpty = 0 ;
	while ( ( openAt = index( rest, "[[" ) ) > 0 ) {
		closeAt = index( substr( rest, openAt + 2 ), "]]" ) ;
		if ( closeAt == 0 ) { break ; }
		done = done fillSlots( substr( rest, 1, openAt - 1 ), 1 ) ;
		inner = fillSlots( substr( rest, openAt + 2, closeAt - 1 ), 0 ) ;
		if ( slotsEmpty == 0 ) { done = done inner ; }
		rest = substr( rest, openAt + closeAt + 3 ) ;
	}
	done = done fillSlots( rest, 1 ) ;
	if ( substr( done, 1, 4 ) == " \302\267 " ) { done = substr( done, 5 ) ; }
	else if ( substr( done, 1, 3 ) == " / " ) { done = substr( done, 4 ) ; }
	return done ;
}

## A kind's line is left out when a required slot of it is empty, or nothing is left of it.
function kindLineGone( filled ) {
	return ( requiredEmpty > 0 || filled !~ /[^ \t]/ ) ;
}

## A block's span: its first and its last moment, each a Slack date token showing the time
## with seconds, so each reader sees it in their own timezone; one token when both are the same.
function spanOf( fromAt, toAt ) {
	if ( fromAt == "" ) { return "" ; }
	return ( fromAt == toAt || toAt == "" ? sldToken( fromAt, "time-secs" ) : sldToken( fromAt, "time-secs" ) "\342\200\223" sldToken( toAt, "time-secs" ) ) ;
}

## A block's header, for its subject, member and span.
function headerText( subject, who, fromAt, toAt,    text ) {
	fillMember = who ; fillSpan = spanOf( fromAt, toAt ) ;
	text = ( subject in subjectTmpl ) ? fillText( subjectTmpl[subject] ) : "*" esc( who ) "*" ;
	fillMember = "" ; fillSpan = "" ;
	return text ;
}

## One line of the post: its text, its block's header, whether it is that header; for a
## block's own line, the moment it is of and whether it is a context line, a secondary detail.
function addLine( text, header, isHeader, atText, isContext ) {
	outLine[++outCount] = text ;
	outHeader[outCount] = header ;
	outIsHeader[outCount] = isHeader ;
	outAt[outCount] = atText ;
	outContext[outCount] = ( isContext ? 1 : 0 ) ;
}

## A block's header line, with what its box needs: its subject and who it regards.
function addHeader( text, subject, who ) {
	addLine( text, text, 1 ) ;
	outSubject[outCount] = subject ;
	outWho[outCount] = who ;
}

## ---- the boxes: a post as Slack blocks ----

## A value in a box's title: one line, with no backtick to end a code span, and not escaped,
## since a title's text is not mrkdwn.
function titleValue( text ) {
	gsub( /[\t\r\n]/, " ", text ) ;
	gsub( /`/, "%60", text ) ;
	return text ;
}

## A JSON string's body, by the table and the handling of AgentsMcpJsonEscape.awk, as
## AgentsSlackBlocksBuild.awk's jsonEscapeLine has them; a line break is \n.
function jsonText( text,    outText, oneChar ) {
	outText = "" ;
	while ( match( text, /[\\"\001-\037]/ ) ) {
		oneChar = substr( text, RSTART, 1 ) ;
		outText = outText substr( text, 1, RSTART - 1 ) ( oneChar == "\n" ? "\\n" : ( ( oneChar in jsonCtl ) ? jsonCtl[oneChar] : "\\" oneChar ) ) ;
		text = substr( text, RSTART + 1 ) ;
	}
	return outText text ;
}

function listAdd( listText, itemText ) {
	if ( itemText == "" ) { return listText ; }
	return ( listText == "" ? itemText : listText "," itemText ) ;
}

function mrkdwnJson( text ) {
	return "{\"type\":\"mrkdwn\",\"text\":\"" jsonText( text ) "\"}" ;
}

function sectionJson( text ) {
	return "{\"type\":\"section\",\"text\":" mrkdwnJson( text ) "}" ;
}

function contextJson( text ) {
	return "{\"type\":\"context\",\"elements\":[" mrkdwnJson( text ) "]}" ;
}

## One box: a container block of full width, its title, its subtitle where it has one, its children.
function boxJson( titleJson, subtitleText, childrenJson,    outText ) {
	outText = "{\"type\":\"container\",\"width\":\"full\",\"rich_text_title\":{\"type\":\"rich_text\",\"elements\":[{\"type\":\"rich_text_section\",\"elements\":[" titleJson "]}]}" ;
	if ( subtitleText != "" ) { outText = outText ",\"subtitle\":" mrkdwnJson( subtitleText ) ; }
	return outText ",\"child_blocks\":[" childrenJson "]}" ;
}

## One element of a title: a text element, in code style where it was a code span.
function titleElement( text, isCode ) {
	if ( text == "" ) { return "" ; }
	return "{\"type\":\"text\",\"text\":\"" jsonText( text ) "\"" ( isCode ? ",\"style\":{\"code\":true}" : "" ) "}" ;
}

## A box's title, the elements of a rich_text section, from its filled line: a `:name:` that
## opens it is an emoji element by name (a Unicode emoji in a title's text shows as its name),
## a code span a text element in code style, the rest text elements as written. Sets
## titlePlain, the same as plain text: what names the box in the notification text.
function titleElements( text,    outText, tickAt, endAt ) {
	outText = "" ; titlePlain = "" ;
	if ( match( text, /^:[a-z0-9_+-]+:/ ) ) {
		outText = "{\"type\":\"emoji\",\"name\":\"" substr( text, 2, RLENGTH - 2 ) "\"}" ;
		text = substr( text, RLENGTH + 1 ) ;
	}
	while ( text != "" ) {
		tickAt = index( text, "`" ) ;
		endAt = ( tickAt > 0 ) ? index( substr( text, tickAt + 1 ), "`" ) : 0 ;
		if ( endAt < 2 ) { outText = listAdd( outText, titleElement( text, 0 ) ) ; titlePlain = titlePlain text ; break ; }
		outText = listAdd( outText, titleElement( substr( text, 1, tickAt - 1 ), 0 ) ) ;
		outText = listAdd( outText, titleElement( substr( text, tickAt + 1, endAt - 1 ), 1 ) ) ;
		titlePlain = titlePlain substr( text, 1, tickAt - 1 ) substr( text, tickAt + 1, endAt - 1 ) ;
		text = substr( text, tickAt + endAt + 1 ) ;
	}
	sub( /^[ \t]+/, "", titlePlain ) ;
	return outText ;
}

## A box's title for its subject and who it regards; a subject the template gives no title
## is named by who it regards.
function boxTitle( subject, who,    text ) {
	fillMember = who ; fillTitle = 1 ;
	text = ( subject in subjectTitle ) ? fillText( subjectTitle[subject] ) : "" ;
	fillMember = "" ; fillTitle = 0 ;
	if ( text !~ /[^ \t]/ ) { text = titleValue( who != "" ? who : ( subject != "" ? subject : "system" ) ) ; }
	return titleElements( text ) ;
}

## A box's subtitle, its small grey text, for its subject, who it regards and the moment of
## its first line: left out when a required slot of it is empty, so with no date where its
## template requires one. Its date is one Slack date token, made by the shared helper
## (sldTokenAs, AgentsSlackDate.awk) in the format its subject's template gives, its fallback
## the UTC date and time; it is made here, where it is sent, and never escaped. At most 150
## characters, Slack's limit, and never cut inside its date: longer, it is the date alone.
function boxSubtitle( subject, who, atText,    text ) {
	if ( ! ( subject in subjectSubtitle ) ) { return "" ; }
	fillMember = who ; fillDate = sldTokenAs( atText, subjectDateFormat[subject], "date-time" ) ;
	text = fillText( subjectSubtitle[subject] ) ;
	if ( kindLineGone( text ) ) { text = "" ; }
	else if ( charLength( text ) > 150 ) { text = ( fillDate != "" ? fillDate : cutBytes( text, 147 ) ) ; }
	fillMember = "" ; fillDate = "" ;
	return text ;
}

## One child block of the block being built: its JSON, the lines it holds, the moment of its first.
function addChild( jsonValue, lineList, atText ) {
	childTotal++ ;
	childJson[childTotal] = jsonValue ; childLines[childTotal] = lineList ; childAt[childTotal] = atText ;
}

## One block as its boxes, into the units of the post: its lines in sections of at most
## sectionCap characters, a line never cut in two, then its context lines, joined, small and
## grey; at most childCap children to a box, the rest in a further box with the same title,
## its subtitle the moment of its own first line. A block with no header has no box: its
## sections stand alone.
function buildBlock( headAt, firstLine, lastLine,    lineNo, lineText, packText, packLines, packAt, blockAt, fromChild, childNo, boxChildren, boxLines, boxAt, titleText, namePlain ) {
	childTotal = 0 ;
	packText = "" ; packLines = "" ; packAt = "" ;
	for ( lineNo = firstLine ; lineNo <= lastLine ; lineNo++ ) {
		if ( outContext[lineNo] ) { continue ; }
		lineText = outLine[lineNo] ;
		if ( charLength( lineText ) > sectionCap ) { lineText = cutBytes( lineText, sectionCap - 3 ) ; }
		if ( packText != "" && charLength( packText ) + 1 + charLength( lineText ) > sectionCap ) {
			addChild( sectionJson( packText ), packLines, packAt ) ;
			packText = "" ; packLines = "" ; packAt = "" ;
		}
		packText = ( packText == "" ? lineText : packText "\n" lineText ) ;
		packLines = packLines " " lineNo ;
		if ( packAt == "" ) { packAt = outAt[lineNo] ; }
	}
	if ( packText != "" ) { addChild( sectionJson( packText ), packLines, packAt ) ; }
	packText = "" ; packLines = "" ;
	for ( lineNo = firstLine ; lineNo <= lastLine ; lineNo++ ) {
		if ( ! outContext[lineNo] ) { continue ; }
		lineText = outLine[lineNo] ;
		if ( charLength( lineText ) > sectionCap ) { lineText = cutBytes( lineText, sectionCap - 3 ) ; }
		if ( packText != "" && charLength( packText ) + 3 + charLength( lineText ) > sectionCap ) {
			addChild( contextJson( packText ), packLines, "" ) ;
			packText = "" ; packLines = "" ;
		}
		packText = ( packText == "" ? lineText : packText " \302\267 " lineText ) ;
		packLines = packLines " " lineNo ;
	}
	if ( packText != "" ) { addChild( contextJson( packText ), packLines, "" ) ; }
	if ( headAt == 0 ) {
		for ( childNo = 1 ; childNo <= childTotal ; childNo++ ) {
			unitCount++ ;
			unitJson[unitCount] = childJson[childNo] ; unitWeight[unitCount] = 1 ; unitLines[unitCount] = childLines[childNo] ; unitName[unitCount] = "" ;
		}
		return ;
	}
	titleText = boxTitle( outSubject[headAt], outWho[headAt] ) ; namePlain = titlePlain ;
	blockAt = "" ;
	for ( childNo = 1 ; childNo <= childTotal && blockAt == "" ; childNo++ ) { blockAt = childAt[childNo] ; }
	for ( fromChild = 1 ; fromChild <= childTotal ; fromChild += childCap ) {
		boxChildren = "" ; boxLines = "" ; boxAt = "" ;
		for ( childNo = fromChild ; childNo < fromChild + childCap && childNo <= childTotal ; childNo++ ) {
			boxChildren = listAdd( boxChildren, childJson[childNo] ) ;
			boxLines = boxLines childLines[childNo] ;
			if ( boxAt == "" ) { boxAt = childAt[childNo] ; }
		}
		if ( boxAt == "" ) { boxAt = blockAt ; }
		unitCount++ ;
		unitJson[unitCount] = boxJson( titleText, boxSubtitle( outSubject[headAt], outWho[headAt], boxAt ), boxChildren ) ;
		unitWeight[unitCount] = 1 + childNo - fromChild ;
		unitLines[unitCount] = boxLines ;
		unitName[unitCount] = namePlain ;
	}
}

function writePart( basePath, number, text,    path ) {
	path = basePath ".plain." sprintf( "%03d", number ) ;
	printf "%s", text > path ;
	close( path ) ;
}

## A post as plain text, for a Slack that refuses its boxes: the lines it holds, in the
## order given, each block under its header, cut at line boundaries into parts of at most
## cap characters. A part that starts inside a block repeats its header, a header never ends
## a part, and every header but a part's first has one empty line before it.
function writePlain( basePath, lineList,    listTotal, listItems, itemNo, lineNo, lastBlock, plainCount, partTotal, chunk, chunkChars, needText, lineBreak ) {
	delete plainOf ;
	listTotal = split( lineList, listItems, " " ) ;
	for ( itemNo = 1 ; itemNo <= listTotal ; itemNo++ ) { plainOf[listItems[itemNo] + 0] = 1 ; }
	plainCount = 0 ; lastBlock = -1 ;
	for ( lineNo = 1 ; lineNo <= outCount ; lineNo++ ) {
		if ( outIsHeader[lineNo] || ! ( lineNo in plainOf ) ) { continue ; }
		if ( outBlock[lineNo] != lastBlock ) {
			lastBlock = outBlock[lineNo] ;
			if ( lastBlock > 0 ) { plainCount++ ; plainLine[plainCount] = outLine[lastBlock] ; plainHeader[plainCount] = outLine[lastBlock] ; plainIsHeader[plainCount] = 1 ; }
		}
		plainCount++ ; plainLine[plainCount] = outLine[lineNo] ; plainHeader[plainCount] = outHeader[lineNo] ; plainIsHeader[plainCount] = 0 ;
	}
	partTotal = 0 ; chunk = "" ; chunkChars = 0 ;
	for ( lineNo = 1 ; lineNo <= plainCount ; lineNo++ ) {
		needText = plainLine[lineNo] ;
		if ( plainIsHeader[lineNo] && lineNo < plainCount && ! plainIsHeader[lineNo + 1] ) { needText = needText "\n" plainLine[lineNo + 1] ; }
		lineBreak = ( plainIsHeader[lineNo] ? "\n\n" : "\n" ) ;
		if ( chunk != "" && chunkChars + length( lineBreak ) + charLength( needText ) > cap ) { writePart( basePath, ++partTotal, chunk ) ; chunk = "" ; chunkChars = 0 ; }
		if ( chunk == "" && ! plainIsHeader[lineNo] && plainHeader[lineNo] != "" ) { chunk = plainHeader[lineNo] ; chunkChars = charLength( chunk ) ; }
		chunkChars += ( chunk == "" ? 0 : length( lineBreak ) ) + charLength( plainLine[lineNo] ) ;
		chunk = ( chunk == "" ? plainLine[lineNo] : chunk lineBreak plainLine[lineNo] ) ;
	}
	if ( chunk != "" ) { writePart( basePath, ++partTotal, chunk ) ; }
}

## One post's files: <n>.blocks, its boxes as a JSON array; <n>.text, the short text it
## carries beside them, for a notification; <n>.plain.<m>, the same post as plain text.
function writeBoxes( number, blocksText, lineList, nameList,    basePath, path, lineItems, text ) {
	basePath = outDir "/" sprintf( "%06d", number ) ;
	path = basePath ".blocks" ;
	printf "[%s]", blocksText > path ;
	close( path ) ;
	fillSubjects = cutBytes( esc( nameList ), 120 ) ;
	fillLineCount = plural( split( lineList, lineItems, " " ) "", "line", "lines" ) ;
	text = ( notifyTmpl != "" ) ? fillText( notifyTmpl ) : "" ;
	if ( text !~ /[^ \t]/ ) { text = fillLineCount ; }
	fillSubjects = "" ; fillLineCount = "" ;
	path = basePath ".text" ;
	printf "%s", text > path ;
	close( path ) ;
	writePlain( basePath, lineList ) ;
}

BEGIN {
	kind = ENVIRON["ETP_KIND"] ;
	member = ENVIRON["ETP_MEMBER"] ;
	teamMembers = ENVIRON["ETP_MEMBERS"] ;
	shortSession = cleanValue( substr( ENVIRON["ETP_SESSION"], 1, 8 ) ) ;
	## Characters per post of plain text, never configured: Slack's limit for a message's `text`.
	cap = 4000 ;
	## Slack's limits for blocks, never configured: the characters of a section's text, the
	## children of a box, the blocks of a post with every box's children counted too.
	sectionCap = 3000 ; childCap = 10 ; blockCap = 50 ;
	for ( ctlNo = 1 ; ctlNo <= 31 ; ctlNo++ ) { jsonCtl[sprintf( "%c", ctlNo )] = sprintf( "\\u%04x", ctlNo ) ; }
	titleSession = titleValue( substr( ENVIRON["ETP_SESSION"], 1, 8 ) ) ;
	## The moment the post is made, epoch seconds: the time of a kind's own lines.
	nowAt = ( ENVIRON["ETP_NOW"] ~ /^[0-9]+$/ ) ? ENVIRON["ETP_NOW"] : "" ;
	outDir = ENVIRON["ETP_DIR"] ;
	fieldCount = split( ENVIRON["ETP_FIELDS"], fieldLines, "\n" ) ;
	for ( fieldNo = 1 ; fieldNo <= fieldCount ; fieldNo++ ) {
		eqAt = index( fieldLines[fieldNo], "=" ) ;
		if ( eqAt < 2 ) { continue ; }
		fieldName = substr( fieldLines[fieldNo], 1, eqAt - 1 ) ;
		fieldValue = stlRedact( substr( fieldLines[fieldNo], eqAt + 1 ) ) ;
		## A value given as - is no value: no field is ever shown as a placeholder.
		if ( fieldValue == "-" ) { delete field[fieldName] ; continue ; }
		if ( fieldName == "tokens" ) { fieldValue = tokensText( fieldValue ) ; }
		## Escaped as every value is, but for a Slack date token of the helper's own making,
		## which a caller gives for a date or a time and which works only unescaped (sldKeep).
		field[fieldName] = sldKeep( cleanValue( fieldValue ) ) ;
	}
	## Who a Slack account is, by the team's own account cache.
	userCount = split( ENVIRON["ETP_USERS"], userPairs, " " ) ;
	for ( userNo = 1 ; userNo <= userCount ; userNo++ ) {
		eqAt = index( userPairs[userNo], "=" ) ;
		if ( eqAt > 1 ) { userName[substr( userPairs[userNo], 1, eqAt - 1 )] = substr( userPairs[userNo], eqAt + 1 ) ; }
	}
	## The session's previous Wait set, digested, as an earlier post left it.
	waitStateFile = ENVIRON["ETP_WAIT_STATE"] ;
	prevWaitSet = "" ;
	if ( waitStateFile != "" ) {
		if ( ( getline prevWaitSet < waitStateFile ) <= 0 ) { prevWaitSet = "" ; }
		close( waitStateFile ) ;
	}
	companionTool["MSG-OUT"] = "SendMessage" ;
	companionTool["HANDBACK"] = "SubagentHandback" ;
	companionTool["WAIT-RESULT"] = "Wait" ;
	companionTool["DISMISSED"] = "Wait" ;
	companionTool["ASK"] = "AskUserQuestion" ;
	companionTool["ANSWER"] = "AskUserQuestion" ;
	companionTool["SPAWN"] = "Agent" ;
	sessionTotal = split( "START END MODEL RESTART HANDBACK DISMISSED ENDING REVIEW VERDICT", sessionList, " " ) ;
	for ( sessionNo = 1 ; sessionNo <= sessionTotal ; sessionNo++ ) { sessionKind[sessionList[sessionNo]] = 1 ; }
	simpleTotal = split( "mode job handle kind severity pages view state server task_id shell_id", simpleKeys, " " ) ;
	targetTotal = split( "pattern cmd to agent subagent_type name skill url query sources job handle task_id", targetKeys, " " ) ;
	eventTotal = split( "n turns model service host tier item kind by at source exit outcome", eventKeys, " " ) ;
}

## The template: the kind's block under `# Skeleton`, every subject and operation line.
FNR == NR {
	if ( $0 ~ /^# / ) { section = $0 ; sub( /[ \t]+$/, "", section ) ; heading = "" ; inBlock = 0 ; next ; }
	if ( $0 ~ /^## / ) { heading = substr( $0, 4 ) ; sub( /[ \t]+$/, "", heading ) ; inBlock = 0 ; next ; }
	if ( heading == "" ) { next ; }
	if ( $0 ~ /^```/ ) { inBlock = ! inBlock ; if ( ! inBlock ) { heading = "" ; } next ; }
	if ( ! inBlock ) { next ; }
	if ( section == "# Skeleton" && heading == kind ) {
		tmpl[++tmplCount] = $0 ; blockDone = 1 ;
		## A line that opens with {{context}} is a secondary detail: a context line of its box.
		if ( index( $0, "{{context}}" ) == 1 ) { tmpl[tmplCount] = substr( $0, 12 ) ; tmplContext[tmplCount] = 1 ; }
	}
	else if ( section == "# Subjects" ) {
		## A subject's box: its title, its subtitle and the date format in it, each by its mark;
		## the line with no mark is its header in the plain-text rendering.
		if ( index( $0, "{{title}}" ) == 1 ) { subjectTitle[heading] = substr( $0, 10 ) ; }
		else if ( index( $0, "{{subtitle}}" ) == 1 ) { subjectSubtitle[heading] = substr( $0, 13 ) ; }
		else if ( index( $0, "{{date-format}}" ) == 1 ) { subjectDateFormat[heading] = substr( $0, 16 ) ; }
		else if ( ! ( heading in subjectTmpl ) ) { subjectTmpl[heading] = $0 ; }
	}
	else if ( section == "# Operations" && ! ( heading in opTmpl ) ) { opTmpl[heading] = $0 ; }
	else if ( section == "# Notification" && notifyTmpl == "" ) { notifyTmpl = $0 ; }
	next ;
}

## The lines: an event line with its `> ` body lines is one operation; any other line a text one.
{
	if ( substr( $0, 1, 1 ) == ">" && curKind != "" ) {
		curBody[++curBodyCount] = ( substr( $0, 1, 2 ) == "> " ) ? substr( $0, 3 ) : substr( $0, 2 ) ;
		next ;
	}
	takeEvent() ;
	if ( isEventLine( $0 ) ) {
		curLine = $0 ;
		split( $0, curWords, " " ) ;
		curKind = curWords[2] ;
		curBodyCount = 0 ;
		next ;
	}
	if ( $0 ~ /^[ \t]*$/ ) { next ; }
	evAt = "" ;
	textOp = newOp( "text", "", "", member ) ;
	opF[textOp, "text"] = cutText( $0, 300 ) ;
}

END {
	takeEvent() ;
	if ( ! blockDone || tmplCount == 0 ) { exit 3 ; }
	## The longest an operation's line may be, so a block's header and the line fit one post.
	lineCap = cap - 200 ;
	if ( lineCap < 64 ) { lineCap = 64 ; }
	## What each Wait waited on: the set its result read, else the one it asked for, shown whole
	## on the session's first Wait, then only where it differs from the one before, as a
	## difference; an error waited on nothing, and a Wait whose set is unknown changes nothing.
	waitSeen = 0 ;
	for ( op = 1 ; op <= opCount ; op++ ) {
		if ( opName[op] != "Wait" ) { continue ; }
		waitSetText = ( op in opWaitRead ) ? opWaitRead[op] : opWaitAsked[op] ;
		if ( waitSetText == "" ) { continue ; }
		waitNow = waitDigest( waitSetText ) ;
		if ( waitNow == "" ) { continue ; }
		if ( prevWaitSet == "" ) { waitOn = waitNow ; gsub( /[|]/, ", ", waitOn ) ; }
		else { waitOn = waitDiff( prevWaitSet, waitNow ) ; }
		setField( op, "on", waitOn ) ;
		prevWaitSet = waitNow ; waitSeen = 1 ;
	}
	if ( waitSeen && waitStateFile != "" ) { printf "%s\n", prevWaitSet > waitStateFile ; close( waitStateFile ) ; }
	## The kind's own block: its subject's header, then its lines, a line with a required slot
	## empty, or with nothing left, left out.
	kindSubject = "" ; currentHeader = "" ; currentKey = "" ; lineNo = 1 ;
	if ( substr( tmpl[1], 1, 10 ) == "{{subject:" && substr( tmpl[1], length( tmpl[1] ) - 1 ) == "}}" ) {
		kindSubject = substr( tmpl[1], 11, length( tmpl[1] ) - 12 ) ;
		currentHeader = headerText( kindSubject, member, "", "" ) ;
		currentKey = kindSubject SUBSEP member ;
		addHeader( currentHeader, kindSubject, member ) ;
		lineNo = 2 ;
	}
	## A kind's own line is of the moment the post is made.
	opsAt = 0 ;
	for ( ; lineNo <= tmplCount ; lineNo++ ) {
		if ( tmpl[lineNo] == "{{operations}}" ) { opsAt = lineNo ; break ; }
		filled = fillText( tmpl[lineNo] ) ;
		if ( kindLineGone( filled ) ) { continue ; }
		addLine( cutBytes( filled, lineCap ), currentHeader, 0, nowAt, ( lineNo in tmplContext ) ) ;
	}
	## The operations, a block each time the subject changes: a run of them regarding the same
	## subject, an immediate one too, shares one header.
	lastComment = "" ;
	for ( op = 1 ; op <= opCount ; op++ ) {
		if ( opSubject[op] == "" ) { opSubject[op] = ( kindSubject != "" ? kindSubject : "system" ) ; }
		if ( opName[op] in opTmpl ) { opText = opTmpl[opName[op]] ; }
		else if ( opTool[op] != "" ) { opText = opTmpl["tool"] ; }
		else { opText = opTmpl["event"] ; }
		if ( opText == "" ) { continue ; }
		## A comment shows once, not again on the next line that has the same.
		if ( index( opText, "{{comment}}" ) > 0 && ( ( op, "comment" ) in opF ) ) {
			if ( opF[op, "comment"] == lastComment ) { delete opF[op, "comment"] ; }
			else { lastComment = opF[op, "comment"] ; }
		}
		opKey = opSubject[op] SUBSEP ( opSubject[op] == "member" ? opMember[op] : member ) ;
		if ( opKey != currentKey ) {
			## The block's span: this operation to the last one before the subject changes.
			blockLast = opLastAt[op] ;
			for ( nextOp = op + 1 ; nextOp <= opCount ; nextOp++ ) {
				nextSubject = ( opSubject[nextOp] != "" ? opSubject[nextOp] : ( kindSubject != "" ? kindSubject : "system" ) ) ;
				if ( nextSubject SUBSEP ( nextSubject == "member" ? opMember[nextOp] : member ) != opKey ) { break ; }
				if ( opLastAt[nextOp] != "" ) { blockLast = opLastAt[nextOp] ; }
			}
			currentHeader = headerText( opSubject[op], opSubject[op] == "member" ? opMember[op] : member, opFirstAt[op], blockLast ) ;
			currentKey = opKey ;
			addHeader( currentHeader, opSubject[op], opSubject[op] == "member" ? opMember[op] : member ) ;
		}
		fillOp = op ;
		addLine( cutBytes( fillText( opText ), lineCap ), currentHeader, 0, opFirstAt[op], 0 ) ;
		fillOp = 0 ;
	}
	for ( lineNo = opsAt + 1 ; opsAt > 0 && lineNo <= tmplCount ; lineNo++ ) {
		filled = fillText( tmpl[lineNo] ) ;
		if ( kindLineGone( filled ) ) { continue ; }
		addLine( cutBytes( filled, lineCap ), currentHeader, 0, nowAt, ( lineNo in tmplContext ) ) ;
	}
	## A header goes only with a line under it: one whose block was left with none is dropped.
	keptCount = 0 ;
	for ( lineNo = 1 ; lineNo <= outCount ; lineNo++ ) {
		if ( outIsHeader[lineNo] && ( lineNo == outCount || outIsHeader[lineNo + 1] ) ) { continue ; }
		keptCount++ ;
		outLine[keptCount] = outLine[lineNo] ; outHeader[keptCount] = outHeader[lineNo] ; outIsHeader[keptCount] = outIsHeader[lineNo] ;
		outAt[keptCount] = outAt[lineNo] ; outContext[keptCount] = outContext[lineNo] ; outSubject[keptCount] = outSubject[lineNo] ; outWho[keptCount] = outWho[lineNo] ;
	}
	outCount = keptCount ;
	## The boxes: each block one box, or more where it outgrows one (buildBlock), each line
	## marked with the block it is in.
	lineNo = 1 ; unitCount = 0 ;
	while ( lineNo <= outCount ) {
		headAt = 0 ;
		if ( outIsHeader[lineNo] ) { headAt = lineNo ; lineNo++ ; }
		firstLine = lineNo ;
		while ( lineNo <= outCount && ! outIsHeader[lineNo] ) { outBlock[lineNo] = headAt ; lineNo++ ; }
		buildBlock( headAt, firstLine, lineNo - 1 ) ;
	}
	## Into posts of at most blockCap blocks, a box's children counted too, cut between boxes:
	## what is beyond goes in the next post. Each post is named, for its notification text, by
	## its boxes' titles, each once.
	postTotal = 0 ; postBlocks = "" ; postWeight = 0 ; postLines = "" ; postNames = "" ;
	for ( unitNo = 1 ; unitNo <= unitCount ; unitNo++ ) {
		if ( postBlocks != "" && postWeight + unitWeight[unitNo] > blockCap ) {
			writeBoxes( ++postTotal, postBlocks, postLines, postNames ) ;
			postBlocks = "" ; postWeight = 0 ; postLines = "" ; postNames = "" ; delete postNamed ;
		}
		postBlocks = listAdd( postBlocks, unitJson[unitNo] ) ;
		postWeight += unitWeight[unitNo] ;
		postLines = postLines unitLines[unitNo] ;
		if ( unitName[unitNo] != "" && ! ( unitName[unitNo] in postNamed ) ) {
			postNamed[unitName[unitNo]] = 1 ;
			postNames = postNames ( postNames == "" ? "" : ", " ) unitName[unitNo] ;
		}
	}
	if ( postBlocks != "" ) { writeBoxes( ++postTotal, postBlocks, postLines, postNames ) ; }
	exit 0 ;
}
