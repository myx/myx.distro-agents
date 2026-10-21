#!/usr/bin/env bash
## Behavioural check on the scopes of the console's `Scope Settings` (F11.7 of the refactorings epic), run rather than read: the
## operations --manager-scope-list, -read, -reveal, -set, -unset, -clear and -delete, against a rig workspace built here, so what
## the user who runs this check and the real workspace have saved is never read and never written, which the last section asserts.
## Held (F11.7: "displays all `--config` items of every installed subsystem as sources, allows edit and delete ... A subsection is a
## group of settings and becomes a folder, named like `Agents: client-ndm`, `Remote: mdci01.ndm9.xyz`, `Common: user-myx` ... A
## whole subsection can be cleared, reset or deleted where the subsystem allows it"; the coordinator's rulings: the scopes as they
## exist, no Deploy folder since nothing is there, the preset-<name> blocks are scopes of the agents each its own folder, Clear for
## any scope and Delete where many exist, no Reset with nothing to reset to):
##   1. the scopes: the workspace's own and the running user's own settings, each remote profile, each scope of the agents (members,
##      the team, routines, presets) with its label as a folder is named, how many keys it holds and whether it may be cleared and
##      deleted; the settings of another user, a file that is no scope and the placeholder of the deploy tools are none
##   2. a scope read: its own row, then a row for each key with its state; a credential in the one form of F11.8, never whole; a
##      comment, a blank and a line with no = are no key; an id that is none is refused with nothing repeated
##   3. a key saved: the value comes on the standard input and never as an argument; the row says what the file holds, a credential
##      in its one form; every other line, the mode of the file and the other scopes stay as they were; an empty value, a value of
##      more lines, a name that is no setting's and a value given as an argument are refused; a write that a preset refuses is refused
##      here and the file stays; a user's and a remote profile's key are saved in their own files
##   4. a key taken out, one the scope does not hold refused; a scope cleared of every key, its file, its comments and the others
##      staying; a scope deleted where there are many (agents, remote), the two common scopes refused
##   5. a credential revealed whole, by the one operation that prints a value whole
##   6. from inside a member's session the whole family is refused; the help pair of each operation
## Offline; only the rig's own tree is written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScopeCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills"
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"
rigUser="$( id -un )" || rigRefuse "the name of the user who runs this check cannot be read"
[ -n "$rigUser" ] && [ "$rigUser" != "rig-other-user" ] || rigRefuse "the user who runs this check has no name of its own"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigWs/.local/home/$rigUser" "$rigWs/.local/home/rig-other-user" "$rigWs/remote/static" "$rigHome" "$rigSkills"
rigAgents="$rigWs/.local/.agents"
rigShared="$rigWs/.local/MDLT.settings.env"
rigOwn="$rigWs/.local/home/$rigUser/MDLT.settings.env"
rigOther="$rigWs/.local/home/rig-other-user/MDLT.settings.env"
rigRemote="$rigWs/remote/static/mdci01.rig.example.remote.env"
rigTeam="$rigAgents/magic-team.agent.env"
rigPreset="$rigAgents/preset-rig.agent.env"
## A value nobody may see again, in the settings of the team and of a remote profile.
rigSecret="Hd3mTyRIGSECRET31Vq7zKe"
rigMask(){ ## value -- the form of F11.8: its first quarter, not under 4 and not over 20 characters, then a * for each character after them
	local maskHead=$(( ${#1} / 4 )) maskRest
	[ "$maskHead" -ge 4 ] || maskHead=4
	[ "$maskHead" -le 20 ] || maskHead=20
	printf -v maskRest '%*s' $(( ${#1} - maskHead )) ''
	printf '%s%s' "${1:0:maskHead}" "${maskRest// /*}"
}
rigShown="$( rigMask "$rigSecret" )"
rigShownTwo="$( rigMask "$rigSecret-2" )"
printf 'MDLT_CONSOLE_ORIGIN=.local\nMDLT_CONSOLE_HISTORY=workspace-shared\n' > "$rigShared"
printf 'MDLT_CONSOLE_HISTORY=workspace-separate\n' > "$rigOwn"
printf 'MDLT_CONSOLE_HISTORY=workspace-personal\n' > "$rigOther"
printf 'REMOTE_HOST=mdci01.rig.example\nREMOTE_NOTE=two words\n' > "$rigRemote"
printf '# a note of the owner\nWAIT_ROUND_SECONDS=claude\nSLACK_BOT_TOKEN=%s\nnot a setting line\nlower_case=1\n\nEMPTY_KEY=\n' "$rigSecret" > "$rigTeam"
printf 'PRESET_CLI_SERVICE=claude\nPRESET_EFFORT=high\n' > "$rigPreset"
: > "$rigAgents/keeper-rig.agent.env" ; : > "$rigAgents/magic-coordinator.agent.env"
printf 'U1:rig\n' > "$rigAgents/slack-mention-ids.cache"
: > "$rigWs/.local/MDSC.deploy.settings.env"
chmod 770 "$rigAgents" ; chmod 660 "$rigAgents"/*.agent.env

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
: > "$rigTmp/all"
rigPre=()
rigIn=""
rigRun(){ ## tool arguments... -- one dispatcher call from the rig workspace, rigIn on its standard input; rc in rigRc, stdout in out, stderr in err, both kept in all
	rigRc=0
	( cd "$rigWs" && printf '%s' "$rigIn" | env -i HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" || rigRc=$?
	cat "$rigTmp/out" "$rigTmp/err" >> "$rigTmp/all"
}
rigRunIn(){ ## the standard input, then tool arguments...
	rigIn="$1" ; shift
	rigRun "$@"
	rigIn=""
}
rigTroubles(){ ## -- how many lines of the last stderr are an error or a warning, but for the one every rig of this package gets
	LC_ALL=C grep -E -- 'ERROR|WARNING' "$rigTmp/err" | LC_ALL=C grep -c -v -F -- 'SystemContext.SetInputSpec' || :
}
rigFlat(){ ## file -- its lines, TAB to a blank, parted by `/`
	LC_ALL=C tr '\t' ' ' < "$1" | LC_ALL=C tr '\n' '/'
}
rigSum(){ ## file -- the checksum of its bytes, or `absent`
	if [ -f "$1" ] ; then cksum < "$1" ; else echo absent ; fi
}
rigMode(){ ## file -- its mode in octal
	stat -f '%Lp' "$1" 2> /dev/null || stat -c '%a' "$1" 2> /dev/null
}
rigRealBefore="$( rigSum "${MMDAPP%/}/.local/.agents/magic-team.agent.env" ) $( rigSum "${MMDAPP%/}/.local/MDLT.settings.env" )"

echo "-- 1. the scopes, one row each, as the console shows them as folders --"
rigRun --manager-scope-list
rigAssert "the call ends 0, with no error and no warning" "$rigRc $( rigTroubles )" "0 0"
rigAssert "the workspace's own, the user's own, the remote profile, then the scopes of the agents by name, the presets among them, each with its label, its keys, whether it may be cleared and deleted, and its file; no other user's settings, no cache, no deploy scope" "$( rigFlat "$rigTmp/out" )" \
	"scope common:workspace Common:_workspace 2 yes no $rigShared/scope common:user-$rigUser Common:_user-$rigUser 1 yes no $rigOwn/scope remote:mdci01.rig.example Remote:_mdci01.rig.example 2 yes yes $rigRemote/scope agents:keeper-rig Agents:_keeper-rig 0 no yes $rigAgents/keeper-rig.agent.env/scope agents:magic-coordinator Agents:_magic-coordinator 0 no yes $rigAgents/magic-coordinator.agent.env/scope agents:magic-team Agents:_magic-team 4 yes yes $rigTeam/scope agents:preset-rig Agents:_preset-rig 2 yes yes $rigPreset/"

echo "-- 2. a scope read --"
rigRun --manager-scope-read agents:magic-team
rigAssert "its own row, then a row for each key, in the order of the file, with its type: a setting, a credential in its one form, a key with nothing after the = as missing; a comment, a line with no = and a blank are no key" "$rigRc $( LC_ALL=C awk -F'\t' '$1 == "scope" { printf "%s %s %s %s %s %s %s / ", $2, $3, $4, $5, $6, $7, NF } $1 == "key" { printf "%s %s %s %s / ", $2, $3, $4, $5 }' "$rigTmp/out" )" \
	"0 agents:magic-team Agents:_magic-team 4 yes yes $rigTeam 7 / WAIT_ROUND_SECONDS set claude setting / SLACK_BOT_TOKEN secret-set $rigShown credential / lower_case set 1 setting / EMPTY_KEY missing - setting / SPAWN_TIER_LOW missing - setting / SPAWN_TIER_NORMAL missing - setting / SPAWN_TIER_HIGH missing - setting / "
rigAssert "the description is the catalogue of the owner setup's text for a key it describes, and a dash for any other; it holds no value" "$( LC_ALL=C awk -F'\t' '$1 == "key" { printf "%s:%s ", $2, ( $6 == "-" ) ? "none" : "text" }' "$rigTmp/out" ) $( LC_ALL=C awk -F'\t' '$1 == "key" && $2 == "WAIT_ROUND_SECONDS" { print $6 }' "$rigTmp/out" | LC_ALL=C grep -c -F 'how_long_a_wait' )" "WAIT_ROUND_SECONDS:text SLACK_BOT_TOKEN:text lower_case:none EMPTY_KEY:none SPAWN_TIER_LOW:text SPAWN_TIER_NORMAL:text SPAWN_TIER_HIGH:text  1"
rigAssert "the credential is never on the screen whole: not in what was printed, not in what was said" "$( LC_ALL=C grep -c -F -- "$rigSecret" "$rigTmp/out" "$rigTmp/err" | LC_ALL=C awk -F: '{ n += $NF } END { print n + 0 }' )" "0"
rigRun --manager-scope-read remote:mdci01.rig.example
rigAssert "a remote profile: its keys with their values, a value of two words as one field" "$rigRc $( rigFlat "$rigTmp/out" )" "0 scope remote:mdci01.rig.example Remote:_mdci01.rig.example 2 yes yes $rigRemote/key REMOTE_HOST set mdci01.rig.example setting - - -/key REMOTE_NOTE set two_words setting - - -/"
rigRun --manager-scope-read "common:user-$rigUser"
rigAssert "the user's own settings are the running user's, read from the user's own file" "$rigRc $( rigFlat "$rigTmp/out" )" "0 scope common:user-$rigUser Common:_user-$rigUser 1 yes no $rigOwn/key MDLT_CONSOLE_HISTORY set workspace-separate setting - - -/"
rigRun --manager-scope-read common:user-rig-other-user
rigAssert "the settings of another user are none of the scopes: refused, nothing on stdout, the id not repeated" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( LC_ALL=C grep -c -F -- 'rig-other-user' "$rigTmp/err" || : )" "1 0 0"
rigRun --manager-scope-read agents:no-such-scope
rigAssert "an id that names no scope is refused, nothing on stdout" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( LC_ALL=C grep -c -F -- 'no-such-scope' "$rigTmp/err" || : )" "1 0 0"
rigRun --manager-scope-read
rigAssert "a read with no id is refused with its syntax" "$rigRc $( LC_ALL=C grep -c -F -- '--manager-scope-read <scope-id>' "$rigTmp/err" || : )" "1 1"

echo "-- 3. a key saved --"
rigTeamBefore="$( rigSum "$rigTeam" )" ; rigModeBefore="$( rigMode "$rigTeam" )"
rigRunIn "codex" --manager-scope-set agents:magic-team WAIT_ROUND_SECONDS
rigAssert "the value comes on the standard input; one row says what the key holds now" "$rigRc $( rigFlat "$rigTmp/out" )" "0 saved agents:magic-team WAIT_ROUND_SECONDS codex/"
rigAssert "the file holds the one new value; every other line, the comment and the credential among them, stands as it was; the mode stays" "$( LC_ALL=C grep -c -x -F -- 'WAIT_ROUND_SECONDS=codex' "$rigTeam" ) $( LC_ALL=C grep -c -F -- 'WAIT_ROUND_SECONDS=' "$rigTeam" ) $( LC_ALL=C grep -c -x -F -- "SLACK_BOT_TOKEN=$rigSecret" "$rigTeam" ) $( LC_ALL=C grep -c -x -F -- '# a note of the owner' "$rigTeam" ) $( rigMode "$rigTeam" )" "1 1 1 1 $rigModeBefore"
rigRunIn "$rigSecret-2" --manager-scope-set agents:magic-team SLACK_BOT_TOKEN
rigAssert "a credential saved shows in its one form, the new value never whole" "$rigRc $( rigFlat "$rigTmp/out" ) $( LC_ALL=C grep -c -F -- "$rigSecret" "$rigTmp/out" "$rigTmp/err" | LC_ALL=C awk -F: '{ n += $NF } END { print n + 0 }' )" "0 saved agents:magic-team SLACK_BOT_TOKEN $rigShownTwo/ 0"
rigRunIn "" --manager-scope-set agents:magic-team WAIT_ROUND_SECONDS
rigAssert "an empty value is refused, and says a key is taken out with --manager-scope-unset" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( LC_ALL=C grep -c -F -- '--manager-scope-unset' "$rigTmp/err" || : ) $( LC_ALL=C grep -c -x -F -- 'WAIT_ROUND_SECONDS=codex' "$rigTeam" )" "1 0 1 1"
rigRunIn $'one\ntwo' --manager-scope-set agents:magic-team WAIT_ROUND_SECONDS
rigAssert "a value of more than one line is refused and the file stays" "$rigRc $( LC_ALL=C grep -c -x -F -- 'WAIT_ROUND_SECONDS=codex' "$rigTeam" )" "1 1"
rigRunIn "x" --manager-scope-set agents:magic-team 'BAD KEY'
rigAssert "a name that is no setting's is refused" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" "1 0"
rigRun --manager-scope-set agents:magic-team WAIT_ROUND_SECONDS claude
rigAssert "a value given as an argument is refused: a value never travels in argv" "$rigRc $( LC_ALL=C grep -c -x -F -- 'WAIT_ROUND_SECONDS=codex' "$rigTeam" )" "1 1"
rigRunIn "sideways" --manager-scope-set agents:preset-rig PRESET_EFFORT
rigAssert "a preset's write check is asked as for any writer: a value its key does not take is refused and the file stays as it was" "$rigRc $( LC_ALL=C grep -c -x -F -- 'PRESET_EFFORT=high' "$rigPreset" ) $( LC_ALL=C grep -c -F -- 'sideways' "$rigPreset" || : )" "1 1 0"
rigRunIn "low" --manager-scope-set agents:preset-rig PRESET_EFFORT
rigAssert "a value the preset takes is saved" "$rigRc $( rigFlat "$rigTmp/out" ) $( LC_ALL=C grep -c -x -F -- 'PRESET_EFFORT=low' "$rigPreset" )" "0 saved agents:preset-rig PRESET_EFFORT low/ 1"
rigRunIn "workspace-personal" --manager-scope-set "common:user-$rigUser" MDLT_CONSOLE_HISTORY
rigAssert "a key of the user's own settings is saved in the user's own file, and the other user's and the workspace's stay" "$rigRc $( LC_ALL=C grep -c -x -F -- 'MDLT_CONSOLE_HISTORY=workspace-personal' "$rigOwn" ) $( rigSum "$rigOther" ) $( LC_ALL=C grep -c -x -F -- 'MDLT_CONSOLE_HISTORY=workspace-shared' "$rigShared" )" "0 1 $( printf 'MDLT_CONSOLE_HISTORY=workspace-personal\n' | cksum ) 1"
rigRunIn "mdci02.rig.example" --manager-scope-set remote:mdci01.rig.example REMOTE_HOST
rigAssert "a key of a remote profile is saved in the profile's file, the other key staying" "$rigRc $( LC_ALL=C grep -c -x -F -- 'REMOTE_HOST=mdci02.rig.example' "$rigRemote" ) $( LC_ALL=C grep -c -x -F -- 'REMOTE_NOTE=two words' "$rigRemote" )" "0 1 1"
rigRunIn "native" --manager-scope-set common:workspace MDLT_CONSOLE_DETAIL
rigAssert "a key not yet there is added to the workspace's own settings, the others staying" "$rigRc $( LC_ALL=C grep -c -x -F -- 'MDLT_CONSOLE_DETAIL=native' "$rigShared" ) $( LC_ALL=C grep -c -x -F -- 'MDLT_CONSOLE_ORIGIN=.local' "$rigShared" )" "0 1 1"
rigRunIn "x" --manager-scope-set agents:no-such-scope SOMETHING
rigAssert "a scope that is none is refused" "$rigRc" "1"

echo "-- 4. a key taken out, a scope cleared, a scope deleted --"
rigRun --manager-scope-unset agents:magic-team WAIT_ROUND_SECONDS
rigAssert "a key is taken out: one row, and the file no longer holds it, the others stand" "$rigRc $( rigFlat "$rigTmp/out" ) $( LC_ALL=C grep -c -F -- 'WAIT_ROUND_SECONDS' "$rigTeam" || : ) $( LC_ALL=C grep -c -F -- 'SLACK_BOT_TOKEN=' "$rigTeam" )" "0 removed agents:magic-team WAIT_ROUND_SECONDS/ 0 1"
rigRun --manager-scope-unset agents:magic-team WAIT_ROUND_SECONDS
rigAssert "a key the scope does not hold is refused" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" "1 0"
rigRun --manager-scope-clear agents:magic-team
rigAssert "a scope is cleared of every key: one row with their count, the file and its comment stay, the other scopes stay" "$rigRc $( rigFlat "$rigTmp/out" ) $( [ -f "$rigTeam" ] && echo file ) $( LC_ALL=C grep -c -x -F -- '# a note of the owner' "$rigTeam" ) $( LC_ALL=C grep -c -F -- 'SLACK_BOT_TOKEN' "$rigTeam" || : ) $( LC_ALL=C grep -c -x -F -- 'PRESET_EFFORT=low' "$rigPreset" )" "0 cleared agents:magic-team 3/ file 1 0 1"
rigRun --manager-scope-clear common:workspace
rigAssert "the workspace's own settings are cleared too, the file staying" "$rigRc $( rigFlat "$rigTmp/out" ) $( [ -f "$rigShared" ] && echo file )" "0 cleared common:workspace 3/ file"
rigRun --manager-scope-delete common:workspace
rigAssert "the workspace's own settings are one, and are not deleted" "$rigRc $( [ -f "$rigShared" ] && echo file )" "1 file"
rigRun --manager-scope-delete "common:user-$rigUser"
rigAssert "nor are the user's own" "$rigRc $( [ -f "$rigOwn" ] && echo file )" "1 file"
rigRun --manager-scope-delete remote:mdci01.rig.example
rigAssert "a remote profile is deleted: its file is gone" "$rigRc $( rigFlat "$rigTmp/out" ) $( [ -e "$rigRemote" ] && echo file || echo gone )" "0 deleted remote:mdci01.rig.example/ gone"
rigRun --manager-scope-delete agents:preset-rig
rigAssert "a preset, which is a scope of the agents, is deleted: its file is gone" "$rigRc $( rigFlat "$rigTmp/out" ) $( [ -e "$rigPreset" ] && echo file || echo gone )" "0 deleted agents:preset-rig/ gone"
rigRun --manager-scope-list
rigAssert "what was deleted is no longer listed, what was cleared still is, with no key" "$( LC_ALL=C awk -F'\t' '{ printf "%s ", $2 }' "$rigTmp/out" )" "common:workspace common:user-$rigUser agents:keeper-rig agents:magic-coordinator agents:magic-team "

echo "-- 5. a credential revealed whole --"
printf 'SLACK_BOT_TOKEN=%s\n' "$rigSecret" > "$rigTeam"
rigRun --manager-scope-reveal agents:magic-team SLACK_BOT_TOKEN
rigAssert "the one operation that prints a value whole prints it, alone" "$rigRc [$( cat "$rigTmp/out" )]" "0 [$rigSecret]"
rigRun --manager-scope-reveal agents:no-such-scope SLACK_BOT_TOKEN
rigAssert "a scope that is none prints nothing" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" "1 0"

echo "-- 6. from a member's session, and the help pair --"
rigPre=(MDAT_SPAWN_AGENT=magic-coordinator)
rigBad=""
for rigOne in "--manager-scope-list" "--manager-scope-read agents:magic-team" "--manager-scope-clear agents:keeper-rig" ; do
	rigRun $rigOne
	[ "$rigRc" = 1 ] && [ "$( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" = 0 ] || rigBad="$rigBad [$rigOne]"
done
rigAssert "a member's session is refused each operation of the family, magic-coordinator's too" "${rigBad:- all refused}" " all refused"
rigPre=()
rigBad=""
for rigOne in list read reveal set unset clear delete ; do
	LC_ALL=C grep -q -F -- "DistroAgentsTools.fn.sh --manager-scope-$rigOne" "$rigPackage/sh-lib/help/Help.DistroAgentsTools.include" || rigBad="$rigBad [include $rigOne]"
	LC_ALL=C grep -q -E -- "^[[:space:]]+--manager-scope-$rigOne( |\$)" "$rigPackage/sh-lib/help/Help.DistroAgentsTools.help.md" || rigBad="$rigBad [help.md $rigOne]"
done
rigAssert "each of the seven operations has its syntax line and its help entry" "${rigBad:- all paired}" " all paired"

echo "-- 7. nothing of the real workspace was read or written --"
rigAssert "the real team settings and the real workspace settings are as they were" "$( rigSum "${MMDAPP%/}/.local/.agents/magic-team.agent.env" ) $( rigSum "${MMDAPP%/}/.local/MDLT.settings.env" )" "$rigRealBefore"
rigAssert "no secret of the rig is anywhere in what the calls printed, but the one reveal" "$( LC_ALL=C grep -c -F -- "$rigSecret" "$rigTmp/all" )" "1"

printf '\nTOTAL: %d passed, %d failed\n' "$rigPasses" "$rigFails"
[ "$rigFails" = 0 ]
