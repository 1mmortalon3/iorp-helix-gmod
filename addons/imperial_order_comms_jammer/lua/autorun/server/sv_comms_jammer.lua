local function IMPERIAL_ORDERJammerMapSupported()
    local mapName = string.lower(game.GetMap() or "")
    return mapName == "rp_victory_destroyer"
        or mapName == "rp_stardestroyer_v2_7"
        or mapName == "rp_stardestroyer_v2_7_inf"
end

if not IMPERIAL_ORDERJammerMapSupported() then return end

--[[
    Communications Jammer System
    Server-Side Management

    Tracks jammer entities and tool-applied jammers.
    When ANY jammer is active, comms go offline.
    Operates as a standalone extension for the RDV communications addon.
]]

util.AddNetworkString("CommsJammer_OpenMinigame")
util.AddNetworkString("CommsJammer_MinigameResult")
util.AddNetworkString("CommsJammer_SyncToolJammers")
util.AddNetworkString("CommsJammer_RemoveAll")
util.AddNetworkString("CommsJammer_ClientState")

-- Allow jammer tool on all entities (override prop protection for admins)
hook.Add("CanTool", "!!!CommsJammer_AllowTool", function(ply, tr, toolname)
    if toolname == "comms_jammer" and IsValid(tr.Entity) and ply:IsAdmin() then
        return true
    end
end)

-- Active jammer entities
local jammerEntities = {}
-- Tool-applied jammers: { [entIndex] = true }
local toolJammers = {}
-- Health for tool-jammed props: { [entIndex] = { hp = n, maxHp = n } }
local toolJammerHealth = {}
-- Is jamming currently active?
local jamming = false
-- Forward declaration (used before definition)
local SyncToolJammers

-- ConVar for prop jammer health
CreateConVar("sv_commsjammer_prop_health", 300, {FCVAR_NOTIFY, FCVAR_ARCHIVE}, "HP for props with jammer applied", 50, 5000)
local cv_prop_health = GetConVar("sv_commsjammer_prop_health")

-- Detect entity type
local function GetEntityType(ent)
    if not IsValid(ent) then return "unknown" end
    local cls = ent:GetClass()

    -- LVS vehicles (class prefix or .LVS flag from base entity)
    if string.StartWith(cls, "lvs_") or ent.LVS then return "vehicle_lvs" end
    -- LFS vehicles (class prefix or lunasflightschool prefix)
    if string.StartWith(cls, "lfs_") or string.StartWith(cls, "lunasflightschool_") then return "vehicle_lfs" end
    -- Simfphys
    if string.StartWith(cls, "gmod_sent_vehicle") or ent.IsSimfphyscar then return "vehicle_sim" end
    -- Generic vehicles
    if ent:IsVehicle() then return "vehicle" end
    -- Props
    if string.StartWith(cls, "prop_physics") or cls == "prop_dynamic" then return "prop" end

    return "entity"
end

--[[---------------------------------------------
    State Calculation
-----------------------------------------------]]
local function RecalcJamState()
    -- Check jammer entities
    for idx, ent in pairs(jammerEntities) do
        if not IsValid(ent) then
            jammerEntities[idx] = nil
        elseif ent:GetJammerActive() then
            jamming = true
            return
        end
    end

    -- Check tool-applied jammers
    for idx, _ in pairs(toolJammers) do
        local ent = Entity(idx)
        if not IsValid(ent) then
            toolJammers[idx] = nil
        else
            jamming = true
            return
        end
    end

    jamming = false
end

-- Expose current jammer state
function CommsJammer_IsJamming()
    return jamming
end

--[[---------------------------------------------
    Broadcast jam state to clients
-----------------------------------------------]]
local function BroadcastJamState()
    net.Start("CommsJammer_ClientState")
        net.WriteBool(jamming)
    net.Broadcast()

    if IMPERIAL_ORDER_CommsInterferenceSetPersistent then
        IMPERIAL_ORDER_CommsInterferenceSetPersistent(
            "imperial_order_active_jammer",
            jamming,
            jamming and "communications jamming field" or "jammer field cleared"
        )
    end

    if NCS_COMMUNICATIONS then
        net.Start("RDV_COMMUNICATIONS_ToggleComms")
            net.WriteBool(not jamming)
        net.Broadcast()
    end
end

--[[---------------------------------------------
    Entity Jammer Callbacks
-----------------------------------------------]]
function CommsJammer_OnSpawned(ent)
    if not IsValid(ent) then return end
    jammerEntities[ent:EntIndex()] = ent

    local wasJamming = jamming
    RecalcJamState()

    if not wasJamming and jamming then
        BroadcastJamState()
    end
end

function CommsJammer_OnDeactivated(ent)
    if not IsValid(ent) then return end

    local wasJamming = jamming
    RecalcJamState()

    if wasJamming and not jamming then
        BroadcastJamState()
    end
end

function CommsJammer_OnRemoved(ent)
    if not ent then return end
    jammerEntities[ent:EntIndex()] = nil

    local wasJamming = jamming
    RecalcJamState()

    if wasJamming and not jamming then
        BroadcastJamState()
    end
end

--[[---------------------------------------------
    Tool-Applied Jammers
-----------------------------------------------]]
function CommsJammer_ApplyToEntity(ent)
    if not IsValid(ent) then return false end
    local idx = ent:EntIndex()
    if toolJammers[idx] then return false end

    toolJammers[idx] = true

    -- Props get health so they can be destroyed
    local entType = GetEntityType(ent)
    if entType == "prop" then
        local maxHp = cv_prop_health:GetInt()
        toolJammerHealth[idx] = { hp = maxHp, maxHp = maxHp }

        -- Enable damage on the prop
        ent:SetHealth(maxHp)
        ent:SetMaxHealth(maxHp)
    end

    -- Hook entity removal (capture idx at apply time for safety)
    ent:CallOnRemove("CommsJammer_ToolCleanup", function()
        toolJammers[idx] = nil
        toolJammerHealth[idx] = nil
        local wasJamming = jamming
        RecalcJamState()
        if wasJamming and not jamming then
            BroadcastJamState()
        end
    end)

    local wasJamming = jamming
    RecalcJamState()

    if not wasJamming and jamming then
        BroadcastJamState()
    end

    SyncToolJammers()
    return true
end

function CommsJammer_RemoveFromEntity(ent)
    if not IsValid(ent) then return false end
    local idx = ent:EntIndex()
    if not toolJammers[idx] then return false end

    toolJammers[idx] = nil
    toolJammerHealth[idx] = nil
    ent:RemoveCallOnRemove("CommsJammer_ToolCleanup")

    local wasJamming = jamming
    RecalcJamState()

    if wasJamming and not jamming then
        BroadcastJamState()
    end

    SyncToolJammers()
    return true
end

--[[---------------------------------------------
    Prop Health System
    Props with jammers take damage. When HP
    reaches 0, the prop is destroyed.
-----------------------------------------------]]
hook.Add("EntityTakeDamage", "CommsJammer_PropDamage", function(ent, dmginfo)
    if not IsValid(ent) then return end
    local idx = ent:EntIndex()
    if not toolJammerHealth[idx] then return end

    local info = toolJammerHealth[idx]
    info.hp = math.max(info.hp - dmginfo:GetDamage(), 0)

    -- Update networked health for client-side display
    ent:SetHealth(math.ceil(info.hp))

    if info.hp <= 0 then
        -- Destruction effects
        local pos = ent:LocalToWorld(ent:OBBCenter())
        local fx = EffectData()
        fx:SetOrigin(pos)
        fx:SetMagnitude(1)
        fx:SetScale(1)
        fx:SetRadius(2)
        util.Effect("cball_explode", fx, true, true)

        local sparks = EffectData()
        sparks:SetOrigin(pos)
        sparks:SetNormal(Vector(0, 0, 1))
        sparks:SetMagnitude(1)
        sparks:SetScale(0.5)
        sparks:SetRadius(1)
        util.Effect("ElectricSpark", sparks, true, true)

        local explosion = EffectData()
        explosion:SetOrigin(pos)
        explosion:SetScale(1.25)
        explosion:SetMagnitude(1.25)
        explosion:SetRadius(2.5)
        util.Effect("Explosion", explosion, true, true)

        sound.Play("ambient/explosions/explode_8.wav", pos, 82, 108, 0.75)
        util.ScreenShake(pos, 4, 105, 0.6, 425)

        if IMPERIAL_ORDER_CommsInterferenceBurst then
            IMPERIAL_ORDER_CommsInterferenceBurst(10, "jammer emitter overload")
        end

        -- Defer removal to next tick (unsafe to remove during damage processing)
        timer.Simple(0, function()
            if IsValid(ent) then
                ent:Remove()
            end
        end)
    end
end)

-- Expose entity type function for client sync
function CommsJammer_GetEntityType(ent)
    return GetEntityType(ent)
end

SyncToolJammers = function(target)
    local list = {}
    for idx, _ in pairs(toolJammers) do
        local ent = Entity(idx)
        if IsValid(ent) then
            table.insert(list, ent)
        else
            toolJammers[idx] = nil
        end
    end

    net.Start("CommsJammer_SyncToolJammers")
        net.WriteUInt(#list, 8)
        for _, ent in ipairs(list) do
            net.WriteEntity(ent)
            net.WriteString(GetEntityType(ent))
            net.WriteString(string.GetFileFromFilename(ent:GetModel() or "unknown"))
        end
    if target then
        net.Send(target)
    else
        net.Broadcast()
    end
end

--[[---------------------------------------------
    Minigame Completion
-----------------------------------------------]]
net.Receive("CommsJammer_MinigameResult", function(len, ply)
    if not IsValid(ply) then return end

    local ent = net.ReadEntity()
    local success = net.ReadBool()

    if not IsValid(ent) then return end
    local cls = ent:GetClass()
    if cls ~= "comms_jammer" and cls ~= "comms_jammer_armored" then return end
    if not ent:GetJammerActive() then return end
    if not ent:GetDeactivating() then return end

    -- Verify this is the player who initiated the deactivation
    if ent.DeactivatingPlayer ~= ply then return end

    -- Verify player is close enough
    if ply:GetPos():Distance(ent:GetPos()) > 200 then
        ent:SetDeactivating(false)
        ent.DeactivatingPlayer = nil
        return
    end

    if success then
        -- Successful terminal bypass deactivates either jammer type.
        ent:DeactivateJammer()
        ent.DeactivatingPlayer = nil
        ply:ChatPrint("[Comms] Jammer successfully deactivated!")
    else
        ent:SetDeactivating(false)
        ent.DeactivatingPlayer = nil
        ply:ChatPrint("[Comms] Deactivation failed. Try again.")
    end
end)

--[[---------------------------------------------
    Remove All Jammers (admin command)
-----------------------------------------------]]
local removeAllCooldown = 0
net.Receive("CommsJammer_RemoveAll", function(len, ply)
    if not IsValid(ply) then return end
    if not ply:IsAdmin() then
        ply:ChatPrint("[Comms] Admin only.")
        return
    end
    if removeAllCooldown > CurTime() then return end
    removeAllCooldown = CurTime() + 5

    -- Remove jammer entities
    for idx, ent in pairs(jammerEntities) do
        if IsValid(ent) then
            ent:Remove()
        end
    end
    jammerEntities = {}

    -- Remove tool-applied jammers
    for idx, _ in pairs(toolJammers) do
        local ent = Entity(idx)
        if IsValid(ent) then
            ent:RemoveCallOnRemove("CommsJammer_ToolCleanup")
        end
    end
    toolJammers = {}
    toolJammerHealth = {}

    jamming = false
    BroadcastJamState()
    SyncToolJammers()

    for _, p in ipairs(player.GetHumans()) do
        p:ChatPrint("[Comms] All jammers removed by admin.")
    end
end)

--[[---------------------------------------------
    RDV Communications Integration Hook
    Block comms when jamming is active.
-----------------------------------------------]]
-- Deferred: only register after RDV finishes init
local function RegisterJammerHook()
    hook.Add("RDV_COMMS_CanAccessChannel", "CommsJammer_BlockAccess", function(ply, channel)
        if not NCS_COMMUNICATIONS or not NCS_COMMUNICATIONS.LIST then return end
        if not IsValid(ply) then return end
        if jamming then
            return false
        end
    end)
end
hook.Add("RDV_COMMS_Loaded", "CommsJammer_DeferHook", function()
    timer.Simple(1, RegisterJammerHook)
end)
-- Fallback
timer.Simple(15, function()
    if NCS_COMMUNICATIONS and NCS_COMMUNICATIONS.LIST then RegisterJammerHook() end
end)

--[[---------------------------------------------
    Periodic enforcer while jamming
-----------------------------------------------]]
timer.Create("CommsJammer_Enforce", 2, 0, function()
    if not jamming then return end

    -- Enforce client-side jammer state
    net.Start("CommsJammer_ClientState")
        net.WriteBool(true)
    net.Broadcast()

    if NCS_COMMUNICATIONS then
        net.Start("RDV_COMMUNICATIONS_ToggleComms")
            net.WriteBool(false)
        net.Broadcast()
    end
end)

--[[---------------------------------------------
    Player join sync
-----------------------------------------------]]
hook.Add("PlayerInitialSpawn", "CommsJammer_SyncState", function(ply)
    timer.Simple(4, function()
        if not IsValid(ply) then return end
        SyncToolJammers(ply)

        net.Start("CommsJammer_ClientState")
            net.WriteBool(jamming)
        net.Send(ply)
    end)
end)
