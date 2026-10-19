#!/usr/bin/env awk
# Fills the tool index (sh-lib/templates/tool-index.document.format.md) from the generator's input
# (AgentsToolsToolIndexData, AgentsTools.InternOpToolIndex.include): its path in TIX_DATA, one
# TAB-separated row a line -- member, shell, calls, may and holds rows. It reads each tool file's
# help (the syntax lines, the Summary, the entries of the Options) and the tools' declarations
# (the harness's tools list, the MCP server's own tools) itself, each file once. The slots are
# filled by the one shared filler, loaded ahead of this file (AgentsToolsToolingTemplateFill,
# AgentsToolingTemplateFill.awk). Nothing here depends on a date, a time or an order of input
# that is not byte order: the same inputs give the same bytes.
# Exit 3: the template lacks a block. Exit 4: the input cannot be read.

## A text's first sentence, its white space closed up, at most 120 characters: cut at the last
## word that fits, with `...`. A full stop of `e.g.`, `i.e.` or `etc.` ends no sentence.
function tixSentence( text,    at, size, ahead, cut ) {
	gsub( /[ \t\r\n]+/, " ", text ) ; sub( /^ /, "", text ) ; sub( / $/, "", text )
	size = length( text )
	for ( at = 1 ; at <= size ; at++ ) {
		if ( substr( text, at, 1 ) != "." ) continue
		ahead = ( at == size ) ? " " : substr( text, at + 1, 1 )
		if ( ahead != " " ) continue
		if ( at >= 4 && substr( text, at - 3, 4 ) ~ /^(e\.g|i\.e|etc)\.$/ ) continue
		text = substr( text, 1, at ) ; break
	}
	if ( length( text ) <= 120 ) return text
	cut = substr( text, 1, 117 ) ; sub( / [^ ]*$/, "", cut )
	return cut "..."
}

## A JSON string's text from just after its opening quote, to its closing one, its escapes read.
function tixJsonString( text,    at, size, ch, out, next1 ) {
	out = "" ; size = length( text )
	for ( at = 1 ; at <= size ; at++ ) {
		ch = substr( text, at, 1 )
		if ( ch == "\"" ) break
		if ( ch == "\\" && at < size ) {
			next1 = substr( text, ++at, 1 )
			if ( next1 == "n" || next1 == "t" || next1 == "r" ) out = out " "
			else if ( next1 == "u" ) { out = out "\\u" }
			else out = out next1
			continue
		}
		out = out ch
	}
	return out
}

## One tool file's help: its operations in the order of its syntax lines, each once, with its
## family, its entry's first sentence, and the Summary's. Entry heads one after another share
## the text under them: entryOp holds them all, by spaces.
function tixReadHelp( file, help,    line, part, op, words, zone, entryOp, collecting, text, lastHead ) {
	opCount[file] = 0 ; summary[file] = "" ; zone = "syntax" ; entryOp = "" ; collecting = 0 ; text = "" ; lastHead = 0
	if ( help == "" ) return
	while ( ( getline line < help ) > 0 ) {
		if ( line ~ /^##  Summary:/ ) { zone = "summary" ; text = "" ; continue }
		if ( line ~ /^##  Options:/ ) { zone = "options" ; continue }
		if ( line ~ /^##  / ) { tixEntryEnd( file, entryOp, text ) ; entryOp = "" ; zone = "other" ; continue }
		if ( zone == "syntax" ) {
			if ( index( line, "📘 syntax: " ) != 1 ) continue
			part = substr( line, length( "📘 syntax: " ) + 1 )
			if ( split( part, words, " " ) < 2 ) continue
			op = words[2] ; gsub( /[][]/, "", op )
			if ( op !~ /^--/ || ( ( file, op ) in opSeen ) ) continue
			opSeen[file, op] = 1
			opName[file, ++opCount[file]] = op
			opFamily[file, opCount[file]] = tixFamily( op )
			familyCount[file, tixFamily( op )]++
			continue
		}
		if ( zone == "summary" ) {
			if ( summary[file] != "" ) continue
			if ( line ~ /^[ \t]*$/ ) { if ( text != "" ) summary[file] = tixSentence( text ) ; continue }
			text = text " " line
			continue
		}
		if ( zone != "options" ) continue
		if ( line ~ /^\t\t--/ ) {
			op = line ; sub( /^\t\t/, "", op ) ; sub( /[ \t].*$/, "", op )
			if ( lastHead ) { entryOp = entryOp " " op ; continue }
			tixEntryEnd( file, entryOp, text )
			entryOp = op ; text = "" ; collecting = 1 ; lastHead = 1
			continue
		}
		lastHead = 0
		if ( entryOp == "" || ! collecting ) continue
		## The entry's first paragraph; one that starts with an option of its own is no
		## description, and a `--` inside the paragraph is part of its text.
		if ( line ~ /^[ \t]*$/ ) { if ( text != "" ) collecting = 0 ; continue }
		if ( text == "" && line ~ /^\t\t\t--/ ) { collecting = 0 ; continue }
		text = text " " line
	}
	tixEntryEnd( file, entryOp, text )
	close( help )
}
function tixEntryEnd( file, ops, text,    list, count, at ) {
	if ( ops == "" || text == "" ) return
	count = split( ops, list, " " )
	for ( at = 1 ; at <= count ; at++ ) if ( ! ( ( file, list[at] ) in entry ) ) entry[file, list[at]] = tixSentence( text )
}

## An operation's family: `--` and its first word with the dash after it, or the whole
## operation where its name is one word.
function tixFamily( op,    rest, dash ) {
	rest = substr( op, 3 ) ; dash = index( rest, "-" )
	return dash ? "--" substr( rest, 1, dash ) : op
}

## The tools one file declares, `"name":"<tool>","description":"...`, in its order, each once
## across the files read.
function tixReadTools( file,    line, name, start ) {
	if ( file == "" ) return
	while ( ( getline line < file ) > 0 ) {
		while ( match( line, /"name":"[A-Za-z_]+","description":"/ ) ) {
			name = substr( line, RSTART + 8 ) ; sub( /".*$/, "", name )
			start = RSTART + RLENGTH
			if ( ! ( name in toolSeen ) ) {
				toolSeen[name] = 1
				toolName[++toolCount] = name
				toolText[name] = tixSentence( tixJsonString( substr( line, start ) ) )
			}
			line = substr( line, start )
		}
	}
	close( file )
}

## Members joined for a hint: in byte order, by ` or `.
function tixJoin( list, count,    at, out ) {
	out = ""
	for ( at = 1 ; at <= count ; at++ ) out = out ( at > 1 ? " or " : "" ) list[at]
	return out
}

## The value the shared filler asks for (AgentsToolingTemplateFill.awk).
function ttSlot( name ) {
	if ( name == "member" ) return curMember
	if ( name == "file" ) return curFile
	if ( name == "command" ) return curCommand
	if ( name == "summary" ) return curSummary
	if ( name == "op" ) return curOp
	if ( name == "description" ) return curText
	if ( name == "family" ) return curFamily
	if ( name == "count" ) return curCount
	if ( name == "owners" ) return curOwners
	if ( name == "tool" ) return curTool
	return ""
}
function tixBlock( name ) {
	if ( ! ( ( "Skeleton" SUBSEP name ) in ttHas ) ) { tixFailed = 3 ; return }
	print ttFill( ttBlock["Skeleton", name] )
}

BEGIN {
	if ( ! ttRead( ARGV[1] ) ) { exit 3 }
	for ( need = split( "head member shell shell-file shell-file-bare op op-bare family-held family-console family-closed calls call call-held", needs, " " ) ; need > 0 ; need-- )
		if ( ! ( ( "Skeleton" SUBSEP needs[need] ) in ttHas ) ) exit 3
	dataFile = ENVIRON["TIX_DATA"]
	if ( dataFile == "" ) exit 4
	while ( ( got = ( getline row < dataFile ) ) > 0 ) {
		fieldCount = split( row, f, "\t" )
		if ( f[1] == "member" && f[2] != "" ) member[++memberCount] = f[2]
		else if ( f[1] == "shell" ) { shellFile[++shellCount] = f[2] ; shellCommand[shellCount] = f[3] ; shellHelp[shellCount] = f[4] }
		else if ( f[1] == "calls" ) { harnessTools = f[2] ; mcpTools = f[3] }
		else if ( f[1] == "may" ) {
			checked[f[2]] = 1 ; may[f[2], f[3]] = ( f[4] == "yes" )
			if ( f[4] == "yes" && f[3] != "" ) mayList[f[2], ++mayCount[f[2]]] = f[3]
		}
		else if ( f[1] == "holds" ) { holds[f[2], f[3]] = 1 ; holdList[f[2], ++holdCount[f[2]]] = f[3] }
	}
	if ( got < 0 ) exit 4
	close( dataFile )
	for ( s = 1 ; s <= shellCount ; s++ ) tixReadHelp( shellFile[s], shellHelp[s] )
	tixReadTools( harnessTools ) ; tixReadTools( mcpTools )

	tixBlock( "head" )
	for ( m = 1 ; m <= memberCount ; m++ ) {
		curMember = member[m]
		tixBlock( "member" )
		tixBlock( "shell" )
		for ( s = 1 ; s <= shellCount ; s++ ) {
			curFile = shellFile[s] ; curCommand = shellCommand[s] ; curSummary = summary[curFile]
			if ( shellHelp[s] == "" || opCount[curFile] == 0 ) { tixBlock( "shell-file-bare" ) ; continue }
			tixBlock( "shell-file" )
			split( "", familyShown )
			for ( o = 1 ; o <= opCount[curFile] ; o++ ) {
				curOp = opName[curFile, o] ; curFamily = opFamily[curFile, o]
				if ( ! ( curFamily in checked ) || may[curFamily, curMember] ) {
					if ( ( curFile, curOp ) in entry ) { curText = entry[curFile, curOp] ; tixBlock( "op" ) }
					else tixBlock( "op-bare" )
					continue
				}
				if ( curFamily in familyShown ) continue
				familyShown[curFamily] = 1
				curCount = familyCount[curFile, curFamily]
				split( "", owners ) ; ownerCount = 0
				for ( k = 1 ; k <= mayCount[curFamily] ; k++ ) owners[++ownerCount] = mayList[curFamily, k]
				curOwners = tixJoin( owners, ownerCount )
				if ( ownerCount ) tixBlock( "family-held" )
				else if ( may[curFamily, ""] ) tixBlock( "family-console" )
				else tixBlock( "family-closed" )
			}
		}
		tixBlock( "calls" )
		for ( t = 1 ; t <= toolCount ; t++ ) {
			curTool = toolName[t] ; curText = toolText[curTool]
			if ( ! holdCount[curTool] || ( ( curTool, curMember ) in holds ) || ( ( curTool, "*" ) in holds ) ) { tixBlock( "call" ) ; continue }
			split( "", owners ) ; ownerCount = 0
			for ( k = 1 ; k <= holdCount[curTool] ; k++ ) owners[++ownerCount] = holdList[curTool, k]
			curOwners = tixJoin( owners, ownerCount )
			tixBlock( "call-held" )
		}
	}
	exit tixFailed
}
