--[[
    Axel Admin Menu - ranks and player meta

    Overrides GetUserGroup/SetUserGroup/IsAdmin/IsSuperAdmin so every addon on
    the server sees our ranks through the standard interface. Anything that
    calls ply:IsAdmin() keeps working with no changes.

    Replication
    -----------
    The authoritative rank is a plain server-side field. It is pushed to the
    owning client with the net library, because a client only ever needs its
    own rank: the menu uses it to grey out controls it knows the server would
    refuse. Every other player's rank already reaches the client inside
    AXEL.SendPlayers, so there is nothing to broadcast.

    The engine's own SetUserGroup is still called underneath, so client-side
    ply:GetUserGroup() stays correct for any addon reading it that way.
]]

local PLAYER = FindMetaTable("Player")

util.AddNetworkString("AXEL.RankUpdate")
util.AddNetworkString("AXEL.RankRequest")

-- Captured once, before anything else has a chance to replace it.
AXEL.OldSetUserGroup = AXEL.OldSetUserGroup or PLAYER.SetUserGroup

--[[
    Pushes a player their own rank.

    SetUserGroup often runs during connection, before the client can receive
    anything, so this is best-effort. The client asks again once it is ready,
    which is what actually guarantees delivery.
]]
function AXEL.SendRank(client)
    if (not IsValid(client) or not client:IsPlayer()) then return end

    net.Start("AXEL.RankUpdate")
        net.WriteString(client.AXELRank or AXEL.RootRank)
    net.Send(client)
end

net.Receive("AXEL.RankRequest", function(_, client)
    if (not IsValid(client)) then return end

    -- Cheap, but a client can call it in a loop, so rate limit it anyway.
    if ((client.AXELRankRequestNext or 0) > CurTime()) then return end
    client.AXELRankRequestNext = CurTime() + 1

    AXEL.SendRank(client)
end)

hook.Add("PlayerInitialSpawn", "AXEL.RankPush", function(client)
    timer.Simple(3, function()
        if (IsValid(client)) then AXEL.SendRank(client) end
    end)
end)

--[[
    Applied through a function rather than at file scope so it can be re-run
    after every other addon has loaded.

    Addons load alphabetically, so any admin mod sorting after
    "axel_admin" installs its own PLAYER:IsSuperAdmin over ours and
    every rank check silently starts answering from its data instead. SAM is
    one such case. Re-applying on Initialize and InitPostEntity means we win
    regardless of folder name.
]]
function AXEL.ApplyPlayerMeta()

function PLAYER:GetUserGroup()
    local group = self.AXELRank
    if (group and group ~= "") then return group end
    return AXEL.RootRank
end

function PLAYER:SetUserGroup(name)
    name = string.lower(string.Trim(tostring(name or AXEL.RootRank)))
    if (not AXEL.Ranks[name]) then name = AXEL.RootRank end

    local previous = self:GetUserGroup()
    self.AXELRank = name

    -- Keep the engine's own notion in sync; some modules read it directly.
    if (AXEL.OldSetUserGroup) then
        pcall(AXEL.OldSetUserGroup, self, name)
    end

    AXEL.SendRank(self)

    if (previous ~= name) then
        hook.Run("AXEL.RankChanged", self, previous, name)

        -- Tell CAMI, so anything listening (prop protection included) drops
        -- its cached answer for this player.
        if (CAMI and isfunction(CAMI.SignalUserGroupChanged)) then
            pcall(CAMI.SignalUserGroupChanged, self, previous, name, "AXEL")
        end
    end

    return name
end

function PLAYER:IsUserGroup(name)
    return AXEL.InheritsFrom(self:GetUserGroup(), name)
end

function PLAYER:IsAdmin()
    return AXEL.InheritsFrom(self:GetUserGroup(), "admin")
        or AXEL.InheritsFrom(self:GetUserGroup(), AXEL.SuperRank)
end

function PLAYER:IsSuperAdmin()
    return AXEL.InheritsFrom(self:GetUserGroup(), AXEL.SuperRank)
end

--- The permission check every command routes through.
function PLAYER:AXELHasPermission(permission)
    return AXEL.RankHasPermission(self:GetUserGroup(), permission)
end

function PLAYER:AXELImmunity()
    return AXEL.GetImmunity(self:GetUserGroup())
end

-- Remember our own function so AXEL.OwnsMeta can tell whether it is still the
-- one installed, rather than merely whether something is installed.
AXEL.MetaIsSuperAdmin = PLAYER.IsSuperAdmin

end -- AXEL.ApplyPlayerMeta

AXEL.ApplyPlayerMeta()

--[[
    Re-apply after every other addon has had its turn, and say so plainly if
    something else was found sitting on the meta first. A silent overwrite is
    exactly the failure this guards against, so it must not fail silently.
]]
--[[
    Re-reads every connected player's rank from the database and re-applies it.

    Needed because SetUserGroup is the thing that writes the axel_rank networked
    var. If another admin mod owned that function when a player spawned, their
    SetUserGroup ran instead of ours, axel_rank was never written, and
    GetUserGroup falls back to "user" for the rest of the session - so a genuine
    superadmin reads as a normal player and stays that way.

    Reclaiming the meta alone does not fix that, because nothing re-runs
    SetUserGroup for players who are already connected.
]]
function AXEL.ResyncConnectedPlayers(reason)
    local resynced = {}

    for _, client in ipairs(player.GetAll()) do
        if (IsValid(client)) then
            local stored = AXEL.GetStoredPlayer(client:SteamID())
            local rank = stored and string.lower(stored.rank or AXEL.RootRank) or AXEL.RootRank

            if (not AXEL.Ranks[rank]) then rank = AXEL.RootRank end

            local before = client.AXELRank or ""
            client:SetUserGroup(rank)

            if (before ~= rank) then
                resynced[#resynced + 1] = client:Nick() .. " -> " .. rank
            end
        end
    end

    if (#resynced > 0) then
        MsgC(Color(226, 169, 60), "[Axel] ", Color(210, 213, 218),
            "Re-synced " .. #resynced .. " player rank(s) after " .. tostring(reason) ..
            ": " .. table.concat(resynced, ", ") .. "\n")
    end

    return #resynced
end

local function reapply(stage)
    local before = PLAYER.IsSuperAdmin
    AXEL.ApplyPlayerMeta()

    if (before ~= PLAYER.IsSuperAdmin) then
        MsgC(Color(226, 169, 60), "[Axel] ", Color(210, 213, 218),
            "Another addon had replaced PLAYER:IsSuperAdmin. Reclaimed at " ..
            stage .. ".\n")
    end

    -- Always re-sync, not only when the meta had been stolen: a player may have
    -- spawned during the window before we reclaimed it.
    AXEL.ResyncConnectedPlayers(stage)
end

hook.Add("Initialize", "AXEL.ReapplyMeta", function() reapply("Initialize") end)
hook.Add("InitPostEntity", "AXEL.ReapplyMetaLate", function() reapply("InitPostEntity") end)
timer.Simple(0, function() reapply("post-load") end)

--- Names any other admin mod sharing the server, because two of them fighting
--- over the player meta produces symptoms that look like corrupt rank data.
hook.Add("InitPostEntity", "AXEL.DetectConflicts", function()
    local conflicts = {}

    if (sam and sam.ranks) then conflicts[#conflicts + 1] = "SAM" end
    if (ULib or ULX) then conflicts[#conflicts + 1] = "ULX/ULib" end
    if (serverguard) then conflicts[#conflicts + 1] = "ServerGuard" end
    if (evolve) then conflicts[#conflicts + 1] = "Evolve" end

    if (#conflicts > 0) then
        MsgC(Color(220, 48, 52), "\n[Axel] ", Color(238, 240, 243),
            "ANOTHER ADMIN MOD IS INSTALLED: " .. table.concat(conflicts, ", ") .. "\n")
        MsgC(Color(210, 213, 218),
            "  Both are overriding PLAYER:IsAdmin / IsSuperAdmin. Axel\n" ..
            "  has reclaimed them, but the other mod's own commands and menu will\n" ..
            "  still read its own rank data and may disagree.\n" ..
            "  Run its commands only for as long as you need it, then remove it.\n\n")
    end
end)

--[[ ------------------------------------------------------------------------
    Assignment
--------------------------------------------------------------------------- ]]

--- Sets a player's rank and persists it. duration 0 means permanent.
function AXEL.SetRank(target, rankName, duration, actor)
    rankName = string.lower(string.Trim(tostring(rankName or "")))

    if (not AXEL.Ranks[rankName] or rankName == "__migrated__") then
        return false, "That rank does not exist."
    end

    local steamid = IsValid(target) and target:SteamID() or tostring(target)
    duration = math.max(0, math.floor(tonumber(duration) or 0))
    local expiry = duration > 0 and (AXEL.Now() + duration) or 0

    local saved, saveMessage = AXEL.SavePlayer(
        steamid,
        IsValid(target) and target:Nick() or nil,
        rankName,
        expiry
    )

    if (not saved) then
        return false, "Rank was not changed: " .. tostring(saveMessage or "storage write failed")
    end

    -- Apply the live rank only after at least one persistent store confirms it.
    if (IsValid(target)) then target:SetUserGroup(rankName) end

    AXEL.Log(
        IsValid(actor) and actor:SteamID() or "CONSOLE",
        IsValid(actor) and actor:Nick() or "Console",
        "setrank", steamid,
        rankName .. (duration > 0 and (" for " .. AXEL.FormatDuration(duration)) or ""))

    return true, "Rank set to " .. rankName .. "." ..
        (saveMessage and (" Warning: " .. saveMessage) or "")
end

--[[ ------------------------------------------------------------------------
    Connection
--------------------------------------------------------------------------- ]]

local joinTime = {}

hook.Add("PlayerInitialSpawn", "AXEL.LoadRank", function(client)
    local steamid = client:SteamID()
    local stored = AXEL.GetStoredPlayer(steamid)
    local rank = AXEL.RootRank

    if (stored) then
        rank = string.lower(stored.rank or AXEL.RootRank)

        -- Temporary ranks expire on join rather than on a timer, so a player
        -- who was offline when it lapsed still comes back demoted.
        local expiry = tonumber(stored.rank_expiry) or 0
        if (expiry > 0 and AXEL.Now() >= expiry) then
            rank = AXEL.RootRank
            AXEL.SavePlayer(steamid, client:Nick(), AXEL.RootRank, 0)

            AXEL.Log("SYSTEM", "System", "rankexpired", steamid,
                "Temporary rank '" .. tostring(stored.rank) .. "' expired")
        end

        if (not AXEL.Ranks[rank]) then rank = AXEL.RootRank end
    end

    client:SetUserGroup(rank)
    AXEL.SavePlayer(steamid, client:Nick(), rank, stored and tonumber(stored.rank_expiry) or 0)

    joinTime[steamid] = AXEL.Now()
end)

-- MySQL is asynchronous. Apply a newer remote rank after the normal local
-- spawn load, then mirror it into SQLite and the JSON backup.
local function loadMySQLRank(client)
    if (not IsValid(client) or not AXEL.MySQL or not AXEL.MySQL.Ready) then return end

    local steamid = client:SteamID()
    AXEL.MySQL:LoadPlayer(steamid, function(remote)
        if (not IsValid(client) or not istable(remote)) then return end

        local localRow = AXEL.GetStoredPlayer(steamid)
        local remoteUpdated = tonumber(remote.updated) or 0
        local localUpdated = localRow and tonumber(localRow.updated) or 0
        local rank = string.lower(tostring(remote.rank or AXEL.RootRank))
        local expiry = tonumber(remote.rank_expiry) or 0

        if (remoteUpdated < localUpdated or not AXEL.Ranks[rank]) then return end
        if (expiry > 0 and AXEL.Now() >= expiry) then
            rank, expiry = AXEL.RootRank, 0
        end

        AXEL.SavePlayer(steamid, client:Nick(), rank, expiry)
        client:SetUserGroup(rank)
    end)
end

hook.Add("PlayerInitialSpawn", "AXEL.LoadMySQLRank", function(client)
    timer.Simple(2, function() loadMySQLRank(client) end)
end)

hook.Add("AXEL.MySQLReady", "AXEL.LoadConnectedMySQLRanks", function()
    for _, client in ipairs(player.GetAll()) do loadMySQLRank(client) end
end)

hook.Add("PlayerDisconnected", "AXEL.SavePlayTime", function(client)
    local steamid = client:SteamID()
    local started = joinTime[steamid]

    if (started) then
        AXEL.AddPlayTime(steamid, AXEL.Now() - started)
        joinTime[steamid] = nil
    end
end)

--- Live play time including the current session.
function AXEL.GetPlayTime(client)
    local stored = AXEL.GetStoredPlayer(client:SteamID())
    local total = stored and (tonumber(stored.play_time) or 0) or 0
    local started = joinTime[client:SteamID()]

    if (started) then total = total + (AXEL.Now() - started) end

    return total
end

--[[ ------------------------------------------------------------------------
    Diagnostics

    Distinguishes "the menu did not receive the ranks" from "no ranks were
    loaded in the first place", which are very different problems.
--------------------------------------------------------------------------- ]]

concommand.Add("axel_ranks", function(client)
    if (IsValid(client) and not client:IsSuperAdmin()) then return end

    local names = {}
    for name in next, AXEL.Ranks do
        if (name ~= "__migrated__") then names[#names + 1] = name end
    end

    table.sort(names, function(a, b)
        return AXEL.GetImmunity(a) > AXEL.GetImmunity(b)
    end)

    local lines = {"[Axel] " .. #names .. " ranks loaded:"}

    for _, name in ipairs(names) do
        local rank = AXEL.Ranks[name]
        -- Keyed by permission name, so table.Count and not #.
        local count = table.Count(rank.permissions or {})

        lines[#lines + 1] = string.format("  %-24s immunity %-4d inherits %-20s %d permissions",
            name, rank.immunity or 0, rank.inherit or "(root)", count)
    end

    if (#names == 0) then
        lines[#lines + 1] = "  NONE. Run  axel_migrate_from_sam  in the server console."
    end

    for _, line in ipairs(lines) do
        if (IsValid(client)) then
            client:PrintMessage(HUD_PRINTCONSOLE, line)
        else
            print(line)
        end
    end
end)

--[[
    Prints every step between "the database says X" and "IsSuperAdmin returns
    Y", so a failure can be pinned to a specific link instead of guessed at.
]]
local function describe(client, target)
    local steamid = target:SteamID()
    local stored = AXEL.GetStoredPlayer(steamid)
    local field = target.AXELRank or ""
    local resolved = target:GetUserGroup()
    local rank = AXEL.Ranks[resolved]

    -- Walk the chain by hand so a break is visible.
    local chain, seen, current = {}, {}, resolved
    while current and not seen[current] do
        seen[current] = true
        chain[#chain + 1] = current
        local link = AXEL.Ranks[current]
        if (not link) then chain[#chain] = current .. " (MISSING)" break end
        current = link.inherit
    end

    local lines = {
        "---- Axel: " .. target:Nick() .. " ----",
        "  SteamID              " .. steamid,
        "  Database rank        " .. (stored and stored.rank or "NO ROW"),
        "  AXELRank field        " .. (field ~= "" and field or "EMPTY  <-- SetUserGroup never ran as ours"),
        "  GetUserGroup()       " .. resolved,
        "  Rank exists          " .. tostring(rank ~= nil),
        "  Immunity             " .. AXEL.GetImmunity(resolved),
        "  Inheritance chain    " .. table.concat(chain, " -> "),
        "  IsSuperAdmin()       " .. tostring(target:IsSuperAdmin()),
        "  IsAdmin()            " .. tostring(target:IsAdmin()),
        "  Meta owner           " .. (AXEL.OwnsMeta and AXEL.OwnsMeta() and "Axel"
            or "ANOTHER ADMIN MOD  <-- this is the problem"),
    }

    if (stored and field ~= "" and string.lower(stored.rank or "") ~= field) then
        lines[#lines + 1] = "  MISMATCH: database and net var disagree. Run axel_resync."
    end

    for _, line in ipairs(lines) do
        if (IsValid(client)) then
            client:PrintMessage(HUD_PRINTCONSOLE, line)
        else
            print(line)
        end
    end
end

--- True while our own functions are the ones installed on the player meta.
function AXEL.OwnsMeta()
    return PLAYER.IsSuperAdmin == AXEL.MetaIsSuperAdmin
end

concommand.Add("axel_whoami", function(client)
    if (IsValid(client)) then
        describe(client, client)
    else
        for _, target in ipairs(player.GetAll()) do describe(nil, target) end
    end
end)

concommand.Add("axel_resync", function(client)
    -- Deliberately does NOT gate on IsSuperAdmin(): a broken IsSuperAdmin is
    -- the exact reason someone would need this. Authorise against the stored
    -- rank instead, which no other addon can have overwritten.
    if (IsValid(client)) then
        local stored = AXEL.GetStoredPlayer(client:SteamID())
        local rank = stored and string.lower(stored.rank or "") or ""

        if (not AXEL.InheritsFrom(rank, AXEL.SuperRank)) then
            client:PrintMessage(HUD_PRINTCONSOLE,
                "[Axel] Only a stored superadmin may run this.")
            return
        end
    end

    AXEL.ApplyPlayerMeta()
    local count = AXEL.ResyncConnectedPlayers("manual axel_resync")

    local message = "[Axel] Re-applied player meta and re-synced " ..
        count .. " player(s)."

    if (IsValid(client)) then
        client:PrintMessage(HUD_PRINTCONSOLE, message)
    else
        print(message)
    end
end)
