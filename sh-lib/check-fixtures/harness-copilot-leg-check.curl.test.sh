#!/usr/bin/env bash
## Records this round's argv, stdin and request body, and replays this round's canned
## stream. It opens no socket, and being first on PATH is the whole of this check's
## offline guarantee -- against a leaf whose own endpoint is the live one.
set -u
## Outside a scenario there is nothing to record into and nothing canned to replay, so a
## fake curl that somehow ran there dies rather than proxying the request onward.
[ -n "${RIG_SCENARIO:-}" ] && [ -d "$RIG_SCENARIO" ] || { printf 'rig: curl ran outside a scenario\n' >&2 ; exit 1 ; }
## The three renameable declarations, taken from the environment the leaf exported into
## this process: the core execs the leaf and assigns no HARNESS_* name of its own, so
## these ARE the leaf's. The endpoint, the host and the credential name are not here --
## the check pins those, so reading them would assert nothing.
printf '%s' "${HARNESS_PROVIDER_NAME:-}" > "$RIG_DECL_DIR/decl.provider"
printf '%s' "${HARNESS_MODEL_MAIN:-}" > "$RIG_DECL_DIR/decl.modelMain"
printf '%s' "${HARNESS_MODEL_LIGHT:-}" > "$RIG_DECL_DIR/decl.modelLight"
rigRound=$(( $( cat "$RIG_SCENARIO/round" ) + 1 ))
printf '%s' "$rigRound" > "$RIG_SCENARIO/round"
printf '%s\n' "$@" > "$RIG_SCENARIO/argv.$rigRound"
cat > "$RIG_SCENARIO/stdin.$rigRound"
while [ $# -gt 0 ] ; do
	case "$1" in
		-d) printf '%s' "${2:-}" > "$RIG_SCENARIO/req.$rigRound" ; shift 2 ;;
		*)  shift ;;
	esac
done
[ -f "$RIG_SCENARIO/res.$rigRound" ] || { printf 'rig: no canned stream for round %s\n' "$rigRound" >&2 ; exit 1 ; }
cat "$RIG_SCENARIO/res.$rigRound"
