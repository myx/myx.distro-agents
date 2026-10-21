#!/usr/bin/env bash
## Behavioural check on `Presets` and `Tiers` in Settings of the manager screen (sh-lib/manager/AgentsManagerScreen.Presets.py; F10.1, F10.2, F11.7), run rather than read, through the stand-in terminal of the driver and a
## stand-in for the dispatcher that prints the fixture. Held: both folders stand in Settings, ahead of its subjects; the presets are listed by name with what each extends at the end of its row, and the folder selected
## shows them as one table (extends, CLI service, model, effort, used by); a preset opened lists its variables, those it does not hold as empty; Enter on a choice offers its list and its OK
## saves through --manager-scope-set with the scope and the name as words and the value on the standard input alone; a number is asked as a number; the CLI service of a preset that extends is locked and says why;
## `n` makes a preset (a name, what it extends or a CLI service of its own) through --manager-preset-new; the tiers list the team and the members, and Enter on a tier of the team offers the presets. Offline.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigScreen="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsManagerScreen.py"
rigFixtures="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures"
rigDriver="$rigFixtures/manager-screen.driver.py"
rigTools="$rigFixtures/manager-screen.tools.stub.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigScreen" ] && [ -f "$rigDriver" ] && [ -f "$rigTools" ] || rigRefuse "the screen, its driver or its stand-in is missing"
rigPython="$( command -v python3 )" || rigRefuse "no python3 on PATH"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenPresetsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
export TZ=UTC
mkdir -p "$rigTmp/ws/.local/agents/scratch" ; export MMDAPP="$rigTmp/ws"
rigPassCount=0 rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 )) ; fi
}
rigScope(){ ## id, label, keys -- a `scope` row
	printf 'scope\t%s\t%s\t%s\tyes\tyes\t/rig/%s.agent.env\n' "$1" "$2" "$3" "${1#agents:}"
}
rigKey(){ ## name state value type description kind takes -- a `key` row
	printf 'key\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$@"
}
rigCase(){ ## name
	export MANAGER_SCREEN_RIG="$rigTmp/$1"
	mkdir -p "$MANAGER_SCREEN_RIG"
	{
		printf 'preset\tagents:preset-rig-base\tAgents:_preset-rig-base\t1\tyes\tyes\t/rig/preset-rig-base.agent.env\t-\tclaude\t-\t-\tpreset-rig-ext\n'
		printf 'preset\tagents:preset-rig-ext\tAgents:_preset-rig-ext\t2\tyes\tyes\t/rig/preset-rig-ext.agent.env\trig-base\tclaude\tlow\t-\tmagic-team\n'
	} > "$MANAGER_SCREEN_RIG/rows.--manager-preset-list"
	{
		rigScope agents:preset-rig-ext Agents:_preset-rig-ext 2
		rigKey PRESET_EXTEND set rig-base setting Parent choice "rig-base=rig-base,rig-other=rig-other"
		rigKey PRESET_CLI_SERVICE missing - setting Service locked "it_extends_a_preset:_the_CLI_service_is_the_parents,_and_cannot_be_edited"
		rigKey PRESET_EFFORT missing - setting Effort choice "low=low,default=default,high=high"
		rigKey PRESET_CONTEXT_MAX_SIZE missing - setting Context number "1000..10000000"
		rigKey PRESET_EXTRA_SPAWN_LINE missing - setting Line text "-"
	} > "$MANAGER_SCREEN_RIG/rows.--manager-scope-read agents:preset-rig-ext"
	{
		printf 'tier\tagents:magic-team\tTeam\t3\tyes\tno\t/rig/magic-team.agent.env\trig-ext\trig-ext\t-\n'
		printf 'tier\tagents:keeper-myx\tkeeper-myx\t0\tno\tno\t/rig/keeper-myx.agent.env\t-\t-\t-\n'
	} > "$MANAGER_SCREEN_RIG/rows.--manager-preset-tiers"
	{
		rigScope agents:magic-team Agents:_magic-team 3
		rigKey SPAWN_TIER_LOW set rig-ext:high setting Low tier "rig-base,rig-ext/low,normal,high"
		rigKey SPAWN_TIER_NORMAL set rig-ext setting Normal tier "rig-base,rig-ext/low,normal,high"
		rigKey SPAWN_TIER_HIGH missing - setting High tier "rig-base,rig-ext/low,normal,high"
	} > "$MANAGER_SCREEN_RIG/rows.--manager-scope-read agents:magic-team"
	: > "$MANAGER_SCREEN_RIG/calls" ; : > "$MANAGER_SCREEN_RIG/words" ; echo rows > "$MANAGER_SCREEN_RIG/mode"
}
rigScript(){ rigOut="$( { printf 'tools bash %s\nwall 2026-10-21 09:30 +0000\nsize 150 40\n' "$rigTools" ; cat ; } | "$rigPython" -I -B "$rigDriver" "$rigScreen" script 2>&1 )" ; }
rigVal(){ printf '%s\n' "$rigOut" | LC_ALL=C sed -n "s/^$1=//p" | head -1 ; }
rigHolds(){ printf '%s\n' "$rigOut" | LC_ALL=C grep "^$1|" | LC_ALL=C grep -c -F -- "$2" || : ; }
rigCalled(){ LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/calls" || : ; }
rigWords(){ LC_ALL=C grep -c -x -F -- "$1" "$MANAGER_SCREEN_RIG/words" || : ; }

echo "-- CLI Presets and Tiers, in the Configuration --"
rigCase feature
rigScript <<'RIGSCRIPT'
turn
at @configuration
turn
wait list 10
rowids top
keys DOWN DOWN DOWN
wait focus 10
turn
wait focus 10
turn
get on
show summary
keys ENTER
turn
wait list 10
rowids sub
RIGSCRIPT
rigAssert "the Configuration holds CLI Presets and Tiers, and the old item of the CLI services is gone" "$( rigVal top )" ".. checker keys clipresets git subsystems diagnostics"
rigAssert "selected, it shows two compact tables: the presets, and the tiers that are assigned (the team's, and the number of members that use the defaults)" "$( rigVal on.selectedLabel ) $( rigHolds summary 'CLI Service Presets' ) $( rigHolds summary 'Member Tier Assignments' ) $( rigHolds summary 'PRESET    CLI SERVICE' ) $( rigHolds summary 'MEMBER  DEFAULT' ) $( rigHolds summary '1 more member uses the defaults.' )" "CLI Presets and Tiers 1 1 1 1 1"
rigAssert "the keys of its tasks stand in the status line: add a preset, assign a tier, configure, select the CLI" "$( rigHolds summary ' n New  a Assign  c Configure  s Auto-select' )" "1"
rigAssert "opened, it holds its two folders" "$( rigVal sub )" ".. presets tiers"
rigDump(){ ## tag... -- the left pane of those screens (RIG_DUMP=1 prints it, to be read); the frame, the right pane and the empty lines are left out
	[ -z "${RIG_DUMP:-}" ] || RIG_OUT="$rigOut" "$rigPython" -I -c '
import os, sys
for tag in sys.argv[1:]:
    print("== %s ==" % tag)
    for line in os.environ["RIG_OUT"].split("\n"):
        if line.startswith(tag + "|"):
            text = line[len(tag) + 1:].split("│║")[0].split("┐")[0].split("┘")[0]
            text = text[1:] if text[:1] in "│┌└" else text
            if text.strip(" ─") and "Go  View" not in text:
                print(text.rstrip())
' "$@"
}
rigDumpBox(){ ## tag... -- the box (dialog) of those screens: its lines only, the panes behind it cut away
	[ -z "${RIG_DUMP:-}" ] || RIG_OUT="$rigOut" "$rigPython" -I -c '
import os, sys
for tag in sys.argv[1:]:
    print("== %s ==" % tag)
    left = right = None
    for line in os.environ["RIG_OUT"].split("\n"):
        if not line.startswith(tag + "|"):
            continue
        text = line[len(tag) + 1:]
        if left is None and "╔═[■]" in text:
            left = text.index("╔═[■]")
            right = text.index("╗", left) + 1
        if left is not None:
            print(text[left:right].rstrip())
            if "╚" in text[left:right]:
                break
' "$@"
}
rigDump summary

echo "-- the folders and the presets --"
rigCase list
rigScript <<'RIGSCRIPT'
turn
at @settings
turn
wait list 10
rowids top
at @clipresets presets
turn
wait list 10
rowids rows
show p
RIGSCRIPT
rigAssert "Settings holds Scope Settings first and no presets or tiers: those are the Configuration's" "$( rigVal top | LC_ALL=C cut -d' ' -f1-2 )" ".. scopes"
rigAssert "Presets lists the presets by their scope ids" "$( rigVal rows )" ".. agents:preset-rig-base agents:preset-rig-ext"
rigAssert "the folder selected shows them as one table: the preset, what it extends, its CLI service, its model, its effort, and by whom it is used" "$( rigHolds p 'PRESET' ) $( rigHolds p 'rig-ext   rig-base' ) $( rigHolds p 'claude' ) $( rigHolds p 'magic-team' )" "1 1 3 1"

echo "-- a variable by its kind --"
rigCase kinds
rigScript <<'RIGSCRIPT'
turn
at @clipresets presets agents:preset-rig-ext
turn
wait list 10
rowids keys
keys DOWN DOWN
wait focus 10
turn
keys ENTER
turn
get locked
keys DOWN
wait focus 10
turn
keys ENTER
turn
get choice
show choice
keys DOWN SPACE
turn
get picked
keys ENTER
turn
wait action 30
turn 2
keys DOWN
wait focus 10
turn
keys ENTER
turn
get number
RIGSCRIPT
rigAssert "the variables the preset holds and those it does not, in the order of the operation" "$( rigVal keys )" ".. PRESET_EXTEND PRESET_CLI_SERVICE PRESET_EFFORT PRESET_CONTEXT_MAX_SIZE PRESET_EXTRA_SPAWN_LINE"
rigAssert "the CLI service of a preset that extends is locked: no form opens, and the status line says why" "[$( rigVal locked.dialog )] $( rigVal locked.notice | LC_ALL=C cut -c1-80 )" "[] PRESET_CLI_SERVICE cannot be edited: it extends a preset: the CLI service is the"
rigAssert "the effort, a parameter the preset did not hold, opens a form of a choice, titled by it, with its list" "$( rigVal choice.dialog | LC_ALL=C cut -d'|' -f1 ) $( rigVal choice.dialogTitle ) $( rigHolds choice 'default' ) $( rigHolds choice 'high' )" "setting:choice PRESET_EFFORT 1 1"
rigAssert "its OK saves in that scope by --manager-scope-set, the scope and the name as words and the value alone on the standard input" "$( rigWords '[--manager-scope-set][agents:preset-rig-ext][PRESET_EFFORT]' ) $( LC_ALL=C tr -d '\n' < "$MANAGER_SCREEN_RIG/stdin.--manager-scope-set" 2> /dev/null )" "1 default"
rigAssert "a whole number is asked as a number, in its range" "$( rigVal number.dialog | LC_ALL=C cut -d'|' -f1 ) $( rigVal number.dialogTitle )" "setting-number:number PRESET_CONTEXT_MAX_SIZE"

echo "-- a preset made --"
rigCase made
rigScript <<'RIGSCRIPT'
turn
at @clipresets presets
turn
wait list 10
keys n
turn
get dialog
show dialog
RIGSCRIPT
rigAssert "n opens the form of a new preset: its name, what it extends (none among them), its CLI service" "$( rigVal dialog.dialogTitle ) $( rigHolds dialog 'rig-base' ) $( rigHolds dialog 'none' ) $( rigHolds dialog 'claude' )" "New preset 4 3 5"
rigScript <<'RIGSCRIPT'
turn
at @clipresets presets
turn
wait list 10
keys n
turn
keys r i g - n e w TAB DOWN SPACE
turn
keys ENTER
turn
wait action 30
turn 2
RIGSCRIPT
rigAssert "its OK makes it through --manager-preset-new, the name, the way and what it extends as words" "$( rigWords '[--manager-preset-new][rig-new][--extend][rig-base]' )" "1"

echo "-- the tasks: use a preset for a member, assign a tier --"
rigCase use
rigScript <<'RIGSCRIPT'
turn
at @clipresets presets
turn
wait list 10
keys DOWN
wait focus 10
turn
keys f
turn
get who
show who
keys ENTER
turn
get editor
show editor
keys ENTER
wait action 30
turn 2
RIGSCRIPT
rigAssert "f on a preset asks for whom and which tier, naming the preset" "$( rigVal who.dialog | LC_ALL=C cut -d'|' -f1 ) [$( rigVal who.dialogTitle )] $( rigHolds who 'Team' ) $( rigHolds who 'keeper-myx' ) $( rigHolds who 'Low' ) $( rigHolds who 'High' )" "tier-who:who [Use rig-base for] 1 1 1 1"
rigDumpBox who editor
rigAssert "Next opens the two selectors of that tier, the preset chosen being the one selected" "$( rigVal editor.dialog | LC_ALL=C cut -d'|' -f1 ) [$( rigVal editor.dialogTitle )] $( rigHolds editor 'Preset' ) $( rigHolds editor 'Effort' )" "setting-tier:preset [SPAWN_TIER_NORMAL] 2 1"
rigAssert "OK saves the value in the scope of the team by --manager-scope-set" "$( rigWords '[--manager-scope-set][agents:magic-team][SPAWN_TIER_NORMAL]' ) $( LC_ALL=C tr -d '\n' < "$MANAGER_SCREEN_RIG/stdin.--manager-scope-set" 2> /dev/null )" "1 rig-base"
rigCase assign
rigScript <<'RIGSCRIPT'
turn
at @clipresets tiers
turn
wait list 10
keys a
turn
get ask
keys DOWN SPACE TAB DOWN SPACE
turn
keys ENTER
turn
get editor
keys DOWN SPACE TAB DOWN DOWN SPACE
turn
keys ENTER
wait action 30
turn 2
RIGSCRIPT
rigAssert "a on the tiers asks for whom and which tier; the member and the tier chosen come to the two selectors, and the choice is saved as <preset>:<effort> in that member's scope" "[$( rigVal ask.dialogTitle )] [$( rigVal editor.dialogTitle )] $( rigWords '[--manager-scope-set][agents:keeper-myx][SPAWN_TIER_HIGH]' ) $( LC_ALL=C tr -d '\n' < "$MANAGER_SCREEN_RIG/stdin.--manager-scope-set" 2> /dev/null )" "[Assign a tier] [SPAWN_TIER_HIGH] 1 rig-ext:normal"
rigCase configure
rigScript <<'RIGSCRIPT'
turn
at @clipresets presets
turn
wait list 10
keys DOWN DOWN
wait focus 10
turn
keys c
turn
wait dialog 5
get wiz
RIGSCRIPT
rigAssert "c on a preset starts the wizard of the CLI service: it reads what the form needs" "$( rigCalled '--manager-wizard-read cli-service' )" "1"

echo "-- the tiers --"
rigCase tiers
rigScript <<'RIGSCRIPT'
turn
at @clipresets tiers
turn
wait list 10
rowids rows
show t
at @clipresets tiers
turn
wait list 10
keys DOWN ENTER
turn
wait list 10
keys DOWN DOWN
wait focus 10
turn
keys ENTER
turn
get tier
show tier
RIGSCRIPT
rigAssert "the tiers list the team and every member by their scope ids" "$( rigVal rows )" ".. agents:magic-team agents:keeper-myx"
rigAssert "the folder selected shows who has which tier" "$( rigHolds t 'MEMBER' ) $( rigHolds t 'Team' ) $( rigHolds t 'rig-ext' )" "1 2 3"
rigAssert "Enter on a tier of the team opens a form of two selectors, the preset and the effort: the presets alone, no list of presets multiplied by efforts" "$( rigVal tier.dialog | LC_ALL=C cut -d'|' -f1 ) $( rigVal tier.dialogTitle ) $( rigHolds tier 'rig-base' ) $( rigHolds tier 'rig-ext:high' ) $( rigHolds tier 'Preset' ) $( rigHolds tier 'Effort' )" "setting-tier:preset SPAWN_TIER_HIGH 1 0 1 1"
rigScript <<'RIGSCRIPT'
turn
at @clipresets tiers
turn
wait list 10
keys DOWN ENTER
turn
wait list 10
keys DOWN DOWN
wait focus 10
turn
keys ENTER
turn
keys DOWN SPACE TAB DOWN DOWN DOWN SPACE
turn
get picked
show picked
keys ENTER
wait action 30
turn 2
RIGSCRIPT
rigAssert "the effort offers unset, low, normal and high; the two chosen are saved as one value, <preset>:<effort>, alone on the standard input of --manager-scope-set" "$( rigHolds picked 'unset' ) $( rigHolds picked 'high' ) $( rigWords '[--manager-scope-set][agents:magic-team][SPAWN_TIER_HIGH]' ) $( LC_ALL=C tr -d '\n' < "$MANAGER_SCREEN_RIG/stdin.--manager-scope-set" 2> /dev/null )" "3 1 1 rig-ext:high"
rigCase tier2
rigScript <<'RIGSCRIPT'
turn
at @clipresets tiers
turn
wait list 10
keys DOWN ENTER
turn
wait list 10
keys DOWN DOWN DOWN
wait focus 10
turn
keys ENTER
turn
keys ENTER
wait action 30
turn 2
RIGSCRIPT
rigAssert "a tier that is <preset>:<effort> opens with both chosen, and OK as it stands saves the same value" "$( LC_ALL=C tr -d '\n' < "$MANAGER_SCREEN_RIG/stdin.--manager-scope-set" 2> /dev/null )" "rig-ext"
rigCase tier3
rigScript <<'RIGSCRIPT'
turn
at @clipresets tiers
turn
wait list 10
keys DOWN ENTER
turn
wait list 10
keys DOWN
wait focus 10
turn
keys ENTER
turn
keys ENTER
wait action 30
turn 2
RIGSCRIPT
rigAssert "a preset with no effort stays so: the effort selector on unset saves the preset alone" "$( LC_ALL=C tr -d '\n' < "$MANAGER_SCREEN_RIG/stdin.--manager-scope-set" 2> /dev/null )" "rig-ext"

if [ "$rigFailCount" -ne 0 ] ; then echo "⛔ MANAGER SCREEN PRESETS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1 ; fi
echo "MANAGER_SCREEN_PRESETS: OK ($rigPassCount assertions, offline, stand-in terminal and stand-in dispatcher)"
