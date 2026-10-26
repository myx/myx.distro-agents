#!/bin/sh
## The stand-in for setup.feature-lancedb/host/install/feature-lancedb.install.txt, which `--install-knowledge-store` calls
## (sh-test/config/AgentsKnowledgeStoreInstallCheck.test.sh). It installs nothing: it logs the call and the two variables the
## installer hands over, says one line on standard error, prints one Python on standard output where it ends 0, and ends with
## the rc the scenario asks for (RIG_FEATURE_RC: 0 installed, 1 refused or failed, 3 this platform is not covered).
{
	printf 'CALL'
	for featureArg in "$@" ; do printf ' %s' "$featureArg" ; done
	printf '\n'
	printf 'ENV MMDAPP=%s\n' "$MMDAPP"
	printf 'ENV MDLT_ORIGIN=%s\n' "$MDLT_ORIGIN"
} >> "${RIG_FEATURE_LOG:?}"
echo "setup.feature-lancedb: the stand-in said this" >&2
[ "${RIG_FEATURE_RC:-0}" != 0 ] || printf '%s\n' "${RIG_FEATURE_PYTHON:-$MMDAPP/.local/lancedb/venv/bin/python}"
exit "${RIG_FEATURE_RC:-0}"
