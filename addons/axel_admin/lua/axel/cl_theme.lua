-- Axel Admin Menu: local Derma components. No global skin overrides.
if SERVER then return end

AXEL.UI = AXEL.UI or {}
local UI = AXEL.UI
UI.Version = "1.4.1-axel"

--[[
    UI.C is populated by UI.ApplyTheme and is never replaced, only written into.

    That constraint is the whole reason themes can be swapped without rebuilding
    anything: cl_menu.lua does `local C = UI.C` once at load, and every Paint
    function reads C.background at paint time. Reassigning UI.C would leave that
    upvalue pointing at the old table and half the menu painted in the previous
    theme until the next map change.
]]
UI.C = UI.C or {}
local C = UI.C

--- Non-colour parts of a theme, read live by the drawing helpers below.
UI.Style = UI.Style or {radius = 6}

function UI.ApplyTheme(id)
    local theme = AXEL.GetTheme(id) or AXEL.GetTheme(AXEL.DefaultTheme)
    if (not theme) then return end

    --[[
        Iterate the canonical slot list rather than the theme's own table.

        AXEL.ThemeKeys is a sequential array, so ipairs is correct here and the
        order is deterministic. RegisterTheme guarantees every one of these
        slots is filled - a partial theme is completed from the base palette at
        registration - so there is no nil to guard against, and GetTheme only
        ever returns themes that went through it.

        This is also stricter than iterating theme.colors: a stray key that is
        not a real slot cannot leak into C.
    ]]
    for _, key in ipairs(AXEL.ThemeKeys) do
        local color = theme.colors[key]
        C[key] = Color(color.r, color.g, color.b, color.a)
    end

    UI.Style.radius = theme.radius or 6
    UI.ActiveTheme = theme.id

    hook.Run("AXEL.ThemeChanged", theme.id)
    return theme
end

-- Something must be in C before the first frame; the resolved choice arrives
-- from cl_appearance.lua a moment later.
UI.ApplyTheme(AXEL.DefaultTheme)
local scaleConVar = CreateClientConVar("axel_admin_scale", "1", true, false,
    "Size multiplier for the Axel admin menu (0.75 to 2).")
local scale, textCache = 1, {}
local cacheCount = 0

function UI.S(value) return math.max(1, math.floor(value * scale + 0.5)) end
local S = UI.S

function UI.CreateFonts()
    local auto = math.Clamp(ScrH() / 1080, 0.85, 2.2)
    -- Keep even the largest manual setting usable on small displays.
    local fit = math.min((ScrW() - 24) / 720, (ScrH() - 24) / 510)
    scale = math.max(0.5, math.min(auto * math.Clamp(scaleConVar:GetFloat(), 0.75, 2), fit))
    local fonts = {
        {"Title", 27, 700}, {"Heading", 21, 700}, {"Body", 16, 500},
        {"Button", 15, 600}, {"Small", 13, 500}, {"Label", 12, 700},
        {"Number", 30, 700}
    }
    for _, spec in ipairs(fonts) do
        surface.CreateFont("AXEL." .. spec[1], {
            font = "Roboto", size = math.max(10, S(spec[2])), weight = spec[3],
            antialias = true, extended = true
        })
    end
    textCache, cacheCount = {}, 0
end
UI.CreateFonts()

-- Fit whole UTF-8 characters. Long player names never paint over other controls.
function UI.Fit(value, font, width)
    local text = tostring(value or ""):gsub("[\r\n\t]", " ")
    width = math.max(0, math.floor(width or 0))
    local key = font .. "\0" .. width .. "\0" .. text
    if textCache[key] ~= nil then return textCache[key] end
    surface.SetFont(font)
    local result = text
    if surface.GetTextSize(text) > width then
        local chars = {}
        for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do chars[#chars + 1] = char end
        local low, high = 0, #chars
        while low < high do
            local mid = math.ceil((low + high) / 2)
            if surface.GetTextSize(table.concat(chars, "", 1, mid) .. "...") <= width then
                low = mid
            else high = mid - 1 end
        end
        result = surface.GetTextSize("...") <= width and (table.concat(chars, "", 1, low) .. "...") or ""
    end
    if cacheCount > 2400 then textCache, cacheCount = {}, 0 end
    textCache[key], cacheCount = result, cacheCount + 1
    return result
end

function UI.Text(text, font, x, y, color, width, align)
    if width then text = UI.Fit(text, font, width) end
    draw.SimpleText(tostring(text or ""), font, x, y, color or C.text,
        align or TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

function UI.Box(x, y, w, h, color, border)
    if w <= 0 or h <= 0 then return end
    local radius = UI.Style.radius or 6
    draw.RoundedBox(S(radius), x, y, w, h, border or C.border)
    draw.RoundedBox(S(math.max(0, radius - 1)), x + 1, y + 1, math.max(0, w - 2), math.max(0, h - 2), color or C.panel)
end

-- Small native line icons: no Workshop materials or downloaded assets required.
function UI.Icon(kind, x, y, size, color)
    surface.SetDrawColor(color or C.muted)
    local function line(a, b, c, d)
        surface.DrawLine(x + size * a, y + size * b, x + size * c, y + size * d)
    end
    if kind == "close" then
        line(.25, .25, .75, .75); line(.75, .25, .25, .75)
    elseif kind == "search" then
        line(.2, .15, .6, .15); line(.6, .15, .75, .3); line(.75, .3, .75, .6)
        line(.75, .6, .6, .75); line(.6, .75, .2, .75); line(.2, .75, .05, .6)
        line(.05, .6, .05, .3); line(.05, .3, .2, .15); line(.7, .7, .95, .95)
    elseif kind == "players" then
        line(.35, .1, .65, .1); line(.65, .1, .65, .4)
        line(.65, .4, .35, .4); line(.35, .4, .35, .1)
        line(.1, .9, .1, .65); line(.1, .65, .35, .55)
        line(.35, .55, .65, .55); line(.65, .55, .9, .65)
        line(.9, .65, .9, .9); line(.9, .9, .1, .9)
    elseif kind == "ranks" then
        for _, offset in ipairs({0, .25, .5}) do
            line(.15, .35 + offset, .5, .1 + offset)
            line(.5, .1 + offset, .85, .35 + offset)
        end
    elseif kind == "logs" then
        for _, offset in ipairs({.2, .5, .8}) do
            line(.1, offset, .2, offset); line(.35, offset, .9, offset)
        end
    elseif kind == "theme" then
        -- Three swatches. Outlined rects rather than lines so it stays legible
        -- at the 16px the header button draws it at.
        surface.DrawOutlinedRect(x + size * .08, y + size * .22, size * .24, size * .56, 1)
        surface.DrawOutlinedRect(x + size * .38, y + size * .12, size * .24, size * .76, 1)
        surface.DrawOutlinedRect(x + size * .68, y + size * .22, size * .24, size * .56, 1)
    elseif kind == "refresh" then
        line(.85, .4, .75, .15); line(.75, .15, .3, .15)
        line(.3, .15, .1, .4); line(.1, .4, .1, .7)
        line(.1, .7, .35, .9); line(.35, .9, .8, .9)
        line(.8, .9, .9, .7); line(.85, .4, .85, .05); line(.85, .4, .5, .4)
    else
        line(.1, .1, .9, .1); line(.9, .1, .85, .6)
        line(.85, .6, .5, .95); line(.5, .95, .15, .6); line(.15, .6, .1, .1)
        if kind == "bans" then line(.3, .3, .7, .65)
        else line(.35, .38, .5, .55); line(.5, .55, .73, .27) end
    end
end

function UI.Panel(parent)
    local panel = vgui.Create("DPanel", parent)
    panel.Paint = function() end
    return panel
end

function UI.Button(parent, label, callback, tone, icon)
    local button = vgui.Create("DButton", parent)
    button:SetText("")
    button:SetTall(S(36))
    button:SetCursor("hand")
    button.AXELLabel = label
    button.Paint = function(self, w, h)
        local disabled = not self:IsEnabled()
        local hover = self:IsHovered() and not disabled
        local active = self.AXELActive and self.AXELActive()
        local bg = (tone == "primary" and not disabled) and (hover and C.accentHover or C.accent)
            or (active and C.accentSoft or (hover and C.hover or C.raised))
        local edge = active and C.accent or (tone == "danger" and C.accentSoft or C.border)
        UI.Box(0, 0, w, h, bg, edge)
        local col = disabled and C.faint or (tone == "danger" and C.danger or C.text)
        if icon then UI.Icon(icon, S(10), (h - S(16)) / 2, S(16), col) end
        local caption = isfunction(self.AXELLabel) and self.AXELLabel() or self.AXELLabel
        local left = icon and S(34) or S(8)
        UI.Text(caption, "AXEL.Button", left + (w - left - S(8)) / 2, h / 2,
            col, w - left - S(8), TEXT_ALIGN_CENTER)
    end
    button.DoClick = function(self)
        if self:IsEnabled() and callback then callback(self) end
    end
    return button
end

function UI.Scroll(parent)
    local scroll = vgui.Create("DScrollPanel", parent)
    local bar = scroll:GetVBar()
    bar:SetWide(S(6))
    bar:SetHideButtons(true)
    bar.Paint = function() end
    bar.btnUp.Paint, bar.btnDown.Paint = function() end, function() end
    bar.btnGrip.Paint = function(self, w, h)
        draw.RoundedBox(S(3), 0, 0, w, h, self:IsHovered() and C.accent or C.border)
    end
    scroll:GetCanvas():DockPadding(0, 0, S(8), 0)
    return scroll
end

function UI.Entry(parent, placeholder, initial, changed, search)
    local shell = UI.Panel(parent)
    shell:SetTall(S(40))
    shell:DockPadding(search and S(36) or S(12), S(5), S(10), S(5))
    local entry = vgui.Create("DTextEntry", shell)
    entry:Dock(FILL)
    entry:SetFont("AXEL.Body")
    entry:SetText(initial or "")
    entry:SetUpdateOnType(true)
    entry.Paint = function(self, w, h)
        if self:GetText() == "" and not self:HasFocus() then
            UI.Text(placeholder or "", "AXEL.Body", 0, h / 2, C.faint, w)
        end
        self:DrawTextEntryText(C.text, C.accentSoft, C.text)
    end
    shell.Paint = function(_, w, h)
        UI.Box(0, 0, w, h, C.background, entry:HasFocus() and C.accent or C.border)
        if search then UI.Icon("search", S(12), (h - S(15)) / 2, S(15), C.faint) end
    end
    if changed then entry.OnValueChange = function(self, value) changed(value, self) end end
    shell.Entry = entry
    return shell, entry
end

function UI.Label(parent, text, height, color, font)
    local panel = UI.Panel(parent)
    panel:Dock(TOP)
    panel:SetTall(S(height or 28))
    panel.Paint = function(_, w, h)
        UI.Text(isfunction(text) and text() or text, font or "AXEL.Small", 0, h / 2, color or C.muted, w)
    end
    return panel
end

function UI.Section(parent, title, detail)
    local panel = UI.Panel(parent)
    panel:Dock(TOP)
    panel:DockMargin(0, S(8), 0, S(10))
    panel:SetTall(S(detail and 48 or 30))
    panel.Paint = function(_, w, h)
        draw.RoundedBox(S(2), 0, S(7), S(3), h - S(14), C.accent)
        UI.Text(string.upper(title), "AXEL.Label", S(14), detail and S(15) or h / 2,
            C.accentHover, w - S(20))
        if detail then UI.Text(detail, "AXEL.Small", S(14), S(35), C.muted, w - S(20)) end
    end
    return panel
end

function UI.StatCard(parent, label, value, detail, icon)
    local panel = UI.Panel(parent)
    panel.Paint = function(self, w, h)
        UI.Box(0, 0, w, h, self:IsHovered() and C.hover or C.panel)
        draw.RoundedBox(S(2), 0, S(10), S(3), h - S(20), C.accent)
        if icon then UI.Icon(icon, w - S(38), S(14), S(22), C.faint) end
        UI.Text(string.upper(label), "AXEL.Label", S(16), S(20), C.muted, w - S(58))
        UI.Text(isfunction(value) and value() or value, "AXEL.Number", S(16), S(54), C.text, w - S(32))
        UI.Text(isfunction(detail) and detail() or detail, "AXEL.Small", S(16), h - S(17), C.faint, w - S(32))
    end
    return panel
end

function UI.Empty(parent, title, detail)
    local panel = UI.Panel(parent)
    panel:Dock(TOP)
    panel:SetTall(S(152))
    panel.Paint = function(_, w, h)
        UI.Box(0, 0, w, h, C.panel)
        UI.Icon("logs", w / 2 - S(12), S(25), S(24), C.faint)
        UI.Text(title, "AXEL.Heading", w / 2, S(79), C.text, w - S(28), TEXT_ALIGN_CENTER)
        UI.Text(detail, "AXEL.Small", w / 2, S(110), C.muted, w - S(28), TEXT_ALIGN_CENTER)
    end
    return panel
end

function UI.Window(title, subtitle, width, height)
    local window = vgui.Create("DFrame")
    window:SetSize(math.min(S(width), ScrW() - 24), math.min(S(height), ScrH() - 24))
    window:Center()
    window:SetTitle("")
    window:ShowCloseButton(false)
    window:SetSizable(false)
    window:SetScreenLock(true)
    window:SetDeleteOnClose(true)
    window:DockPadding(S(20), S(88), S(20), S(20))
    window.Paint = function(_, w, h)
        UI.Box(0, 0, w, h, C.background, C.border)
        surface.SetDrawColor(C.accent)
        surface.DrawRect(S(20), 0, S(72), S(3))
        UI.Text(title, "AXEL.Title", S(22), S(32), C.text, w - S(92))
        UI.Text(isfunction(subtitle) and subtitle() or subtitle, "AXEL.Small",
            S(22), S(60), C.muted, w - S(90))
        surface.SetDrawColor(C.border)
        surface.DrawLine(S(20), S(79), w - S(20), S(79))
    end
    local close = UI.Button(window, "", function() window:Close() end, "danger")
    close:SetTooltip("Close (Esc)")
    close.Paint = function(self, w, h)
        UI.Box(0, 0, w, h, self:IsHovered() and C.accentSoft or C.panel)
        UI.Icon("close", w / 2 - S(10), h / 2 - S(10), S(20), self:IsHovered() and C.text or C.muted)
    end
    local baseLayout = window.PerformLayout
    window.PerformLayout = function(self, w, h)
        if baseLayout then baseLayout(self, w, h) end
        close:SetSize(S(34), S(34))
        close:SetPos(w - S(54), S(19))
    end
    local baseThink = window.Think
    window.Think = function(self)
        if baseThink then baseThink(self) end
        local pressed = input.IsKeyDown(KEY_ESCAPE)
        if not pressed then UI.EscapeConsumed = false end
        if pressed and not UI.EscapeConsumed and (not IsValid(UI.Modal) or UI.Modal == self) then
            UI.EscapeConsumed = true
            self:Close()
            gui.HideGameUI()
        end
    end
    window:MakePopup()
    return window
end

function UI.CloseModal()
    if IsValid(UI.Modal) then UI.Modal:Remove() end
end

function UI.OpenModal(owner, title, subtitle, width, height)
    UI.CloseModal()
    local shade
    if IsValid(owner) then
        shade = UI.Panel(owner)
        shade:SetSize(owner:GetWide(), owner:GetTall())
        shade:SetZPos(1000)
        shade.Paint = function(_, w, h) draw.RoundedBox(S(6), 0, 0, w, h, C.shade) end
    end
    local dialog = UI.Window(title, subtitle, width, height)
    UI.Modal = dialog
    dialog.OnRemove = function(self)
        if IsValid(shade) then shade:Remove() end
        if UI.Modal == self then UI.Modal = nil end
        -- Removal can finish a frame later. Do not steal focus from a newer dialog.
        if not IsValid(UI.Modal) and IsValid(owner) and not owner.AXELClosing then owner:MakePopup() end
    end
    return dialog
end

function UI.Avatar(parent, entry, size)
    local holder = UI.Panel(parent)
    holder:SetSize(S(size), S(size))
    holder:SetMouseInputEnabled(false)
    holder.Paint = function(_, w, h)
        UI.Box(0, 0, w, h, C.raised)
        UI.Icon("players", w * .25, h * .25, w * .5, C.muted)
    end
    if IsValid(entry.entity) and entry.entity:IsPlayer() and not entry.entity:IsBot() then
        local avatar = vgui.Create("AvatarImage", holder)
        avatar:SetPos(S(3), S(3))
        avatar:SetSize(S(size) - S(6), S(size) - S(6))
        avatar:SetPlayer(entry.entity, 64)
        avatar:SetMouseInputEnabled(false)
    end
    return holder
end
