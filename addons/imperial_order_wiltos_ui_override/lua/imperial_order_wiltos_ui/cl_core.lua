IMPERIAL_ORDER_WILTOS_UI = IMPERIAL_ORDER_WILTOS_UI or {}
local UI = IMPERIAL_ORDER_WILTOS_UI

UI.Version = "1.2.2"
UI.Name = "Imperial wiltOS Interface"
UI.Frame = UI.Frame or nil
UI.FormFrame = UI.FormFrame or nil
UI.Original = UI.Original or {}
UI.SelectedTree = UI.SelectedTree or nil
UI.SelectedSkill = UI.SelectedSkill or nil

UI.CVarEnabled = CreateClientConVar("imperial_order_wiltos_ui_enabled", "1", true, false, "Enable the Imperial wiltOS UI override.")
UI.CVarF2 = CreateClientConVar("imperial_order_wiltos_ui_f2", "0", true, false, "Legacy setting. wiltOS is station/command driven and does not own a function key.")
UI.CVarHUD = CreateClientConVar("imperial_order_wiltos_ui_hud", "1", true, false, "Enable the Imperial wiltOS HUD.")
UI.CVarProgress = CreateClientConVar("imperial_order_wiltos_ui_progress_hud", "1", true, false, "Show wiltOS progression at the top of the HUD.")

UI.Colors = {
    Background = Color(7, 8, 10, 248),
    Panel = Color(16, 18, 22, 245),
    PanelSoft = Color(24, 27, 32, 235),
    Header = Color(11, 12, 15, 252),
    Accent = Color(178, 24, 33, 255),
    AccentBright = Color(235, 48, 58, 255),
    AccentDark = Color(86, 11, 17, 255),
    Steel = Color(102, 111, 124, 255),
    SteelDark = Color(48, 53, 62, 255),
    Text = Color(238, 240, 244, 255),
    TextDim = Color(155, 163, 176, 255),
    TextDark = Color(82, 88, 98, 255),
    Success = Color(74, 190, 116, 255),
    Warning = Color(225, 165, 54, 255),
    Danger = Color(226, 60, 67, 255),
    Black = Color(0, 0, 0, 255),
}

local function fontSize(base)
    return math.max(12, math.floor(base * math.Clamp(ScrH() / 1080, 0.72, 1.35)))
end

function UI.CreateFonts()
    surface.CreateFont("IMPERIAL_ORDER.WOS.Title", {font = "Roboto", size = fontSize(30), weight = 900, extended = true})
    surface.CreateFont("IMPERIAL_ORDER.WOS.Header", {font = "Roboto", size = fontSize(22), weight = 850, extended = true})
    surface.CreateFont("IMPERIAL_ORDER.WOS.SubHeader", {font = "Roboto", size = fontSize(18), weight = 800, extended = true})
    surface.CreateFont("IMPERIAL_ORDER.WOS.Body", {font = "Roboto", size = fontSize(16), weight = 500, extended = true})
    surface.CreateFont("IMPERIAL_ORDER.WOS.BodyBold", {font = "Roboto", size = fontSize(16), weight = 800, extended = true})
    surface.CreateFont("IMPERIAL_ORDER.WOS.Small", {font = "Roboto", size = fontSize(13), weight = 550, extended = true})
    surface.CreateFont("IMPERIAL_ORDER.WOS.SmallBold", {font = "Roboto", size = fontSize(13), weight = 850, extended = true})
    surface.CreateFont("IMPERIAL_ORDER.WOS.HUD", {font = "Roboto", size = fontSize(14), weight = 800, extended = true})
    surface.CreateFont("IMPERIAL_ORDER.WOS.HUDLarge", {font = "Roboto", size = fontSize(19), weight = 900, extended = true})
end

UI.CreateFonts()
hook.Add("OnScreenSizeChanged", "IMPERIAL_ORDER.WiltOS.UI.FontRefresh", UI.CreateFonts)

function UI.Scale(value)
    return math.floor(value * math.Clamp(ScrH() / 1080, 0.72, 1.35))
end

function UI.SafeRemove(panel)
    if IsValid(panel) then
        panel:Remove()
    end
end

function UI.DrawPanel(x, y, w, h, color, radius)
    draw.RoundedBox(radius or UI.Scale(4), x, y, w, h, color or UI.Colors.Panel)
    surface.SetDrawColor(UI.Colors.SteelDark)
    surface.DrawOutlinedRect(x, y, w, h, 1)
end

function UI.DrawAccentLine(x, y, w, h)
    surface.SetDrawColor(UI.Colors.Accent)
    surface.DrawRect(x, y, w, h or UI.Scale(3))
end

function UI.DrawBar(x, y, w, h, fraction, fill, label, valueText)
    fraction = math.Clamp(tonumber(fraction) or 0, 0, 1)
    draw.RoundedBox(UI.Scale(2), x, y, w, h, Color(3, 4, 6, 230))
    draw.RoundedBox(UI.Scale(2), x + 1, y + 1, math.max(0, (w - 2) * fraction), h - 2, fill or UI.Colors.Accent)
    surface.SetDrawColor(UI.Colors.SteelDark)
    surface.DrawOutlinedRect(x, y, w, h, 1)
    if label then
        draw.SimpleText(label, "IMPERIAL_ORDER.WOS.SmallBold", x + UI.Scale(7), y + h / 2, UI.Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    if valueText then
        draw.SimpleText(valueText, "IMPERIAL_ORDER.WOS.SmallBold", x + w - UI.Scale(7), y + h / 2, UI.Colors.Text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
end

function UI.PaintButton(panel, w, h, text, active, danger)
    local col = UI.Colors.PanelSoft
    if danger then
        col = panel:IsHovered() and Color(132, 24, 31, 255) or Color(82, 20, 25, 255)
    elseif active then
        col = panel:IsHovered() and UI.Colors.AccentBright or UI.Colors.Accent
    elseif panel:IsHovered() then
        col = Color(42, 46, 54, 255)
    end
    draw.RoundedBox(UI.Scale(3), 0, 0, w, h, col)
    surface.SetDrawColor(active and UI.Colors.AccentBright or UI.Colors.SteelDark)
    surface.DrawOutlinedRect(0, 0, w, h, 1)
    draw.SimpleText(text or "", "IMPERIAL_ORDER.WOS.BodyBold", w / 2, h / 2, UI.Colors.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function UI.MakeButton(parent, text, callback, activeFunc, danger)
    local button = vgui.Create("DButton", parent)
    button:SetText("")
    button.Paint = function(self, w, h)
        local active = activeFunc and activeFunc() or false
        UI.PaintButton(self, w, h, text, active, danger)
    end
    button.DoClick = function()
        if callback then callback(button) end
    end
    return button
end

function UI.Notify(text, kind, duration)
    text = tostring(text or "")
    if notification and notification.AddLegacy then
        notification.AddLegacy(text, kind or NOTIFY_GENERIC, duration or 4)
    end
    surface.PlaySound(kind == NOTIFY_ERROR and "buttons/button10.wav" or "buttons/button15.wav")
end

function UI.IsEnabled()
    return UI.CVarEnabled:GetBool()
end


function UI.CanOpenAdminMenu()
    local ply = LocalPlayer()
    return IsValid(ply) and ply:IsAdmin()
end

function UI.OpenAdminMenu()
    local ply = LocalPlayer()

    if not IsValid(ply) or not ply:IsAdmin() then
        UI.Notify("Administrator access is required", NOTIFY_ERROR)
        return false
    end

    if not isfunction(IMPERIAL_ORDER_RequestWiltOSAdminMenu) then
        UI.Notify("The V264 wiltOS admin bridge did not load", NOTIFY_ERROR, 6)
        return false
    end

    UI.CloseMain()
    UI.SafeRemove(UI.FormFrame)
    UI.FormFrame = nil
    return IMPERIAL_ORDER_RequestWiltOSAdminMenu()
end

function UI.NativeProgressHUDEnabled()
    local skills = wOS and wOS.ALCS and wOS.ALCS.Config and wOS.ALCS.Config.Skills
    return istable(skills) and skills.MountLevelToHUD == true
end

local function parseLevelHUDState(value)
    value = string.lower(string.Trim(tostring(value or "")))

    if value == "1" or value == "on" or value == "enable" or value == "enabled" then
        return true
    end

    if value == "0" or value == "off" or value == "disable" or value == "disabled" then
        return false
    end

    return nil
end

function UI.SetProgressHUDEnabled(enabled, showNotice)
    enabled = enabled == true
    RunConsoleCommand("imperial_order_wiltos_ui_progress_hud", enabled and "1" or "0")

    timer.Simple(0, function()
        if UI.InstallHUDOverride then
            UI.InstallHUDOverride()
        end
    end)

    if showNotice ~= false then
        UI.Notify("WiltOS level HUD " .. (enabled and "enabled" or "disabled"), NOTIFY_GENERIC, 4)
    end

    return enabled
end

concommand.Add("imperial_order_wiltos_levelhud", function(_, _, args)
    local requested = parseLevelHUDState(args and args[1])

    if requested == nil then
        requested = not UI.CVarProgress:GetBool()
    end

    local enabled = UI.SetProgressHUDEnabled(requested, true)
    print("[IMPERIAL_ORDER] WiltOS level HUD is now " .. (enabled and "enabled" or "disabled") .. ".")
end, nil, "Toggle the WiltOS level HUD. Usage: imperial_order_wiltos_levelhud [on/off]")
