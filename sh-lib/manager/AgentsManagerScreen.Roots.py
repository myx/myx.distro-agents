##
## AgentsManagerScreen.Roots.py -- the roots of the list and what each asks of the tooling: SECTIONS, FIXED_ROWS, SUMMARIES, READS, CALLS, STARTS, DASHBOARD, PLACES.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

## The root of the list, in its order: the id of each section and what it shows as.
SECTIONS = (
    ("dashboard", "Dashboard (Monitor)"),
    ("sessions", "Sessions (Activity)"),
    ("pending", "Pending Questions"),
    ("team", "Team Members"),
    ("teamdata", "Team Data"),
    ("places", "Locations (Places)"),
    ("consoles", "Consoles"),
    ("settings", "Settings"),
    ("configuration", "Configuration"),
    ("manuals", "Manuals (Help)"),
)
## The root the selection is on when the screen starts: the manuals, whose help is where a user starts.
START_ROOT = "manuals"
## The groups of the roots, in their order, a spacer between two (spacersAt): the work of
## the team, then where it runs and what is started there, then how it is set up, then the
## manuals.
SECTION_GROUPS = (("dashboard", "sessions", "pending", "team", "teamdata"), ("places", "consoles"),
                  ("settings", "configuration"), ("manuals",))
## The console user's own setting of .local, beside MDLT_CONSOLE_HISTORY and no setting of
## the agents, that turns every spacer of the list off where it reads `disable`; the
## spacers are there where it names nothing else. Read from the environment of the start,
## where the start of the screen (`--manager`) puts what the user saved.
SPACERS_VARIABLE = "MDLT_CONSOLE_SPACERS"
## The roots that stand in the list only where what they show is there: by the id of the
## root, the function that says so from what was read ("shown"), and why its item of the
## `Go` menu does nothing where it is not ("says"). Where one is not there the roots after
## it take its number (goKeys), and it has none.
SECTIONS_WHEN = {
    "teamdata": {"shown": "teamDataHere", "says": "no team data is configured for this workspace"},
}
## The roots that stand in the list now, in its order: those SECTIONS_WHEN does not name,
## until a turn of the screen has said which of the others are there too (noteRoots).
SECTIONS_NOW = [sectionId for sectionId, sectionLabel in SECTIONS if sectionId not in SECTIONS_WHEN]
## What the root `Team Data` shows, from two reads that give it: the blocks of the
## dashboard it holds as rows of its own, read with the dashboard ("blocks", in the level
## "level"); the block and the figure that say that its team data is there ("present",
## with that value), and the figure of its root; the prefix of the figures that count the
## items of the board by state ("board"); and the lines of the digest of the settings it
## shows, each by its subject, its group (None: any) and its key: the mode of the
## workspace, whether it is a full team rig, the remote and the branch of the team data.
## "teamRig": the mode in which the team data is maintained here, the one mode an operation
## that needs a rig is offered in (CLEANUPS). "data", "git", "loop": the blocks of the team
## data, of its git state, and of the main loop; "blocks", those the dashboard's own read
## gives the root too, so that it knows from the start whether the team data is there.
TEAM_DATA = {
    "level": "teamdata",
    "blocks": ("team-data", "loop"),
    "data": "team-data", "git": "team-data-git", "loop": "loop",
    "present": ("team-data", "present", "yes"),
    "root": "root",
    "board": "board-",
    "mode": ("workspace", "mode", "MDAT_WORKSPACE_MODE"),
    "full": ("workspace", "mode", "full-team-rig"),
    "remote": ("scopes", None, "TEAM_DATA_GIT_REMOTE"),
    "branch": ("scopes", None, "TEAM_DATA_BRANCH"),
    "teamRig": "team-rig",
}
## The operations of the tooling that `Team Data` holds under `Operations`, its cleanups and
## its sync, in their order, each by its id: "label", what it shows as; "operation", the
## operation exactly as it is called, with its words, never another made for the screen;
## "does", what it does, as its help says it; "needs": "rig" where it is offered only in the
## mode of TEAM_DATA "teamRig", "remote" only where a git remote of the team data is set
## (TEAM_DATA "remote"), None where it runs anywhere. Each runs in the big output dialog (DIALOGS
## "output"), which follows what it writes. The trash of the board and of an inbox name
## an item, and the sweeps read and store a member's state: no such one is here.
CLEANUPS = (
    ("purge", {"label": "Purge The Cleanup Folder", "operation": ["--owner-cleanup-purge"],
               "does": "Empties the cleanup folder of this workspace, .local/.cleanup, where the tooling puts what is to be removed; the folder itself stays. It takes no arguments.",
               "needs": None}),
    ("final-gc", {"label": "Delete Expired Team Data", "operation": ["--intern-team-data-final-gc-deletion", "magic-coordinator"],
                  "does": "Deletes from the team data what its retention has passed, the handled items of the inboxes, the processed items of the board and the trash, warnings and reflections after one day and every other item after seven, and commits the deletions where the team data is a repository. It is what closing the heartbeat runs, as magic-coordinator.",
                  "needs": "rig"}),
    ("sync", {"label": "Sync The Team Data", "operation": ["--magic-team-data-commit-pending", "magic-coordinator"],
              "does": "Commits everything pending under the team data in one commit, then syncs it with its remote by myx.common git/cloneSync: the remote's commits are pulled and merged in, what is ahead is pushed, and the remote is read back. It takes no lock: run it only while no routine holds the advance or the heartbeat lock.",
              "needs": "remote"}),
)
## The stores of the team data that `Team Data` holds as folders, to browse their items, in
## their order: the id of each, as `--manager-team-data-read` takes it, and what it shows
## as. Inside a store its folders, the board's states or the audit's months, each a folder
## of its items, and the items that lie in the store itself; a selected item shows its
## text, read only.
TEAM_DATA_STORES = (("board", "Board"), ("audit", "Audit"), ("vault", "Vault"))
## What a member holds as a folder of `Team Members`, in its order: the id of each folder,
## what it shows as, and the kind of its row.
## The kind of the row of the team itself among the members: no member, and no folder.
MEMBER_TEAM_KIND = "team"
MEMBER_FOLDERS = (("permissions", "Permissions", "grants"), ("files", "Skillset Files", "files"),
                  ("sessions", "Sessions", "member-sessions"), ("help", "Member Help", "member-help"))
ROOT_TITLE = "/"
ROW_UP = ".."
## The scope a credential of a subject of the digest is read from, for the form of the credential: the scopes are their
## own (None: the group of the line is the scope), and the credentials of the CLIs are settings of the team.
CREDENTIAL_SCOPE = {"scopes": None, "cli": "magic-team"}
## The rows a level always holds, ahead of the rows its operation gives:
## id, what it shows as, kind, whether Enter dives into it.
FIXED_ROWS = {
    "sessions": (("launch", "Launch (Start)", "launch", True),),
    "sessions/launch": (("free", "Free prompt", "free", False),),
    "configuration": (("checker", "Config Checker", "checker", True), ("keys", "Server Keys", "keys", True)),
    "manuals": (("user", "User Manuals", "manuals", True), ("commands", "Tooling Commands", "commands", True),
                ("maintainer", "Maintainer Manuals", "manuals", True)),
    "teamdata": (("operations", "Operations", "operations", True),) + tuple((storeId, label, "store", True) for storeId, label in TEAM_DATA_STORES),
    "team/*": tuple((folderId, label, kind, True) for folderId, label, kind in MEMBER_FOLDERS),
    "teamdata/operations": tuple((cleanupId, cleanup["label"], "operation", False) for cleanupId, cleanup in CLEANUPS),
}
## What each folder of those rows holds, in words, where the left pane sets the folder out
## among the subjects of its root (digestSummary).
FOLDER_WORDS = {
    "checker": "the read-only checks of the installation, run on demand",
    "keys": "the public keys of this server",
    "commands": "the commands a console user calls by name",
    "user": "the README.md of each project, in build order",
    "maintainer": "the MAGIC.md of each project, in build order",
}
## The levels whose listed rows the user may have by name instead of in the order the operation gave
## them, by the key of the command "alphabetical" (orderedRows): the manuals of the projects, which
## the operation gives in the build order.
ALPHABETICAL = ("manuals/user", "manuals/maintainer")
## What the left window shows of a folder, a row that opens a level of its own, while that
## row is selected, and while the row that goes up is selected inside it: the summary of
## what the folder holds, made from its rows in a form of its kind, by the function
## "lines" names. By the level the folder opens, as READS names a level. A folder is read
## when the selection comes to stand on it, and not only when it is entered (focusReads),
## so its summary is of its real rows; until they have come the window says that it waits
## (POPULATING). The other words are that function's own. "counted": the states that are
## counted first, in this order, where the rows hold them; "missingFirst": the
## lines that are missing stand ahead of the others. A folder that is not listed here
## shows what its own row shows: a session its summary, as its mode says.
SUMMARIES = {
    "dashboard": {"lines": "dashboardSummary"},
    "sessions": {"lines": "sessionsSummary", "counted": ("running", "waiting", "unclosed")},
    "sessions/launch": {"lines": "routinesSummary"},
    "pending": {"lines": "pendingSummary"},
    "team": {"lines": "membersSummary"},
    "places": {"lines": "placesSummary"},
    "consoles": {"lines": "startsSummary"},
    "settings": {"lines": "digestSummary"},
    "settings/*": {"lines": "subjectSummary"},
    "configuration": {"lines": "digestSummary"},
    "configuration/*": {"lines": "subjectSummary", "missingFirst": True},
    "configuration/checker": {"lines": "checksSummary"},
    "configuration/keys": {"lines": "serverKeysSummary"},
    "teamdata": {"lines": "teamDataSummary"},
    "teamdata/operations": {"lines": "cleanupsSummary"},
    "teamdata/board": {"lines": "storeSummary"},
    "teamdata/audit": {"lines": "storeSummary"},
    "teamdata/vault": {"lines": "storeSummary"},
    **{"teamdata/%s/*" % storeId: {"lines": "itemsSummary", "store": storeId} for storeId, storeLabel in TEAM_DATA_STORES},
    "team/*/permissions": {"lines": "grantsSummary"},
    "team/*/files": {"lines": "filesSummary"},
    "team/*/sessions": {"lines": "sessionsSummary", "counted": ("running", "waiting", "unclosed")},
    "team/*/help": {"lines": "helpSummary", "chapters": "help"},
    "manuals": {"lines": "foldersSummary"},
    "manuals/user": {"lines": "manualsSummary"},
    "manuals/commands": {"lines": "commandsSummary"},
    "manuals/maintainer": {"lines": "manualsSummary"},
}

## What each level of the list and each view of the left pane asks the tooling for: the
## operation with its arguments, as the dispatcher takes them, and under "active" what the
## `a` filter adds. None: no operation yet, the task of that level or view names it.
## A level below a record is named with `*` in the place of that record's id, and {level}
## in an argument is that id. A view is named by its level and the kind of the row that is
## selected there, and {id} in an argument is the id of that row. An entry with "always" is
## read whatever is shown, since a status line counts by it, and "kind" then names the kind
## it runs as, beside the one list and the one view that are shown. "rows" names the form
## of what a list operation prints (parseLevels). A level with "from" has no read of its
## own: the read named there fills it. Beside the "view" of a row, its facts, stands its
## "feed", its lines, read as a kind of its own; "log" is what `l` adds to it. "needs"
## names what a row must carry for the read to be made at all. "acts" is what can be done
## with a row, read as one more part of it (VIEW_PARTS). "once": it is read when it is asked
## for, and never again because its period has passed (startDueReads). "seldom": a list that
## is read whatever is shown is read once, when the screen starts; it is read again, on
## the period and when a read is asked for, only while it is the list shown (seldomNow). "peek": a list that
## is read also while its section is the row the root stands on, since the left window
## then shows that section from its rows (wantedReads).
## "also": the reads made beside the list of a level, by their keys, while that level is
## shown and while the folder that opens it has the focus, as a kind of their own.
## "demand": it is read only when its command asks for it ("demand" in COMMANDS), never
## because it was not read yet or its period has passed, and "said" is what the status
## line says of it then.
## {parent} in an argument is the id of the level above the level read: the member of a
## folder of a member.
## "each": a read that is made for every row of the level it is named by that carries what
## it "needs", by the id of that row; its key is its name and, after a `|`, that id (readEntry).
## The list of a level is read also while the row that opens that level is the row
## selected, a folder that has the focus, as it would be on entering it (focusReads): once
## the selection has rested on that row (REST_SECONDS), so a selection that runs down a
## list starts none, and one such read at a time, as the kind "focus", beside the list
## shown, and once for each time the selection comes to rest there: while it stays, the
## period reads that list no more, and coming back reads it again only when its period
## has passed since. "peek" is read with no rest, and on the period. One that is read on
## "demand" alone is never started by the focus: its command asks for it there too.
VIEW_PARTS = ("view", "feed", "acts")
READS = {
    ## The blocks of the dashboard, each with its figures, all from the one operation. It is
    ## read on the period only while its root is selected or opened, and never else.
    "list:dashboard": {"operation": ["--manager-dashboard-read"], "rows": "blocks", "peek": True},
    ## The coworking sessions with their runs, and last the row of counters of the status lines.
    "list:sessions": {"operation": ["--manager-session-list"], "active": ["--active"],
                      "rows": "sessions", "kind": "sessions", "always": True},
    ## The routines the members carry, each with whether the session spawner would start it.
    "list:sessions/launch": {"operation": ["--manager-routine-list"], "rows": "routines"},
    ## The agents of one session come with the list of the sessions.
    "list:sessions/*": {"from": "list:sessions"},
    ## The asks that wait, every owner's. The member named filters nothing with --any-owner; it
    ## is the one the tooling's own read of every owner's asks names (the heartbeat's input scan).
    "list:pending": {"operation": ["--member-pending-reply-read", "magic-coordinator", "--any-owner"],
                     "rows": "pending"},
    ## The members of the team as this workspace knows them, one row each.
    "list:team": {"operation": ["--manager-team-member-list"], "rows": "members"},
    ## The settings and the configuration of the workspace as they are, by subject: every
    ## line with its description, whether and how it is changed, and, as its last field,
    ## which of the two roots it is of (DIGEST_FIELDS). One read fills both roots, and under
    ## each the level of every subject that has a line there (parseDigestLevels).
    "list:settings": {"operation": ["--manager-config-digest", "--full"], "rows": "digest"},
    "list:settings/*": {"from": "list:settings"},
    "list:configuration": {"from": "list:settings"},
    "list:configuration/*": {"from": "list:settings"},
    ## The checks of the installation, by the owner's own read-only diagnosis of each part
    ## of it: a row a check, with its state, why, and the command that mends it. It takes
    ## up to a minute and some of it asks outside this machine, so it is made on demand
    ## alone, and as a kind of its own, beside the lists.
    "list:configuration/checker": {"operation": ["--manager-check-run"], "rows": "checks", "kind": "check", "demand": True,
                                   "said": "it takes up to a minute"},
    ## The public keys of this server, those to add to git and those to trust when
    ## connecting, each with its fingerprint and its key shortened. Read on entering and
    ## when it is asked for, not on the period.
    "list:configuration/keys": {"operation": ["--manager-keys-list"], "rows": "keys", "once": True},
    ## One of those keys whole: the line to paste, and where the deploy key is registered.
    ## Read when its box opens, by the name of the key, and never before (askKeyLine).
    "full:key": {"operation": ["--manager-keys-read", "{id}"], "rows": "key-read", "kind": "plan", "once": True},
    ## One credential whole, read when its form is asked for it by its key and never before (revealCredential): by the
    ## setting reader as every program reads a setting, from the scope {level} by the key {id}.
    "full:credential": {"operation": ["--agents-config-option", "{level}", "--select", "{id}"], "rows": "credential-read", "kind": "plan", "demand": True},
    ## The same read for each key of the list whose public file can be read, by its name:
    ## once when the folder is opened and when it is asked for, never on the period. It
    ## gives the whole line of a key where its row of the list does not carry it, and
    ## where the key is to be registered.
    "each:configuration/keys": {"operation": ["--manager-keys-read", "{id}"], "rows": "key-read", "kind": "plan", "once": True, "needs": "readable"},
    ## What is started from here with the whole terminal, in the order of a menu: the consoles
    ## of the workspace, each with the folder it starts in and its command, a field a word (STARTS).
    "list:consoles": {"operation": ["--manager-console-list"], "rows": "starts"},
    ## The root `Team Data`: its own blocks of the dashboard, its git state among them, which
    ## is read only while the root is selected or opened (TEAM_DATA); and the digest of the
    ## settings read beside them ("also": read with the list of the level, while it is shown
    ## and while its folder has the focus), for the mode of the workspace and the remote of
    ## the team data. Its `Operations` reads the digest, for the mode and the remote.
    "list:teamdata": {"operation": ["--manager-dashboard-read", "team-data", "team-data-git", "loop"], "rows": "blocks", "also": ("list:settings",)},
    "list:teamdata/operations": {"from": "list:settings"},
    ## The locations the tooling knows by a name, one row each. Read whatever is shown, as a
    ## kind of its own, since a path inside one of them stands by its name in the other
    ## views (PLACED): once when the screen starts; again, on the period and when a read is
    ## asked for, only while `Locations (Places)` is the list shown.
    "list:places": {"operation": ["--manager-place-list"], "rows": "places", "kind": "places", "always": True, "seldom": True},
    ## One location, whole: its row, what declares it, and what stands in it.
    "view:places:record": {"operation": ["--manager-place-read", "{id}"], "rows": "place-read", "needs": "place"},
    ## The commands of a workspace among them, those its editor's palette gets, as the declarations of this
    ## console's packages give them. Read on entering it and when it is asked for, not on the period.
    "list:places/*": {"operation": ["--manager-place-command-list", "{level}"], "rows": "place-commands", "once": True},
    "view::section": None,
    "view:sessions:launch": None,
    ## A session whole, and what its runs did: the lines its tracking thread shows.
    "view:sessions:record": {"operation": ["--manager-session-read", "--session-id", "{id}"],
                             "rows": "session-read", "needs": "session"},
    "feed:sessions:record": {"operation": ["--manager-session-transcript-read", "--session-id", "{id}"],
                             "log": ["--log"], "rows": "transcript", "needs": "session"},
    ## One run of a session: --run takes the id as a run's own, the founder's too, whose id is its session's.
    "view:sessions/*:record": {"operation": ["--manager-session-read", "--session-id", "{id}", "--run"],
                               "rows": "session-read", "needs": "run"},
    "feed:sessions/*:record": {"operation": ["--manager-session-transcript-read", "--session-id", "{id}", "--run"],
                               "log": ["--log"], "rows": "transcript", "needs": "run"},
    ## One ask, whole: what the stores hold of it.
    "view:pending:record": {"operation": ["--member-pending-reply-read", "magic-coordinator", "{id}"],
                            "rows": "ask", "needs": "ask"},
    ## What can be done with one ask from the console: the row of the question, with whether it
    ## takes words, a reject and a dismissal and with the link of its message, and a row for
    ## each answer it takes. Read as a part of its own, "acts", beside the view of the ask.
    "acts:pending:record": {"operation": ["--manager-pending-reply-read", "--id", "{id}"],
                            "rows": "ask-acts", "needs": "ask"},
    ## One member, whole: its information, the sessions it is in, its grants and its settings.
    "view:team:record": {"operation": ["--manager-team-member-read", "--full", "{id}"], "rows": "member-read", "needs": "member"},
    ## What the kill of a session, and of one agent, would do, and nothing is done: the rows
    ## of the kill itself, each with what would become of it (KILL_ROWS). Read when the
    ## confirmation of that kill opens, and once more when it is confirmed (submitKill), by
    ## the id it names, as a kind of its own; never on the period, so what the confirmation
    ## says does not change under the word typed into it.
    "plan:kill:session": {"operation": ["--manager-session-kill", "--session-id", "{id}", "--plan"], "rows": "kill", "kind": "plan", "once": True},
    "plan:kill:run": {"operation": ["--manager-session-kill", "--session-id", "{id}", "--run", "--plan"], "rows": "kill", "kind": "plan", "once": True},
    ## The folders of a member: its grants and its sessions from the read of the member, the
    ## files of its skillset folder and one of them whole, and its help as the tooling gives
    ## a member its help, read when it is opened and when it is asked for.
    "list:team/*/permissions": {"operation": ["--manager-team-member-read", "--full", "{parent}"], "rows": "member-grants"},
    "list:team/*/files": {"operation": ["--manager-team-member-files", "{parent}"], "rows": "member-files"},
    "view:team/*/files:file": {"operation": ["--manager-team-member-files", "{parent}", "{id}"], "needs": "text", "once": True},
    "list:team/*/sessions": {"operation": ["--manager-team-member-read", "--full", "{parent}"], "rows": "member-sessions"},
    "view:team/*/sessions:record": {"operation": ["--manager-session-read", "--session-id", "{id}"],
                                    "rows": "session-read", "needs": "session"},
    "feed:team/*/sessions:record": {"operation": ["--manager-session-transcript-read", "--session-id", "{id}"],
                                    "log": ["--log"], "rows": "transcript", "needs": "session"},
    "list:team/*/help": {"operation": ["--member-help", "{parent}"], "rows": "member-help", "once": True, "also": ("list:help",)},
    ## The chapters of the help of this tool, which a member's `Member Help` shows around its own
    ## syntax lines. It is no level of the list: a read of its own, made beside that folder.
    "list:help": {"operation": ["--manager-help-read"], "rows": "chapters", "once": True},
    ## The root `Manuals (Help)`. The tooling commands a console user calls by name, as the
    ## console's completion gathers them, each with the file it resolves to. Read on entering
    ## and when it is asked for, not on the period.
    "list:manuals/commands": {"operation": ["--manager-command-list"], "rows": "commands", "once": True},
    ## The help of one of them, as its own `--help` prints it, read from its help files and
    ## never by running it: of the command selected alone, once the selection rests on it, and
    ## not on the period.
    "view:manuals/commands:help-entry": {"operation": ["--manager-help-read", "{id}"], "once": True},
    ## The manuals of the projects, the README.md of each (`User Manuals`) and its MAGIC.md
    ## (`Maintainer Manuals`), in the build order, a project a row; one of them whole is read
    ## by the name of its project, once the selection rests on it.
    "list:manuals/user": {"operation": ["--manager-manual-read", "user"], "rows": "manuals", "once": True},
    "view:manuals/user:help-entry": {"operation": ["--manager-manual-read", "user", "{id}"], "once": True},
    "list:manuals/maintainer": {"operation": ["--manager-manual-read", "maintainer"], "rows": "manuals", "once": True},
    "view:manuals/maintainer:help-entry": {"operation": ["--manager-manual-read", "maintainer", "{id}"], "once": True},
}
## The stores of the team data (TEAM_DATA_STORES): a store, its folders and the items in
## it; a folder of it, its items; and one item whole, its text, read once it is selected.
for storeId, storeLabel in TEAM_DATA_STORES:
    READS.update({
        "list:teamdata/%s" % storeId: {"operation": ["--manager-team-data-read", storeId], "rows": "data-store"},
        "list:teamdata/%s/*" % storeId: {"operation": ["--manager-team-data-read", storeId, "{level}"], "rows": "data-items"},
        "view:teamdata/%s:item" % storeId: {"operation": ["--manager-team-data-read", storeId, "-", "{id}"], "once": True},
        "view:teamdata/%s/*:item" % storeId: {"operation": ["--manager-team-data-read", storeId, "{level}", "{id}"], "once": True},
    })

## What each action asks the tooling for: the operation with its arguments, {id} the id of
## what it acts on. The screen itself signals no process and starts no CLI. A session's id
## finishes that session: every live run of it is ended, its questions that wait are
## dismissed and its records left open are closed; `--run` takes the id as a run's own, so on the row of an
## agent that agent alone is ended, the founder too, whose id is its session's. A start
## names its routine by its selector, or takes the standing default routine with what was
## typed as its task text, which goes on standard input and is never a word of the command.
## One member is started by its name, with what was typed as its prompt, on standard input too.
## The control thread of a session is started again by the id of that session: whether one
## is started is the operation's to say, which starts none where one lives or none is needed.
CALLS = {
    "kill:session": ["--manager-session-kill", "--session-id", "{id}"],
    "kill:run": ["--manager-session-kill", "--session-id", "{id}", "--run"],
    "control": ["--manager-session-control-start", "--session-id", "{id}"],
    "launch": ["--magic-spawn-session", "--routine", "{id}"],
    "prompt": ["--magic-spawn-session", "--routine-default"],
    "start": ["--manager-spawn-member", "{id}"],
    ## a pending question is answered, rejected by the negative answer of its kind, or
    ## dismissed, by its id; the answer chosen or typed is the word after --answer
    "answer": ["--manager-pending-reply-answer", "--id", "{id}", "--answer"],
    "reject": ["--manager-pending-reply-answer", "--id", "{id}", "--reject"],
    "dismiss": ["--manager-pending-reply-dismiss", "--id", "{id}"],
    ## a setting is saved by its key, the value chosen or typed being the word after it,
    ## as it was chosen or typed; whom it is saved for is the operation's to say
    "set": ["--manager-config-set", "{id}"],
}
## What each of those is given the words typed beside it with, where any were typed.
CALL_WORDS = {"answer": "--text", "reject": "--text", "dismiss": "--reason"}
## What a start names its session with, ahead of the name.
CALL_NAME = "--session-name-or-comment"
## The word that confirms a kill, typed whole.
KILL_WORD = "yes"
## The state of a session that is finished, as its row of the list gives it: such a one
## takes no kill, since nothing of it is left to end, to dismiss or to close.
SESSION_FINISHED = "finished"
## What the confirmation of a kill says in its own line between the press of its button
## and the deed: while its plan is read once more; where the plan was not read yet; and
## where the plan read then is not the one the confirmation showed. And, in the text of
## the confirmation itself, what it says where the plan could not be read at all.
KILL_SAYS = {
    "checking": "its plan is read once more: it is done if nothing of it has changed",
    "unread": "nothing is done yet: its plan is still being read",
    "changed": "nothing was done: its plan changed while this stood open. It stands above as it is now: type the word again",
    "unreadable": "So it is not asked for: nothing is killed, dismissed or closed. Cancel and Esc close this. The key of the kill asks again, and reads its plan anew.",
}

## What the root `Consoles` holds: the things that are started with the whole
## terminal, each sort by the name of the row its operation prints for one. "fields": the
## names of the fields of such a row after the first, written as the family writes them,
## `_` for a blank and `-` for absent. The fields after those are exact, as they are
## printed, and are never rewritten: the folder it is started in, and then its command,
## a field a word, the first the program. "terminal": the word of its field of that name
## that says it needs a terminal. "said": what one of that sort is called where the screen
## speaks of it. Another sort of thing to start is one more entry here: its rows come in
## the same list, and Enter starts it the same way (askRun, runChild).
STARTS = {
    "console": {"fields": ("key", "group", "label", "terminal"), "terminal": "terminal", "said": "console"},
}

## What the root `Dashboard (Monitor)` shows: blocks of figures, each block and each figure
## as its operation prints it; the screen knows no block and no figure by its name, and
## draws whatever comes. "block" and "figure": the names of the fields of such a row after
## the first, as the family writes them, `_` for a blank and `-` for absent; what stands
## after them in a row is left alone. "units": how a value shows by its unit, the name of
## the function that makes it short for the eye; a value of another unit shows as it is
## printed. "levels": the levels of a figure in their order, the worst last, each with
## the look its value is drawn in and the mark that stands ahead of the value where the
## style has no colours, so that bold and a mark tell it there. "bar": how many cells the
## bar of a figure that is a share takes beside its value. "least": the least width of a
## block: as many columns as blocks of that width fit are set side by side. "gap": the
## cells between two columns.
DASHBOARD = {
    "block": ("key", "label", "figures"),
    "figure": ("block", "key", "label", "value", "unit", "level", "share"),
    "units": {"count": "shortCount", "bytes": "shortBytes", "seconds": "shortSpan"},
    "levels": (("ok", {"look": LEVEL_OK, "mark": "+"}),
               ("warn", {"look": LEVEL_WARN, "mark": "!"}),
               ("bad", {"look": LEVEL_BAD, "mark": "!!"})),
    "bar": 10, "least": 34, "gap": 1,
}

## What the root `Locations (Places)` shows: the locations the tooling knows by a name, as
## its operation prints them. "fields": the names of the fields of a `place` row after the
## first. "here": the word of its field of that name that marks the workspace the console
## runs in. "present": the state of a location that is there; one in another state shows
## plainer. Looking only: nothing here changes a location.
PLACES = {
    "fields": ("key", "label", "kind", "ceiling", "path", "state", "here", "sessions"),
    "here": "yes", "present": "present",
    ## the fields of a `member` row of the read of one location, after the first; and what
    ## the row of a member says in <setup> where no registry names it: such a one shows plainer
    "member": ("name", "kind", "home", "setup", "folder"), "unlisted": "not-in-registry",
    ## the kind of a location that is a workspace, and the folder of it that holds its projects
    "workspace": "workspace", "projects": "source",
}
## The rule of the locations: a path that lies in a registered location shows as the key
## of that location, a colon and what follows it there, `<place key>:rest`, the location
## itself as its key alone, the longest location winning, the key in the look of a folder. It is a rule of the drawing alone: what the
## screen holds, what it sends to an operation, a link and a command are never changed by
## it. "real": the views where a path stands as it is, each by the root it is under and,
## where that is not the whole root, by the ids of the rows and levels under it: the table
## of the locations and the summary of one; the subject of the workspace's paths, in the
## settings and in the configuration; and what is started with the whole terminal, whose
## folder and command are exact. The raw mode of a log is such a view too, wherever it
## is. In the summary of a location, the folder of a member that lies in another location
## takes the rule all the same (placeLines). "dialogs": the dialogs whose text takes the rule,
## the path as it is standing under its paragraph as a line of its own: the answers to a
## pending question.
PLACED = {
    "real": {"places": None, "consoles": None, "settings": ("workspace",), "configuration": ("workspace",)},
    "dialogs": ("answer", "answer-many", "reply", "reject", "dismiss", "confirm"),
}
