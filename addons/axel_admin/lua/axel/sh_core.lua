--[[
    Axel Admin Menu - shared core

    Rank inheritance and permission resolution. Shared so the menu can grey out
    buttons the server would refuse anyway; the server always re-checks.

    A rank:
        {
            name       = "moderator",
            inherit    = "user",        -- nil on the root rank only
            immunity   = 50,
            banLimit   = 604800,        -- seconds, 0 = permanent allowed
            permissions = {kick = true, ban = true}
        }

    Inheritance walks parent to parent. Two failure modes are guarded because
    both were live bugs in the mod this replaces:

      * a rank whose parent does not exist  -> chain ends, returns false
      * a rank with no parent at all (root) -> loop must stop, not index nil
      * a circular chain a -> b -> a        -> visited set breaks the loop

    Every walk in this file uses WalkChain so a fix lands in one place.
]]

AXEL = AXEL or {}
AXEL.Ranks = AXEL.Ranks or {}

AXEL.RootRank = "user"
AXEL.SuperRank = "superadmin"

-- Immunity ceiling. Anyone at or above this can target anyone.
AXEL.MaxImmunity = 100

AXEL.Colors = {
    accent = Color(218, 177, 83),
    success = Color(85, 184, 112),
    warning = Color(226, 169, 60),
    danger = Color(220, 48, 52),
    text = Color(210, 213, 218),
    dim = Color(132, 137, 144)
}

function AXEL.GetRank(name)
    if (not name) then return nil end
    return AXEL.Ranks[string.lower(string.Trim(tostring(name)))]
end

function AXEL.RankExists(name)
    return AXEL.GetRank(name) ~= nil
end

--[[
    Walks a rank's inheritance chain, calling fn(rank) for each link including
    the starting rank. Stops when fn returns a non-nil value and returns it.

    Returns nil if the chain ends without a result. Safe against a nil start,
    a missing parent, a root rank with no parent, and a circular chain.
]]
function AXEL.WalkChain(name, fn)
    local visited = {}
    local current = name and string.lower(string.Trim(tostring(name))) or nil

    -- "while current" and not "while true": a root rank sets current to nil,
    -- and visited[nil] = true would error.
    while current do
        if (visited[current]) then return nil end
        visited[current] = true

        local rank = AXEL.Ranks[current]
        if (not rank) then return nil end

        local result = fn(rank)
        if (result ~= nil) then return result end

        current = rank.inherit
    end

    return nil
end

--- True if `name` is, or inherits from, `target`.
function AXEL.InheritsFrom(name, target)
    if (not name or not target) then return false end

    name = string.lower(string.Trim(tostring(name)))
    target = string.lower(string.Trim(tostring(target)))

    if (name == target) then return true end

    return AXEL.WalkChain(name, function(rank)
        if (rank.name == target) then return true end
    end) == true
end

--[[
    Resolves a permission across the inheritance chain.

    A rank may explicitly deny a permission with `false`, which must beat an
    inherited `true` - that is the whole point of having a chain. So the walk
    stops at the first rank that mentions the permission at all, and only
    continues past ranks that say nothing about it.
]]
function AXEL.RankHasPermission(name, permission)
    if (not name or not permission) then return false end

    permission = string.lower(string.Trim(tostring(permission)))

    -- superadmin is unconditional; without this a fresh install with no
    -- permissions configured would lock everyone out of their own server.
    if (AXEL.InheritsFrom(name, AXEL.SuperRank)) then return true end

    local result = AXEL.WalkChain(name, function(rank)
        local value = rank.permissions and rank.permissions[permission]
        if (value ~= nil) then return {value} end
    end)

    return result ~= nil and result[1] == true
end

function AXEL.GetImmunity(name)
    local rank = AXEL.GetRank(name)
    return rank and (tonumber(rank.immunity) or 0) or 0
end

--[[
    Can `actor` act on `target`?

    Console (nil actor) can always act. Otherwise the actor must out-rank the
    target strictly - equal immunity cannot target equal immunity, which stops
    staff of the same tier from banning each other. Acting on yourself is always
    allowed so /kick me style commands work.
]]
function AXEL.CanTarget(actorRank, targetRank, sameAllowed)
    if (actorRank == nil) then return true end   -- console

    local actor = AXEL.GetImmunity(actorRank)
    local target = AXEL.GetImmunity(targetRank)

    if (actor >= AXEL.MaxImmunity) then return true end
    if (sameAllowed and actor == target) then return true end

    return actor > target
end

--[[ ------------------------------------------------------------------------
    Utility
--------------------------------------------------------------------------- ]]

function AXEL.IsSteamID(value)
    value = tostring(value or "")
    return string.match(value, "^STEAM_%d:%d:%d+$") ~= nil
end

function AXEL.IsSteamID64(value)
    value = tostring(value or "")
    return string.match(value, "^7656119%d+$") ~= nil and #value == 17
end

--- Seconds to "2d 4h 30m". 0 or nil means permanent.
function AXEL.FormatDuration(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    if (seconds <= 0) then return "permanent" end

    local units = {
        {"d", 86400}, {"h", 3600}, {"m", 60}, {"s", 1}
    }

    local parts = {}
    for _, unit in ipairs(units) do
        local value = math.floor(seconds / unit[2])
        if (value > 0) then
            parts[#parts + 1] = value .. unit[1]
            seconds = seconds - (value * unit[2])
        end
        if (#parts >= 2) then break end
    end

    return #parts > 0 and table.concat(parts, " ") or "0s"
end

--- Parses "30m", "2h", "7d", "perma"/"0" into seconds. Returns nil if invalid.
function AXEL.ParseDuration(input)
    input = string.lower(string.Trim(tostring(input or "")))

    if (input == "" or input == "0" or input == "perma" or input == "permanent") then
        return 0
    end

    local amount, unit = string.match(input, "^(%d+)%s*([smhdwy]?)$")
    amount = tonumber(amount)
    if (not amount) then return nil end

    local multipliers = {
        [""] = 60,      -- bare number means minutes, matching admin-mod convention
        s = 1, m = 60, h = 3600, d = 86400, w = 604800, y = 31536000
    }

    return amount * (multipliers[unit] or 60)
end

function AXEL.Now()
    return os.time()
end
