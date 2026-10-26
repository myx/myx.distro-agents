##
## AgentsManagerScreen.MagicTeam.py -- the root Magic-Team (Agents): the team of the workspace, managed by myx.distro-agents.
## A part of the manager screen (AgentsManagerScreen.py): that file executes it, in its own namespace and in the
## order of its PARTS, and it is never run by itself. The part is plain text of the screen.
##

## ---- the plugin: `Magic-Team (Agents)` ----

## It holds no content of its own: what the team does and is stands under it, as plugins mounted on this one -- `Pending Questions`,
## as it stands in the root too (Pending.py), `Activity` (Sessions.py), `Team Members` (Members.py) and `Team Data`
## (TeamData.py) -- and its left window sets those folders out (foldersSummary). It stands in the list after `Dashboard (Monitor)`
## and `Pending Questions`, since it registers after the parts of those; the plugins mounted on it stand in it in the order they
## registered in (pluginsOrdered).
registerPlugin({
    "name": "magic-team",
    "root": {"id": "magic-team", "label": "Magic-Team (Agents)", "go": "Ma~g~ic-Team (Agents)", "group": "team"},
    "summaries": {
        "magic-team": {"lines": "foldersSummary"},
    },
})
