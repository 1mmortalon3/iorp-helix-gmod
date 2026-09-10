--[[
    Axel Admin Menu - server theme defaults

    Two separate things live here and it matters that they stay separate:

      * the server default, which is what a player sees before they have ever
        opened the picker, and
      * the lock, which takes the choice away and is meant for servers that
        want one look in screenshots and clips.

    A player's own selection is a client convar and never leaves their machine.
    The server stores one theme id and one boolean, and nothing else.
]]

util.AddNetworkString("AXEL.ThemeConfig")
util.AddNetworkString("AXEL.ThemeSet")
util.AddNetworkString("AXEL.ThemeRequest")

local DIRECTORY = "axel_admin"
local FILE_PATH = DIRECTORY .. "/theme.json"

local function persist()
    if (not file.IsDir(DIRECTORY, "DATA")) then file.CreateDir(DIRECTORY) end

    file.Write(FILE_PATH, util.TableToJSON({
        default = AXEL.ServerTheme.default,
        locked = AXEL.ServerTheme.locked
    }, true))
end

local function restore()
    local raw = file.Read(FILE_PATH, "DATA")
    if (not raw) then return end

    local stored = util.JSONToTable(raw)
    if (not istable(stored)) then return end

    -- A theme can be removed between restarts; fall back rather than sending
    -- an id no client will recognise.
    if (AXEL.ThemeExists(stored.default)) then
        AXEL.ServerTheme.default = string.lower(stored.default)
    end

    AXEL.ServerTheme.locked = stored.locked == true
end

restore()

--[[
    The payload carries canManage so the client can show the admin controls
    without having to reason about rank inheritance itself. The server still
    re-checks on receipt; this flag only decides what is drawn.
]]
function AXEL.SendThemeConfig(target)
    local recipients = target and {target} or player.GetHumans()

    for _, client in ipairs(recipients) do
        if (IsValid(client)) then
            net.Start("AXEL.ThemeConfig")
                net.WriteString(AXEL.ServerTheme.default)
                net.WriteBool(AXEL.ServerTheme.locked)
                net.WriteBool(client:AXELHasPermission("managetheme"))
            net.Send(client)
        end
    end
end

--- Returns success, message so it can be used directly as a command result.
function AXEL.SetServerTheme(id, locked, actor)
    id = string.lower(string.Trim(tostring(id or "")))

    if (not AXEL.ThemeExists(id)) then
        return false, "Unknown theme '" .. id .. "'. Run settheme with no arguments to list them."
    end

    local changed = AXEL.ServerTheme.default ~= id or AXEL.ServerTheme.locked ~= (locked == true)

    AXEL.ServerTheme.default = id
    AXEL.ServerTheme.locked = locked == true

    persist()
    AXEL.SendThemeConfig()

    if (not changed) then
        return true, "Server theme is already " .. AXEL.Themes[id].name .. "."
    end

    return true, string.format("Server theme set to %s%s.",
        AXEL.Themes[id].name,
        AXEL.ServerTheme.locked and " and locked for everyone" or "")
end

local setCooldown = {}

net.Receive("AXEL.ThemeSet", function(_, client)
    -- Consume the payload before any early return, or the channel desyncs.
    local id = string.sub(net.ReadString(), 1, 32)
    local locked = net.ReadBool()

    if (not IsValid(client)) then return end
    if ((setCooldown[client] or 0) > CurTime()) then return end
    setCooldown[client] = CurTime() + 1

    if (not client:AXELHasPermission("managetheme")) then
        client:ChatPrint("[Axel] You do not have permission to change the server theme.")
        return
    end

    local success, message = AXEL.SetServerTheme(id, locked, client)

    if (success) then
        AXEL.Announce(client, message)
        AXEL.Log(client:SteamID(), client:Nick(), "settheme", id, message)
    else
        client:ChatPrint("[Axel] " .. message)
    end
end)

-- Its own bucket: asking for the current config must never be blocked by the
-- one-second guard on changing it, or the picker opens showing stale state.
local requestCooldown = {}

net.Receive("AXEL.ThemeRequest", function(_, client)
    if (not IsValid(client)) then return end
    if ((requestCooldown[client] or 0) > CurTime()) then return end
    requestCooldown[client] = CurTime() + 0.5

    AXEL.SendThemeConfig(client)
end)

-- Clients ask for this themselves once they are ready, but a push on spawn
-- means the correct palette is in place before the menu is ever opened.
hook.Add("PlayerInitialSpawn", "AXEL.ThemeConfigPush", function(client)
    timer.Simple(3, function()
        if (IsValid(client)) then AXEL.SendThemeConfig(client) end
    end)
end)

hook.Add("PlayerDisconnected", "AXEL.ThemeCleanup", function(client)
    setCooldown[client] = nil
    requestCooldown[client] = nil
end)
