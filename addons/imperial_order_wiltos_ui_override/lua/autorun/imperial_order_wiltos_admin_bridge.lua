-- Imperial Order - wiltOS admin permission/command bridge (V264)
-- Keeps the custom UI command admin-only while synchronizing the caller's
-- actual Garry's Mod usergroup with wiltOS's separate permission table.

local NET_REQUEST = "IMPERIAL_ORDER_WOS_AdminReq"
local NET_OPEN = "IMPERIAL_ORDER_WOS_AdminOpen"
local NET_MESSAGE = "IMPERIAL_ORDER_WOS_AdminMsg"
local NET_STATUS = "IMPERIAL_ORDER_WOS_AdminStatus"

if SERVER then
    AddCSLuaFile()

    util.AddNetworkString(NET_REQUEST)
    util.AddNetworkString(NET_OPEN)
    util.AddNetworkString(NET_MESSAGE)
    util.AddNetworkString(NET_STATUS)

    local function sendMessage(client, ok, text)
        if not IsValid(client) then return end

        net.Start(NET_MESSAGE)
            net.WriteBool(ok == true)
            net.WriteString(tostring(text or ""))
        net.Send(client)
    end

    local function isIMPERIAL_ORDERAdmin(client)
        return IsValid(client) and (client:IsAdmin() or client:IsSuperAdmin())
    end

    local function prepareWiltOSPermission(client)
        if not (wOS and wOS.ALCS and wOS.ALCS.Config) then
            return false, "wiltOS ALCS is not loaded on the server"
        end

        local permissions = wOS.ALCS.Config.CanAccessAdminMenu
        if not istable(permissions) then
            permissions = {}
            wOS.ALCS.Config.CanAccessAdminMenu = permissions
        end

        local group = tostring(client:GetUserGroup() or ""):Trim()
        if group == "" then
            return false, "Your server admin group could not be detected"
        end

        -- wiltOS examples use lowercase group names. Set both forms so custom
        -- admin systems with case-sensitive group names remain compatible.
        permissions[group] = true
        permissions[string.lower(group)] = true

        return true, group
    end

    local function requestOpen(client, clientHasNativeCommand)
        if not isIMPERIAL_ORDERAdmin(client) then
            sendMessage(client, false, "Administrator access is required")
            return
        end

        local permissionReady, groupOrError = prepareWiltOSPermission(client)
        if not permissionReady then
            sendMessage(client, false, groupOrError)
            return
        end

        local serverCommands = concommand.GetTable and concommand.GetTable() or {}
        local serverHasNativeCommand = isfunction(serverCommands["wos_openadminmenu"])

        if not serverHasNativeCommand and not clientHasNativeCommand then
            sendMessage(client, false, "wos_openadminmenu is not registered. The wiltOS admin module is missing or failed to load")
            return
        end

        net.Start(NET_OPEN)
            net.WriteBool(serverHasNativeCommand)
            net.WriteString(tostring(groupOrError or "admin"))
        net.Send(client)
    end

    net.Receive(NET_REQUEST, function(_, client)
        requestOpen(client, net.ReadBool())
    end)

    net.Receive(NET_STATUS, function(_, client)
        if not IsValid(client) then return end

        local serverCommands = concommand.GetTable and concommand.GetTable() or {}
        local nativeLoaded = isfunction(serverCommands["wos_openadminmenu"])
        local alcsLoaded = wOS and wOS.ALCS and wOS.ALCS.Config ~= nil
        local group = tostring(client:GetUserGroup() or "unknown")
        local allowed = false

        if alcsLoaded and istable(wOS.ALCS.Config.CanAccessAdminMenu) then
            allowed = wOS.ALCS.Config.CanAccessAdminMenu[group] == true
                or wOS.ALCS.Config.CanAccessAdminMenu[string.lower(group)] == true
        end

        sendMessage(client, true, string.format(
            "wiltOS status: group=%s, gmodAdmin=%s, ALCS=%s, nativeServerCommand=%s, wiltOSPermission=%s",
            group,
            tostring(isIMPERIAL_ORDERAdmin(client)),
            tostring(alcsLoaded == true),
            tostring(nativeLoaded == true),
            tostring(allowed == true)
        ))
    end)

    -- Server-console/player-console fallback. The client command normally uses
    -- the net request above so it can verify both client and server realms.
    concommand.Add("imperial_order_wiltos_admin_sv", function(client)
        if not IsValid(client) then
            print("[Imperial Order wiltOS] Run imperial_order_wiltos_admin from an in-game admin client.")
            return
        end

        requestOpen(client, false)
    end)

    return
end

local function nativeClientCommandExists()
    local commands = concommand.GetTable and concommand.GetTable() or {}
    return isfunction(commands["wos_openadminmenu"])
end

function IMPERIAL_ORDER_RequestWiltOSAdminMenu()
    local client = LocalPlayer()
    if not IsValid(client) or not client:IsAdmin() then
        if IMPERIAL_ORDER_WILTOS_UI and IMPERIAL_ORDER_WILTOS_UI.Notify then
            IMPERIAL_ORDER_WILTOS_UI.Notify("Administrator access is required", NOTIFY_ERROR)
        else
            notification.AddLegacy("Administrator access is required", NOTIFY_ERROR, 4)
        end
        return false
    end

    net.Start(NET_REQUEST)
        net.WriteBool(nativeClientCommandExists())
    net.SendToServer()
    return true
end

net.Receive(NET_OPEN, function()
    local serverHasNativeCommand = net.ReadBool()
    local group = net.ReadString()

    -- RunConsoleCommand reaches a server command when one is registered, or
    -- executes the native client command when that is how this ALCS build ships.
    RunConsoleCommand("wos_openadminmenu")

    timer.Simple(0, function()
        local text = "wiltOS admin request accepted for group '" .. tostring(group) .. "'"
        if IMPERIAL_ORDER_WILTOS_UI and IMPERIAL_ORDER_WILTOS_UI.Notify then
            IMPERIAL_ORDER_WILTOS_UI.Notify(text, NOTIFY_GENERIC, 4)
        else
            notification.AddLegacy(text, NOTIFY_GENERIC, 4)
        end

        if not serverHasNativeCommand and not nativeClientCommandExists() then
            chat.AddText(Color(226, 60, 67), "[Imperial Order wiltOS] Native admin command disappeared before it could run.")
        end
    end)
end)

net.Receive(NET_MESSAGE, function()
    local ok = net.ReadBool()
    local text = net.ReadString()
    local kind = ok and NOTIFY_GENERIC or NOTIFY_ERROR

    if IMPERIAL_ORDER_WILTOS_UI and IMPERIAL_ORDER_WILTOS_UI.Notify then
        IMPERIAL_ORDER_WILTOS_UI.Notify(text, kind, 6)
    else
        notification.AddLegacy(text, kind, 6)
    end

    chat.AddText(ok and Color(74, 190, 116) or Color(226, 60, 67), "[Imperial Order wiltOS] ", color_white, text)
end)

concommand.Add("imperial_order_wiltos_admin_status", function()
    net.Start(NET_STATUS)
    net.SendToServer()

    print(string.format(
        "[Imperial Order wiltOS] client: UI=%s, ALCS=%s, nativeClientCommand=%s, group=%s, admin=%s",
        tostring(IMPERIAL_ORDER_WILTOS_UI ~= nil),
        tostring(wOS and wOS.ALCS ~= nil),
        tostring(nativeClientCommandExists()),
        IsValid(LocalPlayer()) and tostring(LocalPlayer():GetUserGroup()) or "invalid",
        IsValid(LocalPlayer()) and tostring(LocalPlayer():IsAdmin()) or "false"
    ))
end)
