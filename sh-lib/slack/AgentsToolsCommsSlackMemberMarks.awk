#!/usr/bin/env awk
# Prints a member's Slack icon and alias, tab-separated, read from its own .basic.md.
icon  == "" && /^- \*\*Slack shortcode\*\*:/	{ icon  = $2 ; }
emoji == "" && /^- \*\*Unicode character\*\*:/	{ emoji = $2 ; }
alias == "" && /^- \*\*Alias\*\*:/		{ alias = $2 ; }
END {
	if ( icon == "" ) { icon = emoji ; }
	gsub( /`/, "", icon )  ; sub( /[[:space:]].*$/, "", icon ) ;
	gsub( /`/, "", alias ) ; sub( /[[:space:]].*$/, "", alias ) ; sub( /\.$/, "", alias ) ;
	if ( alias !~ /^[A-Za-z0-9._-]+$/ ) { alias = who ; }
	printf "%s\t%s\n", icon, alias ;
}
