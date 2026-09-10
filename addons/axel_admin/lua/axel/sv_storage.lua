--[[
    Axel Admin Menu - storage

    Owns the axel_* tables and the one-time import from SAM.

    The import is additive and idempotent: it reads sam_* if those tables still
    exist and writes anything not already present. SAM's tables are never
    modified or dropped, so the old mod can be put back by re-enabling it.
]]

local DEFAULT_RANKS = {
    {name = "user", inherit = nil, immunity = 0, permissions = {}},
    {name = "moderator", inherit = "user", immunity = 40, permissions = {
        menu = true, kick = true, ban = true, freeze = true, bring = true,
        goto_player = true, teleport = true, mute = true, gag = true,
        slay = true, spectate = true, viewlogs = true
    }},
    {name = "admin", inherit = "moderator", immunity = 60, permissions = {
        setrank = true, unban = true, noclip = true, god = true,
        hp = true, armor = true, setmodel = true, cleanup = true
    }},
    {name = "superadmin", inherit = "admin", immunity = 100, permissions = {}}
}

function AXEL.InitStorage()
    -- Preserve existing installations before creating the renamed tables.
    local migrated = false
    for _, suffix in ipairs({"ranks", "players", "bans", "logs"}) do
        local previous = "ax31_" .. suffix
        if not sql.TableExists(previous) then previous = "ioa_" .. suffix end
        local current = "axel_" .. suffix
        if sql.TableExists(previous) and not sql.TableExists(current) then
            if not migrated then sql.Begin(); migrated = true end
            if sql.Query("ALTER TABLE " .. previous .. " RENAME TO " .. current) == false then
                sql.Query("ROLLBACK")
                error("[Axel] Database migration failed: " .. tostring(sql.LastError()))
            end
        end
    end
    if migrated then sql.Commit() end

    sql.Query([[
        CREATE TABLE IF NOT EXISTS axel_ranks (
            name       TEXT PRIMARY KEY,
            inherit    TEXT,
            immunity   INTEGER DEFAULT 0,
            ban_limit  INTEGER DEFAULT 0,
            permissions TEXT DEFAULT '{}'
        )
    ]])

    sql.Query([[
        CREATE TABLE IF NOT EXISTS axel_players (
            steamid    TEXT PRIMARY KEY,
            name       TEXT,
            rank       TEXT DEFAULT 'user',
            rank_expiry INTEGER DEFAULT 0,
            first_join INTEGER DEFAULT 0,
            last_join  INTEGER DEFAULT 0,
            play_time  INTEGER DEFAULT 0
        )
    ]])

    sql.Query([[
        CREATE TABLE IF NOT EXISTS axel_bans (
            steamid    TEXT PRIMARY KEY,
            name       TEXT,
            reason     TEXT,
            admin      TEXT,
            admin_name TEXT,
            created    INTEGER DEFAULT 0,
            expires    INTEGER DEFAULT 0
        )
    ]])

    sql.Query([[
        CREATE TABLE IF NOT EXISTS axel_logs (
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            time      INTEGER,
            admin     TEXT,
            admin_name TEXT,
            action    TEXT,
            target    TEXT,
            detail    TEXT
        )
    ]])

    -- Trimmed on boot rather than on every write.
    sql.Query("DELETE FROM axel_logs WHERE id NOT IN " ..
        "(SELECT id FROM axel_logs ORDER BY id DESC LIMIT 5000)")
end

local function esc(value)
    return sql.SQLStr(tostring(value or ""))
end

-- Keep a second, small rank store in data/axel. SQLite remains the primary
-- database for full player records, but this backup survives a damaged/reset
-- sv.db and gives us a verifiable write instead of silently claiming success.
local RANK_BACKUP_PATH = "axel/player_ranks.json"
AXEL.PlayerRankBackup = AXEL.PlayerRankBackup or {}

function AXEL.LoadPlayerRankBackup()
    file.CreateDir("axel")

    local raw = file.Read(RANK_BACKUP_PATH, "DATA")
    local decoded = raw and util.JSONToTable(raw) or nil
    AXEL.PlayerRankBackup = istable(decoded) and decoded or {}
end

local function savePlayerRankBackup()
    file.CreateDir("axel")

    local encoded = util.TableToJSON(AXEL.PlayerRankBackup or {}, true)
    if (not isstring(encoded)) then return false, "could not encode rank backup" end

    file.Write(RANK_BACKUP_PATH, encoded)

    -- file.Write has no useful return value, so read it back and validate it.
    local check = file.Read(RANK_BACKUP_PATH, "DATA")
    if (not isstring(check) or not istable(util.JSONToTable(check))) then
        return false, "could not verify data/" .. RANK_BACKUP_PATH
    end

    return true
end

--[[ ------------------------------------------------------------------------
    Ranks
--------------------------------------------------------------------------- ]]

function AXEL.LoadRanks()
    AXEL.Ranks = {}

    local rows = sql.Query("SELECT * FROM axel_ranks")
    if (istable(rows)) then
        for _, row in ipairs(rows) do
            local permissions = util.JSONToTable(row.permissions or "{}") or {}
            local inherit = row.inherit

            -- Empty string and the literal "NULL" both mean "no parent".
            -- Storing them as a string is what made the previous mod walk into
            -- a rank that does not exist.
            if (inherit == "" or inherit == "NULL") then inherit = nil end

            AXEL.Ranks[row.name] = {
                name = row.name,
                inherit = inherit,
                immunity = tonumber(row.immunity) or 0,
                banLimit = tonumber(row.ban_limit) or 0,
                permissions = permissions
            }
        end
    end

    AXEL.ValidateRanks()
end

--[[
    Repairs structurally broken rank data at load, loudly.

    A rank pointing at a parent that does not exist silently truncates the
    permission chain, which is invisible until someone loses a power they
    should have. Reparenting to the root is a safe default and the warning
    tells the owner to fix it properly.
]]
function AXEL.ValidateRanks()
    if (not AXEL.Ranks[AXEL.RootRank]) then
        AXEL.Ranks[AXEL.RootRank] = {
            name = AXEL.RootRank, inherit = nil, immunity = 0,
            banLimit = 0, permissions = {}
        }
    end

    for name, rank in next, AXEL.Ranks do
        if (rank.inherit and not AXEL.Ranks[rank.inherit]) then
            MsgC(Color(226, 169, 60), "[Axel] ",
                Color(210, 213, 218),
                string.format("Rank '%s' inherits '%s', which does not exist. " ..
                    "Reparented to '%s'.\n", name, rank.inherit, AXEL.RootRank))

            rank.inherit = AXEL.RootRank
            AXEL.SaveRank(rank)
        end

        if (name == AXEL.RootRank and rank.inherit) then
            rank.inherit = nil
            AXEL.SaveRank(rank)
        end
    end

    -- Break any cycle by reparenting the rank that closes it.
    for name, rank in next, AXEL.Ranks do
        local seen, current = {}, name

        while current do
            if (seen[current]) then
                MsgC(Color(226, 169, 60), "[Axel] ",
                    Color(210, 213, 218),
                    string.format("Circular inheritance at '%s'. Reparented to '%s'.\n",
                        current, AXEL.RootRank))

                AXEL.Ranks[current].inherit = nil
                AXEL.SaveRank(AXEL.Ranks[current])
                break
            end

            seen[current] = true
            local link = AXEL.Ranks[current]
            current = link and link.inherit or nil
        end
    end
end

function AXEL.SaveRank(rank)
    sql.Query(string.format(
        "REPLACE INTO axel_ranks (name, inherit, immunity, ban_limit, permissions) " ..
        "VALUES (%s, %s, %d, %d, %s)",
        esc(rank.name),
        rank.inherit and esc(rank.inherit) or "NULL",
        math.floor(tonumber(rank.immunity) or 0),
        math.floor(tonumber(rank.banLimit) or 0),
        esc(util.TableToJSON(rank.permissions or {}))))
end

function AXEL.DeleteRank(name)
    name = string.lower(tostring(name))
    if (name == AXEL.RootRank or name == AXEL.SuperRank) then return false end
    if (not AXEL.Ranks[name]) then return false end

    -- Reparent children before removing, or they become orphans.
    for _, rank in next, AXEL.Ranks do
        if (rank.inherit == name) then
            rank.inherit = AXEL.Ranks[name].inherit or AXEL.RootRank
            AXEL.SaveRank(rank)
        end
    end

    sql.Query("DELETE FROM axel_ranks WHERE name = " .. esc(name))
    sql.Query(string.format("UPDATE axel_players SET rank = %s WHERE rank = %s",
        esc(AXEL.RootRank), esc(name)))

    AXEL.Ranks[name] = nil
    return true
end

--[[ ------------------------------------------------------------------------
    Players
--------------------------------------------------------------------------- ]]

function AXEL.GetStoredPlayer(steamid)
    local rows = sql.Query("SELECT * FROM axel_players WHERE steamid = " .. esc(steamid))
    local stored = istable(rows) and rows[1] or nil
    local backup = AXEL.PlayerRankBackup[tostring(steamid)]

    if (istable(backup)) then
        stored = stored or {steamid = tostring(steamid)}
        stored.name = backup.name or stored.name
        stored.rank = backup.rank or stored.rank
        stored.rank_expiry = tonumber(backup.rank_expiry) or 0
        stored.updated = tonumber(backup.updated) or 0
    end

    return stored
end

function AXEL.SavePlayer(steamid, name, rank, expiry)
    local existing = AXEL.GetStoredPlayer(steamid)
    local now = AXEL.Now()
    local query

    if (existing) then
        query = string.format(
            "UPDATE axel_players SET name = %s, rank = %s, rank_expiry = %d, last_join = %d " ..
            "WHERE steamid = %s",
            esc(name or existing.name), esc(rank or existing.rank),
            math.floor(tonumber(expiry) or tonumber(existing.rank_expiry) or 0),
            now, esc(steamid))
    else
        query = string.format(
            "INSERT INTO axel_players (steamid, name, rank, rank_expiry, first_join, last_join, play_time) " ..
            "VALUES (%s, %s, %s, %d, %d, %d, 0)",
            esc(steamid), esc(name or "Unknown"), esc(rank or AXEL.RootRank),
            math.floor(tonumber(expiry) or 0), now, now)
    end

    local sqlOK = sql.Query(query) ~= false
    local sqlError = sqlOK and nil or tostring(sql.LastError())

    local key = tostring(steamid)
    AXEL.PlayerRankBackup[key] = {
        name = name or (existing and existing.name) or "Unknown",
        rank = rank or (existing and existing.rank) or AXEL.RootRank,
        rank_expiry = math.floor(tonumber(expiry) or (existing and tonumber(existing.rank_expiry)) or 0),
        updated = now
    }

    local backupOK, backupError = savePlayerRankBackup()
    if (AXEL.MySQL and AXEL.MySQL.Ready) then
        AXEL.MySQL:SavePlayer(key, AXEL.PlayerRankBackup[key].name,
            AXEL.PlayerRankBackup[key].rank, AXEL.PlayerRankBackup[key].rank_expiry, now)
    end
    if (not sqlOK) then
        ErrorNoHalt("[Axel] SQLite player-rank save failed: " .. sqlError .. "\n")
    end
    if (not backupOK) then
        ErrorNoHalt("[Axel] Rank backup save failed: " .. tostring(backupError) .. "\n")
    end

    if (not sqlOK and not backupOK) then
        return false, "SQLite and rank-backup writes both failed"
    end

    return true, sqlOK and nil or "saved to backup; SQLite failed: " .. sqlError
end

function AXEL.AddPlayTime(steamid, seconds)
    sql.Query(string.format(
        "UPDATE axel_players SET play_time = play_time + %d WHERE steamid = %s",
        math.max(0, math.floor(seconds or 0)), esc(steamid)))
end

--[[ ------------------------------------------------------------------------
    Logging
--------------------------------------------------------------------------- ]]

function AXEL.Log(admin, adminName, action, target, detail)
    sql.Query(string.format(
        "INSERT INTO axel_logs (time, admin, admin_name, action, target, detail) " ..
        "VALUES (%d, %s, %s, %s, %s, %s)",
        AXEL.Now(), esc(admin or "CONSOLE"), esc(adminName or "Console"),
        esc(action), esc(target or ""), esc(detail or "")))
end

function AXEL.GetLogs(limit)
    limit = math.Clamp(math.floor(tonumber(limit) or 100), 1, 500)
    local rows = sql.Query("SELECT * FROM axel_logs ORDER BY id DESC LIMIT " .. limit)
    return istable(rows) and rows or {}
end

--[[ ------------------------------------------------------------------------
    SAM import

    Runs once. Reads sam_* if present and copies anything missing. SAM's tables
    are left untouched so the old mod remains a working fallback.
--------------------------------------------------------------------------- ]]

local function tableExists(name)
    local result = sql.Query(
        "SELECT name FROM sqlite_master WHERE type='table' AND name = " .. esc(name))
    return istable(result) and #result > 0
end

function AXEL.MigrateFromSAM(force)
    local marker = sql.Query("SELECT * FROM axel_ranks WHERE name = '__migrated__'")

    if (not force and istable(marker)) then
        return false, "Already migrated. Pass true to force."
    end

    if (not tableExists("sam_ranks")) then
        return false, "No SAM tables found in this database."
    end

    local imported = {ranks = 0, players = 0, bans = 0, skipped = 0}

    -- Ranks. SAM stores permissions in a JSON `data` column and writes the
    -- string "NULL" for the root rank's parent.
    local ranks = sql.Query("SELECT * FROM sam_ranks")
    if (istable(ranks)) then
        for _, row in ipairs(ranks) do
            local name = string.lower(row.name or "")

            if (name ~= "" and not AXEL.Ranks[name]) then
                local inherit = row.inherit
                if (inherit == "" or inherit == "NULL" or inherit == nil) then
                    inherit = nil
                end

                local permissions = {}
                local data = util.JSONToTable(row.data or "{}")
                if (istable(data) and istable(data.permissions)) then
                    for permission, value in next, data.permissions do
                        permissions[string.lower(tostring(permission))] = value and true or false
                    end
                end

                AXEL.Ranks[name] = {
                    name = name,
                    inherit = inherit and string.lower(inherit) or nil,
                    immunity = tonumber(row.immunity) or 0,
                    banLimit = tonumber(row.ban_limit) or 0,
                    permissions = permissions
                }

                AXEL.SaveRank(AXEL.Ranks[name])
                imported.ranks = imported.ranks + 1
            end
        end
    end

    -- ValidateRanks repairs SAM's broken parents rather than importing them
    -- verbatim, which is the point of migrating.
    AXEL.ValidateRanks()

    if (tableExists("sam_players")) then
        local players = sql.Query("SELECT * FROM sam_players")
        if (istable(players)) then
            for _, row in ipairs(players) do
                if (row.steamid and row.steamid ~= "" and not AXEL.GetStoredPlayer(row.steamid)) then
                    local rank = string.lower(row.rank or AXEL.RootRank)
                    if (not AXEL.Ranks[rank]) then rank = AXEL.RootRank end

                    sql.Query(string.format(
                        "INSERT INTO axel_players (steamid, name, rank, rank_expiry, first_join, last_join, play_time) " ..
                        "VALUES (%s, %s, %s, %d, %d, %d, %d)",
                        esc(row.steamid), esc(row.name or "Unknown"), esc(rank),
                        math.floor(tonumber(row.expiry_date) or 0),
                        math.floor(tonumber(row.first_join) or 0),
                        math.floor(tonumber(row.last_join) or 0),
                        math.floor(tonumber(row.play_time) or 0)))

                    imported.players = imported.players + 1
                end
            end
        end
    end

    if (tableExists("sam_bans")) then
        local bans = sql.Query("SELECT * FROM sam_bans")
        if (istable(bans)) then
            for _, row in ipairs(bans) do
                local steamid = row.steamid

                if (steamid and steamid ~= "") then
                    local existing = sql.Query(
                        "SELECT steamid FROM axel_bans WHERE steamid = " .. esc(steamid))

                    if (not istable(existing)) then
                        -- SAM stores 0 for permanent, which matches ours.
                        sql.Query(string.format(
                            "INSERT INTO axel_bans (steamid, name, reason, admin, admin_name, created, expires) " ..
                            "VALUES (%s, %s, %s, %s, %s, %d, %d)",
                            esc(steamid), esc("Imported"),
                            esc(row.reason or "No reason given"),
                            esc(row.admin or "CONSOLE"), esc(row.admin or "Console"),
                            AXEL.Now(), math.floor(tonumber(row.unban_date) or 0)))

                        imported.bans = imported.bans + 1
                    else
                        imported.skipped = imported.skipped + 1
                    end
                end
            end
        end
    end

    sql.Query(string.format(
        "REPLACE INTO axel_ranks (name, inherit, immunity, ban_limit, permissions) " ..
        "VALUES ('__migrated__', NULL, 0, 0, %s)",
        esc(util.TableToJSON({at = AXEL.Now()}))))
    AXEL.Ranks["__migrated__"] = nil

    return true, string.format("Imported %d ranks, %d players, %d bans (%d bans already present).",
        imported.ranks, imported.players, imported.bans, imported.skipped)
end

--[[ ------------------------------------------------------------------------
    Boot
--------------------------------------------------------------------------- ]]

AXEL.LoadPlayerRankBackup()
AXEL.InitStorage()
AXEL.LoadRanks()

--[[
    Import first, seed second.

    The defaults are a fallback for a genuinely fresh server, not a baseline to
    merge over real data. Seeding first meant the import - which only adds ranks
    that do not already exist - would skip every rank sharing a name with a
    default. On a server migrating from SAM that silently replaced the real
    "moderator" and "admin" with the placeholders, changing their immunity and
    permissions. Getting this backwards is a privilege change, not a cosmetic
    one, so the order matters.
]]
local function countRanks()
    local total = 0
    for name in next, AXEL.Ranks do
        if (name ~= "__migrated__") then total = total + 1 end
    end
    return total
end

if (countRanks() == 0) then
    local _, message = AXEL.MigrateFromSAM(false)
    MsgC(Color(218, 177, 83), "[Axel] ", Color(210, 213, 218),
        "SAM import: " .. tostring(message) .. "\n")

    AXEL.LoadRanks()

    -- Only fill gaps the import did not cover. On a fresh server with no SAM
    -- data this seeds the whole default hierarchy; after a successful import it
    -- typically adds nothing.
    local seeded = 0
    for _, rank in ipairs(DEFAULT_RANKS) do
        if (not AXEL.Ranks[rank.name]) then
            AXEL.Ranks[rank.name] = rank
            AXEL.SaveRank(rank)
            seeded = seeded + 1
        end
    end

    if (seeded > 0) then
        MsgC(Color(218, 177, 83), "[Axel] ", Color(210, 213, 218),
            "Seeded " .. seeded .. " default rank(s) the import did not provide.\n")
    end

    AXEL.LoadRanks()

    -- A server with no superadmin cannot be administered. Guarantee one exists
    -- even if both the import and the seed somehow failed.
    if (not AXEL.Ranks[AXEL.SuperRank]) then
        AXEL.Ranks[AXEL.SuperRank] = {
            name = AXEL.SuperRank, inherit = AXEL.RootRank,
            immunity = AXEL.MaxImmunity, banLimit = 0, permissions = {}
        }
        AXEL.SaveRank(AXEL.Ranks[AXEL.SuperRank])

        MsgC(Color(226, 169, 60), "[Axel] ", Color(210, 213, 218),
            "No superadmin rank found. Created one.\n")
    end
end

concommand.Add("axel_migrate_from_sam", function(client)
    if (IsValid(client)) then return end   -- server console only

    local ok, message = AXEL.MigrateFromSAM(true)
    AXEL.LoadRanks()
    print("[Axel] " .. tostring(message))
end)
