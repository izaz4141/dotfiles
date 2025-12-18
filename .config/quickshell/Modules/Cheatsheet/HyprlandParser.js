.pragma library

function parse(configContent) {
    const lines = configContent.split('\n');
    const root = {
        children: []
    };

    let currentSection = null;

    // Helper to find or create a section
    function getSection(name) {
        let section = root.children.find(c => c.name === name);
        if (!section) {
            section = {
                name: name,
                keybinds: []
            };
            root.children.push(section);
        }
        return section;
    }

    // Default section
    currentSection = getSection("General");

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();

        // Skip empty lines
        if (!line) continue;

        // Check for section headers (comments starting with # Section Name)
        // We look for lines that are just a comment and not inline comments
        if (line.startsWith('#') && !line.startsWith('# bind')) {
            const comment = line.substring(1).trim();
            // Simple heuristic: if it's a short comment, treat as section header
            // Ignoring separator lines like # -----------------
            if (comment.length > 0 && comment.length < 30 && !comment.startsWith('-')) {
                currentSection = getSection(comment);
            }
            continue;
        }

        // Parse binds
        // Format: bind = MODS, KEY, ACTION, ARGS # Comment
        if (line.startsWith('bind =') || line.startsWith('bindm =')) {
            // Remove 'bind = ' or 'bindm = '
            const parts = line.split('=');
            if (parts.length < 2) continue;

            const bindBody = parts.slice(1).join('=').trim();

            // Split by comma, but be careful about comments
            // We can split by comma first, then handle the last part which might have a comment
            const tokens = bindBody.split(',').map(t => t.trim());

            if (tokens.length < 2) continue;

            let mods = tokens[0];
            let key = tokens[1];
            let action = tokens[2] || "";
            let args = tokens.slice(3).join(', '); // Join remaining args

            // Extract comment from the last valid token or args
            let comment = "";

            // Check if there is a comment in the line
            const commentIndex = line.indexOf('#');
            if (commentIndex !== -1) {
                // Verify the comment is after the bind definition
                // (Simple check: is it at the end?)
                comment = line.substring(commentIndex + 1).trim();
            }

            // Clean up mods
            const modParts = mods.split(' ').filter(m => m !== "");

            // Clean up key
            // If key is empty/invalid, skip
            if (!key) continue;

            currentSection.keybinds.push({
                mods: modParts,
                key: key,
                action: action,
                args: args,
                comment: comment
            });
        }
    }

    // Filter out empty sections
    root.children = root.children.filter(s => s.keybinds.length > 0);

    return root;
}
