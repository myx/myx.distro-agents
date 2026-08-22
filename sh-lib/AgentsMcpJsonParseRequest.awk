#!/usr/bin/env awk

# One single-line JSON-RPC message on stdin -> one file per field under -v outDir.
# Caller must set LC_ALL=C for byte safety. Emitted field names: see MAGIC.md.

# Must be a real 0: "" would build "arg_env_name_" with no index.
BEGIN { envEntryCount = 0; }

function skipws(   c) {
	while (p <= n) {
		c = substr(s, p, 1)
		if (c == " " || c == "\t" || c == "\n" || c == "\r") p++
		else break
	}
}

function hex2dec(h,   i, c, v, r) {
	r = 0
	for (i = 1; i <= length(h); i++) {
		c = tolower(substr(h, i, 1))
		v = index("0123456789abcdef", c) - 1
		r = r * 16 + v
	}
	return r
}

# Decomposes to bytes <= 255 before any %c, which is what keeps this byte-safe.
function utf8enc(cp,   c1, c2, c3, c4) {
	if (cp < 128) {
		return sprintf("%c", cp)
	} else if (cp < 2048) {
		c1 = 192 + int(cp / 64)
		c2 = 128 + (cp % 64)
		return sprintf("%c%c", c1, c2)
	} else if (cp < 65536) {
		c1 = 224 + int(cp / 4096)
		c2 = 128 + int(cp / 64) % 64
		c3 = 128 + (cp % 64)
		return sprintf("%c%c%c", c1, c2, c3)
	} else {
		c1 = 240 + int(cp / 262144)
		c2 = 128 + int(cp / 4096) % 64
		c3 = 128 + int(cp / 64) % 64
		c4 = 128 + (cp % 64)
		return sprintf("%c%c%c%c", c1, c2, c3, c4)
	}
}

function parseString(   c, out, hex, code, hex2, code2, cp) {
	p++ # skip opening quote
	out = ""
	while (p <= n) {
		c = substr(s, p, 1)
		if (c == "\"") { p++; break; }
		if (c == "\\") {
			p++
			c = substr(s, p, 1)
			if (c == "\"") out = out "\""
			else if (c == "\\") out = out "\\"
			else if (c == "/") out = out "/"
			else if (c == "b") out = out "\b"
			else if (c == "f") out = out "\f"
			else if (c == "n") out = out "\n"
			else if (c == "r") out = out "\r"
			else if (c == "t") out = out "\t"
			else if (c == "u") {
				hex = substr(s, p + 1, 4)
				code = hex2dec(hex)
				p += 4
				if (code >= 55296 && code <= 56319 && substr(s, p + 1, 2) == "\\u") {
					hex2 = substr(s, p + 3, 4)
					code2 = hex2dec(hex2)
					if (code2 >= 56320 && code2 <= 57343) {
						cp = 65536 + (code - 55296) * 1024 + (code2 - 56320)
						out = out utf8enc(cp)
						p += 6
					} else {
						out = out utf8enc(code)
					}
				} else {
					out = out utf8enc(code)
				}
			}
			else out = out c
			p++
		} else {
			out = out c
			p++
		}
	}
	return out
}

function emitLeaf(path, raw, val,   f, idx) {
	if (path == "method") { f = outDir "/method"; print val > f; close(f); }
	else if (path == "id") {
		f = outDir "/id"; print raw > f; close(f)
		f = outDir "/has_id"; print "1" > f; close(f)
	}
	else if (path == "params.name") { f = outDir "/tool_name"; print val > f; close(f); }
	else if (path == "params.uri") { f = outDir "/uri"; print val > f; close(f); }
	else if (path == "params.requestId") { f = outDir "/cancel_request_id"; print raw > f; close(f); }
	else if (path == "params.clientInfo.name") { f = outDir "/client_name"; print val > f; close(f); }
	else if (path == "params.clientInfo.version") { f = outDir "/client_version"; print val > f; close(f); }
	else if (path == "params.arguments.command") { f = outDir "/arg_command"; print val > f; close(f); }
	else if (path == "params.arguments.uname") { f = outDir "/arg_uname"; print val > f; close(f); }
	else if (path == "params.arguments.stdin") { f = outDir "/arg_stdin"; print val > f; close(f); }
	else if (path == "params.arguments.timeout") { f = outDir "/arg_timeout"; print val > f; close(f); }
	else if (path == "params.arguments.args.__count") { f = outDir "/arg_args_count"; print val > f; close(f); }
	else if (index(path, "params.arguments.args.") == 1) {
		idx = substr(path, length("params.arguments.args.") + 1)
		f = outDir "/arg_args_" idx; print val > f; close(f)
	}
	else if (index(path, "params.arguments.env.") == 1) {
		idx = substr(path, length("params.arguments.env.") + 1)
		if (idx ~ /^[A-Za-z_][A-Za-z0-9_]*$/) {
			f = outDir "/arg_env_name_" envEntryCount; print idx > f; close(f)
			f = outDir "/arg_env_val_" envEntryCount; print val > f; close(f)
			envEntryCount++
			f = outDir "/arg_env_count"; print envEntryCount > f; close(f)
		}
	}
}

function parseValue(path,   c, startp, val, raw) {
	skipws()
	c = substr(s, p, 1)
	if (c == "\"") {
		startp = p
		val = parseString()
		raw = substr(s, startp, p - startp)
		emitLeaf(path, raw, val)
	} else if (c == "{") {
		parseObject(path)
	} else if (c == "[") {
		parseArray(path)
	} else if (c == "t") {
		p += 4
		emitLeaf(path, "true", "true")
	} else if (c == "f") {
		p += 5
		emitLeaf(path, "false", "false")
	} else if (c == "n") {
		p += 4
		emitLeaf(path, "null", "")
	} else {
		startp = p
		while (p <= n) {
			c = substr(s, p, 1)
			if (c == "-" || c == "+" || c == "." || c == "e" || c == "E" || (c >= "0" && c <= "9")) p++
			else break
		}
		raw = substr(s, startp, p - startp)
		emitLeaf(path, raw, raw)
	}
}

function parseObject(path,   key, keypath, c) {
	p++ # skip {
	skipws()
	if (substr(s, p, 1) == "}") { p++; return; }
	while (1) {
		skipws()
		key = parseString()
		skipws()
		p++ # skip :
		keypath = (path == "") ? key : path "." key
		parseValue(keypath)
		skipws()
		c = substr(s, p, 1)
		if (c == ",") { p++; continue; }
		else if (c == "}") { p++; break; }
		else break
	}
}

function parseArray(path,   idx, c) {
	p++ # skip [
	skipws()
	idx = 0
	if (substr(s, p, 1) == "]") { p++; emitLeaf(path ".__count", idx, idx); return; }
	while (1) {
		parseValue(path "." idx)
		idx++
		skipws()
		c = substr(s, p, 1)
		if (c == ",") { p++; continue; }
		else if (c == "]") { p++; break; }
		else break
	}
	emitLeaf(path ".__count", idx, idx)
}

{ s = $0; n = length(s); p = 1; parseValue(""); }