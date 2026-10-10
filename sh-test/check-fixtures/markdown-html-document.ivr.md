# IVR-002: Slack send drops a reply under rate limiting

**Jira:** [MAGIC-12](https://example.atlassian.net/browse/MAGIC-12)

## Root cause

The retry loop reads `Retry-After` from the wrong header line, so a `429`
reply is treated as success.

## Effect

- Replies posted during a burst are lost.
- The sender logs no error.

## Flow

1. The send posts the message.
2. Slack answers `429` with `Retry-After: 3`.
3. The loop compares `429\r` with `429`, finds no match, and stops.

## Locations

`sh-lib/AgentsTools.Member.include`, the retry loop:

```sh
status="$( awk 'NR==1 { print $2 ; }' "$headers" )"
[ "$status" = 429 ] && sleep "$retryAfter"
```

## Confirmed

| What | By | Evidence |
| --- | --- | --- |
| The header line ends in CR LF | magic-developer | a `curl -D` capture |
| The retry never runs | magic-tester | the log of 3 bursts |

## Not verified

- Whether other operations share the same loop.
  - The Trello send is the likeliest one.

## Fix options

1. Strip the `\r` before comparing.\
   This is the smallest change.

2. Parse the status with `curl -w` instead.

> Proposals only. Nothing changes until the owner rules.

See https://api.slack.com/docs/rate-limits for the limits.
