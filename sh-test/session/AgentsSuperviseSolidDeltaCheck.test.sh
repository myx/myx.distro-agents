#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
## Behavioural check on the scan's `solid-delta` kind: the live SOLID gate's kept total, and the files the tree changed since it
## last read 0. Held:
##   1. the control: a workspace whose gate kept no reading reads no `solid-delta` line
##   2. a kept reading reads `solid-delta <ws> total=<n> at=<n>m zero=<n>m files=<n>`, and a second line names the files
##   3. the files are the ones newer than that instant; the control is a file older than it, which is not named
##   4. a tree that has never read 0 reads `zero=none files=0`, since there is no instant to measure a delta from
##   5. the owner keeps the reading: a write of 0 records that instant, and a later write of rows leaves it standing
## Red before the kind: no `solid-delta` line exists at all. Offline: the rig is the check's own, and its tree is a stand-in.
set -u
rigCheckName="SUPERVISE_SOLID_DELTA"
. "$( dirname "${BASH_SOURCE[0]}" )/../check-fixtures/supervise-scan.rig.include.sh" || exit 1
type AgentsToolsSolidGateMarkerWrite > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/supervise/AgentsTools.SuperviseSolidDelta.include"
rigScanBegin "$rigCheckName"

## The stand-in tree the marker names, and two files in it: one older than the gate's zero reading, one newer.
rigPkgTree="$rigTmp/pkg"
mkdir -p "$rigPkgTree/sh-lib" || rigRefuse "the stand-in tree could not be made"
printf 'one\n' > "$rigPkgTree/sh-lib/Older.include" || rigRefuse "the older file could not be made"
printf 'two\n' > "$rigPkgTree/sh-lib/Newer.include" || rigRefuse "the newer file could not be made"
rigStamp(){ date -r "$1" '+%Y%m%d%H%M.%S' 2> /dev/null || date -d "@$1" '+%Y%m%d%H%M.%S' 2> /dev/null ; }
rigIsoOf(){ date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ 2> /dev/null || date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ 2> /dev/null ; }
touch -t "$( rigStamp $(( rigNow - 1200 )) )" "$rigPkgTree/sh-lib/Older.include" || rigRefuse "the older file's date could not be set"
touch -t "$( rigStamp $(( rigNow - 60 )) )" "$rigPkgTree/sh-lib/Newer.include" || rigRefuse "the newer file's date could not be set"
rigMarker="$rigWs/.local/agents/solid-gate.last"

rigOut="$( rigScan )"
rigAssert "the control: a gate that kept no reading reads no solid-delta line" "$( rigKindHas solid-delta 'total=' )" "0"

## A reading the gate kept: its total, and the instant it read 0, which is a ten-minute-old moment of this rig's own.mkdir -p "${rigMarker%/*}" || rigRefuse "the marker folder could not be made"
printf 'total 3\nat %s\nzero-at %s\npackage %s\n' "$( rigIsoOf "$rigNow" )" "$( rigIsoOf $(( rigNow - 600 )) )" "$rigPkgTree" > "$rigMarker" \
	|| rigRefuse "the marker could not be made"
rigOut="$( rigScan )"
rigAssert "a kept reading reads solid-delta" "$( rigKindHas solid-delta 'total=3' )" "1"
rigAssert "and its line carries the total, both ages and the file count" \
	"$( printf '%s' "$( rigKind solid-delta )" | LC_ALL=C grep -c 'total=3 at=[0-9]*m zero=[0-9]*m files=1' )" "1"
rigAssert "a second line names the newer file" "$( rigKindHas solid-delta 'sh-lib/Newer.include' )" "1"
rigAssert "the control: the file older than the zero instant is not named" "$( rigKindHas solid-delta 'Older.include' )" "0"

## A tree that has never read 0: the marker carries `zero-at -`, as the owner writes when it is given none.
printf 'total 3\nat %s\nzero-at -\npackage %s\n' "$( rigIsoOf "$rigNow" )" "$rigPkgTree" > "$rigMarker" || rigRefuse "the marker could not be made"
rigOut="$( rigScan )"
rigAssert "a tree that never read 0 reads zero=none" "$( rigKindHas solid-delta 'zero=none' )" "1"
rigAssert "and names no files, since there is no instant to measure from" "$( rigKindHas solid-delta 'files=0' )" "1"

## The owner's two directions, on a folder of its own so the reading above stands as it was.
rigOwnerWs="$rigTmp/ownerws"
mkdir -p "$rigOwnerWs" || rigRefuse "the owner's workspace could not be made"
AgentsToolsSolidGateMarkerWrite "$rigOwnerWs" 0 "$rigPkgTree" || rigRefuse "the owner refused to keep a zero reading"
rigOwnerMarker="$rigOwnerWs/.local/agents/solid-gate.last"
rigKeptZero="$( LC_ALL=C awk '$1 == "zero-at" { print $2 ; }' "$rigOwnerMarker" )"
rigAssert "a reading of 0 records the instant it read 0" "$( [ -n "$rigKeptZero" ] && [ "$rigKeptZero" != "-" ] && echo kept )" kept
AgentsToolsSolidGateMarkerWrite "$rigOwnerWs" 5 "$rigPkgTree" || rigRefuse "the owner refused to keep a reading of rows"
rigAssert "a later reading of rows leaves that instant standing" "$( LC_ALL=C awk '$1 == "zero-at" { print $2 ; }' "$rigOwnerMarker" )" "$rigKeptZero"
rigAssert "and keeps the total it was given" "$( LC_ALL=C awk '$1 == "total" { print $2 ; }' "$rigOwnerMarker" )" "5"

rigScanDone
