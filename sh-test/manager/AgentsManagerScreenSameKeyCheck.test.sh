#!/usr/bin/env bash
## Behavioural check on a key that stands under more than one scope in `Outside Systems` of the Configuration (the owner's report, 2026-10-21: every Slack Channel row under a member
## scope jumped the selection to the top and drew no left pane), run rather than read. The screen's own code runs through the stand-in terminal of the driver
## (check-fixtures/manager-screen.driver.py), and where it would call the dispatcher it calls a stand-in script (check-fixtures/manager-screen.tools.stub.sh) that prints the fixture.
## THE CAUSE: the id of a line of a subject was its group and its key, so the same key held by two scopes of one outside system (SLACK_CHANNEL_MAGIC_TEAM under magic-team and under
## magic-coordinator) made two rows of one id; the selection is kept by that id, and the second row was always found as the first. Held: each of the two rows is its own: selected with
## DOWN it stays selected, the left pane shows its own scope and value; a key held by one scope only keeps the id it always had; the same key in a third scope is its own row too. Offline.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigScreen="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsManagerScreen.py"
rigFixtures="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures"
rigDriver="$rigFixtures/manager-screen.driver.py"
rigTools="$rigFixtures/manager-screen.tools.stub.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigScreen" ] || rigRefuse "the screen is not at the origin: $rigScreen"
[ -f "$rigDriver" ] || rigRefuse "the driver of the screen tests is missing: $rigDriver"
[ -f "$rigTools" ] || rigRefuse "the stand-in for the dispatcher is missing: $rigTools"
rigPython="$( command -v python3 )" || rigRefuse "no python3 on PATH"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenSameKeyCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
export TZ=UTC
mkdir -p "$rigTmp/ws/.local/agents/scratch"
export MMDAPP="$rigTmp/ws"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigLine(){ ## group key state value label source -- a `line` of the subject `systems`, as the digest prints it
	printf 'line\tsystems\t%s\t%s\t%s\t%s\t%s\tA_setting_of_this_outside_system.\tno:set_at_deployment\t-\t-\t%s\t-\t/rig/scope-file\tconfiguration\n' "$1" "$2" "$3" "$4" "$5" "$6"
}
rigScopeLine(){ ## group scope -- the line of a scope of the system: no source
	printf 'line\tsystems\t%s\t%s\tset\t-\tScope_%s\tWhether_this_scope_holds_the_settings.\tno:set_at_deployment\t-\t-\t-\t-\t-\tconfiguration\n' "$1" "$2" "$2"
}
rigCase(){ ## name -- a fresh rig whose digest holds one system with the same keys under three scopes
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	{
		printf 'subject\tsystems\t9\tOutside_Systems\n'
		printf 'group\tsystems\tslack\t6\tslack\ngroup\tsystems\temail\t1\temail\n'
		rigScopeLine slack team-scope
		rigLine slack CHAN_KEY set ID_TEAM Chan_Key team-scope
		rigLine slack ONLY_TEAM set ONE Only_Team team-scope
		rigScopeLine slack member-scope
		rigLine slack CHAN_KEY set ID_MEMBER Chan_Key member-scope
		rigLine slack OTHER_KEY set ID_OTHER Other_Key member-scope
		rigScopeLine slack third-scope
		rigLine slack CHAN_KEY set ID_THIRD Chan_Key third-scope
		rigLine email MAIL_USER set rig@host Mail_User team-scope
	} > "$MANAGER_SCREEN_RIG/rows.--manager-config-digest --full"
	: > "$MANAGER_SCREEN_RIG/calls" ; : > "$MANAGER_SCREEN_RIG/words" ; echo rows > "$MANAGER_SCREEN_RIG/mode"
}
rigScript(){
	rigOut="$( { printf 'tools bash %s\nwall 2026-10-13 02:30 +0000\nsize 140 40\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )"
}
rigVal(){ ## name -- the value of the first `<name>=` line
	printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1
}
rigHolds(){ ## tag, text -- how many lines of that whole screen hold the text anywhere
	printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || :
}

echo "-- the same key under three scopes of one outside system --"
rigCase same
rigScript <<'RIGSCRIPT'
turn
at @configuration systems
turn
wait list 10
rowids rows
keys DOWN DOWN DOWN DOWN DOWN DOWN
wait focus 10
turn
get second
show second
keys DOWN DOWN DOWN
wait focus 10
turn
get third
show third
keys UP UP
wait focus 10
turn
get back
RIGSCRIPT
rigAssert "each of the three rows of the one key is a row of its own; a key one scope holds has the id it always had" "$( rigVal rows | LC_ALL=C tr ' ' '_' )" ".._group_slack_slack_team-scope_slack_CHAN_KEY_slack_ONLY_TEAM_slack_member-scope_slack_CHAN_KEY_member-scope_slack_OTHER_KEY_slack_third-scope_slack_CHAN_KEY_third-scope_group_email_email_MAIL_USER"
rigAssert "the second of them, selected with DOWN, stays selected and is the second: the selection does not return to the first, nor to the top of the list" "$( rigVal second.selectedLabel ) $( rigVal second.index )" "Chan Key 6"
rigAssert "its left pane is drawn and is its own: its value and its scope, not those of the first" "$( rigHolds second 'ID_MEMBER' ) $( rigHolds second 'ID_TEAM' )" "1 0"
rigAssert "the third copy is its own too, and its left pane shows its value" "$( rigVal third.index ) $( rigHolds third 'ID_THIRD' )" "9 1"
rigAssert "going back up returns to the rows it passed, one by one" "$( rigVal back.index )" "7"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SCREEN SAME KEY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
echo "MANAGER_SCREEN_SAME_KEY: OK ($rigPassCount assertions, offline, stand-in terminal and stand-in dispatcher)"
