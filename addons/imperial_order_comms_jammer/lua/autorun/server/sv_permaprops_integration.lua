local function IMPERIAL_ORDERJammerMapSupported()
    local mapName = string.lower(game.GetMap() or "")
    return mapName == "rp_victory_destroyer"
        or mapName == "rp_stardestroyer_v2_7"
        or mapName == "rp_stardestroyer_v2_7_inf"
end

if not IMPERIAL_ORDERJammerMapSupported() then return end

-- PermaProps persistence for the retained jammer entities only.
local function RegisterJammerHandlers()
    if not PermaProps then return false end
    if not PermaProps.SpecialENTSSave then return false end
    if not PermaProps.SpecialENTSSpawn then return false end

    PermaProps.SpecialENTSSave["comms_jammer"] = function(ent)
        return {Other = {Active = ent:GetJammerActive() and "1" or "0"}}
    end

    PermaProps.SpecialENTSSpawn["comms_jammer"] = function(ent, data)
        ent:Spawn()
        ent:Activate()

        local other = (data and data.Other) or data
        if other and other.Active == "0" then
            ent:SetJammerActive(false)
            ent:SetDeactivating(false)
            ent:SetHealth(ent:GetMaxHealth())
            ent:SetHealthRatio(1)
            if IMPERIAL_ORDER_CommsJammerFailure then
                IMPERIAL_ORDER_CommsJammerFailure.RestoreDisabled(ent, false)
            end
        end

        ent.PermaProps = true
        timer.Simple(1, function()
            if IsValid(ent) and CommsJammer_OnSpawned then
                CommsJammer_OnSpawned(ent)
            end
        end)
        return true
    end

    PermaProps.SpecialENTSSave["comms_jammer_armored"] = function(ent)
        return {Other = {Active = ent:GetJammerActive() and "1" or "0"}}
    end

    PermaProps.SpecialENTSSpawn["comms_jammer_armored"] = function(ent, data)
        ent:Spawn()
        ent:Activate()

        local other = (data and data.Other) or data
        if other and other.Active == "0" then
            ent:SetJammerActive(false)
            ent:SetDeactivating(false)
            ent:SetHealth(ent:GetMaxHealth())
            ent:SetHealthRatio(1)
            if IMPERIAL_ORDER_CommsJammerFailure then
                IMPERIAL_ORDER_CommsJammerFailure.RestoreDisabled(ent, true)
            end
        end

        ent.PermaProps = true
        timer.Simple(1, function()
            if IsValid(ent) and CommsJammer_OnSpawned then
                CommsJammer_OnSpawned(ent)
            end
        end)
        return true
    end

    MsgC(Color(0, 255, 100), "[Imperial Order Jammer] ", color_white, "PermaProps handlers registered.\n")
    return true
end

RegisterJammerHandlers()
hook.Add("InitPostEntity", "IMPERIAL_ORDERJammer_PermaProps", RegisterJammerHandlers)
timer.Simple(3, RegisterJammerHandlers)
