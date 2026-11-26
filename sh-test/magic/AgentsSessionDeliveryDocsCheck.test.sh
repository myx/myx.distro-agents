#!/usr/bin/env bash
## Behavioural check on the session-delivery pages: every source path, line number and function name a doc page
## cites still exists. A rename or a delete that leaves the docs lying turns this red. Run rather than read.
## Held:
##   1. control: a citation that names a file the tree holds reads as present, so the probe can answer OK
##   2. a citation naming a file the tree does not hold reads as missing, so the probe can answer MISSING
##   3. control: a line number inside its file reads as in range
##   4. a line number past its file's end reads as out of range
##   5. every page named below is present
##   6. every `path` citation of every page is present in the tree
##   7. every `path:NN` citation of every page is in range for that file
##   8. every `Function` citation of every page is found in sh-lib or sh-scripts
##   9. every bare `Name.include:NN` citation resolves to exactly one file, and its line is in range there
## Offline: the pages and the source tree under the origin. No network, no store, no tooling state.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -d "$rigPackage" ] || rigRefuse "the package is not at the origin this workspace resolves: $rigPackage"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## The pages this check holds. A page added here is held by the same three assertions.
rigPages="docs/session-delivery.md docs/session-delivery-vocabulary.md"

## rc 0 when a cited path exists under the package.
rigPathPresent(){ ## relative path
	[ -e "$rigPackage/$1" ]
}

## The number of lines in a file, printed, or `0` for one that is not there.
rigLineCount(){ ## relative path
	if [ -f "$rigPackage/$1" ] ; then wc -l < "$rigPackage/$1" | tr -d ' ' ; else printf '0' ; fi
}

## Every backticked path citation of one page, sorted and unique, one a line.
rigCitations(){ ## page
	LC_ALL=C grep -oE '`(sh-lib|sh-scripts)/[A-Za-z0-9._/-]+`' "$rigPackage/$1" \
		| tr -d '`' | LC_ALL=C sort -u
}

## Every backticked `path:NN` citation of one page, with its line number kept.
rigLineCitations(){ ## page
	LC_ALL=C grep -oE '`(sh-lib|sh-scripts)/[A-Za-z0-9._/-]+:[0-9]+`' "$rigPackage/$1" \
		| tr -d '`' | LC_ALL=C sort -u
}

## Every backticked `:NN` citation of one page that is neither a path nor a `:NN` continuation of the path before it -- the bare
## `Name.include:NN` form, which the two assertions above read past.
rigBareCitations(){ ## page
	LC_ALL=C grep -oE '`[^`]+:[0-9]+`' "$rigPackage/$1" | tr -d '`' \
		| LC_ALL=C grep -vE '^((sh-lib|sh-scripts)/[A-Za-z0-9._/-]+)?:[0-9]+$' | LC_ALL=C sort -u
}

## The files of the tree a bare citation's name matches, relative to the package, one a line.
rigNamed(){ ## bare name
	find "$rigPackage/sh-lib" "$rigPackage/sh-scripts" -name "$1" 2>/dev/null | while IFS= read -r namedPath ; do
		printf '%s\n' "${namedPath#$rigPackage/}"
	done
}

## Every backticked function name of one page that begins Agents, sorted and unique.
rigFunctions(){ ## page
	LC_ALL=C grep -oE '`Agents[A-Za-z0-9]+`' "$rigPackage/$1" \
		| tr -d '`' | LC_ALL=C sort -u
}

## `present` or `missing`, for a path the check would cite.
rigAnswerFor(){ ## relative path
	if [ -e "$rigPackage/$1" ] ; then printf 'present' ; else printf 'missing' ; fi
}

## `in-range`, `out-of-range` or `no-file`, for a cited path and line.
rigInRange(){ ## relative path, line number
	local count
	count="$( rigLineCount "$1" )"
	[ "$count" -gt 0 ] || { printf 'no-file' ; return 0 ; }
	[ "$2" -le "$count" ] && printf 'in-range' || printf 'out-of-range'
}

## --- 1 and 2: the path probe answers both ways ---
printf '%s\n' '## the path probe, both directions'
rigAssert "control: a path the tree holds reads present" \
	"$( rigAnswerFor sh-lib/harness/AgentsHarnessRun.include )" "present"
rigAssert "a path the tree does not hold reads missing" \
	"$( rigAnswerFor sh-lib/harness/NoSuchFileAtAll.include )" "missing"

## --- 3 and 4: the line-range probe answers both ways ---
printf '%s\n' '## the line-range probe, both directions'
rigAssert "control: a line inside its file reads in range" \
	"$( rigInRange sh-lib/harness/AgentsHarnessRun.include 757 )" "in-range"
rigAssert "a line past its file's end reads out of range" \
	"$( rigInRange sh-lib/harness/AgentsHarnessRun.include 999999 )" "out-of-range"

## --- 5 to 8: every page, and every citation of it ---
for rigPage in $rigPages ; do
	printf '## %s\n' "$rigPage"
	rigAssert "the page is present" "$( rigPathPresent "$rigPage" && printf 'yes' || printf 'no' )" "yes"
	[ -f "$rigPackage/$rigPage" ] || continue

	rigMissing=""
	for rigCited in $( rigCitations "$rigPage" ) ; do
		rigPathPresent "$rigCited" || rigMissing="$rigMissing $rigCited"
	done
	rigAssert "every path citation is present" "${rigMissing:-none}" "none"

	rigOut=""
	for rigCited in $( rigLineCitations "$rigPage" ) ; do
		rigPath="${rigCited%:*}" ; rigNumber="${rigCited##*:}"
		[ "$( rigInRange "$rigPath" "$rigNumber" )" = "in-range" ] || rigOut="$rigOut $rigCited"
	done
	rigAssert "every line citation is in range" "${rigOut:-none}" "none"

	rigBare=""
	for rigCited in $( rigBareCitations "$rigPage" ) ; do
		rigPath="$( rigNamed "${rigCited%%:*}" )"
		case "$( printf '%s' "$rigPath" | LC_ALL=C grep -c . )" in
			1) [ "$( rigInRange "$rigPath" "${rigCited##*:}" )" = "in-range" ] || rigBare="$rigBare $rigCited" ;;
			*) rigBare="$rigBare $rigCited" ;;
		esac
	done
	rigAssert "every bare citation names one file, and is in range there" "${rigBare:-none}" "none"

	rigGone=""
	for rigCited in $( rigFunctions "$rigPage" ) ; do
		LC_ALL=C grep -rq -- "$rigCited" "$rigPackage/sh-lib" "$rigPackage/sh-scripts" 2>/dev/null || rigGone="$rigGone $rigCited"
	done
	rigAssert "every function citation is found in the tree" "${rigGone:-none}" "none"
done

printf '\n# assertions: %s passed, %s failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" -eq 0 ] || { printf 'RESULT: FAIL (%s passed, %s failed)\n' "$rigPassCount" "$rigFailCount" ; exit 1 ; }
printf 'RESULT: PASS (%s assertions)\n' "$rigPassCount"
