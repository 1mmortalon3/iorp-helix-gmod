if SERVER then
    AddCSLuaFile()
end

SWEP.PrintName = "Tactical Insertion"
SWEP.Author = "Imperial Order"
SWEP.Instructions = "Primary: place insertion | Secondary: remove insertion"
SWEP.Category = "Imperial Order"

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Base = "weapon_base"
SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/v_hands.mdl"
SWEP.WorldModel = "models/weapons/v_hands.mdl"
SWEP.ViewModelFOV = 54
SWEP.HoldType = "slam"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true
SWEP.Slot = 4
SWEP.SlotPos = 1

local function notify(client, message)
    if ix and client.Notify then
        client:Notify(message)
    else
        client:ChatPrint(message)
    end
end

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 1)

    if CLIENT then return end

    local client = self:GetOwner()
    if not IsValid(client) then return end

    local allowed, reason = IMPERIAL_ORDER_TacticalInsertionCanUse(client)
    if not allowed then
        notify(client, reason or "You cannot use a tactical insertion.")
        return
    end

    if client:InVehicle() then
        notify(client, "Exit the vehicle before placing a tactical insertion.")
        return
    end

    local config = IMPERIAL_ORDER_TACTICAL_INSERTION or {}
    local maximumDistance = math.max(32, tonumber(config.MaxPlacementDistance) or 140)
    local trace = util.TraceLine({
        start = client:GetShootPos(),
        endpos = client:GetShootPos() + client:GetAimVector() * maximumDistance,
        filter = client,
        mask = MASK_SOLID
    })

    if not trace.Hit or trace.HitSky then
        notify(client, "Aim at a nearby solid surface.")
        return
    end

    if trace.HitNormal.z < (tonumber(config.MinimumSurfaceNormal) or 0.55) then
        notify(client, "The tactical insertion must be placed on a mostly flat surface.")
        return
    end

    local blocked = util.TraceHull({
        start = trace.HitPos + trace.HitNormal * 4,
        endpos = trace.HitPos + trace.HitNormal * 4,
        mins = Vector(-14, -14, 0),
        maxs = Vector(14, 14, 16),
        mask = MASK_SOLID,
        filter = client
    })

    if blocked.StartSolid then
        notify(client, "There is not enough room to place the tactical insertion.")
        return
    end

    if IsValid(client.IMPERIAL_ORDERTacticalInsertion) then
        client.IMPERIAL_ORDERTacticalInsertion.IMPERIAL_ORDERSilentRemove = true
        client.IMPERIAL_ORDERTacticalInsertion:Remove()
    end

    local beacon = ents.Create("imperial_order_tactical_insertion")
    if not IsValid(beacon) then
        notify(client, "The tactical insertion could not be created.")
        return
    end

    local angle = trace.HitNormal:Angle()
    angle:RotateAroundAxis(angle:Right(), -90)
    angle:RotateAroundAxis(trace.HitNormal, client:EyeAngles().y)

    beacon:SetPos(trace.HitPos + trace.HitNormal * 2)
    beacon:SetAngles(angle)
    beacon:SetInsertionOwner(client)
    beacon:SetCreator(client)
    beacon:Spawn()
    beacon:Activate()

    client.IMPERIAL_ORDERTacticalInsertion = beacon

    self:EmitSound("buttons/button14.wav", 65, 105)
    notify(client, "Tactical insertion deployed.")
end

function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + 0.5)

    if CLIENT then return end

    local client = self:GetOwner()
    if not IsValid(client) then return end

    if not IsValid(client.IMPERIAL_ORDERTacticalInsertion) then
        notify(client, "You do not have an active tactical insertion.")
        return
    end

    IMPERIAL_ORDER_RemoveTacticalInsertion(client, false)
    self:EmitSound("buttons/button19.wav", 60, 100)
    notify(client, "Tactical insertion removed.")
end
