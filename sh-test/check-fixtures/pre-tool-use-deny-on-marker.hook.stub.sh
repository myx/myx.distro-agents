#!/usr/bin/env bash
set -u
case "$( cat )" in
	*RIG-ARG-MARKER*)
		printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"RIG-HOOK-DENIED"}}'
	;;
esac
