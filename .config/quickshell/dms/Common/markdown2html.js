.pragma library
// This exists only because I haven't been able to get linkColor to work with MarkdownText
// May not be necessary if that's possible tbh.
const _ENTITIES = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" };

function _escape(s) {
    return String(s).replace(/[&<>"]/g, c => _ENTITIES[c]);
}

function _formatInline(raw) {
    let out = _escape(raw);
    const codes = [];
    let c = 0;
    out = out.replace(/`([^`]+)`/g, (m, code) => {
        codes.push(`<code>${code}</code>`);
        return `\x00CI${c++}\x00`;
    });
    out = out.replace(/\*\*\*(.*?)\*\*\*/g, '<b><i>$1</i></b>');
    out = out.replace(/\*\*(.*?)\*\*/g, '<b>$1</b>');
    out = out.replace(/\*(.*?)\*/g, '<i>$1</i>');
    out = out.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');
    out = out.replace(/(^|[\s(])((?:https?|file):\/\/[^\s]+)/g, (m, pref, url) => pref + `<a href="${url}">${url}</a>`);
    out = out.replace(/\x00CI(\d+)\x00/g, (m, i) => codes[parseInt(i, 10)]);
    return out;
}

function _buildTable(blockText) {
    const rows = blockText.split("\n").map(r => r.trim()).filter(r => r.length > 0);
    const fallback = _escape(blockText).replace(/\n/g, '<br/>');
    if (rows.length < 2) return fallback;
    const cells = row => row.replace(/^\s*\|/, "").replace(/\|\s*$/, "").split("|").map(c => c.trim());
    const headers = cells(rows[0]);
    const sep = cells(rows[1]);
    const isSep = s => /^:?-+:?$/.test(s);
    if (!sep.length || !sep.every(isSep)) return fallback;
    const align = s => {
        const a = s || "";
        return a.startsWith(":") && a.endsWith(":") ? "center" : a.endsWith(":") ? "right" : "left";
    };
    let out = "<table>";
    out += "<tr>" + headers.map((h, i) => `<th style="text-align:${align(sep[i])}">${_formatInline(h)}</th>`).join("") + "</tr>";
    for (let r = 2; r < rows.length; r++) {
        const cs = cells(rows[r]);
        out += "<tr>" + cs.map((cell, i) => `<td style="text-align:${align(sep[i])}">${_formatInline(cell)}</td>`).join("") + "</tr>";
    }
    return out + "</table>";
}

function markdownToHtml(text, opts = {}) {
    if (!text) return "";

    const o = {
        linkColor: "",
        paragraphMarginBottom: 0,
        headingMarginTop: 0,
        headingMarginBottom: 0,
        codeMarginTop: 0,
        codeMarginBottom: 0,
        listMarginTop: 0,
        listMarginBottom: 0,
        tableMarginTop: 0,
        tableMarginBottom: 0
    };
    for (const k in opts) {
        if (k in o) o[k] = opts[k];
    }

    const codeBlocks = [];
    const inlineCode = [];
    const urls = [];
    const tables = [];
    const images = [];
    let blockIndex = 0;
    let inlineIndex = 0;
    let urlIndex = 0;
    let tableIndex = 0;
    let imageIndex = 0;

    let html = text.replace(/\r\n?/g, "\n");

    // Store code blocks with optional language and protect them from further processing
    html = html.replace(/```(\w*)\n?([\s\S]*?)```/g, (match, lang, code) => {
        const trimmedCode = code.replace(/^\n+|\n+$/g, '');
        const escapedCode = trimmedCode.replace(/&/g, '&amp;')
                                       .replace(/</g, '&lt;')
                                       .replace(/>/g, '&gt;');
        codeBlocks.push(`<pre><code>${escapedCode}</code></pre>`);
        return `\x00CODEBLOCK${blockIndex++}\x00`;
    });

    // Extract contiguous single-line tables before any other processing
    {
        const lines = html.split("\n");
        const out = [];
        for (let i = 0; i < lines.length; i++) {
            if (/^\s*\|/.test(lines[i])) {
                const block = [];
                let j = i;
                while (j < lines.length && /^\s*\|/.test(lines[j])) {
                    block.push(lines[j]);
                    j++;
                }
                if (block.length >= 2) {
                    tables.push(block.join("\n"));
                    out.push(`\x00TABLE${tableIndex++}\x00`);
                    i = j - 1;
                } else {
                    out.push(lines[i]);
                }
            } else {
                out.push(lines[i]);
            }
        }
        html = out.join("\n");
    }

    // Extract markdown images ![alt](src)
    html = html.replace(/!\[([^\]]*)\]\(([^)\s]+)(?:\s+["'][^"']*["'])?\)/g, (match, alt, src) => {
        images.push({ kind: "md", alt: alt, src: src });
        return `\x00IMG${imageIndex++}\x00`;
    });

    // Extract raw <img> tags untouched
    html = html.replace(/<\s*img\b[^>]*\/?>/gi, (match) => {
        images.push({ kind: "raw", value: match });
        return `\x00IMG${imageIndex++}\x00`;
    });

    // Extract and replace inline code
    html = html.replace(/`([^`]+)`/g, (match, code) => {
        const escapedCode = code.replace(/&/g, '&amp;')
                               .replace(/</g, '&lt;')
                               .replace(/>/g, '&gt;');
        inlineCode.push(`<code>${escapedCode}</code>`);
        return `\x00INLINECODE${inlineIndex++}\x00`;
    });

    // Extract plain URLs before escaping so & in query strings is preserved
    html = html.replace(/(^|[\s])((?:https?|file):\/\/[^\s]+)/gm, (match, prefix, url) => {
        urls.push(url);
        return prefix + `\x00URL${urlIndex++}\x00`;
    });

    // Escape HTML entities (but not in code blocks, tables, images or URLs)
    html = html.replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;');

    // Headers
    html = html.replace(/^###### (.*?)$/gm, '<h6>$1</h6>');
    html = html.replace(/^##### (.*?)$/gm, '<h5>$1</h5>');
    html = html.replace(/^#### (.*?)$/gm, '<h4>$1</h4>');
    html = html.replace(/^### (.*?)$/gm, '<h3>$1</h3>');
    html = html.replace(/^## (.*?)$/gm, '<h2>$1</h2>');
    html = html.replace(/^# (.*?)$/gm, '<h1>$1</h1>');

    // Bold and italic (order matters!)
    html = html.replace(/\*\*\*(.*?)\*\*\*/g, '<b><i>$1</i></b>');
    html = html.replace(/\*\*(.*?)\*\*/g, '<b>$1</b>');
    html = html.replace(/\*(.*?)\*/g, '<i>$1</i>');
    html = html.replace(/___(.*?)___/g, '<b><i>$1</i></b>');
    html = html.replace(/__(.*?)__/g, '<b>$1</b>');
    html = html.replace(/_(.*?)_/g, '<i>$1</i>');

    // Links
    html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');

    // Lists
    html = html.replace(/^\* (.*?)$/gm, '<li>$1</li>');
    html = html.replace(/^- (.*?)$/gm, '<li>$1</li>');
    html = html.replace(/^\d+\. (.*?)$/gm, '<li>$1</li>');

    // Wrap consecutive list items in ul/ol tags
    html = html.replace(/(<li>[\s\S]*?<\/li>\s*)+/g, function(match) {
        return '<ul>' + match.replace(/\s+$/g, '') + '</ul>';
    });

    // Restore extracted URLs as anchor tags (preserves raw & in href)
    html = html.replace(/\x00URL(\d+)\x00/g, (_, index) => {
        const url = urls[parseInt(index)];
        const display = url.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
        return `<a href="${url}">${display}</a>`;
    });

    // Restore code blocks and inline code BEFORE line break processing
    html = html.replace(/\x00CODEBLOCK(\d+)\x00/g, (match, index) => {
        return codeBlocks[parseInt(index)];
    });

    html = html.replace(/\x00INLINECODE(\d+)\x00/g, (match, index) => {
        return inlineCode[parseInt(index)];
    });

    // Restore tables, then images, before line break processing
    html = html.replace(/\x00TABLE(\d+)\x00/g, (match, index) => {
        return _buildTable(tables[parseInt(index)]);
    });

    html = html.replace(/\x00IMG(\d+)\x00/g, (match, index) => {
        const img = images[parseInt(index)];
        if (img.kind === "raw") return img.value;
        return `<img src="${img.src.replace(/"/g, '&quot;')}" alt="${_escape(img.alt)}"/>`;
    });

    // Line breaks (after code blocks and tables are restored)
    html = html.replace(/\n\n/g, '</p><p>');
    html = html.replace(/\n/g, '<br/>');

    // Wrap in paragraph tags if not already wrapped
    if (!html.startsWith('<')) {
        html = '<p>' + html + '</p>';
    }

    // Clean up the final HTML
    // Remove <br/> tags immediately before block elements
    html = html.replace(/<br\/>\s*<pre>/g, '<pre>');
    html = html.replace(/<br\/>\s*<ul>/g, '<ul>');
    html = html.replace(/<br\/>\s*<table>/g, '<table>');
    html = html.replace(/<br\/>\s*<h([1-6])>/g, '<h$1>');

    // Remove line breaks glued to list items and after block elements
    html = html.replace(/<br\/>\s*<li>/g, '<li>');
    html = html.replace(/<\/li>\s*<br\/>/g, '</li>');
    html = html.replace(/<\/(h[1-6]|pre|ul|ol|table)>\s*<br\/>/g, '</$1>');

    // Unwrap block elements that got wrapped in <p>
    html = html.replace(/<p>(?=\s*<(?:h[1-6]|pre|ul|ol|table))/g, '');
    html = html.replace(/<\/(h[1-6]|pre|ul|ol|table)>(\s*)<\/p>/g, '</$1>$2');

    // Remove empty paragraphs
    html = html.replace(/<p>\s*<\/p>/g, '');
    html = html.replace(/<p>\s*<br\/>\s*<\/p>/g, '');

    // Remove excessive line breaks
    html = html.replace(/(<br\/>){3,}/g, '<br/><br/>'); // Max 2 consecutive line breaks
    html = html.replace(/(<\/p>)\s*(<p>)/g, '$1$2'); // Remove whitespace between paragraphs

    // Apply block spacing (opt-in; all zero keeps the output compact)
    if (o.paragraphMarginBottom > 0) {
        html = html.replace(/<p>/g, `<p style="margin-bottom:${o.paragraphMarginBottom}px;">`);
    }
    if (o.headingMarginTop > 0 || o.headingMarginBottom > 0) {
        const headingStyle = `${o.headingMarginTop > 0 ? `margin-top:${o.headingMarginTop}px;` : ""}${o.headingMarginBottom > 0 ? `margin-bottom:${o.headingMarginBottom}px;` : ""}`;
        html = html.replace(/<h([1-6])>/g, `<h$1 style="${headingStyle}">`);
    }
    if (o.codeMarginTop > 0 || o.codeMarginBottom > 0) {
        const codeStyle = `${o.codeMarginTop > 0 ? `margin-top:${o.codeMarginTop}px;` : ""}${o.codeMarginBottom > 0 ? `margin-bottom:${o.codeMarginBottom}px;` : ""}`;
        html = html.replace(/<pre>/g, `<pre style="${codeStyle}">`);
    }
    if (o.listMarginTop > 0 || o.listMarginBottom > 0) {
        const listStyle = `${o.listMarginTop > 0 ? `margin-top:${o.listMarginTop}px;` : ""}${o.listMarginBottom > 0 ? `margin-bottom:${o.listMarginBottom}px;` : ""}`;
        html = html.replace(/<ul>/g, `<ul style="${listStyle}">`);
    }
    if (o.tableMarginTop > 0 || o.tableMarginBottom > 0) {
        const tableStyle = `${o.tableMarginTop > 0 ? `margin-top:${o.tableMarginTop}px;` : ""}${o.tableMarginBottom > 0 ? `margin-bottom:${o.tableMarginBottom}px;` : ""}`;
        html = html.replace(/<table>/g, `<table style="${tableStyle}">`);
    }

    // Link color (opt-in)
    if (o.linkColor) {
        html = html.replace(/<a /g, `<a style="color:${o.linkColor}" `);
    }

    // Remove leading/trailing whitespace
    html = html.trim();

    return html;
}