#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
##
## The one way a check of sh-test makes the folder its rig lives in. Sourced by the check:
##   . "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh"
##
## WHY. No file of this package is ever kept in the system's temp folder (the owner's rule, held for every
## file of the package by AgentsTempNamesCheck): a rig lives in the workspace the check runs in, under
## .local/agents/scratch/sh-test/, beside the harness's own scratch and like it outside every member's floor
## (AgentsTools.Grants.include), so no grant of the workspace reaches a path of a rig. Where there is no
## workspace there is no rig, and no result.
##
##   rigTempDir <name>   prints the path of a new, empty folder, $MMDAPP/.local/agents/scratch/sh-test/<name>.XXXXXXXX,
##                       made by mktemp -d. With no MMDAPP, or one that is no folder, it makes nothing, says so
##                       on stderr, and returns 1, for the check to end on before it reports a result.
##

rigTempDir(){
	if [ -z "${MMDAPP:-}" ] || [ ! -d "$MMDAPP" ] ; then
		echo "⛔ ERROR: MMDAPP names no workspace, so this rig has no place to live -- the system temp folder is never used; refusing to report a result" >&2
		return 1
	fi
	mkdir -p "$MMDAPP/.local/agents/scratch/sh-test" || return 1
	mktemp -d "$MMDAPP/.local/agents/scratch/sh-test/$1.XXXXXXXX"
}
