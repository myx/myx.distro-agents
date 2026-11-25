#!/usr/bin/env bash
## Behavioural check on the LOCAL LEG's one tooling read, `--list-models`: it sends the credential its leg declares on
## curl's stdin and never in argv, and every way the read can fail names its own cause instead of exiting 1 in silence.
## Offline: curl is a stand-in first on PATH, which records the header lines and the argv it was handed. It replays real
## curl 8.7.1 as measured here, its two load-bearing options included: -f suppresses a refused status's body, and -w
## prints the status only where the caller's arguments ask for it. A refused status ends rc 22, a server that never
## answers rc 28, an unreachable one rc 7, a closed answer rc 52, and a served answer rc 0.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
leg="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsLocalHarness.sh"
[ -f "$leg" ] || { echo "⛔ ERROR: the local leg is not there: $leg" >&2 ; exit 1 ; }
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsLocalModelsCausesCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/home" "$rigTmp/bin"

pass=0 fail=0
check(){ ## name, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; pass=$(( pass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; fail=$(( fail + 1 )) ; fi
}

cat > "$rigTmp/bin/curl" <<'EOF'
#!/usr/bin/env bash
## The stand-in: what curl was handed, then the answer its endpoint name carries. It honours the two options the read's
## correctness rests on, so dropping either of them from the leg shows up here: -f suppresses a refused status's body, and
## -w prints the status the server answered, in the format the caller named.
cat > "$RIG_CURL_STDIN"
printf '%s\n' "$*" > "$RIG_CURL_ARGV"
codeFmt="" prevArg="" withF=no
for arg in "$@" ; do
	[ "$prevArg" != "-w" ] || codeFmt="$arg"
	prevArg="$arg"
	case "$arg" in --*) ;; -*) case "${arg#-}" in *f*) withF=yes ;; esac ;; esac
done
answered(){ ## status, body, rc: real curl's own behaviour, its two load-bearing options included
	## -f turns a refused HTTP status into rc 22 with no body, where the same answer without it prints its body and ends 0.
	## A transport failure carries no HTTP status at all, so -f changes nothing there and the command's own rc stands.
	case "$1" in
		2[0-9][0-9])
			printf '%s' "$2"
			case "$codeFmt" in *'%{http_code}'*) printf "${codeFmt%%'%{http_code}'*}" ; printf '%s' "$1" ;; esac
			exit 0
		;;
		[3-5][0-9][0-9])
			case "$codeFmt" in *'%{http_code}'*) printf "${codeFmt%%'%{http_code}'*}" ; printf '%s' "$1" ;; esac
			[ "$withF" = yes ] && exit 22
			printf '%s' "$2"
			exit 0
		;;
	esac
	case "$codeFmt" in *'%{http_code}'*) printf "${codeFmt%%'%{http_code}'*}" ; printf '%s' "$1" ;; esac
	exit "$3"
}
case "$*" in
	*rig-401.invalid*) answered 401 '{"error":{"message":"no credential"}}' 22 ;;
	*rig-403.invalid*) answered 403 '{"error":{"message":"denied"}}' 22 ;;
	*rig-404.invalid*) answered 404 '{"error":{"message":"no such path"}}' 22 ;;
	*rig-500.invalid*) answered 500 '{"error":{"message":"boom"}}' 22 ;;
	*rig-empty.invalid*) answered 200 '{"object":"list","data":[]}' 0 ;;
	*rig-nostatus.invalid*) printf '{"object":"list","data":[{"id":"qwen3-4b","object":"model"},{"id":"qwen3:8b","object":"model"}]}' ; exit 0 ;;
	*rig-slow.invalid*) answered 000 '' 28 ;;
	*rig-down.invalid*) answered 000 '' 7 ;;
	*rig-shut.invalid*) answered 000 '' 52 ;;
esac
answered 200 '{"object":"list","data":[{"id":"qwen3-4b","object":"model"},{"id":"qwen3:8b","object":"model"}]}' 0
EOF
chmod +x "$rigTmp/bin/curl"

legRc=0
runLeg(){ ## the endpoint's host name; stdout in $rigTmp/out, stderr in $rigTmp/err, the leg's rc in legRc
	: > "$rigTmp/stdin" ; : > "$rigTmp/argv" ; : > "$rigTmp/out" ; : > "$rigTmp/err"
	( cd "$( dirname "$leg" )" \
		&& env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
			MDLT_ORIGIN="$MDLT_ORIGIN" RIG_CURL_STDIN="$rigTmp/stdin" RIG_CURL_ARGV="$rigTmp/argv" \
			LOCAL_AI_API_KEY=rig-token HARNESS_ENDPOINT_URL="http://$1/v1" bash "$leg" --list-models < /dev/null ) \
		> "$rigTmp/out" 2> "$rigTmp/err"
	legRc=$?
}
oneCauseLine(){ ## the case name -- asserts exactly one cause line, then keeps it as $rigTmp/err.<name>
	check "$1: one cause line, and only one" "$( wc -l < "$rigTmp/err" | tr -d ' ' )" 1
	cp "$rigTmp/err" "$rigTmp/err.$1"
}

echo "-- the read lists, so a cause line costs no model row --"
runLeg rig-models.invalid
check "the served answer ends 0" "$legRc" 0
check "two models, one a line" "$( wc -l < "$rigTmp/out" | tr -d ' ' )" 2
check "the first row is qwen3-4b's, with its profile and limits" "$( LC_ALL=C grep -c '^qwen3-4b[[:space:]]' "$rigTmp/out" )" 1
check "the second row is qwen3:8b's" "$( LC_ALL=C grep -c '^qwen3:8b[[:space:]]' "$rigTmp/out" )" 1

echo "-- the credential the leg declares reaches the server, and only on curl's stdin --"
check "an Authorization line is handed to curl on its stdin" "$( LC_ALL=C grep -c '^Authorization: Bearer ' "$rigTmp/stdin" )" 1
check "the token is the one the environment names, not the leg's own default" "$( LC_ALL=C grep -c '^Authorization: Bearer rig-token$' "$rigTmp/stdin" )" 1
check "no credential reaches curl's argv" "$( LC_ALL=C grep -c 'rig-token\|Authorization' "$rigTmp/argv" )" 0

echo "-- an answer carrying no status line still lists its models --"
runLeg rig-nostatus.invalid
check "it ends 0" "$legRc" 0
check "both models list, so no row is lost to the missing status" "$( wc -l < "$rigTmp/out" | tr -d ' ' )" 2

echo "-- a credential the server will not take reads the line that says so --"
runLeg rig-401.invalid
check "a 401 ends 1" "$legRc" 1
check "the refused answer's body prints no model row" "$( wc -c < "$rigTmp/out" | tr -d ' ' )" 0
check "its line names the status the server answered" "$( LC_ALL=C grep -c '401' "$rigTmp/err" )" 1
check "its line says the credential was not accepted" "$( LC_ALL=C grep -c 'did not accept' "$rigTmp/err" )" 1
oneCauseLine 401

runLeg rig-403.invalid
check "a 403 ends 1" "$legRc" 1
check "a 403 reads the same credential line, since it is a refusal of it" "$( LC_ALL=C grep -c 'did not accept' "$rigTmp/err" )" 1
check "its line names the status it answered" "$( LC_ALL=C grep -c '403' "$rigTmp/err" )" 1
oneCauseLine 403

echo "-- a status that is not about the credential reads its own line --"
runLeg rig-404.invalid
check "a 404 ends 1" "$legRc" 1
check "its line names the status the server answered" "$( LC_ALL=C grep -c '404' "$rigTmp/err" )" 1
check "and does not blame the credential" "$( LC_ALL=C grep -c 'did not accept' "$rigTmp/err" )" 0
oneCauseLine 404

runLeg rig-500.invalid
check "a 500 ends 1" "$legRc" 1
check "its line names the status the server answered" "$( LC_ALL=C grep -c '500' "$rigTmp/err" )" 1
check "and does not blame the credential" "$( LC_ALL=C grep -c 'did not accept' "$rigTmp/err" )" 0
oneCauseLine 500

echo "-- a server that accepts and never answers reads its own line --"
runLeg rig-slow.invalid
check "the wait ends 1" "$legRc" 1
check "its line names the wait" "$( LC_ALL=C grep -c 'did not answer in time' "$rigTmp/err" )" 1
oneCauseLine slow

echo "-- a server that cannot be reached reads its own line --"
runLeg rig-down.invalid
check "the refused connection ends 1" "$legRc" 1
check "its line names the connection" "$( LC_ALL=C grep -c 'could not be reached' "$rigTmp/err" )" 1
oneCauseLine down

echo "-- a curl failure the four do not name reads a line of its own --"
runLeg rig-shut.invalid
check "an answer that closed unread ends 1" "$legRc" 1
check "it carries curl's own rc, so the reader can look it up" "$( LC_ALL=C grep -c 'rc=52' "$rigTmp/err" )" 1
oneCauseLine shut

echo "-- an answer that names no model reads a line saying so --"
runLeg rig-empty.invalid
check "an empty list ends 1" "$legRc" 1
check "nothing is printed on stdout" "$( wc -c < "$rigTmp/out" | tr -d ' ' )" 0
check "its line says the answer named no model" "$( LC_ALL=C grep -c 'named no model' "$rigTmp/err" )" 1
oneCauseLine empty

echo "-- the cause lines are all different, and none is empty --"
causes="$( cat "$rigTmp"/err.401 "$rigTmp"/err.403 "$rigTmp"/err.404 "$rigTmp"/err.500 "$rigTmp"/err.slow "$rigTmp"/err.down "$rigTmp"/err.shut "$rigTmp"/err.empty )"
check "eight causes, eight distinct lines" "$( printf '%s\n' "$causes" | LC_ALL=C sort -u | wc -l | tr -d ' ' )" 8
check "each line is a sentence, not an empty one" "$( printf '%s\n' "$causes" | LC_ALL=C awk 'length($0) > 20 { n++ ; } END { print n + 0 ; }' )" 8

if [ "$fail" = 0 ] ; then printf 'LOCAL_MODELS_CAUSES: OK (%s assertions, offline)\n' "$pass" ; exit 0 ; fi
printf '⛔ LOCAL_MODELS_CAUSES CHECK FAILED: %s of %s assertion(s)\n' "$fail" "$(( pass + fail ))" ; exit 1
