-- Optional MySQL persistence for AXEL (MySQLOO).
-- Configure data/axel/mysql.json, then restart the server.

AXEL.MySQL = AXEL.MySQL or {Ready = false}
local DB = AXEL.MySQL
local CONFIG_PATH = "axel/mysql.json"

local defaults = {
    enabled = false,
    host = "127.0.0.1",
    port = 3306,
    database = "gmod",
    username = "gmod",
    password = "change_me",
    table_prefix = "axel_"
}

local function loadConfig()
    file.CreateDir("axel")
    local raw = file.Read(CONFIG_PATH, "DATA")
    local config = raw and util.JSONToTable(raw) or nil

    if (not istable(config)) then
        file.Write(CONFIG_PATH, util.TableToJSON(defaults, true))
        config = table.Copy(defaults)
    end

    config.port = math.Clamp(math.floor(tonumber(config.port) or 3306), 1, 65535)
    config.table_prefix = tostring(config.table_prefix or "axel_")
    if (not string.match(config.table_prefix, "^[%w_]+$")) then
        config.table_prefix = "axel_"
    end

    return config
end

function DB:Query(statement, onSuccess, onError)
    if (not self.Ready or not self.Connection) then
        if (onError) then onError("MySQL is not connected") end
        return false
    end

    local query = self.Connection:query(statement)
    function query:onSuccess(data)
        if (onSuccess) then onSuccess(data or {}) end
    end
    function query:onError(message)
        ErrorNoHalt("[Axel] MySQL query failed: " .. tostring(message) .. "\n")
        if (onError) then onError(message) end
    end
    query:start()
    return true
end

function DB:SavePlayer(steamid, name, rank, expiry, updated)
    if (not self.Ready) then return false end

    local escape = function(value)
        return "'" .. self.Connection:escape(tostring(value or "")) .. "'"
    end
    local tableName = self.TableName

    return self:Query(string.format(
        "INSERT INTO `%s` (`steamid`,`name`,`rank`,`rank_expiry`,`updated`) " ..
        "VALUES (%s,%s,%s,%d,%d) ON DUPLICATE KEY UPDATE " ..
        "`name`=VALUES(`name`),`rank`=VALUES(`rank`)," ..
        "`rank_expiry`=VALUES(`rank_expiry`),`updated`=VALUES(`updated`)",
        tableName, escape(steamid), escape(name), escape(rank),
        math.floor(tonumber(expiry) or 0), math.floor(tonumber(updated) or AXEL.Now())))
end

function DB:LoadPlayer(steamid, callback)
    if (not self.Ready) then return false end
    local escaped = self.Connection:escape(tostring(steamid or ""))

    return self:Query("SELECT * FROM `" .. self.TableName ..
        "` WHERE `steamid`='" .. escaped .. "' LIMIT 1", function(rows)
        callback(istable(rows) and rows[1] or nil)
    end)
end

function DB:Connect()
    self.Config = loadConfig()
    if (not self.Config.enabled) then
        MsgC(Color(218, 177, 83), "[Axel] ", color_white,
            "MySQL disabled; using SQLite plus JSON rank backup.\n")
        return
    end

    if (not file.Exists("bin/gmsv_mysqloo_" .. jit.os:lower() .. ".dll", "LUA") and
        not pcall(require, "mysqloo")) then
        ErrorNoHalt("[Axel] MySQL enabled but MySQLOO could not be loaded.\n")
        return
    end
    if (not mysqloo) then
        local ok = pcall(require, "mysqloo")
        if (not ok or not mysqloo) then
            ErrorNoHalt("[Axel] MySQL enabled but MySQLOO is unavailable.\n")
            return
        end
    end

    self.TableName = self.Config.table_prefix .. "players"
    local connection = mysqloo.connect(
        tostring(self.Config.host), tostring(self.Config.username),
        tostring(self.Config.password), tostring(self.Config.database), self.Config.port)
    self.Connection = connection

    function connection:onConnected()
        DB.Ready = true
        DB:Query("CREATE TABLE IF NOT EXISTS `" .. DB.TableName .. "` (" ..
            "`steamid` VARCHAR(32) NOT NULL PRIMARY KEY," ..
            "`name` VARCHAR(255) NOT NULL DEFAULT 'Unknown'," ..
            "`rank` VARCHAR(64) NOT NULL DEFAULT 'user'," ..
            "`rank_expiry` BIGINT NOT NULL DEFAULT 0," ..
            "`updated` BIGINT NOT NULL DEFAULT 0" ..
            ") CHARACTER SET utf8mb4", function()
                MsgC(Color(218, 177, 83), "[Axel] ", color_white,
                    "MySQL rank persistence connected.\n")
                hook.Run("AXEL.MySQLReady")
            end)
    end

    function connection:onConnectionFailed(message)
        DB.Ready = false
        ErrorNoHalt("[Axel] MySQL connection failed: " .. tostring(message) .. "\n")
    end

    connection:connect()
end

DB:Connect()

