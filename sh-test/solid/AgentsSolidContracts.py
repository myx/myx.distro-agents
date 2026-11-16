#!/usr/bin/env python3
## AgentsSolidContracts.py -- the breaches of an internal contract in myx.distro-agents, one row each:
## `<class>\t<file>:<line>\t<detail>`, for AgentsSolidBreachScan.sh to prioritise. A broken call fails at run time on the
## path that reaches it, and a broken file contract gives stale data while every check stays green, so these come first.
## Classes:
##   unreached       a call to a package function whose file is not loaded on the path to the call: in the calling
##                   function, in the file, or by every file that loads this one at that place. A load inside a case
##                   branch counts for that branch only. Text inside quotes and heredocs is no call.
##   silent-load     a load of a package file that discards its stderr or falls back silently (`|| :`, `|| true`,
##                   `|| return 0`, `|| exit 0`, `|| continue`): a missing or broken library reads as stale data.
##   optional-call   a package function called only if it happens to be loaded (`type F ... && F`, `if type F`,
##                   `! type F ... || F`).
##   load-missing    a load of a package file, by a literal path, that no file answers: the call fails at run time.
##   guarded-op      a dispatcher arm whose result is a sourced file's (`. file` then `return $?`) behind a guard: the
##                   file runs its operation when sourced, so a guard makes a second call in one process do nothing.
##   dual-use        a library that runs a command at its load, or a file sourced with a dummy word to reach its functions.
##   duplicate-def   one function name defined twice: the first copy is dead, or two files race on load order.
##   dead            a function defined and named nowhere else in the package.
##   guard-target    a guarded load `type F ... || . file` whose file does not define F: the guard either never
##                   loads, or loads a file that leaves F undefined, so the call fails, or reads stale data, on its path.
##   guard-name      a guarded load whose F is defined in its file but not called by the code it guards: it works
##                   until a split moves the function that code calls, then fails silently on that path.
## Left out on purpose: the universal harness's served-mode stubs (AgentsUniversalHarness.sh), the two wire
## implementations that share one interface (AgentsOpenAiChatWire.sh, AgentsAnthropicMessagesWire.sh), the client
## hooks (each a standalone script), a define-once guard (`if ! type F ; then F(){`), a self-replacing lazy stub
## (`type F || F(){ unset -f F ; . file ; F "$@" ; }`), and the entry scripts' bootstrap DistroAgentsContext.
## Usage: AgentsSolidContracts.py <package root>
import collections, glob, os, re, sys

root = sys.argv[1]
os.chdir(root)
code = sorted(f for f in glob.glob('sh-lib/**/*', recursive=True) + glob.glob('sh-scripts/*.sh')
              if os.path.isfile(f) and (f.endswith('.include') or f.endswith('.sh'))
              and '/client-hooks/' not in f and '.include-green' not in f and not f.endswith('template.sh'))
text = {f: open(f, errors='replace').read() for f in code}
fnRe = re.compile(r'^([A-Za-z_][A-Za-z0-9_]*)\(\)\s*\{?\s*(?:#.*)?$')
loadRe = re.compile(r'(?:^\s*|[;&|(]\s*|\$\(\s*|\{\s*|\bthen\s+|\bdo\s+|\belse\s+|\bif\s+)\.\s+"\$MDLT_ORIGIN/myx/myx\.distro-agents/((?:sh-lib|sh-scripts)/[A-Za-z0-9._/-]+)"')
callRe = re.compile(r'(?:^|[;|&(`]|\$\(|\bthen\b|\bdo\b|\belse\b|\bif\b|\bwhile\b|\buntil\b|!|\{)\s*([A-Za-z_][A-Za-z0-9_]*)\b')
rows = []
def row(cls, f, n, detail): rows.append(f'{cls}\t{f}:{n}\t{detail}')

# --- the load graph and the calls
defs, top, fnLoads, fnCalls, topCalls, loadSites = {}, {}, {}, {}, {}, {}
for r in code:
    top[r], fnLoads[r], fnCalls[r], topCalls[r] = set(), {}, {}, []
    cur = None ; prevSt = '' ; heredoc = None ; ifTyped = {} ; inSq = False
    for n, line in enumerate(text[r].split('\n'), 1):
        if heredoc:
            if line.strip() == heredoc: heredoc = None
            continue
        ## a single-quoted string that spans lines is text, not code, on every line it covers
        quotes = re.sub(r'"(?:[^"\\]|\\.)*"', '', line.split(' #')[0] if not line.lstrip().startswith('#') else '').count("'")
        if inSq:
            if quotes % 2: inSq = False
            continue
        if quotes % 2: inSq = True
        hm = re.search(r"<<-?\s*'?\"?([A-Za-z_]+)'?\"?", line)
        if hm and '<<<' not in line: heredoc = hm.group(1)
        s = '' if line.lstrip().startswith('#') else line
        m = fnRe.match(line)
        if m:
            cur = m.group(1) ; defs.setdefault(cur, r) ; fnLoads[r][cur] = set() ; fnCalls[r][cur] = []
            continue
        if cur and line == '}':
            cur = None ; continue
        st = s.strip()
        branch = bool(re.match(r'^[^()#"]*[^\s(]\)\s*\.\s', st)) or (st.startswith('. ') and prevSt.endswith(')') and not prevSt.endswith('$( )'))
        for lm in loadRe.finditer(s):
            p = lm.group(1)
            if not branch: (fnLoads[r][cur] if cur else top[r]).add(p)
            loadSites.setdefault(p, []).append((r, cur))
        if st: prevSt = st
        sc = re.sub(r"'[^']*'", "''", s)
        sc = re.sub(r'"(?:[^"\\$]|\\.|\$(?!\())*"', '""', sc)
        sc = re.sub(r'type [A-Za-z_]+ ?> ?/dev/null 2>&1 &&', '', sc)
        sc = re.sub(r'^\s*[A-Za-z0-9_*.|-]+\)(\s|$)', ' ', sc)
        for g in re.findall(r'\b(?:if|elif) type ([A-Za-z_]+)', sc): ifTyped[g] = n
        sc = re.sub(r'\b(?:if|elif) !? ?type .*', '', sc)
        for cm in callRe.finditer(sc):
            if n - ifTyped.get(cm.group(1), -99) <= 3: continue
            (fnCalls[r][cur] if cur else topCalls[r]).append((n, cm.group(1)))

def closure(seed):
    out, todo = set(), list(seed)
    while todo:
        p = todo.pop()
        if p in out: continue
        out.add(p) ; todo += list(top.get(p, ()))
    return out
allf = set(top)
ctx = {r: set(allf) for r in allf}
entries = {r for r in allf if r.startswith('sh-scripts/') or r not in loadSites}
for _ in range(40):
    changed = False
    for r in allf:
        if r in entries: new = closure({r})
        else:
            parts = [ctx[p] | closure(fnLoads[p].get(fn, set()) if fn else set()) for (p, fn) in loadSites[r] if p in ctx]
            new = closure({r}) | (set.intersection(*parts) if parts else set())
        if new != ctx[r]: ctx[r] = new ; changed = True
    if not changed: break
def prevLoads(r, n, g):
    lines = text[r].split('\n')
    return any(g in lines[k] for k in range(max(0, n - 3), n - 1))

## The two wire implementations share one interface (the header above): a call to a function
## whose defining file is a wire file is satisfied wherever the harness core loads the one
## selected wire (AgentsUniversalHarness.sh:1339, `[ -n "$harnessNeedsMcp" ] && . "$harnessWireFile"`).
## No guard load is ever added for one, since the core already loads the wire on every path
## that reaches a wire function.
wireFiles = {'sh-lib/harness/AgentsOpenAiChatWire.sh', 'sh-lib/harness/AgentsAnthropicMessagesWire.sh'}
## The MCP client enumerates servers as it loads, so no caller guard-loads it. The core
## loads it exactly when it loads the wire (AgentsUniversalHarness.sh:1435,
## `[ -z "$harnessNeedsMcp" ] || . "$harnessMcpFile"`), and the two files below are sourced
## on the same terms, so their calls into it are satisfied wherever the client is loaded.
mcpClientFile = 'sh-lib/harness/AgentsHarnessMcpClient.sh'
mcpClientReachedByCoreGated = {'sh-lib/harness/AgentsHarnessMcpResources.include', 'sh-lib/harness/AgentsHarnessRun.include'}
for r in sorted(allf):
    if r.startswith('sh-lib/harness/AgentsUniversalHarness.sh'): continue
    def check(calls, extra):
        have = ctx[r] | closure(extra) ; seen = set()
        for n, c in calls:
            g = defs.get(c)
            if not g or g == r or g in have or c in seen or c == 'DistroAgentsContext' or prevLoads(r, n, g): continue
            if g in wireFiles or (g == mcpClientFile and r in mcpClientReachedByCoreGated): continue
            seen.add(c) ; row('unreached', r, n, f'{c} of {g} is not loaded on this path')
    check(topCalls[r], set())
    for fn, calls in fnCalls[r].items(): check(calls, fnLoads[r][fn])

# --- silent loads, optional calls, dual use
pkgFn = set(defs)
for r in code:
    for n, line in enumerate(text[r].split('\n'), 1):
        if line.lstrip().startswith('#'): continue
        if re.search(r'\.\s+"\$MDLT_ORIGIN/myx/myx\.distro-agents/[^"]+"\s*(?:[^|;&]*\s)?(?:2>\s?/dev/null|>\s?/dev/null 2>&1)', line) \
           or re.search(r'\.\s+"\$MDLT_ORIGIN/myx/myx\.distro-agents/[^"]+"[^|;&]*\|\|\s*(?::|true|return 0|exit 0|continue)(?:\s|;|$|\))', line):
            row('silent-load', r, n, 'a package load that hides its failure')
        for m in re.finditer(r'(?:\bif !? ?type|type) ([A-Za-z_][A-Za-z0-9_]*) ?> ?/dev/null 2>&1( &&|\s*;\s*then)|! type ([A-Za-z_][A-Za-z0-9_]*) ?> ?/dev/null 2>&1 \|\|', line):
            f = m.group(1) or m.group(3)
            ## The family's entry functions are optional by design: the bootstrap asks for its context function the way
            ## myx.distro-source does (`! type DistroSystemContext`, sh-scripts/CleanSourceToCached.fn.sh:30), and a lazy tool
            ## entry falls back to running the same tool script, so neither reads stale data.
            if f in pkgFn and not re.match(r'^(DistroAgents[A-Za-z]*|Agent[A-Z][a-z]+Tools|Agents)$', f) and not re.search(r'if ! type ' + f + r'\b', line) and not re.search(r'type ' + f + r' > ?/dev/null 2>&1 &&\s*return\b', line) and not r.endswith('AgentsUniversalHarness.sh'):
                row('optional-call', r, n, f'{f} is called only if it happens to be loaded')
        if re.search(r'\.\s+"\$MDLT_ORIGIN/myx/myx\.distro-agents/sh-lib/[^"]+\.include"\s+--definitions-only', line):
            row('dual-use', r, n, 'a file sourced with a dummy word to reach its functions')
for r in code:
    if not r.endswith('.include') or r.endswith('AgentsTools.MyRoot.include'): continue
    lines = text[r].split('\n') ; depth = 0 ; hasFn = False
    for n, line in enumerate(lines, 1):
        if depth == 0 and fnRe.match(line): depth = 1 ; hasFn = True ; continue
        if depth == 1 and line == '}': depth = 0 ; continue
        if depth == 0 and hasFn:
            m = re.match(r'^([A-Z][A-Za-z0-9_]+)(\s|$)', line)
            if m and m.group(1) in pkgFn: row('dual-use', r, n, f'a library that runs {m.group(1)} at its load')

# --- duplicate definitions and dead functions
skipDup = ('AgentsUniversalHarness.sh', 'AgentsOpenAiChatWire.sh', 'AgentsAnthropicMessagesWire.sh')
where = collections.defaultdict(list)
for r in code:
    for n, line in enumerate(text[r].split('\n'), 1):
        m = re.match(r'^(\s*)([A-Za-z_][A-Za-z0-9_]*)\(\)', line)
        if m and not m.group(1) and not r.endswith(skipDup): where[m.group(2)].append((r, n))
for fn, locs in where.items():
    for r, n in locs[:-1]: row('duplicate-def', r, n, f'{fn} is defined again at {locs[-1][0]}:{locs[-1][1]}')
cnt = collections.Counter()
for f in glob.glob('**/*', recursive=True):
    if os.path.isfile(f) and not f.endswith('.keep') and '.include-green' not in f:
        cnt.update(re.findall(r'[A-Za-z_][A-Za-z0-9_]*', open(f, errors='replace').read()))
dyn = set()
for t in text.values(): dyn.update(re.findall(r'\b([A-Z][A-Za-z0-9_]{6,})\$\{?[A-Za-z_]', t))
for fn, locs in where.items():
    if cnt[fn] <= len(locs) and not any(fn.startswith(p) for p in dyn):
        row('dead', locs[0][0], locs[0][1], f'{fn} is named nowhere else')
# --- calls to a function nobody defines
known = set(pkgFn)
for t in text.values(): known.update(re.findall(r'^\s*(?:function\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*\(\)', t, re.M))
for f in glob.glob('sh-test/**/*.sh', recursive=True):
    known.update(re.findall(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\(\)', open(f, errors='replace').read(), re.M))
for f in glob.glob('../myx.distro-*/sh-lib/**/*', recursive=True) + glob.glob('../myx.distro-*/sh-scripts/*'):
    if os.path.isfile(f):
        known.update(re.findall(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\(\)', open(f, errors='replace').read(), re.M))
famRe = re.compile(r'(?:^|[;|&(`]|\$\(|\bthen\b|\bdo\b|\belse\b|\bif\b|\bwhile\b|!|\{)\s*((?:Agents|DistroAgents|Agent[A-Z][a-z]+Tools)[A-Za-z0-9_]*)(?![A-Za-z0-9_.=\[])')
for r in code:
    for n, line in enumerate(text[r].split('\n'), 1):
        if line.lstrip().startswith('#'): continue
        s = re.sub(r"'[^']*'", "''", line) ; s = re.sub(r'"(?:[^"\\$]|\\.|\$(?!\())*"', '""', s)
        if re.match(r'^\s*local\s', s): continue
        s = re.sub(r'^\s*[A-Za-z0-9_*.|:-]+\)(\s|$)', ' ', s)
        for m in famRe.finditer(s):
            if m.group(1) not in known: row('undefined-call', r, n, f'{m.group(1)} is defined nowhere')
# --- guarded loads: the guard names a function its file defines, and the guarded code calls
guardRe = re.compile(r'type ([A-Za-z_][A-Za-z0-9_]*) > /dev/null 2>&1 \|\| \. "\$MDLT_ORIGIN/myx/myx\.distro-agents/((?:sh-lib|sh-scripts)/[^"]+)"')
anyDef = re.compile(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\(\)\s*\{')
fileDefs = collections.defaultdict(set)
for r in code:
    for line in text[r].split('\n'):
        m = anyDef.match(line)
        if m: fileDefs[r].add(m.group(1))
for r in code:
    lines = text[r].split('\n')
    for i, line in enumerate(lines):
        if line.lstrip().startswith('#'): continue
        m = guardRe.search(line)
        if not m or m.group(2) not in fileDefs: continue
        fn, target = m.group(1), m.group(2)
        if fn not in fileDefs[target]:
            row('guard-target', r, i + 1, f'{fn} is not defined in {target}') ; continue
        j, body = i + 1, []
        ## the guarded code: to the end of its function, or of its case arm (`;;`), whichever comes first
        while j < len(lines) and not lines[j].startswith('}') and not anyDef.match(lines[j]):
            if not lines[j].lstrip().startswith('#'): body.append(lines[j])
            if lines[j].rstrip().endswith(';;'): break
            j += 1
        guarded = line[m.end():] + '\n' + ('' if line.rstrip().endswith(';;') else '\n'.join(body))
        calls = {k for k in fileDefs[target] if re.search(r'(?<![A-Za-z0-9_])' + re.escape(k) + r'(?![A-Za-z0-9_])', guarded)}
        if calls and fn not in calls and not re.search(r'(?<![A-Za-z0-9_])' + re.escape(fn) + r'(?![A-Za-z0-9_])', guarded):
            row('guard-name', r, i + 1, f'{fn} guards a load whose code calls {sorted(calls)[0]} of {target}')
# --- a guard on an op arm: the arm's result is the sourced file's, so the file must run every time
for r in code:
    if not r.startswith('sh-scripts/'): continue
    lines = text[r].split('\n')
    for i in range(1, len(lines) - 1):
        if re.match(r'^\s*--[a-z0-9-]+\)\s*$', lines[i - 1]) and lines[i + 1].strip() == 'return $?' and guardRe.search(lines[i]):
            row('guarded-op', r, i + 1, 'an op arm sources its file behind a guard: a second call in one process runs nothing')
# --- a load whose literal path names no file
anyLoadRe = re.compile(r'\.\s+"\$MDLT_ORIGIN/myx/myx\.distro-agents/((?:sh-lib|sh-scripts)/[A-Za-z0-9._/-]+)"')
for r in code:
    for n, line in enumerate(text[r].split('\n'), 1):
        if line.lstrip().startswith('#'): continue
        for m in anyLoadRe.finditer(line):
            if not os.path.isfile(m.group(1)): row('load-missing', r, n, f'{m.group(1)} is no file')
if rows: print('\n'.join(sorted(rows)))
