# Extension

[Back to the README](../README.md)

## Adding your own team members

A workspace contributes members by declaring them in a project's `project.inf`:

	Declares: \
		magic-team:team-member:skillset/<member-name>:<host-glob> \

Put the member's own skill directory at that path, then re-run
`--install-skillset-symlinks` to register it.

## Adding your own channels

A project registers a communication channel the whole workspace can address by name, with one
`Declares` entry per channel:

	Declares: \
		magic-team:comms-channel:<channel-name>:<service>:<channel-address> \

`<service>` is one of the drivers (`slack`, `email`, `telegram`, `printback`); `<channel-address>` is
that driver's address (a Slack conversation id, an e-mail address, a Telegram chat id, a session id
for the root-native `printback` kind). The name resolves through the communication-channel-id
abstraction, with the drivers ordered by preference — `slack`, then `email`, then `telegram`, then
`printback`.

## Adding your own channels

A project registers a communication channel the whole workspace can address by name, with one
`Declares` entry per channel:

	Declares: \
		magic-team:comms-channel:<channel-name>:<service>:<channel-address> \

`<service>` is one of the drivers (`slack`, `email`, `telegram`, `printback`); `<channel-address>` is
that driver's address (a Slack conversation id, an e-mail address, a Telegram chat id, a session id
for the root-native `printback` kind). The name resolves through the communication-channel-id
abstraction, with the drivers ordered by preference — `slack`, then `email`, then `telegram`, then
`printback`.
