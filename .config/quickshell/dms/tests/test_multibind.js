// Tests for multi-bind variable support in HyprlandParser.js
// Run: node test/test_multibind.js

const fs = require("fs");
const path = require("path");

const src = fs.readFileSync(
    path.join(__dirname, "../Modules/Cheatsheet/HyprlandParser.js"),
    "utf8"
);
const cleaned = src.replace(/^\.pragma library\n/, "");
eval(cleaned);

let pass = 0;
let fail = 0;

function assert(label, got, want) {
    const a = JSON.stringify(got);
    const b = JSON.stringify(want);
    if (a === b) {
        pass++;
        console.log(`  PASS  ${label}`);
    } else {
        fail++;
        console.log(`  FAIL  ${label}`);
        console.log(`    got:  ${a}`);
        console.log(`    want: ${b}`);
    }
}

// ---------------------------------------------------------------
console.log("\n=== applyVariablesCreateOp: single value ===");
{
    const content = "return {\n    -- Misc\n    kbFoo = \"SUPER + T\",\n}\n";
    const res = applyVariablesCreateOp(content, {
        name: "kbNew",
        value: "SUPER + A",
        category: "Misc"
    });
    assert("changed", res.changed, true);
    assert("contains new var", res.content.includes("kbNew = \"SUPER + A\""), true);
    assert("existing preserved", res.content.includes("kbFoo"), true);
}

// ---------------------------------------------------------------
console.log("\n=== applyVariablesCreateOp: array value ===");
{
    const content = "return {\n    -- Util\n    kbOld = \"CTRL + A\",\n}\n";
    const res = applyVariablesCreateOp(content, {
        name: "kbMulti",
        value: ["SUPER + A", "CTRL + A", "ALT + A"],
        category: "Util"
    });
    assert("changed", res.changed, true);
    assert("array format", res.content.includes("{ \"SUPER + A\", \"CTRL + A\", \"ALT + A\" }"), true);
    assert("existing preserved", res.content.includes("kbOld"), true);
}

// ---------------------------------------------------------------
console.log("\n=== applyVariablesCreateOp: replace single with array ===");
{
    const content = "return {\n    -- Util\n    kbShort = \"SUPER + T\",\n}\n";
    const res = applyVariablesCreateOp(content, {
        name: "kbShort",
        value: ["SUPER + T", "CTRL + T"],
        category: "Util"
    });
    assert("changed", res.changed, true);
    assert("array replaces string", res.content.includes("kbShort = { \"SUPER + T\", \"CTRL + T\" }"), true);
}

// ---------------------------------------------------------------
console.log("\n=== applyVariablesCreateOp: replace array with single ===");
{
    const content = "return {\n    -- Util\n    kbShort = { \"SUPER + T\", \"CTRL + T\" },\n}\n";
    const res = applyVariablesCreateOp(content, {
        name: "kbShort",
        value: "SUPER + A",
        category: "Util"
    });
    assert("changed", res.changed, true);
    assert("single replaces array", res.content.includes("kbShort = \"SUPER + A\""), true);
}

// ---------------------------------------------------------------
console.log("\n=== parseVariables: array roundtrip ===");
{
    const content = "local scheme = require(\"scheme.current\")\nreturn {\n    -- Util\n    kbMulti = { \"SUPER + A\", \"CTRL + A\" },\n    kbSingle = \"SUPER + T\",\n}\n";
    const parsed = parseVariables(content);
    assert("array value", parsed.map["kbMulti"], ["SUPER + A", "CTRL + A"]);
    assert("single value", parsed.map["kbSingle"], "SUPER + T");
    assert("list entry array", parsed.list[0].value, ["SUPER + A", "CTRL + A"]);
    assert("list entry single", parsed.list[1].value, "SUPER + T");
}

// ---------------------------------------------------------------
console.log("\n=== parseEditor: array variable resolves to multiple keys ===");
{
    const varsMap = { "kbMulti": ["SUPER + A", "CTRL + A"] };
    const varsList = [{ name: "kbMulti", value: ["SUPER + A", "CTRL + A"], category: "Util", note: null }];
    const keybinds = "-- Util\ncreate_bind(\n    vars.kbMulti,\n    hl.dsp.exec_cmd(\"echo hi\"),\n    \"Test bind\"\n)\n";
    const ed = parseEditor(varsMap, keybinds, varsList);
    const bind = ed.sections[0]?.binds[0];
    assert("bind found", !!bind, true);
    assert("2 keys resolved", bind?.keys?.length, 2);
    assert("key 0", bind?.keys[0]?.combo, "SUPER + A");
    assert("key 1", bind?.keys[1]?.combo, "CTRL + A");
    assert("editable", bind?.editable, true);
    assert("varEditable", bind?.varEditable, true);
}

// ---------------------------------------------------------------
console.log("\n=== createKeybindStatement: no literalKeys → vars.kbX form ===");
{
    const stmt = createKeybindStatement({
        name: "kbMulti",
        lua: "hl.dsp.exec_cmd(\"echo hi\")",
        desc: "Test",
        flags: []
    });
    assert("has vars.kbMulti", stmt.includes("vars.kbMulti"), true);
    assert("no table", !stmt.includes("{"), true);
}

// ---------------------------------------------------------------
console.log("\n=== applyKeybindsOps: update op works with var ref ===");
{
    const content = "-- Util\ncreate_bind(\n    vars.kbOld,\n    hl.dsp.exec_cmd(\"old\"),\n    \"Old bind\"\n)\n";
    const newStmt = "create_bind(\n    vars.kbMulti,\n    hl.dsp.exec_cmd(\"new\"),\n    \"New bind\"\n)\n";
    const res = applyKeybindsOps(content, [{
        op: "update",
        stmtIndex: 1,
        statement: newStmt,
        section: "Util"
    }]);
    assert("changed", res.changed, true);
    assert("old removed", !res.content.includes("kbOld"), true);
    assert("new inserted", res.content.includes("vars.kbMulti"), true);
}

// ---------------------------------------------------------------
console.log("\n=== splitStatementsDetailed: multiline create_bind with local/for stays whole ===");
{
    const varsMap = { "kbPip": "SUPER + P" };
    const varsList = [{ name: "kbPip", value: "SUPER + P", category: "Windows", note: null }];
    const content = "-- Window actions\ncreate_bind(vars.kbPip, function()\n    local a = hl.get_active_window()\n    if a then\n        local pip = {}\n        for _, x in ipairs(pip) do\n            hl.dispatch(x)\n        end\n    end\nend, \"Toggle picture-in-picture\")\n";
    const ed = parseEditor(varsMap, content, varsList);
    const bind = ed.sections[0]?.binds.find(b => b.keysRaw.includes("kbPip"));
    assert("multiline bind parsed", !!bind, true);
    assert("desc parsed", bind?.desc, "Toggle picture-in-picture");
    assert("stmtIndex is whole statement", bind?.stmtIndex, 1);
    const newStmt = "create_bind(vars.kbPip, function()\n    local a2 = true\nend, \"Toggle picture-in-picture\")\n";
    const res = applyKeybindsOps(content, [{ op: "update", stmtIndex: bind.stmtIndex, statement: newStmt, section: "Window actions" }]);
    assert("update changed", res.changed, true);
    assert("rebuilt body present", res.content.includes("local a2"), true);
    assert("old fragment absent", !res.content.includes("hl.get_active_window"), true);
}

// ---------------------------------------------------------------
console.log("\n=== createKeybindStatement/update: literal companion keys preserved on table bind ===");
{
    const content = "-- Media\ncreate_bind({ vars.kbVolumeMute, \"XF86AudioMute\" }, hl.dsp.exec_cmd(\"wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle\"), \"Mute\")\n";
    const varsMap = { "kbVolumeMute": "SUPER + M" };
    const varsList = [{ name: "kbVolumeMute", value: "SUPER + M", category: "Media", note: null }];
    const ed = parseEditor(varsMap, content, varsList);
    const bind = ed.sections[0]?.binds[0];
    assert("table bind parsed", !!bind, true);
    assert("keysKind table", bind?.keysKind, "table");
    const stmt = createKeybindStatement({ name: "kbVolumeMute", lua: "hl.dsp.exec_cmd(\"newmute\")", desc: bind.desc, flags: [], literalKeys: ['"XF86AudioMute"'] });
    assert("literal key emitted", stmt.includes('"XF86AudioMute"'), true);
    const res = applyKeybindsOps(content, [{ op: "update", stmtIndex: bind.stmtIndex, statement: stmt, section: "Media" }]);
    assert("update changed", res.changed, true);
    assert("var ref preserved", res.content.includes("vars.kbVolumeMute"), true);
    assert("literal key preserved", res.content.includes('"XF86AudioMute"'), true);
    const ed2 = parseEditor(varsMap, res.content, varsList);
    const b2 = ed2.sections[0]?.binds[0];
    assert("reparse preserves 2 keys", b2?.keys?.length, 2);
    assert("reparse literal still there", b2?.keys?.[1]?.isVar, false);
}

// ---------------------------------------------------------------
console.log("\n=== findStatementSection: finds header past a leading non-comment statement ===");
{
    const content = "-- A\nlocal f = hl.dsp.exec_cmd\ncreate_bind(vars.kbA, f(\"a\"), \"A\")\n-- B\ncreate_bind(vars.kbB, f(\"b\"), \"B\")\n";
    const detailed = splitStatementsDetailed(content);
    let kbAIdx = -1;
    for (let i = 0; i < detailed.length; i++)
        if (detailed[i].text.includes("vars.kbA")) { kbAIdx = i; break; }
    assert("found kbA index", kbAIdx >= 0, true);
    assert("section of kbA", findStatementSection(detailed, kbAIdx), "A");
}

// ---------------------------------------------------------------
console.log("\n=== findStatementSection: banner line yields no section ===");
{
    const detailed = splitStatementsDetailed("----------\ncreate_bind(vars.kbA, hl.dsp.exec_cmd(\"a\"), \"A\")\n");
    let kbAIdx = -1;
    for (let i = 0; i < detailed.length; i++)
        if (detailed[i].text.includes("vars.kbA")) { kbAIdx = i; break; }
    assert("found kbA index", kbAIdx >= 0, true);
    assert("banner is null section", findStatementSection(detailed, kbAIdx), null);
}

// ---------------------------------------------------------------
console.log("\n=== applyKeybindsOps: moving a bind prunes emptied old header ===");
{
    const content = "-- A\ncreate_bind(vars.kbA, hl.dsp.exec_cmd(\"a\"), \"A\")\n-- B\ncreate_bind(vars.kbB, hl.dsp.exec_cmd(\"b\"), \"B\")\n";
    const newStmt = "create_bind(vars.kbA, hl.dsp.exec_cmd(\"a2\"), \"A\")\n";
    const res = applyKeybindsOps(content, [{ op: "update", stmtIndex: 1, statement: newStmt, section: "C" }]);
    assert("move changed", res.changed, true);
    assert("old header pruned", !res.content.includes("-- A"), true);
    assert("new header created", res.content.includes("-- C"), true);
}

// ---------------------------------------------------------------
console.log("\n=== applyKeybindsOps: same-section update stays in place ===");
{
    const content = "-- A\ncreate_bind(vars.kbA, hl.dsp.exec_cmd(\"a\"), \"A\")\ncreate_bind(vars.kbB, hl.dsp.exec_cmd(\"b\"), \"B\")\ncreate_bind(vars.kbC, hl.dsp.exec_cmd(\"c\"), \"C\")\n-- B\ncreate_bind(vars.kbD, hl.dsp.exec_cmd(\"d\"), \"D\")\n";
    const stmt = createKeybindStatement({ name: "kbB", lua: "hl.dsp.exec_cmd(\"b2\")", desc: "B", flags: [] });
    const res = applyKeybindsOps(content, [{ op: "update", stmtIndex: 2, statement: stmt, section: "A" }]);
    assert("same-section update changed", res.changed, true);
    assert("new body present", res.content.includes("b2"), true);
    assert("position preserved A before B before C", res.content.indexOf("kbA") < res.content.indexOf("kbB") && res.content.indexOf("kbB") < res.content.indexOf("kbC"), true);
    assert("section B intact", res.content.includes("-- B"), true);
}

// ---------------------------------------------------------------
console.log("\n=== applyKeybindsOps: reorder drag down (A before C) ===");
{
    const content = "-- A\ncreate_bind(vars.kbA, hl.dsp.exec_cmd(\"a\"), \"A\")\ncreate_bind(vars.kbB, hl.dsp.exec_cmd(\"b\"), \"B\")\ncreate_bind(vars.kbC, hl.dsp.exec_cmd(\"c\"), \"C\")\n-- B\ncreate_bind(vars.kbD, hl.dsp.exec_cmd(\"d\"), \"D\")\n";
    const res = applyKeybindsOps(content, [{ op: "reorder", stmtIndex: 1, beforeStmtIndex: 3 }]);
    assert("reorder down changed", res.changed, true);
    assert("new order B,A,C", res.content.indexOf("kbB") < res.content.indexOf("kbA") && res.content.indexOf("kbA") < res.content.indexOf("kbC"), true);
    assert("header still first statement block", res.content.indexOf("-- A") < res.content.indexOf("kbA"), true);
}

// ---------------------------------------------------------------
console.log("\n=== applyKeybindsOps: reorder drag up (C before A) ===");
{
    const content = "-- A\ncreate_bind(vars.kbA, hl.dsp.exec_cmd(\"a\"), \"A\")\ncreate_bind(vars.kbB, hl.dsp.exec_cmd(\"b\"), \"B\")\ncreate_bind(vars.kbC, hl.dsp.exec_cmd(\"c\"), \"C\")\n-- B\ncreate_bind(vars.kbD, hl.dsp.exec_cmd(\"d\"), \"D\")\n";
    const res = applyKeybindsOps(content, [{ op: "reorder", stmtIndex: 3, beforeStmtIndex: 1 }]);
    assert("reorder up changed", res.changed, true);
    assert("new order C,A,B", res.content.indexOf("kbC") < res.content.indexOf("kbA") && res.content.indexOf("kbA") < res.content.indexOf("kbB"), true);
}

// ---------------------------------------------------------------
console.log("\n=== applyKeybindsOps: reorder to end of section (beforeStmtIndex -1) ===");
{
    const content = "-- A\ncreate_bind(vars.kbA, hl.dsp.exec_cmd(\"a\"), \"A\")\ncreate_bind(vars.kbB, hl.dsp.exec_cmd(\"b\"), \"B\")\ncreate_bind(vars.kbC, hl.dsp.exec_cmd(\"c\"), \"C\")\n-- B\ncreate_bind(vars.kbD, hl.dsp.exec_cmd(\"d\"), \"D\")\n";
    const res = applyKeybindsOps(content, [{ op: "reorder", stmtIndex: 1, beforeStmtIndex: -1 }]);
    assert("reorder to end changed", res.changed, true);
    assert("new order B,C,A", res.content.indexOf("kbB") < res.content.indexOf("kbC") && res.content.indexOf("kbC") < res.content.indexOf("kbA"), true);
    assert("A stays before -- B header", res.content.indexOf("kbA") < res.content.indexOf("-- B"), true);
}

// ---------------------------------------------------------------
console.log("\n=== applyKeybindsOps: reorder no-op cases ===");
{
    const content = "-- A\ncreate_bind(vars.kbA, hl.dsp.exec_cmd(\"a\"), \"A\")\ncreate_bind(vars.kbB, hl.dsp.exec_cmd(\"b\"), \"B\")\ncreate_bind(vars.kbC, hl.dsp.exec_cmd(\"c\"), \"C\")\n-- B\ncreate_bind(vars.kbD, hl.dsp.exec_cmd(\"d\"), \"D\")\n";
    assert("same position no-op", applyKeybindsOps(content, [{ op: "reorder", stmtIndex: 1, beforeStmtIndex: 1 }]).changed, false);
    assert("last-to-end no-op", applyKeybindsOps(content, [{ op: "reorder", stmtIndex: 3, beforeStmtIndex: -1 }]).changed, false);
}

// ---------------------------------------------------------------
// ---------------------------------------------------------------
console.log("\n=== applyKeybindsOps: delete removes statement, keeps siblings ===");
{
    const content = "-- A\ncreate_bind(vars.kbA, hl.dsp.exec_cmd(\"a\"), \"A\")\ncreate_bind(vars.kbB, hl.dsp.exec_cmd(\"b\"), \"B\")\ncreate_bind(vars.kbC, hl.dsp.exec_cmd(\"c\"), \"C\")\n-- B\ncreate_bind(vars.kbD, hl.dsp.exec_cmd(\"d\"), \"D\")\n";
    const res = applyKeybindsOps(content, [{ op: "delete", stmtIndex: 2 }]);
    assert("changed", res.changed, true);
    assert("kbB removed", !res.content.includes("kbB"), true);
    assert("kbA kept", res.content.includes("kbA"), true);
    assert("kbC kept", res.content.includes("kbC"), true);
    assert("section B kept", res.content.includes("-- B"), true);
}

// ---------------------------------------------------------------
console.log("\n=== applyKeybindsOps: delete prunes emptied section header ===");
{
    const content = "-- A\ncreate_bind(vars.kbA, hl.dsp.exec_cmd(\"a\"), \"A\")\n-- B\ncreate_bind(vars.kbB, hl.dsp.exec_cmd(\"b\"), \"B\")\n";
    const res = applyKeybindsOps(content, [{ op: "delete", stmtIndex: 1 }]);
    assert("changed", res.changed, true);
    assert("header A pruned", !res.content.includes("-- A"), true);
    assert("section B kept", res.content.includes("-- B"), true);
    assert("statement B kept", res.content.includes("kbB"), true);
}

// ---------------------------------------------------------------
console.log("\n=== applyKeybindsOps: delete invalid stmtIndex no-op ===");
{
    const content = "-- A\ncreate_bind(vars.kbA, hl.dsp.exec_cmd(\"a\"), \"A\")\n";
    assert("invalid stmtIndex no-op", applyKeybindsOps(content, [{ op: "delete", stmtIndex: 99 }]).changed, false);
}

// ---------------------------------------------------------------
console.log("\n=== applyVariablesRemoveOp: removes variable line ===");
{
    const content = "return {\n    -- Misc\n    kbFoo = \"SUPER + T\",\n    kbBar = \"SUPER + A\",\n}\n";
    const res = applyVariablesRemoveOp(content, { name: "kbFoo", category: "Misc" });
    assert("changed", res.changed, true);
    assert("kbFoo removed", !res.content.includes("kbFoo"), true);
    assert("kbBar kept", res.content.includes("kbBar"), true);
    assert("header kept", res.content.includes("-- Misc"), true);
}

// ---------------------------------------------------------------
console.log("\n=== applyVariablesRemoveOp: prunes emptied section header ===");
{
    const content = "return {\n    -- Misc\n    kbFoo = \"SUPER + T\",\n}\n";
    const res = applyVariablesRemoveOp(content, { name: "kbFoo", category: "Misc" });
    assert("changed", res.changed, true);
    assert("kbFoo removed", !res.content.includes("kbFoo"), true);
    assert("header pruned", !res.content.includes("-- Misc"), true);
    assert("return table intact", res.content.includes("return {"), true);
}

// ---------------------------------------------------------------
console.log("\n=== applyVariablesRemoveOp: absent variable no-op ===");
{
    const content = "return {\n    -- Misc\n    kbFoo = \"SUPER + T\",\n}\n";
    assert("absent no-op", applyVariablesRemoveOp(content, { name: "kbNope", category: "Misc" }).changed, false);
}

// ---------------------------------------------------------------
console.log(`\n=== Results: ${pass} passed, ${fail} failed ===`);
process.exit(fail > 0 ? 1 : 0);
