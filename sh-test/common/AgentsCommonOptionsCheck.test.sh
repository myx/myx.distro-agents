#!/usr/bin/env bash
## Behavioural check on the common option set of the commands (F2.2 of the refactorings epic): --team-member, --session-id, --spawn-id, --select-workspace and
## --tooling-origin, and the operation that shows what they resolve, --intern-context-show, run rather than read, in a rig: two workspaces the machine knows, one it
## does not, a home with the registries, and the real tooling (AgentsTools.CommonOptions.include and the entry of each tool). Every option and every default is
## tested through --intern-context-show. Held:
##   1. THE DEFAULTS at the console: team-member user-<account> (USER), session-id empty, spawn-id `shell-console`, the workspace and the origin as the call runs; the
##      five lines first, then every MDAT_* and MDLT_* variable by name, `<name>: <value>`.
##   2. IMPLIED from the environment, with a JOINED session first: the spawn id is the child's (MDAT_SPAWN_SESSION_ID) and the session id the native one (MDAT_SESSION_ID),
##      two facts; team-member from MDAT_SPAWN_AGENT.
##   3. THE OPTIONS override them at the console; a value is needed, once each, a run directly after the operation; a stray argument is refused.
##   4. NO ACCOUNT: nothing is given and the call is refused, never `user-` or `user-unknown`. The console may not become a member by --team-member (F6.10: it
##      answers as user-<account>): for an operation without a member positional only its own default is accepted; member-first operations keep the positional's meaning.
##   5. SECRETS are printed in the one form of a credential (F11.8), never whole; a value of several lines is one line.
##   6. THE MEMBER POSITIONAL: an operation that takes a member first gets the resolved one there (named, or implied), the old positional still works, two members
##      named are refused, and a member session naming another member is refused exactly as it is without the option; for an operation without a member positional the same.
##   7. A MEMBER SESSION restates its own ids and no other; a workspace only the one it is in or the one it is set up in; an origin only of a workspace the machine
##      knows (a tree it controls would bypass every gate). The console is unrestricted.
##   9. REQUIRED WHERE THE CONTEXT DOES NOT HOLD IT: an operation whose syntax writes a common option unbracketed needs its value from the option or its variable;
##      with neither the call is refused naming the option ("needs --session-id: no MDAT_SESSION_ID in this context"), never run with an empty value.
##   8. EVERY TOOL takes the options (the entry of each of the eight), and a call under --select-workspace reads that workspace.
## Offline, rig tree only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsCommonOptionsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
## The effective account of these rigs is the USER they give: a stand-in `id` first on PATH says it (none where USER is empty), as the person at the console is the effective account
## (AgentsToolsConsoleAccount, sh-lib/member/AgentsTools.CallerCheck.include).
mkdir -p "$rigTmp/idbin" && printf '#!/bin/sh\n[ "$*" = "-un" ] || exec /usr/bin/id "$@"\n[ -n "${USER:-}" ] || exit 1\necho "$USER"\n' > "$rigTmp/idbin/id" && chmod +x "$rigTmp/idbin/id"
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigWs="$rigTmp/ws-a" rigWs2="$rigTmp/ws-b" rigWs3="$rigTmp/ws-c" rigHome="$rigTmp/home" rigData="$rigTmp/data" rigSkills="$rigTmp/skills" rigEvil="$rigTmp/evil"
mkdir -p "$rigWs/.local/temp" "$rigWs/.local/agents" "$rigWs2/.local/temp" "$rigWs2/.local/agents/spawned/sess-b" "$rigWs3/.local/temp" "$rigHome/.agents/magic-team" "$rigData" "$rigSkills/magic-rig" "$rigSkills/magic-team" "$rigEvil" "$rigWs2/source"
printf '# rig armed\n' > "$rigSkills/magic-rig/magic-rig.armed.md"
ln -s "$MDLT_ORIGIN/myx" "$rigEvil/myx" ; ln -s "$MDLT_ORIGIN/myx" "$rigWs2/source/myx"
printf -- '---\nsession-id: sess-b\nspawn-id: run-b\nstart-context: spawned\nworkspace: ws-b\nowner: magic-rig\nstatus: spawn-started\nstarted-at: 2026-10-20 10:00 +0300\n---\n\n# Spawn session: run-b\n' > "$rigWs2/.local/agents/spawned/sess-b/run-b.spawn.md"
## The machine: ws-a (here) and ws-b are workspaces it knows (a place of ws-a's registry names ws-b); ws-c it does not. magic-rig is set up here, keeper-other only in ws-b.
printf 'ws-b-place\tworkspace\tread-write\t%s\tworkspace\n' "$rigWs2" > "$rigWs/.local/agents/directories.registry"
printf 'magic-rig\t%s\tsource-link\tmyx/pkg/skillset/magic-rig\t%s\nkeeper-other\t%s\tsource-link\tmyx/pkg/skillset/keeper-other\t%s\n' "$rigWs" "$rigTmp/x1" "$rigWs2" "$rigTmp/x2" > "$rigHome/.agents/magic-team/members.registry"
rigRc=0
rigRun(){ ## result prefix, VAR=value..., --, words... -- one call of the tool; rc in rigRc
	local runOut="$1" runEnv=() ; shift
	while [ "$1" != -- ] ; do runEnv+=( "$1" ) ; shift ; done ; shift
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" USER=rigacct PATH="$rigTmp/idbin:$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" ${runEnv[@]+"${runEnv[@]}"} \
		bash -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; exec bash "$@"' rig "$rigTool" "$@" ) > "$runOut.out" 2> "$runOut.err" < /dev/null
	rigRc=$?
}
rigLine(){ ## name, file -- the value of the line `name: value`, as printed ("<none>" where there is no such line)
	LC_ALL=C awk -v want="$1: " 'index( $0, want ) == 1 { print substr( $0, length( want ) + 1 ) ; found = 1 ; exit } index( $0, substr( want, 1, length( want ) - 1 ) ) == 1 && length( $0 ) == length( want ) - 1 { print "" ; found = 1 ; exit } END { if ( ! found ) print "<none>" }' "$2"
}
rigHas(){ ## fixed text, file -- how many lines of the file hold it
	LC_ALL=C grep -c -F -- "$1" "$2" || :
}
rigSame(){ ## file, file -- `same`, or the first of what differs
	if cmp -s "$1" "$2" ; then printf same ; else printf 'DIFF:' ; diff "$1" "$2" | head -c 160 | LC_ALL=C tr '\n' '~' ; fi
}
rigBegin=$( date +%s )

echo "-- 1. the defaults at the console --"
rigRun "$rigTmp/a1" -- --intern-context-show
rigAssert "the five lines first: user-<account>, no session, shell-console, the workspace, the origin" "$rigRc $( head -n 5 "$rigTmp/a1.out" | LC_ALL=C tr '\n' '|' )" "0 team-member: user-rigacct|session-id: |spawn-id: shell-console|select-workspace: $rigWs|tooling-origin: $MDLT_ORIGIN|"
rigAssert "then the MDAT_* and MDLT_* variables, each as name: value, by name" "$( tail -n +6 "$rigTmp/a1.out" | LC_ALL=C grep -c -v -E '^(MDAT|MDLT)_[A-Z0-9_]*: ' || : ) $( tail -n +6 "$rigTmp/a1.out" | LC_ALL=C cut -d: -f1 | LC_ALL=C sort -c 2>&1 | wc -l | tr -d ' ' ) $( rigLine MDAT_DATA_ROOT "$rigTmp/a1.out" ) $( rigLine MDLT_ORIGIN "$rigTmp/a1.out" )" "0 0 $rigData $MDLT_ORIGIN"

echo "-- 2. implied from the environment: a joined session --"
rigRun "$rigTmp/b1" MDAT_SPAWN_AGENT=magic-rig MDAT_SESSION_ID=native-1 MDAT_SPAWN_SESSION_ID=child-9 -- --intern-context-show
rigAssert "the spawn id is the child's and the session id the native one, two facts; the member is the session's" "$rigRc $( rigLine team-member "$rigTmp/b1.out" ) $( rigLine session-id "$rigTmp/b1.out" ) $( rigLine spawn-id "$rigTmp/b1.out" )" "0 magic-rig native-1 child-9"

echo "-- 3. the options override them at the console --"
rigRun "$rigTmp/c1" -- --intern-context-show --team-member user-rigacct --session-id s-7 --spawn-id c-8
rigAssert "team-member, session-id and spawn-id" "$rigRc $( rigLine team-member "$rigTmp/c1.out" ) $( rigLine session-id "$rigTmp/c1.out" ) $( rigLine spawn-id "$rigTmp/c1.out" )" "0 user-rigacct s-7 c-8"
rigRun "$rigTmp/c2" -- --intern-context-show --select-workspace "$rigWs2"
rigRun "$rigTmp/c3" -- --intern-context-show --select-workspace ws-b-place
rigAssert "a workspace by absolute path and by place name, the call made there" "$( rigLine select-workspace "$rigTmp/c2.out" ) $( rigLine select-workspace "$rigTmp/c3.out" ) $( rigLine MMDAPP "$rigTmp/c2.out" )" "$rigWs2 $rigWs2 <none>"
rigRun "$rigTmp/c4" -- --intern-context-show --select-workspace "$rigWs2" --tooling-origin source
rigRun "$rigTmp/c5" -- --intern-context-show --tooling-origin "$rigEvil"
rigAssert "an origin by spec (source of the workspace selected) and by absolute path, the call made from it" "$( rigLine tooling-origin "$rigTmp/c4.out" ) $( rigLine select-workspace "$rigTmp/c4.out" ) $( rigLine tooling-origin "$rigTmp/c5.out" ) $( rigLine MDLT_ORIGIN "$rigTmp/c5.out" )" "$rigWs2/source $rigWs2 $rigEvil $rigEvil"
rigRun "$rigTmp/c6" -- --intern-context-show --team-member user-rigacct
rigAssert "an option alone leaves the others implied" "$( rigLine team-member "$rigTmp/c6.out" ) $( rigLine session-id "$rigTmp/c6.out" ) $( rigLine spawn-id "$rigTmp/c6.out" ) $( rigLine select-workspace "$rigTmp/c6.out" )" "user-rigacct  shell-console $rigWs"
rigRun "$rigTmp/c7" MDAT_SPAWN_SESSION_ID=child-9 -- --intern-context-show --spawn-id shell-console
rigAssert "--spawn-id shell-console is the shell CLI: no spawned session" "$( rigLine spawn-id "$rigTmp/c7.out" ) $( rigLine MDAT_SPAWN_SESSION_ID "$rigTmp/c7.out" )" "shell-console <none>"

echo "-- 4. refused: a value, once, a run after the operation, a stray argument --"
rigRun "$rigTmp/d1" -- --intern-context-show --session-id
rigRun "$rigTmp/d2" -- --intern-context-show --team-member user-rigacct --team-member user-rigacct
rigRun "$rigTmp/d3" -- --intern-context-show --session-id 'bad id'
rigRun "$rigTmp/d4" -- --intern-context-show stray
rigRun "$rigTmp/d5" -- --intern-context-show --select-workspace "$rigTmp/nowhere"
rigRun "$rigTmp/d6" -- --intern-context-show --select-workspace not-a-place
rigRun "$rigTmp/d7" -- --intern-context-show --tooling-origin "$rigTmp/home"
rigRun "$rigTmp/d8" -- --intern-context-show --tooling-origin somewhere
rigRun "$rigTmp/d9" -- --intern-context-show --team-member 'bad/name'
rigAssert "a missing value, a repeated option, a bad id, a stray argument, a missing and an unknown workspace, an origin without the tooling and one that is no spec, a bad member: each refused, rc 1, nothing printed" "$( for rigN in d1 d2 d3 d4 d5 d6 d7 d8 d9 ; do printf '%s' "$( [ ! -s "$rigTmp/$rigN.out" ] && [ -s "$rigTmp/$rigN.err" ] && printf y || printf n )" ; done ) $( rigHas 'takes a value' "$rigTmp/d1.err" ) $( rigHas 'is given twice' "$rigTmp/d2.err" ) $( rigHas 'takes only the common options' "$rigTmp/d4.err" ) $( rigHas 'is no place this machine knows' "$rigTmp/d6.err" ) $( rigHas 'holds no myx.distro-agents tooling' "$rigTmp/d7.err" )" "yyyyyyyyy 1 1 1 1 1"
rigRun "$rigTmp/d11" -- --intern-context-show --tooling-origin .local
rigRun "$rigTmp/d12" -- --member-help ''
rigAssert "the spec .local of a workspace that holds no tooling is refused; an empty first argument is a positional somebody gave and is not replaced by the implied member" "$( rigHas 'holds no myx.distro-agents tooling' "$rigTmp/d11.err" ) $( rigHas 'syntax is <team-member>' "$rigTmp/d12.err" )" "1 1"
rigRun "$rigTmp/d10" -- --intern-context-show --team-member user-rigacct --session-id s-1 stray --spawn-id late
rigAssert "an option after the operation's own argument is not an option: the stray argument is what is refused" "$( rigHas 'takes only the common options, got: stray' "$rigTmp/d10.err" )" "1"

echo "-- 5. no account --"
rigRun "$rigTmp/e1" USER= -- --intern-context-show
rigRcE1=$rigRc
rigRun "$rigTmp/e2" USER= -- --member-help
rigRun "$rigTmp/e3" USER= -- --member-help --team-member magic-rig
rigRun "$rigTmp/e4" USER= -- --intern-context-show --team-member keeper-x
rigRun "$rigTmp/e5" -- --intern-context-show --team-member magic-coordinator
rigRun "$rigTmp/e6" -- --member-inbox-note-upsert --team-member magic-coordinator note-x.md
rigAssert "no account, no member's session: the call is refused, no user- is given" "$rigRcE1 $( [ ! -s "$rigTmp/e1.out" ] && printf none ) $( rigHas 'needs --team-member: no MDAT_SPAWN_AGENT in this context and no account (USER)' "$rigTmp/e1.err" ) $( rigHas 'user-' "$rigTmp/e1.out" )" "1 none 1 0"
rigAssert "the same for an operation that takes a member first" "$( [ ! -s "$rigTmp/e2.out" ] && printf none ) $( rigHas 'needs --team-member: no MDAT_SPAWN_AGENT in this context and no account (USER)' "$rigTmp/e2.err" )" "none 1"
rigAssert "an operation that takes a member first keeps today's positional meaning with the option, account or none" "$( rigHas '# Duty instructions' "$rigTmp/e3.err" )" "1"
rigAssert "the console may not become a member by --team-member (F6.10): with no account, or with one, naming another is refused with the line, and nothing is printed" "$( [ ! -s "$rigTmp/e4.out" ] && printf none ) $( rigHas 'this is the console, which answers as user-<account> and never as another member, and --team-member names keeper-x' "$rigTmp/e4.err" ) $( [ ! -s "$rigTmp/e5.out" ] && printf none ) $( rigHas 'which answers as user-rigacct and never as another member, and --team-member names magic-coordinator' "$rigTmp/e5.err" )" "none 1 none 1"
rigAssert "a member-first operation from the console naming magic-coordinator is no wider than the positional: the op's own check, not this line" "$( rigHas 'which answers as' "$rigTmp/e6.err" )" "0"

echo "-- 6. secrets --"
rigRun "$rigTmp/f1" MDAT_RIG_API_TOKEN=abcdefghijklmnop MDAT_RIG_PASSWORD=pw MDAT_RIG_SECRET_KEY=0123456789abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOP0123456789abcdefghijklmnopqrstuvwxyz MDLT_RIG_CREDENTIAL=abcdefgh MDAT_RIG_PLAIN=visible "MDAT_RIG_MULTI=a
b" -- --intern-context-show
rigAssert "a token: its first quarter (not under 4) and a * for the rest; a password under 4: all *; a long key: 20 characters at most" "$( rigLine MDAT_RIG_API_TOKEN "$rigTmp/f1.out" ) $( rigLine MDAT_RIG_PASSWORD "$rigTmp/f1.out" ) $( rigLine MDAT_RIG_SECRET_KEY "$rigTmp/f1.out" | LC_ALL=C cut -c1-24 ) $( rigLine MDLT_RIG_CREDENTIAL "$rigTmp/f1.out" )" "abcd************ ** 0123456789abcdefghij**** abcd****"
rigAssert "no secret is whole anywhere in the output; a plain value is; several lines are one" "$( rigHas abcdefghijklmnop "$rigTmp/f1.out" ) $( rigHas '0123456789abcdefghijklmnopqrstuvwxyz' "$rigTmp/f1.out" ) $( rigLine MDAT_RIG_PLAIN "$rigTmp/f1.out" ) $( rigLine MDAT_RIG_MULTI "$rigTmp/f1.out" )" '0 0 visible a\nb'

echo "-- 7. the member positional --"
rigRun "$rigTmp/g1" -- --member-help magic-rig
rigRun "$rigTmp/g2" -- --member-help --team-member magic-rig
rigRun "$rigTmp/g3" MDAT_SPAWN_AGENT=magic-rig -- --member-help
rigAssert "the old positional, the option and the implied member give the same help (it is written on stderr)" "$( rigSame "$rigTmp/g1.err" "$rigTmp/g2.err" ) $( rigSame "$rigTmp/g1.err" "$rigTmp/g3.err" ) $( rigHas '# Duty instructions' "$rigTmp/g1.err" )" "same same 1"
rigRun "$rigTmp/g5" -- --member-help --team-member keeper-third magic-rig
rigAssert "the option fills the place of the positional: a second member after it is the operation's own argument, which this one refuses" "$( [ ! -s "$rigTmp/g5.out" ] && printf none ) $( rigHas 'takes exactly one argument' "$rigTmp/g5.err" )" "none 1"
rigRun "$rigTmp/g6" -- --member-help
rigAssert "at the console the implied member is user-<account>, the operation then says that member is none" "$( rigHas 'user-rigacct' "$rigTmp/g6.err" )" "1"
rigRun "$rigTmp/h1" MDAT_SPAWN_AGENT=magic-rig -- --member-inbox-note-upsert keeper-third note-x.md
rigRun "$rigTmp/h2" MDAT_SPAWN_AGENT=magic-rig -- --member-inbox-note-upsert --team-member keeper-third note-x.md
rigAssert "a member session naming another member is refused as it is by position: the same line" "$( rigHas 'this session acts as magic-rig, so it cannot act as keeper-third' "$rigTmp/h1.err" ) $( rigHas 'this session acts as magic-rig, so it cannot act as keeper-third' "$rigTmp/h2.err" ) $( rigSame "$rigTmp/h1.err" "$rigTmp/h2.err" )" "1 1 same"
rigRun "$rigTmp/h3" MDAT_SPAWN_AGENT=magic-rig -- --intern-context-show --team-member keeper-third
rigRun "$rigTmp/h4" MDAT_SPAWN_AGENT=magic-rig -- --intern-context-show --team-member magic-rig
rigAssert "an operation without a member positional: another member is refused, itself is restated" "$( rigHas 'this session acts as magic-rig, so it cannot act as keeper-third' "$rigTmp/h3.err" ) $( [ ! -s "$rigTmp/h3.out" ] && printf none ) $( rigLine team-member "$rigTmp/h4.out" )" "1 none magic-rig"

echo "-- 8. a member session: ids, workspace, origin --"
rigRun "$rigTmp/i1" MDAT_SPAWN_AGENT=magic-rig MDAT_SESSION_ID=native-1 MDAT_SPAWN_SESSION_ID=child-9 -- --intern-context-show --session-id native-2
rigRun "$rigTmp/i2" MDAT_SPAWN_AGENT=magic-rig MDAT_SESSION_ID=native-1 MDAT_SPAWN_SESSION_ID=child-9 -- --intern-context-show --spawn-id child-8
rigRun "$rigTmp/i3" MDAT_SPAWN_AGENT=magic-rig MDAT_SESSION_ID=native-1 MDAT_SPAWN_SESSION_ID=child-9 -- --intern-context-show --session-id native-1 --spawn-id child-9
rigAssert "another session's id or spawn id is refused; its own is restated" "$( rigHas 'not its own (native-1)' "$rigTmp/i1.err" ) $( rigHas 'not its own (child-9)' "$rigTmp/i2.err" ) $( rigLine session-id "$rigTmp/i3.out" ) $( rigLine spawn-id "$rigTmp/i3.out" )" "1 1 native-1 child-9"
rigRun "$rigTmp/j1" MDAT_SPAWN_AGENT=magic-rig -- --intern-context-show --select-workspace "$rigWs3"
rigRun "$rigTmp/j2" MDAT_SPAWN_AGENT=magic-rig -- --intern-context-show --select-workspace "$rigWs2"
rigRun "$rigTmp/j3" MDAT_SPAWN_AGENT=magic-rig -- --intern-context-show --select-workspace "$rigWs"
rigRun "$rigTmp/j4" MDAT_SPAWN_AGENT=keeper-other -- --intern-context-show --select-workspace "$rigWs2"
rigAssert "a workspace the machine does not know: refused" "$( rigHas 'which this machine does not know as a workspace' "$rigTmp/j1.err" ) $( [ ! -s "$rigTmp/j1.out" ] && printf none )" "1 none"
rigAssert "a known workspace the member is not set up in: refused; the one it is in: accepted" "$( rigHas 'which is not the workspace it is in nor the one it is set up in' "$rigTmp/j2.err" ) $( [ ! -s "$rigTmp/j2.out" ] && printf none ) $( rigLine select-workspace "$rigTmp/j3.out" )" "1 none $rigWs"
rigAssert "the workspace the member-workspace resolution gives a member set up elsewhere: accepted" "$rigRc $( rigLine select-workspace "$rigTmp/j4.out" )" "0 $rigWs2"
rigRun "$rigTmp/k1" MDAT_SPAWN_AGENT=magic-rig -- --intern-context-show --tooling-origin "$rigEvil"
rigRun "$rigTmp/k2" MDAT_SPAWN_AGENT=magic-rig -- --intern-context-show --tooling-origin "$rigWs2/source"
rigRun "$rigTmp/k3" MDAT_SPAWN_AGENT=magic-rig -- --intern-context-show --tooling-origin "$MDLT_ORIGIN"
rigRun "$rigTmp/k4" MDAT_SPAWN_AGENT=magic-rig -- --intern-context-show --tooling-origin "$rigWs3/source"
mkdir -p "$rigWs3/source" ; ln -s "$MDLT_ORIGIN/myx" "$rigWs3/source/myx"
rigRun "$rigTmp/k5" MDAT_SPAWN_AGENT=magic-rig -- --intern-context-show --tooling-origin "$rigWs3/source"
rigAssert "an arbitrary path (a tree with the tooling the member controls) is refused, and so is the source of a workspace the machine does not know" "$( rigHas 'not the origin of a workspace this machine knows' "$rigTmp/k1.err" ) $( [ ! -s "$rigTmp/k1.out" ] && printf none ) $( rigHas 'not the origin of a workspace this machine knows' "$rigTmp/k5.err" ) $( [ ! -s "$rigTmp/k5.out" ] && printf none )" "1 none 1 none"
rigAssert "the origin of a known workspace is accepted, and so is the one the session runs from" "$( rigLine tooling-origin "$rigTmp/k2.out" ) $( rigLine tooling-origin "$rigTmp/k3.out" )" "$rigWs2/source $MDLT_ORIGIN"

echo "-- 9. every tool takes the options --"
for rigT in DistroAgentsTools DistroAgentsDispatcher DistroAgentsSession DistroAgentsContacts DistroAgentsTesting AgentLibrarianTools AgentTestingTools AgentDispatcherTools ; do
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" USER=rigacct PATH="$rigTmp/idbin:$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash "$rigPackage/sh-scripts/$rigT.fn.sh" --no-such-operation --session-id s-1 ) > "$rigTmp/t-$rigT.out" 2> "$rigTmp/t-$rigT.err" < /dev/null
	printf '%s ' "$rigT:$( rigHas '--session-id' "$rigTmp/t-$rigT.err" ):$( rigHas 'no-such-operation' "$rigTmp/t-$rigT.err" )" >> "$rigTmp/t-all"
done
rigAssert "each of the eight consumes the options and then meets the operation: its error names the operation (1) and never the option (0)" "$( cat "$rigTmp/t-all" )" "DistroAgentsTools:0:1 DistroAgentsDispatcher:0:1 DistroAgentsSession:0:1 DistroAgentsContacts:0:1 DistroAgentsTesting:0:1 AgentLibrarianTools:0:1 AgentTestingTools:0:1 AgentDispatcherTools:0:1 "
( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" USER=rigacct PATH="$rigTmp/idbin:$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" \
	bash "$rigPackage/sh-scripts/DistroAgentsDispatcher.fn.sh" --all-sessions --select-workspace "$rigWs2" ) > "$rigTmp/n1.out" 2> "$rigTmp/n1.err" < /dev/null
( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" USER=rigacct PATH="$rigTmp/idbin:$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" \
	bash "$rigPackage/sh-scripts/DistroAgentsDispatcher.fn.sh" --all-sessions ) > "$rigTmp/n2.out" 2> "$rigTmp/n2.err" < /dev/null
rigAssert "a call under --select-workspace reads that workspace (its run), the call without reads this one (none)" "$( rigHas 'run-b' "$rigTmp/n1.out" ) $( rigHas 'run-b' "$rigTmp/n2.out" )" "1 0"

echo "-- 10. required where the context does not hold it --"
## A rig origin whose manual holds one more operation, written with --session-id unbracketed (so it needs the value); everything else is the real package, linked.
rigOrg="$rigTmp/origin-needs" rigPkg="$rigOrg/myx/myx.distro-agents"
mkdir -p "$rigPkg/sh-lib/help"
for rigE in "$MDLT_ORIGIN"/myx/* ; do [ "${rigE##*/}" = myx.distro-agents ] || ln -s "$rigE" "$rigOrg/myx/${rigE##*/}" ; done
for rigE in "$rigPackage"/* "$rigPackage"/.[a-zA-Z]* ; do [ -e "$rigE" ] || continue ; [ "${rigE##*/}" = sh-lib ] || ln -s "$rigE" "$rigPkg/${rigE##*/}" ; done
for rigE in "$rigPackage"/sh-lib/* ; do [ "${rigE##*/}" = help ] || ln -s "$rigE" "$rigPkg/sh-lib/${rigE##*/}" ; done
for rigE in "$rigPackage"/sh-lib/help/* ; do [ "${rigE##*/}" = Help.DistroAgentsTools.help.md ] || ln -s "$rigE" "$rigPkg/sh-lib/help/${rigE##*/}" ; done
cp "$rigPackage/sh-lib/help/Help.DistroAgentsTools.help.md" "$rigPkg/sh-lib/help/Help.DistroAgentsTools.help.md"
printf '📘 syntax: DistroAgentsTools.fn.sh --member-rig-needs-session --session-id <session-id> <thing>\n' >> "$rigPkg/sh-lib/help/Help.DistroAgentsTools.help.md"
rigRunNeeds(){ ## result prefix, VAR=value..., --, words...
	local runOut="$1" runEnv=() ; shift
	while [ "$1" != -- ] ; do runEnv+=( "$1" ) ; shift ; done ; shift
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" USER=rigacct PATH="$rigTmp/idbin:$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrg" MDLT_OPTION="--run-from-path $rigOrg" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" ${runEnv[@]+"${runEnv[@]}"} \
		bash -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; exec bash "$@"' rig "$rigPkg/sh-scripts/DistroAgentsTools.fn.sh" "$@" ) > "$runOut.out" 2> "$runOut.err" < /dev/null
	rigRc=$?
}
rigRunNeeds "$rigTmp/p1" -- --member-rig-needs-session
rigRunNeeds "$rigTmp/p2" MDAT_SESSION_ID=native-1 -- --member-rig-needs-session
rigRunNeeds "$rigTmp/p3" -- --member-rig-needs-session --session-id native-2
rigRunNeeds "$rigTmp/p4" -- --member-rig-needs-session --session-id
rigAssert "neither the variable nor the option: refused naming the option, and the operation does not run" "$( rigHas 'needs --session-id: no MDAT_SESSION_ID in this context' "$rigTmp/p1.err" ) $( rigHas 'invalid option: --member-rig-needs-session' "$rigTmp/p1.err" ) $( [ ! -s "$rigTmp/p1.out" ] && printf none )" "1 0 none"
rigAssert "the variable alone, and the option alone, are enough: the call goes on to the dispatcher" "$( rigHas 'needs --session-id' "$rigTmp/p2.err" ) $( rigHas 'invalid option: --member-rig-needs-session' "$rigTmp/p2.err" ) $( rigHas 'needs --session-id' "$rigTmp/p3.err" ) $( rigHas 'invalid option: --member-rig-needs-session' "$rigTmp/p3.err" )" "0 1 0 1"
rigAssert "an option without a value is no value" "$( rigHas 'takes a value' "$rigTmp/p4.err" ) $( rigHas 'invalid option: --member-rig-needs-session' "$rigTmp/p4.err" )" "1 0"
rigAssert "control: the same operation under the real manual does not need it, and the implied context-show runs with no session at all" "$( rigLine session-id "$rigTmp/a1.out" | LC_ALL=C awk '{ print ( $0 == "" ? "empty" : $0 ) }' ) $( rigHas 'needs --session-id' "$rigTmp/a1.err" )" "empty 0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ COMMON OPTIONS CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'COMMON_OPTIONS: OK (%d assertions, offline, rig tree only, %d seconds)\n' "$rigPasses" "$(( $( date +%s ) - rigBegin ))"
