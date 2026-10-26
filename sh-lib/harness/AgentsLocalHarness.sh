#!/usr/bin/env bash
set -e

## AgentsLocalHarness.sh -- our own installed local models (setup.feature-local-ai), and nothing else: the endpoint
## of the local server, the macros that resolve to its models, the credential name and the wire it speaks. It then
## execs the universal harness, which holds the logic. The console resolves `local` to exactly this path.
##
## It speaks the standard-v1 protocol, the OpenAI chat wire, to the local server. A local server reached over a Unix
## socket instead is not wired: the core's request path is an https URL, and a socket is a later addition once the
## setup names the socket it serves.
##
## ONE TOOLING READ, for the console form: `AgentsLocalHarness.sh --list-models` lists the models the local server
## really has installed, one per line, TAB-separated: model, machine profile (1 a normal CPU with constrained or shared
## RAM, 2 a dedicated or bigger CPU with more RAM, 3 the GPU machine, - where the name carries no size), context window,
## output budget, and the effort-none form of its family. A model of no known family has - in the last three. Nothing is
## printed and rc 1 where the server cannot be reached.

HARNESS_PROVIDER_NAME="Local models"
HARNESS_SELF_NAME="AgentsLocalHarness.sh"

## --- the endpoint: the preset's, else the local server's own default ------
## HARNESS_ENDPOINT_URL is what the console reads out of PRESET_ENDPOINT_URL. Default: an OpenAI-compatible server
## on this machine: the one setup.feature-local-ai serves its chat models on, 127.0.0.1:8181 (its LAI_CHAT_ADDR default).
## A preset may name another loopback address in PRESET_ENDPOINT_URL.
HARNESS_ENDPOINT="${HARNESS_ENDPOINT_URL:-http://127.0.0.1:8181/v1}"
HARNESS_HOST="${HARNESS_ENDPOINT#*://}"
HARNESS_HOST="${HARNESS_HOST%%/*}"
HARNESS_WIRE="OpenAiChat"

## --- the credential: none is needed, a key is optional --------------------
## A local server asks for no key. The core wants a token to send, so a literal stands in when none is set; it is not a
## secret and opens nothing.
HARNESS_CREDENTIAL_NAMES="LOCAL_AI_API_KEY"
HARNESS_TOKEN_LIGHT="${LOCAL_AI_API_KEY:-local}"
HARNESS_TOKEN_MAIN="${LOCAL_AI_API_KEY:-local}"

## --- the models: the macros low, normal and high resolve to the agreed set, by the ids setup.feature-local-ai serves --
## As the standard-v1 leg has them: low is Qwen3.5 4B Q8_0 (machine profile 1), normal and high Qwen3.5 9B Q8_0 (profile 2),
## high at the effort high. The GPU machine (profile 3) is chosen by naming qwen3.8-27b-q8_0 in the preset. A model the preset
## names stands ahead, and one of no family in the table is refused by the core at start.
HARNESS_MODEL_FROM_LIGHT="${HARNESS_MODEL_LIGHT:+name}" ; HARNESS_MODEL_FROM_MAIN="${HARNESS_MODEL_MAIN:+name}"
HARNESS_MODEL_LIGHT="${HARNESS_MODEL_LIGHT:-qwen3.5-4b-q8_0}"
HARNESS_MODEL_MAIN="${HARNESS_MODEL_MAIN:-qwen3.5-9b-q8_0}"

## --- the family table: the open chat models, stated once in AgentsHarnessLimits.include -------
HARNESS_MODEL_TABLE="$( . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessLimits.include" && AgentsHarnessOpenModelTable )"

if [ "${1:-}" = "--list-models" ] ; then
	localIds="$( curl -fsS --max-time 3 "${HARNESS_ENDPOINT%/}/models" 2> /dev/null | tr ',{}[]' '\n\n\n\n\n' | sed -n 's/^ *"id" *: *"\([^"]*\)".*/\1/p' )" || localIds=""
	[ -n "$localIds" ] || exit 1
	harnessSelfName="$HARNESS_SELF_NAME" harnessBad="" harnessOff=""
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessLimits.include"
	while IFS= read -r localOne ; do
		[ -n "$localOne" ] || continue
		if ( AgentsHarnessLimitsResolve "$localOne" "" "" ) 2> /dev/null ; then
			( AgentsHarnessLimitsResolve "$localOne" "" "" 2> /dev/null ; printf '%s\t%s\t%s\t%s\t%s\n' "$localOne" "$( AgentsHarnessOpenModelProfile "$localOne" )" "$harnessWindowTokens" "$harnessOutputTokens" "$harnessNoneForm" )
		else
			printf '%s\t%s\t-\t-\t-\n' "$localOne" "$( AgentsHarnessOpenModelProfile "$localOne" )"
		fi
	done <<< "$localIds"
	exit 0
fi

## --- prompt_cache_key: off by default here ---------------------------------
## UNOBSERVED against a local server, which may refuse a body field it does not know.
HARNESS_PROMPT_CACHE_KEY="${HARNESS_PROMPT_CACHE_KEY:-off}"

export HARNESS_PROMPT_CACHE_KEY
## The service's own web search (AgentsHarnessSearchNative): none; this leg is our own engine, which has no search of its own, so WebSearch is DuckDuckGo's.
HARNESS_WEB_SEARCH="none"
export HARNESS_WEB_SEARCH

export HARNESS_PROVIDER_NAME HARNESS_SELF_NAME HARNESS_ENDPOINT HARNESS_HOST
export HARNESS_WIRE HARNESS_CREDENTIAL_NAMES
export HARNESS_MODEL_LIGHT HARNESS_MODEL_MAIN HARNESS_TOKEN_LIGHT HARNESS_TOKEN_MAIN
export HARNESS_MODEL_TABLE HARNESS_MODEL_FROM_LIGHT HARNESS_MODEL_FROM_MAIN

## exec, not source: the core becomes this process, so the console keeps one
## invoker. The core resolves its own helper lookups from the origin, not from $0.
exec "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsUniversalHarness.sh" "$@"
