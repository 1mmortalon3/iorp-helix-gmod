local UI = IMPERIAL_ORDER_WILTOS_UI
local A = UI.Adapter


local function shouldYieldToVehicleHUD()
    local client = LocalPlayer()
    if (not IsValid(client)) then return false end

    if (ImperialUI and isfunction(ImperialUI.ShouldYieldInfantryHUD)) then
        local ok, result = pcall(ImperialUI.ShouldYieldInfantryHUD, client)
        if (ok) then return result == true end
    end

    -- Standalone fallback in case the WiltOS addon loads before the schema UI.
    for _, methodName in ipairs({"lvsGetVehicle", "lfsGetPlane"}) do
        local method = client[methodName]
        if (isfunction(method)) then
            local ok, vehicle = pcall(method, client)
            if (ok and IsValid(vehicle)) then return true end
        end
    end

    return false
end

local function safeNumber(wep, method, fallback)
    return tonumber(A.SafeCall(wep, method, fallback or 0)) or (fallback or 0)
end

local function getPowerList(wep)
    local list = A.SafeCall(wep, "GetActiveForcePowers", nil)
    if not istable(list) then list = wep.ForcePowers end
    return istable(list) and list or {}
end

function UI.DrawProgressHUD()
    if shouldYieldToVehicleHUD() then return end
    if not UI.IsEnabled() or not UI.CVarHUD:GetBool() or not UI.CVarProgress:GetBool() then return end
    if not UI.NativeProgressHUDEnabled() then return end
    if IsValid(UI.Frame) then return end
    local level = A.GetLevel()
    local points = A.GetPoints()
    local xp = A.GetXP()
    local previous, required, fraction = A.GetLevelBounds()
    local w, h = UI.Scale(440), UI.Scale(34)
    local x, y = ScrW() / 2 - w / 2, UI.Scale(10)
    draw.RoundedBox(UI.Scale(3), x, y, w, h, Color(7, 8, 10, 225))
    draw.RoundedBox(UI.Scale(2), x + 1, y + h - UI.Scale(5), (w - 2) * fraction, UI.Scale(4), UI.Colors.Accent)
    surface.SetDrawColor(UI.Colors.SteelDark)
    surface.DrawOutlinedRect(x, y, w, h, 1)
    draw.SimpleText("WILTOS LEVEL " .. level, "IMPERIAL_ORDER.WOS.HUD", x + UI.Scale(10), y + h / 2 - UI.Scale(2), UI.Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(points .. " SP", "IMPERIAL_ORDER.WOS.HUD", x + w - UI.Scale(10), y + h / 2 - UI.Scale(2), points > 0 and UI.Colors.Warning or UI.Colors.TextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    draw.SimpleText(string.Comma(xp) .. " / " .. string.Comma(required), "IMPERIAL_ORDER.WOS.Small", x + w / 2, y + h / 2 - UI.Scale(2), UI.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function UI.DrawSaberHUD(wep)
    if shouldYieldToVehicleHUD() then return end
    if not UI.IsEnabled() or not UI.CVarHUD:GetBool() then return end
    if not IsValid(wep) then return end

    local force = safeNumber(wep, "GetForce", 0)
    local maxForce = math.max(1, safeNumber(wep, "GetMaxForce", 100))
    local stamina = safeNumber(wep, "GetStamina", 0)
    local maxStamina = math.max(1, safeNumber(wep, "GetMaxStamina", 100))
    local powers = getPowerList(wep)
    local selected = math.Clamp(math.floor(safeNumber(wep, "GetForceType", 1)), 1, math.max(1, #powers))
    local form, stance = A.GetCurrentForm(wep)

    local panelW = math.Clamp(UI.Scale(660), UI.Scale(420), ScrW() - UI.Scale(60))
    local icon = UI.Scale(48)
    local gap = UI.Scale(6)
    local barsH = UI.Scale(57)
    local x = ScrW() / 2 - panelW / 2
    local y = ScrH() - UI.Scale(42) - barsH - icon - gap

    draw.RoundedBox(UI.Scale(4), x, y, panelW, barsH + icon + gap + UI.Scale(24), Color(7, 8, 10, 225))
    surface.SetDrawColor(UI.Colors.SteelDark)
    surface.DrawOutlinedRect(x, y, panelW, barsH + icon + gap + UI.Scale(24), 1)
    UI.DrawAccentLine(x, y, panelW, UI.Scale(3))

    draw.SimpleText(form .. "  /  STANCE " .. stance, "IMPERIAL_ORDER.WOS.HUD", x + UI.Scale(12), y + UI.Scale(15), UI.Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    local selectedPower = powers[selected]
    draw.SimpleText(selectedPower and (selectedPower.name or "FORCE POWER") or "NO FORCE POWER", "IMPERIAL_ORDER.WOS.HUD", x + panelW - UI.Scale(12), y + UI.Scale(15), UI.Colors.TextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    UI.DrawBar(x + UI.Scale(12), y + UI.Scale(29), panelW - UI.Scale(24), UI.Scale(15), force / maxForce, Color(154, 31, 42, 255), "FORCE", math.floor(force) .. " / " .. math.floor(maxForce))
    UI.DrawBar(x + UI.Scale(12), y + UI.Scale(47), panelW - UI.Scale(24), UI.Scale(13), stamina / maxStamina, Color(108, 118, 132, 255), "STAMINA", math.floor(stamina) .. " / " .. math.floor(maxStamina))

    local total = #powers
    if total > 0 then
        local totalW = total * icon + math.max(0, total - 1) * gap
        local startX = ScrW() / 2 - totalW / 2
        local iconY = y + barsH + gap
        for index, power in ipairs(powers) do
            local px = startX + (index - 1) * (icon + gap)
            local active = index == selected
            draw.RoundedBox(UI.Scale(3), px, iconY, icon, icon, active and UI.Colors.AccentDark or Color(17, 19, 23, 245))
            surface.SetDrawColor(active and UI.Colors.AccentBright or UI.Colors.SteelDark)
            surface.DrawOutlinedRect(px, iconY, icon, icon, active and 2 or 1)
            local mat = wOS and wOS.ForceIcons and power and wOS.ForceIcons[power.name]
            if mat then
                surface.SetMaterial(mat)
                surface.SetDrawColor(color_white)
                surface.DrawTexturedRect(px + UI.Scale(5), iconY + UI.Scale(5), icon - UI.Scale(10), icon - UI.Scale(10))
            else
                draw.SimpleText(power.icon or index, "IMPERIAL_ORDER.WOS.HUDLarge", px + icon / 2, iconY + icon / 2, UI.Colors.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            draw.SimpleText(index, "IMPERIAL_ORDER.WOS.SmallBold", px + icon - UI.Scale(4), iconY + icon - UI.Scale(3), UI.Colors.TextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
        end
    end
end

hook.Add("HUDPaint", "IMPERIAL_ORDER.WiltOS.UI.ProgressHUD", UI.DrawProgressHUD)

hook.Add("wOS.ALCS.DrawLightsaberHUD", "IMPERIAL_ORDER.WiltOS.UI.OverrideSaberHUD", function(wep)
    if not UI.IsEnabled() or not UI.CVarHUD:GetBool() then return end
    UI.DrawSaberHUD(wep)
    return true
end)

hook.Add("wOS.SkillTrees.OnMountToHud", "IMPERIAL_ORDER.WiltOS.UI.DisableDefaultProgressHUD", function()
    -- While the Imperial HUD controller is active, it owns whether the level bar
    -- is shown. Returning true here prevents the stock WiltOS bar from appearing
    -- when the custom progress HUD is disabled by the player.
    if UI.IsEnabled() and UI.CVarHUD:GetBool() and UI.NativeProgressHUDEnabled() then return true end
end)

local function handleHUDOverride(self, wep)
    if UI.IsEnabled() and UI.CVarHUD:GetBool() then
        UI.DrawSaberHUD(wep)
        if self and isfunction(self.HandleTarget) then
            pcall(self.HandleTarget, self, wep)
        end
        return
    end

    local original = UI.Original and UI.Original.HandleHUD
    if isfunction(original) and original ~= handleHUDOverride then
        return original(self, wep)
    end
end

function UI.InstallHUDOverride()
    if not wOS or not wOS.ALCS or not wOS.ALCS.LightsaberBase then return end
    local base = wOS.ALCS.LightsaberBase
    if base.HandleHUD ~= handleHUDOverride then
        if not UI.Original.HandleHUD and isfunction(base.HandleHUD) then
            UI.Original.HandleHUD = base.HandleHUD
        end
        base.HandleHUD = handleHUDOverride
    end

    local hudHooks = hook.GetTable().HUDPaint or {}
    local mounted = hudHooks["wOS.SkillTrees.MountHUD"]
    if mounted and mounted ~= UI.Original.MountSkillHUD then
        UI.Original.MountSkillHUD = UI.Original.MountSkillHUD or mounted
    end

    local nativeProgress = UI.NativeProgressHUDEnabled()
    local imperialHUDController = UI.IsEnabled() and UI.CVarHUD:GetBool()

    if not nativeProgress or imperialHUDController then
        -- The Imperial controller always suppresses the stock WiltOS level bar.
        -- UI.CVarProgress then controls only the custom Imperial level bar, so
        -- disabling it results in no level bar instead of restoring the stock one.
        hook.Remove("HUDPaint", "wOS.SkillTrees.MountHUD")
    elseif UI.Original.MountSkillHUD and not hook.GetTable().HUDPaint["wOS.SkillTrees.MountHUD"] then
        hook.Add("HUDPaint", "wOS.SkillTrees.MountHUD", UI.Original.MountSkillHUD)
    end
end

hook.Add("InitPostEntity", "IMPERIAL_ORDER.WiltOS.UI.InstallHUD", function()
    timer.Simple(1.25, UI.InstallHUDOverride)
    timer.Simple(4.25, UI.InstallHUDOverride)
end)
timer.Create("IMPERIAL_ORDER.WiltOS.UI.ReapplyHUD", 2, 0, UI.InstallHUDOverride)
