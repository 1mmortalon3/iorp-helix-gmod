ENT.Base = "base_anim"
ENT.Type = "anim"

ENT.PrintName    = "Communications Jammer"
ENT.Category     = "[IMPERIAL_ORDER] Star Destroyer Systems"
ENT.Author       = "Imperial Order"
ENT.Spawnable    = true
ENT.AdminOnly    = true
ENT.RenderGroup  = RENDERGROUP_BOTH

function ENT:SetupDataTables()
    self:NetworkVar("Bool",  0, "JammerActive")
    self:NetworkVar("Bool",  1, "Deactivating") -- minigame in progress
    self:NetworkVar("Float", 0, "HealthRatio")
end
