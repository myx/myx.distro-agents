#!/usr/bin/env bash
## AgentsSolidBreachScan.sh -- lists every SOLID breach of myx.distro-agents as one row: `<priority>\t<class>\t<file>:<line>\t<detail>`.
## Each row is a critical issue; zero rows is done. Priority, fixed in this order:
##   P0 unreached, silent-load, optional-call, dual-use, undefined-call, guard-target, guard-name, guarded-op, load-missing  a broken call or a broken internal file contract: an error at
##                   run time, or stale data while every check stays green (AgentsSolidContracts.py beside this file).
##   P1 foreign-package  the package boundary: what a sibling or myx.common change breaks.
##   P2 foreign-store    a store read or written past its owner: silent wrong data.
##   P3 (none)           an include of another concern is that concern's contract, never a breach: the package is one subsystem
##                       (the shared awk files and the distro index helpers are the examples). Data files are owned strictly: P2.
##   P4 duplicate        one concern written twice.
##   P5 fabricated       a check that tests its own fixture; replaced by unit tests as each concern is rewritten.
##   P6 dead          a function defined and named nowhere else. A concern is a folder of sh-lib until the concern map names others.
## Classes, priority 1 first:
##   foreign-package a call into a sibling package that the reference siblings (myx.distro-source, -deploy, -system) never make.
##                   The siblings are optional parts of one system at matching versions, so sourcing a sibling's shared include by
##                   $MDLT_ORIGIN path is the family form. Breaches: calling a sibling's internal function by name, as no reference
##                   sibling does (myx.distro-.local's LocalTools*, DistroLocal*); a hardcoded path into myx.common, whose libraries
##                   are reached by `. "$( myx.common which lib/<name> )"` (myx.distro-system MAGIC.md, "Calling a tool").
##   foreign-store   a file names a store another concern owns, or one only the distro tooling owns (system-index, project.inf).
##                   The owner of a file is the one concern whose state it records, wherever it sits: a path into a session
##                   folder is matched to its most specific part first (sessionParts), and a concern reading its own part is no row.
##   duplicate       one awk program text written in more than one file.
##   fabricated      a check writes a store the code under test then reads, instead of driving its owner.
## Usage: AgentsSolidBreachScan.sh [<package root>] [--summary]   (default root: $MDLT_ORIGIN/myx/myx.distro-agents)
set -u
root="${1:-${MDLT_ORIGIN:?MDLT_ORIGIN is not set}/myx/myx.distro-agents}" ; case "$root" in --summary) root="$MDLT_ORIGIN/myx/myx.distro-agents" ;; esac
summary="" ; for a in "$@" ; do [ "$a" = --summary ] && summary=yes ; done
scanHere="$( cd "${BASH_SOURCE%/*}" && pwd )"
cd "$root" || { echo "⛔ ERROR: no package at $root" >&2 ; exit 1 ; }
## The stores and their owner folders; `-` is a store the distro tooling alone owns. The first owner is the one a row names.
## A further owner is a layer the store is read and written through: items (AgentsToolsItemRead, AgentsToolsItemUpsert)
## is that layer for every team-data store, so its reads and writes are no row.
stores='sessions/ session
spawned/ session
/board/ board items
/inboxes/ inbox items
/vault/ vault items
system-index -
project\.inf -'
## The parts of .local/agents/sessions/<id>/ another concern owns, one a line: `<name pattern> <owner> <label>`, where the
## pattern is matched whole against the path segment after the session id. A segment no line matches is the session's own.
## <refusal> is one variable or printf %s before a single .md or .task, so `%s.checklist.md` stays the session's.
sessionParts='(\$\{?[A-Za-z_][A-Za-z0-9_]*\}?|%s)\.md grants <refusal>.md
(\$\{?[A-Za-z_][A-Za-z0-9_]*\}?|%s)\.task grants <refusal>.task
grants grants grants
consumed grants consumed
changes grants changes
permissions\..* grants permissions.*
wait wait wait/
dms-roster\..* wait dms-roster.<member>
event-track\.thread event-track event-track.thread
event-track\.wait-on event-track event-track.wait-on
feed.* event-track feed*
processes harness processes/
learn slack learn
sent\.recent slack sent.recent
corrections\.told slack corrections.told
undo undo undo/'
## The documented interface of myx.distro-.local, one function and its citation a line: the
## file:line of the .local document that declares the function for other packages' readers
## and callers. A call to a function on this list is no row. Nothing else is exempted.
allowedForeignFunctions='LocalToolsManagerDashboardFigure|myx.distro-.local/sh-lib/manager/LocalTools.ManagerDashboard.include:20
LocalToolsManagerDashboardShare|myx.distro-.local/sh-lib/manager/LocalTools.ManagerDashboard.include:63
LocalToolsManagerDashboardAge|myx.distro-.local/sh-lib/manager/LocalTools.ManagerDashboard.include:74
LocalToolsManagerDashboardKept|myx.distro-.local/sh-lib/manager/LocalTools.ManagerDashboard.include:90
LocalToolsManagerDashboardKeep|myx.distro-.local/sh-lib/manager/LocalTools.ManagerDashboard.include:92
LocalToolsManagerDashboardDisk|myx.distro-.local/sh-lib/manager/LocalTools.ManagerDashboard.include:37
LocalToolsManagerField|myx.distro-.local/sh-lib/manager/LocalTools.ManagerField.include:6
LocalToolsManagerWorkspaceFact|myx.distro-.local/sh-lib/manager/LocalTools.ManagerWorkspace.include:21
LocalToolsManagerWorkspaceItem|myx.distro-.local/sh-lib/manager/LocalTools.ManagerWorkspace.include:21
LocalToolsManagerScopeNameOk|myx.distro-.local/sh-lib/manager/LocalTools.ManagerScope.include:9
LocalToolsPlacesDirectiveRows|myx.distro-.local/sh-lib/places/LocalTools.Places.include:6
LocalToolsPlacesHomeSkills|myx.distro-.local/sh-lib/places/LocalTools.Places.include:6
LocalToolsPlacesLegacyImport|myx.distro-.local/sh-lib/places/LocalTools.Places.include:6
LocalToolsPlacesListText|myx.distro-.local/sh-lib/places/LocalTools.Places.include:6
LocalToolsPlacesLocalFile|myx.distro-.local/sh-lib/places/LocalTools.Places.include:6
LocalToolsPlacesLocalUpdate|myx.distro-.local/sh-lib/places/LocalTools.Places.include:6
LocalToolsPlacesMergedText|myx.distro-.local/sh-lib/places/LocalTools.Places.include:6
LocalToolsPlacesNameValid|myx.distro-.local/sh-lib/places/LocalTools.Places.include:6
LocalToolsPlacesOf|myx.distro-.local/sh-lib/places/LocalTools.Places.include:6
LocalToolsPlacesOwnerForget|myx.distro-.local/sh-lib/places/LocalTools.Places.include:6
LocalToolsPlacesOwnerUpsert|myx.distro-.local/sh-lib/places/LocalTools.Places.include:6
LocalToolsPlacesResolve|myx.distro-.local/sh-lib/places/LocalTools.Places.include:6
LocalToolsPlacesWorkspaceRoots|myx.distro-.local/sh-lib/places/LocalTools.Places.include:6
DistroLocalEchoBashPrompt|myx.distro-.local/sh-lib/LocalTools.EchoBashPrompt.include:4'
rows(){
	## foreign-package
	LC_ALL=C grep -rnoE --include='*.include' --include='*.sh' --include='*.py' --include='*.awk' -e '\$MDLT_ORIGIN/myx/myx\.common/' sh-lib sh-scripts |
		LC_ALL=C awk -F: '{ m = $3 ; sub(/.*\/myx\//, "", m) ; sub(/\/$/, "", m) ; printf "foreign-package\t%s:%s\tpath into %s\n", $1, $2, m }'
	LC_ALL=C grep -rnE --include='*.include' --include='*.sh' -e '\b(LocalTools[A-Za-z]+|DistroLocal[A-Za-z]+)\b' sh-lib sh-scripts |
		allowed="$allowedForeignFunctions" LC_ALL=C awk -F: '
			BEGIN { n = split(ENVIRON["allowed"], allowedLines, "\n") ; for (allowedAt = 1 ; allowedAt <= n ; allowedAt++) { if (allowedLines[allowedAt] == "") continue ; allowedName = allowedLines[allowedAt] ; sub(/\|.*/, "", allowedName) ; allowedFn[allowedName] = 1 ; } }
			{
				line = $0 ; sub(/^[^:]*:[^:]*:/, "", line)
				if (line ~ /^[[:space:]]*#/) next
				rest = line
				while (match(rest, /(LocalTools[A-Za-z]+|DistroLocal[A-Za-z]+)/)) {
					fn = substr(rest, RSTART, RLENGTH)
					before = (RSTART > 1) ? substr(rest, RSTART - 1, 1) : ""
					rest = substr(rest, RSTART + RLENGTH)
					if (before ~ /[A-Za-z0-9_]/) continue
					if (rest ~ /^[A-Za-z0-9_.]/) continue
					if (fn in allowedFn) continue
					printf "foreign-package\t%s:%s\t%s, myx.distro-.local\x27s internal\n", $1, $2, fn
				}
			}'
	## foreign-store: code only. A `#` comment line and the trailing comment of a code line are dropped, a `#` opening a
	## comment only at the start of a word and outside quotes. The quotes left are dropped before the store names are matched,
	## so `"$MMDAPP/.local/agents/spawned"/*/"$run.spawn.md"` is read as `spawned/`. Quote state is read one line at a time.
## A data store name (/board/, /inboxes/, /vault/) counts only in a store path: its path word starts from a variable or a
## printf %s, and the store name does not follow sh-lib. So a load of a package file under sh-lib/board/, and a literal
## URL or API path such as the Jira /rest/agile/1.0/board/ID, are no row.
	find sh-lib -type f \( -name '*.include' -o -name '*.sh' -o -name '*.py' -o -name '*.awk' \) | LC_ALL=C sort |
		stores="$stores" sessionParts="$sessionParts" LC_ALL=C awk '
			BEGIN {
				n = split(ENVIRON["stores"], storeLines, "\n")
				for (s = 1 ; s <= n ; s++) { k = split(storeLines[s], w, " ") ; storePat[s] = w[1] ; storeOwner[s] = w[2] ; storeName[s] = w[1] ; gsub(/\\/, "", storeName[s]) ; storeAlso[s] = " " ; for (j = 2 ; j <= k ; j++) storeAlso[s] = storeAlso[s] w[j] " " }
				partN = split(ENVIRON["sessionParts"], partLines, "\n")
				for (j = 1 ; j <= partN ; j++) { split(partLines[j], w, " ") ; partPat[j] = "^(" w[1] ")$" ; partOwner[j] = w[2] ; partLabel[j] = w[3] }
			}
			## sessionOwners: for each `sessions/<id>/<part>` in the code, the part owner and the label a row names, one `owner\tlabel`
			## a line. The id is one path segment, a `${...}` read whole so a `:-/` default inside it does not end it.
			function sessionOwners(code,    rest, id, seg, j, out, owner, label, depth, c, i) {
				rest = code ; out = ""
				while (match(rest, /sessions\//)) {
					rest = substr(rest, RSTART + RLENGTH) ; i = 1 ; depth = 0
					while (i <= length(rest)) { c = substr(rest, i, 1) ; if (c == "{") depth++ ; else if (c == "}" && depth > 0) depth-- ; else if (depth == 0 && c ~ /[\/ \t;|&()<>]/) break ; i++ }
					owner = "session" ; label = ""
					if (substr(rest, i, 1) == "/") {
						seg = substr(rest, i + 1) ; sub(/[\/ \t;|&()<>].*/, "", seg)
						for (j = 1 ; j <= partN ; j++) if (seg ~ partPat[j]) { owner = partOwner[j] ; label = partLabel[j] ; break }
					}
					out = out owner "\t" label "\n"
				}
				return out
			}
			function codeOf(text,    i, c, q, prev, out) {
				q = "" ; prev = " " ; out = ""
				for (i = 1 ; i <= length(text) ; i++) {
					c = substr(text, i, 1)
					if (q == "" && c == "#" && prev ~ /[ \t;&|()]/) break
					if (c == "\\" && q != "\x27") { out = out c substr(text, i + 1, 1) ; i++ ; prev = "x" ; continue }
					if (q == "" && (c == "\"" || c == "\x27")) q = c
					else if (q != "" && c == q) q = ""
					else out = out c
					prev = c
				}
				gsub(/["\x27]/, "", out)
				return out
			}
			function inStorePath(code, pat,    rest, word, found) {
				if (pat !~ /^\/(board|inboxes|vault)\/$/) return code ~ pat
				rest = code ; found = 0
				while (match(rest, pat)) {
					word = substr(rest, 1, RSTART - 1) ; sub(/.*[ \t=(<>|;&]/, "", word)
					if (word ~ /(\$|%s)/ && word !~ /sh-lib$/) found = 1
					rest = substr(rest, RSTART + 1)
				}
				return found
			}
			{
				file = $0 ; split(file, p, "/") ; at = 0
				while ((getline line < file) > 0) {
					at++ ; code = codeOf(line)
					for (s = 1 ; s <= n ; s++) {
						if (!inStorePath(code, storePat[s])) continue
						if (storeName[s] == "sessions/") {
							split("", told) ; m = split(sessionOwners(code), found, "\n")
							for (j = 1 ; j <= m ; j++) {
								if (found[j] == "" || (found[j] in told)) continue
								told[found[j]] = 1 ; split(found[j], f, "\t")
								if (p[2] != f[1]) printf "foreign-store\t%s:%d\tsessions/%s owned by %s\n", file, at, f[2], f[1]
							}
							continue
						}
						if (storeOwner[s] == "-" || index(storeAlso[s], " " p[2] " ") == 0)
							printf "foreign-store\t%s:%d\t%s owned by %s\n", file, at, storeName[s], (storeOwner[s] == "-" ? "the distro tooling" : storeOwner[s])
					}
				}
				close(file)
			}'
	## duplicate: an awk program of 80+ characters, one row per extra file carrying it
	LC_ALL=C grep -rnoE "awk [^|]{0,40}'[^']{80,}'" sh-lib --include='*.include' --include='*.sh' |
		LC_ALL=C awk -F: '{ f = $1 ; l = $2 ; $1 = "" ; $2 = "" ; t = $0 ; sub(/^[^'"'"']*/, "", t) ; if (!(t in first)) first[t] = f ":" l ; else if (index(first[t], f ":") != 1) printf "duplicate\t%s:%s\tsame awk program as %s\n", f, l, first[t] }'
	## the internal contracts: unreached calls, silent loads, optional calls, dual use, duplicate definitions, dead functions
	python3 "$scanHere/AgentsSolidContracts.py" "$root"
	## fabricated: a check writing into a store path
	LC_ALL=C grep -rnE '(>|>>|cp [^|]*|mkdir -p [^|]*)[^|;]*(system-index|/board/|/inboxes/|/vault/|distro-declares|distro-projects)' sh-test --include='*.sh' |
		LC_ALL=C awk -F: '{ printf "fabricated\t%s:%s\twrites a store the code reads\n", $1, $2 }'
}
prioritise(){
	LC_ALL=C awk -F'\t' 'BEGIN { p["foreign-package"] = "P1" ; p["foreign-store"] = "P2" ; p["duplicate"] = "P4" ; p["fabricated"] = "P5" ; p["unreached"] = "P0" ; p["silent-load"] = "P0" ; p["optional-call"] = "P0" ; p["dual-use"] = "P0" ; p["undefined-call"] = "P0" ; p["guard-target"] = "P0" ; p["guard-name"] = "P0" ; p["guarded-op"] = "P0" ; p["load-missing"] = "P0" ; p["duplicate-def"] = "P4" ; p["dead"] = "P6" } { print p[$1] "\t" $0 }' | LC_ALL=C sort -t "$(printf '\t')" -k1,1 -s
}
if [ -n "$summary" ] ; then
	rows | prioritise | LC_ALL=C awk -F'\t' '{ n[$1 " " $2]++ ; t++ ; split($3, f, "/") ; d[$1 " " $2 " " f[1] "/" f[2]]++ } END { for (c in n) printf "class %s %d\n", c, n[c] ; for (k in d) printf "where %s %d\n", k, d[k] ; printf "total %d\n", t + 0 }' | LC_ALL=C sort -k1,1 -k2,2
else
	rows | prioritise
fi
