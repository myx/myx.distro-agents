#!/usr/bin/env python3
##
## AgentsJiraApiCall.py -- the Jira Cloud API worker behind the
## --member-comms-jira-* operations. Read side only. Endpoint choices, the
## false-empty search trap and the format decision are in this package's
## own MAGIC.md.
##
## Environment: AGENTS_JIRA_SITE, AGENTS_JIRA_USER, AGENTS_JIRA_API_TOKEN,
## AGENTS_JIRA_OP (whoami|issue-search|issue-read|comment-read),
## AGENTS_JIRA_ISSUE_KEY, AGENTS_JIRA_JQL, AGENTS_JIRA_LIMIT,
## AGENTS_JIRA_FORMAT (adf|rendered).
## Exit: 0 answered, 1 contract error, 3 answer UNKNOWN, 4 credential rejected.
##

import base64
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

CALL_TIMEOUT = 120

BODY_FORMATS = ("adf", "rendered")

## The fields issue-read asks for by name. An unrestricted read returns every
## custom field the site defines, which is a large payload nothing here uses.
ISSUE_FIELDS = ("summary,status,assignee,reporter,priority,issuetype,"
                "resolution,labels,created,updated,description")


def failWith(exitStatus, messageText):
    sys.stderr.write("⛔ ERROR: AgentsJiraApiCall.py: %s\n" % messageText)
    sys.exit(exitStatus)


def apiGet(siteHost, authHeader, pathText, questionText):
    """One authenticated GET against the Jira Cloud REST API."""
    requestObject = urllib.request.Request("https://%s%s" % (siteHost, pathText),
                                           method="GET")
    requestObject.add_header("Authorization", authHeader)
    requestObject.add_header("Accept", "application/json")
    try:
        with urllib.request.urlopen(requestObject, timeout=CALL_TIMEOUT) as responseObject:
            rawBody = responseObject.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as errorObject:
        detailText = errorObject.read().decode("utf-8", errors="replace")
        if errorObject.code in (401, 403):
            failWith(4, "%s -- the site rejected the credential with HTTP %s. The "
                        "answer is UNKNOWN. A 401 here usually means the email or "
                        "API token is wrong or the token has been revoked; a 403 "
                        "usually means the account is authenticated but has no "
                        "permission on that issue or project. Neither is fixed by "
                        "retrying. Atlassian's own response: %s"
                        % (questionText, errorObject.code, detailText.strip()))
        if errorObject.code == 404:
            failWith(3, "%s -- HTTP 404. This is NOT proof the issue does not "
                        "exist: Jira returns 404 both for a genuinely missing "
                        "issue and for one this account cannot see, and says so "
                        "itself in the response. Atlassian's own response: %s"
                        % (questionText, detailText.strip()))
        if errorObject.code == 410:
            failWith(3, "%s -- HTTP 410, which Atlassian returns for a REST "
                        "endpoint it has retired. The answer is UNKNOWN, and no "
                        "retry helps: the path this worker used has to be moved "
                        "to whatever the response names. Atlassian's own "
                        "response: %s" % (questionText, detailText.strip()))
        failWith(3, "%s -- the call failed with HTTP %s, so the answer is UNKNOWN, "
                    "not empty. Atlassian's own response: %s"
                    % (questionText, errorObject.code, detailText.strip()))
    except urllib.error.URLError as errorObject:
        failWith(3, "%s -- the call could not be performed (%s), so the answer is "
                    "UNKNOWN, not empty." % (questionText, errorObject.reason))
    if not rawBody.strip():
        failWith(3, "%s -- the response body was empty, which is not a valid "
                    "answer to this question; treat it as UNKNOWN." % questionText)
    try:
        return json.loads(rawBody)
    except ValueError as errorObject:
        failWith(3, "%s -- the response was not valid JSON (%s), so the answer is "
                    "UNKNOWN." % (questionText, errorObject))


def tsvEscape(cellValue):
    """Same rule as the Confluence and Google families': a summary or a comment
    body legitimately carries tabs and newlines, and emitted raw they would
    break the row structure. Backslash first so the escape round-trips."""
    if cellValue is None:
        return ""
    cellText = cellValue if isinstance(cellValue, str) else str(cellValue)
    return (cellText.replace("\\", "\\\\")
                    .replace("\t", "\\t")
                    .replace("\r", "\\r")
                    .replace("\n", "\\n"))


def emitTsvRow(cellList):
    sys.stdout.write("\t".join(tsvEscape(cellValue) for cellValue in cellList) + "\n")


def resolveFormat(argMap):
    formatName = argMap.get("format") or "adf"
    if formatName not in BODY_FORMATS:
        failWith(1, "unknown body format: %s -- supported formats are %s. adf is "
                    "the document Jira accepts back on a write; rendered is HTML "
                    "for a human reader and cannot be written back."
                    % (formatName, ", ".join(BODY_FORMATS)))
    return formatName


def opWhoami(siteHost, authHeader, _argMap):
    """Which Atlassian account does this member's credential resolve to?"""
    payload = apiGet(siteHost, authHeader, "/rest/api/3/myself",
                     "could not determine which Atlassian account this "
                     "credential belongs to")
    if not payload.get("accountId"):
        failWith(3, "the current-user call returned no accountId, so the acting "
                    "identity is UNKNOWN. This is a POSITIVE test on what is "
                    "present: an empty user is not evidence of an anonymous "
                    "identity, it is evidence the question was not answered.")
    sys.stdout.write("JIRA_ACCOUNT_ID=%s\n" % payload.get("accountId", ""))
    sys.stdout.write("JIRA_ACCOUNT_EMAIL=%s\n" % (payload.get("emailAddress") or ""))
    sys.stdout.write("JIRA_ACCOUNT_NAME=%s\n" % (payload.get("displayName") or ""))


def opIssueSearch(siteHost, authHeader, argMap):
    """JQL search -- the discovery entry point, since the issue ops need a key."""
    jqlText = argMap.get("jql")
    if not jqlText:
        failWith(1, "issue-search requires a JQL query")
    rawLimit = argMap.get("limit") or ""
    if rawLimit:
        if not rawLimit.isdigit() or int(rawLimit) < 1:
            failWith(1, "limit must be a positive whole number, got: %s" % rawLimit)
        pageLimit = int(rawLimit)
    else:
        pageLimit = 25
    payload = apiGet(
        siteHost, authHeader,
        "/rest/api/3/search/jql?%s" % urllib.parse.urlencode({
            "jql": jqlText,
            "maxResults": pageLimit,
            "fields": "summary,status,issuetype,assignee,updated",
        }),
        "could not run the JQL search",
    )
    issueList = payload.get("issues")
    if issueList is None:
        failWith(3, "the search returned no issues field, so the result set is "
                    "UNKNOWN rather than empty.")
    emitTsvRow(["ISSUE_KEY", "TYPE", "STATUS", "ASSIGNEE", "UPDATED", "SUMMARY"])
    for issueEntry in issueList:
        fieldMap = issueEntry.get("fields") or {}
        emitTsvRow([
            issueEntry.get("key", ""),
            (fieldMap.get("issuetype") or {}).get("name", ""),
            (fieldMap.get("status") or {}).get("name", ""),
            (fieldMap.get("assignee") or {}).get("displayName", ""),
            fieldMap.get("updated", ""),
            fieldMap.get("summary", ""),
        ])
    ## Jira answers a query naming a project that does not exist, and one that is
    ## not JQL at all, with HTTP 200 and no issues -- so an empty page is not
    ## evidence about the issues, only about this query.
    if not issueList:
        sys.stderr.write("# issue-search: the query ran and matched nothing. Jira "
                         "answers an unresolvable or malformed query with an empty "
                         "page rather than an error, so this does NOT establish "
                         "that no issue matches what you meant: re-check the "
                         "query itself. The JQL as sent: %s\n" % jqlText)
    ## /search/jql pages by token and reports no total, so the only truncation
    ## signal a caller gets is isLast.
    if payload.get("isLast") is False:
        sys.stderr.write("# issue-search: more issues match beyond this page -- "
                         "Jira reports isLast=false. This endpoint returns no "
                         "total, so how many more is unknown; raise --limit or "
                         "narrow the query.\n")


def opIssueRead(siteHost, authHeader, argMap):
    """One issue's description to stdout, its metadata to stderr.

    Same split as the Confluence family's page-read: the description is this
    op's product, so `issue-read > file` yields it and nothing else.
    """
    issueKey = argMap.get("issueKey")
    if not issueKey:
        failWith(1, "issue-read requires an issue key")
    formatName = resolveFormat(argMap)
    queryMap = {"fields": ISSUE_FIELDS}
    if formatName == "rendered":
        queryMap["expand"] = "renderedFields"
    payload = apiGet(
        siteHost, authHeader,
        "/rest/api/3/issue/%s?%s" % (
            urllib.parse.quote(str(issueKey), safe=""),
            urllib.parse.urlencode(queryMap),
        ),
        "could not read issue %s" % issueKey,
    )
    fieldMap = payload.get("fields")
    if fieldMap is None:
        failWith(3, "the issue returned no fields object, so its content is "
                    "UNKNOWN rather than empty. This is a POSITIVE test on what "
                    "is present.")
    if "description" not in fieldMap:
        failWith(3, "the issue carried no description field at all, so its "
                    "description is UNKNOWN rather than absent.")
    sys.stderr.write(
        "# issue %s: type=%s status=%s resolution=%s assignee=%s reporter=%s "
        "priority=%s created=%s updated=%s labels=%s format=%s\n"
        % (payload.get("key", issueKey),
           (fieldMap.get("issuetype") or {}).get("name", ""),
           (fieldMap.get("status") or {}).get("name", ""),
           (fieldMap.get("resolution") or {}).get("name", ""),
           (fieldMap.get("assignee") or {}).get("displayName", ""),
           (fieldMap.get("reporter") or {}).get("displayName", ""),
           (fieldMap.get("priority") or {}).get("name", ""),
           fieldMap.get("created", ""),
           fieldMap.get("updated", ""),
           ",".join(fieldMap.get("labels") or []),
           formatName))
    sys.stderr.write("# issue %s: summary=%s\n"
                     % (payload.get("key", issueKey), fieldMap.get("summary", "")))
    if formatName == "rendered":
        renderedMap = payload.get("renderedFields")
        if renderedMap is None or "description" not in renderedMap:
            failWith(3, "the issue was returned without a renderedFields "
                        "description, so the rendered body is UNKNOWN rather "
                        "than empty.")
        sys.stdout.write(renderedMap.get("description") or "")
        return
    descriptionValue = fieldMap.get("description")
    if descriptionValue is None:
        sys.stderr.write("# issue %s: this issue really has no description -- the "
                         "field was returned and its value is null, which is an "
                         "answer, not a failed read\n" % payload.get("key", issueKey))
        return
    sys.stdout.write(json.dumps(descriptionValue, ensure_ascii=False) + "\n")


def opCommentRead(siteHost, authHeader, argMap):
    """One issue's comments, as TSV with its own header row."""
    issueKey = argMap.get("issueKey")
    if not issueKey:
        failWith(1, "comment-read requires an issue key")
    formatName = resolveFormat(argMap)
    queryMap = {"maxResults": 100}
    if formatName == "rendered":
        queryMap["expand"] = "renderedBody"
    payload = apiGet(
        siteHost, authHeader,
        "/rest/api/3/issue/%s/comment?%s" % (
            urllib.parse.quote(str(issueKey), safe=""),
            urllib.parse.urlencode(queryMap),
        ),
        "could not read comments on issue %s" % issueKey,
    )
    commentList = payload.get("comments")
    if commentList is None:
        failWith(3, "the comments call returned no comments field, so the comment "
                    "list is UNKNOWN rather than empty.")
    emitTsvRow(["COMMENT_ID", "AUTHOR_ID", "AUTHOR_NAME", "CREATED", "UPDATED", "BODY"])
    for commentEntry in commentList:
        authorMap = commentEntry.get("author") or {}
        if formatName == "rendered":
            bodyCell = commentEntry.get("renderedBody") or ""
        else:
            bodyCell = json.dumps(commentEntry.get("body"), ensure_ascii=False)
        emitTsvRow([
            commentEntry.get("id", ""),
            authorMap.get("accountId", ""),
            authorMap.get("displayName", ""),
            commentEntry.get("created", ""),
            commentEntry.get("updated", ""),
            bodyCell,
        ])
    ## This endpoint does report a total, so truncation is stated exactly.
    totalCount = payload.get("total")
    if isinstance(totalCount, int) and totalCount > len(commentList):
        sys.stderr.write("# comment-read: issue %s has %s comments and this page "
                         "carries %s -- the rest were not read\n"
                         % (issueKey, totalCount, len(commentList)))


OPERATIONS = {
    "whoami": opWhoami,
    "issue-search": opIssueSearch,
    "issue-read": opIssueRead,
    "comment-read": opCommentRead,
}


def main():
    siteHost = os.environ.get("AGENTS_JIRA_SITE", "").strip()
    userEmail = os.environ.get("AGENTS_JIRA_USER", "").strip()
    apiToken = os.environ.get("AGENTS_JIRA_API_TOKEN", "").strip()
    opName = os.environ.get("AGENTS_JIRA_OP", "").strip()

    if not siteHost or not userEmail or not apiToken:
        failWith(1, "JIRA_SITE/JIRA_USER/JIRA_API_TOKEN were not supplied in the "
                    "environment. Credentials are passed through the environment "
                    "and never through argv; nothing was attempted.")
    if not opName:
        failWith(1, "AGENTS_JIRA_OP was not supplied in the environment")

    operationFunction = OPERATIONS.get(opName)
    if operationFunction is None:
        failWith(1, "unknown op: %s -- known ops are %s"
                    % (opName, ", ".join(sorted(OPERATIONS))))

    ## A scheme or path left on the site value would build a wrong URL rather
    ## than raise an obvious error.
    if "/" in siteHost or ":" in siteHost:
        failWith(1, "JIRA_SITE must be a bare host such as example.atlassian.net "
                    "-- no scheme, no path, no port. Got: %s" % siteHost)

    ## Assembled here and nowhere else, and specifically not via curl -u, which
    ## Atlassian's own documentation shows and which would publish the token.
    authHeader = "Basic " + base64.b64encode(
        ("%s:%s" % (userEmail, apiToken)).encode("utf-8")).decode("ascii")

    operationFunction(siteHost, authHeader, {
        "issueKey": os.environ.get("AGENTS_JIRA_ISSUE_KEY", "").strip(),
        "jql": os.environ.get("AGENTS_JIRA_JQL", "").strip(),
        "limit": os.environ.get("AGENTS_JIRA_LIMIT", "").strip(),
        "format": os.environ.get("AGENTS_JIRA_FORMAT", "").strip(),
    })


if __name__ == "__main__":
    main()
