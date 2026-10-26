#!/usr/bin/env bash
## Behavioural check on F5.3 of the refactorings epic, the type kinds of the ONE validator,
## `--intern-doc-validate <store>-item.<type> <file|--from-stdin>` (sh-lib/team-data/AgentsTools.DocValidate.include and
## AgentsDocTypeCheck.awk): the rule set of a team-data type IS its contract (magic-team/contracts/<kind>.contract.format.md),
## read by one reader. A row is `<file>:<line>: <rule>: <text>`; the rule of a reporting row starts `report-` and refuses
## nothing (exit 0); a refusing row exits non-zero. The disposition is the one table, per rule and call site.
## Held:
##   1. every type that has a contract is a kind, and the reader understands every unmarked rule of every contract
##   2. a document that meets its contract passes; each required key absent or empty refuses, naming the key
##   3. a value outside the value form of its key refuses; a literal wrong refuses; `type` against the file name refuses
##   4. what is said and refuses nothing: a key the contract does not name, two keys that appear together, no frontmatter,
##      the body of an audit table, a snapshot's file name; and a mixed document refuses
##   5. `blocks` is required on an approval; `references` of an audit or vault item never names a board item
##   6. the table of dispositions: the same rule is the same at the check and the write site, refusing or reporting
##   7. the contract is the rule set: another contract at the skillset root of the run gives another verdict
##   8. the contracts say what the writers enforce: the owner of a board item is required, the shapes show no optional owner
##   9. a pure rule set: the same rows twice, and --from-stdin the same rows (the file name rule excepted)
## Red before F5.3: the type kinds are not built (every case fails).
## Offline: rig files only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigTemplates="$rigPackage/skillset/magic-team/magic-team/contracts"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the dispatcher is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDocTypeValidateCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigSkills="$rigTmp/skills" rigD="$rigTmp/docs"
mkdir -p "$rigWs/.local/agents" "$rigTmp/home" "$rigSkills/magic-team" "$rigD"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigSkillsRoot="$rigSkills"
rigRun(){ ## kind, file|--from-stdin -- rc in rigRc, the rows in $rigTmp/said.out, the other stream in $rigTmp/said.err
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigTmp/home" USER=rigacct PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigSkillsRoot" bash "$rigTool" --intern-doc-validate "$1" "$2" ) > "$rigTmp/said.out" 2> "$rigTmp/said.err" < "${rigStdin:-/dev/null}" || rigRc=$?
}
rigRules(){ ## the rules of the rows of the last run, in the order printed, space-separated
	LC_ALL=C sed -n -E 's/^.*:[0-9]+: ((report-)?contract-[a-z-]+): .*$/\1/p' "$rigTmp/said.out" | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//'
}
rigHas(){ ## fixed text -- 1 where the rows hold it
	LC_ALL=C grep -c -F -- "$1" "$rigTmp/said.out" || :
}
rigDoc(){ ## file name, lines... -- the document $rigD/<name>
	local docName="$1" ; shift
	printf '%s\n' "$@" > "$rigD/$docName"
}
rigCheck(){ ## kind, file name
	rigRun "$1" "$rigD/$2"
}

## A task that meets its contract, and what each case takes out of it or puts in.
rigTask(){ ## file name, the lines to put after owner (may be none)
	local taskName="$1" ; shift
	rigDoc "$taskName" '---' 'document-contract: board-item.task' 'type: task' 'from: keeper-rig' 'date: 2026-10-01 10:00 +0300' 'owner: keeper-rig' "$@" '---' '# Task: a matter' '' 'The work.'
}

echo "-- 1. every type with a contract is a kind, and every unmarked rule of every contract is read --"
rigKinds=0 rigKindFaults=0 rigUnread=0
for rigContract in "$rigTemplates"/*-item.*.contract.format.md ; do
	rigKind="${rigContract##*/}" ; rigKind="${rigKind%.contract.format.md}"
	rigKinds=$(( rigKinds + 1 ))
	rigDoc "${rigKind#*.}-20261001T1000Z-a.md" '---' '---'
	rigCheck "$rigKind" "${rigKind#*.}-20261001T1000Z-a.md"
	[ "$rigRc" -eq 1 ] || rigKindFaults=$(( rigKindFaults + 1 ))
	rigUnread=$(( rigUnread + $( rigHas 'contract-rule-unread' ) ))
done
rigAssert "19 contracts, each its own kind: a document with no key refuses (exit 1) under every one" "$rigKinds:$rigKindFaults" "19:0"
rigAssert "the reader understands every unmarked rule of every contract: no contract-rule-unread row" "$rigUnread" "0"
rigRun no-such-kind "$rigD/real.md"
rigAssert "an unknown kind is refused, the kinds built named, the type kinds among them" "$rigRc:$( LC_ALL=C grep -o -E 'board-item[.]task|inbox-item[.]note|audit-item[.]transcript|vault-item[.]verbatim' "$rigTmp/said.err" | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' ' )" "1:audit-item.transcript board-item.task inbox-item.note vault-item.verbatim "

echo "-- 2. a document that meets its contract passes; a required key absent refuses --"
rigTask task-20261001T1000Z-ok.md
rigCheck board-item.task task-20261001T1000Z-ok.md
rigAssert "a task that meets its contract: exit 0, no row" "$rigRc:$( rigRules )" "0:"
for rigKey in document-contract type from date owner ; do
	LC_ALL=C grep -v "^$rigKey: " "$rigD/task-20261001T1000Z-ok.md" > "$rigD/task-20261001T1000Z-no-$rigKey.md"
	rigCheck board-item.task "task-20261001T1000Z-no-$rigKey.md"
	rigAssert "no $rigKey: refuses, the key named" "$rigRc:$( rigRules ):$( rigHas "the key $rigKey is required and absent" )" "1:contract-key:1"
done
LC_ALL=C sed 's/^owner: .*$/owner: /' "$rigD/task-20261001T1000Z-ok.md" > "$rigD/task-20261001T1000Z-empty.md"
rigCheck board-item.task task-20261001T1000Z-empty.md
rigAssert "a required key with no value is as absent" "$rigRc:$( rigRules ):$( rigHas 'the key owner is required and empty' )" "1:contract-key:1"

echo "-- 3. a value outside its form refuses --"
rigBad(){ ## file name, a frontmatter line replaced, its new line, the rows wanted (rules), the text the row holds
	LC_ALL=C sed "s/^$2: .*\$/$3/" "$rigD/task-20261001T1000Z-ok.md" > "$rigD/$1"
	rigCheck board-item.task "$1"
	rigAssert "$6" "$rigRc:$( rigRules ):$( rigHas "$5" )" "1:$4:1"
}
rigBad task-20261001T1001Z-a.md date 'date: 2026-10-01' contract-form 'the key date is not a date-time' "a date with no time refuses"
rigBad task-20261001T1002Z-a.md from 'from: two words' contract-form 'the key from is not one member name' "a member that is not one name refuses"
rigBad task-20261001T1003Z-a.md document-contract 'document-contract: board-item.change' contract-form 'is not the literal board-item.task' "a document that names another contract refuses"
rigBad task-20261001T1004Z-a.md type 'type: change' 'contract-form contract-type' 'is not the literal task' "a type that is not the literal refuses, and the file name rule says it too"
rigTask task-20261001T1005Z-a.md 'references: [task-20261001T0900Z-x]'
rigCheck board-item.task task-20261001T1005Z-a.md
rigAssert "item names in brackets refuse" "$rigRc:$( rigRules ):$( rigHas 'the key references is not bare item names' )" "1:contract-form:1"
rigTask task-20261001T1006Z-a.md 'references: task-20261001T0900Z-x, change-20261001T0901Z-y'
rigCheck board-item.task task-20261001T1006Z-a.md
rigAssert "bare item names, comma-separated, pass" "$rigRc:$( rigRules )" "0:"
rigTask task-20261001T1007Z-a.md 'archive: yes'
rigCheck board-item.task task-20261001T1007Z-a.md
rigAssert "a flag that is not the word true refuses" "$rigRc:$( rigRules ):$( rigHas 'the key archive is not the word true' )" "1:contract-form:1"
rigTask task-20261001T1008Z-a.md 'communication-channel-id: slack:C123:1700000000.000100' 'recheck-date: 2026-10-02 09:00 +0300' 'condition: the owner answers' 'review-by: none'
rigCheck board-item.task task-20261001T1008Z-a.md
rigAssert "channel id, date-time, text and reviewer forms pass" "$rigRc:$( rigRules )" "0:"
rigTask task-20261001T1009Z-a.md 'communication-channel-id: chat:C123'
rigCheck board-item.task task-20261001T1009Z-a.md
rigAssert "a channel id of no known channel refuses" "$rigRc:$( rigRules )" "1:contract-form"
rigTask change-20261001T1010Z-a.md
rigCheck board-item.task change-20261001T1010Z-a.md
rigAssert "type task in a file named change-: the type word of the file name refuses" "$rigRc:$( rigRules ):$( rigHas 'is not the type word of the file name change-20261001T1010Z-a.md: task (the file name says change)' )" "1:contract-type:1"
rigStdin="$rigD/change-20261001T1010Z-a.md" rigRun board-item.task --from-stdin
rigAssert "read from stdin there is no file name to hold the type to: it passes" "$rigRc:$( rigRules )" "0:"

echo "-- 4. said and refusing nothing; a mixed document refuses --"
rigTask task-20261001T1011Z-a.md 'advance-reassess-note-20261001T1011Z: looked again'
rigCheck board-item.task task-20261001T1011Z-a.md
rigAssert "a key the contract does not name is said (report-), exit 0" "$rigRc:$( rigRules )" "0:report-contract-unknown-key"
rigTask task-20261001T1012Z-a.md 'approved-by: magic-coordinator (rig-session, 2026-10-01T10:00:00Z)'
rigCheck board-item.task task-20261001T1012Z-a.md
rigAssert "approved-by without approved-at is said, exit 0" "$rigRc:$( rigRules )" "0:report-contract-pair"
rigTask task-20261001T1013Z-a.md 'recheck-date: 2026-10-02 09:00 +0300'
rigCheck board-item.task task-20261001T1013Z-a.md
rigAssert "recheck-date without condition is said, exit 0" "$rigRc:$( rigRules )" "0:report-contract-pair"
rigDoc task-20261001T1014Z-a.md 'a task with no frontmatter at all'
rigCheck board-item.task task-20261001T1014Z-a.md
rigAssert "a document with no frontmatter block is said, exit 0" "$rigRc:$( rigRules )" "0:report-contract-frontmatter"
rigDoc task-20261001T1015Z-a.md '---' 'document-contract: board-item.task' 'type: task' 'from: keeper-rig' 'date: 2026-10-01' 'owner: keeper-rig' 'advance-reassess-note: x' '---' '# Task: a matter'
rigCheck board-item.task task-20261001T1015Z-a.md
rigAssert "a refusing fault and a reported one in one document: both rows, exit 1" "$rigRc:$( rigRules )" "1:contract-form report-contract-unknown-key"
rigDoc declaration-20261001T0000Z-output-style.md '---' 'document-contract: audit-item.declaration' 'type: declaration' 'topic: output-style text-group declarations' '---' '' '# Declarations: text sent as not message group' '' $'date-time\tkind\tmember\tgroup\tdestination\ttext' $'2026-10-01T10:00:00Z\tdeclaration\tkeeper-rig\tstatus\tslack\tone' $'2026-10-01T10:01:00Z\tdeclaration\tkeeper-rig\tmessage\tslack\ttwo' $'2026-10-01T10:02:00Z\tdeclaration\tkeeper-rig'
rigCheck audit-item.declaration declaration-20261001T0000Z-output-style.md
rigAssert "an audit table: a short row and a row of the group message are said, exit 0" "$rigRc:$( rigRules ):$( rigHas 'the row has 3 tab-separated columns, and the contract says 6' ):$( rigHas 'a declaration is never of the group message' )" "0:report-contract-body report-contract-body:1:1"
rigDoc snapshot-20261001T100000Z-jira-issue-ABC-1.md '---' 'document-contract: audit-item.snapshot' 'type: snapshot' 'system: jira' 'resource-type: issue' 'resource-id: ABC-2' 'write-op: x' 'captured-by: keeper-rig' 'captured-at: 20261001T100000Z' '---' '' 'as read'
rigCheck audit-item.snapshot snapshot-20261001T100000Z-jira-issue-ABC-1.md
rigAssert "a snapshot whose file name does not carry what its frontmatter gives is said, exit 0" "$rigRc:$( rigRules )" "0:report-contract-filename"

echo "-- 5. blocks on an approval; references of an audit item --"
rigDoc approval-20261001T1020Z-a.md '---' 'document-contract: board-item.approval' 'type: approval' 'from: keeper-rig' 'date: 2026-10-01 10:20 +0300' 'owner: keeper-rig' '---' '# Approval: gate'
rigCheck board-item.approval approval-20261001T1020Z-a.md
rigAssert "an approval without blocks refuses, the key named" "$rigRc:$( rigRules ):$( rigHas 'the key blocks is required and absent' )" "1:contract-key:1"
rigDoc approval-20261001T1021Z-a.md '---' 'document-contract: board-item.approval' 'type: approval' 'from: keeper-rig' 'date: 2026-10-01 10:21 +0300' 'owner: keeper-rig' 'blocks: task-20261001T1000Z-ok' '---' '# Approval: gate'
rigCheck board-item.approval approval-20261001T1021Z-a.md
rigAssert "with blocks it passes" "$rigRc:$( rigRules )" "0:"
rigDoc transcript-20261001T1022Z-a.md '---' 'document-contract: audit-item.transcript' 'type: transcript' 'references: task-20261001T1000Z-ok, audit-item-x' '---' '' 'keeper-rig (2026-10-01T10:22:00Z):' '' '> hello'
rigCheck audit-item.transcript transcript-20261001T1022Z-a.md
rigAssert "an audit item that names a board item refuses" "$rigRc:$( rigRules ):$( rigHas 'names a board item: task-20261001T1000Z-ok' )" "1:contract-references:1"
rigDoc note-20261001T1023Z-a.md '---' 'document-contract: inbox-item.note' 'type: note' 'from: keeper-rig' 'date: 2026-10-01 10:23 +0300' 'owner: keeper-rig' '---' '# Note: a matter'
rigCheck inbox-item.note note-20261001T1023Z-a.md
rigAssert "an inbox note that meets its contract passes" "$rigRc:$( rigRules )" "0:"

echo "-- 6. the one table of dispositions, per rule and site --"
rigTable="$( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" bash -c '
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.DocValidate.include"
	for ruleName in contract-key contract-form contract-type contract-references contract-unknown-key contract-pair contract-frontmatter contract-body contract-filename contract-rule-unread contract-name contract-store ; do
		printf "%s=%s/%s " "$ruleName" "$( AgentsToolsDocValidateDisposition "$ruleName" check )" "$( AgentsToolsDocValidateDisposition "$ruleName" write )"
	done' )"
rigAssert "the contract refuses, at both sites; what is only said is said at both" "$rigTable" "contract-key=refuse/refuse contract-form=refuse/refuse contract-type=refuse/refuse contract-references=refuse/refuse contract-unknown-key=report/report contract-pair=report/report contract-frontmatter=report/report contract-body=report/report contract-filename=report/report contract-rule-unread=report/report contract-name=report/report contract-store=report/report "

echo "-- 7. the contract is the rule set --"
mkdir -p "$rigSkills/magic-team/contracts"
LC_ALL=C sed 's/^| `owner` | required |/| `owner` | optional |/' "$rigTemplates/board-item.task.contract.format.md" > "$rigSkills/magic-team/contracts/board-item.task.contract.format.md"
rigCheck board-item.task task-20261001T1000Z-no-owner.md
rigAssert "a task with no owner passes where the contract of the skillset root makes owner optional" "$rigRc:$( rigRules )" "0:"
rigSkillsRoot="$rigTmp/none"
rigCheck board-item.task task-20261001T1000Z-no-owner.md
rigSkillsRoot="$rigSkills"
rigAssert "and refuses where it does not" "$rigRc:$( rigRules )" "1:contract-key"

echo "-- 8. the contracts say what the writers enforce --"
rigOwners=0 rigShapes=0
for rigContract in "$rigTemplates"/board-item.*.contract.format.md ; do
	LC_ALL=C grep -q -E '^\| `owner` \| required \| (either|tooling) \| `owner-name` \|' "$rigContract" && rigOwners=$(( rigOwners + 1 ))
done
for rigShape in "$rigPackage/sh-lib/templates"/board-item.*.document.format.md ; do
	LC_ALL=C grep -q -E '^owner: <[^>]*optional' "$rigShape" || rigShapes=$(( rigShapes + 1 ))
done
rigAssert "the owner is required in all 9 board contracts, and no board shape shows it optional" "$rigOwners:$rigShapes" "9:9"
rigAssert "a contract is no longer 'not built yet'" "$( LC_ALL=C grep -l 'not built yet' "$rigTemplates"/*-item.*.contract.format.md | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "0"

echo "-- 9. a pure rule set --"
rigCheck board-item.task task-20261001T1015Z-a.md
cp "$rigTmp/said.out" "$rigTmp/first.out"
rigCheck board-item.task task-20261001T1015Z-a.md
rigAssert "the same document gives the same rows" "$( cmp -s "$rigTmp/said.out" "$rigTmp/first.out" && echo same || echo differ )" "same"
rigStdin="$rigD/task-20261001T1015Z-a.md" rigRun board-item.task --from-stdin
rigAssert "--from-stdin gives the same rules, shown as <stdin>" "$( rigRules ):$( LC_ALL=C grep -c '^<stdin>:' "$rigTmp/said.out" )" "contract-form report-contract-unknown-key:2"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ DOC TYPE VALIDATE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'DOC_TYPE_VALIDATE: OK (%d assertions, offline)\n' "$rigPassCount"
