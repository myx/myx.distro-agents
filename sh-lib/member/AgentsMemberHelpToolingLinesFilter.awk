#!/usr/bin/env awk
# Prints each distinct Help.DistroAgentsTools.include line whose op name is on the allow-list.
BEGIN {
	count = split(ENVIRON["MDAT_MEMBER_HELP_NAMES"], arr, "\n");
	for (i = 1; i <= count; i++) { if (arr[i] != "") nameList[arr[i]] = 1; };
	## The coordinator's own operations are shown to the member by their names, never by a family prefix that happens to start them (--client-operation-run under --client-*).
	count = split(ENVIRON["MDAT_MEMBER_HELP_EXCLUDE"], arr, "\n");
	for (i = 1; i <= count; i++) { if (arr[i] != "") excludeList[arr[i]] = 1; };
}
{
	msg = $0;
	sub(/^echo "/, "", msg);
	sub(/" >&2$/, "", msg);
	for (nm in nameList) {
		matched = 0;
		if (substr(nm, length(nm), 1) == "*") {
			prefix = substr(nm, 1, length(nm) - 1);
			if (index(msg, ".fn.sh " prefix) > 0) {
				opWord = substr(msg, index(msg, ".fn.sh ") + 7); sub(/[ \t].*$/, "", opWord);
				if (!(opWord in excludeList) || (opWord in nameList)) { matched = 1; };
			};
		} else {
			needle = ".fn.sh " nm;
			pos = index(msg, needle);
			if (pos > 0) {
				after = substr(msg, pos + length(needle), 1);
				if (after == " " || after == "") { matched = 1; };
			};
		};
		if (matched) { break; };
	};
	if (matched && !(msg in seen)) { print msg; seen[msg] = 1; };
}
