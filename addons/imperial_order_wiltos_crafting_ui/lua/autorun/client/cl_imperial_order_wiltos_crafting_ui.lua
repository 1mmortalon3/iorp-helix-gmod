-- Imperial Order - wiltOS Lightsaber Crafting UI
-- Client-side visual override. Uses the existing wiltOS crafting backend/networking.

if SERVER then return end

ImperialOrderCraftingUI = ImperialOrderCraftingUI or {}
local UI = ImperialOrderCraftingUI

UI.Version = "1.0.0"
UI.Frame = UI.Frame or nil
UI.Selector = UI.Selector or nil
UI.ActivePage = UI.ActivePage or "ASSEMBLY"
UI.SelectedBlueprint = UI.SelectedBlueprint or nil
UI.SelectedSalvage = UI.SelectedSalvage or nil
UI.SelectedModSlot = UI.SelectedModSlot or 1
UI.Original = UI.Original or {}
UI.Patched = UI.Patched or false

UI.Enabled = CreateClientConVar("imperial_order_crafting_ui_enabled", "1", true, false, "Use the Imperial Order lightsaber crafting UI.")
UI.Brand = CreateClientConVar("imperial_order_crafting_ui_brand", "IMPERIAL ORDER", true, false, "Header brand for the crafting UI.")

local function scale(v)
    return math.max(1, math.floor((tonumber(v) or 0) * math.Clamp(ScrH() / 1080, 0.72, 1.35)))
end

UI.Scale = scale

local function theme()
    -- First preference: the schema UI shipped in the supplied server archive.
    if ImperialUI and ImperialUI.Colors then
        local c = ImperialUI.Colors
        return {
            Background = c.background or Color(5, 6, 8, 248),
            BackgroundSoft = c.backgroundSoft or Color(9, 10, 13, 245),
            Panel = c.panel or Color(14, 16, 20, 246),
            PanelRaised = c.panelRaised or Color(21, 24, 29, 248),
            Hover = c.panelHover or Color(34, 37, 43, 250),
            Accent = c.red or Color(178, 24, 33),
            AccentBright = c.redBright or Color(238, 38, 48),
            AccentDark = c.redDark or Color(78, 7, 12),
            Steel = c.steel or Color(134, 139, 145),
            SteelDark = c.steelDark or Color(55, 60, 66),
            Line = c.line or Color(86, 91, 97, 150),
            Text = c.white or c.text or Color(238, 240, 243),
            TextDim = c.textDim or Color(140, 145, 153),
            Success = c.success or Color(85, 184, 112),
            Warning = c.warning or Color(226, 169, 60),
            Danger = c.danger or Color(220, 48, 52),
        }
    end

    if IORP_WILTOS_UI and IORP_WILTOS_UI.Colors then
        local c = IORP_WILTOS_UI.Colors
        return {
            Background = c.Background or Color(7, 8, 10, 248),
            BackgroundSoft = c.Panel or Color(16, 18, 22, 245),
            Panel = c.Panel or Color(16, 18, 22, 245),
            PanelRaised = c.PanelSoft or Color(24, 27, 32, 245),
            Hover = Color(42, 46, 54, 255),
            Accent = c.Accent or Color(178, 24, 33),
            AccentBright = c.AccentBright or Color(235, 48, 58),
            AccentDark = c.AccentDark or Color(86, 11, 17),
            Steel = c.Steel or Color(102, 111, 124),
            SteelDark = c.SteelDark or Color(48, 53, 62),
            Line = Color(75, 81, 92, 160),
            Text = c.Text or Color(238, 240, 244),
            TextDim = c.TextDim or Color(155, 163, 176),
            Success = c.Success or Color(74, 190, 116),
            Warning = c.Warning or Color(225, 165, 54),
            Danger = c.Danger or Color(226, 60, 67),
        }
    end

    return {
        Background = Color(5, 6, 8, 248),
        BackgroundSoft = Color(10, 12, 15, 245),
        Panel = Color(15, 17, 21, 246),
        PanelRaised = Color(23, 26, 31, 248),
        Hover = Color(35, 39, 46, 250),
        Accent = Color(178, 24, 33),
        AccentBright = Color(235, 48, 58),
        AccentDark = Color(86, 11, 17),
        Steel = Color(112, 120, 132),
        SteelDark = Color(49, 55, 64),
        Line = Color(78, 84, 94, 160),
        Text = Color(238, 240, 244),
        TextDim = Color(153, 160, 171),
        Success = Color(74, 190, 116),
        Warning = Color(225, 165, 54),
        Danger = Color(226, 60, 67),
    }
end

UI.Theme = theme

local function rebuildFonts()
    local display = "Roboto"
    local body = "Roboto"

    if ImperialUI and ImperialUI.Config then
        display = ImperialUI.Config.FontDisplay or ImperialUI.Config.FontFallback or display
        body = ImperialUI.Config.FontBody or ImperialUI.Config.FontFallback or body
    end

    local function make(name, font, size, weight)
        surface.CreateFont(name, {
            font = font,
            size = scale(size),
            weight = weight,
            antialias = true,
            extended = true,
        })
    end

    make("ImperialOrderCraft.Title", display, 30, 900)
    make("ImperialOrderCraft.Header", display, 21, 850)
    make("ImperialOrderCraft.SubHeader", display, 17, 800)
    make("ImperialOrderCraft.Body", body, 15, 550)
    make("ImperialOrderCraft.BodyBold", body, 15, 800)
    make("ImperialOrderCraft.Small", body, 12, 550)
    make("ImperialOrderCraft.SmallBold", body, 12, 800)
    make("ImperialOrderCraft.Micro", body, 10, 700)
end

rebuildFonts()
hook.Add("OnScreenSizeChanged", "ImperialOrderCraftingUI.Fonts", rebuildFonts)

local function angularPoints(x, y, w, h, notch)
    notch = math.Clamp(notch or scale(10), 0, math.min(w, h) / 3)
    return {
        {x = x + notch, y = y},
        {x = x + w - notch, y = y},
        {x = x + w, y = y + notch},
        {x = x + w, y = y + h - notch},
        {x = x + w - notch, y = y + h},
        {x = x + notch, y = y + h},
        {x = x, y = y + h - notch},
        {x = x, y = y + notch},
    }
end

local function angularBox(x, y, w, h, fill, border, notch)
    local pts = angularPoints(x, y, w, h, notch)
    draw.NoTexture()
    surface.SetDrawColor(fill)
    surface.DrawPoly(pts)
    if border then
        surface.SetDrawColor(border)
        for i = 1, #pts do
            local n = i == #pts and 1 or i + 1
            surface.DrawLine(pts[i].x, pts[i].y, pts[n].x, pts[n].y)
        end
    end
end

UI.DrawAngularBox = angularBox

local function line(x, y, w, col)
    surface.SetDrawColor(col or theme().Line)
    surface.DrawRect(x, y, w, 1)
end

local function shadowText(text, font, x, y, col, xa, ya)
    draw.SimpleText(tostring(text or ""), font, x + 1, y + 2, Color(0, 0, 0, 220), xa or TEXT_ALIGN_LEFT, ya or TEXT_ALIGN_TOP)
    draw.SimpleText(tostring(text or ""), font, x, y, col or theme().Text, xa or TEXT_ALIGN_LEFT, ya or TEXT_ALIGN_TOP)
end

local function notify(text, kind)
    if notification and notification.AddLegacy then
        notification.AddLegacy(tostring(text or ""), kind or NOTIFY_GENERIC, 4)
    end
    surface.PlaySound(kind == NOTIFY_ERROR and "buttons/button10.wav" or "buttons/button15.wav")
end

UI.Notify = notify

local function safeItem(name)
    if name == "Standard" then
        return {Name = "Standard", Description = "Factory-standard component", RarityName = "Standard"}
    end
    if name == "Empty" then
        return {Name = "Empty", Description = "No proficiency modification installed"}
    end
    return wOS and wOS.ItemList and wOS.ItemList[name] or nil
end

local function inventoryCount(name)
    local total = 0
    if not wOS or not istable(wOS.SaberInventory) then return total end
    for _, entry in pairs(wOS.SaberInventory) do
        if istable(entry) then
            if entry.Name == name then total = total + math.max(0, tonumber(entry.Amount) or 1) end
        elseif entry == name then
            total = total + 1
        end
    end
    return total
end

local function hasInventoryItem(name)
    if name == "Standard" or name == "Empty" then return true end
    return inventoryCount(name) > 0
end

local function currentEquip()
    if not wOS then return nil end
    local key = wOS.CurrentInventoryTable or "EquippedItems"
    return wOS[key]
end

local function currentSaber()
    if not wOS then return nil end
    local key = wOS.CurrentCraftTable or "PersonalSaber"
    return wOS[key]
end

local TYPE_META = {
    [1] = {title = "CRYSTAL", subtitle = "KYBER / BLADE COLOR"},
    [2] = {title = "IGNITER", subtitle = "CRYSTAL ACTIVATOR"},
    [3] = {title = "IDLE", subtitle = "IDLE REGULATOR"},
    [4] = {title = "VORTEX", subtitle = "POWER VORTEX"},
    [5] = {title = "HILT", subtitle = "SABER CHASSIS"},
}

local PAGES = {
    {id = "ASSEMBLY", label = "ASSEMBLY"},
    {id = "HILT", label = "HILT", typeId = 5},
    {id = "CRYSTAL", label = "CRYSTAL", typeId = 1},
    {id = "IGNITER", label = "IGNITER", typeId = 2},
    {id = "IDLE", label = "IDLE", typeId = 3},
    {id = "VORTEX", label = "VORTEX", typeId = 4},
    {id = "MODS", label = "PROFICIENCY MODS"},
    {id = "FORGE", label = "BLUEPRINT FORGE"},
    {id = "SALVAGE", label = "SALVAGE"},
}

local function getPageMeta(id)
    for _, data in ipairs(PAGES) do
        if data.id == id then return data end
    end
    return PAGES[1]
end

local function getComponentChoices(typeId)
    local result, seen = {}, {}
    local equipped = currentEquip()
    local current = equipped and equipped[typeId] or nil
    local original = UI.Original.CurrentItems and UI.Original.CurrentItems[typeId] or nil

    local function add(name)
        if not name or name == "" or seen[name] then return end
        seen[name] = true
        result[#result + 1] = name
    end

    add(current)
    add(original)
    add("Standard")

    local sorted = wOS and wOS.SortedItemList and wOS.SortedItemList[typeId] or {}
    local names = {}
    for name in pairs(sorted or {}) do
        if name ~= "Standard" and hasInventoryItem(name) then
            names[#names + 1] = name
        end
    end
    table.sort(names, function(a, b) return string.lower(a) < string.lower(b) end)
    for _, name in ipairs(names) do add(name) end
    return result
end

local function sendPreview()
    local equipped = currentEquip()
    if not equipped then return end
    net.Start("wOS.Crafting.PreviewChange")
        net.WriteBool(wOS.UsingDualLightsaber == true)
        net.WriteTable(equipped)
    net.SendToServer()
end

local function selectComponent(typeId, name)
    local equipped = currentEquip()
    if not equipped then return end
    equipped[typeId] = name
    sendPreview()
    UI.Refresh()
    surface.PlaySound("buttons/button9.wav")
end

local function getPreviewModel()
    local saber = currentSaber()
    if saber and isstring(saber.UseHilt) and saber.UseHilt ~= "" then
        return saber.UseHilt
    end

    local equipped = currentEquip()
    local hiltName = equipped and equipped[5]
    local item = hiltName and safeItem(hiltName)
    if item and item.Model then return item.Model end
    return "models/weapons/w_crowbar.mdl"
end

local function getBladeColor()
    local saber = currentSaber()
    if saber and IsColor(saber.UseColor) then return saber.UseColor end
    return Color(190, 210, 255)
end

local function panel(parent, paint)
    local p = vgui.Create("DPanel", parent)
    p.Paint = paint
    return p
end

local function styledButton(parent, text, callback, activeFunc, danger)
    local b = vgui.Create("DButton", parent)
    b:SetText("")
    b.Paint = function(self, w, h)
        local c = theme()
        local active = activeFunc and activeFunc() or false
        local fill = c.PanelRaised
        local border = c.SteelDark
        if danger then
            fill = self:IsHovered() and Color(115, 26, 32, 255) or Color(72, 19, 24, 255)
            border = c.Danger
        elseif active then
            fill = self:IsHovered() and c.AccentBright or c.Accent
            border = c.AccentBright
        elseif self:IsHovered() then
            fill = c.Hover
            border = c.Accent
        end
        angularBox(0, 0, w, h, fill, border, scale(6))
        shadowText(text, "ImperialOrderCraft.BodyBold", w / 2, h / 2, c.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    b.DoClick = function()
        if callback then callback(b) end
    end
    return b
end

local function closeVisuals()
    if IsValid(UI.Frame) then UI.Frame:Remove() end
    if IsValid(UI.Selector) then UI.Selector:Remove() end
    UI.Frame = nil
    UI.Selector = nil
    gui.EnableScreenClicker(false)
end

function UI.Close(sendClean, restore)
    if restore and UI.Original.EquippedItems and wOS then
        wOS.EquippedItems = table.Copy(UI.Original.EquippedItems)
        wOS.SecEquippedItems = table.Copy(UI.Original.SecEquippedItems or {})
        wOS.SaberMiscSlots = table.Copy(UI.Original.SaberMiscSlots or {})
    end

    closeVisuals()

    if sendClean and wOS then
        net.Start("wOS.ALCS.Crafting.CleanExit")
        net.SendToServer()
    end
end

local function configureModelPanel(modelPanel)
    if not IsValid(modelPanel) then return end
    local model = getPreviewModel()
    if not util.IsValidModel(model) then model = "models/weapons/w_crowbar.mdl" end
    if modelPanel._ImperialOrderModel ~= model then
        modelPanel._ImperialOrderModel = model
        modelPanel:SetModel(model)
        modelPanel:SetFOV(32)

        timer.Simple(0, function()
            if not IsValid(modelPanel) or not IsValid(modelPanel.Entity) then return end
            local mn, mx = modelPanel.Entity:GetRenderBounds()
            local center = (mn + mx) * 0.5
            local radius = math.max(8, (mx - mn):Length() * 0.55)
            modelPanel:SetLookAt(center)
            modelPanel:SetCamPos(center + Vector(radius * 1.6, radius * 1.6, radius * 0.7))
        end)
    end
end

local function createPreview(parent)
    local host = panel(parent, function(self, w, h)
        local c = theme()
        angularBox(0, 0, w, h, c.BackgroundSoft, c.SteelDark, scale(9))
        surface.SetDrawColor(c.Accent)
        surface.DrawRect(0, 0, scale(4), h)
        shadowText("LIVE ASSEMBLY PREVIEW", "ImperialOrderCraft.SubHeader", scale(15), scale(13), c.Text)
        shadowText(wOS and wOS.UsingDualLightsaber and "OFF-HAND CONFIGURATION" or "PRIMARY CONFIGURATION", "ImperialOrderCraft.SmallBold", scale(15), scale(38), c.TextDim)
        line(scale(15), scale(62), w - scale(30), c.Line)

        local blade = getBladeColor()
        local bx = w - scale(34)
        local by = scale(90)
        local bh = h - scale(130)
        draw.RoundedBox(scale(2), bx, by, scale(9), bh, Color(blade.r, blade.g, blade.b, 70))
        draw.RoundedBox(scale(2), bx + scale(2), by, scale(5), bh, Color(blade.r, blade.g, blade.b, 235))
        draw.RoundedBox(scale(2), bx + scale(3), by, scale(3), bh, Color(245, 248, 255, 235))
    end)

    local model = vgui.Create("DModelPanel", host)
    model:Dock(FILL)
    model:DockMargin(scale(12), scale(72), scale(42), scale(12))
    model:SetMouseInputEnabled(true)
    model.LayoutEntity = function(self, ent)
        ent:SetAngles(Angle(0, (RealTime() * 18) % 360, 0))
    end
    configureModelPanel(model)
    host.ModelPanel = model
    return host
end

local function createItemRow(parent, name, typeId)
    local item = safeItem(name) or {Name = name, Description = "Unknown component"}
    local row = vgui.Create("DButton", parent)
    row:SetText("")
    row:SetTall(scale(76))
    row:Dock(TOP)
    row:DockMargin(0, 0, 0, scale(7))
    row.Paint = function(self, w, h)
        local c = theme()
        local equipped = currentEquip()
        local active = equipped and equipped[typeId] == name
        local fill = active and Color(c.AccentDark.r, c.AccentDark.g, c.AccentDark.b, 245) or (self:IsHovered() and c.Hover or c.Panel)
        angularBox(0, 0, w, h, fill, active and c.AccentBright or c.SteelDark, scale(7))
        if active then
            surface.SetDrawColor(c.AccentBright)
            surface.DrawRect(0, 0, scale(4), h)
        end

        shadowText(item.Name or name, "ImperialOrderCraft.BodyBold", scale(15), scale(13), c.Text)
        shadowText(item.Description or "", "ImperialOrderCraft.Small", scale(15), scale(40), c.TextDim)

        local rightText = active and "INSTALLED" or (name == "Standard" and "AVAILABLE" or (inventoryCount(name) .. " OWNED"))
        local rightCol = active and c.Success or c.TextDim
        shadowText(rightText, "ImperialOrderCraft.SmallBold", w - scale(15), scale(14), rightCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        if item.BurnOnUse then
            shadowText("CONSUMED ON USE", "ImperialOrderCraft.Micro", w - scale(15), scale(42), c.Warning, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        elseif item.RarityName then
            shadowText(string.upper(item.RarityName), "ImperialOrderCraft.Micro", w - scale(15), scale(42), item.RarityColor or c.TextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        end
    end
    row.DoClick = function() selectComponent(typeId, name) end
    return row
end

local function buildComponentPage(content, typeId)
    local meta = TYPE_META[typeId] or {title = "COMPONENT", subtitle = "LIGHTSABER COMPONENT"}
    local heading = panel(content, function(self, w, h)
        local c = theme()
        shadowText(meta.title, "ImperialOrderCraft.Title", 0, 0, c.Text)
        shadowText(meta.subtitle, "ImperialOrderCraft.SmallBold", 0, scale(39), c.TextDim)
        line(0, h - 1, w, c.Line)
    end)
    heading:Dock(TOP)
    heading:SetTall(scale(72))

    local scroll = vgui.Create("DScrollPanel", content)
    scroll:Dock(FILL)
    scroll:DockMargin(0, scale(10), 0, 0)
    for _, name in ipairs(getComponentChoices(typeId)) do
        createItemRow(scroll, name, typeId)
    end
end

local function componentName(typeId)
    local equipped = currentEquip()
    return equipped and equipped[typeId] or "Standard"
end

local function buildAssemblyPage(content)
    local c = theme()
    local heading = panel(content, function(self, w, h)
        shadowText("LIGHTSABER ASSEMBLY", "ImperialOrderCraft.Title", 0, 0, c.Text)
        shadowText("Review the installed chassis and internal components before fabrication.", "ImperialOrderCraft.Body", 0, scale(41), c.TextDim)
        line(0, h - 1, w, c.Line)
    end)
    heading:Dock(TOP)
    heading:SetTall(scale(78))

    local cards = vgui.Create("DIconLayout", content)
    cards:Dock(TOP)
    cards:SetTall(scale(260))
    cards:DockMargin(0, scale(10), 0, scale(10))
    cards:SetSpaceX(scale(8))
    cards:SetSpaceY(scale(8))

    for _, typeId in ipairs({5, 1, 2, 3, 4}) do
        local meta = TYPE_META[typeId]
        local card = cards:Add("DButton")
        card:SetText("")
        card:SetSize(scale(235), scale(118))
        card.Paint = function(self, w, h)
            local cc = theme()
            angularBox(0, 0, w, h, self:IsHovered() and cc.Hover or cc.Panel, cc.SteelDark, scale(7))
            surface.SetDrawColor(cc.Accent)
            surface.DrawRect(0, 0, scale(4), h)
            shadowText(meta.title, "ImperialOrderCraft.SubHeader", scale(14), scale(13), cc.Text)
            shadowText(meta.subtitle, "ImperialOrderCraft.Micro", scale(14), scale(38), cc.TextDim)
            line(scale(14), scale(59), w - scale(28), cc.Line)
            shadowText(componentName(typeId), "ImperialOrderCraft.SmallBold", scale(14), scale(74), cc.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
        card.DoClick = function()
            UI.ActivePage = meta.title
            UI.Refresh()
        end
    end

    local info = panel(content, function(self, w, h)
        local cc = theme()
        angularBox(0, 0, w, h, cc.BackgroundSoft, cc.SteelDark, scale(7))
        local ply = LocalPlayer()
        local lvl = IsValid(ply) and ply:GetNW2Int("wOS.ProficiencyLevel", 0) or 0
        local xp = IsValid(ply) and ply:GetNW2Int("wOS.ProficiencyExperience", 0) or 0
        shadowText("SABER PROFICIENCY", "ImperialOrderCraft.SubHeader", scale(15), scale(14), cc.Text)
        shadowText("LEVEL " .. lvl, "ImperialOrderCraft.BodyBold", scale(15), scale(48), cc.Warning)
        shadowText("XP " .. xp, "ImperialOrderCraft.SmallBold", scale(120), scale(51), cc.TextDim)
        shadowText("Proficiency mods can be installed from the Mods tab when slots are unlocked.", "ImperialOrderCraft.Small", scale(15), scale(82), cc.TextDim)
    end)
    info:Dock(TOP)
    info:SetTall(scale(118))

    local fabricate = styledButton(content, "FABRICATE LIGHTSABER", function()
        if not wOS then return end
        net.Start("wOS.Crafting.UpdateItems")
            net.WriteTable(wOS.EquippedItems or {})
            net.WriteTable(wOS.SecEquippedItems or {})
            net.WriteTable(wOS.SaberMiscSlots or {})
        net.SendToServer()
        surface.PlaySound("buttons/button24.wav")
        UI.Close(false, false)
    end, function() return true end)
    fabricate:Dock(BOTTOM)
    fabricate:SetTall(scale(48))
end

local function getUnlockedModSlots()
    local levelPerSlot = wOS and wOS.ALCS and wOS.ALCS.Config and wOS.ALCS.Config.Crafting and tonumber(wOS.ALCS.Config.Crafting.LevelPerSlot) or 0
    if levelPerSlot <= 0 then return 0, 0 end
    local ply = LocalPlayer()
    local level = IsValid(ply) and ply:GetNW2Int("wOS.ProficiencyLevel", 0) or 0
    return math.max(0, math.floor(level / levelPerSlot)), levelPerSlot
end

local function getModChoices()
    local result = {"Empty"}
    local names = {}
    for _, typeId in ipairs({6, 7}) do
        local tbl = wOS and wOS.SortedItemList and wOS.SortedItemList[typeId] or {}
        for name in pairs(tbl or {}) do
            if name ~= "Standard" and hasInventoryItem(name) then names[name] = true end
        end
    end
    local sorted = {}
    for name in pairs(names) do sorted[#sorted + 1] = name end
    table.sort(sorted, function(a, b) return string.lower(a) < string.lower(b) end)
    for _, name in ipairs(sorted) do result[#result + 1] = name end
    return result
end

local function buildModsPage(content)
    local slots, levelPerSlot = getUnlockedModSlots()
    local c = theme()
    local heading = panel(content, function(self, w, h)
        shadowText("PROFICIENCY MODS", "ImperialOrderCraft.Title", 0, 0, c.Text)
        shadowText(slots > 0 and (slots .. " modification slots unlocked") or ("Unlocks every " .. math.max(1, levelPerSlot) .. " proficiency levels"), "ImperialOrderCraft.Body", 0, scale(41), c.TextDim)
        line(0, h - 1, w, c.Line)
    end)
    heading:Dock(TOP)
    heading:SetTall(scale(78))

    local body = panel(content, function() end)
    body:Dock(FILL)
    body:DockMargin(0, scale(10), 0, 0)

    local left = vgui.Create("DScrollPanel", body)
    left:Dock(LEFT)
    left:SetWide(scale(255))
    left:DockMargin(0, 0, scale(10), 0)

    if slots <= 0 then
        local empty = panel(left, function(self, w, h)
            local cc = theme()
            angularBox(0, 0, w, h, cc.Panel, cc.SteelDark, scale(7))
            shadowText("NO MOD SLOTS AVAILABLE", "ImperialOrderCraft.BodyBold", w / 2, h / 2 - scale(8), cc.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            shadowText("Increase saber proficiency.", "ImperialOrderCraft.Small", w / 2, h / 2 + scale(18), cc.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end)
        empty:Dock(TOP)
        empty:SetTall(scale(110))
    else
        UI.SelectedModSlot = math.Clamp(UI.SelectedModSlot or 1, 1, slots)
        for i = 1, slots do
            local slot = i
            local b = styledButton(left, "SLOT " .. slot .. "  •  " .. ((wOS.SaberMiscSlots and wOS.SaberMiscSlots[slot]) or "EMPTY"), function()
                UI.SelectedModSlot = slot
                UI.Refresh()
            end, function() return UI.SelectedModSlot == slot end)
            b:Dock(TOP)
            b:SetTall(scale(50))
            b:DockMargin(0, 0, 0, scale(7))
        end
    end

    local right = vgui.Create("DScrollPanel", body)
    right:Dock(FILL)

    if slots > 0 then
        for _, name in ipairs(getModChoices()) do
            local item = safeItem(name) or {Name = name, Description = "Proficiency modification"}
            local row = vgui.Create("DButton", right)
            row:SetText("")
            row:SetTall(scale(70))
            row:Dock(TOP)
            row:DockMargin(0, 0, 0, scale(7))
            row.Paint = function(self, w, h)
                local cc = theme()
                local installed = wOS.SaberMiscSlots and wOS.SaberMiscSlots[UI.SelectedModSlot] == name
                local otherSlot = nil
                if name ~= "Empty" and wOS.SaberMiscSlots then
                    for slot, installedName in pairs(wOS.SaberMiscSlots) do
                        if installedName == name and slot ~= UI.SelectedModSlot then otherSlot = slot break end
                    end
                end
                local fill = installed and Color(cc.AccentDark.r, cc.AccentDark.g, cc.AccentDark.b, 245) or (self:IsHovered() and cc.Hover or cc.Panel)
                angularBox(0, 0, w, h, fill, installed and cc.AccentBright or cc.SteelDark, scale(7))
                shadowText(item.Name or name, "ImperialOrderCraft.BodyBold", scale(14), scale(12), cc.Text)
                shadowText(item.Description or "", "ImperialOrderCraft.Small", scale(14), scale(39), cc.TextDim)
                if otherSlot then
                    shadowText("IN SLOT " .. otherSlot, "ImperialOrderCraft.SmallBold", w - scale(14), h / 2, cc.Danger, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                elseif installed then
                    shadowText("INSTALLED", "ImperialOrderCraft.SmallBold", w - scale(14), h / 2, cc.Success, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end
            end
            row.DoClick = function()
                if not wOS.SaberMiscSlots then wOS.SaberMiscSlots = {} end
                if name == "Empty" then
                    wOS.SaberMiscSlots[UI.SelectedModSlot] = nil
                    UI.Refresh()
                    return
                end
                for slot, installedName in pairs(wOS.SaberMiscSlots) do
                    if installedName == name and slot ~= UI.SelectedModSlot then
                        notify("That mod is already installed in slot " .. slot, NOTIFY_ERROR)
                        return
                    end
                end
                wOS.SaberMiscSlots[UI.SelectedModSlot] = name
                UI.Refresh()
            end
        end
    end
end

local function getBlueprints()
    local result = {}
    local tbl = wOS and wOS.SortedItemList and wOS.SortedItemList[8] or {}
    for name, data in pairs(tbl or {}) do
        if hasInventoryItem(name) then result[#result + 1] = data end
    end
    table.sort(result, function(a, b) return string.lower(a.Name or "") < string.lower(b.Name or "") end)
    return result
end

local function materialAmount(name)
    return tonumber(wOS and wOS.RawMaterials and wOS.RawMaterials[name]) or 0
end

local function canCraftBlueprint(bp)
    if not bp or not istable(bp.Ingredients) then return false end
    for mat, amount in pairs(bp.Ingredients) do
        if materialAmount(mat) < (tonumber(amount) or 0) then return false end
    end
    return true
end

local function buildForgePage(content)
    local c = theme()
    local heading = panel(content, function(self, w, h)
        shadowText("BLUEPRINT FORGE", "ImperialOrderCraft.Title", 0, 0, c.Text)
        shadowText("Convert collected raw materials into registered lightsaber components.", "ImperialOrderCraft.Body", 0, scale(41), c.TextDim)
        line(0, h - 1, w, c.Line)
    end)
    heading:Dock(TOP)
    heading:SetTall(scale(78))

    local body = panel(content, function() end)
    body:Dock(FILL)
    body:DockMargin(0, scale(10), 0, 0)

    local list = vgui.Create("DScrollPanel", body)
    list:Dock(LEFT)
    list:SetWide(scale(430))
    list:DockMargin(0, 0, scale(10), 0)

    local blueprints = getBlueprints()
    if #blueprints == 0 then
        local empty = panel(list, function(self, w, h)
            local cc = theme()
            angularBox(0, 0, w, h, cc.Panel, cc.SteelDark, scale(7))
            shadowText("NO BLUEPRINTS AVAILABLE", "ImperialOrderCraft.BodyBold", w / 2, h / 2, cc.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end)
        empty:Dock(TOP)
        empty:SetTall(scale(110))
    end

    for _, bp in ipairs(blueprints) do
        local data = bp
        local b = vgui.Create("DButton", list)
        b:SetText("")
        b:SetTall(scale(72))
        b:Dock(TOP)
        b:DockMargin(0, 0, 0, scale(7))
        b.Paint = function(self, w, h)
            local cc = theme()
            local active = UI.SelectedBlueprint == data
            angularBox(0, 0, w, h, active and Color(cc.AccentDark.r, cc.AccentDark.g, cc.AccentDark.b, 245) or (self:IsHovered() and cc.Hover or cc.Panel), active and cc.AccentBright or cc.SteelDark, scale(7))
            shadowText(data.Name or "Blueprint", "ImperialOrderCraft.BodyBold", scale(14), scale(12), cc.Text)
            shadowText(data.Description or "", "ImperialOrderCraft.Small", scale(14), scale(40), cc.TextDim)
            shadowText(inventoryCount(data.Name) .. " OWNED", "ImperialOrderCraft.Micro", w - scale(14), scale(14), cc.TextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        end
        b.DoClick = function()
            UI.SelectedBlueprint = data
            UI.Refresh()
        end
    end

    local detail = panel(body, function(self, w, h)
        local cc = theme()
        angularBox(0, 0, w, h, cc.BackgroundSoft, cc.SteelDark, scale(8))
        local bp = UI.SelectedBlueprint
        if not bp then
            shadowText("SELECT A BLUEPRINT", "ImperialOrderCraft.Header", w / 2, h / 2 - scale(12), cc.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            shadowText("Requirements and output will appear here.", "ImperialOrderCraft.Small", w / 2, h / 2 + scale(17), cc.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            return
        end
        shadowText(bp.Name or "Blueprint", "ImperialOrderCraft.Header", scale(18), scale(18), cc.Text)
        shadowText("OUTPUT  •  " .. tostring(bp.Result or "Unknown"), "ImperialOrderCraft.SmallBold", scale(18), scale(54), cc.Warning)
        line(scale(18), scale(82), w - scale(36), cc.Line)
        shadowText("MATERIAL REQUIREMENTS", "ImperialOrderCraft.SubHeader", scale(18), scale(100), cc.Text)
        local y = scale(136)
        for mat, amount in pairs(bp.Ingredients or {}) do
            local have = materialAmount(mat)
            local need = tonumber(amount) or 0
            shadowText(mat, "ImperialOrderCraft.Body", scale(18), y, cc.Text)
            shadowText(have .. " / " .. need, "ImperialOrderCraft.BodyBold", w - scale(18), y, have >= need and cc.Success or cc.Danger, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            y = y + scale(30)
        end
    end)
    detail:Dock(FILL)

    local craft = styledButton(detail, "CRAFT BLUEPRINT", function()
        local bp = UI.SelectedBlueprint
        if not bp then notify("Select a blueprint first", NOTIFY_ERROR) return end
        if not canCraftBlueprint(bp) then notify("Missing required raw materials", NOTIFY_ERROR) return end
        net.Start("wOS.Crafting.CraftBlueprint")
            net.WriteString(bp.Name)
        net.SendToServer()
        surface.PlaySound("buttons/button24.wav")
    end, function() return canCraftBlueprint(UI.SelectedBlueprint) end)
    craft:Dock(BOTTOM)
    craft:SetTall(scale(48))
    craft:DockMargin(scale(15), scale(10), scale(15), scale(15))
end

local function getSalvageItems()
    local found, order = {}, {}
    if not wOS or not istable(wOS.SaberInventory) then return order end
    for _, entry in pairs(wOS.SaberInventory) do
        local name = istable(entry) and entry.Name or entry
        if name and name ~= "Empty" then
            local item = safeItem(name)
            if item and istable(item.DismantleParts) and not found[name] then
                found[name] = true
                order[#order + 1] = item
            end
        end
    end
    table.sort(order, function(a, b) return string.lower(a.Name or "") < string.lower(b.Name or "") end)
    return order
end

local function buildSalvagePage(content)
    local c = theme()
    local heading = panel(content, function(self, w, h)
        shadowText("SALVAGE", "ImperialOrderCraft.Title", 0, 0, c.Text)
        shadowText("Break eligible components down into reusable crafting materials.", "ImperialOrderCraft.Body", 0, scale(41), c.TextDim)
        line(0, h - 1, w, c.Line)
    end)
    heading:Dock(TOP)
    heading:SetTall(scale(78))

    local body = panel(content, function() end)
    body:Dock(FILL)
    body:DockMargin(0, scale(10), 0, 0)

    local list = vgui.Create("DScrollPanel", body)
    list:Dock(LEFT)
    list:SetWide(scale(430))
    list:DockMargin(0, 0, scale(10), 0)

    local items = getSalvageItems()
    if #items == 0 then
        local empty = panel(list, function(self, w, h)
            local cc = theme()
            angularBox(0, 0, w, h, cc.Panel, cc.SteelDark, scale(7))
            shadowText("NO SALVAGEABLE ITEMS", "ImperialOrderCraft.BodyBold", w / 2, h / 2, cc.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end)
        empty:Dock(TOP)
        empty:SetTall(scale(110))
    end

    for _, item in ipairs(items) do
        local data = item
        local b = vgui.Create("DButton", list)
        b:SetText("")
        b:SetTall(scale(72))
        b:Dock(TOP)
        b:DockMargin(0, 0, 0, scale(7))
        b.Paint = function(self, w, h)
            local cc = theme()
            local active = UI.SelectedSalvage == data
            angularBox(0, 0, w, h, active and Color(cc.AccentDark.r, cc.AccentDark.g, cc.AccentDark.b, 245) or (self:IsHovered() and cc.Hover or cc.Panel), active and cc.AccentBright or cc.SteelDark, scale(7))
            shadowText(data.Name or "Item", "ImperialOrderCraft.BodyBold", scale(14), scale(12), cc.Text)
            shadowText(data.Description or "", "ImperialOrderCraft.Small", scale(14), scale(40), cc.TextDim)
            shadowText(inventoryCount(data.Name) .. " OWNED", "ImperialOrderCraft.Micro", w - scale(14), scale(14), cc.TextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        end
        b.DoClick = function()
            UI.SelectedSalvage = data
            UI.Refresh()
        end
    end

    local detail = panel(body, function(self, w, h)
        local cc = theme()
        angularBox(0, 0, w, h, cc.BackgroundSoft, cc.SteelDark, scale(8))
        local item = UI.SelectedSalvage
        if not item then
            shadowText("SELECT AN ITEM", "ImperialOrderCraft.Header", w / 2, h / 2, cc.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            return
        end
        shadowText(item.Name or "Item", "ImperialOrderCraft.Header", scale(18), scale(18), cc.Text)
        line(scale(18), scale(62), w - scale(36), cc.Line)
        shadowText("RECOVERED MATERIALS", "ImperialOrderCraft.SubHeader", scale(18), scale(82), cc.Text)
        local y = scale(119)
        for mat, amount in pairs(item.DismantleParts or {}) do
            shadowText(mat, "ImperialOrderCraft.Body", scale(18), y, cc.Text)
            shadowText("+" .. tostring(amount), "ImperialOrderCraft.BodyBold", w - scale(18), y, cc.Success, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            y = y + scale(30)
        end
    end)
    detail:Dock(FILL)

    local salvage = styledButton(detail, "SALVAGE ITEM", function()
        local item = UI.SelectedSalvage
        if not item then notify("Select an item first", NOTIFY_ERROR) return end
        net.Start("wOS.Crafting.SmeltItem")
            net.WriteString(item.Name)
        net.SendToServer()
        surface.PlaySound("buttons/button24.wav")
    end, function() return UI.SelectedSalvage ~= nil end, true)
    salvage:Dock(BOTTOM)
    salvage:SetTall(scale(48))
    salvage:DockMargin(scale(15), scale(10), scale(15), scale(15))
end

local function buildPage(content)
    if not IsValid(content) then return end
    content:Clear()
    local page = UI.ActivePage or "ASSEMBLY"
    local meta = getPageMeta(page)
    if meta.typeId then
        buildComponentPage(content, meta.typeId)
    elseif page == "MODS" then
        buildModsPage(content)
    elseif page == "FORGE" then
        buildForgePage(content)
    elseif page == "SALVAGE" then
        buildSalvagePage(content)
    else
        buildAssemblyPage(content)
    end
end

function UI.Refresh()
    if not IsValid(UI.Frame) then return end
    if IsValid(UI.Frame.Content) then buildPage(UI.Frame.Content) end
    if IsValid(UI.Frame.Preview) and IsValid(UI.Frame.Preview.ModelPanel) then configureModelPanel(UI.Frame.Preview.ModelPanel) end
end

local function buildMainFrame()
    closeVisuals()

    local frame = vgui.Create("DFrame")
    UI.Frame = frame
    frame:SetSize(math.min(ScrW() - scale(50), scale(1680)), math.min(ScrH() - scale(50), scale(960)))
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(false)
    frame:MakePopup()
    frame.Paint = function(self, w, h)
        local c = theme()
        angularBox(0, 0, w, h, c.Background, c.Accent, scale(12))
        surface.SetDrawColor(c.Accent)
        surface.DrawRect(0, 0, scale(5), h)
        surface.SetDrawColor(c.SteelDark)
        surface.DrawRect(scale(5), scale(72), w - scale(10), 1)
        shadowText(string.upper(UI.Brand:GetString()), "ImperialOrderCraft.SmallBold", scale(22), scale(15), c.AccentBright)
        shadowText("LIGHTSABER CRAFTING INTERFACE", "ImperialOrderCraft.Title", scale(22), scale(31), c.Text)
        shadowText("WILTOS CRAFTING LINK ACTIVE", "ImperialOrderCraft.Micro", w - scale(65), scale(51), c.TextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    end
    frame.Think = function()
        if not IsValid(LocalPlayer()) or not LocalPlayer():Alive() then
            UI.Close(true, true)
        end
    end
    frame.OnKeyCodePressed = function(_, key)
        if key == KEY_ESCAPE or key == KEY_BACKSPACE then UI.Close(true, true) end
    end

    local close = styledButton(frame, "×", function() UI.Close(true, true) end, nil, true)
    close:SetSize(scale(42), scale(38))
    close:SetPos(frame:GetWide() - scale(54), scale(17))

    local sidebar = panel(frame, function(self, w, h)
        local c = theme()
        angularBox(0, 0, w, h, c.BackgroundSoft, c.SteelDark, scale(8))
    end)
    sidebar:SetPos(scale(18), scale(88))
    sidebar:SetSize(scale(255), frame:GetTall() - scale(106))

    local sideScroll = vgui.Create("DScrollPanel", sidebar)
    sideScroll:Dock(FILL)
    sideScroll:DockMargin(scale(9), scale(9), scale(9), scale(9))
    for _, page in ipairs(PAGES) do
        local data = page
        local b = styledButton(sideScroll, data.label, function()
            UI.ActivePage = data.id
            UI.Refresh()
        end, function() return UI.ActivePage == data.id end)
        b:Dock(TOP)
        b:SetTall(scale(47))
        b:DockMargin(0, 0, 0, scale(7))
    end

    local switch = styledButton(sideScroll, wOS and wOS.UsingDualLightsaber and "SWITCH TO PRIMARY" or "SWITCH TO OFF-HAND", function()
        local dual = not (wOS and wOS.UsingDualLightsaber == true)
        if wOS then
            wOS.UsingDualLightsaber = dual
            wOS.CurrentInventoryTable = dual and "SecEquippedItems" or "EquippedItems"
            wOS.CurrentCraftTable = dual and "SecPersonalSaber" or "PersonalSaber"
            UI.Original.CurrentItems = table.Copy(currentEquip() or {})
        end
        UI.ActivePage = "ASSEMBLY"
        UI.Refresh()
    end)
    switch:Dock(BOTTOM)
    switch:SetTall(scale(47))
    switch:DockMargin(0, scale(8), 0, 0)

    local contentX = scale(291)
    local previewW = scale(410)
    local preview = createPreview(frame)
    frame.Preview = preview
    preview:SetPos(frame:GetWide() - previewW - scale(18), scale(88))
    preview:SetSize(previewW, frame:GetTall() - scale(106))

    local content = panel(frame, function() end)
    frame.Content = content
    content:SetPos(contentX, scale(88))
    content:SetSize(frame:GetWide() - contentX - previewW - scale(36), frame:GetTall() - scale(106))

    buildPage(content)
end

local function selectorCard(parent, title, subtitle, primary, x)
    local c = styledButton(parent, title, function()
        if not wOS then return end
        wOS.UsingDualLightsaber = not primary
        wOS.CurrentInventoryTable = primary and "EquippedItems" or "SecEquippedItems"
        wOS.CurrentCraftTable = primary and "PersonalSaber" or "SecPersonalSaber"
        UI.Original.CurrentItems = table.Copy(currentEquip() or {})
        buildMainFrame()
    end, nil)
    c:SetText("")
    c:SetPos(x, scale(160))
    c:SetSize(scale(330), scale(190))
    c.Paint = function(self, w, h)
        local cc = theme()
        angularBox(0, 0, w, h, self:IsHovered() and cc.Hover or cc.Panel, self:IsHovered() and cc.AccentBright or cc.SteelDark, scale(10))
        surface.SetDrawColor(cc.Accent)
        surface.DrawRect(0, 0, scale(5), h)
        shadowText(title, "ImperialOrderCraft.Header", scale(20), scale(28), cc.Text)
        shadowText(subtitle, "ImperialOrderCraft.Body", scale(20), scale(68), cc.TextDim)
        line(scale(20), scale(108), w - scale(40), cc.Line)
        shadowText("OPEN ASSEMBLY", "ImperialOrderCraft.SmallBold", scale(20), scale(133), cc.AccentBright)
        shadowText("›", "ImperialOrderCraft.Title", w - scale(24), scale(131), cc.Text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    end
    return c
end

local function openSelector()
    closeVisuals()

    local frame = vgui.Create("DFrame")
    UI.Selector = frame
    frame:SetSize(scale(760), scale(430))
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(false)
    frame:MakePopup()
    frame.Paint = function(self, w, h)
        local c = theme()
        angularBox(0, 0, w, h, c.Background, c.Accent, scale(12))
        surface.SetDrawColor(c.Accent)
        surface.DrawRect(0, 0, scale(5), h)
        shadowText(string.upper(UI.Brand:GetString()), "ImperialOrderCraft.SmallBold", scale(22), scale(18), c.AccentBright)
        shadowText("SELECT LIGHTSABER ASSEMBLY", "ImperialOrderCraft.Title", scale(22), scale(40), c.Text)
        shadowText("Choose which weapon configuration you want to modify.", "ImperialOrderCraft.Body", scale(22), scale(84), c.TextDim)
        line(scale(22), scale(119), w - scale(44), c.Line)
    end
    frame.Think = function()
        if not IsValid(LocalPlayer()) or not LocalPlayer():Alive() then UI.Close(true, true) end
    end
    frame.OnKeyCodePressed = function(_, key)
        if key == KEY_ESCAPE or key == KEY_BACKSPACE then UI.Close(true, true) end
    end

    local close = styledButton(frame, "×", function() UI.Close(true, true) end, nil, true)
    close:SetSize(scale(42), scale(38))
    close:SetPos(frame:GetWide() - scale(54), scale(17))

    selectorCard(frame, "PRIMARY LIGHTSABER", "Main-hand saber configuration", true, scale(40))
    selectorCard(frame, "OFF-HAND LIGHTSABER", "Secondary / dual-saber configuration", false, scale(390))
end

function UI.Open()
    if not UI.Enabled:GetBool() then
        if UI.Original.OpenSaberCrafting then return UI.Original.OpenSaberCrafting(wOS) end
        return
    end

    if IsValid(UI.Frame) or IsValid(UI.Selector) then
        UI.Close(true, true)
        return
    end

    UI.Original.EquippedItems = table.Copy(wOS.EquippedItems or {})
    UI.Original.SecEquippedItems = table.Copy(wOS.SecEquippedItems or {})
    UI.Original.SaberMiscSlots = table.Copy(wOS.SaberMiscSlots or {})
    UI.SelectedBlueprint = nil
    UI.SelectedSalvage = nil
    UI.ActivePage = "ASSEMBLY"
    openSelector()
end

local function patchWiltOS()
    if not wOS or not isfunction(wOS.OpenSaberCrafting) then return false end

    if not UI.Original.OpenSaberCrafting then UI.Original.OpenSaberCrafting = wOS.OpenSaberCrafting end
    if not UI.Original.RebuildCraftingMenus and isfunction(wOS.RebuildCraftingMenus) then UI.Original.RebuildCraftingMenus = wOS.RebuildCraftingMenus end
    if not UI.Original.BuildCraftingSaber and isfunction(wOS.BuildCraftingSaber) then UI.Original.BuildCraftingSaber = wOS.BuildCraftingSaber end
    if not UI.Original.CleanCraftingMenus and isfunction(wOS.CleanCraftingMenus) then UI.Original.CleanCraftingMenus = wOS.CleanCraftingMenus end

    wOS.OpenSaberCrafting = function()
        if UI.Enabled:GetBool() then return UI.Open() end
        if UI.Original.OpenSaberCrafting then return UI.Original.OpenSaberCrafting(wOS) end
    end
    UI.InstalledOpenFunction = wOS.OpenSaberCrafting

    if UI.Original.RebuildCraftingMenus then
        wOS.RebuildCraftingMenus = function()
            if IsValid(UI.Frame) then UI.Refresh() return end
            return UI.Original.RebuildCraftingMenus(wOS)
        end
    end

    if UI.Original.BuildCraftingSaber then
        wOS.BuildCraftingSaber = function()
            if IsValid(UI.Frame) then
                timer.Simple(0, UI.Refresh)
                return
            end
            return UI.Original.BuildCraftingSaber(wOS)
        end
    end

    if UI.Original.CleanCraftingMenus then
        wOS.CleanCraftingMenus = function(_, button)
            if IsValid(UI.Frame) or IsValid(UI.Selector) then
                closeVisuals()
                return
            end
            return UI.Original.CleanCraftingMenus(wOS, button)
        end
    end

    UI.Patched = true
    return true
end

local function ensurePatch()
    if not wOS or not isfunction(wOS.OpenSaberCrafting) then return end
    if not UI.Patched or wOS.OpenSaberCrafting ~= UI.InstalledOpenFunction then
        -- If wiltOS reloaded its own file, preserve the new native function and reinstall.
        if UI.Patched then UI.Original.OpenSaberCrafting = wOS.OpenSaberCrafting end
        patchWiltOS()
    end
end

timer.Create("ImperialOrderCraftingUI.Install", 1, 0, ensurePatch)
hook.Add("InitPostEntity", "ImperialOrderCraftingUI.Install", function() timer.Simple(1, ensurePatch) end)
hook.Add("OnReloaded", "ImperialOrderCraftingUI.Reload", function()
    timer.Simple(0.2, function()
        UI.Patched = false
        ensurePatch()
    end)
end)

concommand.Add("imperial_order_saber_crafting", function()
    ensurePatch()
    if not wOS or not isfunction(wOS.OpenSaberCrafting) then
        notify("wiltOS crafting has not loaded", NOTIFY_ERROR)
        return
    end
    if not istable(wOS.EquippedItems) or not istable(wOS.SaberInventory) then
        notify("Use a wiltOS saber crafting station first so the server can send your inventory", NOTIFY_ERROR)
        return
    end
    wOS:OpenSaberCrafting()
end)

concommand.Add("imperial_order_crafting_ui_reload", function()
    rebuildFonts()
    ensurePatch()
    if IsValid(UI.Frame) then UI.Refresh() end
    notify("Imperial Order crafting UI refreshed", NOTIFY_GENERIC)
end)

print("[Imperial Order Crafting UI] Loaded v" .. UI.Version)
