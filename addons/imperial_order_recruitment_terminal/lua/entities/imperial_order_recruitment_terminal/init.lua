AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- Send logo material to clients
resource.AddFile("materials/imperial_order/imperial_recruitment_logo.png")

util.AddNetworkString("IMPERIAL_ORDERRecruit_AddCategory")
util.AddNetworkString("IMPERIAL_ORDERRecruit_AddEntry")
util.AddNetworkString("IMPERIAL_ORDERRecruit_DeleteCategory")
util.AddNetworkString("IMPERIAL_ORDERRecruit_DeleteEntry")
util.AddNetworkString("IMPERIAL_ORDERRecruit_Exit")
util.AddNetworkString("IMPERIAL_ORDERRecruit_SyncData")
util.AddNetworkString("IMPERIAL_ORDERRecruit_QuizSubmit")
util.AddNetworkString("IMPERIAL_ORDERRecruit_QuizResult")
util.AddNetworkString("IMPERIAL_ORDERRecruit_SyncQuiz")
util.AddNetworkString("IMPERIAL_ORDERRecruit_QuizAddQ")
util.AddNetworkString("IMPERIAL_ORDERRecruit_QuizRemoveQ")
util.AddNetworkString("IMPERIAL_ORDERRecruit_RestoreDefaults")
util.AddNetworkString("IMPERIAL_ORDERRecruit_SaveBackup")
util.AddNetworkString("IMPERIAL_ORDERRecruit_LoadBackup")
util.AddNetworkString("IMPERIAL_ORDERRecruit_DeleteBackup")
util.AddNetworkString("IMPERIAL_ORDERRecruit_BackupStatus")
util.AddNetworkString("IMPERIAL_ORDERRecruit_ListBackups")

local DEFAULT_QUIZ

local cvTerminalScale = CreateConVar(
    "imperial_order_recruitment_terminal_scale",
    "1.00",
    {FCVAR_ARCHIVE, FCVAR_NOTIFY},
    "Physical and display scale for newly spawned Imperial recruitment terminals (0.75-2.5)."
)

local function SetupScaledTerminalPhysics(ent, scale)
    ent:SetModelScale(scale, 0)

    local mins, maxs = ent:GetModelBounds()
    if mins and maxs then
        mins = mins * scale
        maxs = maxs * scale
        ent:PhysicsInitBox(mins, maxs)
        ent:SetCollisionBounds(mins, maxs)
    else
        ent:PhysicsInit(SOLID_VPHYSICS)
    end

    ent:SetSolid(SOLID_VPHYSICS)
    ent:SetMoveType(MOVETYPE_NONE)

    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:Sleep()
    end
end

local DEFAULT_DATA = {
    {
        name = "Recruitment",
        icon = "rank",
        entries = {
            { title = "IMPERIAL SERVICE", body = "Complete the recruitment assessment to enter Imperial service. Follow orders, respect the chain of command, and maintain discipline." },
            { title = "CADET EXPECTATIONS", body = "Cadets must obey server rules, remain in character, and report to their assigned instructor or superior officer." },
            { title = "ASSESSMENT", body = "A passing score is required. Failed assessments enter a cooldown before another attempt can be made." },
        },
    },
    {
        name = "Chain of Command",
        icon = "comms",
        entries = {
            { title = "ENLISTED", body = "Imperial Troopers form the operational backbone of the Empire and carry out lawful orders." },
            { title = "NCO", body = "Non-Commissioned Officers lead squads, train cadets, and maintain unit discipline." },
            { title = "OFFICER", body = "Commissioned Officers lead formations and coordinate shipboard operations." },
            { title = "HIGH COMMAND", body = "High Command holds operational authority over Imperial forces and recruitment standards." },
        },
    },
    {
        name = "Communications",
        icon = "jammer",
        entries = {
            { title = "IMPERIAL COMMS", body = "Use authorized channels, maintain radio discipline, and do not disclose restricted information." },
            { title = "BRIDGE FAILURE", body = "Active communications jammers disrupt authorized channels until they are bypassed or destroyed." },
        },
    },
}

function ENT:Initialize()
    self:SetModel(self.TerminalModel)
    self:SetUseType(SIMPLE_USE)

    local scale = math.Clamp(cvTerminalScale:GetFloat(), 0.75, 2.5)
    self:SetDisplayScale(scale)
    SetupScaledTerminalPhysics(self, scale)

    -- Expand the Source use trigger without changing the visible model. This
    -- makes E reliable when aiming at the monitor, frame, or control surface.
    if self.UseTriggerBounds then
        self:UseTriggerBounds(true, 42 * scale)
    end

    self:SetPowered(true)
    self:SetBootTime(0)
    self:SetActiveUser(NULL)
    self:SetTermState(0) -- STANDBY

    self.Data = table.Copy(DEFAULT_DATA)

    self:SyncData()
    self.QuizData = table.Copy(DEFAULT_QUIZ)
    self:SyncQuiz()
end

function ENT:SyncData(target)
    local json = util.TableToJSON(self.Data)
    local compressed = util.Compress(json)
    local len = #compressed

    net.Start("IMPERIAL_ORDERRecruit_SyncData")
        net.WriteUInt(self:EntIndex(), 16)
        net.WriteUInt(len, 16)
        net.WriteData(compressed, len)
    if target then
        net.Send(target)
    else
        net.Broadcast()
    end
end

-- Sync data to players on spawn and when they get close
hook.Add("PlayerInitialSpawn", "IMPERIAL_ORDERRecruit_SyncOnJoin", function(ply)
    timer.Simple(3, function()
        if not IsValid(ply) then return end
        for _, ent in ipairs(ents.FindByClass("imperial_order_recruitment_terminal")) do
            if IsValid(ent) and ent.Data then
                ent:SyncData(ply)
                ent:SyncQuiz(ply)
            end
        end
    end)
end)

--[[---------------------------------------------
    Terminal Session Management
    States: 0=STANDBY, 1=BOOTING, 2=ACTIVE
-----------------------------------------------]]
local BOOT_DURATION = 4
local IDLE_TIMEOUT = 300 -- 5 minutes

function ENT:StartSession(ply)
    if not IsValid(ply) then return end
    if IsValid(self:GetActiveUser()) then return end

    -- Cancel idle timer if active
    timer.Remove("IMPERIAL_ORDERRecruit_Idle_" .. self:EntIndex())

    self:SetActiveUser(ply)
    ply:Freeze(true)
    ply.IMPERIAL_ORDERRecruitUsing = self

    -- Sync data to this player (ensures quiz + data are fresh)
    self:SyncData(ply)
    self:SyncQuiz(ply)
end

function ENT:EndSession()
    local ply = self:GetActiveUser()
    if IsValid(ply) then
        ply:Freeze(false)
        ply.IMPERIAL_ORDERRecruitUsing = nil
    end
    self:SetActiveUser(NULL)

    -- Start idle timer: revert to STANDBY after 5 minutes
    if not self.ImperialOrderBeingRemoved and self:GetTermState() >= 1 then
        local entRef = self
        timer.Create("IMPERIAL_ORDERRecruit_Idle_" .. self:EntIndex(), IDLE_TIMEOUT, 1, function()
            if IsValid(entRef) and not IsValid(entRef:GetActiveUser()) then
                entRef:SetTermState(0) -- Back to STANDBY
            end
        end)
    end
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if not self:GetPowered() then return end

    -- The engine use callback and the fallback KeyPress hook can both run for
    -- the same key press. Debounce them so opening never immediately closes.
    if (activator.IMPERIAL_ORDERRecruitNextUse or 0) > CurTime() then return end
    activator.IMPERIAL_ORDERRecruitNextUse = CurTime() + 0.35

    local currentUser = self:GetActiveUser()
    local state = self:GetTermState()

    -- If this player is already using it, exit
    if currentUser == activator then
        self:EndSession()
        return
    end

    -- If someone else is using it
    if IsValid(currentUser) then
        activator:ChatPrint("[Recruitment] Terminal is in use.")
        return
    end

    -- Measure from the player's eyes to the nearest point on the console,
    -- rather than between entity origins, so the whole visible console is a
    -- reliable interaction target.
    local scale = math.max(self:GetDisplayScale(), 0.75)
    local useDistance = (self.BaseUseDistance or 220) * scale
    local eyePos = activator:EyePos()
    local nearest = self:NearestPoint(eyePos)
    if eyePos:DistToSqr(nearest) > (useDistance * useDistance) then return end

    if state == 0 then
        -- STANDBY → Boot up and start session
        self:SetTermState(1)
        self:SetBootTime(CurTime())
        self:StartSession(activator)
    elseif state == 1 then
        -- BOOTING → Start session (boot is already playing)
        self:StartSession(activator)
    elseif state == 2 then
        -- ACTIVE → Start session
        self:StartSession(activator)
    end
end

-- Reliable +use fallback for models whose visual screen does not line up
-- perfectly with their compiled collision mesh. The normal ENT:Use path still
-- handles direct traces; this only selects a nearby terminal in the view cone.
hook.Add("KeyPress", "IMPERIAL_ORDERRecruit_ReliableUse", function(ply, key)
    if key ~= IN_USE or not IsValid(ply) or not ply:Alive() then return end
    if IsValid(ply.IMPERIAL_ORDERRecruitUsing) then return end

    local eyePos = ply:EyePos()
    local aim = ply:GetAimVector()
    local best, bestScore

    local traced = ply:GetEyeTrace().Entity
    if IsValid(traced) and traced:GetClass() == "imperial_order_recruitment_terminal" then
        best = traced
    else
        for _, ent in ipairs(ents.FindByClass("imperial_order_recruitment_terminal")) do
            if IsValid(ent) and ent:GetPowered() then
                local scale = math.max(ent:GetDisplayScale(), 1)
                local target = ent:WorldSpaceCenter()
                local delta = target - eyePos
                local distance = delta:Length()

                if distance > 0 and distance <= ((ent.BaseUseDistance or 220) * scale) then
                    local score = aim:Dot(delta / distance)
                    if score >= 0.82 and (not bestScore or score > bestScore) then
                        best = ent
                        bestScore = score
                    end
                end
            end
        end
    end

    if IsValid(best) then
        best:Use(ply)
    end
end)

-- Client requests exit
net.Receive("IMPERIAL_ORDERRecruit_Exit", function(len, ply)
    if not IsValid(ply) then return end
    if not ply.IMPERIAL_ORDERRecruitUsing then return end
    local db = ply.IMPERIAL_ORDERRecruitUsing
    if IsValid(db) and db:GetActiveUser() == ply then
        db:EndSession()
    end
end)

function ENT:OnRemove()
    self.ImperialOrderBeingRemoved = true
    timer.Remove("IMPERIAL_ORDERRecruit_Idle_" .. self:EntIndex())
    self:EndSession()
end

function ENT:Think()
    -- Boot → Active transition
    if self:GetTermState() == 1 and self:GetBootTime() > 0 then
        if CurTime() - self:GetBootTime() >= BOOT_DURATION then
            self:SetTermState(2)
        end
    end

    -- Safety: release player if they moved too far
    -- Skip check if player is frozen (in active session, can't move)
    local user = self:GetActiveUser()
    if IsValid(user) and not user:IsFrozen() then
        if user:GetPos():Distance(self:GetPos()) > (650 * math.max(self:GetDisplayScale(), 1)) then
            self:EndSession()
        end
    end

    self:NextThink(CurTime() + 0.5)
    return true
end

--[[---------------------------------------------
    Cleanup on death/disconnect
-----------------------------------------------]]
hook.Add("PlayerDeath", "IMPERIAL_ORDERRecruit_ReleaseOnDeath", function(ply)
    if ply.IMPERIAL_ORDERRecruitUsing and IsValid(ply.IMPERIAL_ORDERRecruitUsing) then
        ply.IMPERIAL_ORDERRecruitUsing:EndSession()
    end
end)

hook.Add("PlayerDisconnected", "IMPERIAL_ORDERRecruit_ReleaseOnDisconnect", function(ply)
    if ply.IMPERIAL_ORDERRecruitUsing and IsValid(ply.IMPERIAL_ORDERRecruitUsing) then
        ply.IMPERIAL_ORDERRecruitUsing:EndSession()
    end
end)

--[[---------------------------------------------
    Rank Check & Data Handlers
-----------------------------------------------]]
local function GetPlayerRank(ply)
    if not IsValid(ply) then return "trooper" end
    if RPExtraTeams then
        local jobData = RPExtraTeams[ply:Team()]
        if jobData then
            local cat = jobData.category or ""
            if cat == "High Command" or cat == "Imperial Inquisitors" then return "commander" end
        end
    end
    local n = string.lower(team.GetName(ply:Team()) or "")
    if string.find(n, "commander") or string.find(n, "marshal") or string.find(n, "regimental") or string.find(n, "boss") or string.find(n, "director") or string.find(n, "admiral") then return "commander" end
    if string.find(n, "officer") or string.find(n, "captain") or string.find(n, " arc") or string.find(n, "lieutenant") then return "officer" end
    if string.find(n, "sergeant") or string.find(n, "heavy officer") or string.find(n, "corporal") then return "nco" end
    return "trooper"
end

local function CanEdit(ply)
    local r = GetPlayerRank(ply)
    return r == "commander" or r == "officer"
end

local function FindRecruitmentTerminal(ply)
    if ply.IMPERIAL_ORDERRecruitUsing and IsValid(ply.IMPERIAL_ORDERRecruitUsing) then
        return ply.IMPERIAL_ORDERRecruitUsing
    end
    -- Fallback: find nearest recruitment terminal within range
    local best, bestDist = nil, 750
    local ppos = ply.GetRealPos and ply:GetRealPos() or ply:GetPos()
    for _, ent in ipairs(ents.FindByClass("imperial_order_recruitment_terminal")) do
        if IsValid(ent) then
            local epos = ent.GetRealPos and ent:GetRealPos() or ent:GetPos()
            local d = ppos:Distance(epos)
            if d < bestDist then best = ent; bestDist = d end
        end
    end
    return best
end

local lastAction = {}
local function RateLimit(ply, action, cooldown)
    local key = ply:SteamID64() .. action
    if lastAction[key] and CurTime() - lastAction[key] < (cooldown or 1) then return false end
    lastAction[key] = CurTime()
    return true
end

local MAX_CATEGORIES = 8
local MAX_ENTRIES_PER_CAT = 15

net.Receive("IMPERIAL_ORDERRecruit_AddCategory", function(len, ply)
    if not IsValid(ply) then return end
    if not CanEdit(ply) then ply:ChatPrint("[Recruitment] Officer+ required."); return end
    if not RateLimit(ply, "addcat", 2) then return end
    local db = FindRecruitmentTerminal(ply)
    if not db then return end
    if #db.Data >= MAX_CATEGORIES then ply:ChatPrint("[Recruitment] Maximum " .. MAX_CATEGORIES .. " categories reached."); return end
    local name = string.Trim(net.ReadString())
    if #name < 1 or #name > 30 then return end
    -- Add to ALL recruitment terminals
    for _, ent in ipairs(ents.FindByClass("imperial_order_recruitment_terminal")) do
        if IsValid(ent) and ent.Data then
            table.insert(ent.Data, { name = name, icon = "custom", entries = {} })
            ent:SyncData()
        end
    end
    ply:ChatPrint("[Recruitment] Category '" .. name .. "' added to all terminals.")
end)

net.Receive("IMPERIAL_ORDERRecruit_AddEntry", function(len, ply)
    if not IsValid(ply) then return end
    if not CanEdit(ply) then ply:ChatPrint("[Recruitment] Officer+ required."); return end
    if not RateLimit(ply, "addent", 1) then return end
    local db = FindRecruitmentTerminal(ply)
    if not db then return end
    local catIdx = net.ReadUInt(8)
    local title = string.Trim(net.ReadString())
    local body = string.Trim(net.ReadString())
    if #title < 1 or #title > 60 then return end
    if #body < 1 or #body > 500 then return end
    if not db.Data[catIdx] then return end
    if #db.Data[catIdx].entries >= MAX_ENTRIES_PER_CAT then ply:ChatPrint("[Recruitment] Maximum " .. MAX_ENTRIES_PER_CAT .. " entries per category."); return end

    local catName = db.Data[catIdx].name
    -- Add to ALL recruitment terminals (match by category name)
    for _, ent in ipairs(ents.FindByClass("imperial_order_recruitment_terminal")) do
        if IsValid(ent) and ent.Data then
            for _, cat in ipairs(ent.Data) do
                if cat.name == catName then
                    table.insert(cat.entries, { title = title, body = body })
                    break
                end
            end
            ent:SyncData()
        end
    end
    ply:ChatPrint("[Recruitment] Entry '" .. title .. "' added.")
end)

net.Receive("IMPERIAL_ORDERRecruit_DeleteCategory", function(len, ply)
    if not CanEdit(ply) then return end
    if not RateLimit(ply, "delcat", 1) then return end
    local db = FindRecruitmentTerminal(ply)
    if not db then return end
    local catIdx = net.ReadUInt(8)
    if not db.Data[catIdx] then return end

    local cat = db.Data[catIdx]
    local rank = GetPlayerRank(ply)
    local isDefault = (cat.icon ~= "custom")

    if rank == "commander" then
        -- allowed
    elseif rank == "officer" then
        if isDefault then ply:ChatPrint("[Recruitment] Only High Command can delete default categories."); return end
    else
        return
    end

    local catName = cat.name
    -- Delete from ALL recruitment terminals (match by name)
    for _, ent in ipairs(ents.FindByClass("imperial_order_recruitment_terminal")) do
        if IsValid(ent) and ent.Data then
            for i = #ent.Data, 1, -1 do
                if ent.Data[i].name == catName then
                    table.remove(ent.Data, i)
                    break
                end
            end
            ent:SyncData()
        end
    end
    ply:ChatPrint("[Recruitment] Category '" .. catName .. "' deleted from all terminals.")
end)

net.Receive("IMPERIAL_ORDERRecruit_DeleteEntry", function(len, ply)
    if not CanEdit(ply) then return end
    if not RateLimit(ply, "delent", 1) then return end
    local db = FindRecruitmentTerminal(ply)
    if not db then return end
    local catIdx = net.ReadUInt(8)
    local entIdx = net.ReadUInt(8)
    if not db.Data[catIdx] or not db.Data[catIdx].entries[entIdx] then return end

    local cat = db.Data[catIdx]
    local rank = GetPlayerRank(ply)

    -- Officers and High Command can delete entries in ANY category
    if rank ~= "commander" and rank ~= "officer" then
        return
    end

    local catName = cat.name
    local entTitle = cat.entries[entIdx].title
    -- Delete from ALL recruitment terminals (match by category name + entry title)
    for _, ent in ipairs(ents.FindByClass("imperial_order_recruitment_terminal")) do
        if IsValid(ent) and ent.Data then
            for _, c in ipairs(ent.Data) do
                if c.name == catName then
                    for j = #c.entries, 1, -1 do
                        if c.entries[j].title == entTitle then
                            table.remove(c.entries, j)
                            break
                        end
                    end
                    break
                end
            end
            ent:SyncData()
        end
    end
    ply:ChatPrint("[Recruitment] Entry '" .. entTitle .. "' deleted from all terminals.")
end)

--[[---------------------------------------------
    Imperial Cadet Recruitment Assessment
    Questions stored per-entity, editable by High Command.
    Pass threshold: 70% | Cooldown: 5 minutes on fail
-----------------------------------------------]]
local QUIZ_PASS_PERCENT = 70
local QUIZ_COOLDOWN = 300
local quizCooldowns = {}
local MAX_QUIZ_QUESTIONS = 20

local QUIZ_WHITELIST_TEAMS = {}

hook.Add("InitPostEntity", "IMPERIAL_ORDERRecruit_QuizTeamSetup", function()
    QUIZ_WHITELIST_TEAMS = {}
    if RPExtraTeams then
        for k, v in pairs(RPExtraTeams) do
            local name = string.lower(v.name or "")
            if (string.find(name, "imperial trooper", 1, true) or string.find(name, "stormtrooper", 1, true)) and not string.find(name, "cadet", 1, true) then
                table.insert(QUIZ_WHITELIST_TEAMS, k)
            end
        end
    end
end)

-- Default questions (used when entity has no custom quiz data)
DEFAULT_QUIZ = {
    { question = "What is the primary duty of an Imperial Trooper?", answers = {
        { text = "Follow orders and serve the Empire", correct = true },
        { text = "Explore new planets", correct = false },
        { text = "Negotiate peace treaties", correct = false },
    }},
    { question = "What does RDM stand for?", answers = {
        { text = "Random Death Match — killing without reason", correct = true },
        { text = "Really Dangerous Missions", correct = false },
        { text = "Imperial Defense Mandate", correct = false },
    }},
    { question = "A fellow trooper is being disrespectful. What do you do?", answers = {
        { text = "Report to an NCO or Officer", correct = true },
        { text = "Attack them", correct = false },
        { text = "Ignore all rules and retaliate", correct = false },
    }},
    { question = "When should you follow the chain of command?", answers = {
        { text = "Always — report to your immediate superior", correct = true },
        { text = "Only when you feel like it", correct = false },
        { text = "Never — go straight to the Commander", correct = false },
    }},
    { question = "What happens if all communications consoles are destroyed?", answers = {
        { text = "All comms go offline until repaired", correct = true },
        { text = "Nothing changes", correct = false },
        { text = "Players are kicked from the server", correct = false },
    }},
    { question = "What is NLR (New Life Rule)?", answers = {
        { text = "After dying, you forget events leading to your death", correct = true },
        { text = "You get a new character name", correct = false },
        { text = "You must switch teams after death", correct = false },
    }},
    { question = "An enemy jammer is disrupting comms. How can you disable it?", answers = {
        { text = "Press E and complete the deactivation minigame", correct = true },
        { text = "Ignore it, comms will come back on their own", correct = false },
        { text = "Leave the server and rejoin", correct = false },
    }},
    { question = "What should you do during a debrief?", answers = {
        { text = "Stand at attention and listen to Command", correct = true },
        { text = "Run around the base", correct = false },
        { text = "Shoot your weapon in the air", correct = false },
    }},
}

-- Sync quiz questions to client (stripped of correct flags)
function ENT:SyncQuiz(target)
    local stripped = {}
    for i, q in ipairs(self.QuizData or {}) do
        local answers = {}
        for j, a in ipairs(q.answers) do
            table.insert(answers, a.text)
        end
        table.insert(stripped, { question = q.question, answers = answers })
    end

    local json = util.TableToJSON(stripped)
    local compressed = util.Compress(json)
    local len = #compressed

    net.Start("IMPERIAL_ORDERRecruit_SyncQuiz")
        net.WriteUInt(self:EntIndex(), 16)
        net.WriteUInt(len, 16)
        net.WriteData(compressed, len)
    if target then
        net.Send(target)
    else
        net.Broadcast()
    end
end

-- Rank check for quiz editing (Commander only)
local function IsHighCommand(ply)
    local r = GetPlayerRank(ply)
    return r == "commander"
end

-- Add question (High Command)
net.Receive("IMPERIAL_ORDERRecruit_QuizAddQ", function(len, ply)
    if not IsValid(ply) then return end
    if not IsHighCommand(ply) then ply:ChatPrint("[Recruitment] Access denied."); return end
    if not RateLimit(ply, "quizadd", 2) then return end
    local db = FindRecruitmentTerminal(ply)
    if not db then ply:ChatPrint("[Recruitment] No terminal found."); return end
    if #db.QuizData >= MAX_QUIZ_QUESTIONS then ply:ChatPrint("[Recruitment] Maximum " .. MAX_QUIZ_QUESTIONS .. " questions."); return end

    local question = string.Trim(net.ReadString())
    if #question < 5 or #question > 200 then return end

    local numCorrect = net.ReadUInt(4)
    if numCorrect < 1 or numCorrect > 8 then return end
    local correctAnswers = {}
    for i = 1, numCorrect do
        local a = string.Trim(net.ReadString())
        if #a >= 1 and #a <= 100 then table.insert(correctAnswers, a) end
    end

    local numWrong = net.ReadUInt(4)
    if numWrong < 1 or numWrong > 8 then return end
    local wrongAnswers = {}
    for i = 1, numWrong do
        local a = string.Trim(net.ReadString())
        if #a >= 1 and #a <= 100 then table.insert(wrongAnswers, a) end
    end

    if #correctAnswers < 1 or #wrongAnswers < 1 then return end

    local answers = {}
    for _, a in ipairs(correctAnswers) do
        table.insert(answers, { text = a, correct = true })
    end
    for _, a in ipairs(wrongAnswers) do
        table.insert(answers, { text = a, correct = false })
    end

    table.insert(db.QuizData, {
        question = question,
        answers = answers,
    })

    db:SyncQuiz()
    ply:ChatPrint("[Recruitment] Question added. Total: " .. #db.QuizData)
end)

-- Remove question (High Command)
net.Receive("IMPERIAL_ORDERRecruit_QuizRemoveQ", function(len, ply)
    if not IsValid(ply) then return end
    if not IsHighCommand(ply) then return end
    if not RateLimit(ply, "quizrem", 1) then return end
    local db = FindRecruitmentTerminal(ply)
    if not db then return end

    local idx = net.ReadUInt(8)
    if not db.QuizData[idx] then return end

    table.remove(db.QuizData, idx)
    db:SyncQuiz()
    ply:ChatPrint("[Recruitment] Question removed. Total: " .. #db.QuizData)
end)


local cvRecruitFaction = CreateConVar("imperial_order_recruitment_faction", "imperial_troopers", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Helix faction unique ID or name granted after passing recruitment.")
local cvRecruitClass = CreateConVar("imperial_order_recruitment_class", "", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Optional Helix class unique ID or name assigned after passing recruitment.")
local cvAutoTransfer = CreateConVar("imperial_order_recruitment_auto_transfer", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Transfer the active Helix character after whitelisting (0/1).")

local function FindHelixFaction(requested)
    if not ix or not ix.faction then return nil end
    requested = string.lower(string.Trim(requested or ""))

    local function consider(value, key)
        if not istable(value) then return nil end
        local uniqueID = string.lower(tostring(value.uniqueID or value.uniqueId or ""))
        local name = string.lower(tostring(value.name or ""))
        local index = value.index or (isnumber(key) and key or nil)
        if not index then return nil end

        if requested ~= "" and (uniqueID == requested or name == requested) then
            return index, value
        end
        return nil
    end

    for key, value in pairs(ix.faction.indices or {}) do
        local index, faction = consider(value, key)
        if index then return index, faction end
    end
    for key, value in pairs(ix.faction.list or {}) do
        local index, faction = consider(value, key)
        if index then return index, faction end
    end

    -- Safe fallback for schemas whose unique ID differs from the default convar.
    for key, value in pairs(ix.faction.indices or ix.faction.list or {}) do
        if istable(value) then
            local uniqueID = string.lower(tostring(value.uniqueID or ""))
            local name = string.lower(tostring(value.name or ""))
            local combined = uniqueID .. " " .. name
            if (string.find(combined, "imperial trooper", 1, true) or string.find(combined, "stormtrooper", 1, true))
                and not string.find(combined, "cadet", 1, true) then
                return value.index or (isnumber(key) and key or nil), value
            end
        end
    end
end

local function FindHelixClass(requested)
    if not ix or not ix.class or not ix.class.list then return nil end
    requested = string.lower(string.Trim(requested or ""))
    if requested == "" then return nil end
    for key, value in pairs(ix.class.list) do
        if istable(value) then
            local uniqueID = string.lower(tostring(value.uniqueID or ""))
            local name = string.lower(tostring(value.name or ""))
            if uniqueID == requested or name == requested then
                return value.index or (isnumber(key) and key or nil), value
            end
        end
    end
end

local function ApplyRecruitment(ply, terminal)
    -- Schemas can override everything by returning true/false from this hook.
    local custom = hook.Run("IMPERIAL_ORDERRecruitmentApply", ply, terminal)
    if custom ~= nil then return custom == true end

    -- Native Helix support: grant the faction whitelist first. Optionally
    -- transfer the currently loaded character when the server enables it.
    if ix and ply.SetWhitelisted then
        local factionIndex = select(1, FindHelixFaction(cvRecruitFaction:GetString()))
        if factionIndex then
            local ok, changed = pcall(ply.SetWhitelisted, ply, factionIndex, true)
            if ok then
                local character = ply.GetCharacter and ply:GetCharacter() or nil
                if character and character.SetData then
                    character:SetData("imperial_orderRecruitmentPassed", true)
                end

                if cvAutoTransfer:GetBool() and character and character.SetFaction then
                    pcall(character.SetFaction, character, factionIndex)

                    local classIndex = select(1, FindHelixClass(cvRecruitClass:GetString()))
                    if classIndex and character.JoinClass then
                        pcall(character.JoinClass, character, classIndex)
                    end
                end

                if character and character.Save then pcall(character.Save, character) end
                return true
            end
        end
    end

    -- DarkRP whitelist compatibility retained for servers that use it.
    local whitelisted = false
    for _, teamId in ipairs(QUIZ_WHITELIST_TEAMS) do
        if GAS and GAS.JobWhitelist then
            GAS.JobWhitelist:AddToWhitelist(teamId, GAS.JobWhitelist.LIST_TYPE_STEAMID, ply:AccountID())
            whitelisted = true
        elseif SH_WHITELIST then
            SH_WHITELIST:WhitelistSteamID(nil, ply:SteamID(), {team.GetName(teamId)}, {true})
            whitelisted = true
        elseif ply.changeTeam then
            ply:changeTeam(teamId, true)
            whitelisted = true
            break
        end
    end
    return whitelisted
end

-- Process quiz submission
net.Receive("IMPERIAL_ORDERRecruit_QuizSubmit", function(len, ply)
    if not IsValid(ply) then return end
    if not ply.IMPERIAL_ORDERRecruitUsing then return end
    local db = ply.IMPERIAL_ORDERRecruitUsing
    if not IsValid(db) then return end

    local questions = db.QuizData or {}
    local sid = ply:SteamID64()

    if quizCooldowns[sid] and quizCooldowns[sid] > CurTime() then
        net.Start("IMPERIAL_ORDERRecruit_QuizResult")
            net.WriteBool(false)
            net.WriteUInt(0, 8)
            net.WriteUInt(#questions, 8)
            net.WriteBool(true)
        net.Send(ply)
        return
    end

    local count = net.ReadUInt(8)
    local correct = 0

    for i = 1, math.min(count, #questions) do
        local answerIdx = net.ReadUInt(8)
        if questions[i] and questions[i].answers[answerIdx] then
            if questions[i].answers[answerIdx].correct then
                correct = correct + 1
            end
        end
    end

    local total = #questions
    local percent = total > 0 and (correct / total) * 100 or 0
    local passed = percent >= QUIZ_PASS_PERCENT

    if passed then
        local recruited = ApplyRecruitment(ply, db)
        if recruited then
            ply:ChatPrint("[Recruitment] Assessment passed. Your Imperial Trooper recruitment access has been granted.")
        else
            ply:ChatPrint("[Recruitment] Assessment passed. No matching automatic assignment was found; staff review is required.")
        end
    else
        quizCooldowns[sid] = CurTime() + QUIZ_COOLDOWN
        ply:ChatPrint("[Recruitment] Training failed. Score: " .. math.Round(percent) .. "%. Try again in 5 minutes.")
    end

    net.Start("IMPERIAL_ORDERRecruit_QuizResult")
        net.WriteBool(passed)
        net.WriteUInt(correct, 8)
        net.WriteUInt(total, 8)
        net.WriteBool(false)
    net.Send(ply)
end)

--[[---------------------------------------------
    Backup / Restore System
    Officers+ can restore defaults and save backups.
    Superadmins can delete backup files.
-----------------------------------------------]]
local BACKUP_DIR = "imperial_order_recruitment_backups/"

-- Ensure backup directory exists
if not file.IsDir(BACKUP_DIR, "DATA") then
    file.CreateDir(BACKUP_DIR)
end

-- Helper: check if ply is officer+
local function IsOfficerPlus(ply)
    local r = GetPlayerRank(ply)
    return r == "commander" or r == "officer"
end

-- Restore default data entries (merges defaults back, keeps custom categories)
net.Receive("IMPERIAL_ORDERRecruit_RestoreDefaults", function(len, ply)
    if not IsValid(ply) then return end
    if not IsOfficerPlus(ply) then ply:ChatPrint("[Recruitment] Access denied."); return end
    if not RateLimit(ply, "restore", 5) then return end
    local db = FindRecruitmentTerminal(ply)
    if not db then ply:ChatPrint("[Recruitment] No terminal found."); return end

    -- Get names of default categories
    local defaultNames = {}
    for _, cat in ipairs(DEFAULT_DATA) do
        defaultNames[cat.name] = true
    end

    -- Remove existing default categories from current data
    local customOnly = {}
    for _, cat in ipairs(db.Data) do
        if not defaultNames[cat.name] then
            table.insert(customOnly, cat)
        end
    end

    -- Rebuild: defaults first, then custom
    db.Data = table.Copy(DEFAULT_DATA)
    for _, cat in ipairs(customOnly) do
        table.insert(db.Data, cat)
    end

    db:SyncData()
    ply:ChatPrint("[Recruitment] Default entries restored. Custom entries preserved.")
end)

-- Send backup file list to client
local function SendBackupList(ply)
    local files = file.Find(BACKUP_DIR .. "*.json", "DATA")
    local list = {}
    for _, f in ipairs(files or {}) do
        table.insert(list, BACKUP_DIR .. f)
    end
    net.Start("IMPERIAL_ORDERRecruit_BackupStatus")
        net.WriteString(util.TableToJSON(list))
    net.Send(ply)
end

-- Save backup
net.Receive("IMPERIAL_ORDERRecruit_SaveBackup", function(len, ply)
    if not IsValid(ply) then return end
    if not IsOfficerPlus(ply) then ply:ChatPrint("[Recruitment] Access denied."); return end
    if not RateLimit(ply, "savebackup", 5) then return end
    local db = FindRecruitmentTerminal(ply)
    if not db then ply:ChatPrint("[Recruitment] No terminal found."); return end

    local timestamp = os.date("%Y%m%d_%H%M%S")
    local filename = BACKUP_DIR .. "recruitment_" .. timestamp .. ".json"

    local backup = {
        data = db.Data,
        quiz = db.QuizData,
        timestamp = timestamp,
        savedBy = ply:Nick(),
    }

    file.Write(filename, util.TableToJSON(backup, true))
    ply:ChatPrint("[Recruitment] Backup saved: " .. filename)

    -- Send backup list to client
    SendBackupList(ply)
end)

-- Load backup
net.Receive("IMPERIAL_ORDERRecruit_LoadBackup", function(len, ply)
    if not IsValid(ply) then return end
    if not IsOfficerPlus(ply) then return end
    if not RateLimit(ply, "loadbackup", 3) then return end
    local db = FindRecruitmentTerminal(ply)
    if not db then return end

    local filename = net.ReadString()
    -- Path traversal protection: must start with backup dir and end with .json
    if not string.StartWith(filename, BACKUP_DIR) then return end
    if not string.EndsWith(filename, ".json") then return end
    if string.find(filename, "%.%./") or string.find(filename, "\\") then return end
    if not file.Exists(filename, "DATA") then ply:ChatPrint("[Recruitment] Backup not found."); return end

    local json = file.Read(filename, "DATA")
    local backup = util.JSONToTable(json)
    if not backup then ply:ChatPrint("[Recruitment] Backup corrupted."); return end

    if backup.data then db.Data = backup.data end
    if backup.quiz then db.QuizData = backup.quiz end

    db:SyncData()
    db:SyncQuiz()
    ply:ChatPrint("[Recruitment] Backup loaded: " .. filename)
end)

-- Delete backup (Superadmin only)
net.Receive("IMPERIAL_ORDERRecruit_DeleteBackup", function(len, ply)
    if not IsValid(ply) then return end
    if not ply:IsSuperAdmin() then ply:ChatPrint("[Recruitment] Superadmin required."); return end
    if not RateLimit(ply, "delbackup", 2) then return end

    local filename = net.ReadString()
    if not string.StartWith(filename, BACKUP_DIR) then return end
    if not string.EndsWith(filename, ".json") then return end
    if string.find(filename, "%.%./") or string.find(filename, "\\") then return end
    if not file.Exists(filename, "DATA") then ply:ChatPrint("[Recruitment] File not found."); return end

    file.Delete(filename)
    ply:ChatPrint("[Recruitment] Backup deleted: " .. filename)
    SendBackupList(ply)
end)

-- List backups (no save, just send list)
net.Receive("IMPERIAL_ORDERRecruit_ListBackups", function(len, ply)
    if not IsValid(ply) then return end
    if not IsOfficerPlus(ply) then return end
    SendBackupList(ply)
end)
