#!/usr/bin/env bash
## Behavioural check on `--confluence-page-update --if-version` through the tool file a coordinator calls, not through the
## operation alone: DistroAgentsAtlassian.fn.sh's forwarding stub is driven for real, so the approved form is read end to end.
## Held:
##   1. a page standing at the caller's own reading is written, one PUT, carrying the next version number
##   2. a page that has moved is CONFLICT, exit 10, and nothing at all is sent
##   3. CONTROL: `--version` alone still writes, so the older arm does not regress
## Red recipe: before `--if-version` was declared at the stub, the flags check's red run named it as refused, and the
## stub answered `unexpected: --if-version` with rc 1 and no request. Offline: a fake curl stands for the site.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigAtlassian="$rigPackage/sh-scripts/DistroAgentsAtlassian.fn.sh"
[ -f "$rigAtlassian" ] || { echo "⛔ ERROR: the Atlassian tool is not at the origin: $rigAtlassian" >&2 ; exit 1 ; }
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsAtlassianIfVersionCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPass=0 rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

rigWs="$rigTmp/ws" rigHome="$rigTmp/home" rigData="$rigTmp/data" rigSkills="$rigTmp/skills" rigState="$rigTmp/site" rigBin="$rigTmp/bin"
mkdir -p "$rigWs/.local/temp" "$rigWs/.local/.agents" "$rigHome" "$rigData" "$rigState" "$rigBin"
mkdir -p "$rigSkills/magic-coordinator"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
printf -- '---\nmaintainers: rig\n---\nrig\n' > "$rigSkills/magic-coordinator/magic-coordinator.armed.md"

## The fake site answers the read with the version the fixture names, and the write with 204.
cat > "$rigBin/curl" <<'RIGCURL'
#!/bin/sh
rigMethod=GET
rigUrl=""
while [ $# -gt 0 ] ; do
	case "$1" in
		-X) rigMethod="$2" ; shift 2 ;;
		--data-binary|--data-urlencode|-H|-w|--connect-timeout|--max-time|-K) shift 2 ;;
		https://*) rigUrl="$1" ; shift ;;
		*) shift ;;
	esac
done
cat > /dev/null
rigRest="${rigUrl#https://}"
rigHost="${rigRest%%/*}"
rigPath="/${rigRest#*/}"
printf '%s %s %s\n' "$rigMethod" "$rigHost" "$rigPath" >> "$RIG_STATE/calls"
case "$rigHost" in
	*.invalid) ;;
	*) printf '{"message":"rig: %s is not the fake site"}\n599' "$rigHost" ; exit 0 ;;
esac
rigLive="$( cat "$RIG_STATE/live-version" 2> /dev/null || : )"
case "$rigMethod" in
	GET) printf '\n%s\n%s' "{\"id\":\"7000000001\",\"title\":\"Rig page\",\"version\":{\"number\":${rigLive:-7}},\"spaceId\":\"5001\",\"body\":{\"storage\":{\"value\":\"<p>rig</p>\"}}}" 200 ;;
	*) printf '\n%s\n%s' "" 204 ;;
esac
RIGCURL
chmod +x "$rigBin/curl" || { echo "⛔ ERROR: the fake site could not be written" >&2 ; exit 1 ; }
printf '#!/bin/sh\nexec bash "%s" "$@"\n' "$rigAtlassian" > "$rigBin/rig-atlassian" || exit 1
chmod +x "$rigBin/rig-atlassian" || exit 1

rigRc=0
rigRun(){ ## words... -- one call through the tool file, rc in rigRc
	: > "$rigState/calls"
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$rigBin:/usr/bin:/bin" MMDAPP="$rigWs" \
		MDAT_WORKSPACE_MODE=team-rig MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SPAWN_AGENT=magic-coordinator RIG_STATE="$rigState" \
		CONFLUENCE_SITE=rig-confluence.invalid CONFLUENCE_USER=us@rig.invalid CONFLUENCE_API_TOKEN=rig-token \
		bash "$rigBin/rig-atlassian" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null
	rigRc=$?
}
rigCalls(){ LC_ALL=C cat "$rigState/calls" 2> /dev/null || : ; }
rigErrHas(){ LC_ALL=C grep -c -F -- "$1" "$rigTmp/err" 2> /dev/null || : ; }
rigSentWrites(){ LC_ALL=C awk '$1 != "GET" { n++ ; } END { print n + 0 ; }' "$rigState/calls" 2> /dev/null || : ; }

rigPageId="7000000001"
rigUpdate(){ ## words... -- the operation's fixed arguments, then the version form under test
	rigRun --confluence-page-update --team-member magic-coordinator "$rigPageId" \
		--title "Rig page" --status current --body-storage '<p>the new body</p>' "$@"
}

## 1. The page stands where the caller read it, and the write goes.
printf '7' > "$rigState/live-version"
rigUpdate --if-version 7
rigAssert "a page at the caller's reading is written" "$rigRc" "0"
rigAssert "and the write is the one PUT of that page" "$( rigCalls )" "GET rig-confluence.invalid /wiki/api/v2/pages/$rigPageId?body-format=storage
PUT rig-confluence.invalid /wiki/api/v2/pages/$rigPageId"

## 2. The page has moved since that reading, and nothing is sent.
printf '9' > "$rigState/live-version"
rigUpdate --if-version 7
rigAssert "a page that moved is CONFLICT, exit 10" "$rigRc" "10"
rigAssert "and no write is sent at all" "$( rigSentWrites )" "0"
rigAssert "and the CONFLICT names both versions" "$( rigErrHas '--if-version is 7 and the page stands at 9' )" "1"

## 3. CONTROL: the older arm is unchanged, and it writes whatever the page stands at.
rigUpdate --version 7
rigAssert "control: --version alone still writes" "$rigRc" "0"
rigAssert "control: and the write is sent" "$( rigSentWrites )" "1"

if [ "$rigFail" = 0 ] ; then printf 'ATLASSIAN IF-VERSION: OK (%s assertions, offline)\n' "$rigPass" ; exit 0 ; fi
printf '⛔ ATLASSIAN IF-VERSION CHECK FAILED: %s of %s assertion(s)\n' "$rigFail" "$(( rigPass + rigFail ))" ; exit 1
