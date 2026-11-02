##
## AgentsManagerScreen.Roots.py -- what the roots of the list hold and what an action asks of the tooling: TEAM_DATA, CALLS, STARTS, PLACES. The roots themselves, their rows and their reads are declared by their plugins (Plugins.py).
## A part of the manager screen (LocalManagerScreen.py of `myx.distro-.local`): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen, moved whole.
##

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
                  "does": "Deletes from the team data what its retention has passed, the handled items of the inboxes, the processed items of the board and the trash, warnings and reflections after one day and every other item after seven, and commits the deletions where the team data is a repository. It is what closing the advance runs, as magic-coordinator.",
                  "needs": "rig"}),
    ("sync", {"label": "Sync The Team Data", "operation": ["--commit-pending", "magic-coordinator"],
              "does": "Commits everything pending under the team data in one commit, then syncs it with its remote by myx.common git/cloneSync: the remote's commits are pulled and merged in, what is ahead is pushed, and the remote is read back. It takes no lock: run it only while no routine holds the advance lock.",
              "needs": "remote"}),
    ("repair-keep-merged", {"label": "Keep Local Commits Merged", "operation": ["--repair-team-data-checkout", "magic-coordinator", "--keep-merged"],
              "does": "Repairs a team-data checkout that has diverged from its remote, with local commits never pushed, in one operation: it shows the local-only commits and what the remote has, trial-merges in a throwaway copy, then merges the remote in keeping the local commits, moves any flat inbox item by its processed stamp, and pushes. It takes no lock: run it only while no routine holds the advance lock.",
              "needs": "remote"}),
    ("repair-take-remote", {"label": "Set Local Commits Aside, Take Remote", "operation": ["--repair-team-data-checkout", "magic-coordinator", "--take-remote"],
              "does": "Repairs a team-data checkout that has diverged from its remote, with local commits never pushed, in one operation: it shows the local-only commits and what the remote has, trial-merges in a throwaway copy, then sets the local commits aside (kept reachable at a ref) and takes the remote, moves any flat inbox item by its processed stamp, and pushes. It takes no lock: run it only while no routine holds the advance lock.",
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
                  ("sessions", "Sessions", "member-sessions"), ("settings", "Member Settings", "member-settings"),
                  ("help", "Member Help", "member-help"))
## The scope a credential of a subject of the digest is read from, for the form of the credential: the scopes are their
## own (None: the group of the line is the scope), and the credentials of the CLIs are settings of the team.
CREDENTIAL_SCOPE = {"scopes": None, "cli": "magic-team"}
## What each folder of the rows a plugin declares always there (FIXED_ROWS) holds, in words, where the left pane sets the folder out
## among the subjects of its root (digestSummary).
FOLDER_WORDS = {
    "checker": "the read-only checks of the installation, run on demand",
    "keys": "the public keys of this server",
    "scopes": "every scope of settings of this workspace, each a folder of its variables",
    "clipresets": "the CLI services you set up as presets, and the preset and effort each member and the team use for their tiers",
    "git": "the global git settings of the account that runs the tools",
    "subsystems": "the subsystems of the tool family, installed here or not, and the commands to install and uninstall them",
    "diagnostics": "what the tooling sees, read-only: the context it resolves",
    "commands": "the commands a console user calls by name",
    "user": "the README.md of each project, in build order",
    "maintainer": "the MAGIC.md of each project, in build order",
    "activity": "the sessions of the team and the agents in them",
    "launch": "the starts you make by hand: a coworking, standalone, work-duty, routine or free-prompt session",
    "routines": "every routine of the team, with its state, its members and when it runs",
    "schedule": "the week by hour: which routines run when, in the order they run",
    "pending": "the questions that wait for an answer",
    "team": "each member of the team, its permissions, files, sessions, settings and help",
    "teamdata": "the board, the audit and the vault of the team data, and its operations",
}
## What each of those is given the words typed beside it with, where any were typed.
CALL_WORDS = {"answer": "--text", "reject": "--text", "dismiss": "--reason"}
## What a start names its session with, ahead of the name.
CALL_NAME = "--session-name-or-comment"
## The state of a session that is finished, as its row of the list gives it: such a one
## takes no kill, since nothing of it is left to end, to dismiss or to close.
SESSION_FINISHED = "finished"
## What the confirmation of a kill says in its own line where the plan was not read yet,
## and, in the text of the confirmation itself, what it says where the plan could not be
## read at all.
KILL_SAYS = {
    "unread": "nothing is done yet: its plan is still being read, and the kill follows when it has been read",
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
