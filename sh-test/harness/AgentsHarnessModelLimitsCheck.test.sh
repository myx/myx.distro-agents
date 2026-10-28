#!/usr/bin/env bash
## Behavioural check on the limits and the effort a harness run judges for the model it runs (AgentsHarnessLimits.include),
## from the family table each thin wrapper supplies (Agents{Claude,Copilot,Grok,Scaleway,Deepseek,StandardV1}Harness.sh).
## Each wrapper is sourced with exec stubbed, so its table is read as the core would get it. Held, per wrapper:
##   1. a model of each family gets the window, the output maximum and the restart threshold (window less output) of that family
##   2. the preset's PRESET_CONTEXT_MAX_SIZE sets the threshold ahead of the family's, and the operator's override ahead of that;
##      the window and the output stay the family's
##   3. a model of no family is refused with rc 1, and the refusal lists the families the leg knows
##   4. a leg with no table keeps the pair it declares
##   5. the effort: unset sends nothing, normal is medium, low and high are themselves, and none is sent as the family says
##      (its none, its lowest with the start line saying so, the thinking off, or nothing for a model that does not reason)
## Offline by construction: nothing is run but the wrappers' own assignments.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigLimits="$rigHere/harness/AgentsHarnessLimits.include"
[ -f "$rigLimits" ] || { echo "⛔ ERROR: not found at the origin this workspace resolves: $rigLimits -- refusing to report a result" >&2 ; exit 1 ; }
rigPassCount=0 rigFailCount=0
rigAssert(){ ## label, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 )) ; echo "  PASS  $1"
	else
		rigFailCount=$(( rigFailCount + 1 )) ; echo "  FAIL  $1" ; echo "        got:  $2" ; echo "        want: $3"
	fi
}
## The table a wrapper states, as the core would receive it: the wrapper sourced with exec stubbed and dummy credentials.
rigTable(){ ## wrapper file name
	( exec(){ return 0 ; }
	  export MDLT_ORIGIN ANTHROPIC_API_KEY=rig OPENAI_API_KEY=rig HARNESS_ENDPOINT_URL=https://rig.example/v1 HARNESS_MODEL_LIGHT=rig-model HARNESS_MODEL_MAIN=rig-model
	  unset HARNESS_MODEL_TABLE
	  . "$rigHere/harness/$1" > /dev/null 2>&1
	  printf '%s' "${HARNESS_MODEL_TABLE:-}" )
}
## window, output, threshold and none form that the table gives a model; or REFUSED and the refusal.
rigJudge(){ ## table, model [env assignments...]
	local judgeTable="$1" judgeModel="$2" ; shift 2
	( export HARNESS_MODEL_TABLE="$judgeTable" harnessSelfName=rig-leg harnessBad="" harnessOff=""
	  unset PRESET_CONTEXT_MAX_SIZE MDAT_HARNESS_CONTEXT_TOKENS
	  while [ $# -gt 0 ] ; do export "$1" ; shift ; done
	  . "$rigLimits"
	  if AgentsHarnessLimitsResolve "$judgeModel" "" "" 2> /dev/null ; then
		printf '%s %s %s %s' "$harnessWindowTokens" "$harnessOutputTokens" "$harnessContextTokens" "$harnessNoneForm"
	  else
		printf 'REFUSED %s' "$( AgentsHarnessLimitsResolve "$judgeModel" "" "" 2>&1 > /dev/null )"
	  fi )
}
rigEffort(){ ## none form, effort -- what the wire is given: reasoning effort, thinking off, the note
	( . "$rigLimits" ; harnessNoneForm="$1" ; harnessEffort="$2" ; AgentsHarnessEffortApply
	  printf '[%s] [%s] [%s]' "$harnessReasoningEffort" "$harnessThinkingOff" "$harnessEffortNote" )
}

rigCase(){ ## wrapper, table, model, want "window output threshold noneform"
	rigAssert "$1: $3" "$( rigJudge "$2" "$3" )" "$4"
}

echo "-- 1. each family of each wrapper --"
rigClaude="$( rigTable AgentsClaudeHarness.sh )"
## each row read from the vendor's own page on 2026-10-28 (the source and date are in the row): the legacy Haiku 4.5 and Opus 4.5 are 200K and 64K, the current models 1M and 128K
rigCase claude "$rigClaude" claude-haiku-4-5  "200000 64000 136000 thinking:disabled"
rigCase claude "$rigClaude" claude-haiku-5-5  "1000000 128000 872000 thinking:disabled"
## the none form per model, from the vendor's page of 2026-10-28: Fable 5 and 5.1 and Opus 5.5 think always ("Adaptive (always on)"), Sonnet 5.5 rejects thinking disabled; the effort none of those is refused, not remapped
rigCase claude "$rigClaude" claude-opus-4-5   "200000 64000 136000 thinking:disabled"
rigCase claude "$rigClaude" claude-sonnet-5-5 "1000000 128000 872000 refuse"
rigCase claude "$rigClaude" claude-opus-5-5   "1000000 128000 872000 refuse"
rigCase claude "$rigClaude" claude-fable-5    "1000000 128000 872000 refuse"
rigCase claude "$rigClaude" claude-fable-5-1  "1000000 128000 872000 refuse"
rigCopilot="$( rigTable AgentsCopilotHarness.sh )"
rigCase copilot "$rigCopilot" gpt-5.6-sol    "272000 32768 239232 effort:none"
rigCase copilot "$rigCopilot" claude-fable-5 "1000000 65536 934464 effort:low"
rigDeepseek="$( rigTable AgentsDeepseekHarness.sh )"
rigCase deepseek "$rigDeepseek" deepseek-flash   "1048576 384000 664576 thinking:disabled"
rigCase deepseek "$rigDeepseek" deepseek-v4-pro  "1048576 384000 664576 thinking:disabled"
rigGrok="$( rigTable AgentsGrokHarness.sh )"
rigCase grok "$rigGrok" grok-4.3 "1000000 30000 970000 effort:none"
rigCase grok "$rigGrok" grok-4.7 "500000 65536 434464 effort:low"
rigScaleway="$( rigTable AgentsScalewayHarness.sh )"
rigCase scaleway "$rigScaleway" deepseek-v4-flash-0731 "256000 32768 223232 effort:low"
rigCase scaleway "$rigScaleway" gemma-3-27b-it         "40000 8192 31808 omit"
rigCase scaleway "$rigScaleway" gemma-4-26b-a4b-it     "256000 32768 223232 omit"
## Scaleway takes any model the user's key serves (sketch 13.2): a model no row was read for gets the open table's default
rigAssert "scaleway: a gemma of a size the page gives no serverless figure for gets the default, not gemma-3's" "$( rigJudge "$rigScaleway" gemma-4-31b-it )" "32768 8192 24576 omit"
rigAssert "scaleway: a model of no family gets the default, not a refusal" "$( rigJudge "$rigScaleway" mystery-model-9 )" "32768 8192 24576 omit"
rigStandard="$( rigTable AgentsStandardV1Harness.sh )"
rigCase standard-v1 "$rigStandard" qwen3-4b          "32768 4096 28672 thinking:disabled"
rigCase standard-v1 "$rigStandard" qwen3.5-9b-q8_0   "262144 32768 229376 thinking:disabled"
rigCase standard-v1 "$rigStandard" qwen3.8-27b-q8_0  "262144 131072 131072 thinking:disabled"
rigLocal="$( rigTable AgentsLocalHarness.sh )"
rigCase local "$rigLocal" qwen3.5-9b-q8_0             "262144 32768 229376 thinking:disabled"
rigCase local "$rigLocal" qwen3.8-27b-q8_0            "262144 131072 131072 thinking:disabled"
rigCase standard-v1 "$rigStandard" qwen3:8b          "32768 8192 24576 thinking:disabled"
rigCase standard-v1 "$rigStandard" Qwen3_14B-Instruct "32768 8192 24576 thinking:disabled"
rigCase standard-v1 "$rigStandard" qwen3-14b         "32768 8192 24576 thinking:disabled"
rigCase standard-v1 "$rigStandard" qwen3-32b         "32768 8192 24576 thinking:disabled"
rigCase standard-v1 "$rigStandard" gemma3:4b         "131072 4096 126976 omit"
rigCase standard-v1 "$rigStandard" gemma3:12b        "131072 8192 122880 omit"
rigCase standard-v1 "$rigStandard" gemma-3-27b-it    "131072 8192 122880 omit"
rigCase standard-v1 "$rigStandard" deepseek-r1:14b   "131072 16384 114688 thinking:disabled"
rigCase standard-v1 "$rigStandard" deepseek-r1       "131072 32768 98304 thinking:disabled"
rigCase standard-v1 "$rigStandard" llama3.1:8b       "131072 8192 122880 omit"
rigCase standard-v1 "$rigStandard" gemma-3-4b-it     "131072 4096 126976 omit"
rigCase standard-v1 "$rigStandard" llama-3.2-3b      "131072 8192 122880 omit"
## a generic row is only as wide as the versions its figures were read for (2026-10-28): Gemma 3 (128k), Llama 3.1, 3.2 and 3.3 (128k), DeepSeek-R1 distills (131072); a model of any other version
## or family gets the reasonable default of the open table (sketch 13.1: "the universal standard-v1 default is reasonable"), with one note on standard error, and is never refused
for rigOther in gemma-3n-e4b gemma2:9b gemma-4-31b-it llama-3-8b-instruct llama3:8b llama-4-scout llama2:13b deepseek-v3.2 deepseek-v4-flash mistral-7b-instruct ; do
	rigAssert "standard-v1: $rigOther is of no row this table was read for, so it gets the default limits, not a refusal" "$( rigJudge "$rigStandard" "$rigOther" )" "32768 8192 24576 omit"
done
rigAssert "and the default says so, once, on standard error, naming the model and the way to set its own threshold" "$( ( export HARNESS_MODEL_TABLE="$rigStandard" harnessSelfName=rig-leg harnessBad="" harnessOff="" ; unset PRESET_CONTEXT_MAX_SIZE MDAT_HARNESS_CONTEXT_TOKENS ; . "$rigLimits" ; AgentsHarnessLimitsResolve mistral-7b-instruct "" "" 2>&1 > /dev/null ) )" "rig-leg: the model 'mistral-7b-instruct' is of no family this table was read for, so the default limits apply (window 32768, output 8192); a preset that knows its server's window sets PRESET_CONTEXT_MAX_SIZE"
rigAssert "a model that has a row says nothing" "$( ( export HARNESS_MODEL_TABLE="$rigStandard" harnessSelfName=rig-leg harnessBad="" harnessOff="" ; . "$rigLimits" ; AgentsHarnessLimitsResolve qwen3-8b "" "" 2>&1 > /dev/null ) | wc -c | LC_ALL=C tr -d ' ' )" 0
rigAssert "the DeepSeek-R1 distills keep their rows (131072)" "$( rigJudge "$rigStandard" deepseek-r1-distill-llama-8b | LC_ALL=C cut -d' ' -f1,2 ) $( rigJudge "$rigStandard" DeepSeek-R1-Distill-Qwen-14B | LC_ALL=C cut -d' ' -f1,2 )" "131072 16384 131072 16384"
rigCase standard-v1 "$rigStandard" Llama-3.3-70B     "131072 8192 122880 omit"
rigAssert "every wrapper states a table" "$( for rigOne in "$rigClaude" "$rigCopilot" "$rigDeepseek" "$rigGrok" "$rigScaleway" "$rigStandard" ; do [ -n "$rigOne" ] && printf y || printf n ; done )" yyyyyy

echo "-- 2. the preset's size, and the operator's --"
for rigWrapper in claude:claude-opus-5-5:1000000:128000 copilot:gpt-5.6-sol:272000:32768 deepseek:deepseek-flash:1048576:384000 grok:grok-4.3:1000000:30000 scaleway:gemma-3-27b-it:40000:8192 standard-v1:qwen3-8b:32768:8192 ; do
	IFS=: read -r rigName rigModel rigWindow rigOutput <<< "$rigWrapper"
	case "$rigName" in claude) rigT="$rigClaude" ;; copilot) rigT="$rigCopilot" ;; deepseek) rigT="$rigDeepseek" ;; grok) rigT="$rigGrok" ;; scaleway) rigT="$rigScaleway" ;; *) rigT="$rigStandard" ;; esac
	rigAssert "$rigName: the preset's 50000 is the threshold, the family's window and output stay" "$( rigJudge "$rigT" "$rigModel" PRESET_CONTEXT_MAX_SIZE=50000 | LC_ALL=C awk '{ print $1, $2, $3 }' )" "$rigWindow $rigOutput 50000"
	rigAssert "$rigName: the operator's 40000 stands ahead of the preset's" "$( rigJudge "$rigT" "$rigModel" PRESET_CONTEXT_MAX_SIZE=50000 MDAT_HARNESS_CONTEXT_TOKENS=40000 | LC_ALL=C awk '{ print $3 }' )" 40000
done

echo "-- 3. a model of no family is refused, with the families listed (the hosted legs; standard-v1, local and scaleway give the default of section 1 instead) --"
for rigName in claude copilot deepseek grok ; do
	case "$rigName" in claude) rigT="$rigClaude" ;; copilot) rigT="$rigCopilot" ;; deepseek) rigT="$rigDeepseek" ;; grok) rigT="$rigGrok" ;; scaleway) rigT="$rigScaleway" ;; *) rigT="$rigStandard" ;; esac
	rigOut="$( rigJudge "$rigT" mystery-model-9 )"
	rigFirst="$( printf '%s\n' "$rigT" | LC_ALL=C awk -F'|' 'NR == 1 { print $1 }' )"
	rigRefusal="no: $rigOut"
	case "$rigOut" in
		REFUSED*mystery-model-9*"$rigFirst"*) rigRefusal=yes ;;
	esac
	rigAssert "$rigName: refused, naming the model and the first family" "$rigRefusal" yes
done
rigAssert "the preset's size does not make a model of no family known" "$( rigJudge "$rigClaude" mystery-model-9 PRESET_CONTEXT_MAX_SIZE=50000 | LC_ALL=C cut -c1-7 )" REFUSED

## Scaleway's credential is the one key the user generates (sketch 13.2); the old per-model names are not read, and it says so
rigScalewayCred(){ ## env assignments...
	( exec(){ return 0 ; } ; unset SCALEWAY_API_KEY SCALEWAY_DEEPSEEK SCALEWAY_GEMMA
	  while [ $# -gt 0 ] ; do export "$1" ; shift ; done
	  ( . "$rigHere/harness/AgentsScalewayHarness.sh" 2>&1 > /dev/null ) | LC_ALL=C grep -c 'reads SCALEWAY_API_KEY' | LC_ALL=C tr -d ' '
	  . "$rigHere/harness/AgentsScalewayHarness.sh" > /dev/null 2>&1
	  printf '%s|%s|%s\n' "$HARNESS_CREDENTIAL_NAMES" "$HARNESS_TOKEN_MAIN" "$HARNESS_TOKEN_LIGHT" )
}
rigAssert "scaleway: one credential name, SCALEWAY_API_KEY, and both tokens are that key" "$( rigScalewayCred SCALEWAY_API_KEY=k1 | LC_ALL=C tr '\n' ' ' )" "0 SCALEWAY_API_KEY|k1|k1 "
rigAssert "scaleway: a per-model name alone gives no token, and the leg says it reads SCALEWAY_API_KEY" "$( rigScalewayCred SCALEWAY_DEEPSEEK=k2 SCALEWAY_GEMMA=k3 | LC_ALL=C tr '\n' ' ' )" "1 SCALEWAY_API_KEY|| "

echo "-- 4. a leg with no table --"
rigAssert "it keeps the pair it declares, and its threshold is the window less the output" "$( ( unset HARNESS_MODEL_TABLE PRESET_CONTEXT_MAX_SIZE MDAT_HARNESS_CONTEXT_TOKENS ; . "$rigLimits" ; AgentsHarnessLimitsResolve anything-1 128000 16384 && printf '%s %s %s' "$harnessWindowTokens" "$harnessOutputTokens" "$harnessContextTokens" ) )" "128000 16384 111616"

echo "-- 5. the effort --"
rigAssert "unset sends nothing"                       "$( rigEffort effort:none unset )"        "[] [] [effort unset, the model's default]"
rigAssert "low is low"                                "$( rigEffort effort:none low )"          "[low] [] [effort low]"
rigAssert "high is high"                              "$( rigEffort effort:none high )"         "[high] [] [effort high]"
rigAssert "normal is medium"                          "$( rigEffort effort:none normal )"       "[medium] [] [effort normal, sent as medium]"
rigAssert "none of a family that has none: its none"  "$( rigEffort effort:none none )"         "[none] [] [effort none, sent as none]"
rigAssert "none of a family with no none: its lowest, said so"  "$( rigEffort effort:low none )"  "[low] [] [effort none, sent as low: this service has no none, so its lowest]"
rigAssert "none of a family that switches thinking off"  "$( rigEffort thinking:disabled none )"  "[] [1] [effort none, the thinking is off]"
rigRefuseEffort(){ ## model, effort -- the return code and the error of an effort the model refuses, under the none form refuse
	( . "$rigLimits" ; harnessNoneForm=refuse ; harnessEffort="$2" ; harnessModel="$1" ; harnessSelfName=rig-leg ; harnessBad="" ; harnessOff=""
	  if refuseErr="$( AgentsHarnessEffortApply 2>&1 )" ; then printf 'accepted' ; else printf 'refused %s' "$refuseErr" ; fi )
}
rigAssert "none of a model whose thinking cannot be switched off: refused, naming the model and the efforts it takes, and nothing sent" "$( rigRefuseEffort claude-opus-5-5 none )" "refused ⛔ ERROR: rig-leg: the model 'claude-opus-5-5' cannot have its reasoning switched off, so the effort none is refused. It takes: unset, low, normal, high."
rigAssert "the core stops a start whose effort the model refuses: the apply is followed by an exit, and a change mid-run keeps the effort it had" "$( LC_ALL=C grep -c '^AgentsHarnessEffortApply || exit 1$' "$rigHere/harness/AgentsUniversalHarness.sh" ) $( LC_ALL=C grep -c 'was refused for' "$rigHere/harness/AgentsUniversalHarness.sh" )" "1 1"
rigAssert "the other efforts of that model are accepted" "$( rigRefuseEffort claude-opus-5-5 high ) $( rigRefuseEffort claude-opus-5-5 unset )" "accepted accepted"
rigAssert "none of a model that does not reason: nothing sent"  "$( rigEffort omit none )"     "[] [] [effort none, nothing to send: this model does not reason]"

if [ "$rigFailCount" -gt 0 ] ; then
	printf '⛔ HARNESS MODEL LIMITS CHECK FAILED: %d of %d assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))" >&2
	exit 1
fi
printf 'HARNESS_MODEL_LIMITS: OK (%d assertions, offline)\n' "$rigPassCount"
