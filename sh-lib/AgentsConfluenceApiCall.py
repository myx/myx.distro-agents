#!/usr/bin/env python3
##
## AgentsConfluenceApiCall.py -- the Confluence Cloud API worker behind the
## --member-comms-confluence-* operations in
## AgentsTools.MemberCommsConfluence.include.
##
## CREDENTIALS ARRIVE ONLY THROUGH THE ENVIRONMENT, NEVER argv -- the same
## mechanism and the same reason as AgentsImapFetchMessage.py and
## AgentsGoogleApiCall.py, stated in the first of those: argv is world-readable
## through `ps`. This matters more than usual here, because Atlassian's own
## documented curl example is `curl -u email:api_token`, which puts the token
## directly into argv. That example is NOT followed: the Basic credential is
## assembled and base64-encoded in memory and set as an Authorization header on
## the request object, so it never reaches a command line and never reaches a
## file.
##
## AUTH IS MUCH SIMPLER THAN THE GOOGLE FAMILY'S, deliberately noted so nobody
## reintroduces machinery that is not needed. Atlassian Cloud REST uses HTTP
## Basic with `<email>:<api-token>`; there is no OAuth app, no consent URL, no
## refresh exchange, no access token, and no scopes. One token authenticates
## the whole Atlassian account, so the same value works for Jira on the same
## site -- see the include's own note on why the two key sets stay separate
## anyway.
##
## THE API'S STATUS CODE IS NOT THE ANSWER TO THE QUESTION THE CALLER ASKED.
## Same doctrine as every other op in this package. A failed call means the
## answer is UNKNOWN, never empty and never zero rows.
##
## Environment contract:
##   AGENTS_CONFLUENCE_SITE       required -- e.g. ndm.atlassian.net
##   AGENTS_CONFLUENCE_USER       required -- the Atlassian account email
##   AGENTS_CONFLUENCE_API_TOKEN  required
##   AGENTS_CONFLUENCE_OP         required -- whoami|page-read|page-search|comment-read
##   AGENTS_CONFLUENCE_PAGE_ID    page-read, comment-read
##   AGENTS_CONFLUENCE_CQL        page-search
##   AGENTS_CONFLUENCE_LIMIT      page-search, optional (default 25)
##   AGENTS_CONFLUENCE_FORMAT     page-read, optional -- storage (default) or atlas_doc_format
##
## Exit statuses, deliberately distinct so a caller can tell outcomes apart:
##   0  the question was answered (possibly with a real, empty answer)
##   1  usage/contract error -- nothing was attempted
##   3  the call failed; the answer is UNKNOWN
##   4  the credential was rejected (401/403) and a human must check it
##

import base64
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

TIMEOUT = 120

## storage is the DEFAULT and the reason is round-trip symmetry, the same
## property that decided TSV on the Google side. Confluence can return a page
## body several ways, and they are not equivalent:
##  - storage           XHTML-ish Confluence storage format. The only form that
##                      can be written BACK through the same API unchanged, so
##                      read -> edit -> write is possible at all.
##  - atlas_doc_format  ADF, a JSON document tree. Also writable back, but it
##                      is JSON, and making a shell caller parse JSON to see a
##                      page is exactly the boundary mistake TSV avoided.
##  - view/export_view  rendered HTML. LOSSY -- it cannot be written back --
##                      and REST v2 does not offer it at all; it exists only on
##                      the older v1 content API.
## So: storage by default, atlas_doc_format on request, rendered HTML not
## offered rather than offered-and-lossy.
BODY_FORMATS = ("storage", "atlas_doc_format")


def fail(status, message):
    sys.stderr.write("⛔ ERROR: AgentsConfluenceApiCall.py: %s\n" % message)
    sys.exit(status)


def api_get(site, auth_header, path, question):
    """One authenticated GET against the Confluence Cloud REST API."""
    url = "https://%s%s" % (site, path)
    request = urllib.request.Request(url, method="GET")
    request.add_header("Authorization", auth_header)
    request.add_header("Accept", "application/json")
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            raw = response.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        if error.code in (401, 403):
            fail(4, "%s -- the site rejected the credential with HTTP %s. The "
                    "answer is UNKNOWN. A 401 here usually means the email or "
                    "API token is wrong or the token has been revoked; a 403 "
                    "usually means the account is authenticated but has no "
                    "permission on that content. Neither is fixed by "
                    "retrying. Atlassian's own response: %s"
                    % (question, error.code, detail.strip()))
        if error.code == 404:
            fail(3, "%s -- HTTP 404. This is NOT proof the content does not "
                    "exist: Confluence returns 404 both for genuinely missing "
                    "content and for content this account cannot see, and the "
                    "two are indistinguishable from here. Atlassian's own "
                    "response: %s" % (question, detail.strip()))
        fail(3, "%s -- the call failed with HTTP %s, so the answer is UNKNOWN, "
                "not empty. Atlassian's own response: %s"
                % (question, error.code, detail.strip()))
    except urllib.error.URLError as error:
        fail(3, "%s -- the call could not be performed (%s), so the answer is "
                "UNKNOWN, not empty." % (question, error.reason))
    if not raw.strip():
        fail(3, "%s -- the response body was empty, which is not a valid "
                "answer to this question; treat it as UNKNOWN." % question)
    try:
        return json.loads(raw)
    except ValueError as error:
        fail(3, "%s -- the response was not valid JSON (%s), so the answer is "
                "UNKNOWN." % (question, error))


def tsv_escape(value):
    """Identical rule to the Google family's, deliberately.

    A page title legitimately contains a tab or a newline far more often than a
    spreadsheet cell does, and emitted raw it would break the row structure the
    same way. Backslash first so the escape character round-trips.
    """
    if value is None:
        return ""
    text = value if isinstance(value, str) else str(value)
    return (text.replace("\\", "\\\\")
                .replace("\t", "\\t")
                .replace("\r", "\\r")
                .replace("\n", "\\n"))


def emit_tsv_row(cells):
    sys.stdout.write("\t".join(tsv_escape(cell) for cell in cells) + "\n")


def op_whoami(site, auth_header, _args):
    """Which Atlassian account does this member's credential resolve to?

    Same rationale as the Google and Trello whoami ops: the credential IS an
    identity, and one filed against the wrong account leaves the member acting
    as somebody else with no error to notice it by. Cheap, and the first thing
    to run after a token is filed.
    """
    payload = api_get(site, auth_header, "/wiki/rest/api/user/current",
                      "could not determine which Atlassian account this "
                      "credential belongs to")
    if not payload.get("accountId"):
        fail(3, "the current-user call returned no accountId, so the acting "
                "identity is UNKNOWN. This is a POSITIVE test on what is "
                "present: an empty user is not evidence of an anonymous "
                "identity, it is evidence the question was not answered.")
    sys.stdout.write("CONFLUENCE_ACCOUNT_ID=%s\n" % payload.get("accountId", ""))
    sys.stdout.write("CONFLUENCE_ACCOUNT_EMAIL=%s\n" % payload.get("email", ""))
    sys.stdout.write("CONFLUENCE_ACCOUNT_NAME=%s\n"
                     % payload.get("publicName") or payload.get("displayName", ""))


def op_page_read(site, auth_header, args):
    """One page's body, plus its identifying metadata on stderr.

    THE BODY GOES TO STDOUT AND THE METADATA TO STDERR, deliberately: the body
    is this op's product, so `page-read > file` yields the page and nothing
    else. Title, version and space are diagnostics, and a caller that needs the
    version for a later write should re-read it at write time rather than carry
    a stale one across a gap in which somebody else may have edited the page.
    """
    page_id = args.get("page_id")
    if not page_id:
        fail(1, "page-read requires a page id")
    body_format = args.get("format") or "storage"
    if body_format not in BODY_FORMATS:
        fail(1, "unknown body format: %s -- supported formats are %s. Rendered "
                "HTML (view/export_view) is deliberately not offered: it is "
                "lossy, cannot be written back, and REST v2 does not provide "
                "it at all." % (body_format, ", ".join(BODY_FORMATS)))
    payload = api_get(
        site, auth_header,
        "/wiki/api/v2/pages/%s?%s" % (
            urllib.parse.quote(str(page_id), safe=""),
            urllib.parse.urlencode({"body-format": body_format}),
        ),
        "could not read page %s" % page_id,
    )
    body = (payload.get("body") or {}).get(body_format) or {}
    if "value" not in body:
        fail(3, "the page returned no %s body, so its content is UNKNOWN "
                "rather than empty. This is a POSITIVE test on what is "
                "present." % body_format)
    version = (payload.get("version") or {}).get("number", "")
    sys.stderr.write("# page %s: title=%s version=%s spaceId=%s format=%s\n"
                     % (page_id, payload.get("title", ""), version,
                        payload.get("spaceId", ""), body_format))
    sys.stdout.write(body.get("value") or "")


def op_page_search(site, auth_header, args):
    """CQL search -- the discovery entry point, since page ops need a page id.

    CQL IS PASSED THROUGH AS GIVEN. Unlike Drive's `q`, which this package
    wraps because a bare term there is a syntax error, CQL is the documented
    query surface a caller is expected to write, and there is no safe general
    wrapping of it: `text ~ "..."`, `title ~ "..."`, `space = X` and
    `lastmodified >= ...` are all ordinary and mean different things. A caller
    who wants a plain-text search writes `text ~ "term"`.
    """
    cql = args.get("cql")
    if not cql:
        fail(1, "page-search requires a CQL query")
    raw_limit = args.get("limit") or ""
    if raw_limit:
        if not raw_limit.isdigit() or int(raw_limit) < 1:
            fail(1, "limit must be a positive whole number, got: %s" % raw_limit)
        limit = int(raw_limit)
    else:
        limit = 25
    payload = api_get(
        site, auth_header,
        "/wiki/rest/api/search?%s" % urllib.parse.urlencode({
            "cql": cql,
            "limit": limit,
        }),
        "could not run the CQL search",
    )
    results = payload.get("results")
    if results is None:
        fail(3, "the search returned no results field, so the result set is "
                "UNKNOWN rather than empty.")
    emit_tsv_row(["CONTENT_ID", "TYPE", "TITLE", "LAST_MODIFIED", "URL"])
    for entry in results:
        content = entry.get("content") or {}
        emit_tsv_row([
            content.get("id", ""),
            content.get("type", entry.get("entityType", "")),
            entry.get("title", content.get("title", "")),
            entry.get("lastModified", ""),
            entry.get("url", ""),
        ])


def op_comment_read(site, auth_header, args):
    """Footer comments on one page, as TSV."""
    page_id = args.get("page_id")
    if not page_id:
        fail(1, "comment-read requires a page id")
    payload = api_get(
        site, auth_header,
        "/wiki/api/v2/pages/%s/footer-comments?%s" % (
            urllib.parse.quote(str(page_id), safe=""),
            urllib.parse.urlencode({"body-format": "storage", "limit": 100}),
        ),
        "could not read comments on page %s" % page_id,
    )
    results = payload.get("results")
    if results is None:
        fail(3, "the comments call returned no results field, so the comment "
                "list is UNKNOWN rather than empty.")
    emit_tsv_row(["COMMENT_ID", "VERSION_AUTHOR_ID", "CREATED", "BODY"])
    for entry in results:
        version = entry.get("version") or {}
        body = (entry.get("body") or {}).get("storage") or {}
        emit_tsv_row([
            entry.get("id", ""),
            version.get("authorId", ""),
            version.get("createdAt", ""),
            body.get("value", ""),
        ])


OPERATIONS = {
    "whoami": op_whoami,
    "page-read": op_page_read,
    "page-search": op_page_search,
    "comment-read": op_comment_read,
}


def main():
    site = os.environ.get("AGENTS_CONFLUENCE_SITE", "").strip()
    user = os.environ.get("AGENTS_CONFLUENCE_USER", "").strip()
    token = os.environ.get("AGENTS_CONFLUENCE_API_TOKEN", "").strip()
    op_name = os.environ.get("AGENTS_CONFLUENCE_OP", "").strip()

    if not site or not user or not token:
        fail(1, "CONFLUENCE_SITE/CONFLUENCE_USER/CONFLUENCE_API_TOKEN were not "
                "supplied in the environment. Credentials are passed through "
                "the environment and never through argv; nothing was "
                "attempted.")
    if not op_name:
        fail(1, "AGENTS_CONFLUENCE_OP was not supplied in the environment")

    operation = OPERATIONS.get(op_name)
    if operation is None:
        fail(1, "unknown op: %s -- known ops are %s"
                % (op_name, ", ".join(sorted(OPERATIONS))))

    ## A scheme or path accidentally left on the site value would silently
    ## produce a wrong URL rather than an obvious error, so it is refused here.
    if "/" in site or ":" in site:
        fail(1, "CONFLUENCE_SITE must be a bare host such as "
                "example.atlassian.net -- no scheme, no path, no port. Got: %s"
                % site)

    ## THE CREDENTIAL IS ASSEMBLED HERE AND NOWHERE ELSE, and specifically NOT
    ## via curl -u, which Atlassian's own documentation shows and which would
    ## publish the token to argv.
    auth_header = "Basic " + base64.b64encode(
        ("%s:%s" % (user, token)).encode("utf-8")).decode("ascii")

    args = {
        "page_id": os.environ.get("AGENTS_CONFLUENCE_PAGE_ID", "").strip(),
        "cql": os.environ.get("AGENTS_CONFLUENCE_CQL", "").strip(),
        "limit": os.environ.get("AGENTS_CONFLUENCE_LIMIT", "").strip(),
        "format": os.environ.get("AGENTS_CONFLUENCE_FORMAT", "").strip(),
    }
    operation(site, auth_header, args)


if __name__ == "__main__":
    main()
