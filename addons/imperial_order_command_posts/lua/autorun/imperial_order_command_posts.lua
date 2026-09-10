IMPERIAL_ORDER_COMMAND_POSTS = IMPERIAL_ORDER_COMMAND_POSTS or {}
local CP = IMPERIAL_ORDER_COMMAND_POSTS

CP.Version = "1.3.1"
CP.NeutralKey = "neutral"
CP.NeutralName = "NEUTRAL"
CP.NeutralColor = Color(150, 155, 165)

CP.SideModels = {
    neutral = "models/capturepoint/white_none/base.mdl",
    imperial = "models/capturepoint/red/imperial/imperial_r.mdl",
    rebel_alliance = "models/capturepoint/blue/rebels/rebels_b.mdl"
}

-- Set an exact Helix faction unique ID here to force it onto an event side.
-- Example: CP.FactionOverrides["event_rebels"] = "rebel_alliance"
CP.FactionOverrides = CP.FactionOverrides or {}

CP.SideDefinitions = {
    imperial = {
        name = "GALACTIC EMPIRE",
        color = Color(190, 30, 35),
        matches = {
            "imperial",
            "stormtrooper",
            "501st",
            "inferno",
            "purge",
            "emperor",
            "inquisitor",
            "royal_guard"
        }
    },
    rebel_alliance = {
        name = "REBEL ALLIANCE",
        color = Color(50, 115, 210),
        matches = {
            "the_rebels",
            "rebel",
            "alliance",
            "insurgent",
            "resistance"
        }
    }
}

-- Keep command posts saved by version 1.0 compatible with the renamed side.
CP.SideAliases = {
    the_rebels = "rebel_alliance"
}

local function Normalize(value)
    return string.lower(string.Trim(tostring(value or "")))
end

function CP.ColorToVector(color)
    color = color or CP.NeutralColor
    return Vector(color.r / 255, color.g / 255, color.b / 255)
end

function CP.VectorToColor(vector)
    vector = vector or Vector(0.6, 0.6, 0.65)
    return Color(
        math.Clamp(math.floor(vector.x * 255), 0, 255),
        math.Clamp(math.floor(vector.y * 255), 0, 255),
        math.Clamp(math.floor(vector.z * 255), 0, 255)
    )
end

function CP.GetSideByKey(sideKey)
    sideKey = Normalize(sideKey)
    sideKey = CP.SideAliases[sideKey] or sideKey

    if sideKey == "" or sideKey == CP.NeutralKey then
        return CP.NeutralKey, CP.NeutralName, CP.NeutralColor
    end

    local definition = CP.SideDefinitions[sideKey]
    if definition then
        return sideKey, definition.name or string.upper(sideKey), definition.color or color_white
    end

    -- Unknown and retired sides are neutral in the two-faction system.
    return CP.NeutralKey, CP.NeutralName, CP.NeutralColor
end

function CP.GetSideModel(sideKey)
    sideKey = Normalize(sideKey)
    sideKey = CP.SideAliases[sideKey] or sideKey

    return CP.SideModels[sideKey] or CP.SideModels[CP.NeutralKey]
end

local function GetFactionData(client)
    if not IsValid(client) or not client:IsPlayer() then return nil end

    if ix and client.GetCharacter then
        local character = client:GetCharacter()
        if character and character.GetFaction and ix.faction and ix.faction.indices then
            local faction = ix.faction.indices[character:GetFaction()]
            if faction then return faction end
        end
    end

    local teamIndex = client:Team()
    return {
        uniqueID = Normalize(team.GetName(teamIndex)),
        name = team.GetName(teamIndex),
        color = team.GetColor(teamIndex)
    }
end

function CP.GetPlayerSide(client)
    local faction = GetFactionData(client)
    if not faction then return nil end

    local factionKey = Normalize(faction.uniqueID or faction.name)
    local factionName = tostring(faction.name or factionKey)
    local searchText = factionKey .. " " .. Normalize(factionName)
    local override = Normalize(CP.FactionOverrides[factionKey])

    if override ~= "" then
        override = CP.SideAliases[override] or override
        local key, name, color = CP.GetSideByKey(override)
        return {
            key = key,
            name = name,
            color = color
        }
    end

    for sideKey, definition in pairs(CP.SideDefinitions) do
        for _, fragment in ipairs(definition.matches or {}) do
            if string.find(searchText, Normalize(fragment), 1, true) then
                return {
                    key = sideKey,
                    name = definition.name or factionName,
                    color = definition.color or faction.color or color_white
                }
            end
        end
    end

    -- Command posts are a two-faction objective. Unrelated factions neither
    -- capture nor contest them.
    return nil
end

function CP.IsCaptureEligible(client)
    if not IsValid(client) or not client:IsPlayer() then return false end
    if not client:Alive() then return false end
    if client:GetMoveType() == MOVETYPE_NOCLIP then return false end

    if ix and client.GetCharacter and not client:GetCharacter() then
        return false
    end

    return CP.GetPlayerSide(client) ~= nil
end

if SERVER then
    AddCSLuaFile()
    util.AddNetworkString("ImperialOrderCommandPost_Announcement")

    function CP.Announce(postName, sideName, color)
        color = color or color_white

        net.Start("ImperialOrderCommandPost_Announcement")
            net.WriteString(tostring(postName or "Command Post"))
            net.WriteString(tostring(sideName or CP.NeutralName))
            net.WriteColor(color)
        net.Broadcast()
    end
else
    net.Receive("ImperialOrderCommandPost_Announcement", function()
        local postName = net.ReadString()
        local sideName = net.ReadString()
        local color = net.ReadColor()

        chat.AddText(
            Color(190, 30, 35), "[IMPERIAL ORDER] ",
            Color(230, 230, 235), postName .. " captured by ",
            color, sideName,
            Color(230, 230, 235), "."
        )

        surface.PlaySound("buttons/button14.wav")
    end)
end
