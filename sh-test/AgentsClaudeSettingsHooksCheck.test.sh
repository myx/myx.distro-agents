#!/usr/bin/env bash
## Behavioural check on the settings merge and verifier for hook entries under more
## than one hooks event. A descriptor with a third field lands under that event, one
## without it under PreToolUse; a second merge changes nothing; the verifier finds
## each entry under its own event and reports one that is absent. Offline: two awk
## programs over files in this check's own temp tree.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHere/AgentsClaudeWorkspaceRestrictionsUpsert.awk" ] || rigRefuse "the settings merge is missing: $rigHere/AgentsClaudeWorkspaceRestrictionsUpsert.awk"
[ -f "$rigHere/AgentsClaudeSettingsVerify.awk" ] || rigRefuse "the settings verifier is missing: $rigHere/AgentsClaudeSettingsVerify.awk"

rigTmp="$( mktemp -d -t AgentsClaudeSettingsHooksCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

printf '{\n  "permissions": {"allow": [], "deny": []},\n  "hooks": {"PreToolUse": []}\n}\n' > "$rigTmp/settings.json"
{
	printf '%s\t%s\n' ".claude/hooks/rig-pre.sh" '{"matcher": "Read", "hooks": [{"type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/rig-pre.sh"}]}'
	printf '%s\t%s\t%s\n' ".claude/hooks/rig-permission.sh" '{"hooks": [{"type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/rig-permission.sh"}]}' "PermissionRequest"
} > "$rigTmp/hooks.txt"

rigMerge(){ ## input settings, output settings
	MYX_WSRESTRICT_DENY_ADD_JSON='["Bash"]' MYX_WSRESTRICT_HOOKS_FILE="$rigTmp/hooks.txt" MYX_WSRESTRICT_RETIRED_HOOKS="" \
		MYX_WSRESTRICT_ALLOW_SOURCE_ROOT=/rig/source MYX_WSRESTRICT_ALLOW_AGENTS_ROOT=/rig/.claude/skills \
		MYX_WSRESTRICT_ALLOW_EXTRA_ROOTS_JSON='[]' MYX_WSRESTRICT_ALLOW_WRITE_ROOTS_JSON='[]' \
		LC_ALL=C awk -f "$rigHere/AgentsClaudeWorkspaceRestrictionsUpsert.awk" "$1" > "$2"
}
rigVerify(){ ## event (empty for the default), key, settings
	MYX_CLAUDEVERIFY_HOOK_EVENT="$1" MYX_CLAUDEVERIFY_HOOK_KEYS="$2" \
		LC_ALL=C awk -f "$rigHere/AgentsClaudeSettingsVerify.awk" < "$3" 2>&1 | head -1
}

rigMerge "$rigTmp/settings.json" "$rigTmp/merged.json" || rigRefuse "the merge failed on a plain settings file"
rigAssert "the PermissionRequest entry is under its own event" "$( rigVerify PermissionRequest .claude/hooks/rig-permission.sh "$rigTmp/merged.json" )" "hooks.PermissionRequest .claude/hooks/rig-permission.sh: OK"
rigAssert "the entry with no event is under PreToolUse" "$( rigVerify "" .claude/hooks/rig-pre.sh "$rigTmp/merged.json" )" "hooks.PreToolUse .claude/hooks/rig-pre.sh: OK"
rigAssert "the PermissionRequest entry is not under PreToolUse" "$( rigVerify "" .claude/hooks/rig-permission.sh "$rigTmp/merged.json" )" "hooks.PreToolUse .claude/hooks/rig-permission.sh: MISSING"
rigAssert "the verifier reports an absent entry as missing" "$( rigVerify PermissionRequest .claude/hooks/rig-permission.sh "$rigTmp/settings.json" )" "hooks.PermissionRequest .claude/hooks/rig-permission.sh: MISSING"
rigMerge "$rigTmp/merged.json" "$rigTmp/merged2.json" || rigRefuse "the second merge failed"
rigAssert "a second merge changes nothing" "$( cmp -s "$rigTmp/merged.json" "$rigTmp/merged2.json" && printf same || printf changed )" same
printf '%s\t%s\t%s\n' ".claude/hooks/rig-bad.sh" '{"hooks": []}' "Pre Tool" > "$rigTmp/hooks.txt"
rigAssert "an event that is not a plain name is refused" "$( rigMerge "$rigTmp/settings.json" "$rigTmp/bad.json" 2>/dev/null && printf merged || printf refused )" refused

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SETTINGS HOOKS CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SETTINGS_HOOKS: OK (%d assertions, offline)\n' "$rigPasses"
