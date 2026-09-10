include("shared.lua")

local COL_ARMORED   = Color(255, 190, 50)
local COL_INACTIVE  = Color(160, 160, 160)
local COL_BG        = Color(8, 10, 12, 200)
local COL_WHITE     = Color(255, 255, 255, 240)
local COL_SHADOW    = Color(0, 0, 0, 160)
local haloColor     = Color(255, 120, 30)
local barColor      = Color(255, 190, 50)

local smoothHealth = {}

surface.CreateFont("CommsJammerA_Label", {
    font = "Roboto", size = 90, weight = 700, antialias = true,
})
surface.CreateFont("CommsJammerA_HP", {
    font = "Roboto", size = 70, weight = 600, antialias = true,
})

function ENT:Draw()
    self:DrawModel()

    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if self:GetPos():DistToSqr(ply:GetPos()) > 500000 then return end

    local pos = self:GetPos()
    local ang = Angle(0, (ply:GetPos() - pos):Angle().y - 90, 90)
    local active = self:GetJammerActive()
    local ratio = self:GetHealthRatio()

    local idx = self:EntIndex()
    smoothHealth[idx] = Lerp(FrameTime() * 6, smoothHealth[idx] or ratio, ratio)
    local smooth = smoothHealth[idx]

    local labelPos = pos + Vector(0, 0, 55)
    cam.Start3D2D(labelPos, ang, 0.05)
        local labelText = active and "ARMORED JAMMER" or "JAMMER [DISABLED]"
        local labelCol = active and COL_ARMORED or COL_INACTIVE

        if active then
            local pulse = 0.7 + 0.3 * math.abs(math.sin(CurTime() * 1.5))
            labelCol = Color(255, 160, 30, 180 + 75 * pulse)
        end

        draw.RoundedBox(0, -320, -30, 640, 60, COL_BG)
        draw.SimpleText(labelText, "CommsJammerA_Label", 1, 1, COL_SHADOW, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(labelText, "CommsJammerA_Label", 0, 0, labelCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        if active then
            draw.SimpleText("EXPLOSIVES / LIGHTSABER / PRESS E TO BYPASS", "DermaDefault", 0, 34, Color(200, 160, 100, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    cam.End3D2D()

    if active and smooth < 0.99 then
        local barPos = pos + Vector(0, 0, 68)
        cam.Start3D2D(barPos, ang, 0.05)
            local barW = 400
            local barH = 25
            local x = -barW / 2

            draw.RoundedBox(3, x - 2, -2, barW + 4, barH + 4, COL_BG)
            local fillW = math.max(barW * smooth, 0)
            draw.RoundedBox(2, x, 0, fillW, barH, barColor)

            local pct = math.Round(smooth * 100) .. "%"
            draw.SimpleText(pct, "CommsJammerA_HP", 1, barH / 2 + 1, COL_SHADOW, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(pct, "CommsJammerA_HP", 0, barH / 2, COL_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.End3D2D()
    end
end

function ENT:OnRemove()
    smoothHealth[self:EntIndex()] = nil
end

-- Orange pulsing halo when active
hook.Add("PreDrawHalos", "CommsJammerArmored_ActiveHalo", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local jammers = {}
    for _, ent in ipairs(ents.FindByClass("comms_jammer_armored")) do
        if IsValid(ent) and ent:GetJammerActive() then
            if ply:GetPos():DistToSqr(ent:GetPos()) < 1000000 then
                table.insert(jammers, ent)
            end
        end
    end

    if #jammers > 0 then
        local pulse = 0.4 + 0.6 * math.abs(math.sin(CurTime() * 1.5))
        haloColor.a = 255 * pulse
        halo.Add(jammers, haloColor, 3, 3, 1, true, false)
    end
end)
