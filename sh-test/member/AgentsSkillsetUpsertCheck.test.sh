#!/usr/bin/env bash
## Behavioural check on the librarian's write of a skillset file (F7.7 of the refactorings epic): AgentLibrarianTools.fn.sh --skillset-upsert and its
## stub --librarian-skillset-upsert of DistroAgentsTools.fn.sh, run rather than read, in a rig: a workspace with its member registry, a HOME with the
## machine's registry and its skills folder, the sessions of the librarian with the routines they run. It is SKILL ACCESS, NOT FILE ACCESS: a tool of
## its own that names a member and a file in that member's skill, resolves the skill to its source copy through the member registry, and writes that
## copy only -- never an install under .local, never the HOME skills folder. Held:
##   0. THE VALIDATOR'S --as. A text on stdin checked as the document that will stand at a path: shown by that path, its citations looked for from
##      there, so a skill file checked before it is saved gives the rows it would give as the file.
##   1. WHO. Only magic-librarian: another member, a session with no member and a call from no session are refused.
##   2. THE PERMISSION CHAIN. The call asks the chain for the permission `skillset-upsert` over `<member>:<pathname>`, as a tool call is asked: a routine
##      whose `access-control:` names it holds it (`magic-librarian:skillset-upsert`, `executors:skillset-upsert`, or with a target); a call from a session with no
##      routine, from a routine with no access-control:, one that allows another tool, one that allows it to another member, or for another file, is not held:
##      it is REFUSED with a REFUSAL-ID, recorded (tool skillset-upsert, target member:pathname), and the hint to ask with RequestPermission, and writes
##      nothing. Once the owner grants it for the session, or once, the call is retried as it was made and written; a grant covers its target only, and
##      a once is used up by the call.
##   3. WHAT AND WHEN. Only a .md file below a skill's folder, the text from stdin or a file and not empty, and only while learning is on: while it is
##      off the refusal names the proposal route.
##   4. WHICH COPY. The source copy the member registry names (this workspace's rows, then the machine's), written whole where the member has install
##      rows beside it; refused, saying why: a member the registry does not know, one with only an install, one whose source copy is not on this
##      machine, one with two. A file that leaves the folder by a link, a link, a folder: refused.
##   5. VALIDATED BEFORE SAVED. A routine that does not meet the routine contract is refused with its rows, nothing written; the rows that only report
##      are printed and refuse nothing.
##   6. THE SAVE. The text exactly as given (a trailing line break or none, quotes, backslashes, accents, tabs), in place by a rename in the file's own
##      folder with its mode kept (a new file 644), the folders made, no temp file left, the install and the HOME skills folder untouched, by the
##      stub the same.
## Offline, rig tree only: nothing here reaches Slack or any endpoint.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-scripts/AgentLibrarianTools.fn.sh" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigPackage/sh-scripts/AgentLibrarianTools.fn.sh"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSkillsetUpsertCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
trap 'rigProcSignal TERM $rigStarted ; chmod -R u+w "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigWs="$rigTmp/ws" rigHome="$rigTmp/home" rigOther="$rigTmp/otherws"
rigRegistry="$rigWs/.local/agents/members.registry" rigShared="$rigHome/.agents/magic-team/members.registry"
mkdir -p "$rigWs/.local/agents/members/magic-librarian" "$rigWs/.local/agents/spawned" "$rigWs/.local/temp" "$rigHome/.claude/skills" "$rigHome/.agents/magic-team" "$rigWs/source/rig/rig-proj/skillset" "$rigOther/source/rig/skillset" "$rigTmp/bin"
: > "$rigRegistry" ; : > "$rigShared"
## A skill: its folder with a basic.md and an armed.md, and a registry row for it, `member ws kind relative-path directory`.
rigSkill(){ ## member, folder, kind, registry (file)
	mkdir -p "$2/reference"
	printf 'rig\n' > "$2/$1.basic.md" ; printf 'rig-seed armed\n' > "$2/$1.armed.md"
	printf '%s\t%s\t%s\t%s\t%s\n' "$1" "${2%%/source/*}" "$3" "${2#*/source/}" "$2" >> "$4"
}
rigSrc="$rigWs/source/rig/rig-proj/skillset"
rigSkill keeper-here "$rigSrc/keeper-here" source-symlink "$rigRegistry"
rigSkill keeper-both "$rigSrc/keeper-both" source-symlink "$rigRegistry"
rigSkill keeper-both "$rigWs/.local/myx/rig/skillset/keeper-both" .local-symlink "$rigRegistry"
rigSkill keeper-install "$rigWs/.local/myx/rig/skillset/keeper-install" .local-symlink "$rigRegistry"
rigSkill keeper-twice "$rigSrc/keeper-twice-a" source-symlink "$rigRegistry"
rigSkill keeper-twice "$rigSrc/keeper-twice-b" source-symlink "$rigRegistry"
printf 'keeper-gone\t%s\tsource-symlink\trig/rig-proj/skillset/keeper-gone\t%s\n' "$rigWs" "$rigSrc/keeper-gone" >> "$rigRegistry"
rigSkill keeper-away "$rigOther/source/rig/skillset/keeper-away" source-symlink "$rigShared"
## the HOME skills folder, which is never written: links to the copies, as the vendors' clients are given them
ln -s "$rigSrc/keeper-here" "$rigHome/.claude/skills/keeper-here" ; ln -s "$rigWs/.local/myx/rig/skillset/keeper-install" "$rigHome/.claude/skills/keeper-install"
mkdir -p "$rigHome/.claude/skills/keeper-plain/reference" ; printf 'rig\n' > "$rigHome/.claude/skills/keeper-plain/keeper-plain.basic.md" ; printf 'rig-seed armed\n' > "$rigHome/.claude/skills/keeper-plain/keeper-plain.armed.md"
## The rig's own process list: a session runs while a stand-in process is listed under its id (a grant of a session counts only for a session that runs).
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
## The sessions of the librarian and the routines they run: a spawn record names its routine, the routine file stands in the librarian's folder.
rigRoutines="$rigWs/.local/agents/members/magic-librarian"
for rigMember in magic-librarian keeper-myx ; do
	mkdir -p "$rigWs/.local/agents/members/$rigMember" ; printf -- '---\nname: %s\ndescription: rig member\n---\n' "$rigMember" > "$rigWs/.local/agents/members/$rigMember/SKILL.md" ; printf 'rig\n' > "$rigWs/.local/agents/members/$rigMember/$rigMember.basic.md"
done
rigRoutine(){ ## file name, executors, allows line (may be empty)
	printf -- '---\ntype: routine\nexecutors: %s\nmaintainers: human-owner\nrequires-session-kind: standalone\n%s---\n# %s\n' "$2" "${3:+access-control: $3$'\n'}" "$1" > "$rigRoutines/$1"
}
rigSession(){ ## session id, routine file name (may be empty)
	mkdir -p "$rigWs/.local/agents/spawned/$1" "$rigWs/.local/agents/sessions/$1"
	printf -- '---\nsession-id: 5e55104a-%s\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: %s\nowner: magic-librarian\nstatus: spawn-started\n%s---\n' "$1" "$1" "$1" "${2:+routine: $2$'\n'}" > "$rigWs/.local/agents/spawned/$1/$1.spawn.md"
	printf '%s rig-run --session-id %s\n' "$rigStand" "$1" >> "$rigTmp/ps.list"
}
rigRoutine magic-librarian.rig-allowed.routine.md magic-librarian 'magic-librarian:allow-tool:skillset-upsert' ; rigSession rig-allowed magic-librarian.rig-allowed.routine.md
rigRoutine magic-librarian.rig-executors.routine.md magic-librarian 'executors:allow-tool:skillset-upsert' ; rigSession rig-executors magic-librarian.rig-executors.routine.md
rigRoutine magic-librarian.rig-target.routine.md magic-librarian 'magic-librarian:allow-tool:skillset-upsert:keeper-here%3Areference/by-target.md' ; rigSession rig-target magic-librarian.rig-target.routine.md
rigRoutine magic-librarian.rig-silent.routine.md magic-librarian '' ; rigSession rig-silent magic-librarian.rig-silent.routine.md
rigRoutine magic-librarian.rig-other.routine.md magic-librarian 'magic-librarian:allow-tool:WebFetch' ; rigSession rig-other magic-librarian.rig-other.routine.md
rigRoutine magic-librarian.rig-someone.routine.md magic-librarian 'keeper-myx:allow-tool:skillset-upsert' ; rigSession rig-someone magic-librarian.rig-someone.routine.md
rigSession rig-bare ""
rigSession rig-granted ""
rigSession rig-once ""
rigStdin=""
rigRun(){ ## result prefix, session id (may be empty), member (may be empty), command... -- one command in the rig; stdin from rigStdin; output into <prefix>, rc into <prefix>.rc
	local runOut="$1" runSession="$2" runMember="$3" ; shift 3
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$rigTmp/bin:$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" \
		${runMember:+MDAT_SPAWN_AGENT="$runMember"} ${runSession:+MDAT_SPAWN_SESSION_ID="$runSession"} \
		bash -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; exec "$@"' rig "$@" ) > "$runOut" 2>&1 < "${rigStdin:-/dev/null}"
	printf '%s' "$?" > "$runOut.rc"
}
rigUp(){ ## result prefix, session id, member, AgentLibrarianTools.fn.sh arguments...
	local upOut="$1" upSession="$2" upMember="$3" ; shift 3
	rigRun "$upOut" "$upSession" "$upMember" bash "$rigPackage/sh-scripts/AgentLibrarianTools.fn.sh" "$@"
}
rigAsLib(){ ## result prefix, arguments... -- as the librarian in the session of the routine that allows it
	local asOut="$1" ; shift
	rigUp "$asOut" rig-allowed magic-librarian "$@"
}
rigBytes(){ ## file -- every byte of a file, so a newline shows as \n and nothing is trimmed
	[ -f "$1" ] || { printf 'MISSING' ; return 0 ; }
	od -An -c "$1" | tr -d ' \n'
}
rigHas(){ ## fixed text, file -- how many lines of the file hold it
	LC_ALL=C grep -c -F -- "$1" "$2" || :
}
rigMode(){ ## file -- its mode in octal
	stat -f '%Lp' "$1" 2> /dev/null || stat -c '%a' "$1" 2> /dev/null
}
rigRefusalIdOf(){ ## output file -- the REFUSAL-ID it names
	LC_ALL=C sed -n 's/^REFUSAL-ID: \(refusal-[0-9a-f-]*\)$/\1/p' "$1" | LC_ALL=C sed -n 1p
}
rigRefusalField(){ ## session, refusal id, field
	LC_ALL=C awk -v key="$3" '$0 == "---" { if ( ++dashes == 2 ) { exit ; } next ; } dashes == 1 && index( $0, key ": " ) == 1 { print substr( $0, length( key ) + 3 ) ; exit ; }' "$rigWs/.local/agents/sessions/$1/$2.md" 2> /dev/null
}
rigBegin=$( date +%s )
rigNew=$'---\nmaintainers: rig\n---\n# keeper-here armed\n\nA "quoted" word, a back\\slash, an accent: café, and a tab:\there.\n\nThe last line.\n'
printf '%s' "$rigNew" > "$rigTmp/new.md"
printf 'no break at the end' > "$rigTmp/nobreak.md"
rigHere="$rigSrc/keeper-here/keeper-here.armed.md"

echo "-- 0. the validator's --as --"
rigDoc="$rigPackage/skillset/magic-team/magic-tester/magic-tester.armed.md"
rigTools=( bash "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" )
rigStdin="$rigDoc" ; rigRun "$rigTmp/v0a" "" "" "${rigTools[@]}" --intern-doc-validate document --from-stdin
rigStdin="$rigDoc" ; rigRun "$rigTmp/v0b" "" "" "${rigTools[@]}" --intern-doc-validate document --from-stdin --as "$rigDoc"
rigStdin="$rigDoc" ; rigRun "$rigTmp/v0c" "" "" "${rigTools[@]}" --intern-doc-validate document --from-stdin --as "$(dirname "$rigDoc")/magic-tester.new.md"
rigAssert "without --as a skill file on stdin is looked at from nowhere: its citations of sibling files are rows; with --as its own path, or a new file beside it, none" \
	"$( LC_ALL=C grep -c 'report-citation' "$rigTmp/v0a" ) $( LC_ALL=C grep -c 'report-' "$rigTmp/v0b" ) $( LC_ALL=C grep -c 'report-' "$rigTmp/v0c" )" "3 0 0"
rigStdin="$rigTmp/new.md" ; rigRun "$rigTmp/v0d" "" "" "${rigTools[@]}" --intern-doc-validate routine --from-stdin --as "$rigWs/skill/rig.x.routine.md"
rigAssert "a row is shown by the path it was given with --as: there are rows, and every one of them is" "$( [ "$( LC_ALL=C grep -c "^$rigWs/skill/rig.x.routine.md:[0-9]*: " "$rigTmp/v0d" )" -ge 1 ] && printf rows ) $( LC_ALL=C grep -c "^$rigWs/skill/rig.x.routine.md:[0-9]*: " "$rigTmp/v0d" ) of $( LC_ALL=C grep -c ':[0-9][0-9]*: ' "$rigTmp/v0d" )" "rows $( LC_ALL=C grep -c ':[0-9][0-9]*: ' "$rigTmp/v0d" ) of $( LC_ALL=C grep -c ':[0-9][0-9]*: ' "$rigTmp/v0d" )"
rigStdin=""
rigRun "$rigTmp/v0e" "" "" "${rigTools[@]}" --intern-doc-validate document --from-stdin --as
rigAssert "--as with no path is the syntax message" "$( rigHas 'syntax is <kind> <file|--from-stdin [--as <path>]>' "$rigTmp/v0e" )" "1"

echo "-- 1. who --"
rigStdin="$rigTmp/new.md"
rigUp "$rigTmp/g1a" rig-allowed keeper-myx --skillset-upsert keeper-here keeper-here.armed.md --from-stdin
rigAssert "another member than the librarian: refused" "$( cat "$rigTmp/g1a.rc" ) $( rigHas 'runs only as magic-librarian, and this call comes from keeper-myx' "$rigTmp/g1a" )" "1 1"
rigUp "$rigTmp/g1b" "" "" --skillset-upsert keeper-here keeper-here.armed.md --from-stdin
rigAssert "a call from no member's session: refused" "$( cat "$rigTmp/g1b.rc" ) $( rigHas 'runs only as magic-librarian, and this call comes from no member' "$rigTmp/g1b" )" "1 1"
rigAssert "none of them wrote a byte, or recorded a refusal" "$( rigBytes "$rigHere" ) $( ls "$rigWs/.local/agents/sessions/rig-allowed" | LC_ALL=C grep -c '^refusal-' )" 'rig-seedarmed\n 0'

echo "-- 2. the permission chain --"
## learning is on for what follows; the learning gate itself is section 3
rigRun "$rigTmp/learning-on" "" "" bash "$rigPackage/sh-scripts/DistroAgentsDispatcher.fn.sh" --override-flag learning
rigAssert "learning is switched on by the flag's own operation" "$( LC_ALL=C grep -c -x 'learning: yes' "$rigTmp/learning-on" )" "1"
rigUp "$rigTmp/p2a" rig-bare magic-librarian --skillset-upsert keeper-here keeper-here.armed.md --from-stdin
rigIdA="$( rigRefusalIdOf "$rigTmp/p2a" )"
rigAssert "a session that runs no routine: not held, refused, naming the access-control: key, with a REFUSAL-ID and the way to ask with RequestPermission" "$( cat "$rigTmp/p2a.rc" ) $( rigHas 'does not name skillset-upsert in its access-control: key' "$rigTmp/p2a" ) $( rigHas 'magic-librarian:allow-tool:skillset-upsert' "$rigTmp/p2a" ) $( printf '%s' "$rigIdA" | LC_ALL=C grep -c '^refusal-' ) $( rigHas "RequestPermission refusal_id=$rigIdA" "$rigTmp/p2a" )" "1 1 1 1 1"
rigAssert "the refusal is recorded as a refused call of that tool: the librarian's, the tool skillset-upsert, the target member:pathname; nothing was written" "$( rigRefusalField rig-bare "$rigIdA" owner ) $( rigRefusalField rig-bare "$rigIdA" tool ) $( rigRefusalField rig-bare "$rigIdA" target ) $( rigBytes "$rigHere" )" 'magic-librarian skillset-upsert keeper-here:keeper-here.armed.md rig-seedarmed\n'
rigUp "$rigTmp/p2b" rig-silent magic-librarian --skillset-upsert keeper-here keeper-here.armed.md --from-stdin
rigUp "$rigTmp/p2c" rig-other magic-librarian --skillset-upsert keeper-here keeper-here.armed.md --from-stdin
rigUp "$rigTmp/p2d" rig-someone magic-librarian --skillset-upsert keeper-here keeper-here.armed.md --from-stdin
rigUp "$rigTmp/p2e" rig-target magic-librarian --skillset-upsert keeper-here keeper-here.armed.md --from-stdin
rigAssert "from a routine with no access-control:, one that allows another tool, one that allows it to another member, one that allows it for another file: refused each time, each with its refusal id, nothing written" \
	"$( cat "$rigTmp/p2b.rc" )$( cat "$rigTmp/p2c.rc" )$( cat "$rigTmp/p2d.rc" )$( cat "$rigTmp/p2e.rc" ) $( rigRefusalIdOf "$rigTmp/p2b" | LC_ALL=C grep -c '^refusal-' )$( rigRefusalIdOf "$rigTmp/p2c" | LC_ALL=C grep -c '^refusal-' )$( rigRefusalIdOf "$rigTmp/p2d" | LC_ALL=C grep -c '^refusal-' )$( rigRefusalIdOf "$rigTmp/p2e" | LC_ALL=C grep -c '^refusal-' ) $( rigBytes "$rigHere" )" '1111 1111 rig-seedarmed\n'
rigAsLib "$rigTmp/p2f" --skillset-upsert keeper-here reference/by-allows.md --from-stdin
rigAssert "from the routine whose access-control: names it for its member (magic-librarian:skillset-upsert): held, and written" "$( cat "$rigTmp/p2f.rc" ) $( cmp -s "$rigSrc/keeper-here/reference/by-allows.md" "$rigTmp/new.md" && printf same ) $( rigHas 'REFUSAL-ID' "$rigTmp/p2f" )" "0 same 0"
rigUp "$rigTmp/p2g" rig-executors magic-librarian --skillset-upsert keeper-here reference/by-executors.md --from-stdin
rigAssert "from a routine that allows it to its executors (executors:skillset-upsert): written" "$( cat "$rigTmp/p2g.rc" ) $( cmp -s "$rigSrc/keeper-here/reference/by-executors.md" "$rigTmp/new.md" && printf same )" "0 same"
rigUp "$rigTmp/p2h" rig-target magic-librarian --skillset-upsert keeper-here reference/by-target.md --from-stdin
rigAssert "from a routine that allows it for one file: written for that file" "$( cat "$rigTmp/p2h.rc" ) $( cmp -s "$rigSrc/keeper-here/reference/by-target.md" "$rigTmp/new.md" && printf same )" "0 same"
## the owner's answer to the request for the refused call, as the chain records it: a grant for the session, then one for the call
rigRun "$rigTmp/p2i" "" "" bash "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-permission-grant-open human-owner --session-id rig-bare --refusal-id "$rigIdA" --kind session
rigUp "$rigTmp/p2j" rig-bare magic-librarian --skillset-upsert keeper-here keeper-here.armed.md --from-stdin
rigAssert "once the owner grants it for the session the call is retried as it was made and written: no refusal now" "$( LC_ALL=C grep -c '^GRANT: session ' "$rigTmp/p2i" ) $( cat "$rigTmp/p2j.rc" ) $( cmp -s "$rigHere" "$rigTmp/new.md" && printf same ) $( rigHas 'REFUSAL-ID' "$rigTmp/p2j" )" "1 0 same 0"
rigUp "$rigTmp/p2k" rig-bare magic-librarian --skillset-upsert keeper-here reference/other-file.md --from-stdin
rigAssert "the grant covers its target only: another file of the same session is refused again, with a refusal id of its own" "$( cat "$rigTmp/p2k.rc" ) $( rigRefusalIdOf "$rigTmp/p2k" | LC_ALL=C grep -c '^refusal-' ) $( [ -e "$rigSrc/keeper-here/reference/other-file.md" ] && printf written || printf absent )" "1 1 absent"
rigUp "$rigTmp/p2l" rig-once magic-librarian --skillset-upsert keeper-here reference/once.md --from-stdin
rigIdB="$( rigRefusalIdOf "$rigTmp/p2l" )"
rigRun "$rigTmp/p2m" "" "" bash "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-permission-grant-open human-owner --session-id rig-once --refusal-id "$rigIdB" --kind once
rigUp "$rigTmp/p2n" rig-once magic-librarian --skillset-upsert keeper-here reference/once.md --from-stdin
rigUp "$rigTmp/p2o" rig-once magic-librarian --skillset-upsert keeper-here reference/once.md --from-stdin
rigAssert "a grant for the call: the retry is written, and the grant is used up, so the same call again is refused" "$( LC_ALL=C grep -c '^GRANT: once ' "$rigTmp/p2m" ) $( cat "$rigTmp/p2n.rc" ) $( cmp -s "$rigSrc/keeper-here/reference/once.md" "$rigTmp/new.md" && printf same ) $( cat "$rigTmp/p2o.rc" ) $( rigRefusalIdOf "$rigTmp/p2o" | LC_ALL=C grep -c '^refusal-' )" "1 0 same 1 1"

echo "-- 3. what and when --"
rm -f "$rigWs/.local/.agents/magic-team.agent.env.keep"
rigRun "$rigTmp/learning-off" "" "" bash "$rigPackage/sh-scripts/DistroAgentsDispatcher.fn.sh" --override-flag --no learning
rigAsLib "$rigTmp/w3a" --skillset-upsert keeper-here keeper-here.armed.md --from-stdin
rigAssert "learning off, the permission held: refused, and the refusal names the proposal route" "$( LC_ALL=C grep -c -x 'learning: no' "$rigTmp/learning-off" ) $( cat "$rigTmp/w3a.rc" ) $( rigHas 'learning is off, so the librarian offers proposals' "$rigTmp/w3a" ) $( rigHas 'inquiry-* to magic-coordinator' "$rigTmp/w3a" )" "1 1 1 1"
rigRun "$rigTmp/learning-on2" "" "" bash "$rigPackage/sh-scripts/DistroAgentsDispatcher.fn.sh" --override-flag learning
printf 'rig-seed armed\n' > "$rigHere"
rigAsLib "$rigTmp/w3b" --skillset-upsert keeper-here
rigAssert "no path: the syntax message" "$( cat "$rigTmp/w3b.rc" ) $( rigHas 'syntax is <team-member> <pathname> (--from-stdin|--from-file <path>)' "$rigTmp/w3b" )" "1 1"
rigBadOut=""
for rigBad in /abs/x.md ../x.md a/../x.md a//x.md a/ x.txt ./x.md ; do
	rigAsLib "$rigTmp/w3c" --skillset-upsert keeper-here "$rigBad" --from-stdin
	rigBadOut="$rigBadOut$( cat "$rigTmp/w3c.rc" )"
done
rigAssert "a path that is absolute, goes up, has an empty or a dot part, ends in a slash or is no .md file: refused each time" "$rigBadOut" "1111111"
rigAsLib "$rigTmp/w3d" --skillset-upsert 'bad/name' x.md --from-stdin
rigAssert "a member name that is not a bare name: refused" "$( cat "$rigTmp/w3d.rc" )" "1"
rigStdin="" ; rigAsLib "$rigTmp/w3e" --skillset-upsert keeper-here keeper-here.armed.md
rigAssert "no source of the text: refused with the syntax, which names the two" "$( cat "$rigTmp/w3e.rc" ) $( rigHas '(--from-stdin|--from-file <path>)' "$rigTmp/w3e" )" "1 1"
rigAsLib "$rigTmp/w3f" --skillset-upsert keeper-here keeper-here.armed.md --from-file "$rigTmp/none.md"
rigAssert "a file that is not there: refused" "$( cat "$rigTmp/w3f.rc" ) $( rigHas 'names no file' "$rigTmp/w3f" )" "1 1"
: > "$rigTmp/empty.md" ; rigAsLib "$rigTmp/w3g" --skillset-upsert keeper-here keeper-here.armed.md --from-file "$rigTmp/empty.md"
rigAssert "an empty text: refused" "$( cat "$rigTmp/w3g.rc" ) $( rigHas 'the text is empty' "$rigTmp/w3g" )" "1 1"
rigAssert "none of these wrote a byte" "$( rigBytes "$rigHere" )" 'rig-seedarmed\n'

echo "-- 4. which copy --"
rigStdin="$rigTmp/new.md"
rigAsLib "$rigTmp/c4a" --skillset-upsert keeper-none keeper-none.armed.md --from-stdin
rigAssert "a member the registry has no row for: refused, saying so" "$( cat "$rigTmp/c4a.rc" ) $( rigHas 'has no row for keeper-none' "$rigTmp/c4a" )" "1 1"
rigAsLib "$rigTmp/c4b" --skillset-upsert keeper-install keeper-install.armed.md --from-stdin
rigAssert "a member whose only copy is an install under .local: refused, saying it has no source copy and that an install is never written" "$( cat "$rigTmp/c4b.rc" ) $( rigHas 'keeper-install has no source copy' "$rigTmp/c4b" ) $( rigHas 'an install under .local' "$rigTmp/c4b" ) $( rigHas 'an install is never written' "$rigTmp/c4b" ) $( rigBytes "$rigWs/.local/myx/rig/skillset/keeper-install/keeper-install.armed.md" )" '1 1 1 1 rig-seedarmed\n'
rigAsLib "$rigTmp/c4c" --skillset-upsert keeper-twice keeper-twice.armed.md --from-stdin
rigAssert "a member with two source copies: refused, naming both" "$( cat "$rigTmp/c4c.rc" ) $( rigHas 'has more than one source copy' "$rigTmp/c4c" ) $( rigHas 'keeper-twice-a' "$rigTmp/c4c" ) $( rigHas 'keeper-twice-b' "$rigTmp/c4c" )" "1 1 1 1"
rigAsLib "$rigTmp/c4d" --skillset-upsert keeper-gone keeper-gone.armed.md --from-stdin
rigAssert "a source copy that is registered but not on this machine: refused, saying where it was registered" "$( cat "$rigTmp/c4d.rc" ) $( rigHas 'is registered at' "$rigTmp/c4d" ) $( rigHas 'keeper-gone, which is not on this machine' "$rigTmp/c4d" )" "1 1 1"
rigAsLib "$rigTmp/c4e" --skillset-upsert keeper-plain keeper-plain.armed.md --from-stdin
rigAssert "a plain folder of the HOME skills folder is no source copy: the registry has no row for it, and it is not written" "$( cat "$rigTmp/c4e.rc" ) $( rigHas 'has no row for keeper-plain' "$rigTmp/c4e" ) $( rigBytes "$rigHome/.claude/skills/keeper-plain/keeper-plain.armed.md" )" '1 1 rig-seedarmed\n'
mkdir -p "$rigTmp/outside" ; ln -s "$rigTmp/outside" "$rigSrc/keeper-here/reference/out"
rigAsLib "$rigTmp/c4f" --skillset-upsert keeper-here reference/out/x.md --from-stdin
rigAssert "a path that leaves the skill's folder by a link inside it: refused, nothing written outside" "$( cat "$rigTmp/c4f.rc" ) $( rigHas 'leaves the folder of keeper-here by a link' "$rigTmp/c4f" ) $( ls "$rigTmp/outside" | LC_ALL=C grep -c . )" "1 1 0"
mkdir -p "$rigSrc/keeper-here/reference/dir.md" ; ln -s keeper-here.armed.md "$rigSrc/keeper-here/reference/link.md"
rigAsLib "$rigTmp/c4g" --skillset-upsert keeper-here reference/dir.md --from-stdin
rigAsLib "$rigTmp/c4h" --skillset-upsert keeper-here reference/link.md --from-stdin
rigAssert "a folder, and a link, where the file should be: refused" "$( cat "$rigTmp/c4g.rc" ) $( cat "$rigTmp/c4h.rc" ) $( rigHas 'is a link or a folder' "$rigTmp/c4g" ) $( rigHas 'is a link or a folder' "$rigTmp/c4h" )" "1 1 1 1"

echo "-- 5. validated before it is saved --"
printf -- '---\ntype: routine\n---\n# x\n' > "$rigTmp/bad.routine.md"
rigStdin="$rigTmp/bad.routine.md" ; rigAsLib "$rigTmp/r5a" --skillset-upsert keeper-here keeper-here.x.routine.md --from-stdin
rigAssert "a routine that does not meet its contract: refused, its rows printed by the path it would have, nothing written" \
	"$( cat "$rigTmp/r5a.rc" ) $( [ "$( LC_ALL=C grep -c "^$rigSrc/keeper-here/keeper-here.x.routine.md:[0-9]*: " "$rigTmp/r5a" )" -ge 3 ] && printf rows ) $( rigHas 'does not meet the routine contract, so nothing was saved' "$rigTmp/r5a" ) $( [ -e "$rigSrc/keeper-here/keeper-here.x.routine.md" ] && printf written || printf absent )" "1 rows 1 absent"
printf -- '---\nmaintainers: rig\n---\n# keeper-here armed\n\nRead `reference/nothing-here.md` first.\n' > "$rigTmp/cite.md"
rigStdin="$rigTmp/cite.md" ; rigAsLib "$rigTmp/r5b" --skillset-upsert keeper-here keeper-here.armed.md --from-stdin
rigAssert "a citation of a file that is not there only reports: the row is printed, and the file is saved" "$( LC_ALL=C grep -c "^$rigHere:[0-9]*: " "$rigTmp/r5b" ) $( rigHas 'report-citation: cites a file that is not there: reference/nothing-here.md' "$rigTmp/r5b" ) $( cat "$rigTmp/r5b.rc" ) $( cmp -s "$rigHere" "$rigTmp/cite.md" && printf saved )" "1 1 0 saved"

echo "-- 6. the save --"
chmod 640 "$rigHere"
rigStdin="$rigTmp/new.md" ; rigAsLib "$rigTmp/s6a" --skillset-upsert keeper-here keeper-here.armed.md --from-stdin
rigAssert "the text is written exactly, a trailing line break, quotes, a backslash, an accent and a tab among it, and it is said" "$( cat "$rigTmp/s6a.rc" ) $( cmp -s "$rigHere" "$rigTmp/new.md" && printf same ) $( LC_ALL=C grep -c "^OK: wrote $rigHere\$" "$rigTmp/s6a" )" "0 same 1"
rigAssert "the mode of the file is kept, and no temp file is left in its folder" "$( rigMode "$rigHere" ) $( ls -A "$rigSrc/keeper-here" | LC_ALL=C grep -c '\.upsert\.' )" "640 0"
rigAsLib "$rigTmp/s6b" --skillset-upsert keeper-both keeper-both.armed.md --from-file "$rigTmp/nobreak.md"
rigAssert "a member with an install beside its source copy: the source copy is written, from a file, with no line break at its end as given; the install is not" "$( cat "$rigTmp/s6b.rc" ) $( cmp -s "$rigSrc/keeper-both/keeper-both.armed.md" "$rigTmp/nobreak.md" && printf same ) $( rigBytes "$rigWs/.local/myx/rig/skillset/keeper-both/keeper-both.armed.md" )" '0 same rig-seedarmed\n'
rigStdin="$rigTmp/new.md" ; rigAsLib "$rigTmp/s6c" --skillset-upsert keeper-here reference/deeper/more/notes.md --from-stdin
rigAssert "a new file in folders that are not there yet: the folders are made, the file is written and is said to be new, its mode is 644" "$( cat "$rigTmp/s6c.rc" ) $( cmp -s "$rigSrc/keeper-here/reference/deeper/more/notes.md" "$rigTmp/new.md" && printf same ) $( LC_ALL=C grep -c '(a new file)' "$rigTmp/s6c" ) $( rigMode "$rigSrc/keeper-here/reference/deeper/more/notes.md" ) $( ls -A "$rigSrc/keeper-here/reference/deeper/more" | LC_ALL=C grep -c '\.upsert\.' )" "0 same 1 644 0"
rigRun "$rigTmp/s6d" rig-allowed magic-librarian bash "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" --librarian-skillset-upsert keeper-here reference/by-stub.md --from-stdin
rigAssert "by the stub of the dispatcher: the same" "$( cat "$rigTmp/s6d.rc" ) $( cmp -s "$rigSrc/keeper-here/reference/by-stub.md" "$rigTmp/new.md" && printf same )" "0 same"
rigAsLib "$rigTmp/s6e" --skillset-upsert keeper-away keeper-away.armed.md --from-stdin
rigAssert "a member whose source copy only the machine's registry names, in another workspace's source/: that copy is written" "$( cat "$rigTmp/s6e.rc" ) $( cmp -s "$rigOther/source/rig/skillset/keeper-away/keeper-away.armed.md" "$rigTmp/new.md" && printf same )" "0 same"
rigAssert "the HOME skills folder's link shows the source copy it points to, and its install is untouched" "$( cmp -s "$rigHome/.claude/skills/keeper-here/keeper-here.armed.md" "$rigHere" && printf linked ) $( rigBytes "$rigWs/.local/myx/rig/skillset/keeper-install/keeper-install.armed.md" )" 'linked rig-seedarmed\n'

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SKILLSET UPSERT CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SKILLSET_UPSERT: OK (%d assertions, offline, rig tree only, %d seconds)\n' "$rigPasses" "$(( $( date +%s ) - rigBegin ))"
