#!/usr/bin/env bash
## Behavioural check on the LOCAL LEG (AgentsLocalHarness.sh), like the other legs': it is a harness leg the console finds by
## its file, it speaks the OpenAI chat wire to a local server, it needs no credential, its macros resolve to the smaller and
## the larger qwen3 chat model, its limits come from the one open-model table, and its one tooling read, --list-models, lists
## the models the server really has installed with the machine profile and the limits of each.
## Offline: the local server is a fake `curl` first on PATH; nothing here reaches a network.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
leg="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsLocalHarness.sh"
[ -f "$leg" ] || { echo "⛔ ERROR: the local leg is not there: $leg" >&2 ; exit 1 ; }
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsLocalLegCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/home" "$rigTmp/bin"

pass=0 fail=0
check(){ ## name, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; pass=$(( pass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; fail=$(( fail + 1 )) ; fi
}

echo "-- the leg declares the service and nothing else --"
check "the console can find it: a provider name is declared" "$( LC_ALL=C grep -c '^HARNESS_PROVIDER_NAME=' "$leg" )" 1
check "the leg is executable, because it is run as a program" "$( [ -x "$leg" ] && printf yes || printf no )" yes
check "it speaks the OpenAI chat wire" "$( LC_ALL=C grep -c '^HARNESS_WIRE="OpenAiChat"' "$leg" )" 1
check "it needs no credential: a literal stands in for the token the core wants" "$( LC_ALL=C grep -c 'HARNESS_TOKEN_MAIN="${LOCAL_AI_API_KEY:-local}"' "$leg" )" 1
check "the macros resolve to the agreed Qwen3.5 4B and 9B, by their served ids" \
	"$( LC_ALL=C grep -c -e '^HARNESS_MODEL_LIGHT="${HARNESS_MODEL_LIGHT:-qwen3.5-4b-q8_0}"' -e '^HARNESS_MODEL_MAIN="${HARNESS_MODEL_MAIN:-qwen3.5-9b-q8_0}"' "$leg" )" 2
check "its table is the one open-model table, stated once" "$( LC_ALL=C grep -c 'AgentsHarnessOpenModelTable' "$leg" )" 1

echo "-- the tooling read: the models that are installed --"
cat > "$rigTmp/bin/curl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
	*rig-down*) exit 7 ;;
esac
printf '{"object":"list","data":[{"id":"qwen3-4b","object":"model"},{"id":"qwen3:8b","object":"model"},{"id":"Qwen3-14B","object":"model"},{"id":"mystery-model-9","object":"model"}]}'
EOF
chmod +x "$rigTmp/bin/curl"
runLeg(){ ## environment pairs, then the arguments
	( cd "$( dirname "$leg" )" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MDLT_ORIGIN="$MDLT_ORIGIN" "$@" bash "$leg" --list-models ) 2> /dev/null
}
check "the list: model, profile, window, output and the none form, one model a line" \
	"$( runLeg HARNESS_ENDPOINT_URL=http://rig.invalid/v1 | tr '\t' ',' | tr '\n' ' ' )" \
	"qwen3-4b,1,32768,4096,thinking:disabled qwen3:8b,2,32768,8192,thinking:disabled Qwen3-14B,3,32768,8192,thinking:disabled mystery-model-9,-,32768,8192,omit "
check "a server that cannot be reached lists nothing and ends 1" \
	"$( runLeg HARNESS_ENDPOINT_URL=http://rig-down.invalid/v1 > /dev/null ; echo "$?" )" 1

echo "-- the run itself: no credential, the default local endpoint and the smaller and larger qwen3 as they stand --"
## The greps above only read the leg. Here it runs: a fake curl first on PATH (the fixture the harness checks share) keeps the
## request body and the curl arguments, and replays one canned OpenAI-chat stream. Nothing reaches a network.
rigScn="$rigTmp/scn" ; mkdir -p "$rigTmp/bin2" "$rigScn" "$rigTmp/work"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "%s/curl.argv"\nexec bash "%s" "$@"\n' "$rigTmp" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/harness-restart-check.curl.stub.sh" > "$rigTmp/bin2/curl"
chmod +x "$rigTmp/bin2/curl"
printf '0' > "$rigScn/round" ; : > "$rigTmp/curl.argv"
printf 'data: {"choices":[{"index":0,"delta":{"content":"RIG-LOCAL-ANSWER"},"finish_reason":"stop"}],"usage":{"prompt_tokens":5,"completion_tokens":3,"total_tokens":8}}\ndata: [DONE]\n' > "$rigScn/res.1"
rigRc="$( cd "$rigTmp/work" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin2:/usr/bin:/bin:/usr/sbin:/sbin" MDLT_ORIGIN="$MDLT_ORIGIN" MMDAPP="$MMDAPP" RIG_SCENARIO="$rigScn" \
	bash "$leg" --access-root "$rigTmp/work" "rig prompt" > "$rigTmp/run.out" 2> "$rigTmp/run.err" ; echo $? )"
check "with no endpoint, no model and no credential set it runs and ends 0" "$rigRc" 0
check "the answer is the output, after exactly one request" "$( LC_ALL=C grep -c 'RIG-LOCAL-ANSWER' "$rigTmp/run.out" ) $( cat "$rigScn/round" )" "1 1"
check "the request names the larger model by default" "$( LC_ALL=C grep -c '^{"model":"qwen3.5-9b-q8_0"' "$rigScn/req.1" )" 1
check "and goes to the local server's own address" "$( LC_ALL=C grep -c -F '127.0.0.1:8181/v1' "$rigTmp/curl.argv" )" 1
echo "-- the tooling operation that calls the read --"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
check "the operation is in the table of the tool files, in DistroAgentsKnowledge, for any member" \
	"$( LC_ALL=C grep -c -x 'DistroAgentsKnowledge	--local-models-list	member' "$rigPackage/sh-lib/harness/AgentsContext.FrontTable.include" )" 1
check "the tool file calls the leg's read, with the rc passed through" \
	"$( LC_ALL=C grep -c 'AgentsLocalHarness.sh" --list-models' "$rigPackage/sh-scripts/DistroAgentsKnowledge.fn.sh" )" 1
check "its syntax line stands in the help, in the list and in the manual" \
	"$( LC_ALL=C grep -c -F -e 'DistroAgentsKnowledge.fn.sh --local-models-list' "$rigPackage/sh-lib/help/Help.DistroAgentsTools.include" "$rigPackage/sh-lib/help/Help.DistroAgentsTools.help.md" | LC_ALL=C awk -F: '{ n += $NF } END { print n }' )" 2

if [ "$fail" = 0 ] ; then printf 'LOCAL_LEG: OK (%s assertions, offline)\n' "$pass" ; exit 0 ; fi
printf '⛔ LOCAL_LEG CHECK FAILED: %s of %s assertion(s)\n' "$fail" "$(( pass + fail ))" ; exit 1
