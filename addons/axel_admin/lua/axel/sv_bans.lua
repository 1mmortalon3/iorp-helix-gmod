--[[
    Axel Admin Menu - bans

    A ban is only real if it is enforced at connect. CheckPassword runs before
    the player entity exists, which is why the lookup here is by SteamID against
    the database and not against anything in-game.

    Expiry is lazy: an elapsed ban is deleted when it is next looked at, so no
    timer is needed and a ban that lapses while the server is offline is still
    correctly gone on the next join attempt.
]]

local function esc(value)
    return sql.SQLStr(tostring(value or ""))
end

--- Returns the ban row, or nil. Deletes it first if it has expired.
function AXEL.GetBan(steamid)
    if (not steamid or steamid == "") then return nil end

    local rows = sql.Query("SELECT * FROM axel_bans WHERE steamid = " .. esc(steamid))
    if (not istable(rows)) then return nil end

    local ban = rows[1]
    local expires = tonumber(ban.expires) or 0

    if (expires > 0 and AXEL.Now() >= expires) then
        sql.Query("DELETE FROM axel_bans WHERE steamid = " .. esc(steamid))
        AXEL.Log("SYSTEM", "System", "banexpired", steamid, "Ban expired")
        return nil
    end

    return ban
end

function AXEL.IsBanned(steamid)
    return AXEL.GetBan(steamid) ~= nil
end

--[[
    Bans a SteamID. duration in seconds, 0 for permanent.

    Accepts a disconnected SteamID as well as a live player, so offline bans
    work from the menu.
]]
function AXEL.Ban(target, duration, reason, actor)
    local steamid, name

    if (IsValid(target) and target:IsPlayer()) then
        steamid, name = target:SteamID(), target:Nick()
    else
        steamid = tostring(target)
        local stored = AXEL.GetStoredPlayer(steamid)
        name = stored and stored.name or "Unknown"
    end

    if (not AXEL.IsSteamID(steamid)) then
        return false, "That is not a valid SteamID."
    end

    duration = math.max(0, math.floor(tonumber(duration) or 0))
    reason = string.sub(string.Trim(tostring(reason or "")), 1, 200)
    if (reason == "") then reason = "No reason given" end

    -- A rank's ban_limit caps how long its holders may ban for. 0 means
    -- unlimited, so a limited rank cannot issue a permanent ban.
    if (IsValid(actor)) then
        local rank = AXEL.GetRank(actor:GetUserGroup())
        local limit = rank and (tonumber(rank.banLimit) or 0) or 0

        if (limit > 0) then
            if (duration == 0) then
                return false, "Your rank cannot issue permanent bans. Maximum is " ..
                    AXEL.FormatDuration(limit) .. "."
            end

            if (duration > limit) then
                return false, "Your rank can ban for at most " ..
                    AXEL.FormatDuration(limit) .. "."
            end
        end
    end

    local expires = duration > 0 and (AXEL.Now() + duration) or 0

    sql.Query(string.format(
        "REPLACE INTO axel_bans (steamid, name, reason, admin, admin_name, created, expires) " ..
        "VALUES (%s, %s, %s, %s, %s, %d, %d)",
        esc(steamid), esc(name), esc(reason),
        esc(IsValid(actor) and actor:SteamID() or "CONSOLE"),
        esc(IsValid(actor) and actor:Nick() or "Console"),
        AXEL.Now(), expires))

    AXEL.Log(
        IsValid(actor) and actor:SteamID() or "CONSOLE",
        IsValid(actor) and actor:Nick() or "Console",
        "ban", steamid,
        string.format("%s (%s) - %s", name, AXEL.FormatDuration(duration), reason))

    if (IsValid(target) and target:IsPlayer()) then
        target:Kick(AXEL.FormatBanMessage(reason, expires))
    end

    hook.Run("AXEL.PlayerBanned", steamid, duration, reason, actor)

    return true, string.format("%s banned (%s): %s", name, AXEL.FormatDuration(duration), reason)
end

function AXEL.Unban(steamid, actor)
    steamid = tostring(steamid)

    local ban = AXEL.GetBan(steamid)
    if (not ban) then return false, "That SteamID is not banned." end

    sql.Query("DELETE FROM axel_bans WHERE steamid = " .. esc(steamid))

    AXEL.Log(
        IsValid(actor) and actor:SteamID() or "CONSOLE",
        IsValid(actor) and actor:Nick() or "Console",
        "unban", steamid, ban.name or "")

    hook.Run("AXEL.PlayerUnbanned", steamid, actor)

    return true, steamid .. " unbanned."
end

function AXEL.GetBans()
    local rows = sql.Query("SELECT * FROM axel_bans ORDER BY created DESC")
    return istable(rows) and rows or {}
end

function AXEL.FormatBanMessage(reason, expires)
    local remaining = "permanently"

    if (expires and expires > 0) then
        remaining = "for " .. AXEL.FormatDuration(expires - AXEL.Now())
    end

    return string.format(
        "[Axel] You are banned %s.\nReason: %s",
        remaining, tostring(reason or "No reason given"))
end

--[[ ------------------------------------------------------------------------
    Enforcement

    CheckPassword fires before the player exists. Returning false with a message
    rejects the connection outright.
--------------------------------------------------------------------------- ]]

hook.Add("CheckPassword", "AXEL.EnforceBans", function(steamID64)
    local steamid = util.SteamIDFrom64(steamID64)
    local ban = AXEL.GetBan(steamid)

    if (ban) then
        return false, AXEL.FormatBanMessage(ban.reason, tonumber(ban.expires) or 0)
    end
end)

-- Belt and braces: if something else allowed the connection through, catch it
-- once the player exists rather than letting a banned player stay.
hook.Add("PlayerInitialSpawn", "AXEL.EnforceBansLate", function(client)
    local ban = AXEL.GetBan(client:SteamID())

    if (ban) then
        client:Kick(AXEL.FormatBanMessage(ban.reason, tonumber(ban.expires) or 0))
    end
end)
