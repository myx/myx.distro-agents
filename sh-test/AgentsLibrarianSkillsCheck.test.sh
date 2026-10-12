#!/usr/bin/env bash
## Behavioural check: the librarian's standing write on the skills of the team this machine
## holds (AgentsToolsGrantsMemberSkills, AgentsTools.Grants.include). magic-librarian may edit
## every .md file of a team member's skill of the machine's skills folder in HOME, where that
## skill is machine-local (a real folder there) or a link there into the source tree of the
## workspace it runs from, and it is never asked for these file by file. Decided on the real
## file: the same file reached through the HOME link, through .local/agents/members or by
## its path under source gets the same answer. A skill linked into another workspace's source
## is asked as today, and so is every other file and every other member.
## The folders are resolved by the grants index builder, once; a call is checked against the
## rows of the index, as every standing grant is.
## Proved through the real paths: served Edit, Write and Read calls decided by the harness
## gate, what the member holds (`--intern-op-permission-holds`), the grant read, and the
## session index (the native client's hook).
##   1. a skill linked into this workspace's source: its .md files, by any path;
##   2. a machine-local skill;
##   3. only .md files, only a member's skill, never the reference-only identity record;
##   4. a skill linked into another workspace's source, and a link out of this one's;
##   5. any other member on the same files;
##   6. the machine changes: a skill added, and one relinked elsewhere;
##   7. a machine whose HOME holds .agents/skills only.
## Red recipe: leave the librarian's skill rows out of AgentsToolsGrantsIndexText, and section
## 1 fails on the first Edit.
## Offline: HOME, the workspaces and the team data are this rig's own; a fake curl is first on
## PATH and no request leaves the box.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigLib/AgentsUniversalHarness.sh"
rigHook="$rigLib/client-hooks/allow-granted-native-tool.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigFn" "$rigHarness" "$rigHook" "$rigLib/AgentsTools.Grants.include" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
rigTmp="$( mktemp -d -t AgentsLibrarianSkillsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
mkdir -p "$rigTmp/bin"
printf '#!/bin/sh\necho "rig fake curl: no request leaves this box" >&2\nexit 7\n' > "$rigTmp/bin/curl"
chmod +x "$rigTmp/bin/curl"

## The machine: ws-main, the workspace the librarian runs from, and ws-other beside it. Each
## holds members' skills in its source. HOME holds the machine's skills folder.
rigHome="$rigTmp/home"
rigMain="$rigTmp/ws-main"
rigOther="$rigTmp/ws-other"
rigData="$rigTmp/data"
rigSkills="$rigHome/.claude/skills"
rigHere="$rigMain/source/rig/rig-proj/skillset"
rigThere="$rigOther/source/rig/rig-proj/skillset"
mkdir -p "$rigSkills" "$rigHere" "$rigThere" "$rigMain/.local/agents/members" "$rigData/board/running" "$rigMain/source/rig/rig-proj/not-a-skillset/keeper-here"
## A member's skill: its SKILL.md, its own <name>.basic.md, an .md file at its top and one deeper, and a file that is no .md.
rigSkill(){ ## folder, name, status line (may be empty)
	mkdir -p "$1/reference" "$1/resources"
	printf -- '---\nname: %s\ndescription: rig member\n%s---\n' "$2" "${3:+$3
}" > "$1/SKILL.md"
	printf 'rig\n' > "$1/$2.basic.md"
	printf 'rig-seed armed\n' > "$1/$2.armed.md"
	printf 'rig-seed notes\n' > "$1/reference/notes.md"
	printf 'rig-seed mark\n' > "$1/resources/mark.txt"
}
for rigName in magic-librarian magic-tester keeper-here ; do
	rigSkill "$rigHere/$rigName" "$rigName" ""
	ln -s "$rigHere/$rigName" "$rigSkills/$rigName"
	ln -s "$rigHere/$rigName" "$rigMain/.local/agents/members/$rigName"
done
rigSkill "$rigHere/human-owner" human-owner "status: reference-only"
ln -s "$rigHere/human-owner" "$rigSkills/human-owner"
ln -s "$rigHere/human-owner" "$rigMain/.local/agents/members/human-owner"
## A skill of another workspace, linked from HOME into that workspace's source; and one whose
## HOME link names a folder under this workspace's source that is itself a link out of it.
rigSkill "$rigThere/keeper-other" keeper-other ""
ln -s "$rigThere/keeper-other" "$rigSkills/keeper-other"
rigSkill "$rigThere/keeper-out" keeper-out ""
ln -s "$rigThere/keeper-out" "$rigHere/keeper-out"
ln -s "$rigHere/keeper-out" "$rigSkills/keeper-out"
## A machine-local skill: a real folder of the HOME skills folder. And a real folder there that is no member's.
rigSkill "$rigSkills/keeper-local" keeper-local ""
mkdir -p "$rigSkills/vendor-skill"
printf -- '---\nname: vendor-skill\ndescription: rig-seed, not a member\n---\n' > "$rigSkills/vendor-skill/SKILL.md"
## Files that are no member's skill: an .md elsewhere in source, one in a skillset folder no
## member holds, one under a folder whose path only holds the word.
printf 'rig-seed notes\n' > "$rigMain/source/rig/rig-proj/notes.md"
mkdir -p "$rigHere/draft"
printf 'rig-seed draft\n' > "$rigHere/draft/draft.md"
printf 'rig-seed word\n' > "$rigMain/source/rig/rig-proj/not-a-skillset/keeper-here/x.md"

rigRunHome="$rigHome"
## One served call as one member's run, as the MCP server makes it; its output in call.out.
rigCall(){ ## member, session, tool, argument object
	( cd "$rigMain" && printf '%s' "$4" | env -i HOME="$rigRunHome" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigMain" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_DATA_ROOT="$rigData" MDAT_SPAWN_AGENT="$1" MDAT_SPAWN_SESSION_ID="$2" \
		bash "$rigHarness" --intern-tool "$3" ) > "$rigTmp/call.out" 2> "$rigTmp/call.err"
}
## What the last served call came to: `refused` by a gate, else the word given when its output holds the text given.
rigCame(){ ## word, text
	case "$( cat "$rigTmp/call.out" )" in
		*'not in the allowed access-root set'*|*'not in the allowed write-root set'*) printf 'refused' ;;
		*"$2"*) printf '%s' "$1" ;;
		*) printf 'other:%s' "$( head -1 "$rigTmp/call.out" )" ;;
	esac
}
rigEdit(){ ## member, file -- one more word after its seed
	rigCall "$1" "s-$1" Edit "{\"file_path\":\"$2\",\"old_string\":\"rig-seed\",\"new_string\":\"rig-seed edited\"}" ; rigCame edited 'OK: replaced'
}
rigWrite(){ ## member, file
	rigCall "$1" "s-$1" Write "{\"file_path\":\"$2\",\"content\":\"rig-seed written\\n\"}" ; rigCame wrote 'OK: wrote'
}
rigRead(){ ## member, file
	rigCall "$1" "s-$1" Read "{\"file_path\":\"$2\"}" ; rigCame read rig-seed
}
## One operation of the tooling in ws-main, clean env; stdout in out.
rigOp(){ ## op and arguments...
	env -i HOME="$rigRunHome" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigMain" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_DATA_ROOT="$rigData" RIG_TMP="$rigTmp" bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$HOME" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$0" "$@"
		' "$rigFn" "$@" > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null
}
rigHolds(){ ## member, tool, path -- the HOLDS or NOT-HOLDS line
	rigOp --intern-op-permission-holds "$1" "$2" "$3" --session-id "s-$1"
	LC_ALL=C grep -E '^(HOLDS|NOT-HOLDS)' "$rigTmp/out" | head -1
}
rigGrantRead(){ ## member, tool, path -- what grants that call, as its GRANT line says it, or empty
	rigOp --intern-op-permission-grant-read "$1" --session-id "s-$1" --tool "$2" --target "$3"
	LC_ALL=C sed -n 's/^GRANT: //p' "$rigTmp/out" | head -1
}
## The native client's PreToolUse hook asked about an Edit, as one member's run. It decides by
## the session index alone: `allow <what admitted it>`, `none` when no row does, else `deny`.
rigHookEdit(){ ## member, path
	local hookOut
	printf '{"session_id":"s-%s","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"%s","old_string":"a","new_string":"b"}}' "$1" "$rigMain" "$2" > "$rigTmp/hook.in"
	hookOut="$( env -i HOME="$rigRunHome" PATH=/usr/bin:/bin:/usr/sbin:/sbin MMDAPP="$rigMain" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SPAWN_AGENT="$1" MDAT_SPAWN_SESSION_ID="s-$1" bash "$rigHook" < "$rigTmp/hook.in" 2> "$rigTmp/hook.err" )"
	case "$hookOut" in
		'') printf 'none' ;;
		*'"permissionDecision": "allow"'*) printf 'allow %s' "$( printf '%s\n' "$hookOut" | LC_ALL=C sed -n "s/.*\"permissionDecisionReason\": \"granted to $1: \\(.*\\)\"\$/\\1/p" )" ;;
		*) printf 'deny' ;;
	esac
}
## The folders whose .md files the grants index gives the librarian to write, sorted, the rig tree written T, a `;` after each.
rigRows(){
	LC_ALL=C awk -F'\t' '$1 == "magic-librarian" && $2 == "write" && $3 ~ /\/\*\*\.md$/ { print substr( $3, 1, length( $3 ) - 6 ) ; }' "$rigMain/.local/agents/grants.index" 2> /dev/null \
		| LC_ALL=C sed "s|$rigTmp|T|" | LC_ALL=C sort | LC_ALL=C tr '\n' ';'
}

## ---------------------------------------------------------------- linked into this workspace's source
echo "-- 1. a skill the machine links into this workspace's source: its .md files, by any path --"
rigFile="keeper-here/keeper-here.armed.md"
rigAssert "the Edit goes through, by its path under source"   "$( rigEdit magic-librarian "$rigHere/$rigFile" )" edited
rigAssert "through the HOME link"                             "$( rigEdit magic-librarian "$rigSkills/$rigFile" )" edited
rigAssert "through the workspace's member link, a file deeper in the skill" "$( rigEdit magic-librarian "$rigMain/.local/agents/members/keeper-here/reference/notes.md" )" edited
rigAssert "a new .md file is written there, through the link" "$( rigWrite magic-librarian "$rigSkills/keeper-here/new-note.md" ):$( cat "$rigHere/keeper-here/new-note.md" 2> /dev/null )" "wrote:rig-seed written"
rigAssert "reading follows from editing"                      "$( rigRead magic-librarian "$rigSkills/$rigFile" )" read
rigAssert "it is the librarian's standing access, never asked" "$( rigHolds magic-librarian Edit "$rigHere/$rigFile" )|$( rigGrantRead magic-librarian Edit "$rigHere/$rigFile" )|$( LC_ALL=C grep -c 'REFUSAL-ID' "$rigTmp/call.out" )" "HOLDS standing|standing standing|0"
rigAssert "the session index admits it, by the link and by the real path" "$( rigHookEdit magic-librarian "$rigSkills/$rigFile" )|$( rigHookEdit magic-librarian "$rigHere/$rigFile" )" "allow standing|allow standing"
rigAssert "the index builder prepared the folders: the acting members linked here, and the machine-local one" "$( rigRows )" "T/home/.claude/skills/keeper-local;T/ws-main/source/rig/rig-proj/skillset/keeper-here;T/ws-main/source/rig/rig-proj/skillset/magic-librarian;T/ws-main/source/rig/rig-proj/skillset/magic-tester;"

## ---------------------------------------------------------------- machine-local
echo "-- 2. a machine-local skill: a real folder of the HOME skills folder --"
rigAssert "its .md file is edited, and a new one written"    "$( rigEdit magic-librarian "$rigSkills/keeper-local/keeper-local.armed.md" ):$( rigWrite magic-librarian "$rigSkills/keeper-local/reference/new.md" )" edited:wrote
rigAssert "held as standing access"                           "$( rigHolds magic-librarian Write "$rigSkills/keeper-local/reference/new.md" )" "HOLDS standing"

## ---------------------------------------------------------------- only .md, only a member's skill
echo "-- 3. only .md files, only a member's skill, never the identity record --"
rigAssert "a file there that is no .md is refused, linked or machine-local" "$( rigEdit magic-librarian "$rigHere/keeper-here/resources/mark.txt" ):$( rigWrite magic-librarian "$rigSkills/keeper-here/tool.sh" ):$( rigEdit magic-librarian "$rigSkills/keeper-local/resources/mark.txt" )" refused:refused:refused
rigAssert "an .md elsewhere in the source tree is refused"    "$( rigEdit magic-librarian "$rigMain/source/rig/rig-proj/notes.md" )" refused
rigAssert "an .md in a skillset folder no member holds"       "$( rigEdit magic-librarian "$rigHere/draft/draft.md" )" refused
rigAssert "an .md whose path only holds the word"             "$( rigEdit magic-librarian "$rigMain/source/rig/rig-proj/not-a-skillset/keeper-here/x.md" )" refused
rigAssert "a real folder in HOME that is no member's skill"   "$( rigEdit magic-librarian "$rigSkills/vendor-skill/SKILL.md" )" refused
rigAssert "the reference-only identity record, by its path and by the link" "$( rigWrite magic-librarian "$rigHere/human-owner/human-owner.armed.md" ):$( rigWrite magic-librarian "$rigSkills/human-owner/human-owner.armed.md" )" refused:refused

## ---------------------------------------------------------------- another workspace's source
echo "-- 4. a skill linked into another workspace's source is asked as today --"
rigAssert "by its real path and through the HOME link: refused" "$( rigEdit magic-librarian "$rigThere/keeper-other/keeper-other.armed.md" ):$( rigEdit magic-librarian "$rigSkills/keeper-other/keeper-other.armed.md" )" refused:refused
rigAssert "it is not held, and the refusal is recorded to ask by" "$( rigHolds magic-librarian Edit "$rigThere/keeper-other/keeper-other.armed.md" ):$( LC_ALL=C grep -c '^REFUSAL-ID: refusal-' "$rigTmp/call.out" )" "NOT-HOLDS:1"
rigAssert "a HOME link to a folder under this source that is itself a link out of it: the real file decides" \
	"$( rigEdit magic-librarian "$rigSkills/keeper-out/keeper-out.armed.md" ):$( rigEdit magic-librarian "$rigHere/keeper-out/keeper-out.armed.md" ):$( rigEdit magic-librarian "$rigThere/keeper-out/keeper-out.armed.md" )" refused:refused:refused

## ---------------------------------------------------------------- another member
echo "-- 5. any other member on the same files is refused as today --"
rigAssert "the linked skill, by its path and by the link; the machine-local one" "$( rigEdit magic-tester "$rigHere/$rigFile" ):$( rigEdit magic-tester "$rigSkills/$rigFile" ):$( rigEdit magic-tester "$rigSkills/keeper-local/keeper-local.armed.md" )" refused:refused:refused
rigAssert "nor does it hold them"                             "$( rigHolds magic-tester Edit "$rigHere/$rigFile" ):$( rigHookEdit magic-tester "$rigHere/$rigFile" )" "NOT-HOLDS:none"

## ---------------------------------------------------------------- the machine changes
echo "-- 6. the machine changes: a skill added in HOME, and one relinked elsewhere --"
## A second on, so the HOME skills folder is newer than the grants index built before.
sleep 1
rigSkill "$rigSkills/keeper-late" keeper-late ""
rigAssert "a machine-local skill added since is the librarian's at its next call" "$( rigEdit magic-librarian "$rigSkills/keeper-late/keeper-late.armed.md" )" edited
sleep 1
rm -f "$rigSkills/keeper-here"
rigSkill "$rigThere/keeper-here" keeper-here ""
ln -s "$rigThere/keeper-here" "$rigSkills/keeper-here"
rigAssert "a skill the machine now links elsewhere is asked: its new target, and the folder it left" "$( rigEdit magic-librarian "$rigSkills/$rigFile" ):$( rigEdit magic-librarian "$rigHere/$rigFile" )" refused:refused

## ---------------------------------------------------------------- .agents/skills only
echo "-- 7. a machine whose HOME holds .agents/skills only --"
rigRunHome="$rigTmp/home-agents"
rigSkill "$rigRunHome/.agents/skills/keeper-agents" keeper-agents ""
rigAssert "its machine-local skill is the librarian's"       "$( rigEdit magic-librarian "$rigRunHome/.agents/skills/keeper-agents/keeper-agents.armed.md" ):$( rigRows )" "edited:T/home-agents/.agents/skills/keeper-agents;"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ LIBRARIAN SKILLS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'LIBRARIAN_SKILLS: OK (%d assertions, offline, rig HOME only)\n' "$rigPassCount"
