pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services

Item {
    id: root

    property string commandPrefix: "/"

    readonly property var commands: [{
        "name": "attach",
        "icon": "attach_file",
        "description": I18n.tr("Attach a file. Only works with Gemini.", "AiChat toolbar"),
        "execute": args => Ai.attachFile(args.join(" ").trim())
    }, {
        "name": "model",
        "icon": "psychology",
        "description": I18n.tr("Choose model", "AiChat toolbar"),
        "execute": args => Ai.setModel(args[0])
    }, {
        "name": "tool",
        "icon": "service_toolbox",
        "description": I18n.tr("Set the tool to use for the model.", "AiChat toolbar"),
        "execute": args => {
            if (args.length == 0 || args[0] == "get") {
                Ai.addMessage(I18n.tr("Usage: %1tool TOOL_NAME", "AiChat toolbar").arg(root.commandPrefix), Ai.interfaceRole);
            } else {
                const tool = args[0];
                if (Ai.setTool(tool))
                    Ai.addMessage(I18n.tr("Tool set to: %1", "AiChat toolbar").arg(tool), Ai.interfaceRole);
            }
        }
    }, {
        "name": "prompt",
        "icon": "notes",
        "description": I18n.tr("Set the system prompt file for the model.", "AiChat toolbar"),
        "execute": args => {
            if (args.length === 0 || args[0] === "get") {
                Ai.printPrompt();
                return;
            }
            Ai.loadPrompt(args.join(" ").trim());
        }
    }, {
        "name": "key",
        "icon": "key",
        "description": I18n.tr("Set API key", "AiChat toolbar"),
        "execute": args => {
            if (args[0] == "get") {
                Ai.printApiKey();
            } else {
                Ai.setApiKey(args[0]);
            }
        }
    }, {
        "name": "save",
        "icon": "save",
        "description": I18n.tr("Save chat", "AiChat toolbar"),
        "execute": args => {
            const joinedArgs = args.join(" ");
            if (joinedArgs.trim().length == 0) {
                Ai.addMessage(I18n.tr("Usage: %1save CHAT_NAME", "AiChat toolbar").arg(root.commandPrefix), Ai.interfaceRole);
                return;
            }
            Ai.saveChat(joinedArgs);
        }
    }, {
        "name": "load",
        "icon": "folder_open",
        "description": I18n.tr("Load chat", "AiChat toolbar"),
        "execute": args => {
            const joinedArgs = args.join(" ");
            if (joinedArgs.trim().length == 0) {
                Ai.addMessage(I18n.tr("Usage: %1load CHAT_NAME", "AiChat toolbar").arg(root.commandPrefix), Ai.interfaceRole);
                return;
            }
            Ai.loadChat(joinedArgs);
        }
    }, {
        "name": "clear",
        "icon": "delete_sweep",
        "description": I18n.tr("Clear chat history", "AiChat toolbar"),
        "execute": () => Ai.clearMessages()
    }, {
        "name": "temp",
        "icon": "device_thermostat",
        "description": I18n.tr("Set temperature (randomness) of the model. Values range between 0 to 2 for Gemini, 0 to 1 for other models. Default is 0.5.", "AiChat toolbar"),
        "execute": args => {
            if (args.length === 0 || args[0] == "get") {
                Ai.printTemperature();
            } else {
                Ai.setTemperature(parseFloat(args[0]));
            }
        }
    }, {
        "name": "test",
        "icon": "science",
        "description": I18n.tr("Markdown test", "AiChat toolbar"),
        "execute": () => {
            Ai.addMessage(`
thinking
A longer think block to test the revealing animation
It should fade in chunk by chunk as the model streams. Every paragraph is a separate
line of the fade-in animation, so longer replies feel alive while they generate.
response
## ✏️ Markdown test
### Formatting

- *Italic*, \`Monospace\`, **Bold**, [Link](https://example.com)
- Arch lincox icon <img src="${Quickshell.shellPath("assets/icons/arch-symbolic.svg")}" height="${Theme.fontSizeMedium}"/>

### Table

Quickshell vs AGS/Astal

|                          | Quickshell       | AGS/Astal         |
|--------------------------|------------------|-------------------|
| UI Toolkit               | Qt               | Gtk3/Gtk4         |
| Language                 | QML              | Js/Ts/Lua         |
| Reactivity               | Implied          | Needs declaration |
| Widget placement         | Mildly difficult | More intuitive    |
| Bluetooth & Wifi support | ❌               | ✅                |
| No-delay keybinds        | ✅               | ❌                |
| Development              | New APIs         | New syntax        |

### Code block

Just a hello world with syntax highlighting...

\`\`\`cpp
#include <bits/stdc++.h>
// This is intentionally very long to test scrolling
const std::string GREETING = "UwU";
int main(int argc, char* argv[]) {
    std::cout << GREETING;
}
\`\`\`

### LaTeX

Inline w/ dollar signs: $\\frac{1}{2} = \\frac{2}{4}$

Inline w/ double dollar signs: $$\\int_0^\\infty e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2}$$

Inline w/ backslash and square brackets \\[\\int_0^\\infty \\frac{1}{x^2} dx = \\infty\\]

Inline w/ backslash and round brackets \\(e^{i\\pi} + 1 = 0\\)
`, Ai.interfaceRole);
        }
    }]

    function commandIcon(name) {
        return root.commands.find(cmd => cmd.name === name)?.icon ?? "";
    }
}
