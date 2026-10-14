#!/usr/bin/env bash
## Behavioural check on --manager-config-digest [<subject>...], the digest of the settings of a workspace as they
## are, run rather than read, against a rig workspace built here: its own scope files, its own registered place,
## its own team data with a heartbeat note, its own main loop state, and a PATH of its own on which, of the vendor
## binaries, only the rig's `copilot` stands. EVERY SECRET OF THE RIG IS A FAKE VALUE THIS CHECK KNOWS, each with
## six letters of its own at its head and at its tail and the mark RIGSECRET between them.
## Held: the eight subjects in their one order, each a `subject` row with the count of the `line` rows after it;
## the workspace and its paths, a path that is not there read as missing, and each registered place with its path;
## the CLI service the workspace asks for, each vendor CLI with whether its binary is present (a harness leg lies in
## sh-lib and has no such line, the owner: "remove `present` - it is always present it is in sh-lib"), the credentials a harness leg
## reads as set or not, whether it is usable, and its wait round; the outside systems, each scope that holds one as
## configured or not, with what it lacks by key name; the main loop by its state file and the heartbeat by its
## note, running only while its lock is held; the scopes that hold a key, a scope with none left out, each key with
## its value where it is no secret. A SECRET IS NEVER PRINTED: a key the catalogue marks secret, a key with the
## shape of one that no catalogue names, a key of a kind not met before, a key that holds the word of a secret
## ahead of a plain last word, and a password inside a URL under a plain key all read secret-set with the value
## `-`; an empty one reads secret-missing; a line that is a comment is no key, and a line whose name is not a
## setting's is never listed, a secret pasted with an `=` at its end among them. No fake secret, no head and no tail
## of one, stands anywhere in what any call of this check printed, on either stream. One subject or some are
## printed by name, in the one order, and a name that is none refuses the call before anything is printed. The
## call only reads: every file of the rig is as it was. From inside a member's session it is refused. And the help
## pair, with the two row forms the output is checked against. A fake `curl` first on PATH would log a request:
## none is made. Offline; only the rig's own tree is read.
## The sixth subject, the interface settings of the user, has its own check, AgentsManagerConfigInterfaceCheck,
## with the one operation of this family's settings that writes: here it is held only in its place.
## THE LABELS: every row ends with what a screen calls it, its last field: capitalised words, more than one, their
## blanks written `_`. Held: the six labels of the subjects; the label of each line the include prints under a key
## of its own, each from its own row of the one declaration; a line whose key is not the include's by the rule of
## its row, the words of the key or the name after a word; a line no row fits gets `-`, on which this check fails.
## IN FULL (--full) every line has eight more fields at its end: a description from the same declaration, whether
## it can be changed, for a line that can its kind, its scope, where its value comes from, what it takes and where
## it is saved, and which of the two it belongs to, the settings or the configuration. Without --full every row is byte for byte what it was. The writer of a changeable setting
## and the two subjects of them, the console and the control of sessions, are held by AgentsManagerConfigSetCheck.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigOp="--manager-config-digest"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
rigTmp="$( mktemp -d -t AgentsManagerConfigDigestCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills"
rigScopes="$rigWs/.local/.agents" ; rigAgents="$rigWs/.local/agents"
rigData="$rigAgents/team-data-root"
rigNote="$rigData/inboxes/magic-coordinator/note-20260809T155000Z-heartbeat-state-and-lock.md"
mkdir -p "$rigTmp/bin" "$rigScopes" "$rigAgents" "$rigData/inboxes/magic-coordinator" "$rigHome" "$rigSkills" "$rigTmp/docs"
rigTab="$( printf '\t' )"
rigOrigin="${MDLT_ORIGIN%/}"

## THE RIG'S OWN PATH: its bin, then the system's own folders, where no vendor CLI is installed. Of the vendor
## binaries only `copilot` stands on it, the rig's own; and a curl that would log a request.
printf '#!/bin/sh\nexit 0\n' > "$rigTmp/bin/copilot"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/curl.calls"\nexit 7\n' "$rigTmp" > "$rigTmp/bin/curl"
chmod +x "$rigTmp/bin/copilot" "$rigTmp/bin/curl"
rigPath="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin"
[ "$( PATH="$rigPath" command -v copilot )" = "$rigTmp/bin/copilot" ] && [ "$( PATH="$rigPath" command -v curl )" = "$rigTmp/bin/curl" ] \
	|| rigRefuse "the rig's own copilot and curl are not first on the rig's PATH"
[ -z "$( PATH="$rigPath" command -v claude )$( PATH="$rigPath" command -v grok )" ] \
	|| rigRefuse "a vendor claude or grok stands in the system's own folders, so this check cannot say which CLI is absent"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

## THE FAKE SECRETS, one a line: six letters of its own, the mark and its number, six more letters of its own.
cat > "$rigTmp/secrets" <<'RIGSECRETS'
Qz7wHaRIGSECRET01Xk9vTu
Jr4tBeRIGSECRET02Lm2qYo
Ap8nCiRIGSECRET03Vc5dWe
Cm3xDoRIGSECRET04Hy6bSa
Ep1kFuRIGSECRET05Wd8sRi
Tr9gGaRIGSECRET06Nf4zQu
Go2hHeRIGSECRET07Ub7rPo
Od6jJiRIGSECRET08Pe3mNa
Sc5yKoRIGSECRET09Zt1cMe
Aw7fLuRIGSECRET10Kq9lLi
Ur4vMaRIGSECRET11Bn6pKo
Sy8eNeRIGSECRET12Mg2wJu
Vb3nPoRIGSECRET13Dz5hGi
RIGSECRETS
rigSecret(){ ## number -- that fake secret
	LC_ALL=C sed -n "${1}p" "$rigTmp/secrets"
}
: > "$rigTmp/all"
rigPre=()
rigRunIn(){ ## workspace, tool arguments... -- one dispatcher call from that workspace; rc in rigRc, stdout in out, stderr in err, both kept in all
	local runWs="$1" ; shift
	rigRc=0
	( cd "$runWs" && env -i HOME="$rigHome" PATH="$rigPath" MMDAPP="$runWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
	cat "$rigTmp/out" "$rigTmp/err" >> "$rigTmp/all"
}
rigRun(){ ## tool arguments... -- in the rig workspace
	rigRunIn "$rigWs" "$@"
}
rigLine(){ ## subject, group, key -- the state and the value of that line in the last output, TAB written as a space; one line each
	LC_ALL=C awk -F'\t' -v wantSubject="$1" -v wantGroup="$2" -v wantKey="$3" '$1 == "line" && $2 == wantSubject && $3 == wantGroup && $4 == wantKey { print $5, $6 ; }' "$rigTmp/out"
}
rigGroups(){ ## subject -- the groups of that subject in the last output, each once, in their order, joined by spaces
	LC_ALL=C awk -F'\t' -v wantSubject="$1" '$1 == "line" && $2 == wantSubject && !( $3 in seen ) { seen[$3] = 1 ; printf "%s%s", sep, $3 ; sep = " " ; }' "$rigTmp/out"
}
rigPart(){ ## subject, file -- the rows of that subject in the file: its subject row and its lines
	LC_ALL=C awk -F'\t' -v wantSubject="$1" '$2 == wantSubject { print ; }' "$2"
}
rigTroubles(){ ## -- how many lines of the last stderr are an error or a warning, but for the one every rig of this package gets
	LC_ALL=C grep -E -- 'ERROR|WARNING' "$rigTmp/err" | LC_ALL=C grep -c -v -F -- 'SystemContext.SetInputSpec' || :
}
rigWhole(){ ## file, text -- how many lines of the file are that text, whole
	LC_ALL=C grep -c -x -F -- "$2" "$1" 2> /dev/null || :
}
rigTree(){ ## -- every file of the rig's workspaces, home, skills and place, each with the sum of its bytes, as one sum
	( cd "$rigTmp" && find ws ws-bare home skills docs -type f 2> /dev/null | LC_ALL=C sort | while IFS= read -r treeFile ; do printf '%s %s\n' "$treeFile" "$( cksum < "$treeFile" )" ; done ) | cksum
}

## THE SETTINGS. Four scope files, three of them empty; the one that holds keys has a line that is a comment.
: > "$rigScopes/magic-coordinator.agent.env" ; : > "$rigScopes/keeper-rig.agent.env" ; : > "$rigScopes/human-owner.agent.env"
{
	printf '# SLACK_APP_TOKEN=%s\n' "$( rigSecret 4 )"
	printf 'SLACK_BOT_TOKEN=%s\n' "$( rigSecret 1 )"
	printf 'JIRA_API_TOKEN=%s\n' "$( rigSecret 2 )"
	printf 'SPAWN_CLI_SERVICE=claude\n'
	printf 'MDAT_WORKSPACE_MODE=team-rig\n'
	printf 'SLACK_CHANNEL_MAGIC_TEAM=C0RIGTEAM01\n'
	printf 'SLACK_CHANNEL_HUMAN_OWNER=U0RIGOWNER1\n'
	printf 'ANTHROPIC_API_KEY=%s\n' "$( rigSecret 3 )"
} > "$rigScopes/magic-team.agent.env"
chmod 770 "$rigScopes" ; chmod 660 "$rigScopes"/*.agent.env
## One registered place beside the workspace's own row.
{
	printf 'ws\tworkspace\tread-write\t%s\tworkspace\n' "$rigWs"
	printf 'docs\tdirectory\tread-only\t%s\towner\n' "$rigTmp/docs"
} > "$rigAgents/directories.registry"
## The main loop's state, as its last iteration left it, and the heartbeat's note with its lock held: a
## recheck date far ahead.
{
	printf 'MAIN_LOOP_LAST_OUTCOME=succeeded\n'
	printf 'MAIN_LOOP_LAST_ITERATION_UTC=2026-10-13T00:10:00Z\n'
	printf 'MAIN_LOOP_CONSECUTIVE_FAILURES=0\n'
	printf 'MAIN_LOOP_CURRENT_DELAY_SECONDS=29\n'
	printf 'MAIN_LOOP_TEAM_DATA=skipped\n'
	printf 'MAIN_LOOP_TEAM_DATA_CONSECUTIVE_FAILURES=0\n'
} > "$rigAgents/main-loop.state"
rigNoteWrite(){ ## state, recheck-date
	printf -- '---\ntype: note\nfrom: magic-coordinator\nowner: magic-coordinator\nrecheck-date: %s\nstate: %s\nsession-id: main-loop\nlast-iteration-timestamp: 2026-10-12T19:54:21Z\n---\n\nstate: a line of the body\n' "$2" "$1" > "$rigNote"
}
rigNoteWrite heartbeat-running '2099-01-01 00:00 +0000'
mkdir -p "$rigTmp/ws-bare/.local/.agents"
rigTreeBefore="$( rigTree )"

echo "-- 1. the whole digest: eight subjects in their one order, each with its lines --"
rigRun "$rigOp"
cp "$rigTmp/out" "$rigTmp/whole"
rigAssert "the call ends 0, with no error and no warning" "$rigRc $( rigTroubles )" "0 0"
rigAssert "the subjects come in the one order: the workspace, the CLI services, the outside systems, the main loop, the scopes, the interface, the console, the control of sessions" "$( LC_ALL=C awk -F'\t' '$1 == "subject" { printf "%s ", $2 }' "$rigTmp/out" )" "workspace cli systems loop scopes interface console control "
rigAssert "every row has the fields of its kind, its label the last: 4 of a subject, 7 of a line, 9 of a line of the interface, and no line is of another kind" "$( LC_ALL=C awk -F'\t' '{ want = ( $1 == "subject" ) ? 4 : ( $1 == "line" ) ? ( $2 == "interface" ? 9 : 7 ) : -1 ; if ( NF != want ) bad++ ; } END { print ( NR > 20 ? "rows" : "few" ) ":" bad + 0 }' "$rigTmp/out" )" "rows:0"
rigAssert "a subject row counts the lines after it, and every line stands under its own subject" "$( LC_ALL=C awk -F'\t' '$1 == "subject" { if ( name != "" && said != seen ) bad++ ; name = $2 ; said = $3 ; seen = 0 ; next ; } $1 == "line" { if ( $2 != name ) bad++ ; seen++ ; } END { if ( said != seen ) bad++ ; print bad + 0 }' "$rigTmp/out" )" "0"
rigAssert "every state is one of the four, and no field is empty or holds a space" "$( LC_ALL=C awk -F'\t' '$1 == "line" && $5 != "set" && $5 != "missing" && $5 != "secret-set" && $5 != "secret-missing" { bad++ ; } { for ( i = 1 ; i <= NF ; i++ ) if ( $i == "" || $i ~ / / ) bad++ ; } END { print bad + 0 }' "$rigTmp/out" )" "0"

echo "-- 2. the workspace and its paths --"
rigWant="$( {
	printf 'subject\tworkspace\t12\tWorkspace_Paths\n'
	printf 'line\tworkspace\tpaths\tworkspace-root\tset\t%s\tWorkspace_Root\n' "$rigWs"
	printf 'line\tworkspace\tpaths\ttooling-origin\tset\t%s\tTooling_Origin\n' "$rigOrigin"
	printf 'line\tworkspace\tpaths\tteam-data-root\tset\t%s\tTeam_Data_Root\n' "$rigData"
	printf 'line\tworkspace\tpaths\tsession-records\tmissing\t%s\tSession_Records\n' "$rigAgents/spawned"
	printf 'line\tworkspace\tpaths\tsession-stores\tmissing\t%s\tSession_Stores\n' "$rigAgents/sessions"
	printf 'line\tworkspace\tpaths\tsettings\tset\t%s\tScope_Settings_Folder\n' "$rigScopes"
	printf 'line\tworkspace\tmode\tMDAT_WORKSPACE_MODE\tset\tteam-rig\tWorkspace_Mode\n'
	printf 'line\tworkspace\tmode\tfull-team-rig\tmissing\tno\tFull_Team_Rig\n'
	printf 'line\tworkspace\tplaces\t.skillset-shared\tmissing\t%s\tRegistered_Place_.skillset-shared\n' "$rigHome/.claude/skills"
	printf 'line\tworkspace\tplaces\t.skillset-.local\tset\t%s\tRegistered_Place_.skillset-.local\n' "$rigSkills"
	printf 'line\tworkspace\tplaces\tws\tset\t%s\tRegistered_Place_ws\n' "$rigWs"
	printf 'line\tworkspace\tplaces\tdocs\tset\t%s\tRegistered_Place_docs\n' "$rigTmp/docs"
} )"
rigAssert "the whole subject, byte for byte: the root of the workspace, the origin of the tooling, the root of the team data, the session stores and the settings, then each place with its path" "$( rigPart workspace "$rigTmp/out" )" "$rigWant"
rigAssert "a path that is not there reads missing, with the path it would have: no session has run in the rig" "$( rigLine workspace paths session-records )" "missing $rigAgents/spawned"
rigAssert "the place registered beside the workspace is printed with its path, and the workspace's own row too" "$( rigLine workspace places docs ) / $( rigLine workspace places ws )" "set $rigTmp/docs / set $rigWs"

echo "-- 3. the CLI services --"
rigAssert "the digest names the CLI service the workspace asks for" "$( rigLine cli workspace SPAWN_CLI_SERVICE )" "set claude"
rigAssert "the harness tier and the wait round of the workspace are not set, and read missing; the spawn settings are this workspace's own" "$( rigLine cli workspace SPAWN_HARNESS_TIER ) / $( rigLine cli workspace WAIT_ROUND_SECONDS ) / $( rigLine cli workspace spawn-settings-workspace )" "missing - / missing - / set $rigWs"
rigAssert "each known CLI has its group, in the console's own order, after the workspace's" "$( rigGroups cli )" "workspace copilot copilot-native claude claude-native grok grok-native scaleway"
rigAssert "control: those are the CLIs the console knows, by its own declaration" "$( LC_ALL=C sed -n 's/^DAGC_KNOWN_CLIS="\(.*\)"$/\1/p' "$rigHere/AgentsConsoleShellScript.template.sh" )" "copilot copilot-native claude claude-native grok grok-native scaleway"
rigAssert "a harness leg has no present line: it lies in sh-lib, beside the tooling" "[$( rigLine cli claude present )] [$( rigLine cli scaleway present )] [$( rigLine cli copilot present )] [$( rigLine cli grok present )]" "[] [] [] []"
rigAssert "of the vendor binaries only copilot is on the path: copilot-native is present, claude-native and grok-native are not" "$( rigLine cli copilot-native present ) / $( rigLine cli claude-native present ) / $( rigLine cli grok-native present )" "set $rigTmp/bin/copilot / missing - / missing -"
rigAssert "the credentials a leg reads are named, each set or not, and never shown: of claude's two one is set" "$( rigLine cli claude ANTHROPIC_API_KEY ) / $( rigLine cli claude CLAUDE_CODE_OAUTH_TOKEN )" "secret-set - / secret-missing -"
rigAssert "a leg with one of its credentials set is usable, one with none is not; a vendor CLI is usable where its binary is" "$( rigLine cli claude usable ) / $( rigLine cli copilot usable ) / $( rigLine cli grok usable ) / $( rigLine cli copilot-native usable ) / $( rigLine cli claude-native usable )" "set yes / missing no / missing no / set yes / missing no"
rigAssert "each CLI has its wait round: the vendor claude's own, the safe one of the others" "$( rigLine cli claude-native wait-round ) / $( rigLine cli claude wait-round ) / $( rigLine cli scaleway wait-round )" "set 2700 / set 270 / set 270"

echo "-- 4. the scopes: a scope with no key is left out, a secret is masked, a plain key shows its value --"
rigWant="$( {
	printf 'subject\tscopes\t7\tScope_Settings\n'
	printf 'line\tscopes\tmagic-team\tSLACK_BOT_TOKEN\tsecret-set\t-\tSlack_Bot_Token\n'
	printf 'line\tscopes\tmagic-team\tJIRA_API_TOKEN\tsecret-set\t-\tJira_API_Token\n'
	printf 'line\tscopes\tmagic-team\tSPAWN_CLI_SERVICE\tset\tclaude\tSpawn_CLI_Service\n'
	printf 'line\tscopes\tmagic-team\tMDAT_WORKSPACE_MODE\tset\tteam-rig\tMdat_Workspace_Mode\n'
	printf 'line\tscopes\tmagic-team\tSLACK_CHANNEL_MAGIC_TEAM\tset\tC0RIGTEAM01\tSlack_Channel_Magic_Team\n'
	printf 'line\tscopes\tmagic-team\tSLACK_CHANNEL_HUMAN_OWNER\tset\tU0RIGOWNER1\tSlack_Channel_Human_Owner\n'
	printf 'line\tscopes\tmagic-team\tANTHROPIC_API_KEY\tsecret-set\t-\tAnthropic_API_Key\n'
} )"
rigAssert "the whole subject, byte for byte: the one scope that holds keys, each key in the order of its file, each labelled by the words of its key" "$( rigPart scopes "$rigTmp/out" )" "$rigWant"
rigAssert "the rig has four scope files and three of them are empty: the digest shows one scope" "$( ls "$rigScopes" | LC_ALL=C grep -c -e '\.agent\.env$' ) $( rigGroups scopes )" "4 magic-team"
rigAssert "a key the catalogue marks secret is masked: it reads as set, and nothing of its value is printed" "$( rigLine scopes magic-team SLACK_BOT_TOKEN )" "secret-set -"
rigAssert "a key with the shape of a secret is masked though no catalogue names it, as a key the catalogue marks" "$( . "$rigHere/AgentsTools.OwnerSetupOptionSpec.include" ; AgentsToolsOwnerSetupOptionSpec JIRA_API_TOKEN | LC_ALL=C grep -c . ) $( rigLine scopes magic-team JIRA_API_TOKEN )" "0 secret-set -"
rigAssert "a plain key shows its name and its value" "$( rigLine scopes magic-team SPAWN_CLI_SERVICE )" "set claude"
rigAssert "a line that is a comment is no key, though it holds an assignment" "$( LC_ALL=C grep -c -e '^# SLACK_APP_TOKEN=' "$rigScopes/magic-team.agent.env" ) $( LC_ALL=C grep -c -e 'SLACK_APP_TOKEN' "$rigTmp/out" || : )" "1 0"

echo "-- 5. which key is a secret: every key but one known not to be --"
{
	printf 'WEB_ALLOW_PREFIXES=https://rigbot:%s@docs.rig.example/api/ https://plain.rig.example/\n' "$( rigSecret 11 )"
	printf 'WEB_DENY_PREFIXES=https://tracker.rig.example/\n'
	printf 'SCALEWAY_DEEPSEEK=%s\n' "$( rigSecret 12 )"
	printf 'WAIT_ROUND_SECONDS=600\n'
	printf 'SPAWN_HARNESS_TIER=heavy\n'
} >> "$rigScopes/magic-team.agent.env"
{
	printf 'EMAIL_USER=old@rig.example\n'
	printf 'EMAIL_USER=coordinator@rig.example\n'
	printf 'EMAIL_APP_PASSWORD=%s\n' "$( rigSecret 5 )"
	printf 'EMAIL_IMAP_HOST=imap.rig.example\n'
	printf 'EMAIL_SMTP_PORT=587\n'
	printf 'EMAIL_SMTP_HOST=\n'
	printf 'SLACK_USER_TOKEN=\n'
	printf 'TRELLO_KEY=%s\n' "$( rigSecret 6 )"
	printf 'GOOGLE_CLIENT_ID=rig-client-id.apps.rig.example\n'
	printf 'GOOGLE_CLIENT_SECRET=%s\n' "$( rigSecret 7 )"
	printf 'FIRST_NAME=Rig  The \t Coordinator\n'
	printf 'ODD_SETTING=%s\n' "$( rigSecret 8 )"
	printf 'SESSION_COOKIE=%s\n' "$( rigSecret 9 )"
	printf 'AWS_ACCESS_KEY_ID=%s\n' "$( rigSecret 10 )"
	printf '%s=\n' "$( rigSecret 13 )"
	printf 'lower_key=shown-nowhere\n'
} > "$rigScopes/magic-coordinator.agent.env"
rigTreeBefore="$( rigTree )"
rigRun "$rigOp"
cp "$rigTmp/out" "$rigTmp/whole"
rigAssert "the call ends 0, with no error and no warning, and now shows two scopes" "$rigRc $( rigTroubles ) $( rigGroups scopes )" "0 0 magic-coordinator magic-team"
rigAssert "a key the catalogue marks secret is masked though its name has no shape of one" "$( rigLine scopes magic-team SCALEWAY_DEEPSEEK )" "secret-set -"
rigAssert "a password, a key and a secret of a member's scope, which no catalogue names, are masked" "$( rigLine scopes magic-coordinator EMAIL_APP_PASSWORD ) / $( rigLine scopes magic-coordinator TRELLO_KEY ) / $( rigLine scopes magic-coordinator GOOGLE_CLIENT_SECRET ) / $( rigLine scopes magic-coordinator SESSION_COOKIE )" "secret-set - / secret-set - / secret-set - / secret-set -"
rigAssert "a key of a kind not met before is a secret: nothing says it is not" "$( rigLine scopes magic-coordinator ODD_SETTING )" "secret-set -"
rigAssert "a key that holds the word of a secret is one, though its last word is a plain kind" "$( rigLine scopes magic-coordinator AWS_ACCESS_KEY_ID )" "secret-set -"
rigAssert "a password inside a URL is masked under a key the catalogue marks plain, and a URL with none is shown" "$( rigLine scopes magic-team WEB_ALLOW_PREFIXES ) / $( rigLine scopes magic-team WEB_DENY_PREFIXES )" "secret-set - / set https://tracker.rig.example/"
rigAssert "a name, a host, a number and an id are no secrets, and show their values" "$( rigLine scopes magic-coordinator EMAIL_USER ) / $( rigLine scopes magic-coordinator EMAIL_IMAP_HOST ) / $( rigLine scopes magic-coordinator EMAIL_SMTP_PORT ) / $( rigLine scopes magic-coordinator GOOGLE_CLIENT_ID )" "set coordinator@rig.example / set imap.rig.example / set 587 / set rig-client-id.apps.rig.example"
rigAssert "a key written twice is one line, with the value the reader gives: the last" "$( LC_ALL=C grep -c -e '^EMAIL_USER=' "$rigScopes/magic-coordinator.agent.env" ) $( rigLine scopes magic-coordinator EMAIL_USER | LC_ALL=C grep -c . )" "2 1"
rigAssert "a value's own whitespace reads _, a run of it as one" "$( rigLine scopes magic-coordinator FIRST_NAME )" "set Rig_The_Coordinator"
rigAssert "a key with no value reads missing, and a secret with none secret-missing: each with the value -" "$( rigLine scopes magic-coordinator EMAIL_SMTP_HOST ) / $( rigLine scopes magic-coordinator SLACK_USER_TOKEN )" "missing - / secret-missing -"
rigAssert "a line whose name is not a setting's is never listed, whatever stands ahead of its =: a secret pasted with an = at its end, a name in small letters" "$( LC_ALL=C grep -c -e '^lower_key=' -e 'RIGSECRET13.*=$' "$rigScopes/magic-coordinator.agent.env" ) $( LC_ALL=C grep -c -e 'lower_key' -e 'shown-nowhere' "$rigTmp/out" || : ) $( LC_ALL=C awk -F'\t' '$1 == "line" && $2 == "scopes" && $3 == "magic-coordinator" { n++ } END { print n + 0 }' "$rigTmp/out" )" "2 0 13"
rigAssert "and the scope's count of such lines is noted once on standard error, by scope and never by text" "$( rigWhole "$rigTmp/err" "# DistroAgentsTools $rigOp: the scope 'magic-coordinator' holds 2 line(s) whose name is not a setting's -- capital letters, digits and _ -- so they are not listed" ) $( LC_ALL=C grep -c -F -e 'not listed' "$rigTmp/err" || : )" "1 1"
rigAssert "the value of every secret line is -, set or not: not a part of it, not its length" "$( LC_ALL=C awk -F'\t' '$1 == "line" && ( $5 == "secret-set" || $5 == "secret-missing" ) { n++ ; if ( $6 != "-" ) bad++ ; } END { print ( n >= 14 ? "many" : "few:" n ) ":" bad + 0 }' "$rigTmp/out" )" "many:0"
rigAssert "the workspace's own wait round and tier are read: every CLI's round is the one set, and a second leg is usable by its credential" "$( rigLine cli workspace WAIT_ROUND_SECONDS ) / $( rigLine cli workspace SPAWN_HARNESS_TIER ) / $( rigLine cli claude-native wait-round ) / $( rigLine cli grok wait-round ) / $( rigLine cli scaleway SCALEWAY_DEEPSEEK ) $( rigLine cli scaleway SCALEWAY_GEMMA ) $( rigLine cli scaleway usable )" "set 600 / set heavy / set 600 / set 600 / secret-set - secret-missing - set yes"

echo "-- 6. the outside systems: configured or not, with what is lacking by key name --"
rigWant="$( {
	printf 'subject\tsystems\t7\tOutside_Systems\n'
	printf 'line\tsystems\tslack\tmagic-team\tset\tSLACK_WORKSPACE_DOMAIN,SLACK_CHANNEL_EVENT_TRACK,SLACK_CHANNEL_EVENT_ALERT\tScope_magic-team\n'
	printf 'line\tsystems\tslack\tmagic-coordinator\tmissing\tSLACK_USER_TOKEN\tScope_magic-coordinator\n'
	printf 'line\tsystems\temail\tmagic-coordinator\tset\tEMAIL_SMTP_HOST\tScope_magic-coordinator\n'
	printf 'line\tsystems\tjira\tmagic-team\tset\t-\tScope_magic-team\n'
	printf 'line\tsystems\tconfluence\tmagic-team\tmissing\tCONFLUENCE_SPACE\tScope_magic-team\n'
	printf 'line\tsystems\ttrello\tmagic-coordinator\tset\t-\tScope_magic-coordinator\n'
	printf 'line\tsystems\tgoogle\tmagic-coordinator\tset\t-\tScope_magic-coordinator\n'
} )"
rigAssert "the whole subject, byte for byte: each system in the tooling's own order, the team's own Slack first, each scope that holds it as set or missing, with the keys it lacks" "$( rigPart systems "$rigTmp/out" )" "$rigWant"
rigAssert "the team's own Slack is configured, and lacks three keys of the catalogue, named in its order" "$( rigLine systems slack magic-team )" "set SLACK_WORKSPACE_DOMAIN,SLACK_CHANNEL_EVENT_TRACK,SLACK_CHANNEL_EVENT_ALERT"
rigAssert "a scope whose only key of a system is empty is not configured for it, and the key is named" "$( rigLine systems slack magic-coordinator )" "missing SLACK_USER_TOKEN"
rigAssert "a setting of the catalogue that no scope holds is named as lacking where the catalogue keeps it" "$( rigLine systems confluence magic-team )" "missing CONFLUENCE_SPACE"
rigAssert "control: those are the outside systems the tooling knows, in its own order" "$( rigGroups systems ) / $( LC_ALL=C sed -n 's/^agentsMemberSettingSystems="\(.*\)"$/\1/p' "$rigHere/AgentsTools.MemberWorkspace.include" )" "slack email jira confluence trello google / SLACK EMAIL JIRA CONFLUENCE TRELLO GOOGLE"
rigRunIn "$rigTmp/ws-bare" "$rigOp" systems
rigAssert "in a workspace with no setting each system reads missing: the team's Slack with every key of the catalogue, a system no catalogue names under no scope" "$rigRc $( rigLine systems slack magic-team ) / $( rigLine systems email - ) / $( rigLine systems trello - )" "0 missing SLACK_BOT_TOKEN,SLACK_WORKSPACE_DOMAIN,SLACK_CHANNEL_MAGIC_TEAM,SLACK_CHANNEL_HUMAN_OWNER,SLACK_CHANNEL_EVENT_TRACK,SLACK_CHANNEL_EVENT_ALERT / missing - / missing -"

echo "-- 7. the main loop and the heartbeat --"
rigRun "$rigOp" loop
rigWant="$( {
	printf 'subject\tloop\t12\tMain_Loop_And_Heartbeat\n'
	printf 'line\tloop\tmain-loop\tstate-file\tset\t%s\tMain_Loop_State_File\n' "$rigAgents/main-loop.state"
	printf 'line\tloop\tmain-loop\tMAIN_LOOP_LAST_OUTCOME\tset\tsucceeded\tMain_Loop_Last_Outcome\n'
	printf 'line\tloop\tmain-loop\tMAIN_LOOP_LAST_ITERATION_UTC\tset\t2026-10-13T00:10:00Z\tMain_Loop_Last_Iteration_UTC\n'
	printf 'line\tloop\tmain-loop\tMAIN_LOOP_CONSECUTIVE_FAILURES\tset\t0\tMain_Loop_Consecutive_Failures\n'
	printf 'line\tloop\tmain-loop\tMAIN_LOOP_CURRENT_DELAY_SECONDS\tset\t29\tMain_Loop_Current_Delay_Seconds\n'
	printf 'line\tloop\tmain-loop\tMAIN_LOOP_TEAM_DATA\tset\tskipped\tMain_Loop_Team_Data\n'
	printf 'line\tloop\tmain-loop\tMAIN_LOOP_TEAM_DATA_CONSECUTIVE_FAILURES\tset\t0\tMain_Loop_Team_Data_Consecutive_Failures\n'
	printf 'line\tloop\theartbeat\tstate-note\tset\t%s\tHeartbeat_State_Note\n' "$rigNote"
	printf 'line\tloop\theartbeat\tstate\tset\theartbeat-running\tHeartbeat_State\n'
	printf 'line\tloop\theartbeat\trecheck-date\tset\t2099-01-01_00:00_+0000\tHeartbeat_Recheck_Date\n'
	printf 'line\tloop\theartbeat\tlast-iteration-timestamp\tset\t2026-10-12T19:54:21Z\tHeartbeat_Last_Iteration\n'
	printf 'line\tloop\theartbeat\trunning\tset\tyes\tHeartbeat_Running\n'
} )"
rigAssert "the whole subject, byte for byte: the main loop by what its last iteration left, the heartbeat by its note, running while its lock is held" "$rigRc $( cat "$rigTmp/out" )" "0 $rigWant"
rigNoteWrite heartbeat-running '2026-10-01 00:00 +0000'
rigRun "$rigOp" loop
rigAssert "a heartbeat whose lock has gone stale does not run: its recheck date is long past" "$( rigLine loop heartbeat state ) / $( rigLine loop heartbeat running )" "set heartbeat-running / missing no"
rigNoteWrite heartbeat-finished '2099-01-01 00:00 +0000'
rigRun "$rigOp" loop
rigAssert "a heartbeat that has finished does not run, whatever its recheck date" "$( rigLine loop heartbeat state ) / $( rigLine loop heartbeat running )" "set heartbeat-finished / missing no"
rigRunIn "$rigTmp/ws-bare" "$rigOp" loop
rigAssert "a workspace that is no team rig says nothing of the main loop: it was its own case that each line reads missing, with the path it would have, before only a team rig had a main loop" "$rigRc $( cat "$rigTmp/out" | LC_ALL=C tr '\t' ' ' | LC_ALL=C tr '\n' '/' )" "0 "
rigNoteWrite heartbeat-running '2099-01-01 00:00 +0000'
## The mode of the workspace, the one setting the main loop follows: only a team rig has it.
rigModeFile="$( cat "$rigScopes/magic-team.agent.env" )"
rigRun "$rigOp" workspace
rigAssert "the mode is the one the installer set in the settings of the team, a team rig, and it is no full team rig while its team data has no git remote" "$( rigLine workspace mode MDAT_WORKSPACE_MODE ) / $( rigLine workspace mode full-team-rig )" "set team-rig / missing no"
printf '%s\nTEAM_DATA_GIT_REMOTE=git@rig.invalid:team-data.git\n' "$rigModeFile" > "$rigScopes/magic-team.agent.env"
rigRun "$rigOp" workspace
rigAssert "a team rig whose team data has a git remote is a full team rig" "$( rigLine workspace mode full-team-rig )" "set yes"
printf '%s\n' "$rigModeFile" | LC_ALL=C sed -e 's/^MDAT_WORKSPACE_MODE=team-rig$/MDAT_WORKSPACE_MODE=rig-client/' > "$rigScopes/magic-team.agent.env"
rigRun "$rigOp" loop
rigAssert "a remote rig client acts as just agents for now: nothing of the main loop, not even its subject" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" "0 0"
printf '%s\n' "$rigModeFile" | LC_ALL=C sed -e 's/^MDAT_WORKSPACE_MODE=team-rig$/MDAT_WORKSPACE_MODE=nonesuch/' > "$rigScopes/magic-team.agent.env"
rigRun "$rigOp" workspace
rigAssert "a mode that is none of the three is no mode: the workspace is just agents, by default" "$( LC_ALL=C awk -F'\t' '$1 == "line" && $3 == "mode" && $4 == "MDAT_WORKSPACE_MODE" { print $5, $6 }' "$rigTmp/out" )" "set just-agents"
printf '%s\n' "$rigModeFile" > "$rigScopes/magic-team.agent.env"
rigRunIn "$rigTmp/ws-bare" "$rigOp" workspace loop
rigAssert "a workspace whose installer set no mode is just agents, by default, and the digest says nothing of the main loop there, not even its subject" "$rigRc $( LC_ALL=C awk -F'\t' '$1 == "subject" { printf "%s ", $2 }' "$rigTmp/out" )/ $( rigLine workspace mode MDAT_WORKSPACE_MODE ) / $( rigLine workspace mode full-team-rig )" "0 workspace / set just-agents / missing no"

echo "-- 8. one subject, or some, by name --"
rigSubjectsBad=""
for rigSubject in workspace cli systems loop scopes interface console control ; do
	rigRun "$rigOp" "$rigSubject"
	[ "$rigRc" = 0 ] && [ "$( cat "$rigTmp/out" )" = "$( rigPart "$rigSubject" "$rigTmp/whole" )" ] && [ -n "$( cat "$rigTmp/out" )" ] || rigSubjectsBad="$rigSubjectsBad $rigSubject"
done
rigAssert "each subject asked alone is printed alone, byte for byte as it stands in the whole digest" "${rigSubjectsBad:- each alone}" " each alone"
rigRun "$rigOp" scopes workspace
rigAssert "several names print those subjects, in the one order whatever the order given" "$rigRc $( LC_ALL=C awk -F'\t' '$1 == "subject" { printf "%s ", $2 }' "$rigTmp/out" )" "0 workspace scopes "
rigRun "$rigOp" workspace cli systems loop scopes interface console control
rigAssert "all eight names print the whole digest" "$( cat "$rigTmp/out" )" "$( cat "$rigTmp/whole" )"
rigRun "$rigOp" nonesuch
rigAssert "a name that is none of the subjects refuses the call, rc 1, nothing on stdout, in one line that lists them" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: 'nonesuch' is none of its subjects -- nothing was printed. Its subjects: workspace, cli, systems, loop, scopes, interface, console, control" )" "1 0 1"
rigRun "$rigOp" scopes --all
rigAssert "and so does an option it does not take, after a name it has: before anything is printed" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: '--all' is none of its subjects -- nothing was printed. Its subjects: workspace, cli, systems, loop, scopes, interface, console, control" )" "1 0 1"

echo "-- 9. it only reads --"
rigRunIn "$rigTmp/ws-bare" "$rigOp"
rigAssert "a workspace with no setting at all still has its digest: seven subjects, no main loop since it is no team rig, no scope, no CLI asked for, and its team data not there yet" "$rigRc $( LC_ALL=C awk -F'\t' '$1 == "subject" { printf "%s ", $2 }' "$rigTmp/out" )/ $( rigPart scopes "$rigTmp/out" | LC_ALL=C tr '\t' ' ' ) / $( rigLine cli workspace SPAWN_CLI_SERVICE ) / $( rigLine workspace paths team-data-root )" "0 workspace cli systems scopes interface console control / subject scopes 0 Scope_Settings / missing - / missing $rigTmp/ws-bare/.local/agents/team-data-root"
rigAssert "no call so far wrote, made or removed a file of the rig: its workspaces, its home, its skills and its place are as they were" "$( rigTree )" "$rigTreeBefore"
rigAssert "the include never asks the reader for every line of a scope, the form that prints a secret like any value" "$( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/AgentsTools.ManagerConfig.include" | LC_ALL=C grep -c -e '--select-all' -e '--select --all' -e '--all' || : ) $( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/AgentsTools.ManagerConfig.include" | LC_ALL=C grep -c -e '--select "' | LC_ALL=C awk '{ print ( $1 > 0 ) ? "one-key-a-call" : "no-read" }' )" "0 one-key-a-call"
rigAssert "and the digest writes no setting: the include names six forms of the reader that change one, a save and a removal in the scope of the current user, of the team and of the workspace, all of them for the one writer of a declared setting (AgentsManagerConfigSetCheck)" "$( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/AgentsTools.ManagerConfig.include" | LC_ALL=C grep -c -e '--upsert' -e '--delete' || : ) $( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/AgentsTools.ManagerConfig.include" | LC_ALL=C grep -e '--upsert' -e '--delete' | LC_ALL=C grep -c -v -F -e '--custom-config-option --upsert' -e '--agents-config-option magic-team --upsert' -e '--system-config-option --upsert' -e '--system-config-option --delete' -e '--custom-config-option --delete' -e '--agents-config-option magic-team --delete' || : )" "6 0"

echo "-- 10. the place of the operation in its family --"
rigPre=( "MDAT_SPAWN_AGENT=keeper-rig" )
rigRun "$rigOp"
rigPre=()
rigAssert "from inside a member's session it is refused, rc 1, nothing on stdout, by the one rule of the family" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "DistroAgentsTools: ${rigOp#--}: ⛔ ERROR: this session acts as keeper-rig, and a --manager-* operation is the console's own, never run from inside a member's session -- nothing was done" )" "1 0 1"
rigRun --manager-config-no-such
rigAssert "an operation its subject does not have is refused by name, rc 1" "$rigRc $( rigWhole "$rigTmp/err" "DistroAgentsTools: ⛔ ERROR: invalid option: --manager-config-no-such" )" "1 1"
rigAssert "the family's include has one arm for the settings, which sources their include" "$( LC_ALL=C grep -c -x -e '	--manager-config-\*)' "$rigHere/AgentsTools.Manager.include" || : ) $( LC_ALL=C grep -c -F -e '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.ManagerConfig.include"' "$rigHere/AgentsTools.Manager.include" || : )" "1 1"
rigPre=( "MDSC_DETAIL=1" )
rigRun "$rigOp" scopes
rigPre=()
rigAssert "with the detail of the dispatcher on, the digest is the same" "$rigRc $( cat "$rigTmp/out" )" "0 $( rigPart scopes "$rigTmp/whole" )"

echo "-- 11. the help pair --"
rigHelpInclude="$rigHere/help/Help.DistroAgentsTools.include"
rigHelpMd="$rigHere/help/Help.DistroAgentsTools.help.md"
rigSyntax="📘 syntax: DistroAgentsTools.fn.sh $rigOp [--full] [<subject>...]"
rigEntry(){ ## -- the operation's entry in the help.md, from under its heading to the next operation's
	LC_ALL=C awk -v head="$( printf '\t\t%s [--full] [<subject>...]' "$rigOp" )" '$0 == head { on = 1 ; next } on && /^\t\t--/ { exit } on { print }' "$rigHelpMd"
}
rigAssert "the operation has its syntax echo, its syntax line and its entry, once each, and in no other form" "$( LC_ALL=C grep -c -x -F -- "echo \"$rigSyntax\" >&2" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -x -F -- "$rigSyntax" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -x -F -- "$( printf '\t\t%s [--full] [<subject>...]' "$rigOp" )" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -F -- "syntax: DistroAgentsTools.fn.sh $rigOp" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -F -- "syntax: DistroAgentsTools.fn.sh $rigOp" "$rigHelpMd" || : )" "1 1 1 1 1"
rigForm(){ ## row kind -- the form line of that row in the entry, its back quotes and its indent taken off
	rigEntry | LC_ALL=C sed -n -e 's/^[[:space:]]*`\('"$1"' <.*>\)`$/\1/p'
}
rigAssert "its entry gives the form of each of the two rows" "$( rigForm subject ) | $( rigForm line )" "subject <subject> <lines> <label> | line <subject> <group> <key> <state> <value> <label>"
rigRun "$rigOp"
rigAssert "and every row printed has exactly the fields its form names, a line of the interface apart, whose own form has two more" "$( for rigKind in subject line ; do LC_ALL=C awk -F'\t' -v wantKind="$rigKind" -v wantFields="$( rigForm "$rigKind" | LC_ALL=C awk '{ print NF }' )" '$1 == wantKind && !( $1 == "line" && $2 == "interface" ) { rows++ ; if ( NF != wantFields ) bad++ ; } END { printf "%s:%s ", ( rows > 0 ? "rows" : "none" ), bad + 0 }' "$rigTmp/out" ; done )" "rows:0 rows:0 "
rigAssert "the entry names the eight subjects and the four states" "$( for rigWord in workspace cli systems loop scopes interface console control set missing secret-set secret-missing ; do rigEntry | LC_ALL=C grep -c -F -- "\`$rigWord\`" | LC_ALL=C awk '{ printf "%s", ( $1 > 0 ) ? "y" : "n" }' ; done )" "yyyyyyyyyyyy"
rigAssert "the entry names every plain kind the rule of a secret takes, each word of the include's own list" "$( rigPlainBad="" ; for rigWord in $( LC_ALL=C sed -n 's/^agentsManagerConfigPlainWords="\(.*\)"$/\1/p' "$rigHere/AgentsTools.ManagerConfig.include" ) ; do rigEntry | LC_ALL=C tr -s ' \t\n,.' ' ' | LC_ALL=C grep -q -e " $rigWord " || rigPlainBad="$rigPlainBad $rigWord" ; done ; printf '%s' "${rigPlainBad:- each named}" ) $( LC_ALL=C sed -n 's/^agentsManagerConfigPlainWords="\(.*\)"$/\1/p' "$rigHere/AgentsTools.ManagerConfig.include" | LC_ALL=C awk '{ print NF }' )" " each named 18"
rigAssert "the entry says that nothing of a secret is printed, and that the call only reads" "$( rigEntry | LC_ALL=C tr -s ' \t\n' ' ' | LC_ALL=C grep -c -F -e 'Nothing of the value of a secret is printed' || : ) $( rigEntry | LC_ALL=C tr -s ' \t\n' ' ' | LC_ALL=C grep -c -F -e 'It only reads' || : )" "1 1"
rigAssert "control: the entry was cut up to the next operation's heading" "$( rigEntry | LC_ALL=C grep -c -F -- 'TAB-separated' || : ) $( rigEntry | LC_ALL=C grep -c -F -- '--manager-session-list' || : )" "1 0"
rigRun --help-syntax
rigAssert "--help-syntax prints its line, once" "$rigRc $( LC_ALL=C grep -c -x -F -- "$rigSyntax" "$rigTmp/err" || : )" "0 1"

echo "-- 12. the labels: what a screen calls each subject and each line --"
rigInclude="$rigHere/AgentsTools.ManagerConfig.include"
rigLabel(){ ## file, subject, group, key -- the label of that line in the file: its last field
	LC_ALL=C awk -F'\t' -v wantSubject="$2" -v wantGroup="$3" -v wantKey="$4" '$1 == "line" && $2 == wantSubject && $3 == wantGroup && $4 == wantKey { print $NF ; }' "$1"
}
rigLabelRule(){ ## file -- its rows against the rule of a label: `rows:<how many break it>`, `few` ahead of the colon where the file holds too few rows to say
	LC_ALL=C awk -F'\t' '$1 == "subject" || $1 == "line" {
		rows++ ; label = $NF ; words = split( label, word, "_" )
		named = ( $1 == "line" && ( ( $2 == "workspace" && $3 == "places" ) || ( $2 == "systems" && $4 != "-" ) ) ) ? 1 : 0
		if ( label == "-" || words < 2 || label !~ /^[A-Z]/ || ( $1 == "line" && label == $4 ) ) { bad++ ; next }
		for ( at = 1 ; at <= words - named ; at++ ) if ( word[at] !~ /^[A-Z0-9]/ ) { bad++ ; break }
	} END { print ( rows > 20 ? "rows" : "few" ) ":" bad + 0 }' "$1"
}
## The one declaration, as the include holds it, and the words it writes in capitals: what the controls below
## give the labeller, with a line of their own making.
rigTable="$( LC_ALL=C sed -n '/^agentsManagerConfigLabels="/,/"$/p' "$rigInclude" | LC_ALL=C sed -e 's/^agentsManagerConfigLabels="//' -e 's/"$//' )"
rigCapitals="$( LC_ALL=C sed -n 's/^agentsManagerConfigLabelCapitals="\(.*\)"$/\1/p' "$rigInclude" )"
rigNamed(){ ## subject, group, key -- the label the declaration gives a line of that name, by the labeller itself
	{ printf '%s\n' "$rigTable" ; printf '\034\n' ; printf 'line\t%s\t%s\t%s\tset\tx\n' "$1" "$2" "$3" ; } | LC_ALL=C awk -v capitals="$rigCapitals" -f "$rigHere/AgentsManagerConfigLabels.awk" 2> /dev/null | LC_ALL=C awk -F'\t' '{ print $NF }'
}
rigAssert "each subject row ends with its label" "$( LC_ALL=C awk -F'\t' '$1 == "subject" { printf "%s=%s ", $2, $NF }' "$rigTmp/whole" )" "workspace=Workspace_Paths cli=CLI_Services systems=Outside_Systems loop=Main_Loop_And_Heartbeat scopes=Scope_Settings interface=Interface_Settings console=Console_Behaviour control=Session_Control "
rigRun "$rigOp"
cp "$rigTmp/out" "$rigTmp/whole-late"
rigRunIn "$rigTmp/ws-bare" "$rigOp"
rigAssert "every row has a label that keeps the rule, in the first digest, in the last and in that of a workspace with no setting: none is absent, none is one word, none is the bare key, each begins with a capital letter and so does each of its words, the name of a place or of a scope apart" "$( rigLabelRule "$rigTmp/whole" ) $( rigLabelRule "$rigTmp/whole-late" ) $( rigLabelRule "$rigTmp/out" )" "rows:0 rows:0 rows:0"
rigAssert "a system that no scope holds has its one line labelled so" "$( rigLabel "$rigTmp/out" systems email - )" "No_Scope_Configured"
rigAssert "the paths of the workspace, and a registered place by its name" "$( for rigOne in workspace-root tooling-origin team-data-root session-records session-stores settings ; do printf '%s ' "$( rigLabel "$rigTmp/whole" workspace paths "$rigOne" )" ; done )/ $( rigLabel "$rigTmp/whole" workspace places docs )" "Workspace_Root Tooling_Origin Team_Data_Root Session_Records Session_Stores Scope_Settings_Folder / Registered_Place_docs"
rigAssert "what the workspace asks of its CLI services, and the lines of one CLI, a credential by the words of its key" "$( for rigOne in SPAWN_CLI_SERVICE SPAWN_HARNESS_TIER WAIT_ROUND_SECONDS spawn-settings-workspace ; do printf '%s ' "$( rigLabel "$rigTmp/whole" cli workspace "$rigOne" )" ; done )/ $( printf '%s ' "$( rigLabel "$rigTmp/whole" cli claude-native present )" ; for rigOne in ANTHROPIC_API_KEY usable wait-round ; do printf '%s ' "$( rigLabel "$rigTmp/whole" cli claude "$rigOne" )" ; done )" "Spawn_CLI_Service Spawn_Harness_Tier Wait_Round_Seconds Spawn_Settings_Workspace / CLI_Present Anthropic_API_Key CLI_Usable CLI_Wait_Round "
rigAssert "the main loop, what its state file holds by the words of the key, and the heartbeat" "$( rigLabel "$rigTmp/whole" loop main-loop state-file ) $( rigLabel "$rigTmp/whole" loop main-loop MAIN_LOOP_LAST_ITERATION_UTC ) / $( for rigOne in state-note state recheck-date last-iteration-timestamp running ; do printf '%s ' "$( rigLabel "$rigTmp/whole" loop heartbeat "$rigOne" )" ; done )" "Main_Loop_State_File Main_Loop_Last_Iteration_UTC / Heartbeat_State_Note Heartbeat_State Heartbeat_Recheck_Date Heartbeat_Last_Iteration Heartbeat_Running "
rigAssert "the style of the interface by its own name, and the key of every line still in its own field: the lines are found by the keys they had" "$( rigLabel "$rigTmp/whole" interface style MDAT_MANAGER_STYLE ) $( rigLabel "$rigTmp/whole-late" scopes magic-coordinator EMAIL_SMTP_PORT )" "Interface_Style Email_SMTP_Port"
rigAssert "the include has the one declaration of the labels, and the labels come from it: control, a line it has no row for gets the label -, which the rule above fails" "$( LC_ALL=C grep -c -e '^agentsManagerConfigLabels="' "$rigInclude" || : ) $( printf '%s\n' "$rigTable" | LC_ALL=C grep -c -e '|' | LC_ALL=C awk '{ print ( $1 > 20 ) ? "rows" : "few" }' ) [$( rigNamed workspace paths no-such-line )] [$( rigNamed loop heartbeat no-such-header )] [$( rigNamed nonesuch any ANY_KEY )] [$( rigNamed workspace paths workspace-root )]" "1 rows [-] [-] [-] [Workspace_Root]"
rigAssert "the rule of a key's own words: a key of one word gets a second, an empty word is none, a word of the include's list stands in capitals" "$( rigNamed scopes any-scope PORT ) $( rigNamed scopes any-scope KEY_2__URL ) $( rigNamed cli any-cli XAI_API_KEY ) [$rigCapitals]" "Port_Setting Key_2_URL XAI_API_Key [API CLI ID IMAP SMTP URL UTC XAI]"
rigAssert "every line the include prints under a key of its own has its own row in the declaration, none left to a row for any key: each key it names where it makes a line, and each key the workspace asks its CLI services by" "$( rigLacking="" ; rigCount=0 ; while read -r rigOwner rigOne ; do [ -n "$rigOne" ] || continue ; rigCount=$(( rigCount + 1 )) ; printf '%s\n' "$rigTable" | LC_ALL=C grep -q -e "^$rigOwner|[^|]*|$rigOne|." || rigLacking="$rigLacking $rigOwner/$rigOne" ; done <<< "$( { LC_ALL=C sed -n 's/^.*AgentsToolsManagerConfig\(Path\)\{0,1\}Line \([a-z][a-z]*\) [^ ]* \([a-z][a-z-]*\) .*$/\2 \3/p' "$rigInclude" ; LC_ALL=C sed -n 's/^	for cliKey in \([A-Z_ ]*\) ; do$/\1/p' "$rigInclude" | LC_ALL=C tr ' ' '\n' | LC_ALL=C sed -e 's/^/cli /' ; } | LC_ALL=C sort -u )" ; printf '%s%s' "$( [ "$rigCount" -ge 16 ] && echo many || echo "few:$rigCount" )" "${rigLacking:- none-lacking}" )" "many none-lacking"
rigAssert "the entry of the help says what a label is, and names the label of each subject" "$( rigEntry | LC_ALL=C grep -c -F -e '<label> is what a screen calls' || : ) $( for rigWord in 'Workspace Paths' 'CLI Services' 'Outside Systems' 'Main Loop And Heartbeat' 'Scope Settings' 'Interface Settings' 'Console Behaviour' 'Session Control' ; do rigEntry | LC_ALL=C grep -c -F -- "\`$rigWord\`" | LC_ALL=C awk '{ printf "%s", ( $1 > 0 ) ? "y" : "n" }' ; done )" "1 yyyyyyyy"

echo "-- 13. each line in full: its description, and whether it can be changed --"
rigRun "$rigOp" --full
cp "$rigTmp/out" "$rigTmp/full"
rigFullRc="$rigRc $( rigTroubles )"
rigRun "$rigOp"
rigAssert "asked in full the digest ends 0 with no error, and every line has fifteen fields, none empty and none with a blank; a subject row keeps its four, and a group row has five" "$rigFullRc $( LC_ALL=C awk -F'\t' '{ want = ( $1 == "subject" ) ? 4 : ( $1 == "line" ) ? 15 : ( $1 == "group" ) ? 5 : -1 ; if ( NF != want ) bad++ ; for ( at = 1 ; at <= NF ; at++ ) if ( $at == "" || $at ~ / / ) bad++ ; } END { print ( NR > 20 ? "rows" : "few" ) ":" bad + 0 }' "$rigTmp/full" )" "0 0 rows:0"
rigAssert "the first seven fields of a line in full are the line as it is printed without it, its six and its label, and the subjects and the order of the rows are the same" "$( LC_ALL=C awk -F'\t' -v OFS='\t' '$1 == "group" { next } $1 == "subject" { print ; next } { print $1, $2, $3, $4, $5, $6, $7 }' "$rigTmp/full" | cksum )" "$( LC_ALL=C awk -F'\t' -v OFS='\t' '$1 == "subject" { print ; next } { print $1, $2, $3, $4, $5, $6, $NF }' "$rigTmp/out" | cksum )"
rigAssert "every line has a description: plain sentences of five words or more that end with a full stop, with nothing of a value in them, no digit, no path and no assignment" "$( LC_ALL=C awk -F'\t' '$1 == "line" { rows++ ; words = split( $8, word, "_" ) ; if ( $8 == "-" || words < 5 || $8 !~ /\.$/ || $8 ~ /[0-9\/=]/ ) bad++ ; } END { print ( rows > 20 ? "rows" : "few" ) ":" bad + 0 }' "$rigTmp/full" )" "rows:0"
rigAssert "the lines that can be changed are the declared few, each with its kind and its scope, where its value comes from, what it takes and where it is saved, and each belongs to the settings" "$( LC_ALL=C awk -F'\t' '$1 == "line" && $9 == "yes" { printf "%s:%s:%s ", $4, $10, $11 ; if ( $12 == "-" || $13 == "-" || $14 == "-" || $15 != "settings" ) bad++ } END { print "/ " bad + 0 }' "$rigTmp/full" )" "MDAT_MANAGER_STYLE:choice:user MDLT_CONSOLE_HISTORY:choice:user MDLT_CONSOLE_ORIGIN:choice:workspace MDLT_CONSOLE_DETAIL:choice:user SESSION_CONTROL_REQUEST_SECONDS:number:workspace SESSION_CONTROL_KILL_SECONDS:number:workspace / 0"
rigAssert "every other line belongs to the configuration and cannot be changed, with the one reason and none of the fields of a change: a path, a place, a CLI, a system, the loop, a scope, a secret, what is measured" "$( LC_ALL=C awk -F'\t' '$1 == "line" && $9 != "yes" && !( $2 == "workspace" && $4 == "MDAT_WORKSPACE_MODE" ) { rows++ ; if ( $9 != "no:set_at_deployment:_a_wizard_will_change_it" || $10 $11 $12 $13 $14 != "-----" || $15 != "configuration" ) bad++ ; subjects[$2] = 1 } END { for ( name in subjects ) seen++ ; print ( rows > 20 ? "rows" : "few" ) ":" bad + 0, seen + 0 }' "$rigTmp/full" )" "rows:0 5"
rigAssert "the mode of the workspace is a line of the configuration with the fields of a change, its kind, its scope, where it comes from, what it takes and its file, the settings of the team, and it is not changed from here either" "$( LC_ALL=C awk -F'\t' '$1 == "line" && $2 == "workspace" && $4 == "MDAT_WORKSPACE_MODE" { print $2, $3, $5, $6, $9, $10, $11, $12, $13, $14, $15 }' "$rigTmp/full" )" "workspace mode set team-rig no:set_at_deployment:_a_wizard_will_change_it choice workspace workspace just-agents=Just_Agents,rig-client=Remote_Rig_Client,team-rig=Team_Rig $rigScopes/magic-team.agent.env configuration"
rigAssert "in the one declaration every row of a line says which of the two it belongs to and has its description beside its label, a row for any key among them, and the row of a subject and the row of a group have neither: a line cannot come without them" "$( printf '%s\n' "$rigTable" | LC_ALL=C awk -F'|' 'NF > 1 { rows++ ; own = ( $3 == "" ) ; words = split( $6, word, " " ) ; if ( own ? ( $5 $6 != "" ) : ( ( $5 != "settings" && $5 != "configuration" ) || words < 5 || $6 !~ /\.$/ ) ) bad++ ; } END { print ( rows > 30 ? "rows" : "few" ) ":" bad + 0 }' )" "rows:0"
rigAssert "the rows that belong to the settings are the rows of the declaration of the changeable settings, each and no other: what the writer takes and what is offered for a change are one list" "$( printf '%s\n' "$rigTable" | LC_ALL=C awk -F'|' '$5 == "settings" { print $1 "|" $2 "|" $3 }' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "$( LC_ALL=C sed -n '/^agentsManagerConfigSettings="/,/"$/p' "$rigInclude" | LC_ALL=C sed -e 's/^agentsManagerConfigSettings="//' -e 's/"$//' | LC_ALL=C awk -F'|' 'NF > 3 { print $1 "|" $2 "|" $3 }' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )"
rigAssert "in full each group of a subject has a row of its own ahead of its lines: the subject, the group as its lines carry it, how many lines it has, and its label; every line stands under the row of its own group, and the row counts them" "$( LC_ALL=C awk -F'\t' '$1 == "subject" { if ( said != seen ) bad++ ; said = 0 ; seen = 0 ; now = "" ; next } $1 == "group" { if ( said != seen ) bad++ ; groups++ ; subject = $2 ; now = $3 ; said = $4 ; seen = 0 ; next } $1 == "line" { if ( $2 != subject || $3 != now ) bad++ ; seen++ } END { if ( said != seen ) bad++ ; print ( groups > 10 ? "groups" : "few" ) ":" bad + 0 }' "$rigTmp/full" )" "groups:0"
rigGroup(){ ## subject, group -- the label of that group in the digest in full
	LC_ALL=C awk -F'\t' -v wantSubject="$1" -v wantGroup="$2" '$1 == "group" && $2 == wantSubject && $3 == wantGroup { print $5 }' "$rigTmp/full"
}
rigAssert "a group that is a word of the tooling's has a label of capitalised words, more than one, true to what it holds" "$( rigGroup workspace paths ) $( rigGroup workspace places ) $( rigGroup workspace mode ) $( rigGroup cli workspace ) $( rigGroup loop main-loop ) $( rigGroup loop heartbeat ) $( rigGroup interface style ) $( rigGroup console history ) $( rigGroup console origin ) $( rigGroup console detail ) $( rigGroup control request ) $( rigGroup control kill )" "Workspace_Folders Registered_Places Workspace_Role Workspace_Defaults Main_Loop_State Heartbeat_State Screen_Style Shell_History Tooling_Origin Tool_Verbosity Control_Request Control_Kill"
rigAssert "a group that is a name has that name as it is written, not made over: a CLI's, a system's, a scope's" "$( rigGroup cli claude ) $( rigGroup cli claude-native ) $( rigGroup cli scaleway ) $( rigGroup systems slack ) $( rigGroup scopes magic-team )" "claude claude-native scaleway slack magic-team"
rigAssert "no group is without a label, and the label of a group of the tooling's own is never one word: a new group cannot come without one" "$( LC_ALL=C awk -F'\t' '$1 == "group" { rows++ ; if ( $5 == "-" || $5 == "" ) bad++ ; named = ( $2 == "systems" || $2 == "scopes" || ( $2 == "cli" && $3 != "workspace" ) ) ; if ( !named && $5 !~ /^[A-Z][A-Za-z]*(_[A-Z][A-Za-z]*)+$/ ) bad++ } END { print ( rows > 10 ? "groups" : "few" ) ":" bad + 0 }' "$rigTmp/full" ) $( printf '%s\n' "$rigTable" | LC_ALL=C awk -F'|' 'NF > 1 && $2 != "" && $3 == "" { rows++ ; if ( $4 == "" ) bad++ } END { print rows + 0 ":" bad + 0 }' )" "groups:0 15:0"
rigRun "$rigOp" cli
rigAssert "without --full no group row is printed: the rows are as they were" "$rigRc $( LC_ALL=C grep -c -e '^group' "$rigTmp/out" || : )" "0 0"
rigAssert "the entry of the help gives the form of a group's row" "$( rigEntry | LC_ALL=C sed -n -e 's/^[[:space:]]*`\(group <.*>\)`$/\1/p' )" "group <subject> <group> <lines> <label>"
rigRun "$rigOp" --full scopes
rigAssert "in full one subject is printed by its name as without" "$rigRc $( cksum < "$rigTmp/out" )" "0 $( LC_ALL=C awk -F'\t' '$2 == "scopes"' "$rigTmp/full" | cksum )"
rigRun "$rigOp" scopes --full
rigAssert "--full stands first: after a name it is taken for a subject, and refused" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: '--full' is none of its subjects -- nothing was printed. Its subjects: workspace, cli, systems, loop, scopes, interface, console, control" )" "1 0 1"
rigAssert "the entry of the help gives the eight fields a line has more in full, and names the option" "$( rigEntry | LC_ALL=C sed -n -e 's/^[[:space:]]*`\(<description> <.*>\)`$/\1/p' ) $( rigEntry | LC_ALL=C grep -c -F -e '`--full`' | LC_ALL=C awk '{ print ( $1 > 0 ) ? "named" : "not-named" }' )" "<description> <change> <kind> <scope> <source> <values> <where> <belongs> named"

echo "-- 14. no secret of the rig stands anywhere in what was printed --"
rigAssert "control: each of the thirteen fake secrets stands in a scope file of the rig, whole" "$( while IFS= read -r rigOne ; do LC_ALL=C grep -l -F -e "$rigOne" "$rigScopes"/*.agent.env > /dev/null 2>&1 && printf y || printf n ; done < "$rigTmp/secrets" )" "yyyyyyyyyyyyy"
rigAssert "control: what every call printed, on both streams, was kept, and a plain value of the rig stands in it" "$( LC_ALL=C grep -c -F -e 'coordinator@rig.example' "$rigTmp/all" | LC_ALL=C awk '{ print ( $1 > 0 ) ? "kept" : "lost" }' ) $( LC_ALL=C grep -c -e '^subject' "$rigTmp/all" | LC_ALL=C awk '{ print ( $1 > 20 ) ? "many" : "few" }' )" "kept many"
rigAssert "the mark of the fake secrets stands nowhere in it" "$( LC_ALL=C grep -c -F -e 'RIGSECRET' "$rigTmp/all" || : )" "0"
rigAssert "no head and no tail of a secret stands in it either: six letters of each, at either end" "$( while IFS= read -r rigOne ; do printf '%s\n%s\n' "$( printf '%s' "$rigOne" | LC_ALL=C cut -c1-6 )" "$( printf '%s' "$rigOne" | LC_ALL=C cut -c18-23 )" ; done < "$rigTmp/secrets" > "$rigTmp/fragments" ; LC_ALL=C awk 'length( $0 ) == 6 { n++ } END { print n + 0 }' "$rigTmp/fragments" ) $( LC_ALL=C grep -c -F -f "$rigTmp/fragments" "$rigTmp/all" || : )" "26 0"
rigAssert "no run of this check issued a request" "$( [ -e "$rigTmp/curl.calls" ] && wc -l < "$rigTmp/curl.calls" | LC_ALL=C tr -d ' ' || echo 0 )" "0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MANAGER CONFIG DIGEST CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_CONFIG_DIGEST: OK (%d assertions, offline)\n' "$rigPasses"
