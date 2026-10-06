#!/usr/bin/awk -f
##
## AgentsBoardItemHeaderOpsApply.awk -- applies a set of upsert/append/remove
## header operations to a board-item body's frontmatter, for
## DistroAgentsTools.fn.sh's --intern-op-board-upsert-move-edit op
## (myx.distro-agents/sh-lib/AgentsTools.InternOpBoardUpsertMoveEdit.include),
## externalized per this package's own externalize-awk/py convention (see
## AgentsBoardItemFrontmatterPrint.awk's own header comment for that name).
##
## Main input: the body on stdin (frontmatter delimited by two literal
## `---` lines, same shape AgentsBoardItemFrontmatterPrint.awk reads).
## `-v opsFile=<path>`: a tab-separated `opType<TAB>opName<TAB>opValue` file,
## one header operation per line, in application order -- opType is one of
## upsert/append/remove/default. Repeat upserts/removes on the same field: last
## wins. Repeat appends on the same field: cumulative, joined into one
## `a, b, c`-shaped comma-separated list value, in order (no brackets --
## a single-value list is just the bare value). `default` sets a field only
## where nothing else gives it a value: never over an upsert/append/remove
## of the same field, in either order, and never over the field already in
## the body's own frontmatter (an empty `name:` line counts as given). It is
## how the tooling stamps required headers without overwriting the caller's.
## A field with no operations targeting it, and every non-frontmatter body
## line, passes through unchanged. Fields this awk adds are printed in the
## order their operations first appeared. Prints the resulting body to stdout.
##
## Every closing `}` below is preceded by a `;` (magic-developer's
## reference/shell.md axiom: some AWK builds reject the missing-semicolon
## form as a hard parse error).
##
BEGIN {
	n = 0 ;
	while ( (getline line < opsFile) > 0 ) {
		split(line, parts, "\t") ;
		n++ ;
		opType[n] = parts[1] ; opName[n] = parts[2] ; opValue[n] = parts[3] ;
	} ;
	close(opsFile) ;
	nOrder = 0 ;
	for (i = 1 ; i <= n ; i++) {
		nm = opName[i] ;
		if (!(nm in orderSeen)) { orderSeen[nm] = 1 ; nOrder++ ; orderName[nOrder] = nm ; } ;
		if (opType[i] == "remove") {
			finalAction[nm] = "remove" ; listCount[nm] = 0 ;
		} else if (opType[i] == "upsert") {
			finalAction[nm] = "set" ; finalValue[nm] = opValue[i] ; listCount[nm] = 0 ;
		} else if (opType[i] == "append") {
			if (finalAction[nm] == "default") { listCount[nm] = 0 ; } ;
			finalAction[nm] = "set" ;
			listCount[nm]++ ;
			pendingList[nm SUBSEP listCount[nm]] = opValue[i] ;
		} else if (opType[i] == "default") {
			if (!(nm in finalAction)) { finalAction[nm] = "default" ; finalValue[nm] = opValue[i] ; listCount[nm] = 0 ; } ;
		} ;
	} ;
	for (nm in finalAction) {
		if (finalAction[nm] == "set" && listCount[nm] > 0) {
			v = "" ;
			for (k = 1 ; k <= listCount[nm] ; k++) { v = (v == "" ? pendingList[nm SUBSEP k] : v ", " pendingList[nm SUBSEP k]) ; } ;
			finalValue[nm] = v ;
		} ;
	} ;
	infm = 0 ; closed = 0 ;
} ;
NR == 1 && $0 != "---" && n > 0 {
	print "---" ;
	for (k = 1 ; k <= nOrder ; k++) {
		nm = orderName[k] ;
		if (finalAction[nm] == "set" || finalAction[nm] == "default") { print nm ": " finalValue[nm] ; seen[nm] = 1 ; } ;
	} ;
	print "---" ;
	print "" ;
	closed = 1 ;
} ;
$0 == "---" && closed == 0 {
	if (infm == 0) { infm = 1 ; print ; next ; } ;
	for (k = 1 ; k <= nOrder ; k++) {
		nm = orderName[k] ;
		if (!seen[nm] && (finalAction[nm] == "set" || finalAction[nm] == "default")) { print nm ": " finalValue[nm] ; seen[nm] = 1 ; } ;
	} ;
	infm = 0 ; closed = 1 ; print ; next ;
} ;
infm == 1 {
	for (k = 1 ; k <= nOrder ; k++) {
		nm = orderName[k] ;
		## A default field counts as given by the bare `name:` form too.
		if ($0 ~ "^" nm ": " || (finalAction[nm] == "default" && $0 == nm ":")) {
			seen[nm] = 1 ;
			if (finalAction[nm] == "set") { print nm ": " finalValue[nm] ; }
			else if (finalAction[nm] == "default") { print ; } ;
			next ;
		} ;
	} ;
	print ; next ;
} ;
{ print ; }
END {
	if (n > 0 && closed == 0) {
		printf("⛔ ERROR: AgentsBoardItemHeaderOpsApply.awk: %d header operation(s) requested, but this body has no complete `---` frontmatter block (opened=%d, closed=%d) -- the operations were NOT applied. Failing rather than passing the body through unchanged, which would report success having written nothing.\n", n, infm, closed) > "/dev/stderr" ;
		exit 1 ;
	} ;
} ;
