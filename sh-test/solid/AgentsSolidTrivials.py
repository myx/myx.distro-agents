#!/usr/bin/env python3
## AgentsSolidTrivials.py -- the trivial functions and trivial variables of myx.distro-agents, one row each:
## `trivial\t<file>:<line>\t<function|variable> <name>: <why it is trivial>`, for AgentsSolidBreachScan.sh.
## The rule: every trivial is inlined. A trivial function's body is one simple command, or one printf of its
## arguments: no pipeline, no `||`, no `;`, no `if`, never two statements. A trivial variable is value-only: one
## value, from a literal or from another variable, read once nearby.
## A trivial function is kept only where the mechanism needs a function, never because another file calls it: a call
## from another file is inlined at its callers. A name is kept for one of these reasons, each in
## `magic-developer/reference/code-craft.md`:
##   callback   its own file hands it over as a bare word: a value, an array entry, a case arm's command, or a
##              `trap` handler. The shell runs it by that name, so no caller line names it.
##   API        another file holds the name as data -- an argument word, a value, an array entry -- and runs it by that
##              name: a dispatcher, a hook registry, a callback table.
##   interface  the same name is defined in two files of the package: each file is one implementation of it, and the
##              code that calls the name does not know which file it has, so inlining either copy breaks the other.
##   shim       another file defines the same name and names it again inside that body: the name is rebound on first
##              use, so inlining the real definition leaves the shim calling a name nothing defines.
##   filter     its input arrives on its own stdin, and a call site feeds it there with a redirect or a pipe: no
##              argument carries the document, so inlining it writes its reader into every call site.
##   contract   a file of a sibling package names it, one optional part of one system naming another's.
##   knowledge  a comment attached to it states a reason, a trap or a consequence, which `knowledgeWords` reads.
##   algorithm  for a variable: assigned twice, read twice, read further than `nearbyLines` away, read outside its
##              function, sliced or substituted at the read, built by a command substitution, written by `read` or
##              `printf -v`, or named by another file.
## Left out on purpose: an exported or readonly name, an environment name, text inside a heredoc, a function indented
## inside another, and a comment that names a name (prose, never a call).
## The class is a gauge, not a verdict: a row names a name that carries less than the body behind it, and a reader
## settles it. It sits beside the existing classes and changes none of them.
## Usage: AgentsSolidTrivials.py <package root> [--explain]
import glob, os, re, sys

nearbyLines = 3
explain = '--explain' in sys.argv
kept = []
## A comment states more than the signature when it carries one of these: a reason, a trap, a consequence, or a rule
## a caller must keep. `## file, key` is the signature, which the body already shows, so it marks nothing.
knowledgeWords = re.compile(r'''(?ix)
    \b(?: because | never | must | always | otherwise | silently | silent | gotcha | warning | carefull?y
       | deliberate(?:ly)? | intentional(?:ly)? | legacy | quirk | workaround | cannot | breaks | fails
       | failing | do\ not | don.t | no\ fork | the\ reason | so\ that | in\ case | only\ one | exactly\ one
       | at\ most\ one | no\ more\ than | reads\ as | as\ if | is\ not\ a | is\ no | left\ in\ place
       | rather\ than | unimplemented | the\ callers? | every\ caller | inert | forward\ compat
       | owner\s+\d{4} | \d{4}-\d{2}-\d{2} )
''')

root = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()
os.chdir(root)
if not os.path.isdir('sh-lib'):
    sys.exit(f'⛔ ERROR: no package at {root}')

code = [f for f in sorted(glob.glob('sh-lib/**/*', recursive=True)) + sorted(glob.glob('sh-scripts/*.sh'))
        if os.path.isfile(f) and (f.endswith('.include') or f.endswith('.sh'))
        and '/client-hooks/' not in f and '.include-green' not in f and not f.endswith('template.sh')]
tests = sorted(f for f in glob.glob('sh-test/**/*.sh', recursive=True) if os.path.isfile(f))
linesOf = {f: open(f, errors='replace').read().split('\n') for f in code + tests}

def maskHeredocs(lines):
    mask, tag = [False] * len(lines), None
    for i, line in enumerate(lines):
        if tag:
            mask[i] = True
            if line.strip() == tag: tag = None
            continue
        m = re.search(r"<<-?\s*'?\"?([A-Za-z_][A-Za-z0-9_]*)'?\"?", line)
        if m and '<<<' not in line: tag = m.group(1)
    return mask

## one pass over every file: the heredoc mask, the lines each name appears on, the lines each name is assigned on,
## the function each line belongs to, and the names each file hands over as a bare word. Comments are left out
## throughout: a comment naming a thing is prose.
maskOf, mentions, assigns, spanOf, handedOver = {}, {}, {}, {}, {}
## the code files' own definitions, `name` -> the `(file, line)` of every one of them: a name two files define is a
## shape, and one name is never a shape on its own.
defines = {}
codeHere = set(code)
## a name, whole. A dot either side is part of a longer name, as `AgentsHarnessSkillSection.awk` names a file and not
## the function, so it is not this name.
wordRe = re.compile(r'(?<![A-Za-z0-9_.])[A-Za-z_][A-Za-z0-9_]*(?![A-Za-z0-9_.])')
assignRe = re.compile(r'^[ \t]*(?:(local|declare|typeset|export|readonly)\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$')
defStartRe = re.compile(r'^([A-Za-z_][A-Za-z0-9_]*)\(\)\s*\{')
## a command position: the start of a line, or after an operator, a keyword or a `$(`, where the shell runs a word
commandRe = re.compile(r'(?:^|[;|&({]|\$\(|\b(?:then|do|else|elif|if|while|until)\b|!|\|\||&&)\s*'
                       r'([A-Za-z_][A-Za-z0-9_]*)')
holderRe = re.compile(r'^[ \t]*(?:(?:local|export|readonly|declare|typeset)\s+)?[A-Za-z_][A-Za-z0-9_]*=(.*)$')
armRe = re.compile(r'^\s*[A-Za-z0-9_|*.-]+\)\s*(.*?)\s*(?:;;)?\s*$')
for f in linesOf:
    lines = linesOf[f]
    maskOf[f] = maskHeredocs(lines)
    mentions[f], assigns[f], spanOf[f] = {}, {}, {}
    handed = set()
    at = None
    for n, line in enumerate(lines, 1):
        if not maskOf[f][n - 1]:
            d = defStartRe.match(line)
            if d:
                at = n
                if f in codeHere: defines.setdefault(d.group(1), []).append((f, n))
            elif at and line.strip() == '}': at = None
        spanOf[f][n] = at or 0
        if maskOf[f][n - 1] or line.lstrip().startswith('#'): continue
        for m in wordRe.finditer(line): mentions[f].setdefault(m.group(0), []).append(n)
        m = assignRe.match(line)
        if m: assigns[f].setdefault(m.group(2), []).append(n)
        ## a name handed over as a bare word: a trap handler, a case arm's command, a value or an array entry
        if re.search(r'\btrap\b', line):
            handed.update(re.findall(r'(?<![A-Za-z0-9_$])[A-Za-z_][A-Za-z0-9_]*(?![A-Za-z0-9_(])', line))
        m = armRe.match(line)
        if m: handed.update(x[1] for x in commandRe.finditer(m.group(1)))
        m = holderRe.match(line)
        if m:
            held = m.group(1).strip()
            if held.startswith('('): handed.update(w for w in wordRe.findall(held) if len(w) > 3)
            else:
                word = held.strip('"\'')
                if re.match(r'^[A-Za-z_][A-Za-z0-9_]*$', word): handed.add(word)
    handedOver[f] = handed

## The names a sibling package names, one `name\tfile` an entry: every package beside this one is an optional part of
## one system at matching versions, so a sibling's naming a name is a contract and that name stays. A folder beside
## this one holding no sh-lib and no sh-scripts is no package and is not read. A sibling file that cannot be read is
## left out rather than ending the scan, and so is the contract it would have given. Comments and heredocs are left
## out, the same as in this package's own files.
siblingNames = {}
packageHere = os.getcwd()
for sibling in sorted(glob.glob(os.path.join(os.pardir, '*'))):
    if not os.path.isdir(sibling) or os.path.abspath(sibling) == packageHere: continue
    if not (os.path.isdir(os.path.join(sibling, 'sh-lib')) or os.path.isdir(os.path.join(sibling, 'sh-scripts'))): continue
    for area in ('sh-lib', 'sh-scripts', 'sh-test'):
        for g in sorted(glob.glob(os.path.join(sibling, area, '**', '*'), recursive=True)):
            if not os.path.isfile(g) or not g.endswith(('.include', '.sh', '.py', '.awk')): continue
            try: siblingText = open(g, errors='replace').read()
            except OSError: continue
            siblingLines = siblingText.split('\n')
            siblingMask = maskHeredocs(siblingLines)
            for k, line in enumerate(siblingLines):
                if siblingMask[k] or line.lstrip().startswith('#'): continue
                for word in wordRe.findall(line): siblingNames.setdefault(word, g)

def namedElsewhere(name, home):
    return sorted(f for f in mentions if f != home and name in mentions[f])

def textMask(line):
    ## the characters of a line that are text rather than code: inside a single-quoted string, or inside a
    ## double-quoted one. A `$(` opens code again, and the quotes inside that code open their own strings, so a
    ## pattern in a single-quoted grep inside a `$( )` is text exactly as it is anywhere else.
    text = [False] * len(line)
    stack = [['code', 0, False]]                       ## mode, the `$(` depth, entered from a double-quoted string
    i = 0
    while i < len(line):
        c, mode = line[i], stack[-1][0]
        if mode == 'single':
            text[i] = True
            if c == "'": stack.pop()
            i += 1 ; continue
        if mode == 'double':
            if c == '"': stack.pop() ; i += 1 ; continue
            if c == '\\': text[i] = True ; i += 2 ; continue
            if line[i:i + 2] == '$(':
                stack.append(['code', 1, True]) ; i += 2 ; continue
            text[i] = True ; i += 1 ; continue
        if c == "'": stack.append(['single', 0, False]) ; i += 1 ; continue
        if c == '"': stack.append(['double', 0, True]) ; i += 1 ; continue
        if c == '\\': i += 2 ; continue
        if line[i:i + 2] == '$(':
            stack[-1][1] += 1 ; i += 2 ; continue
        if c == '(' and stack[-1][1]: stack[-1][1] += 1 ; i += 1 ; continue
        if c == ')' and stack[-1][1]:
            stack[-1][1] -= 1
            if not stack[-1][1] and stack[-1][2]: stack.pop()
            i += 1 ; continue
        i += 1
    return text

def runsOf(name, home, ownLine):
    ## the lines of its own file that run the name at a command position, and those that name it in code any other
    ## way -- a trap handler, a case arm's command, a value, an array entry: `(runs, handedOver)`. A mention inside a
    ## quoted string is text, so it counts for neither. Neither ever counts `$name`.
    runs, handed = [], []
    for n in mentions[home].get(name, []):
        if n == ownLine: continue
        line = linesOf[home][n - 1]
        text = textMask(line)
        codeChars = ''.join(' ' if text[i] else c for i, c in enumerate(line))
        words = [(m.start(), m.end()) for m in re.finditer(r'(?<![A-Za-z0-9_$])' + re.escape(name) + r'(?![A-Za-z0-9_])', codeChars)]
        if not words: continue
        if any(m.group(1) == name for m in commandRe.finditer(codeChars)): runs.append(n)
        else: handed.append(n)
    return runs, handed

## The keywords a command position starts after, beside the `!` and `time` prefixes.
commandWords = {'if', 'elif', 'while', 'until', 'then', 'do', 'else', '!', 'time'}
## The commands that only ask whether a name exists: a load guard tests loaded-ness and never runs the name, so the name
## a guard holds is no API. The flag forms are `command -v`, `declare -F` and their siblings.
guardWords = {'type', 'command', 'declare', 'hash', 'builtin', 'whence', 'which'}
guardFlags = {'-v', '-V', '-t', '-F', '-f', '-p', '-a', '-A'}
## A word that sets a variable for one command, as `LC_ALL=C`: the command is the word after it, not this one.
assignWord = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*=')

def previousWords(code, at):
    ## the words of the line before `at`, nearest first, read from the masked code: a quoted span is blanked, so the
    ## words are the code words. A blanked word still ends a word, which is what keeps the argument after it an
    ## argument.
    words, rest = [], code[:at].rstrip()
    while rest:
        cut = len(rest)
        while cut and not rest[cut - 1].isspace(): cut -= 1
        prev, rest = rest[cut:], rest[:cut].rstrip()
        words.append(prev)
    return words

def positionKind(code, at):
    ## how a file names a name at `at`: `guard` where it only tests loaded-ness, `runs` where the shell runs it there,
    ## `holds` where it stands as data -- an argument word, a value, an array entry -- and is run by that name.
    ## A name straight after `=` is that assignment's value. Every other word is read back to the start of its command:
    ## after an operator, a keyword or an assignment prefix the name is the command, and after anything else it is an
    ## argument to the command before it. Where the words before it are all blanked -- a name handed over inside a
    ## quoted command, as `"$runner" name` -- the name is read as a call, so the gauge names it and a reader settles it.
    if at and code[at - 1] == '=': return 'holds'
    words = [w for w in previousWords(code, at) if w]
    if words and words[0] in guardWords: return 'guard'
    if len(words) > 1 and words[0] in guardFlags and words[1] in guardWords: return 'guard'
    if not words: return 'runs'
    for prev in words:
        prev = prev.rstrip()
        if not prev: continue
        bare = prev.rstrip('"\'')
        if not bare: continue                               ## a run of quote marks is the quote of a blanked value
        prev = bare                                         ## `NAME="` before a blanked value is the prefix `NAME=`
        if prev[-1] in ';|&=': 
            if prev[-1] == '=': continue                  ## an assignment prefix: `X=` or a blanked `="value"`
            return 'runs'
        if prev.endswith(')'): return 'runs'
        if prev.endswith('{') or prev.endswith('('):
            return 'holds' if (prev.endswith('(') and len(prev) > 1 and (prev[-2].isalnum() or prev[-2] in '_=')) else 'runs'
        if prev in commandWords: return 'runs'
        if assignWord.match(prev): continue
        return 'holds'
    return 'runs'

def mentionsElsewhere(name, home):
    ## one `(kind, `<file>:<line>`)` for each place another file names the name in code, in file order: `defines` where
    ## that file defines it too, `runs` where the shell calls it there, `guard` where it only tests the name exists, and
    ## `holds` where it stands as data -- an argument word, a value, an array entry -- and is run by that name rather
    ## than called.
    found = []
    for g in sorted(f for f in mentions if f != home and name in mentions[f]):
        for n in mentions[g][name]:
            line = linesOf[g][n - 1]
            text = textMask(line)
            codeChars = ''.join(' ' if text[i] else c for i, c in enumerate(line))
            m = re.search(r'(?<![A-Za-z0-9_$])' + re.escape(name) + r'(?![A-Za-z0-9_])', codeChars)
            if not m: continue
            if defStartRe.match(line): found.append(('defines', f'{g}:{n}'))
            else: found.append((positionKind(codeChars, m.start()), f'{g}:{n}'))
    return found

def commentAbove(f, at):
    ## the comment block attached to the item at `at`: the run of comment lines straight above it. A run reaching
    ## the file's first line is the file's own header, so only the part after its last bare `#` line counts.
    above, k = [], at - 1
    while k >= 1 and linesOf[f][k - 1].lstrip().startswith('#'):
        above.insert(0, linesOf[f][k - 1].strip())
        k -= 1
    if k < 1:
        for i in range(len(above) - 1, -1, -1):
            if re.match(r'^#+$', above[i]):
                return above[i + 1:]
    return above

def knowledgeIn(comments):
    return any(c and knowledgeWords.search(c) for c in comments)

def otherDefiners(name, home):
    ## the `(file, line)` of every definition of the name in a code file other than its home
    return [(g, n) for g, n in defines.get(name, []) if g != home]

def bodyNamesItself(name, g, at):
    ## whether the definition at `g:at` names the name again inside its own body, which is a rebind: the file hands the
    ## name its real definition when the shim is first run. The body may stand on the definition line itself.
    defLine = linesOf[g][at - 1]
    same = re.search(r'(?<![A-Za-z0-9_$])' + re.escape(name) + r'(?![A-Za-z0-9_])', defLine[defLine.index('{') + 1:])
    if same: return True
    for k in range(at + 1, len(linesOf[g]) + 1):
        line = linesOf[g][k - 1]
        if maskOf[g][k - 1] or line.lstrip().startswith('#'): continue
        if line.strip() == '}': return False
        if re.search(r'(?<![A-Za-z0-9_$])' + re.escape(name) + r'(?![A-Za-z0-9_])', line): return True
    return False

def shimOf(name, home):
    ## the `file:line` of a definition of the name in another file whose body names it again, empty where there is none
    for g, n in otherDefiners(name, home):
        if bodyNamesItself(name, g, n): return f'{g}:{n}'
    return ''

def stdinSites(name, home):
    ## one `file:line` for each place the name is run and fed on its own stdin: a `<` redirect after it, or a single `|`
    ## before it. `||` and `&&` are no pipe, and `<<`/`<<<` and `<(` feed something else. No argument carries such a
    ## document, so the reader has to stay one name.
    found = []
    for g in sorted(f for f in mentions if name in mentions[f]):
        for n in mentions[g][name]:
            line = linesOf[g][n - 1]
            text = textMask(line)
            codeChars = ''.join(' ' if text[i] else c for i, c in enumerate(line))
            for m in re.finditer(r'(?<![A-Za-z0-9_$])' + re.escape(name) + r'(?![A-Za-z0-9_])', codeChars):
                if positionKind(codeChars, m.start()) != 'runs': continue
                if re.search(r'(?<![\|])\|(?![\|])', codeChars[:m.start()]) or \
                        re.search(r'(?<!<)<(?![<(])', codeChars[m.end():]):
                    found.append(f'{g}:{n}')
                    break
    return found

rows = []
compound = re.compile(r'[|;&]|\bthen\b|\bdo\b|\besac\b|\bdone\b|\bfi\b')
leadWord = re.compile(r'^(?:if|case|for|while|until|select|function|eval|\{|\()\b')
trailingComment = re.compile(r'(?:^|\s)#.*$')

## --- functions: the definition line, then every line of the body up to the bare `}` that closes it
for f in code:
    lines = linesOf[f]
    for i, line in enumerate(lines):
        if maskOf[f][i] or line.lstrip().startswith('#'): continue
        d = defStartRe.match(line)
        if not d: continue
        name = d.group(1)
        rest = line[d.end():]
        remark, inner = '', []
        if '}' in rest:
            ## a whole body on the definition line, as `f(){ body ; }`
            body = [rest.split('}')[0].strip().strip(';').strip()]
        else:
            rm = re.match(r'^\s*(##.*)$', rest)
            if rm: remark = rm.group(1).strip()
            else:
                first = trailingComment.sub('', rest).strip()
                if first: inner.append(first)
            j = i + 1
            while j < len(lines) and lines[j].strip() != '}':
                inner.append(lines[j])
                j += 1
            if any(maskOf[f][k] for k in range(i + 1, min(j + 1, len(lines)))): continue
            body = [l.strip() for l in inner if l.strip() and not l.strip().startswith('#')]
        if len(body) != 1: continue
        stmt = body[0]
        if not stmt or compound.search(stmt) or leadWord.match(stmt): continue
        runs, handed = runsOf(name, f, i + 1)
        elsewhere = mentionsElsewhere(name, f)
        comments = [remark] + commentAbove(f, i + 1) + [l.strip() for l in inner if l.strip().startswith('#')]
        held = [w for k, w in elsewhere if k == 'holds']
        if held: kept.append(f'function\t{f}:{i + 1} {name}\ta name another file runs by string, from {held[0].rsplit(":", 1)[0]}') ; continue
        ## a rebind: another file defines the same name and names it again inside that definition, so that copy is a lazy
        ## shim and this file's is the real one. Inlining this copy leaves the shim loading a name nothing defines.
        rebind = shimOf(name, f)
        if rebind: kept.append(f'function\t{f}:{i + 1} {name}\trebound by the shim at {rebind}, which loads this file') ; continue
        ## an interface: another file defines the same name as a plain implementation, and a file that defines neither
        ## copy runs or holds it. The name is what the caller names, so each file is one implementation of it. Two copies
        ## and no third caller is a duplicate, which is no API.
        definers = [(g, n) for g, n in otherDefiners(name, f) if not bodyNamesItself(name, g, n)]
        if definers:
            callers = {w.rsplit(':', 1)[0] for k, w in elsewhere if k in ('runs', 'holds')}
            callers -= {f} | {g for g, _ in definers}
            if callers:
                kept.append(f'function\t{f}:{i + 1} {name}\tan interface, defined again at {definers[0][0]}:{definers[0][1]} '
                            f'and run from {sorted(callers)[0]}') ; continue
        if name in siblingNames: kept.append(f'function\t{f}:{i + 1} {name}\tthe sibling package names it, in {siblingNames[name]}') ; continue
        if handed or name in handedOver[f]: kept.append(f'function\t{f}:{i + 1} {name}\thanded over as a bare word') ; continue
        if knowledgeIn(comments): kept.append(f'function\t{f}:{i + 1} {name}\tits comment states why') ; continue
        fed = stdinSites(name, f)
        if fed: kept.append(f'function\t{f}:{i + 1} {name}\ta filter, its document arrives on its stdin, as at {fed[0]}') ; continue
        where = (f'{len(runs)} call site' + ('' if len(runs) == 1 else 's')) if runs else 'no call site'
        calledFrom = [w for k, w in elsewhere if k == 'runs']
        alsoFrom = f', also called from {calledFrom[0]}' if calledFrom else ''
        rows.append(f'trivial\t{f}:{i + 1}\tfunction {name}: one simple command, `{stmt[:90]}`, {where} in this file{alsoFrom}')

## --- variables
literalRe = re.compile(r'^(?:"[^"$`\\]*"|\'[^\']*\'|[A-Za-z0-9_./:%,+=@-]+)$')
copyRe = re.compile(r'^(?:"?)\$\{?[A-Za-z_][A-Za-z0-9_]*\}?(?:"?)(?:/[^ $]*)?$')
envRe = re.compile(r'^[A-Z][A-Z0-9_]*$')
writeTarget = re.compile(r'(?:\bread\s+(?:-\S+\s+)*|printf\s+-v\s+|\blet\s+)([A-Za-z_][A-Za-z0-9_]*)')
for f in code:
    for n, line in enumerate(linesOf[f], 1):
        if maskOf[f][n - 1] or line.lstrip().startswith('#'): continue
        m = assignRe.match(line)
        if not m: continue
        declare, name, value = m.group(1) or '', m.group(2), m.group(3).strip()
        if declare in ('export', 'readonly') or envRe.match(name): continue
        if not (literalRe.match(value) or copyRe.match(value)): continue
        ## one assignment of the name in its own function
        if assigns[f][name] != [n]: continue
        ## exactly one other mention in the file: the read. Anything more is not one value read once.
        others = [k for k in mentions[f].get(name, []) if k != n]
        if len(others) != 1: continue
        readAt = others[0]
        if not (n < readAt <= n + nearbyLines): continue
        if spanOf[f].get(n) != spanOf[f].get(readAt): continue
        readLine = linesOf[f][readAt - 1]
        ## a second assignment, a counter's read-modify-write, or a line the shell writes the value into
        if re.match(r'^[ \t]*(?:(?:local|declare|typeset|export|readonly)\s+)?' + re.escape(name) + r'=', readLine): continue
        if re.search(r'\$\(\(|\$\{\{|\$\{!' + re.escape(name), readLine): continue
        ## the read slices or substitutes the variable itself (`${n:2}`, `${#n}`, `${s//a/b}`): the algorithm needs a
        ## name there, and the value written out would not do the same thing
        if re.search(r'\$(?:\{#' + re.escape(name) + r'|\{' + re.escape(name) + r'[:#%/^,-])', readLine): continue
        if writeTarget.search(readLine): continue
        ## a copy of another variable: inlining writes that variable where the copy is read, so the copy only goes
        ## where the source cannot change in between. A source set in more than one place, in any file, keeps it.
        ## An environment name is set once by the caller's environment, so it counts as one place.
        src = re.match(r'^"?\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?"?', value)
        if src and not envRe.match(src.group(1)):
            source = src.group(1)
            if sum(len(assigns[g][source]) for g in assigns if source in assigns[g]) > 1: continue
        away = namedElsewhere(name, f)
        if away:
            kept.append(f'variable\t{f}:{n} {name}\tnamed in {away[0]}') ; continue
        rows.append(f'trivial\t{f}:{n}\tvariable {name}: one value `{value[:70]}`, '
                    f'read once at {f}:{readAt}, nothing else uses it')

if explain:
    for line in sorted(kept): print(f'kept\t{line}', file=sys.stderr)
if rows: print('\n'.join(sorted(rows)))
