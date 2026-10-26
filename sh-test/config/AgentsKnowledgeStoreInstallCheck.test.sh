#!/usr/bin/env bash
## Behavioural check on `DistroAgentsTools.fn.sh --install-knowledge-store` (F8.1 of the refactorings epic; the include is
## sh-lib/config/AgentsTools.InstallKnowledgeStore.include). The operation is a THIN CALL: the install is the feature
## setup.feature-lancedb, its fragment host/install/feature-lancedb.install.txt, whose own steps are not run here. The rig is an
## origin of links to the real one with that one fragment replaced by a stand-in (sh-test/check-fixtures/knowledge-store-install.feature.stub.sh),
## a HOME, a workspace, env -i for every call. No request leaves the rig and nothing is installed. Held:
##   1. the store has a setting, MDAT_KNOWLEDGE_STORE, in the catalogue of the changeable settings (subject knowledge),
##      off unless it is turned on, read from the environment and then the settings of the team, saved in those of the team
##   2. with the setting off, which it is by default, the operation refuses, says so and how to turn it on, writes nothing and
##      does not call the feature
##   3. with it on, the feature is called once, with no argument, the workspace and the origin handed over; its standard output
##      (the Python of the environment, one line) and its messages are passed through, and its rc is the operation's
##   4. --from-folder <folder> is checked, made absolute and handed on; a missing folder, a missing value and any other option are
##      refused before the feature is called
##   5. the rc of the feature is returned as it is: 1 refused or failed, 3 this platform is not covered (the store stays off)
##   6. a feature that is not in the origin is refused, naming it
##   7. the Python the Knowledge tool uses is $LANCEDB_HOME/venv/bin/python, else $MMDAPP/.local/lancedb/venv/bin/python, and
##      only where the feature wrote lancedb.env
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigFixDir="$rigPackage/sh-test/check-fixtures"
rigKnowledge="$rigPackage/sh-lib/team-data/AgentsTools.Knowledge.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigFixDir/knowledge-store-install.feature.stub.sh" ] || rigRefuse "the stand-in of the feature is missing from the package: sh-test/check-fixtures/knowledge-store-install.feature.stub.sh"
. "$rigFixDir/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsKnowledgeStoreInstallCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}

## The origin of the rig: every entry of the real one linked, but for the feature, which is the stand-in.
rigOrigin="$rigTmp/origin"
mkdir -p "$rigOrigin/myx/mdci-packages-myx/setup.feature-lancedb/host/install" "$rigTmp/cwd"
for rigEntry in "$MDLT_ORIGIN"/* "$MDLT_ORIGIN"/.[!.]* ; do
	[ -e "$rigEntry" ] || continue
	[ "${rigEntry##*/}" = myx ] || ln -s "$rigEntry" "$rigOrigin/${rigEntry##*/}"
done
for rigEntry in "$MDLT_ORIGIN/myx"/* ; do
	[ "${rigEntry##*/}" = mdci-packages-myx ] || ln -s "$rigEntry" "$rigOrigin/myx/${rigEntry##*/}"
done
for rigEntry in "$MDLT_ORIGIN/myx/mdci-packages-myx"/* ; do
	[ "${rigEntry##*/}" = setup.feature-lancedb ] || ln -s "$rigEntry" "$rigOrigin/myx/mdci-packages-myx/${rigEntry##*/}"
done
rigFeature="$rigOrigin/myx/mdci-packages-myx/setup.feature-lancedb/host/install/feature-lancedb.install.txt"
cp "$rigFixDir/knowledge-store-install.feature.stub.sh" "$rigFeature"

## A scenario: its own workspace, HOME and log of the feature.
rigNew(){ ## name
	rigDir="$rigTmp/$1" ; rigSetting="" ; rigFeatureRc=0
	mkdir -p "$rigDir/ws/.local" "$rigDir/home"
	: > "$rigDir/feature.log"
}
rigRun(){ ## the tool's arguments; rigSetting and rigFeatureRc, where set, reach the call
	rigRc=0
	( cd "$rigTmp/cwd" && env -i HOME="$rigDir/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigDir/ws" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		RIG_FEATURE_LOG="$rigDir/feature.log" RIG_FEATURE_RC="$rigFeatureRc" ${rigSetting:+MDAT_KNOWLEDGE_STORE="$rigSetting"} \
		bash "$rigTool" "$@" ) > "$rigDir/out" 2> "$rigDir/err" || rigRc=$?
}
rigTree(){ ## folder -- what stands below it, sorted, one line
	( cd "$1" && find . -mindepth 1 | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )
}
rigLocalTree(){ ## folder -- as rigTree, the scope folder of the settings left out
	rigTree "$1" | LC_ALL=C sed -e 's| *\./\.agents[^ ]*||g;s/^ *//;s/ *$//'
}
rigCalls(){ ## -- how many times the feature was called
	LC_ALL=C grep -c '^CALL' "$rigDir/feature.log" || :
}

echo "-- 1. the setting of the store, in the catalogue of the changeable settings --"
rigNew digest
rigRun --manager-config-digest knowledge
rigAssert "the subject knowledge has one line, MDAT_KNOWLEDGE_STORE, off by default" "$( LC_ALL=C awk -F'\t' '$1 == "line" { print $2 " " $4 " " $5 " " $6 }' "$rigDir/out" )" "knowledge MDAT_KNOWLEDGE_STORE set off"
rigRun --manager-config-digest --full knowledge
rigAssert "in full it says it can be changed, a choice of off and on saved for the workspace, its value from the default, with a label and a description, of the settings" "$( LC_ALL=C awk -F'\t' '$1 == "line" { print $7 " " ( length( $8 ) > 40 ? "described" : "bare" ) " " $9 " " $10 " " $11 " " $12 " " $13 " " $15 }' "$rigDir/out" )" "Knowledge_Store_Switch described yes choice workspace default off=Off,on=On settings"
rigSetting=on ; rigRun --manager-config-digest --full knowledge ; rigSetting=""
rigAssert "set in the environment it reads on, from the environment" "$( LC_ALL=C awk -F'\t' '$1 == "line" { print $6 " " $12 }' "$rigDir/out" )" "on environment"
rigRun --manager-config-set MDAT_KNOWLEDGE_STORE on
rigAssert "it is saved in the settings of the team, which then hold it" "$( LC_ALL=C cut -f1-4 "$rigDir/out" | LC_ALL=C tr "\t" " " ) $( LC_ALL=C grep -c -x 'MDAT_KNOWLEDGE_STORE=on' "$rigDir/ws/.local/.agents/magic-team.agent.env" )" "saved MDAT_KNOWLEDGE_STORE on workspace 1"
rigRun --manager-config-set MDAT_KNOWLEDGE_STORE maybe
rigAssert "any other value is refused and nothing is saved" "$( [ "$rigRc" -ne 0 ] && printf refused ) $( LC_ALL=C grep -c -x 'MDAT_KNOWLEDGE_STORE=on' "$rigDir/ws/.local/.agents/magic-team.agent.env" )" "refused 1"

echo "-- 2. with the setting off, which it is by default, nothing is installed --"
rigNew off
rigRun --install-knowledge-store
rigAssert "refused, rc non-zero, it says the store is off and how to turn it on, the feature not called, nothing written" "$( [ "$rigRc" -ne 0 ] && printf refused ) $( LC_ALL=C grep -c -F -e 'MDAT_KNOWLEDGE_STORE' -e 'is off' "$rigDir/err" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/said/' ) $( rigCalls ) [$( rigLocalTree "$rigDir/ws/.local" )]" "refused said 0 []"
rigSetting=off ; rigRun --install-knowledge-store ; rigSetting=""
rigAssert "set to off, the same" "$( [ "$rigRc" -ne 0 ] && printf refused ) $( rigCalls )" "refused 0"
rigSetting=yes ; rigRun --install-knowledge-store ; rigSetting=""
rigAssert "a word that is no value of the setting is off too" "$( [ "$rigRc" -ne 0 ] && printf refused ) $( rigCalls )" "refused 0"

echo "-- 3. with it on: the feature is called, its output passed through, its rc returned --"
rigNew on
rigSetting=on ; rigRun --install-knowledge-store
rigAssert "rc 0, and standard output is the Python the feature printed, one line, unchanged" "$rigRc $( LC_ALL=C cat "$rigDir/out" | LC_ALL=C sed -e "s|$rigDir/ws/||" )" "0 .local/lancedb/venv/bin/python"
rigAssert "the messages of the feature are on standard error, unchanged" "$( LC_ALL=C grep -c -x 'setup.feature-lancedb: the stand-in said this' "$rigDir/err" )" 1
rigAssert "the feature was called once, with no argument, the workspace and the origin handed over" "$( rigCalls ) $( LC_ALL=C grep -c -x 'CALL' "$rigDir/feature.log" ) $( LC_ALL=C grep -c -x "ENV MMDAPP=$rigDir/ws" "$rigDir/feature.log" ) $( LC_ALL=C grep -c -x "ENV MDLT_ORIGIN=$rigOrigin" "$rigDir/feature.log" )" "1 1 1 1"
rigAssert "nothing else is written by the operation: the home of the rig is empty, .local holds only the settings" "[$( rigTree "$rigDir/home" )] [$( rigLocalTree "$rigDir/ws/.local" )]" "[] []"

echo "-- 4. --from-folder --"
mkdir -p "$rigTmp/carried"
rigNew from
rigSetting=on ; rigRun --install-knowledge-store --from-folder "$rigTmp/carried"
rigAssert "a folder is handed on, absolute, with the option" "$rigRc $( rigCalls ) $( LC_ALL=C grep -c -x "CALL --from-folder $rigTmp/carried" "$rigDir/feature.log" )" "0 1 1"
rigNew from-relative
rigSetting=on ; ( cd "$rigTmp" && rigRc=0 && env -i HOME="$rigDir/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigDir/ws" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" RIG_FEATURE_LOG="$rigDir/feature.log" RIG_FEATURE_RC=0 MDAT_KNOWLEDGE_STORE=on bash "$rigTool" --install-knowledge-store --from-folder carried > "$rigDir/out" 2> "$rigDir/err" )
rigAssert "a relative folder is made absolute before it is handed on" "$( LC_ALL=C grep -c -x "CALL --from-folder $rigTmp/carried" "$rigDir/feature.log" )" 1
rigRefuseCase(){ ## label, what the message names, the arguments
	local caseLabel="$1" caseNames="$2"
	shift 2
	rigNew "refuse-${caseLabel// /-}" ; rigSetting=on
	rigRun --install-knowledge-store "$@"
	rigAssert "$caseLabel: refused, rc non-zero, it names $caseNames, the feature not called, nothing written" "$( [ "$rigRc" -ne 0 ] && printf refused ) $( LC_ALL=C grep -c -F -e "$caseNames" "$rigDir/err" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/named/' ) $( rigCalls ) [$( rigLocalTree "$rigDir/ws/.local" )]" "refused named 0 []"
}
rigRefuseCase "no such folder" "$rigTmp/there-is-no-such-folder" --from-folder "$rigTmp/there-is-no-such-folder"
rigRefuseCase "the option without a folder" "needs a folder" --from-folder
rigRefuseCase "another option" "invalid option" --nonsense

echo "-- 5. the rc of the feature is the rc of the operation --"
rigNew rc-1
rigSetting=on ; rigFeatureRc=1 ; rigRun --install-knowledge-store
rigAssert "1, refused or failed: rc 1, nothing on standard output, the message passed through" "$rigRc [$( LC_ALL=C cat "$rigDir/out" )] $( LC_ALL=C grep -c -x 'setup.feature-lancedb: the stand-in said this' "$rigDir/err" )" "1 [] 1"
rigNew rc-3
rigSetting=on ; rigFeatureRc=3 ; rigRun --install-knowledge-store
rigAssert "3, this platform is not covered: rc 3, nothing on standard output, the store stays off" "$rigRc [$( LC_ALL=C cat "$rigDir/out" )] $( rigCalls )" "3 [] 1"

echo "-- 6. a feature that is not in the origin --"
rigNew no-feature
mv "$rigFeature" "$rigFeature.away"
rigSetting=on ; rigRun --install-knowledge-store
mv "$rigFeature.away" "$rigFeature"
rigAssert "refused, rc non-zero, it names the feature, and the store stays off" "$( [ "$rigRc" -ne 0 ] && printf refused ) $( LC_ALL=C grep -c -F 'setup.feature-lancedb' "$rigDir/err" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/named/' ) $( LC_ALL=C grep -c -i 'stays off' "$rigDir/err" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/off/' ) $( rigCalls )" "refused named off 0"

echo "-- 7. the Python the Knowledge tool uses --"
rigNew python
rigPyRun(){ ## environment pairs -- the answer and rc of the reader of the Python
	( env -i PATH="/usr/bin:/bin" MMDAPP="$rigDir/ws" "$@" bash -c '. "$1" && AgentsToolsKnowledgeStorePython' rig "$rigKnowledge" 2> /dev/null ; echo "rc=$?" ) | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed -e "s|$rigDir/||g"
}
mkdir -p "$rigDir/ws/.local/lancedb/venv/bin" "$rigDir/elsewhere/venv/bin"
printf '#!/bin/sh\n' > "$rigDir/ws/.local/lancedb/venv/bin/python" ; chmod +x "$rigDir/ws/.local/lancedb/venv/bin/python"
printf '#!/bin/sh\n' > "$rigDir/elsewhere/venv/bin/python" ; chmod +x "$rigDir/elsewhere/venv/bin/python"
rigAssert "a venv with no lancedb.env is not an install: nothing, rc 1" "$( rigPyRun )" "rc=1 "
: > "$rigDir/ws/.local/lancedb/lancedb.env"
rigAssert "with lancedb.env, the Python of .local/lancedb" "$( rigPyRun )" "ws/.local/lancedb/venv/bin/python rc=0 "
rigAssert "LANCEDB_HOME moves the home: that one has no lancedb.env, so nothing, rc 1" "$( rigPyRun LANCEDB_HOME="$rigDir/elsewhere" )" "rc=1 "
: > "$rigDir/elsewhere/lancedb.env"
rigAssert "and with its lancedb.env, its Python" "$( rigPyRun LANCEDB_HOME="$rigDir/elsewhere" )" "elsewhere/venv/bin/python rc=0 "

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ KNOWLEDGE STORE INSTALL CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'KNOWLEDGE_STORE_INSTALL: OK (%d assertions, offline, the feature a stand-in)\n' "$rigPasses"
