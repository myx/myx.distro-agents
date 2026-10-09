#!/usr/bin/env bash
## Behavioural check on the settings merge and verifier for hook entries under more
## than one hooks event. A descriptor with a third field lands under that event, one
## without it under PreToolUse; a second merge changes nothing; the verifier finds
## each entry under its own event and reports one that is absent. A retired deny entry
## is removed on an exact match and the user's own deny rules stay. No allow entry is
## written; the file grants earlier installs wrote go, the user's own stay. Then the real
## --install-workspace-restrictions writes the policy's memory guard, fresh and over a
## hand-wired entry, and no file grant. Offline: everything in this check's own temp tree and HOME.
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
	MYX_WSRESTRICT_DENY_ADD_JSON='["Bash(rm *)"]' MYX_WSRESTRICT_HOOKS_FILE="$rigTmp/hooks.txt" MYX_WSRESTRICT_RETIRED_HOOKS="" \
		MYX_WSRESTRICT_RETIRED_DENY="Bash" \
		MYX_WSRESTRICT_RETIRED_ALLOW="$( printf '%s\n' 'Read(//rig/.claude/skills/**)' 'Read(//rig/.local/temp/team/**)' 'Edit(//rig/.local/temp/team/**)' )" \
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
rigDeny(){ ## settings -- the permissions.deny array, on one line
	tr -d '\n' < "$1" | sed -n 's/.*"deny": *\(\[[^]]*\]\).*/\1/p'
}
rigAssert "a fresh merge writes no blanket Bash deny" "$( rigDeny "$rigTmp/merged.json" )" '["Bash(rm *)"]'
printf '{\n  "permissions": {"allow": [], "deny": ["Bash", "Bash(git push*)", "WebFetch"]},\n  "hooks": {"PreToolUse": []}\n}\n' > "$rigTmp/old.json"
rigMerge "$rigTmp/old.json" "$rigTmp/old-merged.json" || rigRefuse "the merge failed on a settings file carrying the retired deny"
rigAssert "the retired Bash deny goes, the user's own deny rules stay" "$( rigDeny "$rigTmp/old-merged.json" )" '["Bash(git push*)", "Bash(rm *)", "WebFetch"]'
rigAllow(){ ## settings -- the permissions.allow array, on one line, or none
	tr -d '\n' < "$1" | sed -n 's/.*"allow": *\(\[[^]]*\]\).*/\1/p'
}
rigAssert "a fresh merge writes no allow entry at all" "$( rigAllow "$rigTmp/merged.json" )" '[]'
printf '{"model": "rig-model"}\n' > "$rigTmp/bare.json"
rigMerge "$rigTmp/bare.json" "$rigTmp/bare-merged.json" || rigRefuse "the merge failed on a settings file with no permissions"
rigAssert "and adds no allow key where there is none" "$( LC_ALL=C grep -c '"allow"' "$rigTmp/bare-merged.json" )" 0
printf '{\n  "permissions": {"allow": ["Read(//rig/source/**)", "Read(//rig-old/source/**)", "Read(//rig/.claude/skills/**)", "Read(//rig-old/.agents/**)", "Read(//rig/.local/temp/team/**)", "Edit(//rig/.local/temp/team/**)", "Read(//rig-user/notes/**)", "Bash(ls *)"], "deny": []},\n  "hooks": {"PreToolUse": []}\n}\n' > "$rigTmp/granted.json"
rigMerge "$rigTmp/granted.json" "$rigTmp/granted-merged.json" || rigRefuse "the merge failed on a settings file carrying earlier file grants"
rigAssert "the file grants earlier installs wrote go, the user's own entries stay in place" "$( rigAllow "$rigTmp/granted-merged.json" )" '["Read(//rig-user/notes/**)", "Bash(ls *)"]'
rigMerge "$rigTmp/granted-merged.json" "$rigTmp/granted-merged2.json" || rigRefuse "the second merge over dropped grants failed"
rigAssert "and a second merge changes nothing" "$( cmp -s "$rigTmp/granted-merged.json" "$rigTmp/granted-merged2.json" && printf same || printf changed )" same
printf '%s\t%s\t%s\n' ".claude/hooks/rig-bad.sh" '{"hooks": []}' "Pre Tool" > "$rigTmp/hooks.txt"
rigAssert "an event that is not a plain name is refused" "$( rigMerge "$rigTmp/settings.json" "$rigTmp/bad.json" 2>/dev/null && printf merged || printf refused )" refused

## The real --install-workspace-restrictions, in this check's own workspace and HOME: the
## policy's memory guard lands in settings.json, and a hand-wired entry running the same
## script (ws-myx-devops' own, verbatim) is taken as the policy's entry -- one entry, its
## script replaced by the package copy.
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigGuard="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/client-hooks/protect-memory-md.sh"
rigInstall(){ ## workspace
	mkdir -p "$1/.local" "$1/source" "$rigTmp/home"
	printf 'MDLT_CONSOLE_ORIGIN=%s\n' "$MDLT_ORIGIN" > "$1/.local/MDLT.settings.env"
	( cd "$1" && env HOME="$rigTmp/home" MMDAPP="$1" MDLT_ORIGIN="$MDLT_ORIGIN" bash "$rigTool" --install-workspace-restrictions --workspace "$1" ) > "$1.log" 2>&1
}
rigGuardEntries(){ ## settings -- matcher and count of entries running the memory guard
	tr -d '\n\t ' < "$1" | LC_ALL=C awk '{ n = gsub(/"matcher":"Edit\|Write","hooks":\[\{"type":"command","command":"\\"\$CLAUDE_PROJECT_DIR\\"\/\.claude\/hooks\/protect-memory-md\.sh"\}\]/, "") ; print n ; }'
}
mkdir -p "$rigTmp/fresh/.claude"
printf '{\n  "permissions": {"allow": [], "deny": []}\n}\n' > "$rigTmp/fresh/.claude/settings.json"
rigInstall "$rigTmp/fresh" || { cat "$rigTmp/fresh.log" >&2 ; rigRefuse "--install-workspace-restrictions failed on a fresh workspace" ; }
rigAssert "install: the memory guard is written into settings.json" "$( rigGuardEntries "$rigTmp/fresh/.claude/settings.json" )" 1
rigAssert "install: the verifier finds it" "$( rigVerify "" .claude/hooks/protect-memory-md.sh "$rigTmp/fresh/.claude/settings.json" )" "hooks.PreToolUse .claude/hooks/protect-memory-md.sh: OK"
rigAssert "install: the read guard is wired for Glob and Grep too" "$( rigVerify "" ".claude/hooks/deny-memory-md-read.sh Glob" "$rigTmp/fresh/.claude/settings.json" ) / $( rigVerify "" ".claude/hooks/deny-memory-md-read.sh Grep" "$rigTmp/fresh/.claude/settings.json" )" "hooks.PreToolUse .claude/hooks/deny-memory-md-read.sh Glob: OK / hooks.PreToolUse .claude/hooks/deny-memory-md-read.sh Grep: OK"
rigSetting(){ ## settings, key -- its value, whitespace dropped
	tr -d ' \t\n' < "$1" | sed -n 's/.*"'"$2"'":\([^,}]*\).*/\1/p'
}
rigAssert "install: claude auto-memory is turned off" "$( rigSetting "$rigTmp/fresh/.claude/settings.json" autoMemoryEnabled )" false
cp "$rigTmp/fresh/.claude/settings.json" "$rigTmp/fresh.first.json"
rigInstall "$rigTmp/fresh" || rigRefuse "a second --install-workspace-restrictions failed"
rigAssert "install: a second run changes nothing" "$( cmp -s "$rigTmp/fresh.first.json" "$rigTmp/fresh/.claude/settings.json" && printf same || printf changed )" same
rigAssert "install: its script is the package's" "$( cmp -s "$rigGuard" "$rigTmp/fresh/.claude/hooks/protect-memory-md.sh" && [ -x "$rigTmp/fresh/.claude/hooks/protect-memory-md.sh" ] && printf same || printf differs )" same
rigAssert "install: no file grant is written, Read, Edit or Write" "$( LC_ALL=C grep -c -e '"Read(' -e '"Edit(' -e '"Write(' "$rigTmp/fresh/.claude/settings.json" )" 0
rigAssert "install: the granted-call allow hook is wired, its script the package's" \
	"$( rigVerify "" .claude/hooks/allow-granted-native-tool.sh "$rigTmp/fresh/.claude/settings.json" ) / $( cmp -s "$rigHere/client-hooks/allow-granted-native-tool.sh" "$rigTmp/fresh/.claude/hooks/allow-granted-native-tool.sh" && [ -x "$rigTmp/fresh/.claude/hooks/allow-granted-native-tool.sh" ] && printf same || printf differs )" \
	"hooks.PreToolUse .claude/hooks/allow-granted-native-tool.sh: OK / same"
## The entries an earlier install wrote here, beside one of the user's own: they go, it stays.
rigOld="$rigTmp/old-grants"
mkdir -p "$rigOld/.claude"
printf '{"permissions": {"allow": ["Read(/%s/source/**)", "Read(/%s/.claude/skills/**)", "Read(/%s/**)", "Read(/%s/**)", "Read(/%s/.local/temp/team/**)", "Edit(/%s/.local/temp/team/**)", "Read(//rig-user/notes/**)"], "deny": []}}\n' \
	"$rigOld" "$rigOld" "$MDLT_ORIGIN/myx/myx.distro-agents/skillset" "$rigTmp/home/.claude/skills" "$rigOld" "$rigOld" > "$rigOld/.claude/settings.json"
rigInstall "$rigOld" || { cat "$rigOld.log" >&2 ; rigRefuse "--install-workspace-restrictions failed over earlier file grants" ; }
rigAssert "install: the file grants an earlier install wrote are dropped, the user's own stays" "$( rigAllow "$rigOld/.claude/settings.json" )" '["Read(//rig-user/notes/**)"]'
mkdir -p "$rigTmp/wired/.claude/hooks"
printf '{\n  "autoMemoryEnabled": true,\n  "model": "rig-model",\n  "hooks": {\n    "PreToolUse": [\n      {\n        "matcher": "Edit|Write",\n        "hooks": [\n          {\n            "type": "command",\n            "command": "\\"$CLAUDE_PROJECT_DIR\\"/.claude/hooks/protect-memory-md.sh"\n          }\n        ]\n      }\n    ]\n  }\n}\n' > "$rigTmp/wired/.claude/settings.json"
printf '#!/bin/bash\n## the old hand-wired copy\nexit 0\n' > "$rigTmp/wired/.claude/hooks/protect-memory-md.sh"
chmod +x "$rigTmp/wired/.claude/hooks/protect-memory-md.sh"
rigInstall "$rigTmp/wired" || { cat "$rigTmp/wired.log" >&2 ; rigRefuse "--install-workspace-restrictions failed on a hand-wired workspace" ; }
rigAssert "install: the hand-wired entry is the policy's one, never a second" "$( rigGuardEntries "$rigTmp/wired/.claude/settings.json" )" 1
rigAssert "install: an existing autoMemoryEnabled true is set false" "$( rigSetting "$rigTmp/wired/.claude/settings.json" autoMemoryEnabled )" false
rigAssert "install: an unrelated top-level key is untouched" "$( rigSetting "$rigTmp/wired/.claude/settings.json" model )" '"rig-model"'
mkdir -p "$rigTmp/readonly/.claude"
printf '{"hooks": {"PreToolUse": [{"matcher": "Read", "hooks": [{"type": "command", "command": "\\"$CLAUDE_PROJECT_DIR\\"/.claude/hooks/deny-memory-md-read.sh"}]}]}}\n' > "$rigTmp/readonly/.claude/settings.json"
rigInstall "$rigTmp/readonly" || { cat "$rigTmp/readonly.log" >&2 ; rigRefuse "--install-workspace-restrictions failed over an earlier Read-only memory guard" ; }
rigAssert "install: over an earlier Read-only guard, Glob and Grep entries are added" "$( tr -d '\n\t ' < "$rigTmp/readonly/.claude/settings.json" | LC_ALL=C awk '{ print gsub(/deny-memory-md-read\.sh"/, "") " " gsub(/deny-memory-md-read\.shGlob"/, "") " " gsub(/deny-memory-md-read\.shGrep"/, "") ; }' )" "1 1 1"
rigAssert "install: the hand-wired script is replaced by the package's" "$( cmp -s "$rigGuard" "$rigTmp/wired/.claude/hooks/protect-memory-md.sh" && printf same || printf differs )" same

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SETTINGS HOOKS CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SETTINGS_HOOKS: OK (%d assertions, offline)\n' "$rigPasses"
