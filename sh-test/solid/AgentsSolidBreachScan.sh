#!/usr/bin/env bash
## AgentsSolidBreachScan.sh -- lists every SOLID breach of myx.distro-agents as one row: `<priority>\t<class>\t<file>:<line>\t<detail>`.
## Each row is a critical issue; zero rows is done. Priority, fixed in this order:
##   P0 unreached, silent-load, optional-call, dual-use, undefined-call, guard-target, guard-name  a broken call or a broken internal file contract: an error at
##                   run time, or stale data while every check stays green (AgentsSolidContracts.py beside this file).
##   P1 foreign-package  the package boundary: what a sibling or myx.common change breaks.
##   P2 foreign-store    a store read or written past its owner: silent wrong data.
##   P3 foreign-source   a subsystem reaching into another's internals: no layering, no unit tests possible.
##   P4 duplicate        one concern written twice.
##   P5 fabricated       a check that tests its own fixture; replaced by unit tests as each concern is rewritten.
##   P6 dead          a function defined and named nowhere else. A concern is a folder of sh-lib until the concern map names others.
## Classes, priority 1 first:
##   foreign-package a call into a sibling package that the reference siblings (myx.distro-source, -deploy, -system) never make.
##                   The siblings are optional parts of one system at matching versions, so sourcing a sibling's shared include by
##                   $MDLT_ORIGIN path is the family form. Breaches: calling a sibling's internal function by name, as no reference
##                   sibling does (myx.distro-.local's LocalTools*, DistroLocal*); a hardcoded path into myx.common, whose libraries
##                   are reached by `. "$( myx.common which lib/<name> )"` (myx.distro-system MAGIC.md, "Calling a tool").
##   foreign-source  a file sources an include of another concern's folder (reaching into its internals, not calling a door).
##   foreign-store   a file names a store another concern owns, or one only the distro tooling owns (system-index, project.inf).
##   duplicate       one awk program text written in more than one file.
##   fabricated      a check writes a store the code under test then reads, instead of driving its owner.
## Usage: AgentsSolidBreachScan.sh [<package root>] [--summary]   (default root: $MDLT_ORIGIN/myx/myx.distro-agents)
set -u
root="${1:-${MDLT_ORIGIN:?MDLT_ORIGIN is not set}/myx/myx.distro-agents}" ; case "$root" in --summary) root="$MDLT_ORIGIN/myx/myx.distro-agents" ;; esac
summary="" ; for a in "$@" ; do [ "$a" = --summary ] && summary=yes ; done
scanHere="$( cd "${BASH_SOURCE%/*}" && pwd )"
cd "$root" || { echo "⛔ ERROR: no package at $root" >&2 ; exit 1 ; }
## The stores and their one owner folder; `-` is a store the distro tooling alone owns.
stores='sessions/ session
spawned/ session
/board/ board
/inboxes/ inbox
/vault/ team-data
system-index -
project\.inf -'
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
	## foreign-source
	LC_ALL=C grep -rnoE '(\. |source )"?\$MDLT_ORIGIN/myx/myx\.distro-agents/sh-lib/[a-z-]+/[A-Za-z0-9_.-]+' sh-lib --include='*.include' --include='*.sh' |
		LC_ALL=C awk -F: '{ split($1, p, "/") ; m = $3 ; sub(/.*sh-lib\//, "", m) ; split(m, q, "/") ; if (p[2] != q[1]) printf "foreign-source\t%s:%s\t%s -> %s\n", $1, $2, p[2], m }'
	## foreign-store
	printf '%s\n' "$stores" | while read -r pat owner ; do
		LC_ALL=C grep -rnE --include='*.include' --include='*.sh' --include='*.py' --include='*.awk' -e "$pat" sh-lib |
			LC_ALL=C awk -F: -v pat="$pat" -v owner="$owner" '{ split($1, p, "/") ; if (owner == "-" || p[2] != owner) printf "foreign-store\t%s:%s\t%s owned by %s\n", $1, $2, pat, (owner == "-" ? "the distro tooling" : owner) }'
	done
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
	LC_ALL=C awk -F'\t' 'BEGIN { p["foreign-package"] = "P1" ; p["foreign-store"] = "P2" ; p["foreign-source"] = "P3" ; p["duplicate"] = "P4" ; p["fabricated"] = "P5" ; p["unreached"] = "P0" ; p["silent-load"] = "P0" ; p["optional-call"] = "P0" ; p["dual-use"] = "P0" ; p["undefined-call"] = "P0" ; p["guard-target"] = "P0" ; p["guard-name"] = "P0" ; p["duplicate-def"] = "P4" ; p["dead"] = "P6" } { print p[$1] "\t" $0 }' | LC_ALL=C sort -t "$(printf '\t')" -k1,1 -s
}
if [ -n "$summary" ] ; then
	rows | prioritise | LC_ALL=C awk -F'\t' '{ n[$1 " " $2]++ ; t++ ; split($3, f, "/") ; d[$1 " " $2 " " f[1] "/" f[2]]++ } END { for (c in n) printf "class %s %d\n", c, n[c] ; for (k in d) printf "where %s %d\n", k, d[k] ; printf "total %d\n", t + 0 }' | LC_ALL=C sort -k1,1 -k2,2
else
	rows | prioritise
fi
