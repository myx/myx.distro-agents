#!/usr/bin/env bash
set -e

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
HARNESS_MODEL_LIGHT=""
HARNESS_MODEL_MAIN=""
HARNESS_TOKEN_LIGHT="${COPILOT_GITHUB_TOKEN:-}"
HARNESS_TOKEN_MAIN="${COPILOT_GITHUB_TOKEN:-}"

export HARNESS_PROVIDER_NAME HARNESS_SELF_NAME HARNESS_ENDPOINT HARNESS_HOST
export HARNESS_WIRE HARNESS_CREDENTIAL_NAMES
export HARNESS_MODEL_LIGHT HARNESS_MODEL_MAIN HARNESS_TOKEN_LIGHT HARNESS_TOKEN_MAIN

## exec, not source: the core becomes this process, so $0 resolves to the core's
## own directory for its helper lookups and the console keeps one invoker.
exec "$harnessHere/AgentsUniversalHarness.sh" "$@"
