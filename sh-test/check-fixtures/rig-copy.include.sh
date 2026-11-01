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
## The copy is a clone where the filesystem has one (APFS `cp -c`: no space, no copy of the bytes) and a plain copy
## elsewhere, so the cost stays flat on this machine and the result is the same on FreeBSD and Linux. Links are read
## through, never carried: a copy holds the file a link named, so a rig holds no link at all, not even one inside it.
##
##   rigCopyTree <source> <destination>   makes <destination> a real copy of <source>, a file or a whole tree, and
##                                        prints nothing. <destination> must not exist, as it must not for `ln -s`:
##                                        the caller names a fresh path and makes its parents. Returns 1, saying
##                                        why, when the source is absent or the copy fails, so a check ends there
##                                        rather than reporting a result over half a tree.
##

rigCopyTree(){ ## source, destination
	[ -e "$1" ] || { echo "⛔ ERROR: rigCopyTree: no such source: $1" >&2 ; return 1 ; }
	[ -n "$2" ] && [ "$2" != / ] || { echo "⛔ ERROR: rigCopyTree: refusing the destination '$2'" >&2 ; return 1 ; }
	## `-c` is the clone, and GNU cp has no such option: it refuses at once, before writing a byte
	cp -RLcp "$1" "$2" 2> /dev/null && return 0
	rm -rf -- "$2"
	cp -RLp "$1" "$2" || { echo "⛔ ERROR: rigCopyTree: could not copy $1 to $2" >&2 ; return 1 ; }
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
