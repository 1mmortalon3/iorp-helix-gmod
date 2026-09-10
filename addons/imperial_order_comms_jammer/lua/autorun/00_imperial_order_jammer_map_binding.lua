IMPERIAL_ORDERCommsJammer = IMPERIAL_ORDERCommsJammer or {}

IMPERIAL_ORDERCommsJammer.SupportedMaps = {
    ["rp_victory_destroyer"] = true,
    ["rp_stardestroyer_v2_7"] = true,
    ["rp_stardestroyer_v2_7_inf"] = true,
}

function IMPERIAL_ORDERCommsJammer.IsSupportedMap(mapName)
    mapName = string.lower(mapName or game.GetMap() or "")
    return IMPERIAL_ORDERCommsJammer.SupportedMaps[mapName] == true
end

if SERVER then
    AddCSLuaFile()
    hook.Add("InitPostEntity", "IMPERIAL_ORDERCommsJammer_MapStatus", function()
        local mapName = string.lower(game.GetMap() or "")
        if IMPERIAL_ORDERCommsJammer.IsSupportedMap(mapName) then
            MsgC(Color(185, 25, 30), "[Imperial Order Jammer] ", color_white,
                "Bound to " .. mapName .. ". Training/recruitment terminal remains a separate add-on.\n")
        end
    end)
end
