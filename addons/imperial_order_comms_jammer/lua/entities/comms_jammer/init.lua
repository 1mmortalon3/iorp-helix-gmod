AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- Imperial Order jammer-console model.
-- The same console remains in place after disable/destruction because this
-- model pack does not provide a matching destroyed variant.
local MDL_ACTIVE    = "models/lordtrilobite/starwars/isd/imp_console_small01.mdl"
local MDL_DESTROYED = MDL_ACTIVE

function ENT:Initialize()
    local mapName = string.lower(game.GetMap() or "")
    if mapName ~= "rp_victory_destroyer"
        and mapName ~= "rp_stardestroyer_v2_7"
        and mapName ~= "rp_stardestroyer_v2_7_inf" then
        SafeRemoveEntityDelayed(self, 0)
        return
    end

    self:SetModel(MDL_ACTIVE)
    self:SetColor(Color(255, 255, 255, 255))
    self:SetMaterial("")
    self:SetUseType(SIMPLE_USE)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)

    self:SetHealth(350)
    self:SetMaxHealth(350)
    self:SetHealthRatio(1)
    self:SetJammerActive(true)
    self:SetDeactivating(false)

    self.IMPERIAL_ORDERFailureActive = false
    self.IMPERIAL_ORDERFailureDestroyed = false
    self.IMPERIAL_ORDERExplosionPlayed = false

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
    end

    if CommsJammer_OnSpawned then
        CommsJammer_OnSpawned(self)
    end
end

function ENT:OnRemove()
    if CommsJammer_OnRemoved then
        CommsJammer_OnRemoved(self)
    end
end

function ENT:OnTakeDamage(dmginfo)
    if not self:GetJammerActive() then return end

    local newHp = math.Clamp(self:Health() - dmginfo:GetDamage(), 0, self:GetMaxHealth())
    self:SetHealth(newHp)
    self:SetHealthRatio(newHp / self:GetMaxHealth())

    if newHp <= 0 then
        self:DestroyJammer()
    end
end

function ENT:DestroyJammer()
    if not self:GetJammerActive() then return end

    self:SetJammerActive(false)
    self:SetDeactivating(false)
    self.DeactivatingPlayer = nil

    -- Keep the Imperial console in place and make it non-blocking briefly
    -- while the electrical failure sequence plays.
    self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    self:SetModel(MDL_DESTROYED)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
    end

    if IMPERIAL_ORDER_CommsJammerFailure then
        IMPERIAL_ORDER_CommsJammerFailure.BeginDestroyed(self, false)
    end

    if IMPERIAL_ORDER_CommsInterferenceBurst then
        IMPERIAL_ORDER_CommsInterferenceBurst(12, "communications jammer detonation")
    end

    timer.Simple(0.8, function()
        if IsValid(self) then
            self:SetCollisionGroup(COLLISION_GROUP_NONE)
        end
    end)

    -- Keep the disabled console in place for persistent map decoration.
    self:SetHealth(self:GetMaxHealth())
    self:SetHealthRatio(1)

    if CommsJammer_OnDeactivated then
        CommsJammer_OnDeactivated(self)
    end
end

function ENT:DeactivateJammer()
    if not self:GetJammerActive() then return end

    self:SetJammerActive(false)
    self:SetDeactivating(false)
    self.DeactivatingPlayer = nil

    self:SetHealth(self:GetMaxHealth())
    self:SetHealthRatio(1)

    if IMPERIAL_ORDER_CommsJammerFailure then
        IMPERIAL_ORDER_CommsJammerFailure.BeginDisabled(self, false)
    end

    if CommsJammer_OnDeactivated then
        CommsJammer_OnDeactivated(self)
    end
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    if not self:GetJammerActive() then
        activator:ChatPrint("[Jammer] This jammer is already disabled.")
        return
    end


    if self:GetDeactivating() then
        activator:ChatPrint("[Jammer] Deactivation already in progress.")
        return
    end

    self:SetDeactivating(true)
    self.DeactivatingPlayer = activator

    local jammerRef = self
    timer.Simple(12, function()
        if IsValid(jammerRef) and jammerRef:GetDeactivating() then
            jammerRef:SetDeactivating(false)
            jammerRef.DeactivatingPlayer = nil
        end
    end)

    net.Start("CommsJammer_OpenMinigame")
        net.WriteEntity(self)
    net.Send(activator)
end

function ENT:Think()
    if self:GetJammerActive() then
        local ed = EffectData()
        ed:SetOrigin(self:LocalToWorld(self:OBBCenter()) + Vector(0, 0, 10))
        ed:SetScale(0.3)
        util.Effect("smoking", ed)

        self:NextThink(CurTime() + 3)
    else
        if IMPERIAL_ORDER_CommsJammerFailure then
            IMPERIAL_ORDER_CommsJammerFailure.Think(self, false)
        end

        self:NextThink(CurTime() + 0.35)
    end

    return true
end
