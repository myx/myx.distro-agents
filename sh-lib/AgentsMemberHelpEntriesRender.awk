#!/usr/bin/env awk
# Prints each full help entry (syntax lines plus body) whose op name is on the allow-list.
BEGIN {
	count = split(ENVIRON["MDAT_MEMBER_HELP_NAMES"], arr, "\n");
	for (i = 1; i <= count; i++) { if (arr[i] != "") nameList[arr[i]] = 1; };
}
## An entry is a run of syntax lines plus the text under them -- its text shows when any of those syntax lines shows.
/^## / { inBlock = 0; inHeaders = 0; inOptions = ($0 ~ /^##  Options:/); }
/^\t\t--/ && inOptions {
	tmp = $0;
	sub(/^\t\t/, "", tmp);
	split(tmp, parts, " ");
	opName = parts[1];
	if (!inHeaders) { entryCount++; inBlock = 0; };
	inHeaders = 1;
	lineShown = 0;
	for (nm in nameList) {
		if (substr(nm, length(nm), 1) == "*") {
			prefix = substr(nm, 1, length(nm) - 1);
			if (index(opName, prefix) == 1) { lineShown = 1; break; };
		} else if (opName == nm) { lineShown = 1; break; };
	};
	if (lineShown && (opName in printed) && printed[opName] != entryCount) { lineShown = 0; };
	if (lineShown) { printed[opName] = entryCount; inBlock = 1; print; };
	next;
}
{ inHeaders = 0; }
inBlock { print; }
