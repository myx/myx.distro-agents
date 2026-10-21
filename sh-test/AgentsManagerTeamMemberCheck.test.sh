#!/usr/bin/env bash
## Behavioural check on --manager-team-member-list and --manager-team-member-read [--full] <team-member>, two operations of the
## console's own family --manager-*, run rather than read, against a rig machine built here: a HOME with the
## machine's members index and the workspaces it knows, a workspace we run from with its own member registry, its
## names registry, its members' folders, their scopes and its spawn records, a second workspace with members of its
## own, and a process list of its own -- a ps first on PATH lists the rig's runs only, so no process of the host is
## ever seen.
## Held, THE LIST: one `member` row a member, byte for byte -- its mark, its three names, its prefix group, the
## workspace it is set up in, where that is, the status of its SKILL.md and whether a run of it is alive. The
## workspace's own members come first, in the order of their registry; then each member the machine knows that is
## set up only in another workspace, which is a member here too, with the names its own workspace's registry holds;
## then one whose workspace cannot be reached, which is said and never dropped. A reference-only member is listed
## and marked. A member with no names shows `-`. The call rebuilds `team-members`, so a member added since the last
## rebuild has its row, and reads `team-members-names` as it lies: with none, every name is `-`, one note says so,
## and the status is 0. A rules file is no member.
## THE READ: the member's row, its information (the description of its SKILL.md in both forms a frontmatter writes
## it, its workspace, its home, the kind of its link and its path), the bullets of its basic.md, the sessions it has
## a run in with those where a run of it is alive first -- rows of --manager-session-list, verbatim -- its grants,
## which are the rows --magic-permission-list prints for it, and its settings by key, which are the lines
## --manager-config-digest prints of its scope: the family has one rule on which key is a credential, the digest's.
## A CREDENTIAL IS PRINTED IN ONE FORM (F11.8): no value of one stands whole anywhere in what any call here printed,
## on either stream, only its first quarter and a `*` for each character after it.
## A member set up elsewhere is found by the operation itself, and its settings of a system this workspace holds
## none of are named, by key alone, with the workspace they are read from. A name that is no member, a member whose
## workspace cannot be reached, a missing or a second argument are refused in one line, status 1, nothing on stdout.
## THE CALLER RULE of the family holds for both. And the help pair, with the row forms the output is checked
## against. A fake `curl` first on PATH would log a request: none is made. Offline; only the rig's own tree is
## read or written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigListOp="--manager-team-member-list"
rigReadOp="--manager-team-member-read"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerTeamMemberCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws-here" ; rigFar="$rigTmp/ws-far" ; rigHome="$rigTmp/home"
rigAgents="$rigWs/.local/agents"
rigSp="$rigAgents/spawned"
rigShared="$rigHome/.agents/magic-team"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigAgents/members" "$rigSp" "$rigFar/.local/.agents" "$rigFar/.local/agents/members" "$rigHome"
rigHost="$( hostname -s 2>/dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"
rigTab="$( printf '\t' )"

## THE RIG'S OWN PROCESS LIST, as in AgentsManagerSessionListCheck: the ps first on PATH answers the whole-host
## listing from the rig's own list, one `<pid> <command line>` line a process, and hands every other call to the
## real ps.
ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
: > "$rigTmp/ps.list"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*)
		case "$*" in
			*pid=*) cat "${0%/*}/../ps.list" 2> /dev/null ;;
			*) sed 's/^[^ ]* //' "${0%/*}/../ps.list" 2> /dev/null ;;
		esac
		exit 0
	;;
esac
exec "${0%/*}/ps.real" "$@"
RIGPS
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/curl.calls"\nexit 7\n' "$rigTmp" > "$rigTmp/bin/curl"
chmod +x "$rigTmp/bin/ps" "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v ps )" = "$rigTmp/bin/ps" ] && [ "$( command -v curl )" = "$rigTmp/bin/curl" ] \
	|| rigRefuse "the rig's own ps and curl are not first on PATH, so this check would read the host's process list or issue a real request"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

## THE RIG'S SECRETS: values no call may print whole. They are this rig's own strings and open nothing; a check still
## never shows one, so what a call printed is compared with each of them written as a mark (rigShown).
rigSecretSlack="rig-slack-user-token-KEEPER-7f3a91"
rigSecretSlackOld="rig-slack-user-token-KEEPER-OLD-11c2"
rigSecretXai="rig-xai-api-key-KEEPER-91bc04"
rigPlainOdd="rig-key-of-no-catalogue-KEEPER-5e5e"
rigPlainUrl="rig-password-in-a-url-KEEPER-6d6d"
rigSecretFarHere="rig-slack-user-token-FAR-HERE-a1a1"
rigSecretFarThere="rig-slack-user-token-FAR-THERE-b2b2"
rigSecretFarJira="rig-jira-api-token-FAR-c3c3"
rigSecretFarWhere="rig-key-of-no-system-FAR-d4d4"
rigSecrets="$rigSecretSlack $rigSecretSlackOld $rigSecretXai $rigSecretFarHere $rigSecretFarThere $rigSecretFarJira $rigSecretFarWhere"
rigMask(){ ## value -- the F11.8 form: the first quarter, 4 to 20 characters, then a `*` for each character after it
	local maskValue="$1" maskLength maskShown
	maskLength="${#maskValue}"
	maskShown=$(( maskLength / 4 ))
	[ "$maskShown" -ge 4 ] || maskShown=4
	[ "$maskShown" -le 20 ] || maskShown=20
	printf '%s' "${maskValue:0:$maskShown}"
	[ "$maskLength" -le "$maskShown" ] || printf '%*s' $(( maskLength - maskShown )) '' | LC_ALL=C tr ' ' '*'
}
rigShown(){ ## -- stdin with every secret of the rig written as a mark
	local shownSecret shownScript=""
	for shownSecret in $rigSecrets ; do shownScript="$shownScript -e s/$shownSecret/<A-SECRET-OF-THE-RIG>/g" ; done
	LC_ALL=C sed $shownScript
}

## THE MEMBERS. A member is set up in a workspace by its own folder in that workspace's source, linked into that
## workspace's member set view, with a row in its member registry and in the machine's members index.
rigMemberDir(){ ## workspace root, member -- that member's own folder in that workspace's source
	printf '%s\n' "$1/source/myx/pkg/skillset/$2"
}
rigMemberRow(){ ## registry file, workspace root, member, link kind
	mkdir -p "${1%/*}"
	printf '%s\t%s\t%s\tmyx/pkg/skillset/%s\t%s\n' "$3" "$2" "$4" "$3" "$( rigMemberDir "$2" "$3" )" >> "$1"
}
rigMemberAt(){ ## workspace root, member, status ("" for none), the description lines of its SKILL.md as its frontmatter holds them
	local atDir ; atDir="$( rigMemberDir "$1" "$2" )"
	mkdir -p "$atDir" "$1/.local/agents/members"
	{
		printf -- '---\nname: %s\n' "$2"
		[ -z "$3" ] || printf 'status: %s\n' "$3"
		printf 'invocation_mode: auto\n%s\nmaintainers: rig\n---\n\n# %s\n' "$4" "$2"
	} > "$atDir/SKILL.md"
	ln -sfn "$atDir" "$1/.local/agents/members/$2"
}
rigBasic(){ ## workspace root, member -- stdin: the body of its basic.md
	{ printf -- '---\nmaintainers: rig\n---\nYou are `%s`.\n\n' "$2" ; cat ; } > "$( rigMemberDir "$1" "$2" )/$2.basic.md"
}
rigScope(){ ## workspace root, scope, lines...
	local scopeFile="$1/.local/.agents/$2.agent.env" ; shift 2
	printf '%s\n' "$@" > "$scopeFile"
}

## The workspace we run from: three members of its own, one of them reference-only, and a rules file's row.
rigMemberAt "$rigWs" human-owner reference-only 'description: >-
  Reference-only record of the rig'"'"'s owner.'
rigBasic "$rigWs" human-owner <<'RIGBASIC'
## Identity marks

- **Slack shortcode**: `:own:`
RIGBASIC
rigMemberAt "$rigWs" magic-coordinator active "description: The rig's coordinator, on one line."
rigBasic "$rigWs" magic-coordinator <<'RIGBASIC'
## Public Information

- **Name**: Magic Vane.
- **Alias**: `dispatchr`.

## Identity marks

- **Unicode character**: 🐭
RIGBASIC
rigMemberAt "$rigWs" keeper-rig active 'description: >-
  The rig'"'"'s keeper: keeps the rig,
  and nothing else.'
rigBasic "$rigWs" keeper-rig <<'RIGBASIC'
Identity only. A line with **Name**: in its middle is no bullet.

## Public Information

- **Description**: keeper of the rig — keeps
  what the rig holds.
- **Name**: Rig Keeper.
- **Alias**: `rigkeep`.

## Identity marks

- **Unicode character**: 🔧
- **a rule and no identity bullet** (it has no colon after its name): never listed
RIGBASIC
: > "$rigAgents/members.registry"
rigMemberRow "$rigAgents/members.registry" "$rigWs" human-owner source-symlink
rigMemberRow "$rigAgents/members.registry" "$rigWs" magic-coordinator source-symlink
rigMemberRow "$rigAgents/members.registry" "$rigWs" keeper-rig .local-symlink
printf '%s\t%s\trules-symlink\tmyx/pkg/skillset/magic-team/magic-team.basic.md\t%s\n' magic-team.basic.md "$rigWs" "$rigWs/source/myx/pkg/skillset/magic-team/magic-team.basic.md" >> "$rigAgents/members.registry"
## Its names registry, as --make-harness-indices would have left it: the owner has no person name by design.
rigNames="$rigAgents/team-members-names.registry"
printf '%s\n' 'human-owner :own: - - -' 'magic-coordinator 🐭 Magic Vane dispatchr' 'keeper-rig 🔧 Rig Keeper rigkeep' > "$rigNames"

## The scope of keeper-rig here: a comment, a token the catalogue marks secret, twice (the reader takes the last
## line), two keys the owner setup's catalogue marks plain, one with a space and one with an `=` in its value, a key
## that catalogue marks secret, a key with no value, a key that is none of the credentials with a value, a key of a
## plain kind, and a plain key whose value carries a password inside a URL.
rigScope "$rigWs" keeper-rig \
	'# NOTE=a comment, which is no setting' \
	"SLACK_USER_TOKEN=$rigSecretSlackOld" \
	'CONFLUENCE_SPACE=RIG SPACE' \
	"XAI_API_KEY=$rigSecretXai" \
	'SLACK_BOT_TOKEN=' \
	'WEB_ALLOW_PREFIXES=https://docs.rig.invalid/a?b=c https://rig.invalid/' \
	"ODD_SETTING=$rigPlainOdd" \
	'JIRA_SITE=jira-here.rig.invalid' \
	"TEAM_DATA_GIT_REMOTE=https://rig:$rigPlainUrl@git.rig.invalid/team.git" \
	"SLACK_USER_TOKEN=$rigSecretSlack"
chmod 660 "$rigWs/.local/.agents/keeper-rig.agent.env"

## THE SESSIONS of the workspace we run from, as AgentsManagerSessionListCheck writes them. keeper-rig has a live
## run in sess-live and a closed one in sess-done, which is the NEWER session, so the order of the session list and
## the order of the read differ; sess-other holds no run of it. magic-coordinator's runs have no process.
rigRec(){ ## sandbox, record name, session id, spawn id, owner, status, started-at, resolved-at ("" for none), session-comment ("" for none)
	mkdir -p "$rigSp/$1"
	{
		printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nworkspace: rigws\nowner: %s\nstatus: %s\nstarted-at: %s\n' "$3" "$4" "$rigHost" "$5" "$6" "$7"
		[ -z "$8" ] || printf 'resolved-at: %s\n' "$8"
		[ -z "$9" ] || printf 'session-comment: %s\n' "$9"
		printf -- '---\n\n# Spawn session: %s\n' "$3"
	} > "$rigSp/$1/$2.spawn.md"
}
rigLive(){ ## spawn id... -- the rig's process list: each a run by its own --session-id word
	local liveId livePid=900100
	: > "$rigTmp/ps.list"
	for liveId in "$@" ; do
		livePid=$(( livePid + 1 ))
		printf '%s claude --verbose --session-id %s --agent rig-member the brief\n' "$livePid" "$liveId" >> "$rigTmp/ps.list"
	done
}
rigRec sess-live sess-live sess-live sess-live magic-coordinator spawn-started '2026-10-12 09:00 +0300' '' ''
rigRec run-k1 run-k1 sess-live run-k1 keeper-rig spawn-started '2026-10-12 09:05 +0300' '' ''
rigRec sess-done sess-done sess-done sess-done magic-coordinator spawn-succeeded '2026-10-13 08:00 +0300' '2026-10-13 08:50 +0300' 'daily of the rig'
rigRec run-k2 run-k2 sess-done run-k2 keeper-rig spawn-succeeded '2026-10-13 08:05 +0300' '2026-10-13 08:40 +0300' ''
rigRec sess-other sess-other sess-other sess-other magic-coordinator spawn-succeeded '2026-10-11 07:00 +0300' '2026-10-11 07:30 +0300' ''
rigLive run-k1

rigPre=()
: > "$rigTmp/all.printed"
rigRunIn(){ ## workspace, tool arguments... -- one dispatcher call from that workspace; rc in rigRc, stdout in out, stderr in err
	local runWs="$1" ; shift
	rigRc=0
	( cd "$runWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$runWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
	cat "$rigTmp/out" "$rigTmp/err" >> "$rigTmp/all.printed"
}
rigRun(){ ## tool arguments... -- in the workspace we run from
	rigRunIn "$rigWs" "$@"
}
rigRows(){ ## row kind -- the rows of that kind in the last output, TAB written as a space
	LC_ALL=C awk -F'\t' -v wantKind="$1" '$1 == wantKind { gsub( /\t/, " " ) ; print ; }' "$rigTmp/out"
}
rigRowOf(){ ## row kind, the name in its second field -- that row, TAB written as a space
	LC_ALL=C awk -F'\t' -v wantKind="$1" -v wantId="$2" '$1 == wantKind && $2 == wantId { gsub( /\t/, " " ) ; print ; }' "$rigTmp/out"
}
rigTroubles(){ ## -- how many lines of the last stderr are an error or a warning, but for the one every rig of this package gets
	LC_ALL=C grep -E -- 'ERROR|WARNING' "$rigTmp/err" | LC_ALL=C grep -c -v -F -- 'SystemContext.SetInputSpec' || :
}
rigWhole(){ ## file, text -- how many lines of the file are that text, whole
	LC_ALL=C grep -c -x -F -- "$2" "$1" 2> /dev/null || :
}
rigPrint(){ ## file -- its inode and the sum of its bytes; no-file where there is none
	[ -f "$1" ] || { printf 'no-file\n' ; return 0 ; }
	printf '%s:%s\n' "$( ls -i "$1" | LC_ALL=C awk '{ print $1 ; exit }' )" "$( cksum < "$1" | LC_ALL=C tr -s ' \t' '-' )"
}
rigOthers(){ ## -- every file of the workspace we run from but the registries a call here rebuilds and the grants index, each with the sum of its bytes, as one sum
	( cd "$rigWs" && find . -type f ! -name team-members.registry ! -name spawned-sessions.registry ! -name pending-replies.registry ! -name 'grants.index*' ! -name 'permissions*.registry' | LC_ALL=C sort | while IFS= read -r othersFile ; do printf '%s %s\n' "$othersFile" "$( cksum < "$othersFile" )" ; done ) | cksum
}

echo "-- 1. the list: each member of the workspace is one row --"
rigRun "$rigListOp"
rigWant="$( {
	printf 'member\thuman-owner\t:own:\t-\t-\t-\thuman\tws-here\there\treference-only\tno-process\t👤\t%s\n' "$( rigMemberDir "$rigWs" human-owner )"
	printf 'member\tmagic-coordinator\t🐭\tMagic\tVane\tdispatchr\tmagic\tws-here\there\tactive\tno-process\t🤖\t%s\n' "$( rigMemberDir "$rigWs" magic-coordinator )"
	printf 'member\tkeeper-rig\t🔧\tRig\tKeeper\trigkeep\tkeeper\tws-here\there\tactive\trunning\t🔏\t%s\n' "$( rigMemberDir "$rigWs" keeper-rig )"
} )"
rigAssert "the call ends 0, with no error and no warning" "$rigRc $( rigTroubles )" "0 0"
rigAssert "the whole output, byte for byte: the member registry holds three members and a rules file, and the list prints three rows, in the registry's order, each with its mark, its names and its alias" "$( rigShown < "$rigTmp/out" )" "$rigWant"
rigAssert "a member that is not to be started is marked: the SKILL.md of human-owner says reference-only and its row says so; the other rows say active" "$( rigRows member | LC_ALL=C awk '{ printf "%s=%s ", $2, $10 }' )" "human-owner=reference-only magic-coordinator=active keeper-rig=active "
rigAssert "a member with no names shows -: the names registry holds - for the three names of human-owner, and so does its row" "$( LC_ALL=C awk '$1 == "human-owner" { print $3, $4, $5 }' "$rigNames" ) / $( rigRowOf member human-owner | LC_ALL=C awk '{ print $4, $5, $6 }' )" "- - - / - - -"
rigAssert "the prefix group of each member is its kind" "$( rigRows member | LC_ALL=C awk '{ printf "%s ", $7 }' )" "human magic keeper "
rigAssert "a member with a run that has a live process reads running, and one whose runs have none reads no-process" "$( rigRowOf member keeper-rig | LC_ALL=C awk '{ print $11 }' ) $( rigRowOf member magic-coordinator | LC_ALL=C awk '{ print $11 }' )" "running no-process"
: > "$rigTmp/ps.list"
rigRun "$rigListOp"
rigAssert "with no live process no member reads running: alive is measured now, by the process list" "$rigRc $( rigRows member | LC_ALL=C awk '$11 == "running" { n++ } END { print n + 0 }' )" "0 0"
rigLive run-k1 run-f1
rigAssert "every row has thirteen fields, the last the member's own skillset folder, its link in the member set followed (the owner: \"WHERE - can show <workspace place name>:<project-path>\"), and no line is of another kind" "$( LC_ALL=C awk -F'\t' '{ if ( $1 != "member" || NF != 13 ) bad++ ; } END { print NR ":" bad + 0 }' "$rigTmp/out" )" "3:0"

echo "-- 2. a reader that passes by updates the registry, and writes nothing else --"
rigAssert "the registry team-members is written, with its four columns in each of its three rows" "$( LC_ALL=C awk 'NF == 4 { whole++ } END { print NR ":" whole + 0 }' "$rigAgents/team-members.registry" )" "3:3"
rigOthersBefore="$( rigOthers )"
TZ=UTC touch -t 202610010000.00 "$rigAgents/team-members.registry"
rigMemberAt "$rigWs" keeper-new active 'description: A member added since the last rebuild.'
rigMemberRow "$rigAgents/members.registry" "$rigWs" keeper-new source-symlink
rigAssert "control: the member registry got a row after team-members was last built, which holds no row of it" "$( [ "$rigAgents/members.registry" -nt "$rigAgents/team-members.registry" ] && echo newer ) $( LC_ALL=C grep -c -e '^keeper-new ' "$rigAgents/team-members.registry" )" "newer 0"
rigOthersAdded="$( rigOthers )"
rigRun "$rigListOp"
rigAssert "a member added since the last rebuild has its row, with - for the names no registry holds of it yet" "$rigRc $( rigRowOf member keeper-new )" "0 member keeper-new - - - - keeper ws-here here active no-process 🔏 $( rigMemberDir "$rigWs" keeper-new )"
rigAssert "and its row in the registry file, which the call rebuilt" "$( LC_ALL=C awk '$1 == "keeper-new" { print $2, $3 }' "$rigAgents/team-members.registry" )" "ws-here source-symlink"
rigAssert "nothing else of the workspace was written by the list: every other file is as it was" "$( rigOthers )" "$rigOthersAdded"
rigAssert "the names registry is read as it lies: the list did not rebuild it" "$( LC_ALL=C grep -c -e '^keeper-new ' "$rigNames" )" "0"
## The added member is taken out again: the rig holds its three members from here on.
LC_ALL=C grep -v -e '^keeper-new'"$rigTab" "$rigAgents/members.registry" > "$rigTmp/members.kept" && cat "$rigTmp/members.kept" > "$rigAgents/members.registry"
rm -rf "$( rigMemberDir "$rigWs" keeper-new )" "$rigAgents/members/keeper-new"
rigRun "$rigListOp"
rigAssert "a member taken out of the member registry is no row any more" "$rigRc $( rigRows member | LC_ALL=C awk '{ printf "%s ", $2 }' )" "0 human-owner magic-coordinator keeper-rig "
rigAssert "control: the workspace is as it was before the member was added" "$( rigOthers )" "$rigOthersBefore"

echo "-- 3. the list goes on with no names registry --"
mv "$rigNames" "$rigNames.aside"
rigRun "$rigListOp"
rigAssert "with no team-members-names registry the status is 0 and each member is printed with - for its mark and its names" "$rigRc $( rigRows member | LC_ALL=C awk '{ printf "%s:%s,%s,%s,%s ", $2, $3, $4, $5, $6 }' )" "0 human-owner:-,-,-,- magic-coordinator:-,-,-,- keeper-rig:-,-,-,- "
rigAssert "one note says so, on standard error, with no error and no warning" "$( LC_ALL=C grep -c -F -- "# DistroAgentsTools $rigListOp: no names registry is at $rigNames" "$rigTmp/err" || : ) $( LC_ALL=C grep -c -F -- "$rigListOp" "$rigTmp/err" || : ) $( rigTroubles )" "1 1 0"
rigAssert "the rest of each row stands: its kind, its workspace, its status and whether it is alive" "$( rigRowOf member keeper-rig | LC_ALL=C awk '{ print $7, $8, $9, $10, $11 }' )" "keeper ws-here here active running"
rigAssert "and the list did not make the registry it found missing" "$( [ -e "$rigNames" ] && echo made || echo none )" "none"
rigRun "$rigReadOp" keeper-rig
rigAssert "the read of a member goes on the same way: its row with - for its mark and its names, one note under its own name, status 0" "$rigRc $( rigRowOf member keeper-rig | LC_ALL=C awk '{ printf "%s,%s,%s,%s %s", $3, $4, $5, $6, $10 }' ) $( LC_ALL=C grep -c -F -- "# DistroAgentsTools $rigReadOp: no names registry is at $rigNames" "$rigTmp/err" || : ) $( rigTroubles )" "0 -,-,-,- active 1 0"
mv "$rigNames.aside" "$rigNames"

echo "-- 4. a member set up only in another workspace on this machine is a member here too --"
## ws-far: two members of its own and the team's folder, its names registry and its team-members registry as they
## lie there. The machine's members index names both workspaces' members, one whose workspace is not on this machine
## and one whose workspace the machine does not know; its pointers name the workspaces it knows.
rigMemberAt "$rigFar" keeper-far active 'description: >-
  A keeper set up in the far workspace.'
rigBasic "$rigFar" keeper-far <<'RIGBASIC'
## Public Information

- **Name**: Far Keeper.
RIGBASIC
rigMemberAt "$rigFar" client-rig active 'description: The rig'"'"'s client-side member.'
rigBasic "$rigFar" client-rig <<'RIGBASIC'
## Public Information

- **Name**: Rig Client.
RIGBASIC
rigMemberAt "$rigFar" magic-team active 'description: The team as a whole.'
printf '%s\n' 'keeper-far 🛰️ Far Keeper farkeep' 'client-rig 🐭 Magic Vane dispatchr' > "$rigFar/.local/agents/team-members-names.registry"
printf '%s\n' 'keeper-far ws-far source-symlink myx/pkg/skillset/keeper-far' 'client-rig ws-far origin-symlink myx/pkg/skillset/client-rig' > "$rigFar/.local/agents/team-members.registry"
rigIndex="$rigShared/members.registry"
mkdir -p "$rigShared" ; : > "$rigIndex"
rigMemberRow "$rigIndex" "$rigWs" human-owner source-symlink
rigMemberRow "$rigIndex" "$rigWs" magic-coordinator source-symlink
rigMemberRow "$rigIndex" "$rigWs" keeper-rig .local-symlink
rigMemberRow "$rigIndex" "$rigFar" keeper-far source-symlink
rigMemberRow "$rigIndex" "$rigFar" client-rig source-symlink
rigMemberRow "$rigIndex" "$rigTmp/gone/ws-gone" keeper-gone source-symlink
rigMemberRow "$rigIndex" "$rigTmp/ws-nolist" keeper-lost source-symlink
printf '%s\t%s\trules-symlink\tmyx/pkg/skillset/magic-team/magic-team.basic.md\t%s\n' magic-team.basic.md "$rigFar" "$rigFar/source/myx/pkg/skillset/magic-team/magic-team.basic.md" >> "$rigIndex"
printf '%s\t%s\n' ws-here "$rigWs" ws-far "$rigFar" ws-gone "$rigTmp/gone/ws-gone" > "$rigShared/directories.registry"
printf '%s\t%s\n' keeper-far "$rigFar" > "$rigShared/member-homes.registry"
## Its scopes: here one Slack key of keeper-far, so its Slack settings are this workspace's alone; there a Slack
## key that is therefore never read, two Jira keys, which this workspace holds none of, and a key of no system.
rigScope "$rigWs" keeper-far "SLACK_USER_TOKEN=$rigSecretFarHere"
rigScope "$rigFar" keeper-far "SLACK_USER_TOKEN=$rigSecretFarThere" 'JIRA_SITE=jira.rig.invalid' "JIRA_API_TOKEN=$rigSecretFarJira" "WHERE_KEY=$rigSecretFarWhere"
## And a run of keeper-far in a session of the workspace we run from, alive.
rigRec run-f1 run-f1 sess-live run-f1 keeper-far spawn-started '2026-10-12 09:07 +0300' '' ''
rigRun "$rigListOp"
rigWant="$( {
	printf 'member\thuman-owner\t:own:\t-\t-\t-\thuman\tws-here\there\treference-only\tno-process\t👤\t%s\n' "$( rigMemberDir "$rigWs" human-owner )"
	printf 'member\tmagic-coordinator\t🐭\tMagic\tVane\tdispatchr\tmagic\tws-here\there\tactive\tno-process\t🤖\t%s\n' "$( rigMemberDir "$rigWs" magic-coordinator )"
	printf 'member\tkeeper-rig\t🔧\tRig\tKeeper\trigkeep\tkeeper\tws-here\there\tactive\trunning\t🔏\t%s\n' "$( rigMemberDir "$rigWs" keeper-rig )"
	printf 'member\tkeeper-far\t🛰️\tFar\tKeeper\tfarkeep\tkeeper\tws-far\telsewhere\tactive\trunning\t🔏\t%s\n' "$( rigMemberDir "$rigFar" keeper-far )"
	printf 'member\tclient-rig\t🐭\tMagic\tVane\tdispatchr\tclient\tws-far\telsewhere\tactive\tno-process\t👥\t%s\n' "$( rigMemberDir "$rigFar" client-rig )"
	printf 'member\tkeeper-gone\t-\t-\t-\t-\tkeeper\t-\tnot-present\t-\tno-process\t🔏\t-\n'
	printf 'member\tkeeper-lost\t-\t-\t-\t-\tkeeper\t-\tnot-present\t-\tno-process\t🔏\t-\n'
} )"
rigAssert "the call ends 0, with no error and no warning" "$rigRc $( rigTroubles )" "0 0"
rigAssert "the whole output, byte for byte: this workspace's own members first, then each member the machine knows that is set up only elsewhere, and a rules file of neither workspace is a row" "$( rigShown < "$rigTmp/out" )" "$rigWant"
rigAssert "a member set up only in another workspace is listed, with the name of that workspace and the word elsewhere; its names are those of that workspace's own registry, which this workspace's holds no row of" "$( rigRowOf member keeper-far | LC_ALL=C awk '{ print $8, $9, $4, $5, $6 }' ) $( LC_ALL=C grep -c -e '^keeper-far ' "$rigNames" )" "ws-far elsewhere Far Keeper farkeep 0"
rigAssert "a run of it in a session of this workspace makes it read running here" "$( rigRowOf member keeper-far | LC_ALL=C awk '{ print $11 }' )" "running"
rigAssert "a client's row holds what its registry row holds, which is its persona's names" "$( rigRowOf member client-rig | LC_ALL=C awk '{ print $3, $4, $5, $6 }' ) / $( rigRowOf member magic-coordinator | LC_ALL=C awk '{ print $3, $4, $5, $6 }' )" "🐭 Magic Vane dispatchr / 🐭 Magic Vane dispatchr"
rigAssert "a member whose workspace is not on this machine, and one whose workspace the machine does not know, are listed as not-present, never dropped and never called a member of here" "$( rigRowOf member keeper-gone | LC_ALL=C awk '{ print $8, $9, $10 }' ) / $( rigRowOf member keeper-lost | LC_ALL=C awk '{ print $8, $9, $10 }' )" "- not-present - / - not-present -"
rigAssert "this workspace's registry still holds its own members only" "$( LC_ALL=C awk '{ printf "%s ", $1 }' "$rigAgents/team-members.registry" )" "human-owner magic-coordinator keeper-rig "
rigAssert "nothing of the other workspace was written: its two registries are the files they were" "$( cat "$rigFar/.local/agents/team-members-names.registry" "$rigFar/.local/agents/team-members.registry" | cksum )" "$( printf '%s\n' 'keeper-far 🛰️ Far Keeper farkeep' 'client-rig 🐭 Magic Vane dispatchr' 'keeper-far ws-far source-symlink myx/pkg/skillset/keeper-far' 'client-rig ws-far origin-symlink myx/pkg/skillset/client-rig' | cksum )"

echo "-- 4a. the icon of each member is the last field of its row --"
## Three more members the machine's index names and no workspace holds, of the prefix groups the rig has no member
## of yet: a partner, a warden, and a name of no group.
rigMemberRow "$rigIndex" "$rigTmp/gone/ws-gone" partner-rig source-symlink
rigMemberRow "$rigIndex" "$rigTmp/gone/ws-gone" warden-rig source-symlink
rigMemberRow "$rigIndex" "$rigTmp/gone/ws-gone" scribe-rig source-symlink
rigRun "$rigListOp"
rigIcons(){ ## -- each member of the last output with the last field of its row
	rigRows member | LC_ALL=C awk '{ printf "%s=%s ", $2, $12 }'
}
rigAssert "each row ends with the icon the member table of the installer shows that member with, the icon of its prefix group: the human-owner, a magic member, a keeper, a client, a partner, a warden, and a name of no group" "$rigRc $( rigIcons )" "0 human-owner=👤 magic-coordinator=🤖 keeper-rig=🔏 keeper-far=🔏 client-rig=👥 keeper-gone=🔏 keeper-lost=🔏 partner-rig=👫 warden-rig=🔏 scribe-rig=🤖 "
rigAssert "a member with a mark of its own keeps the mark where it was, and its icon is that table's, which shows no mark" "$( rigRowOf member magic-coordinator | LC_ALL=C awk '{ print $3, $12 }' ) / $( rigRowOf member human-owner | LC_ALL=C awk '{ print $3, $12 }' )" "$( LC_ALL=C awk '$1 == "magic-coordinator" { print $2 }' "$rigNames" ) 🤖 / :own: 👤"
rigAssert "the icons are those of the one list of them, which the installer's table reads: there is no second list" "$( rigIcons )" "$( . "$rigHere/team-data/AgentsTools.TeamRegistry.include" ; rigRows member | while read -r rigIconKind rigIconName rigIconRest ; do printf '%s=%s ' "$rigIconName" "$( AgentsToolsTeamMemberKindIcon "$rigIconName" )" ; done )"
rigAssert "every row has thirteen fields: the icon and the skillset folder at the end, and each field before them stands where it stood" "$( LC_ALL=C awk -F'\t' '{ if ( $1 != "member" || NF != 13 ) bad++ ; } END { print NR ":" bad + 0 }' "$rigTmp/out" ) $( rigRowOf member keeper-far | LC_ALL=C awk '{ print $7, $8, $9, $10, $11 }' )" "10:0 keeper ws-far elsewhere active running"
LC_ALL=C grep -v -e '^partner-rig'"$rigTab" -e '^warden-rig'"$rigTab" -e '^scribe-rig'"$rigTab" "$rigIndex" > "$rigTmp/index.kept" && cat "$rigTmp/index.kept" > "$rigIndex"

echo "-- 5. the read: one member's information --"
## What the sessions and the grants of a member are printed from, each by its own operation, for the comparison.
rigRun --manager-session-list
cp "$rigTmp/out" "$rigTmp/sessions.list"
rigSessionRows(){ ## session id, spawn id of the member's run in it... -- that session's row and those runs' rows, as --manager-session-list printed them
	local rowsSession="$1" rowsRun ; shift
	LC_ALL=C awk -F'\t' -v wantId="$rowsSession" '$1 == "session" && $2 == wantId' "$rigTmp/sessions.list"
	for rowsRun in "$@" ; do LC_ALL=C awk -F'\t' -v wantId="$rowsRun" '$1 == "run" && $3 == wantId' "$rigTmp/sessions.list" ; done
}
rigGrantRows(){ ## member -- the rows --magic-permission-list prints for it, each behind the word grant, a field's spaces written _ and an empty one -
	rigRun --magic-permission-list --member "$1"
	[ "$rigRc" = 0 ] || rigRefuse "the rig could not list the grants of $1: $( LC_ALL=C grep -m2 -e ERROR "$rigTmp/err" )"
	LC_ALL=C awk -F'\t' -v OFS='\t' 'NF { for ( fieldAt = 1 ; fieldAt <= NF ; fieldAt++ ) { gsub( /[ ]+/, "_", $fieldAt ) ; if ( $fieldAt == "" ) $fieldAt = "-" ; } print "grant", $0 ; }' "$rigTmp/out"
}
rigGrantRows keeper-rig > "$rigTmp/grants.keeper-rig"
rigGrantRows keeper-far > "$rigTmp/grants.keeper-far"
rigRun --manager-config-digest scopes
[ "$rigRc" = 0 ] || rigRefuse "the rig could not print the digest of its scopes: $( LC_ALL=C grep -m2 -e ERROR "$rigTmp/err" )"
cp "$rigTmp/out" "$rigTmp/digest.scopes"
rigSettingRows(){ ## scope -- the lines the digest printed for that scope, each as a setting row of this workspace
	LC_ALL=C awk -F'\t' -v OFS='\t' -v wantScope="$1" '$1 == "line" && $2 == "scopes" && $3 == wantScope { print "setting", $4, $5, $6, "ws-here" ; }' "$rigTmp/digest.scopes"
}
[ "$( rigSettingRows keeper-rig | LC_ALL=C awk 'END { print NR + 0 }' )" = 8 ] || rigRefuse "the digest of the rig does not print the eight keys of the scope of keeper-rig, so the setting rows would be checked against nothing"
[ -s "$rigTmp/grants.keeper-rig" ] || rigRefuse "the rig holds no grant of keeper-rig, its floor among them, so the grant rows would be checked against nothing"
rigRun "$rigReadOp" keeper-rig
rigWant="$( {
	printf 'member\tkeeper-rig\t🔧\tRig\tKeeper\trigkeep\tkeeper\tws-here\there\tactive\trunning\t🔏\t%s\n' "$( rigMemberDir "$rigWs" keeper-rig )"
	printf 'info\tdescription\tThe_rig'"'"'s_keeper:_keeps_the_rig,_and_nothing_else.\n'
	printf 'info\tworkspace\t%s\n' "$rigWs"
	printf 'info\thome\t-\n'
	printf 'info\tlink-kind\t.local-symlink\n'
	printf 'info\tskillset-path\tmyx/pkg/skillset/keeper-rig\n'
	printf 'bullet\tDescription\tkeeper_of_the_rig_—_keeps_what_the_rig_holds.\n'
	printf 'bullet\tName\tRig_Keeper.\n'
	printf 'bullet\tAlias\t`rigkeep`.\n'
	printf 'bullet\tUnicode_character\t🔧\n'
	rigSessionRows sess-live run-k1
	rigSessionRows sess-done run-k2
	cat "$rigTmp/grants.keeper-rig"
	rigSettingRows keeper-rig
} )"
rigAssert "the call ends 0, with no error and no warning" "$rigRc $( rigTroubles )" "0 0"
rigAssert "the whole output, byte for byte: its row, its information, its bullets, its sessions, its grants and its settings" "$( rigShown < "$rigTmp/out" )" "$rigWant"
rigAssert "one member shows its description and its status: the description of its SKILL.md, folded over two lines there, and the status in its row" "$( rigRowOf info description | LC_ALL=C awk '{ print $3 }' ) $( rigRowOf member keeper-rig | LC_ALL=C awk '{ print $10 }' )" "The_rig's_keeper:_keeps_the_rig,_and_nothing_else. active"
rigAssert "and the bullets of its basic.md, one that runs over two lines whole; a rule with no colon after its name and a line with a name in its middle are no bullets" "$( rigRows bullet | LC_ALL=C awk '{ printf "%s ", $2 }' ) $( rigRows bullet | LC_ALL=C awk '$2 == "Description" { print $3 }' )" "Description Name Alias Unicode_character  keeper_of_the_rig_—_keeps_what_the_rig_holds."
rigAssert "one member shows the sessions it is in, the live ones first: the session where its run is alive stands before the newer one where its run is closed, which the session list prints first" "$( rigRows session | LC_ALL=C awk '{ printf "%s ", $2 }' )/ $( LC_ALL=C awk -F'\t' '$1 == "session" { printf "%s ", $2 }' "$rigTmp/sessions.list" )" "sess-live sess-done / sess-done sess-live sess-other "
rigAssert "each session is followed by the member's own runs in it and by no other member's, and a session it has no run in is not printed" "$( rigRows run | LC_ALL=C awk '{ printf "%s:%s:%s:%s ", $2, $3, $4, $6 }' ) $( rigRows session | LC_ALL=C awk '$2 == "sess-other" { n++ } END { print n + 0 }' )" "sess-live:run-k1:keeper-rig:running sess-done:run-k2:keeper-rig:no-process  0"
rigAssert "its grants are the rows the permission list prints for it, its floor among them" "$( rigRows grant | LC_ALL=C awk 'END { print ( NR > 0 ) ? "rows" : "none" }' ) $( rigRows grant | LC_ALL=C awk '$2 == "floor" { n++ } END { print ( n > 0 ) ? "floor" : "no-floor" }' ) $( LC_ALL=C grep -c -e "^grant$rigTab" "$rigTmp/out" )" "rows floor $( LC_ALL=C awk 'END { print NR + 0 }' "$rigTmp/grants.keeper-rig" )"
rigAssert "its settings are the lines the digest of settings prints for its scope, each with the state and the value the digest gives it" "$( rigRows setting | LC_ALL=C awk '{ printf "%s ", $2 }' ) $( LC_ALL=C grep -e "^setting$rigTab" "$rigTmp/out" | rigShown | cksum )" "SLACK_USER_TOKEN CONFLUENCE_SPACE XAI_API_KEY SLACK_BOT_TOKEN WEB_ALLOW_PREFIXES ODD_SETTING JIRA_SITE TEAM_DATA_GIT_REMOTE  $( rigSettingRows keeper-rig | rigShown | cksum )"
rigAssert "one member shows its settings by key: a token's key reads secret-set with its value in the form of a credential, and the value stands whole nowhere in what the call printed, on either stream" "$( rigRowOf setting SLACK_USER_TOKEN ) $( cat "$rigTmp/out" "$rigTmp/err" | LC_ALL=C grep -c -F -e "$rigSecretSlack" -e "$rigSecretSlackOld" || : )" "setting SLACK_USER_TOKEN secret-set $( rigMask "$rigSecretSlack" ) ws-here 0"
rigAssert "a key the owner setup's catalogue marks secret reads the same, and a key that is none of the credentials shows its value" "$( rigRowOf setting XAI_API_KEY | LC_ALL=C awk '{ print $3, $4 }' ) / $( rigRowOf setting ODD_SETTING | LC_ALL=C awk '{ print $3, $4 }' ) $( cat "$rigTmp/out" "$rigTmp/err" | LC_ALL=C grep -c -F -e "$rigSecretXai" || : )" "secret-set $( rigMask "$rigSecretXai" ) / set $rigPlainOdd 0"
rigAssert "a key known to be no secret shows its value, a space in it written _ and an = in it kept" "$( rigRowOf setting CONFLUENCE_SPACE | LC_ALL=C awk '{ print $3, $4 }' ) $( rigRowOf setting WEB_ALLOW_PREFIXES | LC_ALL=C awk '{ print $3, $4 }' ) $( rigRowOf setting JIRA_SITE | LC_ALL=C awk '{ print $3, $4 }' )" "set RIG_SPACE set https://docs.rig.invalid/a?b=c_https://rig.invalid/ set jira-here.rig.invalid"
rigAssert "a plain key whose value carries a password inside a URL is no credential here: the member read masks per key, so its value stands as it is, the URL with it (the digest in full, which the settings views read, masks the password alone)" "$( rigRowOf setting TEAM_DATA_GIT_REMOTE | LC_ALL=C awk '{ print $3, $4 }' )" "set https://rig:$rigPlainUrl@git.rig.invalid/team.git"
rigAssert "a secret with no value reads secret-missing, a key written twice is one row, and a comment is no setting" "$( rigRowOf setting SLACK_BOT_TOKEN | LC_ALL=C awk '{ print $3 }' ) $( rigRows setting | LC_ALL=C awk '$2 == "SLACK_USER_TOKEN" { n++ } END { print n + 0 }' ) $( rigRows setting | LC_ALL=C awk 'END { print NR + 0 }' )" "secret-missing 1 8"
rigRun "$rigReadOp" --full keeper-rig
rigAssert "asked with --full, as the console reads, a password inside a URL under a key that is no credential is masked alone, the URL standing, and its row reads secret-set; a credential reads as it does without" "$( rigRowOf setting TEAM_DATA_GIT_REMOTE | LC_ALL=C awk '{ print $3, $4 }' ) $( rigRowOf setting SLACK_USER_TOKEN | LC_ALL=C awk '{ print $3, $4 }' )" "secret-set https://rig:$( rigMask "$rigPlainUrl" )@git.rig.invalid/team.git secret-set $( rigMask "$rigSecretSlack" )"
rigOthersRead="$( rigOthers )"
rigScopeBefore="$( rigPrint "$rigWs/.local/.agents/keeper-rig.agent.env" )"
rigRun "$rigReadOp" keeper-rig
rigAssert "a read writes nothing but the registries it rebuilds: every other file of the workspace is as it was, the scope it read among them" "$rigRc $( rigOthers ) $( rigPrint "$rigWs/.local/.agents/keeper-rig.agent.env" )" "0 $rigOthersRead $rigScopeBefore"

rigRun "$rigReadOp" magic-coordinator
rigAssert "a description written on its own line of the frontmatter is read too; a member with no scope has no setting row; none of its runs is alive, so its sessions come in the order of the session list" "$rigRc $( rigRowOf info description | LC_ALL=C awk '{ print $3 }' ) $( rigRows setting | LC_ALL=C awk 'END { print NR + 0 }' ) $( rigRows session | LC_ALL=C awk '{ printf "%s ", $2 }' )" "0 The_rig's_coordinator,_on_one_line. 0 sess-done sess-live sess-other "
rigRun "$rigReadOp" human-owner
rigAssert "a reference-only member is read like any other, and marked: its row says so, and it is in no session" "$rigRc $( rigRowOf member human-owner | LC_ALL=C awk '{ print $10, $11 }' ) $( rigRows session | LC_ALL=C awk 'END { print NR + 0 }' ) $( rigRowOf info description | LC_ALL=C awk '{ print $3 }' )" "0 reference-only no-process 0 Reference-only_record_of_the_rig's_owner."

echo "-- 6. the read of a member set up only in another workspace --"
rigRun "$rigReadOp" keeper-far
rigWant="$( {
	printf 'member\tkeeper-far\t🛰️\tFar\tKeeper\tfarkeep\tkeeper\tws-far\telsewhere\tactive\trunning\t🔏\t%s\n' "$( rigMemberDir "$rigFar" keeper-far )"
	printf 'info\tdescription\tA_keeper_set_up_in_the_far_workspace.\n'
	printf 'info\tworkspace\t%s\n' "$rigFar"
	printf 'info\thome\t%s\n' "$rigFar"
	printf 'info\tlink-kind\tsource-symlink\n'
	printf 'info\tskillset-path\tmyx/pkg/skillset/keeper-far\n'
	printf 'bullet\tName\tFar_Keeper.\n'
	rigSessionRows sess-live run-f1
	cat "$rigTmp/grants.keeper-far"
	rigSettingRows keeper-far
	printf 'setting\tJIRA_SITE\telsewhere\t-\tws-far\n'
	printf 'setting\tJIRA_API_TOKEN\telsewhere\t-\tws-far\n'
} )"
rigAssert "the call ends 0, with no error and no warning: the operation asks where the member is set up itself, the dispatcher bringing none for this family" "$rigRc $( rigTroubles )" "0 0"
rigAssert "the whole output, byte for byte: its files are read where it is set up, its home is the machine's, its link is its row of that workspace's registry as it lies, and its sessions are this workspace's" "$( rigShown < "$rigTmp/out" )" "$rigWant"
rigAssert "its settings of a system this workspace holds none of are named, each by its key alone, as elsewhere, with the name of the workspace they are read from; a system this workspace holds a key of is read here alone, and a key of no system is never read from there" "$( rigRows setting | LC_ALL=C awk '{ printf "%s:%s:%s@%s ", $2, $3, $4, $5 }' ) $( rigRows setting | LC_ALL=C awk '$2 == "WHERE_KEY" { n++ } END { print n + 0 }' )" "SLACK_USER_TOKEN:secret-set:$( rigMask "$rigSecretFarHere" )@ws-here JIRA_SITE:elsewhere:-@ws-far JIRA_API_TOKEN:elsewhere:-@ws-far  0"
rigAssert "no value of either workspace's scope stands in what the call printed, on either stream" "$( cat "$rigTmp/out" "$rigTmp/err" | LC_ALL=C grep -c -F -e "$rigSecretFarHere" -e "$rigSecretFarThere" -e "$rigSecretFarJira" -e "$rigSecretFarWhere" -e 'jira.rig.invalid' || : )" "0"
rigRun "$rigReadOp" client-rig
rigAssert "a client's read says whose names its row holds: its persona, in one more line of its information" "$rigRc $( rigRowOf info persona | LC_ALL=C awk '{ print $3 }' ) $( rigRowOf info link-kind | LC_ALL=C awk '{ print $3 }' )" "0 magic-coordinator origin-symlink"
rigRun "$rigReadOp" keeper-rig
rigAssert "control: a member that is no client has no such line" "$rigRc $( rigRows info | LC_ALL=C awk '$2 == "persona" { n++ } END { print n + 0 }' )" "0 0"

echo "-- 7. what the read refuses --"
rigRefused(){ ## -- the status, the bytes on stdout and the count of error lines of the last call
	printf '%s %s %s' "$rigRc" "$( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" "$( LC_ALL=C grep -c -e 'ERROR' -e 'ASSERT' "$rigTmp/err" || : )"
}
rigRun "$rigReadOp" keeper-none
rigAssert "the read refuses a name that is no member: one error line, status 1, nothing on stdout" "$( rigRefused ) $( LC_ALL=C grep -c -F -- "⛔ ERROR: DistroAgentsTools $rigReadOp: no team member is named 'keeper-none'" "$rigTmp/err" || : )" "1 0 1 1"
rigRun "$rigReadOp" magic-team.basic.md
rigAssert "a rules file is no member to it either" "$( rigRefused )" "1 0 1"
rigRun "$rigReadOp" keeper-gone
rigAssert "a member whose workspace is not on this machine is refused in one line, which names the folder the machine's index gives for it" "$( rigRefused ) $( LC_ALL=C grep -c -F -- "⛔ ERROR: DistroAgentsTools $rigReadOp: member 'keeper-gone' is set up in no workspace that can be reached from $rigWs: the machine's members index ($rigIndex) names its folder as $( rigMemberDir "$rigTmp/gone/ws-gone" keeper-gone )," "$rigTmp/err" || : )" "1 0 1 1"
rigRun "$rigReadOp" keeper-lost
rigAssert "and so is one whose workspace the machine does not know" "$( rigRefused ) $( LC_ALL=C grep -c -F -- "member 'keeper-lost' is set up in no workspace that can be reached from $rigWs: the machine's members index ($rigIndex) names its folder as $( rigMemberDir "$rigTmp/ws-nolist" keeper-lost )," "$rigTmp/err" || : )" "1 0 1 1"
## A member the index places in a workspace that does not hold its folder: known, and not to be read.
rigMemberRow "$rigIndex" "$rigFar" keeper-hollow source-symlink
rigRun "$rigReadOp" keeper-hollow
rigAssert "and one whose workspace is reached and holds no folder of it in its member set" "$( rigRefused ) $( LC_ALL=C grep -c -F -- "member 'keeper-hollow' is set up in no workspace that can be reached from $rigWs" "$rigTmp/err" || : )" "1 0 1 1"
rigRun "$rigListOp"
rigAssert "the list still names it, as not-present" "$rigRc $( rigRowOf member keeper-hollow | LC_ALL=C awk '{ print $8, $9, $10 }' )" "0 - not-present -"
LC_ALL=C grep -v -e '^keeper-hollow'"$rigTab" "$rigIndex" > "$rigTmp/index.kept" && cat "$rigTmp/index.kept" > "$rigIndex"
rigRun "$rigReadOp" --full
rigAssert "--full with no member is refused as no member is" "$( rigRefused ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigReadOp: syntax is <team-member>, got no team member" )" "1 0 1 1"
rigRun "$rigReadOp"
rigAssert "the read with no member is refused, with its syntax" "$( rigRefused ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigReadOp: syntax is <team-member>, got no team member" )" "1 0 1 1"
rigRun "$rigReadOp" keeper-rig keeper-far
rigAssert "and so is a second word" "$( rigRefused ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigReadOp: syntax is <team-member>, got also: keeper-far" )" "1 0 1 1"
rigRun "$rigReadOp" ../ws-far/keeper-far
rigAssert "a name that is a path is refused before anything is read" "$( rigRefused )" "1 0 1"
rigRun "$rigListOp" keeper-rig
rigAssert "the list takes no argument: refused, with its syntax" "$( rigRefused ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigListOp: syntax takes no argument, got: keeper-rig" )" "1 0 1 1"
rigRun --manager-team-member-no-such
rigAssert "an operation the subject does not have is refused by name" "$rigRc $( rigWhole "$rigTmp/err" "DistroAgentsTools: ⛔ ERROR: invalid option: --manager-team-member-no-such" )" "1 1"
## A registry that cannot be rebuilt: the folder of the registries takes no new file.
rigKept="$( rigPrint "$rigAgents/team-members.registry" )"
chmod a-w "$rigAgents"
rigRun "$rigListOp"
rigAssert "where the registry team-members cannot be rebuilt the list prints nothing and ends 1, in one line: a stale file is never listed as though it were fresh" "$( rigRefused ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigListOp: the registry team-members could not be rebuilt in $rigAgents -- nothing is shown" )" "1 0 1 1"
rigRun "$rigReadOp" keeper-rig
rigAssert "and so does the read" "$( rigRefused ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigReadOp: the registry team-members could not be rebuilt in $rigAgents -- nothing is shown" )" "1 0 1 1"
chmod u+w "$rigAgents"
rigAssert "control: the registry is the file it was, and the list runs again" "$( rigPrint "$rigAgents/team-members.registry" ) $( rigRun "$rigListOp" ; printf '%s' "$rigRc" )" "$rigKept 0"

echo "-- 8. the caller rule of the family --"
rigRegBefore="$( rigPrint "$rigAgents/team-members.registry" ) $( rigPrint "$rigAgents/spawned-sessions.registry" )"
rigCallerBad=""
for rigCaller in "MDAT_SPAWN_AGENT=keeper-rig keeper-rig" "MDAT_SPAWN_AGENT=magic-coordinator magic-coordinator" "MDAT_SPAWN_SESSION_ID=run-k1 keeper-rig" ; do
	rigPre=( "${rigCaller% *}" )
	rigRun "$rigListOp"
	[ "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "DistroAgentsTools: ${rigListOp#--}: ⛔ ERROR: this session acts as ${rigCaller#* }, and a --manager-* operation is the console's own, never run from inside a member's session -- nothing was done" )" = "1 0 1" ] || rigCallerBad="$rigCallerBad [$rigCaller list: rc $rigRc]"
	rigRun "$rigReadOp" keeper-rig
	[ "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "DistroAgentsTools: ${rigReadOp#--}: ⛔ ERROR: this session acts as ${rigCaller#* }, and a --manager-* operation is the console's own, never run from inside a member's session -- nothing was done" )" = "1 0 1" ] || rigCallerBad="$rigCallerBad [$rigCaller read: rc $rigRc]"
done
rigPre=()
rigAssert "from inside a member's session both are refused, rc 1, nothing on stdout, in the one line of the family: a member's by its spawn, magic-coordinator's, and one known by its spawn record alone" "${rigCallerBad:-each refused}" "each refused"
rigAssert "and a refused call rebuilt nothing: the registries are the files they were" "$( rigPrint "$rigAgents/team-members.registry" ) $( rigPrint "$rigAgents/spawned-sessions.registry" )" "$rigRegBefore"

echo "-- 9. the place of the two operations --"
rigInclude="$rigHere/manager/AgentsTools.ManagerTeamMember.include"
rigCode(){ ## file -- its lines that are no comment
	LC_ALL=C grep -v '^[[:space:]]*#' "$1" 2> /dev/null
}
rigAssert "the family's include has one arm for the subject, which sources the subject's own include" "$( LC_ALL=C grep -c -x -e '	--manager-team-member-\*)' "$rigHere/manager/AgentsTools.Manager.include" || : ) $( LC_ALL=C grep -c -F -e '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsTools.ManagerTeamMember.include"' "$rigHere/manager/AgentsTools.Manager.include" || : )" "1 1"
rigAssert "where a member of another workspace is set up is the tooling's own answer for an invited member, asked in one place; its name is the machine's own directory's, read by the list, the read and the files; and the machine's members index is read, a member brought and the resolver called by no code of this include" "$( rigCode "$rigInclude" | LC_ALL=C grep -c -e 'AgentsToolsMemberInvitedWorkspace "' || : ) $( rigCode "$rigInclude" | LC_ALL=C grep -c -e '"\$( AgentsToolsTeamMemberDirectoryText )"' || : ) $( rigCode "$rigInclude" | LC_ALL=C grep -c -e 'members\.registry' -e 'awk -F.*HOME' -e 'AgentsToolsMemberSkillsetBring' -e 'AgentsToolsMemberWorkspaceResolve' || : )" "1 3 0"
rigAssert "the sessions are read through the session list, and the store of the sessions and the process list are read by no code of this include" "$( rigCode "$rigInclude" | LC_ALL=C grep -c -e 'DistroAgentsTools --manager-session-list' || : ) $( rigCode "$rigInclude" | LC_ALL=C grep -c -e 'spawned' -e 'ps -' -e 'RunWords' -e 'MeasureRows' || : )" "1 0"
rigAssert "the grants are read through the permission list and the settings through the digest, whose rule on secrets is the one of the family: no code of this include opens a scope, asks the setting reader or asks the catalogue" "$( rigCode "$rigInclude" | LC_ALL=C grep -c -e 'DistroAgentsTools --magic-permission-list --member' || : ) $( rigCode "$rigInclude" | LC_ALL=C grep -c -e 'DistroAgentsTools --manager-config-digest .*scopes' || : ) $( rigCode "$rigInclude" | LC_ALL=C grep -c -e 'agent\.env' -e 'config-option' -e 'LocalTools' -e 'AgentsToolsOwnerSetupOptionSpec' || : )" "1 1 0"

echo "-- 10. the help pair --"
rigHelpInclude="$rigHere/help/Help.DistroAgentsTools.include"
rigHelpMd="$rigHere/help/Help.DistroAgentsTools.help.md"
rigListSyntax="📘 syntax: DistroAgentsTools.fn.sh $rigListOp"
rigReadSyntax="📘 syntax: DistroAgentsTools.fn.sh $rigReadOp [--full] <team-member>"
rigEntry(){ ## heading -- that operation's entry in the help.md, from under its heading to the next operation's
	LC_ALL=C awk -v head="$( printf '\t\t%s' "$1" )" '$0 == head { on = 1 ; next } on && /^\t\t--/ { exit } on { print }' "$rigHelpMd"
}
rigForm(){ ## heading, row kind -- the form line of that row in that entry, its back quotes and its indent taken off
	rigEntry "$1" | LC_ALL=C sed -n -e 's/^[[:space:]]*`\('"$2"' <.*>\)`$/\1/p'
}
rigAssert "each operation has its syntax echo, its syntax line and its entry, once each" "$( LC_ALL=C grep -c -x -F -- "echo \"$rigListSyntax\" >&2" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -x -F -- "$rigListSyntax" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -x -F -- "$( printf '\t\t%s' "$rigListOp" )" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -x -F -- "echo \"$rigReadSyntax\" >&2" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -x -F -- "$rigReadSyntax" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -x -F -- "$( printf '\t\t%s [--full] <team-member>' "$rigReadOp" )" "$rigHelpMd" || : )" "1 1 1 1 1 1"
rigAssert "and in no other form" "$( LC_ALL=C grep -c -F -- "syntax: DistroAgentsTools.fn.sh --manager-team-member-" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -F -- "syntax: DistroAgentsTools.fn.sh --manager-team-member-" "$rigHelpMd" || : )" "3 3"
rigMemberForm="member <team-member> <mark> <first-name> <family-name> <alias> <kind> <workspace> <set-up> <status> <live> <icon> <folder>"
rigAssert "the entry of the list gives the form of its row" "$( rigForm "$rigListOp" member )" "$rigMemberForm"
rigAssert "the entry of the read gives the form of each of its rows that is its own, and names the two operations whose rows it prints" "$( rigForm "$rigReadOp [--full] <team-member>" info ) | $( rigForm "$rigReadOp [--full] <team-member>" bullet ) | $( rigForm "$rigReadOp [--full] <team-member>" grant ) | $( rigForm "$rigReadOp [--full] <team-member>" setting ) | $( rigEntry "$rigReadOp [--full] <team-member>" | LC_ALL=C grep -c -F -e '`--manager-session-list`' || : ) $( rigEntry "$rigReadOp [--full] <team-member>" | LC_ALL=C grep -c -F -e '`--magic-permission-list`' || : ) $( rigEntry "$rigReadOp [--full] <team-member>" | LC_ALL=C grep -c -F -e '`--manager-team-member-list`' || : )" \
	"info <name> <value> | bullet <name> <text> | grant <kind> <access> <target> <place> <origin> <ends> | setting <key> <state> <value> <workspace> | 1 1 1"
rigFieldsBad(){ ## row kind, form -- how many rows of that kind in the last output have another count of fields than the form names, behind whether there was any
	LC_ALL=C awk -F'\t' -v wantKind="$1" -v wantFields="$( printf '%s\n' "$2" | LC_ALL=C awk '{ print NF }' )" '$1 == wantKind { rows++ ; if ( NF != wantFields ) bad++ ; } END { printf "%s:%s ", ( rows > 0 ? "rows" : "none" ), bad + 0 }' "$rigTmp/out"
}
rigRun "$rigListOp"
rigAssert "every row the list prints has exactly the fields its form names" "$( rigFieldsBad member "$rigMemberForm" )" "rows:0 "
rigRun "$rigReadOp" keeper-rig
rigAssert "and so has every row the read prints: its own, and those of the session list by that operation's forms" "$( rigFieldsBad member "$rigMemberForm" ; for rigKind in info bullet grant setting ; do rigFieldsBad "$rigKind" "$( rigForm "$rigReadOp [--full] <team-member>" "$rigKind" )" ; done ; for rigKind in session run ; do rigFieldsBad "$rigKind" "$( rigForm '--manager-session-list [--active]' "$rigKind" )" ; done ) $( LC_ALL=C awk -F'\t' '$1 != "member" && $1 != "info" && $1 != "bullet" && $1 != "session" && $1 != "run" && $1 != "grant" && $1 != "setting" { other++ } END { print other + 0 }' "$rigTmp/out" )" "rows:0 rows:0 rows:0 rows:0 rows:0 rows:0 rows:0  0"
rigAssert "the entries name the registries read, the three words of where a member is set up, and what a setting reads as" "$( for rigWord in team-members team-members-names here elsewhere not-present reference-only running no-process ; do rigEntry "$rigListOp" | LC_ALL=C grep -c -F -- "\`$rigWord\`" | LC_ALL=C awk '{ printf "%s", ( $1 > 0 ) ? "y" : "n" }' ; done ) $( for rigWord in --manager-config-digest set missing secret-set secret-missing elsewhere ; do rigEntry "$rigReadOp [--full] <team-member>" | LC_ALL=C grep -c -F -- "\`$rigWord\`" | LC_ALL=C awk '{ printf "%s", ( $1 > 0 ) ? "y" : "n" }' ; done )" "yyyyyyyy yyyyyy"
rigAssert "control: each entry was cut up to the next operation's heading" "$( rigEntry "$rigListOp" | LC_ALL=C grep -c -F -- "$rigReadOp [--full] <team-member>" || : ) $( rigEntry "$rigReadOp [--full] <team-member>" | LC_ALL=C grep -c -e '^		--' || : )" "0 0"
rigRun --help-syntax
rigAssert "--help-syntax prints both lines, once each" "$rigRc $( LC_ALL=C grep -c -x -F -- "$rigListSyntax" "$rigTmp/err" || : ) $( LC_ALL=C grep -c -x -F -- "$rigReadSyntax" "$rigTmp/err" || : )" "0 1 1"
rigAssert "no member's help lists the family: the member help names no --manager prefix" "$( LC_ALL=C grep -c -e '--manager' "$rigHere/member/AgentsTools.MemberHelp.include" || : )" "0"

echo "-- 11. no secret was printed, and nothing was posted --"
rigLeaks=0
for rigSecret in $rigSecrets ; do
	[ "$( LC_ALL=C grep -c -F -e "$rigSecret" "$rigTmp/all.printed" || : )" = 0 ] || rigLeaks=$(( rigLeaks + 1 ))
done
rigAssert "control: every secret of the rig stands in a scope file of a workspace a call here read the settings of" "$( for rigSecret in $rigSecrets ; do cat "$rigWs/.local/.agents"/*.agent.env "$rigFar/.local/.agents"/*.agent.env | LC_ALL=C grep -c -F -e "$rigSecret" | LC_ALL=C awk '{ printf "%s", ( $1 > 0 ) ? "y" : "n" }' ; done )" "yyyyyyy"
rigAssert "no secret of the rig stands whole anywhere in what the calls of this check printed, on either stream" "$rigLeaks of $( LC_ALL=C awk 'END { print ( NR > 100 ) ? "many-lines" : "too-few-lines" }' "$rigTmp/all.printed" )" "0 of many-lines"
rigAssert "no run of this check issued a request" "$( [ -e "$rigTmp/curl.calls" ] && wc -l < "$rigTmp/curl.calls" | LC_ALL=C tr -d ' ' || echo 0 )" "0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MANAGER TEAM MEMBER CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_TEAM_MEMBER: OK (%d assertions, offline)\n' "$rigPasses"
