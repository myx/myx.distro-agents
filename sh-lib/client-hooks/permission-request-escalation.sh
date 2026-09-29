#!/bin/bash
## permission-request-escalation.sh -- the PermissionRequest hook for a *-native client.
## A REAL SCRIPT: installed by copying, runs exactly as it stands, nothing substituted.
##
## An interactive session keeps Claude Code's own prompt, so this hook stays silent there
## and the person answers as usual. An unattended session -- any other launch, the team's
## console in non-interactive mode and a spawn among them -- has nobody to answer, so the decision
## is taken by the team tooling instead: a grant for this session, tool and target
## allows; anything else is a refusal the tooling records and posts, denied with its id
## and the way to escalate for it. The one exception to builtins only is that one call
## into the tooling, which PermissionRequest can afford: it runs only when a prompt
## would appear, never on every tool call.
##
## It always prints a decision for an unattended session. Where the tooling cannot be
## reached it denies with a stated reason, because a hook that prints nothing is also a
## deny there, only with no reason given.

IFS= read -r -d '' hookInput

## Attended only from an interactive Claude Code client with no unattended marker and no
## spawn id -- the same rule the harness gate keys on. Anything else is unattended.
if [ "${MDAT_SESSION_UNATTENDED:-}" != "true" ] && [ -z "${MDAT_SPAWN_SESSION_ID:-}" ] ; then
	case "${CLAUDE_CODE_ENTRYPOINT:-}" in
		cli|claude-vscode) exit 0 ;;
	esac
fi

hookTools="${MDLT_ORIGIN:-${MMDAPP:-}/.local}/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
hookDecision=""
if [ -n "${MMDAPP:-}" ] && [ -x "$hookTools" ] ; then
	while IFS= read -r hookLine ; do
		[[ "$hookLine" == '{"hookSpecificOutput":'* ]] && hookDecision="$hookLine"
	done < <( printf '%s' "$hookInput" | "$hookTools" --intern-op-permission-hook "${MDAT_SPAWN_AGENT:-}" 2>/dev/null )
fi

if [ -n "$hookDecision" ] ; then
	printf '%s\n' "$hookDecision"
	exit 0
fi

printf '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny","message":"Refused, and not recorded: the team tooling could not be reached from this hook, so there is no refusal id to escalate by. Report this."}}}\n'
exit 0
