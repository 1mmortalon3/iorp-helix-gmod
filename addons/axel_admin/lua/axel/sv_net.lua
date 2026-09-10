--[[
    Axel Admin Menu - networking

    The menu is a view, never an authority. It sends a command name and
    arguments exactly as if they had been typed, and the server runs them
    through AXEL.RunCommand with the same permission and immunity checks. There
    is deliberately no "menu only" code path.
]]

util.AddNetworkString("AXEL.OpenMenu")
util.AddNetworkString("AXEL.RequestData")
util.AddNetworkString("AXEL.SendPlayers")
util.AddNetworkString("AXEL.SendBans")
util.AddNetworkString("AXEL.SendLogs")
util.AddNetworkString("AXEL.SendRanks")
util.AddNetworkString("AXEL.RunCommand")

-- Separate buckets on purpose.
--
-- dataCooldown is per client AND per kind: the menu legitimately asks for
-- players, bans, ranks and logs in the same frame when it opens, and a single
-- shared timer would drop every request after the first.
--
-- actionCooldown is its own bucket so that opening the menu does not rate-limit
-- the first button press that follows it.
local dataCooldown = {}
local actionCooldown = {}

local function onCooldown(store, client, key, seconds)
    local now = CurTime()
    local bucket = store[client]

    if (not bucket) then
        bucket = {}
        store[client] = bucket
    end

    if ((bucket[key] or 0) > now) then return true end

    bucket[key] = now + seconds
    return false
end

function AXEL.OpenMenu(client)
    net.Start("AXEL.OpenMenu")
    net.Send(client)
end

local function sendPlayers(client)
    local all = player.GetAll()

    net.Start("AXEL.SendPlayers")
        net.WriteUInt(#all, 8)

        for _, target in ipairs(all) do
            net.WriteEntity(target)
            net.WriteString(target:Nick())
            net.WriteString(target:SteamID())
            net.WriteString(target:GetUserGroup())
            net.WriteUInt(math.Clamp(AXEL.GetImmunity(target:GetUserGroup()), 0, 255), 8)
            net.WriteUInt(math.Clamp(AXEL.GetPlayTime(target), 0, 4294967295), 32)
        end
    net.Send(client)
end

local function sendBans(client)
    local bans = AXEL.GetBans()
    local count = math.min(#bans, 200)

    net.Start("AXEL.SendBans")
        net.WriteUInt(count, 8)

        for index = 1, count do
            local ban = bans[index]
            net.WriteString(ban.steamid or "")
            net.WriteString(string.sub(ban.name or "Unknown", 1, 64))
            net.WriteString(string.sub(ban.reason or "", 1, 128))
            net.WriteString(string.sub(ban.admin_name or "Console", 1, 64))
            net.WriteUInt(math.max(0, tonumber(ban.expires) or 0), 32)
        end
    net.Send(client)
end

local function sendLogs(client)
    local logs = AXEL.GetLogs(150)

    net.Start("AXEL.SendLogs")
        net.WriteUInt(#logs, 8)

        for _, entry in ipairs(logs) do
            net.WriteUInt(math.max(0, tonumber(entry.time) or 0), 32)
            net.WriteString(string.sub(entry.admin_name or "Console", 1, 64))
            net.WriteString(string.sub(entry.action or "", 1, 32))
            net.WriteString(string.sub(entry.detail or "", 1, 160))
        end
    net.Send(client)
end

local function sendRanks(client)
    local names = {}
    for name in next, AXEL.Ranks do
        if (name ~= "__migrated__") then names[#names + 1] = name end
    end
    table.sort(names, function(a, b)
        return AXEL.GetImmunity(a) > AXEL.GetImmunity(b)
    end)

    net.Start("AXEL.SendRanks")
        net.WriteUInt(#names, 8)

        for _, name in ipairs(names) do
            local rank = AXEL.Ranks[name]
            net.WriteString(name)
            net.WriteString(rank.inherit or "")
            net.WriteUInt(math.Clamp(rank.immunity or 0, 0, 255), 8)

            -- Only permissions this rank sets explicitly. Inherited ones are
            -- resolved client-side from the chain, so the editor can show the
            -- difference between "granted here" and "granted by a parent".
            local explicit = {}
            for permission, value in next, rank.permissions or {} do
                explicit[#explicit + 1] = {name = permission, value = value}
            end

            net.WriteUInt(math.min(#explicit, 255), 8)
            for index = 1, math.min(#explicit, 255) do
                net.WriteString(explicit[index].name)
                net.WriteBool(explicit[index].value == true)
            end
        end

        -- The catalogue of every permission the server knows about, so the
        -- editor can list ones a rank has not set yet.
        local catalogue = {}
        for permission, info in next, AXEL.Permissions or {} do
            catalogue[#catalogue + 1] = {name = permission, category = info.category or "General"}
        end
        table.sort(catalogue, function(a, b)
            if (a.category ~= b.category) then return a.category < b.category end
            return a.name < b.name
        end)

        net.WriteUInt(math.min(#catalogue, 255), 8)
        for index = 1, math.min(#catalogue, 255) do
            net.WriteString(catalogue[index].name)
            net.WriteString(catalogue[index].category)
        end
    net.Send(client)
end

net.Receive("AXEL.RequestData", function(_, client)
    if (not IsValid(client)) then return end

    -- Read the payload before any early return. A net message must be fully
    -- consumed or the next read on this channel desyncs.
    local kind = net.ReadString()

    if (onCooldown(dataCooldown, client, kind, 0.3)) then return end

    -- Opening the menu at all requires the menu permission.
    if (not client:AXELHasPermission("menu")) then return end

    if (kind == "players") then sendPlayers(client)
    elseif (kind == "bans") then sendBans(client)
    elseif (kind == "ranks") then sendRanks(client)
    elseif (kind == "logs") then
        if (not client:AXELHasPermission("viewlogs")) then return end
        sendLogs(client)
    end
end)

net.Receive("AXEL.RunCommand", function(_, client)
    if (not IsValid(client)) then return end

    -- Consume the whole message first, whatever we decide afterwards.
    local name = net.ReadString()
    local count = math.Clamp(net.ReadUInt(4), 0, 8)

    local args = {}
    for index = 1, count do
        args[index] = string.sub(net.ReadString(), 1, 200)
    end

    if (onCooldown(actionCooldown, client, "command", 0.2)) then return end

    -- Same path as chat and console. No shortcuts.
    local success, message = AXEL.RunCommand(client, name, args)

    if (success) then
        AXEL.Announce(client, message)
    elseif (message) then
        client:ChatPrint("[Axel] " .. message)
    end
end)

hook.Add("PlayerDisconnected", "AXEL.NetCleanup", function(client)
    dataCooldown[client] = nil
    actionCooldown[client] = nil
end)
