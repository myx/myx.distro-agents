#!/usr/bin/env awk
# ^^^ for syntax checking in the editor only

##
## AgentsDocTypeCheck.awk -- the rule sets of the team-data type kinds (`board-item.task`, `inbox-item.note`,
## `audit-item.transcript`, ...) of the one validator (F5.3): ONE reader of a type contract, and a document read against it.
## The contract is the rule set. This file reads the contract's own Keys table (which key is required, which value
## form each key has), its unmarked Rules (the marked [store] and [judged] ones need more than a file, or a reader), and
## reads the document with them. No rule is written in this file for a kind.
##
## Run by AgentsToolsDocValidateType (AgentsTools.InternDocValidate.include):
##   DOC_NAME=<the document's file name, empty for stdin> LC_ALL=C awk -f AgentsDocTypeCheck.awk <contract> <document>
## Prints tab-separated records, `ROW <line> <rule> <text>`, in the order of the contract. A rule here has a BASE name
## (contract-key, contract-form, ...); whether its row refuses or reports is the include's table, per rule and site.
##
## The rules:
##   contract-frontmatter    the document has no frontmatter block
##   contract-key            a key the contract requires is absent or empty
##   contract-form           a key's value is not in its value form
##   contract-duplicate-key  a key that stands twice in the frontmatter (the row names the key and both lines)
##   contract-unknown-key    a key the contract does not name
##   contract-type           `type` is not the type word of the file name
##   contract-pair           two keys that appear together do not
##   contract-references     a `references` that names a board item where the contract forbids it
##   contract-body           the body table has the wrong number of columns, or a row's column holds a wrong value
##   contract-filename       the file name does not carry what the frontmatter gives
##   contract-rule-unread    the contract has an unmarked rule this reader does not know
##

function trimText(textIn,   textOut) {
	textOut = textIn ; sub(/^[ \t]+/, "", textOut) ; sub(/[ \t]+$/, "", textOut) ;
	return textOut ;
}

## A row is its line, its rule, its text and, apart, the value it is about: a fault is its rule and its text, so the
## same fault stays the same fault when its value changes (the write gate holds a fault by those two).
function emitRow(lineNo, ruleName, rowText, detailText) {
	printf "ROW\t%d\t%s\t%s\t%s\n", lineNo, ruleName, rowText, detailText ;
}

## The number a word or digits name, 0 where neither.
function countOf(wordIn,   wordLow) {
	wordLow = tolower(wordIn) ;
	if (wordLow ~ /^[0-9]+$/) return wordLow + 0 ;
	if (wordLow == "two") return 2 ; if (wordLow == "three") return 3 ; if (wordLow == "four") return 4 ;
	if (wordLow == "five") return 5 ; if (wordLow == "six") return 6 ; if (wordLow == "seven") return 7 ;
	if (wordLow == "eight") return 8 ; if (wordLow == "nine") return 9 ; if (wordLow == "ten") return 10 ;
	return 0 ;
}

## Whether a comma-separated list holds only things of one shape (a regular expression): "" where it does, else the first misfit.
function listMisfit(valueIn, shapeIn,   parts, partN, idx, one) {
	partN = split(valueIn, parts, ",") ;
	for (idx = 1 ; idx <= partN ; idx++) {
		one = trimText(parts[idx]) ;
		if (one == "" || one !~ shapeIn) return (one == "" ? "<empty>" : one) ;
	}
	return "" ;
}

## Why a value is not in its value form: "" where it is. The value itself is left in faultDetail.
function formFault(formWord, formArg, valueIn,   misfit, enumParts, enumN, idx, hit, entries, entryN, entryIdx) {
	faultDetail = valueIn ;
	if (formWord == "literal") return (valueIn == formArg ? "" : "is not the literal " formArg) ;
	if (formWord == "date-time") return (valueIn ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9] [+-][0-9][0-9][0-9][0-9]$/ ? "" : "is not a date-time (YYYY-MM-DD HH:MM +ZZZZ)") ;
	if (formWord == "member") return (valueIn ~ /^[A-Za-z][A-Za-z0-9._-]*$/ ? "" : "is not one member name") ;
	if (formWord == "owner-name") return "" ;
	if (formWord == "text") return "" ;
	if (formWord == "item-names") {
		misfit = listMisfit(valueIn, "^[A-Za-z0-9][A-Za-z0-9._-]*$") ;
		if (misfit == "" && valueIn ~ /[.]md(,|$)/) misfit = "a name with .md" ;
		faultDetail = misfit ;
		return (misfit == "" ? "" : "is not bare item names, comma-separated, no folder, no .md, no brackets") ;
	}
	if (formWord == "flag") return (valueIn == "true" ? "" : "is not the word true") ;
	if (formWord == "channel-id") return (valueIn ~ /^(slack:[^: ]+(:[^: ]+)?|email:.+|telegram:.+)$/ ? "" : "is not slack:<channel>, slack:<channel>:<ts>, email:<..> or telegram:<..>") ;
	if (formWord == "session-id") return (valueIn ~ /^[A-Za-z0-9][A-Za-z0-9._-]*$/ ? "" : "is not one session id") ;
	if (formWord == "members") {
		misfit = listMisfit(valueIn, "^[A-Za-z][A-Za-z0-9._-]*$") ;
		faultDetail = misfit ;
		return (misfit == "" ? "" : "is not comma-separated member names") ;
	}
	if (formWord == "reviewer") return (valueIn ~ /^[A-Za-z0-9][A-Za-z0-9._:-]*$/ ? "" : "is not a reviewer (a member, a session, <session-id>:<member>, a routine, none)") ;
	if (formWord == "approval-ref") return (valueIn ~ /^[A-Za-z][A-Za-z0-9_-]* \([^,()]+, [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9](\.[0-9]+)?Z\)$/ ? "" : "is not <member> (<session-id>, <iso-utc>)") ;
	if (formWord == "allows-set") {
		entryN = split(valueIn, entries, ",") ;
		for (entryIdx = 1 ; entryIdx <= entryN ; entryIdx++) {
			if (trimText(entries[entryIdx]) !~ /^(session|task):[^:]*:[^:]*:[^:]*:[0-9]+T[0-9]+Z$/) { faultDetail = trimText(entries[entryIdx]) ; return "has an entry that is not session|task:<tool>:<target>:<granted-by>:<stamp>" ; }
		}
		return "" ;
	}
	if (formWord == "workspace-name") return (valueIn ~ /^[A-Za-z0-9._-]+$/ ? "" : "is not a workspace's basename") ;
	if (formWord == "word") return (valueIn ~ /^[^ ]+$/ ? "" : "is not one word") ;
	if (formWord == "utc-stamp") return (valueIn ~ /^[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z$/ ? "" : "is not YYYYMMDDTHHmmssZ") ;
	if (formWord == "url") return (valueIn ~ /^(-|[A-Za-z][A-Za-z0-9+.-]*:\/\/[^ ]+)$/ ? "" : "is not one URL, or -") ;
	if (formWord == "tokens") return (valueIn ~ /^in=[0-9]+ cache-read=[0-9]+ cache-write=[0-9]+ out=[0-9]+$/ ? "" : "is not in=<N> cache-read=<N> cache-write=<N> out=<N>") ;
	if (formWord == "epoch-seconds") return (valueIn ~ /^[0-9]+$/ ? "" : "is not whole seconds since the epoch") ;
	if (formWord == "enum") {
		enumN = split(formArg, enumParts, /[ ,|]+/) ; hit = 0 ;
		for (idx = 1 ; idx <= enumN ; idx++) { if (enumParts[idx] != "" && enumParts[idx] == valueIn) hit = 1 ; }
		return (hit ? "" : "is not one of " formArg) ;
	}
	if (formWord == "audit-path") return "" ;
	return "has a value form this reader does not know: " formWord ;
}

## The key a back-quoted token of a rule names.
function ruleKey(ruleText,   keyText) {
	keyText = ruleText ; sub(/^[^`]*`/, "", keyText) ; sub(/`.*$/, "", keyText) ;
	return keyText ;
}

FNR == 1 { fileNo++ ; inKeys = 0 ; inRules = 0 ; inFront = 0 ; frontDone = 0 ; }

## ---- the contract ----
fileNo == 1 {
	if ($0 ~ /^## /) { inKeys = ($0 ~ /^## Keys/) ; inRules = ($0 ~ /^## Rules/) ; next ; }
	if ($0 ~ /^# /) { inKeys = 0 ; inRules = 0 ; next ; }
	if (inKeys && $0 ~ /^\| `/) {
		cellN = split($0, cells, "|") ;
		keyName = trimText(cells[2]) ; gsub(/`/, "", keyName) ;
		keyN++ ; keyOrder[keyN] = keyName ;
		keyPresence[keyName] = trimText(cells[3]) ;
		formCell = trimText(cells[5]) ; gsub(/`/, "", formCell) ;
		keyFormWord[keyName] = formCell ; sub(/ .*$/, "", keyFormWord[keyName]) ;
		keyFormArg[keyName] = (index(formCell, " ") > 0 ? substr(formCell, index(formCell, " ") + 1) : "") ;
		next ;
	}
	if (inRules && $0 ~ /^- / && $0 !~ /^- \[(store|judged)\]/) { ruleN++ ; ruleText[ruleN] = substr($0, 3) ; }
	next ;
}

## ---- the document ----
fileNo == 2 {
	lastLine = FNR ;
	if (FNR == 1) { if ($0 == "---") inFront = 1 ; else noFront = 1 ; next ; }
	if (noFront) { bodyN++ ; bodyText[bodyN] = $0 ; bodyLine[bodyN] = FNR ; next ; }
	if (inFront) {
		if ($0 == "---") { inFront = 0 ; frontDone = 1 ; next ; }
		if (match($0, /^[A-Za-z0-9_<>-]+:( |$)/)) {
			docName = substr($0, 1, RLENGTH) ; sub(/:.*$/, "", docName) ;
			docValue = substr($0, RLENGTH + 1) ; docValue = trimText(docValue) ;
			if (!(docName in docHas)) { docKeyN++ ; docKeyOrder[docKeyN] = docName ; }
			else emitRow(FNR, "contract-duplicate-key", "the key " docName " stands twice in the frontmatter", "lines " docLine[docName] " and " FNR) ;
			docHas[docName] = 1 ; docVal[docName] = docValue ; docLine[docName] = FNR ;
		}
		next ;
	}
	bodyN++ ; bodyText[bodyN] = $0 ; bodyLine[bodyN] = FNR ;
}

END {
	if (noFront || (!frontDone && inFront)) {
		emitRow(1, "contract-frontmatter", "the document has no complete frontmatter block", "") ;
		exit 0 ;
	}
	docFile = ENVIRON["DOC_NAME"] ;
	## Required keys.
	for (idx = 1 ; idx <= keyN ; idx++) {
		keyName = keyOrder[idx] ;
		if (keyPresence[keyName] == "required" && !(keyName in docHas && docVal[keyName] != "")) {
			emitRow(1, "contract-key", "the key " keyName " is required and " (keyName in docHas ? "empty" : "absent"), "") ;
		}
	}
	## Each key the document has: named by the contract, and in its value form.
	for (idx = 1 ; idx <= docKeyN ; idx++) {
		docName = docKeyOrder[idx] ;
		if (!(docName in keyFormWord)) { emitRow(docLine[docName], "contract-unknown-key", "the key " docName " is not named by the contract", "") ; continue ; }
		if (docVal[docName] == "") continue ;
		why = formFault(keyFormWord[docName], keyFormArg[docName], docVal[docName]) ;
		if (why != "") emitRow(docLine[docName], "contract-form", "the key " docName " " why, faultDetail) ;
	}
	## The contract's unmarked rules.
	for (idx = 1 ; idx <= ruleN ; idx++) {
		oneRule = ruleText[idx] ; handled = 0 ;
		if (oneRule ~ /^`[a-z-]+` equals the type word in the filename/) {
			handled = 1 ; keyName = ruleKey(oneRule) ;
			typeOfName = docFile ; sub(/-.*$/, "", typeOfName) ;
			if (docFile != "" && (keyName in docHas) && docVal[keyName] != "" && docVal[keyName] != typeOfName) {
				emitRow(docLine[keyName], "contract-type", "the key " keyName " is not the type word of the file name " docFile, docVal[keyName] " (the file name says " typeOfName ")") ;
			}
		}
		else if (oneRule ~ /^`[a-z-]+` and `[a-z-]+` appear together/) {
			handled = 1 ; firstKey = ruleKey(oneRule) ;
			secondKey = oneRule ; sub(/^`[a-z-]+` and `/, "", secondKey) ; sub(/`.*$/, "", secondKey) ;
			if ((firstKey in docHas) != (secondKey in docHas)) {
				emitRow((firstKey in docHas ? docLine[firstKey] : docLine[secondKey]), "contract-pair", "the keys " firstKey " and " secondKey " appear together, and " (firstKey in docHas ? secondKey : firstKey) " is absent", "") ;
			}
		}
		else if (oneRule ~ /^`[a-z-]+` never names a board item/) {
			handled = 1 ; keyName = ruleKey(oneRule) ;
			if (keyName in docHas) {
				partN = split(docVal[keyName], parts, ",") ;
				for (partIdx = 1 ; partIdx <= partN ; partIdx++) {
					if (trimText(parts[partIdx]) ~ /^(project|task|change|idea|proposal|interview|approval|dispatch|warning)-/) {
						emitRow(docLine[keyName], "contract-references", "the key " keyName " names a board item", trimText(parts[partIdx])) ;
					}
				}
			}
		}
		else if (oneRule ~ /^The body header row has [A-Za-z0-9]+ tab-separated columns/) {
			handled = 1 ;
			wantCols = oneRule ; sub(/^The body header row has /, "", wantCols) ; sub(/ .*$/, "", wantCols) ; wantCols = countOf(wantCols) ;
			headerAt = 0 ;
			for (bodyIdx = 1 ; bodyIdx <= bodyN ; bodyIdx++) {
				if (index(bodyText[bodyIdx], "\t") > 0) { headerAt = bodyIdx ; break ; }
			}
			if (headerAt == 0) emitRow(lastLine, "contract-body", "the body has no header row of " wantCols " tab-separated columns", "") ;
			else {
				for (bodyIdx = headerAt ; bodyIdx <= bodyN ; bodyIdx++) {
					if (trimText(bodyText[bodyIdx]) == "") continue ;
					if (split(bodyText[bodyIdx], cols, "\t") != wantCols) emitRow(bodyLine[bodyIdx], "contract-body", "the " (bodyIdx == headerAt ? "header row" : "row") " has " split(bodyText[bodyIdx], cols, "\t") " tab-separated columns, and the contract says " wantCols, "") ;
				}
			}
		}
		else if (oneRule ~ /^A row's `kind` is `declaration` and its `group` is never `message`/) {
			handled = 1 ;
			for (bodyIdx = 1 ; bodyIdx <= bodyN ; bodyIdx++) {
				if (index(bodyText[bodyIdx], "\t") == 0) continue ;
				split(bodyText[bodyIdx], cols, "\t") ;
				if (cols[1] == "date-time") continue ;
				if (cols[2] != "declaration") emitRow(bodyLine[bodyIdx], "contract-body", "a row's kind is not declaration", cols[2]) ;
				if (cols[4] == "message") emitRow(bodyLine[bodyIdx], "contract-body", "a row's group is message, and a declaration is never of the group message", "") ;
			}
		}
		else if (oneRule ~ /^A row's `kind` is `refusal` where/) {
			handled = 1 ;
			for (bodyIdx = 1 ; bodyIdx <= bodyN ; bodyIdx++) {
				if (index(bodyText[bodyIdx], "\t") == 0) continue ;
				split(bodyText[bodyIdx], cols, "\t") ;
				if (cols[1] == "date-time") continue ;
				if (cols[2] != "refusal" && cols[2] != "report") emitRow(bodyLine[bodyIdx], "contract-body", "a row's kind is neither refusal nor report", cols[2]) ;
			}
		}
		else if (oneRule ~ /^The filename carries /) {
			handled = 1 ;
			if (docFile != "" && ("captured-at" in docHas) && ("system" in docHas) && ("resource-type" in docHas) && ("resource-id" in docHas)) {
				wantName = "snapshot-" docVal["captured-at"] "-" docVal["system"] "-" docVal["resource-type"] "-" docVal["resource-id"] ".md" ;
				if (docFile != wantName) emitRow(1, "contract-filename", "the file name does not carry what the frontmatter gives", docFile " (the frontmatter gives " wantName ")") ;
			}
		}
		if (!handled) emitRow(1, "contract-rule-unread", "the contract has a rule this reader does not know", oneRule) ;
	}
}
