--[[
    Axel Admin Menu - command execution

    Every route into a command lands here: chat (!kick), console (axel kick) and
    the menu. Permission and immunity are checked in this one place so the menu
    cannot become a way around them.

    Targeting:
        Name       partial, case-insensitive, must be unambiguous
        STEAM_...  exact
        ^          yourself
        @          whoever you are looking at
        *          everyone
        #rank      everyone holding that rank
]]

function AXEL.DescribeTargets(targets)
    if (#targets == 1) then return targets[1]:Nick() end
    return #targets .. " players"
end

--[[
    Resolves a target string to a list of players.
    Returns list, error. An empty list always comes with an error.
]]
function AXEL.FindTargets(actor, input, allowMultiple)
    input = string.Trim(tostring(input or ""))
    if (input == "") then return {}, "No target given." end

    local all = player.GetAll()

    if (input == "^") then
        if (not IsValid(actor)) then return {}, "Console is not a player." end
        return {actor}, nil
    end

    if (input == "@") then
        if (not IsValid(actor)) then return {}, "Console cannot look at anyone." end

        local trace = actor:GetEyeTrace()
        local entity = trace.Entity

        if (not IsValid(entity) or not entity:IsPlayer()) then
            return {}, "You are not looking at a player."
        end

        return {entity}, nil
    end

    if (input == "*") then
        if (not allowMultiple) then return {}, "That command takes a single target." end
        return all, nil
    end

    if (string.sub(input, 1, 1) == "#") then
        if (not allowMultiple) then return {}, "That command takes a single target." end

        local rank = string.lower(string.sub(input, 2))
        local matches = {}

        for _, client in ipairs(all) do
            if (client:GetUserGroup() == rank) then matches[#matches + 1] = client end
        end

        if (#matches == 0) then return {}, "No players with rank '" .. rank .. "'." end
        return matches, nil
    end

    if (AXEL.IsSteamID(input)) then
        for _, client in ipairs(all) do
            if (client:SteamID() == input) then return {client}, nil end
        end
        return {}, "That SteamID is not connected."
    end

    -- Name matching: exact wins outright, otherwise partial must be unique.
    local needle = string.lower(input)
    local partial = {}

    for _, client in ipairs(all) do
        local nick = string.lower(client:Nick())
        if (nick == needle) then return {client}, nil end
        if (string.find(nick, needle, 1, true)) then partial[#partial + 1] = client end
    end

    if (#partial == 0) then return {}, "No player matching '" .. input .. "'." end

    if (#partial > 1 and not allowMultiple) then
        local names = {}
        for _, client in ipairs(partial) do names[#names + 1] = client:Nick() end
        return {}, "'" .. input .. "' matches several players: " .. table.concat(names, ", ")
    end

    return partial, nil
end

--[[
    Filters a target list by immunity, returning the allowed ones and a note
    about any that were blocked. Blocking silently would look like a bug.
]]
local function filterByImmunity(actor, targets, command)
    if (not IsValid(actor)) then return targets, nil end

    local allowed, blocked = {}, {}

    for _, target in ipairs(targets) do
        if (target == actor) then
            if (command.targetSelf) then
                allowed[#allowed + 1] = target
            else
                blocked[#blocked + 1] = target:Nick()
            end
        elseif (AXEL.CanTarget(actor:GetUserGroup(), target:GetUserGroup(), command.equalRank)) then
            allowed[#allowed + 1] = target
        else
            blocked[#blocked + 1] = target:Nick()
        end
    end

    local note
    if (#blocked > 0) then
        note = "Outranked by: " .. table.concat(blocked, ", ")
    end

    return allowed, note
end

--[[
    Parses raw arguments against a command's signature.
    Returns a list ready to unpack into OnRun, or nil plus an error.
]]
local function parseArguments(actor, command, args)
    local parsed = {}

    for index, kind in ipairs(command.arguments) do
        local raw = args[index]

        if (kind == "player" or kind == "players") then
            local targets, err = AXEL.FindTargets(actor, raw, kind == "players")
            if (err) then return nil, err end

            local allowed, note = filterByImmunity(actor, targets, command)
            if (#allowed == 0) then
                return nil, note or "You cannot target that player."
            end

            parsed[index] = (kind == "player") and allowed[1] or allowed

            -- Store a return position before anything moves them.
            if (command.name == "bring") then
                for _, target in ipairs(kind == "player" and {allowed[1]} or allowed) do
                    target.AXELReturnPos = target:GetPos()
                end
            end

        elseif (kind == "number") then
            local value = tonumber(raw)
            if (not value or value ~= value or value == math.huge or value == -math.huge) then return nil, "Expected a finite number." end
            parsed[index] = value

        elseif (kind == "duration") then
            -- Optional: a missing duration means permanent.
            if (raw == nil or raw == "") then
                parsed[index] = 0
            else
                local seconds = AXEL.ParseDuration(raw)
                if (not seconds) then
                    return nil, "Bad duration. Use 30m, 2h, 7d, or 0 for permanent."
                end
                parsed[index] = seconds
            end

        elseif (kind == "text") then
            -- Everything from here on, spaces included.
            local rest = {}
            for i = index, #args do rest[#rest + 1] = args[i] end
            parsed[index] = table.concat(rest, " ")
            break

        else -- string
            parsed[index] = tostring(raw or "")
        end
    end

    return parsed
end

--[[
    The single entry point. actor may be nil for console.
    Returns success, message.
]]
function AXEL.RunCommand(actor, name, args)
    local command = AXEL.GetCommand(name)
    if (not command) then return false, "Unknown command '" .. tostring(name) .. "'." end

    if (IsValid(actor) and not actor:AXELHasPermission(command.permission)) then
        return false, "You do not have permission to use that."
    end

    local parsed, err = parseArguments(actor, command, args or {})
    if (not parsed) then return false, err end

    local ok, success, message = pcall(command.OnRun, actor, unpack(parsed, 1, #command.arguments))

    if (not ok) then
        ErrorNoHalt("[Axel] Command '" .. command.name .. "' failed: " ..
            tostring(success) .. "\n")
        return false, "That command errored. Check the server console."
    end

    if (success and command.name ~= "menu") then
        AXEL.Log(
            IsValid(actor) and actor:SteamID() or "CONSOLE",
            IsValid(actor) and actor:Nick() or "Console",
            command.name,
            tostring(args and args[1] or ""),
            tostring(message or ""))
    end

    return success, message
end

--- Broadcasts the result the way admin mods conventionally do.
function AXEL.Announce(actor, message)
    if (not message or message == "") then return end

    local from = IsValid(actor) and actor:Nick() or "Console"

    for _, client in ipairs(player.GetAll()) do
        client:ChatPrint("[Axel] " .. from .. ": " .. message)
    end

    MsgC(Color(218, 177, 83), "[Axel] ", Color(210, 213, 218),
        from .. ": " .. message .. "\n")
end

--[[ ------------------------------------------------------------------------
    Chat and console routing
--------------------------------------------------------------------------- ]]

local PREFIXES = {["!"] = true, ["/"] = true}

--[[
    Splits a chat command into tokens, skipping empty ones.

    string.Explode preserves empty fields, so "!kick  bob" - a double space,
    which people type constantly after deleting and retyping a word - came out
    as {"", "bob"}. The target then resolved to "" and the command answered
    "No target given." for a line that looks perfectly correct in chat.
    Trailing spaces did the same thing to text arguments.

    %S+ also covers tabs, which a pasted command can carry.
]]
local function tokenise(text)
    local out = {}
    for token in string.gmatch(text, "%S+") do out[#out + 1] = token end
    return out
end

hook.Add("PlayerSay", "AXEL.ChatCommands", function(client, text)
    -- Gag is enforced here so it covers every chat route at once.
    if (client.AXELGagged) then
        client:ChatPrint("[Axel] You are gagged.")
        return ""
    end

    local prefix = string.sub(text, 1, 1)
    if (not PREFIXES[prefix]) then return end

    local args = tokenise(string.sub(text, 2))
    local name = table.remove(args, 1)
    if (not name or name == "") then return end

    -- Not one of ours: leave it for Helix and anything else listening.
    if (not AXEL.GetCommand(name)) then return end

    local success, message = AXEL.RunCommand(client, name, args)

    if (success) then
        AXEL.Announce(client, message)
    elseif (message) then
        client:ChatPrint("[Axel] " .. message)
    end

    --[[
        Suppress the original line so "!ban bob 2h cheating" is not echoed to
        public chat, reason and all.

        A static analyser will report this as an unconditional return in a hook.
        It is not: the three guard clauses above return early for anything that
        is not one of our commands, so reaching this line already means the
        message was a command and has been executed. Returning nil here would
        broadcast every admin command verbatim.
    ]]
    if (AXEL.GetCommand(name)) then return "" end
end)

hook.Add("PlayerCanHearPlayersVoice", "AXEL.Mute", function(listener, talker)
    if (talker.AXELMuted) then return false end
end)

concommand.Add("axel", function(client, _, args)
    local name = table.remove(args, 1)

    if (not name) then
        print("[Axel] Usage: axel <command> [arguments]")
        return
    end

    local actor = IsValid(client) and client or nil
    local success, message = AXEL.RunCommand(actor, name, args)

    if (success) then
        AXEL.Announce(actor, message)
    elseif (message) then
        if (IsValid(client)) then
            client:ChatPrint("[Axel] " .. message)
        else
            print("[Axel] " .. message)
        end
    end
end)
