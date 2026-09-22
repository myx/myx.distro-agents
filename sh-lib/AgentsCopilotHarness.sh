#!/usr/bin/env bash
set -e

## AgentsCopilotHarness.sh -- GitHub Copilot's specifics, and nothing else: the endpoint,
## the tier models, the credential names and the wire it speaks. It then execs the
## universal harness, which holds the logic. It is not a preset and must not grow into a
## selector. See MAGIC.md for the split.

harnessHere="$( cd "$( dirname -- "$0" )" && pwd )"

HARNESS_PROVIDER_NAME="GitHub Copilot"
HARNESS_SELF_NAME="AgentsCopilotHarness.sh"

## --- the endpoint, and the host named in its own refusal message ---------
HARNESS_ENDPOINT="https://api.githubcopilot.com/chat/completions"
HARNESS_HOST="api.githubcopilot.com"

## --- which wire this endpoint speaks: resolves to AgentsOpenAiChatWire.sh
HARNESS_WIRE="OpenAiChat"

## --- the credential names, which the core reports but never chooses ------
HARNESS_CREDENTIAL_NAMES="COPILOT_GITHUB_TOKEN"

## --- tier -> model, and tier -> credential -------------------------------
## THESE MODEL IDS ARE ANCHORED BY ELIMINATION, NOT BY MEASURED CAPABILITY. Both are read
## out of this machine's own vendor state, with no network touched: ~/.copilot/settings.json
## carries "model": "claude-fable-5" and ~/.copilot/config.json carries
## "recentModelIds": ["gpt-5.6-sol"]. config.json says of itself that it is managed
## automatically and that user settings belong in settings.json, so the first id is a
## declared choice and the second is machine-managed MRU state -- main is the tier doing the
## real work, so it takes the id actually selected. NEITHER ID IS YET CONFIRMED ACCEPTED BY
## THE ENDPOINT UNDER THIS SPELLING.
HARNESS_MODEL_LIGHT="gpt-5.6-sol"
HARNESS_MODEL_MAIN="claude-fable-5"
HARNESS_TOKEN_LIGHT="${COPILOT_GITHUB_TOKEN:-}"
HARNESS_TOKEN_MAIN="${COPILOT_GITHUB_TOKEN:-}"

## --- credential exchange, and extra headers: both declared empty ----------
## Empty spends the stored credential itself as the bearer and adds no header. That path is
## untested against this endpoint, and the first live run is what settles it -- MAGIC.md
## carries the reasoning, the unresolved premise conflict and what was already searched.
## Set HARNESS_TOKEN_EXCHANGE="GithubCopilot" once sh-lib/AgentsGithubCopilotExchange.sh exists.
HARNESS_TOKEN_EXCHANGE=""
HARNESS_EXTRA_HEADERS=""

export HARNESS_PROVIDER_NAME HARNESS_SELF_NAME HARNESS_ENDPOINT HARNESS_HOST
export HARNESS_WIRE HARNESS_CREDENTIAL_NAMES
export HARNESS_MODEL_LIGHT HARNESS_MODEL_MAIN HARNESS_TOKEN_LIGHT HARNESS_TOKEN_MAIN
export HARNESS_TOKEN_EXCHANGE HARNESS_EXTRA_HEADERS

## exec, not source: the core becomes this process, so $0 resolves to the core's
## own directory for its helper lookups and the console keeps one invoker.
exec "$harnessHere/AgentsUniversalHarness.sh" "$@"
