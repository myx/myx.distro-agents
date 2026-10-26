#!/usr/bin/env bash
## Behavioural check on the DeepSeek Harness home patch that --make-workspace-integrations
## writes as part of its harness MCP config step: one myx-distro MCP client row in
## $HOME/.dsh/cordis.patch.yml, the file DSH applies over every profile.
##
## Held: with a DSH home and no patch file the row is created; a second run leaves the file
## byte for byte and says nothing changed; a row that is not ours is kept, one of ours
## carrying old values is replaced in place once, and a markerless row left by the hand
## install is adopted rather than duplicated; a machine with no DSH home gets neither file
## nor failure; the row's command, args and env are the workspace's own; and the step's own
## lines carry no absolute path. The merged file is read back with a real YAML parser
## where one exists -- ruby's psych, else python3's yaml -- and the assertion says it was
## skipped where none does. The workspace, its HOME, a private origin and the myx.common
## and myx.distro-source under them are all this rig's own; nothing of the package and
## nothing of the real HOME is written.
##
## RED RECIPE (live, before this feature): the live integrations run writes no
## $HOME/.dsh/cordis.patch.yml and prints no line naming DeepSeek Harness. From this
## sandbox, with a pristine package copy as the origin:
##   MMDAPP=<scratch workspace> MDLT_ORIGIN=<pristine copy>/.. \
##     bash <patched copy>/sh-test/AgentsHarnessDshInstallCheck.test.sh
## Expected red, one cause: FAIL "the DeepSeek Harness home patch is created" (got none)
## and FAIL "the step says it installed the row" (got 0). Every later assertion fails on
## the same absent file, not on a second fault.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigOrigin="${MDLT_ORIGIN:-$MMDAPP/.local}"
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigLocalContext="$rigOrigin/myx/myx.distro-.local/sh-lib/LocalContext.include"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigTool" ] || rigRefuse "the dispatcher is not at the origin: $rigTool"
[ -f "$rigLocalContext" ] || rigRefuse "LocalContext.include is not at the origin: $rigLocalContext"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessDshInstallCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

## The command's origin is this check's own: the package under test by link, the two
## siblings the workspace needs by link, and a minimal myx.distro-source. The source scan
## is not this check's subject, and a sandbox may carry no source package; the stub makes
## the run end 0 with no project instead of depending on the origin's composition.
[ -d "$rigOrigin/myx/myx.distro-system" ] || rigRefuse "myx.distro-system is not at the origin: $rigOrigin/myx/myx.distro-system"
rigToolOrigin="$rigTmp/origin"
mkdir -p "$rigToolOrigin/myx"
ln -s "$rigPackage" "$rigToolOrigin/myx/myx.distro-agents"
ln -s "$rigOrigin/myx/myx.distro-system" "$rigToolOrigin/myx/myx.distro-system"
ln -s "$rigOrigin/myx/myx.distro-.local" "$rigToolOrigin/myx/myx.distro-.local"
rigSourceStub="$rigToolOrigin/myx/myx.distro-source"
mkdir -p "$rigSourceStub/sh-scripts" "$rigSourceStub/sh-lib/source-prepare"
cat > "$rigSourceStub/sh-scripts/DistroSourceTools.fn.sh" <<'SH'
#!/usr/bin/env bash
ListDistroProjects(){ return 0 ; }
ListDistroDeclares(){ return 0 ; }
ListDistroNamespaces(){ return 0 ; }
DistroSourceTools(){ return 0 ; }
SH
printf '# a rig source scan: no project\nreturn 0\n' > "$rigSourceStub/sh-lib/source-prepare/ScanSourceProjects.include"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigCount(){ ## file, fixed text -- how many lines of that file are exactly that text
	LC_ALL=C grep -c -x -F -- "$2" "$1" 2> /dev/null || :
}
rigHolds(){ ## file, fixed text -- how many lines of that file hold it
	LC_ALL=C grep -c -F -- "$2" "$1" 2> /dev/null || :
}
rigCksum(){ ## file -- its checksum, or no-file
	[ -f "$1" ] && cksum < "$1" || printf 'no-file\n'
}

## The workspace the integrations run sees: its own source folder (empty), and a myx.common
## of the rig's own with only what the harness MCP step runs -- its server script, its home
## setup and the JSON escaper. The origin the command runs from is private to this rig and
## carries a minimal myx.distro-source, so no source tree or project is read. The rig's HOME
## is its own and no call may leave this tree.
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigNoDsh="$rigTmp/home-no-dsh"
mkdir -p "$rigWs/.local/myx" "$rigWs/source" "$rigWs/.local/.agents" "$rigHome/.dsh" "$rigNoDsh"
for rigPackageDir in "$rigOrigin"/myx/* ; do
	[ -d "$rigPackageDir" ] || continue
	[ "${rigPackageDir##*/}" = "myx.common" ] && continue
	ln -s "$rigPackageDir" "$rigWs/.local/myx/${rigPackageDir##*/}" || rigRefuse "cannot link ${rigPackageDir##*/} into the rig workspace"
done
rigMcpRoot="$rigWs/.local/myx/myx.common/os-myx.common/host/tarball/share/myx.common"
mkdir -p "$rigMcpRoot/bin/lib" "$rigMcpRoot/bin/setup" "$rigMcpRoot/include/data"
printf '#!/usr/bin/env bash\nexit 0\n' > "$rigMcpRoot/bin/lib/agentMcpServer.Common"
printf '#!/usr/bin/env bash\nprintf "{}\\n" > "${HOME:?}/.claude.json"\nexit 0\n' > "$rigMcpRoot/bin/setup/agentMcp.Common"
chmod +x "$rigMcpRoot/bin/lib/agentMcpServer.Common" "$rigMcpRoot/bin/setup/agentMcp.Common"
cat > "$rigMcpRoot/include/data/agentMcpJsonEscape.awk" <<'AWK'
BEGIN { ORS = "" }
{
	gsub(/\\/, "\\\\")
	gsub(/"/, "\\\"")
	printf "%s", $0
}
AWK

rigPath="/usr/bin:/bin:/usr/sbin:/sbin"
rigPatch="$rigHome/.dsh/cordis.patch.yml"
rigRc=0
rigRun(){ ## home, arguments...
	rigRc=0
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$1" PATH="$rigPath" MMDAPP="$rigWs" MDLT_ORIGIN="$rigToolOrigin" \
		MDLT_OPTION="--run-from-path $rigToolOrigin" \
		python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 300 -- bash "$rigTool" "${@:2}" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigStepLines(){ ## -- this run's lines that name the harness, the step's own
	LC_ALL=C grep -F -- 'DeepSeek Harness' "$rigTmp/err" || :
}
rigRowValue(){ ## patch file -- the myx-distro row as serverName|transport|command|args|MMDAPP|failOnStartupError
	[ -f "$1" ] || return 0
	case "$rigYaml" in
		ruby)
			ruby -ryaml -e '
doc = YAML.load_file(ARGV[0])
rows = []
if doc.is_a?(Array)
  doc.each do |item|
    next unless item.is_a?(Hash) && item["insert"].is_a?(Array)
    item["insert"].each do |entry|
      next unless entry.is_a?(Hash) && entry["id"] == "myx-distro-mcp"
      c = entry["config"].is_a?(Hash) ? entry["config"] : {}
      e = c["env"].is_a?(Hash) ? c["env"] : {}
      rows << [c["serverName"], c["transport"], c["command"], Array(c["args"]).join(" "), e["MMDAPP"], c["failOnStartupError"].to_s].join("|")
    end
  end
end
puts rows
' "$1"
		;;
		python3)
			python3 -c '
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
rows = []
if isinstance(doc, list):
    for item in doc:
        if isinstance(item, dict) and isinstance(item.get("insert"), list):
            for entry in item["insert"]:
                if isinstance(entry, dict) and entry.get("id") == "myx-distro-mcp":
                    c = entry.get("config") or {}
                    e = c.get("env") or {}
                    rows.append("|".join([str(c.get("serverName")), str(c.get("transport")), str(c.get("command")),
                        " ".join(c.get("args") or []), str(e.get("MMDAPP")), str(c.get("failOnStartupError")).lower()]))
print("\n".join(rows))
' "$1"
		;;
	esac
}

## A parser the check provides itself, not one the installer needs: the writer must be right
## without one, and this is what proves the result is YAML where the tool exists.
rigYaml=""
if command -v ruby > /dev/null 2>&1 && ruby -ryaml -e 'exit 0' > /dev/null 2>&1 ; then
	rigYaml="ruby"
elif command -v python3 > /dev/null 2>&1 && python3 -c 'import yaml' > /dev/null 2>&1 ; then
	rigYaml="python3"
fi
rigWantRow="myx-distro|stdio|$rigWs/.local/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh|--intern-mcp-server --run|$rigWs|false"
rigRowAssert(){ ## label, patch file
	if [ -n "$rigYaml" ] ; then
		rigAssert "$1" "$( rigRowValue "$2" )" "$rigWantRow"
	else
		printf '  SKIP  %s (no YAML parser here: ruby with psych, or python3 with yaml)\n' "$1"
	fi
}

echo "-- 1. a DSH home and no patch file: the row is created --"
rigRun "$rigHome" --make-workspace-integrations --quiet
rigAssert "the integrations run ends 0"                                  "$rigRc" 0
rigAssert "the DeepSeek Harness home patch is created"                   "$( [ -f "$rigPatch" ] && echo file || echo none )" file
rigAssert "the step says it installed the row"                           "$( rigStepLines | LC_ALL=C grep -c -F 'DeepSeek Harness home patch installed' || : )" 1
rigAssert "the step's own lines carry no absolute path"                  "$( rigStepLines | LC_ALL=C grep -c '/' || : )" 0
rigAssert "the row is in the file once"                                  "$( rigCount "$rigPatch" '    - id: myx-distro-mcp' )" 1
rigAssert "its command is the workspace's own installed tool"            "$( rigCount "$rigPatch" "        command: '$rigWs/.local/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh'" )" 1
rigAssert "its env names the workspace"                                  "$( rigCount "$rigPatch" "          MMDAPP: '$rigWs'" )" 1
rigAssert "it carries no other workspace's env"                          "$( rigHolds "$rigPatch" 'MDLT_ORIGIN' )" 0
rigRowAssert "the merged file is valid YAML and the row says what it must" "$rigPatch"

echo "-- 2. a second run changes nothing and says so --"
rigBefore="$( [ -f "$rigPatch" ] && rigCksum "$rigPatch" || printf 'first-run-wrote-no-file\n' )"
rigRun "$rigHome" --make-workspace-integrations --quiet
rigAssert "the second run ends 0"                                        "$rigRc" 0
rigAssert "the patch is byte for byte what the first run wrote"          "$( rigCksum "$rigPatch" )" "$rigBefore"
rigAssert "the step says nothing changed"                                "$( rigStepLines | LC_ALL=C grep -c -F 'nothing changed' || : )" 1
rigAssert "the row is still written once"                                "$( rigCount "$rigPatch" '    - id: myx-distro-mcp' )" 1

echo "-- 3. another row is kept, and a row of ours with old values is replaced in place --"
{
	printf '%s\n' '- insert:'
	printf '%s\n' '    - id: rig-unrelated'
	printf '%s\n' "      name: '@deepseek-ai/dsh-other'"
	printf '%s\n' '      config:'
	printf '%s\n' '        keep: me'
} >> "$rigPatch"
rigOldWs="$rigTmp/moved-workspace"
LC_ALL=C awk -v old="$rigOldWs" 'BEGIN { q = sprintf("%c", 39) }
	/^        command: / { print "        command: " q old "/DistroAgentsTools.fn.sh" q ; next }
	/^          MMDAPP: / { print "          MMDAPP: " q old q ; next }
	{ print }
' "$rigPatch" > "$rigPatch.corrupt" && mv "$rigPatch.corrupt" "$rigPatch"
rigAssert "control: the row now holds the old workspace's values"        "$( rigHolds "$rigPatch" "$rigOldWs" )" 2
rigRun "$rigHome" --make-workspace-integrations --quiet
rigAssert "the run ends 0"                                               "$rigRc" 0
rigAssert "the other row is kept, once"                                  "$( rigCount "$rigPatch" '    - id: rig-unrelated' )" 1
rigAssert "and its own content is kept"                                  "$( rigCount "$rigPatch" '        keep: me' )" 1
rigAssert "our row is still written once"                                "$( rigCount "$rigPatch" '    - id: myx-distro-mcp' )" 1
rigAssert "its command is the workspace's own again"                     "$( rigCount "$rigPatch" "        command: '$rigWs/.local/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh'" )" 1
rigAssert "its env names the workspace again"                            "$( rigCount "$rigPatch" "          MMDAPP: '$rigWs'" )" 1
rigAssert "no old value is left"                                         "$( rigHolds "$rigPatch" "$rigOldWs" )" 0
rigAssert "the one managed block is replaced, not duplicated"            "$( rigHolds "$rigPatch" 'managed block, replaced on update' )" 1
rigRowAssert "the merged file is valid YAML and the row says what it must" "$rigPatch"

echo "-- 4. a row the hand install wrote, without markers: adopted, not duplicated --"
rigAdopt="$rigTmp/home-adopt" ; rigAdoptPatch="$rigAdopt/.dsh/cordis.patch.yml"
mkdir -p "$rigAdopt/.dsh"
rigOldWs="$rigTmp/hand-workspace"
{
	printf '%s\n' '# Home-level patch for dsh profiles: applied over every profile layer.'
	printf '%s\n' '- insert:'
	printf '%s\n' '    - id: myx-distro-mcp'
	printf '%s\n' "      name: '@deepseek-ai/dsh-mcp-client'"
	printf '%s\n' '      config:'
	printf '%s\n' '        serverName: myx-distro'
	printf '%s\n' '        transport: stdio'
	printf '%s\n' "        command: '$rigOldWs/DistroAgentsTools.fn.sh'"
	printf '%s\n' '        args:'
	printf '%s\n' '          - --intern-mcp-server'
	printf '%s\n' '          - --run'
	printf '%s\n' '        env:'
	printf '%s\n' "          MMDAPP: '$rigOldWs'"
	printf '%s\n' '        failOnStartupError: false'
	printf '%s\n' '- insert:'
	printf '%s\n' '    - id: rig-neighbour'
	printf '%s\n' "      name: '@deepseek-ai/dsh-other'"
	printf '%s\n' '      config:'
	printf '%s\n' '        keep: me'
} > "$rigAdoptPatch"
rigRun "$rigAdopt" --make-workspace-integrations --quiet
rigAssert "the run ends 0"                                               "$rigRc" 0
rigAssert "the hand-installed row is adopted, not duplicated"            "$( rigCount "$rigAdoptPatch" '    - id: myx-distro-mcp' )" 1
rigAssert "the step says the patch was updated"                          "$( rigStepLines | LC_ALL=C grep -c -F 'DeepSeek Harness home patch updated' || : )" 1
rigAssert "the marker block is written once"                             "$( rigHolds "$rigAdoptPatch" 'managed block, replaced on update' )" 1
rigAssert "the neighbour row is kept"                                    "$( rigCount "$rigAdoptPatch" '    - id: rig-neighbour' )" 1
rigAssert "and its content is kept"                                      "$( rigCount "$rigAdoptPatch" '        keep: me' )" 1
rigAssert "no hand-installed value is left"                              "$( rigHolds "$rigAdoptPatch" "$rigOldWs" )" 0
rigRowAssert "the adopted file is valid YAML and the row says what it must" "$rigAdoptPatch"

echo "-- 5. no DSH home: nothing is written and the run still succeeds --"
rigRun "$rigNoDsh" --make-workspace-integrations --quiet
rigAssert "the run on a machine without the harness ends 0"              "$rigRc" 0
rigAssert "no DSH home is made"                                          "$( [ -e "$rigNoDsh/.dsh" ] && echo made || echo none )" none
rigAssert "the step says the harness is not installed there"             "$( rigStepLines | LC_ALL=C grep -c -F 'DeepSeek Harness is not installed there' || : )" 1
rigAssert "and its lines carry no absolute path"                         "$( rigStepLines | LC_ALL=C grep -c '/' || : )" 0

echo
printf '  %s passed, %s failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" = "0" ]
