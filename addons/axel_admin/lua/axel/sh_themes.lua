--[[
    Axel Admin Menu - theme registry (shared)

    Palettes live here rather than in cl_theme.lua so the server can validate a
    theme id without owning any drawing code, and so third-party addons can add
    their own palette with AXEL.RegisterTheme before the menu is ever opened.

    A theme is a flat table of colours keyed exactly like AXEL.UI.C. Any key a
    theme leaves out is inherited from the base palette, so a theme that only
    wants to move the accent can list three colours and nothing else.

    Colours are written as {r, g, b} or {r, g, b, a} to keep the definitions
    readable; they are converted to Color objects once, at registration.
]]

AXEL = AXEL or {}
AXEL.Themes = AXEL.Themes or {}
AXEL.ThemeOrder = AXEL.ThemeOrder or {}
AXEL.DefaultTheme = "obsidian"

--- Every colour slot the interface paints with. Order is display order.
AXEL.ThemeKeys = {
    "background", "sidebar", "panel", "raised", "hover", "border",
    "text", "muted", "faint",
    "accent", "accentHover", "accentSoft",
    "danger", "green", "amber",
    "shade", "white"
}

local KEYSET = {}
for _, key in ipairs(AXEL.ThemeKeys) do KEYSET[key] = true end

--[[
    The base palette. Every other theme is diffed against this one, so a missing
    key can never produce a nil colour and crash a Paint function mid-frame.
]]
local BASE = {
    background = {18, 18, 17}, sidebar = {23, 23, 21}, panel = {29, 29, 26},
    raised = {37, 37, 32}, hover = {49, 47, 39}, border = {70, 65, 50},
    text = {245, 240, 225}, muted = {187, 181, 164}, faint = {144, 137, 119},
    accent = {119, 87, 28}, accentHover = {170, 127, 43}, accentSoft = {62, 51, 29},
    danger = {236, 116, 106}, green = {111, 207, 157}, amber = {230, 187, 109},
    shade = {0, 0, 0, 170}, white = {255, 255, 255}
}

local function toColor(value)
    if (IsColor and IsColor(value)) then
        return Color(value.r, value.g, value.b, value.a or 255)
    end

    if (istable(value)) then
        return Color(
            math.Clamp(tonumber(value[1] or value.r) or 0, 0, 255),
            math.Clamp(tonumber(value[2] or value.g) or 0, 0, 255),
            math.Clamp(tonumber(value[3] or value.b) or 0, 0, 255),
            math.Clamp(tonumber(value[4] or value.a) or 255, 0, 255))
    end

    return nil
end

--[[
    Registers a palette.

        id          lowercase word, used in the convar and over the network
        data.name   shown in the picker
        data.radius corner rounding in unscaled pixels (default 6)
        data.light  true if the palette is light-on-dark, for contrast choices
        data.colors partial or complete map of AXEL.ThemeKeys to colours

    Re-registering an existing id replaces it in place and keeps its position in
    the list, so a server can override a built-in palette without it jumping to
    the bottom of the picker.
]]
function AXEL.RegisterTheme(id, data)
    id = string.lower(string.Trim(tostring(id or "")))

    if (id == "" or #id > 32 or not string.match(id, "^[%w_]+$")) then return end
    if (id == "server") then return end -- reserved: means "follow the server"
    if (not istable(data)) then return end

    local colors = {}
    local supplied = istable(data.colors) and data.colors or {}

    for _, key in ipairs(AXEL.ThemeKeys) do
        colors[key] = toColor(supplied[key]) or toColor(BASE[key])
    end

    -- A theme that misspells a key would otherwise fail silently.
    for key in next, supplied do
        if (not KEYSET[key]) then
            ErrorNoHalt("[Axel] Theme '" .. id .. "' has unknown colour '" .. tostring(key) .. "'.\n")
        end
    end

    local existing = AXEL.Themes[id]

    AXEL.Themes[id] = {
        id = id,
        name = string.sub(tostring(data.name or id), 1, 48),
        description = string.sub(tostring(data.description or ""), 1, 120),
        radius = math.Clamp(tonumber(data.radius) or 6, 0, 12),
        light = data.light == true,
        colors = colors
    }

    if (not existing) then
        AXEL.ThemeOrder[#AXEL.ThemeOrder + 1] = id
    end

    return AXEL.Themes[id]
end

function AXEL.GetTheme(id)
    if (not id) then return nil end
    return AXEL.Themes[string.lower(string.Trim(tostring(id)))]
end

function AXEL.ThemeExists(id)
    return AXEL.GetTheme(id) ~= nil
end

--- Registration order, which is deliberately hand-curated rather than alphabetical.
function AXEL.GetThemeList()
    local out = {}
    for _, id in ipairs(AXEL.ThemeOrder) do
        if (AXEL.Themes[id]) then out[#out + 1] = AXEL.Themes[id] end
    end
    return out
end

--[[ ------------------------------------------------------------------------
    Built-in palettes
--------------------------------------------------------------------------- ]]

AXEL.RegisterTheme("midnight", {
    name = "Axel Midnight",
    description = "The original warm charcoal and brass.",
    colors = BASE
})

AXEL.RegisterTheme("obsidian", {
    name = "Obsidian",
    description = "Neutral near-black with a cold blue accent.",
    colors = {
        background = {14, 15, 17}, sidebar = {19, 20, 23}, panel = {24, 26, 30},
        raised = {32, 35, 40}, hover = {42, 46, 53}, border = {55, 60, 70},
        text = {236, 240, 246}, muted = {168, 176, 188}, faint = {122, 131, 145},
        accent = {42, 98, 182}, accentHover = {62, 132, 232}, accentSoft = {24, 45, 78},
        danger = {235, 110, 110}, green = {106, 204, 150}, amber = {226, 182, 104}
    }
})

AXEL.RegisterTheme("nord", {
    name = "Nord",
    description = "Muted arctic blues, easy on long sessions.",
    colors = {
        background = {36, 41, 51}, sidebar = {46, 52, 64}, panel = {52, 59, 72},
        raised = {59, 66, 82}, hover = {67, 76, 94}, border = {76, 86, 106},
        text = {236, 239, 244}, muted = {190, 199, 213}, faint = {143, 156, 175},
        accent = {94, 129, 172}, accentHover = {129, 161, 193}, accentSoft = {55, 71, 94},
        danger = {191, 97, 106}, green = {163, 190, 140}, amber = {235, 203, 139}
    }
})

AXEL.RegisterTheme("crimson", {
    name = "Crimson",
    description = "Dark room, red command accent.",
    colors = {
        background = {17, 13, 14}, sidebar = {23, 17, 18}, panel = {30, 22, 24},
        raised = {40, 29, 31}, hover = {53, 37, 40}, border = {74, 50, 54},
        text = {245, 235, 236}, muted = {190, 172, 175}, faint = {145, 126, 130},
        accent = {150, 38, 48}, accentHover = {196, 58, 70}, accentSoft = {66, 26, 31},
        danger = {240, 130, 128}, green = {118, 198, 150}, amber = {226, 180, 104}
    }
})

AXEL.RegisterTheme("emerald", {
    name = "Emerald",
    description = "Deep green, high contrast on dark maps.",
    colors = {
        background = {13, 18, 16}, sidebar = {17, 24, 21}, panel = {22, 31, 27},
        raised = {29, 41, 36}, hover = {38, 54, 47}, border = {51, 74, 64},
        text = {233, 244, 238}, muted = {170, 190, 180}, faint = {126, 146, 137},
        accent = {26, 124, 88}, accentHover = {42, 168, 118}, accentSoft = {20, 58, 45},
        danger = {232, 112, 104}, green = {111, 207, 157}, amber = {226, 182, 104}
    }
})

AXEL.RegisterTheme("amethyst", {
    name = "Amethyst",
    description = "Violet accent over a cool graphite base.",
    colors = {
        background = {17, 14, 22}, sidebar = {22, 18, 29}, panel = {29, 24, 38},
        raised = {39, 32, 50}, hover = {51, 42, 66}, border = {70, 58, 92},
        text = {240, 235, 248}, muted = {184, 174, 200}, faint = {140, 131, 158},
        accent = {108, 63, 178}, accentHover = {146, 96, 222}, accentSoft = {50, 32, 80},
        danger = {236, 112, 120}, green = {116, 205, 158}, amber = {228, 184, 110}
    }
})

AXEL.RegisterTheme("oceanic", {
    name = "Oceanic",
    description = "Teal on slate, low glare.",
    colors = {
        background = {12, 20, 23}, sidebar = {16, 26, 30}, panel = {21, 34, 39},
        raised = {28, 45, 51}, hover = {37, 59, 67}, border = {48, 80, 90},
        text = {231, 244, 246}, muted = {165, 190, 196}, faint = {121, 146, 153},
        accent = {20, 120, 130}, accentHover = {36, 166, 178}, accentSoft = {16, 56, 62},
        danger = {234, 116, 108}, green = {108, 205, 160}, amber = {228, 184, 108}
    }
})

AXEL.RegisterTheme("sunset", {
    name = "Sunset",
    description = "Warm amber and burnt orange.",
    colors = {
        background = {23, 16, 16}, sidebar = {30, 21, 20}, panel = {38, 27, 25},
        raised = {50, 36, 33}, hover = {64, 46, 42}, border = {88, 62, 55},
        text = {250, 238, 231}, muted = {198, 177, 167}, faint = {152, 133, 124},
        accent = {182, 74, 38}, accentHover = {232, 112, 62}, accentSoft = {78, 38, 22},
        danger = {238, 118, 108}, green = {118, 202, 152}, amber = {236, 178, 96}
    }
})

AXEL.RegisterTheme("terminal", {
    name = "Terminal",
    description = "Square corners, phosphor green, minimal chrome.",
    radius = 2,
    colors = {
        background = {8, 10, 9}, sidebar = {11, 14, 12}, panel = {14, 18, 15},
        raised = {20, 26, 21}, hover = {28, 38, 29}, border = {40, 66, 44},
        text = {208, 246, 212}, muted = {138, 190, 146}, faint = {96, 140, 104},
        accent = {30, 120, 52}, accentHover = {56, 190, 88}, accentSoft = {18, 52, 26},
        danger = {236, 110, 96}, green = {90, 220, 120}, amber = {224, 196, 96},
        shade = {0, 0, 0, 200}
    }
})

AXEL.RegisterTheme("paper", {
    name = "Paper",
    description = "Light palette for bright rooms and streaming.",
    light = true,
    colors = {
        background = {240, 239, 235}, sidebar = {231, 229, 223}, panel = {250, 249, 246},
        raised = {238, 236, 230}, hover = {226, 223, 214}, border = {205, 200, 188},
        text = {34, 33, 30}, muted = {92, 89, 82}, faint = {134, 130, 121},
        accent = {150, 110, 30}, accentHover = {182, 138, 48}, accentSoft = {236, 224, 196},
        danger = {186, 52, 48}, green = {42, 138, 88}, amber = {168, 124, 26},
        shade = {0, 0, 0, 110}
    }
})

--[[ ------------------------------------------------------------------------
    Server default, exposed as an ordinary command so it works from chat,
    console and the menu with the same permission check as everything else.
--------------------------------------------------------------------------- ]]

AXEL.ServerTheme = AXEL.ServerTheme or {
    default = AXEL.DefaultTheme,
    locked = false
}

AXEL.RegisterCommand("settheme", {
    description = "Set the default menu theme for this server.",
    category = "General",
    permission = "managetheme",
    arguments = {"string", "string"},
    OnRun = function(actor, id, lock)
        if (not AXEL.SetServerTheme) then return false, "Theme storage is not loaded." end

        id = string.lower(string.Trim(id or ""))
        if (id == "") then
            local names = {}
            for _, theme in ipairs(AXEL.GetThemeList()) do names[#names + 1] = theme.id end
            return false, "Available themes: " .. table.concat(names, ", ")
        end

        local locked = AXEL.ServerTheme.locked
        lock = string.lower(string.Trim(lock or ""))
        if (lock == "lock" or lock == "1" or lock == "true" or lock == "force") then locked = true
        elseif (lock == "unlock" or lock == "0" or lock == "false" or lock == "free") then locked = false end

        return AXEL.SetServerTheme(id, locked, actor)
    end
})
