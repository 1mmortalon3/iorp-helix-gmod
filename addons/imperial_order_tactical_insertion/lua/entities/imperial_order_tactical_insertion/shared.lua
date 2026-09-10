ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Tactical Insertion"
ENT.Category = "Imperial Order"
ENT.Spawnable = false
ENT.AdminOnly = false

function ENT:SetupDataTables()
    self:NetworkVar("Entity", 0, "InsertionOwner")
end
