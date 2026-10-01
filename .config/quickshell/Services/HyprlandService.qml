pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Common
import qs.Services
import "../Modules/Cheatsheet/HyprlandParser.js" as KeybindParser

Singleton {
    id: root
    readonly property var log: Log.scoped("HyprlandService")

    readonly property string configDir: Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation))
    readonly property string variablesPath: configDir + "/hypr/variables.lua"
    readonly property string keybindsPath: configDir + "/hypr/hyprland/keybinds.lua"
    readonly property string outputsPath: configDir + "/hypr/conf/monitors/default.lua"
    readonly property string cursorPath: configDir + "/hypr/input.lua"
    readonly property string rulesPath: configDir + "/hypr/hyprland/rules.lua"
    readonly property bool luaConfigActive: CompositorService.isHyprland && (Hyprland.usingLua === true || luaConfigDetected)

    property int _lastGapValue: -1
    property bool luaConfigDetected: false
    property bool luaConfigStatusReady: false
    property bool luaConfigStatusLoading: false
    property string luaConfigFormat: ""
    property bool layoutGenerationPending: false
    property bool layoutGenerationRunning: false
    property int _layoutRequestRevision: 0
    property int _layoutAppliedRevision: 0
    property int _frameTransitionRevision: 0
    readonly property bool frameLayoutReady: _layoutAppliedRevision >= _frameTransitionRevision

    // Parsed hypr/variables.lua store: [{ name, value, category, note }]
    property var keybindVariables: []
    property var keybindVariablesMap: ({})
    property bool keybindVariablesLoading: false
    property bool keybindVariablesReady: false
    signal keybindVariablesLoaded

    // dms/layout.lua is the source of truth for xray; parsed once before the first regeneration
    property bool layoutXrayEnabled: false
    property bool layoutBarXrayEnabled: true
    property bool _layoutXrayLoaded: false
    property bool _layoutXrayLoading: false

    DeferredAction {
        id: layoutGenerationAction
        onTriggered: root.doGenerateLayoutConfig()
    }

    onLuaConfigStatusLoadingChanged: {
        if (!luaConfigStatusLoading && layoutGenerationPending)
            layoutGenerationAction.schedule();
    }

    onLuaConfigActiveChanged: {
        if (luaConfigActive)
            ensureDmsLuaConfigs();
    }

    Component.onCompleted: {
        if (CompositorService.isHyprland) {
            refreshLuaConfigStatus();
            refreshKeybindVariables();
            if (luaConfigActive)
                ensureDmsLuaConfigs();
        }
    }

    function ensureDmsLuaConfigs() {
        Qt.callLater(generateLayoutConfig);
    }

    function refreshKeybindVariables() {
        if (keybindVariablesLoading)
            return;
        keybindVariablesLoading = true;
        keybindVariablesReady = false;
        Proc.runCommand("hypr-read-variables", ["cat", variablesPath], (output, exitCode) => {
            keybindVariablesLoading = false;
            if (exitCode !== 0) {
                keybindVariablesReady = false;
                return;
            }
            try {
                const parsed = KeybindParser.parseVariables(output);
                keybindVariables = parsed.list;
                keybindVariablesMap = parsed.map;
                keybindVariablesReady = true;
                keybindVariablesLoaded();
                _reparseKeybindEditorIfReady();
            } catch (e) {
                log.warn("Failed to parse Hyprland variables:", e);
                keybindVariablesReady = false;
            }
        });
    }

    function luaLiteral(value) {
        if (typeof value === "boolean")
            return value ? "true" : "false";
        if (typeof value === "number" && isFinite(value))
            return String(value);
        let s = String(value).trim();
        if ((s.startsWith("\"") && s.endsWith("\"")) || (s.startsWith("'") && s.endsWith("'")))
            s = s.slice(1, -1);
        s = s.replace(/[\n\t\r]+/g, " ");
        s = s.replace(/\\|"/g, ch => ch === "\\" ? "\\\\" : "\\\"");
        s = s.replace(/\\/g, "\\\\");
        s = s.replace(/&/g, "\\&");
        return "\"" + s + "\"";
    }

    function setVariable(name, value) {
        if (!CompositorService.isHyprland || !name)
            return;
        const literal = luaLiteral(value);
        if (!literal)
            return;
        const safe = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        const varRe = new RegExp("^([ \\t]*" + safe + "[ \\t]*=)[^\\n]*", "m");
        Proc.runCommand("hypr-read-variable", ["cat", variablesPath], (output, exitCode) => {
            if (exitCode !== 0) {
                log.warn("Failed to read Hyprland variables:", name, output);
                return;
            }
            let content = output;
            if (varRe.test(content)) {
                content = content.replace(varRe, "$1 " + literal.replace(/\$/g, "$$") + ",");
                if (content === output)
                    return;
            } else {
                const closeIdx = content.lastIndexOf("}");
                const line = "    " + name + " = " + literal + ",";
                content = closeIdx >= 0 ? content.slice(0, closeIdx) + line + "\n" + content.slice(closeIdx) : content + "\n" + line + "\n";
            }
            Proc.runCommand("hypr-set-variable", ["sh", "-c", `cat > "${variablesPath}" << 'EOF'\n${content}EOF`], (out, ec) => {
                if (ec !== 0) {
                    log.warn("Failed to write Hyprland variable:", name, out);
                    return;
                }
                reloadConfig(() => refreshKeybindVariables());
            });
        });
    }

    function updateAppDefault(name, value) {
        setVariable(name, value);
    }

    // Keybind editor state (statement-level layout parsed from keybinds.lua)
    property var keybindEditorSections: []
    property string keybindEditorContent: ""
    property bool keybindEditorLoading: false
    property bool keybindEditorReady: false
    signal keybindEditorLoaded

    function _reparseKeybindEditorIfReady() {
        if (!keybindVariablesReady || !keybindEditorContent)
            return;
        try {
            keybindEditorSections = KeybindParser.parseEditor(keybindVariablesMap, keybindEditorContent, keybindVariables).sections;
            keybindEditorReady = true;
            keybindEditorLoaded();
        } catch (e) {
            log.warn("Failed to parse Hyprland keybinds for editor:", e);
            keybindEditorReady = false;
        }
    }

    function refreshKeybindEditor() {
        if (!CompositorService.isHyprland)
            return;
        keybindEditorLoading = true;
        Proc.runCommand("hypr-read-keybinds-editor", ["cat", keybindsPath], (output, exitCode) => {
            keybindEditorLoading = false;
            if (exitCode !== 0) {
                log.warn("Failed to read keybinds.lua:", output);
                return;
            }
            keybindEditorContent = output;
            _reparseKeybindEditorIfReady();
        });
    }

    function applyKeybindOp(op) {
        if (!CompositorService.isHyprland || !keybindEditorContent)
            return;
        const res = KeybindParser.applyKeybindsOps(keybindEditorContent, [op]);
        if (!res.changed)
            return;
        const safeContent = res.content.endsWith("\n") ? res.content : res.content + "\n";
        Proc.runCommand("hypr-write-keybinds", ["sh", "-c", `cat > "${keybindsPath}" << 'EOF'\n${safeContent}EOF`], (output, exitCode) => {
            if (exitCode !== 0) {
                log.warn("Failed to write keybinds.lua:", output);
                return;
            }
            reloadConfig(() => refreshKeybindEditor());
        });
    }

    function changeBindKey(stmtIndex, keyIndex, combo) {
        if (!combo)
            return;
        applyKeybindOp({ op: "change", stmtIndex: stmtIndex, keyIndex: keyIndex, combo: combo });
    }

    function addBindKey(stmtIndex, combo) {
        if (!combo)
            return;
        applyKeybindOp({ op: "add", stmtIndex: stmtIndex, combo: combo });
    }

    function removeBindKey(stmtIndex, keyIndex) {
        applyKeybindOp({ op: "remove", stmtIndex: stmtIndex, keyIndex: keyIndex });
    }

    function sanitizeCustomVarBase(desc) {
        const words = String(desc || "").match(/[A-Za-z0-9]+/g) || [];
        let camel = words.map((w, i) => i === 0 ? w.toLowerCase() : (w[0].toUpperCase() + w.slice(1).toLowerCase())).join("");
        if (!camel || camel.length < 2)
            return "kbShortcut";
        return "kb" + camel[0].toUpperCase() + camel.slice(1);
    }

    function nextCustomBindVarName(desc) {
        const base = root.sanitizeCustomVarBase(desc);
        const taken = {};
        for (let i = 0; i < keybindVariables.length; i++)
            taken[keybindVariables[i].name] = true;
        let name = base;
        let n = 2;
        while (taken[name])
            name = base + (n++);
        return name;
    }

    // Adds a custom shortcut: stores the combo (or list of combos) in
    // variables.lua under the chosen category and appends a
    // create_bind(vars.kbX, <lua>, "<desc>", flags) to keybinds.lua, then
    // reloads and refreshes the editor state.
    function addCustomBind(combos, luaCode, category, desc, flags, customVarName, onDone) {
        const done = (ok) => { if (onDone) onDone(ok); };
        if (!CompositorService.isHyprland || !keybindEditorContent)
            return done(false);
        if (!canWriteLuaConfig("keybinds"))
            return done(false);
        const comboList = (Array.isArray(combos) ? combos : [combos])
            .map(c => String(c || "").trim())
            .filter(c => c !== "");
        const luaText = String(luaCode || "").trim();
        const descText = String(desc || "").trim();
        const categoryText = String(category || "").trim();
        if (!comboList.length || !luaText || !descText || !categoryText)
            return done(false);
        const varName = (String(customVarName || "").trim() || root.nextCustomBindVarName(descText));
        Proc.runCommand("hypr-add-variable-read", ["cat", variablesPath], (output, exitCode) => {
            if (exitCode !== 0) {
                log.warn("Failed to read Hyprland variables for custom bind:", output);
                done(false);
                return;
            }
            let res;
            try {
                res = KeybindParser.applyVariablesCreateOp(output, {
                    "name": varName,
                    "value": comboList.length === 1 ? comboList[0] : comboList,
                    "category": categoryText
                });
            } catch (e) {
                log.warn("Failed to build variables.lua update for custom bind:", e);
                done(false);
                return;
            }
            if (!res.changed) {
                log.warn("Failed to build variables.lua update for custom bind");
                done(false);
                return;
            }
            Proc.runCommand("hypr-add-variable-write", ["sh", "-c", `cat > "${variablesPath}" << 'EOF'\n${res.content}EOF`], (out, ec) => {
                if (ec !== 0) {
                    log.warn("Failed to write variables.lua:", out);
                    done(false);
                    return;
                }
                root.addCustomBindWriteKeybinds(varName, luaText, descText, categoryText, flags, done);
            });
        });
        return true;
    }

    function addCustomBindWriteKeybinds(varName, luaText, descText, categoryText, flags, done) {
        let stmt, res;
        try {
            stmt = KeybindParser.createKeybindStatement({
                "name": varName,
                "lua": luaText,
                "desc": descText,
                "flags": flags
            });
            if (!stmt)
                return finish(done, false);
            res = KeybindParser.applyKeybindsOps(keybindEditorContent, [{ "op": "create", "section": categoryText, "statement": stmt }]);
        } catch (e) {
            log.warn("Failed to build keybinds.lua update for custom bind:", e);
            return finish(done, false);
        }
        if (!res.changed) {
            log.warn("Failed to build keybinds.lua update for custom bind");
            return finish(done, false);
        }
        const safeContent = res.content.endsWith("\n") ? res.content : res.content + "\n";
        Proc.runCommand("hypr-write-keybinds", ["sh", "-c", `cat > "${keybindsPath}" << 'EOF'\n${safeContent}EOF`], (output, exitCode) => {
            if (exitCode !== 0) {
                log.warn("Failed to write keybinds.lua:", output);
                return finish(done, false);
            }
            reloadConfig(() => {
                refreshKeybindVariables();
                refreshKeybindEditor();
                finish(done, true);
            });
        });

        function finish(cb, ok) {
            if (cb)
                cb(ok);
        }
    }

    // Extracts the vars.* variable name from a bind's keysRaw (a bare var ref
    // or a table literal containing a var element).
    function _customBindVarName(bind) {
        if (!bind)
            return "";
        const raw = String(bind.keysRaw || "");
        if (raw.startsWith("vars."))
            return raw.slice(5).trim();
        const m = raw.match(/vars\.(\w+)/);
        return m ? m[1] : "";
    }

    // True when the bind row refers to a custom vars.* variable (editable via
    // the Add/Edit dialog) rather than a literal or loop-derived keybind.
    // Literal-only table binds (no vars.* element) are not custom-editable.
    function isCustomBind(bind) {
        if (!bind || !bind.editable)
            return false;
        if (bind.keysKind === "var")
            return true;
        if (bind.keysKind === "table" && Array.isArray(bind.keys))
            return bind.keys.some(k => !!k.isVar);
        return false;
    }

    // Edits an existing custom keybind: updates the stored combo (or combos) in
    // variables.lua (and its category) and rebuilds the create_bind statement
    // in keybinds.lua, then reloads and refreshes the editor state.
    function updateCustomBind(bind, combos, luaCode, category, desc, flags, flagsRaw, customVarName, literalKeys, onDone) {
        const done = (ok) => { if (onDone) onDone(ok); };
        if (!CompositorService.isHyprland || !keybindEditorContent)
            return done(false);
        if (!canWriteLuaConfig("keybinds"))
            return done(false);
        const comboList = (Array.isArray(combos) ? combos : [combos])
            .map(c => String(c || "").trim())
            .filter(c => c !== "");
        const luaText = String(luaCode || "").trim();
        const descText = String(desc || "").trim();
        const categoryText = String(category || "").trim();
        const varName = (String(customVarName || "").trim() || root._customBindVarName(bind));
        if (!root.isCustomBind(bind) || !varName || !comboList.length || !luaText || !descText || !categoryText)
            return done(false);
        let stmt;
        try {
            stmt = KeybindParser.createKeybindStatement({
                "name": varName,
                "lua": luaText,
                "desc": descText,
                "flags": flags,
                "flagsRaw": flagsRaw,
                "literalKeys": literalKeys
            });
        } catch (e) {
            log.warn("Failed to build keybind statement:", e);
            return done(false);
        }
        if (!stmt)
            return done(false);

        const writeKeybinds = () => {
            let res;
            try {
                res = KeybindParser.applyKeybindsOps(keybindEditorContent, [{
                    "op": "update",
                    "stmtIndex": bind.stmtIndex,
                    "statement": stmt,
                    "section": categoryText
                }]);
            } catch (e) {
                log.warn("Failed to build keybinds.lua update for custom bind:", e);
                done(false);
                return;
            }
            if (!res.changed) {
                log.warn("Failed to build keybinds.lua update for custom bind");
                done(false);
                return;
            }
            const safeContent = res.content.endsWith("\n") ? res.content : res.content + "\n";
            Proc.runCommand("hypr-update-keybinds-write", ["sh", "-c", `cat > "${keybindsPath}" << 'EOF'\n${safeContent}EOF`], (o, ec2) => {
                if (ec2 !== 0) {
                    log.warn("Failed to write keybinds.lua:", o);
                    done(false);
                    return;
                }
                reloadConfig(() => {
                    refreshKeybindVariables();
                    refreshKeybindEditor();
                    done(true);
                });
            });
        };

        const curVar = root.keybindVariables.find(v => v.name === varName);
        const varValue = comboList.length === 1 ? comboList[0] : comboList;
        const varValSame = !!curVar && JSON.stringify(curVar.value) === JSON.stringify(varValue);
        const varCatSame = !!curVar && String(curVar.category || "").trim() === categoryText;
        if (varValSame && varCatSame) {
            writeKeybinds();
            return true;
        }
        Proc.runCommand("hypr-update-variable-read", ["cat", variablesPath], (output, exitCode) => {
            if (exitCode !== 0) {
                log.warn("Failed to read Hyprland variables for custom bind update:", output);
                done(false);
                return;
            }
            let varRes;
            try {
                varRes = KeybindParser.applyVariablesCreateOp(output, {
                    "name": varName,
                    "value": varValue,
                    "category": categoryText
                });
            } catch (e) {
                log.warn("Failed to build variables.lua update for custom bind:", e);
                done(false);
                return;
            }
            if (!varRes.changed) {
                log.warn("Failed to build variables.lua update for custom bind");
                done(false);
                return;
            }
            Proc.runCommand("hypr-update-variable-write", ["sh", "-c", `cat > "${variablesPath}" << 'EOF'\n${varRes.content}EOF`], (out, ec) => {
                if (ec !== 0) {
                    log.warn("Failed to write variables.lua:", out);
                    done(false);
                    return;
                }
                writeKeybinds();
            });
        });
        return true;
    }

    // Reorders a keybind within its section by moving the statement at
    // stmtIndex to just before another statement (beforeStmtIndex) or to the
    // end of the section when beforeStmtIndex is -1, then reloads and refreshes.
    function reorderKeybind(stmtIndex, beforeStmtIndex, onDone) {
        const done = (ok) => { if (onDone) onDone(ok); };
        if (!CompositorService.isHyprland || !keybindEditorContent)
            return done(false);
        if (!canWriteLuaConfig("keybinds"))
            return done(false);
        let fromBind = null;
        try {
            for (let s = 0; s < keybindEditorSections.length; s++) {
                const binds = keybindEditorSections[s].binds || [];
                for (let b = 0; b < binds.length; b++) {
                    if (binds[b].stmtIndex === stmtIndex) {
                        fromBind = binds[b];
                        break;
                    }
                }
                if (fromBind)
                    break;
            }
            if (!fromBind || !fromBind.editable)
                return done(false);
            const res = KeybindParser.applyKeybindsOps(keybindEditorContent, [{
                "op": "reorder",
                "stmtIndex": stmtIndex,
                "beforeStmtIndex": beforeStmtIndex
            }]);
            if (!res.changed) {
                log.warn("Failed to build keybinds.lua reorder");
                return done(false);
            }
            const safeContent = res.content.endsWith("\n") ? res.content : res.content + "\n";
            Proc.runCommand("hypr-reorder-keybind", ["sh", "-c", `cat > "${keybindsPath}" << 'EOF'\n${safeContent}EOF`], (output, exitCode) => {
                if (exitCode !== 0) {
                    log.warn("Failed to write keybinds.lua:", output);
                    done(false);
                    return;
                }
                reloadConfig(() => {
                    refreshKeybindVariables();
                    refreshKeybindEditor();
                    done(true);
                });
            });
        } catch (e) {
            log.warn("Failed to build keybinds.lua reorder:", e);
            return done(false);
        }
        return true;
    }

    // Deletes a custom keybind: removes its create_bind statement from
    // keybinds.lua and drops its associated vars.* variable from variables.lua
    // (pruning an emptied section header), then reloads and refreshes.
    function removeCustomBind(bind, onDone) {
        const done = (ok) => { if (onDone) onDone(ok); };
        if (!CompositorService.isHyprland || !keybindEditorContent)
            return done(false);
        if (!canWriteLuaConfig("keybinds"))
            return done(false);
        if (!root.isCustomBind(bind) || bind.stmtIndex === undefined)
            return done(false);
        const varName = root._customBindVarName(bind);
        let res;
        try {
            res = KeybindParser.applyKeybindsOps(keybindEditorContent, [{
                "op": "delete",
                "stmtIndex": bind.stmtIndex
            }]);
        } catch (e) {
            log.warn("Failed to build keybinds.lua delete:", e);
            return done(false);
        }
        if (!res.changed) {
            log.warn("Failed to build keybinds.lua delete");
            return done(false);
        }
        const writeKeybinds = () => {
            const safeContent = res.content.endsWith("\n") ? res.content : res.content + "\n";
            Proc.runCommand("hypr-delete-keybind", ["sh", "-c", `cat > "${keybindsPath}" << 'EOF'\n${safeContent}EOF`], (output, exitCode) => {
                if (exitCode !== 0) {
                    log.warn("Failed to write keybinds.lua:", output);
                    done(false);
                    return;
                }
                reloadConfig(() => {
                    refreshKeybindVariables();
                    refreshKeybindEditor();
                    done(true);
                });
            });
        };
        if (!varName) {
            writeKeybinds();
            return true;
        }
        const curVar = root.keybindVariables.find(v => v.name === varName);
        const category = curVar ? String(curVar.category || "").trim() : "";
        Proc.runCommand("hypr-delete-variable-read", ["cat", variablesPath], (output, exitCode) => {
            if (exitCode !== 0) {
                log.warn("Failed to read Hyprland variables for custom bind delete:", output);
                done(false);
                return;
            }
            let varRes;
            try {
                varRes = KeybindParser.applyVariablesRemoveOp(output, {
                    "name": varName,
                    "category": category
                });
            } catch (e) {
                log.warn("Failed to build variables.lua delete:", e);
                done(false);
                return;
            }
            if (varRes.changed) {
                Proc.runCommand("hypr-delete-variable-write", ["sh", "-c", `cat > "${variablesPath}" << 'EOF'\n${varRes.content}EOF`], (out, ec) => {
                    if (ec !== 0) {
                        log.warn("Failed to write variables.lua:", out);
                        done(false);
                        return;
                    }
                    writeKeybinds();
                });
            } else {
                writeKeybinds();
            }
        });
        return true;
    }

    Connections {
        target: SettingsData
        function onBarConfigsChanged() {
            if (!CompositorService.isHyprland)
                return;
            const newGaps = Math.max(4, (SettingsData.barConfigs[0]?.spacing ?? 4));
            if (newGaps === root._lastGapValue)
                return;
            root._lastGapValue = newGaps;
            generateLayoutConfig();
        }
    }

    Connections {
        target: CompositorService
        function onIsHyprlandChanged() {
            if (CompositorService.isHyprland) {
                refreshLuaConfigStatus();
                refreshKeybindVariables();
                if (luaConfigActive)
                    ensureDmsLuaConfigs();
                return;
            }
            luaConfigDetected = false;
            luaConfigStatusReady = false;
            luaConfigStatusLoading = false;
            luaConfigFormat = "";
            keybindVariables = [];
            keybindVariablesMap = {};
            keybindVariablesReady = false;
            keybindEditorSections = [];
            keybindEditorContent = "";
            keybindEditorReady = false;
        }
    }

    function getOutputIdentifier(output, outputName) {
        if (output.explicitIdentifier)
            return outputName;
        if (SettingsData.displayNameMode === "model" && output.make && output.model)
            return ("desc:" + [output.make, output.model, output.serial].filter(p => p).join(" ")).replace(/,/g, "");
        return outputName;
    }

    function luaQuoted(str) {
        return JSON.stringify(String(str ?? ""));
    }

    function refreshLuaConfigStatus() {
        if (!CompositorService.isHyprland) {
            luaConfigDetected = false;
            luaConfigStatusReady = false;
            luaConfigStatusLoading = false;
            luaConfigFormat = "";
            return;
        }
        if (luaConfigStatusLoading)
            return;

        luaConfigStatusLoading = true;
        Proc.runCommand("hypr-lua-config-status", [Proc.dmsBin, "config", "resolve-include", "hyprland", "outputs.lua"], (output, exitCode) => {
            luaConfigStatusLoading = false;
            luaConfigStatusReady = true;
            if (exitCode !== 0) {
                luaConfigDetected = false;
                luaConfigFormat = "";
                return;
            }
            try {
                const status = JSON.parse(output.trim());
                luaConfigFormat = status.configFormat ?? "";
                luaConfigDetected = luaConfigFormat === "lua" && status.readOnly !== true;
            } catch (e) {
                luaConfigDetected = false;
                luaConfigFormat = "";
            }
        });
    }

    function canWriteLuaConfig(name) {
        if (luaConfigActive)
            return true;
        if (CompositorService.isHyprland && !luaConfigStatusReady && !luaConfigStatusLoading)
            refreshLuaConfigStatus();
        if (CompositorService.isHyprland && (luaConfigStatusLoading || !luaConfigStatusReady)) {
            log.debug("Deferring Hyprland", name || "config", "Lua write until config format is known");
            return false;
        }
        log.info("Skipping Hyprland", name || "config", "Lua write because the active Hyprland config is not Lua");
        return false;
    }

    function forceFlagValue(value) {
        if (value === true)
            return 1;
        if (value === false)
            return -1;
        return Number(value);
    }

    function generateOutputsConfig(outputsData, hyprlandSettings, callback) {
        if (!outputsData || Object.keys(outputsData).length === 0) {
            if (callback)
                callback(false);
            return;
        }

        const settings = hyprlandSettings || SettingsData.hyprlandOutputSettings;
        let lines = [];

        for (const outputName in outputsData) {
            const output = outputsData[outputName];
            if (!output)
                continue;

            const identifier = getOutputIdentifier(output, outputName);
            const outputSettings = settings[identifier] || {};

            if (outputSettings.disabled) {
                lines.push(`hl.monitor({ output = ${luaQuoted(identifier)}, disabled = true })`);
                continue;
            }

            let resolution = output.configured_mode || "preferred";
            if (!output.configured_mode && output.modes && output.current_mode !== undefined) {
                const mode = output.modes[output.current_mode];
                if (mode)
                    resolution = mode.width + "x" + mode.height + "@" + (mode.refresh_rate / 1000).toFixed(3);
            }

            const x = output.logical?.x ?? 0;
            const y = output.logical?.y ?? 0;
            const position = x + "x" + y;
            const scale = output.logical?.scale ?? 1.0;

            const parts = [`output = ${luaQuoted(identifier)}`, `mode = ${luaQuoted(resolution)}`, `position = ${luaQuoted(position)}`, `scale = ${Number(scale)}`];

            const transform = transformToHyprland(output.logical?.transform ?? "Normal");
            if (transform !== 0)
                parts.push(`transform = ${transform}`);

            if (output.vrr_supported) {
                const vrrMode = outputSettings.vrrFullscreenOnly ? 2 : (output.vrr_enabled ? 1 : 0);
                parts.push(`vrr = ${vrrMode}`);
            }

            if (output.mirror && output.mirror.length > 0)
                parts.push(`mirror = ${luaQuoted(output.mirror)}`);

            if (outputSettings.bitdepth && outputSettings.bitdepth !== 8)
                parts.push(`bitdepth = ${Number(outputSettings.bitdepth)}`);

            if (outputSettings.colorManagement && outputSettings.colorManagement !== "auto")
                parts.push(`cm = ${luaQuoted(outputSettings.colorManagement)}`);

            if (outputSettings.sdrBrightness !== undefined && outputSettings.sdrBrightness !== 1.0)
                parts.push(`sdrbrightness = ${Number(outputSettings.sdrBrightness)}`);

            if (outputSettings.sdrSaturation !== undefined && outputSettings.sdrSaturation !== 1.0)
                parts.push(`sdrsaturation = ${Number(outputSettings.sdrSaturation)}`);

            if (outputSettings.supportsWideColor !== undefined)
                parts.push(`supports_wide_color = ${forceFlagValue(outputSettings.supportsWideColor)}`);

            if (outputSettings.supportsHdr !== undefined)
                parts.push(`supports_hdr = ${forceFlagValue(outputSettings.supportsHdr)}`);

            lines.push("hl.monitor({ " + parts.join(", ") + " })");
        }

        lines.push("");
        const content = lines.join("\n");

        Proc.runCommand("hypr-write-outputs", ["sh", "-c", `mkdir -p "$(dirname "${outputsPath}")" && cat > "${outputsPath}" << 'EOF'\n${content}EOF`], (output, exitCode) => {
            if (exitCode !== 0) {
                log.warn("Failed to write outputs config:", output);
                if (callback)
                    callback(false);
                return;
            }
            log.info("Generated outputs config at", outputsPath);
            if (CompositorService.isHyprland)
                reloadConfig();
            if (callback)
                callback(true);
        });
    }

    function reloadConfig(callback) {
        Proc.runCommand("hyprctl-reload", ["hyprctl", "reload"], (output, exitCode) => {
            if (exitCode !== 0)
                log.warn("hyprctl reload failed:", output);
            if (callback)
                callback(exitCode === 0);
        });
    }

    function previewMonitorConfig(outputsData, hyprlandSettings, callback) {
        if (!outputsData || Object.keys(outputsData).length === 0) {
            if (callback)
                callback(false);
            return;
        }

        const settings = hyprlandSettings || SettingsData.hyprlandOutputSettings;
        let lines = [];

        for (const outputName in outputsData) {
            const output = outputsData[outputName];
            if (!output)
                continue;

            const identifier = getOutputIdentifier(output, outputName);
            const outputSettings = settings[identifier] || {};

            if (outputSettings.disabled) {
                lines.push(`hl.monitor({ output = ${luaQuoted(identifier)}, disabled = true })`);
                continue;
            }

            let resolution = "preferred";
            if (output.current_mode !== undefined && output.modes && output.modes[output.current_mode]) {
                const mode = output.modes[output.current_mode];
                resolution = mode.width + "x" + mode.height + "@" + (mode.refresh_rate / 1000).toFixed(3);
            }

            const x = output.logical?.x ?? 0;
            const y = output.logical?.y ?? 0;
            const position = x + "x" + y;
            const scale = output.logical?.scale ?? 1.0;

            const parts = [`output = ${luaQuoted(identifier)}`, `mode = ${luaQuoted(resolution)}`, `position = ${luaQuoted(position)}`, `scale = ${Number(scale)}`];

            const transform = transformToHyprland(output.logical?.transform ?? "Normal");
            if (transform !== 0)
                parts.push(`transform = ${transform}`);

            if (output.vrr_supported) {
                const vrrMode = outputSettings.vrrFullscreenOnly ? 2 : (output.vrr_enabled ? 1 : 0);
                parts.push(`vrr = ${vrrMode}`);
            }

            if (output.mirror && output.mirror.length > 0)
                parts.push(`mirror = ${luaQuoted(output.mirror)}`);

            if (outputSettings.bitdepth && outputSettings.bitdepth !== 8)
                parts.push(`bitdepth = ${Number(outputSettings.bitdepth)}`);

            if (outputSettings.colorManagement && outputSettings.colorManagement !== "auto")
                parts.push(`cm = ${luaQuoted(outputSettings.colorManagement)}`);

            if (outputSettings.sdrBrightness !== undefined && outputSettings.sdrBrightness !== 1.0)
                parts.push(`sdrbrightness = ${Number(outputSettings.sdrBrightness)}`);

            if (outputSettings.sdrSaturation !== undefined && outputSettings.sdrSaturation !== 1.0)
                parts.push(`sdrsaturation = ${Number(outputSettings.sdrSaturation)}`);

            if (outputSettings.supportsWideColor !== undefined)
                parts.push(`supports_wide_color = ${forceFlagValue(outputSettings.supportsWideColor)}`);

            if (outputSettings.supportsHdr !== undefined)
                parts.push(`supports_hdr = ${forceFlagValue(outputSettings.supportsHdr)}`);

            lines.push("hl.monitor({ " + parts.join(", ") + " })");
        }

        lines.push("");
        const content = lines.join("\n");

        Proc.runCommand("hypr-preview-monitors", ["sh", "-c", `mkdir -p "$(dirname "${outputsPath}")" && cat > "${outputsPath}" << 'EOF'\n${content}EOF`], (output, exitCode) => {
            if (exitCode !== 0) {
                log.warn("Failed to write preview config:", output);
                if (callback)
                    callback(false);
                return;
            }
            reloadConfig(success => {
                if (callback)
                    callback(success);
            });
        });
    }

    function restoreMonitorConfig(originalContent, callback) {
        Proc.runCommand("hypr-write-outputs", ["sh", "-c", `mkdir -p "$(dirname "${outputsPath}")" && cat > "${outputsPath}" << 'EOF'\n${originalContent}EOF`], (output, exitCode) => {
            if (exitCode !== 0) {
                log.warn("Failed to restore outputs config:", output);
                if (callback)
                    callback(false);
                return;
            }
            reloadConfig(success => {
                if (callback)
                    callback(success);
            });
        });
    }

    function setLayoutXray(enabled) {
        layoutXrayEnabled = enabled;
        _layoutXrayLoaded = true;
        generateLayoutConfig();
    }

    function setLayoutBarXray(enabled) {
        layoutBarXrayEnabled = enabled;
        _layoutXrayLoaded = true;
        generateLayoutConfig();
    }

    function loadLayoutXrayState() {
        if (_layoutXrayLoading)
            return;
        _layoutXrayLoading = true;
        Proc.runCommand("hypr-read-layout-xray", ["cat", root.rulesPath], (output, exitCode) => {
            _layoutXrayLoading = false;
            if (!_layoutXrayLoaded) {
                const content = exitCode === 0 ? output : "";
                layoutXrayEnabled = content.includes('"^dms:.*$"');
                layoutBarXrayEnabled = !content.includes("-- bar-xray off");
                _layoutXrayLoaded = true;
            }
            if (layoutGenerationPending)
                layoutGenerationAction.schedule();
        });
    }

    function generateLayoutConfig(frameTransition) {
        if (!CompositorService.isHyprland)
            return;
        _layoutRequestRevision++;
        if (frameTransition === true)
            _frameTransitionRevision = _layoutRequestRevision;
        layoutGenerationPending = true;
        layoutGenerationAction.schedule();
    }

    // Batch-upserts layout variables into hypr/variables.lua (single read+write).
    // ops: [{ name, value, category }]
    function _upsertLayoutVariables(ops, callback) {
        const done = (ok) => { if (callback) callback(ok); };
        if (!ops || !ops.length)
            return done(true);
        Proc.runCommand("hypr-layout-vars-read", ["cat", root.variablesPath], (output, exitCode) => {
            if (exitCode !== 0) {
                log.warn("Failed to read Hyprland variables for layout:", output);
                done(false);
                return;
            }
            let content = output;
            let changed = false;
            for (let i = 0; i < ops.length; i++) {
                let res;
                try {
                    res = KeybindParser.applyVariablesCreateOp(content, {
                        "name": ops[i].name,
                        "value": ops[i].value,
                        "category": ops[i].category,
                        "literal": true
                    });
                } catch (e) {
                    log.warn("Failed to build variables.lua layout update:", e);
                    done(false);
                    return;
                }
                if (res.changed) {
                    content = res.content;
                    changed = true;
                }
            }
            if (!changed)
                return done(true);
            Proc.runCommand("hypr-layout-vars-write", ["sh", "-c", `cat > "${root.variablesPath}" << 'EOF'\n${content}EOF`], (out, ec) => {
                if (ec !== 0) {
                    log.warn("Failed to write Hyprland variables for layout:", out);
                    done(false);
                    return;
                }
                refreshKeybindVariables();
                done(true);
            });
        });
    }

    // Ensures hypr/hyprland/general.lua references vars.resizeOnBorder inside its
    // `general = { ... }` block so the DMS-managed flag stays editable.
    function _ensureResizeOnBorderLine(callback) {
        const done = (ok) => { if (callback) callback(ok); };
        Proc.runCommand("hypr-general-read", ["cat", configDir + "/hypr/hyprland/general.lua"], (output, exitCode) => {
            if (exitCode !== 0) {
                log.warn("Failed to read Hyprland general.lua:", output);
                done(false);
                return;
            }
            const content = output || "";
            if (/\bresize_on_border\s*=/.test(content))
                return done(true);
            const borderRe = /^([ \t]*)(?:vars\.)?border_size[ \t]*=.*$/m;
            const m = content.match(borderRe);
            let next;
            if (m) {
                const indent = m[1] || "\t\t";
                next = content.slice(0, m.index + m[0].length) + "\n" + indent + "resize_on_border = vars.resizeOnBorder," + content.slice(m.index + m[0].length);
            } else {
                const generalRe = /general\s*=\s*\{/;
                const gm = content.match(generalRe);
                if (!gm)
                    return done(false);
                next = content.slice(0, gm.index + gm[0].length) + "\n\t\tresize_on_border = vars.resizeOnBorder," + content.slice(gm.index + gm[0].length);
            }
            if (next === content)
                return done(true);
            Proc.runCommand("hypr-general-write", ["sh", "-c", `cat > "${configDir + "/hypr/hyprland/general.lua"}" << 'EOF'\n${next}EOF`], (out, ec) => {
                if (ec !== 0) {
                    log.warn("Failed to write Hyprland general.lua:", out);
                    done(false);
                    return;
                }
                done(true);
            });
        });
    }

    // Idempotently replaces the DMS marker span in hypr/hyprland/rules.lua.
    function _applyXrayRules(rulesContent, callback) {
        const done = (ok) => { if (callback) callback(ok); };
        Proc.runCommand("hypr-rules-read", ["cat", root.rulesPath], (output, exitCode) => {
            if (exitCode !== 0) {
                log.warn("Failed to read Hyprland rules.lua:", output);
                done(false);
                return;
            }
            const existing = output || "";
            const beginMarker = "-- DMS xray :: begin";
            const endMarker = "-- DMS xray :: end";
            const block = beginMarker + "\n" + rulesContent.trim() + "\n" + endMarker;
            const startIdx = existing.indexOf(beginMarker);
            const endIdx = startIdx === -1 ? -1 : existing.indexOf(endMarker, startIdx);
            let content;
            if (startIdx !== -1 && endIdx !== -1) {
                const before = existing.slice(0, startIdx).replace(/\s+$/, "");
                const after = existing.slice(endIdx + endMarker.length).replace(/^\s+/, "");
                content = before + "\n\n" + block + "\n\n" + after;
            } else {
                content = existing.replace(/\s+$/, "") + "\n\n" + block + "\n";
            }
            if (content === existing)
                return done(true);
            Proc.runCommand("hypr-rules-write", ["sh", "-c", `cat > "${root.rulesPath}" << 'EOF'\n${content}EOF`], (out, ec) => {
                if (ec !== 0) {
                    log.warn("Failed to write Hyprland rules.lua:", out);
                    done(false);
                    return;
                }
                done(true);
            });
        });
    }

    function doGenerateLayoutConfig() {
        if (layoutGenerationRunning)
            return;
        if (!_layoutXrayLoaded) {
            loadLayoutXrayState();
            return;
        }
        layoutGenerationPending = false;
        const requestRevision = _layoutRequestRevision;
        if (!canWriteLuaConfig("layout")) {
            if (luaConfigStatusLoading || !luaConfigStatusReady) {
                layoutGenerationPending = true;
                return;
            }
            _layoutAppliedRevision = Math.max(_layoutAppliedRevision, requestRevision);
            return;
        }
        layoutGenerationRunning = true;

        const finish = (ok) => {
            if (!ok)
                log.warn("Failed to generate Hyprland layout config");
            // Advance even on failure — proceed degraded rather than wedge the transition
            _layoutAppliedRevision = Math.max(_layoutAppliedRevision, requestRevision);
            layoutGenerationRunning = false;
            if (layoutGenerationPending)
                layoutGenerationAction.schedule();
        };

        const defaultRadius = typeof SettingsData !== "undefined" ? SettingsData.cornerRadius : 12;
        const defaultGaps = typeof SettingsData !== "undefined" ? Math.max(4, (SettingsData.barConfigs[0]?.spacing ?? 4)) : 4;
        const defaultBorderSize = 2;

        const cornerRadius = (typeof SettingsData !== "undefined" && SettingsData.hyprlandLayoutRadiusOverride >= 0) ? SettingsData.hyprlandLayoutRadiusOverride : defaultRadius;
        const gapsOverride = typeof SettingsData !== "undefined" ? SettingsData.hyprlandLayoutGapsOverride : -1;
        const manageGaps = gapsOverride !== -2;
        const gapsIn = gapsOverride >= 0 ? gapsOverride : defaultGaps;
        const gapsOut = (gapsOverride >= 0 && SettingsData.hyprlandLayoutGapsOutOverride >= 0) ? SettingsData.hyprlandLayoutGapsOutOverride : gapsIn;
        const borderSize = (typeof SettingsData !== "undefined" && SettingsData.hyprlandLayoutBorderSize >= 0) ? SettingsData.hyprlandLayoutBorderSize : defaultBorderSize;
        const resizeOnBorder = (typeof SettingsData !== "undefined" && SettingsData.hyprlandResizeOnBorder) ? true : false;
        const frameEnabled = typeof SettingsData !== "undefined" && SettingsData.frameEnabled;
        // Hyprland `xray = false` is still early-development; unset already samples real content, so only force xray=true
        // dms:frame only in separate mode — connected-mode frame blur overlaps windows via popouts/arcs
        const xrayNamespaces = ["dms:bar"];
        if (frameEnabled && SettingsData.frameMode !== "connected")
            xrayNamespaces.push("dms:frame");

        const varOps = [];
        if (manageGaps) {
            varOps.push({ "name": "windowGapsIn", "value": gapsIn, "category": "Gaps" });
            varOps.push({ "name": "windowGapsOut", "value": gapsOut, "category": "Gaps" });
        }
        varOps.push({ "name": "windowBorderSize", "value": borderSize, "category": "Window styling" });
        varOps.push({ "name": "windowRounding", "value": cornerRadius, "category": "Window styling" });
        varOps.push({ "name": "resizeOnBorder", "value": resizeOnBorder, "category": "Window styling" });

        const rulesLines = [];
        if (layoutXrayEnabled)
            rulesLines.push(`hl.layer_rule({ match = { namespace = "^dms:.*$" }, xray = true })`);
        if (layoutBarXrayEnabled) {
            for (const ns of xrayNamespaces)
                rulesLines.push(`hl.layer_rule({ match = { namespace = "^${ns}$" }, xray = true })`);
        }
        // Marker persists the preference even while the rule has no target
        if (!layoutBarXrayEnabled)
            rulesLines.push("-- bar-xray off");
        const rulesContent = rulesLines.join("\n");

        root._upsertLayoutVariables(varOps, varsOk => {
            if (!varsOk)
                return finish(false);
            root._ensureResizeOnBorderLine(generalOk => {
                if (!generalOk)
                    return finish(false);
                root._applyXrayRules(rulesContent, rulesOk => {
                    if (!rulesOk)
                        return finish(false);
                    log.info("Generated Hyprland layout config (variables.lua + rules.lua)");
                    reloadConfig(success => finish(true));
                });
            });
        });
    }

    function transformToHyprland(transform) {
        switch (transform) {
        case "Normal":
            return 0;
        case "90":
            return 1;
        case "180":
            return 2;
        case "270":
            return 3;
        case "Flipped":
            return 4;
        case "Flipped90":
            return 5;
        case "Flipped180":
            return 6;
        case "Flipped270":
            return 7;
        default:
            return 0;
        }
    }

    function hyprlandToTransform(value) {
        switch (value) {
        case 0:
            return "Normal";
        case 1:
            return "90";
        case 2:
            return "180";
        case 3:
            return "270";
        case 4:
            return "Flipped";
        case 5:
            return "Flipped90";
        case 6:
            return "Flipped180";
        case 7:
            return "Flipped270";
        default:
            return "Normal";
        }
    }

    function generateCursorConfig() {
        if (!CompositorService.isHyprland)
            return;

        const cursorSettings = typeof SettingsData !== "undefined" ? SettingsData.cursorSettings : null;
        const inputSettings = typeof SettingsData !== "undefined" ? SettingsData.inputSettings?.hyprland : null;
        const themeName = cursorSettings?.theme === "System Default" ? (SettingsData.systemDefaultCursorTheme || "") : (cursorSettings?.theme || "");
        const size = cursorSettings?.size || 24;
        const hideOnKeyPress = cursorSettings?.hyprland?.hideOnKeyPress || false;
        const hideOnTouch = cursorSettings?.hyprland?.hideOnTouch || false;
        const inactiveTimeout = cursorSettings?.hyprland?.inactiveTimeout || 0;

        const sensitivity = inputSettings?.sensitivity ?? 0;
        const followMouse = inputSettings?.follow_mouse ?? 1;
        const naturalScroll = inputSettings?.touchpad?.natural_scroll ?? true;
        const tapToClick = inputSettings?.touchpad?.tap_to_click ?? true;
        const disableWhileTyping = inputSettings?.touchpad?.disable_while_typing ?? false;
        const kbLayout = inputSettings?.kb_layout || "us";

        const hasTheme = themeName.length > 0;
        const hasNonDefaultSize = size !== 24;
        const hasCursorSettings = hideOnKeyPress || hideOnTouch || inactiveTimeout > 0;
        const hasInputOverrides = sensitivity !== 0 || followMouse !== 1 || !naturalScroll || !tapToClick || disableWhileTyping;

        let newLines = [];
        if (hasTheme || hasNonDefaultSize || hasCursorSettings) {
            if (hasTheme) {
                newLines.push(`hl.env("HYPRCURSOR_THEME", ${luaQuoted(themeName)})`);
                newLines.push(`hl.env("XCURSOR_THEME", ${luaQuoted(themeName)})`);
            }
            newLines.push(`hl.env("HYPRCURSOR_SIZE", ${luaQuoted(String(size))})`);
            newLines.push(`hl.env("XCURSOR_SIZE", ${luaQuoted(String(size))})`);

            if (hasCursorSettings) {
                newLines.push("");
                newLines.push("hl.config({");
                newLines.push("\tcursor = {");
                if (hideOnKeyPress)
                    newLines.push("\t\thide_on_key_press = true,");
                if (hideOnTouch)
                    newLines.push("\t\thide_on_touch = true,");
                if (inactiveTimeout > 0)
                    newLines.push(`\t\tinactive_timeout = ${inactiveTimeout},`);
                newLines.push("\t},");
                newLines.push("})");
            }
        }

        if (hasInputOverrides) {
            newLines.push("");
            newLines.push("hl.config({");
            newLines.push("\tinput = {");
            if (sensitivity !== 0)
                newLines.push(`\t\tsensitivity = ${sensitivity},`);
            if (followMouse !== 1)
                newLines.push(`\t\tfollow_mouse = ${followMouse},`);
            if (kbLayout && kbLayout !== "us")
                newLines.push(`\t\tkb_layout = ${luaQuoted(kbLayout)},`);
            newLines.push("\t\ttouchpad = {");
            if (!naturalScroll)
                newLines.push("\t\t\tnatural_scroll = false,");
            if (!tapToClick)
                newLines.push("\t\t\ttap_to_click = false,");
            if (disableWhileTyping)
                newLines.push("\t\t\tdisable_while_typing = true,");
            newLines.push("\t\t},");
            newLines.push("\t},");
            newLines.push("})");
        }

        Proc.runCommand("hypr-read-input", ["sh", "-c", `cat "${cursorPath}" 2>/dev/null || true`], (existingContent, exitCode) => {
            let lines = (exitCode === 0 && existingContent) ? existingContent.split("\n") : [];
            const cursorPattern = /HYPRCURSOR_THEME|XCURSOR_THEME|HYPRCURSOR_SIZE|XCURSOR_SIZE|hide_on_key_press|hide_on_touch|inactive_timeout/;
            const inputPattern = /sensitivity|follow_mouse|natural_scroll|tap_to_click|disable_while_typing|kb_layout/;
            const configStartPattern = /hl\.config\s*\(\s*\{?\s*$/;
            const configEndPattern = /^\s*\}\s*\)\s*$/;
            let filtered = [];
            let skipBlock = false;

            for (let i = 0; i < lines.length; i++) {
                const line = lines[i];
                if (skipBlock) {
                    if (configEndPattern.test(line))
                        skipBlock = false;
                    continue;
                }
                if (cursorPattern.test(line))
                    continue;
                if (inputPattern.test(line))
                    continue;
                const blockContext = lines.slice(Math.max(0, i - 5), i + 1).join(" ");
                if ((blockContext.includes("input") || blockContext.includes("cursor")) && configStartPattern.test(line)) {
                    skipBlock = true;
                    continue;
                }
                filtered.push(line);
            }

            while (filtered.length > 0 && filtered[filtered.length - 1].trim() === "")
                filtered.pop();

            if (newLines.length > 0) {
                if (filtered.length > 0 && filtered[filtered.length - 1].trim() !== "")
                    filtered.push("");
                filtered.push(...newLines);
                filtered.push("");
            }

            const content = filtered.join("\n");
            Proc.runCommand("hypr-write-cursor", ["sh", "-c", `cat > "${cursorPath}" << 'EOF'\n${content}EOF`], (output, writeExitCode) => {
                if (writeExitCode !== 0)
                    log.warn("Failed to write cursor config:", output);
            });
        });
    }

    function renameWorkspace(newName) {
        if (!Hyprland.focusedWorkspace)
            return;
        const wsId = Hyprland.focusedWorkspace.id;
        if (!wsId)
            return;
        const fullName = wsId + " " + newName;
        Hyprland.dispatch(`hl.dsp.workspace.rename({ workspace = ${luaValue(wsId)}, name = ${luaString(fullName)} })`);
    }

    function focusWorkspace(workspace) {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${luaValue(workspace)} })`);
    }

    function luaString(value) {
        return `"${String(value ?? "").replace(/\\/g, "\\\\").replace(/"/g, "\\\"")}"`;
    }

    function luaValue(value) {
        const text = String(value ?? "");
        return /^[-+]?\d+$/.test(text) ? text : luaString(text);
    }

    function windowSelector(windowAddress) {
        if (!windowAddress)
            return "";

        const text = String(windowAddress);
        if (text.startsWith("address:"))
            return text;

        return `address:${text.startsWith("0x") ? text : "0x" + text}`;
    }

    function focusWindow(windowAddress) {
        const selector = windowSelector(windowAddress);
        if (!selector)
            return;

        Hyprland.dispatch(`hl.dsp.focus({ window = ${luaString(selector)} })`);
    }

    function closeWindow(windowAddress) {
        const selector = windowSelector(windowAddress);
        if (!selector)
            return;

        Hyprland.dispatch(`hl.dsp.window.close(${luaString(selector)})`);
    }

    function moveToWorkspace(workspace, windowAddress, follow = true) {
        const selector = windowSelector(windowAddress);
        if (!selector)
            return;

        Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${luaValue(workspace)}, window = ${luaString(selector)}, follow = ${follow ? "true" : "false"} })`);
    }

    function toggleSpecial(specialName) {
        Hyprland.dispatch(`hl.dsp.workspace.toggle_special(${luaString(specialName)})`);
    }

    function exit() {
        Hyprland.dispatch("hl.dsp.exit()");
    }

    function dpmsOff() {
        Hyprland.dispatch(`hl.dsp.dpms({ action = "disable" })`);
    }

    function dpmsOn() {
        Hyprland.dispatch(`hl.dsp.dpms({ action = "enable" })`);
    }
}
