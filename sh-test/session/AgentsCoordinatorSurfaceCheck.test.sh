#!/usr/bin/env bash
## Behavioural check on the coordinator's role surface (F7.9 of the refactorings epic): AgentDispatcherTools.fn.sh --tasks, --spawns, --flags, --contacts, --contact,
## --standing-directives, --directive-set and --directive-end, run rather than read, in a rig: a workspace with its team data (the board, magic-coordinator's inbox
## with the state-note) and the real tooling. The surface owns no state; every view is the owner's answer, and the one write, an order of the human-owner,
## is a section of the state-note written THROUGH the note's lock. Held:
##   1. WHO: magic-coordinator, and for what only reads a call from no member's session; another member is refused; a write from no member's session is refused.
##   2. THE VIEWS delegate: --spawns and --flags print what the Dispatcher prints, --contacts what Contacts prints, --contact a record with its access, --tasks the
##      board's counts and active items.
##   3. STANDING DIRECTIVES, three together: an open warning-* item (not a processed one), a coordinator note that carries `standing: yes`, and an order of the
##      human-owner; an order is IN FORCE while its expires-at is none or ahead, shown only then (--all shows an expired one, marked).
##   4. THE WRITE changes the `# Standing directives` section and nothing else of the note (its fields, its stamps, its other body), takes the lock as a session
##      does and gives it back; --directive-set with an id there replaces it, --directive-end takes one out.
##   5. THE LOCK IS NOT BYPASSED: while a pass holds the note, the write waits (it succeeds the moment the lock is given back) and, past its --wait, refuses with
##      the note untouched.
##   6. REFUSED: no text, a text too long, an expires-at that is none or missing, a bad id or wait, an option it does not know, an id that is not there, no note.
##   7. A SPAWN IS GIVEN THEM: the brief (spawn-prepare-brief) has a section `standing directives in force` with the orders and notes in force, or `(none in force)`.
##   8. STANDING IS A ROW OF THE NOTE CONTRACT: `standing: yes|no` meets inbox-item.note's contract (a value off it is refused by the one validator), and the note writer
##      (--member-inbox-note-upsert) sets it with --standing yes|no, on a note only; the surface selects the notes that carry yes.
## Offline, rig tree only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/AgentDispatcherTools.fn.sh"
rigChain="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigDispatcher="$rigPackage/sh-scripts/DistroAgentsDispatcher.fn.sh"
rigContacts="$rigPackage/sh-scripts/DistroAgentsContacts.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsCoordinatorSurfaceCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigWs="$rigTmp/ws" rigHome="$rigTmp/home" rigData="$rigTmp/data" rigSkills="$rigTmp/skills"
rigNote="$rigData/inboxes/magic-coordinator/incoming/note-20260809T155000Z-heartbeat-state-and-lock.md"
mkdir -p "$rigWs/.local/temp" "$rigHome" "$rigData/inboxes/magic-coordinator/incoming" "$rigData/inboxes/magic-coordinator/processed" "$rigSkills/magic-team" "$rigSkills/rig-member" "$rigSkills/magic-coordinator"
for rigState in backlog pending running review blocked parked processed archived retained ; do mkdir -p "$rigData/board/$rigState" ; done
printf '# rig armed\n' > "$rigSkills/rig-member/rig-member.armed.md"
printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator, magic-librarian\ninvitees: magic-team\nrequires-session-kind: coworking\n---\n# rig coworking routine fixture\n' > "$rigSkills/magic-team/magic-team.coworking.routine.md"
rigAs=""
rigRun(){ ## result prefix, script, words... -- rc in rigRc
	local runOut="$1" runScript="$2" ; shift 2
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" ${rigAs:+MDAT_SPAWN_AGENT="$rigAs"} \
		bash -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; exec bash "$@"' rig "$runScript" "$@" ) > "$runOut.out" 2> "$runOut.err" < /dev/null
	rigRc=$?
}
rigSurface(){ ## result prefix, words...
	local surfaceOut="$1" ; shift
	rigRun "$surfaceOut" "$rigTool" "$@"
}
rigHas(){ ## fixed text, file -- how many lines of the file hold it
	LC_ALL=C grep -c -F -- "$1" "$2" || :
}
rigSame(){ ## file, file -- `same`, or the first of what differs
	if cmp -s "$1" "$2" ; then printf same ; else printf 'DIFF:' ; diff "$1" "$2" | head -c 160 | LC_ALL=C tr '\n' '~' ; fi
}
rigWriter(){ ## result prefix, stdin file, words... -- one call of DistroAgentsTools.fn.sh as magic-coordinator; rc in rigRc
	local writerOut="$1" writerIn="$2" ; shift 2
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" MDAT_SPAWN_AGENT=magic-coordinator \
		bash -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; exec bash "$@"' rig "$rigChain" "$@" ) > "$writerOut.out" 2> "$writerOut.err" < "$writerIn"
	rigRc=$?
}
rigField(){ ## key -- a front matter field of the state note
	LC_ALL=C awk -v want="$1: " 'NR == 1 { next } $0 == "---" { exit } index( $0, want ) == 1 { print substr( $0, length( want ) + 1 ) ; exit }' "$rigNote"
}
rigWrite(){ ## the state note as a session leaves it
	printf -- '---\ntype: note\nfrom: magic-coordinator\ndate: 2026-08-09\nowner: magic-coordinator\nstate: heartbeat-finished\nrecheck-date: 2026-01-01 00:00 +0000\nsession-id: rig-pass-0\ntoday-stage: grooming-dispatched\nlast-iteration-date: 2026-10-19\nlast-iteration-timestamp: 2026-10-19T08:00:00Z\n---\n\nLast iteration: rig.\n\n# Day notes\n\nkeep this line\n' > "$rigNote"
}
rigWrite
rigBegin=$( date +%s )
rigFuture="$( date -v+2d '+%Y-%m-%d %H:%M' 2> /dev/null || date -d '+2 days' '+%Y-%m-%d %H:%M' )"
rigPast="2020-01-01 00:00"

echo "-- 1. who --"
rigAs=keeper-x ; rigSurface "$rigTmp/w1" --standing-directives
rigSurface "$rigTmp/w2" --directive-set --text x --expires-at none
rigAs=""
rigSurface "$rigTmp/w3" --directive-set --text x --expires-at none
rigSurface "$rigTmp/w4" --standing-directives
rigAssert "another member: refused for a read and for a write; from no member's session a read is fine and a write is refused; the note is untouched" "$( rigHas 'runs only as magic-coordinator, and this call comes from keeper-x' "$rigTmp/w1.err" ) $( rigHas 'runs only as magic-coordinator, and this call comes from keeper-x' "$rigTmp/w2.err" ) $( rigHas 'a directive is written by magic-coordinator' "$rigTmp/w3.err" ) $rigRc $( rigHas 'runs only as magic-coordinator' "$rigTmp/w4.err" ) $( LC_ALL=C grep -c 'Standing directives' "$rigNote" )" "1 1 1 0 0 0"

echo "-- 3. standing directives, three together --"
printf -- '---\ntype: warning\n---\n\n# a risk\n' > "$rigData/board/running/warning-20261020-rig-risk.md"
printf -- '---\ntype: warning\n---\n\n# a mitigated risk\n' > "$rigData/board/processed/warning-20261001-done.md"
printf '# Keep the rig quiet on weekends\n\nx\n' > "$rigTmp/in1" ; printf '# A plain note\n\nx\n' > "$rigTmp/in2"
rigWriter "$rigTmp/n1" "$rigTmp/in1" --member-inbox-note-upsert magic-coordinator note-20261020T1000Z-rig-standing.md --standing yes
rigWriter "$rigTmp/n2" "$rigTmp/in2" --member-inbox-note-upsert magic-coordinator note-20261020T1000Z-rig-plain.md
rigAs=magic-coordinator
rigSurface "$rigTmp/d1" --directive-set --id use-claude --text "Scaleway is down, use Claude" --expires-at "$rigFuture"
rigSurface "$rigTmp/d2" --directive-set --id forever --text "Slack silence after 22:00" --expires-at none
rigSurface "$rigTmp/d3" --directive-set --id gone --text "Work hard today" --expires-at "$rigPast"
rigAssert "set: said so for each" "$( cat "$rigTmp/d1.out" "$rigTmp/d2.out" "$rigTmp/d3.out" | LC_ALL=C tr '\n' ',' )" "DIRECTIVE: use-claude set,DIRECTIVE: forever set,DIRECTIVE: gone set,"
rigSurface "$rigTmp/s1" --standing-directives
rigAssert "in force together: the open warning (not the processed one), the standing note (not the plain one), the two orders that are in force (not the expired)" "$rigRc $( LC_ALL=C cut -f1,2 "$rigTmp/s1.out" | LC_ALL=C tr '\t' ':' | LC_ALL=C tr '\n' ' ' )" "0 warning:warning-20261020-rig-risk.md note:note-20261020T1000Z-rig-standing.md order:use-claude order:forever "
rigAssert "a warning row names its state, a note row its heading, an order row its set time, its expires-at and its text" "$( LC_ALL=C grep '^warning' "$rigTmp/s1.out" | LC_ALL=C cut -f3 ) | $( LC_ALL=C grep '^note' "$rigTmp/s1.out" | LC_ALL=C cut -f3 ) | $( LC_ALL=C grep '^order	use-claude' "$rigTmp/s1.out" | LC_ALL=C cut -f4,5 | LC_ALL=C tr '\t' '~' )" "running | Keep the rig quiet on weekends | $rigFuture~Scaleway is down, use Claude"
rigSurface "$rigTmp/s2" --standing-directives --all
rigAssert "--all shows the expired one too, marked" "$( LC_ALL=C grep '^order	gone' "$rigTmp/s2.out" | LC_ALL=C cut -f4 )" "$rigPast (expired)"

echo "-- 4. the write changes the section alone, through the lock --"
rigAssert "the note: its other fields and stamps and its other body are as they were; the section stands under its heading; the lock was given back" "$( rigField today-stage ) $( rigField last-iteration-date ) $( rigField last-iteration-timestamp ) $( rigField state ) $( LC_ALL=C grep -c '^keep this line$' "$rigNote" ) $( LC_ALL=C grep -c '^Last iteration: rig\.$' "$rigNote" ) $( LC_ALL=C grep -c '^# Standing directives$' "$rigNote" ) $( LC_ALL=C grep -c '^- ' "$rigNote" )" "grooming-dispatched 2026-10-19 2026-10-19T08:00:00Z heartbeat-finished 1 1 1 3"
rigAssert "an order is one line: id, set time, expires-at, text" "$( LC_ALL=C grep -c -E '^- use-claude \| set [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} \| expires-at: .* \| Scaleway is down, use Claude$' "$rigNote" )" "1"
rigSurface "$rigTmp/r1" --directive-set --id use-claude --text "Scaleway is back, use it again" --expires-at none
rigSurface "$rigTmp/r2" --directive-end --id gone
rigSurface "$rigTmp/r3" --standing-directives --all
rigAssert "an id there is replaced, and an order ended is out; the others stand" "$( LC_ALL=C grep '^order' "$rigTmp/r3.out" | LC_ALL=C cut -f2,5 | LC_ALL=C tr '\t' ':' | LC_ALL=C tr '\n' ',' ) $( LC_ALL=C grep -c '^- ' "$rigNote" )" "forever:Slack silence after 22:00,use-claude:Scaleway is back, use it again, 2"
rigSurface "$rigTmp/r4" --directive-end --id nothere
rigAssert "ending an id that is not there: refused, rc 1" "$rigRc $( rigHas 'no directive nothere stands' "$rigTmp/r4.err" )" "1 1"

echo "-- 5. the lock is not bypassed --"
printf -- '---\ntype: note\nfrom: magic-coordinator\ndate: 2026-08-09\nowner: magic-coordinator\nstate: heartbeat-running\nrecheck-date: 2099-01-01 00:00 +0000\nsession-id: rig-pass-1\ntoday-stage: grooming-dispatched\n---\n\nLast iteration: rig.\n' > "$rigNote.held"
cp "$rigNote" "$rigNote.before"
cp "$rigNote.held" "$rigNote"
cp "$rigNote" "$rigTmp/held.before"
rigSurface "$rigTmp/l1" --directive-set --text "While a pass runs" --expires-at none --wait 2
rigAssert "a session holds the note: the write waits its --wait, refuses naming the lock, and the note is untouched" "$rigRc $( rigHas 'is locked by a session that holds it' "$rigTmp/l1.err" ) $( cmp -s "$rigNote" "$rigTmp/held.before" && printf untouched )" "1 1 untouched"
( sleep 3 ; cp "$rigNote.before" "$rigNote" ) &
rigPid=$!
rigSurface "$rigTmp/l2" --directive-set --id after-wait --text "Written when the pass let go" --expires-at none --wait 20
wait "$rigPid"
rigAssert "the lock given back while it waits: the write goes through on what stands NOW (the orders there before the wait are kept), the lock is given back" "$rigRc $( LC_ALL=C cat "$rigTmp/l2.out" ) $( rigHas '| Written when the pass let go' "$rigNote" ) $( rigField state ) $( LC_ALL=C grep -c '^- ' "$rigNote" )" "0 DIRECTIVE: after-wait set 1 heartbeat-finished 3"
rm -f "$rigNote.held" "$rigNote.before"

echo "-- 6. what is refused --"
cp "$rigNote" "$rigTmp/n.before"
rigSurface "$rigTmp/x1" --directive-set --expires-at none
rigSurface "$rigTmp/x2" --directive-set --text "$( printf 'x%.0s' $(seq 1 401) )" --expires-at none
rigSurface "$rigTmp/x3" --directive-set --text x
rigSurface "$rigTmp/x4" --directive-set --text x --expires-at tomorrow
rigSurface "$rigTmp/x5" --directive-set --text x --expires-at none --id 'bad id'
rigSurface "$rigTmp/x6" --directive-set --text x --expires-at none --wait soon
rigSurface "$rigTmp/x7" --directive-set --text x --expires-at none --soon
rigSurface "$rigTmp/x8" --directive-end
rigAssert "no text, a text too long, no expires-at, an expires-at that is none, a bad id, a bad wait, an unknown option, an end with no id: each refused, the note untouched" "$( rigHas 'one line of at most 400 characters' "$rigTmp/x1.err" ) $( rigHas 'one line of at most 400 characters' "$rigTmp/x2.err" ) $( rigHas 'and is needed: <nothing>' "$rigTmp/x3.err" ) $( rigHas 'and is needed: tomorrow' "$rigTmp/x4.err" ) $( rigHas '--id is letters' "$rigTmp/x5.err" ) $( rigHas '--wait is whole seconds' "$rigTmp/x6.err" ) $( rigHas 'unknown option: --soon' "$rigTmp/x7.err" ) $( rigHas '--id is needed' "$rigTmp/x8.err" ) $( cmp -s "$rigNote" "$rigTmp/n.before" && printf untouched )" "1 1 1 1 1 1 1 1 untouched"
mv "$rigNote" "$rigNote.gone"
rigSurface "$rigTmp/x9" --directive-set --text x --expires-at none
mv "$rigNote.gone" "$rigNote"
rigAssert "no state-note: refused" "$rigRc $( rigHas 'the state-note is not there' "$rigTmp/x9.err" )" "1 1"

echo "-- 2. the views delegate --"
rigRun "$rigTmp/v1" "$rigDispatcher" --active-sessions
rigSurface "$rigTmp/v2" --spawns
rigRun "$rigTmp/v3" "$rigDispatcher" --all-sessions
rigSurface "$rigTmp/v4" --spawns --all
rigRun "$rigTmp/v5" "$rigDispatcher" --current-flags
rigSurface "$rigTmp/v6" --flags
rigAssert "--spawns and --flags print what the Dispatcher prints" "$( rigSame "$rigTmp/v1.out" "$rigTmp/v2.out" ) $( rigSame "$rigTmp/v3.out" "$rigTmp/v4.out" ) $( rigSame "$rigTmp/v5.out" "$rigTmp/v6.out" ) $( LC_ALL=C grep -c -E '^(worktime|weekend|emergency|overtime|learning): ' "$rigTmp/v6.out" )" "same same same 5"
rigAs=""
rigRun "$rigTmp/c0" "$rigContacts" --collect-contact --id alice-one --name "Alice One" --email alice@rig.example --reached-by keeper-x
rigAs=magic-coordinator
rigSurface "$rigTmp/c1" --contacts
rigRun "$rigTmp/c2" "$rigContacts" --all-contacts
rigSurface "$rigTmp/c3" --contact alice-one
rigRecordLines="$( wc -l < "$rigData/contacts/persons/alice-one.md" | tr -d ' ' )"
rigAssert "--contacts is Contacts' rows, none empty; --contact is the record whole, then its access under a heading" "$( rigSame "$rigTmp/c1.out" "$rigTmp/c2.out" ) $( [ -s "$rigTmp/c1.out" ] && printf rows ) $( head -n "$rigRecordLines" "$rigTmp/c3.out" | cmp -s - "$rigData/contacts/persons/alice-one.md" && printf record ) $( sed -n "$(( rigRecordLines + 1 ))p" "$rigTmp/c3.out" )" "same rows record # access"
rigSurface "$rigTmp/c4" --contact nobody-at-all
rigAssert "a contact not recorded: refused" "$rigRc" "1"
rigSurface "$rigTmp/t1" --tasks
rigAssert "--tasks: the counts of each board state and the active items" "$( rigHas 'running: 1' "$rigTmp/t1.out" ) $( rigHas 'processed: 1' "$rigTmp/t1.out" ) $( rigHas 'running/warning-20261020-rig-risk.md' "$rigTmp/t1.out" )" "1 1 1"

echo "-- 8. standing: yes|no is a row of the note contract; the note writer sets it --"
rigStand="$rigData/inboxes/magic-coordinator/incoming/note-20261020T1000Z-rig-standing.md" rigPlain="$rigData/inboxes/magic-coordinator/incoming/note-20261020T1000Z-rig-plain.md"
rigAssert "the writer: the new note has its stamps and standing: yes once; the plain one has no standing" "$( LC_ALL=C grep -c '^standing: yes$' "$rigStand" ) $( LC_ALL=C grep -c '^type: note$' "$rigStand" ) $( LC_ALL=C grep -c '^owner: magic-coordinator$' "$rigStand" ) $( LC_ALL=C grep -c '^standing:' "$rigPlain" )" "1 1 1 0"
rigRun "$rigTmp/k1" "$rigChain" --intern-doc-validate inbox-item.note "$rigStand"
rigRun "$rigTmp/k2" "$rigChain" --intern-doc-validate inbox-item.note "$rigPlain"
rigAssert "the contract takes both: the validator passes the standing note and the plain one" "$( cat "$rigTmp/k1.out" | wc -l | tr -d ' ' ) $( cat "$rigTmp/k2.out" | wc -l | tr -d ' ' )" "0 0"
LC_ALL=C sed 's/^standing: yes$/standing: maybe/' "$rigStand" > "$rigTmp/bad-note.md"
rigRun "$rigTmp/k3" "$rigChain" --intern-doc-validate inbox-item.note "$rigTmp/bad-note.md"
rigAssert "a value off the row (maybe) is refused by the validator, naming the form" "$rigRc $( rigHas 'contract-form' "$rigTmp/k3.out" ) $( rigHas 'standing' "$rigTmp/k3.out" )" "1 1 1"
printf '[]' > "$rigTmp/in3"
rigWriter "$rigTmp/n3" "$rigTmp/in3" --member-inbox-note-upsert magic-coordinator note-20261020T1000Z-rig-standing.md --standing no --edit-patch-from-stdin
rigSurface "$rigTmp/k4" --standing-directives
rigAssert "--standing no on the existing note changes the header alone (body kept) and the surface no longer selects it" "$rigRc $( LC_ALL=C grep -c '^standing: no$' "$rigStand" ) $( LC_ALL=C grep -c '^standing: yes$' "$rigStand" ) $( LC_ALL=C grep -c '^x$' "$rigStand" ) $( rigHas 'note-20261020T1000Z-rig-standing.md' "$rigTmp/k4.out" )" "0 1 0 1 0"
rigWriter "$rigTmp/n4" "$rigTmp/in3" --member-inbox-note-upsert magic-coordinator note-20261020T1000Z-rig-standing.md --standing yes --edit-patch-from-stdin
rigSurface "$rigTmp/k5" --standing-directives
rigAssert "--standing yes again: selected again, the header once" "$rigRc $( LC_ALL=C grep -c '^standing:' "$rigStand" ) $( rigHas 'note-20261020T1000Z-rig-standing.md' "$rigTmp/k5.out" )" "0 1 1"
rigWriter "$rigTmp/n5" "$rigTmp/in1" --member-inbox-note-upsert magic-coordinator note-20261020T1000Z-rig-other.md --standing maybe
rigWriter "$rigTmp/n6" "$rigTmp/in1" --member-inbox-note-upsert magic-coordinator inquiry-20261020T1000Z-rig-other.md --standing yes
rigAssert "--standing maybe and --standing on an inquiry are refused, nothing written" "$( rigHas '--standing is yes or no: maybe' "$rigTmp/n5.err" ) $( rigHas '--standing is for a note' "$rigTmp/n6.err" ) $( ls "$rigData/inboxes/magic-coordinator/incoming" | LC_ALL=C grep -c 'rig-other' )" "1 1 0"

echo "-- 7. a spawn is given them --"
rigBrief(){ ## result prefix
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		bash "$rigChain" --intern-op-spawn-prepare-brief rig-member --routine-default ) > "$1.out" 2> "$1.err" < /dev/null
}
rigBrief "$rigTmp/b1"
rigAssert "the brief has the section, with the orders in force and the note that stands, after the open warnings, before the hand back" "$( LC_ALL=C grep -n -F -e '## open warning-* items' -e '## standing directives in force' -e 'When done, hand back' "$rigTmp/b1.out" | LC_ALL=C cut -d: -f2 | LC_ALL=C tr '\n' '|' ) $( rigHas '- order forever: Slack silence after 22:00' "$rigTmp/b1.out" ) $( rigHas '- order use-claude: Scaleway is back, use it again' "$rigTmp/b1.out" ) $( rigHas '- note note-20261020T1000Z-rig-standing.md: Keep the rig quiet on weekends' "$rigTmp/b1.out" )" "## open warning-* items|## standing directives in force|When done, hand back; then Wait until dismissed.| 1 1 1"
rigSurface "$rigTmp/e1" --directive-set --id until --text "Until the 22nd" --expires-at "$rigFuture"
rigBrief "$rigTmp/b2"
rigAssert "an order that ends is told with its date" "$( rigHas "- order until (until $rigFuture): Until the 22nd" "$rigTmp/b2.out" )" "1"
for rigId in forever use-claude after-wait until ; do rigSurface "$rigTmp/e2$rigId" --directive-end --id "$rigId" ; done
rm -f "$rigData/inboxes/magic-coordinator/incoming/note-20261020T1000Z-rig-standing.md"
rigBrief "$rigTmp/b3"
rigAssert "none in force: the section says so" "$( LC_ALL=C grep -A1 -F '## standing directives in force' "$rigTmp/b3.out" | LC_ALL=C tail -1 )" "(none in force)"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ COORDINATOR SURFACE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'COORDINATOR_SURFACE: OK (%d assertions, offline, rig tree only, %d seconds)\n' "$rigPasses" "$(( $( date +%s ) - rigBegin ))"
