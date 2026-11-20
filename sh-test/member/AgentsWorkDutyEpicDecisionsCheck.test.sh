#!/usr/bin/env bash
## Behavioural check on the Decisions of the active epics, the section every work-duty scan prints and --supervise-epics prints for a rig
## (AgentsTools.EpicDecisions.include). Held, run and not read, in a rig of this check's own:
##   1. WHO READS AN EPIC: the coordinator every epic an item of the running, pending, blocked or review state names, in `epic:`,
##      `spawned-by:` or `references:`; a member those of the items it owns or takes part in; a member of none no section, not even a heading.
##      An epic named only by an item of another state is no one's.
##   2. WHAT IS READ: the epic's title and its whole `## Decisions`, its dated lines among them, and nothing past it.
##   3. THE SAME TEXT TWICE, so the section wakes no idle Wait by itself.
##   4. --supervise-epics prints the coordinator's section, `--member` exactly that member's, and one `none:` line for a member of none.
##   5. PAST THE CAP (MDAT_EPIC_DECISIONS_CAP_BYTES): the newest decisions first, by the date each opens with, and a line counting those cut.
## Offline: a Slack-shaped fake curl first on PATH.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigTest="$rigOrigin/myx/myx.distro-agents/sh-test"
rigTool="$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigSurface="$rigOrigin/myx/myx.distro-agents/sh-scripts/AgentDispatcherTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] && [ -f "$rigSurface" ] || rigRefuse "the tools are not at the origin this workspace resolves: $rigTool"
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWorkDutyEpicDecisionsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigData="$rigTmp/data"
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigWs/.local/.agents" "$rigWs/.local/agents/sessions/rig-session" "$rigTmp/skills/human-owner"
for rigMember in magic-coordinator keeper-rig keeper-other ; do
	mkdir -p "$rigTmp/skills/$rigMember"
	printf 'rig\n' > "$rigTmp/skills/$rigMember/$rigMember.basic.md" ; printf 'rig\n' > "$rigTmp/skills/$rigMember/$rigMember.armed.md"
done
printf -- '---\nstatus: reference-only\n---\n# human-owner\n' > "$rigTmp/skills/human-owner/SKILL.md"
printf 'rig\n' > "$rigTmp/skills/human-owner/human-owner.basic.md"
cp "$rigTest/check-fixtures/work-duty.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nWAIT_COLLECT_SECONDS=1\n' > "$rigWs/.local/.agents/magic-team.agent.env"
. "$rigTest/check-fixtures/rig-owner-writes.include.sh" || exit 1
rigOwnerWs="$rigWs" rigOwnerData="$rigData" rigOwnerHome="$rigTmp/home" rigOwnerSkills="$rigTmp/skills" rigOwnerOrigin="$rigOrigin"
rigOwnerBoardReady || rigRefuse "the rig board could not be made"
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigRun(){ ## tool script, arguments... -- its stdout, run as the rig's own process
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_WAIT_REMIND=off MDAT_WAIT_POLL_SECONDS=1 ${RIG_CAP:+MDAT_EPIC_DECISIONS_CAP_BYTES=$RIG_CAP} \
		python3 -I -B "$rigTest/check-fixtures/rig-exec.py" --alarm 120 -- bash "$@" 2> /dev/null < /dev/null )
}
rigScan(){ ## member -- the work-duty scan of that member
	rigRun "$rigTool" --intern-op-work-duty-input-scan "$1" --session-id rig-session
}
rigSection(){ ## text -- the epic section, from its heading to the next section, no blank line at either end
	printf '%s\n' "$1" | LC_ALL=C awk '
		$0 == "## Decisions of the active epics" { on = 1 ; }
		on && /^## / && $0 != "## Decisions of the active epics" { on = 0 ; }
		on { kept[++n] = $0 ; }
		END { while ( n > 0 && kept[n] == "" ) { n-- ; } for ( i = 1 ; i <= n ; i++ ) { print kept[i] ; } ; }'
}
rigCount(){ ## text, fixed line -- how many lines are exactly it
	printf '%s\n' "$1" | LC_ALL=C grep -c -x -F -- "$2" || :
}
rigEpic(){ ## name, title, Decisions body
	printf -- '---\ndocument-contract: vault-item.epic-blueprint\ntype: epic-blueprint\nfrom: magic-coordinator\ndate: 2026-11-18 00:00 +0200\n---\n# %s\n\nSource: `rig.sketch.md`. The rig sprint.\n\nBuilders: magic-developer.\n\n## Decisions\n\n%s\n\n---\n\n## S1 - The rig feature\n\nOwner: magic-developer. State: open.\n\n1. One outcome a check can pass. Owner: magic-developer.\n\n## Done\n\n' "$2" "$3" | rigOwnerVaultPut "$1.md" || rigRefuse "the vault epic $1 could not be written"
}
rigItem(){ ## state, item, frontmatter lines
	printf -- '---\ntype: task\n%s---\n\n# rig\n' "$3" | rigOwnerBoardPut "$1" "$2" || rigRefuse "the board item $2 could not be written"
}
rigEpicA='epic-blueprint-20261118T0000Z-rig-a'
rigEpicB='epic-blueprint-20261118T0000Z-rig-b'
rigEpicC='epic-blueprint-20261118T0000Z-rig-c'
rigEpicD='epic-blueprint-20261118T0000Z-rig-d'
rigLine35='- 2026-11-18 20:35 +0200, the human-owner: the rig epic is one whole machine.'
rigLine33='- 2026-11-18 20:33 +0200, the human-owner: the rig package lives in the rig namespace.'
rigLine16='- 2026-11-16 14:16 +0200, the human-owner: the rig answer to the first gap.'
rigLineSuper='- Superseded on 2026-11-18 20:35 +0200 by the line above: every rig service has its own guest.'
rigEpic "$rigEpicA" 'The rig epic A' "$rigLine16"$'\n\n- One rule holds for the rig epic A.\n'"$rigLine35"$'\n'"$rigLine33"$'\n'"$rigLineSuper"
rigEpic "$rigEpicB" 'The rig epic B' '- One rule holds for the rig epic B.'
rigEpic "$rigEpicC" 'The rig epic C' '- One rule holds for the rig epic C.'
rigEpic "$rigEpicD" 'The rig epic D' '- One rule holds for the rig epic D.'
rigItem running task-20261118T0001Z-rig-a.md "owner: magic-coordinator"$'\n'"participants: keeper-rig, magic-devops"$'\n'"references: $rigEpicA"$'\n'
rigItem review task-20261118T0002Z-rig-b.md "owner: keeper-rig"$'\n'"spawned-by: $rigEpicB.md"$'\n'
rigItem blocked task-20261118T0003Z-rig-d.md "owner: magic-coordinator"$'\n'"epic: $rigEpicD"$'\n'
rigItem backlog task-20261118T0004Z-rig-c.md "owner: keeper-rig"$'\n'"epic: $rigEpicC"$'\n'
rigItem pending task-20261118T0005Z-rig-plain.md "owner: keeper-other"$'\n'

echo "-- 1 and 2. who reads an epic, and what is read --"
rigCoord="$( rigScan magic-coordinator )"
rigKeeper="$( rigScan keeper-rig )"
rigOther="$( rigScan keeper-other )"
[ -n "$rigCoord" ] && [ -n "$rigOther" ] || rigRefuse "a scan of the rig printed nothing"
rigAssert "control: keeper-other's scan ran, its Slack section printed" "$( printf '%s\n' "$rigOther" | LC_ALL=C grep -c '^## Slack: tagged to keeper-other' || : )" 1
rigCoordSection="$( rigSection "$rigCoord" )"
rigKeeperSection="$( rigSection "$rigKeeper" )"
rigAssert "the coordinator sees A, B and D, by references:, spawned-by: and epic:, and not C of the backlog" \
	"$( rigCount "$rigCoordSection" "### The rig epic A ($rigEpicA)" )$( rigCount "$rigCoordSection" "### The rig epic B ($rigEpicB)" )$( rigCount "$rigCoordSection" "### The rig epic D ($rigEpicD)" )$( rigCount "$rigCoordSection" "### The rig epic C ($rigEpicC)" )" 1110
rigAssert "the coordinator reads A's dated decisions" "$( rigCount "$rigCoordSection" "$rigLine33" )$( rigCount "$rigCoordSection" "$rigLine35" )" 11
rigAssert "a participant of A's item and owner of B's sees A and B, and not D or C" \
	"$( rigCount "$rigKeeperSection" "### The rig epic A ($rigEpicA)" )$( rigCount "$rigKeeperSection" "### The rig epic B ($rigEpicB)" )$( rigCount "$rigKeeperSection" "### The rig epic D ($rigEpicD)" )$( rigCount "$rigKeeperSection" "### The rig epic C ($rigEpicC)" )" 1100
rigAssert "the participant reads A's 20:35 line" "$( rigCount "$rigKeeperSection" "$rigLine35" )" 1
rigAssert "a member of no epic's item gets no section, not even a heading" "$( printf '%s\n' "$rigOther" | LC_ALL=C grep -c -e '^## Decisions of the active epics' -e 'rig epic' || : )" 0
rigAssert "nothing past the Decisions: no feature and no Done" "$( printf '%s\n' "$rigCoordSection" | LC_ALL=C grep -c -e 'The rig feature' -e '^## Done' -e '^---$' || : )" 0

echo "-- 3. the same text twice --"
rigAssert "a second scan of the coordinator prints the same section" "$( [ -n "$rigCoordSection" ] && [ "$( rigSection "$( rigScan magic-coordinator )" )" = "$rigCoordSection" ] && echo same || echo differs )" same

echo "-- 4. --supervise-epics --"
rigAssert "with no member: the coordinator's section" "$( [ -n "$rigCoordSection" ] && [ "$( rigSection "$( rigRun "$rigSurface" --supervise-epics )" )" = "$rigCoordSection" ] && echo same || echo differs )" same
rigAssert "--member keeper-rig: exactly that member's section" "$( [ -n "$rigKeeperSection" ] && [ "$( rigSection "$( rigRun "$rigSurface" --supervise-epics --member keeper-rig )" )" = "$rigKeeperSection" ] && echo same || echo differs )" same
rigAssert "--member keeper-other: one none line" "$( rigRun "$rigSurface" --supervise-epics --member keeper-other )" "none: no item of the running, pending, blocked or review state names an epic that keeper-other may read"

echo "-- 5. past the cap --"
rigCapped="$( RIG_CAP=$(( ${#rigLine35} + 1 + ${#rigLine33} + 1 )) rigRun "$rigSurface" --supervise-epics --member keeper-rig )"
rigCappedA="$( printf '%s\n' "$rigCapped" | LC_ALL=C awk -v want="### The rig epic A ($rigEpicA)" '$0 == want { on = 1 ; next ; } on && /^### / { on = 0 ; } on && /^- / { print ; }' )"
rigAssert "the two newest decisions, the newest first, and no other" "$rigCappedA" "$rigLine35"$'\n'"$rigLine33"
rigAssert "the line counting the cut ones" "$( printf '%s\n' "$rigCapped" | LC_ALL=C grep -c -F "(3 of 5 decisions cut, the oldest: the whole section is the \`## Decisions\` of the vault item, read by \`DistroAgentsItems.fn.sh --get-vault-item $rigEpicA\`)" || : )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WORK DUTY EPIC DECISIONS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WORK_DUTY_EPIC_DECISIONS: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
