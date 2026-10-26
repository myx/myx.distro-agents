#!/usr/bin/env bash
## Behavioural check on the key: value forms of setup.feature-local-ai (mdci-packages-myx): `mdci-local-ai check --parse`, `install --dry-run --parse`,
## `uninstall --dry-run`, `ask` and `transcribe`, and the check fragment host/install/feature-local-ai.2.check.txt with MDCI_CHECK_PARSE=1, which the console's
## optional features read (--manager-feature-list). The command is the real one, a copy of it with its one fixed data folder pointed into the rig (the constant stays
## a constant in the package; only the copy is changed), a manifest of three small models beside it, and stand-ins for curl, llama-server and whisper-server on a PATH of
## the rig. Nothing is installed, downloaded or served, no request leaves the rig, and no file of the package is written. Held:
##   1. check --parse: the first line is the feature (broken while a model is of the wrong size, installed when it is whole, not installed where nothing is there);
##      each model of the manifest has its part, state, bytes on disk, bytes expected, memory and whether it runs; a broken one says why; the exit is the human check's
##   2. the human check is as it was: the same report, no key: value line in it
##   3. install --dry-run --parse says the packages, the models, the download, the free space and the memory, and whether it is blocked and why; uninstall --dry-run says
##      what would be removed and how much is freed; neither changes a file
##   4. ask puts the prompt on the standard input of curl and never on its command line, escapes it, and refuses a model that is not an installed chat model;
##      transcribe sends a file, or the one second of silence it makes and removes
##   5. the check fragment: with MDCI_CHECK_PARSE=1 the key: value lines on standard output and the status of the check; without it the human report on standard error and 0
##   6. the check fragment of setup.feature-lancedb prints `lancedb:` first, in a home that is not there
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigFeature="$MDLT_ORIGIN/myx/mdci-packages-myx/setup.feature-local-ai"
rigLancedb="$MDLT_ORIGIN/myx/mdci-packages-myx/setup.feature-lancedb"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigFeature/data/local-ai/mdci-local-ai" "$rigFeature/host/install/feature-local-ai.2.check.txt" "$rigLancedb/host/install/feature-lancedb.check.txt" ; do
	[ -f "$rigFile" ] || rigRefuse "not in the origin this workspace resolves: $rigFile"
done
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsLocalAiCheckParse )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}

## THE RIG: the command with its data folder in the rig, in a folder of its own with a manifest and an rc.d (so it reads its source there), as the staged copy stands.
rigData="$rigTmp/data" rigFiles="$rigTmp/files" rigStubs="$rigTmp/stubs"
rigTool="$rigFiles/local-ai/mdci-local-ai"
mkdir -p "$rigFiles/local-ai/rc.d" "$rigStubs" "$rigData/models" "$rigData/stt" "$rigData/state" "$rigData/run"
LC_ALL=C sed -e "s|^LAI_DATA=.*|LAI_DATA=$rigData|" -e "s|^LAI_BIN=.*|LAI_BIN=$rigTmp/sbin/mdci-local-ai|" "$rigFeature/data/local-ai/mdci-local-ai" > "$rigTool"
chmod +x "$rigTool"
[ "$( LC_ALL=C grep -c -x "LAI_DATA=$rigData" "$rigTool" )" = 1 ] || rigRefuse "the command has no line LAI_DATA= to point into the rig"
rigTab="$( printf '\t' )"
{
	printf '# id\tpart\tfamily\tparams\tquant\tprofiles\tfile\tsize_bytes\tsha256\turl\n'
	printf 'chat-a\tchat\tqwen3\t4B\tq4\tshared-cpu*\tchat-a.gguf\t100\t%s\thttps://rig.invalid/chat-a\n' "$( printf 'a%.0s' $(seq 1 64) )"
	printf 'chat-b\tchat\tqwen3\t8B\tq4\tbig-cpu*\tchat-b.gguf\t200\t%s\thttps://rig.invalid/chat-b\n' "$( printf 'b%.0s' $(seq 1 64) )"
	printf 'stt-a\tstt\twhisper\tsmall\tq5\tall*\tstt-a.bin\t50\t%s\thttps://rig.invalid/stt-a\n' "$( printf 'c%.0s' $(seq 1 64) )"
	printf 'huge\tchat\tqwen3\t99B\tq4\tgpu\thuge.gguf\t4000000000000000000\t%s\thttps://rig.invalid/huge\n' "$( printf 'd%.0s' $(seq 1 64) )"
} > "$rigFiles/local-ai/models.tsv"
## stand-ins: curl logs its arguments and its standard input, and answers by the address; the servers are present or not by being on the PATH
cat > "$rigStubs/curl" <<- 'EOF'
	#!/bin/sh
	printf '%s\n' "$*" >> "$RIG_LOG/curl.args"
	case "$*" in
		*--data-binary*) cat > "$RIG_LOG/curl.body" ;;
	esac
	case "$*" in
		*/v1/chat/completions*) printf '{"choices":[{"message":{"content":"pong"}}]}' ;;
		*/inference*) printf '{"text":" hello"}' ;;
	esac
	exit 0
EOF
printf '#!/bin/sh\nexit 0\n' > "$rigStubs/llama-server"
chmod +x "$rigStubs"/*
rigLog="$rigTmp/log" ; mkdir -p "$rigLog"
rigRun(){ ## input file, command and arguments... -- the command with the rig PATH; rc in rigRc, standard output in out, standard error in err
	local runInput="$1" ; shift
	rigRc=0
	env -i HOME="$rigTmp" PATH="$rigPath" RIG_LOG="$rigLog" MDCI_FILES_PATH="$rigFiles" "$@" > "$rigTmp/out" 2> "$rigTmp/err" < "$runInput" || rigRc=$?
}
rigPath="$rigStubs:/usr/bin:/bin:/usr/sbin:/sbin"
rigNoEngines="/usr/bin:/bin:/usr/sbin:/sbin"
rigKv(){ ## key -- the value of that key in the last standard output
	LC_ALL=C awk -v wanted="$1" '{ at = index( $0, ": " ) ; if ( at > 0 && substr( $0, 1, at - 1 ) == wanted ) { print substr( $0, at + 2 ) ; exit } }' "$rigTmp/out"
}
rigTree(){ ## -- every file under the data folder with its size, sorted: what a read must leave as it is
	( cd "$rigData" && find . -type f -exec wc -c {} + | LC_ALL=C sort | LC_ALL=C tr -s ' ' )
}
printf '%0100d' 0 > "$rigData/models/chat-a.gguf" ; printf 'a' > "$rigData/state/chat-a.ok"
head -c 150 /dev/zero > "$rigData/models/chat-b.gguf" ; printf 'b' > "$rigData/state/chat-b.ok"

echo "-- 1. check --parse --"
rigTreeBefore="$( rigTree )"
rigRun /dev/null "$rigTool" check --parse
rigAssert "a model of the wrong size: the feature is broken, and the exit says so" "$rigRc $( sed -n 1p "$rigTmp/out" )" "1 local-ai: broken"
rigAssert "chat-a is whole: installed, its bytes on disk and expected, the memory a chat model takes (its file and a sixth), and running, the chat server being up" "$( rigKv part.chat-a.state ) $( rigKv part.chat-a.disk_bytes ) $( rigKv part.chat-a.expected_bytes ) $( rigKv part.chat-a.memory_bytes ) $( rigKv part.chat-a.running ) $( rigKv part.chat-a.part )" "installed 100 100 116 yes chat"
rigAssert "chat-b is not: broken, with its reason, the file it has and the file it should have, and it does not run" "$( rigKv part.chat-b.state ) | $( rigKv part.chat-b.why ) | $( rigKv part.chat-b.disk_bytes ) $( rigKv part.chat-b.expected_bytes ) $( rigKv part.chat-b.running )" "broken | the file size differs from the manifest | 150 200 no"
rigAssert "stt-a is not there: not installed, nothing on disk, the memory it would take (its file), not running" "$( rigKv part.stt-a.state ) $( rigKv part.stt-a.disk_bytes ) $( rigKv part.stt-a.memory_bytes ) $( rigKv part.stt-a.running )" "not installed 0 50 no"
rigAssert "every model of the manifest has its six keys, and the engines say what they are" "$( LC_ALL=C grep -c '^part\.[a-z0-9-]*\.\(part\|state\|disk_bytes\|expected_bytes\|memory_bytes\|running\): ' "$rigTmp/out" ) $( rigKv engine.chat.state ) $( rigKv engine.stt.state ) $( rigKv engine.stt.path )" "24 running absent none"
rigAssert "the host and the data folder: the folder is the rig's, set up, with the profile and the bytes free" "$( rigKv host.data | LC_ALL=C sed "s|^$rigData\$|rig|" ) $( rigKv setup ) $( rigKv host.profile ) $( rigKv host.free_bytes | LC_ALL=C awk '{ print ( $1 > 0 ) ? "free" : "none" }' )" "rig yes shared-cpu free"
rigAssert "every line is key: value, and nothing but them is on standard output" "$( LC_ALL=C grep -c -v '^[A-Za-z0-9._-]*: ' "$rigTmp/out" || : )" "0"
rigAssert "a check changes nothing" "$( rigTree | LC_ALL=C cksum )" "$( printf '%s\n' "$rigTreeBefore" | LC_ALL=C cksum )"
rm -f "$rigData/models/chat-b.gguf" "$rigData/state/chat-b.ok" "$rigData/state/chat-a.ok"
rigRun /dev/null "$rigTool" check --parse
rigAssert "a file with no verified marker is broken, and says so; the marker is what makes it installed" "$rigRc $( sed -n 1p "$rigTmp/out" ) | $( rigKv part.chat-a.state ): $( rigKv part.chat-a.why ) | $( rigKv part.chat-b.state )" "1 local-ai: broken | broken: the file has no verified marker | not installed"
printf 'a' > "$rigData/state/chat-a.ok"
rigRun /dev/null "$rigTool" check --parse
rigAssert "whole, and its server up: the feature is installed and the exit is 0" "$rigRc $( sed -n 1p "$rigTmp/out" )" "0 local-ai: installed"
rigPath="$rigNoEngines"
rigRun /dev/null "$rigTool" check --parse
rigAssert "a model whole and no server on the host: installed, not running, and no exit for it (the human check does not fail it either)" "$rigRc $( sed -n 1p "$rigTmp/out" ) $( rigKv part.chat-a.running ) $( rigKv engine.chat.state )" "0 local-ai: installed no absent"
rm -f "$rigData/models/chat-a.gguf" "$rigData/state/chat-a.ok"
rigRun /dev/null "$rigTool" check --parse
rigAssert "nothing installed and no engine: not installed, and the exit is 0" "$rigRc $( sed -n 1p "$rigTmp/out" )" "0 local-ai: not installed"
rigPath="$rigStubs:/usr/bin:/bin:/usr/sbin:/sbin"
rigRun /dev/null env LAI_NOTHING=1 "$rigTool" check --parse --no-such
rigAssert "an option it does not know is refused in one line" "$rigRc $( LC_ALL=C grep -c -F -- '⛔ ERROR: local-ai: check: unknown option --no-such' "$rigTmp/err" ) $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" "1 1 0"
printf '%0100d' 0 > "$rigData/models/chat-a.gguf" ; printf 'a' > "$rigData/state/chat-a.ok"

echo "-- 2. the human check is as it was --"
rigRun /dev/null "$rigTool" check
rigAssert "the report: the host, the part, the model with its size and the verdict, the endpoint; not one key: value line" "$rigRc $( LC_ALL=C grep -c -x -e '== host' -e '== chat' -e '  model:    chat-a  0 MB  size-ok' "$rigTmp/out" ) $( LC_ALL=C grep -c '^[a-z.-]*: ' "$rigTmp/out" || : )" "0 3 0"

echo "-- 3. the plans --"
rigTreeBefore="$( rigTree )"
rigRun /dev/null "$rigTool" install --dry-run --parse chat-engine chat-b
rigAssert "install: the engine that is there, the model that is not, the download, the memory the model wants (its file and a sixth), the space and the memory of the host, not blocked" "$rigRc | $( rigKv plan.present ) | $( rigKv plan.model ) | $( rigKv plan.download_bytes ) $( rigKv plan.ram_need_bytes ) $( rigKv plan.blocked )" "0 | engine chat | chat-b 200 | 200 233 no"
rigAssert "and the free space and the memory are numbers" "$( rigKv plan.free_bytes | LC_ALL=C awk '{ print ( $1 > 0 ) ? "n" : "x" }' )$( rigKv plan.ram_bytes | LC_ALL=C awk '{ print ( $1 > 0 ) ? "n" : "x" }' )" "nn"
rigRun /dev/null "$rigTool" install --parse chat-a chat-b
rigAssert "a model that is installed is said to be there and not fetched again: --parse is a plan and implies --dry-run" "$( rigKv plan.present ) | $( rigKv plan.model ) | $( rigKv plan.download_bytes )" "model chat-a | chat-b 200 | 200"
rigRun /dev/null "$rigTool" install --dry-run --parse huge
rigAssert "more than the host has free: blocked, with the reason, and the exit is still 0 (the plan is the answer)" "$rigRc $( rigKv plan.blocked ) | $( rigKv plan.why )" "0 yes | not enough free space in $rigData"
rigRun /dev/null "$rigTool" install --dry-run --parse nothing
rigAssert "a model that is none: blocked, and said" "$( rigKv plan.blocked ) | $( rigKv plan.why )" "yes | unknown model nothing"
rigRun /dev/null "$rigTool" uninstall --dry-run chat-a
rigAssert "uninstall: the file that would go with its bytes, what is freed, nothing blocked" "$rigRc | $( rigKv plan.remove ) | $( rigKv plan.reclaim_bytes ) $( rigKv plan.blocked )" "0 | chat-a 100 | 100 no"
rigRun /dev/null "$rigTool" uninstall --parse chat-b
rigAssert "a model that is not there frees nothing, and removes nothing" "$( rigKv plan.reclaim_bytes ) $( LC_ALL=C grep -c '^plan.remove' "$rigTmp/out" || : )" "0 0"
rigRun /dev/null "$rigTool" uninstall --dry-run nothing
rigAssert "a name that is none is refused" "$rigRc $( LC_ALL=C grep -c -F -- 'unknown part or model nothing' "$rigTmp/err" )" "1 1"
rigAssert "no plan changes a file" "$( rigTree | LC_ALL=C cksum )" "$( printf '%s\n' "$rigTreeBefore" | LC_ALL=C cksum )"

echo "-- 4. ask, transcribe --"
: > "$rigLog/curl.args"
printf 'say "hello"\nsecond \\ line\twith a tab\n' > "$rigTmp/prompt"
rigRun "$rigTmp/prompt" "$rigTool" ask chat-a 64
rigAssert "ask: the answer of the server as it is, on standard output" "$rigRc $( cat "$rigTmp/out" )" '0 {"choices":[{"message":{"content":"pong"}}]}'
rigAssert "the body went on standard input of curl, escaped: the model, the token limit, the quote, the newline, the backslash and the tab" "$( cat "$rigLog/curl.body" )" '{"model":"chat-a","max_tokens":64,"messages":[{"role":"user","content":"say \"hello\"\nsecond \\ line\twith a tab"}]}'
rigAssert "and nothing of the prompt is on any command line, where every user of the host reads it" "$( LC_ALL=C grep -c -e hello -e second "$rigLog/curl.args" || : )" "0"
rigRun "$rigTmp/prompt" "$rigTool" ask stt-a
rigAssert "a model that is not an installed chat model is refused" "$rigRc $( LC_ALL=C grep -c -F -- '⛔ ERROR: local-ai: ask: stt-a is not an installed chat model' "$rigTmp/err" ) $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" "1 1 0"
rigRun /dev/null "$rigTool" ask chat-a
rigAssert "an empty prompt is refused" "$rigRc $( LC_ALL=C grep -c -F -- '⛔ ERROR: local-ai: ask: the prompt is empty' "$rigTmp/err" )" "1 1"
rigRun /dev/null "$rigTool" transcribe
rigAssert "transcribe with no speech server: refused, said, and no silence left in the run folder" "$rigRc $( LC_ALL=C grep -c -F -- 'transcribe: the speech endpoint' "$rigTmp/err" ) $( ls "$rigData/run" | LC_ALL=C grep -c . || : )" "1 1 0"
printf '#!/bin/sh\nexit 0\n' > "$rigStubs/whisper-server" ; chmod +x "$rigStubs/whisper-server"
: > "$rigLog/curl.args"
rigRun /dev/null "$rigTool" transcribe
rigAssert "transcribe with the speech server up: one second of silence is sent and removed, and the answer is the server's" "$rigRc $( cat "$rigTmp/out" ) $( LC_ALL=C grep -c -F -- 'file=@' "$rigLog/curl.args" || : ) $( ls "$rigData/run" | LC_ALL=C grep -c . || : )" '0 {"text":" hello"} 1 0'
printf 'RIFFrig' > "$rigTmp/speech.wav"
: > "$rigLog/curl.args"
rigRun /dev/null "$rigTool" transcribe "$rigTmp/speech.wav"
rigAssert "a file is sent as it is, and kept" "$rigRc $( LC_ALL=C grep -c -F -- "file=@$rigTmp/speech.wav" "$rigLog/curl.args" || : ) $( [ -f "$rigTmp/speech.wav" ] && echo kept )" "0 1 kept"
rigRun /dev/null "$rigTool" transcribe "$rigTmp/no-such.wav"
rigAssert "a file that is none is refused" "$rigRc $( LC_ALL=C grep -c -F -- 'transcribe: not a file' "$rigTmp/err" )" "1 1"

echo "-- 5. the check fragment --"
rigFragment="$rigFeature/host/install/feature-local-ai.2.check.txt"
rigRun /dev/null env MDCI_CHECK_PARSE=1 sh "$rigFragment"
rigAssert "MDCI_CHECK_PARSE=1: the key: value lines on standard output, the first the feature, and the status of the check" "$rigRc $( sed -n 1p "$rigTmp/out" ) $( rigKv part.chat-a.state ) $( LC_ALL=C grep -c -v '^[A-Za-z0-9._-]*: ' "$rigTmp/out" || : )" "0 local-ai: installed installed 0"
rigRun /dev/null sh "$rigFragment"
rigAssert "without it, as it was: nothing on standard output, the report on standard error, and 0" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( LC_ALL=C grep -c -x -e 'local-ai:check: report' -e '== host' "$rigTmp/err" )" "0 0 2"
rigRun /dev/null env MDCI_CHECK_PARSE=1 MDCI_FILES_PATH="$rigTmp/nowhere" sh "$rigFragment"
rigAssert "the command not deployed: the first line still says what the feature is, and the status is 1" "$rigRc $( sed -n 1p "$rigTmp/out" )" "1 local-ai: not installed"
rigAssert "the comments of the fragment hold no apostrophe (the generated installer passes through bash 3.2)" "$( LC_ALL=C grep '^[[:space:]]*#' "$rigFragment" | LC_ALL=C grep -c "'" || : )" "0"

echo "-- 6. the check fragment of LanceDB --"
rigRun /dev/null env LANCEDB_HOME="$rigTmp/lancedb-home" sh "$rigLancedb/host/install/feature-lancedb.check.txt"
rigAssert "no home: the first line says what the feature is (not installed, or not supported where the machine is not covered), key: value all through, nothing created" "$( sed -n 1p "$rigTmp/out" | LC_ALL=C sed -e 's/^lancedb: not installed$/lancedb: ok/' -e 's/^lancedb: not supported here$/lancedb: ok/' ) $( LC_ALL=C grep -c -v '^[A-Za-z0-9._-]*: ' "$rigTmp/out" || : ) $( [ -e "$rigTmp/lancedb-home" ] && echo made )" "lancedb: ok 0 "

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ LOCAL AI CHECK PARSE FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'LOCAL_AI_CHECK_PARSE: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
