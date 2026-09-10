local UI = IMPERIAL_ORDER_WILTOS_UI
local A = UI.Adapter

local function clearPanel(panel)
    if not IsValid(panel) then return end
    for _, child in ipairs(panel:GetChildren()) do child:Remove() end
end

local function materialFrom(value)
    if not value then return nil end
    if type(value) == "IMaterial" then return value end
    if isstring(value) and value ~= "" then return Material(value, "smooth") end
    return value
end

local function iconForSkill(tree, tier, skill, data)
    local icons = wOS and wOS.TreeIcons
    local icon = icons and icons[tree] and icons[tree][tier] and icons[tree][tier][skill] and icons[tree][tier][skill].Icon
    return materialFrom(icon or (data and data.Icon))
end

local function iconForTree(name, data)
    local icons = wOS and wOS.TreeIcons
    return materialFrom(icons and icons[name] and icons[name].MainIcon or (data and data.TreeIcon))
end

function UI.CloseMain()
    UI.SafeRemove(UI.Frame)
    UI.Frame = nil
    UI.SelectedSkill = nil
    gui.EnableScreenClicker(false)
end

function UI.ToggleMain(tab)
    if IsValid(UI.Frame) then
        UI.CloseMain()
        return
    end
    UI.OpenMain(tab)
end

local function makeStatCard(parent, title, valueFunc, subtitle)
    local card = vgui.Create("DPanel", parent)
    card:Dock(LEFT)
    card:SetWide(UI.Scale(170))
    card:DockMargin(0, 0, UI.Scale(10), 0)
    card.Paint = function(self, w, h)
        UI.DrawPanel(0, 0, w, h, UI.Colors.PanelSoft, UI.Scale(3))
        UI.DrawAccentLine(0, 0, UI.Scale(4), h)
        draw.SimpleText(title, "IMPERIAL_ORDER.WOS.SmallBold", UI.Scale(14), UI.Scale(13), UI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(tostring(valueFunc()), "IMPERIAL_ORDER.WOS.Title", UI.Scale(14), h - UI.Scale(13), UI.Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
        if subtitle then draw.SimpleText(subtitle, "IMPERIAL_ORDER.WOS.Small", w - UI.Scale(10), h - UI.Scale(11), UI.Colors.TextDark, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM) end
    end
    return card
end

local function buildOverview(content)
    clearPanel(content)

    local title = vgui.Create("DPanel", content)
    title:Dock(TOP)
    title:SetTall(UI.Scale(70))
    title.Paint = function(self, w, h)
        draw.SimpleText("COMBAT PROGRESSION", "IMPERIAL_ORDER.WOS.Title", 0, UI.Scale(4), UI.Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("Live data from the installed wiltOS Sentinel progression system", "IMPERIAL_ORDER.WOS.Body", 0, UI.Scale(42), UI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    local stats = vgui.Create("DPanel", content)
    stats:Dock(TOP)
    stats:SetTall(UI.Scale(98))
    stats.Paint = nil
    makeStatCard(stats, "COMBAT LEVEL", A.GetLevel, "wiltOS")
    makeStatCard(stats, "SKILL POINTS", A.GetPoints, "available")
    makeStatCard(stats, "UNLOCKED", A.GetUnlockedCount, "skills")
    makeStatCard(stats, "PRESTIGE", function() return A.GetPrestigeData().Level end, "rank")

    local progress = vgui.Create("DPanel", content)
    progress:Dock(TOP)
    progress:SetTall(UI.Scale(115))
    progress:DockMargin(0, UI.Scale(16), 0, 0)
    progress.Paint = function(self, w, h)
        UI.DrawPanel(0, 0, w, h, UI.Colors.Panel, UI.Scale(4))
        local previous, required, fraction = A.GetLevelBounds()
        draw.SimpleText("LEVEL ADVANCEMENT", "IMPERIAL_ORDER.WOS.Header", UI.Scale(20), UI.Scale(18), UI.Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(string.Comma(A.GetXP()) .. " TOTAL EXPERIENCE", "IMPERIAL_ORDER.WOS.SmallBold", w - UI.Scale(20), UI.Scale(23), UI.Colors.TextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        UI.DrawBar(UI.Scale(20), UI.Scale(61), w - UI.Scale(40), UI.Scale(26), fraction, UI.Colors.Accent, "LEVEL " .. A.GetLevel(), string.Comma(previous) .. " / " .. string.Comma(required))
    end

    local lower = vgui.Create("DPanel", content)
    lower:Dock(FILL)
    lower:DockMargin(0, UI.Scale(16), 0, 0)
    lower.Paint = nil

    local modelWrap = vgui.Create("DPanel", lower)
    modelWrap:Dock(LEFT)
    modelWrap:SetWide(UI.Scale(330))
    modelWrap.Paint = function(self, w, h) UI.DrawPanel(0, 0, w, h, UI.Colors.Panel, UI.Scale(4)) end
    local model = vgui.Create("DModelPanel", modelWrap)
    model:Dock(FILL)
    local ply = LocalPlayer()
    model:SetModel(IsValid(ply) and ply:GetModel() or "models/player/kleiner.mdl")
    model:SetFOV(31)
    model:SetCamPos(Vector(65, 0, 58))
    model:SetLookAt(Vector(0, 0, 56))
    model.LayoutEntity = function(self, entity)
        entity:SetAngles(Angle(0, 25, 0))
    end

    local right = vgui.Create("DPanel", lower)
    right:Dock(FILL)
    right:DockMargin(UI.Scale(16), 0, 0, 0)
    right.Paint = function(self, w, h)
        UI.DrawPanel(0, 0, w, h, UI.Colors.Panel, UI.Scale(4))
        local form, stance = A.GetCurrentForm()
        local prestige = A.GetPrestigeData()
        draw.SimpleText("ACTIVE COMBAT PROFILE", "IMPERIAL_ORDER.WOS.Header", UI.Scale(22), UI.Scale(20), UI.Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("FORM", "IMPERIAL_ORDER.WOS.SmallBold", UI.Scale(22), UI.Scale(72), UI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(form, "IMPERIAL_ORDER.WOS.SubHeader", UI.Scale(22), UI.Scale(94), UI.Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("STANCE", "IMPERIAL_ORDER.WOS.SmallBold", UI.Scale(250), UI.Scale(72), UI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(tostring(stance), "IMPERIAL_ORDER.WOS.SubHeader", UI.Scale(250), UI.Scale(94), UI.Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("PRESTIGE TOKENS", "IMPERIAL_ORDER.WOS.SmallBold", UI.Scale(22), UI.Scale(148), UI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(tostring(prestige.Tokens), "IMPERIAL_ORDER.WOS.SubHeader", UI.Scale(22), UI.Scale(170), UI.Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("TREES AVAILABLE", "IMPERIAL_ORDER.WOS.SmallBold", UI.Scale(250), UI.Scale(148), UI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(tostring(#A.GetTrees()), "IMPERIAL_ORDER.WOS.SubHeader", UI.Scale(250), UI.Scale(170), UI.Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("The interface is only a presentation layer. All experience, skill purchases, prestige, whitelists, and character saving remain controlled by wiltOS Sentinel.", "IMPERIAL_ORDER.WOS.Body", UI.Scale(22), UI.Scale(235), UI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
end

local function buildSkills(content)
    clearPanel(content)
    UI.SelectedSkill = nil

    local trees = A.GetTrees()
    if not UI.SelectedTree or not A.GetTree(UI.SelectedTree) then
        UI.SelectedTree = trees[1] and trees[1].name or nil
    end

    local sidebar = vgui.Create("DScrollPanel", content)
    sidebar:Dock(LEFT)
    sidebar:SetWide(UI.Scale(235))
    sidebar:DockMargin(0, 0, UI.Scale(14), 0)
    sidebar.Paint = function(self, w, h) UI.DrawPanel(0, 0, w, h, UI.Colors.Panel, UI.Scale(4)) end

    local details = vgui.Create("DPanel", content)
    details:Dock(RIGHT)
    details:SetWide(UI.Scale(280))
    details:DockMargin(UI.Scale(14), 0, 0, 0)
    details.Paint = function(self, w, h)
        UI.DrawPanel(0, 0, w, h, UI.Colors.Panel, UI.Scale(4))
        local selected = UI.SelectedSkill
        draw.SimpleText("SKILL ANALYSIS", "IMPERIAL_ORDER.WOS.Header", UI.Scale(18), UI.Scale(18), UI.Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        if not selected then
            draw.SimpleText("Select a skill node to inspect its requirements and unlock status.", "IMPERIAL_ORDER.WOS.Body", UI.Scale(18), UI.Scale(62), UI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            return
        end
        local data = selected.data
        local owned = A.HasSkill(selected.tree, selected.tier, selected.skill)
        local canBuy, reason = A.CanPurchaseSkill(selected.tree, selected.tier, selected.skill)
        local status = owned and "UNLOCKED" or (canBuy and "AVAILABLE" or string.upper(reason or "LOCKED"))
        local statusColor = owned and UI.Colors.Success or (canBuy and UI.Colors.Warning or UI.Colors.Danger)
        draw.SimpleText(data.Name or ("Skill " .. selected.skill), "IMPERIAL_ORDER.WOS.SubHeader", UI.Scale(18), UI.Scale(62), UI.Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("TIER " .. selected.tier .. "  •  " .. (tonumber(data.PointsRequired) or 0) .. " POINTS", "IMPERIAL_ORDER.WOS.SmallBold", UI.Scale(18), UI.Scale(94), UI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(status, "IMPERIAL_ORDER.WOS.SmallBold", UI.Scale(18), UI.Scale(125), statusColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.DrawText(data.Description or "No description supplied by this skill tree.", "IMPERIAL_ORDER.WOS.Body", UI.Scale(18), UI.Scale(165), UI.Colors.TextDim, TEXT_ALIGN_LEFT)
    end

    local purchase = UI.MakeButton(details, "UNLOCK SELECTED", function()
        local selected = UI.SelectedSkill
        if selected then A.PurchaseSkill(selected.tree, selected.tier, selected.skill) end
    end, function()
        local selected = UI.SelectedSkill
        if not selected then return false end
        return select(1, A.CanPurchaseSkill(selected.tree, selected.tier, selected.skill))
    end)
    purchase:Dock(BOTTOM)
    purchase:SetTall(UI.Scale(46))
    purchase:DockMargin(UI.Scale(15), UI.Scale(7), UI.Scale(15), UI.Scale(15))

    local reset = UI.MakeButton(details, "RESET ALL SKILLS", function()
        Derma_Query("Reset every currently equipped wiltOS skill? The server controls any point refund rules.", "Confirm Skill Reset", "RESET", function() A.ResetSkills() end, "CANCEL")
    end, nil, true)
    reset:Dock(BOTTOM)
    reset:SetTall(UI.Scale(40))
    reset:DockMargin(UI.Scale(15), 0, UI.Scale(15), UI.Scale(6))

    local canvas = vgui.Create("DScrollPanel", content)
    canvas:Dock(FILL)
    canvas.Paint = function(self, w, h) UI.DrawPanel(0, 0, w, h, UI.Colors.Panel, UI.Scale(4)) end

    local function refreshTree()
        clearPanel(canvas:GetCanvas())
        local treeName = UI.SelectedTree
        local tree = A.GetTree(treeName)
        if not tree then return end

        local heading = vgui.Create("DPanel", canvas)
        heading:Dock(TOP)
        heading:SetTall(UI.Scale(92))
        heading:DockMargin(UI.Scale(14), UI.Scale(12), UI.Scale(14), UI.Scale(8))
        heading.Paint = function(self, w, h)
            local icon = iconForTree(treeName, tree)
            if icon then
                surface.SetMaterial(icon)
                surface.SetDrawColor(color_white)
                surface.DrawTexturedRect(UI.Scale(8), UI.Scale(10), UI.Scale(64), UI.Scale(64))
            end
            draw.SimpleText(tree.Name or treeName, "IMPERIAL_ORDER.WOS.Title", UI.Scale(86), UI.Scale(13), UI.Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(tree.Description or "", "IMPERIAL_ORDER.WOS.Body", UI.Scale(86), UI.Scale(52), UI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(A.GetPoints() .. " AVAILABLE POINTS", "IMPERIAL_ORDER.WOS.SmallBold", w - UI.Scale(8), UI.Scale(22), UI.Colors.Warning, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        end

        local maxTiers = tonumber(tree.MaxTiers) or (tree.Tier and table.Count(tree.Tier)) or 0
        for tier = maxTiers, 1, -1 do
            local tierIndex = tier
            local skills = tree.Tier and tree.Tier[tierIndex] or {}
            local row = vgui.Create("DPanel", canvas)
            row:Dock(TOP)
            row:SetTall(UI.Scale(126))
            row:DockMargin(UI.Scale(14), 0, UI.Scale(14), UI.Scale(10))
            row.Paint = function(self, w, h)
                draw.RoundedBox(UI.Scale(3), 0, 0, w, h, UI.Colors.PanelSoft)
                UI.DrawAccentLine(0, 0, UI.Scale(4), h)
                draw.SimpleText("TIER " .. tierIndex, "IMPERIAL_ORDER.WOS.SmallBold", UI.Scale(16), UI.Scale(12), UI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end

            local layout = vgui.Create("DIconLayout", row)
            layout:SetPos(UI.Scale(78), UI.Scale(10))
            layout:SetSize(UI.Scale(560), UI.Scale(106))
            layout:SetSpaceX(UI.Scale(9))
            layout:SetSpaceY(UI.Scale(8))

            local indices = {}
            for skill in pairs(skills) do indices[#indices + 1] = skill end
            table.sort(indices)
            for _, skill in ipairs(indices) do
                local skillIndex = skill
                local skillData = skills[skillIndex]
                if not skillData.DummySkill then
                    local button = layout:Add("DButton")
                    button:SetSize(UI.Scale(102), UI.Scale(101))
                    button:SetText("")
                    button.Paint = function(self, w, h)
                        local owned = A.HasSkill(treeName, tierIndex, skillIndex)
                        local available = select(1, A.CanPurchaseSkill(treeName, tierIndex, skillIndex))
                        local selected = UI.SelectedSkill and UI.SelectedSkill.tree == treeName and UI.SelectedSkill.tier == tierIndex and UI.SelectedSkill.skill == skillIndex
                        local bg = owned and Color(25, 74, 48, 255) or (available and Color(72, 55, 22, 255) or Color(25, 27, 32, 255))
                        if self:IsHovered() then bg = Color(bg.r + 14, bg.g + 14, bg.b + 14, 255) end
                        draw.RoundedBox(UI.Scale(3), 0, 0, w, h, bg)
                        surface.SetDrawColor(selected and UI.Colors.AccentBright or UI.Colors.SteelDark)
                        surface.DrawOutlinedRect(0, 0, w, h, selected and 2 or 1)
                        local icon = iconForSkill(treeName, tierIndex, skillIndex, skillData)
                        if icon then
                            surface.SetMaterial(icon)
                            surface.SetDrawColor(owned and color_white or Color(185, 190, 200, 255))
                            surface.DrawTexturedRect(w / 2 - UI.Scale(25), UI.Scale(8), UI.Scale(50), UI.Scale(50))
                        end
                        draw.SimpleText(skillData.Name or ("Skill " .. skillIndex), "IMPERIAL_ORDER.WOS.SmallBold", w / 2, UI.Scale(66), UI.Colors.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                        draw.SimpleText((tonumber(skillData.PointsRequired) or 0) .. " SP", "IMPERIAL_ORDER.WOS.Small", w / 2, h - UI.Scale(8), UI.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
                    end
                    button.DoClick = function()
                        UI.SelectedSkill = {tree = treeName, tier = tierIndex, skill = skillIndex, data = skillData}
                    end
                    button.DoDoubleClick = function()
                        A.PurchaseSkill(treeName, tierIndex, skillIndex)
                    end
                end
            end
        end
    end

    for _, entry in ipairs(trees) do
        local name, data = entry.name, entry.data
        local button = vgui.Create("DButton", sidebar)
        button:Dock(TOP)
        button:SetTall(UI.Scale(68))
        button:DockMargin(UI.Scale(8), UI.Scale(8), UI.Scale(8), 0)
        button:SetText("")
        button.Paint = function(self, w, h)
            local active = UI.SelectedTree == name
            draw.RoundedBox(UI.Scale(3), 0, 0, w, h, active and UI.Colors.AccentDark or (self:IsHovered() and UI.Colors.PanelSoft or Color(11, 13, 16, 235)))
            local icon = iconForTree(name, data)
            if icon then
                surface.SetMaterial(icon)
                surface.SetDrawColor(color_white)
                surface.DrawTexturedRect(UI.Scale(10), UI.Scale(10), UI.Scale(46), UI.Scale(46))
            end
            draw.SimpleText(data.Name or name, "IMPERIAL_ORDER.WOS.BodyBold", UI.Scale(66), UI.Scale(18), UI.Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText((tonumber(data.MaxTiers) or 0) .. " TIERS", "IMPERIAL_ORDER.WOS.Small", UI.Scale(66), UI.Scale(42), UI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            if active then UI.DrawAccentLine(0, 0, UI.Scale(4), h) end
        end
        button.DoClick = function()
            UI.SelectedTree = name
            UI.SelectedSkill = nil
            refreshTree()
        end
    end

    refreshTree()
end

local function buildPrestige(content)
    clearPanel(content)
    local map = A.GetPrestigeMap()

    local heading = vgui.Create("DPanel", content)
    heading:Dock(TOP)
    heading:SetTall(UI.Scale(105))
    heading.Paint = function(self, w, h)
        local data = A.GetPrestigeData()
        draw.SimpleText(map.HeaderName or "PRESTIGE", "IMPERIAL_ORDER.WOS.Title", 0, UI.Scale(4), UI.Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(map.HeaderTagLine or "Advance through the wiltOS prestige system.", "IMPERIAL_ORDER.WOS.Body", 0, UI.Scale(43), UI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("RANK " .. data.Level, "IMPERIAL_ORDER.WOS.Header", w - UI.Scale(170), UI.Scale(8), UI.Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(data.Tokens .. " TOKENS", "IMPERIAL_ORDER.WOS.SmallBold", w - UI.Scale(170), UI.Scale(45), UI.Colors.Warning, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    local ascend = UI.MakeButton(content, "ASCEND / PRESTIGE", function()
        if not A.CanAscend() then
            UI.Notify("Combat level " .. A.GetPrestigeRequirement() .. " is required", NOTIFY_ERROR)
            return
        end
        Derma_Query("Ascending is handled by wiltOS and may reset combat level, experience, points, and skills. Continue?", "Confirm Ascension", "ASCEND", function() A.Ascend() end, "CANCEL")
    end, A.CanAscend)
    ascend:Dock(TOP)
    ascend:SetTall(UI.Scale(48))
    ascend:DockMargin(0, 0, 0, UI.Scale(14))

    local scroll = vgui.Create("DScrollPanel", content)
    scroll:Dock(FILL)
    scroll.Paint = function(self, w, h) UI.DrawPanel(0, 0, w, h, UI.Colors.Panel, UI.Scale(4)) end
    local layout = vgui.Create("DIconLayout", scroll)
    layout:Dock(FILL)
    layout:DockMargin(UI.Scale(12), UI.Scale(12), UI.Scale(12), UI.Scale(12))
    layout:SetSpaceX(UI.Scale(10))
    layout:SetSpaceY(UI.Scale(10))

    local ids = {}
    for id in pairs(map.Paths or {}) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local masteryID = id
        local data = map.Paths[masteryID]
        local node = layout:Add("DButton")
        node:SetSize(UI.Scale(235), UI.Scale(130))
        node:SetText("")
        node.Paint = function(self, w, h)
            local prestige = A.GetPrestigeData()
            local owned = prestige.Mastery[masteryID] == true
            local available = select(1, A.CanPurchaseMastery(masteryID, data))
            local bg = owned and Color(20, 75, 47, 255) or (available and Color(74, 54, 18, 255) or UI.Colors.PanelSoft)
            if self:IsHovered() then bg = Color(math.min(255, bg.r + 12), math.min(255, bg.g + 12), math.min(255, bg.b + 12), 255) end
            draw.RoundedBox(UI.Scale(3), 0, 0, w, h, bg)
            surface.SetDrawColor(owned and UI.Colors.Success or (available and UI.Colors.Warning or UI.Colors.SteelDark))
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            local icon = materialFrom(data.Icon)
            if icon then
                surface.SetMaterial(icon)
                surface.SetDrawColor(color_white)
                surface.DrawTexturedRect(UI.Scale(12), UI.Scale(15), UI.Scale(52), UI.Scale(52))
            end
            draw.SimpleText(data.Name or ("Mastery " .. masteryID), "IMPERIAL_ORDER.WOS.BodyBold", UI.Scale(76), UI.Scale(16), UI.Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText((tonumber(data.Amount) or 0) .. " TOKEN", "IMPERIAL_ORDER.WOS.SmallBold", UI.Scale(76), UI.Scale(43), UI.Colors.Warning, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.DrawText(data.Description or "", "IMPERIAL_ORDER.WOS.Small", UI.Scale(12), UI.Scale(76), UI.Colors.TextDim, TEXT_ALIGN_LEFT)
            draw.SimpleText(owned and "MASTERED" or (available and "AVAILABLE" or "LOCKED"), "IMPERIAL_ORDER.WOS.SmallBold", w - UI.Scale(10), h - UI.Scale(8), owned and UI.Colors.Success or (available and UI.Colors.Warning or UI.Colors.Danger), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
        end
        node.DoClick = function() A.PurchaseMastery(masteryID, data) end
    end
end

local function buildForms(content)
    clearPanel(content)
    local forms, stances, wep = A.GetAvailableForms()
    local currentForm, currentStance = A.GetCurrentForm(wep)

    local heading = vgui.Create("DPanel", content)
    heading:Dock(TOP)
    heading:SetTall(UI.Scale(88))
    heading.Paint = function(self, w, h)
        draw.SimpleText("LIGHTSABER FORMS", "IMPERIAL_ORDER.WOS.Title", 0, UI.Scale(4), UI.Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("Select an unlocked wiltOS form or a specific stance", "IMPERIAL_ORDER.WOS.Body", 0, UI.Scale(43), UI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(currentForm .. " / STANCE " .. currentStance, "IMPERIAL_ORDER.WOS.SmallBold", w, UI.Scale(18), UI.Colors.Warning, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    end

    if not IsValid(wep) then
        local warning = vgui.Create("DPanel", content)
        warning:Dock(FILL)
        warning.Paint = function(self, w, h)
            UI.DrawPanel(0, 0, w, h, UI.Colors.Panel, UI.Scale(4))
            draw.SimpleText("EQUIP A wiltOS LIGHTSABER", "IMPERIAL_ORDER.WOS.Header", w / 2, h / 2 - UI.Scale(15), UI.Colors.Danger, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("Available forms are supplied by the active weapon and your unlocked skills.", "IMPERIAL_ORDER.WOS.Body", w / 2, h / 2 + UI.Scale(22), UI.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        return
    end

    local scroll = vgui.Create("DScrollPanel", content)
    scroll:Dock(FILL)
    scroll.Paint = function(self, w, h) UI.DrawPanel(0, 0, w, h, UI.Colors.Panel, UI.Scale(4)) end

    for _, form in ipairs(forms) do
        local formName = form
        local row = vgui.Create("DPanel", scroll)
        row:Dock(TOP)
        row:SetTall(UI.Scale(76))
        row:DockMargin(UI.Scale(10), UI.Scale(10), UI.Scale(10), 0)
        row.Paint = function(self, w, h)
            local active = currentForm == formName
            draw.RoundedBox(UI.Scale(3), 0, 0, w, h, active and UI.Colors.AccentDark or UI.Colors.PanelSoft)
            if active then UI.DrawAccentLine(0, 0, UI.Scale(4), h) end
            draw.SimpleText(formName, "IMPERIAL_ORDER.WOS.SubHeader", UI.Scale(18), h / 2, UI.Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local choose = UI.MakeButton(row, "SELECT FORM", function() A.SelectForm(formName) end, function() return currentForm == formName end)
        choose:Dock(RIGHT)
        choose:SetWide(UI.Scale(135))
        choose:DockMargin(UI.Scale(7), UI.Scale(14), UI.Scale(12), UI.Scale(14))

        local stanceList = stances[formName] or {}
        for index = #stanceList, 1, -1 do
            local stanceID = stanceList[index]
            local stanceButton = UI.MakeButton(row, tostring(stanceID), function() A.SelectStance(formName, stanceID) end, function() return currentForm == formName and currentStance == stanceID end)
            stanceButton:Dock(RIGHT)
            stanceButton:SetWide(UI.Scale(48))
            stanceButton:DockMargin(UI.Scale(4), UI.Scale(14), 0, UI.Scale(14))
        end
    end
end

function UI.OpenMain(tab)
    if not UI.IsEnabled() then return end
    A.RemoveDefaultMenus()
    UI.CloseMain()

    local frame = vgui.Create("DFrame")
    UI.Frame = frame
    frame:SetSize(math.min(ScrW() - UI.Scale(60), UI.Scale(1500)), math.min(ScrH() - UI.Scale(60), UI.Scale(900)))
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(true)
    frame:MakePopup()
    frame:SetKeyboardInputEnabled(true)
    frame.Paint = function(self, w, h)
        draw.RoundedBox(UI.Scale(5), 0, 0, w, h, UI.Colors.Background)
        surface.SetDrawColor(UI.Colors.SteelDark)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        UI.DrawAccentLine(0, 0, w, UI.Scale(4))
        for y = UI.Scale(86), h, UI.Scale(5) do
            surface.SetDrawColor(255, 255, 255, 3)
            surface.DrawLine(0, y, w, y)
        end
    end
    frame.OnRemove = function()
        if UI.Frame == frame then UI.Frame = nil end
        gui.EnableScreenClicker(false)
    end

    local top = vgui.Create("DPanel", frame)
    top:Dock(TOP)
    top:SetTall(UI.Scale(86))
    top.Paint = function(self, w, h)
        draw.RoundedBoxEx(UI.Scale(5), 0, 0, w, h, UI.Colors.Header, true, true, false, false)
        draw.SimpleText("IMPERIAL COMBAT ARCHIVE", "IMPERIAL_ORDER.WOS.Title", UI.Scale(24), UI.Scale(18), UI.Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("WILTOS SENTINEL PROGRESSION INTERFACE", "IMPERIAL_ORDER.WOS.SmallBold", UI.Scale(26), UI.Scale(56), UI.Colors.AccentBright, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("LVL " .. A.GetLevel() .. "  •  " .. A.GetPoints() .. " SP  •  PRESTIGE " .. A.GetPrestigeData().Level, "IMPERIAL_ORDER.WOS.BodyBold", w - UI.Scale(78), h / 2, UI.Colors.TextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    local close = UI.MakeButton(top, "×", UI.CloseMain, nil, true)
    close:Dock(RIGHT)
    close:SetWide(UI.Scale(58))
    close:DockMargin(UI.Scale(8), UI.Scale(15), UI.Scale(14), UI.Scale(15))

    local body = vgui.Create("DPanel", frame)
    body:Dock(FILL)
    body:DockMargin(UI.Scale(14), UI.Scale(14), UI.Scale(14), UI.Scale(14))
    body.Paint = nil

    local nav = vgui.Create("DPanel", body)
    nav:Dock(LEFT)
    nav:SetWide(UI.Scale(205))
    nav:DockMargin(0, 0, UI.Scale(14), 0)
    nav.Paint = function(self, w, h)
        UI.DrawPanel(0, 0, w, h, UI.Colors.Panel, UI.Scale(4))
        draw.SimpleText("ARCHIVE SECTIONS", "IMPERIAL_ORDER.WOS.SmallBold", UI.Scale(14), UI.Scale(16), UI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("v" .. UI.Version, "IMPERIAL_ORDER.WOS.Small", UI.Scale(14), h - UI.Scale(14), UI.Colors.TextDark, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
    end

    local content = vgui.Create("DPanel", body)
    content:Dock(FILL)
    content.Paint = nil

    local currentTab = string.lower(tab or "overview")
    local builders = {
        overview = buildOverview,
        skills = buildSkills,
        prestige = buildPrestige,
        forms = buildForms,
    }

    local function setTab(name)
        currentTab = name
        builders[name](content)
    end

    local navEntries = {
        {"overview", "OVERVIEW"},
        {"skills", "SKILL TREES"},
        {"prestige", "PRESTIGE"},
        {"forms", "SABER FORMS"},
    }
    for index, item in ipairs(navEntries) do
        local tabName = item[1]
        local tabLabel = item[2]
        local button = UI.MakeButton(nav, tabLabel, function() setTab(tabName) end, function() return currentTab == tabName end)
        button:SetPos(UI.Scale(10), UI.Scale(48) + (index - 1) * UI.Scale(57))
        button:SetSize(UI.Scale(185), UI.Scale(47))
    end

    if UI.CanOpenAdminMenu() then
        local adminButton = UI.MakeButton(nav, "ADMIN TOOLS", UI.OpenAdminMenu, nil, true)
        adminButton:SetPos(UI.Scale(10), UI.Scale(48) + #navEntries * UI.Scale(57) + UI.Scale(12))
        adminButton:SetSize(UI.Scale(185), UI.Scale(47))
    end

    setTab(builders[currentTab] and currentTab or "overview")
end

function UI.OpenFormsPopup()
    if IsValid(UI.FormFrame) then UI.FormFrame:Remove() end
    local forms, stances, wep = A.GetAvailableForms()
    if not IsValid(wep) then
        UI.Notify("Equip a wiltOS lightsaber first", NOTIFY_ERROR)
        return
    end

    local frame = vgui.Create("DFrame")
    UI.FormFrame = frame
    frame:SetSize(UI.Scale(680), math.min(ScrH() - UI.Scale(100), UI.Scale(650)))
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame.Paint = function(self, w, h)
        UI.DrawPanel(0, 0, w, h, UI.Colors.Background, UI.Scale(5))
        UI.DrawAccentLine(0, 0, w, UI.Scale(4))
        draw.SimpleText("SABER FORM SELECTOR", "IMPERIAL_ORDER.WOS.Title", UI.Scale(20), UI.Scale(18), UI.Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("Powered by wiltOS progression unlocks", "IMPERIAL_ORDER.WOS.SmallBold", UI.Scale(22), UI.Scale(56), UI.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
    frame.OnRemove = function() if UI.FormFrame == frame then UI.FormFrame = nil end end

    local close = UI.MakeButton(frame, "×", function() frame:Remove() end, nil, true)
    close:SetPos(frame:GetWide() - UI.Scale(58), UI.Scale(14))
    close:SetSize(UI.Scale(42), UI.Scale(42))

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(UI.Scale(16), UI.Scale(88))
    scroll:SetSize(frame:GetWide() - UI.Scale(32), frame:GetTall() - UI.Scale(104))

    local currentForm, currentStance = A.GetCurrentForm(wep)
    for _, form in ipairs(forms) do
        local formName = form
        local row = vgui.Create("DPanel", scroll)
        row:Dock(TOP)
        row:SetTall(UI.Scale(70))
        row:DockMargin(0, 0, 0, UI.Scale(8))
        row.Paint = function(self, w, h)
            draw.RoundedBox(UI.Scale(3), 0, 0, w, h, currentForm == formName and UI.Colors.AccentDark or UI.Colors.PanelSoft)
            draw.SimpleText(formName, "IMPERIAL_ORDER.WOS.SubHeader", UI.Scale(15), h / 2, UI.Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        local choose = UI.MakeButton(row, "SELECT", function() A.SelectForm(formName); frame:Remove() end, function() return currentForm == formName end)
        choose:Dock(RIGHT)
        choose:SetWide(UI.Scale(110))
        choose:DockMargin(UI.Scale(5), UI.Scale(12), UI.Scale(10), UI.Scale(12))
        local list = stances[formName] or {}
        for index = #list, 1, -1 do
            local stanceID = list[index]
            local button = UI.MakeButton(row, tostring(stanceID), function() A.SelectStance(formName, stanceID); frame:Remove() end, function() return currentForm == formName and currentStance == stanceID end)
            button:Dock(RIGHT)
            button:SetWide(UI.Scale(44))
            button:DockMargin(UI.Scale(4), UI.Scale(12), 0, UI.Scale(12))
        end
    end
end

local function openSkillsOverride()
    UI.ToggleMain("skills")
end

local function closeSkillsOverride()
    UI.CloseMain()
end

local function openClassicOverride()
    UI.OpenMain("skills")
end

local function openFormsOverride()
    UI.OpenFormsPopup()
end

function UI.InstallOverrides()
    if not UI.IsEnabled() then return end
    if wOS and wOS.ALCS and wOS.ALCS.Skills then
        local skills = wOS.ALCS.Skills
        if skills.OpenSkillsMenu ~= openSkillsOverride then
            UI.Original.OpenSkillsMenu = UI.Original.OpenSkillsMenu or skills.OpenSkillsMenu
            skills.OpenSkillsMenu = openSkillsOverride
        end
        if skills.CloseSkillsMenu ~= closeSkillsOverride then
            UI.Original.CloseSkillsMenu = UI.Original.CloseSkillsMenu or skills.CloseSkillsMenu
            skills.CloseSkillsMenu = closeSkillsOverride
        end
        if skills.OpenClassicTreeMenu ~= openClassicOverride then
            UI.Original.OpenClassicTreeMenu = UI.Original.OpenClassicTreeMenu or skills.OpenClassicTreeMenu
            skills.OpenClassicTreeMenu = openClassicOverride
        end
    end
    if wOS and wOS.ALCS and wOS.ALCS.OpenFormMenu ~= openFormsOverride then
        UI.Original.OpenFormMenu = UI.Original.OpenFormMenu or wOS.ALCS.OpenFormMenu
        wOS.ALCS.OpenFormMenu = openFormsOverride
    end
end

hook.Add("InitPostEntity", "IMPERIAL_ORDER.WiltOS.UI.Install", function()
    timer.Simple(1, UI.InstallOverrides)
    timer.Simple(4, UI.InstallOverrides)
end)
timer.Create("IMPERIAL_ORDER.WiltOS.UI.Reapply", 2, 0, UI.InstallOverrides)

concommand.Add("imperial_order_wiltos_ui", function() UI.ToggleMain("overview") end)
concommand.Add("imperial_order_wiltos_skills", function() UI.ToggleMain("skills") end)
concommand.Add("imperial_order_wiltos_forms", function() UI.OpenFormsPopup() end)

-- V263: admin-only aliases for the native wiltOS administration interface.
concommand.Add("imperial_order_wiltos_admin", function() UI.OpenAdminMenu() end)
concommand.Add("imperial_order_wos_admin", function() UI.OpenAdminMenu() end)
concommand.Add("imperial_order_open_wiltos_admin", function() UI.OpenAdminMenu() end)

-- V247: wiltOS no longer owns F2 or any other physical key. The dedicated
-- wiltOS skill station and explicit commands still call the same interface.
hook.Remove("PlayerBindPress", "IMPERIAL_ORDER.WiltOS.UI.F2Bind")

hook.Add("Think", "IMPERIAL_ORDER.WiltOS.UI.CloseGuard", function()
    if IsValid(UI.Frame) and (not IsValid(LocalPlayer()) or not LocalPlayer():Alive()) then UI.CloseMain() end
end)
