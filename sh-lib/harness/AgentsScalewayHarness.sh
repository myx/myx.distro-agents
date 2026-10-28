#!/usr/bin/env bash
set -e

## AgentsScalewayHarness.sh -- Scaleway's specifics, and nothing else: the
## endpoint, the tier model, the credential name and the wire it speaks. It
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
## One name, the key the user generates; the model is the preset's, never the key's name (sketch 13.2).
HARNESS_CREDENTIAL_NAMES="SCALEWAY_API_KEY"

## --- tier -> model, and tier -> credential -------------------------------
## Scaleway is a cloud service provider, not a model: a key is scoped by Project and
## policy, never by model (confirmed live), and which model a run uses is the preset's
## PRESET_MODEL_OR_MACRO, which the console exports as HARNESS_MODEL_LIGHT and
## HARNESS_MODEL_MAIN (F10.2). A preset called mel-scaleway-deepseek is only a name. The
## macros resolve to two models of the human-owner's pick: the light tier to
## gemma-4-26b-a4b-it, the normal and heavy tiers to deepseek-v4-flash-0731, the model this
## leg has been observed to serve -- a default, never a roster: this API's own /v1/models
## does not list every model a Project carries. An exported HARNESS_MODEL_LIGHT or
## HARNESS_MODEL_MAIN stands ahead of it, as ever.
HARNESS_MODEL_FROM_LIGHT="${HARNESS_MODEL_LIGHT:+name}" ; HARNESS_MODEL_FROM_MAIN="${HARNESS_MODEL_MAIN:+name}"
HARNESS_MODEL_MAIN="${HARNESS_MODEL_MAIN:-deepseek-v4-flash-0731}"
HARNESS_MODEL_LIGHT="${HARNESS_MODEL_LIGHT:-gemma-4-26b-a4b-it}"

## The default model's own window. Scaleway's /v1/models publishes none, so this is its
## supported-models page on 2026-09-28, which gives it as "256k" and no exact figure.
## No output maximum is declared: that page gives "32k", with no exact figure, so the
## provider applies the model's own. A preset that names another model of its own knows
## that model's window, and names the restart threshold it wants.
## The family table (AgentsHarnessLimits.include), every row from Scaleway's own supported-models page (source https://raw.githubusercontent.com/scaleway/docs-content/main/pages/generative-apis/reference-content/supported-models.mdx,
## page validation date 2026-08-14), read 2026-10-28: deepseek (v4.1-flash and v4-flash-0731): 256k of context, 32k of output; gemma-4-26b-a4b-it, the
## default light model: 256k of context, 32k of output; gemma-3-27b-it: 40k of context, 8k of output. Other gemma (gemma-4-31b-it has 262k and no serverless
## output figure) and any other model get the open table's default (the last row). The macros low and normal or high resolve to the default models
## above. The effort none: deepseek is sent its lowest, low (no none observed); gemma does not reason, so nothing is sent.
HARNESS_MODEL_TABLE="deepseek*|256000|32768|effort:low|https://raw.githubusercontent.com/scaleway/docs-content/main/pages/generative-apis/reference-content/supported-models.mdx deepseek-v4.1-flash and deepseek-v4-flash-0731 read 2026-10-28
gemma-4-26b*|256000|32768|omit|https://raw.githubusercontent.com/scaleway/docs-content/main/pages/generative-apis/reference-content/supported-models.mdx gemma-4-26b-a4b-it read 2026-10-28
gemma-3*|40000|8192|omit|https://raw.githubusercontent.com/scaleway/docs-content/main/pages/generative-apis/reference-content/supported-models.mdx gemma-3-27b-it read 2026-10-28
*|32768|8192|omit|the open table's default (AgentsHarnessLimits.include, sketch 13.1), for any model the user's key serves that no row above was read for (sketch 13.2)"
HARNESS_TOKEN_LIGHT="${SCALEWAY_API_KEY:-}"
HARNESS_TOKEN_MAIN="${SCALEWAY_API_KEY:-}"
## Old per-model names are not read; say so where one is all that is set.
if [ -z "${SCALEWAY_API_KEY:-}" ] && [ -n "${SCALEWAY_DEEPSEEK:-}${SCALEWAY_GEMMA:-}" ] ; then
	echo "$HARNESS_SELF_NAME: SCALEWAY_DEEPSEEK and SCALEWAY_GEMMA are not read; this leg reads SCALEWAY_API_KEY, the key you generate, and the preset names the model" >&2
fi

## --- prompt_cache_key: off by default here ---------------------------------
## UNOBSERVED: no request carrying the field has been sent to this endpoint, and an
## OpenAI-compatible server may refuse a body field it does not know. Off until a live
## run shows it accepted; HARNESS_PROMPT_CACHE_KEY=on in the environment tries it.
HARNESS_PROMPT_CACHE_KEY="${HARNESS_PROMPT_CACHE_KEY:-off}"

export HARNESS_PROMPT_CACHE_KEY
## The service's own web search (AgentsHarnessSearchNative): none. Scaleway's docs, read in full on 2026-10-27, offer none: the API reference
## (https://www.scaleway.com/en/developers/api/generative-apis/) lists web_search_options as not supported and says only function tools are supported; the Responses API
## page (https://www.scaleway.com/en/docs/generative-apis/how-to/query-language-models/) says Scaleway's support covers no tools other than function calling; the supported-models
## page (https://www.scaleway.com/en/docs/generative-apis/reference-content/supported-models/) names no search tool for any model. WebSearch is DuckDuckGo's.
HARNESS_WEB_SEARCH="none"
export HARNESS_WEB_SEARCH

export HARNESS_PROVIDER_NAME HARNESS_SELF_NAME HARNESS_ENDPOINT HARNESS_HOST
export HARNESS_WIRE HARNESS_CREDENTIAL_NAMES
export HARNESS_MODEL_LIGHT HARNESS_MODEL_MAIN HARNESS_TOKEN_LIGHT HARNESS_TOKEN_MAIN
export HARNESS_MODEL_TABLE HARNESS_MODEL_FROM_LIGHT HARNESS_MODEL_FROM_MAIN

## exec, not source: the core becomes this process, so the console keeps one
## invoker. The core resolves its own helper lookups from the origin, not from $0.
exec "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsUniversalHarness.sh" "$@"
