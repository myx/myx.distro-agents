#!/usr/bin/env bash
## Behavioural check on what the console's configuration wizards ask of the tooling (F11.7 of the refactorings epic), run rather than
## read: --manager-wizard-read and --manager-wizard-apply for the CLI service's wizard and for the git settings', against a rig workspace
## and a rig account built here, so nothing of the real workspace's settings or of this machine's git settings is read or written,
## which the last section asserts.
## Held (the coordinator's ruling on F11.7: "the CLI-service wizard: pick or create a preset (cli service, model or macro, effort, its
## credentials shown as F11.8 defines), and set the team's three tiers to presets with an optional :effort; SPAWN_CLI_SERVICE only where
## no tier is set. WAIT_ROUND_SECONDS is a plain setting, edited in Scope Settings. Git settings ... each destructive step behind its
## warning and the typed confirm"):
##   1. the read of the CLI wizard gives the choices (the nine services, the five efforts, the presets there are), the credentials each
##      service reads, what each preset holds with a credential in its one form, and what the team holds of its tiers and its service;
##      never a credential whole
##   2. the apply writes a new preset and the team's tiers, each key by the dispatcher's own writer, so the checks of a preset and of
##      a tier are asked, in the order the checks need whatever the order of the lines (the service ahead of its credentials, the
##      preset ahead of a tier that names it); a row for each; a value that is the one held is `unchanged`; an empty value takes the key
##      out; the team's CLI service is written only where no tier is set; a write that a check refuses stops the rest and says so, the
##      rows above it standing; a key the wizard does not write, a key twice and a name that is no preset's refuse the whole call before
##      anything is written; no value is printed
##   3. the git wizard's read gives what stands in the global settings of the account and the private keys it has; its apply writes the
##      three it is given and no other setting, every other line of the file standing; a field not given is left; what is no address,
##      no whole path of a plain private file, or holds a character a command line would read, and an unknown field, refuse and
##      write nothing
##   4. a name that is no wizard is refused; from inside a member's session both operations are refused; the help pair of each
## Offline; only the rig's own tree is written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves"
command -v git > /dev/null 2>&1 || rigRefuse "this machine has no git"
rigKeygen="$( PATH=/usr/bin:/bin command -v ssh-keygen )" || rigRefuse "this machine has no ssh-keygen"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerWizardCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills"
[ "$rigWs" != "${MMDAPP%/}" ] && [ "$rigHome" != "$HOME" ] || rigRefuse "the rig is the real one"
rigAgents="$rigWs/.local/.agents"
mkdir -p "$rigAgents" "$rigWs/.local/agents" "$rigHome/.ssh" "$rigSkills"
rigTeam="$rigAgents/magic-team.agent.env"
## A value nobody may see again.
rigSecret="Hd3mTyRIGSECRET31Vq7zKe"
rigMask(){ ## value -- the form of F11.8: its first quarter, not under 4 and not over 20 characters, then a * for each character after them
	local maskHead=$(( ${#1} / 4 )) maskRest
	[ "$maskHead" -ge 4 ] || maskHead=4
	[ "$maskHead" -le 20 ] || maskHead=20
	printf -v maskRest '%*s' $(( ${#1} - maskHead )) ''
	printf '%s%s' "${1:0:maskHead}" "${maskRest// /*}"
}
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\n' > "$rigTeam"
printf 'PRESET_CLI_SERVICE=claude\nPRESET_MODEL_OR_MACRO=normal\nANTHROPIC_API_KEY=%s\n' "$rigSecret" > "$rigAgents/preset-base.agent.env"
printf 'PRESET_EXTEND=base\n' > "$rigAgents/preset-ext.agent.env"
: > "$rigAgents/keeper-rig.agent.env"
chmod 770 "$rigAgents" ; chmod 660 "$rigAgents"/*.agent.env
printf '[core]\n\teditor = rigvim\n[user]\n\tsigningkey = RIGSIGN\n' > "$rigHome/.gitconfig"
"$rigKeygen" -q -t ed25519 -N '' -C rig-key -f "$rigHome/.ssh/id_ed25519" < /dev/null > /dev/null 2>&1 || rigRefuse "a made-up key could not be made"
rigKey="$rigHome/.ssh/id_ed25519"
rigRealBefore="$( cksum < "${MMDAPP%/}/.local/.agents/magic-team.agent.env" 2> /dev/null || echo none ) $( cksum < "$HOME/.gitconfig" 2> /dev/null || echo none )"
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
: > "$rigTmp/all"
rigPre=()
rigIn=""
rigRun(){ ## tool arguments... -- one dispatcher call from the rig workspace as the rig account, rigIn on its standard input; rc in rigRc, stdout in out, stderr in err, both kept in all
	rigRc=0
	( cd "$rigWs" && printf '%s' "$rigIn" | env -i HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" || rigRc=$?
	cat "$rigTmp/out" "$rigTmp/err" >> "$rigTmp/all"
}
rigRunIn(){ rigIn="$1" ; shift ; rigRun "$@" ; rigIn="" ; }
rigTroubles(){ LC_ALL=C grep -E -- 'ERROR|WARNING' "$rigTmp/err" | LC_ALL=C grep -c -v -F -- 'SystemContext.SetInputSpec' || : ; }
rigFlat(){ LC_ALL=C tr '\t' ' ' < "$1" | LC_ALL=C tr '\n' '/' ; }
rigRows(){ ## pattern -- the rows of the last output whose first fields start with the pattern, TAB written a blank, one a line
	LC_ALL=C tr '\t' ' ' < "$rigTmp/out" | LC_ALL=C grep -E -- "$1" | LC_ALL=C tr '\n' '/'
}
rigHolds(){ ## file, text -- how many lines of the file are that text, whole
	LC_ALL=C grep -c -x -F -- "$2" "$1" 2> /dev/null || :
}
rigNone(){ ## file, text -- how many lines of the file hold the text anywhere
	LC_ALL=C grep -c -F -- "$2" "$1" 2> /dev/null || :
}
rigLeak(){ ## -- how many times the credential stands whole in all that the calls printed
	LC_ALL=C grep -c -F -- "$rigSecret" "$rigTmp/all" || :
}

echo "-- 1. the read of the CLI service's wizard --"
rigRun --manager-wizard-read cli-service
rigAssert "the call ends 0, with no error and no warning" "$rigRc $( rigTroubles )" "0 0"
rigAssert "the nine services of a preset, in the owner's order" "$( LC_ALL=C awk -F'\t' '$1 == "option" && $2 == "cli-service" { printf "%s ", $3 }' "$rigTmp/out" )" "claude copilot grok gemini scaleway standard-v1 claude-native copilot-native grok-native "
rigAssert "the five efforts, and the presets there are" "$( LC_ALL=C awk -F'\t' '$1 == "option" && $2 == "effort" { printf "%s ", $3 }' "$rigTmp/out" ) / $( LC_ALL=C awk -F'\t' '$1 == "option" && $2 == "preset" { printf "%s ", $3 }' "$rigTmp/out" )" "low default normal high hard  / base ext "
rigAssert "the credentials each service reads, from its harness leg" "$( rigRows '^credential (claude|grok) ' )" "credential claude ANTHROPIC_API_KEY/credential claude CLAUDE_CODE_OAUTH_TOKEN/credential grok XAI_API_KEY/"
rigAssert "what a preset holds: its service, its model, a credential in its one form; and what an extending preset holds" "$( rigRows '^preset (base|ext) ' | LC_ALL=C tr '/' '\n' | LC_ALL=C sort | LC_ALL=C tr '\n' '/' )" "preset base ANTHROPIC_API_KEY secret-set $( rigMask "$rigSecret" )/preset base PRESET_CLI_SERVICE set claude/preset base PRESET_MODEL_OR_MACRO set normal/preset ext PRESET_EXTEND set base/"
rigAssert "what the team holds: its three tiers (none), and no CLI service of its own" "$( rigRows '^current|^team ' )" "team SPAWN_TIER_LOW missing -/team SPAWN_TIER_NORMAL missing -/team SPAWN_TIER_HIGH missing -/"
rigAssert "the credential is never on the screen whole" "$( rigLeak )" "0"

echo "-- 2. the apply of the CLI service's wizard --"
rigRunIn "SPAWN_TIER_NORMAL"$'\t'"fresh:high"$'\n'"XAI_API_KEY"$'\t'"$rigSecret"$'\n'"PRESET_EFFORT"$'\t'"high"$'\n'"PRESET_CLI_SERVICE"$'\t'"grok"$'\n' --manager-wizard-apply cli-service --preset fresh
rigAssert "a new preset and a tier that names it, given in any order, are applied in the order the checks need: the service, the effort, the credential, the tier; a row each" "$rigRc $( rigTroubles ) $( rigFlat "$rigTmp/out" )" \
	"0 0 set preset-fresh PRESET_CLI_SERVICE/set preset-fresh PRESET_EFFORT/set preset-fresh XAI_API_KEY/set magic-team SPAWN_TIER_NORMAL/"
rigAssert "the block of the preset is made, and holds the four keys; the team holds the tier; the team's other lines stand" "$( rigHolds "$rigAgents/preset-fresh.agent.env" PRESET_CLI_SERVICE=grok ) $( rigHolds "$rigAgents/preset-fresh.agent.env" PRESET_EFFORT=high ) $( rigHolds "$rigAgents/preset-fresh.agent.env" "XAI_API_KEY=$rigSecret" ) $( rigHolds "$rigTeam" SPAWN_TIER_NORMAL=fresh:high ) $( rigHolds "$rigTeam" SLACK_CHANNEL_MAGIC_TEAM=CRIG00001 )" "1 1 1 1 1"
rigAssert "no value is printed: the credential stands whole nowhere" "$( rigLeak )" "0"
rigRunIn "PRESET_EFFORT"$'\t'"high"$'\n'"PRESET_MODEL_OR_MACRO"$'\t'"" --manager-wizard-apply cli-service --preset fresh
rigAssert "a value that is the one held is unchanged, an empty value for a key not held is unchanged too" "$rigRc $( rigFlat "$rigTmp/out" )" "0 unchanged preset-fresh PRESET_MODEL_OR_MACRO/unchanged preset-fresh PRESET_EFFORT/"
rigRunIn "PRESET_MODEL_OR_MACRO"$'\t'"hard" --manager-wizard-apply cli-service --preset fresh
rigRunIn "PRESET_MODEL_OR_MACRO"$'\t' --manager-wizard-apply cli-service --preset fresh
rigAssert "an empty value takes a key out: removed, the key gone from the block, the others standing" "$rigRc $( rigFlat "$rigTmp/out" ) $( rigNone "$rigAgents/preset-fresh.agent.env" PRESET_MODEL_OR_MACRO ) $( rigHolds "$rigAgents/preset-fresh.agent.env" PRESET_EFFORT=high )" "0 removed preset-fresh PRESET_MODEL_OR_MACRO/ 0 1"
rigSumBefore="$( cksum "$rigAgents/preset-fresh.agent.env" "$rigTeam" )"
rigRunIn "PRESET_EFFORT"$'\t'"medium"$'\n'"SPAWN_TIER_LOW"$'\t'"fresh" --manager-wizard-apply cli-service --preset fresh
rigAssert "a value the preset's check refuses stops the rest, says so without the value, and the file stays: the tier after it was not written" "$rigRc $( [ "$( cksum "$rigAgents/preset-fresh.agent.env" "$rigTeam" )" = "$rigSumBefore" ] && echo same ) $( LC_ALL=C grep -c -F -- 'medium' "$rigTmp/err" || : ) $( LC_ALL=C grep -c -F -- 'PRESET_EFFORT was not written to preset-fresh' "$rigTmp/err" )" "1 same 0 1"
rigRunIn "PRESET_EFFORT"$'\t'"low"$'\n'"COPILOT_GITHUB_TOKEN"$'\t'"x" --manager-wizard-apply cli-service --preset fresh
rigAssert "a credential that the preset's service does not read is refused by the check, the rows above it standing" "$rigRc $( rigFlat "$rigTmp/out" )" "1 set preset-fresh PRESET_EFFORT/"
rigRunIn "SPAWN_TIER_HIGH"$'\t'"no-such-preset" --manager-wizard-apply cli-service --preset fresh
rigAssert "a tier that names no preset is refused by the tier's check" "$rigRc $( rigNone "$rigTeam" SPAWN_TIER_HIGH )" "1 0"
rigRunIn "SPAWN_CLI_SERVICE"$'\t'"copilot" --manager-wizard-apply cli-service --preset fresh
rigAssert "the team's CLI service is no key of the wizard: refused, nothing written" "$rigRc $( rigNone "$rigTeam" SPAWN_CLI_SERVICE )" "1 0"
rigRunIn "SPAWN_TIER_NORMAL"$'\t' --manager-wizard-apply cli-service --preset fresh
rigSumBefore="$( cksum "$rigAgents/preset-fresh.agent.env" "$rigTeam" "$rigAgents/preset-base.agent.env" )"
rigBad=""
rigRunIn "PRESET_EFFORT"$'\t'"low"$'\n'"PRESET_EXTRA_SPAWN_LINE"$'\t'"be nice" --manager-wizard-apply cli-service --preset fresh
[ "$rigRc" = 1 ] && [ "$( cksum "$rigAgents/preset-fresh.agent.env" "$rigTeam" "$rigAgents/preset-base.agent.env" )" = "$rigSumBefore" ] || rigBad="$rigBad [a key the wizard does not write]"
rigRunIn "PRESET_EFFORT"$'\t'"low"$'\n'"PRESET_EFFORT"$'\t'"high" --manager-wizard-apply cli-service --preset fresh
[ "$rigRc" = 1 ] && [ "$( cksum "$rigAgents/preset-fresh.agent.env" "$rigTeam" "$rigAgents/preset-base.agent.env" )" = "$rigSumBefore" ] || rigBad="$rigBad [a key twice]"
rigRunIn "PRESET_EFFORT"$'\t'"low" --manager-wizard-apply cli-service --preset Other
[ "$rigRc" = 1 ] && [ ! -e "$rigAgents/preset-Other.agent.env" ] || rigBad="$rigBad [a name that is no preset's]"
rigRunIn "PRESET_EFFORT"$'\t'"low" --manager-wizard-apply cli-service
[ "$rigRc" = 1 ] || rigBad="$rigBad [no preset named]"
rigRunIn "PRESET_EFFORT"$'\t'"low" --manager-wizard-apply cli-service --preset fresh extra
[ "$rigRc" = 1 ] || rigBad="$rigBad [a word too many]"
rigAssert "a key the wizard does not write, a key twice, a name that is no preset's, no preset and a word too many each refuse the whole call, nothing written" "${rigBad:- all refused}" " all refused"
rigAssert "no value was printed by any of these" "$( rigLeak )" "0"

echo "-- 3. the git settings' wizard --"
rigRun --manager-wizard-read git-settings
rigAssert "nothing is set yet: the name and the email are missing, the key is the one the tools find, and the private keys the account has are offered" "$rigRc $( rigFlat "$rigTmp/out" )" "0 current user.name -/current user.email -/current ssh-key $rigKey/option ssh-key $rigKey Deploy_Key_To_Add_To_Git/"
rigGitBefore="$( cksum < "$rigHome/.gitconfig" )"
rigRunIn "user.name"$'\t'"Rig Person"$'\n'"user.email"$'\t'"rig@rig.example"$'\n'"ssh-key"$'\t'"$rigKey"$'\n' --manager-wizard-apply git-settings
rigAssert "the three are written, a row each" "$rigRc $( rigTroubles ) $( rigFlat "$rigTmp/out" )" "0 0 set git user.name/set git user.email/set git ssh-key/"
rigAssert "the global settings hold them, git itself reads them back, and the lines that were there stand" "$( git config --file "$rigHome/.gitconfig" --get user.name ) / $( git config --file "$rigHome/.gitconfig" --get user.email ) / $( git config --file "$rigHome/.gitconfig" --get core.sshCommand ) / $( git config --file "$rigHome/.gitconfig" --get core.editor ) / $( git config --file "$rigHome/.gitconfig" --get user.signingkey )" \
	"Rig Person / rig@rig.example / ssh -i $rigKey -o IdentitiesOnly=yes / rigvim / RIGSIGN"
rigRun --manager-wizard-read git-settings
rigAssert "the read now says what stands" "$( rigRows '^current ' )" "current user.name Rig_Person/current user.email rig@rig.example/current ssh-key $rigKey/"
rigRunIn "user.email"$'\t'"other@rig.example" --manager-wizard-apply git-settings
rigAssert "a field not given is left as it is" "$rigRc $( rigFlat "$rigTmp/out" ) $( git config --file "$rigHome/.gitconfig" --get user.name ) $( git config --file "$rigHome/.gitconfig" --get user.email )" "0 set git user.email/ Rig Person other@rig.example"
rigGitBefore="$( cksum < "$rigHome/.gitconfig" )"
ln -s "$rigKey" "$rigHome/.ssh/linked"
rigBad=""
for rigOne in "user.email"$'\t'"not-an-address" "user.email"$'\t'"a@b@c" "ssh-key"$'\t'".ssh/id_ed25519" "ssh-key"$'\t'"$rigHome/.ssh/none" "ssh-key"$'\t'"$rigHome/.ssh/linked" "ssh-key"$'\t'"$rigHome/.ssh/id;ed25519" "ssh-key"$'\t'"$rigHome/.ssh/a b" "user.name"$'\t'"two"$'\r'"lines" "core.editor"$'\t'"evil" ; do
	rigRunIn "$rigOne"$'\n' --manager-wizard-apply git-settings
	[ "$rigRc" = 1 ] && [ "$( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" = 0 ] && [ "$( cksum < "$rigHome/.gitconfig" )" = "$rigGitBefore" ] || rigBad="$rigBad [$( printf '%s' "$rigOne" | LC_ALL=C tr '\t\r' '  ' )]"
done
rigRunIn "user.name"$'\t'"a"$'\n'"user.name"$'\t'"b"$'\n' --manager-wizard-apply git-settings
[ "$rigRc" = 1 ] && [ "$( cksum < "$rigHome/.gitconfig" )" = "$rigGitBefore" ] || rigBad="$rigBad [a field twice]"
rigAssert "an address that is none, a relative path, a key that is not there, a link, a path with a character a command line reads, a control character, an unknown field and a field twice each refuse with nothing written" "${rigBad:- all refused}" " all refused"

echo "-- 4. a name that is no wizard, a member's session, the help pair --"
rigRun --manager-wizard-read no-such-wizard
rigAssert "a name that is no wizard is refused for each operation, and not repeated" "$rigRc $( rigNone "$rigTmp/err" no-such-wizard )" "1 0"
rigRunIn "" --manager-wizard-apply no-such-wizard
rigAssert "and for the apply" "$rigRc $( rigNone "$rigTmp/err" no-such-wizard )" "1 0"
rigPre=(MDAT_SPAWN_AGENT=magic-coordinator)
rigBad=""
rigRun --manager-wizard-read cli-service ; [ "$rigRc" = 1 ] && [ "$( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" = 0 ] || rigBad="$rigBad [read]"
rigRunIn "PRESET_EFFORT"$'\t'"low" --manager-wizard-apply cli-service --preset fresh ; [ "$rigRc" = 1 ] || rigBad="$rigBad [apply]"
rigAssert "a member's session is refused both, magic-coordinator's too" "${rigBad:- all refused}" " all refused"
rigPre=()
rigBad=""
for rigOne in "--manager-wizard-read <cli-service|git-settings>" "--manager-wizard-apply cli-service --preset <name>" "--manager-wizard-apply git-settings" ; do
	LC_ALL=C grep -q -F -- "DistroAgentsTools.fn.sh $rigOne" "$rigPackage/sh-lib/help/Help.DistroAgentsTools.include" || rigBad="$rigBad [include $rigOne]"
	LC_ALL=C grep -q -x -F -- "		$rigOne" "$rigPackage/sh-lib/help/Help.DistroAgentsTools.help.md" || rigBad="$rigBad [help.md $rigOne]"
done
rigAssert "each has its syntax line and its help entry" "${rigBad:- all paired}" " all paired"

echo "-- 5. nothing of the real workspace or account was touched --"
rigAssert "the real team settings and the real git settings are as they were" "$( cksum < "${MMDAPP%/}/.local/.agents/magic-team.agent.env" 2> /dev/null || echo none ) $( cksum < "$HOME/.gitconfig" 2> /dev/null || echo none )" "$rigRealBefore"

printf '\nTOTAL: %d passed, %d failed\n' "$rigPasses" "$rigFails"
[ "$rigFails" = 0 ]
