#!/usr/bin/env bash
## Behavioural check on Read AS THE MCP SERVER SERVES IT: every call goes through the real
## server's tools/call, and every answer is read off the wire it writes. It covers cat -n
## numbering, whole-file and range reads, the 48 KB cap over the numbered bytes, the separate
## request/result part, raw Skill output, PNG image parts, PDF pages and notebook cells.
## Each gap assertion sits beside a control that passes on the tree before the fix, so a
## FAIL there is the gap and not a broken rig. Offline: MMDAPP and HOME are this rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"

rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigField="$rigHere/AgentsHarnessJsonField.awk"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

for rigFile in "$rigHere/AgentsUniversalHarness.sh" "$rigField" "$rigTool" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

rigTmp="$( mktemp -d -t "AgentsHarnessReadNativeCheck-XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

## `source/` is inside the access roots the server computes for a workspace; the rig root itself is not.
mkdir -p "$rigTmp/.local" "$rigTmp/source/fix" "$rigTmp/home/.claude/skills" "$rigTmp/owners/rig-keeper"
printf 'alpha\nbeta\ngamma\n' > "$rigTmp/source/fix/a.txt"
## Under the cap raw (40500 bytes), over it once each line carries its 7-byte number; under
## the 2000-line default, so only the byte cap can cut it.
LC_ALL=C awk 'BEGIN { for ( lineNo = 1 ; lineNo <= 1500 ; lineNo++ ) print "abcdefghijklmnopqrstuvwxyz" ; }' > "$rigTmp/source/fix/numbered-over.txt"
## Over the cap raw (52500 bytes), numbered or not, and under the 2000-line default.
LC_ALL=C awk 'BEGIN { for ( lineNo = 1 ; lineNo <= 1500 ; lineNo++ ) print "abcdefghijklmnopqrstuvwxyzabcdefgh" ; }' > "$rigTmp/source/fix/raw-over.txt"
## Over the 2000-line default and far under the byte cap.
LC_ALL=C awk 'BEGIN { for ( lineNo = 1 ; lineNo <= 3000 ; lineNo++ ) print "x" ; }' > "$rigTmp/source/fix/lines-over.txt"
: > "$rigTmp/source/fix/empty.txt"
printf 'bravo-file\n' > "$rigTmp/source/fix/b.txt"
printf 'rig-keeper-boot\n' > "$rigTmp/owners/rig-keeper/SKILL.md"
printf 'rig-keeper-armed\nsecond\n' > "$rigTmp/owners/rig-keeper/rig-keeper.armed.md"
ln -s "$rigTmp/owners/rig-keeper" "$rigTmp/home/.claude/skills/rig-keeper"

## A 1x1 PNG, held as the base64 the image part must carry.
rigPng64='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='
printf '%s' "$rigPng64" | base64 --decode > "$rigTmp/source/fix/pixel.png" || rigRefuse "could not write the PNG fixture"

## A 22-page PDF written by hand, page N showing RIGPDFPAGE<NN> in Helvetica, with a real xref.
rigPdf='%PDF-1.4'$'\n' ; rigPdfOffsets=() ; rigPdfKids=''
for (( rigPageNo = 1 ; rigPageNo <= 22 ; rigPageNo++ )) ; do
	rigPdfKids="$rigPdfKids $(( rigPageNo * 2 + 2 )) 0 R"
done
rigPdfObj(){ ## object body -- appended as the next object number
	rigPdfOffsets+=( "${#rigPdf}" )
	rigPdf="$rigPdf${#rigPdfOffsets[@]} 0 obj"$'\n'"$1"$'\n'"endobj"$'\n'
}
rigPdfObj '<< /Type /Catalog /Pages 2 0 R >>'
rigPdfObj "<< /Type /Pages /Kids [$rigPdfKids ] /Count 22 >>"
rigPdfObj '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>'
for (( rigPageNo = 1 ; rigPageNo <= 22 ; rigPageNo++ )) ; do
	printf -v rigPdfStream 'BT /F1 24 Tf 72 720 Td (RIGPDFPAGE%02d) Tj ET' "$rigPageNo"
	rigPdfObj "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 3 0 R >> >> /Contents $(( ${#rigPdfOffsets[@]} + 2 )) 0 R >>"
	rigPdfObj "<< /Length ${#rigPdfStream} >>"$'\n'"stream"$'\n'"$rigPdfStream"$'\n'"endstream"
done
rigPdfXref="${#rigPdf}"
rigPdf="${rigPdf}xref"$'\n'"0 $(( ${#rigPdfOffsets[@]} + 1 ))"$'\n'"0000000000 65535 f "$'\n'
for rigPdfOffset in "${rigPdfOffsets[@]}" ; do
	printf -v rigPdfEntry '%010d 00000 n \n' "$rigPdfOffset"
	rigPdf="$rigPdf$rigPdfEntry"
done
rigPdf="${rigPdf}trailer"$'\n'"<< /Size $(( ${#rigPdfOffsets[@]} + 1 )) /Root 1 0 R >>"$'\n'"startxref"$'\n'"$rigPdfXref"$'\n'"%%EOF"$'\n'
printf '%s' "$rigPdf" > "$rigTmp/source/fix/pages.pdf"

## Cell 1 is code with stream output, cell 2 is markdown. No digit sits in either cell's own text.
printf '%s\n' '{"cells":[{"cell_type":"code","execution_count":null,"metadata":{},"outputs":[{"name":"stdout","output_type":"stream","text":["RIGNBOUT\n"]}],"source":["print(\"RIGNBCODE\")"]},{"cell_type":"markdown","metadata":{},"source":["# RIGNBMARK"]}],"metadata":{},"nbformat":4,"nbformat_minor":4}' > "$rigTmp/source/fix/cells.ipynb"

rigFix="$rigTmp/source/fix"
{
	printf '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"Read","arguments":{"path":"%s"}}}\n' "$rigFix/a.txt"
	printf '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"Read","arguments":{"path":"%s","offset":2,"limit":1}}}\n' "$rigFix/a.txt"
	printf '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"Read","arguments":{"path":"%s"}}}\n' "$rigFix/numbered-over.txt"
	printf '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"Read","arguments":{"path":"%s"}}}\n' "$rigFix/raw-over.txt"
	printf '%s\n' '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"Skill","arguments":{"name":"rig-keeper/rig-keeper.armed.md"}}}'
	printf '{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"Read","arguments":{"path":"%s"}}}\n' "$rigFix/pixel.png"
	printf '{"jsonrpc":"2.0","id":8,"method":"tools/call","params":{"name":"Read","arguments":{"path":"%s","pages":"1"}}}\n' "$rigFix/pages.pdf"
	printf '{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"Read","arguments":{"path":"%s","pages":"1"}}}\n' "$rigFix/a.txt"
	printf '{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"Read","arguments":{"path":"%s","pages":"1-21"}}}\n' "$rigFix/pages.pdf"
	printf '{"jsonrpc":"2.0","id":11,"method":"tools/call","params":{"name":"Read","arguments":{"path":"%s","pages":"1-20"}}}\n' "$rigFix/pages.pdf"
	printf '{"jsonrpc":"2.0","id":12,"method":"tools/call","params":{"name":"Read","arguments":{"path":"%s"}}}\n' "$rigFix/cells.ipynb"
	printf '{"jsonrpc":"2.0","id":13,"method":"tools/call","params":{"name":"Read","arguments":{"path":"%s"}}}\n' "$rigFix"
	printf '{"jsonrpc":"2.0","id":14,"method":"tools/call","params":{"name":"Read","arguments":{"path":"%s"}}}\n' "$rigFix/empty.txt"
	printf '{"jsonrpc":"2.0","id":15,"method":"tools/call","params":{"name":"Read","arguments":{"file_path":"%s"}}}\n' "$rigFix/a.txt"
	printf '{"jsonrpc":"2.0","id":16,"method":"tools/call","params":{"name":"Read","arguments":{"path":"%s","file_path":"%s"}}}\n' "$rigFix/a.txt" "$rigFix/b.txt"
	printf '%s\n' '{"jsonrpc":"2.0","id":17,"method":"tools/call","params":{"name":"Read","arguments":{}}}'
	printf '{"jsonrpc":"2.0","id":18,"method":"tools/call","params":{"name":"Read","arguments":{"path":"%s"}}}\n' "$rigFix/lines-over.txt"
	printf '%s\n' '{"jsonrpc":"2.0","id":19,"method":"tools/list","params":{}}'
} | MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" HOME="$rigTmp/home" MDAT_SKILLSET_ROOT="$rigTmp/home/.claude/skills" \
	bash "$rigTool" --intern-mcp-server --run > "$rigTmp/wire" 2> "$rigTmp/err" || :

## A request the server never answered was never exercised, so the run stops there.
for rigId in 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 ; do
	LC_ALL=C grep -q "^{\"jsonrpc\":\"2.0\",\"id\":$rigId," "$rigTmp/wire" || {
		echo "-- the server left request $rigId unanswered, so its stderr follows --" >&2
		sed 's/^/    /' "$rigTmp/err" >&2
		rigRefuse "no tools/call answer for request $rigId"
	}
done

rigWire(){ ## request id -- its raw response line
	LC_ALL=C grep -m1 "^{\"jsonrpc\":\"2.0\",\"id\":$1," "$rigTmp/wire"
}

rigPart(){ ## request id, json path under result.content -- the decoded value, empty when absent
	rigWire "$1" | LC_ALL=C awk -v path="result.content.$2" -v optional=1 -f "$rigField" 2>/dev/null || :
}

## The tool's own result: the last text part, since the head part goes first.
rigResult(){ ## request id
	local partIndex
	partIndex="$( rigPart "$1" __count )"
	partIndex=$(( ${partIndex:-0} - 1 ))
	while [ "$partIndex" -ge 0 ] ; do
		[ "$( rigPart "$1" "$partIndex.type" )" != text ] || { rigPart "$1" "$partIndex.text" ; return 0 ; }
		partIndex=$(( partIndex - 1 ))
	done
}

rigHas(){ ## text, needle -- yes when the text holds it
	case "$1" in *"$2"*) printf 'yes' ;; *) printf 'no' ;; esac
}

rigIsError(){ ## text -- yes when it is a refusal
	case "$1" in ERROR*) printf 'yes' ;; *) printf 'no' ;; esac
}

rigFails=0
rigAssert(){ ## what is asserted, got, want -- a tab prints as \t
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1"
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "${2//$'\t'/\\t}" "${3//$'\t'/\\t}"
		rigFails=$(( rigFails + 1 ))
	fi
}

echo "-- whole-file and range reads are numbered in cat -n form --"
rigText="$( rigResult 2 )"
rigAssert "control: the whole read returns the file's lines" "$( rigHas "$rigText" alpha )$( rigHas "$rigText" gamma )" "yesyes"
rigAssert "whole read, line 1 is numbered 1" "${rigText%%$'\n'*}" $'     1\talpha'
rigAssert "whole read, line 2 is numbered 2" "$( sed -n 2p <<< "$rigText" )" $'     2\tbeta'
rigText="$( rigResult 3 )"
rigAssert "control: the range read returns the offset line" "$( rigHas "$rigText" beta )" "yes"
rigAssert "a range read starts at the offset's own number" "${rigText%%$'\n'*}" $'     2\tbeta'

echo "-- the 48 KB cap counts the numbered bytes --"
rigAssert "control: a file over the cap raw is truncated with a continue footer" "$( rigHas "$( rigResult 5 )" 'continue with offset' )" "yes"
rigAssert "a file under the cap raw but over it numbered is truncated with a continue footer" "$( rigHas "$( rigResult 4 )" 'continue with offset' )" "yes"

echo "-- the separate request/result part is still produced --"
rigAssert "the head part leads the answer, names Read and carries a result line" \
	"$( rigHas "$( rigWire 2 )" '"result":{"content":[{"type":"text","text":"   📖 Read ' )$( rigHas "$( rigPart 2 0.text )" '      result ' )" "yesyes"

echo "-- Skill output stays raw --"
rigText="$( rigResult 6 )"
rigAssert "control: Skill returns the file unnumbered" "${rigText%%$'\n'*}" "rig-keeper-armed"

echo "-- a PNG comes back as an image content part --"
rigAssert "control: the PNG read was answered with its head part" "$( rigHas "$( rigWire 7 )" '"result":{"content":[{"type":"text","text":"   📖 Read ' )" "yes"
rigImage="none"
rigIndex=0
while [ -n "$( rigPart 7 "$rigIndex.type" )" ] ; do
	[ "$( rigPart 7 "$rigIndex.type" )" != image ] || rigImage="$( rigPart 7 "$rigIndex.mimeType" ):$( rigPart 7 "$rigIndex.data" )"
	rigIndex=$(( rigIndex + 1 ))
done
rigAssert "an image part carries image/png and the file's base64" "$rigImage" "image/png:$rigPng64"

echo "-- PDF pages --"
rigText="$( rigResult 8 )"
rigAssert "control: pages 1 of the PDF returns page 1's text" "$( rigHas "$rigText" RIGPDFPAGE01 )" "yes"
rigAssert "pages 1 of the PDF returns no other page's text" "$( rigHas "$rigText" RIGPDFPAGE02 )" "no"
rigAssert "control: a non-PDF without pages is not refused" "$( rigIsError "$( rigResult 2 )" )" "no"
rigAssert "pages on a non-PDF is refused" "$( rigIsError "$( rigResult 9 )" )" "yes"
rigAssert "control: 20 pages requested is not refused" "$( rigIsError "$( rigResult 11 )" )" "no"
rigAssert "21 pages requested is refused" "$( rigIsError "$( rigResult 10 )" )" "yes"

echo "-- a notebook returns each cell's number, type, source and output --"
rigText="$( rigResult 12 )"
rigAssert "control: the notebook read is not refused" "$( rigIsError "$rigText" )" "no"
rigAssert "both cell types, both sources and the output text are present" \
	"$( rigHas "$rigText" code )$( rigHas "$rigText" markdown )$( rigHas "$rigText" RIGNBCODE )$( rigHas "$rigText" RIGNBMARK )$( rigHas "$rigText" RIGNBOUT )" "yesyesyesyesyes"
## A cat -n prefix is stripped first, so a line number is never taken for a cell number.
rigCells="$( printf '%s\n' "$rigText" | LC_ALL=C awk '
	{ sub( /^ *[0-9]+\t/, "" ) ; cellText = cellText "\n" $0 ; }
	END {
		codeAt = index( cellText, "RIGNBCODE" ) ; outAt = index( cellText, "RIGNBOUT" ) ; markAt = index( cellText, "RIGNBMARK" )
		firstCell = codeAt > 0 && substr( cellText, 1, codeAt - 1 ) ~ /(^|[^0-9])1([^0-9]|$)/
		secondFrom = ( outAt > codeAt ) ? outAt : codeAt
		secondCell = codeAt > 0 && outAt > 0 && markAt > secondFrom && substr( cellText, secondFrom, markAt - secondFrom ) ~ /(^|[^0-9])2([^0-9]|$)/
		printf "%s %s", ( firstCell ? "yes" : "no" ), ( secondCell ? "yes" : "no" ) ;
	}
' )"
rigAssert "cell 1 is numbered before its source" "${rigCells% *}" "yes"
rigAssert "cell 2 is numbered after cell 1 and before its own source" "${rigCells#* }" "yes"

echo "-- a folder, an empty file, and the native argument and line default --"
rigText="$( rigResult 13 )"
rigAssert "a folder is refused, named as a directory, never as missing" \
	"$( rigIsError "$rigText" ) $( rigHas "$rigText" 'directory' ) $( rigHas "$rigText" 'no such file' )" "yes yes no"
rigText="$( rigResult 14 )"
rigAssert "an empty file is a notice, not an error" "$( rigIsError "$rigText" ) $( rigHas "$rigText" 'empty' )" "no yes"
rigAssert "file_path reads the file, as the native tool names it" "$( rigResult 15 )" $'     1\talpha\n     2\tbeta\n     3\tgamma'
rigAssert "with both given, file_path wins" "$( rigResult 16 )" $'     1\tbravo-file'
rigText="$( rigResult 17 )"
rigAssert "with neither given, the call is refused as missing its file" "$( rigIsError "$rigText" ) $( rigHas "$rigText" 'file_path is required' )" "yes yes"
rigAssert "a read with no range stops at 2000 lines" \
	"$( printf '%s\n' "$( rigResult 18 )" | LC_ALL=C awk '/^ *[0-9]+\t/ { numbered++ ; } END { print numbered + 0 ; }' )" "2000"
rigAssert "a read cut at 2000 lines names where to continue" "$( rigHas "$( rigResult 18 )" 'offset 2001' )" yes
rigReadAt=0
while [ -n "$( rigWire 19 | LC_ALL=C awk -v path="result.tools.$rigReadAt.name" -v optional=1 -f "$rigField" 2>/dev/null )" ] ; do
	[ "$( rigWire 19 | LC_ALL=C awk -v path="result.tools.$rigReadAt.name" -v optional=1 -f "$rigField" 2>/dev/null )" != Read ] || break
	rigReadAt=$(( rigReadAt + 1 ))
done
rigAssert "the listed Read declares file_path and requires no argument" \
	"$( rigWire 19 | LC_ALL=C awk -v path="result.tools.$rigReadAt.inputSchema.properties.file_path.type" -v optional=1 -f "$rigField" 2>/dev/null ) $( rigWire 19 | LC_ALL=C awk -v path="result.tools.$rigReadAt.inputSchema.required.__count" -v optional=1 -f "$rigField" 2>/dev/null )" "string 0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ READ NATIVE CHECK FAILED: $rigFails assertion(s)" >&2
	echo "  warn: Read as the MCP server serves it does not yet number, page, cap, or" >&2
	echo "        decode images, PDFs and notebooks the way it was decided" >&2
	echo "  fix:  AgentsHarnessToolRead and AgentsHarnessReadRange in" >&2
	echo "        sh-lib/AgentsUniversalHarness.sh, and the content parts in" >&2
	echo "        sh-lib/AgentsTools.InternMcpRequest.include -- never the assertion" >&2
	exit 1
fi
echo "HARNESS_READ_NATIVE: OK (served Read: numbering, ranges, cap, head part, raw Skill, image, PDF pages, notebook cells)"
