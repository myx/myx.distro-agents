#!/usr/bin/env python3
#
# AgentsConfluencePageCheck.py -- the mechanical page rules of magic-librarian's documentation
# convention, over the bodies of a checked set. It reads one stream on stdin, built by
# AgentsTools.ConfluencePageCheck.include:
#
#   <title> TAB <version>                         zero or more lines: the current version of every
#                                                 title the checked set's spaces hold, which R9
#                                                 compares a link's pin against
#   U+001E <page id> TAB <read rc> TAB <header>    one record per page, then a newline and the body.
#   <body>                                        U+001E is a byte an XML document cannot carry.
#
# Output is one row per failing page and rule: "<page id> TAB <rule> TAB <finding>". Python, not
# awk, because a link's attributes and the ordered header fields are captured groups, and the
# fleet's awk has no match(s, re, arr).
#
# The rules are the mechanical ones of section 3 of the documentation convention: R1, R2, R3, R4,
# R5, R8's uniqueness half, R9, R10, R11's mechanical half and R13. R6, R7, R12 and R14 need the
# page inventory or a live read. R15 is decided only once this check is wired to the render.
import html, re, sys

RS = "\x1e"
fieldLabels = ["status", "type", "owner", "approver", "last reviewed", "jira"]
legendStatus = ["DRAFT", "IN REVIEW", "WAITING FOR DECISION", "APPROVED", "LIVING",
                "KNOWN WRONG / REJECTED", "ARCHIVED"]
logHeadings = ["change log", "revision log", "\u0436\u0443\u0440\u043d\u0430\u043b \u043f\u0440\u0430\u0432\u043e\u043a"]


def blocksOf(bodyText):
    """One string per paragraph, heading, list item, table cell and preformatted block. A storage
    body carries no line of its own, so a line of the convention is one of these."""
    pieces = re.split(r"(?<=</p>)|(?<=</h[1-6]>)|(?<=</li>)|(?<=</td>)|(?<=</th>)|(?<=</pre>)|(?<=</blockquote>)", bodyText)
    return [" ".join(html.unescape(re.sub(r"<[^>]+>", "", onePiece)).split()) for onePiece in pieces
            if re.sub(r"<[^>]+>", "", onePiece).strip()]


def titleOf(pageHeader):
    titleFound = re.search(r"title=(.*?) version=\d+", pageHeader)
    return titleFound.group(1) if titleFound else ""


def versionOf(pageHeader):
    versionFound = re.search(r" version=(\d+)", pageHeader)
    return versionFound.group(1) if versionFound else ""


streamText = sys.stdin.read()
firstRecord = streamText.find(RS)
versionByTitle = {}
for versionLine in (streamText if firstRecord < 0 else streamText[:firstRecord]).split("\n"):
    if "\t" in versionLine:
        versionTitle, versionNumber = versionLine.rsplit("\t", 1)
        versionByTitle[versionTitle] = versionNumber

pages = []
if firstRecord >= 0:
    for oneRecord in streamText[firstRecord + 1:].split(RS):
        headerLine, _, pageBody = oneRecord.partition("\n")
        headerParts = headerLine.split("\t", 2)
        if len(headerParts) < 3:
            sys.exit("page-check: a record's header line is not <page id> TAB <read rc> TAB <header>")
        pages.append({"id": headerParts[0], "readRc": headerParts[1], "header": headerParts[2], "body": pageBody})

rows = []
for page in pages:
    if page["readRc"] != "0":
        rows.append((page["id"], "read", "the page was not read: %s" % " ".join(page["header"].split())))
        continue
    pageTitle = titleOf(page["header"])
    pageVersion = versionOf(page["header"])
    pageBody = page["body"]
    if not pageTitle or not pageVersion:
        rows.append((page["id"], "read", "the read answered without a title and a version: %s" % " ".join(page["header"].split())))
        continue
    if not pageBody.strip():
        rows.append((page["id"], "read", "the read answered with no body"))
        continue

    blockList = blocksOf(pageBody)
    headText = " ".join(blockList[:10])
    plainText = " ".join(html.unescape(re.sub(r"<[^>]+>", " ", pageBody)).split())

    # R1 -- the page names its one source, in its first ten lines.
    if not [oneBlock for oneBlock in blockList[:10] if re.match(r"Source: \S", oneBlock)]:
        rows.append((page["id"], "R1", 'the page names no source in its first ten lines: expected "Source: <repo path, tool, routine or item>"'))

    # R2 -- the page states its review state in its header block.
    reviewFound = re.search(r"AI-generated \u2014 (reviewed by (.+?)|not yet reviewed)", headText)
    if not reviewFound:
        rows.append((page["id"], "R2", 'the page states no review state: expected "AI-generated \u2014 reviewed by <name>" or "AI-generated \u2014 not yet reviewed"'))
    elif reviewFound.group(2) and re.search(r"magic-", reviewFound.group(2)):
        rows.append((page["id"], "R2", "the reviewer is named as a member, and a reviewer is a person: %s" % reviewFound.group(2)))

    # R3 -- six labelled header fields, in that order, none empty, the status one of the legend's seven.
    fieldValues = {}
    fieldOrder = []
    for oneBlock in blockList[:10]:
        for fieldLabel in fieldLabels:
            fieldMatch = re.match(r"%s:\s*(\S.*)$" % re.escape(fieldLabel), oneBlock, re.I)
            if fieldMatch:
                fieldOrder.append(fieldLabel)
                fieldValues[fieldLabel] = fieldMatch.group(1).strip()
                break
    fieldFaults = []
    if fieldOrder != fieldLabels:
        fieldFaults.append("the fields in their order are %s" % (", ".join(fieldOrder) if fieldOrder else "none"))
    if fieldValues.get("status", "").upper() not in legendStatus:
        fieldFaults.append("the status is %s" % (fieldValues.get("status") or "empty"))
    emptyFields = [fieldLabel for fieldLabel in fieldLabels if fieldLabel in fieldValues and not fieldValues[fieldLabel]]
    if emptyFields:
        fieldFaults.append("these fields are empty: %s" % ", ".join(emptyFields))
    if fieldFaults:
        rows.append((page["id"], "R3", "the header block is not the six fields in order: %s" % "; ".join(fieldFaults)))

    # R4 -- a TL;DR of three to five bullets before the first section heading.
    firstHeading = pageBody.find("<h2")
    dashPart = pageBody if firstHeading < 0 else pageBody[:firstHeading]
    dashCount = len(re.findall(r"<li\b", dashPart))
    if firstHeading < 0 or dashCount < 3 or dashCount > 5:
        rows.append((page["id"], "R4", "the TL;DR before the first section heading holds %d bullet(s), and three to five are required" % dashCount))

    # R5 -- a change log ends the page, and its last line names the page's current version.
    headingList = [" ".join(html.unescape(re.sub(r"<[^>]+>", "", matchFound.group(1))).split())
                   for matchFound in re.finditer(r"<h2[^>]*>(.*?)</h2>", pageBody, re.S)]
    lastHeading = headingList[-1] if headingList else ""
    lastHeadingName = re.sub(r"^\d+[.)]\s*", "", lastHeading).strip().lower()
    if lastHeadingName not in logHeadings:
        rows.append((page["id"], "R5", 'the section that ends the page is "%s", not a change log' % (lastHeading or "none")))
    else:
        logLine = blockList[-1] if blockList else ""
        logVersions = [oneField.strip() for oneField in logLine.split(",") if re.match(r"^v?\d+(\.\d+)*$", oneField.strip())]
        currentVersions = ["v" + pageVersion, pageVersion] + ([fieldValues["version"]] if fieldValues.get("version") else [])
        if not logVersions:
            rows.append((page["id"], "R5", "the change log's last line names no version: %s" % logLine))
        elif not [oneVersion for oneVersion in logVersions if oneVersion in currentVersions]:
            rows.append((page["id"], "R5", "the change log's last line names %s, and the page stands at version %s" % (", ".join(logVersions), pageVersion)))

    # R9 -- no internal link pins a version older than its target's current version.
    staleLinks = []
    unreadTitles = []
    for linkMatch in re.finditer(r"<ri:page\b[^>]*>", pageBody):
        linkTitle = re.search(r'ri:content-title="([^"]*)"', linkMatch.group(0))
        linkPin = re.search(r'ri:version-at-save="(\d+)"', linkMatch.group(0))
        if not linkTitle or not linkPin:
            continue
        linkName = html.unescape(linkTitle.group(1))
        if linkName not in versionByTitle:
            unreadTitles.append(linkName)
        elif int(linkPin.group(1)) < int(versionByTitle[linkName]):
            staleLinks.append("%s v%s of v%s" % (linkName, linkPin.group(1), versionByTitle[linkName]))
    if staleLinks:
        morePart = (" and %d more" % (len(staleLinks) - 6)) if len(staleLinks) > 6 else ""
        rows.append((page["id"], "R9", "%d internal link(s) pin a version older than its target's: %s%s" % (len(staleLinks), "; ".join(staleLinks[:6]), morePart)))
    if unreadTitles:
        print("# page-check: %s links to %s, which the checked set does not hold, so those pins were not compared" % (page["id"], ", ".join(sorted(set(unreadTitles)))), file=sys.stderr)

    # R10 -- no internal vocabulary on a published page.
    vocabFaults = []
    for vocabName, vocabPattern in (("agent name", r"magic-[a-z]+"), ("skillset filename", r"armed\.md"), ("board item id", r"board://"), ("Slack identifier", r"[A-Z0-9]{9,13}:\d{10}\.\d{6}")):
        vocabHits = re.findall(vocabPattern, plainText)
        if vocabHits:
            vocabFaults.append("%d %s (%s)" % (len(vocabHits), vocabName, ", ".join(sorted(set(vocabHits))[:3])))
    if vocabFaults:
        rows.append((page["id"], "R10", "internal vocabulary: %s" % "; ".join(vocabFaults)))

    # R11 -- its mechanical half: no credential value. The reviewer decides the rest.
    secretFaults = []
    for secretName, secretPattern in (("a bearer token", r"Bearer\s+[A-Za-z0-9._\-]{20,}"), ("a private key", r"-----BEGIN [A-Z ]*PRIVATE KEY-----"), ("a password-shaped assignment", r"(?i)\b(?:password|passwd|secret|api[_-]?token)\s*[:=]\s*\S{8,}")):
        if re.search(secretPattern, plainText):
            secretFaults.append(secretName)
    if secretFaults:
        rows.append((page["id"], "R11", "a secret-shaped string: %s" % ", ".join(secretFaults)))

    # R13 -- a frozen record carries no approval block, names its successor, and has not changed
    # since its freeze. A page is a frozen record by its ARCHIVED status, by a claim in its own
    # opening lines, or by its own declaration "frozen <date> at version <n>". An archive written
    # before the convention is the second shape: its first line calls itself archived, and it
    # carries no status field at all.
    recordClaim = re.search(r"(?i)\barchived\b|\bkept word for word\b|\bfrozen\b", " ".join(blockList[:3]))
    freezeFound = re.search(r"(?i)frozen \d{4}-\d{2}-\d{2} at version (\d+)", plainText)
    if fieldValues.get("status", "").upper() == "ARCHIVED" or recordClaim or freezeFound:
        archiveFaults = []
        if re.search(r"(?i)\bConfirmed by\b|\bConfirmation record\b", plainText):
            archiveFaults.append("it carries an approval block, and an archive is not confirmed")
        if not re.search(r"Superseded by", plainText):
            archiveFaults.append("it names no successor: expected Superseded by <link>")
        if not freezeFound:
            archiveFaults.append("it declares no freeze: expected frozen <date> at version <n>")
        elif freezeFound.group(1) != pageVersion:
            archiveFaults.append("it was frozen at version %s and stands at version %s" % (freezeFound.group(1), pageVersion))
        if archiveFaults:
            rows.append((page["id"], "R13", "; ".join(archiveFaults)))

# R8 -- no two pages of one space share a title. Its half over the checked set; the title prefix
# belongs to the page inventory.
titleCount = {}
for page in pages:
    if page["readRc"] == "0":
        pageTitle = titleOf(page["header"])
        if pageTitle:
            titleCount[pageTitle] = titleCount.get(pageTitle, 0) + 1
for page in pages:
    pageTitle = titleOf(page["header"])
    if page["readRc"] == "0" and pageTitle and titleCount[pageTitle] > 1:
        rows.append((page["id"], "R8", 'the title "%s" is shared by %d pages of the checked set' % (pageTitle, titleCount[pageTitle])))

for rowId, rowRule, rowText in rows:
    print("%s\t%s\t%s" % (rowId, rowRule, rowText))
