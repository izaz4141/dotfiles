pragma Singleton
import Quickshell

Singleton {
    id: root

    function format(str, ...args) {
        return str.replace(/{(\d+)}/g, (match, index) => typeof args[index] !== 'undefined' ? args[index] : match);
    }

    function getDomain(url) {
        const match = url.match(/^(?:https?:\/\/)?(?:www\.)?([^\/]+)/);
        return match ? match[1] : null;
    }

    function getBaseUrl(url) {
        const match = url.match(/^(https?:\/\/[^\/]+)(\/.*)?$/);
        return match ? match[1] : null;
    }

    function shellSingleQuoteEscape(str) {
        return String(str)
        .replace(/'/g, "'\\''");
    }

    function splitMarkdownBlocks(markdown) {
        const regex = /```(\w+)?\n([\s\S]*?)```| thinking([\s\S]*?)<\/think>/g;
        let result = [];
        let lastIndex = 0;
        let match;
        while ((match = regex.exec(markdown)) !== null) {
            if (match.index > lastIndex) {
                const text = markdown.slice(lastIndex, match.index);
                if (text.trim()) {
                    result.push({
                        type: "text",
                        content: text
                    });
                }
            }
            if (match[0].startsWith('```')) {
                if (match[2] && match[2].trim()) {
                    result.push({
                        type: "code",
                        lang: match[1] || "",
                        content: match[2],
                        completed: true
                    });
                }
            } else if (match[0].startsWith(' thinking')) {
                if (match[3] && match[3].trim()) {
                    result.push({
                        type: "think",
                        content: match[3],
                        completed: true
                    });
                }
            }
            lastIndex = regex.lastIndex;
        }
        if (lastIndex < markdown.length) {
            const text = markdown.slice(lastIndex);
            const thinkStart = text.indexOf(' thinking');
            const codeStart = text.indexOf('```');
            if (thinkStart !== -1 && (codeStart === -1 || thinkStart < codeStart)) {
                const beforeThink = text.slice(0, thinkStart);
                if (beforeThink.trim()) {
                    result.push({
                        type: "text",
                        content: beforeThink
                    });
                }
                const thinkContent = text.slice(thinkStart + 7);
                if (thinkContent.trim()) {
                    result.push({
                        type: "think",
                        content: thinkContent,
                        completed: false
                    });
                }
            } else if (codeStart !== -1) {
                const beforeCode = text.slice(0, codeStart);
                if (beforeCode.trim()) {
                    result.push({
                        type: "text",
                        content: beforeCode
                    });
                }
                const codeLangMatch = text.slice(codeStart + 3).match(/^(\w+)?\n/);
                let lang = "";
                let codeContentStart = codeStart + 3;
                if (codeLangMatch) {
                    lang = codeLangMatch[1] || "";
                    codeContentStart += codeLangMatch[0].length;
                } else if (text[codeStart + 3] === '\n') {
                    codeContentStart += 1;
                }
                const codeContent = text.slice(codeContentStart);
                if (codeContent.trim()) {
                    result.push({
                        type: "code",
                        lang,
                        content: codeContent,
                        completed: false
                    });
                }
            } else if (text.trim()) {
                result.push({
                    type: "text",
                    content: text
                });
            }
        }
        return result;
    }

    function escapeBackslashes(str) {
        return str.replace(/\\/g, '\\\\');
    }

    function wordWrap(str, maxLen) {
        if (!str)
            return "";
        let words = str.split(" ");
        let lines = [];
        let current = "";
        for (let i = 0; i < words.length; ++i) {
            if ((current + (current.length > 0 ? " " : "") + words[i]).length > maxLen) {
                if (current.length > 0)
                    lines.push(current);
                current = words[i];
            } else {
                current += (current.length > 0 ? " " : "") + words[i];
            }
        }
        if (current.length > 0)
            lines.push(current);
        return lines.join("\n");
    }

    function escapeHtml(str) {
        if (typeof str !== 'string')
            return str;
        return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
    }

    function cleanCliphistEntry(str) {
        if (typeof str !== 'string')
            return str;
        return str.replace(/^\d+\t/, "");
    }

    function toTitleCase(str) {
        return str.replace(/[-_]/g, " ").replace(
            /\w\S*/g,
            function(txt) {
            return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
            }
        );
    }
}