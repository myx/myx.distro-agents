#!/usr/bin/env bash
## Behavioural check on the reflection setting and its wizard (S17 items 2 and 3): REFLECT_MODELS
## reads as `none` where no line stands, refuses any value outside its two closed lists, and one
## value is the whole of it. `--config-check` prints one warning and one only for a half the model
## selects and the workspace cannot use, and none for a token with no half. The wizard's
## `--render-missing` lists exactly the keys a chosen half lacks, and its `--apply` writes the
## model last, only once each half has answered a live read. That read runs against a fake site on
## a stub curl, so nothing leaves this host. The Google half is not exercised: its read is Python's,
## not curl's, and its stub would be a second fake site. Offline; only the rig's own tree is read.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
[ -f "$rigTool" ] || { echo "⛔ ERROR: the tool is not at the origin this workspace resolves: $rigTool -- refusing to report a result" >&2 ; exit 1 ; }

. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsReflectSettingCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigBin="$rigTmp/bin"
rigScopes="$rigWs/.local/.agents"
mkdir -p "$rigScopes" "$rigBin" "$rigTmp/skills" "$rigWs/.local/agents/team-data-root/inboxes/magic-coordinator/incoming"

## THE FAKE SITE: a curl that logs its call and answers the status this run asks for. A half is
## proved to fail by answering a status the call refuses; 200 is an answer, and the read passes.
printf '#!/bin/sh\ncat > /dev/null 2>&1 ; printf "%%s\\n" "$*" >> "%s/curl.calls" ; printf "\\n%%s\\n" "${RIG_REFLECT_STATUS:-200}"\n' "$rigTmp" > "$rigBin/curl"
chmod +x "$rigBin/curl"

rigPass=0 rigFail=0
rigExpect(){ ## what is asserted, output, the text it must hold
	case "$2" in
		*"$3"*) printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 )) ;;
		*) printf '  FAIL  %s\n        want: %s\n        got:  %s\n' "$1" "$3" "$( printf '%s' "$2" | head -4 )" ; rigFail=$(( rigFail + 1 )) ;;
	esac
}
rigEqual(){ ## what is asserted, output, the exact text wanted
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        want: %s\n        got:  %s\n' "$1" "$3" "$2" ; rigFail=$(( rigFail + 1 )) ; fi
}

## Every call runs in a shell of its own with none of the calling session's identity: a
## coordinator's own operation is refused from a member's session, and this call is neither's.
## The tool names its own origin on stderr at every start; that line is not the call's answer.
rigRun(){ ## args -- the call's whole output, both streams, the startup line left out; its status
	local runOut="" runRc=0
	runOut="$( cd "$rigWs" && env -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID \
		-u harnessAgent -u harnessSessionId -u JIRA_SITE -u JIRA_USER -u JIRA_API_TOKEN \
		-u CONFLUENCE_SITE -u CONFLUENCE_USER -u CONFLUENCE_API_TOKEN -u REFLECT_MODELS \
		PATH="$rigBin:$PATH" MDAT_SKILLSET_ROOT="$rigTmp/skills" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash "$rigTool" "$@" 2>&1 )" || runRc=$?
	printf '%s\n' "$runOut" | LC_ALL=C sed '/^SystemContext: init: /d'
	return "$runRc"
}
rigRc(){ ## args -- the status of that call, its output thrown away
	( cd "$rigWs" && env -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID \
		-u harnessAgent -u harnessSessionId -u JIRA_SITE -u JIRA_USER -u JIRA_API_TOKEN \
		-u CONFLUENCE_SITE -u CONFLUENCE_USER -u CONFLUENCE_API_TOKEN -u REFLECT_MODELS \
		PATH="$rigBin:$PATH" MDAT_SKILLSET_ROOT="$rigTmp/skills" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash "$rigTool" "$@" > /dev/null 2>&1 ; printf '%s' "$?" )
}
## The team scope, rewritten whole: one line a key, in the order given.
rigScope(){ printf '%s\n' "$@" > "$rigScopes/magic-team.agent.env" ; }
rigHolds(){ LC_ALL=C grep -c "^$1=" "$rigScopes/magic-team.agent.env" 2> /dev/null || : ; }

## HALF A selects jira and confluence and holds only the confluence keys; HALF B holds both.
HALF_BASE='MDAT_WORKSPACE_MODE=team-rig'
CONFLUENCE_KEYS=(
	'CONFLUENCE_SITE=rig.atlassian.example'
	'CONFLUENCE_USER=rig@example.invalid'
	'CONFLUENCE_API_TOKEN=rig-confluence-token'
	'CONFLUENCE_SPACE=RIGSPACE'
)
JIRA_KEYS=(
	'JIRA_SITE=rig.atlassian.example'
	'JIRA_USER=rig@example.invalid'
	'JIRA_API_TOKEN=rig-jira-token'
	'REFLECT_JIRA_PROJECT=RIGP'
)

echo "-- 1. the key: one value, unset reading as none, and both closed lists enforced --"
rigScope "$HALF_BASE"
rigExpect "an absent line reads as none, never as nothing at all" \
	"$( rigRun --agents-config-option magic-team --select REFLECT_MODELS )" "none"
rigEqual "and the catalogue defines it once, in the team scope" \
	"$( . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/config/AgentsTools.OwnerSetupOptionSpec.include" ; AgentsToolsOwnerSetupOptionSpec REFLECT_MODELS | LC_ALL=C cut -d'|' -f1,2,3 )" \
	"magic-team|<board>+<documents>|plain"
rigExpect "a value of the two closed lists stores" \
	"$( rigRun --agents-config-option magic-team --upsert REFLECT_MODELS 'jira+confluence' ; printf 'rc=%s lines=%s' "$?" "$( rigHolds REFLECT_MODELS )" )" "rc=0 lines=1"
rigExpect "and reads back as it was stored" \
	"$( rigRun --agents-config-option magic-team --select REFLECT_MODELS )" "jira+confluence"
rigScope "$HALF_BASE"
rigExpect "a board position that is none of the three is refused at write" \
	"$( rigRun --agents-config-option magic-team --upsert REFLECT_MODELS 'asana+none' | LC_ALL=C grep -c 'board position is none, jira or trello' )" "1"
rigEqual "and nothing was written" "$( rigHolds REFLECT_MODELS )" "0"
rigExpect "a documents position that is none of the three is refused at write" \
	"$( rigRun --agents-config-option magic-team --upsert REFLECT_MODELS 'none+notion' | LC_ALL=C grep -c 'documents position is none, confluence or google-docs' )" "1"
rigEqual "and nothing was written there either" "$( rigHolds REFLECT_MODELS )" "0"
rigExpect "a value naming no position is refused, so a typo cannot make a third model" \
	"$( rigRun --agents-config-option magic-team --upsert REFLECT_MODELS 'jira' | LC_ALL=C grep -c 'is <board>+<documents>, or none' )" "1"
rigExpect "none stores, and reads back as both halves off" \
	"$( rigRun --agents-config-option magic-team --upsert REFLECT_MODELS 'none' ; rigRun --agents-config-option magic-team --select REFLECT_MODELS )" "none"
rigExpect "none+google-docs stores, which is the documents-only state" \
	"$( rigRun --agents-config-option magic-team --upsert REFLECT_MODELS 'none+google-docs' ; rigRun --agents-config-option magic-team --select REFLECT_MODELS )" "none+google-docs"
rigExpect "a value given on stdin passes the same two lists" \
	"$( printf 'trello+pager' | rigRun --agents-config-option magic-team --upsert-from-stdin REFLECT_MODELS | LC_ALL=C grep -c 'documents position' )" "1"

echo "-- 2. the fault line: one warning for a selected half the workspace lacks, silence otherwise --"
rigScope "$HALF_BASE" 'REFLECT_MODELS=jira+confluence' "${CONFLUENCE_KEYS[@]}"
rigCheckA="$( rigRun --config-check )"
rigEqual "exactly one reflection warning, for the one half that is short" \
	"$( printf '%s\n' "$rigCheckA" | LC_ALL=C grep -c '^REFLECT_MODELS: WARN$' )" "1"
rigEqual "and it names the four keys that half needs" \
	"$( printf '%s\n' "$rigCheckA" | LC_ALL=C grep '^  warn: the jira half' | LC_ALL=C grep -c 'JIRA_SITE, JIRA_USER, JIRA_API_TOKEN, REFLECT_JIRA_PROJECT' )" "1"
rigEqual "the confluence half, whole, draws no warning of its own" \
	"$( printf '%s\n' "$rigCheckA" | LC_ALL=C grep -c 'confluence half' )" "0"
rigEqual "a warning never gates the call: the same workspace gives the same status with no reflection line at all" \
	"$( rigRc --config-check )/$( rigScope "$HALF_BASE" "${CONFLUENCE_KEYS[@]}" "${JIRA_KEYS[@]}" ; rigRc --config-check )" "1/1"
rigScope "$HALF_BASE" 'REFLECT_MODELS=jira+confluence' "${CONFLUENCE_KEYS[@]}" "${JIRA_KEYS[@]}"
rigEqual "control: the same model with both halves whole prints no reflection line" \
	"$( rigRun --config-check | LC_ALL=C grep -c '^REFLECT_MODELS:' )" "0"
rigScope "$HALF_BASE" 'REFLECT_MODELS=none' "${CONFLUENCE_KEYS[@]}" "${JIRA_KEYS[@]}"
rigEqual "a token with no half is no fault: the model is none and every token is there" \
	"$( rigRun --config-check | LC_ALL=C grep -c '^REFLECT_MODELS:' )" "0"
rigScope "$HALF_BASE" 'REFLECT_MODELS=jira+gogle-docs' 'JIRA_SITE=rig.atlassian.example'
rigEqual "a stored value outside the closed lists is reported, never read as a model" \
	"$( rigRun --config-check | LC_ALL=C grep -c 'no half is read from it' )" "1"

echo "-- 3. the wizard: step 2 lists exactly what is lacking, step 5 writes the model last --"
rigScope "$HALF_BASE" 'REFLECT_MODELS=jira+confluence' "${CONFLUENCE_KEYS[@]}"
rigMissingA="$( rigRun --owner-setup-reflection --render-missing )"
rigEqual "step 2 names the four keys the jira half lacks, and no fifth" \
	"$( printf '%s\n' "$rigMissingA" | LC_ALL=C grep '^MISSING: ' | LC_ALL=C tr '\n' ' ' )" \
	"MISSING: jira JIRA_SITE MISSING: jira JIRA_USER MISSING: jira JIRA_API_TOKEN MISSING: jira REFLECT_JIRA_PROJECT "
rigEqual "and no key of the confluence half, which is whole" \
	"$( printf '%s\n' "$rigMissingA" | LC_ALL=C grep -c 'CONFLUENCE' )" "0"
rigEqual "a key missing leaves the step not ready, and the step names four keys" \
	"$( rigRc --owner-setup-reflection --render-missing )/$( printf '%s\n' "$rigMissingA" | LC_ALL=C grep -c '^MISSING: jira ' )" "1/4"
rigScope "$HALF_BASE" 'REFLECT_MODELS=jira+confluence' "${CONFLUENCE_KEYS[@]}" "${JIRA_KEYS[@]}"
rigExpect "a whole model's step 2 says nothing is missing" \
	"$( rigRun --owner-setup-reflection --render-missing )" "MISSING: none"
rigEqual "and that workspace is ready for the model" \
	"$( rigRc --owner-setup-reflection --render-missing )" "0"

## Step 5 writes the model after the reads. The scope is held without a model line first, so the
## one line the apply adds is the whole change and any other byte would show as a second one.
rigScope "$HALF_BASE" "${CONFLUENCE_KEYS[@]}" "${JIRA_KEYS[@]}"
cp -p "$rigScopes/magic-team.agent.env" "$rigTmp/scope.before"
rigApplyOut="$( RIG_REFLECT_STATUS=200 rigRun --owner-setup-reflection --reflect-models 'jira+confluence' --apply )"
rigEqual "the apply ends 0 on a model both halves can use" \
	"$( RIG_REFLECT_STATUS=200 rigRc --owner-setup-reflection --reflect-models 'jira+confluence' --apply )" "0"
rigExpect "and says the model was written after the reads" "$rigApplyOut" "REFLECT_MODELS set in"
rigEqual "step 4 asked the fake site, so a live read really ran" \
	"$( [ -s "$rigTmp/curl.calls" ] && printf yes || printf no )" "yes"
rigEqual "the model line is now stored" "$( rigHolds REFLECT_MODELS )" "1"
rigEqual "and the apply added that one line, removing nothing" \
	"$( diff "$rigTmp/scope.before" "$rigScopes/magic-team.agent.env" | LC_ALL=C grep -c '^>' )/$( diff "$rigTmp/scope.before" "$rigScopes/magic-team.agent.env" | LC_ALL=C grep -c '^<' )" "1/0"

## The control that proves step 5 can fail: the site refuses the jira half, so the model is not
## written at all and the workspace keeps exactly the file it had.
rigScope "$HALF_BASE" "${CONFLUENCE_KEYS[@]}" "${JIRA_KEYS[@]}"
cp -p "$rigScopes/magic-team.agent.env" "$rigTmp/scope.refused"
rigEqual "a half that does not answer its read leaves the apply failed" \
	"$( RIG_REFLECT_STATUS=401 rigRc --owner-setup-reflection --reflect-models 'jira+confluence' --apply )" "1"
rigExpect "and says the model was not written" \
	"$( RIG_REFLECT_STATUS=401 rigRun --owner-setup-reflection --reflect-models 'jira+confluence' --apply )" "so REFLECT_MODELS was not written"
rigEqual "the scope file is untouched, so no half is ever named unusably" \
	"$( cmp -s "$rigTmp/scope.refused" "$rigScopes/magic-team.agent.env" && printf same || printf changed )" "same"
rigExpect "a model of none needs no read, so it is written even while the site refuses everything" \
	"$( RIG_REFLECT_STATUS=401 rigRun --owner-setup-reflection --reflect-models 'none' --apply )" "REFLECT_MODELS set in"
rigEqual "and it reads back as none" "$( rigRun --agents-config-option magic-team --select REFLECT_MODELS )" "none"

echo "-- 4. the shape: one write path, no global out-parameter, and no stray argument --"
## A global used as an out-parameter is banned outright, and a second write path beside the
## operation's own is the same fault. The value on stdin is kept in a local of the arm that
## writes it, so nothing of it stands at file scope.
rigReflectInclude="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/config/AgentsTools.ReflectSetting.include"
rigEqual "the include names no variable outside a function: no global carries a value out" \
	"$( LC_ALL=C grep -c 'agentsReflectStdin' "$rigReflectInclude" )" "0"
rigEqual "a good value on stdin still stores, through the one write path" \
	"$( printf 'trello+google-docs' | rigRun --agents-config-option magic-team --upsert-from-stdin REFLECT_MODELS ; rigRun --agents-config-option magic-team --select REFLECT_MODELS )" "trello+google-docs"
rigEqual "and a bad one still leaves the stored value alone" \
	"$( printf 'trello+pager' | rigRun --agents-config-option magic-team --upsert-from-stdin REFLECT_MODELS > /dev/null ; rigRun --agents-config-option magic-team --select REFLECT_MODELS )" "trello+google-docs"
rigEqual "the half table is called with the arguments it takes, and no other" \
	"$( LC_ALL=C grep -c 'AgentsToolsReflectKeyValue "\$setupReflectKey" ""' "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/config/AgentsTools.Owner.include" )" "0"

if [ "$rigFail" = 0 ] ; then printf 'AGENTS_REFLECT_SETTING: OK (%s assertions, offline)\n' "$rigPass" ; exit 0 ; fi
printf '⛔ AGENTS REFLECT SETTING CHECK FAILED: %s of %s assertion(s)\n' "$rigFail" "$(( rigPass + rigFail ))" ; exit 1
