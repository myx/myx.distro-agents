# Workspace and execution mechanics

Read this for how workspaces, registries and settings work, and for one-off calls and console sessions. The rules every member follows are in "Workspace".

## Contents

- Workspace
- Execution mechanisms

## Workspace

- A machine has several workspaces and one team. The team on it is the members published by its tracked workspaces, whichever one each is set up in. Nothing asks whether two workspaces are the same team; only where a member is set up decides it. A member whose workspace is not mounted is absent, not broken: nothing is repaired or reported.
- Where that is recorded: the machine-wide directory `~/.agents/magic-team/`, in two files.
  - `members.registry`: each member a workspace publishes, with that workspace's root and the member's folder.
  - `directories.registry`: each registered place, by name, with the workspace registering it. Those workspaces are the tracked ones.

  A workspace's own data is in its `.local/agents/`: `members.index` lists its own members only. A member of another workspace has no folder there and none is created: it is found through `members.registry`. `~/.claude/skills`, `~/.agents/skills` and `~/.copilot/skills` are link folders generated for the vendor clients and are never a source.
- Three roles fall on a session's workspace, named `executing-workspace`, `paying-workspace` and `member-workspace` on its own spawn record. It **executes**: its team data and board, its temp, its sessions and sandboxes, its comms settings. It also executes every outside system: Slack, email, Jira, Confluence, the publishing backend. It **pays**: the CLI service, the harness tier and the credentials a member is spawned with. The executing workspace pays by default, unless another known workspace is named to pay. Each participating member brings **its own**: the workspace it is set up in, which supplies its skillset folder and its own standing access.
- On a single-workspace machine the three roles fall on that one workspace. A member behaves differently on two such machines only because the workspace configured there differs.
- A member set up only in another workspace on this machine is invited into a session run from this one. It is spawned here like any other member, and works on this workspace's team data, Slack and billing. It reads its own skillset from the workspace it is set up in. A `client-*` member follows the same rule, not an exception to it. Its whole operation runs in the workspace it is called from. Only its skillset is read from the workspace it is set up in.
- Settings come from the workspace the session runs from. A member's own setting missing there is taken from the workspace that member is set up in, on the same machine. Team-wide settings — the team Slack, the spawn settings, the board — are never borrowed from another workspace. A missing setting is said, never papered over.

## Execution mechanisms

- A one-off call against another workspace goes through `mcp__myx_distro__execute` with that workspace in its `workspace` argument.
- **Console sessions are off by default.** A member opens one (`--console-start`, `--console-send`, `--console-stop`) only where its own instructions list those operations. It does so to batch several commands in one workspace, or to work in another workspace. Process-flow routines use direct calls.
