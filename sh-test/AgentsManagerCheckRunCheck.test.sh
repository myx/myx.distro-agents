#!/usr/bin/env bash
## Behavioural check on --manager-check-run, which shows what the owner's own check of the setup says, run rather
## than read. THE CHECK ITSELF IS NOT RUN HERE: a stand-in of the rig answers `--owner-setup-<domain> --check` for
## each domain with the text that operation prints for a person, so that no CLI, no Slack and no network is asked.
## Held: each result line of a check is one row, with the heading above it, its key, a label of its words, its
## state as the check said it, its reason in the check's own words, a continued line joined, and its remedy as the
## command the check names, blanks kept; a check that printed no result line and a check that does not end are each
## one `skipped` row, the others still answer, and what did not end is ended; --local leaves out the two domains
## whose check asks outside the machine, which are then not started at all; a domain is run alone by its name; one
## row sums them. A word that is no domain is refused, and so is a call from inside a member's session. The arm
## decides nothing: the include holds no check of its own. And the help pair. Offline.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTool="${rigHere%/sh-lib}/sh-scripts/DistroAgentsTools.fn.sh"
rigOp="--manager-check-run"
[ -f "$rigTool" ] || { echo "⛔ ERROR: the tool is not at the origin this workspace resolves -- refusing to report a result" >&2 ; exit 1 ; }
rigTmp="$( mktemp -d -t AgentsManagerCheckRunCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigHome" "$rigSkills"
: > "$rigWs/.local/.agents/keeper-rig.agent.env" ; chmod 770 "$rigWs/.local/.agents" ; chmod 660 "$rigWs/.local/.agents"/*.agent.env
## THE STAND-IN of the owner's check: what each domain's check prints, as the real one prints it. The one that
## hangs sleeps, and has started a sleep of its own that hangs too, under a name of the rig's own, so that what is
## left of it can be told from any other sleep, and for a minute and a half at most: this check sends no signal,
## so what the operation left would end by itself.
ln -s "$( PATH=/bin:/usr/bin command -v sleep )" "$rigTmp/rig-sleep"
cat > "$rigTmp/stand-in" <<RIGSTANDIN
#!/bin/sh
printf '%s\n' "\$*" >> "$rigTmp/stand-in.calls"
case "\$1" in
	--owner-setup-claude)
		printf '%s\n' '# DistroAgentsTools --owner-setup-claude --check: read-only diagnosis (nothing applied)' 'CLAUDE_HARNESS_INSTALLED: OK' '' '## workspace ws-rig' 'SPAWN_CLI_SERVICE: WARN' '  warn: set to another CLI, so this workspace does not run claude' '  fix:  /rig/tool --owner-setup-claude --set-as-default --apply' 'AGENTS_CONSOLE_SCRIPT: FAIL' '  warn: differs from the template it would be regenerated from, so it is' '        behind this release' '  path: /rig/ws/DistroAgentsConsole.sh'
		exit 1 ;;
	--owner-setup-copilot) printf '%s\n' '# a domain with no defined checks' 'copilot has no checks defined yet' ;;
	--owner-setup-grok) "$rigTmp/rig-sleep" 90 & exec "$rigTmp/rig-sleep" 90 ;;
	--owner-setup-scaleway) printf '%s\n' 'SCALEWAY_CREDENTIAL: OK' ;;
	--owner-setup-slack) printf '%s\n' 'SLACK_WORKSPACE_DOMAIN: OK (resolved the workspace)' ;;
	--owner-setup-storage) printf '%s\n' 'TEAM_DATA_DIRECTORY: OK' 'TEAM_DATA_GIT_REMOTE: WARN' '  warn: no remote is set' ;;
esac
RIGSTANDIN
chmod +x "$rigTmp/stand-in"
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigPre=()
rigRun(){ ## tool arguments... -- one dispatcher call from the rig workspace; rc in rigRc, stdout in out, stderr in err
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" MDAT_MANAGER_CHECK_TOOL="$rigTmp/stand-in" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigWhole(){ LC_ALL=C grep -c -x -F -- "$2" "$1" 2> /dev/null || : ; }
rigRows(){ ## domain -- the rows of that domain in the last output, TAB written |, a / after each
	LC_ALL=C awk -F'\t' -v wantDomain="$1" '$1 == "check" && $2 == wantDomain { gsub( /\t/, "|" ) ; printf "%s/", $0 }' "$rigTmp/out"
}

echo "-- 1. every domain, one of them hanging --"
rigBegan="$SECONDS"
rigRun "$rigOp" --seconds 3
rigTook="$(( SECONDS - rigBegan ))"
rigAssert "the call ends 0 though a check failed and one hung, within the bound and a little" "$rigRc $( [ "$rigTook" -le 12 ] && echo in-time || echo "late:$rigTook" )" "0 in-time"
rigAssert "each result line of a check is one row: the heading above it, its key, its label, its state as the check said, its reason in the check's own words with a continued line joined, its remedy as the command, blanks kept" "$( rigRows claude )" "check|claude|-|CLAUDE_HARNESS_INSTALLED|Claude_Harness_Installed|ok|-|-/check|claude|workspace_ws-rig|SPAWN_CLI_SERVICE|Spawn_CLI_Service|warn|set_to_another_CLI,_so_this_workspace_does_not_run_claude|/rig/tool --owner-setup-claude --set-as-default --apply/check|claude|workspace_ws-rig|AGENTS_CONSOLE_SCRIPT|Agents_Console_Script|fail|differs_from_the_template_it_would_be_regenerated_from,_so_it_is_behind_this_release_path:_/rig/ws/DistroAgentsConsole.sh|-/"
rigAssert "a check that printed no result line is one skipped row, and so is the check that did not end, while the others answered" "$( rigRows copilot )$( rigRows grok )$( rigRows scaleway )$( rigRows slack )" "check|copilot|-|-|Copilot_Check|skipped|the_check_printed_no_result_line|-/check|grok|-|-|Grok_Check|skipped|the_check_did_not_end_within_3_seconds|-/check|scaleway|-|SCALEWAY_CREDENTIAL|Scaleway_Credential|ok|-|-/check|slack|-|SLACK_WORKSPACE_DOMAIN|Slack_Workspace_Domain|ok|(resolved_the_workspace)|-/"
rigAssert "the rows come domain by domain in the one order, every check row has eight fields, and the one summing row is the last: the checks, those ok, warned, failed and skipped" "$( LC_ALL=C awk -F'\t' '$1 == "check" { if ( !( $2 in seen ) ) { seen[$2] = 1 ; printf "%s ", $2 } ; if ( NF != 8 ) bad++ } END { printf "/ %s / %s", bad + 0, $1 " " $2 " " $3 " " $4 " " $5 " " $6 " " NF }' "$rigTmp/out" )" "claude copilot grok scaleway slack storage / 0 / summary 9 4 2 1 2 7"
sleep 1
rigAssert "the check that did not end was ended with what it started: nothing of it runs on" "$( pgrep -f "$rigTmp/rig-sleep" | LC_ALL=C grep -c . || : ) $( LC_ALL=C grep -c -e '--owner-setup-' "$rigTmp/stand-in.calls" )" "0 6"
rigAssert "each check was asked as the owner asks it, read-only: the domain's own operation with --check and nothing else" "$( LC_ALL=C sort -u "$rigTmp/stand-in.calls" | LC_ALL=C tr '\n' '/' )" "--owner-setup-claude --check/--owner-setup-copilot --check/--owner-setup-grok --check/--owner-setup-scaleway --check/--owner-setup-slack --check/--owner-setup-storage --check/"

echo "-- 2. --local, a domain by its name, and what is refused --"
: > "$rigTmp/stand-in.calls"
rigRun "$rigOp" --local --seconds 2 claude slack storage
rigAssert "--local leaves out the domains whose check asks outside the machine: each is a skipped row and is not started; the others are run" "$rigRc $( rigRows claude )$( rigRows slack ) $( LC_ALL=C tr '\n' '/' < "$rigTmp/stand-in.calls" )" "0 check|claude|-|-|Claude_Check|skipped|left_out:_its_check_asks_outside_this_machine|-/check|slack|-|-|Slack_Check|skipped|left_out:_its_check_asks_outside_this_machine|-/ --owner-setup-storage --check/"
rigAssert "the domains named are run alone, and summed: a warning keeps its reason" "$( rigRows storage ) $( LC_ALL=C awk -F'\t' '$1 == "summary" { print $2, $3, $4, $5, $6 }' "$rigTmp/out" )" "check|storage|-|TEAM_DATA_DIRECTORY|Team_Data_Directory|ok|-|-/check|storage|-|TEAM_DATA_GIT_REMOTE|Team_Data_Git_Remote|warn|no_remote_is_set|-/ 4 1 1 0 2"
: > "$rigTmp/stand-in.calls"
rigRun "$rigOp" storage nonesuch
rigAssert "a word that is no domain is refused, rc 1, nothing printed, nothing run, in one line that lists the domains and does not repeat the word" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( wc -c < "$rigTmp/stand-in.calls" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: syntax is $rigOp [--local] [--seconds <n>] [<domain>...], and the word given is none of its domains -- nothing was run. Its domains: claude, copilot, grok, scaleway, slack, storage" )" "1 0 0 1"
rigRun "$rigOp" --seconds 0
rigAssert "a bound that is no number above nought is refused" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: --seconds takes a whole number above nought of up to four digits -- nothing was run" )" "1 0 1"
rigPre=( "MDAT_SPAWN_AGENT=keeper-rig" ) ; rigRun "$rigOp" storage ; rigPre=()
rigAssert "from inside a member's session it is refused by the one rule of the family" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "DistroAgentsTools: ${rigOp#--}: ⛔ ERROR: this session acts as keeper-rig, and a --manager-* operation is the console's own, never run from inside a member's session -- nothing was done" )" "1 0 1"

echo "-- 3. it decides nothing, and the help pair --"
rigInclude="$rigHere/AgentsTools.ManagerCheck.include"
rigAssert "the include makes no check of its own: it names the owner's operation with --check, and prints no state but skipped" "$( LC_ALL=C grep -v '^[[:space:]]*#' "$rigInclude" | LC_ALL=C grep -c -F -e '"--owner-setup-$runName" --check' || : ) $( LC_ALL=C grep -v '^[[:space:]]*#' "$rigInclude" | LC_ALL=C grep -c -E -e '(ok|warn|fail)\\t' || : ) $( LC_ALL=C grep -c -E -e '(curl|ssh |slack-call)' "$rigInclude" || : )" "1 0 0"
rigHelpMd="$rigHere/help/Help.DistroAgentsTools.help.md"
rigSyntax="📘 syntax: DistroAgentsTools.fn.sh $rigOp [--local] [--seconds <n>] [<domain>...]"
rigEntry(){ LC_ALL=C awk -v head="$( printf '\t\t%s [--local] [--seconds <n>] [<domain>...]' "$rigOp" )" '$0 == head { on = 1 ; next } on && /^\t\t--/ { exit } on { print }' "$rigHelpMd" ; }
rigAssert "the operation has its syntax echo, its syntax line and its entry, once each, and the entry gives the two row forms, which the rows printed have" "$( LC_ALL=C grep -c -x -F -- "echo \"$rigSyntax\" >&2" "$rigHere/help/Help.DistroAgentsTools.include" || : ) $( LC_ALL=C grep -c -x -F -- "$rigSyntax" "$rigHelpMd" || : ) $( rigEntry | LC_ALL=C sed -n -e 's/^[[:space:]]*`\(check <.*>\)`$/\1/p' -e 's/^[[:space:]]*`\(summary <.*>\)`$/\1/p' | LC_ALL=C tr '\n' '|' )" "1 1 check <domain> <section> <key> <label> <state> <reason> <remedy>|summary <checks> <ok> <warn> <fail> <skipped> <seconds>|"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MANAGER CHECK RUN CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_CHECK_RUN: OK (%d assertions, offline, a stand-in for the checks)\n' "$rigPasses"
