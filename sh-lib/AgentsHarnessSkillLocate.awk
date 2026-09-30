#!/usr/bin/env awk
# Prints the directory of the first candidate SKILL.md file whose own dirname or frontmatter name: matches wantName.
{
	candFile = $0 ; candDir = candFile ; sub(/\/[^\/]*$/, "", candDir) ;
	dirName = candDir ; sub(/^.*\//, "", dirName) ;
	frontName = "" ; readCount = 0
	while ( ( getline candLine < candFile ) > 0 ) {
		readCount++
		if ( readCount == 1 && candLine != "---" ) break
		if ( readCount > 1 && candLine == "---" ) break
		if ( candLine ~ /^name:/ ) { frontName = candLine ; sub(/^name:[ \t]*/, "", frontName) ; sub(/[ \t]+$/, "", frontName) ; gsub(/^["\047]|["\047]$/, "", frontName) ; }
	}
	close(candFile)
	if ( readCount > 0 && ( dirName == wantName || frontName == wantName ) ) { print candDir ; exit ; }
}
