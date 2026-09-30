#!/usr/bin/env awk
# Groups IM item blocks by source, ranks by newest message, caps and renders them.
## Deliberately the same key function as the per-thread trim above:
## two orderings that must agree are not two implementations.
function tskey(v,   d, sec, frac) {
	gsub(/^[ \t]+|[ \t\r]+$/, "", v)
	d = index(v, ".")
	if (d == 0) { sec = v ; frac = "" ; }
	else { sec = substr(v, 1, d - 1) ; frac = substr(v, d + 1) ; }
	if (sec !~ /^[0-9]+$/ || length(sec) > 16) return ""
	frac = substr(frac "000000", 1, 6)
	if (frac !~ /^[0-9]+$/) return ""
	while (length(sec) < 16) sec = "0" sec
	return sec frac
}
function trim(v) {
	gsub(/^[ \t]+|[ \t\r]+$/, "", v)
	return v
}
## Resume points arrive through the ENVIRONMENT, never `-v`:
## one-true-awk rejects a newline inside a `-v` value outright
## ("awk: newline in string ... at source line 1", measured), so
## a multi-line map cannot be passed that way at all.
function loadResume(   raw, nl, i, f) {
	raw = ENVIRON["IM_SOURCE_RESUME"]
	nl = split(raw, rl, "\n")
	for (i = 1; i <= nl; i++) {
		if (rl[i] == "") continue
		split(rl[i], f, "\t")
		resumeChannel[f[1]] = f[2]
		resumeIdentity[f[1]] = f[3]
		resumeTs[f[1]] = f[4]
		resumeOrigin[f[1]] = f[5]
	}
}
function flush(   i, t, g) {
	if (nb == 0) return
	t = ""
	for (i = 1; i <= nb; i++) t = t blk[i] "\n"
	body[++nblk] = t
	bkey[nblk] = curKey
	g = (curSource == "" ? "(source unstated)" : curSource)
	bsrc[nblk] = g
	if (!(g in gseen)) { gseen[g] = 1 ; gname[++ng] = g ; gmax[g] = "" ; gn[g] = 0 ; }
	gn[g]++
	## An undatable conversation ranks HIGHEST, so the cap never
	## deletes one whose recency could not be established. "~"
	## (0x7E) sorts above any digit under LC_ALL=C.
	if (curKey == "") { gmax[g] = "~" ; }
	else if (gmax[g] != "~" && curKey > gmax[g]) { gmax[g] = curKey ; }
	nb = 0 ; curKey = "" ; curSource = "" ;
}
/^## / { flush() ; }
{ if ($0 != "") blk[++nb] = $0 ; }
/^ts:/     { if (curKey == "")    curKey    = tskey(substr($0, index($0, ":") + 1)) ; }
/^source:/ { if (curSource == "") curSource = trim(substr($0, index($0, ":") + 1)) ; }
END {
	flush()
	loadResume()
	## ONE comparator drives both stages: a conversation is ranked by
	## its own NEWEST message, SELECTION keeps the top `cap` of that
	## ranking and PRESENTATION renders that same window ascending.
	for (i = 1; i <= ng; i++) gord[i] = i
	for (x = 2; x <= ng; x++) {
		v = gord[x] ; j = x - 1
		while (j >= 1 && gmax[gname[gord[j]]] > gmax[gname[v]]) { gord[j + 1] = gord[j] ; j-- ; }
		gord[j + 1] = v
	}
	## gord ascends by recency, so the cap keeps the TAIL, never the head.
	keepFrom = ng - cap + 1
	if (keepFrom < 1) keepFrom = 1
	printf("conversations: %d shown of %d\n", ng - keepFrom + 1, ng)
	## Truncation is never silent: a dropped conversation WAS read and
	## still counts toward sources-scanned, and each one is named.
	if (keepFrom > 1) {
		dropped = ""
		for (x = 1; x < keepFrom; x++) {
			g = gname[gord[x]]
			dropped = dropped (dropped == "" ? "" : ", ") g " (" gn[g] " messages)"
		}
		printf("**NOTE:** truncated -- %d conversations found, capped at %d; %d dropped as least-recently-active. Their sources WERE read and are counted in sources-scanned above -- this is a display cap, not an unread source. Dropped: %s\n", ng, cap, keepFrom - 1, dropped)
	}
	printf("\n")
	for (x = keepFrom; x <= ng; x++) {
		g = gname[gord[x]]
		## ONE HEADING PER CORRESPONDENT, naming who this is, which
		## conversation it is, which persona read it, and where THIS
		## pass started in it. The resume point per conversation is
		## what makes the document auditable at all: with one shared
		## cut-off a reader could not tell one source apart from
		## another, and thirty conversations rendered as one flat
		## stream of opaque ids can only be handled in bulk -- which
		## is exactly what forces a DM-specific rule. Grouping is
		## what lets the ORDINARY handling rules apply per message
		## without conflating whose message is whose.
		##
		## `### ` deliberately, not `## `: every block scanner in
		## this pipeline keys on a literal "## " and none of them
		## matches a third hash.
		if (g in resumeChannel) {
			printf("### %s -- conversation %s, read as %s, resumed from %s (%s)\n\n", \
				g, resumeChannel[g], resumeIdentity[g], resumeTs[g], resumeOrigin[g])
		}
		## A `thread:` group has no heading and needs none: a
		## thread is DISCOVERED inside a source that already has
		## one, and does not carry a pointer of its own. Printing
		## "resume point not recorded" against every one of them
		## would bury the sources that do carry one.
		m = 0
		for (i = nblk; i >= 1; i--) if (bsrc[i] == g) ord[++m] = i
		for (y = 2; y <= m; y++) {
			v = ord[y] ; j = y - 1
			while (j >= 1 && bkey[ord[j]] > bkey[v]) { ord[j + 1] = ord[j] ; j-- ; }
			ord[j + 1] = v
		}
		for (y = 1; y <= m; y++) printf("%s\n", body[ord[y]])
	}
}
