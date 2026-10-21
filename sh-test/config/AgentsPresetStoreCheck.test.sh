#!/usr/bin/env bash
## Behavioural check on the preset mechanism (F10.1 of the refactorings epic): a preset is one settings block of its own,
## `preset-<name>`, a sibling of the scopes of the members and of magic-team, which the same tools dump (the digest) and
## edit (--agents-config-option), the one writer with the write check of AgentsTools.Preset.include before it. Against a
## rig workspace built here: every call runs with MMDAPP at the rig, so the settings of the real workspace are never read
## and never written, which the last section asserts. No value of a secret is printed or kept in this file's output: the
## credentials of the rig are made here, and the check fails on any whole value appearing on either stream.
## Held:
##   A. a preset is a block of its own, in the same file form, listed by the digest and read by the same reader
##   B. the CLI service: the nine, no other; a refusal repeats nothing that was given
##   C. a preset's name is lower-case
##   D. extend: a preset that is there, not itself, no loop; and where a preset extends, its CLI service is not editable
##   E. what an extending preset inherits: the parent's CLI service, the parent's other keys unless its own stands ahead
##   F. the model or macro, the effort, the input cache time (5m or 1h, F10.7), the context size that is stored only, the extra spawn line (the owner's)
##   G. the credentials of the selected CLI service, and no other; never printed
##   H. a preset key stands in a preset and in no other scope; every other key and scope is written as it was
##   I. a value taken from stdin is checked as one in argv, and is written whole
##   J. the catalogue describes each key, and says a native CLI is passed no model
## Red before F10.1: B2, B3, C, D, E, F, G, H, I and J fail (A holds: it is the tools that already dump and edit).
## Offline: the rig workspace alone.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the dispatcher is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsPresetStoreCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigAgents="$rigWs/.local/.agents"
mkdir -p "$rigAgents" "$rigWs/.local/agents" "$rigTmp/home" "$rigTmp/skills" "$rigTmp/bin"
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"
printf '#!/bin/sh\nexit 7\n' > "$rigTmp/bin/curl" ; chmod +x "$rigTmp/bin/curl"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## Every output of every call, kept to look for a whole secret in at the end.
: > "$rigTmp/all.out"
rigRc=0
rigRun(){ ## arguments of the dispatcher -- output on stdout, rc in rigRc (a call made in this shell, not in a substitution)
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" ${rigAs:+MDAT_SPAWN_AGENT="$rigAs"} bash "$rigTool" "$@" ) > "$rigTmp/run.out" 2> "$rigTmp/run.err" < /dev/null
	rigRc=$?
	cat "$rigTmp/run.out" "$rigTmp/run.err" >> "$rigTmp/all.out"
}
rigRunStdin(){ ## value, arguments -- the value on stdin
	local stdinValue="$1" ; shift
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" bash "$rigTool" "$@" ) > "$rigTmp/run.out" 2> "$rigTmp/run.err" <<< "$stdinValue"
	rigRc=$?
	cat "$rigTmp/run.out" "$rigTmp/run.err" >> "$rigTmp/all.out"
}
rigSet(){ ## preset, key, value -- the rc of the write
	rigRun --agents-config-option "preset-$1" --upsert "$2" "$3" ; printf '%s' "$rigRc"
}
rigGet(){ ## preset, key -- what the tooling's own reader gives, from the file only (no file made)
	[ -f "$rigAgents/preset-$1.agent.env" ] || return 0
	rigRun --agents-config-option "preset-$1" --select "$2" ; cat "$rigTmp/run.out"
}
rigHas(){ ## preset, key -- `yes` where the block holds a line of that key
	LC_ALL=C grep -q -e "^$2=" "$rigAgents/preset-$1.agent.env" 2> /dev/null && printf yes || printf no
}
rigEffective(){ ## preset, key -- AgentsToolsPresetEffective, called as a function of the include; its text and ` rc=<rc>`
	local effOut effRc
	effOut="$( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDSC_CMD=rig-check bash -c '
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/config/AgentsTools.Preset.include" && AgentsToolsPresetEffective "$MMDAPP" "$1" "$2"
	' rig "$1" "$2" 2>&1 )"
	effRc=$?
	printf '%s rc=%s' "$effOut" "$effRc"
}
rigSecretA="sk-RIGantCRED-Qw7ZpL3xV9tR2mBk4Hs8NfD1"
rigSecretB="oauth-RIGtokenCRED-5yTgHn0LcX6aVu3PqZ8w"
rigSecretC="scwRIGdeepseekCRED-9aB3cD5eF7gH1jK"

echo "-- A. a preset is a block of its own, listed and read by the tools that already are the family's --"
rigAssert "the write into preset-mel-claude is accepted"                         "$( rigSet mel-claude PRESET_CLI_SERVICE claude )" 0
rigAssert "the block is a file of its own, among the scopes"                      "$( [ -f "$rigAgents/preset-mel-claude.agent.env" ] && printf yes )" yes
rigAssert "in the mode of a scope (660)"                                          "$( LC_ALL=C ls -l "$rigAgents/preset-mel-claude.agent.env" | LC_ALL=C cut -c1-10 )" "-rw-rw----"
rigAssert "the reader of the scopes reads its key"                                "$( rigGet mel-claude PRESET_CLI_SERVICE )" claude
rigRun --manager-config-digest scopes
rigAssert "the digest lists it as a scope of its own, with its key and value"      "$( LC_ALL=C awk -F'\t' '$1 == "line" && $2 == "scopes" && $3 == "preset-mel-claude" && $4 == "PRESET_CLI_SERVICE" { print $5, $6 }' "$rigTmp/run.out" )" "set claude"

echo "-- B. the CLI service: the nine, no other --"
rigNine=0
for rigService in claude copilot grok gemini scaleway standard-v1 claude-native copilot-native grok-native ; do
	[ "$( rigSet "svc-$rigService" PRESET_CLI_SERVICE "$rigService" )" = 0 ] && [ "$( rigGet "svc-$rigService" PRESET_CLI_SERVICE )" = "$rigService" ] && rigNine=$(( rigNine + 1 ))
done
rigAssert "each of the nine is accepted and stored"                               "$rigNine" 9
rigAssert "a word that is none of them is refused"                                "$( rigSet mel-bad PRESET_CLI_SERVICE chatgpt )" 1
rigAssert "and nothing was written"                                               "$( rigHas mel-bad PRESET_CLI_SERVICE )" no
rigSet mel-bad PRESET_CLI_SERVICE "RIGBOGUS-pasted-secret-Zq81" > /dev/null
rigAssert "a refusal repeats nothing that was given"                              "$( cat "$rigTmp/run.out" "$rigTmp/run.err" | LC_ALL=C grep -c -F -e 'RIGBOGUS-pasted-secret-Zq81' )" 0

echo "-- C. a preset's name is lower-case --"
rigAssert "a name with an upper-case letter is refused"                           "$( rigSet Mel-Upper PRESET_CLI_SERVICE claude )" 1
rigAssert "and no block was made for it"                                          "$( ls "$rigAgents" | LC_ALL=C grep -c -i -e 'upper' )" 0

echo "-- D. extend: a preset that is there, not itself, no loop; the CLI service of an extending preset is not editable --"
rigAssert "a preset extends a preset that is there"                               "$( rigSet mel-claude-haiku PRESET_EXTEND mel-claude )" 0
rigAssert "the extension is stored"                                               "$( rigGet mel-claude-haiku PRESET_EXTEND )" mel-claude
rigAssert "a preset that is not there is refused"                                 "$( rigSet mel-orphan PRESET_EXTEND mel-nothing )" 1
rigAssert "a preset extending itself is refused"                                  "$( rigSet mel-claude PRESET_EXTEND mel-claude )" 1
rigAssert "a loop (the parent extending its child) is refused"                    "$( rigSet mel-claude PRESET_EXTEND mel-claude-haiku )" 1
rigAssert "a name with an upper-case letter is refused as a parent"               "$( rigSet mel-claude-opus PRESET_EXTEND Mel-Claude )" 1
rigAssert "where a preset extends, its CLI service is not editable"               "$( rigSet mel-claude-haiku PRESET_CLI_SERVICE grok )" 1
rigAssert "and the extending preset holds none of its own"                        "$( rigHas mel-claude-haiku PRESET_CLI_SERVICE )" no
rigAssert "a preset with a CLI service of its own cannot start to extend"          "$( rigSet svc-grok PRESET_EXTEND mel-claude )" 1
rigRun --agents-config-option preset-mel-claude-haiku --delete PRESET_EXTEND
rigAssert "the extension is taken off by a delete"                                "$( rigHas mel-claude-haiku PRESET_EXTEND )$rigRc" no0
rigAssert "then its CLI service is editable again"                                "$( rigSet mel-claude-haiku PRESET_CLI_SERVICE grok )" 0
rigRun --agents-config-option preset-mel-claude-haiku --delete PRESET_CLI_SERVICE
rigSet mel-claude-haiku PRESET_EXTEND mel-claude > /dev/null

echo "-- E. what an extending preset inherits --"
rigSet mel-claude PRESET_EXTRA_SPAWN_LINE "Answer in short sentences; the tools are named as they are." > /dev/null
rigSet mel-claude PRESET_INPUT_CACHE_TIME 1h > /dev/null
rigSet mel-claude PRESET_MODEL_OR_MACRO normal > /dev/null
rigSet mel-claude-haiku PRESET_MODEL_OR_MACRO low > /dev/null
rigSet mel-claude-micro PRESET_EXTEND mel-claude-haiku > /dev/null
rigAssert "the CLI service is the parent's"                                       "$( rigEffective mel-claude-haiku PRESET_CLI_SERVICE )" "claude rc=0"
rigAssert "a key the preset does not hold is the parent's"                        "$( rigEffective mel-claude-haiku PRESET_INPUT_CACHE_TIME )" "1h rc=0"
rigAssert "the extra spawn line is inherited too"                                 "$( rigEffective mel-claude-haiku PRESET_EXTRA_SPAWN_LINE )" "Answer in short sentences; the tools are named as they are. rc=0"
rigAssert "a key the preset holds stands ahead of the parent's"                   "$( rigEffective mel-claude-haiku PRESET_MODEL_OR_MACRO )" "low rc=0"
rigAssert "and the parent keeps its own"                                          "$( rigEffective mel-claude PRESET_MODEL_OR_MACRO )" "normal rc=0"
rigAssert "two steps up: the grandparent's CLI service and cache time"            "$( rigEffective mel-claude-micro PRESET_CLI_SERVICE ) $( rigEffective mel-claude-micro PRESET_INPUT_CACHE_TIME )" "claude rc=0 1h rc=0"
rigAssert "the extension itself is never inherited"                               "$( rigEffective mel-claude-micro PRESET_EXTEND ) $( rigEffective mel-claude PRESET_EXTEND )" "mel-claude-haiku rc=0  rc=0"
printf 'PRESET_EXTEND=mel-claude\nPRESET_CLI_SERVICE=grok\n' > "$rigAgents/preset-mel-hand.agent.env"
rigAssert "a CLI service planted in an extending preset is ignored: the parent's is the value" "$( rigEffective mel-hand PRESET_CLI_SERVICE )" "claude rc=0"
printf 'PRESET_EXTEND=mel-loop-b\n' > "$rigAgents/preset-mel-loop-a.agent.env" ; printf 'PRESET_EXTEND=mel-loop-a\n' > "$rigAgents/preset-mel-loop-b.agent.env"
rigAssert "a loop planted by hand ends, with the reason, and not at the end of time" "$( rigEffective mel-loop-a PRESET_MODEL_OR_MACRO | LC_ALL=C sed -e 's/.*longer than [0-9]*: .*loops/LOOP/' )" "LOOP rc=1"
rigAssert "a parent that is not there is said"                                    "$( printf 'PRESET_EXTEND=mel-gone\n' > "$rigAgents/preset-mel-lost.agent.env" ; rigEffective mel-lost PRESET_EFFORT | LC_ALL=C grep -c -e 'preset mel-gone is not there' )" 1

echo "-- F. the model or macro, the effort, the two numbers, the extra spawn line --"
rigOk=0
for rigMacro in low easy normal default high hard claude-sonnet-5-5 ; do [ "$( rigSet mel-model PRESET_MODEL_OR_MACRO "$rigMacro" )" = 0 ] && rigOk=$(( rigOk + 1 )) ; done
rigAssert "the six macros and a model name are accepted"                          "$rigOk" 7
rigAssert "a value with a space is refused"                                       "$( rigSet mel-model PRESET_MODEL_OR_MACRO 'claude sonnet' )" 1
rigAssert "an empty macro is refused (taking it off is a delete)"                 "$( rigSet mel-model PRESET_MODEL_OR_MACRO '' )" 1
rigOk=0
for rigEffort in low default normal high hard ; do [ "$( rigSet mel-model PRESET_EFFORT "$rigEffort" )" = 0 ] && rigOk=$(( rigOk + 1 )) ; done
rigAssert "the five efforts are accepted"                                         "$rigOk" 5
rigAssert "any other is refused"                                                  "$( rigSet mel-model PRESET_EFFORT max )" 1
rigAssert "the input cache time takes 5m and 1h (F10.7)"                              "$( rigSet mel-model PRESET_INPUT_CACHE_TIME 5m )$( rigSet mel-model PRESET_INPUT_CACHE_TIME 1h )" 00
rigAssert "and nothing else: 1H, 2h, 30m, a number of seconds, a word, a unit alone"   "$( for rigTime in 1H 2h 30m 300 3600 abc h m 5m1h ; do rigSet mel-model PRESET_INPUT_CACHE_TIME "$rigTime" ; done )" 111111111
rigSet mel-model PRESET_INPUT_CACHE_TIME 2h > /dev/null
rigAssert "a refusal names the two it takes and repeats nothing it was given"          "$( LC_ALL=C grep -c -e 'is one of: 5m, 1h' "$rigTmp/run.err" )$( LC_ALL=C grep -c -F -e '2h' "$rigTmp/run.err" )" 10
rigAssert "the stored value is still the last good one"                              "$( rigGet mel-model PRESET_INPUT_CACHE_TIME )" 1h
rigAssert "the context size takes a whole number of tokens"                       "$( rigSet mel-model PRESET_CONTEXT_MAX_SIZE 200000 )" 0
rigAssert "a number written otherwise is refused (word, zero, sign, fraction)"     "$( rigSet mel-model PRESET_CONTEXT_MAX_SIZE abc )$( rigSet mel-model PRESET_CONTEXT_MAX_SIZE 0 )$( rigSet mel-model PRESET_CONTEXT_MAX_SIZE -5 )$( rigSet mel-model PRESET_CONTEXT_MAX_SIZE 1.5 )" 1111
rigAssert "the two keys are named in the preset code, the catalogue, the console and the console's scope reader (which offers their choices) alone (the console names the cache time it passes on; the context size is stored only)" "$( cd "$rigPackage" && LC_ALL=C grep -rl -e PRESET_INPUT_CACHE_TIME -e PRESET_CONTEXT_MAX_SIZE sh-lib sh-scripts | LC_ALL=C sort | tr '\n' ' ' )" "sh-lib/config/AgentsTools.OwnerSetupOptionSpec.include sh-lib/config/AgentsTools.Preset.include sh-lib/manager/AgentsConsoleShellScript.template.sh sh-lib/manager/AgentsTools.ManagerScopeAgents.include "
rigAssert "the extra spawn line, one line with spaces and an = in it, is accepted"  "$( rigSet mel-model PRESET_EXTRA_SPAWN_LINE 'Think step by step; prefer a=b over c.' )" 0
rigAssert "and is stored whole"                                                   "$( rigGet mel-model PRESET_EXTRA_SPAWN_LINE )" "Think step by step; prefer a=b over c."
rigAssert "two lines are refused"                                                 "$( rigSet mel-model PRESET_EXTRA_SPAWN_LINE "$( printf 'one\ntwo' )" )" 1
rigAs=keeper-rig
rigAssert "a member's session cannot write it"                                    "$( rigSet mel-model PRESET_EXTRA_SPAWN_LINE 'a member wrote this' )" 1
rigRun --agents-config-option preset-mel-model --delete PRESET_EXTRA_SPAWN_LINE
rigAssert "nor delete it"                                                         "$rigRc $( rigHas mel-model PRESET_EXTRA_SPAWN_LINE )" "1 yes"
rigAs=""
rigAssert "the other keys a member's session writes by the same operation are checked as any other" "$( rigAs=keeper-rig ; rigSet mel-model PRESET_EFFORT low )" 0
rigAssert "the owner (no member's session) can write it"                          "$( rigSet mel-model PRESET_EXTRA_SPAWN_LINE 'the owner wrote this' )" 0

echo "-- G. the credentials of the selected CLI service, and no other; never printed --"
rigAssert "claude: its two credentials are accepted"                              "$( rigSet mel-claude ANTHROPIC_API_KEY "$rigSecretA" )$( rigSet mel-claude CLAUDE_CODE_OAUTH_TOKEN "$rigSecretB" )" 00
rigAssert "the credential is stored whole"                                        "$( LC_ALL=C grep -c -x -F -e "ANTHROPIC_API_KEY=$rigSecretA" "$rigAgents/preset-mel-claude.agent.env" )" 1
rigAssert "scaleway: its two credentials are accepted"                            "$( rigSet mel-scaleway PRESET_CLI_SERVICE scaleway )$( rigSet mel-scaleway SCALEWAY_DEEPSEEK "$rigSecretC" )$( rigSet mel-scaleway SCALEWAY_GEMMA "$rigSecretC" )" 000
rigAssert "a credential of another CLI service is refused"                        "$( rigSet mel-scaleway ANTHROPIC_API_KEY "$rigSecretA" )" 1
rigAssert "and is not stored"                                                     "$( rigHas mel-scaleway ANTHROPIC_API_KEY )" no
rigAssert "a preset with no CLI service takes no credential"                      "$( rigSet mel-none ANTHROPIC_API_KEY "$rigSecretA" )" 1
rigAssert "a native service has the credentials of its leg"                       "$( rigSet mel-native PRESET_CLI_SERVICE claude-native )$( rigSet mel-native ANTHROPIC_API_KEY "$rigSecretA" )" 00
rigAssert "gemini has no leg, so no credential is taken yet"                      "$( rigSet mel-gemini PRESET_CLI_SERVICE gemini )$( rigSet mel-gemini ANTHROPIC_API_KEY "$rigSecretA" )" 01
rigAssert "an extending preset takes the credentials of the inherited service"    "$( rigSet mel-claude-sonnet PRESET_EXTEND mel-claude )$( rigSet mel-claude-sonnet CLAUDE_CODE_OAUTH_TOKEN "$rigSecretB" )$( rigSet mel-claude-sonnet SCALEWAY_GEMMA "$rigSecretC" )" 001
rigRun --manager-config-digest scopes
rigAssert "the digest shows a credential of a preset in the one form (first quarter, then *)" "$( LC_ALL=C awk -F'\t' '$1 == "line" && $3 == "preset-mel-claude" && $4 == "ANTHROPIC_API_KEY" { print $5 }' "$rigTmp/run.out" )" "secret-set"
rigAssert "the digest does not give the extra spawn line a credential's form"        "$( LC_ALL=C awk -F'\t' '$1 == "line" && $3 == "preset-mel-model" && $4 == "PRESET_EXTRA_SPAWN_LINE" { print $5 }' "$rigTmp/run.out" )" "set"

echo "-- H. a preset key stands in a preset; every other key and scope is written as it was --"
printf 'SPAWN_CLI_SERVICE=claude\n' > "$rigAgents/magic-team.agent.env" ; printf '# member\n' > "$rigAgents/keeper-rig.agent.env"
rigAssert "PRESET_EFFORT in magic-team is refused"                                "$( rigRun --agents-config-option magic-team --upsert PRESET_EFFORT low ; printf '%s' "$rigRc" )" 1
rigAssert "PRESET_EXTRA_SPAWN_LINE in a member's scope is refused"                "$( rigRun --agents-config-option keeper-rig --upsert PRESET_EXTRA_SPAWN_LINE x ; printf '%s' "$rigRc" )" 1
rigAssert "neither scope holds it"                                                "$( LC_ALL=C grep -c -e '^PRESET_' "$rigAgents/magic-team.agent.env" "$rigAgents/keeper-rig.agent.env" | tr '\n' ' ' )" "$rigAgents/magic-team.agent.env:0 $rigAgents/keeper-rig.agent.env:0 "
rigAssert "an ordinary key is written into magic-team as it was"                  "$( rigRun --agents-config-option magic-team --upsert WAIT_ROUND_SECONDS 120 ; printf '%s' "$rigRc" ; rigRun --agents-config-option magic-team --select WAIT_ROUND_SECONDS ; cat "$rigTmp/run.out" )" 0120
rigAssert "and into a member's scope"                                             "$( rigRun --agents-config-option keeper-rig --upsert SLACK_USER_TOKEN "$rigSecretA" ; printf '%s' "$rigRc" )" 0
rigAssert "SPAWN_CLI_SERVICE is no setting any more: a write is refused, naming SPAWN_TIER_NORMAL, and the old line stands"  "$( rigRun --agents-config-option magic-team --upsert SPAWN_CLI_SERVICE grok ; printf '%s' "$rigRc" ) $( LC_ALL=C grep -c -x -e 'SPAWN_CLI_SERVICE=claude' "$rigAgents/magic-team.agent.env" ) $( LC_ALL=C grep -c -F -e 'SPAWN_TIER_NORMAL' "$rigTmp/run.err" )" "1 1 1"
rigAssert "the old line is not read, whatever it says: no CLI service, and the default is the caller's"  "$( rigRun --agents-config-option magic-team --select SPAWN_CLI_SERVICE ; cat "$rigTmp/run.out" )|$( rigRun --agents-config-option magic-team --select-default SPAWN_CLI_SERVICE dflt ; cat "$rigTmp/run.out" )" "|dflt"
rigAssert "and the old line may be deleted"                                       "$( rigRun --agents-config-option magic-team --delete SPAWN_CLI_SERVICE ; printf '%s' "$rigRc" ) $( LC_ALL=C grep -c -e '^SPAWN_CLI_SERVICE=' "$rigAgents/magic-team.agent.env" )" "0 0"

echo "-- I. a value taken from stdin is checked as one in argv, and written whole --"
rigRunStdin "grok" --agents-config-option preset-mel-grok --upsert-from-stdin PRESET_CLI_SERVICE
rigAssert "a good value from stdin is written"                                    "$rigRc $( rigGet mel-grok PRESET_CLI_SERVICE )" "0 grok"
rigRunStdin "chatgpt" --agents-config-option preset-mel-grok --upsert-from-stdin PRESET_CLI_SERVICE
rigAssert "a bad one is refused, and the stored value stands"                     "$rigRc $( rigGet mel-grok PRESET_CLI_SERVICE )" "1 grok"
rigRunStdin "$rigSecretA" --agents-config-option preset-mel-grok --upsert-from-stdin XAI_API_KEY
rigAssert "a credential from stdin is written whole"                              "$rigRc $( LC_ALL=C grep -c -x -F -e "XAI_API_KEY=$rigSecretA" "$rigAgents/preset-mel-grok.agent.env" )" "0 1"
rigRunStdin "a line for the model" --agents-config-option preset-mel-grok --upsert-from-stdin PRESET_EXTRA_SPAWN_LINE
rigAssert "the extra spawn line from stdin is written whole"                      "$rigRc $( rigGet mel-grok PRESET_EXTRA_SPAWN_LINE )" "0 a line for the model"

echo "-- J. the catalogue describes each key --"
rigCatalogue(){ ( . "$rigPackage/sh-lib/config/AgentsTools.OwnerSetupOptionSpec.include" ; AgentsToolsOwnerSetupOptionSpec "$1" ) ; }
rigAssert "each of the seven keys is in the catalogue, in no one scope, plain"     "$( for rigKey in PRESET_EXTEND PRESET_CLI_SERVICE PRESET_MODEL_OR_MACRO PRESET_EFFORT PRESET_INPUT_CACHE_TIME PRESET_CONTEXT_MAX_SIZE PRESET_EXTRA_SPAWN_LINE ; do rigCatalogue "$rigKey" | LC_ALL=C cut -d'|' -f1,3 ; done | LC_ALL=C sort | uniq -c | tr -s ' ' )" " 7 -|plain"
rigAssert "the model's text says a native CLI is passed no model"                 "$( rigCatalogue PRESET_MODEL_OR_MACRO | LC_ALL=C grep -c -e 'native CLI is passed no model' )" 1
rigAssert "the extra line's text says the human-owner writes it and nobody else"   "$( rigCatalogue PRESET_EXTRA_SPAWN_LINE | LC_ALL=C grep -c -e 'human-owner writes it' )" 1
rigAssert "the context size's text says stored only, the cache time's says the two lifetimes it takes"  "$( rigCatalogue PRESET_CONTEXT_MAX_SIZE | LC_ALL=C grep -c -e 'Stored only' )$( rigCatalogue PRESET_INPUT_CACHE_TIME | LC_ALL=C grep -c -e 'Stored only' )$( rigCatalogue PRESET_INPUT_CACHE_TIME | LC_ALL=C grep -c -e '5m' -e '1h' )" 101

echo "-- guard: no whole secret on any stream; the real workspace untouched --"
rigAssert "no whole credential of the rig appears in any output"                  "$( LC_ALL=C grep -c -F -e "$rigSecretA" -e "$rigSecretB" -e "$rigSecretC" "$rigTmp/all.out" )" 0
rigAssert "the real workspace holds no block made by this check (none holds a credential of the rig)"  "$( LC_ALL=C grep -l -F -e "$rigSecretA" -e "$rigSecretB" -e "$rigSecretC" "${MMDAPP%/}/.local/.agents"/*.agent.env 2> /dev/null | wc -l | tr -d ' ' )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PRESET STORE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'PRESET_STORE: OK (%d assertions, offline)\n' "$rigPassCount"
