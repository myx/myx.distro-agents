#!/usr/bin/env bash
## The fake curl of AgentsArtifactPublishCheck: a Slack call goes to the Slack-shaped fake of
## AgentsHarnessAskCheck, every other call to the Confluence stand-in. Opens no socket.
for rigArg in "$@" ; do
	case "$rigArg" in
		https://slack.com/*) exec bash "$RIG_FIXTURES/harness-ask-check.curl.test.sh" "$@" ;;
	esac
done
exec python3 "$RIG_FIXTURES/artifact-publish.confluence.test.py" "$@"
