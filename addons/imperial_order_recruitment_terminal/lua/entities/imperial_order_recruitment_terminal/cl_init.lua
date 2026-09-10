include("shared.lua")

-- Localize hot-path globals
local CurTime = CurTime
local IsValid = IsValid
local FrameTime = FrameTime
local math_sin = math.sin
local math_max = math.max
local math_min = math.min
local math_Clamp = math.Clamp

ENT.RenderGroup = RENDERGROUP_BOTH

-- Fonts
surface.CreateFont("IMPERIAL_ORDERRecruit_Title",    { font = "SWEuro", size = 36, weight = 800, antialias = true, fallbackFonts = {"Arial"} })
surface.CreateFont("IMPERIAL_ORDERRecruit_Header",   { font = "SWEuro", size = 32, weight = 700, antialias = true, fallbackFonts = {"Arial"} })
surface.CreateFont("IMPERIAL_ORDERRecruit_Body",     { font = "SWEuro", size = 18, weight = 500, antialias = true, fallbackFonts = {"Arial"} })
surface.CreateFont("IMPERIAL_ORDERRecruit_Small",    { font = "SWEuro", size = 14, weight = 500, antialias = true, fallbackFonts = {"Arial"} })
surface.CreateFont("IMPERIAL_ORDERRecruit_Cat",      { font = "SWEuro", size = 19, weight = 700, antialias = true, fallbackFonts = {"Arial"} })
surface.CreateFont("IMPERIAL_ORDERRecruit_CatSmall", { font = "SWEuro", size = 15, weight = 600, antialias = true, fallbackFonts = {"Arial"} })
surface.CreateFont("IMPERIAL_ORDERRecruit_Boot",     { font = "SWEuro", size = 42, weight = 800, antialias = true, fallbackFonts = {"Arial"} })
surface.CreateFont("IMPERIAL_ORDERRecruit_BootSub",  { font = "SWEuro", size = 20, weight = 500, antialias = true, fallbackFonts = {"Arial"} })
surface.CreateFont("IMPERIAL_ORDERRecruit_Standby",  { font = "SWEuro", size = 60, weight = 800, antialias = true, fallbackFonts = {"Arial"} })
surface.CreateFont("IMPERIAL_ORDERRecruit_StandbySub", { font = "SWEuro", size = 32, weight = 600, antialias = true, fallbackFonts = {"Arial"} })
surface.CreateFont("IMPERIAL_ORDERRecruit_Btn",      { font = "SWEuro", size = 16, weight = 700, antialias = true, fallbackFonts = {"Arial"} })
surface.CreateFont("IMPERIAL_ORDERRecruit_Prompt",   { font = "SWEuro", size = 20, weight = 600, antialias = true, fallbackFonts = {"Arial"} })
surface.CreateFont("IMPERIAL_ORDERRecruit_ComingSoon", { font = "SWEuro", size = 104, weight = 800, antialias = true, fallbackFonts = {"Arial"} })

-- Pre-allocated colors
local C = {
    bg        = Color(4, 4, 6),
    panel     = Color(13, 13, 17),
    accent    = Color(190, 25, 30),
    accentDim = Color(105, 15, 20, 135),
    text      = Color(195, 198, 205),
    textBrt   = Color(245, 245, 248),
    textDim   = Color(105, 108, 118),
    hover     = Color(125, 15, 20, 95),
    selected  = Color(145, 18, 24, 120),
    gold      = Color(225, 225, 230),
    red       = Color(230, 45, 45),
    green     = Color(120, 205, 145),
    orange    = Color(215, 115, 45),
    scanline  = Color(185, 25, 30, 5),
}

local colSidebarBg  = Color(8, 8, 11)
local colSeparator  = Color(45, 18, 22)
local colTransparent = Color(0, 0, 0, 0)
local colModelBg    = Color(10, 10, 13)
local colBootGlow   = Color(0, 0, 0)
local colBootText   = Color(0, 0, 0)
local colBootSub    = Color(0, 0, 0)
local colLogoTint   = Color(255, 255, 255, 255)

-- Delete button colors (pre-allocated, avoid per-frame Color() calls)
local colDelText    = Color(255, 80, 80)
local colDelTextDim = Color(120, 60, 60)
local colDelCatBg   = Color(80, 20, 20)
local colDelCatBgH  = Color(160, 30, 30)
local colDelCatBdr  = Color(180, 50, 50)
local colDelCatTxt  = Color(160, 100, 100)
local colDelCatTxtH = Color(255, 200, 200)
local colDelEntBg   = Color(100, 30, 30)
local colDelEntBgH  = Color(180, 40, 40)
local colDelEntBdr  = Color(200, 60, 60)
local colDelEntTxt  = Color(180, 120, 120)

-- Logo material
local imperialLogo = Material("imperial_order/imperial_recruitment_logo.png", "smooth mips")

-- Square canvas for the square monitor on imp_console_medium03.mdl.
local SW, SH = 1000, 1000
local BOOT_DURATION = 4

local function GetTerminalDisplayScale(ent)
    if not IsValid(ent) then return 1.00 end
    local scale = ent.GetDisplayScale and ent:GetDisplayScale() or 0
    if scale <= 0 then
        scale = ent.DefaultDisplayScale or 1.00
    end
    return math.Clamp(scale, 0.75, 2.5)
end



--[[---------------------------------------------
    Camera Capture Command
    Stand where you want the camera, aim at the
    screen center, run imperial_order_recruit_capture_cam.
    Prints ready-to-paste ConVar commands.
-----------------------------------------------]]
-- Store the ACTUAL rendered camera each frame for imperial_order_recruit_capture_cam
local lastRealCamPos = Vector(0, 0, 0)
local lastRealCamAng = Angle(0, 0, 0)

concommand.Add("imperial_order_recruit_capture_cam", function(ply)
    if not IsValid(ply) then return end

    local camPos = lastRealCamPos
    local camAng = lastRealCamAng

    -- Trace from actual camera to get target
    local trDir = camAng:Forward()
    local tr = util.TraceLine({ start = camPos, endpos = camPos + trDir * 500, filter = ply })

    -- Find nearest recruitment terminal
    local nearest, nearDist = nil, math.huge
    for _, ent in ipairs(ents.FindByClass("imperial_order_recruitment_terminal")) do
        if IsValid(ent) then
            local d = camPos:Distance(ent:GetPos())
            if d < nearDist then nearest = ent; nearDist = d end
        end
    end

    if not IsValid(nearest) or nearDist > 500 then
        print("[Recruitment] No recruitment terminal within 500 units.")
        return
    end

    local localPos = nearest:WorldToLocal(camPos)
    local localTarget = nearest:WorldToLocal(tr.HitPos)

    print("")
    print("============================================")
    print("  RECRUITMENT TERMINAL CAMERA CAPTURE — paste into console:")
    print("============================================")
    print(string.format("imperial_order_recruit_cam_x %.1f", localPos.x))
    print(string.format("imperial_order_recruit_cam_y %.1f", localPos.y))
    print(string.format("imperial_order_recruit_cam_z %.1f", localPos.z))
    print(string.format("imperial_order_recruit_cam_target_x %.1f", localTarget.x))
    print(string.format("imperial_order_recruit_cam_target_y %.1f", localTarget.y))
    print(string.format("imperial_order_recruit_cam_target_z %.1f", localTarget.z))
    print("============================================")
end)

-- State
local clientState = {}
local recruitmentData = {}

-- Receive data from server (compressed JSON via net message)
net.Receive("IMPERIAL_ORDERRecruit_SyncData", function()
    local entIdx = net.ReadUInt(16)
    local len = net.ReadUInt(16)
    local compressed = net.ReadData(len)
    local json = util.Decompress(compressed)
    if json then
        recruitmentData[entIdx] = util.JSONToTable(json) or {}
    end
end)

-- Session state (client-side)
local activeTerminal = nil
local sessionStart = 0
local camOrigin = Vector(0, 0, 0)

-- 3D2D cursor (set during DrawTranslucent from eye trace)
local cursorX, cursorY = -1, -1
local mousePressed = false
local mouseHeld = false

-- Model preview (ClientsideModel rendered in world)
local previewModel = nil
local previewModelPath = ""
local previewSpin = 0

-- Model preview ConVars
-- Model preview (adjustable)
CreateClientConVar("imperial_order_recruit_mdl_offset_x",   "0",    true, false, "Model X offset")
CreateClientConVar("imperial_order_recruit_mdl_offset_y",   "-4",   true, false, "Model Y offset")
CreateClientConVar("imperial_order_recruit_mdl_offset_z",   "-6.6", true, false, "Model Z offset")
CreateClientConVar("imperial_order_recruit_mdl_size",       "1.8",  true, false, "Model size")
CreateClientConVar("imperial_order_recruit_mdl_pitch",      "0",    true, false, "Model pitch")
CreateClientConVar("imperial_order_recruit_mdl_yaw_offset", "0",    true, false, "Model yaw offset")
CreateClientConVar("imperial_order_recruit_mdl_roll",       "0",    true, false, "Model roll")

local cv_mdl_ox    = GetConVar("imperial_order_recruit_mdl_offset_x")
local cv_mdl_oy    = GetConVar("imperial_order_recruit_mdl_offset_y")
local cv_mdl_oz    = GetConVar("imperial_order_recruit_mdl_offset_z")
local cv_mdl_size  = GetConVar("imperial_order_recruit_mdl_size")
local cv_mdl_pitch = GetConVar("imperial_order_recruit_mdl_pitch")
local cv_mdl_yaw   = GetConVar("imperial_order_recruit_mdl_yaw_offset")
local cv_mdl_roll  = GetConVar("imperial_order_recruit_mdl_roll")

local function RemovePreviewModel()
    if IsValid(previewModel) then
        previewModel:Remove()
    end
    previewModel = nil
    previewModelPath = ""
end

local function UpdatePreviewModel(modelPath)
    if not modelPath or modelPath == "" then
        RemovePreviewModel()
        return
    end

    if previewModelPath == modelPath and IsValid(previewModel) then
        return
    end

    RemovePreviewModel()

    previewModel = ClientsideModel(modelPath)
    if IsValid(previewModel) then
        previewModel:SetNoDraw(true)
        previewModelPath = modelPath

        -- Scale applied per-frame from ConVar
    end
end

local function GetState(ent)
    local idx = ent:EntIndex()
    if not clientState[idx] then
        clientState[idx] = { selectedCat = 1, selectedEntry = 0 }
    end
    return clientState[idx]
end

local function GetCachedData(ent)
    return recruitmentData[ent:EntIndex()] or {}
end

local function InRect(x, y, w, h)
    return cursorX >= x and cursorX <= x + w and cursorY >= y and cursorY <= y + h
end

local function ConsumeClick()
    mousePressed = false
end

local function IsOfficerPlus()
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end
    if RPExtraTeams then
        local jobData = RPExtraTeams[ply:Team()]
        local cat = jobData and jobData.category or ""
        if cat == "High Command" or cat == "Imperial Inquisitors" then return true end
    end
    local n = string.lower(team.GetName(ply:Team()) or "")
    if string.find(n, "commander") or string.find(n, "marshal") or string.find(n, "regimental") or string.find(n, "boss") or string.find(n, "director") or string.find(n, "admiral") then return true end
    if string.find(n, "officer") or string.find(n, "captain") or string.find(n, " arc") or string.find(n, "lieutenant") then return true end
    return false
end

local function IsHighCommand()
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end
    if RPExtraTeams then
        local jobData = RPExtraTeams[ply:Team()]
        if jobData and (jobData.category == "High Command" or jobData.category == "Imperial Inquisitors") then return true end
    end
    local n = string.lower(team.GetName(ply:Team()) or "")
    if string.find(n, "commander") or string.find(n, "marshal") or string.find(n, "regimental") or string.find(n, "admiral") then return true end
    return false
end

local function IsInSession()
    return IsValid(activeTerminal)
end

--[[---------------------------------------------
    Settings Panel (Gear icon, Officer+)
-----------------------------------------------]]
local settingsOpen = false
local backupFiles = {}
local deleteConfirm = nil -- filename pending delete confirmation

-- Reusable delete confirmation popup
local function ConfirmDelete(name, onConfirm)
    local confirm = vgui.Create("DFrame")
    confirm:SetSize(320, 110); confirm:Center()
    confirm:SetTitle("Confirm Deletion"); confirm:MakePopup()
    confirm:SetZPos(999)

    local lbl = vgui.Create("DLabel", confirm)
    lbl:SetPos(10, 30); lbl:SetSize(300, 24)
    lbl:SetText("Delete \"" .. name .. "\"?")
    lbl:SetTextColor(Color(255, 200, 200))
    lbl:SetFont("DermaDefaultBold")

    local yesBtn = vgui.Create("DButton", confirm)
    yesBtn:SetPos(10, 65); yesBtn:SetSize(140, 30); yesBtn:SetText("YES, DELETE")
    yesBtn:SetTextColor(Color(255, 80, 80))
    yesBtn.DoClick = function()
        onConfirm()
        confirm:Remove()
    end

    local noBtn = vgui.Create("DButton", confirm)
    noBtn:SetPos(160, 65); noBtn:SetSize(140, 30); noBtn:SetText("Cancel")
    noBtn.DoClick = function() confirm:Remove() end
end

net.Receive("IMPERIAL_ORDERRecruit_BackupStatus", function()
    local json = net.ReadString()
    local list = util.JSONToTable(json)
    if list then backupFiles = list end
end)

local function OpenSettingsPanel()
    -- Request backup list from server
    net.Start("IMPERIAL_ORDERRecruit_ListBackups"); net.SendToServer()

    local frame = vgui.Create("DFrame")
    frame:SetSize(460, 400); frame:Center(); frame:SetTitle("Recruitment Terminal Settings"); frame:MakePopup()

    local yOff = 30

    -- Restore Defaults (Officer+)
    local restoreBtn = vgui.Create("DButton", frame)
    restoreBtn:SetPos(10, yOff); restoreBtn:SetSize(440, 30)
    restoreBtn:SetText("Restore Default Data Entries (keeps custom)")
    restoreBtn.DoClick = function()
        net.Start("IMPERIAL_ORDERRecruit_RestoreDefaults"); net.SendToServer()
        timer.Simple(0.5, function() if IsValid(frame) then frame:Remove() end end)
    end
    yOff = yOff + 36

    -- Save Backup (Officer+)
    local saveBtn = vgui.Create("DButton", frame)
    saveBtn:SetPos(10, yOff); saveBtn:SetSize(440, 30)
    saveBtn:SetText("Save Custom Data Backup")
    saveBtn.DoClick = function()
        net.Start("IMPERIAL_ORDERRecruit_SaveBackup"); net.SendToServer()
    end
    yOff = yOff + 42

    -- Separator
    local sep = vgui.Create("DLabel", frame)
    sep:SetPos(10, yOff); sep:SetSize(440, 16); sep:SetText("Backup Files:"); sep:SetTextColor(Color(180, 180, 180))
    yOff = yOff + 20

    -- Backup list
    local backupList = vgui.Create("DListView", frame)
    backupList:SetPos(10, yOff); backupList:SetSize(440, 150)
    backupList:AddColumn("Filename")

    local function RefreshList()
        backupList:Clear()
        for _, f in ipairs(backupFiles) do
            backupList:AddLine(f)
        end
    end
    RefreshList()

    yOff = yOff + 156

    -- Load Backup (Officer+)
    local loadBtn = vgui.Create("DButton", frame)
    loadBtn:SetPos(10, yOff); loadBtn:SetSize(215, 28)
    loadBtn:SetText("Load Selected Backup")
    loadBtn.DoClick = function()
        local sel = backupList:GetSelectedLine()
        if not sel then return end
        local line = backupList:GetLine(sel)
        if not line then return end
        net.Start("IMPERIAL_ORDERRecruit_LoadBackup"); net.WriteString(line:GetColumnText(1)); net.SendToServer()
        timer.Simple(0.5, function() if IsValid(frame) then frame:Remove() end end)
    end

    -- Delete Backup (Superadmin only)
    if LocalPlayer():IsSuperAdmin() then
        local delBtn = vgui.Create("DButton", frame)
        delBtn:SetPos(235, yOff); delBtn:SetSize(215, 28)
        delBtn:SetText("Delete Selected Backup")
        delBtn:SetTextColor(Color(220, 80, 80))
        delBtn.DoClick = function()
            local sel = backupList:GetSelectedLine()
            if not sel then return end
            local line = backupList:GetLine(sel)
            if not line then return end
            local filename = line:GetColumnText(1)

            -- Confirmation dialog
            local confirm = vgui.Create("DFrame")
            confirm:SetSize(340, 120); confirm:Center()
            confirm:SetTitle("Confirm Deletion"); confirm:MakePopup()
            confirm:SetZPos(999)

            local lbl = vgui.Create("DLabel", confirm)
            lbl:SetPos(10, 30); lbl:SetSize(320, 32); lbl:SetWrap(true)
            lbl:SetText("Are you sure you want to delete this backup?\n" .. string.GetFileFromFilename(filename))
            lbl:SetTextColor(Color(255, 200, 200))

            local yesBtn = vgui.Create("DButton", confirm)
            yesBtn:SetPos(10, 75); yesBtn:SetSize(150, 30); yesBtn:SetText("YES, DELETE")
            yesBtn:SetTextColor(Color(255, 80, 80))
            yesBtn.DoClick = function()
                net.Start("IMPERIAL_ORDERRecruit_DeleteBackup"); net.WriteString(filename); net.SendToServer()
                confirm:Remove()
                timer.Simple(0.3, RefreshList)
            end

            local noBtn = vgui.Create("DButton", confirm)
            noBtn:SetPos(170, 75); noBtn:SetSize(150, 30); noBtn:SetText("Cancel")
            noBtn.DoClick = function() confirm:Remove() end
        end
    end

    yOff = yOff + 34

    -- Refresh button
    local refreshBtn = vgui.Create("DButton", frame)
    refreshBtn:SetPos(10, yOff); refreshBtn:SetSize(440, 24)
    refreshBtn:SetText("Refresh Backup List")
    refreshBtn.DoClick = function()
        net.Start("IMPERIAL_ORDERRecruit_ListBackups"); net.SendToServer()
        timer.Simple(0.5, RefreshList)
    end
end

--[[---------------------------------------------
    Edit Dialogs (DFrame popups)
-----------------------------------------------]]
local function OpenAddCategoryDialog()
    local frame = vgui.Create("DFrame")
    frame:SetSize(280, 100); frame:Center(); frame:SetTitle("Add Category"); frame:MakePopup()
    local entry = vgui.Create("DTextEntry", frame)
    entry:SetPos(10, 30); entry:SetSize(260, 24); entry:SetPlaceholderText("Category name...")
    local btn = vgui.Create("DButton", frame)
    btn:SetPos(10, 62); btn:SetSize(260, 28); btn:SetText("CREATE")
    btn.DoClick = function()
        local name = string.Trim(entry:GetValue())
        if #name < 1 then return end
        net.Start("IMPERIAL_ORDERRecruit_AddCategory"); net.WriteString(name); net.SendToServer()
        frame:Remove()
    end
end

local function OpenAddEntryDialog(catIdx)
    local frame = vgui.Create("DFrame")
    frame:SetSize(320, 200); frame:Center(); frame:SetTitle("Add Entry"); frame:MakePopup()
    local titleEntry = vgui.Create("DTextEntry", frame)
    titleEntry:SetPos(10, 30); titleEntry:SetSize(300, 24); titleEntry:SetPlaceholderText("Title...")
    local bodyEntry = vgui.Create("DTextEntry", frame)
    bodyEntry:SetPos(10, 62); bodyEntry:SetSize(300, 90); bodyEntry:SetPlaceholderText("Content..."); bodyEntry:SetMultiline(true)
    local btn = vgui.Create("DButton", frame)
    btn:SetPos(10, 160); btn:SetSize(300, 28); btn:SetText("ADD ENTRY")
    btn.DoClick = function()
        local title = string.Trim(titleEntry:GetValue())
        local body = string.Trim(bodyEntry:GetValue())
        if #title < 1 or #body < 1 then return end
        net.Start("IMPERIAL_ORDERRecruit_AddEntry"); net.WriteUInt(catIdx, 8); net.WriteString(title); net.WriteString(body); net.SendToServer()
        frame:Remove()
    end
end

--[[---------------------------------------------
    Imperial crest (texture: imperial_order/imperial_recruitment_logo.png)
-----------------------------------------------]]
local function DrawImperialLogo(cx, cy, radius, rot, alpha)
    local size = radius * 2
    colLogoTint.r = C.accent.r; colLogoTint.g = C.accent.g; colLogoTint.b = C.accent.b; colLogoTint.a = alpha
    surface.SetDrawColor(colLogoTint)
    surface.SetMaterial(imperialLogo)
    surface.DrawTexturedRectRotated(cx, cy, size, size, rot)
end

--[[---------------------------------------------
    Imperial Cadet Recruitment Assessment (3D2D)
    States: nil/loading/question/results
-----------------------------------------------]]
local quizDataCache = {} -- { [entIdx] = { { question=..., answers={...} }, ... } }

-- Receive quiz data from server (stripped of correct flags)
net.Receive("IMPERIAL_ORDERRecruit_SyncQuiz", function()
    local entIdx = net.ReadUInt(16)
    local len = net.ReadUInt(16)
    local compressed = net.ReadData(len)
    local json = util.Decompress(compressed)
    if json then
        quizDataCache[entIdx] = util.JSONToTable(json) or {}
    end
end)

local function GetQuizQuestions(ent)
    return quizDataCache[ent:EntIndex()] or {}
end

local quizState = {
    active = false,
    phase = "loading",
    loadStart = 0,
    currentQ = 1,
    answers = {},
    resultPassed = false,
    resultScore = 0,
    resultTotal = 0,
    resultCooldown = false,
    editorMode = false, -- High Command quiz editor
}

local function ResetQuiz()
    quizState.active = false
    quizState.phase = "loading"
    quizState.currentQ = 1
    quizState.answers = {}
    quizState.resultPassed = false
    quizState.resultScore = 0
    quizState.resultTotal = 0
    quizState.resultCooldown = false
    quizState.editorMode = false
end

local function StartQuiz()
    ResetQuiz()
    quizState.active = true
    quizState.phase = "loading"
    quizState.loadStart = CurTime()
end

local function StartQuizEditor()
    ResetQuiz()
    quizState.active = true
    quizState.editorMode = true
    quizState.phase = "editor"
end

-- Receive quiz results from server
net.Receive("IMPERIAL_ORDERRecruit_QuizResult", function()
    quizState.resultPassed = net.ReadBool()
    quizState.resultScore = net.ReadUInt(8)
    quizState.resultTotal = net.ReadUInt(8)
    quizState.resultCooldown = net.ReadBool()
    quizState.phase = "results"
end)

local colQuizBtn    = Color(70, 12, 16, 175)
local colQuizBtnHov = Color(125, 18, 24, 220)
local colQuizSel    = Color(170, 22, 28, 205)
local colQuizPass   = Color(30, 180, 80)
local colQuizFail   = Color(200, 50, 40)
local colLoadBar    = Color(190, 25, 30)

local function DrawQuizLoading(ent)
    local elapsed = CurTime() - quizState.loadStart
    local duration = 2.5
    local questions = GetQuizQuestions(ent)

    draw.RoundedBox(0, 0, 0, SW, SH, C.bg)
    DrawImperialLogo(SW * 0.5, SH * 0.35, 100, elapsed * 80, 200)

    draw.SimpleText("IMPERIAL RECRUITMENT", "IMPERIAL_ORDERRecruit_Title", SW * 0.5, SH * 0.55, C.textBrt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText("Initializing assessment...", "IMPERIAL_ORDERRecruit_BootSub", SW * 0.5, SH * 0.62, C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    local progress = math_Clamp(elapsed / duration, 0, 1)
    local barW, barH = 300, 6
    local barX = SW * 0.5 - barW / 2
    local barY = SH * 0.70
    draw.RoundedBox(2, barX, barY, barW, barH, colSeparator)
    draw.RoundedBox(2, barX, barY, barW * progress, barH, colLoadBar)

    surface.SetDrawColor(C.scanline)
    for i = 0, SH, 4 do surface.DrawLine(0, i, SW, i) end

    if elapsed >= duration then
        if #questions == 0 then
            quizState.phase = "comingsoon"
        else
            quizState.phase = "question"
        end
    end
end

-- "Quiz coming soon" screen when no questions exist
local function DrawQuizComingSoon(ent)
    local inSession = IsInSession() and activeTerminal == ent

    draw.RoundedBox(0, 0, 0, SW, SH, C.bg)

    -- Scanlines
    surface.SetDrawColor(C.scanline)
    for i = 0, SH, 4 do surface.DrawLine(0, i, SW, i) end

    -- Large centered text
    draw.SimpleText("Quiz", "IMPERIAL_ORDERRecruit_ComingSoon", SW * 0.5, SH * 0.33, C.textBrt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText("coming soon.", "IMPERIAL_ORDERRecruit_ComingSoon", SW * 0.5, SH * 0.55, C.gold, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- Back button
    local backHover = inSession and InRect(SW * 0.5 - 80, SH * 0.78, 160, 40)
    draw.RoundedBox(3, SW * 0.5 - 80, SH * 0.78, 160, 40, backHover and C.hover or colTransparent)
    surface.SetDrawColor(C.accentDim); surface.DrawOutlinedRect(SW * 0.5 - 80, SH * 0.78, 160, 40, 1)
    draw.SimpleText("< BACK", "IMPERIAL_ORDERRecruit_Header", SW * 0.5, SH * 0.78 + 20, backHover and C.accent or C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    if backHover and mousePressed then ConsumeClick(); ResetQuiz() end
end

local function DrawQuizQuestion(ent)
    local inSession = IsInSession() and activeTerminal == ent
    local questions = GetQuizQuestions(ent)
    local q = questions[quizState.currentQ]
    if not q then quizState.phase = "results"; return end
    local totalQ = #questions

    draw.RoundedBox(0, 0, 0, SW, SH, C.bg)

    -- Header
    draw.RoundedBox(0, 0, 0, SW, 80, C.panel)
    surface.SetDrawColor(C.accent); surface.DrawRect(0, 78, SW, 2)
    draw.SimpleText("IMPERIAL RECRUITMENT", "IMPERIAL_ORDERRecruit_Title", 20, 40, C.textBrt, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText("Question " .. quizState.currentQ .. " / " .. totalQ, "IMPERIAL_ORDERRecruit_Cat", SW - 20, 40, C.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    -- Progress bar
    local progress = (quizState.currentQ - 1) / totalQ
    surface.SetDrawColor(C.accentDim); surface.DrawRect(0, 80, SW, 4)
    surface.SetDrawColor(C.accent); surface.DrawRect(0, 80, SW * progress, 4)

    -- Question text
    draw.SimpleText(q.question, "IMPERIAL_ORDERRecruit_Header", SW * 0.5, 130, C.textBrt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    surface.SetDrawColor(C.accentDim); surface.DrawRect(60, 152, SW - 120, 1)

    -- Answer buttons
    local btnW = SW * 0.7
    local btnH = 55
    local btnX = SW * 0.5 - btnW / 2
    local startY = 180
    local selected = quizState.answers[quizState.currentQ]

    for i, ans in ipairs(q.answers) do
        local y = startY + (i - 1) * (btnH + 12)
        local isSel = (selected == i)
        local hovered = inSession and InRect(btnX, y, btnW, btnH)

        local bg = isSel and colQuizSel or (hovered and colQuizBtnHov or colQuizBtn)
        draw.RoundedBox(4, btnX, y, btnW, btnH, bg)
        surface.SetDrawColor(C.accentDim); surface.DrawOutlinedRect(btnX, y, btnW, btnH, 1)

        if isSel then
            surface.SetDrawColor(C.accent); surface.DrawRect(btnX, y, 4, btnH)
        end

        local letter = string.char(64 + i)
        draw.SimpleText(letter .. ".", "IMPERIAL_ORDERRecruit_Cat", btnX + 20, y + btnH * 0.5, isSel and C.textBrt or C.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(ans, "IMPERIAL_ORDERRecruit_Body", btnX + 50, y + btnH * 0.5, isSel and C.textBrt or C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        if hovered and mousePressed then
            ConsumeClick()
            quizState.answers[quizState.currentQ] = i
        end
    end

    -- Next / Submit button
    if selected then
        local nextY = startY + #q.answers * (btnH + 12) + 20
        local isLast = (quizState.currentQ >= totalQ)
        local nextText = isLast and "SUBMIT ANSWERS" or "NEXT QUESTION"
        local nextW = 200
        local nextX = SW * 0.5 - nextW / 2
        local nextHover = inSession and InRect(nextX, nextY, nextW, 40)

        draw.RoundedBox(4, nextX, nextY, nextW, 40, nextHover and C.accent or colQuizBtn)
        surface.SetDrawColor(C.accentDim); surface.DrawOutlinedRect(nextX, nextY, nextW, 40, 1)
        draw.SimpleText(nextText, "IMPERIAL_ORDERRecruit_Btn", SW * 0.5, nextY + 20, C.textBrt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        if nextHover and mousePressed then
            ConsumeClick()
            if isLast then
                net.Start("IMPERIAL_ORDERRecruit_QuizSubmit")
                    net.WriteUInt(totalQ, 8)
                    for qi = 1, totalQ do
                        net.WriteUInt(quizState.answers[qi] or 0, 8)
                    end
                net.SendToServer()
                quizState.phase = "waiting"
            else
                quizState.currentQ = quizState.currentQ + 1
            end
        end
    end

    surface.SetDrawColor(C.scanline)
    for i = 0, SH, 4 do surface.DrawLine(0, i, SW, i) end
end

local function DrawQuizResults(ent)
    local inSession = IsInSession() and activeTerminal == ent

    draw.RoundedBox(0, 0, 0, SW, SH, C.bg)

    local passed = quizState.resultPassed
    local score = quizState.resultScore
    local total = quizState.resultTotal
    local percent = total > 0 and math.Round((score / total) * 100) or 0

    -- Status icon / header
    local statusCol = passed and colQuizPass or colQuizFail
    local statusText = passed and "TRAINING COMPLETE" or "TRAINING FAILED"

    DrawImperialLogo(SW * 0.5, SH * 0.25, 80, passed and CurTime() * 20 or 0, passed and 220 or 60)

    draw.SimpleText(statusText, "IMPERIAL_ORDERRecruit_Title", SW * 0.5, SH * 0.42, statusCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- Stats
    draw.SimpleText("Score: " .. score .. " / " .. total .. "  (" .. percent .. "%)", "IMPERIAL_ORDERRecruit_Header", SW * 0.5, SH * 0.52, C.textBrt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText("Required: 70%", "IMPERIAL_ORDERRecruit_Body", SW * 0.5, SH * 0.58, C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    if passed then
        draw.SimpleText("Assessment passed. Imperial service assignment processed.", "IMPERIAL_ORDERRecruit_Cat", SW * 0.5, SH * 0.66, colQuizPass, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    else
        local cooldownText = quizState.resultCooldown and "Please wait for cooldown." or "You may retry in 5 minutes."
        draw.SimpleText(cooldownText, "IMPERIAL_ORDERRecruit_Cat", SW * 0.5, SH * 0.66, C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Return button
    local btnW, btnH = 260, 44
    local btnX = SW * 0.5 - btnW / 2
    local btnY = SH * 0.76
    local hovered = inSession and InRect(btnX, btnY, btnW, btnH)

    draw.RoundedBox(4, btnX, btnY, btnW, btnH, hovered and C.accent or colQuizBtn)
    surface.SetDrawColor(C.accentDim); surface.DrawOutlinedRect(btnX, btnY, btnW, btnH, 1)
    draw.SimpleText("RETURN TO RECRUITMENT", "IMPERIAL_ORDERRecruit_Btn", SW * 0.5, btnY + btnH * 0.5, C.textBrt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    if hovered and mousePressed then
        ConsumeClick()
        ResetQuiz()
    end

    surface.SetDrawColor(C.scanline)
    for i = 0, SH, 4 do surface.DrawLine(0, i, SW, i) end
end

local colWaitingText = Color(0, 0, 0)

local function DrawQuizWaiting()
    draw.RoundedBox(0, 0, 0, SW, SH, C.bg)
    local pulse = 0.5 + 0.5 * math_sin(CurTime() * 3)
    colWaitingText.r = C.accent.r; colWaitingText.g = C.accent.g; colWaitingText.b = C.accent.b
    colWaitingText.a = 150 + 105 * pulse
    draw.SimpleText("Processing results...", "IMPERIAL_ORDERRecruit_Boot", SW * 0.5, SH * 0.5, colWaitingText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    surface.SetDrawColor(C.scanline)
    for i = 0, SH, 4 do surface.DrawLine(0, i, SW, i) end
end

-- DFrame popup for adding a quiz question
local function OpenAddQuestionDialog()
    local frame = vgui.Create("DFrame")
    frame:SetSize(440, 320); frame:Center(); frame:SetTitle("Add Quiz Question"); frame:MakePopup()

    local extraAnswers = {} -- { {entry=DTextEntry, isCorrect=bool}, ... }
    local yOff = 30

    -- Question text
    local qEntry = vgui.Create("DTextEntry", frame)
    qEntry:SetPos(10, yOff); qEntry:SetSize(420, 24); qEntry:SetPlaceholderText("Question text...")
    yOff = yOff + 32

    -- Correct answer
    local lbl1 = vgui.Create("DLabel", frame)
    lbl1:SetPos(10, yOff); lbl1:SetSize(420, 16); lbl1:SetText("Correct answer:"); lbl1:SetTextColor(Color(100, 220, 100))
    yOff = yOff + 18
    local correctEntry = vgui.Create("DTextEntry", frame)
    correctEntry:SetPos(10, yOff); correctEntry:SetSize(420, 24); correctEntry:SetPlaceholderText("Correct answer...")
    yOff = yOff + 32

    -- Wrong answer (default)
    local lbl2 = vgui.Create("DLabel", frame)
    lbl2:SetPos(10, yOff); lbl2:SetSize(420, 16); lbl2:SetText("Wrong answer:"); lbl2:SetTextColor(Color(220, 100, 100))
    yOff = yOff + 18
    local wrongEntry = vgui.Create("DTextEntry", frame)
    wrongEntry:SetPos(10, yOff); wrongEntry:SetSize(420, 24); wrongEntry:SetPlaceholderText("Wrong answer...")
    yOff = yOff + 32

    -- Scrollable area for additional answers
    local extraPanel = vgui.Create("DScrollPanel", frame)
    extraPanel:SetPos(10, yOff); extraPanel:SetSize(420, 80)

    local function AddExtraAnswer()
        if #extraAnswers >= 6 then return end

        local row = vgui.Create("DPanel", extraPanel)
        row:SetTall(30); row:Dock(TOP); row:DockMargin(0, 2, 0, 0)
        row.Paint = function() end

        local toggle = vgui.Create("DButton", row)
        toggle:SetPos(0, 3); toggle:SetSize(70, 24)
        local isCorrect = false
        toggle:SetText("WRONG")
        toggle:SetTextColor(Color(220, 100, 100))
        toggle.DoClick = function()
            isCorrect = not isCorrect
            if isCorrect then
                toggle:SetText("RIGHT")
                toggle:SetTextColor(Color(100, 220, 100))
            else
                toggle:SetText("WRONG")
                toggle:SetTextColor(Color(220, 100, 100))
            end
        end

        local entry = vgui.Create("DTextEntry", row)
        entry:SetPos(76, 3); entry:SetSize(344, 24)
        entry:SetPlaceholderText("Additional answer " .. (#extraAnswers + 1) .. "...")

        table.insert(extraAnswers, {entry = entry, getCorrect = function() return isCorrect end})
    end

    yOff = yOff + 85

    -- Add Additional Answer button
    local submitBtn -- forward declare for closure
    local addAnsBtn = vgui.Create("DButton", frame)
    addAnsBtn:SetPos(10, yOff); addAnsBtn:SetSize(420, 24); addAnsBtn:SetText("+ ADD ADDITIONAL ANSWER")
    addAnsBtn.DoClick = function()
        AddExtraAnswer()
        local newH = math.min(320 + #extraAnswers * 34, 500)
        frame:SetTall(newH)
        extraPanel:SetTall(80 + #extraAnswers * 34)
        -- Reposition buttons
        addAnsBtn:SetPos(10, newH - 64)
        if IsValid(submitBtn) then submitBtn:SetPos(10, newH - 36) end
    end
    yOff = yOff + 28

    -- Submit button
    submitBtn = vgui.Create("DButton", frame)
    submitBtn:SetPos(10, yOff); submitBtn:SetSize(420, 32); submitBtn:SetText("ADD QUESTION")
    submitBtn.DoClick = function()
        local q = string.Trim(qEntry:GetValue())
        local c = string.Trim(correctEntry:GetValue())
        local w = string.Trim(wrongEntry:GetValue())
        if #q < 5 or #c < 1 or #w < 1 then return end

        -- Collect all answers: correct first, then wrong, then extras
        local allCorrect = {c}
        local allWrong = {w}
        for _, extra in ipairs(extraAnswers) do
            local txt = string.Trim(extra.entry:GetValue())
            if #txt >= 1 then
                if extra.getCorrect() then
                    table.insert(allCorrect, txt)
                else
                    table.insert(allWrong, txt)
                end
            end
        end

        net.Start("IMPERIAL_ORDERRecruit_QuizAddQ")
            net.WriteString(q)
            net.WriteUInt(#allCorrect, 4)
            for _, a in ipairs(allCorrect) do net.WriteString(a) end
            net.WriteUInt(#allWrong, 4)
            for _, a in ipairs(allWrong) do net.WriteString(a) end
        net.SendToServer()
        frame:Remove()
    end
end

-- Quiz editor screen (High Command only)
local colEditorRow   = Color(12, 20, 36, 200)
local colEditorRowH  = Color(20, 30, 50, 200)
local colRemoveBtn   = Color(140, 30, 30, 200)
local colRemoveBtnH  = Color(200, 50, 40, 255)

local editorScroll = 0

local function DrawQuizEditor(ent)
    local inSession = IsInSession() and activeTerminal == ent
    local questions = GetQuizQuestions(ent)

    draw.RoundedBox(0, 0, 0, SW, SH, C.bg)

    -- Header
    draw.RoundedBox(0, 0, 0, SW, 80, C.panel)
    surface.SetDrawColor(C.accent); surface.DrawRect(0, 78, SW, 2)
    draw.SimpleText("QUIZ EDITOR", "IMPERIAL_ORDERRecruit_Title", 20, 40, C.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(#questions .. " questions", "IMPERIAL_ORDERRecruit_Cat", SW - 20, 40, C.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    -- Back button
    local backHover = inSession and InRect(20, 92, 100, 30)
    draw.RoundedBox(3, 20, 92, 100, 30, backHover and C.hover or colTransparent)
    surface.SetDrawColor(C.accentDim); surface.DrawOutlinedRect(20, 92, 100, 30, 1)
    draw.SimpleText("< BACK", "IMPERIAL_ORDERRecruit_Btn", 70, 107, backHover and C.accent or C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    if backHover and mousePressed then ConsumeClick(); ResetQuiz() end

    -- Add question button
    local addX = SW - 200
    local addHover = inSession and InRect(addX, 92, 180, 30)
    draw.RoundedBox(3, addX, 92, 180, 30, addHover and C.accent or colQuizBtn)
    surface.SetDrawColor(C.accentDim); surface.DrawOutlinedRect(addX, 92, 180, 30, 1)
    draw.SimpleText("+ ADD QUESTION", "IMPERIAL_ORDERRecruit_Btn", addX + 90, 107, C.textBrt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    if addHover and mousePressed then ConsumeClick(); OpenAddQuestionDialog() end

    -- Required score info
    draw.SimpleText("Pass: 70%  |  Correct answer is always the first option sent", "IMPERIAL_ORDERRecruit_Small", SW * 0.5, 140, C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- Question list
    local listY = 160
    local rowH = 70
    local listH = SH - listY - 20

    if #questions == 0 then
        draw.SimpleText("No questions configured.", "IMPERIAL_ORDERRecruit_Header", SW * 0.5, SH * 0.5, C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Add questions to enable the training quiz.", "IMPERIAL_ORDERRecruit_Body", SW * 0.5, SH * 0.56, C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    else
        for i, q in ipairs(questions) do
            local y = listY + (i - 1) * (rowH + 6) - editorScroll
            if y > SH - 10 then break end
            if y + rowH < listY then continue end

            local rowHover = inSession and InRect(30, y, SW - 60, rowH)
            draw.RoundedBox(4, 30, y, SW - 60, rowH, rowHover and colEditorRowH or colEditorRow)
            surface.SetDrawColor(C.accentDim); surface.DrawOutlinedRect(30, y, SW - 60, rowH, 1)

            -- Question number
            draw.SimpleText("#" .. i, "IMPERIAL_ORDERRecruit_Cat", 50, y + 16, C.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            -- Question text (truncated)
            local qText = #q.question > 70 and string.sub(q.question, 1, 67) .. "..." or q.question
            draw.SimpleText(qText, "IMPERIAL_ORDERRecruit_Body", 90, y + 16, C.textBrt, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            -- Answers preview
            local ansPreview = table.concat(q.answers, "  |  ")
            if #ansPreview > 80 then ansPreview = string.sub(ansPreview, 1, 77) .. "..." end
            draw.SimpleText(ansPreview, "IMPERIAL_ORDERRecruit_Small", 90, y + 38, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            -- Answer count
            draw.SimpleText(#q.answers .. " answers", "IMPERIAL_ORDERRecruit_Small", 90, y + 54, C.accentDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            -- Remove button
            local rmX = SW - 130
            local rmHover = inSession and InRect(rmX, y + 18, 70, 30)
            draw.RoundedBox(3, rmX, y + 18, 70, 30, rmHover and colRemoveBtnH or colRemoveBtn)
            draw.SimpleText("REMOVE", "IMPERIAL_ORDERRecruit_Small", rmX + 35, y + 33, C.textBrt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            if rmHover and mousePressed then
                ConsumeClick()
                net.Start("IMPERIAL_ORDERRecruit_QuizRemoveQ")
                    net.WriteUInt(i, 8)
                net.SendToServer()
            end
        end
    end

    -- Scanlines
    surface.SetDrawColor(C.scanline)
    for i = 0, SH, 4 do surface.DrawLine(0, i, SW, i) end

    surface.SetDrawColor(C.accent); surface.DrawRect(0, SH - 2, SW, 2)
end

--[[---------------------------------------------
    Standby Screen (3D2D)
    Spinning logo + "Press E to boot"
-----------------------------------------------]]
local colStandbyText = Color(0, 0, 0)
local colStandbyPrompt = Color(0, 0, 0)

local function DrawStandbyScreen()
    draw.RoundedBox(0, 0, 0, SW, SH, C.bg)

    -- Slow spinning logo
    DrawImperialLogo(SW * 0.5, SH * 0.4, 150, CurTime() * 10, 160)

    -- Subtle glow behind logo
    colBootGlow.r = 175; colBootGlow.g = 15; colBootGlow.b = 22; colBootGlow.a = 20
    draw.RoundedBox(100, SW * 0.5 - 170, SH * 0.4 - 170, 340, 340, colBootGlow)

    -- "Press E to boot" with gentle pulse
    local pulse = 0.5 + 0.5 * math_sin(CurTime() * 2)
    colStandbyPrompt.r = C.accent.r; colStandbyPrompt.g = C.accent.g; colStandbyPrompt.b = C.accent.b
    colStandbyPrompt.a = 120 + 100 * pulse
    draw.SimpleText("Press  [ E ]  to boot", "IMPERIAL_ORDERRecruit_Standby", SW * 0.5, SH * 0.68, colStandbyPrompt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- "IMPERIAL RECRUITMENT" dim label
    colStandbyText.r = C.textDim.r; colStandbyText.g = C.textDim.g; colStandbyText.b = C.textDim.b; colStandbyText.a = 100
    draw.SimpleText("IMPERIAL RECRUITMENT", "IMPERIAL_ORDERRecruit_StandbySub", SW * 0.5, SH * 0.76, colStandbyText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- Scanlines
    surface.SetDrawColor(C.scanline)
    for i = 0, SH, 4 do surface.DrawLine(0, i, SW, i) end
end

--[[---------------------------------------------
    Boot Sequence (3D2D)
-----------------------------------------------]]
local function DrawBootSequence(elapsed)
    local phase = elapsed / BOOT_DURATION
    draw.RoundedBox(0, 0, 0, SW, SH, C.bg)

    if phase < 0.6 then
        local logoAlpha = math_min(phase / 0.15, 1) * 255
        DrawImperialLogo(SW * 0.5, SH * 0.42, 120, elapsed * 60, logoAlpha)
        colBootGlow.r = 175; colBootGlow.g = 15; colBootGlow.b = 22; colBootGlow.a = logoAlpha * 0.12
        draw.RoundedBox(100, SW * 0.5 - 140, SH * 0.42 - 140, 280, 280, colBootGlow)
    end

    if phase > 0.2 and phase < 0.85 then
        local textAlpha = math_Clamp((phase - 0.2) / 0.15, 0, 1) * 255
        colBootText.r = C.textBrt.r; colBootText.g = C.textBrt.g; colBootText.b = C.textBrt.b; colBootText.a = textAlpha
        colBootSub.r = C.accent.r; colBootSub.g = C.accent.g; colBootSub.b = C.accent.b; colBootSub.a = textAlpha * 0.7
        draw.SimpleText("GALACTIC EMPIRE", "IMPERIAL_ORDERRecruit_Boot", SW * 0.5, SH * 0.68, colBootText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("RECRUITMENT TERMINAL", "IMPERIAL_ORDERRecruit_BootSub", SW * 0.5, SH * 0.73, colBootSub, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    if phase > 0.35 then
        local barProgress = math_Clamp((phase - 0.35) / 0.55, 0, 1)
        local barW, barH = 400, 6
        local barX, barY = SW * 0.5 - barW / 2, SH * 0.80
        draw.RoundedBox(2, barX, barY, barW, barH, colSeparator)
        draw.RoundedBox(2, barX, barY, barW * barProgress, barH, C.accent)
    end

    surface.SetDrawColor(C.scanline)
    for i = 0, SH, 4 do surface.DrawLine(0, i, SW, i) end
end

--[[---------------------------------------------
    Main Interface (3D2D)
-----------------------------------------------]]
local function DrawMainInterface(ent)
    local state = GetState(ent)
    local data = GetCachedData(ent)
    local inSession = IsInSession() and activeTerminal == ent

    -- Bounds safety
    local cat = data[state.selectedCat]
    if not cat then state.selectedCat = 1; state.selectedEntry = 0; cat = data[1] end
    if state.selectedEntry > 0 and cat and not cat.entries[state.selectedEntry] then state.selectedEntry = 0 end

    -- Background
    draw.RoundedBox(0, 0, 0, SW, SH, C.bg)

    -- Title bar
    draw.RoundedBox(0, 0, 0, SW, 80, C.panel)
    surface.SetDrawColor(C.accent); surface.DrawRect(0, 78, SW, 2)
    DrawImperialLogo(50, 40, 25, CurTime() * 15, 200)
    draw.SimpleText("IMPERIAL RECRUITMENT", "IMPERIAL_ORDERRecruit_Title", 90, 40, C.textBrt, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(os.date("%H:%M:%S"), "IMPERIAL_ORDERRecruit_Small", SW - 20, 40, C.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    -- Gear icon (Officer+ only) — opens settings panel
    if inSession and IsOfficerPlus() then
        local gearX, gearY, gearS = SW - 90, 25, 30
        local gearHover = InRect(gearX, gearY, gearS, gearS)
        local gearCol = gearHover and C.gold or C.textDim
        -- Draw simple gear shape (⚙)
        draw.SimpleText(utf8.char(0x2699), "IMPERIAL_ORDERRecruit_Title", gearX + gearS/2, gearY + gearS/2, gearCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        if gearHover and mousePressed then ConsumeClick(); OpenSettingsPanel() end
    end

    -- Sidebar
    local sideW = 260
    draw.RoundedBox(0, 0, 82, sideW, SH - 82, colSidebarBg)
    surface.SetDrawColor(C.accentDim); surface.DrawRect(sideW, 82, 1, SH - 82)
    draw.SimpleText("CATEGORIES", "IMPERIAL_ORDERRecruit_CatSmall", 20, 100, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    local catY = 120
    for i, catData in ipairs(data) do
        local isSelected = (state.selectedCat == i)
        local hovered = inSession and InRect(0, catY, sideW, 50)

        if isSelected then
            draw.RoundedBox(0, 0, catY, sideW, 50, C.selected)
            surface.SetDrawColor(C.accent); surface.DrawRect(0, catY, 3, 50)
        elseif hovered then
            draw.RoundedBox(0, 0, catY, sideW, 50, C.hover)
        end

        local iconCol = C.textDim
        if catData.icon == "rank" then iconCol = C.gold
        elseif catData.icon == "jammer" then iconCol = C.red
        elseif catData.icon == "comms" then iconCol = C.accent
        elseif catData.icon == "custom" then iconCol = C.green end

        draw.RoundedBox(3, 16, catY + 17, 10, 16, iconCol)
        draw.SimpleText(string.upper(catData.name), "IMPERIAL_ORDERRecruit_Cat", 38, catY + 25, isSelected and C.textBrt or C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(#catData.entries .. " entries", "IMPERIAL_ORDERRecruit_Small", sideW - 14, catY + 25, C.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

        if hovered and mousePressed then ConsumeClick(); ResetQuiz(); state.selectedCat = i; state.selectedEntry = 0 end

        catY = catY + 52
    end

    -- Add Category (Officer+, in session only)
    if inSession and IsOfficerPlus() then
        local addHover = InRect(10, catY + 8, sideW - 20, 32)
        draw.RoundedBox(3, 10, catY + 8, sideW - 20, 32, addHover and C.hover or colTransparent)
        surface.SetDrawColor(C.accentDim); surface.DrawOutlinedRect(10, catY + 8, sideW - 20, 32, 1)
        draw.SimpleText("+ ADD CATEGORY", "IMPERIAL_ORDERRecruit_Btn", sideW * 0.5, catY + 24, addHover and C.accent or C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        if addHover and mousePressed then ConsumeClick(); OpenAddCategoryDialog() end
        catY = catY + 44
    end

    -- Separator line before training tab
    catY = catY + 12
    surface.SetDrawColor(C.accentDim); surface.DrawRect(16, catY, sideW - 32, 1)
    catY = catY + 12

    -- TRAINING QUIZ tab
    local quizSelected = quizState.active
    local quizHover = inSession and InRect(0, catY, sideW, 50)

    if quizSelected then
        draw.RoundedBox(0, 0, catY, sideW, 50, C.selected)
        surface.SetDrawColor(C.gold); surface.DrawRect(0, catY, 3, 50)
    elseif quizHover then
        draw.RoundedBox(0, 0, catY, sideW, 50, C.hover)
    end

    draw.RoundedBox(3, 16, catY + 17, 10, 16, C.gold)
    draw.SimpleText("TRAINING QUIZ", "IMPERIAL_ORDERRecruit_Cat", 38, catY + 25, quizSelected and C.gold or C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText("cadet", "IMPERIAL_ORDERRecruit_Small", sideW - 14, catY + 25, C.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    if quizHover and mousePressed then ConsumeClick(); StartQuiz() end

    catY = catY + 52

    -- EDIT QUIZ button (High Command only)
    if inSession and IsHighCommand() then
        local editHover = InRect(10, catY, sideW - 20, 32)
        draw.RoundedBox(3, 10, catY, sideW - 20, 32, editHover and C.hover or colTransparent)
        surface.SetDrawColor(C.gold); surface.DrawOutlinedRect(10, catY, sideW - 20, 32, 1)
        draw.SimpleText("EDIT QUIZ", "IMPERIAL_ORDERRecruit_Btn", sideW * 0.5, catY + 16, editHover and C.gold or C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        if editHover and mousePressed then ConsumeClick(); StartQuizEditor() end
    end

    -- Content area
    local contentX = sideW + 20
    local contentW = SW - sideW - 40

    -- If quiz is active, render quiz instead of category content
    if quizState.active then
        -- Quiz handled by DrawTranslucent switching — draw nothing here
        -- The main interface content is replaced by quiz screens
    elseif not cat then
        draw.SimpleText("No data available", "IMPERIAL_ORDERRecruit_Header", SW * 0.65, SH * 0.5, C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    else
        draw.SimpleText(string.upper(cat.name), "IMPERIAL_ORDERRecruit_Header", contentX, 100, C.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(C.accentDim); surface.DrawRect(contentX, 116, contentW, 1)

        local entryY = 130

        if state.selectedEntry == 0 then
            RemovePreviewModel()
            for i, entry in ipairs(cat.entries) do
                local ey = entryY + (i - 1) * 68
                if ey > SH - 40 then break end

                local hovered = inSession and InRect(contentX, ey, contentW, 60)
                if hovered then draw.RoundedBox(3, contentX, ey, contentW, 60, C.hover) end

                draw.SimpleText(entry.title, "IMPERIAL_ORDERRecruit_Cat", contentX + 12, ey + 18, C.textBrt, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                local preview = string.sub(string.gsub(entry.body, "\n", " "), 1, 80)
                if #entry.body > 80 then preview = preview .. "..." end
                draw.SimpleText(preview, "IMPERIAL_ORDERRecruit_Small", contentX + 12, ey + 40, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                if entry.model then
                    draw.SimpleText("[3D MODEL]", "IMPERIAL_ORDERRecruit_Small", contentX + contentW - 12, ey + 18, C.orange, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end

                -- Delete entry button
                local canDelEntry = inSession and IsOfficerPlus()

                if canDelEntry then
                    local delEX = contentX + contentW - 14
                    local delEHover = InRect(delEX - 20, ey + 30, 30, 20)
                    draw.SimpleText("DEL", "IMPERIAL_ORDERRecruit_Small", delEX, ey + 42, delEHover and colDelText or colDelTextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                    if delEHover and mousePressed then
                        ConsumeClick()
                        local entName = entry.title
                        local catI = state.selectedCat
                        local entI = i
                        ConfirmDelete(entName, function()
                            net.Start("IMPERIAL_ORDERRecruit_DeleteEntry"); net.WriteUInt(catI, 8); net.WriteUInt(entI, 8); net.SendToServer()
                        end)
                    end
                end

                if hovered and mousePressed then ConsumeClick(); state.selectedEntry = i end

                surface.SetDrawColor(colSeparator); surface.DrawRect(contentX, ey + 62, contentW, 1)
            end

            if #cat.entries == 0 then
                draw.SimpleText("No entries in this category.", "IMPERIAL_ORDERRecruit_Body", contentX + contentW * 0.5, SH * 0.45, C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            if inSession and IsOfficerPlus() then
                local addY = entryY + #cat.entries * 68 + 10
                if addY < SH - 60 then
                    local addHover = InRect(contentX, addY, 180, 30)
                    draw.RoundedBox(3, contentX, addY, 180, 30, addHover and C.hover or colTransparent)
                    surface.SetDrawColor(C.accentDim); surface.DrawOutlinedRect(contentX, addY, 180, 30, 1)
                    draw.SimpleText("+ ADD ENTRY", "IMPERIAL_ORDERRecruit_Btn", contentX + 90, addY + 15, addHover and C.accent or C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    if addHover and mousePressed then ConsumeClick(); OpenAddEntryDialog(state.selectedCat) end

                    -- DELETE CATEGORY button
                    local canDelCat = false
                    if IsHighCommand() then canDelCat = true
                    elseif cat.icon == "custom" then canDelCat = true end

                    if canDelCat then
                        local delCatX = contentX + 200
                        local delCatHover = InRect(delCatX, addY, 180, 30)
                        draw.RoundedBox(3, delCatX, addY, 180, 30, delCatHover and colDelCatBgH or colDelCatBg)
                        surface.SetDrawColor(colDelCatBdr); surface.DrawOutlinedRect(delCatX, addY, 180, 30, 1)
                        draw.SimpleText("DELETE CATEGORY", "IMPERIAL_ORDERRecruit_Btn", delCatX + 90, addY + 15, delCatHover and colDelCatTxtH or colDelCatTxt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                        if delCatHover and mousePressed then
                            ConsumeClick()
                            local catName = cat.name
                            local catI = state.selectedCat
                            ConfirmDelete(catName, function()
                                net.Start("IMPERIAL_ORDERRecruit_DeleteCategory"); net.WriteUInt(catI, 8); net.SendToServer()
                                state.selectedCat = 1; state.selectedEntry = 0
                            end)
                        end
                    end
                end
            end
        else
            local entry = cat.entries[state.selectedEntry]
            if entry then
                local backHover = inSession and InRect(contentX, entryY, 120, 30)
                draw.RoundedBox(3, contentX, entryY, 120, 30, backHover and C.hover or colTransparent)
                surface.SetDrawColor(C.accentDim); surface.DrawOutlinedRect(contentX, entryY, 120, 30, 1)
                draw.SimpleText("< BACK", "IMPERIAL_ORDERRecruit_Btn", contentX + 60, entryY + 15, backHover and C.accent or C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                if backHover and mousePressed then ConsumeClick(); state.selectedEntry = 0 end

                -- DELETE ENTRY button (Officers: custom cats, High Command: all)
                local canDelThis = inSession and IsOfficerPlus()

                if canDelThis then
                    local delBtnX = contentX + 140
                    local delBtnHover = inSession and InRect(delBtnX, entryY, 140, 30)
                    draw.RoundedBox(3, delBtnX, entryY, 140, 30, delBtnHover and colDelEntBgH or colDelEntBg)
                    surface.SetDrawColor(colDelEntBdr); surface.DrawOutlinedRect(delBtnX, entryY, 140, 30, 1)
                    draw.SimpleText("DELETE ENTRY", "IMPERIAL_ORDERRecruit_Btn", delBtnX + 70, entryY + 15, delBtnHover and colDelCatTxtH or colDelEntTxt, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    if delBtnHover and mousePressed then
                        ConsumeClick()
                        local entName = entry.title
                        local catI = state.selectedCat
                        local entI = state.selectedEntry
                        ConfirmDelete(entName, function()
                            net.Start("IMPERIAL_ORDERRecruit_DeleteEntry"); net.WriteUInt(catI, 8); net.WriteUInt(entI, 8); net.SendToServer()
                            state.selectedEntry = 0
                        end)
                    end
                end

                entryY = entryY + 50
                draw.SimpleText(entry.title, "IMPERIAL_ORDERRecruit_Header", contentX, entryY, C.textBrt, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                entryY = entryY + 35

                if entry.model then
                    -- Model preview box
                    draw.RoundedBox(3, contentX, entryY, 200, 200, colModelBg)
                    surface.SetDrawColor(C.accentDim); surface.DrawOutlinedRect(contentX, entryY, 200, 200, 1)
                    local mdlName = string.GetFileFromFilename(entry.model)
                    draw.SimpleText(mdlName, "IMPERIAL_ORDERRecruit_Small", contentX + 100, entryY + 185, C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

                    UpdatePreviewModel(entry.model)

                    local bodyX = contentX + 220
                    local lines = string.Split(entry.body, "\n")
                    for li, line in ipairs(lines) do
                        draw.SimpleText(line, "IMPERIAL_ORDERRecruit_Body", bodyX, entryY + (li - 1) * 22, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    end
                else
                    RemovePreviewModel()
                    local lines = string.Split(entry.body, "\n")
                    for li, line in ipairs(lines) do
                        draw.SimpleText(line, "IMPERIAL_ORDERRecruit_Body", contentX, entryY + (li - 1) * 22, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    end
                end
            end
        end
    end

    -- "Press E to close" prompt (bottom-right, only when in session)
    if inSession then
        draw.SimpleText("Press  [ E ]  to close", "IMPERIAL_ORDERRecruit_Prompt", SW - 30, SH - 30, C.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    -- Scanlines
    surface.SetDrawColor(C.scanline)
    for i = 0, SH, 4 do surface.DrawLine(0, i, SW, i) end

    surface.SetDrawColor(C.accent); surface.DrawRect(0, SH - 2, SW, 2)
end

--[[---------------------------------------------
    3D2D Rendering (always on entity)

    imp_console_medium03 has a square front display. The 1000 x 1000 canvas
    below is centered on that display and its click bounds use the same square.
-----------------------------------------------]]
-- Screen position for models/lordtrilobite/starwars/isd/imp_console_medium03.mdl
CreateClientConVar("imperial_order_recruit_scr_x",     "-16.1", true, false, "Screen X")
CreateClientConVar("imperial_order_recruit_scr_y",     "-15.6", true, false, "Screen Y")
CreateClientConVar("imperial_order_recruit_scr_z",     "36.0",  true, false, "Screen Z")
CreateClientConVar("imperial_order_recruit_scr_pitch", "0",     true, false, "Screen pitch")
CreateClientConVar("imperial_order_recruit_scr_yaw",   "90",    true, false, "Screen yaw")
CreateClientConVar("imperial_order_recruit_scr_roll",  "90",    true, false, "Screen roll")
CreateClientConVar("imperial_order_recruit_scr_scale", "32",    true, false, "Screen scale divisor")

local cv_scr_x     = GetConVar("imperial_order_recruit_scr_x")
local cv_scr_y     = GetConVar("imperial_order_recruit_scr_y")
local cv_scr_z     = GetConVar("imperial_order_recruit_scr_z")
local cv_scr_pitch = GetConVar("imperial_order_recruit_scr_pitch")
local cv_scr_yaw   = GetConVar("imperial_order_recruit_scr_yaw")
local cv_scr_roll  = GetConVar("imperial_order_recruit_scr_roll")
local cv_scr_scale = GetConVar("imperial_order_recruit_scr_scale")

local function GetScreenPos() return Vector(cv_scr_x:GetFloat(), cv_scr_y:GetFloat(), cv_scr_z:GetFloat()) end
local function GetScreenAng() return Angle(cv_scr_pitch:GetFloat(), cv_scr_yaw:GetFloat(), cv_scr_roll:GetFloat()) end
local function GetScreenScale() return 1 / math.max(cv_scr_scale:GetFloat(), 10) end

-- Camera centered on the square display.
CreateClientConVar("imperial_order_recruit_cam_x",        "-78",   true, false, "Camera X")
CreateClientConVar("imperial_order_recruit_cam_y",        "0",     true, false, "Camera Y")
CreateClientConVar("imperial_order_recruit_cam_z",        "51.6",  true, false, "Camera Z")
CreateClientConVar("imperial_order_recruit_cam_target_x", "-16.1", true, false, "Camera target X")
CreateClientConVar("imperial_order_recruit_cam_target_y", "0",     true, false, "Camera target Y")
CreateClientConVar("imperial_order_recruit_cam_target_z", "51.6",  true, false, "Camera target Z")
CreateClientConVar("imperial_order_recruit_cam_fov",      "45",    true, false, "Camera FOV")

local cv_cam_x   = GetConVar("imperial_order_recruit_cam_x")
local cv_cam_y   = GetConVar("imperial_order_recruit_cam_y")
local cv_cam_z   = GetConVar("imperial_order_recruit_cam_z")
local cv_cam_tx  = GetConVar("imperial_order_recruit_cam_target_x")
local cv_cam_ty  = GetConVar("imperial_order_recruit_cam_target_y")
local cv_cam_tz  = GetConVar("imperial_order_recruit_cam_target_z")
local cv_cam_fov = GetConVar("imperial_order_recruit_cam_fov")

-- Migrate every saved client layout value. Merely changing the ConVar defaults
-- does not replace values archived by an older addon build.
local cv_layout_version = CreateClientConVar("imperial_order_recruit_layout_version", "0", true, false, "Recruitment terminal layout version")

local LAYOUT_VERSION = 4

local function ApplyMediumConsoleView()
    RunConsoleCommand("imperial_order_recruit_scr_x", "-16.1")
    RunConsoleCommand("imperial_order_recruit_scr_y", "-15.6")
    RunConsoleCommand("imperial_order_recruit_scr_z", "36.0")
    RunConsoleCommand("imperial_order_recruit_scr_pitch", "0")
    RunConsoleCommand("imperial_order_recruit_scr_yaw", "90")
    RunConsoleCommand("imperial_order_recruit_scr_roll", "90")
    RunConsoleCommand("imperial_order_recruit_scr_scale", "32")

    RunConsoleCommand("imperial_order_recruit_cam_x", "-78")
    RunConsoleCommand("imperial_order_recruit_cam_y", "0")
    RunConsoleCommand("imperial_order_recruit_cam_z", "51.6")
    RunConsoleCommand("imperial_order_recruit_cam_target_x", "-16.1")
    RunConsoleCommand("imperial_order_recruit_cam_target_y", "0")
    RunConsoleCommand("imperial_order_recruit_cam_target_z", "51.6")
    RunConsoleCommand("imperial_order_recruit_cam_fov", "45")
    RunConsoleCommand("imperial_order_recruit_layout_version", tostring(LAYOUT_VERSION))
end

timer.Simple(0, function()
    if not cv_layout_version or cv_layout_version:GetInt() < LAYOUT_VERSION then
        ApplyMediumConsoleView()
    end
end)

concommand.Add("imperial_order_recruit_reset_view", ApplyMediumConsoleView)

local function GetCamPos() return Vector(cv_cam_x:GetFloat(), cv_cam_y:GetFloat(), cv_cam_z:GetFloat()) end
local function GetCamTarget() return Vector(cv_cam_tx:GetFloat(), cv_cam_ty:GetFloat(), cv_cam_tz:GetFloat()) end

function ENT:Draw()
    self:DrawModel()
end

function ENT:DrawTranslucent()
    if not self:GetPowered() then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if self:GetPos():DistToSqr(ply:GetPos()) > 1000000 then return end

    -- 3D2D placement (adjustable via imperial_order_recruit_scr_* ConVars)
    local terminalScale = GetTerminalDisplayScale(self)
    local pos = self:LocalToWorld(GetScreenPos() * terminalScale)
    local ang = self:LocalToWorldAngles(GetScreenAng())

    -- Calculate cursor from eye trace → 3D2D plane intersection
    -- In session: trace from camera through mouse cursor on screen
    -- Out of session: trace from player's eye
    local eyePos, eyeNorm
    if IsInSession() and activeTerminal == self then
        eyePos = camOrigin
        local mx, my = gui.MousePos()
        eyeNorm = gui.ScreenToVector(mx, my)
    else
        eyePos = ply:EyePos()
        eyeNorm = ply:GetAimVector()
    end
    local screenNorm = ang:Up()
    local denom = screenNorm:Dot(eyeNorm)
    local scale = GetScreenScale() * terminalScale

    cursorX, cursorY = -1, -1
    if math_max(denom, -denom) > 0.001 then
        local t = screenNorm:Dot(pos - eyePos) / denom
        if t > 0 then
            local hitPos = eyePos + eyeNorm * t
            local localHit = WorldToLocal(hitPos, Angle(0, 0, 0), pos, ang)
            local hitX = localHit.x / scale
            local hitY = -localHit.y / scale

            -- Ignore intersections outside the actual terminal display. This
            -- prevents invisible buttons from being activated beside the model.
            if hitX >= 0 and hitX <= SW and hitY >= 0 and hitY <= SH then
                cursorX = hitX
                cursorY = hitY
            end
        end
    end

    cam.Start3D2D(pos, ang, scale)
        local state = self:GetTermState()

        if state == 0 then
            DrawStandbyScreen()
        elseif state == 1 then
            local elapsed = CurTime() - self:GetBootTime()
            DrawBootSequence(elapsed)
        elseif quizState.active and quizState.phase == "loading" then
            DrawQuizLoading(self)
        elseif quizState.active and quizState.phase == "question" then
            DrawQuizQuestion(self)
        elseif quizState.active and quizState.phase == "waiting" then
            DrawQuizWaiting()
        elseif quizState.active and quizState.phase == "results" then
            DrawQuizResults(self)
        elseif quizState.active and quizState.phase == "editor" then
            DrawQuizEditor(self)
        elseif quizState.active and quizState.phase == "comingsoon" then
            DrawQuizComingSoon(self)
        else
            DrawMainInterface(self)
        end
    cam.End3D2D()

    -- Render 3D model preview in front of the preview box
    if IsValid(previewModel) then
        previewSpin = previewSpin + FrameTime() * 30

        -- Auto-scale from ConVar
        local mins, maxs = previewModel:GetModelBounds()
        local modelSize = (maxs - mins):Length()
        local targetSize = cv_mdl_size:GetFloat()
        local s = targetSize / math_max(modelSize, 0.1)
        previewModel:SetModelScale(s)

        -- Preview box center in 3D2D coords: approximately (380, 315)
        local px, py = 380 * scale, 315 * scale
        local modelPos = pos + ang:Forward() * px - ang:Right() * py + ang:Up() * 0.5

        -- Center model on its bounds
        local center = (mins + maxs) * 0.5 * s
        modelPos = modelPos - Vector(0, 0, center.z)

        -- Apply manual offset in entity-local space
        modelPos = modelPos + self:GetForward() * cv_mdl_ox:GetFloat() + self:GetRight() * cv_mdl_oy:GetFloat() + self:GetUp() * cv_mdl_oz:GetFloat()

        local modelAng = self:LocalToWorldAngles(Angle(cv_mdl_pitch:GetFloat(), previewSpin + cv_mdl_yaw:GetFloat(), cv_mdl_roll:GetFloat()))

        previewModel:SetPos(modelPos)
        previewModel:SetAngles(modelAng)
        previewModel:SetupBones()
        previewModel:DrawModel()
    end
end

function ENT:OnRemove()
    RemovePreviewModel()
    local idx = self:EntIndex()
    clientState[idx] = nil
    recruitmentData[idx] = nil
    quizDataCache[idx] = nil
    if activeTerminal == self then
        activeTerminal = nil
        ResetQuiz()
        gui.EnableScreenClicker(false)
    end
end

--[[---------------------------------------------
    Session Management (client-side)
-----------------------------------------------]]

-- Detect session state from NetworkVar
hook.Add("Think", "IMPERIAL_ORDERRecruit_SessionTrack", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    if activeTerminal then
        -- Already in session — just check if we're still the active user
        if not IsValid(activeTerminal) or activeTerminal:GetActiveUser() ~= ply then
            activeTerminal = nil
            ResetQuiz()
            gui.EnableScreenClicker(false)
        end
    else
        -- Not in session — scan for a terminal that has us as active user
        for _, ent in ipairs(ents.FindByClass("imperial_order_recruitment_terminal")) do
            if IsValid(ent) and ent:GetActiveUser() == ply then
                activeTerminal = ent
                sessionStart = CurTime()
                gui.EnableScreenClicker(true)
                break
            end
        end
    end
end)

-- Camera: locked position and angle looking at screen center
hook.Add("CalcView", "IMPERIAL_ORDERRecruit_CameraLock", function(ply, pos, angles, fov)
    -- Always store the true player camera for imperial_order_recruit_capture_cam
    lastRealCamPos = pos
    lastRealCamAng = angles

    if not IsValid(activeTerminal) then return end

    local ent = activeTerminal
    local terminalScale = GetTerminalDisplayScale(ent)
    camOrigin = ent:LocalToWorld(GetCamPos() * terminalScale)
    local target = ent:LocalToWorld(GetCamTarget() * terminalScale)
    local lookAng = (target - camOrigin):Angle()

    return {
        origin = camOrigin,
        angles = lookAng,
        fov = cv_cam_fov:GetFloat(),
        drawviewer = false,
    }
end)

-- Block all input while in terminal
hook.Add("StartCommand", "IMPERIAL_ORDERRecruit_BlockInput", function(ply, cmd)
    if not IsValid(activeTerminal) then return end
    if ply ~= LocalPlayer() then return end
    cmd:ClearButtons()
    cmd:ClearMovement()
end)

-- E to exit (intercept +use bind)
hook.Add("PlayerBindPress", "IMPERIAL_ORDERRecruit_ExitBind", function(ply, bind, pressed)
    if not IsValid(activeTerminal) then return end
    if not pressed then return end
    if bind == "+use" then
        net.Start("IMPERIAL_ORDERRecruit_Exit"); net.SendToServer()
        return true
    end
end)

-- Mouse click edge detection (LMB)
hook.Add("PreRender", "IMPERIAL_ORDERRecruit_InputState", function()
    mousePressed = false
    if not IsValid(activeTerminal) then mouseHeld = false; return end
    local isDown = input.IsMouseDown(MOUSE_LEFT)
    if isDown and not mouseHeld then
        mousePressed = true
    end
    mouseHeld = isDown
end)
