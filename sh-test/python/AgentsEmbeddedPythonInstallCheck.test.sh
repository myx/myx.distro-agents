#!/usr/bin/env bash
## Behavioural check on `DistroLocalTools.fn.sh --install-embedded-python` (F8.1 part 1 of the refactorings epic; the
## include is myx.distro-.local/sh-lib/python/LocalTools.EmbeddedPython.include), run on a rig machine: a workspace, a
## HOME, a PATH of stand-ins first (curl, uname, ldd, and the uv inside the fixture release archives), env -i for every
## call. No request leaves the rig and no real uv or Python is ever fetched: the fixture archives are made here, with the
## checksum file beside each as uv publishes it, and served by a curl stand-in. Held:
##   1. the operation stands apart from the subsystem installs (--install-distro-*), its include in a subfolder of the
##      package's sh-lib (python/) and not at its root, its help as a pair (Help.DistroLocalTools-install-embedded-python
##      .help.md and .include) beside the others, listed by the package's manual and docs
##   2. an exact pinned uv release (a default in the include, --uv-version names another) for the machine it runs on
##      (macOS and Linux, arm64 and x86_64, glibc and musl), its archive checked against the .sha256 published beside it,
##      unpacked into a folder under .local; a version that is no version is refused
##   3. a checksum that does not match, is missing or is no checksum refuses the install and leaves no uv behind
##   4. a standalone CPython of the pinned minor (3.12 or later) installed by that uv, and every folder uv uses is a
##      folder of .local: its Python, cache, tool and bin folders, the archives it keeps, its temporary folder (the
##      temp-dir variable of uv's own process), and no shell file is edited (UV_NO_MODIFY_PATH)
##   5. nothing outside the rig's .local is touched: the HOME of the rig stays empty
##   6. the second run changes nothing and fetches nothing, and prints where things are
##   7. an install from files downloaded once elsewhere (--from-folder <the downloads folder of an online run, copied>):
##      no request, the same checks, and a folder that lacks what the install needs is refused, naming it
##   8. a system no standalone build covers (FreeBSD, and any other) is refused with the reason, rc non-zero, and
##      nothing is written
## Red before: the operation did not exist.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-.local"
rigTool="$rigPkg/sh-scripts/DistroLocalTools.fn.sh"
rigInclude="$rigPkg/sh-lib/python/LocalTools.EmbeddedPython.include"
rigFixDir="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
for rigStub in uv curl uname ldd ; do
	[ -f "$rigFixDir/embedded-python-install.$rigStub.stub.sh" ] || rigRefuse "the stand-in for $rigStub is missing from the package: sh-test/check-fixtures/embedded-python-install.$rigStub.stub.sh"
done
. "$rigFixDir/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsEmbeddedPythonInstallCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
## The temp-dir variable, from parts, so that this file is read like every other.
rigTmpVar="TMP""DIR"
rigBin="$rigTmp/bin" ; rigFixtures="$rigTmp/fixtures" ; rigPinned="0.13.1"
mkdir -p "$rigBin" "$rigFixtures" "$rigTmp/cwd"
for rigStub in curl uname ldd ; do cp "$rigFixDir/embedded-python-install.$rigStub.stub.sh" "$rigBin/$rigStub" && chmod +x "$rigBin/$rigStub" ; done
rigSha(){ ## file -- its sha256
	if command -v sha256sum > /dev/null 2>&1 ; then sha256sum "$1" | LC_ALL=C awk '{ print $1 }' ; else shasum -a 256 "$1" | LC_ALL=C awk '{ print $1 }' ; fi
}
rigRelease(){ ## version, triple [star|wrong|none|junk] -- the release folder of a fixture: the archive of the stub uv and the .sha256 beside it
	local ver="$1" triple="$2" form="${3:-}" dir="$rigFixtures/$1"
	mkdir -p "$dir/pack/uv-$triple"
	LC_ALL=C sed -e "s/@UV_VERSION@/$ver/" "$rigFixDir/embedded-python-install.uv.stub.sh" > "$dir/pack/uv-$triple/uv"
	printf '#!/bin/sh\necho "stub uvx"\n' > "$dir/pack/uv-$triple/uvx"
	chmod +x "$dir/pack/uv-$triple/uv" "$dir/pack/uv-$triple/uvx"
	( cd "$dir/pack" && tar -czf "../uv-$triple.tar.gz" "uv-$triple" )
	rm -rf "$dir/pack"
	case "$form" in
		star) printf '%s *%s\n' "$( rigSha "$dir/uv-$triple.tar.gz" )" "uv-$triple.tar.gz" > "$dir/uv-$triple.tar.gz.sha256" ;;
		wrong) printf '%s  %s\n' "0000000000000000000000000000000000000000000000000000000000000000" "uv-$triple.tar.gz" > "$dir/uv-$triple.tar.gz.sha256" ;;
		none) : ;;
		junk) printf 'not a checksum\n' > "$dir/uv-$triple.tar.gz.sha256" ;;
		*) printf '%s  %s\n' "$( rigSha "$dir/uv-$triple.tar.gz" )" "uv-$triple.tar.gz" > "$dir/uv-$triple.tar.gz.sha256" ;;
	esac
}
## A scenario: its own workspace, HOME, logs and fixtures. rigRun runs the tool in it; the result is in rigRc, <dir>/out, <dir>/err.
rigNew(){ ## name, uname -s, uname -m [libc] -- a fresh machine
	rigDir="$rigTmp/$1" ; rigS="$2" ; rigM="$3" ; rigLibc="${4:-glibc}" ; rigFix="$rigFixtures" ; rigOffline=""
	mkdir -p "$rigDir/ws/.local" "$rigDir/home"
	: > "$rigDir/curl.log" ; : > "$rigDir/uv.log"
}
rigRun(){ ## the tool's arguments
	rigRc=0
	( cd "$rigTmp/cwd" && env -i HOME="$rigDir/home" PATH="$rigBin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" \
		RIG_UNAME_S="$rigS" RIG_UNAME_M="$rigM" RIG_LIBC="$rigLibc" RIG_FIXTURES="$rigFix" RIG_CURL_LOG="$rigDir/curl.log" RIG_UV_LOG="$rigDir/uv.log" ${rigOffline:+RIG_CURL_FAIL=1} \
		bash "$rigTool" "$@" ) > "$rigDir/out" 2> "$rigDir/err" || rigRc=$?
}
rigCurls(){ ## -- how many requests the scenario made
	LC_ALL=C wc -l < "$rigDir/curl.log" | LC_ALL=C tr -d ' '
}
rigTree(){ ## folder -- what stands below it, sorted, one line
	( cd "$1" && find . -mindepth 1 | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )
}
rigEmbedded="embedded-python"

echo "-- 1. the operation stands apart, its include in a folder of its own, its help as a pair --"
rigAssert "the include stands in sh-lib/python/, and nothing of its name at the root of sh-lib" "$( [ -f "$rigInclude" ] && printf include ) $( ls "$rigPkg/sh-lib" | LC_ALL=C grep -c 'EmbeddedPython' | LC_ALL=C sed -e 's/^[1-9][0-9]*$/at-root/' )" "include 0"
rigAssert "the dispatcher has one arm for it, which includes that file" "$( LC_ALL=C grep -c -x -e '[[:space:]]*--install-embedded-python)' "$rigTool" ) $( LC_ALL=C grep -c -F -e '. "$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/python/LocalTools.EmbeddedPython.include"' "$rigTool" )" "1 1"
rigAssert "the --install-distro-* arm holds nothing of it" "$( LC_ALL=C awk '/^[[:space:]]*--install-distro-\*\)/ { on = 1 } /^[[:space:]]*--upgrade-installed-tools\)/ { on = 0 } on && /embedded/ { n++ } END { print n + 0 }' "$rigTool" )" "0"
rigAssert "its help is a pair beside the others: the manual and the include" "$( [ -f "$rigPkg/sh-lib/help/Help.DistroLocalTools-install-embedded-python.help.md" ] && printf manual ) $( [ -f "$rigPkg/sh-lib/help/Help.DistroLocalTools-install-embedded-python.include" ] && printf include )" "manual include"
rigAssert "the manual has the package's shape: two syntax lines, then Summary, Arguments, Options, Notes and Examples" "$( LC_ALL=C grep -c -e '^📘 syntax: DistroLocalTools.fn.sh --install-embedded-python' -e '^##  Summary:' -e '^##  Arguments:' -e '^##  Options:' -e '^##  Notes:' -e '^##  Examples:' "$rigPkg/sh-lib/help/Help.DistroLocalTools-install-embedded-python.help.md" 2> /dev/null )" "7"
rigAssert "the package's manual and its command list name the operation, and the list links its manual" "$( LC_ALL=C grep -c -F -e '--install-embedded-python' "$rigPkg/sh-lib/help/Help.DistroLocalTools.help.md" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/manual/' ) $( LC_ALL=C grep -c -F -e '--install-embedded-python' "$rigPkg/docs/commands.md" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/list/' ) $( LC_ALL=C grep -c -F -e 'Help.DistroLocalTools-install-embedded-python.help.md' "$rigPkg/docs/commands.md" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/link/' )" "manual list link"
rigNew help Linux x86_64
rigRun --install-embedded-python --help
rigAssert "--help prints the manual: rc 0, both options, and the systems refused" "$rigRc $( LC_ALL=C grep -c -F -e '--uv-version' -e '--from-folder' -e 'FreeBSD' "$rigDir/err" "$rigDir/out" | LC_ALL=C awk -F: '{ n += $2 } END { print ( n >= 3 ) ? "all" : "missing" }' ) $( rigCurls ) $( rigTree "$rigDir/ws/.local" )" "0 all 0 "
rigNew mixed Linux x86_64
rigRun --install-distro-source --install-embedded-python
rigAssert "it does not combine with --install-distro-*: refused, invalid option, nothing written" "$( [ "$rigRc" -ne 0 ] && printf refused ) $( LC_ALL=C grep -c -F 'invalid option' "$rigDir/err" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/said/' ) $( rigCurls ) $( rigTree "$rigDir/ws/.local" )" "refused said 0 "

echo "-- 2. an exact pinned uv release, for the machine, checked against the checksum beside it --"
for rigCase in "darwin-arm64:Darwin:arm64:aarch64-apple-darwin:glibc" "darwin-x64:Darwin:x86_64:x86_64-apple-darwin:glibc" "linux-x64:Linux:x86_64:x86_64-unknown-linux-gnu:glibc" "linux-arm64:Linux:aarch64:aarch64-unknown-linux-gnu:glibc" "linux-x64-musl:Linux:x86_64:x86_64-unknown-linux-musl:musl" ; do
	IFS=: read -r rigName rigS0 rigM0 rigTriple rigLibc0 <<< "$rigCase"
	rigRelease "$rigPinned" "$rigTriple"
	rigNew "$rigName" "$rigS0" "$rigM0" "$rigLibc0"
	rigRun --install-embedded-python
	rigAssert "$rigName: installed, rc 0, and the two requests are the pinned archive and its .sha256 beside it" "$rigRc $( LC_ALL=C sed -e 's/^.* //' "$rigDir/curl.log" | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "0 https://github.com/astral-sh/uv/releases/download/$rigPinned/uv-$rigTriple.tar.gz https://github.com/astral-sh/uv/releases/download/$rigPinned/uv-$rigTriple.tar.gz.sha256 "
	rigAssert "$rigName: the unpacked uv is in a folder of .local and says the pinned version" "$( env -i PATH=/usr/bin:/bin "$rigDir/ws/.local/$rigEmbedded/uv/uv" --version 2>&1 )" "uv $rigPinned (rig stub)"
done
rigAssert "the pin is one default in the include: the pinned version stands on one line of it" "$( LC_ALL=C grep -c -F -e "$rigPinned" "$rigInclude" 2> /dev/null )" "1"
rigRelease "$rigPinned" x86_64-unknown-linux-gnu star
rigNew star Linux x86_64
rigRun --install-embedded-python
rigAssert "a checksum file in the form 'hash *name' is read by its hash" "$rigRc $( env -i PATH=/usr/bin:/bin "$rigDir/ws/.local/$rigEmbedded/uv/uv" --version 2>&1 )" "0 uv $rigPinned (rig stub)"
rigRelease 0.12.9 x86_64-unknown-linux-gnu
rigNew other Linux x86_64
rigRun --install-embedded-python --uv-version 0.12.9
rigAssert "--uv-version names another release: its archive is the one fetched, and that uv is the one installed" "$rigRc $( LC_ALL=C grep -c -F -e 'releases/download/0.12.9/uv-x86_64-unknown-linux-gnu.tar.gz' "$rigDir/curl.log" ) $( env -i PATH=/usr/bin:/bin "$rigDir/ws/.local/$rigEmbedded/uv/uv" --version 2>&1 )" "0 2 uv 0.12.9 (rig stub)"
for rigBadVersion in latest 0.13 0.13.1/../x '' ; do
	rigNew badver Linux x86_64
	rigRun --install-embedded-python --uv-version "$rigBadVersion"
	rigAssert "a version that is no version is refused, nothing fetched, nothing written: [$rigBadVersion]" "$( [ "$rigRc" -ne 0 ] && printf refused ) $( rigCurls ) $( rigTree "$rigDir/ws/.local" )" "refused 0 "
done
rigRelease "$rigPinned" x86_64-unknown-linux-gnu

echo "-- 3. a checksum that does not match, is missing or is none refuses the install --"
for rigForm in wrong none junk ; do
	rm -rf "$rigFixtures/$rigPinned" ; rigRelease "$rigPinned" x86_64-unknown-linux-gnu "$rigForm"
	rigNew "sum-$rigForm" Linux x86_64
	rigRun --install-embedded-python
	rigAssert "checksum file '$rigForm': refused, rc non-zero, checksum said, no uv left, no python asked for" "$( [ "$rigRc" -ne 0 ] && printf refused ) $( LC_ALL=C grep -c -i 'checksum' "$rigDir/err" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/said/' ) $( [ -e "$rigDir/ws/.local/$rigEmbedded/uv" ] && printf uv-left ) $( [ -s "$rigDir/uv.log" ] && printf asked )" "refused said  "
	rigAssert "checksum file '$rigForm': the archive that failed is not kept for another run" "$( find "$rigDir/ws/.local" -name 'uv-*.tar.gz' 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "0"
done
rm -rf "$rigFixtures/$rigPinned" ; rigRelease "$rigPinned" x86_64-unknown-linux-gnu

echo "-- 4. a standalone CPython of the pinned minor, and every folder uv uses a folder of .local --"
rigNew py Linux x86_64
rigRun --install-embedded-python
rigBase="$rigDir/ws/.local/$rigEmbedded"
rigMinor="$( LC_ALL=C sed -n 's/^CALL python install //p' "$rigDir/uv.log" | head -1 )"
rigAssert "uv installs one Python, of a minor that is 3.12 or later" "$( LC_ALL=C grep -c '^CALL python install ' "$rigDir/uv.log" ) $( printf '%s' "$rigMinor" | LC_ALL=C awk -F. 'NF == 2 && $1 == 3 && $2 >= 12 { print "ok" }' )" "1 ok"
rigAssert "UV_NO_MODIFY_PATH is set, so that no shell file is edited" "$( LC_ALL=C grep -c -x 'UV_NO_MODIFY_PATH=1' "$rigDir/uv.log" )" "1"
rigOut=""
for rigVarName in UV_PYTHON_INSTALL_DIR UV_CACHE_DIR UV_TOOL_DIR UV_TOOL_BIN_DIR UV_PYTHON_BIN_DIR UV_PYTHON_CACHE_DIR "$rigTmpVar" ; do
	rigValue="$( LC_ALL=C sed -n "s/^$rigVarName=//p" "$rigDir/uv.log" | head -1 )"
	case "$rigValue" in "$rigBase/"?*) ;; *) rigOut="$rigOut [$rigVarName=$rigValue]" ;; esac
done
rigAssert "each of the seven folders uv uses (Python, cache, tools and their bin, the Python bin, the archives, the temp folder of its process) is a folder of the workspace's .local/$rigEmbedded" "[${rigOut# }]" "[]"
rigPython="$( cat "$rigDir/out" )"
rigAssert "the operation prints the Python it made, on standard output, and that Python runs" "$( case "$rigPython" in ("$rigBase/"*) env -i PATH=/usr/bin:/bin "$rigPython" --version 2>&1 ;; (*) printf '%s' "$rigPython" ;; esac )" "Python $rigMinor.0"
rigAssert "it says where it put things: the uv, the Python and the folder" "$( LC_ALL=C grep -c -F -e "$rigBase/uv/uv" -e "$rigPython" -e "$rigBase" "$rigDir/err" | LC_ALL=C sed -e 's/^[3-9]$/all/;s/^[1-9][0-9]\+$/all/' )" "all"
rigAssert "and it keeps the files it fetched, for a host with no internet: the uv archive, its .sha256, the Python archive" "$( ls "$rigBase/downloads" | LC_ALL=C tr '\n' ' ' ) $( ls "$rigBase/downloads/python" 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "python uv-x86_64-unknown-linux-gnu.tar.gz uv-x86_64-unknown-linux-gnu.tar.gz.sha256  1"

echo "-- 5. nothing outside the workspace's .local is touched --"
rigAssert "the HOME of the rig is empty, the workspace holds .local alone, and .local holds the one folder" "[$( rigTree "$rigDir/home" )] [$( ls -A "$rigDir/ws" | LC_ALL=C tr '\n' ' ' )] [$( ls -A "$rigDir/ws/.local" | LC_ALL=C tr '\n' ' ' )] [$( rigTree "$rigTmp/cwd" )]" "[] [.local ] [$rigEmbedded ] []"
rigAssert "the Python it installed stands in the folder named for it, and nowhere else in the rig" "$( find "$rigDir" -name 'python3.12' -not -path "$rigBase/*" 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "0"

echo "-- 6. the second run changes nothing and fetches nothing, and says where things are --"
sleep 1
: > "$rigDir/marker"
sleep 1
rigBefore="$( LC_ALL=C cat "$rigDir/out" )"
: > "$rigDir/curl.log" ; : > "$rigDir/uv.log"
rigRun --install-embedded-python
rigAssert "rc 0, no request, no call of uv, the same Python printed, and it says it stands" "$rigRc $( rigCurls ) $( LC_ALL=C grep -c . "$rigDir/uv.log" ) $( [ "$( cat "$rigDir/out" )" = "$rigBefore" ] && printf same ) $( LC_ALL=C grep -c -i 'already' "$rigDir/err" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/said/' )" "0 0 0 same said"
rigAssert "no file or folder of .local was made or changed by it" "$( find "$rigDir/ws/.local" -newer "$rigDir/marker" 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "0"

echo "-- 7. an install from files downloaded once elsewhere --"
## What a person carries to the host with no internet: the downloads folder of an online run, copied.
rigCarried="$rigTmp/carried"
cp -R "$rigBase/downloads" "$rigCarried"
rigCarriedTree="$( rigTree "$rigCarried" )"
rigNew off Linux x86_64
rigOffline=1
rigRun --install-embedded-python --from-folder "$rigCarried"
rigBaseOff="$rigDir/ws/.local/$rigEmbedded"
rigPythonOff="$( cat "$rigDir/out" )"
rigAssert "with no network at all: rc 0, no request, and the Python it printed is one of .local and runs" "$rigRc $( rigCurls ) $( case "$rigPythonOff" in ("$rigBaseOff/"*) env -i PATH=/usr/bin:/bin "$rigPythonOff" --version 2>&1 ;; (*) printf '%s' "$rigPythonOff" ;; esac )" "0 0 Python $rigMinor.0"
rigAssert "the uv is the pinned one, unpacked from the folder's archive after its checksum was read" "$( env -i PATH=/usr/bin:/bin "$rigBaseOff/uv/uv" --version 2>&1 )" "uv $rigPinned (rig stub)"
rigAssert "uv took its Python archive from the folder: its archive cache is the folder's python/, nothing came from the network" "$( LC_ALL=C grep -c '^FROM-CACHE' "$rigDir/uv.log" ) $( LC_ALL=C grep -c '^NETWORK' "$rigDir/uv.log" ) $( LC_ALL=C sed -n 's/^UV_PYTHON_CACHE_DIR=//p' "$rigDir/uv.log" | head -1 )" "1 0 $rigCarried/python"
rigAssert "the folder is left as it was, no downloads folder is made in .local, and nothing is outside it" "$( [ "$( rigTree "$rigCarried" )" = "$rigCarriedTree" ] && printf same ) $( [ -e "$rigBaseOff/downloads" ] && printf made ) [$( rigTree "$rigDir/home" )] [$( ls -A "$rigDir/ws" | LC_ALL=C tr '\n' ' ' )]" "same  [] [.local ]"
## a folder that does not hold what the install needs is refused before anything is written
rigRefuseCase(){ ## label, the folder, what the message names
	rigNew "from-$1" Linux x86_64 ; rigOffline=1
	rigRun --install-embedded-python --from-folder "$2"
	rigAssert "$1: refused, rc non-zero, it names $3, no request, nothing written" "$( [ "$rigRc" -ne 0 ] && printf refused ) $( LC_ALL=C grep -c -F -e "$3" "$rigDir/err" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/named/' ) $( rigCurls ) [$( rigTree "$rigDir/ws/.local" )] [$( rigTree "$rigDir/home" )]" "refused named 0 [] []"
}
cp -R "$rigCarried" "$rigTmp/carried-tampered" ; printf 'x' >> "$rigTmp/carried-tampered/uv-x86_64-unknown-linux-gnu.tar.gz"
rigRefuseCase "tampered archive" "$rigTmp/carried-tampered" "checksum"
cp -R "$rigCarried" "$rigTmp/carried-nosum" ; rm -f "$rigTmp/carried-nosum/uv-x86_64-unknown-linux-gnu.tar.gz.sha256"
rigRefuseCase "no checksum file" "$rigTmp/carried-nosum" "$rigTmp/carried-nosum/uv-x86_64-unknown-linux-gnu.tar.gz.sha256"
cp -R "$rigCarried" "$rigTmp/carried-nopython" ; rm -rf "$rigTmp/carried-nopython/python"
rigRefuseCase "no Python archive" "$rigTmp/carried-nopython" "$rigTmp/carried-nopython/python"
cp -R "$rigCarried" "$rigTmp/carried-noarchive" ; rm -f "$rigTmp/carried-noarchive/uv-x86_64-unknown-linux-gnu.tar.gz"
rigRefuseCase "no uv archive" "$rigTmp/carried-noarchive" "$rigTmp/carried-noarchive/uv-x86_64-unknown-linux-gnu.tar.gz"
rigRefuseCase "no such folder" "$rigTmp/there-is-no-such-folder" "$rigTmp/there-is-no-such-folder"

echo "-- 8. a system no standalone build covers is refused, with the reason, and nothing is written --"
for rigCase in "freebsd-amd64:FreeBSD:amd64" "freebsd-arm64:FreeBSD:arm64" "linux-armv7:Linux:armv7l" "openbsd:OpenBSD:amd64" "darwin-ppc:Darwin:Power Macintosh" ; do
	IFS=: read -r rigName rigS0 rigM0 <<< "$rigCase"
	rigNew "no-$rigName" "$rigS0" "$rigM0"
	rigRun --install-embedded-python
	rigAssert "$rigName: refused, rc non-zero, it names the system and that no standalone build covers it, no request, nothing written" "$( [ "$rigRc" -ne 0 ] && printf refused ) $( LC_ALL=C grep -c -F -e "$rigS0" "$rigDir/err" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/named/' ) $( LC_ALL=C grep -c -i 'standalone' "$rigDir/err" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/reason/' ) $( rigCurls ) [$( rigTree "$rigDir/ws/.local" )] [$( rigTree "$rigDir/home" )] [$( [ -s "$rigDir/out" ] && printf printed )]" "refused named reason 0 [] [] []"
done
rigNew no-freebsd-folder FreeBSD amd64
rigRun --install-embedded-python --from-folder "$rigCarried"
rigAssert "FreeBSD with a folder of files: the same refusal, the folder does not change it" "$( [ "$rigRc" -ne 0 ] && printf refused ) $( LC_ALL=C grep -c -i 'FreeBSD' "$rigDir/err" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/named/' ) [$( rigTree "$rigDir/ws/.local" )]" "refused named []"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ EMBEDDED PYTHON INSTALL CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'EMBEDDED_PYTHON_INSTALL: OK (%d assertions, offline, no uv or Python fetched)\n' "$rigPasses"
