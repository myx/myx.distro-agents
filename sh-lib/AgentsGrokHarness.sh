#!/usr/bin/env bash
set -e

## AgentsGrokHarness.sh -- xAI Grok's specifics, and nothing else: the endpoint,
## the tier models, the credential name and the wire it speaks. It then execs the
## universal harness, which holds the logic. The console and --owner-setup-grok
## both resolve `grok` to exactly this path; the vendor grok CLI is a different
## thing, reached as `grok-native`. It is not a preset and must not grow into a
## selector. See MAGIC.md for the split.

HARNESS_PROVIDER_NAME="xAI Grok"
HARNESS_SELF_NAME="AgentsGrokHarness.sh"

## --- the endpoint, and the host named in its own refusal message ---------
HARNESS_ENDPOINT="https://api.x.ai/v1/chat/completions"
HARNESS_HOST="api.x.ai"

## --- which wire this endpoint speaks: resolves to AgentsOpenAiChatWire.sh
HARNESS_WIRE="OpenAiChat"

## --- the credential name, which the core reports but never chooses -------
HARNESS_CREDENTIAL_NAMES="XAI_API_KEY"

## --- tier -> model, and tier -> credential -------------------------------
## Both ids are listed by this API's own /v1/models; MAGIC.md carries the evidence.
HARNESS_MODEL_LIGHT="grok-4.3"
HARNESS_MODEL_MAIN="grok-4.7"
HARNESS_TOKEN_LIGHT="${XAI_API_KEY:-}"
HARNESS_TOKEN_MAIN="${XAI_API_KEY:-}"

export HARNESS_PROVIDER_NAME HARNESS_SELF_NAME HARNESS_ENDPOINT HARNESS_HOST
export HARNESS_WIRE HARNESS_CREDENTIAL_NAMES
export HARNESS_MODEL_LIGHT HARNESS_MODEL_MAIN HARNESS_TOKEN_LIGHT HARNESS_TOKEN_MAIN

## exec, not source: the core becomes this process, so the console keeps one
## invoker. The core resolves its own helper lookups from the origin, not from $0.
exec "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsUniversalHarness.sh" "$@"