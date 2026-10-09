#!/usr/bin/env awk

## AgentsGrantsPattern.awk -- functions only, loaded with -f beside the program that uses them
## (AgentsGrantsIndexBuild.awk, AgentsGrantsSessionIndex.awk).
##
## A grant names its paths as a glob; a check matches a path with bash `[[ $path == $pattern ]]`,
## which always matches extended patterns (bash 3.2 included), and where a bare `*` crosses `/`.
## So a glob is translated once, here, into such a pattern:
##   /**  at the end    -> @(|/*)     the directory itself, or anything under it
##   /**/ in the middle -> @(/|/*/)   no directory, or any number of them
##   **   elsewhere     -> *          anything, `/` included (`docs/**.md`)
##   *                  -> *([!/])    within one path segment
##   ?                  -> [!/]
##   [...]              -> itself
## Every other character that a pattern reads specially is escaped, so it matches itself.

## One character as a pattern matches it literally.
function grantsLiteralChar( c ) {
	return ( index( "*?[]\\()|!@+", c ) > 0 ) ? "\\" c : c
}

## A text matched exactly: a resolved path a refusal names.
function grantsLiteral( s,    i, out ) {
	out = ""
	for ( i = 1 ; i <= length( s ) ; i++ ) out = out grantsLiteralChar( substr( s, i, 1 ) )
	return out
}

## A grant glob as a bash pattern. Empty, * and ** match anything.
function grantsGlobPattern( g,    i, n, c, out, j ) {
	if ( g == "" || g == "*" || g == "**" ) return "*"
	out = "" ; n = length( g )
	for ( i = 1 ; i <= n ; i++ ) {
		c = substr( g, i, 1 )
		if ( substr( g, i, 4 ) == "/**/" ) { out = out "@(/|/*/)" ; i += 3 ; continue }
		if ( substr( g, i ) == "/**" ) { out = out "@(|/*)" ; break }
		if ( substr( g, i, 2 ) == "**" ) { out = out "*" ; i++ ; continue }
		if ( c == "*" ) { out = out "*([!/])" ; continue }
		if ( c == "?" ) { out = out "[!/]" ; continue }
		if ( c == "[" && ( j = index( substr( g, i + 1 ), "]" ) ) > 1 ) { out = out "[" substr( g, i + 1, j - 1 ) "]" ; i += j ; continue }
		out = out grantsLiteralChar( c )
	}
	return out
}

## A target a passed or set grant names, as AgentsToolsPermissionCovers reads it: empty, *
## and ** for anything, <path>/** for that path and everything under it, a URL prefix
## written <prefix>* for every URL starting with it, and nothing else a pattern.
function grantsCoversPattern( t ) {
	if ( t == "" || t == "*" || t == "**" ) return "*"
	if ( length( t ) > 3 && substr( t, length( t ) - 2 ) == "/**" ) return grantsLiteral( substr( t, 1, length( t ) - 3 ) ) "@(|/*)"
	if ( index( t, "://" ) > 0 && substr( t, length( t ) ) == "*" ) return grantsLiteral( substr( t, 1, length( t ) - 1 ) ) "*"
	return grantsLiteral( t )
}

## The literal directory a glob starts with: its segments up to the first one holding a
## glob character, without a trailing `/`.
function grantsGlobBase( g,    n, seg, i, out ) {
	n = split( g, seg, "/" ) ; out = ""
	for ( i = 2 ; i <= n ; i++ ) {
		if ( seg[i] ~ /[*?[]/ ) break
		out = out "/" seg[i]
	}
	return ( out == "" ) ? "/" : out
}

## A grants-file field back to its natural value: the grants escapes, then the record's own.
function grantsFieldDecode( v ) {
	gsub( /%3A/, ":", v ) ; gsub( /%2C/, ",", v )
	gsub( /%0A/, "\n", v ) ; gsub( /%0D/, "\r", v ) ; gsub( /%20/, " ", v ) ; gsub( /%09/, "\t", v )
	gsub( /%25/, "%", v )
	return v
}
