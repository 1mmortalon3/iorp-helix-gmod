if SERVER then
    AddCSLuaFile()
end

IMPERIAL_ORDER_TACTICAL_INSERTION = IMPERIAL_ORDER_TACTICAL_INSERTION or {}
local CONFIG = IMPERIAL_ORDER_TACTICAL_INSERTION

-- Change these values before restarting the server.
if CONFIG.RespawnDelay == nil then CONFIG.RespawnDelay = 15 end
if CONFIG.RespawnProtection == nil then CONFIG.RespawnProtection = 5 end
if CONFIG.ConsumeOnRespawn == nil then CONFIG.ConsumeOnRespawn = false end
if CONFIG.RemoveOnCharacterSwitch == nil then CONFIG.RemoveOnCharacterSwitch = true end
if CONFIG.AdminOnly == nil then CONFIG.AdminOnly = false end
if CONFIG.MaxPlacementDistance == nil then CONFIG.MaxPlacementDistance = 140 end
if CONFIG.MinimumSurfaceNormal == nil then CONFIG.MinimumSurfaceNormal = 0.55 end
if CONFIG.BeaconHealth == nil then CONFIG.BeaconHealth = 125 end
if CONFIG.AllowedFactions == nil then CONFIG.AllowedFactions = {} end

local function getTimerName(client)
    local identifier = client:SteamID64()

    if not identifier or identifier == "0" then
        identifier = "bot_" .. client:EntIndex()
    end

    return "IMPERIAL_ORDER.TacticalInsertion.Respawn." .. identifier
end

local function notify(client, message)
    if not IsValid(client) then return end

    if ix and client.Notify then
        client:Notify(message)
    else
        client:ChatPrint(message)
    end
end

function IMPERIAL_ORDER_TacticalInsertionHasCharacter(client)
    if not IsValid(client) then return false end

    -- Sandbox and non-Helix gamemodes do not have characters.
    if not ix or not client.GetCharacter then
        return true
    end

    return client:GetCharacter() ~= nil
end

local function factionAllowed(client)
    if not CONFIG.AllowedFactions or #CONFIG.AllowedFactions == 0 then
        return true
    end

    if not ix or not client.GetCharacter then
        return true
    end

    local character = client:GetCharacter()
    if not character then return false end

    local factionIndex = character:GetFaction()
    local factionTable = ix.faction and ix.faction.indices and ix.faction.indices[factionIndex]
    local uniqueID = factionTable and factionTable.uniqueID

    for _, allowed in ipairs(CONFIG.AllowedFactions) do
        if isnumber(allowed) and allowed == factionIndex then
            return true
        end

        if isstring(allowed) and uniqueID and string.lower(allowed) == string.lower(uniqueID) then
            return true
        end
    end

    return false
end

function IMPERIAL_ORDER_TacticalInsertionCanUse(client)
    if not IsValid(client) or not client:IsPlayer() then
        return false, "Invalid player."
    end

    if CONFIG.AdminOnly and not client:IsAdmin() then
        return false, "Only administrators can use tactical insertions."
    end

    if not IMPERIAL_ORDER_TacticalInsertionHasCharacter(client) then
        return false, "Load a character before using a tactical insertion."
    end

    if not factionAllowed(client) then
        return false, "Your faction cannot use tactical insertions."
    end

    return true
end

if SERVER then
    local SAFE_OFFSETS = {
        Vector(0, 0, 10),
        Vector(34, 0, 10),
        Vector(-34, 0, 10),
        Vector(0, 34, 10),
        Vector(0, -34, 10),
        Vector(34, 34, 10),
        Vector(-34, 34, 10),
        Vector(34, -34, 10),
        Vector(-34, -34, 10)
    }

    local function findSafeSpawnPosition(client, beacon)
        local basePosition = beacon:GetPos()
        local filter = {client, beacon}

        for _, offset in ipairs(SAFE_OFFSETS) do
            local candidate = basePosition + offset
            local trace = util.TraceHull({
                start = candidate,
                endpos = candidate,
                mins = Vector(-16, -16, 0),
                maxs = Vector(16, 16, 72),
                mask = MASK_PLAYERSOLID,
                filter = filter
            })

            if not trace.StartSolid and not trace.Hit then
                return candidate
            end
        end

        return nil
    end

    local function clearInsertion(client, removeEntity)
        if not IsValid(client) then return end

        timer.Remove(getTimerName(client))
        client.IMPERIAL_ORDERTacticalInsertionRespawn = nil
        client.IMPERIAL_ORDERInsertionProtectedUntil = nil

        local beacon = client.IMPERIAL_ORDERTacticalInsertion
        client.IMPERIAL_ORDERTacticalInsertion = nil

        if removeEntity and IsValid(beacon) then
            beacon.IMPERIAL_ORDERSilentRemove = true
            beacon:Remove()
        end
    end

    function IMPERIAL_ORDER_RemoveTacticalInsertion(client, silent)
        if not IsValid(client) then return end

        local beacon = client.IMPERIAL_ORDERTacticalInsertion
        client.IMPERIAL_ORDERTacticalInsertion = nil

        if IsValid(beacon) then
            beacon.IMPERIAL_ORDERSilentRemove = silent == true
            beacon:Remove()
        end
    end

    hook.Add("PlayerDeath", "IMPERIAL_ORDER.TacticalInsertion.QueueRespawn", function(client)
        local beacon = client.IMPERIAL_ORDERTacticalInsertion
        if not IsValid(beacon) or beacon:GetInsertionOwner() ~= client then return end

        local allowed = IMPERIAL_ORDER_TacticalInsertionCanUse(client)
        if not allowed then return end

        client.IMPERIAL_ORDERTacticalInsertionRespawn = {
            beacon = beacon,
            yaw = beacon:GetAngles().y
        }

        local timerName = getTimerName(client)
        timer.Remove(timerName)
        timer.Create(timerName, math.max(0, tonumber(CONFIG.RespawnDelay) or 0), 1, function()
            if not IsValid(client) or client:Alive() then return end

            local respawnData = client.IMPERIAL_ORDERTacticalInsertionRespawn
            if not respawnData or not IsValid(respawnData.beacon) then
                client.IMPERIAL_ORDERTacticalInsertionRespawn = nil
                return
            end

            if not IMPERIAL_ORDER_TacticalInsertionHasCharacter(client) then
                client.IMPERIAL_ORDERTacticalInsertionRespawn = nil
                return
            end

            client:Spawn()
        end)
    end)

    hook.Add("PlayerSpawn", "IMPERIAL_ORDER.TacticalInsertion.ApplyRespawn", function(client)
        local respawnData = client.IMPERIAL_ORDERTacticalInsertionRespawn
        if not respawnData then return end

        timer.Remove(getTimerName(client))
        client.IMPERIAL_ORDERTacticalInsertionRespawn = nil

        timer.Simple(0, function()
            if not IsValid(client) or not client:Alive() then return end

            local beacon = respawnData.beacon
            if not IsValid(beacon) or beacon:GetInsertionOwner() ~= client then return end

            local safePosition = findSafeSpawnPosition(client, beacon)
            if not safePosition then
                notify(client, "The tactical insertion was obstructed, so the normal spawn was used.")
                return
            end

            client:SetPos(safePosition)
            client:SetEyeAngles(Angle(0, respawnData.yaw or 0, 0))
            client:SetVelocity(-client:GetVelocity())

            local protection = math.max(0, tonumber(CONFIG.RespawnProtection) or 0)
            if protection > 0 then
                client.IMPERIAL_ORDERInsertionProtectedUntil = CurTime() + protection
            end

            notify(client, "Deployed at your tactical insertion.")

            if CONFIG.ConsumeOnRespawn and IsValid(beacon) then
                beacon.IMPERIAL_ORDERSilentRemove = true
                beacon:Remove()
            end
        end)
    end)

    hook.Add("EntityTakeDamage", "IMPERIAL_ORDER.TacticalInsertion.SpawnProtection", function(target)
        if not IsValid(target) or not target:IsPlayer() then return end

        local protectedUntil = target.IMPERIAL_ORDERInsertionProtectedUntil
        if protectedUntil and protectedUntil > CurTime() then
            return true
        end

        if protectedUntil then
            target.IMPERIAL_ORDERInsertionProtectedUntil = nil
        end
    end)

    hook.Add("PlayerDisconnected", "IMPERIAL_ORDER.TacticalInsertion.Cleanup", function(client)
        clearInsertion(client, true)
    end)

    hook.Add("PlayerLoadedCharacter", "IMPERIAL_ORDER.TacticalInsertion.CharacterSwitch", function(client, character, oldCharacter)
        if not CONFIG.RemoveOnCharacterSwitch or not oldCharacter then return end

        clearInsertion(client, true)
    end)

    hook.Add("PostCleanupMap", "IMPERIAL_ORDER.TacticalInsertion.MapCleanup", function()
        for _, client in ipairs(player.GetAll()) do
            clearInsertion(client, false)
        end
    end)
end
