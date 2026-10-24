#!/usr/bin/env bash
set -e

## AgentsDeepseekHarness.sh -- DeepSeek's official paid service, and nothing else: the endpoint,
## the tier models, the credential name and the wire it speaks. It then execs the universal
## harness, which holds the logic. The console resolves `deepseek` to exactly this path. It is
## not a preset and must not grow into a selector.
##
## THE SERVICE IS THE SUBJECT, NOT A MODEL. DeepSeek speaks the OpenAI chat wire at its own
## host, and the same account also serves the Anthropic Messages wire under `/anthropic`, so
## a preset may point PRESET_ENDPOINT_URL at https://api.deepseek.com/anthropic and the core
## switches the wire and appends `/v1/messages` itself (AgentsUniversalHarness.sh, "THE
## ENDPOINT A PRESET NAMES"). Nothing here changes for either path.

HARNESS_PROVIDER_NAME="DeepSeek"
HARNESS_SELF_NAME="AgentsDeepseekHarness.sh"

## --- the endpoint, and the host named in its own refusal message ---------
## The OpenAI-compatible surface of the paid service. `/v1` is the versioned alias of the
## same endpoint, and the preset URL may name either base.
HARNESS_ENDPOINT="https://api.deepseek.com/v1/chat/completions"
HARNESS_HOST="api.deepseek.com"

## --- which wire this endpoint speaks: resolves to AgentsOpenAiChatWire.sh
HARNESS_WIRE="OpenAiChat"

## --- the credential name, which the core reports but never chooses -------
HARNESS_CREDENTIAL_NAMES="DEEPSEEK_API_KEY"

## --- tier -> model, and tier -> credential -------------------------------
## BOTH IDS ARE REFERENCE-DERIVED AND HAVE NOT BEEN OBSERVED ON THE WIRE by this package.
## They are the two names DeepSeek's own API documentation states on 2026-10-24, and a
## neighbouring leg already records that vendor documentation has been wrong on one model
## in use, so VERIFY BEFORE TRUSTING: GET https://api.deepseek.com/models with the key.
## A model an exported HARNESS_MODEL_LIGHT or HARNESS_MODEL_MAIN names stands ahead of the
## leg's own: the console exports the model name of the preset a spawn runs on (F10.2), and
## nothing else does. The default is the leg's. Best effort, as the service is: a model this
## account cannot reach fails at the wire, not here.
HARNESS_MODEL_LIGHT="${HARNESS_MODEL_LIGHT:-deepseek-chat}"
HARNESS_MODEL_MAIN="${HARNESS_MODEL_MAIN:-deepseek-reasoner}"
HARNESS_TOKEN_LIGHT="${DEEPSEEK_API_KEY:-}"
HARNESS_TOKEN_MAIN="${DEEPSEEK_API_KEY:-}"

## Each model's own window, as the service states it: 128K context on both, and 8K of output
## on the chat model, 64K on the reasoner. UNOBSERVED here, stated as the documented ceiling
## rather than rounded up, and a value the API refuses is corrected here and nowhere else.
HARNESS_CONTEXT_TOKENS_LIGHT="128000"
HARNESS_OUTPUT_TOKENS_LIGHT="8192"
HARNESS_CONTEXT_TOKENS_MAIN="128000"
HARNESS_OUTPUT_TOKENS_MAIN="65536"

export HARNESS_PROVIDER_NAME HARNESS_SELF_NAME HARNESS_ENDPOINT HARNESS_HOST
export HARNESS_WIRE HARNESS_CREDENTIAL_NAMES
export HARNESS_MODEL_LIGHT HARNESS_MODEL_MAIN HARNESS_TOKEN_LIGHT HARNESS_TOKEN_MAIN
export HARNESS_CONTEXT_TOKENS_LIGHT HARNESS_OUTPUT_TOKENS_LIGHT
export HARNESS_CONTEXT_TOKENS_MAIN HARNESS_OUTPUT_TOKENS_MAIN

## exec, not source: the core becomes this process, so the console keeps one
## invoker. The core resolves its own helper lookups from the origin, not from $0.
exec "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsUniversalHarness.sh" "$@"
