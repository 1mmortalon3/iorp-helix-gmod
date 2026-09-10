--[[
    Axel Admin Menu - appearance picker

    Resolution order, highest priority first:

        1. the server lock, if an admin has enabled it
        2. the player's own convar, if it names a theme that still exists
        3. the server default
        4. AXEL.DefaultTheme

    Step 2 checks that the theme still exists on purpose. A player who picked a
    palette that a later update removed should quietly fall back to the server
    default rather than sit on a menu painted from nil colours.
]]

if (SERVER) then return end

local UI = AXEL.UI
local C, S = UI.C, UI.S

local themeConVar = CreateClientConVar("axel_admin_theme", "server", true, false,
    "Axel admin menu theme. 'server' follows the server default.")

AXEL.ServerTheme = AXEL.ServerTheme or {default = AXEL.DefaultTheme, locked = false}
AXEL.ServerTheme.canManage = AXEL.ServerTheme.canManage or false

function UI.ResolveTheme()
    if (AXEL.ServerTheme.locked and AXEL.ThemeExists(AXEL.ServerTheme.default)) then
        return AXEL.ServerTheme.default
    end

    local choice = string.lower(string.Trim(themeConVar:GetString()))
    if (choice ~= "" and choice ~= "server" and AXEL.ThemeExists(choice)) then
        return choice
    end

    if (AXEL.ThemeExists(AXEL.ServerTheme.default)) then
        return AXEL.ServerTheme.default
    end

    return AXEL.DefaultTheme
end

--- Applies whatever the rules currently resolve to. Safe to call repeatedly.
function UI.RefreshTheme()
    local id = UI.ResolveTheme()
    if (UI.ActiveTheme == id) then return end

    UI.ApplyTheme(id)
end

--[[ ------------------------------------------------------------------------
    Networking
--------------------------------------------------------------------------- ]]

net.Receive("AXEL.ThemeConfig", function()
    local default = string.lower(string.Trim(net.ReadString()))

    if (AXEL.ThemeExists(default)) then AXEL.ServerTheme.default = default end
    AXEL.ServerTheme.locked = net.ReadBool()
    AXEL.ServerTheme.canManage = net.ReadBool()

    UI.RefreshTheme()

    -- The picker shows server state directly, so it has to hear about this.
    if (IsValid(UI.ThemeDialog) and UI.ThemeDialog.Rebuild) then
        UI.ThemeDialog.Rebuild()
    end
end)

local function requestConfig()
    net.Start("AXEL.ThemeRequest")
    net.SendToServer()
end

hook.Add("InitPostEntity", "AXEL.ThemeHandshake", function()
    timer.Simple(2, requestConfig)
end)

cvars.AddChangeCallback("axel_admin_theme", function()
    UI.RefreshTheme()
end, "AXEL.ThemeChoice")

--[[ ------------------------------------------------------------------------
    Picker
--------------------------------------------------------------------------- ]]

--- The five slots that actually tell two palettes apart at a glance.
local SWATCHES = {"background", "panel", "accent", "accentHover", "text"}

local function swatches(theme, x, y, size, gap)
    for index, key in ipairs(SWATCHES) do
        local color = theme.colors[key]
        draw.RoundedBox(S(3), x + (index - 1) * (size + gap), y, size, size, color)
        surface.SetDrawColor(0, 0, 0, 60)
        surface.DrawOutlinedRect(x + (index - 1) * (size + gap), y, size, size, 1)
    end
end

local function swatchWidth(size, gap)
    return #SWATCHES * (size + gap) - gap
end

--[[
    One row. `theme` is a real palette or a synthetic one standing in for
    "follow the server", which is why the caption is passed separately.
]]
local function themeRow(parent, theme, caption, detail, isSelected, onClick, enabled)
    local row = UI.Button(parent, caption, onClick)
    row:Dock(TOP)
    row:SetTall(S(64))
    row:DockMargin(0, 0, 0, S(8))
    row:SetEnabled(enabled ~= false)
    row:SetTooltip(detail)

    row.Paint = function(self, w, h)
        local selected = isSelected()
        local usable = self:IsEnabled()
        local hover = self:IsHovered() and usable

        UI.Box(0, 0, w, h,
            selected and C.accentSoft or (hover and C.hover or C.raised),
            selected and C.accent or C.border)

        if (selected) then
            draw.RoundedBox(S(1), S(7), S(12), S(3), h - S(24), C.accent)
        end

        local size, gap = S(20), S(6)
        local block = swatchWidth(size, gap)
        local textWidth = math.max(S(40), w - block - S(52))

        UI.Text(caption, "AXEL.Button", S(20), h / 2 - S(10),
            usable and C.text or C.faint, textWidth)
        UI.Text(detail, "AXEL.Small", S(20), h / 2 + S(11), C.muted, textWidth)

        swatches(theme, w - block - S(16), (h - size) / 2, size, gap)
    end

    return row
end

function UI.OpenThemePicker(owner)
    requestConfig()

    local dialog = UI.OpenModal(owner, "Appearance",
        "Your choice is stored on this computer and applies to every server.", 620, 660)
    UI.ThemeDialog = dialog

    local previousRemove = dialog.OnRemove
    dialog.OnRemove = function(self)
        if (previousRemove) then previousRemove(self) end
        if (UI.ThemeDialog == self) then UI.ThemeDialog = nil end
    end

    local footer = UI.Panel(dialog)
    footer:Dock(BOTTOM)
    footer:SetTall(S(40))

    local close = UI.Button(footer, "Close", function() dialog:Close() end)
    close:Dock(LEFT)
    close:SetWide(S(106))

    if (AXEL.ServerTheme.canManage) then
        local lock = UI.Button(footer, function()
            return AXEL.ServerTheme.locked and "Locked for all" or "Free choice"
        end, function()
            -- Send the existing default so toggling the lock cannot also move
            -- the whole server onto whatever this admin happens to be previewing.
            net.Start("AXEL.ThemeSet")
                net.WriteString(AXEL.ServerTheme.default)
                net.WriteBool(not AXEL.ServerTheme.locked)
            net.SendToServer()
        end)
        lock:Dock(RIGHT)
        lock:SetWide(S(140))
        lock:DockMargin(S(8), 0, 0, 0)
        lock:SetTooltip("When locked, every player sees the server default and cannot change it.")

        local promote = UI.Button(footer, "Set as server default", function()
            net.Start("AXEL.ThemeSet")
                net.WriteString(UI.ResolveTheme())
                net.WriteBool(AXEL.ServerTheme.locked)
            net.SendToServer()
        end, "primary")
        promote:Dock(RIGHT)
        promote:SetWide(S(180))
        promote:SetTooltip("Applies the theme you are previewing to everyone who has not chosen their own.")
    end

    local status = UI.Label(dialog, function()
        local server = AXEL.GetTheme(AXEL.ServerTheme.default)
        local text = "Server default: " .. (server and server.name or AXEL.ServerTheme.default)

        if (AXEL.ServerTheme.locked) then
            text = text .. "   ·   locked, personal choices are ignored"
        end

        return text
    end, 30, C.faint, "AXEL.Small")
    status:Dock(BOTTOM)

    local scroll = UI.Scroll(dialog)
    scroll:Dock(FILL)

    dialog.Rebuild = function()
        if (not IsValid(scroll)) then return end

        local position = scroll:GetVBar():GetScroll()
        scroll:Clear()

        local locked = AXEL.ServerTheme.locked and not AXEL.ServerTheme.canManage
        local choice = string.lower(string.Trim(themeConVar:GetString()))
        local serverTheme = AXEL.GetTheme(AXEL.ServerTheme.default) or AXEL.GetTheme(AXEL.DefaultTheme)

        if (locked) then
            local notice = UI.Panel(scroll)
            notice:Dock(TOP)
            notice:SetTall(S(52))
            notice:DockMargin(0, 0, 0, S(10))
            notice.Paint = function(_, w, h)
                UI.Box(0, 0, w, h, C.accentSoft, C.accent)
                UI.Text("This server has locked the menu theme.", "AXEL.Body",
                    S(16), h / 2, C.text, w - S(32))
            end
        end

        themeRow(scroll, serverTheme, "Follow the server",
            "Currently " .. serverTheme.name .. ". Changes when staff change it.",
            function()
                return choice == "" or choice == "server" or not AXEL.ThemeExists(choice)
            end,
            function()
                RunConsoleCommand("axel_admin_theme", "server")
                timer.Simple(0, dialog.Rebuild)
            end, not locked)

        UI.Label(scroll, "THEMES", 32, C.accentHover, "AXEL.Label")

        for _, theme in ipairs(AXEL.GetThemeList()) do
            themeRow(scroll, theme, theme.name,
                theme.description ~= "" and theme.description or "Custom palette.",
                function() return choice == theme.id end,
                function()
                    RunConsoleCommand("axel_admin_theme", theme.id)
                    timer.Simple(0, dialog.Rebuild)
                end, not locked)
        end

        scroll:InvalidateLayout(true)
        scroll:GetVBar():SetScroll(position)
    end

    dialog.Rebuild()
    return dialog
end

-- Cosmetic and client-side, so this is deliberately open to every player rather
-- than gated behind the menu permission.
concommand.Add("axel_theme", function(_, _, args)
    local id = string.lower(string.Trim(args[1] or ""))

    if (id ~= "") then
        if (id ~= "server" and not AXEL.ThemeExists(id)) then
            local names = {}
            for _, theme in ipairs(AXEL.GetThemeList()) do names[#names + 1] = theme.id end
            MsgC(Color(218, 177, 83), "[Axel] ", Color(210, 213, 218),
                "Unknown theme. Available: server, " .. table.concat(names, ", ") .. "\n")
            return
        end

        RunConsoleCommand("axel_admin_theme", id)
        return
    end

    UI.OpenThemePicker(IsValid(UI.Frame) and UI.Frame or nil)
end, nil, "Open the Axel appearance picker, or pass a theme id to switch directly.")

UI.RefreshTheme()
