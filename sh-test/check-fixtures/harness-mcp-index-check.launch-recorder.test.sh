#!/usr/bin/env bash
## Records exactly how it was launched -- every argument and the environment entries## a registration may set -- one value per line with its byte count, then behaves as the
## rig MCP server beside it. The recording is what proves two ways of resolving a
## registration launch the same process.
set -u
{
	printf 'argc=%s\n' "$#"
	for recArg in "$@" ; do printf 'arg[%s]=%s\n' "${#recArg}" "$recArg" ; done
	recProbe="${RIG_MCP_PROBE-<unset>}"
	recOther="${RIG_MCP_OTHER-<unset>}"
	recWs="${MMDAPP-<unset>}"
	printf 'env RIG_MCP_PROBE[%s]=%s\n' "${#recProbe}" "$recProbe"
	printf 'env RIG_MCP_OTHER[%s]=%s\n' "${#recOther}" "$recOther"
	printf 'env MMDAPP[%s]=%s\n' "${#recWs}" "$recWs"
	printf -- '--\n'
} >> "$RIG_SCENARIO/launch.log"
exec "${0%/*}/rigmcp"
