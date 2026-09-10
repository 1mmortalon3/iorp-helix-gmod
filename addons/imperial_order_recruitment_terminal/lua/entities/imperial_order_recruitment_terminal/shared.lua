ENT.Base = "base_anim"
ENT.Type = "anim"

ENT.PrintName    = "Imperial Recruitment Terminal"
ENT.Category     = "[IMPERIAL_ORDER] Recruitment"
ENT.Author       = "Imperial Order"
ENT.Spawnable    = true
ENT.AdminOnly    = true

-- Keep the model path in shared.lua so both realms use one authoritative
-- value. The Lord Trilobite medium console is correctly sized at native scale.
ENT.TerminalModel = "models/lordtrilobite/starwars/isd/imp_console_medium03.mdl"
ENT.DefaultDisplayScale = 1.00
ENT.BaseUseDistance = 220

function ENT:SetupDataTables()
    self:NetworkVar("Bool",   0, "Powered")
    self:NetworkVar("Float",  0, "BootTime")
    self:NetworkVar("Float",  1, "DisplayScale")
    self:NetworkVar("Entity", 0, "ActiveUser")
    self:NetworkVar("Int",    0, "TermState")  -- 0=STANDBY, 1=BOOTING, 2=ACTIVE
end
