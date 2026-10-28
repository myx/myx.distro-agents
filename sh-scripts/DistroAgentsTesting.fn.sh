#!/usr/bin/env bash

##
## DistroAgentsTesting.fn.sh -- the testing, running and bookkeeping operations (F7.6), for
## magic-tester, console human users and the console app. A subsystem interface: results are
## read from it. --skillset-validate-routine, a thin stub of the one validator, --intern-doc-validate,
## with no logic of its own; and the testbed (.local/agents/testing): --test-register, --test-update,
## --test-unregister, --test-invalidate and --test-list over the metadata of the tests, and
## --run-oldest-untested and --run-all-nightly-regressions, which put tests into the retest queue.
## All testing machinery gathers here, the retest queue included, and there is no second queue: the
## queue is the one of the --retest-* operations (AgentsTools.MemberRetest.include). A member raises a testing need through AgentTestingTools.fn.sh.
## The apply tool (W2) lives here too: --apply-tool mark|level|plan|apply, the one operation that applies a lane's work to a repository under
## $MMDAPP/.local/temp/live-apply.lock.
##
## From DistroAgentsTools.fn.sh (F1.4): --retest-drain, --retest-queue, --retest-result, --send-report (sh-lib/harness/AgentsContext.FrontTable.include).
##
## NOTE:
## Designed to be able to run without distro context. Starts console sessions.
##

if [ -z "$MMDAPP" ] ; then
	set -e
	export MMDAPP="$( ( cd "$( dirname "$0" )/../../../.." && pwd ) )"
	echo "$0: Working in: $MMDAPP"  >&2
	[ -d "$MMDAPP/.local" ] || ( echo "⛔ ERROR: expecting '.local' directory." >&2 && exit 1 )
fi

: "${MDLT_ORIGIN:=$MMDAPP/.local}"
export MDLT_ORIGIN

## Every child finds the bash this runs in, as DistroAgentsTools.fn.sh does.
case "$BASH" in
	/*/bash)
		command -v bash > /dev/null 2>&1 || { PATH="${PATH:+$PATH:}${BASH%/*}" ; export PATH ; }
		export MDAT_BASH="$BASH"
	;;
esac

## The testbed's operations (AgentsTools.Testbed.include), loaded where they are asked for.
DistroAgentsTestingTestbed(){
	type AgentsToolsTestbedRegister > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.Testbed.include"
}

## The operations that came here from DistroAgentsTools.fn.sh (F1.4): every one of them is asked what each name of the table is asked, in AgentsContext.FrontDoor.include.
DistroAgentsTestingMoved(){
	local MDSC_CMD='DistroAgentsTesting' frontDone="" frontRc=0
	type AgentsToolsFrontKnows > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontTable.include"
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontDoor.include"
	[ -z "$frontDone" ] || return "$frontRc"
	case "$1" in

		--retest-drain|--retest-queue|--retest-result)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/member/AgentsTools.MemberRetest.include"
			return $?
		;;

		--send-report)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.MagicCoordinatorState.include"
			return $?
		;;

		*)
			echo "$MDSC_CMD: ⛔ ERROR: invalid option: $1" >&2
			set +e ; return 1
		;;
	esac
}

DistroAgentsTesting(){
	local MDSC_CMD='DistroAgentsTesting'
	## F1.4: a name that came here from DistroAgentsTools.fn.sh runs its operation in the function below.
	type AgentsToolsFrontKnows > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.FrontTable.include"
	if AgentsToolsFrontKnows DistroAgentsTesting "$@" ; then
		DistroAgentsTestingMoved "$@"
		return $?
	fi
	## The three help forms, as DistroAgentsTools.fn.sh has them: no word the default syntax (the entry points a reader
	## starts from), --help-syntax the syntax line of every operation of this file, --help the manual.
	case "${1:-}" in
		''|--help|--help-syntax)
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/help/Help.DistroAgentsTesting.include"
			return $?
		;;
	esac
	## The common option set (F2.2): a run of --team-member, --session-id, --spawn-id, --select-workspace and --tooling-origin after the operation is taken here,
	## and the call is made again under what they resolve (sh-lib/common/AgentsTools.CommonOptions.include).
	case "${agentsCommonFronted:-}:${2:-}" in
		:--team-member|:--session-id|:--spawn-id|:--select-workspace|:--tooling-origin)
			local commonRc=0
			type AgentsToolsCommonRun > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.CommonOptions.include"
			AgentsToolsCommonRun DistroAgentsTesting DistroAgentsTesting.fn.sh "$@" || commonRc=$?
			return "$commonRc"
		;;
	esac
	case "$1" in

		## The metadata of the tests: <test-id> --project <p> --script <path> [--functionality <f>] [--keyword <k>]... [--rig <path>]
		## [--document <path>]... [--resource <path>]... [--nightly yes|no], or --from-folder <dir> --project <p> for every *.test.sh of a folder.
		--test-register)
			local testOp="$1"
			shift
			DistroAgentsTestingTestbed
			AgentsToolsTestbedRegister "$testOp" "$@"
			return $?
		;;

		## Changes the metadata of a registered test: <test-id> and the options of --test-register, a list replaced whole.
		--test-update)
			local testOp="$1"
			shift
			DistroAgentsTestingTestbed
			AgentsToolsTestbedUpdate "$testOp" "$@"
			return $?
		;;

		## Takes a test out of the testbed: <test-id>. The test, its script and its pass record stay.
		--test-unregister)
			local testOp="$1"
			shift
			DistroAgentsTestingTestbed
			AgentsToolsTestbedUnregister "$testOp" "$@"
			return $?
		;;

		## Drops the pass record of a registered test, so that the next batch runs it: <test-id>.
		--test-invalidate)
			local testOp="$1"
			shift
			DistroAgentsTestingTestbed
			AgentsToolsTestbedInvalidate "$testOp" "$@"
			return $?
		;;

		## The registered tests, with their stats and a short run history: [--project <p>] [--namespace <n>] [--keyword <k>].
		--test-list)
			local testOp="$1"
			shift
			DistroAgentsTestingTestbed
			AgentsToolsTestbedList "$testOp" "$@"
			return $?
		;;

		## The oldest untested registered test, or all that are eligible for the nightly, into the retest queue: [--wait|--no-wait].
		--run-oldest-untested|--run-all-nightly-regressions)
			local testOp="$1"
			shift
			DistroAgentsTestingTestbed
			AgentsToolsTestbedRun "$testOp" "$@"
			return $?
		;;

		## Checks a routine file's frontmatter and required headers, and reports what is missing or
		## wrong, a row each; exit non-zero where any. <routine-file|--from-stdin>. Read-only.
		--skillset-validate-routine)
			shift
			if [ -z "${1:-}" ] || [ $# -gt 1 ] ; then
				echo "$MDSC_CMD: ⛔ ERROR: --skillset-validate-routine: syntax is <routine-file|--from-stdin>" >&2
				set +e ; return 1
			fi
			"$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-doc-validate routine "$1"
			return $?
		;;

		## The apply tool (W2): mark, level, plan and apply this work to a repository, all of it under
		## $MMDAPP/.local/temp/live-apply.lock. <mark|level|plan|apply> [--repository <repository-path>]
		## [--scratch <scratch-path>] [mark: <package>/<relative-path>...].
		--apply-tool)
			shift
			DistroAgentsTestingApply "$@"
			return $?
		;;

		*)
			echo "$MDSC_CMD: ⛔ ERROR: invalid option: $1" >&2
			set +e ; return 1
		;;
	esac
}

## The apply tool (W2, DistroAgentsTesting.fn.sh --apply-tool): one operation for the four beats of applying a lane's work to a repository, the
## predecessor's level.sh, mine.sh and apply.sh as one. The scratch is laid out as the predecessor's: changed-files.txt and apply-order.txt list the
## files this work changed, one `<package>/<package-relative path>` a line, in the order definitions stand before callers; base/<path> holds live's
## text of each marked file as the change began; source/myx/<path> holds this work's file; packages.txt lists the packages to level, one name a
## line; levelled.sums keeps the checksum of each file level.sh put there. `mark` records a file's base and lists it, refusing a file whose scratch
## copy is not live's text now (a base that would be taken after the edit); `level` brings the scratch packages level with live, overwriting only
## what it last put there, refusing an unmarked file already edited, and removing what live no longer has; `plan` is the dry run, read-only, naming
## each file new, at its base, or moved -- and whether the three-way merge is clean and exact now -- with the lines it removes of its base and adds
## to it; `apply` takes $MMDAPP/.local/temp/live-apply.lock, stages each file beside its live place (a moved file only as a clean three-way merge
## whose change equals this work's), compares live with its snapshot again right before each rename, puts the work in place, and gives the lock
## back leaving no temp behind. A repository outside the workspace applies the same, one repository per call. The self-test
## sh-test/common/AgentsApplyToolCheck.test.sh is its test; MDAT_APPLY_BEFORE_PUT and MDAT_APPLY_BEFORE_CHECK are that test's alone.
DistroAgentsTestingApplyChange(){ ## from, to -- the +/- lines of a diff, as one comparison text (nothing of the hunk headers)
	diff -u "$1" "$2" 2> /dev/null | LC_ALL=C grep -e '^[+-]' | LC_ALL=C grep -v -e '^+++' -e '^---' || :
}
DistroAgentsTestingApplyCount(){ ## from, to -- "N removed, M added"
	diff "$1" "$2" 2> /dev/null | LC_ALL=C awk '/^</ { r++ } /^>/ { a++ } END { printf "%d removed, %d added\n", r + 0, a + 0 }'
}
DistroAgentsTestingApplyParses(){ ## file, candidate -- rc 0 where the candidate parses (shell files only)
	case "$1" in *.sh|*.include) "$BASH" -n "$2" 2> /dev/null ;; *) return 0 ;; esac
}
DistroAgentsTestingApplySum(){ ## file -- the checksum level keeps
	LC_ALL=C cksum < "$1" 2> /dev/null | LC_ALL=C awk '{ print $1 "-" $2 }'
}

DistroAgentsTestingApply(){
	local applyVerb="${1:-}" applyRepo="$MMDAPP" applyScratch="$MMDAPP/.local/temp/agents-scratch"
	shift
	while [ $# -gt 0 ] ; do
		case "$1" in
			--repository) [ -n "${2:-}" ] || { echo "⛔ ERROR: ${MDSC_CMD:-DistroAgentsTesting} --apply-tool: --repository takes a path" >&2 ; return 1 ; } ; applyRepo="$2" ; shift 2 ;;
			--scratch) [ -n "${2:-}" ] || { echo "⛔ ERROR: ${MDSC_CMD:-DistroAgentsTesting} --apply-tool: --scratch takes a path" >&2 ; return 1 ; } ; applyScratch="$2" ; shift 2 ;;
			--*) echo "⛔ ERROR: ${MDSC_CMD:-DistroAgentsTesting} --apply-tool: unknown option: $1" >&2 ; return 1 ;;
			*) break ;;
		esac
	done
	[ -n "$applyVerb" ] || { echo "⛔ ERROR: ${MDSC_CMD:-DistroAgentsTesting} --apply-tool: syntax is <mark|level|plan|apply> [--repository <path>] [--scratch <path>] [mark: <package>/<relative-path>...]" >&2 ; return 1 ; }
	case "$applyVerb" in
		mark) DistroAgentsTestingApplyMark "$applyRepo" "$applyScratch" "$@" ; return $? ;;
		level) DistroAgentsTestingApplyLevel "$applyRepo" "$applyScratch" ; return $? ;;
		plan) DistroAgentsTestingApplyPlan "$applyRepo" "$applyScratch" ; return $? ;;
		apply) DistroAgentsTestingApplyDo "$applyRepo" "$applyScratch" ; return $? ;;
		*) echo "⛔ ERROR: ${MDSC_CMD:-DistroAgentsTesting} --apply-tool: syntax is <mark|level|plan|apply> ..., got: $applyVerb" >&2 ; return 1 ;;
	esac
}

## mark: records live's text of each file as its base (once) and lists the file in changed-files.txt. MARK A FILE BEFORE EDITING IT, after the level.
## A file whose scratch copy differs from live is refused: it is older than the base would be, or already edited, and applying it would put back
## what live gained since.
DistroAgentsTestingApplyMark(){ ## repository, scratch, package/relative...
	local markRepo="$1" markScratch="$2" markFile markPkg markRel
	shift 2
	[ $# -gt 0 ] || { echo "⛔ ERROR: ${MDSC_CMD:-DistroAgentsTesting} --apply-tool mark: syntax is mark [--repository <path>] [--scratch <path>] <package>/<relative-path>..." >&2 ; return 1 ; }
	touch "$markScratch/changed-files.txt" 2> /dev/null
	for markFile in "$@" ; do
		markPkg="${markFile%%/*}" ; markRel="${markFile#*/}"
		if [ "$markPkg" = "$markFile" ] || [ -z "$markRel" ] ; then
			echo "⛔ ERROR: ${MDSC_CMD:-DistroAgentsTesting} --apply-tool mark: not <package>/<relative-path>: $markFile" >&2 ; continue
		fi
		if LC_ALL=C grep -Fxq -- "$markFile" "$markScratch/changed-files.txt" ; then echo "already marked: $markFile" ; continue ; fi
		if [ -f "$markRepo/source/myx/$markPkg/$markRel" ] ; then
			if [ -f "$markScratch/source/myx/$markPkg/$markRel" ] && ! cmp -s "$markRepo/source/myx/$markPkg/$markRel" "$markScratch/source/myx/$markPkg/$markRel" ; then
				echo "🙋 WARNING: REFUSED: $markFile -- the scratch copy is not live's text now: level it before marking, and mark before editing" >&2
				continue
			fi
			if [ ! -f "$markScratch/base/$markPkg/$markRel" ] ; then
				mkdir -p "$markScratch/base/$markPkg/$( dirname "$markRel" )" 2> /dev/null || { echo "⛔ ERROR: ${MDSC_CMD:-DistroAgentsTesting} --apply-tool mark: could not record the base of $markFile" >&2 ; return 1 ; }
				cp -p "$markRepo/source/myx/$markPkg/$markRel" "$markScratch/base/$markPkg/$markRel" 2> /dev/null || { echo "⛔ ERROR: ${MDSC_CMD:-DistroAgentsTesting} --apply-tool mark: could not record the base of $markFile" >&2 ; return 1 ; }
			fi
		fi
		printf '%s\n' "$markFile" >> "$markScratch/changed-files.txt"
		echo "marked: $markFile"
	done
	return 0
}

## level: brings the scratch packages level with live for every file this work has NOT marked. A file live changed and this work changed too is a
## conflict, never overwritten. A file that is NOT marked and differs from live is overwritten from live only if it is still what the last level left
## in it: a file somebody edited without marking it is refused and left alone. A file gone from live is removed from the scratch (not mine) only
## where a level put it there and it is unchanged; any other unmarked file live does not hold is a builder's new one, said and kept. Ends
## LEVEL: OK, or LEVEL: CONFLICT (rc 1).
DistroAgentsTestingApplyLevel(){ ## repository, scratch
	local levelRepo="$1" levelScratch="$2" levelPkg levelF levelL levelP levelConflict=0 levelKept levelSum
	[ -f "$levelScratch/packages.txt" ] || { echo "⛔ ERROR: ${MDSC_CMD:-DistroAgentsTesting} --apply-tool level: $levelScratch/packages.txt is not there" >&2 ; return 1 ; }
	touch "$levelScratch/changed-files.txt" "$levelScratch/levelled.sums" 2> /dev/null
	while IFS= read -r levelPkg ; do
		[ -n "$levelPkg" ] || continue
		levelL="$levelRepo/source/myx/$levelPkg"
		levelP="$levelScratch/source/myx/$levelPkg"
		[ -d "$levelL" ] || continue
		while IFS= read -r levelF ; do
			levelF="${levelF#./}"
			if [ -f "$levelP/$levelF" ] && cmp -s "$levelL/$levelF" "$levelP/$levelF" ; then continue ; fi
			if LC_ALL=C grep -Fxq -- "$levelPkg/$levelF" "$levelScratch/changed-files.txt" ; then
				if [ -f "$levelScratch/base/$levelPkg/$levelF" ] && cmp -s "$levelL/$levelF" "$levelScratch/base/$levelPkg/$levelF" ; then
					echo "mine, live still at its base: $levelPkg/$levelF"
				else
					echo "🙋 WARNING: CONFLICT: live moved under a file this work changed: $levelPkg/$levelF" ; levelConflict=1
				fi
				continue
			fi
			if [ -f "$levelP/$levelF" ] ; then
				levelKept="$( LC_ALL=C awk -v key="$levelPkg/$levelF" '$1 == key { print $2 }' "$levelScratch/levelled.sums" | LC_ALL=C tail -1 )"
				if [ -n "$levelKept" ] && [ "$levelKept" != "$( DistroAgentsTestingApplySum "$levelP/$levelF" )" ] ; then
					echo "🙋 WARNING: EDITED UNMARKED: $levelPkg/$levelF -- not overwritten from live" ; levelConflict=1 ; continue
				fi
			fi
			mkdir -p "$levelP/$( dirname "$levelF" )" 2> /dev/null || { echo "⛔ ERROR: ${MDSC_CMD:-DistroAgentsTesting} --apply-tool level: could not make the scratch folder of $levelPkg/$levelF" >&2 ; return 1 ; }
			cp -p "$levelL/$levelF" "$levelP/$levelF" 2> /dev/null || { echo "⛔ ERROR: ${MDSC_CMD:-DistroAgentsTesting} --apply-tool level: could not copy $levelPkg/$levelF" >&2 ; return 1 ; }
			levelSum="$( DistroAgentsTestingApplySum "$levelP/$levelF" )"
			{ LC_ALL=C awk -v key="$levelPkg/$levelF" '$1 != key' "$levelScratch/levelled.sums" ; printf '%s %s\n' "$levelPkg/$levelF" "$levelSum" ; } > "$levelScratch/levelled.sums.new" 2> /dev/null && mv -f "$levelScratch/levelled.sums.new" "$levelScratch/levelled.sums" 2> /dev/null || { echo "⛔ ERROR: ${MDSC_CMD:-DistroAgentsTesting} --apply-tool level: could not keep the checksum of $levelPkg/$levelF" >&2 ; return 1 ; }
			echo "levelled from live: $levelPkg/$levelF"
		done < <( cd "$levelL" && find . -type f ! -path './.git/*' | LC_ALL=C sort )
		## A file this work marked with its base and live no longer holds: another builder removed or renamed it.
		while IFS= read -r levelF ; do
			case "$levelF" in "$levelPkg"/*) ;; *) continue ;; esac
			[ -f "$levelScratch/base/$levelF" ] && [ ! -e "$levelRepo/source/myx/$levelF" ] || continue
			echo "🙋 WARNING: CONFLICT: GONE on live: $levelF" ; levelConflict=1
		done < "$levelScratch/changed-files.txt"
		[ -d "$levelP" ] || continue
		while IFS= read -r levelF ; do
			levelF="${levelF#./}"
			[ ! -f "$levelL/$levelF" ] || continue
			if LC_ALL=C grep -Fxq -- "$levelPkg/$levelF" "$levelScratch/changed-files.txt" ; then
				[ -f "$levelScratch/base/$levelPkg/$levelF" ] || echo "mine, new in the scratch: $levelPkg/$levelF"
			## Removed only where a level put it there and it is still what that level left: else it is a builder's new file, and is kept.
			elif [ "$( LC_ALL=C awk -v key="$levelPkg/$levelF" '$1 == key { print $2 }' "$levelScratch/levelled.sums" | LC_ALL=C tail -1 )" = "$( DistroAgentsTestingApplySum "$levelP/$levelF" )" ] ; then
				rm -f -- "$levelP/$levelF" 2> /dev/null && echo "gone from live, removed from the scratch (not mine): $levelPkg/$levelF"
			else
				echo "new, unmarked: $levelPkg/$levelF -- kept; mark it before it is applied"
			fi
		done < <( cd "$levelP" && find . -type f ! -path './.git/*' | LC_ALL=C sort )
	done < "$levelScratch/packages.txt"
	if [ "$levelConflict" != 0 ] ; then echo "LEVEL: CONFLICT" ; return 1 ; fi
	echo "LEVEL: OK"
	return 0
}

## The path rules, at plan, stage and put: inside a package of packages.txt, relative, with no `.` or `..` part and no blank, and no symlink on
## live from the package down. Prints the reason; rc 0 where the path is refused.
DistroAgentsTestingApplyPathRefused(){ ## repository, scratch, <package>/<relative-path>
	local pathWalk="$1/source/myx/$3"
	case "$3" in
		/*|*/../*|../*|*/..|..|*/./*|./*|*/.|.) printf 'PATH REFUSED: %s -- absolute, or with a . or .. part\n' "$3" ; return 0 ;;
		*[[:space:]]*) printf 'PATH REFUSED: %s -- it holds a blank\n' "$3" ; return 0 ;;
	esac
	LC_ALL=C grep -Fxq -- "${3%%/*}" "$2/packages.txt" 2> /dev/null || { printf 'PATH REFUSED: %s -- not inside a package of packages.txt\n' "$3" ; return 0 ; }
	while [ "$pathWalk" != "$1/source/myx" ] ; do
		[ ! -L "$pathWalk" ] || { printf 'PATH REFUSED: %s -- a symlink on live\n' "$3" ; return 0 ; }
		pathWalk="${pathWalk%/*}"
	done
	return 1
}
## The faults of renames.txt (`<old><TAB><new>` a line) and removals.txt (a path a line): a line that is no pair, a case-only rename on macOS,
## a path changed-files.txt does not list. Prints each; rc 0 where there is one.
DistroAgentsTestingApplyListsRefused(){ ## scratch, the list files there are
	[ $# -gt 1 ] || return 1
	APPLY_CHANGED="$1/changed-files.txt" LC_ALL=C awk -F'\t' -v darwin="$( [ "$( uname -s )" = Darwin ] && printf 1 )" '
		BEGIN { changed = ENVIRON["APPLY_CHANGED"] ; while ( ( getline listedLine < changed ) > 0 ) listed[listedLine] = 1 ; }
		FILENAME ~ /renames\.txt$/ && $0 != "" {
			if ( NF != 2 || $1 == "" || $2 == "" ) { print "REFUSED: renames.txt: not <old><TAB><new>: " $0 ; bad = 1 ; next ; }
			if ( darwin && $1 != $2 && tolower( $1 ) == tolower( $2 ) ) { print "REFUSED: renames.txt: a case-only rename, which macOS cannot tell apart: " $0 ; bad = 1 ; }
			if ( !( $1 in listed ) || !( $2 in listed ) ) { print "REFUSED: renames.txt: a path changed-files.txt does not list: " $0 ; bad = 1 ; }
			next ;
		}
		FILENAME ~ /removals\.txt$/ && $0 != "" && !( $0 in listed ) { print "REFUSED: removals.txt: a path changed-files.txt does not list: " $0 ; bad = 1 ; }
		END { exit ( bad ? 0 : 1 ) ; }
	' "${@:2}"
}
## What a listed file is to this work: `remove`, `from<TAB><new>` (a rename's source), `to<TAB><old>` (a rename's new path), or nothing.
DistroAgentsTestingApplyRole(){ ## <package>/<relative-path>, the list files there are
	[ $# -gt 1 ] || return 0
	APPLY_WANT="$1" LC_ALL=C awk -F'\t' '
		BEGIN { want = ENVIRON["APPLY_WANT"] ; }
		FILENAME ~ /removals\.txt$/ && $0 == want { print "remove" ; exit ; }
		FILENAME ~ /renames\.txt$/ && NF == 2 && $1 == want { print "from\t" $2 ; exit ; }
		FILENAME ~ /renames\.txt$/ && NF == 2 && $2 == want { print "to\t" $1 ; exit ; }
	' "${@:2}"
}

## plan: the dry run, read-only. For each file: new, live at its base, or live moved -- and whether the merge is clean and exact now -- with the
## lines this work removes of its base and adds to it; each removal and rename. rc 4 where a file does not merge, a path or a list is refused,
## or a marked file is gone on live, so a hunk it would take from somebody else is seen before the apply.
DistroAgentsTestingApplyPlan(){ ## repository, scratch
	local planRepo="$1" planScratch="$2" planOrder="$2/apply-order.txt" planBad=0 planLists=( "$2/changed-files.txt" )
	local planF planPkg planRel planLive planBase planMine planChanged planMerged planRole
	[ -f "$planOrder" ] || { echo "⛔ ERROR: ${MDSC_CMD:-DistroAgentsTesting} --apply-tool plan: $planOrder is not there" >&2 ; return 1 ; }
	[ -f "$planScratch/packages.txt" ] || { echo "⛔ ERROR: ${MDSC_CMD:-DistroAgentsTesting} --apply-tool plan: $planScratch/packages.txt is not there" >&2 ; return 1 ; }
	if [ "$( LC_ALL=C sort "$planOrder" 2> /dev/null )" != "$( LC_ALL=C sort "$planScratch/changed-files.txt" 2> /dev/null )" ] ; then
		echo "⛔ ERROR: the apply order is not the changed list" >&2 ; return 2
	fi
	[ ! -f "$planScratch/renames.txt" ] || planLists+=( "$planScratch/renames.txt" )
	[ ! -f "$planScratch/removals.txt" ] || planLists+=( "$planScratch/removals.txt" )
	! DistroAgentsTestingApplyListsRefused "$planScratch" "${planLists[@]:1}" || planBad=1
	while IFS= read -r planF ; do
		[ -n "$planF" ] || continue
		planPkg="${planF%%/*}" ; planRel="${planF#*/}"
		planLive="$planRepo/source/myx/$planPkg/$planRel"
		planBase="$planScratch/base/$planPkg/$planRel"
		planMine="$planScratch/source/myx/$planPkg/$planRel"
		if DistroAgentsTestingApplyPathRefused "$planRepo" "$planScratch" "$planF" ; then planBad=1 ; continue ; fi
		planRole="$( DistroAgentsTestingApplyRole "$planF" "${planLists[@]:1}" )"
		## A removal or a rename's source: marked with its base, gone from the scratch, and live still at its base. Never merged, by design.
		case "$planRole" in
			remove|from*)
				if [ ! -f "$planBase" ] || [ -e "$planMine" ] ; then echo "🙋 WARNING: NOT A SOURCE: $planF -- a removal or a rename source is marked with its base and gone from the scratch" ; planBad=1
				elif [ ! -e "$planLive" ] ; then echo "🙋 WARNING: GONE on live: $planF" ; planBad=1
				elif ! cmp -s "$planLive" "$planBase" ; then echo "🙋 WARNING: MOVED on live, and a removal or a rename source is never merged: $planF" ; planBad=1
				elif [ "$planRole" = remove ] ; then echo "remove: $planF"
				fi
				continue
			;;
		esac
		if [ ! -f "$planBase" ] ; then
			if [ -e "$planLive" ] ; then echo "EXISTS on live, though new in this work: $planF" ; planBad=1
			elif [ ! -f "$planMine" ] ; then echo "🙋 WARNING: NOT IN THE SCRATCH: $planF" ; planBad=1 ; continue
			elif [ -n "$planRole" ] ; then echo "rename: ${planRole#to?} -> $planF (this work: $( DistroAgentsTestingApplyCount "$planScratch/base/${planRole#to?}" "$planMine" ))"
			else echo "new: $planF" ; fi
		elif [ ! -e "$planLive" ] ; then
			echo "🙋 WARNING: GONE on live: $planF" ; planBad=1 ; continue
		else
			planChanged="$( DistroAgentsTestingApplyCount "$planBase" "$planMine" )"
			if cmp -s "$planLive" "$planBase" ; then
				echo "at base: $planF (this work: $planChanged)"
			else
				planMerged="$( mktemp "$planScratch/stage.plan.XXXXXX" 2> /dev/null )"
				if [ -n "$planMerged" ] && diff3 -m "$planMine" "$planBase" "$planLive" > "$planMerged" 2> /dev/null && [ "$( DistroAgentsTestingApplyChange "$planBase" "$planMine" )" = "$( DistroAgentsTestingApplyChange "$planLive" "$planMerged" )" ] ; then
					echo "MOVED, merges clean and exact now: $planF (this work: $planChanged)"
				else
					echo "🙋 WARNING: MOVED, DOES NOT MERGE: $planF" ; planBad=1
				fi
				[ -z "$planMerged" ] || rm -f "$planMerged"
			fi
		fi
		DistroAgentsTestingApplyParses "$planF" "$planMine" || { echo "SYNTAX: $planF" ; planBad=1 ; }
	done < "$planOrder"
	if [ "$planBad" != 0 ] ; then echo "plan: not ready" ; return 4 ; fi
	printf 'plan ok: %s files\n' "$( LC_ALL=C wc -l < "$planOrder" | LC_ALL=C tr -d ' ' )"
	return 0
}

## apply: takes the lock, stages, puts in place, verifies. Nothing of the gate's own check is trusted: every file is looked at again, under the lock,
## at the moment it is put in place. Every write first, the removals last. Each step lands in applied-steps.txt as it is made, so an apply that
## stopped is run again and takes what the record and live both show as done. The whole runs in a subshell whose EXIT trap takes the staged temps
## and gives the lock back, whatever ends it; the lock holds an `owner` file, the process and the time.
DistroAgentsTestingApplyDo(){ ## repository, scratch
	local applyRepo="$1" applyScratch="$2" applyOrder="$2/apply-order.txt"
	local applyLock="$MMDAPP/.local/temp/live-apply.lock" applyStageDir="$2/stage.apply" applyTries=0 applyLists=( "$2/changed-files.txt" )
	local applyF applyPkg applyRel applyLive applyBase applyMine applyN applyBad applyRole applyPass applyRecord="$2/applied-steps.txt"
	local applyCand applyKind applyStopped applyDoneList applyStill applySyntax=""
	[ -f "$applyOrder" ] || { echo "⛔ ERROR: ${MDSC_CMD:-DistroAgentsTesting} --apply-tool apply: $applyOrder is not there" >&2 ; return 1 ; }
	[ -f "$applyScratch/packages.txt" ] || { echo "⛔ ERROR: ${MDSC_CMD:-DistroAgentsTesting} --apply-tool apply: $applyScratch/packages.txt is not there" >&2 ; return 1 ; }
	if [ "$( LC_ALL=C sort "$applyOrder" 2> /dev/null )" != "$( LC_ALL=C sort "$applyScratch/changed-files.txt" 2> /dev/null )" ] ; then
		echo "⛔ ERROR: the apply order is not the changed list" >&2 ; return 2
	fi
	[ ! -f "$applyScratch/renames.txt" ] || applyLists+=( "$applyScratch/renames.txt" )
	[ ! -f "$applyScratch/removals.txt" ] || applyLists+=( "$applyScratch/removals.txt" )
	## The work a record line belongs to: the checksum of its order and its lists, so a line of another work never reads as done.
	local applyRun
	applyRun="$( cat "$applyOrder" "${applyLists[@]:1}" | LC_ALL=C cksum | LC_ALL=C awk '{ print $1 "-" $2 ; }' )"
	if DistroAgentsTestingApplyListsRefused "$applyScratch" "${applyLists[@]:1}" ; then echo "ABORT: nothing put in place" ; return 4 ; fi
	mkdir -p "$( dirname "$applyLock" )" 2> /dev/null || { echo "⛔ ERROR: ${MDSC_CMD:-DistroAgentsTesting} --apply-tool apply: could not make the lock folder" >&2 ; return 1 ; }
	(
	until mkdir "$applyLock" 2> /dev/null ; do
		applyTries=$(( applyTries + 1 )) ; [ "$applyTries" -le 120 ] || { echo "⛔ ERROR: the lock stays taken: $applyLock" >&2 ; exit 3 ; }
		sleep 5
	done
	trap "for applyTrapCand in $( printf '%q' "$applyStageDir" )/cand.* ; do [ ! -s \"\$applyTrapCand\" ] || rm -f -- \"\$( cat \"\$applyTrapCand\" )\" ; done 2> /dev/null ; rm -rf -- $( printf '%q %q' "$applyStageDir" "$applyLock" ) 2> /dev/null ; echo 'lock released'" EXIT
	trap 'exit 129' HUP ; trap 'exit 130' INT ; trap 'exit 143' TERM
	printf 'pid %s at %s by %s\n' "$( exec sh -c 'echo "$PPID"' )" "$( date -u +%Y-%m-%dT%H:%M:%SZ )" "${USER:-?}" > "$applyLock/owner"
	echo "lock taken $( date -u +%Y-%m-%dT%H:%M:%SZ )"
	rm -rf "$applyStageDir" 2> /dev/null ; mkdir -p "$applyStageDir" 2> /dev/null || { echo "⛔ ERROR: ${MDSC_CMD:-DistroAgentsTesting} --apply-tool apply: could not make the stage folder" >&2 ; exit 1 ; }
	## 1. stage every file beside its live place, a snapshot of live as staged against kept: the writes in the order, then the removals.
	applyBad=0 ; applyN=0 ; : > "$applyStageDir/order"
	for applyPass in write remove ; do
	while IFS= read -r applyF ; do
		[ -n "$applyF" ] || continue
		applyRole="$( DistroAgentsTestingApplyRole "$applyF" "${applyLists[@]:1}" )"
		case "$applyPass:$applyRole" in write:remove|write:from*|remove:|remove:to*) continue ;; esac
		applyN=$(( applyN + 1 )) ; printf '%s\n' "$applyF" >> "$applyStageDir/order"
		applyPkg="${applyF%%/*}" ; applyRel="${applyF#*/}"
		applyLive="$applyRepo/source/myx/$applyPkg/$applyRel"
		applyBase="$applyScratch/base/$applyPkg/$applyRel"
		applyMine="$applyScratch/source/myx/$applyPkg/$applyRel"
		: > "$applyStageDir/cand.$applyN"
		if DistroAgentsTestingApplyPathRefused "$applyRepo" "$applyScratch" "$applyF" ; then applyBad=1 ; break 2 ; fi
		## A step is recorded before it is made: recorded, and live already as it would leave it, it is done.
		if { [ "$applyPass" = remove ] && [ ! -e "$applyLive" ] && LC_ALL=C grep -Fxq -- "removed"$'\t'"$applyF"$'\t'"$applyRun" "$applyRecord" 2> /dev/null ; } \
			|| { [ "$applyPass" = write ] && cmp -s "$applyLive" "$applyMine" && LC_ALL=C grep -Fxq -- "put"$'\t'"$applyF"$'\t'"$applyRun" "$applyRecord" 2> /dev/null ; } ; then
			printf 'done\n' > "$applyStageDir/kind.$applyN" ; echo "done already (record): $applyF" ; continue
		fi
		if [ "$applyPass" = remove ] ; then
			## A removal or a rename's source is taken only at its base: no merge, by design.
			if [ ! -f "$applyBase" ] || [ -e "$applyMine" ] ; then echo "NOT A SOURCE: $applyF -- a removal or a rename source is marked with its base and gone from the scratch" ; applyBad=1 ; break 2 ; fi
			[ -e "$applyLive" ] || { echo "GONE on live: $applyF" ; applyBad=1 ; break 2 ; }
			cmp -s "$applyLive" "$applyBase" || { echo "MOVED on live, and a removal or a rename source is never merged: $applyF" ; applyBad=1 ; break 2 ; }
			cp -p "$applyLive" "$applyStageDir/snap.$applyN" 2> /dev/null || { echo "cannot snapshot $applyF" ; applyBad=1 ; break 2 ; }
			printf 'remove\n' > "$applyStageDir/kind.$applyN"
			continue
		fi
		[ -f "$applyMine" ] || { echo "NOT IN THE SCRATCH: $applyF" ; applyBad=1 ; break 2 ; }
		[ ! -f "$applyBase" ] || [ -e "$applyLive" ] || { echo "GONE on live: $applyF" ; applyBad=1 ; break 2 ; }
		mkdir -p "$( dirname "$applyLive" )" 2> /dev/null || { echo "CANNOT STAGE beside $applyF" ; applyBad=1 ; break 2 ; }
		applyCand="$( mktemp "$applyLive.XXXXXX" 2> /dev/null )"
		if [ -z "$applyCand" ] ; then echo "CANNOT STAGE beside $applyF" ; applyBad=1 ; break 2 ; fi
		printf '%s\n' "$applyCand" > "$applyStageDir/cand.$applyN"
		if [ ! -f "$applyBase" ] ; then
			[ ! -e "$applyLive" ] || { echo "EXISTS on live, though new in this work: $applyF" ; applyBad=1 ; break 2 ; }
			: > "$applyStageDir/snap.$applyN" ; printf 'new\n' > "$applyStageDir/kind.$applyN"
			cp -p "$applyMine" "$applyCand" 2> /dev/null || { echo "cannot copy $applyF" ; applyBad=1 ; break 2 ; }
		else
			cp -p "$applyLive" "$applyStageDir/snap.$applyN" 2> /dev/null
			if cmp -s "$applyLive" "$applyBase" ; then
				printf 'base\n' > "$applyStageDir/kind.$applyN"
				cp -p "$applyMine" "$applyCand" 2> /dev/null || { echo "cannot copy $applyF" ; applyBad=1 ; break 2 ; }
			else
				if diff3 -m "$applyMine" "$applyBase" "$applyLive" > "$applyCand.merge" 2> /dev/null && [ "$( DistroAgentsTestingApplyChange "$applyBase" "$applyMine" )" = "$( DistroAgentsTestingApplyChange "$applyLive" "$applyCand.merge" )" ] ; then
					printf 'merged\n' > "$applyStageDir/kind.$applyN"
					cat "$applyCand.merge" > "$applyCand" ; rm -f "$applyCand.merge"
					chmod --reference="$applyLive" "$applyCand" 2> /dev/null || chmod "$( stat -f '%Lp' "$applyLive" 2> /dev/null )" "$applyCand" 2> /dev/null
				else
					rm -f "$applyCand.merge"
					echo "MOVED since the base and not mergeable cleanly and exactly now: $applyF" ; applyBad=1 ; break 2
				fi
			fi
		fi
		DistroAgentsTestingApplyParses "$applyF" "$applyCand" || { echo "SYNTAX of what would be put in place: $applyF" ; applyBad=1 ; break 2 ; }
	done < "$applyOrder"
	done
	if [ "$applyBad" != 0 ] ; then echo "ABORT: nothing put in place" ; exit 4 ; fi
	## 2. put in place one file at a time, each compared with its snapshot right before its rename or its removal, the path rules asked again.
	[ -z "${MDAT_APPLY_BEFORE_PUT:-}" ] || eval "$MDAT_APPLY_BEFORE_PUT"
	applyN=0 ; applyDoneList="" ; applyStopped=""
	while IFS= read -r applyF ; do
		applyN=$(( applyN + 1 ))
		applyPkg="${applyF%%/*}" ; applyRel="${applyF#*/}"
		applyLive="$applyRepo/source/myx/$applyPkg/$applyRel"
		applyCand="$( cat "$applyStageDir/cand.$applyN" )" ; applyKind="$( cat "$applyStageDir/kind.$applyN" )"
		[ "$applyKind" != done ] || continue
		if [ -z "$applyStopped" ] ; then
			if DistroAgentsTestingApplyPathRefused "$applyRepo" "$applyScratch" "$applyF" ; then
				applyStopped="the path of $applyF is refused now"
			elif [ "$applyKind" = new ] ; then
				[ ! -e "$applyLive" ] || applyStopped="$applyF appeared on live after it was staged"
			else
				cmp -s "$applyLive" "$applyStageDir/snap.$applyN" || applyStopped="$applyF moved on live after it was staged"
			fi
		fi
		if [ -n "$applyStopped" ] ; then [ -z "$applyCand" ] || rm -f "$applyCand" 2> /dev/null ; continue ; fi
		if [ "$applyKind" = remove ] ; then
			printf 'removed\t%s\t%s\n' "$applyF" "$applyRun" >> "$applyRecord"
			if rm -f -- "$applyLive" 2> /dev/null ; then
				applyDoneList="$applyDoneList $applyF (removed)" ; echo "removed: $applyF"
			else
				applyStopped="the removal of $applyF failed"
			fi
		elif printf 'put\t%s\t%s\n' "$applyF" "$applyRun" >> "$applyRecord" && mv -f "$applyCand" "$applyLive" 2> /dev/null ; then
			applyDoneList="$applyDoneList $applyF ($applyKind)" ; echo "put in place ($applyKind): $applyF"
		else
			applyStopped="the rename of $applyF failed" ; rm -f "$applyCand" 2> /dev/null
		fi
	done < "$applyStageDir/order"
	if [ -n "$applyStopped" ] ; then
		echo "STOPPED: $applyStopped"
		echo "done before it:${applyDoneList:- none}"
		echo "NOT done: the files of the stage order from that one on -- level, re-derive and run the plan again; applied-steps.txt keeps what was done"
		exit 5
	fi
	## 3. what is on live is what was staged, and it parses; a removal is gone, else rc 6.
	[ -z "${MDAT_APPLY_BEFORE_CHECK:-}" ] || eval "$MDAT_APPLY_BEFORE_CHECK"
	applyN=0 ; applyStill=""
	while IFS= read -r applyF ; do
		applyN=$(( applyN + 1 ))
		applyPkg="${applyF%%/*}" ; applyRel="${applyF#*/}"
		applyLive="$applyRepo/source/myx/$applyPkg/$applyRel"
		applyMine="$applyScratch/source/myx/$applyPkg/$applyRel"
		case "$( cat "$applyStageDir/kind.$applyN" )" in
			remove) if [ -e "$applyLive" ] ; then echo "STILL ON LIVE: $applyF" ; applyStill=1 ; else echo "live no longer holds: $applyF" ; fi ; continue ;;
			done) [ -e "$applyMine" ] || continue ;;
		esac
		DistroAgentsTestingApplyParses "$applyF" "$applyLive" || { echo "SYNTAX AFTER APPLY: $applyF" ; applySyntax=1 ; }
		if cmp -s "$applyLive" "$applyMine" ; then echo "live == this work's file: $applyF" ; else echo "live holds this work's file with another's hunks merged in: $applyF" ; fi
	done < "$applyStageDir/order"
	[ -z "$applyStill" ] || exit 6
	[ -z "$applySyntax" ] || exit 7
	date -u +%Y-%m-%dT%H:%M:%SZ > "$applyScratch/applied-at.txt" 2> /dev/null
	exit 0
	)
}

case "$0" in
	*/myx/myx.distro-agents/sh-scripts/DistroAgentsTesting.fn.sh)

		set -e

		if [ -z "$MDLT_ORIGIN" ] || ! type DistroAgentsContext >/dev/null 2>&1 ; then
			. "${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib/harness/AgentsContext.include"
		fi
		DistroAgentsContext --run-from-detect
		DistroAgentsContext --distro-path-auto

		## Copied from DistroAgentsTools.fn.sh: the test runner keys a pass by the myx.common it runs under, so the testbed
		## reads the pass record under the same one the retest queue's batch runs under, called from here or through the tool.
		if   [ -d "${MYXROOT:-}" ] && [ -f "$MYXROOT/bin/lib/catMarkdown.Common" ]; then
			export MYXROOT
		elif   [ -f "$MDLT_ORIGIN/myx/myx.common/os-myx.common/host/tarball/share/myx.common/bin/lib/catMarkdown.Common" ]; then
			export MYXROOT="$MDLT_ORIGIN/myx/myx.common/os-myx.common/host/tarball/share/myx.common"
		elif [ -f "/usr/local/share/myx.common/bin/lib/catMarkdown.Common" ]; then
			export MYXROOT="/usr/local/share/myx.common"
		elif command -v myx.common 2>/dev/null && myx.common which lib/catMarkdown 2>/dev/null ; then
			export MYXROOT="$( myx.common which lib/catMarkdown )"
			export MYXROOT="${MYXROOT%/bin/lib/catMarkdown*}"
		else
			export MYXROOT=''
		fi

		DistroAgentsTesting "$@"
	;;
	*)
		## Executed by an unrecognised path: error. Sourced ($0 differs from BASH_SOURCE[0]): stay silent.
		if [ "${BASH_SOURCE[0]:-}" = "$0" ] ; then
			echo "⛔ ERROR: DistroAgentsTesting.fn.sh: executed as '$0', which this file's own dispatch does not match, so nothing ran. Invoke it by a path ending in /myx/myx.distro-agents/sh-scripts/DistroAgentsTesting.fn.sh, or source it." >&2
			exit 1
		fi
	;;
esac
