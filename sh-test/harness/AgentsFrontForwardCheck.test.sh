#!/usr/bin/env bash
## Behavioural check on the tool files in front of the operations (F1.4 of the refactorings epic, first stage): every `--member-*` and
## `--magic-*` operation that moves into a subsystem file or a member's tool file has its new name there, and the call under the new
## name goes on as the call under the old one: the dispatcher's checks and gates, its refusals, its result. The table of the new names is
## `sh-lib/harness/AgentsContext.FrontForward.include`, one line each: the tool file, the new name, the old name or names.
## Held:
##   1. the table is read: each of its tool files exists in sh-scripts and lists its names for a bare `--help`
##   2. control: a name no table line gives to a tool file is refused as that file's invalid option
##   3. every new name of the table reaches its old operation: never refused as the new file's invalid option, nor as the dispatcher's
##      invalid option of the old name (each call carries one argument no operation takes, so that it refuses before it acts)
##   4. a new name that stands for a member's and a coordinator's operation says which, by the call: --append-transcript with another
##      session, --list-permissions with --member, --send-contact-digest with an origin
##   5. `--mdat-output-format json` before the new name wraps the old operation's result as the dispatcher does
## Offline: a rig workspace and data store of this check's own; a fake curl logs any call; no remote is set.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigInclude="$rigPackage/sh-lib/harness/AgentsContext.FrontForward.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the table of the new names is not at the origin this workspace resolves: $rigInclude"
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package"
rigTmp="$( mkdir -p "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsFrontForwardCheck.XXXXXX" )" || exit 1
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
rigCall(){ ## tool file, then the arguments -- the output in call.out
	local rigFile="$1" ; shift
	env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigTmp/data" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_WAIT_REMIND=off RIG_TMP="$rigTmp" RIG_SCENARIO="$rigTmp" RIG_FN="$rigPackage/sh-scripts/$rigFile.fn.sh" \
		${RIG_ENV:-RIG_NONE=1} \
		perl -e 'alarm 20 ; exec @ARGV' bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$rigTmp/call.out" 2>&1 < /dev/null
}

## 1. the table
rigTable="$( . "$rigInclude" && printf '%s\n' "$agentsFrontTable" )"
printf '%s\n' "$rigTable" > "$rigTmp/table"
rigRows="$( LC_ALL=C grep -c . "$rigTmp/table" )"
[ "$rigRows" -ge 100 ] 2> /dev/null || rigRefuse "the table holds too few lines to be read right: $rigRows"
rigAssert "every line of the table has three fields" "$( LC_ALL=C awk -F'\t' 'NF != 3 || $1 == "" || $2 !~ /^--/ || $3 !~ /^--/ { bad++ } END { print bad + 0 }' "$rigTmp/table" )" 0
rigAssert "no new name is given twice" "$( LC_ALL=C awk -F'\t' '{ print $2 }' "$rigTmp/table" | LC_ALL=C sort | LC_ALL=C uniq -d | LC_ALL=C tr '\n' ' ' )" ""
rigMissing=""
for rigKey in $( LC_ALL=C cut -f1 "$rigTmp/table" | LC_ALL=C sort -u ) ; do
	[ -f "$rigPackage/sh-scripts/$rigKey.fn.sh" ] || rigMissing="$rigMissing $rigKey"
done
rigAssert "each tool file of the table exists in sh-scripts" "[${rigMissing# }]" "[]"
rigHelpWrong=""
for rigKey in $( LC_ALL=C cut -f1 "$rigTmp/table" | LC_ALL=C sort -u ) ; do
	case "$rigKey" in AgentDispatcherTools|DistroAgentsSession|DistroAgentsKnowledge|DistroAgentsDispatcher|DistroAgentsTesting|DistroAgentsContacts) continue ;; esac
	rigCall "$rigKey" --help
	[ "$( LC_ALL=C grep -c -E '^  --' "$rigTmp/call.out" )" = "$( LC_ALL=C awk -F'\t' -v k="$rigKey" '$1 == k' "$rigTmp/table" | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" ] || rigHelpWrong="$rigHelpWrong $rigKey"
done
rigAssert "each new tool file lists all its names for --help" "[${rigHelpWrong# }]" "[]"

## 2. control
rigCall DistroAgentsItems --rig-no-such-operation
rigAssert "control: a name the file has not is its invalid option" "$( LC_ALL=C grep -c -x -F 'DistroAgentsItems: ⛔ ERROR: invalid option: --rig-no-such-operation' "$rigTmp/call.out" )" 1
rigCall DistroAgentsKnowledge --get-roster --rig-argument-no-operation-takes
rigAssert "control: a name it has is reached, and the old operation answers by its own name" "$( LC_ALL=C grep -c -F -- 'magic-team-roster-read' "$rigTmp/call.out" )" 1

## 3. every new name reaches its old operation
rigLost=""
while IFS="$(printf '\t')" read -r rigKey rigNew rigOlds ; do
	rigCall "$rigKey" "$rigNew" --rig-argument-no-operation-takes
	LC_ALL=C grep -q -x -F "$rigKey: ⛔ ERROR: invalid option: $rigNew" "$rigTmp/call.out" && rigLost="$rigLost $rigKey:$rigNew"
	rigFirst="${rigOlds%%,*}"
	LC_ALL=C grep -q -x -F "DistroAgentsTools: ⛔ ERROR: invalid option: $rigFirst" "$rigTmp/call.out" && rigLost="$rigLost $rigNew>$rigFirst"
done < "$rigTmp/table"
rigAssert "every new name of the table ($rigRows) reaches its old operation" "[${rigLost# }]" "[]"

## 4. one new name for a member's and a coordinator's operation
RIG_ENV="MDAT_SESSION_ID=rig-own-1" rigCall DistroAgentsSession --append-transcript --team-member keeper-myx --rig-argument-no-operation-takes
rigAssert "--append-transcript with no other session is the member's operation" "$( LC_ALL=C grep -c -F -- '--member-append-session-transcript' "$rigTmp/call.out" )" 1
RIG_ENV="MDAT_SESSION_ID=rig-own-1" rigCall DistroAgentsSession --append-transcript --session-id rig-other-2 --team-member keeper-myx --rig-argument-no-operation-takes
rigAssert "--append-transcript with another session is the coordinator's operation" "$( LC_ALL=C grep -c -F -- '--magic-append-session-transcript' "$rigTmp/call.out" )" 1
rigCall DistroAgentsGrants --list-permissions --rig-argument-no-operation-takes
rigAssert "--list-permissions with no --member is the member's operation" "$( LC_ALL=C grep -c -F -- '--magic-permission-list' "$rigTmp/call.out" )" 0
rigCall DistroAgentsGrants --list-permissions --member keeper-myx --rig-argument-no-operation-takes
rigAssert "--list-permissions with --member is the coordinator's operation" "$( LC_ALL=C grep -c -F -- '--magic-permission-list' "$rigTmp/call.out" )" 1
rigCall DistroAgentsContacts --send-contact-digest --team-member keeper-myx --resolved
rigAssert "--send-contact-digest with no origin is the member's operation" "$( LC_ALL=C grep -c -F -- '--member-contact-digest-send' "$rigTmp/call.out" )" 1
rigCall DistroAgentsContacts --send-contact-digest --team-member keeper-myx keeper-ae3 --resolved
rigAssert "--send-contact-digest with an origin is the coordinator's operation" "$( LC_ALL=C grep -c -F -- '--magic-contact-digest-send' "$rigTmp/call.out" )" 1

## 5. the json wrapper
rigCall DistroAgentsItems --mdat-output-format json --upsert-inbox-inquiry --rig-argument-no-operation-takes
rigAssert "json before a new name wraps the old operation's result" "$( LC_ALL=C grep -c -F '{"operation":"--member-upsert-member-inquiry","status":' "$rigTmp/call.out" )" 1

rigAssert "and nothing was posted" "$( LC_ALL=C grep -c '^chat.postMessage ' "$rigTmp/calls" || : )" 0
if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ FRONT FORWARD CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'FRONT_FORWARD: OK (%d assertions, %d new names, offline)\n' "$rigPassCount" "$rigRows"
