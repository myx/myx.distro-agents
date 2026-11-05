#!/usr/bin/env bash
## Behavioural check on the plain-language floor of the spawn brief's mechanical block (owner 2026-10-31): the template
## `sh-lib/templates/spawn-brief.document.format.md` is what every spawn receives, so the floor binds it as it binds a
## brief. Held, over the block as the filler emits it with its tags stripped: every sentence is at most 25 words, no line
## holds more than six sentences, a line that is not a list item never carries a run of instructions, and every list item
## is one sentence of at most 20 words. Offline; the template is read, never run.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigTemplate="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/templates/spawn-brief.document.format.md"
[ -f "$rigTemplate" ] || { echo "⛔ ERROR: the brief template is not in the package: $rigTemplate -- refusing to report a result" >&2 ; exit 1 ; }
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigTmp="$( mktemp -d "${TMPDIR:-/tmp}/AgentsSpawnBriefFloorCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
## The block as the filler emits it: from SPAWN-PREPARE-BRIEF to its closing line, its tags stripped.
LC_ALL=C awk '
	/^SPAWN-PREPARE-BRIEF: / { inBlock = 1 ; print ; next }
	!inBlock { next }
	$0 == "When done, hand back and Wait until dismissed." { print ; exit }
	{ sub( /^\[(own|native|lock|scan)\] /, "" ) ; print }
' "$rigTemplate" > "$rigTmp/block"
## Each measure prints `within` when it holds, else the offending size and words.
rigSentences(){ ## line -- its sentences, one a line
	printf '%s\n' "$1" | LC_ALL=C awk '{ gsub( /\{\{[a-z-]+\}\}/, "slot" ) ; gsub( /\[(own|native|lock|scan)\]/, "" ) ; n = split( $0, s, /[.!?]( |$)/ ) ; for ( i = 1 ; i <= n ; i++ ) { if ( s[i] != "" ) print s[i] } }'
}
rigWithin(){ ## limit, sentence... -- within, or over with its size
	local bound="$1" ; shift
	local sentence words
	for sentence in "$@" ; do
		words="$( printf '%s' "$sentence" | LC_ALL=C awk '{ print NF + 0 }' )"
		[ "$words" -le "$bound" ] || { printf 'over: %s words: %s\n' "$words" "$sentence" ; return 0 ; }
	done
	printf 'within\n'
}
rigLongestSentence(){ ## file -- the longest sentence's verdict against the 25-word cap
	local lines=() line sentence
	while IFS= read -r line ; do
		[ -z "$line" ] || lines+=( "$line" )
	done < "$1"
	rigWithin 25 "${lines[@]}"
}
rigPerLine(){ ## file, limit -- the worst line's sentence count against the limit
	LC_ALL=C awk -v bound="$2" '
		{ n = split( $0, s, /[.!?]( |$)/ ) ; if ( $0 == "" ) n = 0 ; if ( n > most ) most = n }
		END { printf "%s\n", ( most <= bound ) ? "within" : "over: " most " sentences" }' "$1"
}
rigPerRun(){ ## file, limit -- the longest paragraph of prose, its sentences against the limit
	LC_ALL=C awk -v bound="$2" '
		/^- / { if ( run > most ) most = run ; run = 0 ; next }
		$0 == "" { if ( run > most ) most = run ; run = 0 ; next }
		/^#/ { if ( run > most ) most = run ; run = 0 ; next }
		/^\{\{[a-z-]+\}\}$/ { if ( run > most ) most = run ; run = 0 ; next }
		{ run = run + split( $0, s, /[.!?]( |$)/ ) }
		END { if ( run > most ) most = run ; printf "%s\n", ( most <= bound ) ? "within" : "over: " most " sentences" }' "$1"
}
rigListItems(){ ## file -- each list item's sentences, as the sentences of one item
	LC_ALL=C awk '
		/^- / { sub( /^- /, "" ) ; gsub( /\{\{[a-z-]+\}\}/, "slot" ) ; gsub( /\[(own|native|lock|scan)\]/, "" ) ; print }
	' "$1"
}
rigListItemSentences(){ ## file -- every list item split into its sentences, within the 20-word cap each
	local items=() item
	while IFS= read -r item ; do
		[ -z "$item" ] || items+=( $(
			printf '%s\n' "$item" | LC_ALL=C awk '{ n = split( $0, s, /[.!?]( |$)/ ) ; for ( i = 1 ; i <= n ; i++ ) { if ( s[i] != "" ) print s[i] } }'
		) )
	done < <( rigListItems "$1" )
	rigWithin 20 ${items[@]+"${items[@]}"}
}
rigCount(){ ## file -- the sentences of a file, and the list items it holds
	LC_ALL=C awk '/^- / { items++ } { n = split( $0, s, /[.!?]( |$)/ ) ; if ( $0 == "" ) n = 0 ; sentences = sentences + n } END { print sentences + 0 ":" items + 0 }' "$1"
}
rigAssert "the block was read whole, to its closing line" "$( tail -1 "$rigTmp/block" )" "When done, hand back and Wait until dismissed."
rigAssert "no sentence of it is over 25 words" "$( rigLongestSentence "$rigTmp/block" )" within
rigAssert "no line holds more than six sentences" "$( rigPerLine "$rigTmp/block" 6 )" within
rigAssert "a line that is not a list item holds no run of instructions: six sentences at most" "$( rigPerRun "$rigTmp/block" 6 )" within
rigAssert "every list item is one sentence of at most 20 words" "$( rigListItemSentences "$rigTmp/block" )" within

if [ "$rigFailCount" -ne 0 ] ; then
	printf '⛔ SPAWN BRIEF FLOOR CHECK FAILED: %d of %d assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))"
	exit 1
fi
printf 'SPAWN_BRIEF_FLOOR: OK (%d assertions, offline)\n' "$rigPassCount"
