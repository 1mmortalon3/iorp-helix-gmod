TOOL.Category   = "[IMPERIAL_ORDER] Star Destroyer Systems"
TOOL.Name       = "Comms Jammer Tool"
TOOL.Command    = nil
TOOL.ConfigName = ""

TOOL.Information = {
    { name = "left" },
    { name = "right" },
}

if CLIENT then
    language.Add("tool.comms_jammer.name",  "Comms Jammer Tool")
    language.Add("tool.comms_jammer.desc",  "Apply or remove communications jamming effect on entities.")
    language.Add("tool.comms_jammer.left",  "Apply jammer to entity")
    language.Add("tool.comms_jammer.right", "Remove jammer from entity")
    language.Add("tool.comms_jammer.0",     "Left-click: Apply jammer | Right-click: Remove jammer")
end

-- Blocked classes (already jammers or special entities)
local BLOCKED = {
    ["comms_jammer"] = true,
    ["comms_jammer_armored"] = true,
}

function TOOL:LeftClick(trace)
    if not trace.Hit or not IsValid(trace.Entity) then return false end
    if trace.Entity:IsPlayer() then return false end
    if trace.Entity:IsWorld() then return false end
    if BLOCKED[trace.Entity:GetClass()] then
        if SERVER then self:GetOwner():ChatPrint("[Jammer Tool] Cannot apply to this entity type.") end
        return false
    end

    -- Admin only
    if SERVER and not self:GetOwner():IsAdmin() then
        self:GetOwner():ChatPrint("[Jammer Tool] Admin only.")
        return false
    end

    if CLIENT then return true end

    local ent = trace.Entity

    if not CommsJammer_ApplyToEntity then
        self:GetOwner():ChatPrint("[Jammer Tool] Jammer system not loaded. Check server console for errors.")
        return true
    end

    local success = CommsJammer_ApplyToEntity(ent)
    if success then
        self:GetOwner():ChatPrint("[Jammer Tool] Jammer applied to " .. tostring(ent:GetClass()) .. " — comms now jammed.")
    else
        self:GetOwner():ChatPrint("[Jammer Tool] Entity already has a jammer applied.")
    end

    return true
end

function TOOL:RightClick(trace)
    if not trace.Hit or not IsValid(trace.Entity) then return false end
    if trace.Entity:IsPlayer() then return false end
    if trace.Entity:IsWorld() then return false end

    -- Admin only
    if SERVER and not self:GetOwner():IsAdmin() then
        self:GetOwner():ChatPrint("[Jammer Tool] Admin only.")
        return false
    end

    if CLIENT then return true end

    local ent = trace.Entity

    if not CommsJammer_RemoveFromEntity then
        self:GetOwner():ChatPrint("[Jammer Tool] Jammer system not loaded.")
        return true
    end

    local success = CommsJammer_RemoveFromEntity(ent)
    if success then
        self:GetOwner():ChatPrint("[Jammer Tool] Jammer removed from " .. tostring(ent:GetClass()) .. ".")
    else
        self:GetOwner():ChatPrint("[Jammer Tool] No jammer on this entity.")
    end

    return true
end

function TOOL:Reload(trace)
    return false
end

-- Tool panel in Q menu with jammer list
function TOOL.BuildCPanel(panel)
    panel:AddControl("Header", {
        Text = "Comms Jammer Tool",
        Description = "Left-click to apply a jammer to an entity. Right-click to remove. Blocked on dedicated jammer entities.",
    })

    -- Remove all jammers button
    local removeBtn = vgui.Create("DButton")
    removeBtn:SetText("Remove All Jammers (Admin)")
    removeBtn:SetTall(28)
    removeBtn.DoClick = function()
        net.Start("CommsJammer_RemoveAll")
        net.SendToServer()
    end
    panel:AddItem(removeBtn)

    panel:Help("")

    -- Active Jammers List
    local listHeader = vgui.Create("DLabel")
    listHeader:SetText("Active Jammers:")
    listHeader:SetFont("DermaDefaultBold")
    listHeader:SetTextColor(Color(220, 180, 100))
    listHeader:SetTall(20)
    panel:AddItem(listHeader)

    local listPanel = vgui.Create("DListView")
    listPanel:SetTall(180)
    listPanel:SetMultiSelect(false)
    listPanel:AddColumn("#"):SetFixedWidth(30)
    listPanel:AddColumn("Type"):SetFixedWidth(80)
    listPanel:AddColumn("Model")

    -- Populate list
    local function RefreshList()
        listPanel:Clear()
        local num = 0

        -- Entity jammers
        for _, ent in ipairs(ents.FindByClass("comms_jammer")) do
            if IsValid(ent) and ent:GetJammerActive() then
                num = num + 1
                local mdl = string.GetFileFromFilename(ent:GetModel() or "unknown")
                listPanel:AddLine(num, "Standard", mdl)
            end
        end

        for _, ent in ipairs(ents.FindByClass("comms_jammer_armored")) do
            if IsValid(ent) and ent:GetJammerActive() then
                num = num + 1
                local mdl = string.GetFileFromFilename(ent:GetModel() or "unknown")
                listPanel:AddLine(num, "Armored", mdl)
            end
        end

        -- Tool-applied jammers (from synced list with type info)
        if CommsJammer_GetToolList then
            local TYPE_LABELS = {
                vehicle_lvs = "LVS Vehicle",
                vehicle_lfs = "LFS Vehicle",
                vehicle_sim = "Simfphys",
                vehicle = "Vehicle",
                prop = "Prop",
                entity = "Entity",
            }

            for _, entry in ipairs(CommsJammer_GetToolList()) do
                local ent = entry.ent
                if IsValid(ent) then
                    num = num + 1
                    local typeLabel = TYPE_LABELS[entry.type] or "Tool"
                    local mdl = entry.model or string.GetFileFromFilename(ent:GetModel() or "unknown")
                    listPanel:AddLine(num, typeLabel, mdl)
                end
            end
        end

        if num == 0 then
            listPanel:AddLine("-", "None", "No active jammers")
        end
    end

    RefreshList()
    panel:AddItem(listPanel)

    -- Refresh button
    local refreshBtn = vgui.Create("DButton")
    refreshBtn:SetText("Refresh List")
    refreshBtn:SetTall(24)
    refreshBtn.DoClick = RefreshList
    panel:AddItem(refreshBtn)
end
