#!/usr/bin/env bash
## Behavioural check on the Jira mirror of the team board: the one board write every move lands through
## reflects the item's own state on its Jira issue, in the same step.
## Held, run and read:
##   1. With the board half of REFLECT_MODELS off, a move reaches the site not at all.
##   2. An item the site holds no issue for gets one, carrying its identity label, its type label and
##      its state label, and the board write stands.
##   3. An item the site already holds has its status moved and its state label replaced, and every
##      label a person put on the issue survives the write.
##   4. A same-state edit is no move, so it reaches the site not at all.
##   5. A Jira write that cannot be made never fails the board move that already landed, and says so.
## Offline: a fake `curl` first on PATH answers every call and records it, so no socket opens and no
## real site is reached. Temp stores only, in a temp workspace.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigReflectInc="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/atlassian/AgentsTools.BoardJiraReflect.include"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
[ -f "$rigReflectInc" ] || rigRefuse "the mirror step is not there, so this check would measure nothing: $rigReflectInc"

. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsBoardJiraReflectCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT

rigPass=0 rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

rigBin="$rigTmp/bin" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills"
rigLog="$rigTmp/call.log" ; rigBodies="$rigTmp/bodies" ; rigSite="$rigTmp/site"
mkdir -p "$rigBin" "$rigHome/.agents/magic-team" "$rigBodies" "$rigSite"
for rigMember in magic-coordinator magic-developer ; do
	mkdir -p "$rigSkills/$rigMember"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
done

## The fake site: one answer a call, from a file the case puts there, and every call recorded.
cat > "$rigBin/curl" <<'RIGCURL'
#!/usr/bin/env bash
set -u
rigMethod="GET" rigUrl="" rigBodyIn=""
while [ $# -gt 0 ] ; do
	case "$1" in
		-X) rigMethod="${2:-GET}" ; shift ; shift ;;
		--data-binary) rigBodyIn="${2#@}" ; shift ; shift ;;
		https://*) rigUrl="$1" ; shift ;;
		*) shift ;;
	esac
done
rigSeen="${rigUrl#https://}"
rigSeen="/${rigSeen#*/}"
rigSeen="${rigSeen%%\?*}"
printf '%s %s\n' "$rigMethod" "$rigSeen" >> "$RIG_LOG"
if [ -n "$rigBodyIn" ] && [ -f "$rigBodyIn" ] ; then
	cp -- "$rigBodyIn" "$RIG_BODIES/$( LC_ALL=C awk 'END { print NR ; }' "$RIG_LOG" )"
fi
## The site refuses a field on a transition, as the real one does: its screen carries none.
if [ "$rigMethod" = POST ] && [ -n "$rigBodyIn" ] && [ -f "$rigBodyIn" ] && [ "${rigSeen%/transitions}" != "$rigSeen" ] && LC_ALL=C grep -q '"labels"' "$rigBodyIn" ; then
	printf '{"errorMessages":[],"errors":{"labels":"Field labels cannot be set. It is not on the appropriate screen, or unknown."}}\n400'
	exit 0
fi
rigAnswer="$RIG_SITE/$( printf '%s %s' "$rigMethod" "$rigSeen" | LC_ALL=C awk '{ gsub(/[^A-Za-z0-9]/, "_") ; print ; }' )"
if [ -f "$rigAnswer" ] ; then cat -- "$rigAnswer" ; else printf '{"ok":false}\n404' ; fi
exit 0
RIGCURL
chmod +x "$rigBin/curl"
PATH="$rigBin:$PATH"
[ "$( command -v curl )" = "$rigBin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check could reach a real site"
export PATH

rigAnswer(){ ## method, path, body, [status]
	printf '%s\n%s\n' "$3" "${4:-200}" > "$rigSite/$( printf '%s %s' "$1" "$2" | LC_ALL=C awk '{ gsub(/[^A-Za-z0-9]/, "_") ; print ; }' )"
}
rigSiteReset(){
	: > "$rigLog"
	rm -f "$rigBodies"/*
	## No issue carries this item's identity label, unless a case says so.
	rigAnswer GET /rest/api/3/search/jql '{"startAt":0,"maxResults":1,"total":0,"isLast":true,"issues":[]}'
	rigAnswer GET /rest/api/3/myself '{"accountId":"rig-account"}'
	rigAnswer POST /rest/api/3/issue '{"id":"900","key":"RIGP-900"}'
	rigAnswer GET /rest/api/3/issue/RIGP-900/transitions '{"transitions":[{"id":"31","name":"To Do","to":{"name":"Backlog"}}]}'
	rigAnswer GET /rest/api/3/issue/RIGP-900 '{"key":"RIGP-900","fields":{"status":{"name":"Backlog"},"labels":["magic-item-rig-item","magic-state-blocked","magic-type-task","security"]}}'
	rigAnswer POST /rest/api/3/issue/RIGP-900/transitions '' 204
	rigAnswer PUT /rest/api/3/issue/RIGP-900 '' 204
}
rigCalls(){ ## -- the calls the site saw, on one line
	if [ ! -s "$rigLog" ] ; then printf 'none' ; return 0 ; fi
	LC_ALL=C awk '{ printf "%s%s", (n++ ? " | " : ""), $0 ; }' "$rigLog"
}
rigCallsReset(){ : > "$rigLog" ; rm -f "$rigBodies"/* ; }

rigScenario(){ ## name
	rigDir="$rigTmp/$1" ; rigStore="$rigDir/store"
	mkdir -p "$rigDir/ws/.local/.agents" "$rigDir/ws/.local/temp"
	rigSiteReset
}
rigOp(){ ## result file, then the operation and its arguments; stdin is the caller's
	local rigResult="$1" ; shift
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigDir/ws" MDAT_DATA_ROOT="$rigStore" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_AGENT=magic-coordinator \
		JIRA_SITE=rig.invalid JIRA_USER=us@rig.invalid JIRA_API_TOKEN=rig-token \
		REFLECT_MODELS="$rigModels" REFLECT_JIRA_PROJECT=RIGP \
		RIG_LOG="$rigLog" RIG_BODIES="$rigBodies" RIG_SITE="$rigSite" RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MDAT_DATA_ROOT outside the rig tree" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$rigResult" 2> "$rigResult.err"
	printf '%s' "$?" > "$rigResult.rc"
}
rigSeed(){ ## state -- one item already on the board, in that state
	mkdir -p "$rigStore/board/$1"
	printf -- '---\ntype: task\n---\nrig body\n' > "$rigStore/board/$1/$rigItem"
}
rigItem="task-20261014T0201Z-Rig-Mirror.md"

echo "-- 1. with the board half off, a move reaches the site not at all --"
rigScenario off
rigModels="none"
rigSeed parked
rigOp "$rigDir/a" --intern-op-board-upsert-move-edit running "$rigItem" --from-state:parked --context rig
rigAssert "the board move lands"                             "$( cat "$rigDir/a.rc" )" 0
rigAssert "and the site was never called"                    "$( rigCalls )" "none"

echo "-- 2. an item the site holds no issue for gets one, with its three labels, and its status --"
rigScenario create
rigModels="jira+none"
rigAnswer GET /rest/api/3/issue/RIGP-900/transitions '{"transitions":[{"id":"31","name":"To Do","to":{"name":"Backlog"}},{"id":"41","name":"Start","to":{"name":"In Progress"}}]}'
printf -- '---\ntype: task\n---\nrig body\n' | rigOp "$rigDir/b" --intern-op-board-upsert-move-edit running "$rigItem" --create --upsert-from-stdin --context rig
rigAssert "the create lands on the board"                    "$( cat "$rigDir/b.rc" ):$( [ -f "$rigStore/board/running/$rigItem" ] && printf yes || printf no )" "0:yes"
rigAssert "the site saw the search, the create, then the transition of the new issue" "$( rigCalls )" "GET /rest/api/3/search/jql | GET /rest/api/3/myself | POST /rest/api/3/issue | GET /rest/api/3/issue/RIGP-900/transitions | POST /rest/api/3/issue/RIGP-900/transitions"
rigAssert "the new issue's transition is the one leading to In Progress" "$( LC_ALL=C grep -c -F '"id":"41"' "$rigBodies/5" || : )" 1
rigAssert "the create carries the identity label, lower case and no .md" "$( LC_ALL=C grep -c -F '"magic-item-task-20261014t0201z-rig-mirror"' "$rigBodies/3" || : )" 1
rigAssert "the create carries the type label"                "$( LC_ALL=C grep -c -F '"magic-type-task"' "$rigBodies/3" || : )" 1
rigAssert "the create carries this state's label"            "$( LC_ALL=C grep -c -F '"magic-state-running"' "$rigBodies/3" || : )" 1

echo "-- 2b. an item created in a Backlog state is left in Backlog --"
rigScenario createbacklog
rigModels="jira+none"
printf -- '---\ntype: task\n---\nrig body\n' | rigOp "$rigDir/b2" --intern-op-board-upsert-move-edit pending "$rigItem" --create --upsert-from-stdin --context rig
rigAssert "the site saw the search and the create, and no transition" "$( rigCalls )" "GET /rest/api/3/search/jql | GET /rest/api/3/myself | POST /rest/api/3/issue"

echo "-- 3. a move to another state transitions the issue and replaces its state label --"
rigScenario transition
rigModels="jira+none"
rigSeed parked
rigAnswer GET /rest/api/3/search/jql '{"startAt":0,"maxResults":1,"total":1,"isLast":true,"issues":[{"key":"RIGP-900","fields":{"status":{"name":"Backlog"},"summary":"rig","issuetype":{"name":"Task"}}}]}'
rigAnswer GET /rest/api/3/issue/RIGP-900/transitions '{"transitions":[{"id":"31","name":"To Do","to":{"name":"Backlog"}},{"id":"41","name":"Start","to":{"name":"In Progress"}}]}'
rigCallsReset
rigOp "$rigDir/c" --intern-op-board-upsert-move-edit running "$rigItem" --from-state:parked --context rig
rigAssert "the board move lands"                             "$( cat "$rigDir/c.rc" )" 0
rigAssert "the site saw the search, the issue's labels, the transition, then the label update" "$( rigCalls )" \
	"GET /rest/api/3/search/jql | GET /rest/api/3/issue/RIGP-900 | GET /rest/api/3/issue/RIGP-900/transitions | POST /rest/api/3/issue/RIGP-900/transitions | PUT /rest/api/3/issue/RIGP-900"
rigAssert "the transition is the one leading to In Progress" "$( LC_ALL=C grep -c -F '"id":"41"' "$rigBodies/4" || : )" 1
rigAssert "and the transition carries no labels"             "$( LC_ALL=C grep -c -F '"labels"' "$rigBodies/4" || : )" 0
rigAssert "the update keeps the label a person put there"    "$( LC_ALL=C grep -c -F '"security"' "$rigBodies/5" || : )" 1
rigAssert "and carries this state's label"                   "$( LC_ALL=C grep -c -F '"magic-state-running"' "$rigBodies/5" || : )" 1
rigAssert "and not the state label it replaced"              "$( LC_ALL=C grep -c -F '"magic-state-blocked"' "$rigBodies/5" || : )" 0

echo "-- 4. a same-state edit is no move, so the site is left alone --"
rigScenario edit
rigModels="jira+none"
rigSeed running
rigCallsReset
rigOp "$rigDir/d" --intern-op-board-upsert-move-edit running "$rigItem" --from-state:running --header:upsert:rig-mark:yes --context rig
rigAssert "the edit lands"                                   "$( cat "$rigDir/d.rc" ):$( LC_ALL=C grep -c '^rig-mark: yes$' "$rigStore/board/running/$rigItem" || : )" "0:1"
rigAssert "and the site was never called"                    "$( rigCalls )" "none"

echo "-- 5. a site fault on the Jira write never fails the board move --"
rigScenario refused
rigModels="jira+none"
rigSeed parked
rigAnswer GET /rest/api/3/search/jql '{"startAt":0,"maxResults":1,"total":1,"isLast":true,"issues":[{"key":"RIGP-900","fields":{"status":{"name":"In Progress"},"summary":"rig","issuetype":{"name":"Task"}}}]}'
rigAnswer POST /rest/api/3/issue/RIGP-900/transitions '{"errorMessages":["the site is unwell"]}' 500
rigCallsReset
rigOp "$rigDir/e" --intern-op-board-upsert-move-edit blocked "$rigItem" --from-state:parked --context rig
rigAssert "the board move stands"                            "$( cat "$rigDir/e.rc" ):$( [ -f "$rigStore/board/blocked/$rigItem" ] && printf yes || printf no )" "0:yes"
rigAssert "the item left the state it was in"                 "$( [ -e "$rigStore/board/parked/$rigItem" ] && printf left || printf gone )" gone
rigAssert "and the warning names the item and its issue"     "$( LC_ALL=C grep -c -F "its issue RIGP-900 was not" "$rigDir/e.err" || : )" 1

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ BOARD JIRA REFLECT CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'BOARD_JIRA_REFLECT: OK (%d assertions, offline, fake site only)\n' "$rigPass"
