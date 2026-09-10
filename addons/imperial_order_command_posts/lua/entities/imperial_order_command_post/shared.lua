ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Imperial Order Command Post"
ENT.Author = "Imperial Order"
ENT.Category = "[IMPERIAL ORDER] Command Posts"
ENT.Spawnable = false
ENT.AdminOnly = true

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "PostName")
    self:NetworkVar("String", 1, "OwnerKey")
    self:NetworkVar("String", 2, "OwnerName")
    self:NetworkVar("String", 3, "CapturingKey")
    self:NetworkVar("String", 4, "CapturingName")
    self:NetworkVar("String", 5, "StatusText")

    self:NetworkVar("Float", 0, "CaptureProgress")
    self:NetworkVar("Float", 1, "CaptureRadius")
    self:NetworkVar("Float", 2, "CaptureDuration")

    self:NetworkVar("Vector", 0, "OwnerColor")
    self:NetworkVar("Vector", 1, "CapturingColor")

    self:NetworkVar("Bool", 0, "Contested")
    self:NetworkVar("Bool", 1, "CommandPostEnabled")
end
