# AgentsHarnessSearchHtml.awk -- the result page of html.duckduckgo.com/html/ in, one TAB-separated row a result out: url, title, snippet.
# The url is the link the result points to (the uddg parameter of DuckDuckGo's redirect, percent-decoded); the title and the snippet lose their markup
# and their entities. A page with no result__a link prints nothing. Run with LC_ALL=C.

function hexValue(character) {
	return index("0123456789abcdef", tolower(character)) - 1
}

function percentDecode(text,    out, at, pair) {
	out = ""
	while ( ( at = index(text, "%") ) > 0 ) {
		pair = substr(text, at + 1, 2)
		if ( pair ~ /^[0-9A-Fa-f][0-9A-Fa-f]$/ ) {
			out = out substr(text, 1, at - 1) sprintf("%c", hexValue(substr(pair, 1, 1)) * 16 + hexValue(substr(pair, 2, 1)))
			text = substr(text, at + 3)
		} else {
			out = out substr(text, 1, at)
			text = substr(text, at + 1)
		}
	}
	return out text
}

function entityDecode(text) {
	gsub(/&lt;/, "<", text)
	gsub(/&gt;/, ">", text)
	gsub(/&quot;/, "\"", text)
	gsub(/&#x27;|&#39;/, "'", text)
	gsub(/&nbsp;/, " ", text)
	gsub(/&amp;/, "\\&", text)
	return text
}

function clean(text) {
	gsub(/<[^>]*>/, "", text)
	text = entityDecode(text)
	gsub(/[ \t\r\n]+/, " ", text)
	sub(/^ /, "", text)
	sub(/ $/, "", text)
	return text
}

function attribute(tag, name,    start, rest, quote) {
	start = index(tag, " " name "=")
	if ( start == 0 ) return ""
	rest = substr(tag, start + length(name) + 2)
	quote = substr(rest, 1, 1)
	if ( quote != "\"" && quote != "'" ) return ""
	rest = substr(rest, 2)
	return substr(rest, 1, index(rest, quote) - 1)
}

function target(href,    at, cut) {
	href = entityDecode(href)
	at = index(href, "uddg=")
	if ( at > 0 ) {
		href = substr(href, at + 5)
		cut = index(href, "&")
		if ( cut > 0 ) href = substr(href, 1, cut - 1)
		return percentDecode(href)
	}
	if ( substr(href, 1, 2) == "//" ) return "https:" href
	return href
}

{ body = body $0 "\n" }

END {
	rest = body
	while ( ( at = index(rest, "class=\"result__a\"") ) > 0 ) {
		tagStart = 0
		for ( i = at ; i > 0 ; i-- ) if ( substr(rest, i, 2) == "<a" ) { tagStart = i ; break }
		tagEnd = at + index(substr(rest, at), ">") - 1
		tag = substr(rest, tagStart, tagEnd - tagStart + 1)
		closing = index(substr(rest, tagEnd + 1), "</a>")
		title = (closing > 0) ? substr(rest, tagEnd + 1, closing - 1) : ""
		rest = substr(rest, tagEnd + 1 + (closing > 0 ? closing : 0))
		next_at = index(rest, "class=\"result__a\"")
		segment = (next_at > 0) ? substr(rest, 1, next_at) : rest
		snippet = ""
		snippet_at = index(segment, "class=\"result__snippet\"")
		if ( snippet_at > 0 ) {
			snippet_open = snippet_at + index(substr(segment, snippet_at), ">")
			snippet_close = index(substr(segment, snippet_open), "</a>")
			if ( snippet_close > 0 ) snippet = substr(segment, snippet_open, snippet_close - 1)
		}
		print target(attribute(tag, "href")) "\t" clean(title) "\t" clean(snippet)
	}
}
