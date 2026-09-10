include("shared.lua")

local glowMaterial = Material("sprites/glow04_noz")

function ENT:Draw()
    self:DrawModel()

    local pulse = 18 + math.sin(CurTime() * 5) * 4
    render.SetMaterial(glowMaterial)
    render.DrawSprite(self:GetPos() + self:GetUp() * 10, pulse, pulse, Color(210, 25, 25, 220))

    local owner = self:GetInsertionOwner()
    local ownerName = IsValid(owner) and owner:Nick() or "UNASSIGNED"
    local angle = LocalPlayer():EyeAngles()
    angle:RotateAroundAxis(angle:Forward(), 90)
    angle:RotateAroundAxis(angle:Right(), 90)

    cam.Start3D2D(self:GetPos() + Vector(0, 0, 24), Angle(0, angle.y, 90), 0.08)
        draw.RoundedBox(4, -150, -30, 300, 60, Color(8, 8, 10, 225))
        surface.SetDrawColor(190, 20, 20, 240)
        surface.DrawOutlinedRect(-150, -30, 300, 60, 2)
        draw.SimpleText("TACTICAL INSERTION", "DermaLarge", 0, -8, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(ownerName, "DermaDefaultBold", 0, 15, Color(205, 205, 205), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
