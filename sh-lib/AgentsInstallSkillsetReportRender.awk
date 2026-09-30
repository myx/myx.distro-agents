#!/usr/bin/env awk
# Renders the skillset install report: one row per member, sorted, with its worst outcome rank.
{
	seen[$1] = 1 ; refs[$1]++
	## a row with no resolved target never overwrites one that has it
	if ( $5 != "-" && $5 != "" ) { who[$1] = $3 ; home[$1] = $4 ; wspace[$1] = $5 ; }
	else if ( who[$1] == "" ) who[$1] = $3
	if ( $2 == "error" ) rank[$1] = 4
	else if ( $2 == "deleted" && rank[$1] < 3 ) rank[$1] = 3
	else if ( $2 == "updated" && rank[$1] < 2 ) rank[$1] = 2
	else if ( rank[$1] < 1 ) rank[$1] = 1
}
END {
	n = 0
	for ( m in seen ) order[++n] = m
	for ( i = 1 ; i < n ; i++ ) for ( j = i + 1 ; j <= n ; j++ ) if ( order[j] < order[i] ) { t = order[i] ; order[i] = order[j] ; order[j] = t ; }
	printf "🔗 magic-team skillset: %d members\n", n
	printf "   %-2s %-20s %-8s %5s %5s %6s\n", "", "MEMBER", "OP", "REFS", "HOME", "WSPACE"
	for ( i = 1 ; i <= n ; i++ ) {
		m = order[i]
		op = ( rank[m] == 4 ) ? "ERROR" : ( rank[m] == 3 ) ? "DELETED" : ( rank[m] == 2 ) ? "UPDATED" : "KEPT"
		if ( wspace[m] == "" ) { home[m] = "-" ; wspace[m] = "-" ; }
		printf "   %-2s %-20s %-8s %5d %5s %6s\n", who[m], m, op, refs[m], home[m], wspace[m]
	}
}
