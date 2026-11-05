#!/usr/bin/env awk
# ^^^ for syntax checking in the editor only

##
## AgentsEpicCheck.awk -- the rule set of the `epic` kind of the one validator (`--intern-doc-validate epic <file>`,
## AgentsTools.InternDocValidate.include): an epic read against its contract, skillset contracts/epic.contract.format.md.
## One pass over the text, no store. Its Sections table, its Feature table, its Done section and its unmarked Rules are the rules
## here. A rule marked [judged] is for a reader. The [store] rule (a moved item exists in the epic it names) is asked of the
## caller, by the MOVED records. Run as: LC_ALL=C awk -f AgentsEpicCheck.awk <file>
## Prints tab-separated records: `ROW <line> <rule> <text>` for a fault, `MOVED <line> <epic file> <feature id>` for each moved item.
##
## The rules:
##   epic-title        the line the epic opens with is not `# <title>`, or a second level-1 heading stands
##   epic-preface      the `Source:` or the `Builders:` line is absent before the first section
##   epic-section      a `## ` heading that is no section of the contract, or a section out of its order
##   epic-decisions    `## Decisions` is absent
##   epic-feature      a feature heading that is not `## S<number> - <title>`, or an id that stands twice
##   epic-owner        a feature with no owner line that has an open item naming no owner
##   epic-empty        a feature that holds no open item and no moved item
##   epic-done         `## Done` is absent, is not the last section, or holds a line that is not `- <id>: <what holds now>`,
##                     or an id that stands twice there or still stands as an open item
##
## A line inside a code fence is no heading and no item. Every closing `}` is preceded by a `;` (some awk builds reject the other form).
##

function sectionRank(headingIn) {
	if (headingIn == "## Decisions") return 1 ;
	if (headingIn == "## Ground rules") return 2 ;
	if (headingIn == "## Standing rulings") return 3 ;
	if (headingIn ~ /^## S[0-9]+ - Close-out: ./) return 5 ;
	if (headingIn ~ /^## S[0-9]+ - ./) return 4 ;
	if (headingIn == "## Plans from investigations") return 6 ;
	if (headingIn == "## Done") return 7 ;
	return 0 ;
}

function row(lineNo, ruleName, rowText) {
	printf "ROW\t%d\t%s\t%s\n", lineNo, ruleName, rowText ;
}

## The `Moved to <file>, section <id>` a line holds, if any, closed by `:` or `.`: counted for the feature, and handed to the caller to find.
function noteMoved(lineNo, textIn,   movedSeg, movedAt) {
	if (!match(textIn, /Moved to [^ ,]+, section S[0-9]+[:.]/)) return 0 ;
	movedSeg = substr(textIn, RSTART + 9, RLENGTH - 10) ;
	movedAt = index(movedSeg, ", section ") ;
	printf "MOVED\t%d\t%s\t%s\n", lineNo, substr(movedSeg, 1, movedAt - 1), substr(movedSeg, movedAt + 10) ;
	return 1 ;
}

## The open item that just ended: its owner stands anywhere in its own block.
function closeItem() {
	if (inItem && !itemOwned) itemsWithoutOwner++ ;
	inItem = 0 ;
}

## The feature that just ended: owned, and holding open work or a moved item.
function closeFeature() {
	closeItem() ;
	if (featureId == "") return ;
	if (!featureOwnerLine && itemsWithoutOwner > 0) row(featureLine, "epic-owner", featureId " has no owner line, and " itemsWithoutOwner " open item(s) name no owner") ;
	if (itemCount == 0 && movedCount == 0) row(featureLine, "epic-empty", featureId " holds no open item and no moved item: a closed item goes to ## Done") ;
	featureId = "" ;
}

BEGIN { fenced = 0 ; h1Count = 0 ; lastRank = 0 ; firstSection = 0 ; lastH2 = 0 ; doneAt = 0 ; inDone = 0 ; inItem = 0 ; featureId = "" ; sourceSeen = 0 ; buildersSeen = 0 ; decisionsSeen = 0 ; frontOpen = 0 ; titleDone = 0 ; }

## A vault epic opens with a frontmatter block, which is no part of the epic: its lines are skipped, and the title is the first
## line after it. A plain epic file has no such block and opens with its title.
FNR == 1 && $0 == "---" { frontOpen = 1 ; next }
frontOpen { if ($0 == "---") frontOpen = 0 ; next }
titleDone == 0 { titleDone = 1 ; if ($0 !~ /^# ./) row(FNR, "epic-title", "the first line is not `# <title>`") ; }

$0 ~ /^```/ { fenced = !fenced ; next ; }
fenced { next ; }

$0 ~ /^# ./ {
	h1Count++ ;
	if (h1Count == 2) row(FNR, "epic-title", "a second level-1 heading: the title is the only one") ;
	next ;
}

$0 ~ /^## / {
	closeFeature() ;
	if (firstSection == 0) firstSection = FNR ;
	lastH2 = FNR ;
	headingRank = sectionRank($0) ;
	if (doneAt > 0) row(FNR, "epic-done", "a section follows ## Done: it is the last") ;
	else if (headingRank == 0) {
		if ($0 ~ /^## S[0-9]+/) row(FNR, "epic-feature", "the feature heading is not `## S<number> - <title>`: " $0) ;
		else row(FNR, "epic-section", "the heading is no section of the contract: " $0) ;
	}
	else if (headingRank < lastRank) row(FNR, "epic-section", "the section is out of its order: " $0) ;
	else lastRank = headingRank ;
	if (headingRank == 1) decisionsSeen = 1 ;
	inDone = 0 ;
	if (headingRank == 7) { doneAt = FNR ; inDone = 1 ; }
	if (headingRank == 4 || headingRank == 5) {
		featureId = $0 ; sub(/^## /, "", featureId) ; sub(/ .*$/, "", featureId) ;
		featureLine = FNR ; featureOwnerLine = 0 ; itemCount = 0 ; movedCount = 0 ; itemsWithoutOwner = 0 ;
		if (featureId in featureSeen) row(FNR, "epic-feature", "the id " featureId " stands twice, first at line " featureSeen[featureId]) ;
		else featureSeen[featureId] = FNR ;
	}
	next ;
}

firstSection == 0 {
	if ($0 ~ /^Source:/) sourceSeen = 1 ;
	if ($0 ~ /^Builders:/) buildersSeen = 1 ;
	next ;
}

inDone {
	if ($0 !~ /^[ \t]*$/ && $0 !~ /^- S[0-9]+(\.[0-9]+)?: ./) row(FNR, "epic-done", "the line is not `- <id>: <what holds now>`") ;
	else if ($0 ~ /^- S[0-9]+(\.[0-9]+)?: /) {
		doneId = $0 ;
		sub(/^- /, "", doneId) ;
		sub(/:.*$/, "", doneId) ;
		if (doneId in doneSeen) row(FNR, "epic-done", "the id " doneId " stands twice here, first at line " doneSeen[doneId]) ;
		else doneSeen[doneId] = FNR ;
		doneIds[doneId] = FNR ;
	}
	next ;
}

featureId != "" {
	if ($0 ~ /^[0-9]+\. /) {
		closeItem() ;
		if (noteMoved(FNR, $0)) { movedCount++ ; }
		else { itemCount++ ; inItem = 1 ; itemOwned = ($0 ~ /[Oo]wner:|owned by/) ; itemNo = $0 ; sub(/\..*$/, "", itemNo) ; openItem[featureId "." itemNo] = FNR ; }
		next ;
	}
	if ($0 ~ /^[^ \t]/) {
		closeItem() ;
		if ($0 ~ /Owner:|owned by/) featureOwnerLine = 1 ;
		if (noteMoved(FNR, $0)) movedCount++ ;
		next ;
	}
	if (inItem && $0 ~ /[Oo]wner:|owned by/) itemOwned = 1 ;
	if (noteMoved(FNR, $0)) movedCount++ ;
	next ;
}

END {
	closeFeature() ;
	## A `## Done` id stands once, and no open item carries it.
	for (doneId in doneIds) {
		if (doneId in openItem) row(doneIds[doneId], "epic-done", "the id " doneId " still stands as an open item at line " openItem[doneId]) ;
	}
	if (!sourceSeen) row(firstSection > 0 ? firstSection : 1, "epic-preface", "the `Source:` line is absent before the first section") ;
	if (!buildersSeen) row(firstSection > 0 ? firstSection : 1, "epic-preface", "the `Builders:` line is absent before the first section") ;
	if (!decisionsSeen) row(firstSection > 0 ? firstSection : 1, "epic-decisions", "the section ## Decisions is absent") ;
	if (doneAt == 0) row(lastH2 > 0 ? lastH2 : 1, "epic-done", "the section ## Done is absent: it is the last section") ;
}
