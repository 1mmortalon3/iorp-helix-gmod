local DATA_DIRECTORY = "imperial_order/command_posts"
local SAVE_TIMER = "ImperialOrderCommandPosts_QueuedSave"

local function GetDataPath()
    return DATA_DIRECTORY .. "/" .. string.lower(game.GetMap() or "unknown_map") .. ".json"
end

local function IsCommandPost(entity)
    return IsValid(entity) and entity:GetClass() == "imperial_order_command_post"
end

local function SerializePost(entity)
    return {
        position = {entity:GetPos().x, entity:GetPos().y, entity:GetPos().z},
        angles = {entity:GetAngles().p, entity:GetAngles().y, entity:GetAngles().r},
        name = entity:GetPostName(),
        radius = entity:GetCaptureRadius(),
        duration = entity:GetCaptureDuration(),
        enabled = entity:GetCommandPostEnabled(),
        ownerKey = entity:GetOwnerKey(),
        ownerName = entity:GetOwnerName(),
        ownerColor = {
            entity:GetOwnerColor().x,
            entity:GetOwnerColor().y,
            entity:GetOwnerColor().z
        }
    }
end

function IMPERIAL_ORDER_COMMAND_POSTS.SaveAll()
    if IMPERIAL_ORDER_COMMAND_POSTS.Restoring then return false end

    file.CreateDir(DATA_DIRECTORY)

    local records = {}
    for _, entity in ipairs(ents.FindByClass("imperial_order_command_post")) do
        if IsCommandPost(entity) then
            records[#records + 1] = SerializePost(entity)
        end
    end

    file.Write(GetDataPath(), util.TableToJSON(records, true))
    return true
end

function IMPERIAL_ORDER_COMMAND_POSTS.QueueSave()
    timer.Create(SAVE_TIMER, 0.25, 1, function()
        if IMPERIAL_ORDER_COMMAND_POSTS then
            IMPERIAL_ORDER_COMMAND_POSTS.SaveAll()
        end
    end)
end

local function VectorFromData(data)
    if not istable(data) then return vector_origin end
    return Vector(tonumber(data[1]) or 0, tonumber(data[2]) or 0, tonumber(data[3]) or 0)
end

local function AngleFromData(data)
    if not istable(data) then return angle_zero end
    return Angle(tonumber(data[1]) or 0, tonumber(data[2]) or 0, tonumber(data[3]) or 0)
end

local function SpawnRecord(record)
    if not istable(record) then return nil end

    local entity = ents.Create("imperial_order_command_post")
    if not IsValid(entity) then return nil end

    entity:SetPos(VectorFromData(record.position))
    entity:SetAngles(AngleFromData(record.angles))
    entity:Spawn()
    entity:Activate()

    entity:SetPostName(string.Trim(tostring(record.name or "COMMAND POST")))
    entity:SetCaptureRadius(math.Clamp(tonumber(record.radius) or 300, 100, 1500))
    entity:SetCaptureDuration(math.Clamp(tonumber(record.duration) or 20, 3, 300))
    entity:SetCommandPostEnabled(record.enabled ~= false)

    local ownerKey, ownerName, ownerColor = IMPERIAL_ORDER_COMMAND_POSTS.GetSideByKey(record.ownerKey)
    entity:SetOwnerSide({
        key = ownerKey,
        name = ownerName,
        color = ownerColor
    }, false)

    return entity
end

function IMPERIAL_ORDER_COMMAND_POSTS.LoadAll()
    IMPERIAL_ORDER_COMMAND_POSTS.Restoring = true
    timer.Remove(SAVE_TIMER)

    for _, entity in ipairs(ents.FindByClass("imperial_order_command_post")) do
        if IsValid(entity) then entity:Remove() end
    end

    local raw = file.Read(GetDataPath(), "DATA")
    local records = raw and util.JSONToTable(raw) or {}

    if istable(records) then
        for _, record in ipairs(records) do
            SpawnRecord(record)
        end
    end

    timer.Simple(0, function()
        if IMPERIAL_ORDER_COMMAND_POSTS then
            IMPERIAL_ORDER_COMMAND_POSTS.Restoring = false
        end
    end)

    return istable(records) and #records or 0
end

hook.Add("InitPostEntity", "ImperialOrderCommandPosts_LoadMapPosts", function()
    timer.Simple(1, function()
        if IMPERIAL_ORDER_COMMAND_POSTS then
            local count = IMPERIAL_ORDER_COMMAND_POSTS.LoadAll()
            MsgC(Color(190, 30, 35), "[Imperial Order Command Posts] ", color_white, "Loaded " .. tostring(count) .. " command post(s) for " .. game.GetMap() .. ".\n")
        end
    end)
end)

hook.Add("ShutDown", "ImperialOrderCommandPosts_SaveShutdown", function()
    if IMPERIAL_ORDER_COMMAND_POSTS then IMPERIAL_ORDER_COMMAND_POSTS.SaveAll() end
end)

local function IsAdminCaller(client)
    return not IsValid(client) or client:IsAdmin() or client:IsSuperAdmin()
end

concommand.Add("imperial_order_commandposts_save", function(client)
    if not IsAdminCaller(client) then return end
    IMPERIAL_ORDER_COMMAND_POSTS.SaveAll()
    if IsValid(client) then client:ChatPrint("[Command Posts] Saved for " .. game.GetMap() .. ".") end
end)

concommand.Add("imperial_order_commandposts_reload", function(client)
    if not IsAdminCaller(client) then return end
    local count = IMPERIAL_ORDER_COMMAND_POSTS.LoadAll()
    if IsValid(client) then client:ChatPrint("[Command Posts] Reloaded " .. tostring(count) .. " post(s).") end
end)

concommand.Add("imperial_order_commandposts_clear", function(client)
    if not IsAdminCaller(client) then return end

    IMPERIAL_ORDER_COMMAND_POSTS.Restoring = true
    for _, entity in ipairs(ents.FindByClass("imperial_order_command_post")) do
        if IsValid(entity) then entity:Remove() end
    end
    IMPERIAL_ORDER_COMMAND_POSTS.Restoring = false
    IMPERIAL_ORDER_COMMAND_POSTS.SaveAll()

    if IsValid(client) then client:ChatPrint("[Command Posts] Cleared all posts on " .. game.GetMap() .. ".") end
end)
