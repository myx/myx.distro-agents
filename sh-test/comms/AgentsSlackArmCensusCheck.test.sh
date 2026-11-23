#!/usr/bin/env bash
## Behavioural check on the arms of the member Slack router, AgentsTools.MemberCommsSlack.include: every arm whose
## word is an operation of the family (--intern-op-comms-slack-*) loads an include of the origin that is there, and
## that include answers the arm's own word as a case arm of its own. An arm whose load line is gone does nothing and
## returns the status of a command it no longer runs, and no other check reads that for every arm.
## Held, run and not read:
##   1. THE ROUTER. One line per arm at any case depth, for every arm that admits an operation word: the include it
##      loads, and whether that file answers every word the arm admits. An arm that loads nothing is a fault, and so
##      is a load of a file that is not there. A label of several words, or one ending in a star, is answered word by
##      word, the star standing for the words it prefixes. A word a file carries only in a comment is not an answer.
##   2. THE INSTRUMENT. The readers on routers made by hand: a bare load, a guarded load, a body of two loads, no
##      load, a label of two words one of which the include does not answer, and a file that is no router.
## Red recipe: on a copy of the router with all eleven load lines deleted, section 1 fails naming all eleven arms and
## section 2 passes; with the react include's case label renamed, section 1 fails naming that arm alone.
## Offline: it reads files, and writes only inside its own rig folder.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:=$MMDAPP/.local}"

rigPackageRel="myx/myx.distro-agents"
rigRouterName="AgentsTools.MemberCommsSlack.include"
rigArmPrefix="--intern-op-comms-slack-"
## The arms the router carried when this check was written: a control on the reader, never a list of what may exist.
rigKnownArms='--intern-op-comms-slack-presence-*
--intern-op-comms-slack-profile-*
--intern-op-comms-slack-socket-*
--intern-op-comms-slack-read
--intern-op-comms-slack-search-messages
--intern-op-comms-slack-react
--intern-op-comms-slack-delete-message
--intern-op-comms-slack-edit-message
--intern-op-comms-slack-file-fetch
--intern-op-comms-slack-file-share
--intern-op-comms-slack-send-message'

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
rigPackage="$MDLT_ORIGIN/$rigPackageRel"
rigRouter="$rigPackage/sh-lib/slack/$rigRouterName"
[ -f "$rigRouter" ] || rigRefuse "no $rigRouterName at the origin this workspace resolves: $rigPackage/sh-lib/slack"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSlackArmCensusCheck )" || exit 1
trap '[ -n "${RIG_KEEP:-}" ] && echo "kept: $rigTmp" || { chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp" ; }' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}

## THE READERS. One census line per arm, and whether an include answers a word.
rigCensus(){ ## router file -- one line per arm: <label> <load>...
	LC_ALL=C awk '
		function noteLoads(atDepth, text) {
			while ( match(text, /\$MDLT_ORIGIN[^"]*\.include/) ) {
				loadCountAt[atDepth]++
				loadAt[atDepth, loadCountAt[atDepth]] = substr(text, RSTART, RLENGTH)
				text = substr(text, RSTART + RLENGTH)
			}
		}
		function flushArm(atDepth,   i, out) {
			if ( atDepth < 1 || labelAt[atDepth] == "" ) { return }
			out = labelAt[atDepth]
			for ( i = 1 ; i <= loadCountAt[atDepth] ; i++ ) { out = out " " loadAt[atDepth, i] }
			printf "%s\n", out
			labelAt[atDepth] = ""
			loadCountAt[atDepth] = 0
		}
		{
			lineText = $0
			sub(/[ \t]+$/, "", lineText)
			if ( lineText ~ /^[ \t]*$/ ) { next }
			if ( lineText ~ /^[ \t]*#/ ) { next }
			if ( lineText ~ /^[ \t]*case[ \t]/ ) { flushArm(depth) ; depth++ ; next }
			if ( lineText ~ /^[ \t]*esac[ \t]*$/ ) { flushArm(depth) ; depth-- ; if ( depth < 0 ) { depth = 0 } ; next }
			if ( depth < 1 ) { next }
			if ( labelAt[depth] == "" && match(lineText, /^[ \t]*[^) \t][^)]*\)/) ) {
				labelAt[depth] = substr(lineText, 1, RLENGTH)
				sub(/^[ \t]*/, "", labelAt[depth])
				sub(/\)$/, "", labelAt[depth])
				loadCountAt[depth] = 0
				noteLoads(depth, substr(lineText, RLENGTH + 1))
				next
			}
			if ( labelAt[depth] != "" ) {
				## an arm ends at its `;;`, wherever on the line it stands
				closesHere = 0
				if ( lineText ~ /^[ \t]*;;[ \t]*$/ ) { closesHere = 1 ; lineText = "" }
				else if ( lineText ~ /;;[ \t]*$/ ) { closesHere = 1 ; sub(/;;[ \t]*$/, "", lineText) }
				if ( lineText != "" ) { noteLoads(depth, lineText) }
				if ( closesHere == 1 ) { flushArm(depth) }
			}
		}
		END { flushArm(depth) }
	' "$1"
}
rigAnswers(){ ## include file, word, exact|prefix -- rc 0 where the file holds a case arm that word names
	LC_ALL=C awk -v word="$2" -v mode="$3" '
		/^[[:space:]]*#/ { next }
		/^[[:space:]]*--/ {
			label = $0
			sub(/^[[:space:]]*/, "", label)
			sub(/\).*$/, "", label)
			labelParts = split(label, part, "|")
			for ( partAt = 1 ; partAt <= labelParts ; partAt++ ) {
				if ( mode == "exact" && part[partAt] == word ) { found = 1 ; exit }
				if ( mode == "prefix" && index(part[partAt], word) == 1 ) { found = 1 ; exit }
			}
		}
		END { exit found ? 0 : 1 }
	' "$1"
}
rigUnanswered(){ ## include file, arm label -- each word the label admits that the file does not answer, one a line
	local unansweredFile="$1" unansweredWord unansweredMode unansweredWords
	unansweredWords="$( printf '%s\n' "$2" | LC_ALL=C tr '|' '\n' )"
	while IFS= read -r unansweredWord ; do
		[ -n "$unansweredWord" ] || continue
		unansweredMode=exact
		case "$unansweredWord" in
			*\*) unansweredMode=prefix ; unansweredWord="${unansweredWord%\*}" ;;
		esac
		rigAnswers "$unansweredFile" "$unansweredWord" "$unansweredMode" || printf '%s\n' "$unansweredWord"
	done <<< "$unansweredWords"
}
rigAdmitsArm(){ ## arm label -- rc 0 where some word it admits begins with the family prefix
	local admitsWord admitsWords
	admitsWords="$( printf '%s\n' "$1" | LC_ALL=C tr '|' '\n' )"
	while IFS= read -r admitsWord ; do
		case "$admitsWord" in "$rigArmPrefix"*) return 0 ;; esac
	done <<< "$admitsWords"
	return 1
}
rigCensusFaults(){ ## router file -- one fault line per arm that fails the census
	local faultsLine faultsLabel faultsLoads faultsLoad faultsWhere faultsMissing
	while IFS= read -r faultsLine ; do
		faultsLabel="${faultsLine%% *}"
		faultsLoads=""
		case "$faultsLine" in *" "*) faultsLoads="${faultsLine#* }" ;; esac
		rigAdmitsArm "$faultsLabel" || continue
		if [ -z "$faultsLoads" ] ; then
			printf '%s: no include loaded\n' "$faultsLabel"
			continue
		fi
		for faultsLoad in $faultsLoads ; do
			faultsWhere="$rigPackage/${faultsLoad#\$MDLT_ORIGIN/$rigPackageRel/}"
			if [ ! -f "$faultsWhere" ] ; then
				printf '%s: %s is not there\n' "$faultsLabel" "${faultsLoad##*/}"
				continue
			fi
			faultsMissing="$( rigUnanswered "$faultsWhere" "$faultsLabel" | LC_ALL=C tr '\n' ' ' )"
			faultsMissing="${faultsMissing% }"
			[ -z "$faultsMissing" ] || printf '%s: %s answers none of %s\n' "$faultsLabel" "${faultsLoad##*/}" "$faultsMissing"
		done
	done <<< "$( rigCensus "$1" )"
}
rigCensusLabels(){ ## router file -- the label of every arm that admits an operation word, one a line
	local labelsLine
	while IFS= read -r labelsLine ; do
		rigAdmitsArm "${labelsLine%% *}" && printf '%s\n' "${labelsLine%% *}"
	done <<< "$( rigCensus "$1" )"
}
rigGrepLabels(){ ## router file -- the same words, found by a plain word scan with the comments left out
	LC_ALL=C grep -v '^[[:space:]]*#' "$1" | LC_ALL=C grep -o -- "$rigArmPrefix[a-z*-]*" | LC_ALL=C sort -u
}

echo "-- 2. the instrument: the readers on routers made by hand --"
printf 'case "$1" in\n\t--intern-op-comms-slack-rig-bare)\n\t\t. "$MDLT_ORIGIN/x/rig.include"\n\t\treturn $?\n\t;;\nesac\n' > "$rigTmp/rig-bare.include"
printf 'case "$1" in\n\t--intern-op-comms-slack-rig-guarded)\n\t\ttype rigArmCensusProbe > /dev/null 2>&1 || . "$MDLT_ORIGIN/x/rig.include"\n\t\treturn $?\n\t;;\nesac\n' > "$rigTmp/rig-guarded.include"
printf 'case "$1" in\n\t--intern-op-comms-slack-rig-two)\n\t\t. "$MDLT_ORIGIN/x/rig-one.include"\n\t\t. "$MDLT_ORIGIN/x/rig-two.include"\n\t\treturn $?\n\t;;\nesac\n' > "$rigTmp/rig-two.include"
printf 'case "$1" in\n\t--intern-op-comms-slack-rig-nothing)\n\t\treturn $?\n\t;;\nesac\n' > "$rigTmp/rig-nothing.include"
printf 'case "$1" in\n\t--intern-op-rig-other)\n\t\t. "$MDLT_ORIGIN/x/rig.include"\n\t;;\nesac\n' > "$rigTmp/rig-no-arm.include"
printf 'rigArmCensusProbe(){ : ; }\ntype rigArmCensusProbe > /dev/null 2>&1 || . "$MDLT_ORIGIN/x/rig.include"\n' > "$rigTmp/rig-no-router.include"
printf 'case "$1" in\n\t--intern-op-comms-slack-answers)\n\t\t: ;;\nesac\n' > "$rigTmp/rig-answers.include"
printf 'case "$1" in\n\t--intern-op-comms-slack-other)\n\t\t: ;;\nesac\n' > "$rigTmp/rig-silent.include"
printf '# a comment naming --intern-op-comms-slack-answers is no answer\n' > "$rigTmp/rig-comment.include"
printf 'case "$1" in\n\t--intern-op-comms-slack-one|--intern-op-comms-slack-two)\n\t\t: ;;\nesac\n' > "$rigTmp/rig-two-words.include"
printf 'case "$1" in\n\t--intern-op-comms-slack-one)\n\t\t: ;;\nesac\n' > "$rigTmp/rig-one-word.include"

rigAssert "the reader names a bare load arm, and the include it loads" \
	"$( rigCensus "$rigTmp/rig-bare.include" )" '--intern-op-comms-slack-rig-bare $MDLT_ORIGIN/x/rig.include'
rigAssert "the reader names a guarded load arm, which the census reads as its own body" \
	"$( rigCensus "$rigTmp/rig-guarded.include" )" '--intern-op-comms-slack-rig-guarded $MDLT_ORIGIN/x/rig.include'
rigAssert "the reader names both loads of an arm of two loads, in the order they run" \
	"$( rigCensus "$rigTmp/rig-two.include" )" '--intern-op-comms-slack-rig-two $MDLT_ORIGIN/x/rig-one.include $MDLT_ORIGIN/x/rig-two.include'
rigAssert "the reader answers for a file holding the arm's word" \
	"$( rigAnswers "$rigTmp/rig-answers.include" --intern-op-comms-slack-answers exact && printf answers || printf silent )" answers
rigAssert "the reader says silent for a file holding another word" \
	"$( rigAnswers "$rigTmp/rig-silent.include" --intern-op-comms-slack-answers exact && printf answers || printf silent )" silent
rigAssert "the reader says silent for a word a file carries only in a comment" \
	"$( rigAnswers "$rigTmp/rig-comment.include" --intern-op-comms-slack-answers exact && printf answers || printf silent )" silent
printf 'case "$1" in\n\t--intern-op-comms-slack-answers-more)\n\t\t: ;;\nesac\n' > "$rigTmp/rig-longer.include"
rigAssert "the reader says silent for a longer word when the arm names its word whole" \
	"$( rigAnswers "$rigTmp/rig-longer.include" --intern-op-comms-slack-answers exact && printf answers || printf silent )" silent
rigAssert "the reader answers a family word, which a star leaves open, for a file holding a longer arm of it" \
	"$( rigAnswers "$rigTmp/rig-longer.include" --intern-op-comms-slack-answers prefix && printf answers || printf silent )" answers
rigAssert "the reader answers a label of two words where the file holds both" \
	"$( rigUnanswered "$rigTmp/rig-two-words.include" '--intern-op-comms-slack-one|--intern-op-comms-slack-two' )" ""
rigAssert "the reader names the one word of a two-word label the file does not hold" \
	"$( rigUnanswered "$rigTmp/rig-one-word.include" '--intern-op-comms-slack-one|--intern-op-comms-slack-two' )" '--intern-op-comms-slack-two'
rigAssert "the census names an operation arm whose body loads nothing" \
	"$( rigCensusFaults "$rigTmp/rig-nothing.include" )" '--intern-op-comms-slack-rig-nothing: no include loaded'
printf 'case "$1" in\n\t--intern-op-comms-slack-rig-absent)\n\t\t. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/slack/AgentsTools.RigAbsent.include"\n\t\treturn $?\n\t;;\nesac\n' > "$rigTmp/rig-absent.include"
rigAssert "the census names an operation arm whose include is not there" \
	"$( rigCensusFaults "$rigTmp/rig-absent.include" )" '--intern-op-comms-slack-rig-absent: AgentsTools.RigAbsent.include is not there'
rigAssert "the census passes an arm of another family, which no include of this one serves" \
	"$( rigCensusFaults "$rigTmp/rig-no-arm.include" )" ""
rigAssert "the census reads a file that is no router as no arm at all" \
	"$( rigCensusFaults "$rigTmp/rig-no-router.include" )" ""

echo "-- 1. $rigRouterName: every operation arm loads an include that answers it --"
rigAssert "$rigRouterName: the census reads one arm line for each of the eleven the router carried" \
	"$( rigCensusLabels "$rigRouter" | LC_ALL=C grep -c . )" "11"
rigAssert "$rigRouterName: a plain word scan over the same router finds the same count, so the census missed no arm" \
	"$( rigGrepLabels "$rigRouter" | LC_ALL=C grep -c . )" "$( rigCensusLabels "$rigRouter" | LC_ALL=C grep -c . )"
rigAssert "$rigRouterName: no operation arm is left without an include that exists and answers its own word" \
	"$( rigCensusFaults "$rigRouter" )" ""
rigAssert "the reader reached the arms the router carried when this check was written (control on the census itself)" \
	"$( for rigArm in $rigKnownArms ; do rigCensusLabels "$rigRouter" | LC_ALL=C grep -Fx -- "$rigArm" > /dev/null || printf '%s ' "$rigArm" ; done )" ""

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SLACK ARM CENSUS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SLACK_ARM_CENSUS: OK (%d assertions, offline)\n' "$rigPassCount"
