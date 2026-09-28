#!/usr/bin/env bash
set -u
[ ! -f "$RIG_SCENARIO/mcp.dead" ] || exit 1
while IFS= read -r rigLine ; do
	case "$rigLine" in
		*'"method":"initialize"'*)
			printf '%s\n' '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2024-11-05","capabilities":{},"serverInfo":{"name":"rigmcp","version":"1"}}}'
		;;
		*'"method":"tools/list"'*)
			printf 'list\n' >> "$RIG_SCENARIO/mcp.calls"
			printf '%s\n' '{"jsonrpc":"2.0","id":2,"result":{"tools":[{"name":"ping","description":"RIG-DESC-MARKER","inputSchema":{"type":"object","properties":{"word":{"type":"string","description":"RIG-SCHEMA-MARKER"}},"required":["word"]}}]}}'
			## This server dies after handing over its tools, which is what makes the
			## mid-run death a real one rather than a name that never resolved.
			[ -z "${RIG_MCP_DIE_AFTER_LIST:-}" ] || : > "$RIG_SCENARIO/mcp.dead"
		;;
		*'"method":"tools/call"'*)
			printf 'call\n' >> "$RIG_SCENARIO/mcp.calls"
			rigWord="${rigLine##*\"word\":\"}"
			rigWord="${rigWord%%\"*}"
			printf '{"jsonrpc":"2.0","id":3,"result":{"content":[{"type":"text","text":"RIG-MCPRESULT:%s"}]}}\n' "$rigWord"
		;;
	esac
done
