.pragma library

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function hasOwn(obj, key) {
    return Object.prototype.hasOwnProperty.call(obj, key);
}

function skipString(str, i) {
    const q = str[i];
    let j = i + 1;
    while (j < str.length) {
        if (str[j] === q)
            return j + 1;
        j++;
    }
    return str.length;
}

// Return a Lua keyword at position i (at a word boundary) that involves block
// structure: function|if|for|while|do|repeat (openers) or end|until (closers).
function luaBlockKeyword(str, i) {
    const prev = i > 0 ? str[i - 1] : "";
    if (/[A-Za-z0-9_]/.test(prev))
        return null;
    const m = str.slice(i).match(/^(function|if|for|while|do|repeat|end|until)\b/);
    if (!m)
        return null;
    const j = i + m[1].length;
    const next = str[j];
    if (/[A-Za-z0-9_]/.test(next || " "))
        return null;
    return m[1];
}

// Split on a separator ("," or e.g. "..") honoring nesting, string literals,
// and Lua block constructs (function/if/for/while/do/repeat ... end/until).
function splitTopLevel(str, sep) {
    const parts = [];
    let depth = 0;
    let blockDepth = 0;
    let pendingDo = false;
    let cur = "";
    let i = 0;
    const n = str.length;
    const sepLen = sep.length;

    while (i < n) {
        const c = str[i];
        if (c === '"' || c === "'") {
            const e = skipString(str, i);
            cur += str.slice(i, e);
            i = e;
            continue;
        }
        if (c === "[" && str[i + 1] === "[") {
            const e = str.indexOf("]]", i + 2);
            if (e === -1) {
                cur += str.slice(i);
                i = n;
            } else {
                cur += str.slice(i, e + 2);
                i = e + 2;
            }
            continue;
        }
        if (c === "(" || c === "{") {
            depth++;
            cur += c;
            i++;
            continue;
        }
        if (c === ")" || c === "}") {
            if (depth > 0)
                depth--;
            cur += c;
            i++;
            continue;
        }
        if (depth === 0 && /[A-Za-z_]/.test(c)) {
            const kw = luaBlockKeyword(str, i);
            if (kw) {
                if (kw === "end" || kw === "until") {
                    if (blockDepth > 0)
                        blockDepth--;
                } else if (kw === "do") {
                    if (pendingDo)
                        pendingDo = false;
                    else
                        blockDepth++;
                } else if (kw === "for" || kw === "while") {
                    blockDepth++;
                    pendingDo = true;
                } else if (kw === "if" || kw === "repeat" || kw === "function") {
                    blockDepth++;
                }
                cur += kw;
                i += kw.length;
                continue;
            }
        }
        if (depth === 0 && blockDepth === 0 && sepLen && str.startsWith(sep, i)) {
            parts.push(cur.trim());
            cur = "";
            i += sepLen;
            continue;
        }
        cur += c;
        i++;
    }
    if (cur.trim())
        parts.push(cur.trim());
    return parts;
}

function splitTopLevelCommas(str) {
    return splitTopLevel(str, ",");
}

// Count paren + brace depth (out of strings) as a signal of complete statements
function parenBalance(str) {
    let bal = 0;
    let i = 0;
    const n = str.length;
    while (i < n) {
        const c = str[i];
        if (c === "-") {
            if (i + 1 < n && str[i + 1] === "-")
                break;
            i++;
            continue;
        }
        if (c === '"' || c === "'") {
            i = skipString(str, i);
            continue;
        }
        if (c === "[" && str[i + 1] === "[") {
            const e = str.indexOf("]]", i + 2);
            i = e === -1 ? n : e + 2;
            continue;
        }
        if (c === "(" || c === "{")
            bal++;
        else if (c === ")" || c === "}")
            bal--;
        i++;
    }
    return bal;
}

// Remove trailing "-- comment" (outside string literals) from a physical line
function stripInlineComment(line) {
    let i = 0;
    const n = line.length;
    while (i < n) {
        const c = line[i];
        if (c === '"' || c === "'") {
            i = skipString(line, i);
            continue;
        }
        if (c === "[" && line[i + 1] === "[") {
            const e = line.indexOf("]]", i + 2);
            i = e === -1 ? n : e + 2;
            continue;
        }
        if (c === "-" && line[i + 1] === "-")
            return line.slice(0, i).trim();
        i++;
    }
    return line.trim();
}

// Merge physical lines into logical statements (multiline create_bind calls).
// Returns [{ text, startLine, endLine }] with 0-based physical line spans.
function splitStatementsDetailed(content) {
    const lines = content.split("\n");
    const statements = [];
    let pending = "";
    let pendingStart = -1;
    for (let i = 0; i < lines.length; i++) {
        const trimmed = lines[i].trim();
        if (!trimmed) {
            if (pending && parenBalance(pending) === 0) {
                statements.push({ text: pending, startLine: pendingStart, endLine: i - 1 });
                pending = "";
                pendingStart = -1;
            }
            continue;
        }
        const cleaned = trimmed.startsWith("--") ? trimmed : stripInlineComment(trimmed);
        const candidate = pending ? (pending + "\n" + cleaned) : cleaned;
        if (parenBalance(candidate) === 0) {
            statements.push({ text: candidate, startLine: pending ? pendingStart : i, endLine: i });
            pending = "";
            pendingStart = -1;
        } else {
            if (pending && !pending.trim().startsWith("create_bind(") && (cleaned.startsWith("--") || cleaned.startsWith("for ") ||
                /^(local\s+\w+\s*=|create_bind\(|[a-zA-Z_]\w*\s*=)/.test(cleaned))) {
                statements.push({ text: pending, startLine: pendingStart, endLine: i - 1 });
                pending = "";
                pendingStart = -1;
            }
            pending = candidate;
            if (pendingStart === -1)
                pendingStart = i;
        }
    }
    if (pending)
        statements.push({ text: pending, startLine: pendingStart, endLine: lines.length - 1 });
    return statements;
}

function splitStatements(content) {
    return splitStatementsDetailed(content).map(s => s.text);
}

// ---------------------------------------------------------------------------
// Variable parsing (hypr/variables.lua)
// ---------------------------------------------------------------------------

// Decode a value expression into a JS value. Returns { value, unresolved }.
function decodeValue(rawExpr) {
    const expr = rawExpr.trim();
    if (!expr)
        return { value: "", unresolved: true };

    const strMatch = expr.match(/^"([\s\S]*)"$/);
    if (strMatch)
        return { value: strMatch[1], unresolved: false };
    const strMatch2 = expr.match(/^'([\s\S]*)'$/);
    if (strMatch2)
        return { value: strMatch2[1], unresolved: false };

    if (/^-?\d+(\.\d+)?$/.test(expr))
        return { value: parseFloat(expr), unresolved: false };

    if (expr === "true" || expr === "false")
        return { value: expr === "true", unresolved: false };

    if (expr.startsWith("{") && expr.endsWith("}")) {
        const inner = expr.slice(1, -1);
        const elements = splitTopLevelCommas(inner);
        const values = [];
        for (let i = 0; i < elements.length; i++) {
            const e = decodeValue(elements[i]);
            values.push(e.value);
        }
        return { value: values, unresolved: false };
    }

    return { value: expr, unresolved: true };
}

// Find the matching closing brace for an opening brace at position openBrace
function findMatchingBrace(content, openBrace) {
    let depth = 0;
    for (let i = openBrace; i < content.length; i++) {
        const c = content[i];
        if (c === '"' || c === "'") { i = skipString(content, i) - 1; continue; }
        if (c === "[" && content[i + 1] === "[") { const e = content.indexOf("]]", i + 2); i = e === -1 ? content.length - 1 : e + 1; continue; }
        if (c === "-" && content[i + 1] === "-") { while (i < content.length && content[i] !== "\n") i++; continue; }
        if (c === "{") depth++;
        else if (c === "}") { depth--; if (depth === 0) return i; }
    }
    return -1;
}

// Find the table body (inner content between { and }) of the return table.
// Supports: return { ... } and local M = { ... } ... return M
function findReturnTable(content) {
    let idx = content.indexOf("return {");
    if (idx !== -1) {
        const bracePos = idx + 7;
        const end = findMatchingBrace(content, bracePos);
        if (end !== -1) return { start: bracePos + 1, end: end };
    }
    const localRe = /local\s+(\w+)\s*=\s*\{/g;
    let m;
    while ((m = localRe.exec(content)) !== null) {
        const bracePos = content.indexOf("{", m.index + m[0].length - 1);
        const end = findMatchingBrace(content, bracePos);
        if (end === -1) continue;
        const after = content.slice(end + 1);
        const returnRe = new RegExp("\\breturn\\s+" + m[1] + "\\b");
        if (returnRe.test(after))
            return { start: bracePos + 1, end: end };
    }
    return null;
}

function isCategoryComment(comment) {
    return /^[A-Z][A-Za-z0-9: +/()-]{0,60}$/.test(comment) && comment.indexOf("----") === -1;
}

function isBannerComment(comment) {
    if (!comment)
        return false;
    const stripped = comment.replace(/[-=\s]+/g, "");
    return stripped.length === 0 || comment.startsWith("-") || comment.endsWith("-");
}

// Parses variables.lua (a Lua table returned from a module) into:
//   list: [{ name, value, category, note }]
//   map:  { name: resolvedValue } (strings/arrays only, unresolved excluded)
function parseVariables(content) {
    const list = [];
    const map = {};

    const table = findReturnTable(content);
    if (!table)
        return { list: list, map: map };

    let category = null;
    let note = null;
    let i = table.start;
    let tableDepth = 1;

    while (i < table.end) {
        const ch = content[i];

        if (ch === "-" && content[i + 1] === "-") {
            let j = i + 2;
            let comment = "";
            while (j < table.end && content[j] !== "\n") {
                comment += content[j];
                j++;
            }
            comment = comment.trim();
            if (isBannerComment(comment)) {
                category = null;
                note = null;
            } else if (isCategoryComment(comment)) {
                category = comment;
            } else {
                note = comment;
            }
            i = j;
            continue;
        }

        if (ch === '"' || ch === "'") {
            i = skipString(content, i);
            continue;
        }

        if (ch === "[" && content[i + 1] === "[") {
            const e = content.indexOf("]]", i + 2);
            i = e === -1 ? table.end : e + 2;
            continue;
        }

        if (ch === "{") {
            tableDepth++;
            i++;
            continue;
        }
        if (ch === "}" && tableDepth > 1) {
            tableDepth--;
            i++;
            continue;
        }

        if (tableDepth === 1) {
            let name = null;
            let k = i;

            if (ch === "[") {
                const closeBracket = content.indexOf("]", i + 1);
                if (closeBracket !== -1 && closeBracket < table.end) {
                    const inner = content.slice(i + 1, closeBracket).trim();
                    const qStr = inner.match(/^"([\s\S]*)"$/) || inner.match(/^'([\s\S]*)'$/);
                    if (qStr) {
                        name = qStr[1];
                        k = closeBracket + 1;
                    }
                }
            } else if (/[A-Za-z_]/.test(ch)) {
                k = i;
                while (k < table.end && /[\w]/.test(content[k]))
                    k++;
                name = content.slice(i, k);
            }

            if (name !== null) {
                let eq = k;
                while (eq < table.end && /\s/.test(content[eq]))
                    eq++;
                if (content[eq] === "=") {
                    const valInfo = captureEntryValue(content, eq + 1);
                    const entry = {
                        name: name,
                        value: valInfo.result,
                        category: category,
                        note: note
                    };
                    list.push(entry);
                    map[name] = valInfo.result;
                    i = valInfo.end;
                    continue;
                }
            }
        }

        i++;
    }

    const resolvedMap = resolveVariableMap(list, map);
    return { list: list, map: resolvedMap };
}

// Read a value expression starting at `start` until a top-level "," or "}"
function captureEntryValue(content, start) {
    let i = start;
    let depth = 0;
    let raw = "";
    const n = content.length;

    while (i < n) {
        const c = content[i];
        if (c === '"' || c === "'") {
            const e = skipString(content, i);
            raw += content.slice(i, e);
            i = e;
            continue;
        }
        if (c === "[" && content[i + 1] === "[") {
            const e = content.indexOf("]]", i + 2);
            if (e === -1) {
                raw += content.slice(i);
                i = n;
                break;
            }
            raw += content.slice(i, e + 2);
            i = e + 2;
            continue;
        }
        if (c === "-" && content[i + 1] === "-") {
            while (i < n && content[i] !== "\n")
                i++;
            continue;
        }
        if (c === "{" || c === "(") {
            depth++;
            raw += c;
            i++;
            continue;
        }
        if (c === "}" || c === ")") {
            if (depth === 0) {
                i++;
                break;
            }
            depth--;
            raw += c;
            i++;
            continue;
        }
        if (c === "," && depth === 0) {
            i++;
            break;
        }
        raw += c;
        i++;
    }

    const info = decodeValue(raw);
    return { result: info.value, unresolved: info.unresolved, end: i };
}

// Multi-pass resolution of variable references and concatenations in map values.
// Map values are already decoded (strings have no surrounding quotes). Resolves:
// bare var references, string concatenation (var .. "..."), var .. var,
// arithmetic (a % b). Unresolvable entries are kept as raw tokens in the map.
function resolveVariableMap(list, map) {
    if (!list.length)
        return map;
    const resolved = {};
    for (const k in map)
        resolved[k] = map[k];

    const MAX_PASSES = 6;
    for (let pass = 0; pass < MAX_PASSES; pass++) {
        let changed = false;
        for (const name in resolved) {
            const v = resolved[name];
            if (typeof v !== "string")
                continue;
            if (Array.isArray(v) || typeof v === "number" || typeof v === "boolean")
                continue;
            const ref = v.trim();
            if (/^[\w.]+$/.test(ref) && hasOwn(resolved, ref) && typeof resolved[ref] === "string" &&
                !/^[\w.]+$/.test(resolved[ref].trim())) {
                resolved[name] = resolved[ref];
                changed = true;
                continue;
            }
            const parts = splitTopLevel(v, "..");
            if (parts.length > 1) {
                let out = "";
                let allResolved = true;
                for (let j = 0; j < parts.length; j++) {
                    const p = parts[j].trim();
                    const strLit = p.match(/^"([\s\S]*)"$/) || p.match(/^'([\s\S]*)'$/);
                    if (strLit) {
                        out += strLit[1];
                        continue;
                    }
                    const bare = /^[\w.]+$/.test(p);
                    if (bare && hasOwn(resolved, p) && typeof resolved[p] === "string") {
                        const pv = resolved[p];
                        if (/^[\w.]+$/.test(pv.trim())) { allResolved = false; break; }
                        out += pv;
                    } else if (bare && !hasOwn(resolved, p)) {
                        allResolved = false;
                        break;
                    } else {
                        allResolved = false;
                        break;
                    }
                }
                if (allResolved) {
                    resolved[name] = out;
                    changed = true;
                    continue;
                }
            }
            const modMatch = v.match(/^(.+?)\s*%\s*(-?\d+)$/);
            if (modMatch) {
                const left = modMatch[1].trim();
                const num = parseInt(modMatch[2], 10);
                if (hasOwn(resolved, left) && typeof resolved[left] === "string") {
                    const n = parseInt(resolved[left], 10);
                    if (!isNaN(n) && !isNaN(num)) {
                        resolved[name] = String(n % num);
                        changed = true;
                        continue;
                    }
                }
            }
        }
        if (!changed)
            break;
    }
    return resolved;
}

// ---------------------------------------------------------------------------
// Keybind parsing (hypr/hyprland/keybinds.lua)
// ---------------------------------------------------------------------------

// Evaluate a small Lua expression subset: strings, numbers, vars.* lookup,
// scope identifiers, `..` concat, `%` modulo, { } arrays, extend_keybind(),
// normalise_keybind(). Returns undefined when unresolvable.
function evalExpr(raw, scope, vars, visited) {
    let expr = String(raw).trim();
    if (!expr)
        return undefined;

    if (expr[0] === "(" && expr[expr.length - 1] === ")" && parenBalance(expr.slice(1, -1)) === 0)
        return evalExpr(expr.slice(1, -1), scope, vars, visited);

    if (expr.startsWith("[[" ) && expr.endsWith("]]"))
        return expr.slice(2, -2);

    const strMatch = expr.match(/^"([\s\S]*)"$/);
    if (strMatch)
        return strMatch[1];
    const strMatch2 = expr.match(/^'([\s\S]*)'$/);
    if (strMatch2)
        return strMatch2[1];

    if (/^-?\d+(\.\d+)?$/.test(expr))
        return parseFloat(expr);
    if (expr === "true")
        return true;
    if (expr === "false")
        return false;

    if (expr.startsWith("{") && expr.endsWith("}")) {
        const parts = splitTopLevelCommas(expr.slice(1, -1));
        const out = [];
        for (let i = 0; i < parts.length; i++) {
            const v = evalExpr(parts[i], scope, vars, visited);
            if (v !== undefined)
                out.push(v);
        }
        return out;
    }

    const callMatch = expr.match(/^([a-zA-Z_]\w*)\(([\s\S]*)\)$/);
    if (callMatch) {
        const fname = callMatch[1];
        const fargs = splitTopLevelCommas(callMatch[2]);
        if (fname === "extend_keybind") {
            const a = evalExpr(fargs[0] || "", scope, vars, visited);
            if (typeof a !== "string" || !a.length)
                return undefined;
            const b = evalExpr(fargs[1] || "", scope, vars, visited);
            if (b === undefined || b === null)
                return undefined;
            return a + " + " + String(b);
        }
        if (fname === "normalise_keybind") {
            const a = evalExpr(fargs[0] || "", scope, vars, visited);
            return typeof a === "string" ? a.toLowerCase().replace(/\s+/g, "") : undefined;
        }
        return undefined;
    }

    const concatParts = splitTopLevel(expr, "..");
    if (concatParts.length > 1) {
        let out = "";
        for (let i = 0; i < concatParts.length; i++) {
            const v = evalExpr(concatParts[i], scope, vars, visited);
            if (v === undefined)
                return undefined;
            out += String(v);
        }
        return out;
    }

    const modMatch = expr.match(/^(.+?)\s*%\s*(-?\d+(?:\.\d+)?)$/);
    if (modMatch) {
        const a = evalExpr(modMatch[1], scope, vars, visited);
        const b = parseFloat(modMatch[2]);
        if (typeof a === "number" && !isNaN(b))
            return a % b;
        return undefined;
    }

    const varRef = expr.match(/^vars\.([\w.]+)$/);
    if (varRef && vars && hasOwn(vars, varRef[1])) {
        const v = vars[varRef[1]];
        return v === undefined ? undefined : v;
    }

    if (scope && hasOwn(scope, expr))
        return scope[expr];

    return undefined;
}

// Extract create_bind(...) args respecting nesting and strings
function extractCallArgs(stmt, funcName) {
    const opened = stmt.indexOf(funcName + "(");
    if (opened === -1)
        return null;
    const start = opened + funcName.length + 1;
    let depth = 1;
    let end = -1;
    const n = stmt.length;
    for (let i = start; i < n; i++) {
        const c = stmt[i];
        if (c === '"' || c === "'") {
            i = skipString(stmt, i) - 1;
            continue;
        }
        if (c === "[" && stmt[i + 1] === "[") {
            const e = stmt.indexOf("]]", i + 2);
            i = e === -1 ? n : e + 1;
            continue;
        }
        if (c === "(") {
            depth++;
        } else if (c === ")") {
            depth--;
            if (depth === 0) {
                end = i;
                break;
            }
        }
    }
    if (end === -1)
        return null;
    return stmt.slice(start, end);
}

function resolveKeysExpr(expr, scope, vars) {
    const val = evalExpr(expr, scope, vars);
    if (val === undefined || val === null)
        return [];
    if (Array.isArray(val))
        return val.filter(x => typeof x === "string" && x.length > 0);
    return typeof val === "string" && val.length > 0 ? [val] : [];
}

function processCreateBind(stmt, scope, vars) {
    const argsStr = extractCallArgs(stmt, "create_bind");
    if (argsStr === null)
        return null;
    const args = splitTopLevelCommas(argsStr);
    if (!args.length || !args[0].trim())
        return null;
    const keys = resolveKeysExpr(args[0], scope, vars);
    if (!keys.length) {
        const rawKeys = args[0].trim();
        if (!rawKeys)
            return null;
        return { keys: [rawKeys], comment: "", appRefs: [] };
    }
    let comment = "";
    if (args.length > 2)
        comment = evalExpr(args[2], scope, vars) || "";
    const actionRaw = args.length > 1 ? args[1] : "";
    const appRefs = [];
    const appRe = /vars\.([A-Za-z_]\w*)/g;
    let appMatch;
    while ((appMatch = appRe.exec(actionRaw)) !== null)
        appRefs.push(appMatch[1]);
    return { keys: keys, comment: comment, appRefs: appRefs };
}

// Split an array literal body into element spans (offsets), honoring nesting
function splitTableElements(inner) {
    const spans = [];
    let start = 0;
    let depth = 0;
    let i = 0;
    const n = inner.length;
    while (i < n) {
        const c = inner[i];
        if (c === '"' || c === "'") {
            i = skipString(inner, i);
            continue;
        }
        if (c === "[" && inner[i + 1] === "[") {
            const e = inner.indexOf("]]", i + 2);
            i = e === -1 ? n : e + 2;
            continue;
        }
        if (c === "(" || c === "{") {
            depth++;
            i++;
            continue;
        }
        if (c === ")" || c === "}") {
            if (depth > 0)
                depth--;
            i++;
            continue;
        }
        if (c === "," && depth === 0) {
            if (inner.slice(start, i).trim())
                spans.push({ start: start, end: i });
            start = i + 1;
        }
        i++;
    }
    if (inner.slice(start, i).trim())
        spans.push({ start: start, end: i });
    return spans;
}

// Detailed classify of the first create_bind argument (keys expression)
function classifyKeys(txt) {
    const t = txt.trim();
    if (t.startsWith("{") && t.endsWith("}"))
        return { kind: "table", inner: t.slice(1, -1) };
    return { kind: "single", inner: t };
}

// Parse the flags argument (last create_bind arg). Returns
// { flags: [names], flagsRaw: <raw expression or ""> }.
// Recognizes simple `{ flag = true, ... }` literals (including those already
// stripped of their surrounding braces preserved as raw when unparseable).
function parseFlagsArg(raw) {
    const t = String(raw || "").trim();
    if (!t)
        return { flags: [], flagsRaw: "" };
    if (t.startsWith("{") && t.endsWith("}")) {
        const inner = t.slice(1, -1).replace(/\s+/g, " ").trim();
        if (!inner)
            return { flags: [], flagsRaw: t };
        const flags = [];
        const parts = splitTopLevelCommas(inner);
        let simple = true;
        for (let i = 0; i < parts.length; i++) {
            const m = parts[i].trim().match(/^([A-Za-z_]\w*)\s*=\s*true$/);
            if (m) {
                flags.push(m[1]);
            } else {
                simple = false;
                break;
            }
        }
        if (simple)
            return { flags: flags, flagsRaw: "" };
        return { flags: [], flagsRaw: t };
    }
    return { flags: [], flagsRaw: t };
}

// Detail-level create_bind parse for the editor. Returns keysRaw, key tokens,
// resolved combos, action text, description. Null when not a usable statement.
function processCreateBindDetailed(stmt, scope, vars) {
    const argsStr = extractCallArgs(stmt, "create_bind");
    if (argsStr === null)
        return null;
    const args = splitTopLevelCommas(argsStr);
    if (!args.length || !args[0].trim())
        return null;

    const keysRaw = args[0].trim();
    let kind = "single";
    let elements = [keysRaw];
    if (keysRaw.startsWith("{") && keysRaw.endsWith("}")) {
        kind = "table";
        const spans = splitTableElements(keysRaw.slice(1, -1));
        elements = [];
        for (let i = 0; i < spans.length; i++)
            elements.push(keysRaw.slice(1 + spans[i].start, 1 + spans[i].end));
        if (!elements.length)
            return null;
    } else if (/^["'].*["']$/.test(keysRaw)) {
        kind = "literal";
    } else if (/^vars\.\w+$/.test(keysRaw)) {
        kind = "var";
    } else {
        kind = "expr";
    }

    const keys = [];
    for (let i = 0; i < elements.length; i++) {
        const token = elements[i].trim();
        const resolved = evalExpr(token, scope, vars);
        let combos;
        if (Array.isArray(resolved))
            combos = resolved.filter(x => typeof x === "string" && x.length > 0);
        else if (typeof resolved === "string" && resolved.length)
            combos = [resolved];
        else
            combos = [token];
        if (!combos.length)
            combos.push(token);
        for (let ci = 0; ci < combos.length; ci++) {
            const combo = combos[ci];
            const parts = combo.split(/\s*\+\s*/).map(s => s.trim()).filter(s => s.length > 0);
            keys.push({
                index: i,
                token: token,
                combo: combo,
                mods: parts.slice(0, -1),
                key: parts.length ? parts[parts.length - 1] : combo,
                isVar: /^vars\.\w+$/.test(token)
            });
        }
    }

    let comment = "";
    if (args.length > 2)
        comment = evalExpr(args[2], scope, vars) || "";
    const actionText = (args.length > 1 ? args[1] : "").trim().replace(/\s+/g, " ");
    const luaRaw = (args.length > 1 ? args[1] : "").trim();
    const flagsInfo = parseFlagsArg(args.length > 3 ? args[3] : "");

    const varRefs = [];
    const appRe = /vars\.([A-Za-z_]\w*)/g;
    let m;
    while ((m = appRe.exec(keysRaw)) !== null)
        varRefs.push(m[1]);

    return {
        keysRaw: keysRaw,
        keysKind: kind,
        keys: keys,
        desc: comment,
        actionText: actionText,
        luaRaw: luaRaw,
        flags: flagsInfo.flags,
        flagsRaw: flagsInfo.flagsRaw,
        varRefs: varRefs
    };
}

// Find the index of the matching standalone `end` for a block starting at start
function findBlockEnd(statements, start) {
    let depth = 1;
    let i = start;
    while (i < statements.length) {
        const s = statements[i].trim();
        if (/^\s*(for\s+.+do|if\s+.+then|local\s+function\s+|function\s+)/.test(s))
            depth++;
        else if (s === "end") {
            depth--;
            if (depth === 0)
                return i;
        }
        i++;
    }
    return i;
}

function parseIpairsElements(raw) {
    const parts = splitTopLevelCommas(raw);
    const out = [];
    for (let i = 0; i < parts.length; i++) {
        const v = evalExpr(parts[i], {}, {});
        if (typeof v === "string")
            out.push(v);
    }
    return out;
}

// Parses keybinds.lua into the Cheatsheet tree format.
//   variablesMap: { name: string | [string] } (from parseVariables.map)
//   variablesList: optional [{ name, value, category, note }] (from parseVariables.list)
function parseKeybinds(variablesMap, content, variablesList) {
    const root = { children: [] };
    const vars = variablesMap || {};
    const statements = splitStatements(content);

    const appCategory = {};
    if (Array.isArray(variablesList)) {
        for (let i = 0; i < variablesList.length; i++) {
            const v = variablesList[i];
            if (v && v.category === "Apps" && v.name)
                appCategory[v.name] = true;
        }
    }

    let currentSection = null;
    let pendingSection = null;
    const globalScope = {};

    function getSection(name) {
        const sectionName = name || "General";
        let section = root.children.find(c => c.name === sectionName);
        if (!section) {
            section = { name: sectionName, keybinds: [] };
            root.children.push(section);
        }
        return section;
    }

    function emitBind(keys, comment, appRefs) {
        if (pendingSection !== null) {
            currentSection = getSection(pendingSection);
            pendingSection = null;
        }
        if (!currentSection)
            currentSection = getSection("General");
        let appDefault = "";
        let appVarName = "";
        if (Array.isArray(appRefs)) {
            for (let i = 0; i < appRefs.length; i++) {
                const ref = appRefs[i];
                if (appCategory[ref]) {
                    appVarName = ref;
                    appDefault = String(vars[ref] ?? "");
                    break;
                }
            }
        }
        for (let i = 0; i < keys.length; i++) {
            const parts = String(keys[i]).split(/\s*\+\s*/).map(s => s.trim()).filter(s => s.length > 0);
            if (!parts.length)
                continue;
            const key = parts[parts.length - 1];
            const mods = parts.slice(0, -1);
            currentSection.keybinds.push({
                mods: mods,
                key: key,
                action: "",
                args: "",
                comment: comment || "",
                appDefault: appDefault,
                appVarName: appVarName
            });
        }
    }

    function expandLoop(i) {
        const stmt = statements[i].trim();
        let loopVar = null;
        let iterVals = [];

        const numMatch = stmt.match(/^for\s+(\w+)\s*=\s*(-?\d+)\s*,\s*(-?\d+)(?:\s*,\s*(-?\d+))?\s+do\s*$/);
        if (numMatch) {
            const start = parseInt(numMatch[2], 10);
            const end = parseInt(numMatch[3], 10);
            const step = numMatch[4] ? parseInt(numMatch[4], 10) : 1;
            loopVar = numMatch[1];
            if (step !== 0) {
                if (step > 0) {
                    for (let v = start; v <= end; v += step)
                        iterVals.push(v);
                } else {
                    for (let v = start; v >= end; v += step)
                        iterVals.push(v);
                }
            }
        } else {
            const ipairsLitMatch = stmt.match(/^for\s+_\s*,\s*(\w+)\s+in\s+ipairs\(\s*\{([\s\S]*?)\}\s*\)\s+do\s*$/);
            if (ipairsLitMatch) {
                loopVar = ipairsLitMatch[1];
                iterVals = parseIpairsElements(ipairsLitMatch[2]);
            } else {
                const ipairsVarMatch = stmt.match(/^for\s+_\s*,\s*(\w+)\s+in\s+ipairs\(\s*(\w+)\s*\)\s+do\s*$/);
                if (ipairsVarMatch && hasOwn(globalScope, ipairsVarMatch[2])) {
                    loopVar = ipairsVarMatch[1];
                    const arr = globalScope[ipairsVarMatch[2]];
                    iterVals = Array.isArray(arr) ? arr : [];
                } else {
                    const pairsLitMatch = stmt.match(/^for\s+(\w+)\s*,\s*(\w+)\s+in\s+pairs\(\s*\{([\s\S]*?)\}\s*\)\s+do\s*$/);
                    if (pairsLitMatch) {
                        loopVar = pairsLitMatch[2];
                        iterVals = parseIpairsElements(pairsLitMatch[3]);
                    } else {
                        return findBlockEnd(statements, i + 1) + 1;
                    }
                }
            }
        }

        const bodyStart = i + 1;
        const bodyEnd = findBlockEnd(statements, bodyStart);

        for (let vi = 0; vi < iterVals.length; vi++) {
            const scope = Object.assign({}, globalScope);
            scope[loopVar] = iterVals[vi];
            for (let j = bodyStart; j < bodyEnd; j++) {
                const bl = statements[j].trim();
                if (!bl || bl.startsWith("--"))
                    continue;
                const localMatch = bl.match(/^local\s+(\w+)\s*=\s*(.+)$/);
                if (localMatch) {
                    const val = evalExpr(localMatch[2], scope, vars);
                    if (val !== undefined)
                        scope[localMatch[1]] = val;
                    continue;
                }
                if (bl.startsWith("create_bind(")) {
                    const res = processCreateBind(bl, scope, vars);
                    if (res)
                        emitBind(res.keys, res.comment, res.appRefs);
                    continue;
                }
            }
        }
        return bodyEnd + 1;
    }

    let i = 0;
    while (i < statements.length) {
        const stmt = statements[i].trim();
        if (!stmt) {
            i++;
            continue;
        }

        if (stmt.startsWith("--")) {
            const comment = stmt.replace(/^--+/, "").trim();
            if (comment)
                pendingSection = comment;
            i++;
            continue;
        }

        if (stmt.startsWith("for ")) {
            i = expandLoop(i);
            continue;
        }

        if (/^local\s+\w+\s*=/.test(stmt)) {
            const localMatch = stmt.match(/^local\s+(\w+)\s*=\s*(.+)$/);
            if (localMatch) {
                const val = evalExpr(localMatch[2], globalScope, vars);
                if (val !== undefined)
                    globalScope[localMatch[1]] = val;
            }
            i++;
            continue;
        }

        if (stmt.startsWith("create_bind(")) {
            const res = processCreateBind(stmt, globalScope, vars);
            if (res)
                emitBind(res.keys, res.comment, res.appRefs);
            i++;
            continue;
        }

        i++;
    }

    root.children = root.children.filter(s => s.keybinds.length > 0);
    return root;
}

// Convenience: parse both files together
function parse(variablesContent, keybindsContent) {
    const parsedVars = parseVariables(variablesContent);
    return parseKeybinds(parsedVars.map, keybindsContent);
}

// ---------------------------------------------------------------------------
// Layout-aware editor parsing (line spans per statement)
// ---------------------------------------------------------------------------

// Parses keybinds.lua into an editable statement tree. Each bind carries the
// absolute statement index and physical line span needed to patch the file.
function parseEditor(variablesMap, content, variablesList) {
    const vars = variablesMap || {};
    const detailed = splitStatementsDetailed(content);

    const sections = [];
    let currentSection = null;
    let pendingSection = null;
    const globalScope = {};

    function getSection(name) {
        const sectionName = name || "General";
        let section = null;
        for (let i = 0; i < sections.length; i++) {
            if (sections[i].name === sectionName) {
                section = sections[i];
                break;
            }
        }
        if (!section) {
            section = { name: sectionName, binds: [] };
            sections.push(section);
        }
        return section;
    }

    function emitBind(res, stmtIndex, startLine, endLine, inLoop) {
        if (pendingSection !== null) {
            currentSection = getSection(pendingSection);
            pendingSection = null;
        }
        if (!currentSection)
            currentSection = getSection("General");
        currentSection.binds.push({
            stmtIndex: stmtIndex,
            startLine: startLine,
            endLine: endLine,
            desc: res.desc,
            actionText: res.actionText,
            luaRaw: res.luaRaw || res.actionText,
            flags: res.flags || [],
            flagsRaw: res.flagsRaw || "",
            keysRaw: res.keysRaw,
            keysKind: res.keysKind,
            inLoop: inLoop,
            editable: !inLoop,
            varEditable: res.varRefs.length > 0,
            keys: res.keys
        });
    }

    function expandEditorLoop(i) {
        const stmt = detailed[i].text.trim();
        let loopVar = null;
        let iterVals = [];

        const numMatch = stmt.match(/^for\s+(\w+)\s*=\s*(-?\d+)\s*,\s*(-?\d+)(?:\s*,\s*(-?\d+))?\s+do\s*$/);
        if (numMatch) {
            const start = parseInt(numMatch[2], 10);
            const end = parseInt(numMatch[3], 10);
            const step = numMatch[4] ? parseInt(numMatch[4], 10) : 1;
            loopVar = numMatch[1];
            if (step !== 0) {
                if (step > 0) {
                    for (let v = start; v <= end; v += step)
                        iterVals.push(v);
                } else {
                    for (let v = start; v >= end; v += step)
                        iterVals.push(v);
                }
            }
        } else {
            const ipairsLitMatch = stmt.match(/^for\s+_\s*,\s*(\w+)\s+in\s+ipairs\(\s*\{([\s\S]*?)\}\s*\)\s+do\s*$/);
            if (ipairsLitMatch) {
                loopVar = ipairsLitMatch[1];
                iterVals = parseIpairsElements(ipairsLitMatch[2]);
            } else {
                const ipairsVarMatch = stmt.match(/^for\s+_\s*,\s*(\w+)\s+in\s+ipairs\(\s*(\w+)\s*\)\s+do\s*$/);
                if (ipairsVarMatch && hasOwn(globalScope, ipairsVarMatch[2])) {
                    loopVar = ipairsVarMatch[1];
                    const arr = globalScope[ipairsVarMatch[2]];
                    iterVals = Array.isArray(arr) ? arr : [];
                } else {
                    const pairsLitMatch = stmt.match(/^for\s+(\w+)\s*,\s*(\w+)\s+in\s+pairs\(\s*\{([\s\S]*?)\}\s*\)\s+do\s*$/);
                    if (pairsLitMatch) {
                        loopVar = pairsLitMatch[2];
                        iterVals = parseIpairsElements(pairsLitMatch[3]);
                    } else {
                        return findBlockEnd(detailed.map(s => s.text), i + 1) + 1;
                    }
                }
            }
        }

        const bodyStart = i + 1;
        const bodyEnd = findBlockEnd(detailed.map(s => s.text), bodyStart);

        // Aggregate per-statement across loop iterations: one row per statement
        const perStatement = {};
        for (let vi = 0; vi < iterVals.length; vi++) {
            const scope = Object.assign({}, globalScope);
            scope[loopVar] = iterVals[vi];
            for (let j = bodyStart; j < bodyEnd; j++) {
                const bl = detailed[j].text.trim();
                if (!bl || bl.startsWith("--"))
                    continue;
                const localMatch = bl.match(/^local\s+(\w+)\s*=\s*(.+)$/);
                if (localMatch) {
                    const val = evalExpr(localMatch[2], scope, vars);
                    if (val !== undefined)
                        scope[localMatch[1]] = val;
                    continue;
                }
                if (bl.startsWith("create_bind(")) {
                    const res = processCreateBindDetailed(bl, scope, vars);
                    if (res) {
                        if (!perStatement[j]) {
                            perStatement[j] = {
                                keysRaw: res.keysRaw,
                                keysKind: res.keysKind,
                                desc: res.desc,
                                actionText: res.actionText,
                                luaRaw: res.luaRaw || res.actionText,
                                flags: res.flags || [],
                                flagsRaw: res.flagsRaw || "",
                                varRefs: res.varRefs,
                                keys: []
                            };
                        }
                        for (let k = 0; k < res.keys.length; k++)
                            perStatement[j].keys.push(res.keys[k]);
                    }
                    continue;
                }
            }
        }

        const keysByIdx = {};
        for (const j in perStatement) {
            const st = perStatement[j];
            const stmtIdx = parseInt(j, 10);
            if (!keysByIdx[stmtIdx])
                keysByIdx[stmtIdx] = [];
            for (let k = 0; k < st.keys.length; k++)
                keysByIdx[stmtIdx].push(st.keys[k]);
        }
        for (const j in keysByIdx) {
            const stmtIdx = parseInt(j, 10);
            const st = perStatement[stmtIdx];
            const keys = [];
            for (let k = 0; k < keysByIdx[stmtIdx].length; k++) {
                const src = keysByIdx[stmtIdx][k];
                keys.push({
                    index: k,
                    token: src.token,
                    combo: src.combo,
                    mods: src.mods,
                    key: src.key,
                    isVar: src.isVar
                });
            }
            emitBind({
                keysRaw: st.keysRaw,
                keysKind: st.keysKind,
                desc: st.desc,
                actionText: st.actionText,
                luaRaw: st.luaRaw || st.actionText,
                flags: st.flags || [],
                flagsRaw: st.flagsRaw || "",
                varRefs: st.varRefs,
                keys: keys
            }, stmtIdx, detailed[stmtIdx].startLine, detailed[stmtIdx].endLine, true);
        }
        return bodyEnd + 1;
    }

    let i = 0;
    while (i < detailed.length) {
        const stmt = detailed[i].text.trim();
        if (!stmt) {
            i++;
            continue;
        }

        if (stmt.startsWith("--")) {
            const comment = stmt.replace(/^--+/, "").trim();
            if (comment)
                pendingSection = comment;
            i++;
            continue;
        }

        if (stmt.startsWith("for ")) {
            i = expandEditorLoop(i);
            continue;
        }

        if (/^local\s+\w+\s*=/.test(stmt)) {
            const localMatch = stmt.match(/^local\s+(\w+)\s*=\s*(.+)$/);
            if (localMatch) {
                const val = evalExpr(localMatch[2], globalScope, vars);
                if (val !== undefined)
                    globalScope[localMatch[1]] = val;
            }
            i++;
            continue;
        }

        if (stmt.startsWith("create_bind(")) {
            const res = processCreateBindDetailed(stmt, globalScope, vars);
            if (res)
                emitBind(res, i, detailed[i].startLine, detailed[i].endLine, false);
            i++;
            continue;
        }

        i++;
    }

    return { sections: sections.filter(s => s.binds.length > 0) };
}

// ---------------------------------------------------------------------------
// Keybind file patching (byte-preserving for everything but the edited span)
// ---------------------------------------------------------------------------

function lineStarts(content) {
    const starts = [0];
    let idx = 0;
    while (idx < content.length) {
        const nl = content.indexOf("\n", idx);
        if (nl === -1)
            break;
        starts.push(nl + 1);
        idx = nl + 1;
    }
    return starts;
}

function quoteCombo(combo) {
    return '"' + String(combo).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';
}

// Find the first comma at the create_bind paren level (depth 1, no brace nest)
function findFirstLevelComma(str, from) {
    let depth = 1;
    let bdepth = 0;
    let i = from;
    const n = str.length;
    while (i < n) {
        const c = str[i];
        if (c === '"' || c === "'") {
            i = skipString(str, i);
            continue;
        }
        if (c === "[" && str[i + 1] === "[") {
            const e = str.indexOf("]]", i + 2);
            i = e === -1 ? n : e + 2;
            continue;
        }
        if (c === "(") {
            depth++;
            i++;
            continue;
        }
        if (c === ")") {
            depth--;
            i++;
            if (depth === 0)
                return -1;
            continue;
        }
        if (c === "{") {
            bdepth++;
            i++;
            continue;
        }
        if (c === "}") {
            if (bdepth > 0)
                bdepth--;
            i++;
            continue;
        }
        if (c === "," && depth === 1 && bdepth === 0)
            return i;
        i++;
    }
    return -1;
}

function findMatchingCloseParen(str, openIdx) {
    let depth = 1;
    let i = openIdx + 1;
    const n = str.length;
    while (i < n) {
        const c = str[i];
        if (c === '"' || c === "'") {
            i = skipString(str, i);
            continue;
        }
        if (c === "[") {
            const e = str.indexOf("]]", i + 1);
            i = e === -1 ? n : e + 2;
            continue;
        }
        if (c === "(") {
            depth++;
        } else if (c === ")") {
            depth--;
            if (depth === 0)
                return i;
        }
        i++;
    }
    return -1;
}

function stringifyArgs0(kind, inner, tokens) {
    if (kind === "table")
        return "{" + tokens.join(", ") + "}";
    return tokens[0] || inner;
}

function escapeRegExp(str) {
    return String(str).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function indentMultiline(str, prefix) {
    return String(str).trim().split("\n").map(line => line.trim() === "" ? "" : prefix + line).join("\n");
}

// Builds a formatted create_bind(...) statement for a custom shortcut.
// op: { name, lua, desc, flags, flagsRaw, literalKeys } where name is the vars.*
// reference (no prefix). When flagsRaw is provided it is emitted verbatim in
// place of the simple flag list, preserving complex expressions (e.g.
// function(...) end). When literalKeys (array of raw key tokens) is provided,
// the keys argument becomes a table preserving those literals alongside the
// vars.* reference (used when editing multi-key table binds).
function createKeybindStatement(op) {
    const name = String(op?.name || "").trim();
    const lua = String(op?.lua ?? "").trim();
    if (!name || !/^[A-Za-z_]\w*$/.test(name) || !lua)
        return "";
    const literalKeys = (Array.isArray(op.literalKeys) ? op.literalKeys : [])
        .map(k => String(k).trim())
        .filter(k => k !== "");
    const desc = String(op.desc ?? "").trim();
    let flagsText = "";
    if (op.flagsRaw !== undefined && String(op.flagsRaw).trim() !== "") {
        flagsText = String(op.flagsRaw).trim();
    } else {
        const flags = (Array.isArray(op.flags) ? op.flags : [])
            .map(f => String(f).trim())
            .filter(f => /^[A-Za-z_]\w*$/.test(f));
        if (flags.length)
            flagsText = "{ " + flags.map(f => f + " = true").join(", ") + " }";
    }
    const hasDesc = desc !== "";
    const hasFlags = flagsText !== "";

    const lines = ["create_bind("];
    if (literalKeys.length) {
        lines.push("    {");
        lines.push("        vars." + name + ",");
        for (let i = 0; i < literalKeys.length; i++)
            lines.push("        " + indentMultiline(literalKeys[i], "        ") + ",");
        lines.push("    }" + ((hasDesc || hasFlags) ? "," : ""));
    } else {
        lines.push("    vars." + name + ",");
    }
    lines.push(indentMultiline(lua, "    ") + ((hasDesc || hasFlags) ? "," : ""));
    if (hasDesc)
        lines.push("    " + quoteCombo(desc) + (hasFlags ? "," : ""));
    if (hasFlags)
        lines.push(indentMultiline(flagsText, "    "));
    lines.push(")");
    return lines.join("\n");
}

// Inserts a statement into the -- <section> block of keybinds.lua, creating the
// section at EOF when missing. Returns { content, changed }.
function insertKeybindStatement(content, section, statement) {
    if (!content || !section || !statement)
        return { content: content, changed: false };
    const headerRe = new RegExp("^\\s*--\\s*" + escapeRegExp(section) + "\\s*$");
    const lines = content.split("\n");
    const block = statement + "\n";

    let headerIdx = -1;
    for (let i = 0; i < lines.length; i++) {
        if (headerRe.test(lines[i]))
            headerIdx = i;
    }

    if (headerIdx === -1) {
        let out = content;
        if (out.length && !out.endsWith("\n"))
            out += "\n";
        if (!out.endsWith("\n\n"))
            out += "\n";
        out += "-- " + section + "\n" + block;
        return { content: out, changed: out !== content };
    }

    let boundary = lines.length;
    for (let i = headerIdx + 1; i < lines.length; i++) {
        if (lines[i].trim().startsWith("--")) {
            boundary = i;
            break;
        }
    }

    let insertAt = headerIdx + 1;
    for (let i = boundary - 1; i > headerIdx; i--) {
        if (lines[i].trim() !== "") {
            insertAt = i + 1;
            break;
        }
        insertAt = i;
    }

    lines.splice(insertAt, 0, "", block.trim());
    const newContent = lines.join("\n");
    return { content: newContent, changed: newContent !== content };
}

// Returns the -- <section> header text that immediately precedes the statement
// at stmtIndex, or null when it is not under a section header. Ordinary
// statements (and non-header comments) between the statement and its header are
// skipped so the nearest header above is found; banner lines are treated as the
// absence of a section header.
function findStatementSection(detailed, stmtIndex) {
    for (let i = stmtIndex - 1; i >= 0; i--) {
        const t = detailed[i].text.trim();
        if (!t || !t.startsWith("--"))
            continue;
        const name = t.replace(/^--+\s*/, "").trim();
        if (!name || /^[-=]+$/.test(name))
            return null;
        return name;
    }
    return null;
}

// Returns true when the given section header still has any non-empty
// create_bind statement beneath it.
function sectionHasBinds(content, section) {
    const headerRe = new RegExp("^\\s*--\\s*" + escapeRegExp(section) + "\\s*$");
    const lines = content.split("\n");
    let idx = -1;
    for (let i = 0; i < lines.length; i++) {
        if (headerRe.test(lines[i])) {
            idx = i;
            break;
        }
    }
    if (idx === -1)
        return false;
    for (let i = idx + 1; i < lines.length; i++) {
        const t = lines[i].trim();
        if (t === "")
            continue;
        if (t.startsWith("--"))
            break;
        return true;
    }
    return false;
}

// Removes an empty -- <section> header and its trailing blank lines from content.
function pruneSectionHeader(content, section) {
    const headerRe = new RegExp("^\\s*--\\s*" + escapeRegExp(section) + "\\s*$");
    const lines = content.split("\n");
    let headerIdx = -1;
    for (let i = 0; i < lines.length; i++) {
        if (headerRe.test(lines[i])) {
            headerIdx = i;
            break;
        }
    }
    if (headerIdx === -1)
        return content;
    let end = headerIdx;
    while (end + 1 < lines.length && lines[end + 1].trim() === "")
        end++;
    const newLines = lines.slice(0, headerIdx).concat(lines.slice(end + 1));
    return newLines.join("\n");
}

// Applies a single edit op. ops: change (replace key element), add (append a
// combo), remove (drop a key element; last key removes whole statement),
// create (insert a whole create_bind statement into a section), update
// (rebuild a statement and move it to a section).
function applyKeybindsSingleOp(content, op) {
    if (!content || content.length <= 0)
        return { content: content, changed: false };

    if (op.op === "create") {
        if (!op.section || !op.statement)
            return { content: content, changed: false };
        const res = insertKeybindStatement(content, op.section, op.statement);
        return { content: res.content, changed: res.content !== content };
    }

    const detailed = splitStatementsDetailed(content);
    const stmt = detailed[op.stmtIndex];
    if (!stmt)
        return { content: content, changed: false };

    const starts = lineStarts(content);
    const stmtStart = starts[stmt.startLine];
    const stmtEnd = (stmt.endLine + 1 < starts.length) ? starts[stmt.endLine + 1] : content.length;
    const stmtText = content.slice(stmtStart, stmtEnd);

    const opened = stmtText.indexOf("create_bind(");
    if (opened === -1)
        return { content: content, changed: false };
    const argStart = opened + "create_bind(".length;

    let argEnd = findFirstLevelComma(stmtText, argStart);
    if (argEnd === -1) {
        const close = findMatchingCloseParen(stmtText, opened);
        if (close === -1)
            return { content: content, changed: false };
        argEnd = close;
    }
    if (argEnd <= argStart)
        return { content: content, changed: false };

    const args0Text = stmtText.slice(argStart, argEnd);
    const args0Start = stmtStart + argStart;
    const args0End = stmtStart + argEnd;
    const trimmedStart = args0Text.length - args0Text.replace(/^\s+/, "").length;
    const args0Trim = args0Text.slice(trimmedStart);
    const cls = classifyKeys(args0Trim);

    // Element spans (relative to args0Text). base = offset where elements start
    let spans = [];
    let base = 0;
    let inner = cls.inner;
    if (cls.kind === "table") {
        spans = splitTableElements(cls.inner);
        base = trimmedStart + 1;
    } else {
        inner = cls.inner;
        spans = [{ start: 0, end: cls.inner.length }];
        base = trimmedStart;
    }

    function elemText(i) {
        const str = cls.kind === "table" ? inner : args0Trim;
        return str.slice(spans[i].start, spans[i].end);
    }

    function replaceAbs(kind, inner, tokens) {
        const rebuilt = stringifyArgs0(kind, inner, tokens);
        return content.slice(0, args0Start) + rebuilt + content.slice(args0End);
    }

    if (op.op === "change") {
        if (!op.combo || !spans[op.keyIndex])
            return { content: content, changed: false };
        const span = spans[op.keyIndex];
        const absStart = args0Start + base + span.start;
        const absEnd = args0Start + base + span.end;
        const newContent = content.slice(0, absStart) + quoteCombo(op.combo) + content.slice(absEnd);
        return { content: newContent, changed: newContent !== content };
    }

    if (op.op === "add") {
        if (!op.combo)
            return { content: content, changed: false };
        const tokens = [];
        for (let i = 0; i < spans.length; i++)
            tokens.push(elemText(i).trim());
        if (cls.kind === "table") {
            tokens.push(quoteCombo(op.combo));
        } else {
            if (cls.kind === "expr")
                return { content: content, changed: false };
            tokens[0] = cls.inner.trim();
            const newArgs0 = "{" + tokens.join(", ") + ", " + quoteCombo(op.combo) + "}";
            const newContent = content.slice(0, args0Start) + newArgs0 + content.slice(args0End);
            return { content: newContent, changed: newContent !== content };
        }
        const newContent = replaceAbs("table", cls.inner, tokens);
        return { content: newContent, changed: newContent !== content };
    }

    if (op.op === "remove") {
        if (!spans.length)
            return { content: content, changed: false };
        const idx = op.keyIndex;
        if (idx < 0 || idx >= spans.length)
            return { content: content, changed: false };
        if (spans.length <= 1) {
            const newContent = content.slice(0, stmtStart) + content.slice(stmtEnd);
            return { content: newContent, changed: newContent !== content };
        }
        let tokens = [];
        for (let i = 0; i < spans.length; i++) {
            if (i !== idx)
                tokens.push(elemText(i).trim());
        }
        let newContent;
        if (cls.kind === "table") {
            newContent = replaceAbs("table", cls.inner, tokens);
        } else {
            newContent = replaceAbs("single", tokens[0] || cls.inner, tokens);
        }
        return { content: newContent, changed: newContent !== content };
    }

    if (op.op === "update") {
        if (!op.statement || !op.section)
            return { content: content, changed: false };
        const oldSection = findStatementSection(detailed, op.stmtIndex);
        if (oldSection && oldSection === String(op.section)) {
            const inPlace = content.slice(0, stmtStart) + op.statement + "\n" + content.slice(stmtEnd);
            return { content: inPlace, changed: inPlace !== content };
        }
        const removedContent = content.slice(0, stmtStart) + content.slice(stmtEnd);
        const res = insertKeybindStatement(removedContent, op.section, op.statement);
        if (!res.changed)
            return res;
        let finalContent = res.content;
        if (oldSection && oldSection !== String(op.section)) {
            if (!sectionHasBinds(finalContent, oldSection))
                finalContent = pruneSectionHeader(finalContent, oldSection);
        }
        return { content: finalContent, changed: finalContent !== content };
    }

    if (op.op === "delete") {
        const delSection = findStatementSection(detailed, op.stmtIndex);
        let newContent = content.slice(0, stmtStart) + content.slice(stmtEnd);
        if (delSection && !sectionHasBinds(newContent, delSection))
            newContent = pruneSectionHeader(newContent, delSection);
        return { content: newContent, changed: newContent !== content };
    }

    if (op.op === "reorder") {
        const from = detailed[op.stmtIndex];
        if (!from)
            return { content: content, changed: false };
        const sec = findStatementSection(detailed, op.stmtIndex);
        if (!sec)
            return { content: content, changed: false };
        const secBinds = [];
        for (let i = 0; i < detailed.length; i++) {
            if (i === op.stmtIndex)
                continue;
            if (String(detailed[i].text).trim().startsWith("--"))
                continue;
            if (findStatementSection(detailed, i) === sec)
                secBinds.push(i);
        }
        if (!secBinds.length)
            return { content: content, changed: false };
        const fromText = content.slice(stmtStart, stmtEnd);
        let targetB = null;
        if (op.beforeStmtIndex === -1) {
            const last = secBinds[secBinds.length - 1];
            const ls = lineStarts(content);
            targetB = last >= 0 ? ls[detailed[last].endLine + 1] : content.length;
        } else if (op.beforeStmtIndex !== op.stmtIndex) {
            const t = detailed[op.beforeStmtIndex];
            if (!t)
                return { content: content, changed: false };
            const tStart = lineStarts(content)[t.startLine];
            if (tStart === stmtStart)
                return { content: content, changed: false };
            targetB = tStart;
        } else {
            return { content: content, changed: false };
        }
        if (targetB === null || targetB === stmtStart || targetB === stmtEnd)
            return { content: content, changed: false };
        let newContent;
        if (targetB < stmtStart) {
            newContent = content.slice(0, targetB) + fromText + content.slice(targetB, stmtStart) + content.slice(stmtEnd);
        } else {
            newContent = content.slice(0, stmtStart) + content.slice(stmtEnd, targetB) + fromText + content.slice(targetB);
        }
        return { content: newContent, changed: newContent !== content };
    }

    return { content: content, changed: false };
}

// Applies a sequence of ops to keybinds.lua content (single-op use recommended)
function applyKeybindsOps(content, ops) {
    let c = content;
    let changed = false;
    for (let i = 0; i < ops.length; i++) {
        const res = applyKeybindsSingleOp(c, ops[i]);
        if (res.changed) {
            c = res.content;
            changed = true;
        }
    }
    return { content: c, changed: changed };
}

// Upserts a variable entry under the -- <category> header of variables.lua. With
// op.literal === true numbers and booleans are written as raw Lua literals rather
// than quoted strings. Returns { content, changed }.
function applyVariablesCreateOp(content, op) {
    if (!content || !op || !op.name || op.value === undefined)
        return { content: content, changed: false };
    const name = String(op.name).trim();
    const literal = op.literal === true;
    const value = Array.isArray(op.value)
        ? "{ " + op.value.filter(v => String(v).trim() !== "").map(v => quoteCombo(v)).join(", ") + " }"
        : literal && typeof op.value === "number" ? String(op.value)
        : literal && typeof op.value === "boolean" ? (op.value ? "true" : "false")
        : quoteCombo(String(op.value));
    const section = String(op.category || "Misc").trim();

    let lines = content.split("\n");

    const nameRe = new RegExp("^\\s*" + escapeRegExp(name) + "\\s*=");
    const filtered = [];
    for (let i = 0; i < lines.length; i++) {
        if (nameRe.test(lines[i]))
            continue;
        filtered.push(lines[i]);
    }
    lines = filtered;

    const headerRe = new RegExp("^\\s*--\\s*" + escapeRegExp(section) + "\\s*$");
    let headerIdx = -1;
    for (let i = 0; i < lines.length; i++) {
        if (headerRe.test(lines[i]))
            headerIdx = i;
    }

    const entry = "    " + name + " = " + value + ",";

    if (headerIdx === -1) {
        let closeIdx = -1;
        for (let i = lines.length - 1; i >= 0; i--) {
            if (lines[i].trim() === "}") {
                closeIdx = i;
                break;
            }
        }
        if (closeIdx === -1)
            return { content: content, changed: false };
        const block = [];
        const prev = closeIdx > 0 ? lines[closeIdx - 1].trim() : "";
        if (prev !== "")
            block.push("");
        block.push("    -- " + section);
        block.push(entry);
        lines.splice(closeIdx, 0, ...block);
    } else {
        let boundary = lines.length;
        for (let i = headerIdx + 1; i < lines.length; i++) {
            const t = lines[i].trim();
            if (t.startsWith("--") || t === "}") {
                boundary = i;
                break;
            }
        }
        let insertAt = headerIdx + 1;
        for (let i = boundary - 1; i > headerIdx; i--) {
            if (lines[i].trim() !== "") {
                insertAt = i + 1;
                break;
            }
            insertAt = i;
        }
        lines.splice(insertAt, 0, entry);
    }

    const newContent = lines.join("\n");
    return { content: newContent, changed: newContent !== content };
}

// Removes a keybind variable line from variables.lua and prunes its -- <section>
// header when that section is left empty. op: { name, category }. Returns
// { content, changed }.
function applyVariablesRemoveOp(content, op) {
    if (!content || !op || !op.name)
        return { content: content, changed: false };
    const name = String(op.name).trim();
    if (!name)
        return { content: content, changed: false };
    const section = String(op.category || "").trim();
    const nameRe = new RegExp("^\\s*" + escapeRegExp(name) + "\\s*=.*$");
    const lines = content.split("\n");
    const filtered = [];
    let removed = false;
    for (let i = 0; i < lines.length; i++) {
        if (nameRe.test(lines[i])) {
            removed = true;
            continue;
        }
        filtered.push(lines[i]);
    }
    if (!removed)
        return { content: content, changed: false };
    let newContent = filtered.join("\n");
    if (section) {
        const headerRe = new RegExp("^\\s*--\\s*" + escapeRegExp(section) + "\\s*$");
        const hLines = newContent.split("\n");
        let headerIdx = -1;
        for (let i = 0; i < hLines.length; i++) {
            if (headerRe.test(hLines[i])) {
                headerIdx = i;
                break;
            }
        }
        if (headerIdx !== -1) {
            let hasBody = false;
            for (let i = headerIdx + 1; i < hLines.length; i++) {
                const t = hLines[i].trim();
                if (t === "")
                    continue;
                if (t.startsWith("--") || t === "}")
                    break;
                hasBody = true;
                break;
            }
            if (!hasBody) {
                let end = headerIdx;
                while (end + 1 < hLines.length && hLines[end + 1].trim() === "")
                    end++;
                newContent = hLines.slice(0, headerIdx).concat(hLines.slice(end + 1)).join("\n");
            }
        }
    }
    return { content: newContent, changed: newContent !== content };
}