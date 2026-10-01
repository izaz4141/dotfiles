const fs = require("fs");
const path = require("path");

const parserPath = path.join(__dirname, "..", "Modules", "Cheatsheet", "HyprlandParser.js");
let source = fs.readFileSync(parserPath, "utf8");

source = source.replace(/^\.pragma library\s*\n/, "");

const moduleObject = {};
const fn = new Function("module", "exports", "require", source + "\n;module.exports={parseVariables,parseEditor,processCreateBindDetailed};");
fn(moduleObject, moduleObject.exports, require);

const { parseVariables, parseEditor } = moduleObject.exports;

let passed = 0;
let failed = 0;
const results = [];

function assertEq(actual, expected, label) {
    const ok = actual === expected;
    if (ok) {
        passed++;
    } else {
        failed++;
        results.push(`FAIL: ${label} — expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
    }
}

function assertDeep(actual, expected, label) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    const ok = a === e;
    if (ok) {
        passed++;
    } else {
        failed++;
        results.push(`FAIL: ${label} — expected ${e}, got ${a}`);
    }
}

const variablesLua = `
return {
    -- Workspaces
    kbNextWsGroup = "CTRL + SUPER + mouse_down",
    kbPrevWsGroup = "CTRL + SUPER + mouse_up",
    kbNextWs = { "SUPER + mouse_down", "CTRL + SUPER + Right", "SUPER + Page_Down" },
    kbPrevWs = { "SUPER + mouse_up", "CTRL + SUPER + Left", "SUPER + Page_Up" },
    kbScalar = "SUPER + K",
}
`;

const keybindsLua = `
create_bind(vars.kbNextWsGroup, hl.dsp.focus({ workspace = "+10" }), "Go to next workspace group", repeating_unless_mouse)
create_bind(vars.kbNextWs, hl.dsp.focus({ workspace = "+1" }), "Go to next workspace", repeating_unless_mouse)
create_bind(vars.kbPrevWs, hl.dsp.focus({ workspace = "-1" }), "Go to previous workspace", repeating_unless_mouse)
create_bind(vars.kbScalar, dispatch("exec", "echo hi"), "Scalar bind")
create_bind(vars.kbMissing, dispatch("exec", "echo missing"), "Missing var bind")
`;

const { map: variablesMap, list: variablesList } = parseVariables(variablesLua);
const editor = parseEditor(variablesMap, keybindsLua, variablesList);

function findBind(desc) {
    for (const section of editor.sections) {
        for (const bind of section.binds) {
            if (bind.desc === desc)
                return bind;
        }
    }
    return null;
}

const nextWs = findBind("Go to next workspace");
assertEq(nextWs !== null && nextWs.keys.length, 3, "kbNextWs emits 3 chips");
if (nextWs) {
    assertEq(nextWs.keysKind, "var", "kbNextWs keysKind is var");
    assertDeep(nextWs.keys.map(k => k.token), ["vars.kbNextWs", "vars.kbNextWs", "vars.kbNextWs"], "kbNextWs tokens all var refs");
    assertDeep(nextWs.keys.map(k => k.combo), ["SUPER + mouse_down", "CTRL + SUPER + Right", "SUPER + Page_Down"], "kbNextWs resolved combos");
    assertDeep(nextWs.keys.map(k => k.isVar), [true, true, true], "kbNextWs all isVar");
    assertEq(nextWs.keys[2].key, "Page_Down", "kbNextWs last key is Page_Down");
}

const prevWs = findBind("Go to previous workspace");
assertEq(prevWs !== null && prevWs.keys.length, 3, "kbPrevWs emits 3 chips");
if (prevWs) {
    assertEq(prevWs.keys[2].key, "Page_Up", "kbPrevWs last key is Page_Up");
    assertEq(prevWs.keys[0].combo, "SUPER + mouse_up", "kbPrevWs first combo");
}

const nextWsGroup = findBind("Go to next workspace group");
assertEq(nextWsGroup !== null && nextWsGroup.keys.length, 1, "scalar var emits 1 chip (no regression)");
if (nextWsGroup) {
    assertEq(nextWsGroup.keys[0].combo, "CTRL + SUPER + mouse_down", "scalar var resolved combo");
    assertEq(nextWsGroup.keys[0].key, "mouse_down", "scalar var last key");
    assertEq(nextWsGroup.keys[0].isVar, true, "scalar var isVar");
}

const scalar = findBind("Scalar bind");
assertEq(scalar !== null && scalar.keys.length, 1, "scalar bind 1 chip");
if (scalar) {
    assertEq(scalar.keys[0].combo, "SUPER + K", "scalar bind combo");
    assertEq(scalar.keys[0].key, "K", "scalar bind key");
}

const missing = findBind("Missing var bind");
assertEq(missing !== null && missing.keys.length, 1, "missing var falls back to 1 chip");
if (missing) {
    assertEq(missing.keys[0].combo, "vars.kbMissing", "missing var shows raw token (no regression)");
    assertEq(missing.keys[0].isVar, true, "missing var still isVar");
}

console.log(`\n${passed} passed, ${failed} failed`);
if (results.length)
    console.log(results.join("\n"));
process.exit(failed ? 1 : 0);
