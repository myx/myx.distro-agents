#!/usr/bin/env bash
## Behavioural check on AgentsMarkdownHtmlDocument.awk, the document mode
## beside AgentsEmailHtmlBuild.awk: every block construct (ATX headings,
## paragraphs and line breaks, nested lists, GFM tables, block quotes, rules,
## fences) and images, each against its exact HTML; the one-line inline
## cases against the email mode own output, with a control that differs; an
## ADR-shaped and an IVR-shaped document against their expected HTML under
## check-fixtures/; and the file under the awk axiom checker, and under
## gawk --posix where gawk is installed. Pure pipe into the converter --
## offline by construction.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents"
rigAwk="$rigPackage/sh-lib/AgentsMarkdownHtmlDocument.awk"
rigEmailAwk="$rigPackage/sh-lib/AgentsEmailHtmlBuild.awk"
rigAxiomAwk="$rigPackage/sh-test/AgentsHarnessAwkAxiom.test.awk"
rigFixtures="$rigPackage/sh-test/check-fixtures"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigAwk" ] || rigRefuse "the converter is not at the origin this workspace resolves: $rigAwk"
[ -f "$rigEmailAwk" ] || rigRefuse "the email converter is not at the origin this workspace resolves: $rigEmailAwk"
[ -f "$rigAxiomAwk" ] || rigRefuse "the awk axiom checker is not at the origin this workspace resolves: $rigAxiomAwk"
for rigDoc in adr ivr ; do
	[ -f "$rigFixtures/markdown-html-document.$rigDoc.md" ] && [ -f "$rigFixtures/markdown-html-document.$rigDoc.html" ] \
		|| rigRefuse "the $rigDoc fixture pair is missing under $rigFixtures"
done

rigTmp="$( mktemp -d -t "AgentsMarkdownHtmlDocumentCheck-XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## Runs the converter over one or more input lines, joined with real newlines.
rigConvert(){ ## line [line...]
	printf '%s\n' "$@" | LC_ALL=C awk -f "$rigAwk"
}
## The expected output, one argument per line.
rigLines(){ ## line [line...]
	printf '%s\n' "$@"
}
## A whole fixture document under the given awk against its expected HTML,
## with a diff on a mismatch rather than two pages of got and want.
rigDocument(){ ## what is asserted, fixture name, awk command words...
	local what="$1" doc="$2"
	shift 2
	LC_ALL=C "$@" -f "$rigAwk" < "$rigFixtures/markdown-html-document.$doc.md" > "$rigTmp/$doc.got" 2>&1
	if cmp -s "$rigTmp/$doc.got" "$rigFixtures/markdown-html-document.$doc.html" ; then
		printf '  PASS  %s\n' "$what" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n' "$what"
		diff "$rigFixtures/markdown-html-document.$doc.html" "$rigTmp/$doc.got" | sed 's/^/        /'
		rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## The subject has to be reachable before anything is asserted about it.
rigSmoke="$( rigConvert '# smoke' )"
[ "$rigSmoke" = '<h1>smoke</h1>' ] || rigRefuse "the converter did not render one heading, so no case below would be measured: $rigSmoke"

echo "-- ATX headings, h1 to h6 --"
rigAssert "a level-1 heading" "$( rigConvert '# One' )" '<h1>One</h1>'
rigAssert "a level-6 heading" "$( rigConvert '###### Six' )" '<h6>Six</h6>'
rigAssert "seven hashes are paragraph text" "$( rigConvert '####### Seven' )" '<p>####### Seven</p>'
rigAssert "a hash with no space after it is paragraph text" "$( rigConvert '#NoSpace' )" '<p>#NoSpace</p>'
rigAssert "a closing hash run is dropped" "$( rigConvert '## Closed ##' )" '<h2>Closed</h2>'
rigAssert "up to three spaces of indentation still make a heading" "$( rigConvert '   ### Indented' )" '<h3>Indented</h3>'
rigAssert "inline markup inside a heading" \
	"$( rigConvert '### A *styled* `code` heading' )" '<h3>A <em>styled</em> <code>code</code> heading</h3>'
rigAssert "a heading escapes HTML" "$( rigConvert '## Fish & <chips>' )" '<h2>Fish &amp; &lt;chips&gt;</h2>'
rigAssert "a heading ends a paragraph" "$( rigConvert 'text' '#### Four' )" "$( rigLines '<p>text</p>' '<h4>Four</h4>' )"

echo "-- paragraphs and line breaks --"
rigAssert "a line break inside a paragraph stays a newline" "$( rigConvert 'one' 'two' )" "$( rigLines '<p>one' 'two</p>' )"
rigAssert "two trailing spaces make a hard break" "$( rigConvert 'one  ' 'two' )" "$( rigLines '<p>one<br>' 'two</p>' )"
rigAssert "a trailing backslash makes a hard break" "$( rigConvert 'one\' 'two' )" "$( rigLines '<p>one<br>' 'two</p>' )"
rigAssert "a blank line separates paragraphs" "$( rigConvert 'one' '' 'two' )" "$( rigLines '<p>one</p>' '<p>two</p>' )"
rigAssert "emphasis spans a line break" "$( rigConvert '**bold' 'text**' )" "$( rigLines '<p><strong>bold' 'text</strong></p>' )"

echo "-- unordered and ordered lists, nested by indentation --"
rigAssert "a tight bullet list" "$( rigConvert '- a' '- b' )" "$( rigLines '<ul>' '<li>a</li>' '<li>b</li>' '</ul>' )"
rigAssert "plus and star are bullets too" "$( rigConvert '+ a' '' '* b' )" \
	"$( rigLines '<ul>' '<li>a</li>' '</ul>' '<ul>' '<li>b</li>' '</ul>' )"
rigAssert "three levels nest by indentation" "$( rigConvert '- a' '  - b' '    - c' '- d' )" \
	"$( rigLines '<ul>' '<li>a' '<ul>' '<li>b' '<ul>' '<li>c</li>' '</ul>' '</li>' '</ul>' '</li>' '<li>d</li>' '</ul>' )"
rigAssert "an ordered list" "$( rigConvert '1. one' '2. two' )" "$( rigLines '<ol>' '<li>one</li>' '<li>two</li>' '</ol>' )"
rigAssert "an ordered list not starting at 1 carries start" "$( rigConvert '3. three' '4. four' )" \
	"$( rigLines '<ol start="3">' '<li>three</li>' '<li>four</li>' '</ol>' )"
rigAssert "a parenthesis delimiter is an ordered list too" "$( rigConvert '1) one' )" "$( rigLines '<ol>' '<li>one</li>' '</ol>' )"
rigAssert "bullets indented two columns under an ordered item nest" "$( rigConvert '1. one' '  - sub' '2. two' )" \
	"$( rigLines '<ol>' '<li>one' '<ul>' '<li>sub</li>' '</ul>' '</li>' '<li>two</li>' '</ol>' )"
rigAssert "a blank line between items makes the list loose" "$( rigConvert '- a' '' '- b' )" \
	"$( rigLines '<ul>' '<li>' '<p>a</p>' '</li>' '<li>' '<p>b</p>' '</li>' '</ul>' )"
rigAssert "a blank line between blocks of one item makes it loose" "$( rigConvert '- a' '' '  more' '- b' )" \
	"$( rigLines '<ul>' '<li>' '<p>a</p>' '<p>more</p>' '</li>' '<li>' '<p>b</p>' '</li>' '</ul>' )"
rigAssert "a changed bullet character starts a new list" "$( rigConvert '- a' '* b' )" \
	"$( rigLines '<ul>' '<li>a</li>' '</ul>' '<ul>' '<li>b</li>' '</ul>' )"
rigAssert "a list interrupts a paragraph" "$( rigConvert 'Steps:' '- a' )" "$( rigLines '<p>Steps:</p>' '<ul>' '<li>a</li>' '</ul>' )"
rigAssert "a number other than 1 does not interrupt a paragraph" "$( rigConvert 'In' '2024. we' )" "$( rigLines '<p>In' '2024. we</p>' )"
rigAssert "an empty item" "$( rigConvert '-' '- x' )" "$( rigLines '<ul>' '<li></li>' '<li>x</li>' '</ul>' )"
rigAssert "a fence inside an item keeps its blank line" "$( rigConvert '- item' '  ```sh' '  echo a' '' '  echo b' '  ```' '- next' )" \
	"$( rigLines '<ul>' '<li>item' '<pre><code class="language-sh">echo a' '' 'echo b</code></pre>' '</li>' '<li>next</li>' '</ul>' )"
rigAssert "a paragraph after a blank line leaves the list" "$( rigConvert '- a' '' 'after' )" \
	"$( rigLines '<ul>' '<li>a</li>' '</ul>' '<p>after</p>' )"

echo "-- GFM tables, with alignment --"
rigAssert "left, center and right columns; a short row padded, a long row cut" \
	"$( rigConvert '| A | B | C |' '| :-- | :-: | --: |' '| 1 | 2 | 3 |' '| x |' '| p | q | r | s |' )" \
	"$( rigLines '<table>' '<thead>' \
		'<tr><th style="text-align:left">A</th><th style="text-align:center">B</th><th style="text-align:right">C</th></tr>' \
		'</thead>' '<tbody>' \
		'<tr><td style="text-align:left">1</td><td style="text-align:center">2</td><td style="text-align:right">3</td></tr>' \
		'<tr><td style="text-align:left">x</td><td style="text-align:center"></td><td style="text-align:right"></td></tr>' \
		'<tr><td style="text-align:left">p</td><td style="text-align:center">q</td><td style="text-align:right">r</td></tr>' \
		'</tbody>' '</table>' )"
rigAssert "an escaped pipe in a code span, inline markup in a cell, a row with no pipe" \
	"$( rigConvert '| `a\|b` | **x** |' '|---|---|' 'tail row' )" \
	"$( rigLines '<table>' '<thead>' '<tr><th><code>a|b</code></th><th><strong>x</strong></th></tr>' '</thead>' \
		'<tbody>' '<tr><td>tail row</td><td></td></tr>' '</tbody>' '</table>' )"
rigAssert "pipe rows with no delimiter row stay a paragraph" "$( rigConvert '| a | b |' '| c | d |' )" \
	"$( rigLines '<p>| a | b |' '| c | d |</p>' )"
rigAssert "a delimiter row with another cell count is no table" "$( rigConvert '| a | b |' '| --- |' )" \
	"$( rigLines '<p>| a | b |' '| --- |</p>' )"
rigAssert "a table interrupts a paragraph" "$( rigConvert 'pre' '| H |' '| - |' '| v |' )" \
	"$( rigLines '<p>pre</p>' '<table>' '<thead>' '<tr><th>H</th></tr>' '</thead>' '<tbody>' '<tr><td>v</td></tr>' '</tbody>' '</table>' )"
rigAssert "a header-only table has no tbody, and a blank line ends a table" "$( rigConvert '| H |' '| --- |' '' 'after' )" \
	"$( rigLines '<table>' '<thead>' '<tr><th>H</th></tr>' '</thead>' '</table>' '<p>after</p>' )"

echo "-- block quotes and horizontal rules --"
rigAssert "a block quote" "$( rigConvert '> quoted' )" "$( rigLines '<blockquote>' '<p>quoted</p>' '</blockquote>' )"
rigAssert "a lazy line continues the quoted paragraph" "$( rigConvert '> one' 'two' )" \
	"$( rigLines '<blockquote>' '<p>one' 'two</p>' '</blockquote>' )"
rigAssert "a nested quote" "$( rigConvert '> > deep' )" \
	"$( rigLines '<blockquote>' '<blockquote>' '<p>deep</p>' '</blockquote>' '</blockquote>' )"
rigAssert "a list and a heading inside a quote" "$( rigConvert '> # Head' '>' '> - a' '> - b' )" \
	"$( rigLines '<blockquote>' '<h1>Head</h1>' '<ul>' '<li>a</li>' '<li>b</li>' '</ul>' '</blockquote>' )"
rigAssert "a blank line ends a quote" "$( rigConvert '> a' '' '> b' )" \
	"$( rigLines '<blockquote>' '<p>a</p>' '</blockquote>' '<blockquote>' '<p>b</p>' '</blockquote>' )"
rigAssert "dashes, stars and underscores make rules, spaced or not" "$( rigConvert '---' '***' '_ _ _' '- - -' )" \
	"$( rigLines '<hr>' '<hr>' '<hr>' '<hr>' )"
rigAssert "a rule under a paragraph is a rule, not a setext heading" "$( rigConvert 'a' '---' )" "$( rigLines '<p>a</p>' '<hr>' )"
rigAssert "two dashes are text" "$( rigConvert '--' )" '<p>--</p>'

echo "-- images, src kept as written --"
rigAssert "an image with a title" "$( rigConvert '![Diagram](img/flow.svg "The flow")' )" \
	'<p><img src="img/flow.svg" alt="Diagram" title="The flow"></p>'
rigAssert "an image with no alt text" "$( rigConvert '![](a.png)' )" '<p><img src="a.png" alt=""></p>'
rigAssert "an angle-bracket src may hold a space" "$( rigConvert '![x](<../shared/a b.png>)' )" \
	'<p><img src="../shared/a b.png" alt="x"></p>'
rigAssert "a src is attribute-escaped only" "$( rigConvert '![q](https://cdn.example.com/a.png?w=1&h=2)' )" \
	'<p><img src="https://cdn.example.com/a.png?w=1&amp;h=2" alt="q"></p>'
rigAssert "alt text is attribute-escaped" "$( rigConvert '![a "b" <c>](x.png)' )" \
	'<p><img src="x.png" alt="a &quot;b&quot; &lt;c&gt;"></p>'
rigAssert "a bang with no image after it stays text" "$( rigConvert '!not an image and ![alt](missing' )" \
	'<p>!not an image and ![alt](missing</p>'
rigAssert "an image in a list item and in a table cell" "$( rigConvert '- ![i](a.png)' '' '| ![j](b.png) |' '| --- |' )" \
	"$( rigLines '<ul>' '<li><img src="a.png" alt="i"></li>' '</ul>' '<table>' '<thead>' '<tr><th><img src="b.png" alt="j"></th></tr>' '</thead>' '</table>' )"

echo "-- fenced code --"
rigAssert "a fence is escaped and verbatim" "$( rigConvert '```' 'a < b' '# not a heading' '- not a list' '```' )" \
	"$( rigLines '<pre><code>a &lt; b' '# not a heading' '- not a list</code></pre>' )"
rigAssert "an info string becomes the language class" "$( rigConvert '```bash' 'echo "x"' '```' )" \
	'<pre><code class="language-bash">echo &quot;x&quot;</code></pre>'
rigAssert "a tilde fence holds backticks" "$( rigConvert '~~~' 'tilde ``` inside' '~~~' )" '<pre><code>tilde ``` inside</code></pre>'
rigAssert "only a fence at least as long closes one" "$( rigConvert '````' '```' '````' )" '<pre><code>```</code></pre>'
rigAssert "a blank line inside a fence is kept" "$( rigConvert '```' 'a' '' 'b' '```' )" "$( rigLines '<pre><code>a' '' 'b</code></pre>' )"
rigAssert "an unterminated fence runs to the end" "$( rigConvert '```' 'unterminated' )" '<pre><code>unterminated</code></pre>'
rigAssert "a fence interrupts a paragraph" "$( rigConvert 'text' '```' 'code' '```' )" "$( rigLines '<p>text</p>' '<pre><code>code</code></pre>' )"

echo "-- inline additions: link title, autolink, backtick runs, nesting --"
rigAssert "a link title" "$( rigConvert '[a](https://x.example "T")' )" '<p><a href="https://x.example" title="T">a</a></p>'
rigAssert "an autolink" "$( rigConvert '<https://example.com/a?b=1>' )" \
	'<p><a href="https://example.com/a?b=1">https://example.com/a?b=1</a></p>'
rigAssert "angle brackets around anything else are text" "$( rigConvert '<notalink>' )" '<p>&lt;notalink&gt;</p>'
rigAssert "a double-backtick code span holds a backtick" "$( rigConvert '``a`b``' )" '<p><code>a`b</code></p>'
rigAssert "an unclosed backtick is text" "$( rigConvert '`unclosed' )" '<p>`unclosed</p>'
rigAssert "a code span inside bold stays inside one strong" "$( rigConvert '**bold `code` bold**' )" \
	'<p><strong>bold <code>code</code> bold</strong></p>'
rigAssert "a link inside bold stays inside one strong" "$( rigConvert '**see [a](https://u.example)**' )" \
	'<p><strong>see <a href="https://u.example">a</a></strong></p>'

echo "-- escaping, and no raw HTML passes through --"
rigAssert "a tag and an entity in a paragraph are text" "$( rigConvert '<script>alert(1)</script> &amp;' )" \
	'<p>&lt;script&gt;alert(1)&lt;/script&gt; &amp;amp;</p>'
rigAssert "a tag in a table cell is text" "$( rigConvert '| <b>cell</b> |' '| --- |' )" \
	"$( rigLines '<table>' '<thead>' '<tr><th>&lt;b&gt;cell&lt;/b&gt;</th></tr>' '</thead>' '</table>' )"

echo "-- one-line inline cases render exactly as the email mode renders them --"
for rigLine in \
	'A **bold** word and `a code span`.' \
	'**bold** and *it* and __b__ and _i_ and ***both***' \
	'*a **b** c*' \
	'Use `http://example.com` literally.' \
	'See [Click here](https://example.com/page) now.' \
	'See [docs](https://example.com/a_b_c) now' \
	'Visit https://example.com/path. Thanks.' \
	'Open https://user@host/path now.' \
	'Contact rig@example.com for help.' \
	'Use & and <tag> and "q" here.' \
	'mcp__myx_distro__execute and some_var_name' \
	'\*not em\* and \`not code\`' \
	'the array [1](see below) stays' \
	'(see https://example.com/x)' \
	'Running version 3.2.57 now'
do
	rigAssert "same as the email mode: $rigLine" "$( rigConvert "$rigLine" )" \
		"$( printf '%s\n' "$rigLine" | LC_ALL=C awk -v format=markdown -f "$rigEmailAwk" )"
done
rigAssert "control: a heading line renders differently in the two modes" \
	"$( [ "$( rigConvert '# Title' )" != "$( printf '%s\n' '# Title' | LC_ALL=C awk -v format=markdown -f "$rigEmailAwk" )" ] && printf differs || printf same )" differs

echo "-- ADR-shaped and IVR-shaped documents --"
rigDocument "the ADR document renders as its expected HTML" adr awk
rigDocument "the IVR document renders as its expected HTML" ivr awk

echo "-- portability --"
rigAssert "the awk axiom checker finds no statement missing its semicolon" \
	"$( LC_ALL=C awk -f "$rigAxiomAwk" "$rigAwk" ; printf 'rc=%s' "$?" )" 'rc=0'
if command -v gawk > /dev/null 2>&1 ; then
	rigDocument "gawk --posix renders the ADR document the same" adr gawk --posix
	rigDocument "gawk --posix renders the IVR document the same" ivr gawk --posix
else
	echo "  SKIP  gawk is not installed here, so the gawk --posix comparison did not run"
fi

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MARKDOWN HTML DOCUMENT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MARKDOWN_HTML_DOCUMENT: OK (%d assertions, offline)\n' "$rigPassCount"
