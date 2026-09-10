AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local MDL_ARMORED = "models/kingpommes/starwars/emperors_tower/guard_console.mdl"

function ENT:Initialize()
    local mapName = string.lower(game.GetMap() or "")
    if mapName ~= "rp_victory_destroyer"
        and mapName ~= "rp_stardestroyer_v2_7"
        and mapName ~= "rp_stardestroyer_v2_7_inf" then
        SafeRemoveEntityDelayed(self, 0)
        return
    end

    self:SetModel(MDL_ARMORED)
    self:SetColor(Color(255, 255, 255, 255))
    self:SetMaterial("")
    self:SetUseType(SIMPLE_USE)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)

    self:SetHealth(2000)
    self:SetMaxHealth(2000)
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

-- The armored relay only accepts explosive or lightsaber damage.
function ENT:OnTakeDamage(dmginfo)
    if not self:GetJammerActive() then return end

    local isExplosive = dmginfo:IsExplosionDamage()
    local isLightsaber = false
    local attacker = dmginfo:GetAttacker()

    if IsValid(attacker) and attacker:IsPlayer() then
        local wep = attacker:GetActiveWeapon()
        if IsValid(wep) then
            isLightsaber = string.find(string.lower(wep:GetClass()), "lightsaber", 1, true) ~= nil
        end
    end

    if not isExplosive and not isLightsaber then return end

    local newHp = math.Clamp(self:Health() - dmginfo:GetDamage(), 0, self:GetMaxHealth())
    self:SetHealth(newHp)
    self:SetHealthRatio(newHp / self:GetMaxHealth())

    local ratio = newHp / self:GetMaxHealth()
    local tint = math.floor(80 + 175 * ratio)
    self:SetColor(Color(tint, tint, tint, 255))

    if newHp <= 0 then
        self:DestroyJammer()
    end
end

function ENT:DestroyJammer()
    if not self:GetJammerActive() then return end

    self:SetJammerActive(false)
    self:SetDeactivating(false)
    self.DeactivatingPlayer = nil

    if IMPERIAL_ORDER_CommsJammerFailure then
        IMPERIAL_ORDER_CommsJammerFailure.BeginDestroyed(self, true)
    end

    if IMPERIAL_ORDER_CommsInterferenceBurst then
        IMPERIAL_ORDER_CommsInterferenceBurst(12, "communications jammer detonation")
    end

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
        IMPERIAL_ORDER_CommsJammerFailure.BeginDisabled(self, true)
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
    timer.Simple(20, function()
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
        ed:SetOrigin(self:LocalToWorld(self:OBBCenter()) + Vector(0, 0, 15))
        ed:SetScale(0.4)
        util.Effect("smoking", ed)

        self:NextThink(CurTime() + 2.5)
    else
        if IMPERIAL_ORDER_CommsJammerFailure then
            IMPERIAL_ORDER_CommsJammerFailure.Think(self, true)
        end

        self:NextThink(CurTime() + 0.3)
    end

    return true
end
