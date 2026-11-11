##
## AgentsManagerScreen.Contacts.py -- the root Contacts: the people and organisations of the team data, who each is and where each stands.
## A part of the manager screen (LocalManagerScreen.py of `myx.distro-.local`): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself.
##

## ---- the contacts of the team data ----

## What `--manager-team-data-contacts` printed: a row per organisation (`organisation <id> <name> <domains>`) and per person
## (`contact <id> <name> <organisation> <e-mails> <team tier> <project and product tiers>`), `-` where a record gives nothing.
def parseContactRows(text):
    rows = []
    for line in text.splitlines():
        fields = line.split("\t")
        if fields[0] == "organisation" and len(fields) >= 4:
            row = newRow(fields[1], "%s  (organisation)  %s" % (fields[2] or fields[1], fields[3]), "organisation", False, fields)
            row["organisation"] = {"id": fields[1], "name": fields[2] or fields[1], "domains": fields[3] or "-"}
            rows.append(row)
        elif fields[0] == "contact" and len(fields) >= 7:
            person = {"id": fields[1], "name": fields[2], "org": fields[3], "email": fields[4], "tier": fields[5], "scopes": fields[6]}
            label = "%s  %s%s" % (person["name"], person["tier"], "" if person["scopes"] == "-" else "  " + person["scopes"])
            row = newRow(fields[1], label, "contact", False, fields)
            row["contact"] = person
            rows.append(row)
    return rows


## The levels of the `contacts` read: registered with the list, so the list asks the read's form rather than naming this parser.
def contactsLevels(readKey, level, text):
    return {level: parseContactRows(text)}


ROW_FORMS["contacts"] = {"parse": contactsLevels}


## The table of Contacts: each person by name, organisation, e-mails, the tier for the whole team, and the project and product
## tiers; then the organisations with their domains. Plainly where the team data holds none.
def contactsSummary(state, path, row, form):
    rows = state.rows.get(levelKey(path))
    if rows is None:
        return None
    people = [held["contact"] for held in rows if held.get("contact")]
    organisations = [held["organisation"] for held in rows if held.get("organisation")]
    if not people and not organisations:
        return [looked("No contact is recorded in this team data.", BOLD)]
    lines = []
    if people:
        lines += tableSummaryLines(state, ("NAME", "ORGANISATION", "E-MAIL", "TEAM TIER", "PROJECT / PRODUCT TIERS"),
                                   [[one["name"], one["org"], one["email"], one["tier"], one["scopes"]] for one in people],
                                   ("key", "text", "text", "enum", "text"))
    if organisations:
        lines += [""] + tableSummaryLines(state, ("ORGANISATION", "ID", "DOMAINS"),
                                          [[one["name"], one["id"], one["domains"]] for one in organisations], ("key", "text", "text"))
    return lines


## ---- the plugin: `Contacts` ----

CONTACTS_READS = {
    ## Every organisation and person of the team data, one read.
    "list:contacts": {"operation": ["--manager-team-data-contacts"], "rows": "contacts"},
    ## One record, whole, read once it is selected.
    "view:contacts:contact": {"operation": ["--manager-team-data-contacts", "{id}"], "once": True},
    "view:contacts:organisation": {"operation": ["--manager-team-data-contacts", "{id}"], "once": True},
}

registerPlugin({
    "name": "contacts",
    "apps": ("agents",),
    "mount": "magic-team",
    "root": {"id": "contacts", "label": "Contacts", "go": "Con~t~acts", "group": "team",
             "when": {"shown": "teamDataHere", "says": "no team data is configured for this workspace"}},
    "summaries": {"contacts": {"lines": "contactsSummary"}},
    "reads": CONTACTS_READS,
    "integrates": {
        "markdown": {"on": ("contacts:contact", "contacts:organisation")},
    },
})
