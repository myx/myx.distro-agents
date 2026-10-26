#!/usr/bin/env bash
set -e

## AgentsStandardV1Harness.sh -- the full service: the universal core with every value manual.
## It holds no endpoint, no model and no credential of its own, so it serves any server that
## speaks one of the two wires. The preset this spawn runs on supplies all of it:
## PRESET_ENDPOINT_URL, PRESET_MODEL_OR_MACRO and the preset's own credential.
##
## The path names the wire: a base ending `/anthropic` speaks the Anthropic Messages wire and
## one ending `/v1` the OpenAI chat wire. The core reads the endpoint and appends the rest of
## the request path, so a base URL is enough.
##
## `standard-v1` is the name the services list and the console already carry for this leg.

HARNESS_PROVIDER_NAME="Standard v1"
HARNESS_SELF_NAME="AgentsStandardV1Harness.sh"

## --- the endpoint: the preset's, never defaulted here --------------------
## HARNESS_ENDPOINT_URL is what the console reads out of PRESET_ENDPOINT_URL.
HARNESS_ENDPOINT="${HARNESS_ENDPOINT_URL:-}"
if [ -z "$HARNESS_ENDPOINT" ] ; then
	echo "⛔ ERROR: $HARNESS_SELF_NAME: this service has no endpoint of its own. Set PRESET_ENDPOINT_URL in the preset, for example https://api.example.com/v1 or https://api.example.com/anthropic" >&2
	exit 1
fi
HARNESS_HOST="${HARNESS_ENDPOINT#*://}"
HARNESS_HOST="${HARNESS_HOST%%/*}"

## --- the wire: the endpoint's own path chooses ---------------------------
case "$HARNESS_ENDPOINT" in
	*/anthropic|*/anthropic/*) HARNESS_WIRE="AnthropicMessages" ;;
	*) HARNESS_WIRE="OpenAiChat" ;;
esac

## --- the models: the macros low, normal and high resolve to the small chat model --
## A model an exported HARNESS_MODEL_LIGHT or HARNESS_MODEL_MAIN names stands ahead of
## anything, and the console exports the preset's (F10.2). A macro names none, so it resolves here to the chat model
## this leg serves by default, the agreed set by the ids setup.feature-local-ai serves: low is qwen3.5-4b-q8_0, and normal
## and high qwen3.5-9b-q8_0, with high at the effort high. The three machine profiles this leg serves choose by naming the
## model in the preset: 1. a normal CPU with constrained or shared RAM, qwen3.5-4b-q8_0; 2. a dedicated or bigger CPU with
## more RAM, qwen3.5-9b-q8_0 (the default of normal); 3. the GPU machine, qwen3.8-27b-q8_0. A model of a family the table
## below does not hold is refused by the core at start.
HARNESS_MODEL_FROM_LIGHT="${HARNESS_MODEL_LIGHT:+name}" ; HARNESS_MODEL_FROM_MAIN="${HARNESS_MODEL_MAIN:+name}"
HARNESS_MODEL_LIGHT="${HARNESS_MODEL_LIGHT:-qwen3.5-4b-q8_0}"
HARNESS_MODEL_MAIN="${HARNESS_MODEL_MAIN:-qwen3.5-9b-q8_0}"

## --- the budget: a reasonable default, and the preset may name its own -----
## This leg serves ANY server, so it cannot read a window from the service it is pointed
## at. A preset that knows its server's real window sets PRESET_CONTEXT_MAX_SIZE, which the
## core reads as the restart threshold and warns about at start when it is far below the
## window of the table below. The old no-declaration fallback of 400000 is exactly the
## overspend class a table avoids: it assumed more than three times the window of the
## commonest server and let a run run there until the server refused it.
##
## THE FAMILY TABLE (AgentsHarnessLimits.include): this leg serves a server it cannot ask, so it knows the popular open
## chat model families by name, in the sizes of the three machine profiles above (4b, 8b, 12b and 14b; a name carries its
## size after a `-`, `:` or `_`, as qwen3-8b, qwen3:8b or Qwen3_8B-Instruct) -- the ones the console is to install from a
## command later -- and a model of none of them is refused at start with this list. The first row that matches wins, so a
## size stands ahead of its family's own row. The figures are the families' published ones as the author knows them, NOT
## re-read for this table (2026-10-26): qwen (the Qwen3 line: 32768 of native context, hybrid thinking, so the effort none
## switches it off), gemma (Gemma 3: 131072 of context from 4b up, does not reason), deepseek (the R1 distills and the open V3
## line: 131072, thinking switched off for none), llama (Llama 3.1 and after: 131072, does not reason). The output is a
## budget per size, not the maximum: it comes off the window for the restart threshold. A small machine cannot hold a large
## window in RAM, so a preset for profile 1 sets PRESET_CONTEXT_MAX_SIZE to the size it can carry, which stands ahead.
## The rows are stated once, in AgentsHarnessLimits.include (AgentsHarnessOpenModelTable), because the local leg serves the
## same open models and reads the same table.
HARNESS_MODEL_TABLE="$( . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessLimits.include" && AgentsHarnessOpenModelTable )"

## --- the credential: either of the two the wires read, and the preset's --
## The preset offers both names, so one of them is entered once, in the preset that holds
## the service, and an extending preset inherits it and enters nothing.
HARNESS_CREDENTIAL_NAMES="ANTHROPIC_API_KEY OPENAI_API_KEY"
HARNESS_TOKEN_LIGHT="${ANTHROPIC_API_KEY:-${OPENAI_API_KEY:-}}"
HARNESS_TOKEN_MAIN="${ANTHROPIC_API_KEY:-${OPENAI_API_KEY:-}}"
if [ -z "$HARNESS_TOKEN_MAIN" ] ; then
	echo "⛔ ERROR: $HARNESS_SELF_NAME: this service has no credential. Set ANTHROPIC_API_KEY or OPENAI_API_KEY in the preset" >&2
	exit 1
fi

## The service's own web search (AgentsHarnessSearchNative): none; the standard-v1 endpoint is our own open-model serving, and no search is documented for it, so WebSearch is DuckDuckGo's.
HARNESS_WEB_SEARCH="none"
export HARNESS_WEB_SEARCH

export HARNESS_PROVIDER_NAME HARNESS_SELF_NAME HARNESS_ENDPOINT HARNESS_HOST
export HARNESS_WIRE HARNESS_CREDENTIAL_NAMES
export HARNESS_MODEL_LIGHT HARNESS_MODEL_MAIN HARNESS_TOKEN_LIGHT HARNESS_TOKEN_MAIN
export HARNESS_MODEL_TABLE HARNESS_MODEL_FROM_LIGHT HARNESS_MODEL_FROM_MAIN

## exec, not source: the core becomes this process, so the console keeps one
## invoker. The core resolves its own helper lookups from the origin, not from $0.
exec "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsUniversalHarness.sh" "$@"
