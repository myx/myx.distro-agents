#!/usr/bin/env awk
# Fills the post of one ask from its tool's own template (sh-lib/templates/, one
# `<tool>.post.format.md` per asking tool), as that file's `# Contract` says. Loaded after the
# shared filling:
#   LC_ALL=C awk -f AgentsToolingTemplateFill.awk -f AgentsAskPostFill.awk <template>
# Environment: ASKP_WANT, what is printed --
#   post       the body of the post;
#   closed     the same body without its `How to answer` part, for a post that no longer
#              takes an answer;
#   reactions  the emoji the tooling places under the post, one Slack name per line;
#   block      one other block of the template, filled: ASKP_BLOCK names it `<Section>/<heading>`
# -- ASKP_FORM (the answer form, a heading under `# Answers`), ASKP_OPTIONS (the options as
# given, one per line), ASKP_REVISED (1: the post is the question asked again, changed, so its
# title carries the `# Marks` `## revised` text), ASKP_SKELETON (optional: the path of another
# template whose `# Skeleton` `## post` block is filled in place of the named template's own,
# with `{{kind-title}}` standing for the named template's title line; everything else is still
# the named template's), and ASKP_F_<slot> for every other slot, a `-` in a slot's name
# written `_`.
# A template may name parts of its post: each block under `# Parts` is filled, and is the
# value of the slot of its heading -- in the template's own post, and in a skeleton around it,
# which so shows a part only for a template that has it. A part is filled from the fields as
# the call gave them, never from another part, so a part may carry the name of a field: the
# post then shows the part wherever it shows that field, and another part can still show the
# field as it was given.
# Nothing here knows which templates exist: a template is whatever file is named, and a form
# whatever heading it carries.
# The number marks are fixed here, with the names the verdict reader takes a click by
# (AgentsEscalationVerdict.awk): the keycaps one to ten. An option past the tenth is numbered
# in plain digits and has no emoji.
# Exit 3: the template has no block that is needed. Exit 4: a required slot is empty. Either
# is named on stderr, and nothing is printed.

function ttSlot( name,    envName ) {
	if ( name in askSlot ) { return askSlot[name] ; }
	envName = name ;
	gsub( /-/, "_", envName ) ;
	return ENVIRON["ASKP_F_" envName] ;
}

function askFail( code, text ) {
	print "AgentsAskPostFill.awk: " text > "/dev/stderr" ;
	exit code ;
}

function askMark( number ) {
	return ( number <= 10 ? askMarks[number] : number "." ) ;
}

BEGIN {
	template = ARGV[1] ; ARGV[1] = "" ;
	want = ENVIRON["ASKP_WANT"] ;
	form = ENVIRON["ASKP_FORM"] ;
	## A skeleton of its own (ASKP_SKELETON): the post block of another template, around what
	## the template named owns -- its title line, its options, its answers, its emoji.
	skeleton = ENVIRON["ASKP_SKELETON"] ; skeletonPost = "" ;
	if ( skeleton != "" ) {
		if ( ! ttRead( skeleton ) || ! ( ( "Skeleton" SUBSEP "post" ) in ttHas ) ) { askFail( 3, "the skeleton template has no `## post` block under `# Skeleton`: " skeleton ) ; }
		skeletonPost = ttBlock["Skeleton", "post"] ;
		delete ttHas["Skeleton", "post"] ;
	}
	if ( template == "" || ! ttRead( template ) ) { askFail( 3, "the template could not be read: " template ) ; }
	for ( markNo = 1 ; markNo <= 9 ; markNo++ ) { askMarks[markNo] = markNo "\357\270\217\342\203\243" ; }
	askMarks[10] = "\360\237\224\237" ;
	split( "one two three four five six seven eight nine keycap_ten", askNames, " " ) ;

	if ( want == "block" ) {
		blockName = ENVIRON["ASKP_BLOCK"] ;
		slashAt = index( blockName, "/" ) ;
		blockKey = substr( blockName, 1, slashAt - 1 ) SUBSEP substr( blockName, slashAt + 1 ) ;
		if ( slashAt < 2 || ! ( blockKey in ttHas ) ) { askFail( 3, "the template has no block `" blockName "`: " template ) ; }
		print ttFill( ttBlock[blockKey] ) ;
		exit 0 ;
	}

	## The options as given: an empty line is none, a leading `- ` is the asker's own bullet.
	optionTotal = 0 ; recommended = 0 ;
	lineTotal = split( ENVIRON["ASKP_OPTIONS"], optionLines, "\n" ) ;
	for ( lineNo = 1 ; lineNo <= lineTotal ; lineNo++ ) {
		if ( optionLines[lineNo] == "" ) { continue ; }
		optionText[++optionTotal] = optionLines[lineNo] ;
		sub( /^- /, "", optionText[optionTotal] ) ;
		if ( index( tolower( optionLines[lineNo] ), "(recommended)" ) ) { recommended = 1 ; }
	}

	## A form whose emoji are its numbers shows its options numbered.
	reactKey = "Reactions" SUBSEP form ;
	numbered = ( ( reactKey in ttHas ) && index( ttBlock[reactKey], "{{numbers}}" ) > 0 ) ;
	numberNames = "" ;
	for ( optionNo = 1 ; optionNo <= optionTotal && optionNo <= 10 ; optionNo++ ) {
		numberNames = numberNames ( optionNo > 1 ? "\n" : "" ) askNames[optionNo] ;
	}

	if ( want == "reactions" ) {
		if ( ! ( reactKey in ttHas ) ) { exit 0 ; }
		askSlot["numbers"] = numberNames ;
		nameTotal = split( ttFill( ttBlock[reactKey] ), nameList, /[ \t\n]+/ ) ;
		for ( nameNo = 1 ; nameNo <= nameTotal ; nameNo++ ) {
			if ( nameList[nameNo] != "" ) { print nameList[nameNo] ; }
		}
		exit 0 ;
	}
	if ( want != "post" && want != "closed" ) { askFail( 3, "ASKP_WANT must be post, closed, reactions or block: " want ) ; }

	postKey = "Skeleton" SUBSEP "post" ;
	if ( ! ( postKey in ttHas ) ) { askFail( 3, "the template has no `## post` block under `# Skeleton`: " template ) ; }
	postText = ( skeletonPost != "" ) ? skeletonPost : ttBlock[postKey] ;

	## Each option by the line the template gives its style, only where the post shows options.
	if ( optionTotal > 0 && index( postText, "{{options}}" ) > 0 ) {
		optionKey = "Options" SUBSEP ( numbered ? "numbered" : "plain" ) ;
		if ( ! ( optionKey in ttHas ) ) { askFail( 3, "the template has no `## " ( numbered ? "numbered" : "plain" ) "` block under `# Options`: " template ) ; }
		optionsText = "" ;
		for ( optionNo = 1 ; optionNo <= optionTotal ; optionNo++ ) {
			askSlot["number"] = askMark( optionNo ) ;
			askSlot["option"] = optionText[optionNo] ;
			optionsText = optionsText ( optionNo > 1 ? "\n" : "" ) ttFill( ttBlock[optionKey] ) ;
		}
		delete askSlot["number"] ;
		delete askSlot["option"] ;
		askSlot["options"] = optionsText ;
	}
	else { askSlot["options"] = "" ; }

	## The title mark of a question asked again, changed.
	askSlot["revised"] = "" ;
	if ( ENVIRON["ASKP_REVISED"] == "1" && ( ( "Marks" SUBSEP "revised" ) in ttHas ) ) { askSlot["revised"] = ttFill( ttBlock["Marks", "revised"] ) ; }

	## How to answer, by the form: its own block where an option is marked (recommended) and
	## the template has one for that. A closed post has none, so its group is left out.
	askSlot["how-to-answer"] = "" ;
	if ( want == "post" ) {
		answerKey = "Answers" SUBSEP form ", recommended" ;
		if ( ! recommended || ! ( answerKey in ttHas ) ) { answerKey = "Answers" SUBSEP form ; }
		if ( ! ( answerKey in ttHas ) ) { askFail( 3, "the template has no `## " form "` block under `# Answers`: " template ) ; }
		askSlot["how-to-answer"] = ttFill( ttBlock[answerKey] ) ;
		if ( askSlot["how-to-answer"] == "" ) { askFail( 3, "the `## " form "` block under `# Answers` is empty: " template ) ; }
	}

	## The parts of the template's post, each the value of the slot of its name. All of them
	## are filled before any is set, so none is filled from another, in whatever order they come.
	for ( partKey in ttHas ) {
		if ( index( partKey, "Parts" SUBSEP ) != 1 ) { continue ; }
		partText = ttFill( ttBlock[partKey] ) ;
		if ( ttRequiredEmpty > 0 ) { askFail( 4, "the slot {{" ttRequiredName "}} is required and has no value" ) ; }
		partFilled[substr( partKey, length( "Parts" SUBSEP ) + 1 )] = partText ;
	}
	for ( partName in partFilled ) { askSlot[partName] = partFilled[partName] ; }

	## Under a skeleton of its own, the title is the first line of the template's own post.
	if ( skeletonPost != "" ) {
		titleLine = ttBlock[postKey] ;
		titleEnd = index( titleLine, "\n" ) ;
		if ( titleEnd > 0 ) { titleLine = substr( titleLine, 1, titleEnd - 1 ) ; }
		askSlot["kind-title"] = ttFill( titleLine ) ;
	}
	body = ttFill( postText ) ;
	if ( ttRequiredEmpty > 0 ) { askFail( 4, "the slot {{" ttRequiredName "}} is required and has no value" ) ; }
	sub( /[ \t\n]+$/, "", body ) ;
	print body ;
	exit 0 ;
}
