AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local FALLBACK_MODEL = "models/props_combine/combine_interface003.mdl"
local THINK_INTERVAL = 0.25

util.PrecacheModel("models/capturepoint/white_none/base.mdl")
util.PrecacheModel("models/capturepoint/red/imperial/imperial_r.mdl")
util.PrecacheModel("models/capturepoint/blue/rebels/rebels_b.mdl")

local function SetSide(entity, prefix, side)
    local CP = IMPERIAL_ORDER_COMMAND_POSTS
    side = side or {
        key = CP.NeutralKey,
        name = CP.NeutralName,
        color = CP.NeutralColor
    }

    entity["Set" .. prefix .. "Key"](entity, side.key)
    entity["Set" .. prefix .. "Name"](entity, side.name)
    entity["Set" .. prefix .. "Color"](entity, CP.ColorToVector(side.color))
end

function ENT:ApplySideModel(sideKey)
    local CP = IMPERIAL_ORDER_COMMAND_POSTS
    local model = CP.GetSideModel(sideKey)

    if not util.IsValidModel(model) then
        model = FALLBACK_MODEL
    end

    if self:GetModel() ~= model then
        self:SetModel(model)
    end

    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_VPHYSICS)

    local physics = self:GetPhysicsObject()
    if IsValid(physics) then
        physics:EnableMotion(false)
    end
end

function ENT:Initialize()
    local CP = IMPERIAL_ORDER_COMMAND_POSTS

    self:SetUseType(SIMPLE_USE)

    if self:GetPostName() == "" then self:SetPostName("COMMAND POST") end
    if self:GetCaptureRadius() <= 0 then self:SetCaptureRadius(300) end
    if self:GetCaptureDuration() <= 0 then self:SetCaptureDuration(20) end
    if self:GetOwnerKey() == "" then
        SetSide(self, "Owner", {
            key = CP.NeutralKey,
            name = CP.NeutralName,
            color = CP.NeutralColor
        })
    end

    self:ApplySideModel(self:GetOwnerKey())

    self:SetCaptureProgress(0)
    self:SetCapturingKey("")
    self:SetCapturingName("")
    self:SetCapturingColor(CP.ColorToVector(CP.NeutralColor))
    self:SetStatusText("SECURE")
    self:SetContested(false)
    self:SetCommandPostEnabled(true)
    self:SetColor(IMPERIAL_ORDER_COMMAND_POSTS.VectorToColor(self:GetOwnerColor()))

    self.IMPERIAL_ORDERNextCaptureThink = CurTime() + THINK_INTERVAL
end

function ENT:SetOwnerSide(side, announce)
    local CP = IMPERIAL_ORDER_COMMAND_POSTS
    SetSide(self, "Owner", side)
    self:ApplySideModel(side.key)
    self:SetColor(side.color or CP.NeutralColor)
    self:SetCaptureProgress(0)
    self:SetCapturingKey("")
    self:SetCapturingName("")
    self:SetCapturingColor(CP.ColorToVector(CP.NeutralColor))
    self:SetContested(false)
    self:SetStatusText("SECURE")

    if announce then
        CP.Announce(self:GetPostName(), side.name, side.color)
        hook.Run("ImperialOrderCommandPostCaptured", self, side.key, side.name)
    end

    if CP.QueueSave then CP.QueueSave() end
end

function ENT:ResetNeutral()
    local CP = IMPERIAL_ORDER_COMMAND_POSTS
    self:SetOwnerSide({
        key = CP.NeutralKey,
        name = CP.NeutralName,
        color = CP.NeutralColor
    }, false)
end

function ENT:GetPresentSides()
    local CP = IMPERIAL_ORDER_COMMAND_POSTS
    local sides = {}

    for _, client in ipairs(ents.FindInSphere(self:GetPos(), self:GetCaptureRadius())) do
        if CP.IsCaptureEligible(client) then
            local side = CP.GetPlayerSide(client)
            if side then
                sides[side.key] = sides[side.key] or {
                    key = side.key,
                    name = side.name,
                    color = side.color,
                    count = 0
                }
                sides[side.key].count = sides[side.key].count + 1
            end
        end
    end

    return sides
end

local function CountTableEntries(tbl)
    local count = 0
    local onlyValue

    for _, value in pairs(tbl) do
        count = count + 1
        onlyValue = value
    end

    return count, onlyValue
end

function ENT:UpdateCapture()
    if not self:GetCommandPostEnabled() then
        self:SetStatusText("OFFLINE")
        return
    end

    local CP = IMPERIAL_ORDER_COMMAND_POSTS
    local sideCount, activeSide = CountTableEntries(self:GetPresentSides())

    if sideCount > 1 then
        self:SetContested(true)
        self:SetStatusText("CONTESTED")
        return
    end

    self:SetContested(false)

    if sideCount == 0 then
        local progress = math.max(self:GetCaptureProgress() - (THINK_INTERVAL / 8), 0)
        self:SetCaptureProgress(progress)
        self:SetStatusText(progress > 0 and "SIGNAL FADING" or "SECURE")

        if progress <= 0 then
            self:SetCapturingKey("")
            self:SetCapturingName("")
            self:SetCapturingColor(CP.ColorToVector(CP.NeutralColor))
        end
        return
    end

    if activeSide.key == self:GetOwnerKey() then
        local progress = math.max(self:GetCaptureProgress() - (THINK_INTERVAL / 3), 0)
        self:SetCaptureProgress(progress)
        self:SetStatusText(progress > 0 and "DEFENDING" or "SECURE")

        if progress <= 0 then
            self:SetCapturingKey("")
            self:SetCapturingName("")
            self:SetCapturingColor(CP.ColorToVector(CP.NeutralColor))
        end
        return
    end

    if self:GetCapturingKey() ~= activeSide.key then
        self:SetCapturingKey(activeSide.key)
        self:SetCapturingName(activeSide.name)
        self:SetCapturingColor(CP.ColorToVector(activeSide.color))
        self:SetCaptureProgress(0)
    end

    local captureDuration = math.max(self:GetCaptureDuration(), 1)
    local playerMultiplier = math.Clamp(activeSide.count, 1, 3)
    local progress = self:GetCaptureProgress() + (THINK_INTERVAL / captureDuration) * playerMultiplier

    self:SetCaptureProgress(math.Clamp(progress, 0, 1))
    self:SetStatusText("CAPTURING")

    if progress >= 1 then
        self:SetOwnerSide(activeSide, true)
    end
end

function ENT:Think()
    if (self.IMPERIAL_ORDERNextCaptureThink or 0) <= CurTime() then
        self.IMPERIAL_ORDERNextCaptureThink = CurTime() + THINK_INTERVAL
        self:UpdateCapture()
    end

    self:NextThink(CurTime() + THINK_INTERVAL)
    return true
end

function ENT:OnRemove()
    local CP = IMPERIAL_ORDER_COMMAND_POSTS
    if CP and CP.QueueSave and not CP.Restoring then
        CP.QueueSave()
    end
end
