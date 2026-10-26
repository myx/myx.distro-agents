#!/usr/bin/env bash
## Behavioural check on the tool files that own the operations of the team (F1.4 of the refactorings epic): every operation that was a `--member-*` or `--magic-*`
## one of DistroAgentsTools.fn.sh has its name in the file of its subsystem, and nothing else of that old family is left. The table is
## `sh-lib/harness/AgentsContext.FrontTable.include`, one line each: the tool file, the name, and who may call it.
## Held:
##   1. the table is read: each of its tool files exists in sh-scripts, a bare `--help` lists its names, and each name has a syntax line naming that file
##   2. control: a name no table line gives to a tool file is refused as that file's invalid option
##   3. every name of the table reaches its operation, asked of its own file and of DistroAgentsTools.fn.sh's one rule: never refused as an invalid option (each call
##      carries one argument no operation takes, so that it refuses before it acts)
##   4. every name an operation had before is refused by DistroAgentsTools.fn.sh with its new place in the line, or with why it is gone
##   5. a coordinator's own operation is refused in the session of another member, and any member's is not
##   6. `--help-syntax` of a tool file: its lines, one name's, a prefix's, and a word that names none is refused
##   7. `--mdat-output-format json` before a name wraps the result of the operations the harness runs
##   8. the standing lock of a routine is taken and given back by the spawner's functions, and refused in a workspace that keeps no team data
##   9. a tool file run by itself calls the others by DistroAgentsTools, and the tool files are commands of the harness's execute
## Offline: a rig workspace and data store of this check's own; a fake curl logs any call; no remote is set.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigInclude="$rigPackage/sh-lib/harness/AgentsContext.FrontTable.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the table of the tool files is not at the origin this workspace resolves: $rigInclude"
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package"
rigTmp="$( mkdir -p "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsToolFilesCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws/.local/.agents" "$rigTmp/home" "$rigTmp/data" "$rigTmp/skills/magic-coordinator" "$rigTmp/skills/keeper-myx" "$rigTmp/bin"
printf 'rig\n' > "$rigTmp/skills/magic-coordinator/magic-coordinator.basic.md"
printf 'rig\n' > "$rigTmp/skills/keeper-myx/keeper-myx.basic.md"
cp "$rigPackage/sh-test/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
: > "$rigTmp/calls" ; : > "$rigTmp/bodies"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigCall(){ ## tool file, then the arguments -- the output in call.out; RIG_ENV holds more variables for the one call
	local rigFile="$1" ; shift
	env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigTmp/data" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_WAIT_REMIND=off RIG_TMP="$rigTmp" RIG_SCENARIO="$rigTmp" RIG_FN="$rigPackage/sh-scripts/$rigFile.fn.sh" \
		${RIG_ENV:-RIG_NONE=1} \
		python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 20 -- bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$rigTmp/call.out" 2>&1 < /dev/null
}

## 1. the table
rigTable="$( . "$rigInclude" && printf '%s\n' "$agentsFrontTable" )"
printf '%s\n' "$rigTable" > "$rigTmp/table"
rigRows="$( LC_ALL=C grep -c . "$rigTmp/table" )"
[ "$rigRows" -ge 100 ] 2> /dev/null || rigRefuse "the table holds too few lines to be read right: $rigRows"
rigAssert "every line of the table has three fields, a name and an audience" "$( LC_ALL=C awk -F'\t' 'NF != 3 || $1 == "" || $2 !~ /^--/ || ( $3 != "member" && $3 != "coordinator" ) { bad++ } END { print bad + 0 }' "$rigTmp/table" )" 0
rigAssert "no name is given twice" "$( LC_ALL=C awk -F'\t' '{ print $2 }' "$rigTmp/table" | LC_ALL=C sort | LC_ALL=C uniq -d | LC_ALL=C tr '\n' ' ' )" ""
rigMissing=""
for rigKey in $( LC_ALL=C cut -f1 "$rigTmp/table" | LC_ALL=C sort -u ) ; do
	[ -f "$rigPackage/sh-scripts/$rigKey.fn.sh" ] || rigMissing="$rigMissing $rigKey"
done
rigAssert "each tool file of the table exists in sh-scripts" "[${rigMissing# }]" "[]"
rigNoSyntax=""
while IFS="$(printf '\t')" read -r rigKey rigName rigWho ; do
	LC_ALL=C grep -q -F "echo \"📘 syntax: $rigKey.fn.sh $rigName" "$rigPackage/sh-lib/help/Help.DistroAgentsTools.include" || rigNoSyntax="$rigNoSyntax $rigName"
done < "$rigTmp/table"
rigAssert "each name has a syntax line that names its tool file" "[${rigNoSyntax# }]" "[]"
rigHelpWrong=""
for rigKey in $( LC_ALL=C cut -f1 "$rigTmp/table" | LC_ALL=C sort -u ) ; do
	case "$rigKey" in AgentDispatcherTools|DistroAgentsSession|DistroAgentsKnowledge|DistroAgentsDispatcher|DistroAgentsTesting|DistroAgentsContacts|DistroAgentsAtlassian|DistroAgentsGoogle|DistroAgentsGrants|DistroAgentsItems|DistroAgentsMail|DistroAgentsQuestions|DistroAgentsSlack|DistroAgentsTrello) continue ;; esac
	rigCall "$rigKey" --help
	[ "$( LC_ALL=C grep -c -E '^  --' "$rigTmp/call.out" )" = "$( LC_ALL=C awk -F'\t' -v k="$rigKey" '$1 == k' "$rigTmp/table" | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" ] || rigHelpWrong="$rigHelpWrong $rigKey"
done
rigAssert "each new tool file lists all its names for --help" "[${rigHelpWrong# }]" "[]"

## 2. control
rigCall DistroAgentsItems --rig-no-such-operation
rigAssert "control: a name the file has not is its invalid option" "$( LC_ALL=C grep -c -x -F 'DistroAgentsItems: ⛔ ERROR: invalid option: --rig-no-such-operation' "$rigTmp/call.out" )" 1

## 3. every name reaches its operation, from its own file and from the one rule of the dispatcher
rigLost=""
while IFS="$(printf '\t')" read -r rigKey rigName rigWho ; do
	rigCall "$rigKey" "$rigName" --rig-argument-no-operation-takes
	LC_ALL=C grep -q -x -F "$rigKey: ⛔ ERROR: invalid option: $rigName" "$rigTmp/call.out" && rigLost="$rigLost $rigKey:$rigName"
	rigCall DistroAgentsTools "$rigName" --rig-argument-no-operation-takes
	LC_ALL=C grep -q -x -F "DistroAgentsTools: ⛔ ERROR: invalid option: $rigName" "$rigTmp/call.out" && rigLost="$rigLost Tools:$rigName"
done < "$rigTmp/table"
rigAssert "every name of the table ($rigRows) reaches its operation, from its file and from DistroAgentsTools.fn.sh" "[${rigLost# }]" "[]"

## 4. the old names
rigNotRefused=""
rigOld=0
while IFS="$(printf '\t')" read -r rigOldName rigNow ; do
	rigOld=$(( rigOld + 1 ))
	rigCall DistroAgentsTools "$rigOldName" --rig-argument-no-operation-takes
	case "$rigNow" in
		\(*) LC_ALL=C grep -q -F -- "$rigOldName is retired: " "$rigTmp/call.out" || rigNotRefused="$rigNotRefused $rigOldName" ;;
		*) LC_ALL=C grep -q -F -- "$rigOldName was renamed: use $rigNow" "$rigTmp/call.out" || rigNotRefused="$rigNotRefused $rigOldName" ;;
	esac
done < <( . "$rigInclude" && printf '%s\n' "$agentsFrontRetired" )
rigAssert "every old name ($rigOld) is refused with its new place in the line, or with why it is gone" "[${rigNotRefused# }]" "[]"

## 5. who may call
RIG_ENV="MDAT_SPAWN_AGENT=keeper-myx" rigCall AgentDispatcherTools --roster-upsert --rig-argument-no-operation-takes
rigAssert "a coordinator's operation is refused in another member's session" "$( LC_ALL=C grep -c -F "roster-upsert is magic-coordinator's only" "$rigTmp/call.out" )" 1
RIG_ENV="MDAT_SPAWN_AGENT=keeper-myx" rigCall DistroAgentsItems --move-to-pending --rig-argument-no-operation-takes
rigAssert "a board move is the coordinator's too" "$( LC_ALL=C grep -c -F "move-to-pending is magic-coordinator's only" "$rigTmp/call.out" )" 1
RIG_ENV="MDAT_SPAWN_AGENT=keeper-myx" rigCall DistroAgentsItems --get-audit-item --rig-argument-no-operation-takes
rigAssert "a member's operation is not refused as the coordinator's" "$( LC_ALL=C grep -c -F "magic-coordinator's only" "$rigTmp/call.out" )" 0
RIG_ENV="MDAT_SPAWN_AGENT=keeper-myx MDAT_SESSION_ID=rig-own-1 MDAT_WORKSPACE_MODE=team-rig" rigCall DistroAgentsSession --append-transcript --team-member keeper-myx --of-session rig-other-2 --message x
rigAssert "--append-transcript of another session is magic-coordinator's alone" "$( LC_ALL=C grep -c -F -- '--of-session runs only as magic-coordinator' "$rigTmp/call.out" )" 1
RIG_ENV="MDAT_SPAWN_AGENT=keeper-myx" rigCall DistroAgentsGrants --list-permissions --member magic-coordinator
rigAssert "another member's grants are magic-coordinator's to list" "$( LC_ALL=C grep -c -F "are magic-coordinator's to list" "$rigTmp/call.out" )" 1

## 6. --help-syntax of a tool file
rigCall DistroAgentsItems --help-syntax
rigAssert "a bare --help-syntax lists the syntax lines of the file, and only of the file" "$( LC_ALL=C grep -c -F '📘 syntax: DistroAgentsItems.fn.sh ' "$rigTmp/call.out" ):$( LC_ALL=C grep -F '📘 syntax: ' "$rigTmp/call.out" | LC_ALL=C grep -c -v -F '📘 syntax: DistroAgentsItems.fn.sh ' )" "$( LC_ALL=C grep -c -F 'echo "📘 syntax: DistroAgentsItems.fn.sh ' "$rigPackage/sh-lib/help/Help.DistroAgentsTools.include" ):0"
rigCall DistroAgentsItems --help-syntax --get-audit-item
rigAssert "one name: its syntax line alone" "$( LC_ALL=C grep -c -F '📘 syntax: ' "$rigTmp/call.out" ):$( LC_ALL=C grep -c -F -- '--get-audit-item' "$rigTmp/call.out" )" "1:1"
rigCall DistroAgentsItems --help-syntax --grooming-
rigAssert "a prefix ending in a dash: the lines of every name it begins" "$( LC_ALL=C grep -c -F -- ' --grooming-' "$rigTmp/call.out" )" "$( LC_ALL=C grep -c -F 'DistroAgentsItems.fn.sh --grooming-' "$rigPackage/sh-lib/help/Help.DistroAgentsTools.include" )"
rigCall DistroAgentsItems --help-syntax --rig-no-such-operation
rigAssert "a word that names none is refused" "$( LC_ALL=C grep -c -F 'no operation of DistroAgentsItems is named so' "$rigTmp/call.out" )" 1

## 7. the json wrapper
rigCall DistroAgentsItems --mdat-output-format json --upsert-inbox-inquiry --rig-argument-no-operation-takes
rigAssert "json before a name wraps the result of an operation the harness runs" "$( LC_ALL=C grep -c -F '{"operation":"--upsert-inbox-inquiry","status":' "$rigTmp/call.out" )" 1
rigCall DistroAgentsTools --mdat-output-format json --upsert-inbox-inquiry --rig-argument-no-operation-takes
rigAssert "and through the dispatcher's one rule" "$( LC_ALL=C grep -c -F '{"operation":"--upsert-inbox-inquiry","status":' "$rigTmp/call.out" )" 1

## 8. the standing lock of a routine
rigCall DistroAgentsTools --intern-op-routine-lock-take advance magic-coordinator rig-advance-pass
rigAssert "a workspace that keeps no team data takes no routine lock" "$( LC_ALL=C grep -c -F 'this workspace keeps no team data' "$rigTmp/call.out" )" 1
RIG_ENV="MDAT_WORKSPACE_MODE=team-rig" rigCall DistroAgentsTools --intern-op-routine-lock-take no-such-routine magic-coordinator rig-pass
rigAssert "a routine with no standing lock is refused by name" "$( LC_ALL=C grep -c -F 'no standing lock for the routine no-such-routine' "$rigTmp/call.out" )" 1

## 9. a tool file run by itself, and the tool files inside the harness's execute
rigCall DistroAgentsSession --wait-for-input keeper-myx --wait-list-sources
rigAssert "a tool file run by itself reaches the operations its operation calls by DistroAgentsTools" "$( LC_ALL=C grep -c -x 'WAIT-RESULT: RECEIVED' "$rigTmp/call.out" || : ):$( LC_ALL=C grep -c 'command not found' "$rigTmp/call.out" || : )" "1:0"
rigExecute="$( printf '%s\n' 'for rigF in DistroAgentsItems DistroAgentsMail DistroAgentsSession AgentDispatcherTools ; do type "$rigF" > /dev/null 2>&1 && printf "%s " "$rigF" ; done' \
	| env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigTmp/data" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		bash "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" --intern-mcp-execute 2> /dev/null )"
rigAssert "every tool file of the table is a command of an execute script" "$rigExecute" "DistroAgentsItems DistroAgentsMail DistroAgentsSession AgentDispatcherTools "

rigAssert "and nothing was posted" "$( LC_ALL=C grep -c '^chat.postMessage ' "$rigTmp/calls" || : )" 0
if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ TOOL FILES CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'TOOL_FILES: OK (%d assertions, %d names, %d old names, offline)\n' "$rigPassCount" "$rigRows" "$rigOld"
