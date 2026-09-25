.pragma library

const KEY_MAP = {
    16777234: "Left",
    16777236: "Right",
    16777235: "Up",
    16777237: "Down",
    44: "Comma",
    46: "Period",
    47: "Slash",
    59: "Semicolon",
    39: "Apostrophe",
    91: "BracketLeft",
    93: "BracketRight",
    92: "Backslash",
    45: "Minus",
    61: "Equal",
    96: "grave",
    32: "space",
    16777225: "Print",
    16777226: "Print",
    16777220: "Return",
    16777221: "Return",
    16777217: "Tab",
    16777219: "BackSpace",
    16777223: "Delete",
    16777222: "Insert",
    16777232: "Home",
    16777233: "End",
    16777238: "Page_Up",
    16777239: "Page_Down",
    16777216: "Escape",
    16777252: "Caps_Lock",
    16777253: "Num_Lock",
    16777254: "Scroll_Lock",
    16777224: "Pause",
    16777330: "XF86AudioRaiseVolume",
    16777328: "XF86AudioLowerVolume",
    16777329: "XF86AudioMute",
    16842808: "XF86AudioMicMute",
    16777344: "XF86AudioPlay",
    16777345: "XF86AudioStop",
    16777346: "XF86AudioPrev",
    16777347: "XF86AudioNext",
    16777348: "XF86AudioPause",
    16777349: "XF86AudioMedia",
    16777350: "XF86AudioRecord",
    16842798: "XF86MonBrightnessUp",
    16777394: "XF86MonBrightnessUp",
    16842797: "XF86MonBrightnessDown",
    16777395: "XF86MonBrightnessDown",
    16842800: "XF86KbdBrightnessUp",
    16842799: "XF86KbdBrightnessDown",
    16842796: "XF86PowerOff",
    16842803: "XF86Sleep",
    16842804: "XF86WakeUp",
    16842802: "XF86Eject",
    16842791: "XF86Calculator",
    16842806: "XF86Explorer",
    16842794: "XF86HomePage",
    16777426: "XF86Search",
    16777427: "XF86Mail",
    16777442: "XF86Launch0",
    16777443: "XF86Launch1",
    33: "1",
    64: "2",
    35: "3",
    36: "4",
    37: "5",
    94: "6",
    38: "7",
    42: "8",
    40: "9",
    41: "0",
    60: "Comma",
    62: "Period",
    63: "Slash",
    58: "Semicolon",
    34: "Apostrophe",
    123: "BracketLeft",
    125: "BracketRight",
    124: "Backslash",
    95: "Minus",
    43: "Equal",
    126: "grave",
    196: "Adiaeresis",
    214: "Odiaeresis",
    220: "Udiaeresis",
    228: "adiaeresis",
    246: "odiaeresis",
    252: "udiaeresis",
    223: "ssharp",
    201: "Eacute",
    233: "eacute",
    200: "Egrave",
    232: "egrave",
    202: "Ecircumflex",
    234: "ecircumflex",
    203: "Ediaeresis",
    235: "ediaeresis",
    192: "Agrave",
    224: "agrave",
    194: "Acircumflex",
    226: "acircumflex",
    199: "Ccedilla",
    231: "ccedilla",
    206: "Icircumflex",
    238: "icircumflex",
    207: "Idiaeresis",
    239: "idiaeresis",
    212: "Ocircumflex",
    244: "ocircumflex",
    217: "Ugrave",
    249: "ugrave",
    219: "Ucircumflex",
    251: "ucircumflex",
    209: "Ntilde",
    241: "ntilde",
    191: "questiondown",
    161: "exclamdown"
};

function xkbKeyFromQtKey(qk) {
    if (qk >= 65 && qk <= 90)
        return String.fromCharCode(qk);
    if (qk >= 97 && qk <= 122)
        return String.fromCharCode(qk - 32);
    if (qk >= 48 && qk <= 57)
        return String.fromCharCode(qk);
    if (qk >= 16777264 && qk <= 16777298)
        return "F" + (qk - 16777264 + 1);
    return KEY_MAP[qk] || "";
}

function modsFromEvent(mods) {
    var result = [];
    if (mods & 0x10000000)
        result.push("Super");
    if (mods & 0x08000000)
        result.push("Alt");
    if (mods & 0x04000000)
        result.push("Ctrl");
    if (mods & 0x02000000)
        result.push("Shift");
    return result;
}

function formatToken(mods, key) {
    return (mods.length ? mods.join("+") + "+" : "") + key;
}

// Lua/Hyprland key naming helpers (shared with the Hyprland keybinds editor)

function luaKeyNameFromEvent(event) {
    const k = event.key;
    if (k >= 65 && k <= 90)
        return String.fromCharCode(k);
    if (k >= 48 && k <= 57)
        return String.fromCharCode(k);
    if (k >= 16777264 && k <= 16777287)
        return "F" + (k - 16777264 + 1);
    const map = {
        32: "Space",
        16777217: "Tab",
        16777220: "Return",
        16777221: "Return",
        16777223: "Delete",
        16777238: "Page_Up",
        16777239: "Page_Down",
        16777235: "Up",
        16777237: "Down",
        16777234: "Left",
        16777236: "Right",
        16777232: "Home",
        16777233: "End",
        45: "Minus",
        61: "Equal",
        44: "Comma",
        46: "Period",
        47: "Slash",
        92: "Backslash",
        59: "Semicolon",
        39: "Apostrophe",
        91: "Bracketleft",
        93: "Bracketright",
        16777225: "Print",
        16777226: "Print",
        16777252: "Scroll",
        16777224: "Pause"
    };
    return map[k] || "";
}

function luaModsFromEvent(event) {
    const mods = [];
    if (event.modifiers & 0x10000000)
        mods.push("SUPER");
    if (event.modifiers & 0x04000000)
        mods.push("CTRL");
    if (event.modifiers & 0x08000000)
        mods.push("ALT");
    if (event.modifiers & 0x02000000)
        mods.push("SHIFT");
    return mods;
}

function luaComboFromEvent(event) {
    const name = luaKeyNameFromEvent(event);
    if (!name)
        return "";
    const mods = luaModsFromEvent(event);
    mods.push(name);
    return mods.join(" + ");
}

function normalizeKeyCombo(keyCombo) {
    if (!keyCombo)
        return "";
    return keyCombo.toLowerCase().replace(/\bmod\b/g, "super").replace(/\bsuper\b/g, "super");
}

// Normalized set of resolved combos ("super + t") for an editor bind. The
// Hyprland parser resolves vars.* and array vars into each key entry's `combo`,
// so this collects the distinct resolved combos across the bind's keys.
function resolvedCombosOfEditorBind(bind) {
    const out = [];
    const seen = {};
    const keys = (bind && bind.keys) || [];
    for (let i = 0; i < keys.length; i++) {
        const combo = normalizeKeyCombo(keys[i].combo || keys[i].key || "");
        if (combo && !seen[combo]) {
            seen[combo] = true;
            out.push(combo);
        }
    }
    return out;
}

// Builds { comboMap, comboDisplay, collidingBinds } from editor sections.
// comboMap maps a normalized resolved combo to an array of bind references
// (section, stmtIndex, desc, actionText). comboDisplay maps a normalized combo
// to a human-readable original. collidingBinds lists the same bind references,
// each with the list of other binds sharing at least one resolved combo.
function computeEditorCollisions(sections) {
    const comboMap = {};
    const comboDisplay = {};
    const refs = [];
    for (let s = 0; s < (sections || []).length; s++) {
        const section = sections[s];
        const binds = section.binds || [];
        for (let b = 0; b < binds.length; b++) {
            const bind = binds[b];
            const ref = {
                section: section.name,
                stmtIndex: bind.stmtIndex,
                desc: bind.desc || bind.actionText || "",
                actionText: bind.actionText || "",
                keysRaw: bind.keysRaw || ""
            };
            ref._index = refs.length;
            refs.push(ref);
            const combos = resolvedCombosOfEditorBind(bind);
            for (let c = 0; c < combos.length; c++) {
                if (!comboMap[combos[c]])
                    comboMap[combos[c]] = [];
                comboMap[combos[c]].push(ref);
                if (comboDisplay[combos[c]] === undefined) {
                    const keys = bind.keys || [];
                    let display = "";
                    for (let ki = 0; ki < keys.length; ki++) {
                        if (normalizeKeyCombo(keys[ki].combo || keys[ki].key || "") === combos[c]) {
                            display = keys[ki].combo || keys[ki].key || "";
                            break;
                        }
                    }
                    comboDisplay[combos[c]] = display || combos[c].toUpperCase();
                }
            }
        }
    }

    for (const combo in comboMap) {
        if (comboMap[combo].length < 2)
            continue;
        for (let i = 0; i < comboMap[combo].length; i++) {
            const ref = comboMap[combo][i];
            for (let j = 0; j < comboMap[combo].length; j++) {
                if (i === j)
                    continue;
                const other = comboMap[combo][j];
                if (!ref.conflicts)
                    ref.conflicts = [];
                if (ref.conflictsIndexed === undefined)
                    ref.conflictsIndexed = {};
                if (!ref.conflictsIndexed[other._index]) {
                    ref.conflictsIndexed[other._index] = true;
                    ref.conflicts.push(other);
                }
            }
        }
    }

    const collidingBinds = refs.filter(r => r.conflicts && r.conflicts.length > 0);
    for (let i = 0; i < collidingBinds.length; i++)
        delete collidingBinds[i].conflictsIndexed;
    return { comboMap: comboMap, comboDisplay: comboDisplay, collidingBinds: collidingBinds };
}

function getConflictingBinds(keyCombo, currentAction, allBinds) {
    if (!keyCombo)
        return [];
    var conflicts = [];
    var normalizedKey = normalizeKeyCombo(keyCombo);
    for (var i = 0; i < allBinds.length; i++) {
        var bind = allBinds[i];
        if (bind.action === currentAction)
            continue;
        for (var k = 0; k < bind.keys.length; k++) {
            if (normalizeKeyCombo(bind.keys[k].key) === normalizedKey) {
                conflicts.push({
                    action: bind.action,
                    desc: bind.desc || bind.action
                });
                break;
            }
        }
    }
    return conflicts;
}
