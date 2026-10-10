#!/usr/bin/env bash
## Behavioural check on the Artifact tool and --intern-artifact-publish: announcing a URL is as
## before; a publish is refused, before anything is sent, without the Artifact permission,
## without a team place, with CONFLUENCE_SPACE but no Confluence credentials, without the
## magic-team Google folder or with two, with an image it does not carry, and with a number in
## its title; CONFLUENCE_SPACE chooses Confluence over Google, a member own value for that
## member alone; Google folders and files are shared with the account organisation, never with
## anyone, and a document that cannot be shared is not announced; a Confluence publish of Markdown
## creates its type index page once, the numbered child page with its attachments, lists it on
## the index, records it in team data and posts its link; a Google publish of HTML creates the
## type folder, uploads the linked file beside it, imports the document with its image inline
## and posts its link; a number grows to four digits after 999; an untyped kind gets no number;
## a PDF is published as it is. Two writers on two clones of one team-data origin never share
## a number: one that loses the push resyncs and takes the next, and a failed publish releases
## its number. Offline: a fake curl answers for Slack and Confluence, a sitecustomize stands in
## for urlopen for Google, and the origin is a bare repository in the rig. Each scenario has its
## own workspace and team data under the workspace's .local/temp.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to read under"
for rigFixture in artifact-publish.curl.test.sh artifact-publish.confluence.test.py artifact-publish.sitecustomize.test.py harness-ask-check.curl.test.sh ; do
	[ -f "$rigTest/check-fixtures/$rigFixture" ] || rigRefuse "the fixture $rigFixture is missing from the package"
done
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsArtifactPublishCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/tmp"
cp "$rigTest/check-fixtures/artifact-publish.curl.test.sh" "$rigTmp/bin/curl"
for rigModel in claude codex ; do
	printf '#!/bin/sh\necho "%s $*" >> "%s/model-calls"\nexit 1\n' "$rigModel" "$rigTmp" > "$rigTmp/bin/$rigModel"
done
chmod +x "$rigTmp/bin/"*
PATH="$rigTmp/bin:/usr/bin:/bin"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"
command -v python3 > /dev/null || rigRefuse "no python3 on the rig PATH"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHolds(){ ## file, fixed string
	LC_ALL=C grep -q -F -- "$2" "$1" 2>/dev/null && printf yes || printf no
}
rigCount(){ ## file, fixed string -- lines holding it
	LC_ALL=C grep -c -F -- "$2" "$1" 2>/dev/null || :
}

rigScenarioDir="" rigWork=""
rigStart(){ ## scenario directory name
	rigScenarioDir="$rigTmp/$1"
	rigWork="$rigScenarioDir/ws/.local/temp/member/$rigMember"
	mkdir -p "$rigScenarioDir/ws/.local/.agents" "$rigScenarioDir/data" "$rigScenarioDir/py" "$rigScenarioDir/google" "$rigWork"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigScenarioDir/ws/.local/.agents/$rigMember.agent.env"
	cp "$rigTest/check-fixtures/artifact-publish.sitecustomize.test.py" "$rigScenarioDir/py/sitecustomize.py"
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
	## The spawn record of the session the call runs in: not ended, so its grants live.
	mkdir -p "$rigScenarioDir/ws/.local/agents/spawned/child-folder"
	printf -- '---\nspawn-id: rig-child-id\nowner: %s\nparent-session-id: none\n---\n' "$rigMember" > "$rigScenarioDir/ws/.local/agents/spawned/child-folder/rig-child-id.md"
}
rigTeam(){ ## KEY=value
	printf '%s\n' "$1" >> "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
}
rigConfluence(){
	printf 'CONFLUENCE_SITE=rig.atlassian.invalid\nCONFLUENCE_USER=rig@example.invalid\nCONFLUENCE_API_TOKEN=rig-confluence-token\n' >> "$rigScenarioDir/ws/.local/.agents/$rigMember.agent.env"
}
rigGoogle(){ ## folders.json content
	printf 'GOOGLE_CLIENT_ID=rig-client\nGOOGLE_CLIENT_SECRET=rig-secret\nGOOGLE_REFRESH_TOKEN=rig-refresh\n' >> "$rigScenarioDir/ws/.local/.agents/$rigMember.agent.env"
	printf '%s\n' "$1" > "$rigScenarioDir/google/folders.json"
}
## The Artifact permission for the session, granted by another member.
rigGrant(){
	local grantStore="$rigScenarioDir/ws/.local/agents/sessions/rig-child-id"
	mkdir -p "$grantStore"
	printf -- '---\nowner: %s\n---\n' "$rigMember" > "$grantStore/set-rig-artifact.md"
	printf 'session:Artifact:publish:magic-coordinator:20261010T000000Z:set-rig-artifact\n' >> "$grantStore/grants"
}
rigCall(){ ## arguments JSON
	printf '%s' "$1" | ( cd "$rigScenarioDir/ws" && env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u ANTHROPIC_API_KEY -u OPENAI_API_KEY -u MDAT_SESSION_THREAD \
		TMPDIR="$rigTmp/tmp" RIG_SCENARIO="$rigScenarioDir" RIG_FIXTURES="$rigTest/check-fixtures" \
		PYTHONPATH="$rigScenarioDir/py" PYTHONDONTWRITEBYTECODE=1 MMDAPP="$rigScenarioDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_DATA_ROOT="$rigScenarioDir/data" MDAT_SPAWN_SESSION_ID=rig-child-id MDAT_SPAWN_AGENT="$rigMember" MDAT_SKILLSET_ROOT="$MDAT_SKILLSET_ROOT" \
		bash "$rigHarness" --intern-tool Artifact ) > "$rigScenarioDir/tool.out" 2> "$rigScenarioDir/tool.err"
}
rigFirstIs(){ ## prefix of the result's first line
	LC_ALL=C awk -v want="$1" 'NR == 1 { print ( index($0, want) == 1 ? "yes" : "no" ) ; exit ; }' "$rigScenarioDir/tool.out"
}
rigPostHolds(){ ## fixed string -- whether any post carries it
	cat "$rigScenarioDir"/post.* 2>/dev/null | LC_ALL=C grep -q -F -- "$1" && printf yes || printf no
}
rigNothingSent(){ ## no call reached Confluence or Google
	[ ! -s "$rigScenarioDir/conf/calls" ] && [ ! -s "$rigScenarioDir/google/requests" ] && printf yes || printf no
}
rigRecord(){ ## every published record, "number|kind|title|url|member|session", in a data root (default the scenario's)
	local recordFile
	for recordFile in "${1:-$rigScenarioDir/data}/audit/"artifact-*.md ; do
		[ -f "$recordFile" ] || continue
		LC_ALL=C awk '
			$0 == "---" { front++ ; next ; }
			front == 1 { key = $0 ; sub( /: .*/, "", key ) ; field[key] = substr( $0, length( key ) + 3 ) ; }
			END { if ( field["state"] == "published" ) { print field["number"] "|" field["kind"] "|" field["title"] "|" field["url"] "|" field["member"] "|" field["session"] ; } ; }
		' "$recordFile"
	done
}
rigMarkdown(){
	printf '# Render documents\n\nThe page shows ![the diagram](images/diagram.png "Diagram").\n\nSee [the report](report.pdf).\n' > "$rigWork/doc.md"
	printf 'rig png bytes' > "$rigWork/diagram.png"
	printf 'rig pdf bytes' > "$rigWork/report.pdf"
}
rigPublishJson(){ ## kind, title, document name
	printf '{"to":"%s","file":"%s/%s","files":["%s/diagram.png","%s/report.pdf"],"title":"%s","kind":"%s","summary":"rig summary"}' \
		"$rigMember" "$rigWork" "$3" "$rigWork" "$rigWork" "$2" "$1"
}

echo "-- announcing a URL is as before --"
rigStart announce
rigCall '{"to":"magic-tester","url":"https://x.invalid/y","title":"Rig page","kind":"page"}'
rigAssert "it posts the link"                               "$( rigPostHolds 'https://x.invalid/y' )$( rigPostHolds 'Rig page' )" yesyes
rigAssert "and publishes nothing"                           "$( rigNothingSent )" yes
rigCall '{"to":"magic-tester","url":"not-a-url"}'
rigAssert "a URL that is not one is still refused"          "$( rigFirstIs 'ERROR: Artifact: url must be' )" yes
rigCall '{"to":"magic-tester"}'
rigAssert "neither url nor file is that same refusal"       "$( rigFirstIs 'ERROR: Artifact: url must be' )" yes

echo "-- every refusal comes before anything is published --"
rigStart noGrant
rigConfluence ; rigTeam CONFLUENCE_SPACE=TEAM ; rigMarkdown
rigCall "$( rigPublishJson ADR 'Render documents' doc.md )"
rigAssert "no Artifact permission: refused, with its id"    "$( rigFirstIs 'ERROR: Artifact: publishing needs the Artifact permission' )$( rigHolds "$rigScenarioDir/tool.out" 'REFUSAL-ID: refusal-' )" yesyes
rigAssert "and nothing sent or posted"                      "$( rigNothingSent )$( rigPostHolds 'Render documents' )" yesno
rigStart noBackend
rigGrant ; rigMarkdown
rigCall "$( rigPublishJson ADR 'Render documents' doc.md )"
rigAssert "no team place: refused, naming the keys"         "$( rigHolds "$rigScenarioDir/tool.out" 'no team place is set up for magic-tester' )$( rigHolds "$rigScenarioDir/tool.out" 'CONFLUENCE_SPACE (its own scope or magic-team) and CONFLUENCE_SITE/CONFLUENCE_USER/CONFLUENCE_API_TOKEN' )$( rigHolds "$rigScenarioDir/tool.out" 'GOOGLE_CLIENT_ID/GOOGLE_CLIENT_SECRET/GOOGLE_REFRESH_TOKEN' )" yesyesyes
rigAssert "and nothing sent, recorded or posted"            "$( rigNothingSent )$( rigRecord | wc -l | tr -d ' ' )$( rigPostHolds 'Render documents' )" yes0no
rigStart noSpace
rigGrant ; rigConfluence ; rigMarkdown
rigCall "$( rigPublishJson ADR 'Render documents' doc.md )"
rigAssert "Confluence credentials, no CONFLUENCE_SPACE, no Google: no place" "$( rigHolds "$rigScenarioDir/tool.out" 'no team place is set up for magic-tester' )$( rigNothingSent )" yesyes
rigStart spaceNoCredentials
rigGrant ; rigGoogle '[{"id":"root-1","name":"magic-team","parent":"x"}]' ; rigTeam CONFLUENCE_SPACE=TEAM ; rigMarkdown
rigCall "$( rigPublishJson ADR 'Render documents' doc.md )"
rigAssert "CONFLUENCE_SPACE without Confluence credentials: refused, not Google" "$( rigHolds "$rigScenarioDir/tool.out" 'CONFLUENCE_SPACE names the team space TEAM, and magic-tester holds no CONFLUENCE_SITE/CONFLUENCE_USER/CONFLUENCE_API_TOKEN' )$( rigNothingSent )" yesyes
rigStart bothPlaces
rigGrant ; rigConfluence ; rigGoogle '[{"id":"root-1","name":"magic-team","parent":"x"}]' ; rigTeam CONFLUENCE_SPACE=TEAM ; rigMarkdown
rigCall "$( rigPublishJson ADR 'Render documents' doc.md )"
rigAssert "both credentials and CONFLUENCE_SPACE: Confluence, not Google" "$( rigFirstIs 'PUBLISHED: ADR-001: Render documents at https://rig.atlassian.invalid/' )$( [ -s "$rigScenarioDir/google/requests" ] && echo google || echo nogoogle )" yesnogoogle
## A member own CONFLUENCE_SPACE: that member on Confluence, and the rest of its workspace on Google.
rigStart memberSpace
rigMarkdown
mkdir -p "$rigTmp/skillset/client-ndm" "$rigTmp/skillset/keeper-mel"
printf 'CONFLUENCE_SITE=rig.atlassian.invalid\nCONFLUENCE_USER=ndm@example.invalid\nCONFLUENCE_API_TOKEN=rig-ndm-token\nCONFLUENCE_SPACE=TEAM\n' > "$rigScenarioDir/ws/.local/.agents/client-ndm.agent.env"
printf 'GOOGLE_CLIENT_ID=rig-client\nGOOGLE_CLIENT_SECRET=rig-secret\nGOOGLE_REFRESH_TOKEN=rig-refresh\n' > "$rigScenarioDir/ws/.local/.agents/keeper-mel.agent.env"
printf '[{"id":"root-1","name":"magic-team","parent":"x"}]\n' > "$rigScenarioDir/google/folders.json"
rigPublishMember(){ ## member, title, output name -- the operation itself, in this scenario
	( cd "$rigScenarioDir/ws" && env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SESSION_ID \
		TMPDIR="$rigTmp/tmp" RIG_SCENARIO="$rigScenarioDir" RIG_FIXTURES="$rigTest/check-fixtures" RIG_CURL_LOG="$rigScenarioDir/curl.log" PYTHONPATH="$rigScenarioDir/py" PYTHONDONTWRITEBYTECODE=1 \
		MMDAPP="$rigScenarioDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigScenarioDir/data" MDAT_SKILLSET_ROOT="$rigTmp/skillset" \
		bash "$rigTool" --intern-artifact-publish "$1" --title "$2" --kind ADR --document "$rigWork/doc.md" --file "$rigWork/diagram.png" ) > "$rigScenarioDir/$3.out" 2> "$rigScenarioDir/$3.err"
}
rigPublishMember client-ndm 'Client decision' ndm
rigPublishMember keeper-mel 'Team decision' mel
rigAssert "its own CONFLUENCE_SPACE takes client-ndm to Confluence, as itself" "$( LC_ALL=C sed -n 's/^ARTIFACT_PLACE=//p' "$rigScenarioDir/ndm.out" )$( awk '{ print $3 ; }' "$rigScenarioDir/conf/calls" 2>/dev/null | sort -u )" "confluencendm@example.invalid"
rigAssert "a team member of the same workspace still goes to Google" "$( LC_ALL=C sed -n 's/^ARTIFACT_PLACE=//p' "$rigScenarioDir/mel.out" )$( rigHolds "$rigScenarioDir/mel.err" 'CONFLUENCE' )" "googleno"
rigStart missingImage
rigGrant ; rigConfluence ; rigTeam CONFLUENCE_SPACE=TEAM ; rigMarkdown
printf '<p><img src="missing.png"> and <img src="images/diagram.png"></p>\n' > "$rigWork/doc.html"
rigCall "$( rigPublishJson ADR 'Render documents' doc.html )"
rigAssert "an image not given: refused, naming it"          "$( rigHolds "$rigScenarioDir/tool.out" 'not among the given files: missing.png' )$( rigNothingSent )" yesyes
rigStart ownNumber
rigGrant ; rigConfluence ; rigTeam CONFLUENCE_SPACE=TEAM ; rigMarkdown
rigCall "$( rigPublishJson ADR 'ADR-007: Render documents' doc.md )"
rigAssert "a title with its own number: refused"            "$( rigHolds "$rigScenarioDir/tool.out" 'the tooling gives ADR its number' )$( rigNothingSent )" yesyes
rigStart noRoot
rigGrant ; rigGoogle '[]' ; rigMarkdown
rigCall "$( rigPublishJson PLN 'Q4 plan' doc.md )"
rigAssert "no magic-team Google folder: refused, saying how" "$( rigHolds "$rigScenarioDir/tool.out" 'sees no Google folder named magic-team -- create the team folder' )$( [ -s "$rigScenarioDir/google/uploads" ] && echo sent || echo none )" yesnone
rigStart twoRoots
rigGrant ; rigGoogle '[{"id":"root-1","name":"magic-team","parent":"x"},{"id":"root-2","name":"magic-team","parent":"y"}]' ; rigMarkdown
rigCall "$( rigPublishJson PLN 'Q4 plan' doc.md )"
rigAssert "two magic-team folders: refused, listing both"   "$( rigHolds "$rigScenarioDir/tool.out" 'sees 2 Google folders named magic-team' )$( rigHolds "$rigScenarioDir/tool.out" 'root-1' )$( rigHolds "$rigScenarioDir/tool.out" 'root-2' )" yesyesyes

echo "-- Confluence: Markdown under its type index page, numbered, attached, listed, recorded, posted --"
rigStart confluence
rigGrant ; rigConfluence ; rigTeam CONFLUENCE_SPACE=TEAM ; rigMarkdown
rigCall "$( rigPublishJson ADR 'Render documents' doc.md )"
rigHolds "$rigScenarioDir/tool.out" 'PUBLISHED:' | grep -q yes || rigRefuse "the Confluence publish did not complete: $( head -5 "$rigScenarioDir/tool.out" )"
rigPages(){ ## title -- "<id> <parent> <version>"
	python3 -c 'import json,sys; [print(p["id"], p["parent"] or "-", p["version"]) for p in json.load(open(sys.argv[1])) if p["title"] == sys.argv[2]]' "$rigScenarioDir/conf/pages.json" "$1"
}
rigPageBody(){ ## title
	python3 -c 'import json,sys; [print(p["body"]) for p in json.load(open(sys.argv[1])) if p["title"] == sys.argv[2]]' "$rigScenarioDir/conf/pages.json" "$1"
}
rigIndex="$( rigPages 'ADR index' )"
rigDoc="$( rigPages 'ADR-001: Render documents' )"
rigAssert "the type index page was created at the space top" "$( printf '%s' "$rigIndex" | awk '{ print $2 ; }' )" "-"
rigAssert "the document is ADR-001, a child of the index"   "$( printf '%s' "$rigDoc" | awk '{ print $2 ; }' )" "${rigIndex%% *}"
rigAssert "as the caller, with its own credential"          "$( awk '{ print $3 ; }' "$rigScenarioDir/conf/calls" | sort -u )" "rig@example.invalid"
rigAssert "its image and its file are attached to it"       "$( LC_ALL=C grep -c "^${rigDoc%% *}	" "$rigScenarioDir/conf/attachments" )$( rigHolds "$rigScenarioDir/conf/attachments" 'diagram.png' )$( rigHolds "$rigScenarioDir/conf/attachments" 'report.pdf' )" 2yesyes
rigPageBody 'ADR-001: Render documents' > "$rigScenarioDir/doc.body"
rigAssert "the image shows the attachment"                  "$( rigHolds "$rigScenarioDir/doc.body" '<ri:attachment ri:filename="diagram.png"/></ac:image>' )" yes
rigAssert "the link points at the attachment"               "$( rigHolds "$rigScenarioDir/doc.body" '<ac:link><ri:attachment ri:filename="report.pdf"/>' )" yes
rigPageBody 'ADR index' > "$rigScenarioDir/index.body"
rigAssert "the index page lists it, in a new version"       "$( rigHolds "$rigScenarioDir/index.body" 'ri:content-title="ADR-001: Render documents"' )$( printf '%s' "$rigIndex" | awk '{ print $3 ; }' )" yes2
rigAssert "it is recorded in team data"                     "$( rigRecord )" "ADR-001|ADR|Render documents|https://rig.atlassian.invalid/wiki/spaces/TEAM/pages/${rigDoc%% *}|magic-tester|rig-child-id"
rigAssert "the post names it by number, with its link"      "$( rigPostHolds 'ADR-001: Render documents' )$( rigPostHolds "pages/${rigDoc%% *}" )$( rigPostHolds 'architecture decision record' )" yesyesyes
rigCall "$( rigPublishJson adr 'Second decision' doc.md )"
rigAssert "the next one, kind given in lower case, is ADR-002" "$( rigPages 'ADR-002: Second decision' | awk '{ print $2 ; }' )" "${rigIndex%% *}"
rigAssert "and the index page is made only once"            "$( rigPages 'ADR index' | wc -l | tr -d ' ' )$( rigPageBody 'ADR index' | LC_ALL=C grep -o 'ri:content-title' | wc -l | tr -d ' ' )" 12
rigCall "$( rigPublishJson IVR 'Slow sync' doc.md )"
rigAssert "numbers run per type: the first IVR is IVR-001"  "$( rigPages 'IVR-001: Slow sync' | wc -l | tr -d ' ' )$( rigPages 'IVR index' | wc -l | tr -d ' ' )" 11
printf '{"to":"%s","file":"%s/report.pdf","title":"Vendor quote","kind":"quote"}' "$rigMember" "$rigWork" > "$rigScenarioDir/pdf.json"
rigCall "$( cat "$rigScenarioDir/pdf.json" )"
rigPdf="$( rigPages 'Vendor quote' )"
rigAssert "a PDF, untyped: a page under Documents index"    "$( printf '%s' "$rigPdf" | awk '{ print $2 ; }' )" "$( rigPages 'Documents index' | awk '{ print $1 ; }' )"
rigAssert "the PDF itself attached and linked"              "$( LC_ALL=C grep -c "^${rigPdf%% *}	report.pdf$" "$rigScenarioDir/conf/attachments" )$( rigPageBody 'Vendor quote' | LC_ALL=C grep -c -F '<ac:link><ri:attachment ri:filename="report.pdf"/></ac:link>' )" 11

echo "-- Google: HTML in its type folder, image inline, file uploaded beside it, four digits after 999 --"
rigStart google
rigGrant ; rigGoogle '[{"id":"root-1","name":"magic-team","parent":"x"}]' ; rigMarkdown
mkdir -p "$rigScenarioDir/data/audit"
printf -- '---\ntype: artifact\nnumber: PLN-999\nkind: PLN\ntitle: Old plan\nurl: https://x.invalid/\nmember: magic-tester\nsession: -\ndate: 2026-10-01 00:00 +0000\nstate: published\n---\n' > "$rigScenarioDir/data/audit/artifact-20261001T0000Z-pln-999.md"
printf '<html><head><title>x</title></head><body><h1>Plan</h1><p>Chart: <img src="diagram.png" alt="chart"><br>Sheet: <a href="report.pdf">report</a></p></body></html>\n' > "$rigWork/plan.html"
rigCall "$( rigPublishJson plan 'Q4 plan' plan.html )"
rigHolds "$rigScenarioDir/tool.out" 'PUBLISHED:' | grep -q yes || rigRefuse "the Google publish did not complete: $( head -5 "$rigScenarioDir/tool.out" )"
rigUpload(){ ## name -- "<mimeType>|<parent>|<media type>|<file>"
	python3 -c 'import json,sys; [print("%s|%s|%s|%s" % (u["mimeType"], u["parents"][0], u["mediaType"], u["file"])) for u in map(json.loads, open(sys.argv[1])) if u["name"] == sys.argv[2]]' "$rigScenarioDir/google/uploads" "$1"
}
rigFolder="$( python3 -c 'import json,sys; [print(f["id"]) for f in json.load(open(sys.argv[1])) if f["name"] == "PLN" and f["parent"] == "root-1"]' "$rigScenarioDir/google/folders.json" )"
rigAssert "the PLN folder was made under the team folder"   "$( [ -n "$rigFolder" ] && echo made || echo none )" made
rigSheet="$( rigUpload 'PLN-1000 - report.pdf' )"
rigAssert "the linked file is uploaded beside the document" "${rigSheet%|*}" "|$rigFolder|application/pdf"
rigAssert "the image is not uploaded as a file"             "$( rigUpload 'PLN-1000 - diagram.png' )" ""
rigDocUpload="$( rigUpload 'PLN-1000: Q4 plan' )"
rigAssert "PLN-999 is followed by PLN-1000, a Google Doc there" "${rigDocUpload%|*}" "application/vnd.google-apps.document|$rigFolder|text/html; charset=UTF-8"
rigAssert "with its image inline and its link rewritten"    "$( rigHolds "${rigDocUpload##*|}" 'src="data:image/png;base64,' )$( rigHolds "${rigDocUpload##*|}" 'href="https://docs.rig.invalid/file-1"' )" yesyes
rigAssert "only Google was called"                          "$( LC_ALL=C grep -v -c -E '^(GET|POST) https://(oauth2|www)\.googleapis\.com/' "$rigScenarioDir/google/requests" )$( [ -s "$rigScenarioDir/conf/calls" ] && echo conf || echo noconf )" 0noconf
rigAssert "it is recorded, and posted with its link"        "$( rigRecord | LC_ALL=C grep -c '^PLN-1000|PLN|Q4 plan|https://docs.rig.invalid/file-2|magic-tester|rig-child-id$' )$( rigPostHolds 'PLN-1000: Q4 plan' )$( rigPostHolds 'https://docs.rig.invalid/file-2' )" 1yesyes
rigSharedTo(){ ## file id -- the domain of its organisation reader permission, made with supportsAllDrives
	LC_ALL=C awk -v want="$1" '$1 == want && index( $0, "\"role\": \"reader\"" ) && index( $0, "\"type\": \"domain\"" ) && index( $0, "supportsAllDrives=true" ) && match( $0, /"domain": "[^"]*"/ ) { print substr( $0, RSTART + 11, RLENGTH - 12 ) ; }' "$rigScenarioDir/google/permissions" 2>/dev/null
}
rigAssert "the new folder, the uploaded file and the document are each shared with the account organisation" "$( rigSharedTo "$rigFolder" ) $( rigSharedTo file-1 ) $( rigSharedTo file-2 )" "rig-org.example rig-org.example rig-org.example"
rigAssert "the team folder the tooling did not make is left as it is" "$( rigSharedTo root-1 )" ""
printf 'someone@second-org.example\n' > "$rigScenarioDir/google/email"
rigCall "$( rigPublishJson 'meeting notes' 'Weekly sync' plan.html )"
rigAssert "the domain is the account own, read each time"   "$( rigSharedTo folder-3 ) $( rigSharedTo file-4 )" "second-org.example second-org.example"
rigAssert "an untyped kind: no number, in Documents"        "$( rigUpload 'Weekly sync' | awk -F'|' '{ print $1 ; }' )$( python3 -c 'import json,sys; print(len([f for f in json.load(open(sys.argv[1])) if f["name"] == "Documents"]))' "$rigScenarioDir/google/folders.json" )" "application/vnd.google-apps.document1"
rigAssert "recorded with its kind as given"                 "$( rigRecord | LC_ALL=C grep -c '^-|meeting notes|Weekly sync|' )" 1
touch "$rigScenarioDir/google/fail-share"
rigCall "$( rigPublishJson 'meeting notes' 'Unshared note' plan.html )"
rigAssert "a document that cannot be shared is not announced" "$( rigFirstIs 'ERROR: Artifact: the publish did not complete (rc=3)' )$( rigHolds "$rigScenarioDir/tool.out" 'The document exists at https://docs.rig.invalid/' )$( rigHolds "$rigScenarioDir/tool.out" 'not shared with the organisation' )$( rigPostHolds 'Unshared note' )" yesyesyesno
rm -f "$rigScenarioDir/google/fail-share"
rigAssert "no permission was ever for anyone with the link, nor asked to notify" "$( LC_ALL=C grep -c -e '"anyone"' -e 'sendNotificationEmail' "$rigScenarioDir/google/permissions" )" 0
## permission-domain on a folder the tooling did not make, the way a one-off applies it.
printf '%s' 'rigShare(){ local googleClientId="" googleClientSecret="" googleRefreshToken="" googleFileId=root-1 ; set -- ; . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MemberCommsGoogle.include" ; AgentsToolsGoogleResolveMember rig-share magic-tester && AgentsToolsGoogleCall permission-domain ; } ; rigShare' \
	| ( cd "$rigScenarioDir/ws" && env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SESSION_ID TMPDIR="$rigTmp/tmp" RIG_SCENARIO="$rigScenarioDir" \
		PYTHONPATH="$rigScenarioDir/py" PYTHONDONTWRITEBYTECODE=1 MMDAPP="$rigScenarioDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigScenarioDir/data" MDAT_SKILLSET_ROOT="$MDAT_SKILLSET_ROOT" \
		bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-mcp-execute ) > "$rigScenarioDir/share.out" 2> "$rigScenarioDir/share.err"
rigAssert "permission-domain on an existing folder"         "$( LC_ALL=C tr '\n' ' ' < "$rigScenarioDir/share.out" )$( rigSharedTo root-1 )" "PERMISSION_ID=perm-root-1 PERMISSION_DOMAIN=second-org.example second-org.example"
## file-trash as tooling calls it in context, here the way the myx.distro MCP execute runs a script.
printf '%s' 'rigTrash(){ local googleClientId="" googleClientSecret="" googleRefreshToken="" googleFileId=file-2 ; set -- ; . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.MemberCommsGoogle.include" ; AgentsToolsGoogleResolveMember rig-trash magic-tester && AgentsToolsGoogleCall file-trash ; } ; rigTrash' \
	| ( cd "$rigScenarioDir/ws" && env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SESSION_ID TMPDIR="$rigTmp/tmp" RIG_SCENARIO="$rigScenarioDir" \
		PYTHONPATH="$rigScenarioDir/py" PYTHONDONTWRITEBYTECODE=1 MMDAPP="$rigScenarioDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigScenarioDir/data" MDAT_SKILLSET_ROOT="$MDAT_SKILLSET_ROOT" \
		bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-mcp-execute ) > "$rigScenarioDir/trash.out" 2> "$rigScenarioDir/trash.err"
rigAssert "file-trash moves a file to the trash by files.update" "$( LC_ALL=C tr '\n' ' ' < "$rigScenarioDir/trash.out" )$( cat "$rigScenarioDir/google/trashed" 2>/dev/null )" 'FILE_ID=file-2 FILE_TRASHED=true file-2 {"trashed": true}'
rigAssert "and nothing anywhere was deleted"                "$( cat "$rigScenarioDir/google/requests" "$rigTmp"/*/conf/calls 2>/dev/null | LC_ALL=C grep -c '^DELETE ' )" 0

echo "-- two writers on two clones of one team-data origin: a lost push takes the next number --"
command -v git > /dev/null || rigRefuse "git is not installed"
[ -f "${MYXROOT:-}/bin/git/cloneSync.Common" ] || rigRefuse "myx.common git/cloneSync is not reachable through MYXROOT"
rigOrigin="$rigTmp/origin.git"
## The rig repositories only, under no user or system git configuration.
rigGit(){
	env GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_AUTHOR_NAME=rig GIT_AUTHOR_EMAIL=rig@example.invalid \
		GIT_COMMITTER_NAME=rig GIT_COMMITTER_EMAIL=rig@example.invalid git "$@"
}
rigGit init -q --bare "$rigOrigin" && rigGit -C "$rigOrigin" symbolic-ref HEAD refs/heads/main || rigRefuse "could not make the rig origin"
rigGit clone -q "$rigOrigin" "$rigTmp/seed" 2> /dev/null && printf 'rig team data\n' > "$rigTmp/seed/README.md" \
	&& rigGit -C "$rigTmp/seed" add -A && rigGit -C "$rigTmp/seed" commit -q -m seed && rigGit -C "$rigTmp/seed" push -q origin HEAD:main \
	|| rigRefuse "could not seed the rig origin"
rigWriter(){ ## scenario name -- a workspace whose team data is its own clone of the origin
	rigStart "$1"
	rigConfluence ; rigTeam CONFLUENCE_SPACE=TEAM ; rigTeam "TEAM_DATA_GIT_REMOTE=$rigOrigin" ; rigMarkdown
	rmdir "$rigScenarioDir/data" && rigGit clone -q "$rigOrigin" "$rigScenarioDir/data" || rigRefuse "could not clone the rig origin for $1"
}
rigPublishAs(){ ## scenario name, title, output name -- the operation itself, as a member of that workspace
	local asDir="$rigTmp/$1"
	( cd "$asDir/ws" && env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SESSION_ID \
		GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_AUTHOR_NAME=rig GIT_AUTHOR_EMAIL=rig@example.invalid GIT_COMMITTER_NAME=rig GIT_COMMITTER_EMAIL=rig@example.invalid \
		TMPDIR="$rigTmp/tmp" RIG_SCENARIO="$asDir" RIG_FIXTURES="$rigTest/check-fixtures" RIG_CURL_LOG="$asDir/curl.log" PYTHONPATH="$asDir/py" PYTHONDONTWRITEBYTECODE=1 \
		MMDAPP="$asDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MYXROOT="$MYXROOT" MDAT_DATA_ROOT="$asDir/data" MDAT_SKILLSET_ROOT="$MDAT_SKILLSET_ROOT" \
		bash "$rigTool" --intern-artifact-publish "$rigMember" --title "$2" --kind ADR --document "$asDir/ws/.local/temp/member/$rigMember/doc.md" \
			--file "$asDir/ws/.local/temp/member/$rigMember/diagram.png" --session-id "rig-$1" ) > "$asDir/$3.out" 2> "$asDir/$3.err"
}
rigTitleOf(){ ## scenario name, output name
	LC_ALL=C sed -n 's/^ARTIFACT_TITLE=//p' "$rigTmp/$1/$2.out"
}
rigOriginRecords(){ ## the published records the origin holds, numbers sorted
	rm -rf "$rigTmp/check" && rigGit clone -q "$rigOrigin" "$rigTmp/check" 2> /dev/null && rigRecord "$rigTmp/check" | LC_ALL=C sort
}
rigWriter writerA
rigWriter writerB
rigPublishAs writerA First a1
rigAssert "writer A takes ADR-001"                          "$( rigTitleOf writerA a1 )" "ADR-001: First"
rigPublishAs writerB Second b1
rigAssert "writer B, whose clone is behind, loses ADR-001 at the push and takes ADR-002" "$( rigTitleOf writerB b1 )$( rigHolds "$rigTmp/writerB/b1.err" 'ADR-001 was taken by another writer first' )" "ADR-002: Secondyes"
rigAssert "and published nothing under the lost number"     "$( python3 -c 'import json,sys; print(sorted(p["title"] for p in json.load(open(sys.argv[1])) if p["title"].startswith("ADR-0")))' "$rigTmp/writerB/conf/pages.json" )" "['ADR-002: Second']"
( rigPublishAs writerA 'Third from A' a2 ) &
rigPidA=$!
( rigPublishAs writerB 'Third from B' b2 ) &
rigPidB=$!
wait "$rigPidA" ; wait "$rigPidB"
rigAssert "two writers at once take two numbers, ADR-003 and ADR-004" "$( { rigTitleOf writerA a2 ; rigTitleOf writerB b2 ; } | LC_ALL=C sed 's/:.*//' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "ADR-003 ADR-004 "
touch "$rigTmp/writerA/conf/fail-create"
rigPublishAs writerA 'Fails' a3
rigAssert "a publish that fails releases its number"        "$( rigTitleOf writerA a3 )$( rigHolds "$rigTmp/writerA/a3.err" 'ADR-005 is released' )" "yes"
rm -f "$rigTmp/writerA/conf/fail-create"
rigPublishAs writerA 'Fifth' a4
rigAssert "so the next publish takes it"                    "$( rigTitleOf writerA a4 )" "ADR-005: Fifth"
rigAssert "the origin holds each number once, every one published" "$( rigOriginRecords | LC_ALL=C cut -d'|' -f1,3 | LC_ALL=C sed 's/Third from [AB]/Third/' | LC_ALL=C tr '\n' ' ' )" "ADR-001|First ADR-002|Second ADR-003|Third ADR-004|Third ADR-005|Fifth "

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ARTIFACT PUBLISH CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ARTIFACT_PUBLISH: OK (%d assertions, offline)\n' "$rigPassCount"
