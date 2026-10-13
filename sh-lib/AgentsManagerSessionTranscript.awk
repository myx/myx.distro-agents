#!/usr/bin/awk -f
##
## AgentsManagerSessionTranscript.awk -- the three small readers behind
## --manager-session-transcript-read (AgentsTools.ManagerSession.include), chosen by
## -v transcriptMode. Loaded after AgentsSessionTranscriptFormat.awk, for its redaction
## (stlRedact); run with LC_ALL=C. stdin is the text, one run's at a time.
##   tail  stdin is the end of a run's transcript, as tail(1) cut it. -v wantLines is how many
##         lines were asked for, -v linesBefore whether lines stand before the text given
##         (0 for none). Prints `cut` or `whole`, whether anything of the transcript is left
##         out, then the fewest whole events at the end of the text that hold at least
##         wantLines lines. An event is its head line with the `> ` lines of its body, so
##         what is printed never starts in the middle of a body.
##   feed  stdin is the rows the tracking post's own renderer gives for those lines
##         (AgentsEventTrackPostFill.awk with ETP_ROWS): moment, subject, who it regards,
##         text. Prints each as `feed <time> <spawn-id> <member> <subject> <regarding> <text>`,
##         a line with no moment of its own taking the one before it.
##   log   stdin is the end of a run's session log. Prints each line as
##         `log <spawn-id> <member> <text>`: its token-like values redacted as the transcript
##         redacts them, then exact, a backslash written `\\`, a TAB `\t`, a carriage return `\r`.
## The run a row is of comes in the environment, MDAT_MANAGER_SPAWN and MDAT_MANAGER_MEMBER.
##

function exactText(textValue,    outText, oneChar) {
	if (textValue !~ /[\\\t\r]/) return textValue ;
	outText = "" ;
	while (match(textValue, /[\\\t\r]/)) {
		oneChar = substr(textValue, RSTART, 1) ;
		outText = outText substr(textValue, 1, RSTART - 1) ( oneChar == "\\" ? "\\\\" : ( oneChar == "\t" ? "\\t" : "\\r" ) ) ;
		textValue = substr(textValue, RSTART + 1) ;
	}
	return outText textValue ;
}

BEGIN {
	OFS = "\t" ;
	rowSpawn = ENVIRON["MDAT_MANAGER_SPAWN"] ; if (rowSpawn == "") rowSpawn = "-" ;
	rowMember = ENVIRON["MDAT_MANAGER_MEMBER"] ; if (rowMember == "") rowMember = "-" ;
	feedMoment = "-" ;
}

transcriptMode == "tail" {
	## A line that is no body line opens an event; so does the first line, whatever it is.
	if (substr($0, 1, 1) != ">" || eventTotal == 0) { eventTotal++ ; eventLines[eventTotal] = 0 ; }
	tailLine[++tailTotal] = $0 ;
	eventLines[eventTotal]++ ;
	next ;
}

transcriptMode == "feed" {
	tabAt = index($0, "\t") ; if (tabAt == 0) next ;
	feedAt = substr($0, 1, tabAt - 1) ; feedRest = substr($0, tabAt + 1) ;
	if (feedAt != "-" && feedAt != "") feedMoment = feedAt ;
	print "feed", feedMoment, rowSpawn, rowMember, feedRest ;
	next ;
}

transcriptMode == "log" {
	print "log", rowSpawn, rowMember, exactText(stlRedact($0)) ;
	next ;
}

END {
	if (transcriptMode != "tail") exit 0 ;
	tailFirst = 1 ; tailHeld = tailTotal ;
	for (eventAt = 1 ; eventAt < eventTotal && tailHeld - eventLines[eventAt] >= wantLines + 0 ; eventAt++) {
		tailHeld -= eventLines[eventAt] ;
		tailFirst += eventLines[eventAt] ;
	}
	print ( ( linesBefore + 0 > 0 || tailFirst > 1 ) ? "cut" : "whole" ) ;
	for (tailAt = tailFirst ; tailAt <= tailTotal ; tailAt++) print tailLine[tailAt] ;
}
