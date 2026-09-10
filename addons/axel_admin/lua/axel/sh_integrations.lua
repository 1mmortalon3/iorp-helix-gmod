-- Discover registries; execute through the source's ordinary player command route.
AXEL.IntegrationShortcuts = AXEL.IntegrationShortcuts or {}
function AXEL.RegisterIntegrationShortcut(id, entry)
    if not isstring(id) or not istable(entry) then return end
    AXEL.IntegrationShortcuts[id] = entry
end
AXEL.RegisterPermission("integrations", "Use installed addon command integrations", "Integrations")

-- A single command only. Quotes group arguments; separators/control bytes are rejected.
function AXEL.ParseIntegrationArguments(raw)
    if #raw > 1000 or (raw:find("[;%c]") or raw:find("\\",1,true)) then return nil, "Use one command, without semicolons or line breaks (1000 bytes maximum)." end
    local out, token, quoted, started = {}, "", false, false
    for i = 1, #raw do
        local char = raw:sub(i, i)
        if char == '"' then quoted = not quoted; started = true
        elseif char:match("%s") and not quoted then
            if started then out[#out + 1] = token; token, started = "", false end
        else token = token .. char; started = true end
    end
    if quoted then return nil, "Close the quotation mark around the argument." end
    if started then out[#out + 1] = token end
    if #out > 32 then return nil, "Maximum 32 arguments." end
    return out
end
if CLIENT then return end
util.AddNetworkString("AXEL.IntegrationList")
util.AddNetworkString("AXEL.IntegrationRequest")
util.AddNetworkString("AXEL.IntegrationRun")
local cooldown, snapshots = {}, {}
local function mayUse(client)
    return IsValid(client) and client:AXELHasPermission("menu") and client:AXELHasPermission("integrations")
end
local function validRoute(value)
    return isstring(value) and #value <= 120 and (value:match("^[%w_+%-]+$") or value:match("^darkrp_[%w_]+$"))
end
-- DarkRP builds disagree about the shape of DarkRP.command: some store a bare
-- function per name, others a table with the handler on a field. Resolve to
-- something callable here so detection and execution cannot drift apart.
local DARKRP_HANDLER_KEYS = {"func", "command", "callback", "onRun"}
local function darkrpCallable(name)
    if not DarkRP or not istable(DarkRP.command) then return nil end
    local entry = DarkRP.command[name]
    if isfunction(entry) then return entry end
    if istable(entry) then
        for _, key in ipairs(DARKRP_HANDLER_KEYS) do
            if isfunction(entry[key]) then return entry[key] end
        end
    end
    return nil
end
function AXEL.CollectIntegrations()
    local entries, seen = {}, {}
    local function add(source, name, root, prefix, route, description)
        if not validRoute(root) or not isstring(name) then return end
        prefix = prefix or ""
        if prefix ~= "" and not validRoute(prefix) then return end
        local id = source .. ":" .. root .. ":" .. prefix
        if seen[id] then return end
        seen[id] = true
        entries[#entries + 1] = {id=id, name=name:sub(1,120), source=source, root=root,
            prefix=prefix, route=route or "console", description=tostring(description or "Enter this addon's arguments; its own permissions apply."):sub(1,200)}
    end
    local consoles = concommand.GetTable()
    for name in next, consoles do
        if name ~= "axel" and not name:find("^axel_") then add("Console", name, name) end
    end
    if ix and ix.command and istable(ix.command.list) then
        for name, command in next, ix.command.list do
            if istable(command) then add("Helix", name, name, "", "helix", tostring(command.description or "") .. " " .. tostring(command.syntax or "")) end
        end
    end
    if ULib and ULib.cmds and istable(ULib.cmds.translatedCmds) then
        for name, command in next, ULib.cmds.translatedCmds do
            if isstring(name) then
                local root, sub = name:match("^(%S+)%s+(%S+)$")
                if root and consoles[root] then add("ULib / ULX", name, root, sub, "console", istable(command) and command.help or nil) end
            end
        end
    end
    -- SAM builds differ. A supported getter is optional; the sam console entry
    -- remains available even when per-command metadata is private or changed.
    if sam and sam.command and isfunction(sam.command.get_commands) and consoles.sam then
        local ok, registry = pcall(sam.command.get_commands)
        if ok and istable(registry) then
            for key, command in next, registry do
                local name = istable(command) and command.name or key
                if isstring(name) then add("SAM", name, "sam", name) end
            end
        end
    end
    -- DarkRP Integration - Enhanced support for both chat and client commands
    if DarkRP then
        -- Try to get chat commands
        if isfunction(DarkRP.getChatCommands) then
            local ok, registry = pcall(DarkRP.getChatCommands)
            if ok and istable(registry) then
                for name in next, registry do 
                    if isstring(name) then 
                        add("DarkRP", name, name, "", "darkrp_chat", "DarkRP chat command")
                    end 
                end
            end
        end
        -- Client commands. Listing one we cannot call would put a dead button
        -- in the menu, so the callable check runs here and not just on dispatch.
        if istable(DarkRP.command) then
            for name, command in next, DarkRP.command do
                if isstring(name) and darkrpCallable(name) then
                    local desc = istable(command) and isstring(command.description) and command.description or "DarkRP command"
                    add("DarkRP", name, name, "", "darkrp_cmd", desc)
                end
            end
        end
        -- Fallback: scan console for darkrp_ commands
        for name in next, consoles do
            if name:find("^darkrp_", 1, true) then
                add("DarkRP", name, name, "", "console")
            end
        end
    end
    for id, entry in next, AXEL.IntegrationShortcuts do
        add("Custom", entry.name or id, entry.command, entry.prefix, entry.route == "chat" and "chat" or "console", entry.description)
    end
    table.sort(entries, function(a,b) return a.source == b.source and a.name < b.name or a.source < b.source end)
    return entries
end
net.Receive("AXEL.IntegrationRequest", function(_, client)
    local offset = net.ReadUInt(16)
    if not mayUse(client) then return end
    if offset == 0 then
        if (cooldown[client] or 0) > CurTime() then return end
        cooldown[client] = CurTime() + 0.5
        snapshots[client] = AXEL.CollectIntegrations()
    end
    local entries = snapshots[client]
    if not entries or offset > #entries then return end
    local count = math.min(40, #entries - offset)
    net.Start("AXEL.IntegrationList")
    net.WriteUInt(offset,16); net.WriteBool(offset + count < #entries); net.WriteUInt(count,8)
    for i = offset + 1, offset + count do
        local e = entries[i]
        net.WriteString(e.id); net.WriteString(e.name); net.WriteString(e.source); net.WriteString(e.description)
    end
    net.Send(client)
end)
net.Receive("AXEL.IntegrationRun", function(_, client)
    local id, raw = net.ReadString(), net.ReadString()
    if not mayUse(client) then return end
    if (client.AXELIntegrationNext or 0) > CurTime() then return end
    client.AXELIntegrationNext = CurTime() + 0.4
    local args, err = AXEL.ParseIntegrationArguments(raw)
    if not args then client:ChatPrint("[Axel] " .. err); return end
    local selected
    -- Refresh registry on execution so removed commands cannot be replayed.
    for _, entry in ipairs(AXEL.CollectIntegrations()) do if entry.id == id then selected = entry; break end end
    if not selected then client:ChatPrint("[Axel] Command removed. Refresh Integrations."); return end
    local line = selected.root
    if selected.prefix ~= "" then line = line .. " " .. selected.prefix end
    
    -- Handle Helix commands
    if selected.route == "helix" then
        if not ix or not ix.command or not isfunction(ix.command.Parse) then return end
        local ok, problem = pcall(ix.command.Parse, client, "/" .. selected.root .. " " .. raw)
        if not ok then ErrorNoHalt("[AXEL] Helix integration error: " .. tostring(problem) .. "\n"); client:ChatPrint("[Axel] Source command errored; see server console."); return end
    -- Handle DarkRP chat commands
    elseif selected.route == "darkrp_chat" then
        -- Preserve original grouping for the chat parser, but escape no console text:
        -- quotes are not accepted on this route because say wraps the entire payload.
        if raw:find('"',1,true) then client:ChatPrint("[Axel] DarkRP chat commands use plain arguments without quotation marks."); return end
        line = 'say "/' .. line .. (raw ~= "" and " " .. raw or "") .. '"'
        client:ConCommand(line)
    -- Handle DarkRP client commands (sv_runcommand)
    elseif selected.route == "darkrp_cmd" then
        local callable = darkrpCallable(selected.root)
        if not callable then client:ChatPrint("[Axel] That DarkRP command is no longer callable. Refresh Integrations."); return end
        local ok, problem = pcall(callable, client, args)
        if not ok then ErrorNoHalt("[AXEL] DarkRP command integration error: " .. tostring(problem) .. "\n"); client:ChatPrint("[Axel] Source command errored; see server console."); return end
    -- Handle generic chat commands
    elseif selected.route == "chat" then
        -- Preserve original grouping for the chat parser, but escape no console text:
        -- quotes are not accepted on this route because say wraps the entire payload.
        if raw:find('"',1,true) then client:ChatPrint("[Axel] Chat commands use plain arguments without quotation marks."); return end
        line = 'say "/' .. line .. (raw ~= "" and " " .. raw or "") .. '"'
        client:ConCommand(line)
    -- Handle console commands
    else
        for _, arg in ipairs(args) do line = line .. ' "' .. arg .. '"' end
        client:ConCommand(line)
    end
    AXEL.Log(client:SteamID(), client:Nick(), "integration", selected.id, "Dispatched " .. selected.source .. " / " .. selected.name .. "; source addon determines success.")
    client:ChatPrint("[Axel] Sent to " .. selected.source .. ". Check its feedback for the result.")
end)
hook.Add("PlayerDisconnected", "AXEL.IntegrationCleanup", function(client) cooldown[client]=nil; snapshots[client]=nil end)
