#!/usr/bin/env bash
set -e

## AgentsScalewayHarness.sh -- Scaleway's specifics, and nothing else: the
## endpoint, the tier models, the credential names and the wire it speaks. It
## then execs the universal harness, which holds the logic. It keeps the
## invoker's filename because the console and --owner-setup-scaleway both
## resolve `scaleway` to exactly this path. It is not a preset and must not grow
## into a selector. See MAGIC.md for the split and the full tier evidence.

## --- Scaleway's identity, as it appears in diagnostics -------------------
HARNESS_PROVIDER_NAME="Scaleway"
HARNESS_SELF_NAME="AgentsScalewayHarness.sh"

## --- the endpoint, and the host named in its own refusal message ---------
HARNESS_ENDPOINT="https://api.scaleway.ai/v1/chat/completions"
HARNESS_HOST="api.scaleway.ai"

## --- which wire this endpoint speaks: resolves to AgentsOpenAiChatWire.sh
HARNESS_WIRE="OpenAiChat"

## --- the credential names, which the core reports but never chooses ------
HARNESS_CREDENTIAL_NAMES="SCALEWAY_DEEPSEEK or SCALEWAY_GEMMA"

## --- tier -> model, and tier -> credential -------------------------------
## THESE MODEL NAMES ARE OBSERVED, NOT DOCUMENTED. gemma-4-26b-a4b-it is a
## live-confirmed stand-in for the originally-decided google/gemma-4-31b-it:bf16,
## which this API's own /v1/models does not list. Gemma is the genuinely lighter
## model (3.8B active parameters per token against deepseek's 13B, and cheaper),
## so light anchors on gemma alone and deepseek splits normal and heavy by its
## own reasoning_effort. Either key reaches either model -- Scaleway scopes by
## Project and policy, not by model -- so each tier prefers its own key and
## falls back to the other rather than failing.
HARNESS_MODEL_LIGHT="gemma-4-26b-a4b-it"
HARNESS_MODEL_MAIN="deepseek-v4-flash-0731"

## Each model's own window. Scaleway's /v1/models publishes none, so this is its
## supported-models page on 2026-09-28, which gives both as "256k" and no exact figure.
## No output maximum is declared: that page gives "32k" for both, with no exact figure,
## so the provider applies the model's own.
HARNESS_CONTEXT_TOKENS_LIGHT="256000"
HARNESS_CONTEXT_TOKENS_MAIN="256000"
HARNESS_TOKEN_LIGHT="${SCALEWAY_GEMMA:-${SCALEWAY_DEEPSEEK:-}}"
HARNESS_TOKEN_MAIN="${SCALEWAY_DEEPSEEK:-${SCALEWAY_GEMMA:-}}"

export HARNESS_PROVIDER_NAME HARNESS_SELF_NAME HARNESS_ENDPOINT HARNESS_HOST
export HARNESS_WIRE HARNESS_CREDENTIAL_NAMES
export HARNESS_MODEL_LIGHT HARNESS_MODEL_MAIN HARNESS_TOKEN_LIGHT HARNESS_TOKEN_MAIN
export HARNESS_CONTEXT_TOKENS_LIGHT HARNESS_CONTEXT_TOKENS_MAIN

## exec, not source: the core becomes this process, so the console keeps one
## invoker. The core resolves its own helper lookups from the origin, not from $0.
exec "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsUniversalHarness.sh" "$@"
