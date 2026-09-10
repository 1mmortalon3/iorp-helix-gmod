AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/lt_c/sci_fi/holo_tablet.mdl")
    self:SetSolid(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    self:SetCollisionGroup(COLLISION_GROUP_WEAPON)

    self:PhysicsInit(SOLID_VPHYSICS)

    local physicsObject = self:GetPhysicsObject()
    if IsValid(physicsObject) then
        physicsObject:EnableMotion(false)
        physicsObject:Sleep()
    end

    local config = IMPERIAL_ORDER_TACTICAL_INSERTION or {}
    self:SetHealth(math.max(1, tonumber(config.BeaconHealth) or 125))
    self:EmitSound("npc/turret_floor/ping.wav", 60, 115)
end

function ENT:OnTakeDamage(damageInfo)
    if self:GetHealth() <= 0 then return end

    self:SetHealth(self:Health() - damageInfo:GetDamage())

    if self:Health() > 0 then
        self:EmitSound("buttons/button10.wav", 55, 95)
        return
    end

    local effect = EffectData()
    effect:SetOrigin(self:GetPos() + Vector(0, 0, 8))
    effect:SetMagnitude(2)
    effect:SetScale(1)
    effect:SetRadius(4)
    util.Effect("Sparks", effect, true, true)

    self:EmitSound("ambient/energy/zap9.wav", 75, 95)
    self:Remove()
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if activator ~= self:GetInsertionOwner() and not activator:IsAdmin() then return end

    if activator == self:GetInsertionOwner() then
        activator.IMPERIAL_ORDERTacticalInsertion = nil
    end

    self:Remove()
end

function ENT:OnRemove()
    local owner = self:GetInsertionOwner()
    if IsValid(owner) and owner.IMPERIAL_ORDERTacticalInsertion == self then
        owner.IMPERIAL_ORDERTacticalInsertion = nil
    end

    if not self.IMPERIAL_ORDERSilentRemove then
        self:EmitSound("buttons/button19.wav", 55, 90)
    end
end
