#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
##
## The AE3 tree, and the two classpaths a check of one AE3 source file needs. Sourced by a check
## before it builds its arm:
##   . "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/ae3-tree.include.sh"

##
## WHY A PLACE, NOT A PATH. The AE3 tree is outside every workspace's own source. A check asks the
## workspace's own places for it, and never carries one machine's path.
##
##   ae3TreeRoot <project>...   the root of the first place holding a tree with every project named;
##                              MDAT_AE3_TREE names a root of its own, and is how a check is shown
##                              to fail: run it against a copy whose one guarded line is broken. One
##                              line on stderr and rc 1 when no place holds them all.
##   ae3CompilePath <root>      the classpath a javac of one AE3 source file takes: every project's
##                              bin, then the jars of ae3-packages. No axiom jar: several perst-*
##                              jars there are malformed and abort javac's classpath scan.
##   ae3RunPath <root>          the classpath a run takes: the compile path, then the axiom jars.
##   ae3Compile <classpath> <source> <output dir>
##                              javac of that one file into that dir's own tree. A failure is said
##                              and returns 1, so a stage that cannot reach its subject never passes.
##   ae3Run <seconds> <classpath> <main class> [<argument>...]
##                              java with a wall-clock bound, its output on stdout. Its status is
##                              java's; a run killed at the bound is said on stderr and returns 124.
##
## A run puts the arm's own output dir FIRST on its classpath, so the arm's compiled copy of that
## one file wins over the tree's bin. The tree's bin is a live Eclipse build, so it is the tree's
## own state and no control: an arm's control is a copy compiled from the source it was given.
##

ae3TreeRoot(){ ## project... -- the root of a tree holding all of them
	local rootTry rootPlace rootProject rootMissing
	if [ -n "${MDAT_AE3_TREE:-}" ] ; then
		for rootProject in "$@" ; do
			[ -d "$MDAT_AE3_TREE/$rootProject" ] || {
				echo "ae3-tree: MDAT_AE3_TREE holds no project: $MDAT_AE3_TREE/$rootProject" >&2
				return 1
			}
		done
		printf '%s\n' "$MDAT_AE3_TREE"
		return 0
	fi
	for rootTry in eclipse-ae3 myx-work/source/ae3 ws-myx.ae3-devel/source/ae3 ; do
		rootPlace="$( DistroAgentsKnowledge.fn.sh --get-place-path "$rootTry" 2> /dev/null )" || continue
		[ -n "$rootPlace" ] && [ -d "$rootPlace" ] || continue
		rootMissing=""
		for rootProject in "$@" ; do
			[ -d "$rootPlace/$rootProject" ] || rootMissing="$rootMissing $rootProject"
		done
		if [ -z "$rootMissing" ] ; then
			printf '%s\n' "$rootPlace"
			return 0
		fi
		echo "ae3-tree: the place $rootTry holds no project:$rootMissing" >&2
	done
	echo "ae3-tree: no place holds a tree with every project: $*" >&2
	return 1
}

ae3CompilePath(){ ## root -- the classpath for a javac of one AE3 source file
	local pathOut="" pathOne
	for pathOne in "$1"/*/bin "$1"/*/ae3-packages/*/jars/*.jar ; do
		[ -e "$pathOne" ] || continue
		pathOut="${pathOut:+$pathOut:}$pathOne"
	done
	printf '%s\n' "$pathOut"
}

ae3RunPath(){ ## root -- the classpath for a run
	local pathOut pathOne
	pathOut="$( ae3CompilePath "$1" )"
	for pathOne in "$1"/acm-cvs/sys-current/axiom/*.jar ; do
		[ -e "$pathOne" ] || continue
		pathOut="$pathOut:$pathOne"
	done
	printf '%s\n' "$pathOut"
}

ae3Compile(){ ## classpath, source file, output dir
	local compileSaid
	compileSaid="$( javac -nowarn -cp "$1" -d "$3" "$2" 2>&1 )" || {
		printf '⛔ ERROR: javac failed: %s\n%s\n' "$2" "$compileSaid" >&2
		return 1
	}
	return 0
}

ae3Run(){ ## seconds, classpath, main class, arguments... -- java, bounded by the wall clock
	local runBound="$1" runCp="$2" runMain="$3" runPid runWatcher runStatus
	shift 3
	java -cp "$runCp" "$runMain" "$@" &
	runPid=$!
	{
		sleep "$runBound"
		kill -9 "$runPid" 2> /dev/null && echo "ae3-tree: the run was killed after ${runBound}s" >&2
	} &
	runWatcher=$!
	wait "$runPid" 2> /dev/null ; runStatus=$?
	kill "$runWatcher" 2> /dev/null || :
	wait "$runWatcher" 2> /dev/null || :
	return "$runStatus"
}
