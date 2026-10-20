#!/usr/bin/env bash
## Behavioural check on `DistroAgentsTools.fn.sh --install-knowledge-store` (F8.1 part 2 of the refactorings epic; the
## include is sh-lib/config/AgentsTools.InstallKnowledgeStore.include), run on a rig machine: a workspace whose
## .local/embedded-python stands as part 1 leaves it (a uv at the pinned version, and the Python, both stand-ins), a HOME,
## a PATH of stand-ins first (uname, curl), env -i for every call. No request leaves the rig, and no real Python, pip,
## LanceDB or package is ever fetched: the wheels are zip files made here, with the metadata a wheel carries, and the
## Python stand-in plays pip. Held:
##   1. the store has a setting, MDAT_KNOWLEDGE_STORE, in the catalogue of the changeable settings (subject knowledge),
##      off unless it is turned on, read from the environment and then the settings of the team, saved in those of the team
##   2. with the setting off, which it is by default, the installer refuses, says so and how to turn it on, and writes
##      nothing and asks for no Python
##   3. with it on, the private environment is made with the Python of part 1 (which the installer asks of part 1 and
##      does not make again), LanceDB pinned (0.40.0) is downloaded from binary packages alone (--only-binary=:all:),
##      BEFORE anything is placed every package that would be placed is listed with its licence, then the environment
##      is made and LanceDB installed into it from those files alone (--no-index), and the environment imports lancedb
##   4. what the licences ask is carried: each package's licence files and its NOTICE are copied beside, in
##      licenses/<name>-<version>/, and the list is kept in packages.txt
##   5. nothing outside the workspace's .local is touched, and the temporary folder of pip's process is in .local
##   6. the second run changes nothing and downloads nothing
##   7. an install from files downloaded once elsewhere (--from-folder <the wheelhouse of an online run, copied>): no
##      download, the same listing and checks; a folder with no wheel, or with no lancedb wheel, is refused
##   8. where no binary package exists (Intel macOS, FreeBSD aarch64 and the like) it says so, the store stays off, and
##      nothing is left; where part 1 refuses (FreeBSD and the systems no standalone build covers) it refuses with part 1's
##      own reason, and nothing is written
##   9. an environment that cannot import lancedb is not kept
## Red before: the operation, the setting and the folder did not exist.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigFixDir="$rigPackage/sh-test/check-fixtures"
rigLocalInclude="$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/python/LocalTools.EmbeddedPython.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigLocalInclude" ] || rigRefuse "part 1, the embedded Python, is not at the origin this workspace resolves: $rigLocalInclude"
for rigStub in knowledge-store-install.python embedded-python-install.uv embedded-python-install.uname ; do
	[ -f "$rigFixDir/$rigStub.stub.sh" ] || rigRefuse "the stand-in $rigStub is missing from the package: sh-test/check-fixtures/$rigStub.stub.sh"
done
command -v zip > /dev/null 2>&1 || rigRefuse "no zip on this machine, which makes the wheels of the rig"
command -v unzip > /dev/null 2>&1 || rigRefuse "no unzip on this machine"
. "$rigFixDir/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsKnowledgeStoreInstallCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
## The temp-dir variable, from parts, so that this file is read like every other.
rigTmpVar="TMP""DIR"
rigUvPin="$( LC_ALL=C sed -n 's/^.*local uvVersion="\([0-9][0-9.]*\)".*$/\1/p' "$rigLocalInclude" | head -1 )"
[ -n "$rigUvPin" ] || rigRefuse "the pinned uv release is not found in $rigLocalInclude"
rigBin="$rigTmp/bin" ; rigWheels="$rigTmp/wheels"
mkdir -p "$rigBin" "$rigWheels" "$rigTmp/cwd" "$rigTmp/stage"
cp "$rigFixDir/embedded-python-install.uname.stub.sh" "$rigBin/uname" && chmod +x "$rigBin/uname"
printf '#!/bin/sh\necho "$*" >> "${RIG_CURL_LOG:?}"\nexit 7\n' > "$rigBin/curl" && chmod +x "$rigBin/curl"
rigWheel(){ ## name, version, tag, the licence header lines (may be empty), then the files of the licence folder, each named
	local name="$1" ver="$2" tag="$3" lic="$4" stage="$rigTmp/stage/wheel" info
	info="$stage/$name-$ver.dist-info"
	rm -rf "$stage" ; mkdir -p "$info"
	{ printf 'Metadata-Version: 2.4\nName: %s\nVersion: %s\n' "$name" "$ver" ; [ -z "$lic" ] || printf '%s\n' "$lic" ; printf '\nA long description of the package.\nLicense: a line of the description, no header\n' ; } > "$info/METADATA"
	printf 'x = 1\n' > "$stage/$name.py"
	shift 4
	while [ $# -gt 0 ] ; do
		mkdir -p "$( dirname "$info/$1" )" && printf 'text of %s of %s\n' "$1" "$name" > "$info/$1"
		shift
	done
	( cd "$stage" && zip -q -r "$rigWheels/$name-$ver-$tag.whl" . )
}
rigWheel lancedb 0.40.0 cp310-abi3-macosx_11_0_arm64 "License-Expression: Apache-2.0" licenses/LICENSE licenses/NOTICE
rigWheel pyarrow 26.0.0 cp312-cp312-macosx_11_0_arm64 "License-Expression: Apache-2.0" licenses/LICENSE.txt
rigWheel tqdm 4.67.1 py3-none-any "License-Expression: MPL-2.0 AND MIT" LICENCE
rigWheel numpy 2.5.4 cp312-cp312-macosx_11_0_arm64 "License: BSD-3-Clause AND 0BSD" LICENSE.txt
rigWheel typing_extensions 4.15.0 py3-none-any "Classifier: License :: OSI Approved :: Python Software Foundation License"
rigWheel legacypkg 1.0.0 py3-none-any "License: MIT License
        Copyright (c) the author, all rights reserved. A long text goes on here." COPYING
rigWheel mystery 1.0.0 py3-none-any ""
rigWheelCount="$( ls "$rigWheels"/*.whl | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )"
## What the listing must say: one line a package, name, version, licence.
rigExpected="lancedb 0.40.0 Apache-2.0
legacypkg 1.0.0 MIT License
mystery 1.0.0 unknown
numpy 2.5.4 BSD-3-Clause AND 0BSD
pyarrow 26.0.0 Apache-2.0
tqdm 4.67.1 MPL-2.0 AND MIT
typing_extensions 4.15.0 Python Software Foundation License"

## A scenario: its own workspace, HOME and logs. rigNew [embedded] makes the Python of part 1 stand in it.
rigNew(){ ## name, uname -s, uname -m, embedded|none
	rigDir="$rigTmp/$1" ; rigS="${2:-Linux}" ; rigM="${3:-x86_64}" ; rigSetting="" ; rigNoBinary="" ; rigNoImport="" ; rigFrom=""
	mkdir -p "$rigDir/ws/.local" "$rigDir/home"
	: > "$rigDir/py.log" ; : > "$rigDir/curl.log"
	rigBase="$rigDir/ws/.local/embedded-python" ; rigStore="$rigDir/ws/.local/knowledge-store"
	if [ "${4:-embedded}" = embedded ] ; then
		mkdir -p "$rigBase/uv" "$rigBase/python/cpython-3.12.0-stub/bin"
		LC_ALL=C sed -e "s/@UV_VERSION@/$rigUvPin/" "$rigFixDir/embedded-python-install.uv.stub.sh" > "$rigBase/uv/uv"
		cp "$rigFixDir/knowledge-store-install.python.stub.sh" "$rigBase/python/cpython-3.12.0-stub/bin/python3.12"
		chmod +x "$rigBase/uv/uv" "$rigBase/python/cpython-3.12.0-stub/bin/python3.12"
	fi
}
rigRun(){ ## the tool's arguments; rigSetting, rigNoBinary and rigNoImport, where set, reach the call
	rigRc=0
	( cd "$rigTmp/cwd" && env -i HOME="$rigDir/home" PATH="$rigBin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		RIG_UNAME_S="$rigS" RIG_UNAME_M="$rigM" RIG_PY_LOG="$rigDir/py.log" RIG_CURL_LOG="$rigDir/curl.log" RIG_WHEELS="$rigWheels" \
		${rigSetting:+MDAT_KNOWLEDGE_STORE="$rigSetting"} ${rigNoBinary:+RIG_NO_BINARY=1} ${rigNoImport:+RIG_NO_IMPORT=1} \
		bash "$rigTool" "$@" ) > "$rigDir/out" 2> "$rigDir/err" || rigRc=$?
}
rigTree(){ ## folder -- what stands below it, sorted, one line
	( cd "$1" && find . -mindepth 1 | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )
}
rigLocalTree(){ ## folder -- as rigTree, the scope folder of the settings and the Python of part 1 left out
	rigTree "$1" | LC_ALL=C sed -e 's| *\./\.agents[^ ]*||g;s| *\./embedded-python[^ ]*||g;s/^ *//;s/ *$//'
}
rigListed(){ ## -- the lines of the listing in the error output of the scenario, as name version licence, blanks squeezed, sorted
	LC_ALL=C awk '/^    [A-Za-z0-9_.-]+ +[0-9][0-9A-Za-z.+-]* +[^ ]/ { print }' "$rigDir/err" | LC_ALL=C sed -e 's/^ *//' -e 's/  */ /g' | LC_ALL=C sort
}
rigCalls(){ ## word -- how many calls of the Python stand-in had this word
	LC_ALL=C grep -c "^CALL .*$1" "$rigDir/py.log" || :
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
rigAssert "refused, rc non-zero, it says the store is off and how to turn it on, no Python asked for, nothing written" "$( [ "$rigRc" -ne 0 ] && printf refused ) $( LC_ALL=C grep -c -F -e 'MDAT_KNOWLEDGE_STORE' -e 'is off' "$rigDir/err" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/said/' ) $( rigCalls . ) [$( rigLocalTree "$rigDir/ws/.local" )]" "refused said 0 []"
rigSetting=off ; rigRun --install-knowledge-store ; rigSetting=""
rigAssert "set to off, the same" "$( [ "$rigRc" -ne 0 ] && printf refused ) $( rigCalls . )" "refused 0"
rigSetting=yes ; rigRun --install-knowledge-store ; rigSetting=""
rigAssert "a word that is no value of the setting is off too" "$( [ "$rigRc" -ne 0 ] && printf refused ) $( rigCalls . )" "refused 0"

echo "-- 3. with it on: the packages are listed with their licences before anything is placed, then placed --"
rigNew on
rigSetting=on ; rigRun --install-knowledge-store
rigPy="$rigStore/venv/bin/python"
rigAssert "rc 0, and standard output is the Python of the environment, one line" "$rigRc $( LC_ALL=C cat "$rigDir/out" | LC_ALL=C sed -e "s|$rigDir/ws/||" )" "0 .local/knowledge-store/venv/bin/python"
rigAssert "every wheel is listed, once, with its version and its licence (an expression, a classifier, a header's first line, or unknown)" "$( rigListed )" "$rigExpected"
rigAssert "the listing says how many packages would be placed" "$( LC_ALL=C grep -c -E "$rigWheelCount packages" "$rigDir/err" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/said/' )" "said"
rigAssert "the listing stands ahead of the environment being made, and the environment ahead of the install" "$( LC_ALL=C awk '/^    lancedb +0.40.0/ { listed = NR } /^PYSTUB venv/ { made = NR } /^PYSTUB pip install/ { placed = NR } END { print ( listed && made && placed && listed < made && made < placed ) ? "in-order" : "listed=" listed " made=" made " placed=" placed }' "$rigDir/err" )" "in-order"
rigAssert "LanceDB pinned is asked of pip as binary packages alone, into the wheelhouse of the store" "$( LC_ALL=C grep -c -E "^CALL -I -m pip download .*--only-binary=:all: .*-d $rigStore/wheelhouse .*lancedb==0.40.0" "$rigDir/py.log" )" "1"
rigAssert "and installed from those files alone: --no-index, --find-links the wheelhouse, nothing built or fetched" "$( LC_ALL=C grep -c -E "^CALL -I -m pip install .*--no-index .*--find-links $rigStore/wheelhouse .*lancedb==0.40.0" "$rigDir/py.log" )" "1"
rigAssert "the environment is made by the Python of part 1, in .local/knowledge-store/venv, and it imports lancedb" "$( LC_ALL=C grep -c -E "^CALL -I -m venv $rigStore/venv\$" "$rigDir/py.log" ) $( env -i PATH=/usr/bin:/bin "$rigPy" -I -c 'import lancedb' 2>&1 )" "1 0.40.0"
rigAssert "part 1 was asked and made nothing again: no request, and uv was not asked to install a Python" "$( LC_ALL=C wc -l < "$rigDir/curl.log" | LC_ALL=C tr -d ' ' ) [$( rigTree "$rigBase" | LC_ALL=C sed -e 's| *\./python[^ ]*||g;s| *\./uv[^ ]*||g;s/^ *//;s/ *$//' )]" "0 []"

echo "-- 4. what the licences ask is carried --"
rigAssert "each package's licence files, and the NOTICE of LanceDB, are copied into licenses/<name>-<version>/" "$( ls "$rigStore/licenses/lancedb-0.40.0" | LC_ALL=C tr '\n' ' ' ) $( ls "$rigStore/licenses/pyarrow-26.0.0" | LC_ALL=C tr '\n' ' ' ) $( ls "$rigStore/licenses/tqdm-4.67.1" | LC_ALL=C tr '\n' ' ' ) $( ls "$rigStore/licenses/legacypkg-1.0.0" | LC_ALL=C tr '\n' ' ' )" "LICENSE NOTICE  LICENSE.txt  LICENCE  COPYING "
rigAssert "the files are the wheel's own, unchanged" "$( LC_ALL=C cat "$rigStore/licenses/lancedb-0.40.0/NOTICE" )" "text of licenses/NOTICE of lancedb"
rigAssert "a package that carries none has a folder with nothing in it, and is not skipped" "$( [ -d "$rigStore/licenses/mystery-1.0.0" ] && printf folder ) $( ls -A "$rigStore/licenses/mystery-1.0.0" | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "folder 0"
rigAssert "packages.txt keeps the list: name, version, licence, a line each" "$( LC_ALL=C sed -e 's/[[:space:]][[:space:]]*/ /g' "$rigStore/packages.txt" | LC_ALL=C sort )" "$rigExpected"

echo "-- 5. nothing outside the workspace's .local is touched --"
rigAssert "the HOME of the rig is empty, the workspace holds .local alone, and .local holds the Python of part 1 and the store" "[$( rigTree "$rigDir/home" )] [$( ls -A "$rigDir/ws" | LC_ALL=C tr '\n' ' ' )] [$( ls -A "$rigDir/ws/.local" | LC_ALL=C grep -v -x '\.agents' | LC_ALL=C tr '\n' ' ' )] [$( rigTree "$rigTmp/cwd" )]" "[] [.local ] [embedded-python knowledge-store ] []"
rigOut=""
for rigCallWord in "pip download" "pip install" ; do
	rigValue="$( LC_ALL=C awk -v w="-m $rigCallWord" 'index( $0, "CALL " ) == 1 { on = index( $0, w ) } on && /^ENV TMP/ { sub( /^ENV [A-Z]+=/, "" ) ; print ; exit }' "$rigDir/py.log" )"
	case "$rigValue" in "$rigStore/"?*) ;; *) rigOut="$rigOut [$rigCallWord: $rigValue]" ;; esac
done
rigAssert "pip's process has its temp-dir variable ($rigTmpVar) in a folder of the store, for the download and for the install" "[${rigOut# }]" "[]"
rigAssert "pip keeps no cache and makes no version check (PIP_NO_CACHE_DIR, PIP_DISABLE_PIP_VERSION_CHECK), and its home is the rig's" "$( LC_ALL=C grep -c -x 'ENV PIP_NO_CACHE_DIR=1' "$rigDir/py.log" | LC_ALL=C sed -e 's/^[2-9]$/each/' ) $( LC_ALL=C grep -c -x 'ENV PIP_DISABLE_PIP_VERSION_CHECK=1' "$rigDir/py.log" | LC_ALL=C sed -e 's/^[2-9]$/each/' )" "each each"

echo "-- 6. the second run changes nothing and downloads nothing --"
sleep 1 ; : > "$rigDir/marker" ; sleep 1
rigBefore="$( LC_ALL=C cat "$rigDir/out" )" ; : > "$rigDir/py.log"
rigRun --install-knowledge-store
rigAssert "rc 0, the same Python printed, no call of pip or venv, and it says it stands" "$rigRc $( [ "$( LC_ALL=C cat "$rigDir/out" )" = "$rigBefore" ] && printf same ) $( rigCalls 'pip' ) $( rigCalls 'venv' ) $( LC_ALL=C grep -c -i 'already' "$rigDir/err" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/said/' )" "0 same 0 0 said"
rigAssert "no file or folder of .local was made or changed by it" "$( find "$rigDir/ws/.local" -newer "$rigDir/marker" 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "0"
rigSetting=""

echo "-- 7. an install from files downloaded once elsewhere --"
rigCarried="$rigTmp/carried"
cp -R "$rigStore/wheelhouse" "$rigCarried"
rigCarriedTree="$( rigTree "$rigCarried" )"
rigNew offline
rigSetting=on ; rigRun --install-knowledge-store --from-folder "$rigCarried"
rigAssert "rc 0, no download (pip was not asked to), the same listing, installed from the folder alone, and it imports lancedb" "$rigRc $( rigCalls 'pip download' ) $( rigCalls 'pip install' ) $( LC_ALL=C grep -c -E "^CALL -I -m pip install .*--no-index .*--find-links $rigCarried .*lancedb==0.40.0" "$rigDir/py.log" ) $( [ "$( rigListed )" = "$rigExpected" ] && printf listed ) $( env -i PATH=/usr/bin:/bin "$rigStore/venv/bin/python" -I -c 'import lancedb' 2>&1 )" "0 0 1 1 listed 0.40.0"
rigAssert "the folder is left as it was, and no wheelhouse is made in .local" "$( [ "$( rigTree "$rigCarried" )" = "$rigCarriedTree" ] && printf same ) $( [ -e "$rigStore/wheelhouse" ] && printf made )" "same "
rigRefuseCase(){ ## label, folder, what the message names
	rigNew "from-${1// /-}" ; rigSetting=on
	rigRun --install-knowledge-store --from-folder "$2"
	rigAssert "$1: refused, rc non-zero, it names $3, no Python asked for, nothing placed" "$( [ "$rigRc" -ne 0 ] && printf refused ) $( LC_ALL=C grep -c -F -e "$3" "$rigDir/err" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/named/' ) $( rigCalls . ) [$( rigLocalTree "$rigDir/ws/.local" )]" "refused named 0 []"
}
mkdir -p "$rigTmp/carried-empty"
rigRefuseCase "folder with no wheel" "$rigTmp/carried-empty" "$rigTmp/carried-empty"
cp -R "$rigCarried" "$rigTmp/carried-nolance" ; rm -f "$rigTmp/carried-nolance"/lancedb-*.whl
rigRefuseCase "folder with no lancedb wheel" "$rigTmp/carried-nolance" "lancedb"
rigRefuseCase "no such folder" "$rigTmp/there-is-no-such-folder" "$rigTmp/there-is-no-such-folder"

echo "-- 8. where no binary package exists, or part 1 refuses --"
rigNew nobinary Darwin x86_64
rigSetting=on ; rigNoBinary=1 ; rigRun --install-knowledge-store
rigAssert "no binary package: refused, rc non-zero, it says there is none of lancedb 0.40.0 for this system and the store stays off" "$( [ "$rigRc" -ne 0 ] && printf refused ) $( LC_ALL=C grep -c -F -e 'no binary package of lancedb 0.40.0' "$rigDir/err" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/said/' ) $( LC_ALL=C grep -c -i -e 'stays off' "$rigDir/err" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/off/' ) $( rigCalls 'venv' ) [$( rigTree "$rigDir/ws/.local/knowledge-store" 2> /dev/null )]" "refused said off 0 []"
rigNew freebsd FreeBSD amd64 none
rigSetting=on ; rigRun --install-knowledge-store
rigAssert "FreeBSD: part 1 refuses, and so does the installer, with part 1's reason: rc non-zero, the system and no standalone build named, no Python asked for, nothing written" "$( [ "$rigRc" -ne 0 ] && printf refused ) $( LC_ALL=C grep -c -F 'FreeBSD' "$rigDir/err" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/named/' ) $( LC_ALL=C grep -c -i 'standalone' "$rigDir/err" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/reason/' ) $( rigCalls . ) [$( rigLocalTree "$rigDir/ws/.local" )]" "refused named reason 0 []"
rigNew freebsd-arm FreeBSD arm64 none
rigSetting=on ; rigRun --install-knowledge-store
rigAssert "FreeBSD on arm64 too, and nothing is read from the system's Python or its packages" "$( [ "$rigRc" -ne 0 ] && printf refused ) [$( rigLocalTree "$rigDir/ws/.local" )]" "refused []"

echo "-- 9. an environment that cannot import lancedb is not kept --"
rigNew noimport
rigSetting=on ; rigNoImport=1 ; rigRun --install-knowledge-store
rigAssert "refused, rc non-zero, it says lancedb cannot be imported and the store stays off, and the environment is gone" "$( [ "$rigRc" -ne 0 ] && printf refused ) $( LC_ALL=C grep -c -i -F -e 'cannot be imported' "$rigDir/err" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/said/' ) $( LC_ALL=C grep -c -i -e 'stays off' "$rigDir/err" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/off/' ) $( [ -e "$rigStore/venv" ] && printf kept )" "refused said off "

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ KNOWLEDGE STORE INSTALL CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'KNOWLEDGE_STORE_INSTALL: OK (%d assertions, offline, no Python, pip or package fetched)\n' "$rigPasses"
