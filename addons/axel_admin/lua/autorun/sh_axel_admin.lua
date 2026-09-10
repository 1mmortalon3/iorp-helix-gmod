--[[
    Axel Admin Menu
    =============================

    A full admin mod: ranks, permissions, bans, commands, logging, and a CAMI
    provider. Replaces SAM.

    Load order matters. sh_core defines the namespace everything else hangs off,
    sv_storage must open the database before sv_ranks reads from it, and the
    CAMI provider registers last so usergroups exist before it advertises them.
]]

AXEL = AXEL or {}
AXEL.Version = "1.4.1-axel"
AXEL.Folder = "axel"

local function shared(path)
    if (SERVER) then AddCSLuaFile(AXEL.Folder .. "/" .. path) end
    include(AXEL.Folder .. "/" .. path)
end

local function server(path)
    if (SERVER) then include(AXEL.Folder .. "/" .. path) end
end

local function client(path)
    if (SERVER) then
        AddCSLuaFile(AXEL.Folder .. "/" .. path)
    else
        include(AXEL.Folder .. "/" .. path)
    end
end

shared("sh_core.lua")
shared("sh_commands.lua")
shared("sh_extended.lua")
shared("sh_integrations.lua")

-- Palettes are shared: the server validates ids and the client paints with them.
-- Must follow sh_commands, which owns RegisterCommand and RegisterPermission.
shared("sh_themes.lua")

server("sv_upgrade.lua")
server("sv_storage.lua")
server("sv_mysql.lua")
server("sv_ranks.lua")
server("sv_bans.lua")
server("sv_commands.lua")
server("sv_cami.lua")
server("sv_net.lua")
server("sv_themes.lua")

client("cl_theme.lua")
client("cl_appearance.lua")
client("cl_menu.lua")

if (SERVER) then
    MsgC(Color(218, 177, 83), "[Axel] ", Color(210, 213, 218),
        "Administration " .. AXEL.Version .. " loaded.\n")
end
