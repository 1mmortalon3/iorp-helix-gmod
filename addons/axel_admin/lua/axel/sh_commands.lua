--[[
    Axel Admin Menu - command registry

    Shared, so the menu builds its buttons from the same table the server
    enforces against. A command that exists in the menu but not on the server
    is impossible by construction.

    Argument types:
        player   - a live player, resolved by the targeting rules in sv_commands
        players  - same, but may match several (@, *, ^, #rank)
        string   - a single word
        text     - everything remaining, spaces included
        number   - a number
        duration - "30m", "2h", "7d", "0"/"perma" -> seconds
]]

AXEL = AXEL or {}
AXEL.Commands = AXEL.Commands or {}
AXEL.CommandOrder = AXEL.CommandOrder or {}

--- Every permission the mod knows about, for the rank editor.
AXEL.Permissions = AXEL.Permissions or {}

function AXEL.RegisterPermission(name, description, category)
    name = string.lower(string.Trim(tostring(name)))
    if (name == "") then return end

    AXEL.Permissions[name] = {
        name = name,
        description = description or name,
        category = category or "General"
    }
end

function AXEL.RegisterCommand(name, data)
    name = string.lower(string.Trim(tostring(name)))
    if (name == "" or not data) then return end

    data.name = name
    data.arguments = data.arguments or {}
    data.description = data.description or ""
    data.category = data.category or "General"
    data.permission = data.permission or name

    -- targetSelf: may the actor run this on themselves?
    if (data.targetSelf == nil) then data.targetSelf = true end
    -- equalRank: may the actor target someone of identical immunity?
    if (data.equalRank == nil) then data.equalRank = false end

    AXEL.Commands[name] = data
    AXEL.CommandOrder[#AXEL.CommandOrder + 1] = name

    AXEL.RegisterPermission(data.permission, data.description, data.category)

    if (data.aliases) then
        for _, alias in ipairs(data.aliases) do
            AXEL.Commands[string.lower(alias)] = data
        end
    end
end

function AXEL.GetCommand(name)
    if (not name) then return nil end
    return AXEL.Commands[string.lower(string.Trim(tostring(name)))]
end

function AXEL.GetCommandList()
    local out = {}
    local seen = {}

    for _, name in ipairs(AXEL.CommandOrder) do
        local command = AXEL.Commands[name]
        if (command and not seen[command]) then
            seen[command] = true
            out[#out + 1] = command
        end
    end

    table.sort(out, function(a, b)
        if (a.category ~= b.category) then return a.category < b.category end
        return a.name < b.name
    end)

    return out
end

--[[ ------------------------------------------------------------------------
    Definitions

    OnRun is server-only; the client loads this file purely for the metadata.
--------------------------------------------------------------------------- ]]

AXEL.RegisterCommand("menu", {
    description = "Open the administration menu.",
    category = "General",
    arguments = {},
    OnRun = function(actor)
        if (not IsValid(actor)) then return false, "Console cannot open the menu." end
        AXEL.OpenMenu(actor)
        return true
    end
})

AXEL.RegisterCommand("kick", {
    description = "Kick a player from the server.",
    category = "Moderation",
    arguments = {"player", "text"},
    OnRun = function(actor, target, reason)
        reason = reason ~= "" and reason or "No reason given"
        target:Kick("[Axel] Kicked: " .. reason)
        return true, string.format("%s kicked: %s", target:Nick(), reason)
    end
})

AXEL.RegisterCommand("ban", {
    description = "Ban a player. Duration 0 is permanent.",
    category = "Moderation",
    arguments = {"player", "duration", "text"},
    OnRun = function(actor, target, duration, reason)
        return AXEL.Ban(target, duration, reason, actor)
    end
})

AXEL.RegisterCommand("banid", {
    description = "Ban a SteamID that is not currently connected.",
    category = "Moderation",
    permission = "ban",
    arguments = {"string", "duration", "text"},
    OnRun = function(actor, steamid, duration, reason)
        return AXEL.Ban(steamid, duration, reason, actor)
    end
})

AXEL.RegisterCommand("unban", {
    description = "Lift a ban by SteamID.",
    category = "Moderation",
    arguments = {"string"},
    OnRun = function(actor, steamid)
        return AXEL.Unban(steamid, actor)
    end
})

AXEL.RegisterCommand("freeze", {
    description = "Freeze a player in place.",
    category = "Moderation",
    arguments = {"players"},
    OnRun = function(actor, targets)
        for _, target in ipairs(targets) do target:Freeze(true) end
        return true, AXEL.DescribeTargets(targets) .. " frozen."
    end
})

AXEL.RegisterCommand("unfreeze", {
    description = "Unfreeze a player.",
    category = "Moderation",
    permission = "freeze",
    arguments = {"players"},
    OnRun = function(actor, targets)
        for _, target in ipairs(targets) do target:Freeze(false) end
        return true, AXEL.DescribeTargets(targets) .. " unfrozen."
    end
})

AXEL.RegisterCommand("slay", {
    description = "Kill a player.",
    category = "Moderation",
    arguments = {"players"},
    OnRun = function(actor, targets)
        for _, target in ipairs(targets) do target:Kill() end
        return true, AXEL.DescribeTargets(targets) .. " slain."
    end
})

AXEL.RegisterCommand("respawn", {
    description = "Respawn a player.",
    category = "Moderation",
    permission = "slay",
    arguments = {"players"},
    OnRun = function(actor, targets)
        for _, target in ipairs(targets) do target:Spawn() end
        return true, AXEL.DescribeTargets(targets) .. " respawned."
    end
})

AXEL.RegisterCommand("bring", {
    description = "Teleport a player to you.",
    category = "Teleport",
    arguments = {"players"},
    OnRun = function(actor, targets)
        if (not IsValid(actor)) then return false, "Console has no position." end

        for _, target in ipairs(targets) do
            target:SetPos(actor:GetPos() + actor:GetAimVector() * 64)
        end

        return true, AXEL.DescribeTargets(targets) .. " brought to you."
    end
})

AXEL.RegisterCommand("goto", {
    description = "Teleport yourself to a player.",
    category = "Teleport",
    permission = "goto_player",
    arguments = {"player"},
    OnRun = function(actor, target)
        if (not IsValid(actor)) then return false, "Console cannot teleport." end

        actor:SetPos(target:GetPos() + target:GetAimVector() * -64)
        return true, "Teleported to " .. target:Nick() .. "."
    end
})

AXEL.RegisterCommand("return", {
    description = "Return a player to where they were before being brought.",
    category = "Teleport",
    permission = "teleport",
    arguments = {"players"},
    OnRun = function(actor, targets)
        local returned = 0

        for _, target in ipairs(targets) do
            if (target.AXELReturnPos) then
                target:SetPos(target.AXELReturnPos)
                target.AXELReturnPos = nil
                returned = returned + 1
            end
        end

        if (returned == 0) then return false, "No stored position for that player." end
        return true, AXEL.DescribeTargets(targets) .. " returned."
    end
})

AXEL.RegisterCommand("god", {
    description = "Toggle godmode on a player.",
    category = "Player",
    arguments = {"players"},
    OnRun = function(actor, targets)
        for _, target in ipairs(targets) do
            if (target:HasGodMode()) then target:GodDisable() else target:GodEnable() end
        end
        return true, "Godmode toggled for " .. AXEL.DescribeTargets(targets) .. "."
    end
})

AXEL.RegisterCommand("hp", {
    description = "Set a player's health.",
    category = "Player",
    arguments = {"players", "number"},
    OnRun = function(actor, targets, amount)
        amount = math.Clamp(math.floor(amount or 100), 1, 100000)
        for _, target in ipairs(targets) do target:SetHealth(amount) end
        return true, AXEL.DescribeTargets(targets) .. " health set to " .. amount .. "."
    end
})

AXEL.RegisterCommand("armor", {
    description = "Set a player's armour.",
    category = "Player",
    arguments = {"players", "number"},
    OnRun = function(actor, targets, amount)
        amount = math.Clamp(math.floor(amount or 0), 0, 100000)
        for _, target in ipairs(targets) do target:SetArmor(amount) end
        return true, AXEL.DescribeTargets(targets) .. " armour set to " .. amount .. "."
    end
})

AXEL.RegisterCommand("setrank", {
    description = "Set a player's rank. Duration is optional.",
    category = "Ranks",
    arguments = {"player", "string", "duration"},
    OnRun = function(actor, target, rank, duration)
        -- Nobody may grant a rank at or above their own immunity, or staff
        -- could promote themselves past their supervisors.
        if (IsValid(actor) and not actor:IsSuperAdmin()) then
            if (AXEL.GetImmunity(rank) >= actor:AXELImmunity()) then
                return false, "You cannot grant a rank at or above your own."
            end
        end

        return AXEL.SetRank(target, rank, duration, actor)
    end
})

AXEL.RegisterCommand("mute", {
    description = "Block a player's voice chat.",
    category = "Moderation",
    arguments = {"players"},
    OnRun = function(actor, targets)
        for _, target in ipairs(targets) do target.AXELMuted = true end
        return true, AXEL.DescribeTargets(targets) .. " muted."
    end
})

AXEL.RegisterCommand("unmute", {
    description = "Restore a player's voice chat.",
    category = "Moderation",
    permission = "mute",
    arguments = {"players"},
    OnRun = function(actor, targets)
        for _, target in ipairs(targets) do target.AXELMuted = nil end
        return true, AXEL.DescribeTargets(targets) .. " unmuted."
    end
})

AXEL.RegisterCommand("gag", {
    description = "Block a player's text chat.",
    category = "Moderation",
    arguments = {"players"},
    OnRun = function(actor, targets)
        for _, target in ipairs(targets) do target.AXELGagged = true end
        return true, AXEL.DescribeTargets(targets) .. " gagged."
    end
})

AXEL.RegisterCommand("ungag", {
    description = "Restore a player's text chat.",
    category = "Moderation",
    permission = "gag",
    arguments = {"players"},
    OnRun = function(actor, targets)
        for _, target in ipairs(targets) do target.AXELGagged = nil end
        return true, AXEL.DescribeTargets(targets) .. " ungagged."
    end
})

AXEL.RegisterCommand("noclip", {
    description = "Toggle noclip on a player.",
    category = "Player",
    arguments = {"players"},
    OnRun = function(actor, targets)
        for _, target in ipairs(targets) do
            target:SetMoveType(target:GetMoveType() == MOVETYPE_NOCLIP
                and MOVETYPE_WALK or MOVETYPE_NOCLIP)
        end
        return true, "Noclip toggled for " .. AXEL.DescribeTargets(targets) .. "."
    end
})

AXEL.RegisterCommand("asay", {
    description = "Message all online staff.",
    category = "General",
    permission = "asay",
    arguments = {"text"},
    OnRun = function(actor, message)
        if (message == "") then return false, "Say what?" end

        local from = IsValid(actor) and actor:Nick() or "Console"

        for _, client in ipairs(player.GetAll()) do
            if (client:AXELHasPermission("asay")) then
                client:ChatPrint("[Staff] " .. from .. ": " .. message)
            end
        end

        return true
    end
})

-- Permissions with no command of their own.
AXEL.RegisterPermission("viewlogs", "View the staff action log", "General")
AXEL.RegisterPermission("manageranks", "Create, edit and delete ranks", "Ranks")
AXEL.RegisterPermission("spectate", "Spectate players", "Moderation")
AXEL.RegisterPermission("cleanup", "Clean up props and decals", "Player")
AXEL.RegisterPermission("setmodel", "Change a player's model", "Player")

--[[ ------------------------------------------------------------------------
    Rank management

    All gated on "manageranks". The recurring guard is that nobody may create,
    edit or delete a rank at or above their own immunity - without it, an admin
    could mint a rank above their supervisors and assign it to themselves.
    superadmin is exempt.
--------------------------------------------------------------------------- ]]

--- Rank names become SQL keys and console arguments, so keep them boring.
function AXEL.ValidateRankName(name)
    name = string.lower(string.Trim(tostring(name or "")))

    if (name == "") then return nil, "Rank name cannot be empty." end
    if (#name > 32) then return nil, "Rank name is too long (32 characters max)." end
    if (name == "__migrated__") then return nil, "That name is reserved." end

    if (string.match(name, "[^%a%d_+%-]")) then
        return nil, "Use letters, digits, underscore, plus or hyphen only - no spaces."
    end

    return name
end

--- sv_cami.lua returns early when CAMI is missing, so this may not exist.
local function resyncCAMI()
    if (isfunction(AXEL.SyncCAMIUsergroups)) then
        pcall(AXEL.SyncCAMIUsergroups)
    end
end

--- Shared guard for every mutating rank command.
local function canEditRank(actor, immunity, what)
    if (not IsValid(actor)) then return true end          -- console
    if (actor:IsSuperAdmin()) then return true end

    if (not actor:AXELHasPermission("manageranks")) then
        return false, "You do not have permission to manage ranks."
    end

    if (immunity >= actor:AXELImmunity()) then
        return false, string.format(
            "You cannot %s a rank at or above your own immunity (%d).",
            what, actor:AXELImmunity())
    end

    return true
end

AXEL.RegisterCommand("addrank", {
    description = "Create a rank.",
    category = "Ranks",
    permission = "manageranks",
    arguments = {"string", "number", "string"},
    OnRun = function(actor, name, immunity, inherit)
        local clean, err = AXEL.ValidateRankName(name)
        if (not clean) then return false, err end

        if (AXEL.Ranks[clean]) then return false, "That rank already exists." end

        immunity = math.Clamp(math.floor(tonumber(immunity) or 0), 0, AXEL.MaxImmunity)

        local ok, reason = canEditRank(actor, immunity, "create")
        if (not ok) then return false, reason end

        inherit = string.lower(string.Trim(tostring(inherit or "")))
        if (inherit == "") then inherit = AXEL.RootRank end

        if (not AXEL.Ranks[inherit]) then
            return false, "Parent rank '" .. inherit .. "' does not exist."
        end

        AXEL.Ranks[clean] = {
            name = clean,
            inherit = inherit,
            immunity = immunity,
            banLimit = 0,
            permissions = {}
        }

        AXEL.SaveRank(AXEL.Ranks[clean])
        resyncCAMI()

        return true, string.format("Rank '%s' created (immunity %d, inherits %s).",
            clean, immunity, inherit)
    end
})

AXEL.RegisterCommand("removerank", {
    description = "Delete a rank. Holders and child ranks are reparented.",
    category = "Ranks",
    permission = "manageranks",
    arguments = {"string"},
    OnRun = function(actor, name)
        name = string.lower(string.Trim(tostring(name or "")))

        local rank = AXEL.Ranks[name]
        if (not rank) then return false, "That rank does not exist." end

        if (name == AXEL.RootRank or name == AXEL.SuperRank) then
            return false, "The " .. name .. " rank cannot be deleted."
        end

        local ok, reason = canEditRank(actor, rank.immunity or 0, "delete")
        if (not ok) then return false, reason end

        if (not AXEL.DeleteRank(name)) then return false, "Could not delete that rank." end

        -- Anyone online holding it drops to the root rank immediately.
        for _, client in ipairs(player.GetAll()) do
            if (client:GetUserGroup() == name) then
                client:SetUserGroup(AXEL.RootRank)
                AXEL.SavePlayer(client:SteamID(), client:Nick(), AXEL.RootRank, 0)
            end
        end

        resyncCAMI()

        return true, "Rank '" .. name .. "' deleted."
    end
})

AXEL.RegisterCommand("rankimmunity", {
    description = "Set a rank's immunity.",
    category = "Ranks",
    permission = "manageranks",
    arguments = {"string", "number"},
    OnRun = function(actor, name, immunity)
        name = string.lower(string.Trim(tostring(name or "")))

        local rank = AXEL.Ranks[name]
        if (not rank) then return false, "That rank does not exist." end

        immunity = math.Clamp(math.floor(tonumber(immunity) or 0), 0, AXEL.MaxImmunity)

        -- Checked against both values: you may not edit a rank above you, nor
        -- raise one to above you.
        local ok, reason = canEditRank(actor, math.max(rank.immunity or 0, immunity), "edit")
        if (not ok) then return false, reason end

        rank.immunity = immunity
        AXEL.SaveRank(rank)

        return true, string.format("Rank '%s' immunity set to %d.", name, immunity)
    end
})

AXEL.RegisterCommand("rankinherit", {
    description = "Set which rank a rank inherits from.",
    category = "Ranks",
    permission = "manageranks",
    arguments = {"string", "string"},
    OnRun = function(actor, name, parent)
        name = string.lower(string.Trim(tostring(name or "")))
        parent = string.lower(string.Trim(tostring(parent or "")))

        local rank = AXEL.Ranks[name]
        if (not rank) then return false, "That rank does not exist." end

        if (name == AXEL.RootRank) then
            return false, "The root rank cannot inherit from anything."
        end

        local ok, reason = canEditRank(actor, rank.immunity or 0, "edit")
        if (not ok) then return false, reason end

        if (parent == "" or parent == "none") then parent = nil end

        if (parent) then
            if (not AXEL.Ranks[parent]) then
                return false, "Rank '" .. parent .. "' does not exist."
            end

            if (parent == name) then return false, "A rank cannot inherit from itself." end

            -- Walk up from the proposed parent: if we meet this rank, the edit
            -- would close a loop.
            local seen, current = {}, parent
            while current and not seen[current] do
                if (current == name) then
                    return false, "That would create a circular inheritance chain."
                end
                seen[current] = true
                local link = AXEL.Ranks[current]
                current = link and link.inherit or nil
            end
        end

        rank.inherit = parent
        AXEL.SaveRank(rank)
        resyncCAMI()

        return true, string.format("Rank '%s' now inherits %s.", name, parent or "nothing")
    end
})

AXEL.RegisterCommand("rankperm", {
    description = "Grant, deny or clear a permission on a rank. Value: allow / deny / clear.",
    category = "Ranks",
    permission = "manageranks",
    arguments = {"string", "string", "string"},
    OnRun = function(actor, name, permission, value)
        name = string.lower(string.Trim(tostring(name or "")))
        permission = string.lower(string.Trim(tostring(permission or "")))
        value = string.lower(string.Trim(tostring(value or "allow")))

        local rank = AXEL.Ranks[name]
        if (not rank) then return false, "That rank does not exist." end
        if (permission == "") then return false, "No permission given." end

        local ok, reason = canEditRank(actor, rank.immunity or 0, "edit")
        if (not ok) then return false, reason end

        -- You cannot grant what you do not hold, or staff could bootstrap
        -- themselves upward one permission at a time.
        if (IsValid(actor) and not actor:IsSuperAdmin()) then
            if (value == "allow" and not actor:AXELHasPermission(permission)) then
                return false, "You cannot grant a permission you do not hold."
            end
        end

        rank.permissions = rank.permissions or {}

        if (value == "clear" or value == "none") then
            rank.permissions[permission] = nil
        elseif (value == "deny" or value == "false") then
            rank.permissions[permission] = false
        else
            rank.permissions[permission] = true
        end

        AXEL.SaveRank(rank)

        return true, string.format("Rank '%s': %s set to %s.", name, permission, value)
    end
})

-- Additional player care controls, routed through the shared permission gateway.
AXEL.RegisterCommand("heal", {
    description = "Restore living players to their maximum health.",
    category = "Player", permission = "hp", arguments = {"players"},
    OnRun = function(actor, targets)
        local count = 0
        for _, target in ipairs(targets) do
            if target:Alive() then target:SetHealth(target:GetMaxHealth()); count = count + 1 end
        end
        if count == 0 then return false, "No living players selected. Use Respawn first." end
        return true, "Healed " .. count .. " player(s)."
    end
})
AXEL.RegisterCommand("extinguish", {
    description = "Put out fire on selected players.",
    category = "Player", arguments = {"players"},
    OnRun = function(actor, targets)
        for _, target in ipairs(targets) do target:Extinguish() end
        return true, "Extinguished " .. AXEL.DescribeTargets(targets) .. "."
    end
})
AXEL.RegisterCommand("ungod", {
    description = "Disable godmode on selected players.",
    category = "Player", permission = "god", arguments = {"players"},
    OnRun = function(actor, targets)
        for _, target in ipairs(targets) do target:GodDisable() end
        return true, "Godmode disabled for " .. AXEL.DescribeTargets(targets) .. "."
    end
})
