#!/usr/bin/env bash
## Behavioural check on the --manager-feature-* operations (sh-lib/manager/AgentsTools.ManagerFeature.include): the optional features of mdci-packages-myx as the console's
## `Optional Features` works them, run rather than read. The rig is an origin of links to the real one with mdci-packages-myx replaced by two stand-in features
## (setup.feature-local-ai and setup.feature-lancedb: their check, install and uninstall fragments and the command of local AI), which answer from canned files and log what
## they were called with. A rig workspace, HOME and env -i for every call. Nothing is installed, downloaded or served. Held:
##   1. the list: a row for each feature and each part of local AI (its models), eleven fields each, the state, the bytes on disk, the memory, whether it runs, and the three commands that apply to
##      the state; the feature is read from its own check fragment, run with the workspace, the origin and MDCI_FILES_PATH, in its key: value form; a check that prints nothing is a broken
##      feature; a feature that does not cover this machine is unsupported and has no command
##   2. a part's plan first: its needs and the space as rows, and with no --yes nothing is called but the plan; a plan that is blocked ends 1 and nothing is called; an action the state does not
##      allow, a part and a feature that are none are refused, nothing called
##   3. with --yes the feature's own fragment does the work, the way its deploy runs it (the parts to install in MDCI_LOCAL_AI_PARTS, the part to remove in MDCI_LOCAL_AI_REMOVE; an update is the
##      removal and the install; LanceDB's is its install and its uninstall); the part is asked again after, and the row `done` says what it is; a part that is not what the action should leave ends 1
##   4. the free prompt: the prompt is on the standard input of the command of the feature, the reply is the text of the answer; a model that is not installed, is none or is no chat model, and an
##      empty prompt are refused; the speech test prints the text; a file that is none is refused
##   5. the `local` preset: made by the preset writer from an installed chat model, with the CLI service local and the model; a taken name, a model that is not installed or is a speech model are refused
##      and leave no file
##   6. the caller rule of the family, the arm of the family, no work of the feature done here, and the help pair of each operation
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigHere="$rigPackage/sh-lib"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerFeatureCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}

## THE ORIGIN of the rig: every entry of the real one linked, but for mdci-packages-myx, which is the two stand-ins.
rigOrigin="$rigTmp/origin" rigPk="$rigTmp/origin/myx/mdci-packages-myx" rigState="$rigTmp/state"
rigAi="$rigPk/setup.feature-local-ai" rigDb="$rigPk/setup.feature-lancedb"
mkdir -p "$rigAi/host/install" "$rigAi/data/local-ai" "$rigDb/host/install" "$rigState"
for rigEntry in "$MDLT_ORIGIN"/* "$MDLT_ORIGIN"/.[!.]* ; do
	[ -e "$rigEntry" ] || continue
	[ "${rigEntry##*/}" = myx ] || ln -s "$rigEntry" "$rigOrigin/${rigEntry##*/}"
done
for rigEntry in "$MDLT_ORIGIN/myx"/* ; do
	[ "${rigEntry##*/}" = mdci-packages-myx ] || ln -s "$rigEntry" "$rigOrigin/myx/${rigEntry##*/}"
done
rigMake(){ ## file, text... -- an executable stand-in
	local makeFile="$1" ; shift
	printf '%s\n' "$@" > "$makeFile" ; chmod +x "$makeFile"
}
## the check fragments print what the rig has canned, and log how they were called
rigMake "$rigAi/host/install/feature-local-ai.2.check.txt" '#!/bin/sh' 'echo "CHECK ai PARSE=${MDCI_CHECK_PARSE:-} FILES=${MDCI_FILES_PATH:-} WS=${MMDAPP:-} ORIGIN=${MDLT_ORIGIN:-}" >> "$RIG_STATE/calls"' 'cat "$RIG_STATE/ai.check" 2> /dev/null' 'exit 0'
rigMake "$rigDb/host/install/feature-lancedb.check.txt" '#!/bin/sh' 'echo "CHECK db WS=${MMDAPP:-} ORIGIN=${MDLT_ORIGIN:-}" >> "$RIG_STATE/calls"' 'cat "$RIG_STATE/db.check" 2> /dev/null' 'exit 0'
## the install and uninstall fragments log their call and leave the part as the rig canned it to be after
rigMake "$rigAi/host/install/feature-local-ai.1.install.txt" '#!/bin/sh' 'echo "INSTALL ai PARTS=${MDCI_LOCAL_AI_PARTS:-} FILES=${MDCI_FILES_PATH:-}" >> "$RIG_STATE/calls"' 'echo "a message of the fragment, on its standard output"' '[ ! -f "$RIG_STATE/ai.after-install" ] || cp "$RIG_STATE/ai.after-install" "$RIG_STATE/ai.check"' 'exit "${RIG_FRAGMENT_RC:-0}"'
rigMake "$rigAi/host/install/feature-local-ai.0.uninstall.txt" '#!/bin/sh' 'echo "UNINSTALL ai REMOVE=${MDCI_LOCAL_AI_REMOVE:-} FILES=${MDCI_FILES_PATH:-}" >> "$RIG_STATE/calls"' '[ ! -f "$RIG_STATE/ai.after-uninstall" ] || cp "$RIG_STATE/ai.after-uninstall" "$RIG_STATE/ai.check"' 'exit 0'
rigMake "$rigDb/host/install/feature-lancedb.install.txt" '#!/bin/sh' 'echo "INSTALL db WS=${MMDAPP:-} ORIGIN=${MDLT_ORIGIN:-}" >> "$RIG_STATE/calls"' '[ ! -f "$RIG_STATE/db.after-install" ] || cp "$RIG_STATE/db.after-install" "$RIG_STATE/db.check"' 'exit 0'
rigMake "$rigDb/host/install/feature-lancedb.uninstall.txt" '#!/bin/sh' 'echo "UNINSTALL db WS=${MMDAPP:-}" >> "$RIG_STATE/calls"' '[ ! -f "$RIG_STATE/db.after-uninstall" ] || cp "$RIG_STATE/db.after-uninstall" "$RIG_STATE/db.check"' 'exit 0'
## the command of local AI: the plans are canned, an ask keeps its standard input
rigMake "$rigAi/data/local-ai/mdci-local-ai" '#!/bin/sh' 'echo "TOOL $*" >> "$RIG_STATE/calls"' \
	'case "$1 $2 $3" in "install --dry-run --parse") cat "$RIG_STATE/plan.install" ;; "uninstall --dry-run --parse") cat "$RIG_STATE/plan.uninstall" ;; esac' \
	'case "$1" in' 'ask) cat > "$RIG_STATE/ask.stdin" ; [ ! -f "$RIG_STATE/ask.fail" ] || exit 1 ; printf "%s" "{\"choices\":[{\"message\":{\"content\":\"line1\\nreply \\\"q\\\"\"}}]}" ;;' \
	'transcribe) [ ! -f "$RIG_STATE/stt.fail" ] || exit 1 ; printf "%s" "{\"text\":\" hello world\"}" ;;' 'esac' 'exit 0'

printf '%s\n' 'local-ai: broken' 'host.os: FreeBSD' 'host.ram_bytes: 17179869184' 'host.free_bytes: 900000000000' 'host.profile: shared-cpu' 'disk_bytes: 5000' \
	'part.chat-a.part: chat' 'part.chat-a.state: installed' 'part.chat-a.disk_bytes: 100' 'part.chat-a.expected_bytes: 100' 'part.chat-a.memory_bytes: 116' 'part.chat-a.running: yes' \
	'part.chat-b.part: chat' 'part.chat-b.state: broken' 'part.chat-b.why: the file size differs from the manifest' 'part.chat-b.disk_bytes: 150' 'part.chat-b.expected_bytes: 200' 'part.chat-b.memory_bytes: 233' 'part.chat-b.running: no' \
	'part.stt-a.part: stt' 'part.stt-a.state: not installed' 'part.stt-a.disk_bytes: 0' 'part.stt-a.expected_bytes: 50' 'part.stt-a.memory_bytes: 50' 'part.stt-a.running: no' \
	'part.stt-b.part: stt' 'part.stt-b.state: installed' 'part.stt-b.disk_bytes: 60' 'part.stt-b.expected_bytes: 60' 'part.stt-b.memory_bytes: 60' 'part.stt-b.running: yes' > "$rigState/ai.check.canned"
printf '%s\n' 'lancedb: installed' 'platform: macOS arm64' 'home: /rig/lancedb' 'size: 12 MB' 'versions: lancedb=0.40.0 model2vec=0.10.0 dim=256' 'query: ok' > "$rigState/db.check.canned"
rigReset(){ ## -- the canned state of the features again, with no call logged and no plan
	rm -f "$rigState"/* ; : > "$rigState/calls"
	cp "$rigTmp/ai.check.canned" "$rigState/ai.check" ; cp "$rigTmp/db.check.canned" "$rigState/db.check"
	printf '%s\n' 'plan.action: install' 'plan.package: llama.cpp' 'plan.model: chat-new 2497280256' 'plan.download_bytes: 2497280256' 'plan.free_bytes: 900000000000' 'plan.ram_bytes: 17179869184' 'plan.ram_need_bytes: 2913493632' 'plan.blocked: no' > "$rigState/plan.install"
	printf '%s\n' 'plan.action: uninstall' 'plan.package: llama.cpp' 'plan.remove: chat-a 100' 'plan.reclaim_bytes: 100' 'plan.free_bytes: 900000000000' 'plan.blocked: no' > "$rigState/plan.uninstall"
}
mv "$rigState/ai.check.canned" "$rigTmp/ai.check.canned" ; mv "$rigState/db.check.canned" "$rigTmp/db.check.canned"
rigReset

## THE WORKSPACE of the rig, for the preset writer
rigWs="$rigTmp/ws" rigSkills="$rigTmp/skills" rigAgents="$rigTmp/ws/.local/.agents"
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"
mkdir -p "$rigAgents/scratch" "$rigTmp/home" "$rigSkills/keeper-myx"
printf 'rig\n' > "$rigSkills/keeper-myx/keeper-myx.basic.md" ; printf 'rig\n' > "$rigSkills/keeper-myx/keeper-myx.armed.md"
rigRc=0
rigRun(){ ## input text, tool arguments... -- one dispatcher call from the rig workspace; rc in rigRc, stdout in out, stderr in err
	local runInput="$1" ; shift
	rigRc=0
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" MDAT_SKILLSET_ROOT="$rigSkills" RIG_STATE="$rigState" \
		${rigPre[@]+"${rigPre[@]}"} bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" <<< "$runInput" || rigRc=$?
}
rigPre=()
rigCalls(){ ## -- the calls logged so far, one line, `|` between them
	LC_ALL=C tr '\n' '|' < "$rigState/calls"
}
rigNoCalls(){ ## -- the calls but for the checks
	LC_ALL=C grep -v '^CHECK' "$rigState/calls" | LC_ALL=C tr '\n' '|'
}
rigErr(){ ## text -- how many lines of the last stderr hold it
	LC_ALL=C grep -c -F -- "$1" "$rigTmp/err" || :
}
rigRow(){ ## kind, id or part (field 2/3 match), fields to cut -- one row of the last stdout, those fields, spaced
	LC_ALL=C awk -F'\t' -v kind="$1" -v who="$2" '$1 == kind && ( $2 == who || $3 == who || $4 == who ) { print ; exit }' "$rigTmp/out" | LC_ALL=C cut -f"$3" | LC_ALL=C tr '\t' ' '
}
rigAi_="setup.feature-local-ai" rigDb_="setup.feature-lancedb"
rigCmd="DistroAgentsTools.fn.sh --manager-feature-part"

echo "-- 1. the list --"
rigRun "" --manager-feature-list
rigAssert "the features and the parts: the lancedb feature, the local AI feature, and a row for each of the four models, each of eleven fields" "$rigRc $( LC_ALL=C awk -F'\t' '{ print $1 ":" NF }' "$rigTmp/out" | LC_ALL=C tr '\n' ' ' )" "0 feature:11 feature:11 part:11 part:11 part:11 part:11 "
rigAssert "local AI, from its check: broken as its first line says, the bytes on disk, the memory of the parts that run (116 and 60), running, and no command of its own" "$( rigRow feature "$rigAi_" 2-11 | LC_ALL=C cut -d' ' -f1-8 )" "setup.feature-local-ai - broken 5000 176 yes - -"
rigAssert "its detail is the host and the profile, whitespace read _" "$( rigRow feature "$rigAi_" 11 )" "host.os=FreeBSD;_host.profile=shared-cpu"
rigAssert "chat-a installed: its bytes, its memory, running, an update and an uninstall and no install" "$( rigRow part chat-a 4-10 )" "installed 100 116 yes - $rigCmd update $rigAi_ chat-a $rigCmd uninstall $rigAi_ chat-a"
rigAssert "chat-b broken: the same two commands, and why in its detail" "$( rigRow part chat-b 4-4 ) $( rigRow part chat-b 11 )" "broken part=chat;_why=the_file_size_differs_from_the_manifest"
rigAssert "stt-a not installed: only an install, nothing running, the memory it would take" "$( rigRow part stt-a 4-10 )" "not-installed 0 50 no $rigCmd install $rigAi_ stt-a - -"
rigAssert "a speech model that runs is a part like another" "$( rigRow part stt-b 4-7 )" "installed 60 60 yes"
rigAssert "LanceDB, from its own check: installed, 12 MB on disk as bytes, no memory and no running (a library), its update and uninstall on the feature row, named for the part lancedb" "$( rigRow feature "$rigDb_" 4-10 )" "installed 12582912 - - - $rigCmd update $rigDb_ lancedb $rigCmd uninstall $rigDb_ lancedb"
rigAssert "the checks were run as they are: the key: value form asked of local AI, the workspace, the origin and the data of the feature handed over, and no other fragment called" "$( rigCalls | LC_ALL=C sed -e "s|$rigOrigin|ORIGIN|g" -e "s|$rigWs|WS|g" )" "CHECK db WS=WS ORIGIN=ORIGIN|CHECK ai PARSE=1 FILES=ORIGIN/myx/mdci-packages-myx/setup.feature-local-ai/data WS=WS ORIGIN=ORIGIN|"
printf 'lancedb: not supported here\nplatform: FreeBSD amd64: no wheel\n' > "$rigState/db.check"
: > "$rigState/ai.check"
rigRun "" --manager-feature-list
rigAssert "a feature that does not cover the machine is unsupported, with no command; a check that prints nothing is a broken feature that says so" "$( rigRow feature "$rigDb_" 4-10 | LC_ALL=C cut -d' ' -f1 ) | $( rigRow feature "$rigDb_" 8-10 ) | $( rigRow feature "$rigAi_" 4 ) $( rigRow feature "$rigAi_" 11 ) $( LC_ALL=C grep -c '^part' "$rigTmp/out" || : )" "unsupported | - - - | broken the_check_printed_nothing 0"
rigRun "" --manager-feature-list extra
rigAssert "an argument is refused in one line" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigErr 'syntax is --manager-feature-list, got 1 argument(s)' )" "1 0 1"

echo "-- 2. the plan first --"
rigReset
rigRun "" --manager-feature-part install "$rigAi_" stt-a
rigAssert "without --yes the plan is all there is: its row, a need for the package and one for the model, the exit 0, and not a fragment called" "$rigRc | $( rigRow plan stt-a 1-11 ) | $( LC_ALL=C grep -c '^need' "$rigTmp/out" ) | $( rigNoCalls )" "0 | plan install setup.feature-local-ai stt-a 2497280256 - 900000000000 2913493632 17179869184 no - | 2 | TOOL install --dry-run --parse stt-engine stt-a|"
rigAssert "the needs say the package and the model, whitespace read _" "$( LC_ALL=C grep '^need' "$rigTmp/out" | LC_ALL=C tr '\n' ' ' )" "need	package_llama.cpp need	model_chat-new_2497280256 "
rigAssert "and says it was a plan" "$( rigErr 'that is the plan; nothing was done. Add --yes to install stt-a of setup.feature-local-ai' )" "1"
rigReset
rigRun "" --manager-feature-part install "$rigAi_" stt-a --force
rigAssert "--force goes to the plan of the command, ahead of the part" "$( rigNoCalls )" "TOOL install --dry-run --parse --force stt-engine stt-a|"
rigReset
printf '%s\n' 'plan.action: install' 'plan.model: stt-a 50' 'plan.download_bytes: 50' 'plan.free_bytes: 10' 'plan.ram_bytes: 1' 'plan.ram_need_bytes: 0' 'plan.blocked: yes' 'plan.why: not enough free space in /var/db/mdci-local-ai' > "$rigState/plan.install"
rigRun "" --manager-feature-part install "$rigAi_" stt-a --yes
rigAssert "a plan that is blocked: the plan is printed, the exit is 1, the reason is said, and with --yes too no fragment is called" "$rigRc | $( rigRow plan stt-a 10-11 ) | $( rigErr '⛔ ERROR: DistroAgentsTools --manager-feature-part: install of stt-a of setup.feature-local-ai is not possible here: not enough free space in /var/db/mdci-local-ai -- nothing was done' ) | $( rigNoCalls )" "1 | yes not_enough_free_space_in_/var/db/mdci-local-ai | 1 | TOOL install --dry-run --parse stt-engine stt-a|"
rigReset
for rigTry in "install $rigAi_ chat-a:is installed already; an update installs it again" "install $rigAi_ chat-b:is broken already; an update installs it again" "update $rigAi_ stt-a:is not installed" "uninstall $rigAi_ stt-a:is not installed" "install $rigAi_ nothing:has no part nothing" "install setup.feature-nothing x:no such feature: setup.feature-nothing" ; do
	rigRun "" --manager-feature-part ${rigTry%%:*} --yes
	rigAssert "refused, with nothing called but the checks: ${rigTry%%:*}" "$rigRc $( rigErr "${rigTry#*:} -- nothing was done" ) [$( rigNoCalls )]" "1 1 []"
done
printf 'lancedb: not supported here\n' > "$rigState/db.check"
rigRun "" --manager-feature-part install "$rigDb_" lancedb --yes
rigAssert "a part this machine is not covered for is refused" "$rigRc $( rigErr 'lancedb of setup.feature-lancedb is not supported on this machine -- nothing was done' ) [$( rigNoCalls )]" "1 1 []"
rigRun "" --manager-feature-part sideways "$rigAi_" stt-a
rigAssert "an action that is none, and a call with too few words, are refused with the syntax" "$rigRc $( rigErr 'syntax is (install|update|uninstall) <feature> <part> [--yes] [--force], got: sideways' )" "1 1"
rigRun "" --manager-feature-part install "$rigAi_"
rigAssert "too few words" "$rigRc $( rigErr 'got 2 argument(s) -- nothing was done' )" "1 1"
rigRun "" --manager-feature-part install "$rigAi_" stt-a --now
rigAssert "an option that is none" "$rigRc $( rigErr 'got: --now' )" "1 1"

echo "-- 3. the work is the feature's own fragment --"
rigReset
sed -e 's/^local-ai: broken/local-ai: installed/' -e 's/^part.stt-a.state: not installed/part.stt-a.state: installed/' "$rigTmp/ai.check.canned" > "$rigState/ai.after-install"
rigRun "" --manager-feature-part install "$rigAi_" stt-a --yes
rigAssert "install: the fragment of the install, with the parts to install (the engine and the model) and the data of the feature; the part is installed after; the row done says it; the fragment's own message is on stderr, not stdout" "$rigRc | $( rigNoCalls | LC_ALL=C sed "s|$rigOrigin|ORIGIN|g" ) | $( LC_ALL=C grep '^done' "$rigTmp/out" | LC_ALL=C tr '\t' ' ' ) | $( LC_ALL=C grep -c 'a message of the fragment' "$rigTmp/out" || : ) $( rigErr 'a message of the fragment' )" "0 | TOOL install --dry-run --parse stt-engine stt-a|INSTALL ai PARTS=stt-engine stt-a FILES=ORIGIN/myx/mdci-packages-myx/setup.feature-local-ai/data| | done install setup.feature-local-ai stt-a installed | 0 1"
rigReset
sed -e 's/^part.chat-a.state: installed/part.chat-a.state: not installed/' -e 's/^part.chat-a.disk_bytes: 100/part.chat-a.disk_bytes: 0/' "$rigTmp/ai.check.canned" > "$rigState/ai.after-uninstall"
rigRun "" --manager-feature-part uninstall "$rigAi_" chat-a --yes
rigAssert "uninstall: the fragment of the uninstall with the part to remove; the part is not installed after" "$rigRc | $( rigNoCalls | LC_ALL=C sed "s|$rigOrigin|ORIGIN|g" ) | $( LC_ALL=C grep '^done' "$rigTmp/out" | LC_ALL=C tr '\t' ' ' ) | $( rigRow plan chat-a 5-6 )" "0 | TOOL uninstall --dry-run --parse chat-a|UNINSTALL ai REMOVE=chat-a FILES=ORIGIN/myx/mdci-packages-myx/setup.feature-local-ai/data| | done uninstall setup.feature-local-ai chat-a not-installed | - 100"
rigReset
cp "$rigTmp/ai.check.canned" "$rigState/ai.after-install"
rigRun "" --manager-feature-part update "$rigAi_" chat-b --yes
rigAssert "update of a broken model: the plan is the model once more, the file it has freed, and the space judged on both; the work is the removal and then the install; the model is still broken in the rig's canned after, so it ends 1 and says what it is" "$rigRc | $( rigRow plan chat-b 5-6 ) | $( rigNoCalls | LC_ALL=C sed "s|$rigOrigin|ORIGIN|g" ) | $( rigErr 'ended with the part broken' )" "1 | 200 150 | UNINSTALL ai REMOVE=chat-b FILES=ORIGIN/myx/mdci-packages-myx/setup.feature-local-ai/data|INSTALL ai PARTS=chat-engine chat-b FILES=ORIGIN/myx/mdci-packages-myx/setup.feature-local-ai/data| | 1"
rigReset
sed -e 's/^part.chat-b.state: broken/part.chat-b.state: installed/' -e '/^part.chat-b.why/d' -e 's/^part.chat-b.disk_bytes: 150/part.chat-b.disk_bytes: 200/' "$rigTmp/ai.check.canned" > "$rigState/ai.after-install"
rigRun "" --manager-feature-part update "$rigAi_" chat-b --yes
rigAssert "and where the install leaves it whole, the update ends 0 with the row done" "$rigRc $( LC_ALL=C grep '^done' "$rigTmp/out" | LC_ALL=C tr '\t' ' ' )" "0 done update setup.feature-local-ai chat-b installed"
rigReset
printf '%s\n' 'local-ai: installed' 'host.ram_bytes: 1' 'host.free_bytes: 100' 'part.chat-b.part: chat' 'part.chat-b.state: installed' 'part.chat-b.disk_bytes: 50' 'part.chat-b.expected_bytes: 200' 'part.chat-b.memory_bytes: 233' 'part.chat-b.running: no' > "$rigState/ai.check"
rigRun "" --manager-feature-part update "$rigAi_" chat-b --yes
rigAssert "an update that does not fit even with the old file freed is blocked, and no fragment is called" "$rigRc $( rigRow plan chat-b 10-11 ) [$( rigNoCalls )]" "1 yes not_enough_free_space []"
rigReset
rigPre=( "RIG_FRAGMENT_RC=7" )
rigRun "" --manager-feature-part install "$rigAi_" stt-a --yes
rigPre=()
rigAssert "a fragment that fails and leaves the part as it was: exit 1, the state and the fragment's own status said" "$rigRc | $( LC_ALL=C grep '^done' "$rigTmp/out" | LC_ALL=C tr '\t' ' ' ) | $( rigErr 'ended with the part not-installed (the fragment ended 7)' )" "1 | done install setup.feature-local-ai stt-a not-installed | 1"
rigReset
printf 'lancedb: not installed\nplatform: macOS arm64\nhome: /rig/lancedb\n' > "$rigState/db.check"
cp "$rigTmp/db.check.canned" "$rigState/db.after-install"
rigRun "" --manager-feature-part install "$rigDb_" lancedb --yes
rigAssert "LanceDB: its install fragment, with the workspace and the origin, and nothing for local AI; the plan names no download it does not know; installed after" "$rigRc | $( rigNoCalls | LC_ALL=C sed -e "s|$rigOrigin|ORIGIN|g" -e "s|$rigWs|WS|g" ) | $( rigRow plan lancedb 5-6 ) | $( LC_ALL=C grep '^done' "$rigTmp/out" | LC_ALL=C tr '\t' ' ' )" "0 | INSTALL db WS=WS ORIGIN=ORIGIN| | - - | done install setup.feature-lancedb lancedb installed"
rigAssert "the space it reports is a number: that of the nearest folder that is there" "$( rigRow plan lancedb 7 | LC_ALL=C awk '{ print ( $1 > 0 ) ? "n" : "x" }' )" "n"
cp "$rigTmp/db.check.canned" "$rigState/db.check"
: > "$rigState/calls"
printf 'lancedb: not installed\nplatform: macOS arm64\nhome: /rig/lancedb\n' > "$rigState/db.after-uninstall"
rigRun "" --manager-feature-part uninstall "$rigDb_" lancedb --yes
rigAssert "LanceDB uninstall: the plan frees its 12 MB, the fragment of the uninstall is called, and it is not installed after" "$rigRc $( rigRow plan lancedb 6 ) $( rigNoCalls | LC_ALL=C sed -e "s|$rigWs|WS|g" ) $( LC_ALL=C grep '^done' "$rigTmp/out" | LC_ALL=C cut -f5 )" "0 12582912 UNINSTALL db WS=WS| not-installed"
cp "$rigTmp/db.check.canned" "$rigState/db.check"
: > "$rigState/calls"
cp "$rigTmp/db.check.canned" "$rigState/db.after-install"
rigRun "" --manager-feature-part update "$rigDb_" lancedb --yes
rigAssert "LanceDB update is its install again (the fragment keeps what stands at the pinned versions)" "$rigRc $( rigNoCalls | LC_ALL=C sed -e "s|$rigOrigin|ORIGIN|g" -e "s|$rigWs|WS|g" )" "0 INSTALL db WS=WS ORIGIN=ORIGIN|"

echo "-- 4. the free prompt and the speech test --"
rigReset
rigRun "$( printf 'what is 2+2?\nsay it twice')" --manager-feature-ask chat-a
rigAssert "the reply is the text of the answer, with its newline and its quote as the model wrote them; the prompt went to the command on its standard input, whole" "$rigRc $( LC_ALL=C tr '\n' '|' < "$rigTmp/out" ) $( LC_ALL=C tr '\n' '|' < "$rigState/ask.stdin" )" '0 line1|reply "q"| what is 2+2?|say it twice|'
printf 'a prompt from a file\n' > "$rigTmp/prompt.txt"
rigRun "" --manager-feature-ask chat-a --from-file "$rigTmp/prompt.txt"
rigAssert "from a file, the same" "$rigRc $( LC_ALL=C tr '\n' '|' < "$rigState/ask.stdin" )" "0 a prompt from a file|"
: > "$rigState/calls"
rigRun "x" --manager-feature-ask stt-a
rigAssert "a model that is not installed is refused, nothing asked of the model" "$rigRc $( rigErr 'stt-a is not-installed -- nothing was done' ) $( LC_ALL=C grep -c '^TOOL ask' "$rigState/calls" || : )" "1 1 0"
rigRun "x" --manager-feature-ask stt-b
rigAssert "a speech model is not asked a question: refused before the command of the feature is called" "$rigRc $( rigErr 'stt-b is a stt model, and a prompt goes to a chat model -- nothing was done' ) $( LC_ALL=C grep -c '^TOOL ask' "$rigState/calls" || : )" "1 1 0"
rigRun "x" --manager-feature-ask nothing
rigAssert "a model that is none" "$rigRc $( rigErr 'nothing is no model of the local AI feature -- nothing was done' )" "1 1"
rigRun "   " --manager-feature-ask chat-a
rigAssert "an empty prompt" "$rigRc $( rigErr 'the prompt is empty -- nothing was done' )" "1 1"
: > "$rigState/ask.fail"
rigRun "x" --manager-feature-ask chat-a
rigAssert "a model that does not answer is said, with nothing on stdout" "$rigRc $( rigErr 'the model did not answer' ) $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" "1 1 0"
rm -f "$rigState/ask.fail"
rigRun "" --manager-feature-stt-test
rigAssert "the speech test: the text the server gives, the command asked with no file (it makes the silence itself)" "$rigRc $( LC_ALL=C tr '\n' '|' < "$rigTmp/out" ) $( LC_ALL=C grep -c -x 'TOOL transcribe' "$rigState/calls" || : )" "0  hello world| 1"
printf 'RIFFrig' > "$rigTmp/speech.wav"
rigRun "" --manager-feature-stt-test "$rigTmp/speech.wav"
rigAssert "with a file, the file is handed on" "$rigRc $( LC_ALL=C grep -c -x "TOOL transcribe $rigTmp/speech.wav" "$rigState/calls" || : )" "0 1"
rigRun "" --manager-feature-stt-test "$rigTmp/no-such.wav"
rigAssert "a file that is none is refused" "$rigRc $( rigErr "not a file: $rigTmp/no-such.wav" )" "1 1"
: > "$rigState/stt.fail"
rigRun "" --manager-feature-stt-test
rigAssert "a speech server that does not answer is said" "$rigRc $( rigErr 'the speech endpoint did not answer' )" "1 1"
rm -f "$rigState/stt.fail"

echo "-- 5. the local preset --"
rigReset
rigRun "" --manager-feature-preset chat-a
rigAssert "made by the preset writer: the row says the scope and the model; the file holds the CLI service local and the model" "$rigRc $( LC_ALL=C tr '\t' ' ' < "$rigTmp/out" ) | $( LC_ALL=C sort "$rigAgents/preset-local.agent.env" | LC_ALL=C tr -d '"' | LC_ALL=C tr '\n' ' ' )" "0 created agents:preset-local chat-a | PRESET_CLI_SERVICE=local PRESET_MODEL_OR_MACRO=chat-a "
rigRun "" --manager-feature-preset chat-a
rigAssert "the name is taken: refused by the writer, the preset as it was" "$rigRc | $( LC_ALL=C grep -c 'PRESET_MODEL_OR_MACRO=chat-a' "$rigAgents/preset-local.agent.env" )" "1 | 1"
rigRun "" --manager-feature-preset chat-a --name local-small
rigAssert "another name by --name" "$rigRc $( LC_ALL=C cut -f2 "$rigTmp/out" ) $( [ -f "$rigAgents/preset-local-small.agent.env" ] && echo made )" "0 agents:preset-local-small made"
rigRun "" --manager-feature-preset stt-b --name from-speech
rigAssert "a speech model is refused, no file left" "$rigRc $( rigErr 'stt-b is a stt model, and a preset speaks to a chat model -- nothing was done' ) [$( [ -e "$rigAgents/preset-from-speech.agent.env" ] && echo made )]" "1 1 []"
rigRun "" --manager-feature-preset chat-b --name from-broken
rigAssert "a model that is broken is refused" "$rigRc $( rigErr 'chat-b is broken -- nothing was done' ) [$( [ -e "$rigAgents/preset-from-broken.agent.env" ] && echo made )]" "1 1 []"
rigRun "" --manager-feature-preset nothing --name from-nothing
rigAssert "a model that is none is refused" "$rigRc $( rigErr 'nothing is no model of the local AI feature' )" "1 1"
rigRun "" --manager-feature-preset chat-a --name "Bad Name"
rigAssert "a name that is no preset's is refused by the writer, no file" "$rigRc [$( ls "$rigAgents" | LC_ALL=C grep -c 'Bad' || : )]" "1 [0]"
rigRun "" --manager-feature-preset chat-a --name
rigAssert "--name with no value is a syntax error" "$rigRc $( rigErr 'syntax is --manager-feature-preset <model-id> [--name <preset>] -- nothing was made' )" "1 1"

echo "-- 5b. the endpoint of a local preset: http for the loopback hosts alone --"
rigEndpointRc(){ ## value -- the exit of the setting reader writing PRESET_ENDPOINT_URL of preset local-small
	rigRun "$1" --agents-config-option preset-local-small --upsert-from-stdin PRESET_ENDPOINT_URL
	printf '%s' "$rigRc"
}
rigAssert "http://127.0.0.1:8181/v1, http://localhost:8181/v1 and http://[::1]:8181/v1 are taken" "$( rigEndpointRc http://127.0.0.1:8181/v1 ) $( rigEndpointRc http://localhost:8181/v1 ) $( rigEndpointRc 'http://[::1]:8181/v1' ) $( rigEndpointRc http://127.0.0.1 )" "0 0 0 0"
rigAssert "the value stands in the file as written" "$( LC_ALL=C grep -c -F 'http://127.0.0.1' "$rigAgents/preset-local-small.agent.env" || : )" "1"
rigAssert "another host over http, a host that only begins like loopback, and a url with no host are refused" "$( rigEndpointRc http://example.com/v1 ) $( rigEndpointRc http://127.0.0.1.evil.example/v1 ) $( rigEndpointRc http://localhostx/v1 ) $( rigEndpointRc http:// )" "1 1 1 1"
rigAssert "https is taken as before, and ftp is not" "$( rigEndpointRc https://api.example.com/v1 ) $( rigEndpointRc ftp://127.0.0.1/v1 )" "0 1"

echo "-- 6. the caller rule, the place in the family, the help --"
rigReset
rigPre=( "MDAT_SPAWN_AGENT=magic-coordinator" )
for rigOp in --manager-feature-list "--manager-feature-part install $rigAi_ stt-a --yes" ; do
	rigRun "" $rigOp
	rigAssert "from inside a member's session it is refused in the one line of the family, and nothing is called: ${rigOp%% *}" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigErr "this session acts as magic-coordinator, and a --manager-* operation is the console's own, never run from inside a member's session -- nothing was done" ) [$( rigCalls )]" "1 0 1 []"
done
rigPre=()
rigRun "" --manager-feature-nothing
rigAssert "an operation the subject does not have is refused by name" "$rigRc $( rigErr 'invalid option: --manager-feature-nothing' )" "1 1"
rigAssert "the family has one arm for the features, which sources their include, and that include asks nobody who calls" \
	"$( LC_ALL=C grep -c -x -e '	--manager-feature-\*)' "$rigHere/manager/AgentsTools.Manager.include" || : ) $( LC_ALL=C grep -c -F -e '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsTools.ManagerFeature.include"' "$rigHere/manager/AgentsTools.Manager.include" || : ) $( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/manager/AgentsTools.ManagerFeature.include" | LC_ALL=C grep -c -e 'AgentsToolsManagerCallerCheck' -e 'AgentsToolsActingMember' || : )" "1 1 0"
rigAssert "the include does no work of a feature: no package, no service, no download, no removal of a folder; it runs the fragments and the command of the feature, by sh" \
	"$( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/manager/AgentsTools.ManagerFeature.include" | LC_ALL=C grep -c -E '(^|[^a-zA-Z_-])(pkg|brew|sysrc|service|pip|rm -rf) ' || : ) $( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/manager/AgentsTools.ManagerFeature.include" | LC_ALL=C grep -c -E 'curl|wget' || : )" "0 0"
rigHelpInclude="$rigHere/help/Help.DistroAgentsTools.include" rigHelpMd="$rigHere/help/Help.DistroAgentsTools.help.md"
for rigOp in --manager-feature-list --manager-feature-part --manager-feature-ask --manager-feature-stt-test --manager-feature-preset ; do
	rigAssert "$rigOp has its syntax echo once, its syntax line once and its entry once" "$( LC_ALL=C grep -c -E "^echo \"📘 syntax: DistroAgentsTools.fn.sh $rigOp( |\")" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -E "^📘 syntax: DistroAgentsTools.fn.sh $rigOp( |\$)" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -E "^		$rigOp( |\$)" "$rigHelpMd" || : )" "1 1 1"
done
rigRun "" --help-syntax --manager-feature-
rigAssert "--help-syntax of the family prints the five lines" "$rigRc $( LC_ALL=C grep -c 'syntax: DistroAgentsTools.fn.sh --manager-feature-' "$rigTmp/err" || : )" "0 5"
rigEntry(){ ## operation -- its entry in the help.md, from under its heading to the next operation
	LC_ALL=C awk -v op="$1" 'index( $0, "\t\t" op ) == 1 && ( length( $0 ) == length( op ) + 2 || substr( $0, length( op ) + 3, 1 ) == " " ) { on = 1 ; next } on && /^\t\t--/ { exit } on { print }' "$rigHelpMd"
}
rigAssert "the entry of the list gives the form of the row, and the entry of the part the forms of its plan and its done" "$( rigEntry --manager-feature-list | LC_ALL=C grep -c -F '<feature|part> <feature> <part> <state> <disk-bytes> <memory-bytes> <running> <install> <update> <uninstall> <detail>' ) $( rigEntry --manager-feature-part | LC_ALL=C grep -c -F -e 'plan <action> <feature> <part> <download-bytes> <reclaim-bytes> <free-bytes> <ram-need-bytes> <ram-bytes> <blocked> <why>' -e 'done <action> <feature> <part> <state>' )" "1 2"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MANAGER FEATURE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_FEATURE: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
