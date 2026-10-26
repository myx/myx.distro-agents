#!/usr/bin/env awk
# Fills an inbox-item document template (sh-lib/templates/inbox-item.<type>.document.format.md) from the
# member's slots. The slots travel in a file, its path in IDS_SLOTS, one slot a line: `key: value` is a
# single-line slot; a `key:` line alone opens a multi-line slot whose value is the indented lines that
# follow, until the next column-0 `key:` line. Blank lines inside a multi-line value are kept. The slots
# are filled by the one shared filler, loaded ahead of this file (AgentsToolsToolingTemplateFill,
# AgentsToolingTemplateFill.awk): by position, never gsub, so & and \ in a value pass through literally.
# A slot the template does not name stays unused. Exit 3: the template lacks its document block. Exit 4:
# the slots file cannot be read.

## The leading and trailing blank lines of a multi-line value dropped, its common indentation stripped,
## its blank lines kept. A single-line value is returned unchanged.
function idsClean( v,    lines, n, i, first, last, min, indent, line, out ) {
	n = split( v, lines, "\n" )
	first = 1 ; last = n
	while ( first <= n && lines[first] ~ /^[[:space:]]*$/ ) first++
	while ( last >= first && lines[last] ~ /^[[:space:]]*$/ ) last--
	if ( first > last ) return ""
	min = -1
	for ( i = first ; i <= last ; i++ ) {
		if ( lines[i] ~ /^[[:space:]]*$/ ) continue
		indent = 0
		while ( indent < length( lines[i] ) && ( substr( lines[i], indent + 1, 1 ) == " " || substr( lines[i], indent + 1, 1 ) == "\t" ) ) indent++
		if ( min < 0 || indent < min ) min = indent
	}
	if ( min <= 0 ) {
		out = ""
		for ( i = first ; i <= last ; i++ ) out = out ( i > first ? "\n" : "" ) lines[i]
		return out
	}
	out = ""
	for ( i = first ; i <= last ; i++ ) {
		line = lines[i]
		if ( i > first ) out = out "\n"
		out = out ( line ~ /^[[:space:]]*$/ ? line : substr( line, min + 1 ) )
	}
	return out
}

## The slots, read from IDS_SLOTS into slot[name].
function idsRead( file,    line, key, val, cur, first ) {
	cur = "" ; first = 1
	while ( ( getline line < file ) > 0 ) {
		if ( line ~ /^[a-z][a-z0-9-]*:[[:space:]]*$/ ) {
			## `key:` alone: a multi-line slot, its value the indented lines that follow.
			key = line ; sub( /:.*$/, "", key )
			slot[key] = "" ; cur = key ; first = 1
		} else if ( line ~ /^[a-z][a-z0-9-]*:[[:space:]]/ ) {
			## `key: value`: a single-line slot.
			key = line ; sub( /:.*$/, "", key )
			val = line ; sub( /^[a-z][a-z0-9-]*:[[:space:]]*/, "", val )
			slot[key] = val ; cur = "" ; first = 1
		} else if ( cur != "" && ( line ~ /^[[:space:]]/ || line ~ /^[[:space:]]*$/ ) ) {
			## an indented or blank line of the open multi-line slot.
			slot[cur] = slot[cur] ( first ? "" : "\n" ) line ; first = 0
		} else {
			cur = "" ; first = 1
		}
	}
	close( file )
	for ( key in slot ) slot[key] = idsClean( slot[key] )
}

## The value the shared filler asks for (AgentsToolingTemplateFill.awk): a slot of the inbox document,
## from the slots file, else from an IDS_<name> environment variable. A value with a hyphen in its name
## comes from the file only.
function ttSlot( name ) {
	if ( name in slot ) return slot[name]
	if ( ( "IDS_" name ) in ENVIRON ) return ENVIRON["IDS_" name]
	return ""
}

BEGIN {
	if ( ! ttRead( ARGV[1] ) ) exit 3
	if ( ! ( ( "Skeleton" SUBSEP "document" ) in ttHas ) ) exit 3
	if ( ENVIRON["IDS_SLOTS"] != "" ) idsRead( ENVIRON["IDS_SLOTS"] )
	print ttFill( ttBlock["Skeleton", "document"] )
	exit 0
}
