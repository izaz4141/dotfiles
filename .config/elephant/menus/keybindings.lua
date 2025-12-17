
Name = "keybindings"
NamePretty = "Keybindings"
Icon = "keyboard"
Cache = false
-- No global action, each entry has its own
-- Action = ""
HideFromProviderlist = false
Description = "Hyprland Keybindings"
SearchName = true

function GetEntries()
    local entries = {}
    local keybind_file = os.getenv("HOME") .. "/.config/hypr/conf/keybindings/default.conf"
    local file = io.open(keybind_file, "r")

    if not file then
        table.insert(entries, { Text = "Error: Could not open keybindings file", Subtext = keybind_file, Icon = "dialog-error" })
        return entries
    end

    local mainMod = "SUPER"
    local dispatchers = { "exec", "killactive", "fullscreen", "togglefloating", "togglesplit", "movefocus", "movewindow", "resizewindow", "resizeactive", "togglegroup", "swapsplit", "pin", "movewindoworgroup", "changegroupactive", "workspace", "movetoworkspace", "submap" }

    for line in file:lines() do
        if line:match("^bind") and not line:match("^#") then
            local bind_part, description = line:match("bindm?[e%s]*=[%s]*(.*)#(.*)")
            if bind_part and description then
                bind_part = bind_part:gsub("%$mainMod", mainMod)
                bind_part = bind_part:gsub("%$HYPRSCRIPTS", os.getenv("HOME") .. "/.config/hypr/scripts")
                bind_part = bind_part:gsub("%$SCRIPTS", os.getenv("HOME") .. "/.config/ml4w/scripts")

                local parts = {}
                for part in bind_part:gmatch("([^,]+)") do
                    table.insert(parts, part:match("^%s*(.-)%s*$"))
                end

                if #parts == 0 then goto continue end

                local dispatcher_index = 0
                for i = #parts, 1, -1 do
                    for _, d in ipairs(dispatchers) do
                        if parts[i] == d then
                            dispatcher_index = i
                            goto found_dispatcher
                        end
                    end
                end
                ::found_dispatcher::

                local keys_list = {}
                local command = ""
                local args = ""

                if dispatcher_index ~= 0 then
                    for i = 1, dispatcher_index - 1 do
                        if parts[i] ~= "" then table.insert(keys_list, parts[i]) end
                    end
                    command = parts[dispatcher_index]
                    local args_list = {}
                    for i = dispatcher_index + 1, #parts do
                        table.insert(args_list, parts[i])
                    end
                    args = table.concat(args_list, ", ")
                else
                    -- Fallback for dispatchers not in the list
                    command = parts[#parts]
                    for i = 1, #parts - 1 do
                        if parts[i] ~= "" then table.insert(keys_list, parts[i]) end
                    end
                end

                local keys = table.concat(keys_list, " + ")
                local action_command
                if command == "exec" then
                    action_command = args
                else
                    action_command = command .. (args ~= "" and " " .. args or "")
                end

                table.insert(entries, {
                    Text = keys,
                    Subtext = description:match("^%s*(.-)%s*$"),
                    Value = action_command,
                    Actions = { default = action_command }
                })
            end
        end
        ::continue::
    end

    file:close()
    return entries
end
