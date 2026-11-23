#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
##
## The one way a check of sh-test puts a tree where it works: a real copy, never a link. Sourced by the check:
##   . "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-copy.include.sh" || exit 1

##
## WHY. A rig that links the origin into its own workspace holds every write of the run one `ln -s` away from the
## owner's real packages, which carry no git and no backup: an index build, an install step or a delete reaches them
## through the link. A copy cannot reach them, whatever the run does.
##
## THE LANE. A check copies the same trees every run, and they move by a file or two between runs. So a tree is synced with
## rsync into a lane of its own, `$MMDAPP/.local/agents/scratch/rig-lanes/<cksum of its path>`, which sends only what changed and
## leaves `.git` out. The rig then takes its copy of the lane with rsync too: a tree reaches a rig by rsync only, never by `cp`.
## Links are read through, never carried, so a rig holds no link at all. A file is copied as it is.
## The lane is locked while it is synced and copied, so two checks of one run never read it half-written; a lock whose holder
## is gone is taken back, and said.
##
##   rigCopyTree <source> <destination>   makes <destination> a real copy of <source>, a file or a whole tree, and
##                                        prints nothing. A destination that is there already takes the tree into
##                                        itself, as copying `src/.` into `dst/` does. Returns 1, saying why, when the source is
##                                        absent or the copy fails, so a check ends there rather than reporting a result
##                                        over half a tree.
##

rigCopyTree(){ ## source, destination
	[ -e "$1" ] || { echo "⛔ ERROR: rigCopyTree: no such source: $1" >&2 ; return 1 ; }
	[ -n "$2" ] && [ "$2" != / ] || { echo "⛔ ERROR: rigCopyTree: refusing the destination '$2'" >&2 ; return 1 ; }
	[ "$1" != / ] || { echo "⛔ ERROR: rigCopyTree: refusing the source '/'" >&2 ; return 1 ; }
	case "$2" in "$1"/*) echo "⛔ ERROR: rigCopyTree: refusing a destination inside its source: $2" >&2 ; return 1 ;; esac
	if [ ! -d "$1" ] ; then
		rsync -tL "$1" "$2" || { echo "⛔ ERROR: rigCopyTree: could not copy $1 to $2" >&2 ; return 1 ; }
		return 0
	fi
	[ -n "${MMDAPP:-}" ] && [ -d "$MMDAPP" ] || { echo "⛔ ERROR: rigCopyTree: MMDAPP names no workspace, so the lane of $1 has no place" >&2 ; return 1 ; }
	(
		copyLane="$( cd -P "$1" && pwd -P | LC_ALL=C cksum )" || exit 1
		copyLane="$MMDAPP/.local/agents/scratch/rig-lanes/${copyLane%% *}"
		mkdir -p "${copyLane%/*}" || exit 1
		copyTries=0
		until mkdir "$copyLane.lock" 2> /dev/null ; do
			copyHolder="" ; { IFS= read -r copyHolder < "$copyLane.lock/pid" ; } 2> /dev/null || :
			if [ -n "$copyHolder" ] && ! kill -0 "$copyHolder" 2> /dev/null ; then
				echo "# rigCopyTree: the lock of $copyLane was held by $copyHolder, which is gone: taken back" >&2
				rm -rf -- "$copyLane.lock"
				continue
			fi
			copyTries=$(( copyTries + 1 ))
			[ "$copyTries" -le 600 ] || { echo "⛔ ERROR: rigCopyTree: the lane stays locked by ${copyHolder:-nobody named}: $copyLane.lock" >&2 ; exit 1 ; }
			sleep 1
		done
		trap "rm -rf -- $( printf '%q' "$copyLane.lock" ) 2> /dev/null || :" EXIT
		printf '%s\n' "$( exec sh -c 'echo "$PPID"' )" > "$copyLane.lock/pid" 2> /dev/null || :
		rsync -rtLO --delete --exclude=.git "$1/" "$copyLane/" || { echo "⛔ ERROR: rigCopyTree: could not sync $1 into its lane $copyLane" >&2 ; exit 1 ; }
		rsync -rtLO "$copyLane/" "$2/" || { echo "⛔ ERROR: rigCopyTree: could not copy $1 to $2" >&2 ; exit 1 ; }
	)
}

## The real binary of a rig, where a stub beside it must call the real one: a script that runs it, never a link to it.
## The command is looked up now, on this PATH, and the script calls that one path. Returns 1, saying why, when the
## command is not on PATH or the script cannot be written, so a check ends there rather than measuring a stub alone.
rigRealTool(){ ## command name, destination
	local toolPath
	toolPath="$( command -v "$1" 2> /dev/null )" || { echo "⛔ ERROR: rigRealTool: no $1 on PATH" >&2 ; return 1 ; }
	mkdir -p "${2%/*}" || return 1
	printf '#!/bin/sh\nexec %s "$@"\n' "'$toolPath'" > "$2" || return 1
	chmod +x "$2" || return 1
}
