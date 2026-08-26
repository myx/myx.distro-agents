#!/usr/bin/env python3
##
## AgentsGoogleApiCall.py -- the read-side Google API worker behind the
## --member-comms-google-* operations in AgentsTools.MemberCommsGoogle.include.
##
## WHY A PYTHON HELPER AND NOT PLAIN curl, matching the reason
## AgentsImapFetchMessage.py exists: two things here cannot be done in shell in
## this package. First, `jq` is NOT a dependency of this tree (nothing in
## sh-lib/ or sh-scripts/ uses it) and JSON work is done by stdlib python3
## helpers exactly like this one -- so parsing an API response in shell would
## mean either adding a dependency or hand-rolling a JSON parser. Second, every
## call needs an OAuth2 refresh-token exchange FIRST, and the access token it
## returns must then be carried into a second request without ever reaching a
## command line. Doing that as two curl invocations means the access token
## crosses a shell variable and risks argv; doing it in one process does not.
##
## CREDENTIALS ARRIVE ONLY THROUGH THE ENVIRONMENT, NEVER argv -- the same
## mechanism and the same reason as AgentsImapFetchMessage.py, which states it
## in its own header: argv is world-readable through `ps`, so a secret passed
## as a command-line argument is published to every process on the box for the
## call's lifetime. This is deliberately NOT a second spelling invented here;
## it is the convention that helper already set. Nothing secret is written to a
## file either -- the token-exchange body is built in memory and posted
## directly, so there is no temp file to leak through an interrupt window and
## none to forget to remove.
##
## THE API'S STATUS CODE IS NOT THE ANSWER TO THE QUESTION THE CALLER ASKED.
## Same doctrine as every other op in this package. A failed exchange or a
## failed call means the answer is UNKNOWN, never empty and never zero rows.
## Every failure path exits non-zero with the reason on stderr; a successful
## call that genuinely found nothing exits 0 having printed nothing, and those
## two states are never rendered the same way.
##
## Environment contract:
##   AGENTS_GOOGLE_CLIENT_ID       required
##   AGENTS_GOOGLE_CLIENT_SECRET   required
##   AGENTS_GOOGLE_REFRESH_TOKEN   required
##   AGENTS_GOOGLE_OP              required -- whoami|file-find|sheet-read|sheet-info
##   AGENTS_GOOGLE_QUERY           file-find only
##   AGENTS_GOOGLE_LIMIT           file-find, optional (default 50)
##   AGENTS_GOOGLE_FULLTEXT        file-find, optional -- "true" searches body text too
##   AGENTS_GOOGLE_INCLUDE_TRASHED file-find, optional -- "true" keeps trashed files
##   AGENTS_GOOGLE_RAW_QUERY       file-find, optional -- "true" forwards the query verbatim
##   AGENTS_GOOGLE_SHEET_ID        sheet-read, sheet-info, sheet-write, sheet-clear
##   AGENTS_GOOGLE_RANGE           sheet-read, sheet-write, sheet-clear
##   AGENTS_GOOGLE_RENDER          sheet-read, optional (default FORMATTED_VALUE)
##   AGENTS_GOOGLE_APPEND          sheet-write, optional -- "true" appends rows
##   AGENTS_GOOGLE_USER_ENTERED    sheet-write, optional -- "true" parses formulas
##   AGENTS_GOOGLE_DOC_ID          doc-read, doc-write
##   AGENTS_GOOGLE_FILE_ID         comment-read, comment-post
##
## CONTENT FOR A WRITE ARRIVES ON STDIN, never in the environment and never in
## argv: TSV rows for sheet-write, plain text for doc-write and comment-post.
## Credentials go the other way -- environment only, never stdin -- so the two
## channels never carry the same kind of thing and cannot be confused.
##
## Exit statuses, deliberately distinct so a caller can tell outcomes apart:
##   0  the question was answered (possibly with an empty but REAL answer)
##   1  usage/contract error -- nothing was attempted
##   2  the refresh-token exchange failed; NO API call was made
##   3  the exchange succeeded but the API call failed; the answer is UNKNOWN
##   4  the credential is dead (invalid_grant) and a human must re-issue it
##

import json
import sys
import urllib.error
import urllib.parse
import urllib.request

TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token"
DRIVE_ABOUT = "https://www.googleapis.com/drive/v3/about"
DRIVE_FILES = "https://www.googleapis.com/drive/v3/files"
SHEETS_BASE = "https://sheets.googleapis.com/v4/spreadsheets"

CONNECT_TIMEOUT = 120


def fail(status, message):
    """Every exit path names the op's own question, never just the HTTP fact."""
    sys.stderr.write("⛔ ERROR: AgentsGoogleApiCall.py: %s\n" % message)
    sys.exit(status)


def http_json(url, data=None, headers=None, method=None):
    """One request, returning parsed JSON.

    Raises HTTPError with the body attached rather than swallowing it -- the
    body is where Google puts the actual reason (invalid_grant, insufficient
    scope), and an error that cannot say why is barely better than no error.
    """
    request = urllib.request.Request(url, data=data, method=method)
    for key, value in (headers or {}).items():
        request.add_header(key, value)
    with urllib.request.urlopen(request, timeout=CONNECT_TIMEOUT) as response:
        raw = response.read().decode("utf-8", errors="replace")
    if not raw.strip():
        return {}
    return json.loads(raw)


def exchange_refresh_token(client_id, client_secret, refresh_token):
    """Trade the stored refresh token for a short-lived access token.

    THE ONE GENUINELY NEW MOVING PART versus the other comms families, which
    all resolve one static secret and are done. It is also the one place a dead
    credential shows up, and `invalid_grant` is reported as its own exit status
    (4) rather than folded into a generic failure: a dead refresh token needs a
    human to re-consent, while a timeout needs a retry, and collapsing the two
    sends whoever reads the error down the wrong path entirely.
    """
    body = urllib.parse.urlencode({
        "client_id": client_id,
        "client_secret": client_secret,
        "refresh_token": refresh_token,
        "grant_type": "refresh_token",
    }).encode("utf-8")
    try:
        payload = http_json(
            TOKEN_ENDPOINT,
            data=body,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        if "invalid_grant" in detail:
            fail(4, "the stored GOOGLE_REFRESH_TOKEN is no longer valid "
                    "(invalid_grant). It was revoked, expired, or the account "
                    "password changed. This is NOT a transient failure and a "
                    "retry will not fix it -- the token must be re-issued by "
                    "performing the one-time consent again. Google's own "
                    "response: %s" % detail.strip())
        fail(2, "the OAuth2 refresh-token exchange failed with HTTP %s -- no "
                "API call was made and the answer is UNKNOWN, not empty. "
                "Google's own response: %s" % (error.code, detail.strip()))
    except urllib.error.URLError as error:
        fail(2, "the OAuth2 refresh-token exchange could not be performed "
                "(%s) -- no API call was made and the answer is UNKNOWN, not "
                "empty." % error.reason)
    access_token = payload.get("access_token")
    if not access_token:
        fail(2, "the OAuth2 refresh-token exchange returned no access_token. "
                "The answer is UNKNOWN, not empty -- this is a POSITIVE test "
                "on what is present, so a malformed success body fails here "
                "rather than being treated as an empty result.")
    return access_token


def api_get(access_token, url, question):
    """One authenticated GET. `question` names what the caller actually asked."""
    try:
        return http_json(url, headers={"Authorization": "Bearer " + access_token})
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        hint = ""
        if error.code in (401, 403) and "insufficientPermissions" in detail or "insufficient" in detail.lower():
            hint = (" This reads as a SCOPE problem rather than a wrong "
                    "credential: the refresh token is valid but was minted "
                    "without the scope this call needs. Widening scopes "
                    "requires performing the consent again -- it cannot be "
                    "done by the per-call token exchange.")
        fail(3, "%s -- the call failed with HTTP %s, so the answer is UNKNOWN, "
                "not empty.%s Google's own response: %s"
                % (question, error.code, hint, detail.strip()))
    except urllib.error.URLError as error:
        fail(3, "%s -- the call could not be performed (%s), so the answer is "
                "UNKNOWN, not empty." % (question, error.reason))


def tsv_escape(value):
    """Make one cell safe to place in a tab-separated row, reversibly.

    A cell may legitimately contain a tab or a newline. Emitted raw, it
    silently becomes a new column or a new row, which corrupts every consumer
    downstream with nothing to notice it by. The rule is stated here and in the
    op's own help so a caller can reverse it exactly: backslash first (so the
    escape character itself round-trips), then tab, carriage return, newline.
    """
    if value is None:
        return ""
    text = value if isinstance(value, str) else str(value)
    text = text.replace("\\", "\\\\")
    text = text.replace("\t", "\\t")
    text = text.replace("\r", "\\r")
    text = text.replace("\n", "\\n")
    return text


def emit_tsv_row(cells):
    sys.stdout.write("\t".join(tsv_escape(cell) for cell in cells) + "\n")


def column_letters_to_index(letters):
    """'A' -> 1, 'D' -> 4, 'AA' -> 27. Returns None when not a column ref."""
    if not letters:
        return None
    total = 0
    for character in letters:
        if not character.isalpha():
            return None
        total = total * 26 + (ord(character.upper()) - ord("A") + 1)
    return total


def range_width(a1_range):
    """Width in columns of an A1 range, or None when it does not fix one.

    Sheets omits trailing empty cells, so a row whose last cells are blank
    comes back short. The caller named a range and the range defines the width,
    so the width is recovered here and the rows are padded to it -- otherwise
    every positional consumer (`awk -F'\\t' '{print $4}'`) silently reads the
    wrong column with no error at all. When the range does not fix a width
    (a bare tab name, an open-ended range), this returns None and the caller
    falls back to the longest row actually returned, which is the most honest
    answer available.
    """
    if not a1_range:
        return None
    spec = a1_range.split("!")[-1]
    if ":" not in spec:
        return None
    start, end = spec.split(":", 1)
    start_letters = "".join(c for c in start if c.isalpha())
    end_letters = "".join(c for c in end if c.isalpha())
    start_index = column_letters_to_index(start_letters)
    end_index = column_letters_to_index(end_letters)
    if start_index is None or end_index is None:
        return None
    if end_index < start_index:
        return None
    return end_index - start_index + 1


def op_whoami(access_token, _args):
    """Which account does this refresh token actually belong to?

    THE POINT OF THIS OP. The refresh token IS the acting identity -- a token
    minted by consenting as the wrong account leaves the member acting as that
    other person on every call, with correct code and no symptom whatsoever.
    This turns that from undetectable into one command. `about.get` needs no
    scope beyond the Drive scope the family already requires, so it costs
    nothing extra to grant.

    Printed as KEY=VALUE lines, the shape --member-comms-trello-whoami already
    hands its caller for the same question on the Trello side.
    """
    payload = api_get(
        access_token,
        DRIVE_ABOUT + "?" + urllib.parse.urlencode({"fields": "user"}),
        "could not determine which Google account this credential belongs to",
    )
    user = payload.get("user") or {}
    if not user.get("emailAddress"):
        fail(3, "the Drive about.get call returned no user record, so the "
                "acting account is UNKNOWN. This is a POSITIVE test on what is "
                "present: an empty user is not evidence of an anonymous "
                "identity, it is evidence the question was not answered.")
    sys.stdout.write("GOOGLE_ACCOUNT_EMAIL=%s\n" % user.get("emailAddress", ""))
    sys.stdout.write("GOOGLE_ACCOUNT_NAME=%s\n" % user.get("displayName", ""))
    sys.stdout.write("GOOGLE_ACCOUNT_ID=%s\n" % user.get("permissionId", ""))


def drive_quote(term):
    """Escape one caller term for use inside a single-quoted Drive `q` string.

    Drive's `q` is a structured query language, not a search box, and a term is
    carried inside single quotes. An apostrophe in the term -- `Bob's notes` is
    an ordinary filename, not a hypothetical -- closes that string early and
    turns the rest into a syntax error, or worse, into a query that parses as
    something the caller never asked for. Backslash is escaped FIRST so the
    escape character itself round-trips; escaping the quote first would then
    have its own backslash doubled and break the result.

    Same class of decision as the TSV escaping on the sheet side: the rule is
    stated and applied at the boundary rather than left for the API to trip on.
    """
    return term.replace("\\", "\\\\").replace("'", "\\'")


def op_file_find(access_token, args):
    """Drive search -- the entry point, since every other op needs a file id.

    THE TERM IS WRAPPED, NOT FORWARDED. Drive's `q` is a structured query
    language: a bare word like `ADR` is a syntax error there, NOT a
    match-anything, and forwarding one returns HTTP 400 rather than results.
    So the default here takes a plain term and builds the query around it,
    which is what a caller reaching for "find me this file" actually means.

    A full structured Drive query is still available under --raw-query, because
    that was this op's original contract and searches like
    `mimeType='application/vnd.google-apps.spreadsheet' and trashed=false` are
    genuinely useful; narrowing the default must not remove the capability.

    Name-only by default, full text behind a flag: fullText is markedly slower
    and matches body content, so a caller looking for a file BY NAME does not
    expect hits from inside unrelated documents.
    """
    query = args.get("query")
    if not query:
        fail(1, "file-find requires a query")

    if not args.get("raw_query"):
        term = drive_quote(query)
        if args.get("full_text"):
            query = "(name contains '%s' or fullText contains '%s')" % (term, term)
        else:
            query = "name contains '%s'" % term
        ## Trashed files are excluded by default -- otherwise a deleted file
        ## comes back indistinguishable from a live one, and a caller acting on
        ## the result operates on something already in the bin.
        if not args.get("include_trashed"):
            query = query + " and trashed=false"
    ## Validated as a real integer rather than passed through: it arrives as a
    ## string from the environment, and handing a non-numeric value straight to
    ## the API would surface as an opaque HTTP 400 about a parameter the caller
    ## never typed in that form.
    raw_limit = args.get("limit") or ""
    if raw_limit:
        if not raw_limit.isdigit() or int(raw_limit) < 1:
            fail(1, "limit must be a positive whole number, got: %s" % raw_limit)
        limit = int(raw_limit)
    else:
        limit = 50
    url = DRIVE_FILES + "?" + urllib.parse.urlencode({
        "q": query,
        "fields": "files(id,name,mimeType,modifiedTime)",
        "pageSize": limit,
        "supportsAllDrives": "true",
        "includeItemsFromAllDrives": "true",
    })
    payload = api_get(access_token, url, "could not search Drive")
    files = payload.get("files")
    if files is None:
        fail(3, "the Drive files.list call returned no files field, so the "
                "result is UNKNOWN rather than an empty result set.")
    for entry in files:
        emit_tsv_row([
            entry.get("id", ""),
            entry.get("name", ""),
            entry.get("mimeType", ""),
            entry.get("modifiedTime", ""),
        ])


def op_sheet_read(access_token, args):
    """Cell values for one A1 range, as TSV rows padded to the range width."""
    sheet_id = args.get("sheet_id")
    a1_range = args.get("range")
    if not sheet_id or not a1_range:
        fail(1, "sheet-read requires sheet_id and range")
    ## FORMATTED_VALUE is the stated default: it returns what a human reading
    ## the sheet sees. UNFORMATTED_VALUE returns the underlying serial, which
    ## turns dates into numbers. Neither is wrong, so the default is stated
    ## rather than left to whatever the API happens to do.
    render = args.get("render") or "FORMATTED_VALUE"
    url = "%s/%s/values/%s?%s" % (
        SHEETS_BASE,
        urllib.parse.quote(sheet_id, safe=""),
        urllib.parse.quote(a1_range, safe=""),
        urllib.parse.urlencode({"valueRenderOption": render}),
    )
    payload = api_get(access_token, url,
                      "could not read range %s" % a1_range)
    values = payload.get("values")
    if values is None:
        ## A range with no data at all legitimately omits `values` entirely.
        ## That IS a real, complete answer -- the range is empty -- and is
        ## reported as zero rows with exit 0, distinctly from a failed call
        ## above, which exits 3 having said the answer is UNKNOWN.
        return
    width = range_width(a1_range)
    if width is None:
        width = max((len(row) for row in values), default=0)
    for row in values:
        padded = list(row) + [""] * (width - len(row))
        emit_tsv_row(padded)


def op_sheet_info(access_token, args):
    """Tab names and dimensions -- what a caller needs to build a range."""
    sheet_id = args.get("sheet_id")
    if not sheet_id:
        fail(1, "sheet-info requires sheet_id")
    url = "%s/%s?%s" % (
        SHEETS_BASE,
        urllib.parse.quote(sheet_id, safe=""),
        urllib.parse.urlencode({
            "fields": "properties.title,sheets.properties("
                      "title,sheetId,index,gridProperties)",
        }),
    )
    payload = api_get(access_token, url,
                      "could not read spreadsheet metadata")
    title = (payload.get("properties") or {}).get("title", "")
    sys.stdout.write("SPREADSHEET_TITLE=%s\n" % tsv_escape(title))
    sheets = payload.get("sheets")
    if sheets is None:
        fail(3, "the spreadsheets.get call returned no sheets field, so the "
                "tab list is UNKNOWN rather than empty.")
    ## Tabs as TSV after the KEY=VALUE title line: one header row naming the
    ## columns, because unlike whoami this part is a table and a caller reading
    ## it positionally needs to know what the positions mean.
    emit_tsv_row(["TAB_TITLE", "TAB_ID", "TAB_INDEX", "ROWS", "COLUMNS"])
    for entry in sheets:
        properties = entry.get("properties") or {}
        grid = properties.get("gridProperties") or {}
        emit_tsv_row([
            properties.get("title", ""),
            properties.get("sheetId", ""),
            properties.get("index", ""),
            grid.get("rowCount", ""),
            grid.get("columnCount", ""),
        ])


def tsv_unescape(text):
    """Exact inverse of tsv_escape.

    Written as a single left-to-right scan rather than a sequence of
    str.replace calls, because chained replaces are WRONG here: replacing
    "\\t" -> tab before "\\\\" -> backslash turns the literal two-character
    sequence backslash-t (which the read path emits as \\\\t) into a real tab.
    A round trip through escape then unescape must return the original cell
    exactly, including cells that themselves contain backslashes.
    """
    result = []
    index = 0
    length = len(text)
    while index < length:
        character = text[index]
        if character == "\\" and index + 1 < length:
            following = text[index + 1]
            if following == "t":
                result.append("\t")
                index += 2
                continue
            if following == "n":
                result.append("\n")
                index += 2
                continue
            if following == "r":
                result.append("\r")
                index += 2
                continue
            if following == "\\":
                result.append("\\")
                index += 2
                continue
        result.append(character)
        index += 1
    return "".join(result)


def read_stdin_content(what):
    """Content for a write arrives on stdin; credentials never do."""
    data = sys.stdin.read()
    if not data:
        fail(1, "no %s supplied on stdin -- nothing was written" % what)
    return data


def stdin_tsv_values():
    """Parse the TSV on stdin into the API's `values` array.

    The inverse of what --member-comms-google-sheet-read emits, so a range can
    be read, edited in a shell pipeline, and written straight back. Trailing
    newline is ignored; every other line becomes a row, including blank ones,
    since a blank row inside a range is meaningful data rather than padding.
    """
    raw = read_stdin_content("TSV content")
    lines = raw.split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    return [[tsv_unescape(cell) for cell in line.split("\t")] for line in lines]


def api_send(access_token, url, payload, question, method="POST"):
    """One authenticated write. Same failure doctrine as api_get."""
    body = json.dumps(payload).encode("utf-8")
    try:
        return http_json(
            url,
            data=body,
            headers={
                "Authorization": "Bearer " + access_token,
                "Content-Type": "application/json",
            },
            method=method,
        )
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        hint = ""
        if error.code in (401, 403):
            hint = (" A scope or permission problem: the credential may be "
                    "valid but minted without write scope, or the account may "
                    "not have edit access to this file. Neither is fixed by "
                    "retrying.")
        if "SERVICE_DISABLED" in detail:
            hint = (" The API itself is not enabled on the Cloud project. That "
                    "is a console setting, independent of scopes, and looks "
                    "like a permission error without being one.")
        fail(3, "%s -- the write failed with HTTP %s. Whether anything was "
                "changed is UNKNOWN; do not assume it was not.%s Google's own "
                "response: %s" % (question, error.code, hint, detail.strip()))
    except urllib.error.URLError as error:
        fail(3, "%s -- the write could not be performed (%s). Whether anything "
                "was changed is UNKNOWN." % (question, error.reason))


def op_sheet_write(access_token, args):
    """Write TSV from stdin into one A1 range."""
    sheet_id = args.get("sheet_id")
    a1_range = args.get("range")
    if not sheet_id or not a1_range:
        fail(1, "sheet-write requires sheet_id and range")
    ## RAW IS THE DEFAULT, AND IT IS A SAFETY DECISION RATHER THAN A
    ## PREFERENCE. Under USER_ENTERED, Google parses each value as though a
    ## person had typed it, so any caller-supplied cell beginning with `=`
    ## becomes a live formula in a document real people will open. RAW stores
    ## exactly what was given. USER_ENTERED stays available for the case where
    ## a formula or a locale-parsed date is genuinely intended.
    input_option = "USER_ENTERED" if args.get("user_entered") else "RAW"
    values = stdin_tsv_values()
    if args.get("append"):
        url = "%s/%s/values/%s:append?%s" % (
            SHEETS_BASE,
            urllib.parse.quote(sheet_id, safe=""),
            urllib.parse.quote(a1_range, safe=""),
            urllib.parse.urlencode({
                "valueInputOption": input_option,
                "insertDataOption": "INSERT_ROWS",
            }),
        )
        payload = api_send(access_token, url, {"values": values},
                           "could not append to %s" % a1_range)
        updates = payload.get("updates") or {}
        sys.stderr.write("# appended %s cell(s) to %s\n"
                         % (updates.get("updatedCells", "?"),
                            updates.get("updatedRange", a1_range)))
        return
    url = "%s/%s/values/%s?%s" % (
        SHEETS_BASE,
        urllib.parse.quote(sheet_id, safe=""),
        urllib.parse.quote(a1_range, safe=""),
        urllib.parse.urlencode({"valueInputOption": input_option}),
    )
    payload = api_send(access_token, url, {"values": values},
                       "could not write %s" % a1_range, method="PUT")
    sys.stderr.write("# wrote %s cell(s) to %s\n"
                     % (payload.get("updatedCells", "?"),
                        payload.get("updatedRange", a1_range)))


def op_sheet_clear(access_token, args):
    """Clear the values in one A1 range. Its own op because it destroys data."""
    sheet_id = args.get("sheet_id")
    a1_range = args.get("range")
    if not sheet_id or not a1_range:
        fail(1, "sheet-clear requires sheet_id and range")
    url = "%s/%s/values/%s:clear" % (
        SHEETS_BASE,
        urllib.parse.quote(sheet_id, safe=""),
        urllib.parse.quote(a1_range, safe=""),
    )
    payload = api_send(access_token, url, {},
                       "could not clear %s" % a1_range)
    sys.stderr.write("# cleared %s\n"
                     % payload.get("clearedRange", a1_range))


def doc_text(document):
    """Flatten a Docs document's body into plain text.

    Only paragraph text runs are extracted. Tables, embedded objects and
    footnotes are NOT rendered, and that is stated here and in the op's help
    rather than left for a caller to infer from output that merely looks
    complete -- silently dropping a table would be exactly the kind of
    plausible-but-wrong answer this package is built to avoid.
    """
    pieces = []
    for element in (document.get("body") or {}).get("content") or []:
        paragraph = element.get("paragraph")
        if not paragraph:
            continue
        for run in paragraph.get("elements") or []:
            text_run = run.get("textRun")
            if text_run and text_run.get("content"):
                pieces.append(text_run["content"])
    return "".join(pieces)


def op_doc_read(access_token, args):
    """Plain text of one Google Doc."""
    doc_id = args.get("doc_id")
    if not doc_id:
        fail(1, "doc-read requires doc_id")
    payload = api_get(
        access_token,
        "https://docs.googleapis.com/v1/documents/%s"
        % urllib.parse.quote(doc_id, safe=""),
        "could not read document %s" % doc_id,
    )
    if payload.get("body") is None:
        fail(3, "the document returned no body, so its content is UNKNOWN "
                "rather than empty.")
    sys.stdout.write(doc_text(payload))


def op_doc_write(access_token, args):
    """Append text from stdin to the end of one Google Doc.

    APPEND ONLY, DELIBERATELY. Replacing a document's whole body means
    computing and deleting its existing content range first, which is
    destructive and structural in the same sense as spreadsheets.batchUpdate.
    If replace-in-place is ever wanted it belongs in its own op, on the same
    reasoning that gave sheet-clear its own name rather than a flag.

    endOfSegmentLocation is used rather than a computed index: it appends to
    the end of the body without a separate round trip to measure the document,
    so there is no window in which the length could change underneath.
    """
    doc_id = args.get("doc_id")
    if not doc_id:
        fail(1, "doc-write requires doc_id")
    text = read_stdin_content("document text")
    url = "https://docs.googleapis.com/v1/documents/%s:batchUpdate" \
        % urllib.parse.quote(doc_id, safe="")
    payload = api_send(
        access_token,
        url,
        {"requests": [{
            "insertText": {
                "endOfSegmentLocation": {"segmentId": ""},
                "text": text,
            },
        }]},
        "could not append to document %s" % doc_id,
    )
    sys.stderr.write("# appended %d character(s) to document %s (revision %s)\n"
                     % (len(text), doc_id, payload.get("writeControl", {})
                        .get("requiredRevisionId", "?")))


def op_comment_read(access_token, args):
    """Comments on one Drive file, newest API order, as TSV."""
    file_id = args.get("file_id")
    if not file_id:
        fail(1, "comment-read requires file_id")
    url = "https://www.googleapis.com/drive/v3/files/%s/comments?%s" % (
        urllib.parse.quote(file_id, safe=""),
        urllib.parse.urlencode({
            "fields": "comments(id,author(displayName),createdTime,resolved,content)",
            "pageSize": 100,
        }),
    )
    payload = api_get(access_token, url,
                      "could not read comments on %s" % file_id)
    comments = payload.get("comments")
    if comments is None:
        fail(3, "the comments call returned no comments field, so the comment "
                "list is UNKNOWN rather than empty.")
    emit_tsv_row(["COMMENT_ID", "AUTHOR", "CREATED", "RESOLVED", "CONTENT"])
    for comment in comments:
        emit_tsv_row([
            comment.get("id", ""),
            (comment.get("author") or {}).get("displayName", ""),
            comment.get("createdTime", ""),
            "true" if comment.get("resolved") else "false",
            comment.get("content", ""),
        ])


def op_comment_post(access_token, args):
    """Post one comment onto one Drive file. Works for Docs and Sheets alike."""
    file_id = args.get("file_id")
    if not file_id:
        fail(1, "comment-post requires file_id")
    text = read_stdin_content("comment text")
    url = "https://www.googleapis.com/drive/v3/files/%s/comments?%s" % (
        urllib.parse.quote(file_id, safe=""),
        urllib.parse.urlencode({"fields": "id,createdTime"}),
    )
    payload = api_send(access_token, url, {"content": text},
                       "could not post a comment on %s" % file_id)
    if not payload.get("id"):
        fail(3, "the comment call returned no id, so whether the comment was "
                "posted is UNKNOWN -- this is a POSITIVE test on what is "
                "present rather than an assumption drawn from a 2xx status.")
    sys.stdout.write("COMMENT_ID=%s\n" % payload.get("id", ""))
    sys.stdout.write("COMMENT_CREATED=%s\n" % payload.get("createdTime", ""))


OPERATIONS = {
    "whoami": op_whoami,
    "file-find": op_file_find,
    "sheet-read": op_sheet_read,
    "sheet-info": op_sheet_info,
    "sheet-write": op_sheet_write,
    "sheet-clear": op_sheet_clear,
    "doc-read": op_doc_read,
    "doc-write": op_doc_write,
    "comment-read": op_comment_read,
    "comment-post": op_comment_post,
}


def main():
    import os

    client_id = os.environ.get("AGENTS_GOOGLE_CLIENT_ID", "").strip()
    client_secret = os.environ.get("AGENTS_GOOGLE_CLIENT_SECRET", "").strip()
    refresh_token = os.environ.get("AGENTS_GOOGLE_REFRESH_TOKEN", "").strip()
    op_name = os.environ.get("AGENTS_GOOGLE_OP", "").strip()

    if not client_id or not client_secret or not refresh_token:
        fail(1, "GOOGLE_CLIENT_ID/GOOGLE_CLIENT_SECRET/GOOGLE_REFRESH_TOKEN "
                "were not supplied in the environment. Credentials are passed "
                "through the environment and never through argv; nothing was "
                "attempted.")
    if not op_name:
        fail(1, "AGENTS_GOOGLE_OP was not supplied in the environment")

    operation = OPERATIONS.get(op_name)
    if operation is None:
        fail(1, "unknown op: %s -- known ops are %s"
                % (op_name, ", ".join(sorted(OPERATIONS))))

    args = {
        "query": os.environ.get("AGENTS_GOOGLE_QUERY", "").strip(),
        "limit": os.environ.get("AGENTS_GOOGLE_LIMIT", "").strip(),
        "sheet_id": os.environ.get("AGENTS_GOOGLE_SHEET_ID", "").strip(),
        "range": os.environ.get("AGENTS_GOOGLE_RANGE", "").strip(),
        "render": os.environ.get("AGENTS_GOOGLE_RENDER", "").strip(),
        "full_text": os.environ.get("AGENTS_GOOGLE_FULLTEXT", "").strip() == "true",
        "include_trashed": os.environ.get("AGENTS_GOOGLE_INCLUDE_TRASHED", "").strip() == "true",
        "raw_query": os.environ.get("AGENTS_GOOGLE_RAW_QUERY", "").strip() == "true",
        "doc_id": os.environ.get("AGENTS_GOOGLE_DOC_ID", "").strip(),
        "file_id": os.environ.get("AGENTS_GOOGLE_FILE_ID", "").strip(),
        "append": os.environ.get("AGENTS_GOOGLE_APPEND", "").strip() == "true",
        "user_entered": os.environ.get("AGENTS_GOOGLE_USER_ENTERED", "").strip() == "true",
    }

    access_token = exchange_refresh_token(client_id, client_secret, refresh_token)
    operation(access_token, args)


if __name__ == "__main__":
    main()
