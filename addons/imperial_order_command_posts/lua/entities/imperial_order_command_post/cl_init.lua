include("shared.lua")

surface.CreateFont("ImperialOrderCommandPost_Title", {
    font = "Roboto",
    size = 28,
    weight = 900,
    antialias = true
})

surface.CreateFont("ImperialOrderCommandPost_Info", {
    font = "Roboto",
    size = 18,
    weight = 700,
    antialias = true
})

surface.CreateFont("ImperialOrderCommandPost_World", {
    font = "Roboto",
    size = 44,
    weight = 900,
    antialias = true
})

local function CurrentDisplayColor(entity)
    local CP = IMPERIAL_ORDER_COMMAND_POSTS
    if entity:GetCaptureProgress() > 0 and entity:GetCapturingKey() ~= "" then
        return CP.VectorToColor(entity:GetCapturingColor())
    end

    return CP.VectorToColor(entity:GetOwnerColor())
end

function ENT:Draw()
    self:DrawModel()

    local distance = LocalPlayer():GetPos():DistToSqr(self:GetPos())
    if distance > 2500000 then return end

    local position = self:LocalToWorld(Vector(0, 0, self:OBBMaxs().z + 14))
    local angle = Angle(0, LocalPlayer():EyeAngles().y - 90, 90)
    local color = CurrentDisplayColor(self)
    local progress = math.Clamp(self:GetCaptureProgress(), 0, 1)

    cam.Start3D2D(position, angle, 0.08)
        draw.RoundedBox(8, -260, -80, 520, 160, Color(8, 10, 13, 235))
        surface.SetDrawColor(color)
        surface.DrawOutlinedRect(-260, -80, 520, 160, 4)

        draw.SimpleText(self:GetPostName(), "ImperialOrderCommandPost_World", 0, -48, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("CONTROL: " .. self:GetOwnerName(), "ImperialOrderCommandPost_Info", 0, -7, Color(235, 235, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        draw.RoundedBox(3, -220, 25, 440, 20, Color(30, 32, 38, 240))
        draw.RoundedBox(3, -220, 25, 440 * progress, 20, color)
        draw.SimpleText(self:GetStatusText(), "ImperialOrderCommandPost_Info", 0, 62, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end

hook.Add("HUDPaint", "ImperialOrderCommandPost_CaptureHUD", function()
    local client = LocalPlayer()
    if not IsValid(client) then return end

    local nearest
    local nearestDistance

    for _, entity in ipairs(ents.FindByClass("imperial_order_command_post")) do
        local distance = client:GetPos():DistToSqr(entity:GetPos())
        local radius = entity:GetCaptureRadius()
        if distance <= radius * radius and (not nearestDistance or distance < nearestDistance) then
            nearest = entity
            nearestDistance = distance
        end
    end

    if not IsValid(nearest) then return end

    local width = math.min(ScrW() * 0.42, 520)
    local height = 92
    local x = (ScrW() - width) * 0.5
    local y = ScrH() * 0.075
    local color = CurrentDisplayColor(nearest)
    local progress = math.Clamp(nearest:GetCaptureProgress(), 0, 1)

    draw.RoundedBox(6, x, y, width, height, Color(7, 9, 12, 235))
    surface.SetDrawColor(color)
    surface.DrawOutlinedRect(x, y, width, height, 2)

    draw.SimpleText(nearest:GetPostName(), "ImperialOrderCommandPost_Title", ScrW() * 0.5, y + 22, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(nearest:GetStatusText() .. "  |  " .. nearest:GetOwnerName(), "ImperialOrderCommandPost_Info", ScrW() * 0.5, y + 49, Color(235, 235, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    draw.RoundedBox(2, x + 18, y + 70, width - 36, 10, Color(28, 30, 35, 255))
    draw.RoundedBox(2, x + 18, y + 70, (width - 36) * progress, 10, color)
end)
