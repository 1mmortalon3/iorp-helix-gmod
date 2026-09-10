TOOL.Category = "Imperial Order"
TOOL.Name = "Command Post"
TOOL.Command = nil
TOOL.ConfigName = ""

TOOL.ClientConVar = {
    post_name = "COMMAND POST A",
    capture_radius = "300",
    capture_time = "20",
    starting_owner = "neutral"
}

if CLIENT then
    language.Add("tool.imperial_order_command_post.name", "Imperial Order Command Post")
    language.Add("tool.imperial_order_command_post.desc", "Place persistent faction capture points for Imperial Order events.")
    language.Add("tool.imperial_order_command_post.0", "Left-click: place | Right-click: remove | Reload: reset neutral")
end

local function IsAdministrator(client)
    return IsValid(client) and (client:IsAdmin() or client:IsSuperAdmin())
end

function TOOL:LeftClick(trace)
    if not trace.Hit then return false end
    if CLIENT then return true end

    local client = self:GetOwner()
    if not IsAdministrator(client) then return false end

    local entity = ents.Create("imperial_order_command_post")
    if not IsValid(entity) then return false end

    local angle = trace.HitNormal:Angle()
    angle:RotateAroundAxis(angle:Right(), -90)

    entity:SetPos(trace.HitPos + trace.HitNormal * 3)
    entity:SetAngles(Angle(0, angle.y, 0))
    entity:Spawn()
    entity:Activate()

    local postName = string.Trim(self:GetClientInfo("post_name"))
    entity:SetPostName(postName ~= "" and string.upper(postName) or "COMMAND POST")
    entity:SetCaptureRadius(math.Clamp(self:GetClientNumber("capture_radius", 300), 100, 1500))
    entity:SetCaptureDuration(math.Clamp(self:GetClientNumber("capture_time", 20), 3, 300))

    local ownerKey = self:GetClientInfo("starting_owner")
    local key, name, color = IMPERIAL_ORDER_COMMAND_POSTS.GetSideByKey(ownerKey)
    entity:SetOwnerSide({key = key, name = name, color = color}, false)

    undo.Create("Imperial Order Command Post")
        undo.AddEntity(entity)
        undo.SetPlayer(client)
    undo.Finish()

    IMPERIAL_ORDER_COMMAND_POSTS.QueueSave()
    client:ChatPrint("[Command Posts] Placed " .. entity:GetPostName() .. ".")
    return true
end

function TOOL:RightClick(trace)
    if CLIENT then return true end

    local client = self:GetOwner()
    if not IsAdministrator(client) then return false end
    if not IsValid(trace.Entity) or trace.Entity:GetClass() ~= "imperial_order_command_post" then return false end

    local postName = trace.Entity:GetPostName()
    trace.Entity:Remove()
    IMPERIAL_ORDER_COMMAND_POSTS.QueueSave()
    client:ChatPrint("[Command Posts] Removed " .. postName .. ".")
    return true
end

function TOOL:Reload(trace)
    if CLIENT then return true end

    local client = self:GetOwner()
    if not IsAdministrator(client) then return false end
    if not IsValid(trace.Entity) or trace.Entity:GetClass() ~= "imperial_order_command_post" then return false end

    trace.Entity:ResetNeutral()
    IMPERIAL_ORDER_COMMAND_POSTS.QueueSave()
    client:ChatPrint("[Command Posts] Reset " .. trace.Entity:GetPostName() .. " to neutral.")
    return true
end

function TOOL.BuildCPanel(panel)
    panel:AddControl("Header", {
        Text = "Imperial Order Command Posts",
        Description = "Persistent event capture points. Multiple friendly players capture faster; opposing sides contest the post."
    })

    panel:TextEntry("Post Name", "imperial_order_command_post_post_name")
    panel:NumSlider("Capture Radius", "imperial_order_command_post_capture_radius", 100, 1500, 0)
    panel:NumSlider("Base Capture Time", "imperial_order_command_post_capture_time", 3, 300, 0)

    local owner = panel:ComboBox("Starting Owner", "imperial_order_command_post_starting_owner")
    owner:AddChoice("Neutral", "neutral")
    owner:AddChoice("Galactic Empire", "imperial")
    owner:AddChoice("Rebel Alliance", "rebel_alliance")

    panel:Help("Left-click to place a post.")
    panel:Help("Right-click a post to remove it.")
    panel:Help("Press reload while aiming at a post to reset it.")
end
