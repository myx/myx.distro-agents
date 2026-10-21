#!/usr/bin/env bash
## Behavioural check on the librarian's queue of update requests (F7.7 of the refactorings epic): AgentLibrarianTools.fn.sh --request-update,
## --request-result, --queue-list, --queue-take and --queue-done. The queue is magic-librarian's inbox itself, with no store of its own: a request
## is an inquiry-* in its incoming/ that carries an `update-kind`, and it is closed into processed/ by the inbox operation, its outcome in
## `update-outcome` and `update-result`. Run rather than read, in a rig: a data root with the inboxes, a skillset root with the members, a member
## registry with one source copy, the sessions of the librarian with the routines they run, the real tooling.
## Held:
##   1. A REQUEST, of the three kinds (a document, the knowledge base, a skill file) and the three forms: a message (--from-stdin|--from-file), a
##      whole text (--whole-text, a skill only), a concrete edit (--old/--new or --old-from-file/--new-from-file, a skill only). Filed as one
##      inquiry into magic-librarian's inbox, from the template block, its words and its blocks whole (quotes, backslashes, accents, several lines,
##      a text with no final line break); its name is printed; the inquiry meets the inquiry contract. THE TOOLING RECORDS the target file's date
##      and checksum itself (`none` for a skill file not there yet, nothing for a topic or a path that is no file). Refused, with nothing filed: a
##      call from no member, a kind that is none of the three, no target or reason, no text, an empty one, two sources, an unknown option, a target
##      or a reason too long, a whole text or an edit for a document, an edit that lacks its old or its new string or changes nothing, a skill
##      whose source copy is not one, a text that holds a line of a block of its own.
##   2. --reply sets `reply-requested: yes`; a request made without it carries no such key.
##   3. LIST AND TAKE. Only the inquiries that carry an update-kind are the queue, whoever else's mail is in the inbox: --queue-list a row each in the
##      order of their names (name, kind, target, form, from, date); --queue-take one batch, each request whole under a line of its own with where
##      its base stands (BASE: or BASE-CHANGED: -- changed, gone, there now and not then); neither moves anything; an empty queue says so.
##   4. --request-result reads a request that waits as waiting and one that is closed as done, with its outcome and result; a name that is no
##      request is unknown (exit 1).
##   5. --queue-done, the librarian only, one of three: --result (closed), --refuse (refused), --apply (applied; a whole text or an edit of a skill
##      file only, by the path and the checks of --skillset-upsert: without the permission, with learning off, with the file changed under a whole
##      text, with the old string gone or twice, it is refused, says why and the request still waits). A closed request leaves the queue and meets
##      the inquiry contract with its outcome and result.
##   6. THE REPLY. A request made with --reply files one note with the outcome into the requester's inbox when it is closed, whichever way it is
##      closed; a request made without --reply sends nothing back, whichever way it is closed.
## Offline, rig tree only: nothing here reaches Slack or any endpoint.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
rigTool="$rigPackage/sh-scripts/AgentLibrarianTools.fn.sh"
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
rigDispatcher="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
[ -f "$rigDispatcher" ] || rigRefuse "the dispatcher is not at the origin this workspace resolves: $rigDispatcher"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsUpdateRequestsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
trap 'rigProcSignal TERM $rigStarted ; rm -rf -- "$rigTmp"' EXIT
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigWs="$rigTmp/ws" rigHome="$rigTmp/home" rigSkills="$rigTmp/skills"
rigData="$rigWs/.local/agents"
rigSrc="$rigWs/source/rig/rig-proj/skillset"
mkdir -p "$rigWs/.local/temp" "$rigWs/docs" "$rigHome/.agents/magic-team" "$rigTmp/bin" "$rigData/spawned"
: > "$rigHome/.agents/magic-team/members.registry"
for rigMember in magic-librarian rig-member rig-other ; do
	mkdir -p "$rigSkills/$rigMember" "$rigData/inboxes/$rigMember/incoming" "$rigData/inboxes/$rigMember/processed"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md" ; printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
	printf '# %s\n' "$rigMember" > "$rigSkills/$rigMember/SKILL.md"
done
rigIn="$rigData/inboxes/magic-librarian/incoming" rigDone="$rigData/inboxes/magic-librarian/processed"
rigMemberIn="$rigData/inboxes/rig-member/incoming"
## a skill with a source copy, and a skill known only by its install
rigHere="$rigSrc/keeper-here/keeper-here.armed.md"
mkdir -p "$rigSrc/keeper-here" "$rigWs/.local/myx/rig/skillset/keeper-install"
printf -- '---\nmaintainers: rig\n---\n# keeper-here armed\n\nThe first rule is alpha.\nThe second rule is beta.\nThe third rule is beta.\n' > "$rigHere"
printf 'rig\n' > "$rigSrc/keeper-here/keeper-here.basic.md"
mkdir -p "$rigWs/.local/agents"
printf 'keeper-here\t%s\tsource-symlink\trig/rig-proj/skillset/keeper-here\t%s\n' "$rigWs" "$rigSrc/keeper-here" > "$rigWs/.local/agents/members.registry"
printf 'keeper-install\t%s\t.local-symlink\trig/skillset/keeper-install\t%s\n' "$rigWs" "$rigWs/.local/myx/rig/skillset/keeper-install" >> "$rigWs/.local/agents/members.registry"
printf 'The guide of the rig.\n' > "$rigWs/docs/guide.md"
rigHereOrig="$( cat "$rigHere" ; printf x )" ; rigHereOrig="${rigHereOrig%x}"
## the rig's own process list: a session runs while a stand-in process is listed under its id
ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" ; : > "$rigTmp/ps.list"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*)
		while read -r rigPsPid rigPsLine ; do
			kill -0 "$rigPsPid" 2> /dev/null || continue
			case "$*" in
				*pid=*) printf '%s %s\n' "$rigPsPid" "$rigPsLine" ;;
				*) printf '%s\n' "$rigPsLine" ;;
			esac
		done < "${0%/*}/../ps.list"
		exit 0
	;;
esac
exec "${0%/*}/ps.real" "$@"
RIGPS
chmod +x "$rigTmp/bin/ps"
bash -c 'sleep 600 ; :' rig-standin > /dev/null 2>&1 < /dev/null &
rigStand="$!" ; rigStarted="$rigStarted $rigStand" ; rigProcNote "$rigStand" ; disown "$rigStand" 2> /dev/null || :
## the librarian's sessions: one in a routine that allows the write, one in no routine
for rigDir in "$rigSkills/magic-librarian" "$rigData/members/magic-librarian" ; do
	mkdir -p "$rigDir"
	printf -- '---\ntype: routine\nexecutors: magic-librarian\nmaintainers: human-owner\nrequires-session-kind: standalone\nallows: magic-librarian:skillset-upsert\n---\n# rig allowed\n' > "$rigDir/magic-librarian.rig-allowed.routine.md"
done
rigSession(){ ## session id, routine file name (may be empty)
	mkdir -p "$rigData/spawned/$1" "$rigData/sessions/$1"
	printf -- '---\nsession-id: 5e55104a-%s\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: %s\nowner: magic-librarian\nstatus: spawn-started\n%s---\n' "$1" "$1" "$1" "${2:+routine: $2$'\n'}" > "$rigData/spawned/$1/$1.spawn.md"
	printf '%s rig-run --session-id %s\n' "$rigStand" "$1" >> "$rigTmp/ps.list"
}
rigSession lib-allowed magic-librarian.rig-allowed.routine.md
rigSession lib-bare ""
rigAs="" rigSid="" rigStdin=""
rigEnv(){ ## the environment of every call, the same
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigTmp/bin:$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" \
		${rigAs:+MDAT_SPAWN_AGENT="$rigAs"} ${rigSid:+MDAT_SPAWN_SESSION_ID="$rigSid"} "$@"
}
rigRun(){ ## result prefix, tool words... -- one call of AgentLibrarianTools.fn.sh as the member in rigAs (session rigSid); stdin from rigStdin (a file) else none; rc in rigRc
	local runOut="$1" ; shift
	( cd "$rigWs" && rigEnv bash -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; exec bash "$0" "$@"' "$rigTool" "$@" ) > "$runOut.out" 2> "$runOut.err" < "${rigStdin:-/dev/null}"
	rigRc=$?
}
rigOther(){ ## result prefix, script, words... -- another script of the package in the same rig
	local otherOut="$1" otherScript="$2" ; shift 2
	( cd "$rigWs" && rigEnv bash -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; exec bash "$@"' rig "$rigPackage/sh-scripts/$otherScript" "$@" ) > "$otherOut.out" 2> "$otherOut.err" < /dev/null
	rigRc=$?
}
rigValidate(){ ## inbox file -- the validator's rows for it as an inquiry, counted
	( cd "$rigWs" && rigEnv bash "$rigDispatcher" --intern-doc-validate inbox-item.inquiry "$1" 2> /dev/null < /dev/null ) | LC_ALL=C grep -c . || :
}
rigValidateNote(){ ## inbox file -- the same as a note
	( cd "$rigWs" && rigEnv bash "$rigDispatcher" --intern-doc-validate inbox-item.note "$1" 2> /dev/null < /dev/null ) | LC_ALL=C grep -c . || :
}
rigKey(){ ## file, key
	LC_ALL=C awk -v want="$2: " 'NR == 1 { if ( $0 != "---" ) exit ; next ; } $0 == "---" { exit ; } index( $0, want ) == 1 { print substr( $0, length( want ) + 1 ) ; exit ; }' "$1" 2> /dev/null
}
rigCount(){ ## folder -- the inquiries in it
	ls "$1" 2> /dev/null | LC_ALL=C grep -c '^inquiry-' || :
}
rigNotes(){ ## folder -- the notes in it
	ls "$1" 2> /dev/null | LC_ALL=C grep -c '^note-' || :
}
rigHas(){ ## fixed text, file -- how many lines of the file hold it
	LC_ALL=C grep -c -F -- "$1" "$2" || :
}
rigBytes(){ ## file -- every byte of a file
	[ -f "$1" ] || { printf 'MISSING' ; return 0 ; }
	od -An -c "$1" | tr -d ' \n'
}
rigSum(){ ## file -- its checksum as the queue records it
	printf 'sha256:%s' "$( shasum -a 256 "$1" | LC_ALL=C cut -d ' ' -f 1 )"
}
rigText=$'First line of the text.\nA "quoted" word, a back\\slash, an accent: café, and a tab:\there.\n\nThe last line.'
rigBegin=$( date +%s )
rigRigIn(){ ## output file -- the name a --request-update printed, its first line
	LC_ALL=C sed -n 1p "$1"
}

echo "-- 1. a request: message, document, knowledge, skill --"
printf '%s\n' "$rigText" > "$rigTmp/text.in"
rigAs=rig-member ; rigStdin="$rigTmp/text.in"
rigRun "$rigTmp/r1" --request-update --kind document --target 'docs/guide.md' --why 'the Wait rules changed in F7.2' --from-stdin
rigStdin=""
rigNameA="$( rigRigIn "$rigTmp/r1.out" )" ; rigFileA="$rigIn/$rigNameA"
rigAssert "a member's request is filed, its name printed: inquiry, stamp, update, kind, eight hex characters" "$rigRc $( printf '%s' "$rigNameA" | LC_ALL=C grep -c -E '^inquiry-[0-9]{8}T[0-9]{4}Z-update-document-[0-9a-f]{8}\.md$' ) $( rigCount "$rigIn" )" "0 1 1"
rigAssert "its frontmatter: from the member, to the librarian, the kind, the target, the form message" "$( rigKey "$rigFileA" type ) $( rigKey "$rigFileA" from ) $( rigKey "$rigFileA" owner ) $( rigKey "$rigFileA" update-kind ) [$( rigKey "$rigFileA" update-target )] $( rigKey "$rigFileA" update-form )" 'inquiry rig-member magic-librarian document [docs/guide.md] message'
rigAssert "its body: the title from the template, the reason, and the member's text whole" "$( rigHas '# Inquiry: rig-member asks for an update of the document docs/guide.md' "$rigFileA" ) $( rigHas 'Why: the Wait rules changed in F7.2' "$rigFileA" ) $( rigHas 'A "quoted" word, a back\slash, an accent: café, and a tab:	here.' "$rigFileA" ) $( rigHas 'The last line.' "$rigFileA" )" "1 1 1 1"
rigAssert "THE TOOLING RECORDED the date and the checksum of the document, which the requester never gave" "$( rigKey "$rigFileA" update-target-checksum ) $( rigKey "$rigFileA" update-target-date | LC_ALL=C grep -c -E '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} [+-][0-9]{4}$' )" "$( rigSum "$rigWs/docs/guide.md" ) 1"
rigAssert "the inquiry meets the inquiry contract: the validator finds no row" "$( rigValidate "$rigFileA" )" "0"
printf '%s\n' 'From a file.' > "$rigTmp/text.file"
rigRun "$rigTmp/r1b" --request-update --kind knowledge --target 'the wait source modes' --why 'learned in a session' --from-file "$rigTmp/text.file"
rigNameB="$( rigRigIn "$rigTmp/r1b.out" )" ; rigFileB="$rigIn/$rigNameB"
rigAssert "from --from-file, of the kind knowledge: a topic is no file, so nothing is recorded of it" "$rigRc $( rigKey "$rigFileB" update-kind ) $( rigHas 'From a file.' "$rigFileB" ) $( rigValidate "$rigFileB" ) [$( rigKey "$rigFileB" update-target-date )][$( rigKey "$rigFileB" update-target-checksum )]" "0 knowledge 1 0 [][]"
rigRun "$rigTmp/r1c" --request-update --kind skill --target 'keeper-here:keeper-here.armed.md' --why 'the rules are out of date' --from-file "$rigTmp/text.file"
rigNameC="$( rigRigIn "$rigTmp/r1c.out" )" ; rigFileC="$rigIn/$rigNameC"
rigAssert "a message about a skill file: its target is member:pathname, the file in the member's SOURCE copy is recorded (checksum and date)" "$rigRc $( rigKey "$rigFileC" update-kind ) $( rigKey "$rigFileC" update-target ) $( rigKey "$rigFileC" update-form ) $( rigKey "$rigFileC" update-target-checksum ) $( rigKey "$rigFileC" update-target-date | LC_ALL=C grep -c . ) $( rigValidate "$rigFileC" )" "0 skill keeper-here:keeper-here.armed.md message $( rigSum "$rigHere" ) 1 0"
rigRun "$rigTmp/r1d" --request-update --kind skill --target 'keeper-here:reference/new-notes.md' --why 'a new file is wanted' --from-file "$rigTmp/text.file"
rigNameD="$( rigRigIn "$rigTmp/r1d.out" )" ; rigFileD="$rigIn/$rigNameD"
rigAssert "a skill file that is not there yet is recorded as none, with no date" "$rigRc $( rigKey "$rigFileD" update-target-checksum ) [$( rigKey "$rigFileD" update-target-date )] $( rigValidate "$rigFileD" )" "0 none [] 0"
rigAssert "none of these asked for the outcome: no reply-requested key" "$( rigHas 'reply-requested' "$rigFileA" )$( rigHas 'reply-requested' "$rigFileB" )$( rigHas 'reply-requested' "$rigFileC" )$( rigHas 'reply-requested' "$rigFileD" )" "0000"
rigAs="" ; rigRun "$rigTmp/r1e" --request-update --kind document --target t --why w --from-file "$rigTmp/text.file"
rigAssert "a call from no member is refused, and nothing is filed" "$rigRc $( rigHas 'a request is made by a member' "$rigTmp/r1e.err" ) $( rigCount "$rigIn" )" "1 1 4"
rigAs=rig-member
rigRun "$rigTmp/r1f" --request-update --kind code --target t --why w --from-file "$rigTmp/text.file"
rigAssert "a kind that is none of document, knowledge, skill is refused" "$rigRc $( rigHas 'syntax is --kind document|knowledge|skill' "$rigTmp/r1f.err" ) $( rigCount "$rigIn" )" "1 1 4"
rigRun "$rigTmp/r1g" --request-update --kind document --why w --from-file "$rigTmp/text.file"
rigAssert "no target is refused" "$rigRc $( rigHas '--target and --why are needed' "$rigTmp/r1g.err" ) $( rigCount "$rigIn" )" "1 1 4"
rigRun "$rigTmp/r1h" --request-update --kind document --target t --from-file "$rigTmp/text.file"
rigAssert "no reason is refused" "$rigRc $( rigHas '--target and --why are needed' "$rigTmp/r1h.err" ) $( rigCount "$rigIn" )" "1 1 4"
rigRun "$rigTmp/r1i" --request-update --kind document --target t --why w
rigAssert "no source of the text is refused" "$rigRc $( rigHas 'neither was given' "$rigTmp/r1i.err" ) $( rigCount "$rigIn" )" "1 1 4"
: > "$rigTmp/empty.in"
rigRun "$rigTmp/r1j" --request-update --kind document --target t --why w --from-file "$rigTmp/empty.in"
rigAssert "an empty text is refused" "$rigRc $( rigHas 'the text is empty' "$rigTmp/r1j.err" ) $( rigCount "$rigIn" )" "1 1 4"
rigStdin="$rigTmp/text.in"
rigRun "$rigTmp/r1k" --request-update --kind document --target t --why w --from-stdin --from-file "$rigTmp/text.file"
rigStdin=""
rigAssert "both sources are refused" "$rigRc $( rigHas 'not both' "$rigTmp/r1k.err" ) $( rigCount "$rigIn" )" "1 1 4"
rigRun "$rigTmp/r1l" --request-update --kind document --target t --why w --from-file "$rigTmp/text.file" --soon
rigAssert "an option it does not know is refused" "$rigRc $( rigHas 'unknown option: --soon' "$rigTmp/r1l.err" ) $( rigCount "$rigIn" )" "1 1 4"
rigLong="$( printf 'x%.0s' $(seq 1 201) )"
rigRun "$rigTmp/r1m" --request-update --kind document --target "$rigLong" --why w --from-file "$rigTmp/text.file"
rigLongWhy="$( printf 'y%.0s' $(seq 1 301) )"
rigRun "$rigTmp/r1n" --request-update --kind document --target t --why "$rigLongWhy" --from-file "$rigTmp/text.file"
rigAssert "a target of more than 200 characters, a reason of more than 300: refused" "$rigRc $( rigHas 'at most 200 characters' "$rigTmp/r1m.err" ) $( rigHas 'at most 200 characters' "$rigTmp/r1n.err" ) $( rigCount "$rigIn" )" "1 1 1 4"
rigRun "$rigTmp/r1o" --request-update --kind document --target t --why w --from-file "$rigTmp/nothing"
rigAssert "a file that is not there is refused" "$rigRc $( rigHas 'names no file' "$rigTmp/r1o.err" ) $( rigCount "$rigIn" )" "1 1 4"
rigRun "$rigTmp/r1p" --request-update --kind skill --target 'keeper-install:keeper-install.armed.md' --why w --from-file "$rigTmp/text.file"
rigRun "$rigTmp/r1q" --request-update --kind skill --target 'keeper-nobody:x.md' --why w --from-file "$rigTmp/text.file"
rigRun "$rigTmp/r1r" --request-update --kind skill --target 'keeper-here:../x.md' --why w --from-file "$rigTmp/text.file"
rigAssert "a skill target the tooling cannot resolve (only an install, no row at all, a path that leaves the folder): refused with the reason, nothing filed" "$rigRc $( rigHas 'keeper-install has no source copy' "$rigTmp/r1p.err" ) $( rigHas 'has no row for keeper-nobody' "$rigTmp/r1q.err" ) $( rigHas "<pathname> is a path below the skill's folder" "$rigTmp/r1r.err" ) $( rigCount "$rigIn" )" "1 1 1 1 4"

echo "-- 2. the whole text and the concrete edit, and --reply --"
printf -- '---\nmaintainers: rig\n---\n# keeper-here notes\n\nA new file "quoted", a back\\slash, café.\nWith no break at the end' > "$rigTmp/whole.md"
rigStdin="$rigTmp/whole.md"
rigRun "$rigTmp/r2" --request-update --kind skill --target 'keeper-here:reference/new-notes.md' --why 'the notes are wanted whole' --whole-text --reply --from-stdin
rigStdin=""
rigNameE="$( rigRigIn "$rigTmp/r2.out" )" ; rigFileE="$rigIn/$rigNameE"
rigAssert "a whole text for a skill file: form text, the recorded base none, the outcome asked for (--reply)" "$rigRc $( rigKey "$rigFileE" update-form ) $( rigKey "$rigFileE" update-target-checksum ) $( rigKey "$rigFileE" reply-requested ) $( rigValidate "$rigFileE" )" "0 text none yes 0"
rigAssert "its text stands in the body between marker lines, with the end line saying there is no final line break" "$( rigHas '----- update text begin -----' "$rigFileE" ) $( rigHas '----- update text end (no final line break) -----' "$rigFileE" ) $( rigHas 'With no break at the end' "$rigFileE" ) $( rigHas 'A new file "quoted", a back\slash, café.' "$rigFileE" )" "1 1 1 1"
printf -- '---\nmaintainers: rig\n---\n# keeper-here armed\n\nThe whole text proposed for the armed file.\n' > "$rigTmp/whole2.md"
rigStdin="$rigTmp/whole2.md"
rigRun "$rigTmp/r2b" --request-update --kind skill --target 'keeper-here:keeper-here.armed.md' --why 'rewrite it' --whole-text --reply --from-stdin
rigStdin=""
rigNameH="$( rigRigIn "$rigTmp/r2b.out" )" ; rigFileH="$rigIn/$rigNameH"
rigRun "$rigTmp/r2c" --request-update --kind skill --target 'keeper-here:keeper-here.armed.md' --why 'alpha is gamma now' --old 'first rule is alpha' --new 'first rule is gamma'
rigNameF="$( rigRigIn "$rigTmp/r2c.out" )" ; rigFileF="$rigIn/$rigNameF"
rigAssert "a concrete edit by --old and --new: form edit, the recorded base of the file as it stands, no reply asked" "$rigRc $( rigKey "$rigFileF" update-form ) $( rigKey "$rigFileF" update-target-checksum ) [$( rigKey "$rigFileF" reply-requested )] $( rigValidate "$rigFileF" )" "0 edit $( rigSum "$rigHere" ) [] 0"
rigAssert "its old and its new string stand in the body between marker lines, whole" "$( rigHas '----- update old begin -----' "$rigFileF" ) $( rigHas 'first rule is alpha' "$rigFileF" ) $( rigHas '----- update old end (no final line break) -----' "$rigFileF" ) $( rigHas '----- update new begin -----' "$rigFileF" ) $( rigHas 'first rule is gamma' "$rigFileF" ) $( rigHas '----- update new end (no final line break) -----' "$rigFileF" )" "1 1 1 1 1 1"
printf 'The third rule is beta.' > "$rigTmp/old.txt" ; printf 'The third rule\nis delta, "quoted", a back\\slash, café.\n' > "$rigTmp/new.txt"
rigRun "$rigTmp/r2d" --request-update --kind skill --target 'keeper-here:keeper-here.armed.md' --why 'the third rule changed' --old-from-file "$rigTmp/old.txt" --new-from-file "$rigTmp/new.txt"
rigNameG="$( rigRigIn "$rigTmp/r2d.out" )" ; rigFileG="$rigIn/$rigNameG"
rigAssert "a concrete edit from two files: the strings kept whole, a new string that ends in a line break among them" "$rigRc $( rigKey "$rigFileG" update-form ) $( rigHas 'The third rule is beta.' "$rigFileG" ) $( rigHas 'is delta, "quoted", a back\slash, café.' "$rigFileG" ) $( rigHas '----- update new end -----' "$rigFileG" ) $( rigValidate "$rigFileG" )" "0 edit 1 1 1 0"
rigRun "$rigTmp/r2e" --request-update --kind skill --target 'keeper-here:keeper-here.armed.md' --why 'is beta twice' --reply --old 'is beta.' --new 'is beta indeed.'
rigNameI="$( rigRigIn "$rigTmp/r2e.out" )" ; rigFileI="$rigIn/$rigNameI"
rigAssert "a request with --reply and an edit: the key is yes" "$rigRc $( rigKey "$rigFileI" reply-requested ) $( rigValidate "$rigFileI" )" "0 yes 0"
rigRun "$rigTmp/r2f" --request-update --kind document --target 'docs/guide.md' --why w --whole-text --from-file "$rigTmp/text.file"
rigRun "$rigTmp/r2g" --request-update --kind knowledge --target t --why w --old a --new b
rigAssert "a whole text and an edit are for a skill file: refused for a document and for a knowledge topic" "$rigRc $( rigHas 'are for a skill file, --kind skill' "$rigTmp/r2f.err" ) $( rigHas 'are for a skill file, --kind skill' "$rigTmp/r2g.err" )" "1 1 1"
rigRun "$rigTmp/r2h" --request-update --kind skill --target 'keeper-here:keeper-here.armed.md' --why w --old a
rigRun "$rigTmp/r2i" --request-update --kind skill --target 'keeper-here:keeper-here.armed.md' --why w --new b
rigRun "$rigTmp/r2j" --request-update --kind skill --target 'keeper-here:keeper-here.armed.md' --why w --old a --new a
rigRun "$rigTmp/r2k" --request-update --kind skill --target 'keeper-here:keeper-here.armed.md' --why w --old '' --new b
rigRun "$rigTmp/r2l" --request-update --kind skill --target 'keeper-here:keeper-here.armed.md' --why w --old a --new b --from-file "$rigTmp/text.file"
rigRun "$rigTmp/r2m" --request-update --kind skill --target 'keeper-here:keeper-here.armed.md' --why w --old a --old-from-file "$rigTmp/old.txt" --new b
rigAssert "an edit with only its old or only its new string, one that changes nothing, an empty old string, one given a text of its own, an old string given twice: refused" "$( cat "$rigTmp/r2h.err" "$rigTmp/r2i.err" | LC_ALL=C grep -c 'needs its old string' ) $( rigHas 'the new string is the old one' "$rigTmp/r2j.err" ) $( rigHas 'is not empty' "$rigTmp/r2k.err" ) $( rigHas 'takes no text of its own' "$rigTmp/r2l.err" ) $( rigHas 'needs its old string' "$rigTmp/r2m.err" )" "2 1 1 1 1"
printf -- 'A line\n----- update text begin -----\nanother\n' > "$rigTmp/marker.in"
rigStdin="$rigTmp/marker.in"
rigRun "$rigTmp/r2n" --request-update --kind skill --target 'keeper-here:keeper-here.armed.md' --why w --whole-text --from-stdin
rigStdin=""
rigAssert "a text that holds a line of a block of its own could not be told from the block: refused" "$rigRc $( rigHas 'could not be told from the block' "$rigTmp/r2n.err" )" "1 1"
rigAssert "nothing of what was refused was filed: the nine requests stand" "$( rigCount "$rigIn" )" "9"

echo "-- 3. list and take --"
## mail that is no request: an inquiry without an update-kind, and a note
printf -- '---\ntype: inquiry\nfrom: rig-other\nowner: magic-librarian\n---\n# Inquiry: a plain question\n\nNo update-kind here.\n' > "$rigIn/inquiry-20261020T0000Z-plain.md"
printf -- '---\ntype: note\nfrom: rig-other\nowner: magic-librarian\n---\n# Note: a note\n\nA note.\n' > "$rigIn/note-20261020T0000Z-note.md"
rigAs=rig-other
rigRun "$rigTmp/l3" --queue-list
rigAssert "the queue is the inquiries that carry an update-kind, nine rows, the plain inquiry and the note not among them" "$rigRc $( LC_ALL=C grep -c . "$rigTmp/l3.out" ) $( LC_ALL=C cut -f1 "$rigTmp/l3.out" | LC_ALL=C grep -c '^inquiry-.*-update-' )" "0 9 9"
rigAssert "a row: name, kind, target, form, from, date" "$( LC_ALL=C grep "^$rigNameA" "$rigTmp/l3.out" | LC_ALL=C cut -f1-4 | LC_ALL=C tr '\t' '|' | LC_ALL=C sed "s/$rigNameA/<A>/" ) $( LC_ALL=C grep "^$rigNameF" "$rigTmp/l3.out" | LC_ALL=C cut -f2-5 | LC_ALL=C tr '\t' '|' ) $( LC_ALL=C cut -f6 "$rigTmp/l3.out" | LC_ALL=C grep -c -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}' )" "<A>|document|docs/guide.md|message skill|keeper-here:keeper-here.armed.md|edit|rig-member 9"
rigAssert "the rows are in the order of their names" "$( LC_ALL=C cut -f1 "$rigTmp/l3.out" | LC_ALL=C sort -c 2>&1 && printf sorted )" "sorted"
rigRun "$rigTmp/t3" --queue-take
rigAssert "taken, the batch says how many wait and holds each request whole under a line of its own" "$rigRc $( LC_ALL=C sed -n 1p "$rigTmp/t3.out" ) $( LC_ALL=C grep -c '^=== UPDATE-REQUEST [1-9]/9: inquiry-' "$rigTmp/t3.out" ) $( rigHas 'A "quoted" word, a back\slash' "$rigTmp/t3.out" ) $( rigHas 'With no break at the end' "$rigTmp/t3.out" ) $( rigHas 'No update-kind here.' "$rigTmp/t3.out" )" "0 UPDATE-BATCH: 9 request(s) waiting 9 1 1 0"
rigBaseIs(){ ## request name, batch file, text -- 1 where the base line of that request in the batch begins with the text, else 0 (none: 0)
	LC_ALL=C awk -v name="$1" -v want="$3" 'index( $0, "=== UPDATE-REQUEST " ) == 1 { on = ( index( $0, name ) > 0 ) ; next ; } on && ( index( $0, "BASE:" ) == 1 || index( $0, "BASE-CHANGED:" ) == 1 ) { found = ( index( $0, want ) == 1 ) ; exit ; } END { print found + 0 ; }' "$2"
}
rigBaseAny(){ ## request name, batch file -- how many base lines that request has in the batch
	LC_ALL=C awk -v name="$1" 'index( $0, "=== UPDATE-REQUEST " ) == 1 { on = ( index( $0, name ) > 0 ) ; next ; } on && ( index( $0, "BASE:" ) == 1 || index( $0, "BASE-CHANGED:" ) == 1 ) { n++ ; } END { print n + 0 ; }' "$2"
}
rigAssert "where the base stands: BASE for the document and the skill file as they were, BASE for the file not there yet and not there now" "$( rigBaseIs "$rigNameA" "$rigTmp/t3.out" 'BASE: docs/guide.md is unchanged since this was written' ) $( rigBaseIs "$rigNameC" "$rigTmp/t3.out" 'BASE: keeper-here:keeper-here.armed.md is unchanged since this was written' ) $( rigBaseIs "$rigNameD" "$rigTmp/t3.out" 'BASE: the file was not there when this was written, and is not there now' )" "1 1 1"
rigAssert "a topic recorded no base: no line for it" "$( rigBaseAny "$rigNameB" "$rigTmp/t3.out" )" "0"
rigAssert "listing and taking moved nothing: the nine requests, the plain inquiry and the note are in incoming/, nothing in processed/" "$( ls "$rigIn" | LC_ALL=C grep -c . ) $( rigCount "$rigDone" )" "11 0"
printf 'The guide of the rig, changed.\n' > "$rigWs/docs/guide.md"
rigRun "$rigTmp/t3b" --queue-take
rigAssert "the document changed after the request: BASE-CHANGED, with the checksum it was and the checksum it is" "$( rigBaseIs "$rigNameA" "$rigTmp/t3b.out" "BASE-CHANGED: docs/guide.md changed after this was written: it was $( rigKey "$rigFileA" update-target-checksum ) (" ) $( rigHas ", it is $( rigSum "$rigWs/docs/guide.md" ) (" "$rigTmp/t3b.out" )" "1 1"
rm -f "$rigWs/docs/guide.md"
rigRun "$rigTmp/t3c" --queue-take
rigAssert "the document gone: BASE-CHANGED, saying it is not there any more" "$( rigBaseIs "$rigNameA" "$rigTmp/t3c.out" 'BASE-CHANGED: docs/guide.md is not there any more; it was ' )" "1"
printf 'The guide of the rig.\n' > "$rigWs/docs/guide.md"

echo "-- 4. where a request stands --"
rigAs=rig-member
rigRun "$rigTmp/s4" --request-result "$rigNameA"
rigAssert "a request that waits: its line says so, with its kind, target and who asked" "$rigRc $( LC_ALL=C sed -e "s/$rigNameA/<A>/" -e 's/ on [0-9].*$//' "$rigTmp/s4.out" )" '0 UPDATE <A> WAITING -- document docs/guide.md, asked by rig-member'
rigRun "$rigTmp/s4b" --request-result inquiry-20261020T0000Z-plain.md
rigAssert "an inquiry that is no request is unknown, exit 1" "$rigRc $( rigHas ' UNKNOWN -- ' "$rigTmp/s4b.out" )" "1 1"
rigRun "$rigTmp/s4c" --request-result inquiry-20261020T0000Z-nothing.md
rigAssert "a name that is nowhere is unknown, exit 1" "$rigRc $( rigHas ' UNKNOWN -- ' "$rigTmp/s4c.out" )" "1 1"
rigRun "$rigTmp/s4d" --request-result 'a/b'
rigAssert "a name that is not a bare name is refused" "$rigRc" "1"

echo "-- 5. the librarian decides: result, refuse --"
rigAs=rig-member
rigRun "$rigTmp/d5" --queue-done "$rigNameA" --result 'done'
rigAssert "another member than the librarian cannot close one: refused, and it still waits" "$rigRc $( rigHas 'runs only as magic-librarian' "$rigTmp/d5.err" ) $( [ -f "$rigIn/$rigNameA" ] && printf waits )" "1 1 waits"
rigAs=magic-librarian ; rigSid=lib-allowed
rigRun "$rigTmp/d5b" --queue-done "$rigNameA" --result $'Updated MAGIC.md:\n  the "Wait" section\tnow says it with a back\\slash and a café.'
rigAssert "the librarian closes a message with a result: said, moved to processed/, out of incoming/" "$rigRc $( LC_ALL=C sed 's/inquiry-[^ ]*/<name>/' "$rigTmp/d5b.out" ) $( [ -f "$rigIn/$rigNameA" ] && printf still-waiting || printf gone-from-incoming ) $( [ -f "$rigDone/$rigNameA" ] && printf in-processed )" "0 closed: <name> gone-from-incoming in-processed"
rigAssert "with its processed-at, its outcome closed and its result on one line, quotes, backslash and accent kept" "[$( rigKey "$rigDone/$rigNameA" processed-at | LC_ALL=C grep -c . )] [$( rigKey "$rigDone/$rigNameA" update-outcome )] [$( rigKey "$rigDone/$rigNameA" update-result )]" '[1] [closed] [Updated MAGIC.md: the "Wait" section now says it with a back\slash and a café.]'
rigAssert "closed, it still meets the inquiry contract, with its own keys: no row" "$( rigValidate "$rigDone/$rigNameA" )" "0"
rigRun "$rigTmp/s5" --request-result "$rigNameA"
rigAssert "it is read as done, with the outcome and the result" "$rigRc $( LC_ALL=C sed -e "s/$rigNameA/<A>/" "$rigTmp/s5.out" )" '0 UPDATE <A> DONE (closed) -- document docs/guide.md, asked by rig-member: Updated MAGIC.md: the "Wait" section now says it with a back\slash and a café.'
rigRun "$rigTmp/d5c" --queue-done "$rigNameA" --result 'again'
rigAssert "a second close is refused, saying it is closed already" "$rigRc $( rigHas 'is closed already' "$rigTmp/d5c.err" )" "1 1"
rigRun "$rigTmp/d5d" --queue-done inquiry-20261020T0000Z-plain.md --result 'not a request'
rigAssert "an inquiry that is no request is not closed by it: refused, and it stays in incoming/" "$rigRc $( rigHas 'is no update request that waits' "$rigTmp/d5d.err" ) $( [ -f "$rigIn/inquiry-20261020T0000Z-plain.md" ] && printf stays )" "1 1 stays"
rigRun "$rigTmp/d5e" --queue-done "$rigNameB"
rigRun "$rigTmp/d5f" --queue-done "$rigNameB" --result 'a' --refuse 'b'
rigRun "$rigTmp/d5g" --queue-done "$rigNameB" --result "$( printf 'y%.0s' $(seq 1 501) )"
rigAssert "a close with nothing to say, with two decisions, with a result of more than 500 characters: refused, and the request still waits" "$rigRc $( rigHas 'syntax is' "$rigTmp/d5e.err" ) $( rigHas 'not several' "$rigTmp/d5f.err" ) $( rigHas 'at most 500 characters' "$rigTmp/d5g.err" ) $( [ -f "$rigIn/$rigNameB" ] && printf waits )" "1 1 1 1 waits"
rigAs="" ; rigSid=""
rigRun "$rigTmp/d5h" --queue-done "$rigNameB" --result 'by the console'
rigAssert "a call from no member's session cannot close one either" "$rigRc $( rigHas 'runs only as magic-librarian' "$rigTmp/d5h.err" )" "1 1"
rigAs=magic-librarian ; rigSid=lib-allowed
rigRun "$rigTmp/d5i" --queue-done "$rigNameB" --apply
rigAssert "a request about the knowledge base is not applied: refused, saying what is, and it waits" "$rigRc $( rigHas 'only the whole text or the concrete edit of a skill file is applied' "$rigTmp/d5i.err" ) $( [ -f "$rigIn/$rigNameB" ] && printf waits )" "1 1 waits"
rigRun "$rigTmp/d5j" --queue-done "$rigNameB" --refuse 'the knowledge tool does not take it yet'
rigAssert "--refuse closes it with the librarian's reason as the result, the outcome refused" "$rigRc [$( rigKey "$rigDone/$rigNameB" update-outcome )] [$( rigKey "$rigDone/$rigNameB" update-result )] $( rigValidate "$rigDone/$rigNameB" )" "0 [refused] [the knowledge tool does not take it yet] 0"
rigAssert "neither was asked for a reply: no note went to the requester" "$( rigNotes "$rigMemberIn" )" "0"

echo "-- 6. the apply --"
## learning is on for what follows, except where it is switched off
rigAs="" ; rigSid=""
rigOther "$rigTmp/lrn" DistroAgentsDispatcher.fn.sh --override-flag learning
rigAs=magic-librarian
rigSid=lib-bare
rigRun "$rigTmp/a6" --queue-done "$rigNameE" --apply
rigAssert "a session with no routine that allows the write: the apply is refused with a REFUSAL-ID and the way to ask, the request still waits, the file is not written" "$rigRc $( rigHas 'REFUSAL-ID: refusal-' "$rigTmp/a6.err" ) $( rigHas 'was not applied, and still waits' "$rigTmp/a6.err" ) $( [ -f "$rigIn/$rigNameE" ] && printf waits ) $( [ -e "$rigSrc/keeper-here/reference/new-notes.md" ] && printf written || printf absent ) $( rigNotes "$rigMemberIn" )" "1 1 1 waits absent 0"
rigSid=lib-allowed
rigOther "$rigTmp/lrn2" DistroAgentsDispatcher.fn.sh --override-flag --no learning
rigAs=magic-librarian
rigRun "$rigTmp/a6b" --queue-done "$rigNameE" --apply
rigAssert "learning off: the apply is refused naming the proposal route, and the request waits" "$rigRc $( rigHas 'learning is off, so the librarian offers proposals' "$rigTmp/a6b.err" ) $( [ -f "$rigIn/$rigNameE" ] && printf waits ) $( [ -e "$rigSrc/keeper-here/reference/new-notes.md" ] && printf written || printf absent )" "1 1 waits absent"
rigAs="" ; rigSid=""
rigOther "$rigTmp/lrn3" DistroAgentsDispatcher.fn.sh --override-flag learning
rigAs=magic-librarian ; rigSid=lib-allowed
rigRun "$rigTmp/a6c" --queue-done "$rigNameE" --apply
rigAssert "THE WHOLE TEXT applied, a new file: written exactly as given (no final line break), said" "$rigRc $( LC_ALL=C grep -c "^OK: wrote $rigSrc/keeper-here/reference/new-notes.md (a new file)\$" "$rigTmp/a6c.out" ) $( cmp -s "$rigSrc/keeper-here/reference/new-notes.md" "$rigTmp/whole.md" && printf same )" "0 1 same"
rigAssert "the request is closed applied, with where it wrote" "$( LC_ALL=C grep -c '^closed: inquiry-' "$rigTmp/a6c.out" ) [$( rigKey "$rigDone/$rigNameE" update-outcome )] [$( rigKey "$rigDone/$rigNameE" update-result )] $( rigValidate "$rigDone/$rigNameE" ) $( [ -f "$rigIn/$rigNameE" ] && printf still-waiting )" "1 [applied] [wrote $rigSrc/keeper-here/reference/new-notes.md (a new file)] 0 "
rigNoteE="$( ls "$rigMemberIn" | LC_ALL=C grep '^note-' | LC_ALL=C sed -n 1p )"
rigAssert "it asked for a reply, so one note went to the requester's inbox: from the librarian, to the requester, saying the outcome, the request and the result" "$( rigNotes "$rigMemberIn" ) $( printf '%s' "$rigNoteE" | LC_ALL=C grep -c -E "^note-[0-9]{8}T[0-9]{4}Z-update-applied-.*\.md\$" ) $( rigKey "$rigMemberIn/$rigNoteE" type ) $( rigKey "$rigMemberIn/$rigNoteE" from ) $( rigKey "$rigMemberIn/$rigNoteE" owner ) $( rigHas "# Note: your request $rigNameE is applied" "$rigMemberIn/$rigNoteE" ) $( rigHas "was applied: wrote $rigSrc/keeper-here/reference/new-notes.md (a new file)" "$rigMemberIn/$rigNoteE" ) $( rigValidateNote "$rigMemberIn/$rigNoteE" )" "1 1 note magic-librarian rig-member 1 1 0"
rigRun "$rigTmp/t6" --queue-take
rigAssert "the file a request recorded as not there is there now (the other message about it): BASE-CHANGED, saying so" "$( rigBaseIs "$rigNameD" "$rigTmp/t6.out" 'BASE-CHANGED: keeper-here:reference/new-notes.md was not there when this was written, and is now (' )" "1"
rigRun "$rigTmp/a6d" --queue-done "$rigNameF" --apply
rigAssert "THE EDIT applied: the old string is replaced by the new one in the file and nothing else changed" "$rigRc $( printf '%s' "$rigHereOrig" | LC_ALL=C sed 's/first rule is alpha/first rule is gamma/' | cmp -s - "$rigHere" && printf edited )" "0 edited"
rigAssert "it asked for no reply: closed applied, and no second note went to the requester" "[$( rigKey "$rigDone/$rigNameF" update-outcome )] $( rigNotes "$rigMemberIn" ) $( rigValidate "$rigDone/$rigNameF" )" "[applied] 1 0"
rigRun "$rigTmp/t6b" --queue-take
rigAssert "the skill file changed since: its other requests say BASE-CHANGED, saying it changed after they were written" "$( rigBaseIs "$rigNameC" "$rigTmp/t6b.out" 'BASE-CHANGED: keeper-here:keeper-here.armed.md changed after this was written' ) $( rigBaseIs "$rigNameH" "$rigTmp/t6b.out" 'BASE-CHANGED: keeper-here:keeper-here.armed.md changed after this was written' )" "1 1"
rigRun "$rigTmp/a6e" --queue-done "$rigNameH" --apply
rigAssert "a whole text whose file changed after it was written is not applied: refused saying to merge by hand, the file as it is, and it waits" "$rigRc $( rigHas 'a whole text is written against the file as it was' "$rigTmp/a6e.err" ) $( rigHas 'still waits' "$rigTmp/a6e.err" ) $( [ -f "$rigIn/$rigNameH" ] && printf waits ) $( LC_ALL=C grep -c 'first rule is gamma' "$rigHere" )" "1 1 1 waits 1"
rigRun "$rigTmp/a6f" --queue-done "$rigNameH" --refuse 'the file changed under it: file the whole text again'
rigNoteH="$( ls "$rigMemberIn" | LC_ALL=C grep '^note-.*-update-refused-' | LC_ALL=C sed -n 1p )"
rigAssert "refused with a reason, as it asked for a reply: the outcome refused, the reason as the result, one more note, saying so" "$rigRc [$( rigKey "$rigDone/$rigNameH" update-outcome )] [$( rigKey "$rigDone/$rigNameH" update-result )] $( rigNotes "$rigMemberIn" ) $( rigHas "was refused: the file changed under it: file the whole text again" "$rigMemberIn/$rigNoteH" )" "0 [refused] [the file changed under it: file the whole text again] 2 1"
rigRun "$rigTmp/a6h" --queue-done "$rigNameI" --apply
rigAssert "an edit whose old string is in the file twice is not applied: refused saying how many times, the file as it is, and it waits" "$rigRc $( rigHas 'is in the file 2 times' "$rigTmp/a6h.err" ) $( [ -f "$rigIn/$rigNameI" ] && printf waits ) $( LC_ALL=C grep -c 'is beta indeed' "$rigHere" )" "1 1 waits 0"
rigRun "$rigTmp/a6g" --queue-done "$rigNameG" --apply
rigAssert "an edit applies on a file that changed, where its old string is in it once (from files: the strings whole)" "$rigRc $( LC_ALL=C grep -c '^The third rule$' "$rigHere" ) $( LC_ALL=C grep -c 'is delta, "quoted", a back\\slash, café.$' "$rigHere" ) $( LC_ALL=C grep -c 'The third rule is beta' "$rigHere" ) [$( rigKey "$rigDone/$rigNameG" update-outcome )]" "0 1 1 0 [applied]"
rigAs=rig-member ; rigRun "$rigTmp/a6i2" --request-update --kind skill --target 'keeper-here:keeper-here.armed.md' --why 'old again' --old 'first rule is alpha' --new 'first rule is omega'
rigNameJ="$( rigRigIn "$rigTmp/a6i2.out" )"
rigAs=magic-librarian
rigRun "$rigTmp/a6j" --queue-done "$rigNameJ" --apply
rigAssert "an edit whose old string is not in the file as it is now is not applied: refused, and it waits" "$rigRc $( rigHas 'the old string is not in the file as it is now' "$rigTmp/a6j.err" ) $( [ -f "$rigIn/$rigNameJ" ] && printf waits )" "1 1 waits"
rigRun "$rigTmp/a6k" --queue-done "$rigNameJ" --refuse 'the rule is gamma already'
rigRun "$rigTmp/a6l" --queue-done "$rigNameI" --result 'left as it is: say which of the two lines'
rigNoteI="$( ls "$rigMemberIn" | LC_ALL=C grep '^note-.*-update-closed-' | LC_ALL=C sed -n 1p )"
rigAssert "a request that asked for a reply and is closed with a result: the outcome closed and one more note (three: applied, refused, closed); the one that did not ask, refused, sent none" "[$( rigKey "$rigDone/$rigNameI" update-outcome )] $( rigNotes "$rigMemberIn" ) $( rigHas "was closed: left as it is: say which of the two lines" "$rigMemberIn/$rigNoteI" ) $( rigKey "$rigDone/$rigNameJ" update-outcome )" "[closed] 3 1 refused"
rigRun "$rigTmp/a6m" --queue-done "$rigNameC" --result 'answered by hand'
rigAssert "a message about a skill, closed with a result, without a reply: no note" "$rigRc $( rigNotes "$rigMemberIn" )" "0 3"
rigRun "$rigTmp/a6n" --queue-done "$rigNameD" --refuse 'the notes file stands already'
rigAssert "the other request for the file now there, refused: still no note; every closed request meets the inquiry contract" "$rigRc $( rigNotes "$rigMemberIn" ) $( for rigClosed in "$rigDone"/inquiry-*.md ; do rigValidate "$rigClosed" ; done | LC_ALL=C tr -d '\n' )" "0 3 0000000000"

echo "-- 7. the queue is empty --"
rigRun "$rigTmp/e7" --queue-list
rigRun "$rigTmp/e7b" --queue-take
rigAssert "with every request closed the queue is empty: no row and a line that says so, and the batch of none" "$( LC_ALL=C grep -c . "$rigTmp/e7.out" ) $( rigHas 'no update request waits' "$rigTmp/e7.err" ) $( LC_ALL=C sed -n 1p "$rigTmp/e7b.out" )" "0 1 UPDATE-BATCH: 0 request(s) waiting"
rigAssert "the plain inquiry and the note were never the queue's: still in incoming/" "$( ls "$rigIn" | LC_ALL=C grep -c . )" "2"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ UPDATE REQUESTS CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'UPDATE_REQUESTS: OK (%d assertions, offline, rig tree only, %d seconds)\n' "$rigPasses" "$(( $( date +%s ) - rigBegin ))"
