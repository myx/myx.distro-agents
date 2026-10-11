#!/usr/bin/env awk
# The shared filling of a tooling template (sh-lib/templates/, AgentsTools.ToolingTemplate.include):
# a template's blocks read by section and heading, and a block filled by its marks, `{{slot}}`
# and `[[ kept only when every slot in it has a value ]]` -- the marks and the rule
# AgentsEventTrackPostFill.awk fills its own lines by. Functions only: loaded with -f ahead of
# the program that composes one message, which defines ttSlot( name ), the value of a slot.
# A group may span lines here, so a heading goes or stays with the field under it.

## Reads a template: under each `# Section`, the first fenced block of each `## heading`, kept
## whole in ttBlock[section, heading], its lines joined by a line break; ttHas says it is
## there. A line inside a fence is never a heading. Returns 1 when the file was read.
function ttRead( file,    line, section, heading, inBlock, key, lineCount, got ) {
	section = "" ; heading = "" ; inBlock = 0 ; key = "" ; lineCount = 0 ;
	while ( ( got = ( getline line < file ) ) > 0 ) {
		if ( ! inBlock && line ~ /^# / ) { section = substr( line, 3 ) ; sub( /[ \t]+$/, "", section ) ; heading = "" ; continue ; }
		if ( ! inBlock && line ~ /^## / ) { heading = substr( line, 4 ) ; sub( /[ \t]+$/, "", heading ) ; continue ; }
		if ( heading == "" ) { continue ; }
		if ( line ~ /^```/ ) {
			inBlock = ! inBlock ;
			if ( ! inBlock ) { heading = "" ; continue ; }
			key = section SUBSEP heading ;
			ttHas[key] = 1 ; ttBlock[key] = "" ; lineCount = 0 ;
			continue ;
		}
		if ( inBlock ) { ttBlock[key] = ( lineCount++ ? ttBlock[key] "\n" : "" ) line ; }
	}
	close( file ) ;
	return ( got == 0 ) ;
}

## The slots of a text replaced by position, never gsub, so & and \ in a value pass through.
## Sets ttSlotsEmpty for this text. An empty slot reads as nothing, never a placeholder;
## outside a group it is required: counted in ttRequiredEmpty, the first one named in
## ttRequiredName.
function ttFillSlots( text, outside,    done, rest, openAt, closeAt, name, value ) {
	done = "" ; rest = text ; ttSlotsEmpty = 0 ;
	while ( ( openAt = index( rest, "{{" ) ) > 0 ) {
		closeAt = index( substr( rest, openAt + 2 ), "}}" ) ;
		if ( closeAt == 0 ) { break ; }
		name = substr( rest, openAt + 2, closeAt - 1 ) ;
		value = ttSlot( name ) ;
		if ( value == "" ) {
			ttSlotsEmpty++ ;
			if ( outside && ! ttRequiredEmpty++ ) { ttRequiredName = name ; }
		}
		done = done substr( rest, 1, openAt - 1 ) value ;
		rest = substr( rest, openAt + closeAt + 3 ) ;
	}
	return done rest ;
}

## A block filled: `[[ … ]]` kept only when every slot in it has a value. A value is never
## read again for marks, so a `{{` or a `[[` in it passes through as written.
function ttFill( text,    done, rest, openAt, closeAt, inner ) {
	done = "" ; rest = text ; ttRequiredEmpty = 0 ; ttRequiredName = "" ;
	while ( ( openAt = index( rest, "[[" ) ) > 0 ) {
		closeAt = index( substr( rest, openAt + 2 ), "]]" ) ;
		if ( closeAt == 0 ) { break ; }
		done = done ttFillSlots( substr( rest, 1, openAt - 1 ), 1 ) ;
		inner = ttFillSlots( substr( rest, openAt + 2, closeAt - 1 ), 0 ) ;
		if ( ttSlotsEmpty == 0 ) { done = done inner ; }
		rest = substr( rest, openAt + closeAt + 3 ) ;
	}
	return done ttFillSlots( rest, 1 ) ;
}
