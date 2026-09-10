--[[
    Axel Admin Menu - CAMI provider

    CAMI is the shared contract other addons use to ask "may this player do X"
    without knowing which admin mod is installed. Helix ships the library, but
    it is inert until something answers its queries. SAM was doing that; with
    SAM gone this file has to, or every CAMI consumer silently falls back to
    IsAdmin() at best and denies at worst.

    On this server sh_cami_propprotect.lua depends on it directly.

    Three responsibilities:
      1. Register our ranks as CAMI usergroups, with their inheritance.
      2. Answer CAMI.PlayerHasAccess / SteamIDHasAccess.
      3. Keep usergroup registration in sync as ranks change.
]]

--[[
    CAMI is provided by the gamemode (Helix loads it from
    gamemode/core/libs/thirdparty), and gamemode files load AFTER addon
    autoruns. So CAMI is reliably nil at this point on every boot.

    Bailing out here would mean the provider hooks are never registered at all,
    even though CAMI shows up moments later. Instead everything is registered
    unconditionally and the parts that touch CAMI wait until it exists.
]]

local SOURCE = "Axel"

function AXEL.HasCAMI()
    return CAMI ~= nil and istable(CAMI) and isfunction(CAMI.RegisterUsergroup)
end

--[[
    Mirrors our ranks into CAMI's usergroup registry.

    CAMI wants a parent ("Inherits") that it recognises. Our custom ranks
    inherit from other custom ranks, which is fine, but the chain must
    ultimately reach one of CAMI's three base groups or consumers that only
    understand user/admin/superadmin will not resolve it.
]]
local function baseGroupFor(rank)
    if (AXEL.InheritsFrom(rank.name, AXEL.SuperRank)) then return "superadmin" end
    if (AXEL.InheritsFrom(rank.name, "admin")) then return "admin" end
    return "user"
end

function AXEL.SyncCAMIUsergroups()
    if (not AXEL.HasCAMI()) then return false end

    -- AXEL.Ranks is a dictionary keyed by rank name ("moderator", "admin"),
    -- not a sequential array. pairs is required; ipairs would visit nothing and
    -- silently register zero usergroups.
    for name, rank in next, AXEL.Ranks do
        if (name ~= "__migrated__") then
            local inherits = rank.inherit

            -- Point at the nearest base group when the parent is one of ours
            -- that CAMI has not been told about yet; registration order is not
            -- guaranteed and a dangling parent makes CAMI treat it as "user".
            if (not inherits or not AXEL.Ranks[inherits]) then
                inherits = baseGroupFor(rank)
            end

            CAMI.RegisterUsergroup({
                Name = name,
                Inherits = inherits
            }, SOURCE)
        end
    end

    return true
end

--[[
    Answers access queries.

    CAMI's contract: a handler returns true to mean "I answered, stop asking
    other providers", or nil to abstain. So the unconditional `return true`
    below is the contract, not an oversight - a static analyser will flag it as
    "returning without a condition in a hook", and it is meant to be there.
    Abstaining would hand the decision to whatever provider answers next, which
    on a server with a half-removed admin mod is exactly the wrong outcome.

    The one case where we genuinely must abstain is a caller that gave us no
    callback to answer through. Claiming to have handled a query we could not
    answer would deny access with no explanation.
]]
hook.Add("CAMI.PlayerHasAccess", "AXEL.CAMIProvider",
function(actor, privilegeName, callback, targetPly, extra)
    if (not isfunction(callback)) then return end

    if (not IsValid(actor) or not actor:IsPlayer()) then
        -- Console and non-players get access; matches every admin mod.
        callback(true, "Axel: console")
        return true
    end

    local privilege = AXEL.HasCAMI() and CAMI.GetPrivilege(privilegeName) or nil
    local group = actor:GetUserGroup()

    -- superadmin short-circuits everything. Safe to do before the immunity
    -- check below, because CanTarget already lets max immunity target anyone.
    if (AXEL.InheritsFrom(group, AXEL.SuperRank)) then
        callback(true, "Axel: superadmin")
        return true
    end

    -- An explicit permission of the same name wins over the privilege's
    -- declared minimum access level.
    local allowed = AXEL.RankHasPermission(group, privilegeName)
    local reason = "Axel: rank permission"

    if (not allowed) then
        local minAccess = privilege and privilege.MinAccess or "admin"
        allowed = AXEL.InheritsFrom(group, minAccess)
        reason = allowed and "Axel: granted" or "Axel: insufficient rank"
    end

    --[[
        Immunity applies to every grant, not only the fallback one.

        This used to sit after an early return on the rank-permission path, so
        an admin holding an explicit "kick" permission was told yes about a
        target of equal immunity - while our own !kick refused the same action.
        A CAMI consumer asking the same question must not get a weaker answer
        than the command does.
    ]]
    if (allowed and IsValid(targetPly) and targetPly:IsPlayer()) then
        if (not AXEL.CanTarget(group, targetPly:GetUserGroup(), false)) then
            callback(false, "Axel: target outranks you")
            return true
        end
    end

    callback(allowed, reason)
    if (isfunction(callback)) then
        return true
    end
end)

hook.Add("CAMI.SteamIDHasAccess", "AXEL.CAMIProviderSteamID",
function(steamid, privilegeName, callback, targetSteamID, extra)
    -- Same reasoning as above: abstain only when we have no way to answer.
    if (not isfunction(callback)) then return end

    local stored = AXEL.GetStoredPlayer(steamid)
    local group = stored and stored.rank or AXEL.RootRank

    if (AXEL.InheritsFrom(group, AXEL.SuperRank)) then
        callback(true, "Axel: superadmin")
        return true
    end

    local allowed = AXEL.RankHasPermission(group, privilegeName)
    local reason = "Axel: rank permission"

    if (not allowed) then
        local privilege = AXEL.HasCAMI() and CAMI.GetPrivilege(privilegeName) or nil
        local minAccess = privilege and privilege.MinAccess or "admin"
        allowed = AXEL.InheritsFrom(group, minAccess)
        reason = allowed and "Axel: granted" or "Axel: insufficient rank"
    end

    -- targetSteamID was previously ignored, so an offline-target query got no
    -- immunity check at all. The stored rank is the right source here: the
    -- target need not be connected for a SteamID query to be asked.
    if (allowed and isstring(targetSteamID) and targetSteamID ~= "" and targetSteamID ~= steamid) then
        local targetStored = AXEL.GetStoredPlayer(targetSteamID)
        local targetGroup = targetStored and targetStored.rank or AXEL.RootRank

        if (not AXEL.CanTarget(group, targetGroup, false)) then
            callback(false, "Axel: target outranks you")
            return true
        end
    end

    callback(allowed, reason)
    if (isfunction(callback)) then
        return true
    end
end)

--- Register our own permissions as CAMI privileges so other admin tools can
--- see and grant them.
local function registerPrivileges()
    if (not AXEL.HasCAMI()) then return false end

    -- Keyed by permission name, same as AXEL.Ranks above. pairs is required.
    for name, data in next, AXEL.Permissions do
        CAMI.RegisterPrivilege({
            Name = name,
            MinAccess = "admin",
            Description = data.description
        })
    end

    return true
end

hook.Add("AXEL.RankChanged", "AXEL.CAMIResync", function()
    AXEL.SyncCAMIUsergroups()
end)

--[[
    Registration waits for CAMI to appear.

    Tried at several points because the exact moment the gamemode finishes
    loading its libraries is not something an addon can depend on. Stops as
    soon as it succeeds, and only warns if CAMI is genuinely absent once
    everything has loaded - which is the difference between "not yet" and
    "not at all".
]]
AXEL.CAMIRegistered = false

local function tryRegisterCAMI(stage)
    if (AXEL.CAMIRegistered) then return true end
    if (not AXEL.HasCAMI()) then return false end

    AXEL.SyncCAMIUsergroups()
    registerPrivileges()
    AXEL.CAMIRegistered = true

    -- table.Count, not #: AXEL.Ranks is keyed by rank name, so the length
    -- operator would report 0.
    local count = table.Count(AXEL.Ranks)

    MsgC(Color(218, 177, 83), "[Axel] ", Color(210, 213, 218),
        string.format("CAMI provider registered at %s (%d usergroups).\n", stage, count))

    return true
end

hook.Add("Initialize", "AXEL.CAMIRegister", function()
    tryRegisterCAMI("Initialize")
end)

hook.Add("InitPostEntity", "AXEL.CAMIRegisterLate", function()
    tryRegisterCAMI("InitPostEntity")
end)

-- Last resort: poll briefly, then report honestly if it never turned up.
local attempts = 0
timer.Create("AXEL.CAMIWait", 1, 15, function()
    attempts = attempts + 1

    if (tryRegisterCAMI("retry " .. attempts)) then
        timer.Remove("AXEL.CAMIWait")
        return
    end

    if (attempts >= 15) then
        MsgC(Color(226, 169, 60), "\n[Axel] ", Color(238, 240, 243),
            "CAMI NOT FOUND after 15 seconds.\n")
        MsgC(Color(210, 213, 218),
            "  Prop protection and other CAMI consumers will not see Axel\n" ..
            "  server ranks. Helix normally provides CAMI at\n" ..
            "  gamemodes/<schema>/gamemode/core/libs/thirdparty/sh_cami.lua\n" ..
            "  Check that file exists and that the gamemode loaded.\n\n")
    end
end)

concommand.Add("axel_cami_status", function(client)
    if (IsValid(client) and not client:IsSuperAdmin()) then return end

    local lines = {}

    -- This is the command someone runs precisely when CAMI is missing, so it
    -- must report that rather than error on CAMI.GetUsergroups().
    if (not AXEL.HasCAMI()) then
        lines[#lines + 1] = "[Axel] CAMI present:    NO"
        lines[#lines + 1] = "[Axel] Provider active: no"
        lines[#lines + 1] = "  CAMI is supplied by the gamemode, not by this addon."
        lines[#lines + 1] = "  Expected at gamemode/core/libs/thirdparty/sh_cami.lua"
    else
        lines[#lines + 1] = "[Axel] CAMI present:    yes (version " ..
            tostring(CAMI.Version or "?") .. ")"
        lines[#lines + 1] = "[Axel] Provider active: " ..
            (AXEL.CAMIRegistered and "yes" or "NO - registration has not run yet")

        -- CAMI.GetUsergroups is keyed by group name, so pairs is required here;
        -- ipairs would visit nothing. Keep the set as well as the sorted list:
        -- the missing-rank check below needs lookups, not iteration.
        local registered = CAMI.GetUsergroups() or {}
        local groups = {}
        for name in next, registered do groups[#groups + 1] = name end
        table.sort(groups)

        lines[#lines + 1] = "[Axel] Usergroups (" .. #groups .. "):"
        for _, name in ipairs(groups) do
            lines[#lines + 1] = "  " .. name .. (AXEL.Ranks[name] and "" or "   (not one of ours)")
        end

        lines[#lines + 1] = "[Axel] Privileges registered: " ..
            table.Count(CAMI.GetPrivileges() or {})

        -- Names a rank that exists locally but never reached CAMI.
        local missing = {}
        for name in next, AXEL.Ranks do
            if (name ~= "__migrated__" and not registered[name]) then
                missing[#missing + 1] = name
            end
        end
        table.sort(missing)

        if (#missing > 0) then
            lines[#lines + 1] = "[Axel] NOT registered with CAMI: " ..
                table.concat(missing, ", ")
            lines[#lines + 1] = "  Run axel_cami_sync to retry."
        end
    end

    for _, line in ipairs(lines) do
        if (IsValid(client)) then client:PrintMessage(HUD_PRINTCONSOLE, line) else print(line) end
    end
end)

concommand.Add("axel_cami_sync", function(client)
    if (IsValid(client) and not client:IsSuperAdmin()) then return end

    AXEL.CAMIRegistered = false
    local ok = tryRegisterCAMI("manual axel_cami_sync")

    local message = ok and "[Axel] CAMI provider re-registered."
        or "[Axel] CAMI is not loaded; nothing to register."

    if (IsValid(client)) then
        client:PrintMessage(HUD_PRINTCONSOLE, message)
    else
        print(message)
    end
end)
