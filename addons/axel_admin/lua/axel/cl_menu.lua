-- Axel Admin Menu: command centre Derma interface.
-- Actions retain the existing network messages and server permission checks.
if SERVER then return end
local UI, frame = AXEL.UI, nil
local C, S = UI.C, UI.S
local data = {players = {}, bans = {}, ranks = {}, logs = {}, commands = {}, integrations = {}, permissions = {}}
local loaded, updated, rankByName = {}, {}, {}
local activeTab, selectedPlayer = "overview", nil
local filters = {overview = "", players = "", bans = "", ranks = "", logs = "", commands = "", integrations = ""}
local nextCommand, noticeUntil = 0, 0
local notice = ""
local Refresh, SelectTab, OpenPermissions, BuildPlayerDetails, commandForm

local function tell(text) notice, noticeUntil = text, RealTime() + 4 end
local function request(kind)
    if kind == "overview" then
        for _, section in ipairs({"players", "ranks", "bans", "logs"}) do request(section) end
        return
    end
    if kind == "commands" then return end
    if kind == "integrations" then
        net.Start("AXEL.IntegrationRequest"); net.WriteUInt(0,16); net.SendToServer(); return
    end
    net.Start("AXEL.RequestData")
    net.WriteString(kind)
    net.SendToServer()
end
local function later(kind)
    timer.Create("AXEL.UI.Request." .. kind, 0.4, 1, function() request(kind) end)
end
local function run(name, ...)
    if RealTime() < nextCommand then return false, "Please wait a moment before the next action." end
    nextCommand = RealTime() + 0.22
    local args = {...}
    net.Start("AXEL.RunCommand")
    net.WriteString(name)
    net.WriteUInt(math.min(#args, 8), 4)
    for index = 1, math.min(#args, 8) do net.WriteString(tostring(args[index])) end
    net.SendToServer()
    tell("Request sent. Server feedback appears in chat.")
    return true
end
--[[
    The local player's own rank, pushed by the server.

    Only the local rank is needed here: it decides which controls the menu greys
    out. Every other player's rank arrives inside AXEL.SendPlayers already.

    GetUserGroup is kept as a fallback for the window between joining and the
    first push, since the server mirrors the rank onto the engine usergroup too.
]]
AXEL.LocalRank = AXEL.LocalRank or ""

local function localRank()
    if AXEL.LocalRank ~= "" then return AXEL.LocalRank end
    local client = LocalPlayer()
    if not IsValid(client) then return "user" end
    return client:GetUserGroup()
end

net.Receive("AXEL.RankUpdate", function()
    local previous = AXEL.LocalRank
    AXEL.LocalRank = net.ReadString()

    -- A rank change moves which permissions we hold, so anything currently
    -- drawn from a permission check has to be rebuilt rather than left stale.
    if previous ~= AXEL.LocalRank and IsValid(frame) then
        AXEL.BuildMenu()
    end
end)

local function requestRank()
    net.Start("AXEL.RankRequest")
    net.SendToServer()
end

hook.Add("InitPostEntity", "AXEL.RankHandshake", function()
    timer.Simple(2, requestRank)
end)
local function inheritsSuper(name)
    local seen = {}
    while name and name ~= "" and not seen[name] do
        if name == AXEL.SuperRank then return true end
        seen[name] = true
        local rank = rankByName[name]
        name = rank and rank.inherit or nil
    end
    return false
end
local function resolvePermission(name, permission)
    local seen, first = {}, name
    while name and name ~= "" and not seen[name] do
        seen[name] = true
        local rank = rankByName[name]
        if not rank then return nil end
        local value = (rank.permissions or {})[permission]
        if value ~= nil then return value, name == first and "own" or name end
        name = rank.inherit
    end
    return nil
end
local function allowed(permission)
    -- An unknown snapshot must not lock users out; the server remains authoritative.
    if not loaded.ranks then return true end
    if inheritsSuper(localRank()) then return true end
    return resolvePermission(localRank(), permission) == true
end
local function editable(rank)
    if not allowed("manageranks") then return false end
    if inheritsSuper(localRank()) then return true end
    local own = rankByName[localRank()]
    return own and (tonumber(own.immunity) or 0) > (tonumber(rank.immunity) or 0) or false
end
local function gate(button, permission)
    button:SetEnabled(allowed(permission))
    if not allowed(permission) then button:SetTooltip("Requires the " .. permission .. " permission.") end
    return button
end
local function matches(query, ...)
    query = string.lower(string.Trim(query or ""))
    if query == "" then return true end
    for _, value in ipairs({...}) do
        if string.find(string.lower(tostring(value)), query, 1, true) then return true end
    end
    return false
end
local function playtime(seconds)
    return (tonumber(seconds) or 0) <= 0 and "0m" or AXEL.FormatDuration(seconds)
end
local function remaining(expires)
    if expires == 0 then return "Permanent" end
    if expires <= os.time() then return "Expired" end
    return AXEL.FormatDuration(expires - os.time()) .. " remaining"
end
local function copy(value)
    SetClipboardText(tostring(value))
    tell("SteamID copied to clipboard.")
end
local function rebuildScroll(scroll, populate)
    local position = scroll:GetVBar():GetScroll()
    scroll:Clear()
    populate(scroll)
    scroll:InvalidateLayout(true)
    scroll:GetVBar():SetScroll(position)
end
local function blank(scroll, kind, count)
    if count > 0 then return end
    if not loaded[kind] then
        UI.Empty(scroll, "Waiting for server data", "Refresh this page if the list does not appear.")
    elseif filters[kind] ~= "" then
        UI.Empty(scroll, "No matching results", "Try another name, SteamID or keyword.")
    else
        local titles = {players = "No players online", bans = "No active bans", ranks = "No ranks loaded", logs = "No logged actions"}
        UI.Empty(scroll, titles[kind], "Use Refresh to retrieve the latest records.")
    end
end
local function paragraph(parent, text)
    local label = vgui.Create("DLabel", parent)
    label:Dock(TOP)
    label:DockMargin(0, 0, 0, S(12))
    label:SetFont("AXEL.Body")
    label:SetTextColor(C.muted)
    -- DLabel caches its colour instead of reading it each frame, so this is the
    -- one place in the menu that would keep the previous theme after a swap.
    label.Think = function(self) self:SetTextColor(C.muted) end
    label:SetText(text)
    label:SetWrap(true)
    label:SetAutoStretchVertical(true)
    return label
end

-- All dialogs use the same local theme, including input, validation and choices.
local function form(title, subtitle, fields, callback, submitText, tone, explanation)
    local dialog = UI.OpenModal(frame, title, subtitle, 550, math.max(290, 205 + #fields * 82))
    local footer = UI.Panel(dialog)
    footer:Dock(BOTTOM); footer:SetTall(S(40))
    local cancel = UI.Button(footer, "Cancel", function() dialog:Close() end)
    cancel:Dock(LEFT); cancel:SetWide(S(106))
    local submit = UI.Button(footer, submitText or "Save changes", nil, tone or "primary")
    submit:Dock(RIGHT); submit:SetWide(S(160))
    local errorText = ""
    local errorLabel = UI.Label(dialog, function() return errorText end, 34, C.accentHover)
    errorLabel:Dock(BOTTOM)
    local scroll = UI.Scroll(dialog)
    scroll:Dock(FILL)
    if explanation then paragraph(scroll, explanation) end
    local entries = {}
    for _, field in ipairs(fields) do
        local block = UI.Panel(scroll)
        block:Dock(TOP); block:SetTall(S(82))
        UI.Label(block, field.label, 27, C.muted, "AXEL.Label")
        local shell, entry = UI.Entry(block, field.placeholder, field.value)
        shell:Dock(TOP)
        if field.numeric then entry:SetNumeric(true) end
        entries[field.key] = entry
        if field.player then
            local picker = UI.Button(block, "Choose player", function()
                local menu = DermaMenu()
                for _, target in ipairs(data.players) do
                    menu:AddOption(target.name, function() entry:SetText(target.steamid) end)
                end
                if field.multiple then menu:AddOption("All players (subject to immunity)", function() entry:SetText("*") end) end
                menu:Open()
            end)
            picker:Dock(TOP); picker:SetTall(S(28))
            block:SetTall(S(116))
            shell:Dock(TOP)
        end
    end
    submit.DoClick = function()
        local values = {}
        for _, field in ipairs(fields) do
            local text = string.Trim(entries[field.key]:GetText())
            if field.required and text == "" then errorText = field.label .. " is required."; return end
            if #text > 200 then errorText = field.label .. " is too long (200 bytes maximum)."; return end
            values[field.key] = text
        end
        local ok, message = callback(values)
        if ok == false then
            errorText = message or "Please check the values and try again."
            errorLabel:SetTooltip(errorText)
        else dialog:Close() end
    end
    -- entries is keyed by field.key ("reason", "duration"), not by index, so
    -- pairs is required; ipairs would attach OnEnter to nothing.
    for _, entry in next, entries do entry.OnEnter = function() submit:DoClick() end end
    if fields[1] then entries[fields[1].key]:RequestFocus() end
    return dialog
end
local function choose(title, subtitle, choices)
    local dialog = UI.OpenModal(frame, title, subtitle, 500, 530)
    local search = UI.Entry(dialog, "Search ranks...", "", function(value)
        dialog.Filter = value
        dialog.Rebuild()
    end, true)
    search:Dock(TOP); search:DockMargin(0, 0, 0, S(12))
    local scroll = UI.Scroll(dialog)
    scroll:Dock(FILL)
    dialog.Rebuild = function()
        rebuildScroll(scroll, function()
            local count = 0
            for _, option in ipairs(choices) do
                if matches(dialog.Filter, option.label) then
                    count = count + 1
                    local button = UI.Button(scroll, option.label, function()
                        dialog:Close()
                        option.callback()
                    end)
                    button:Dock(TOP); button:DockMargin(0, 0, 0, S(6)); button:SetTall(S(42))
                    button:SetEnabled(option.enabled ~= false)
                    button:SetTooltip(option.label)
                end
            end
            if count == 0 then UI.Empty(scroll, "No matching ranks", "Try a different search.") end
        end)
    end
    dialog.Rebuild()
end
local function changePlayerRank(entry)
    local choices = {}
    for _, rank in ipairs(data.ranks) do
        choices[#choices + 1] = {label = rank.name .. "  /  immunity " .. rank.immunity, callback = function()
            local ok, message = run("setrank", entry.steamid, rank.name, "0")
            if ok then later("players") else tell(message) end
        end}
    end
    choose("Assign rank", entry.name, choices)
end
local function playerAction(entry, command)
    if command == "ban" then
        form("Ban player", entry.name, {
            {key = "duration", label = "DURATION", value = "1h", placeholder = "30m, 2h, 7d or 0 for permanent", required = true},
            {key = "reason", label = "REASON", placeholder = "Enter a reason", required = true}
        }, function(values)
            if AXEL.ParseDuration(values.duration) == nil then return false, "Use a duration such as 30m, 2h, 7d or 0." end
            local ok, message = run("ban", entry.steamid, values.duration, values.reason)
            if ok then later("players"); later("bans") end
            return ok, message
        end, "Ban player", "primary")
    elseif command == "kick" then
        form("Kick player", entry.name, {
            {key = "reason", label = "REASON", placeholder = "Enter a reason", required = true}
        }, function(values)
            local ok, message = run("kick", entry.steamid, values.reason)
            if ok then later("players") end
            return ok, message
        end, "Kick player", "primary")
    else
        commandForm(AXEL.GetCommand(command), entry)
    end
end


local argumentLabels = {
    hp = {"Player", "Health"}, armor = {"Player", "Armour"},
    setrank = {"Player", "Rank", "Duration"}, banid = {"SteamID", "Duration", "Reason"},
    ban = {"Player", "Duration", "Reason"}, kick = {"Player", "Reason"},
    unban = {"SteamID"}, asay = {"Message"},
    addrank = {"Rank name", "Immunity", "Parent rank"}, removerank = {"Rank name"},
    rankimmunity = {"Rank name", "Immunity"}, rankinherit = {"Rank name", "Parent rank"},
    rankperm = {"Rank name", "Permission", "allow / deny / clear"}
}
commandForm = function(command, target)
    if not command then tell("Command unavailable."); return end
    local fields, fixed = {}, {}
    for index, kind in ipairs(command.arguments) do
        local isPlayer = kind == "player" or kind == "players"
        if isPlayer and target and index == 1 then
            fixed[index] = target.steamid
        else
            local labels = command.argumentLabels or argumentLabels[command.name] or {}
            fields[#fields + 1] = {
                key = tostring(index), label = string.upper(labels[index] or (isPlayer and "Player" or kind)),
                required = kind ~= "duration" and kind ~= "text", numeric = kind == "number",
                value = kind == "duration" and "0" or (kind == "number" and "100" or ""),
                placeholder = isPlayer and "Choose a player or enter a SteamID" or (kind == "duration" and "30m, 2h, 7d or 0" or "Enter value"),
                player = isPlayer, multiple = kind == "players"
            }
        end
    end
    form(string.upper(command.name), target and target.name or command.category, fields, function(values)
        local args = {}
        for index, kind in ipairs(command.arguments) do
            local value = fixed[index] or values[tostring(index)] or ""
            if kind == "number" then
                local n = tonumber(value)
                if not n or n ~= n or n == math.huge or n == -math.huge then return false, "Enter a finite number." end
            elseif kind == "duration" and not AXEL.ParseDuration(value) then
                return false, "Use a duration such as 30m, 2h, 7d or 0."
            end
            args[index] = value
        end
        local ok, message = run(command.name, unpack(args))
        if ok then later("players"); later("ranks"); later("bans") end
        return ok, message
    end, "Run command", "primary", command.description)
end
local function BuildCommands(parent)
    local scroll = UI.Scroll(parent)
    scroll:Dock(FILL)
    parent.Refresh = function()
        data.commands = AXEL.GetCommandList()
        loaded.commands = true
        rebuildScroll(scroll, function()
            local lastCategory, count = nil, 0
            for _, command in ipairs(data.commands) do
                if command.name ~= "menu" and matches(filters.commands, command.name, command.category, command.description) then
                    count = count + 1
                    if lastCategory ~= command.category then
                        lastCategory = command.category
                        UI.Label(scroll, string.upper(command.category), 34, C.accentHover, "AXEL.Label")
                    end
                    local button = gate(UI.Button(scroll, string.upper(command.name) .. "  /  " .. command.description,
                        function() commandForm(command) end), command.permission)
                    button:Dock(TOP); button:SetTall(S(44)); button:DockMargin(0, 0, 0, S(6))
                    if allowed(command.permission) then button:SetTooltip(command.description) end
                end
            end
            if count == 0 then UI.Empty(scroll, "No matching commands", "Search by name or category.") end
        end)
    end
    parent.Refresh()
end

BuildPlayerDetails = function(parent, entry)
    parent:Clear()
    local scroll = UI.Scroll(parent)
    scroll:Dock(FILL)
    if not entry then UI.Empty(scroll, "Select a player", "Choose someone from the player list."); return end
    local profile = UI.Panel(scroll)
    profile:Dock(TOP); profile:SetTall(S(122))
    UI.Avatar(profile, entry, 48):SetPos(S(14), S(12))
    profile.Paint = function(_, w, h)
        UI.Box(0, 0, w, h, C.panel)
        UI.Text("SELECTED PLAYER", "AXEL.Label", S(76), S(26), C.muted, w - S(90))
        UI.Text(entry.rank, "AXEL.Body", S(76), S(49), C.amber, w - S(90))
        UI.Text(entry.name, "AXEL.Heading", S(14), S(80), C.text, w - S(28))
        UI.Text(entry.steamid, "AXEL.Small", S(14), S(105), C.muted, w - S(28))
    end
    profile:SetTooltip(entry.name .. "\n" .. entry.steamid)
    local meta = UI.Panel(scroll)
    meta:Dock(TOP); meta:DockMargin(0, S(8), 0, S(8)); meta:SetTall(S(54))
    meta.Paint = function(_, w, h)
        UI.Box(0, 0, w, h, C.panel)
        UI.Text("IMMUNITY", "AXEL.Label", S(12), S(16), C.muted, w / 2 - S(20))
        UI.Text(tostring(entry.immunity), "AXEL.Body", S(12), S(38), C.text, w / 2 - S(20))
        UI.Text("TIME PLAYED", "AXEL.Label", w / 2, S(16), C.muted, w / 2 - S(12))
        UI.Text(playtime(entry.playtime), "AXEL.Body", w / 2, S(38), C.text, w / 2 - S(12))
    end
    local copyButton = UI.Button(scroll, "Copy SteamID", function() copy(entry.steamid) end)
    copyButton:Dock(TOP); copyButton:SetTall(S(32)); copyButton:DockMargin(0, 0, 0, S(6))
    UI.Label(scroll, "PLAYER ACTIONS", 28, C.muted, "AXEL.Label")
    local function pair(specs, tone)
        local panel = UI.Panel(scroll)
        panel:Dock(TOP); panel:DockMargin(0, 0, 0, S(6)); panel:SetTall(S(34))
        local buttons = {}
        for column, action in ipairs(specs) do
            local command = AXEL.GetCommand(action[2])
            buttons[column] = gate(UI.Button(panel, action[1], function() playerAction(entry, action[2]) end, tone),
                command and command.permission or action[2])
        end
        panel.PerformLayout = function(_, w, h)
            local half = math.floor((w - S(8)) / 2)
            buttons[1]:SetPos(0, 0); buttons[1]:SetSize(half, h)
            buttons[2]:SetPos(half + S(8), 0); buttons[2]:SetSize(w - half - S(8), h)
        end
    end
    pair({{"Bring", "bring"}, {"Go to", "goto"}})
    pair({{"Return", "return"}, {"Noclip", "noclip"}})
    pair({{"Set health", "hp"}, {"Set armour", "armor"}})
    pair({{"Heal", "heal"}, {"Extinguish", "extinguish"}})
    pair({{"Godmode", "god"}, {"Godmode off", "ungod"}})
    pair({{"Mute voice", "mute"}, {"Unmute voice", "unmute"}})
    pair({{"Gag text", "gag"}, {"Ungag text", "ungag"}})
    pair({{"Freeze", "freeze"}, {"Unfreeze", "unfreeze"}})
    pair({{"Slay", "slay"}, {"Respawn", "respawn"}})
    local rank = gate(UI.Button(scroll, "Assign rank", function() changePlayerRank(entry) end), "setrank")
    rank:Dock(TOP); rank:SetTall(S(34)); rank:DockMargin(0, 0, 0, S(8))
    UI.Label(scroll, "MODERATION", 28, C.muted, "AXEL.Label")
    pair({{"Kick player", "kick"}, {"Ban player", "ban"}}, "danger")
end
local function BuildPlayers(parent)
    local details
    if parent:GetWide() >= S(700) then
        details = UI.Panel(parent)
        details:Dock(RIGHT); details:SetWide(S(292)); details:DockMargin(S(16), 0, 0, 0)
    end
    local scroll = UI.Scroll(parent)
    scroll:Dock(FILL)
    parent.Refresh = function()
        local chosen
        for _, entry in ipairs(data.players) do if entry.steamid == selectedPlayer then chosen = entry end end
        if not chosen then chosen = data.players[1]; selectedPlayer = chosen and chosen.steamid or nil end
        if IsValid(details) then BuildPlayerDetails(details, chosen) end
        rebuildScroll(scroll, function()
            local entries = {}
            for _, entry in ipairs(data.players) do
                if matches(filters.players, entry.name, entry.steamid, entry.rank) then entries[#entries + 1] = entry end
            end
            table.sort(entries, function(a, b) return string.lower(a.name) < string.lower(b.name) end)
            for _, entry in ipairs(entries) do
                local row = vgui.Create("DButton", scroll)
                row:Dock(TOP); row:DockMargin(0, 0, 0, S(8)); row:SetTall(S(96))
                row:SetText(""); row:SetCursor("hand")
                row:SetTooltip(entry.name .. "\n" .. entry.steamid .. "\nSelect to manage this player")
                UI.Avatar(row, entry, 44):SetPos(S(14), S(14))
                row.Paint = function(self, w, h)
                    local active = selectedPlayer == entry.steamid
                    UI.Box(0, 0, w, h, active and C.accentSoft or (self:IsHovered() and C.hover or C.panel), active and C.accent or C.border)
                    UI.Text(entry.name, "AXEL.Body", S(72), S(29), C.text, w - S(92))
                    UI.Text(entry.rank, "AXEL.Small", S(72), S(50), C.amber, w - S(92))
                    UI.Text(entry.steamid, "AXEL.Small", S(14), S(78), C.muted, w - S(80))
                    UI.Text("View", "AXEL.Small", w - S(14), S(78), active and C.text or C.muted, S(40), TEXT_ALIGN_RIGHT)
                end
                row.DoClick = function()
                    selectedPlayer = entry.steamid
                    if IsValid(details) then BuildPlayerDetails(details, entry)
                    else
                        local dialog = UI.OpenModal(frame, "Player details", entry.name, 410, 700)
                        local body = UI.Panel(dialog)
                        body:Dock(FILL)
                        BuildPlayerDetails(body, entry)
                    end
                end
            end
            blank(scroll, "players", #entries)
        end)
    end
    parent.Refresh()
end
local function BuildBans(parent)
    local scroll = UI.Scroll(parent)
    scroll:Dock(FILL)
    parent.Refresh = function()
        rebuildScroll(scroll, function()
            local count = 0
            for _, ban in ipairs(data.bans) do
                if matches(filters.bans, ban.name, ban.steamid, ban.reason, ban.admin) then
                    count = count + 1
                    local row = UI.Panel(scroll)
                    row:Dock(TOP); row:DockMargin(0, 0, 0, S(10)); row:SetTall(S(132))
                    row:SetTooltip(ban.name .. "\n" .. ban.steamid .. "\n" .. ban.reason .. "\nBanned by " .. ban.admin)
                    row.Paint = function(_, w, h)
                        UI.Box(0, 0, w, h, C.panel)
                        UI.Text(ban.name, "AXEL.Heading", S(16), S(28), C.text, w - S(195))
                        UI.Text(remaining(ban.expires), "AXEL.Small", w - S(16), S(28), C.amber, S(170), TEXT_ALIGN_RIGHT)
                        UI.Text(ban.steamid .. "  /  by " .. ban.admin, "AXEL.Small", S(16), S(54), C.muted, w - S(32))
                        UI.Text("Reason: " .. (ban.reason ~= "" and ban.reason or "No reason given"), "AXEL.Body", S(16), S(83), C.text, w - S(32))
                    end
                    local id = UI.Button(row, "Copy SteamID", function() copy(ban.steamid) end)
                    local unban = gate(UI.Button(row, "Lift ban", function()
                        form("Lift ban", ban.name, {}, function()
                            local ok, message = run("unban", ban.steamid)
                            if ok then later("bans") end
                            return ok, message
                        end, "Lift ban", "primary", "Remove the ban for " .. ban.steamid .. "? This player will be able to connect again.")
                    end), "unban")
                    row.PerformLayout = function(_, w, h)
                        id:SetPos(S(16), h - S(33)); id:SetSize(S(128), S(26))
                        unban:SetPos(w - S(126), h - S(33)); unban:SetSize(S(110), S(26))
                    end
                end
            end
            blank(scroll, "bans", count)
        end)
    end
    parent.Refresh()
end
local function createRank()
    form("Create rank", "Define a rank and its place in the hierarchy.", {
        {key = "name", label = "RANK NAME", placeholder = "senior_moderator", required = true},
        {key = "immunity", label = "IMMUNITY (0-100)", value = "10", numeric = true, required = true},
        {key = "parent", label = "PARENT RANK", value = "user", required = true}
    }, function(values)
        local clean, errorText = AXEL.ValidateRankName(values.name)
        if not clean then return false, errorText end
        local immunity = tonumber(values.immunity)
        if not immunity or immunity < 0 or immunity > 100 then return false, "Immunity must be between 0 and 100." end
        if rankByName[clean] then return false, "That rank already exists." end
        local parent = string.lower(values.parent)
        if not rankByName[parent] then return false, "Choose an existing parent rank." end
        local ok, message = run("addrank", clean, math.floor(immunity), parent)
        if ok then later("ranks") end
        return ok, message
    end, "Create rank")
end
local function changeParent(rank)
    local choices = {{label = "No parent", callback = function()
        local ok, message = run("rankinherit", rank.name, "none")
        if ok then later("ranks") else tell(message) end
    end}}
    for _, other in ipairs(data.ranks) do
        if other.name ~= rank.name then
            choices[#choices + 1] = {label = other.name, callback = function()
                local ok, message = run("rankinherit", rank.name, other.name)
                if ok then later("ranks") else tell(message) end
            end}
        end
    end
    choose("Change parent rank", rank.name, choices)
end
local function BuildRanks(parent)
    local toolbar = UI.Panel(parent)
    toolbar:Dock(TOP); toolbar:DockMargin(0, 0, 0, S(12)); toolbar:SetTall(S(36))
    local add = gate(UI.Button(toolbar, "+  Create rank", createRank, "primary"), "manageranks")
    add:Dock(RIGHT); add:SetWide(S(154))
    toolbar.Paint = function(_, w, h)
        UI.Text("Rank hierarchy & access", "AXEL.Body", 0, h / 2, C.muted, w - S(174))
    end
    local scroll = UI.Scroll(parent)
    scroll:Dock(FILL)
    parent.Refresh = function()
        gate(add, "manageranks")
        rebuildScroll(scroll, function()
            local count = 0
            for _, rank in ipairs(data.ranks) do
                if matches(filters.ranks, rank.name, rank.inherit, rank.immunity) then
                    count = count + 1
                    -- Keyed by permission name, so table.Count and not #.
                    local own = table.Count(rank.permissions or {})
                    local protected = rank.name == AXEL.RootRank or rank.name == AXEL.SuperRank
                    local row = UI.Panel(scroll)
                    row:Dock(TOP); row:DockMargin(0, 0, 0, S(10)); row:SetTall(S(130))
                    row:SetTooltip(rank.name .. "\nParent: " .. (rank.inherit ~= "" and rank.inherit or "none"))
                    row.Paint = function(_, w, h)
                        UI.Box(0, 0, w, h, C.panel)
                        UI.Icon("ranks", S(16), S(20), S(24), C.accentHover)
                        UI.Text(rank.name, "AXEL.Heading", S(54), S(30), C.text, w - S(205))
                        UI.Text("Immunity  " .. rank.immunity, "AXEL.Button", w - S(16), S(30), C.amber, S(145), TEXT_ALIGN_RIGHT)
                        UI.Text((rank.inherit ~= "" and "Inherits " .. rank.inherit or "Root rank") .. "  /  " .. own .. " explicit permissions",
                            "AXEL.Small", S(16), S(61), C.muted, w - S(32))
                        local progress = math.Clamp((tonumber(rank.immunity) or 0) / 100, 0, 1)
                        draw.RoundedBox(S(2), S(16), S(77), w - S(32), S(3), C.border)
                        if progress > 0 then draw.RoundedBox(S(2), S(16), S(77), (w - S(32)) * progress, S(3), C.accent) end
                    end
                    local actions = {
                        {"Permissions", function() OpenPermissions(rank.name) end, true},
                        {"Immunity", function()
                            form("Change immunity", rank.name, {
                                {key = "immunity", label = "IMMUNITY (0-100)", value = tostring(rank.immunity), required = true, numeric = true}
                            }, function(values)
                                local value = tonumber(values.immunity)
                                if not value or value < 0 or value > 100 then return false, "Immunity must be between 0 and 100." end
                                local ok, message = run("rankimmunity", rank.name, math.floor(value))
                                if ok then later("ranks") end
                                return ok, message
                            end)
                        end, editable(rank)},
                        {"Parent", function() changeParent(rank) end, editable(rank) and rank.name ~= AXEL.RootRank},
                        {protected and "Protected" or "Delete", function()
                            form("Delete rank", rank.name, {}, function()
                                local ok, message = run("removerank", rank.name)
                                if ok then later("ranks"); later("players") end
                                return ok, message
                            end, "Delete rank", "primary", "Delete this rank? Online holders return to user. Child ranks inherit from this rank's parent.")
                        end, editable(rank) and not protected, "danger"}
                    }
                    local buttons = {}
                    for index, action in ipairs(actions) do
                        buttons[index] = UI.Button(row, action[1], action[2], action[4])
                        buttons[index]:SetEnabled(action[3])
                    end
                    row.PerformLayout = function(_, w, h)
                        local gap = S(8)
                        local width = math.floor((w - S(32) - gap * 3) / 4)
                        for index, button in ipairs(buttons) do
                            button:SetPos(S(16) + (index - 1) * (width + gap), h - S(40))
                            button:SetSize(width, S(28))
                        end
                    end
                end
            end
            blank(scroll, "ranks", count)
        end)
    end
    parent.Refresh()
end

OpenPermissions = function(rankName)
    local dialog = UI.OpenModal(frame, "Rank permissions", rankName .. "  /  changes apply individually", 790, 730)
    local filter, pending = "", {}
    local search = UI.Entry(dialog, "Search permissions or categories...", "", function(value)
        filter = value
        dialog.Rebuild()
    end, true)
    search:Dock(TOP); search:DockMargin(0, 0, 0, S(8))
    UI.Label(dialog, "Allow grants access. Deny blocks it. Inherit uses the parent rank.", 30, C.muted)
    local scroll = UI.Scroll(dialog)
    scroll:Dock(FILL)
    dialog.Rebuild = function()
        rebuildScroll(scroll, function()
            local rank = rankByName[rankName]
            if not rank then UI.Empty(scroll, "Rank no longer exists", "Close this window and refresh the rank list."); return end
            local lastCategory, count = nil, 0
            for _, entry in ipairs(data.permissions) do
                if matches(filter, entry.name, entry.category) then
                    count = count + 1
                    if entry.category ~= lastCategory then
                        lastCategory = entry.category
                        UI.Label(scroll, string.upper(entry.category), 34, C.accentHover, "AXEL.Label")
                    end
                    local row = UI.Panel(scroll)
                    row:Dock(TOP); row:DockMargin(0, 0, 0, S(8)); row:SetTall(S(94))
                    local metadata = AXEL.Permissions[entry.name]
                    row:SetTooltip(metadata and metadata.description or entry.name)
                    row.Paint = function(_, w, h)
                        UI.Box(0, 0, w, h, C.panel)
                        UI.Text(entry.name, "AXEL.Body", S(12), S(22), C.text, w - S(24))
                        local value, source = resolvePermission(rankName, entry.name)
                        local status, color = "No inherited grant", C.muted
                        if inheritsSuper(rankName) then status, color = "Superadmin access is unconditional", C.amber
                        elseif source == "own" then status, color = value and "Allowed on this rank" or "Denied on this rank", value and C.green or C.accentHover
                        elseif source then status = (value and "Allowed" or "Denied") .. " by " .. source end
                        if pending[entry.name] then status, color = "Waiting for server...", C.amber end
                        UI.Text(status, "AXEL.Small", S(12), S(44), color, w - S(24))
                    end
                    local buttons = {}
                    for index, state in ipairs({{"Allow", "allow", true}, {"Deny", "deny", false}, {"Inherit", "clear"}}) do
                        local button = UI.Button(row, state[1], function()
                            local ok, message = run("rankperm", rankName, entry.name, state[2])
                            if ok then pending[entry.name] = true; later("ranks") else tell(message) end
                        end)
                        button.AXELActive = function()
                            local current = rankByName[rankName]
                            return current and current.permissions[entry.name] == state[3]
                        end
                        button.Think = function(self)
                            local current = rankByName[rankName]
                            local canGrant = state[2] ~= "allow" or allowed(entry.name)
                            self:SetEnabled(current ~= nil and editable(current) and canGrant and not pending[entry.name])
                        end
                        buttons[index] = button
                    end
                    row.PerformLayout = function(_, w, h)
                        local gap = S(6)
                        local width = math.floor((w - S(24) - gap * 2) / 3)
                        for index, button in ipairs(buttons) do
                            button:SetPos(S(12) + (index - 1) * (width + gap), h - S(33))
                            button:SetSize(width, S(26))
                        end
                    end
                end
            end
            if count == 0 then UI.Empty(scroll, "No matching permissions", "Try another name or category.") end
        end)
    end
    dialog.RefreshData = function(kind)
        if kind == "ranks" then pending = {}; dialog.Rebuild() end
    end
    dialog.Rebuild()
end
local function BuildLogs(parent)
    local scroll = UI.Scroll(parent)
    scroll:Dock(FILL)
    parent.Refresh = function()
        rebuildScroll(scroll, function()
            if not allowed("viewlogs") then UI.Empty(scroll, "Logs are restricted", "Your rank needs the viewlogs permission."); return end
            local count = 0
            for _, entry in ipairs(data.logs) do
                if matches(filters.logs, entry.admin, entry.action, entry.detail, os.date("%d/%m %H:%M", entry.time)) then
                    count = count + 1
                    local row = UI.Panel(scroll)
                    row:Dock(TOP); row:DockMargin(0, 0, 0, S(8)); row:SetTall(S(92))
                    row:SetTooltip(os.date("%Y-%m-%d %H:%M:%S", entry.time) .. "\n" .. entry.admin .. "\n" .. entry.action .. "\n" .. entry.detail)
                    row.Paint = function(_, w, h)
                        UI.Box(0, 0, w, h, C.panel)
                        UI.Text(string.upper(entry.action), "AXEL.Label", S(14), S(22), C.amber, w - S(164))
                        UI.Text(os.date("%d/%m  %H:%M", entry.time), "AXEL.Small", w - S(14), S(22), C.muted, S(140), TEXT_ALIGN_RIGHT)
                        UI.Text(entry.admin, "AXEL.Body", S(14), S(46), C.text, w - S(28))
                        UI.Text(entry.detail, "AXEL.Small", S(14), S(71), C.muted, w - S(28))
                    end
                end
            end
            blank(scroll, "logs", count)
        end)
    end
    parent.Refresh()
end

local function BuildIntegrations(parent)
    local scroll = UI.Scroll(parent)
    scroll:Dock(FILL)
    parent.Refresh = function()
        rebuildScroll(scroll, function()
            if not allowed("integrations") then
                UI.Empty(scroll, "Integrations restricted", "Grant integrations in Rank permissions."); return
            end
            local count, category = 0, nil
            for _, command in ipairs(data.integrations) do
                if matches(filters.integrations, command.name, command.source, command.description) then
                    count = count + 1
                    if category ~= command.source then category = command.source; UI.Label(scroll, string.upper(category), 34, C.accentHover, "AXEL.Label") end
                    local button = UI.Button(scroll, command.name, function()
                        form(command.name, command.source, {
                            {key="args", label="ARGUMENTS", placeholder="Arguments only; leave empty for no arguments"}
                        }, function(values)
                            local args, err = AXEL.ParseIntegrationArguments(values.args)
                            if not args then return false, err end
                            net.Start("AXEL.IntegrationRun"); net.WriteString(command.id); net.WriteString(values.args); net.SendToServer()
                            tell("Dispatched to source addon; check its feedback.")
                            return true
                        end, "Run command", "primary", command.description)
                    end)
                    button:Dock(TOP); button:SetTall(S(40)); button:DockMargin(0,0,0,S(6))
                    button:SetTooltip(command.description)
                end
            end
            if count == 0 then UI.Empty(scroll, "No integrations listed", "Refresh to discover installed server commands, or clear the search.") end
        end)
    end
    parent.Refresh()
end

local function BuildOverview(parent)
    local scroll = UI.Scroll(parent)
    scroll:Dock(FILL)

    parent.Refresh = function()
        rebuildScroll(scroll, function()
            local welcome = UI.Panel(scroll)
            welcome:Dock(TOP); welcome:SetTall(S(68)); welcome:DockMargin(0, 0, 0, S(12))
            welcome.Paint = function(_, w, h)
                UI.Box(0, 0, w, h, C.sidebar, C.accentSoft)
                draw.RoundedBox(S(2), 0, 0, S(5), h, C.accent)
                UI.Text("COMMAND OVERVIEW", "AXEL.Label", S(20), S(21), C.accentHover, w - S(40))
                UI.Text("AXEL Administration", "AXEL.Heading", S(20), S(48), C.text, w - S(40))
            end

            UI.Section(scroll, "Server status")
            local stats = UI.Panel(scroll)
            stats:Dock(TOP); stats:SetTall(S(104)); stats:DockMargin(0, 0, 0, S(12))
            local cards = {
                UI.StatCard(stats, "Players", function() return tostring(#data.players) end, "currently online", "players"),
                UI.StatCard(stats, "Ranks", function() return tostring(#data.ranks) end, "staff groups", "ranks"),
                UI.StatCard(stats, "Bans", function() return tostring(#data.bans) end, "active records", "bans"),
                UI.StatCard(stats, "Activity", function() return tostring(#data.logs) end, "recent actions", "logs")
            }
            stats.PerformLayout = function(_, w, h)
                local gap, cardWidth = S(10), math.floor((w - S(30)) / 4)
                for index, card in ipairs(cards) do
                    card:SetPos((index - 1) * (cardWidth + gap), 0)
                    card:SetSize(index == 4 and w - (index - 1) * (cardWidth + gap) or cardWidth, h)
                end
            end

            UI.Section(scroll, "Quick access")
            local quick = UI.Panel(scroll)
            quick:Dock(TOP); quick:SetTall(S(48)); quick:DockMargin(0, 0, 0, S(12))
            local quickButtons = {
                UI.Button(quick, "Manage players", function() SelectTab("players") end, "primary", "players"),
                UI.Button(quick, "Run commands", function() SelectTab("commands") end, nil, "commands"),
                UI.Button(quick, "Manage ranks", function() SelectTab("ranks") end, nil, "ranks")
            }
            quick.PerformLayout = function(_, w, h)
                local gap, buttonWidth = S(10), math.floor((w - S(20)) / 3)
                for index, button in ipairs(quickButtons) do
                    button:SetPos((index - 1) * (buttonWidth + gap), 0)
                    button:SetSize(index == 3 and w - (index - 1) * (buttonWidth + gap) or buttonWidth, h)
                end
            end

            UI.Section(scroll, "Recent activity")
            if not allowed("viewlogs") then
                UI.Empty(scroll, "Activity is restricted", "Your rank needs the viewlogs permission.")
            elseif #data.logs == 0 then
                UI.Empty(scroll, "No activity recorded", "Staff actions will appear here.")
            else
                for index = 1, math.min(#data.logs, 4) do
                    local entry = data.logs[index]
                    local row = UI.Panel(scroll)
                    row:Dock(TOP); row:SetTall(S(58)); row:DockMargin(0, 0, 0, S(7))
                    row.Paint = function(_, w, h)
                        UI.Box(0, 0, w, h, C.panel)
                        UI.Text(string.upper(entry.action), "AXEL.Label", S(14), S(18), C.amber, w - S(170))
                        UI.Text(os.date("%d/%m  %H:%M", entry.time), "AXEL.Small", w - S(14), S(18), C.faint, S(145), TEXT_ALIGN_RIGHT)
                        UI.Text(entry.admin .. "  /  " .. entry.detail, "AXEL.Small", S(14), S(41), C.muted, w - S(28))
                    end
                end
            end
        end)
    end
    parent.Refresh()
end
net.Receive("AXEL.IntegrationList", function()
    local offset, more, count = net.ReadUInt(16), net.ReadBool(), net.ReadUInt(8)
    if offset == 0 then data.integrations = {} end
    for i = 1, count do
        data.integrations[offset+i] = {id=net.ReadString(), name=net.ReadString(), source=net.ReadString(), description=net.ReadString()}
    end
    loaded.integrations, updated.integrations = true, os.time()
    if more then
        net.Start("AXEL.IntegrationRequest"); net.WriteUInt(offset+count,16); net.SendToServer()
    else Refresh("integrations") end
end)

local tabs = {
    {kind = "overview", name = "Overview", group = "COMMAND CENTRE", subtitle = "", build = BuildOverview},
    {kind = "players", name = "Players", group = "MODERATION", subtitle = "", build = BuildPlayers},
    {kind = "commands", name = "Commands", group = "MODERATION", subtitle = "", build = BuildCommands},
    {kind = "bans", name = "Bans", group = "MODERATION", subtitle = "", build = BuildBans},
    {kind = "ranks", name = "Ranks", group = "ADMINISTRATION", subtitle = "", build = BuildRanks},
    {kind = "logs", name = "Activity logs", group = "ADMINISTRATION", subtitle = "", build = BuildLogs},
    {kind = "integrations", name = "Integrations", group = "ADMINISTRATION", subtitle = "", build = BuildIntegrations}
}
local tabByKind = {}
for _, tab in ipairs(tabs) do tabByKind[tab.kind] = tab end
Refresh = function(kind)
    if not IsValid(frame) then return end
    if IsValid(frame.content) and frame.content.Refresh and
        (not kind or kind == activeTab or kind == "ranks" or activeTab == "overview") then
        frame.content.Refresh()
    end
    if IsValid(UI.Modal) and UI.Modal.RefreshData then UI.Modal.RefreshData(kind) end
end
SelectTab = function(kind)
    if not IsValid(frame) then return end
    activeTab = kind
    frame.content:Clear()
    frame.content.Refresh = nil
    frame.SearchEntry:SetText(filters[kind])
    frame.SearchShell:SetVisible(kind ~= "overview")
    tabByKind[kind].build(frame.content)
    request(kind)
end
function AXEL.BuildMenu()
    UI.CloseModal()
    if IsValid(frame) then frame:Remove() end
    frame = UI.Window("AXEL", "CENTRAL ADMINISTRATION TERMINAL", 1320, 860)
    UI.Frame = frame
    frame.OnRemove = function(self)
        self.AXELClosing = true
        UI.CloseModal()
        if UI.Frame == self then UI.Frame = nil end
    end
    local width, height = frame:GetWide(), frame:GetTall()
    local compact = width < S(1030)
    local navWidth = compact and 0 or S(198)
    local nav = UI.Panel(frame)
    if compact then nav:SetPos(S(20), S(90)); nav:SetSize(width - S(40), S(88))
    else nav:SetPos(S(12), S(90)); nav:SetSize(navWidth, height - S(106)) end
    nav.Paint = function(_, w, h)
        if compact then return end
        UI.Box(0, 0, w, h, C.sidebar)
        UI.Text("WORKSPACE", "AXEL.Label", S(16), S(27), C.faint, w - S(32))
        UI.Icon("shield", S(16), h - S(109), S(24), C.accent)
        UI.Text("STAFF SESSION", "AXEL.Label", S(16), h - S(67), C.faint, w - S(32))
        UI.Text(localRank(), "AXEL.Body", S(16), h - S(40), C.text, w - S(32))
    end
    local navY, lastGroup = S(46), nil
    for index, tab in ipairs(tabs) do
        if not compact and tab.group ~= lastGroup then
            lastGroup = tab.group
            local groupLabel = UI.Label(nav, tab.group, 26, C.faint, "AXEL.Label")
            groupLabel:Dock(NODOCK)
            groupLabel:SetPos(S(14), navY); groupLabel:SetSize(nav:GetWide() - S(28), S(26))
            navY = navY + S(27)
        end
        local button = UI.Button(nav, tab.name, function() SelectTab(tab.kind) end)
        if compact then
            local tabWidth = math.floor((nav:GetWide() - S(8) * 3) / 4)
            button:SetPos(((index - 1) % 4) * (tabWidth + S(8)), math.floor((index - 1) / 4) * S(46)); button:SetSize(tabWidth, S(40))
        else
            button:SetPos(S(10), navY); button:SetSize(nav:GetWide() - S(20), S(40))
            navY = navY + S(44)
        end
        button.Paint = function(self, w, h)
            local active = activeTab == tab.kind
            if active or self:IsHovered() then UI.Box(0, 0, w, h, active and C.accentSoft or C.hover, active and C.accentSoft or C.border) end
            if active then draw.RoundedBox(S(1), 0, S(10), S(3), h - S(20), C.accent) end
            if not compact then UI.Icon(tab.kind, S(12), (h - S(18)) / 2, S(18), active and C.accentHover or C.muted) end
            UI.Text(tab.name, "AXEL.Button", compact and w / 2 or S(42), h / 2, active and C.text or C.muted,
                w - (compact and S(16) or S(48)), compact and TEXT_ALIGN_CENTER or TEXT_ALIGN_LEFT)
        end
    end
    local x = compact and S(20) or navWidth + S(30)
    local y = compact and S(196) or S(104)
    local mainWidth = width - x - S(24)
    local heading = UI.Panel(frame)
    heading:SetPos(x, y); heading:SetSize(mainWidth, S(62))
    -- On a narrow window the theme button drops its caption rather than
    -- squeezing the tab title down to an ellipsis.
    local narrow = mainWidth < S(300)
    local themeWidth = narrow and S(44) or S(126)
    local titleRoom = S(112) + S(8) + themeWidth + S(16)
    heading.Paint = function(_, w, h)
        local tab = tabByKind[activeTab]
        UI.Text(tab.name, "AXEL.Title", 0, S(16), C.text, math.max(S(60), w - titleRoom))
        if tab.subtitle ~= "" then UI.Text(tab.subtitle, "AXEL.Small", 0, S(46), C.muted, w) end
    end
    local refresh = UI.Button(heading, "Refresh", function()
        request(activeTab)
        if activeTab ~= "ranks" then request("ranks") end
        tell("Requested the latest records.")
    end, nil, "refresh")
    refresh:SetPos(mainWidth - S(112), 0); refresh:SetSize(S(112), S(34))
    local theme = UI.Button(heading, narrow and "" or function()
        local active = AXEL.GetTheme(UI.ActiveTheme)
        return active and active.name or "Theme"
    end, function() UI.OpenThemePicker(frame) end, nil, "theme")
    theme:SetPos(mainWidth - S(112) - S(8) - themeWidth, 0)
    theme:SetSize(themeWidth, S(34))
    theme:SetTooltip("Change how this menu looks.")
    if narrow then
        theme.Paint = function(self, w, h)
            UI.Box(0, 0, w, h, self:IsHovered() and C.hover or C.raised)
            UI.Icon("theme", (w - S(18)) / 2, (h - S(18)) / 2, S(18),
                self:IsHovered() and C.text or C.muted)
        end
    end
    local search, entry = UI.Entry(frame, "Search names, SteamIDs or keywords...", filters[activeTab], function(value)
        filters[activeTab] = value
        Refresh()
    end, true)
    search:SetPos(x, y + S(70)); search:SetSize(mainWidth, S(40))
    frame.SearchShell = search
    frame.SearchEntry = entry
    local content = UI.Panel(frame)
    content:SetPos(x, y + S(126))
    content:SetSize(mainWidth, math.max(S(100), height - y - S(172)))
    frame.content = content
    local footer = UI.Panel(frame)
    footer:SetPos(x, height - S(34)); footer:SetSize(mainWidth, S(24))
    footer.Paint = function(_, w, h)
        local stamp = updated[activeTab]
        local records = data[activeTab]
        local count = istable(records) and #records or 0
        local text = count .. (activeTab == "players" and " online" or " records")
        if activeTab == "overview" then text = "Command centre ready"
        elseif activeTab == "logs" and not allowed("viewlogs") then text = "Restricted"
        elseif not loaded[activeTab] then text = "Waiting for data"
        elseif activeTab == "logs" then text = "Latest " .. #data.logs .. " actions (up to 150)"
        elseif activeTab == "bans" then text = #data.bans .. " bans received (up to 200)" end
        local message = noticeUntil > RealTime() and notice or (stamp and "Updated " .. os.date("%H:%M:%S", stamp) or "")
        UI.Text(text, "AXEL.Small", 0, h / 2, C.faint, w * .47)
        UI.Text(message, "AXEL.Small", w, h / 2, C.muted, w * .51, TEXT_ALIGN_RIGHT)
    end
    search:SetVisible(activeTab ~= "overview")
    tabByKind[activeTab].build(content)
    for _, tab in ipairs(tabs) do request(tab.kind) end
end
local function received(kind)
    loaded[kind], updated[kind] = true, os.time()
    Refresh(kind)
end
net.Receive("AXEL.OpenMenu", function() AXEL.BuildMenu() end)
net.Receive("AXEL.SendPlayers", function()
    data.players = {}
    for _ = 1, net.ReadUInt(8) do
        local entity = net.ReadEntity()
        data.players[#data.players + 1] = {
            entity = entity, name = net.ReadString(), steamid = net.ReadString(),
            rank = net.ReadString(), immunity = net.ReadUInt(8), playtime = net.ReadUInt(32)
        }
    end
    received("players")
end)
net.Receive("AXEL.SendBans", function()
    data.bans = {}
    for _ = 1, net.ReadUInt(8) do
        data.bans[#data.bans + 1] = {
            steamid = net.ReadString(), name = net.ReadString(), reason = net.ReadString(),
            admin = net.ReadString(), expires = net.ReadUInt(32)
        }
    end
    received("bans")
end)
net.Receive("AXEL.SendRanks", function()
    data.ranks, rankByName = {}, {}
    for _ = 1, net.ReadUInt(8) do
        local rank = {name = net.ReadString(), inherit = net.ReadString(), immunity = net.ReadUInt(8), permissions = {}}
        for _ = 1, net.ReadUInt(8) do
            local permission = net.ReadString()
            rank.permissions[permission] = net.ReadBool()
        end
        data.ranks[#data.ranks + 1] = rank
        rankByName[rank.name] = rank
    end
    data.permissions = {}
    for _ = 1, net.ReadUInt(8) do
        data.permissions[#data.permissions + 1] = {name = net.ReadString(), category = net.ReadString()}
    end
    received("ranks")
end)
net.Receive("AXEL.SendLogs", function()
    data.logs = {}
    for _ = 1, net.ReadUInt(8) do
        data.logs[#data.logs + 1] = {
            time = net.ReadUInt(32), admin = net.ReadString(), action = net.ReadString(), detail = net.ReadString()
        }
    end
    received("logs")
end)
local function rebuildForScale()
    UI.CreateFonts()
    UI.CloseModal()
    if IsValid(frame) then AXEL.BuildMenu() end
end
hook.Add("OnScreenSizeChanged", "AXEL.RebuildFonts", rebuildForScale)
cvars.AddChangeCallback("axel_admin_scale", rebuildForScale, "AXEL.ScaleChanged")


-- Branded shortcut; the existing gateway retains all permission checks.
concommand.Add("axel_admin", function() run("menu") end)

concommand.Add("axel_menu", function() run("menu") end)
