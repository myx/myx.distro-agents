## AgentsCommonSyntaxIndex.awk -- one pass over help/Help.DistroAgentsTools.help.md, one line an operation that takes a common
## option or a member first: `<operation> TAB <the common options it needs, space-terminated> TAB <yes|no, a member is its first>`.
## The same rules the call itself applies, read once for every operation instead of once per call, so the call path reads a
## small kept index (AgentsToolsCommonNeedsOf) instead of the 491 KB manual.
BEGIN {
	print "format: myx.distro common-syntax 1"
	want["--team-member"] = "^<(team-member|member)>" ; want["--session-id"] = "^<session-id>" ; want["--spawn-id"] = "^<spawn-id>"
}
## The syntax line of an operation: `📘 syntax: <tool> <operation> ...`, or the operation's own index line in its entry.
$1 == "📘" && $4 ~ /^--/ { atNeed = 5 ; atFirst = 5 ; inOp = $4 ; }
/^\t\t--[a-z]/ && $1 ~ /^--/ { atNeed = 2 ; atFirst = 2 ; inOp = $1 ; }
atNeed {
	for ( i = atNeed ; i < NF ; i++ ) if ( ( $i in want ) && $( i + 1 ) ~ want[$i] ) needs[inOp] = needs[inOp] $i " "
	atNeed = 0
}
atFirst {
	if ( $atFirst ~ /^(<team-member>|<member>)/ ) found[inOp] = 1
	else if ( $atFirst == "[--team-member" && $( atFirst + 2 ) !~ /^\[--session-id/ ) found[inOp] = 1
	atFirst = 0
}
END {
	for ( op in needs ) if ( needs[op] != "" ) printf "%s|%s|%s\n", op, needs[op], ( op in found ? "yes" : "no" )
	for ( op in found ) if ( ! ( op in needs ) || needs[op] == "" ) printf "%s||%s\n", op, "yes"
}
