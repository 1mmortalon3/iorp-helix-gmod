local function IMPERIAL_ORDERJammerMapSupported()
    local mapName = string.lower(game.GetMap() or "")
    return mapName == "rp_victory_destroyer"
        or mapName == "rp_stardestroyer_v2_7"
        or mapName == "rp_stardestroyer_v2_7_inf"
end

if not IMPERIAL_ORDERJammerMapSupported() then return end

--[[
    Communications Jammer - Client Side
    Minigame UI, jammer warning HUD, tool-jammer visuals.
]]

local toolJammerList = {}
local jammerStateActive = false

surface.CreateFont("CommsJammer_Warning", {
    font = "Roboto",
    size = 22,
    weight = 800,
    antialias = true,
    extended = true,
})

net.Receive("CommsJammer_ClientState", function()
    jammerStateActive = net.ReadBool()
end)

hook.Add("HUDPaint", "CommsJammer_GlobalWarning", function()
    if not jammerStateActive then return end

    local text = "IMPERIAL COMMUNICATIONS JAMMED"
    local x = ScrW() * 0.5
    local y = ScrH() * 0.12
    local tw, th = surface.GetTextSize(text)

    draw.RoundedBox(3, x - tw * 0.5 - 16, y - th * 0.5 - 8, tw + 32, th + 16, Color(8, 10, 12, 220))
    surface.SetDrawColor(185, 25, 30, 220)
    surface.DrawOutlinedRect(x - tw * 0.5 - 16, y - th * 0.5 - 8, tw + 32, th + 16, 1)
    draw.SimpleText(text, "CommsJammer_Warning", x, y, Color(235, 235, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

-- Expose for tool Q menu panel
function CommsJammer_GetToolList()
    return toolJammerList
end

-- Receive tool jammer sync (entity references, not indices)
net.Receive("CommsJammer_SyncToolJammers", function()
    toolJammerList = {}
    local count = net.ReadUInt(8)
    for i = 1, count do
        local ent = net.ReadEntity()
        local entType = net.ReadString()
        local model = net.ReadString()
        if IsValid(ent) then
            table.insert(toolJammerList, {
                ent = ent,
                type = entType,
                model = model,
            })
        end
    end
end)

--[[---------------------------------------------
    Tool-Applied Jammer Halo
    Shows red halo on tool-jammed entities.
-----------------------------------------------]]
hook.Add("PreDrawHalos", "CommsJammer_ToolHalo", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local ents_list = {}
    for _, entry in ipairs(toolJammerList) do
        local ent = entry.ent
        if IsValid(ent) and ply:GetPos():DistToSqr(ent:GetPos()) < 1000000 then
            table.insert(ents_list, ent)
        end
    end

    if #ents_list > 0 then
        local pulse = 0.4 + 0.6 * math.abs(math.sin(CurTime() * 1.5))
        halo.Add(ents_list, Color(255, 190, 50, 255 * pulse), 2, 2, 1, true, false)
    end
end)

--[[---------------------------------------------
    Jammer Info HUD
    Shows subtle HP info when looking at a jammer.
-----------------------------------------------]]
surface.CreateFont("JammerHUD_Name", { font = "Roboto", size = 13, weight = 700, antialias = true, extended = true })
surface.CreateFont("JammerHUD_Info", { font = "Roboto", size = 11, weight = 500, antialias = true, extended = true })

-- Pre-allocated HUD colors (black + white + gold)
local colHudBg       = Color(8, 10, 12, 200)
local colHudBorder   = Color(255, 255, 255, 40)
local colArmored     = Color(255, 190, 50)
local colStandard    = Color(230, 85, 85)
local colDisabled    = Color(160, 160, 160)
local colBarBg       = Color(15, 15, 18, 200)
local colHpText      = Color(255, 255, 255, 160)
local colSubtitle    = Color(255, 255, 255, 100)

hook.Add("HUDPaint", "CommsJammer_InfoHUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local tr = ply:GetEyeTrace()
    if not IsValid(tr.Entity) then return end

    local ent = tr.Entity
    local cls = ent:GetClass()
    if cls ~= "comms_jammer" and cls ~= "comms_jammer_armored" then return end
    if ply:GetPos():DistToSqr(ent:GetPos()) > 160000 then return end

    local active = ent:GetJammerActive()
    local ratio = ent:GetHealthRatio()
    local sw, sh = ScrW(), ScrH()

    local x = sw * 0.5
    local y = sh * 0.62
    local panelW = 160

    local panelH = 38

    -- Background
    draw.RoundedBox(3, x - panelW / 2, y, panelW, panelH, colHudBg)
    surface.SetDrawColor(colHudBorder)
    surface.DrawOutlinedRect(x - panelW / 2, y, panelW, panelH, 1)

    -- Name
    local isArmored = (cls == "comms_jammer_armored")
    local nameCol = active and (isArmored and colArmored or colStandard) or colDisabled
    draw.SimpleText(isArmored and "Armored Jammer" or "Comms Jammer", "JammerHUD_Name", x, y + 9, nameCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- HP bar
    local barW = panelW - 16
    local barX = x - barW / 2
    local barY = y + 19

    if active then
        draw.RoundedBox(2, barX, barY, barW, 6, colBarBg)
        draw.RoundedBox(2, barX, barY, barW * ratio, 6, isArmored and colArmored or colStandard)
        draw.SimpleText(math.Round(ratio * 100) .. "%", "JammerHUD_Info", x, barY + 12, colHpText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    else
        draw.SimpleText("DISABLED", "JammerHUD_Info", x, barY + 3, colDisabled, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Subtitle for armored
    if isArmored and active then
        draw.SimpleText("needs explosives to damage", "JammerHUD_Info", x, y + 42, colSubtitle, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)

--[[---------------------------------------------
    Jammer Deactivation Minigame
    Quick-reaction node sequence puzzle.
    Player must click 5 highlighted nodes in
    order within a time limit.
-----------------------------------------------]]

surface.CreateFont("JammerMG_Title", { font = "Roboto", size = 20, weight = 800, antialias = true })
surface.CreateFont("JammerMG_Node",  { font = "Roboto", size = 16, weight = 700, antialias = true })
surface.CreateFont("JammerMG_Info",  { font = "Roboto", size = 14, weight = 500, antialias = true })

local minigamePanel = nil

net.Receive("CommsJammer_OpenMinigame", function()
    local ent = net.ReadEntity()
    if not IsValid(ent) then return end

    if ent:GetClass() == "comms_jammer_armored" then
        OpenArmoredMinigame(ent)
    else
        OpenJammerMinigame(ent)
    end
end)

function OpenJammerMinigame(jammerEnt)
    if IsValid(minigamePanel) then minigamePanel:Remove() end

    local sw, sh = ScrW(), ScrH()
    local pw, ph = 320, 320

    local frame = vgui.Create("DFrame")
    frame:SetSize(pw, ph)
    frame:Center()
    frame:SetTitle("")
    frame:MakePopup()
    frame:ShowCloseButton(false)
    minigamePanel = frame

    -- Generate 5 nodes in random positions
    local NODE_COUNT = 5
    local nodes = {}
    local currentNode = 1
    local timeLimit = 8
    local startTime = CurTime()
    local failed = false
    local completed = false

    for i = 1, NODE_COUNT do
        nodes[i] = {
            x = math.random(40, pw - 40),
            y = math.random(60, ph - 60),
            hit = false,
        }
    end

    frame.Paint = function(self, w, h)
        -- Background
        draw.RoundedBox(0, 0, 0, w, h, Color(8, 10, 12, 250))
        surface.SetDrawColor(255, 190, 50, 120)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        surface.SetDrawColor(255, 190, 50)
        surface.DrawRect(0, 0, w, 2)

        draw.SimpleText("JAMMER DEACTIVATION", "JammerMG_Title", w * 0.5, 16, Color(255, 190, 50), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Timer bar
        local elapsed = CurTime() - startTime
        local remaining = math.max(timeLimit - elapsed, 0)
        local ratio = remaining / timeLimit

        draw.RoundedBox(2, 10, 32, w - 20, 8, Color(15, 15, 18, 200))
        draw.RoundedBox(2, 10, 32, (w - 20) * ratio, 8, ratio > 0.3 and Color(255, 190, 50) or Color(230, 85, 85))

        -- Instructions
        if not completed and not failed then
            draw.SimpleText("Click nodes " .. currentNode .. "/" .. NODE_COUNT .. " in sequence", "JammerMG_Info", w * 0.5, ph - 12, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- Connection lines between nodes
        surface.SetDrawColor(255, 255, 255, 20)
        for i = 1, NODE_COUNT - 1 do
            surface.DrawLine(nodes[i].x, nodes[i].y, nodes[i + 1].x, nodes[i + 1].y)
        end

        -- Draw nodes
        for i, node in ipairs(nodes) do
            local isTarget = (i == currentNode and not completed and not failed)
            local isHit = node.hit

            if isHit then
                draw.RoundedBox(10, node.x - 12, node.y - 12, 24, 24, Color(80, 200, 120))
                draw.SimpleText(tostring(i), "JammerMG_Node", node.x, node.y, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            elseif isTarget then
                local pulse = 0.6 + 0.4 * math.abs(math.sin(CurTime() * 4))
                draw.RoundedBox(14, node.x - 16, node.y - 16, 32, 32, Color(255, 190, 50, 200 * pulse))
                draw.RoundedBox(10, node.x - 12, node.y - 12, 24, 24, Color(200, 150, 40))
                draw.SimpleText(tostring(i), "JammerMG_Node", node.x, node.y, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            else
                draw.RoundedBox(10, node.x - 12, node.y - 12, 24, 24, Color(15, 15, 18))
                draw.SimpleText(tostring(i), "JammerMG_Node", node.x, node.y, Color(160, 160, 160), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        -- Status messages
        if completed then
            draw.SimpleText("DEACTIVATION COMPLETE", "JammerMG_Title", w * 0.5, ph * 0.5, Color(80, 200, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        elseif failed then
            draw.SimpleText("DEACTIVATION FAILED", "JammerMG_Title", w * 0.5, ph * 0.5, Color(255, 190, 50), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- Timeout check
        if remaining <= 0 and not completed and not failed then
            failed = true
            surface.PlaySound("buttons/button10.wav")
            timer.Simple(1.5, function()
                if IsValid(frame) then frame:Remove() end
                net.Start("CommsJammer_MinigameResult")
                    net.WriteEntity(jammerEnt)
                    net.WriteBool(false)
                net.SendToServer()
            end)
        end
    end

    -- Click handler
    frame.OnMousePressed = function(self, keyCode)
        if keyCode ~= MOUSE_LEFT then return end
        if completed or failed then return end

        local mx, my = self:CursorPos()
        local node = nodes[currentNode]

        -- Check if click is within node radius
        local dist = math.sqrt((mx - node.x) ^ 2 + (my - node.y) ^ 2)

        if dist <= 20 then
            node.hit = true
            currentNode = currentNode + 1
            surface.PlaySound("ui/buttonrollover.wav")

            if currentNode > NODE_COUNT then
                completed = true
                surface.PlaySound("ui/buttonclick.wav")
                timer.Simple(1, function()
                    if IsValid(frame) then frame:Remove() end
                    net.Start("CommsJammer_MinigameResult")
                        net.WriteEntity(jammerEnt)
                        net.WriteBool(true)
                    net.SendToServer()
                end)
            end
        else
            -- Wrong click — fail
            failed = true
            surface.PlaySound("buttons/button10.wav")
            timer.Simple(1.5, function()
                if IsValid(frame) then frame:Remove() end
                net.Start("CommsJammer_MinigameResult")
                    net.WriteEntity(jammerEnt)
                    net.WriteBool(false)
                net.SendToServer()
            end)
        end
    end

    -- ESC to cancel
    frame.OnKeyCodePressed = function(self, key)
        if key == KEY_ESCAPE then
            frame:Remove()
            net.Start("CommsJammer_MinigameResult")
                net.WriteEntity(jammerEnt)
                net.WriteBool(false)
            net.SendToServer()
        end
    end
end

--[[---------------------------------------------
    Armored Jammer Minigame — Signal Decrypt
    Scrolling hex columns with a target sequence.
    Click matching codes as they scroll past the
    scan line. Match all 4 within 15 seconds.
-----------------------------------------------]]

surface.CreateFont("JammerMG_Hex",     { font = "Courier New", size = 14, weight = 700, antialias = true })
surface.CreateFont("JammerMG_Target",  { font = "Courier New", size = 16, weight = 800, antialias = true })
surface.CreateFont("JammerMG_ATitle",  { font = "Roboto", size = 18, weight = 800, antialias = true })

function OpenArmoredMinigame(jammerEnt)
    if IsValid(minigamePanel) then minigamePanel:Remove() end

    local pw, ph = 360, 380
    local frame = vgui.Create("DFrame")
    frame:SetSize(pw, ph)
    frame:Center()
    frame:SetTitle("")
    frame:MakePopup()
    frame:ShowCloseButton(false)
    minigamePanel = frame

    -- Generate hex codes
    local COLS = 4
    local COL_W = (pw - 20) / COLS
    local ROW_H = 24
    local SCAN_Y = 200 -- scan line Y position (middle of scrolling area)
    local SCROLL_SPEED = 25 -- pixels per second (slower for readability)

    local targets = {}
    local columns = {}
    local matched = {}
    local failed = false
    local completed = false
    local startTime = CurTime()
    local timeLimit = 15

    -- Generate random hex codes for each column
    local function RandHex()
        return string.format("%04X", math.random(0, 65535))
    end

    -- More rows, target placed so it arrives at scan line mid-game
    for c = 1, COLS do
        targets[c] = RandHex()
        matched[c] = false
        columns[c] = {}

        local targetRow = math.random(8, 18)
        for r = 1, 50 do
            if r == targetRow then
                columns[c][r] = targets[c]
            else
                columns[c][r] = RandHex()
            end
        end
    end

    frame.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(8, 10, 12, 250))
        surface.SetDrawColor(255, 190, 50, 160)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        surface.SetDrawColor(255, 190, 50)
        surface.DrawRect(0, 0, w, 2)

        draw.SimpleText("SIGNAL DECRYPTION", "JammerMG_ATitle", w * 0.5, 16, Color(255, 190, 50), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Timer bar
        local elapsed = CurTime() - startTime
        local remaining = math.max(timeLimit - elapsed, 0)
        local ratio = remaining / timeLimit

        draw.RoundedBox(2, 10, 34, w - 20, 6, Color(30, 15, 5, 200))
        draw.RoundedBox(2, 10, 34, (w - 20) * ratio, 6, ratio > 0.3 and Color(255, 190, 50) or Color(230, 85, 85))

        -- Target sequence display
        draw.SimpleText("TARGET:", "JammerMG_Info", 10, 48, Color(150, 130, 100), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        for c = 1, COLS do
            local tx = 10 + (c - 1) * COL_W + COL_W * 0.5
            local col = matched[c] and Color(80, 200, 120) or Color(255, 200, 80)
            draw.SimpleText(targets[c], "JammerMG_Target", tx, 66, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- Scrolling code area
        local areaY = 82
        local areaH = ph - 120
        local areaBottom = areaY + areaH

        -- Area background
        draw.RoundedBox(0, 10, areaY, w - 20, areaH, Color(2, 4, 10, 255))

        -- Column divider lines
        for c = 1, COLS - 1 do
            local divX = 10 + c * COL_W
            surface.SetDrawColor(255, 255, 255, 15)
            surface.DrawRect(divX, areaY, 1, areaH)
        end

        -- Scan line highlight (bright orange band)
        if SCAN_Y >= areaY and SCAN_Y + ROW_H <= areaBottom then
            surface.SetDrawColor(255, 190, 50, 100)
            surface.DrawRect(10, SCAN_Y, w - 20, ROW_H)
            surface.SetDrawColor(255, 210, 80, 255)
            surface.DrawRect(10, SCAN_Y, w - 20, 2)
            surface.DrawRect(10, SCAN_Y + ROW_H, w - 20, 2)
        end

        -- Draw scrolling columns (manual bounds check, no scissor rect)
        local scrollOffset = (CurTime() - startTime) * SCROLL_SPEED

        for c = 1, COLS do
            local cx = 10 + (c - 1) * COL_W + COL_W * 0.5

            for r = 1, #columns[c] do
                local ry = areaY + (r - 1) * ROW_H - scrollOffset
                local textY = ry + ROW_H * 0.5

                -- Skip if outside visible area
                if textY >= areaY and textY <= areaBottom then
                    local code = columns[c][r]
                    local isTarget = (code == targets[c])
                    local onScanLine = (ry >= SCAN_Y - ROW_H * 0.5 and ry <= SCAN_Y + ROW_H * 0.5)

                    local codeCol = Color(60, 110, 90, 200)

                    if isTarget and matched[c] then
                        codeCol = Color(0, 220, 100, 255)
                    elseif isTarget and onScanLine then
                        codeCol = Color(255, 255, 80, 255)
                    elseif isTarget then
                        codeCol = Color(100, 220, 140, 255)
                    elseif onScanLine then
                        codeCol = Color(255, 200, 120, 255)
                    end

                    draw.SimpleText(code, "JammerMG_Hex", cx, textY, codeCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end
        end

        -- Status
        local matchCount = 0
        for c = 1, COLS do if matched[c] then matchCount = matchCount + 1 end end

        if not completed and not failed then
            draw.SimpleText("Match: " .. matchCount .. "/" .. COLS .. "  |  Click codes on scan line", "JammerMG_Info", w * 0.5, ph - 16, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        elseif completed then
            draw.SimpleText("DECRYPTION COMPLETE", "JammerMG_ATitle", w * 0.5, ph * 0.5, Color(80, 200, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        elseif failed then
            draw.SimpleText("DECRYPTION FAILED", "JammerMG_ATitle", w * 0.5, ph * 0.5, Color(230, 85, 85), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- Timeout
        if remaining <= 0 and not completed and not failed then
            failed = true
            surface.PlaySound("buttons/button10.wav")
            timer.Simple(1.5, function()
                if IsValid(frame) then frame:Remove() end
                net.Start("CommsJammer_MinigameResult")
                    net.WriteEntity(jammerEnt)
                    net.WriteBool(false)
                net.SendToServer()
            end)
        end
    end

    -- Click handler — check if clicked code is on the scan line and matches target
    frame.OnMousePressed = function(self, keyCode)
        if keyCode ~= MOUSE_LEFT then return end
        if completed or failed then return end

        local mx, my = self:CursorPos()
        local scrollOffset = (CurTime() - startTime) * SCROLL_SPEED
        local areaY = 82

        for c = 1, COLS do
            if matched[c] then continue end

            local cx = 10 + (c - 1) * COL_W
            if mx < cx or mx > cx + COL_W then continue end

            -- Check which row is on the scan line
            for r = 1, #columns[c] do
                local ry = areaY + (r - 1) * ROW_H - scrollOffset
                if ry >= SCAN_Y - 5 and ry <= SCAN_Y + ROW_H + 5 then
                    if columns[c][r] == targets[c] then
                        matched[c] = true
                        surface.PlaySound("ui/buttonrollover.wav")

                        -- Check win
                        local allMatched = true
                        for i = 1, COLS do if not matched[i] then allMatched = false end end

                        if allMatched then
                            completed = true
                            surface.PlaySound("ui/buttonclick.wav")
                            timer.Simple(1, function()
                                if IsValid(frame) then frame:Remove() end
                                net.Start("CommsJammer_MinigameResult")
                                    net.WriteEntity(jammerEnt)
                                    net.WriteBool(true)
                                net.SendToServer()
                            end)
                        end
                    else
                        -- Wrong code — fail
                        failed = true
                        surface.PlaySound("buttons/button10.wav")
                        timer.Simple(1.5, function()
                            if IsValid(frame) then frame:Remove() end
                            net.Start("CommsJammer_MinigameResult")
                                net.WriteEntity(jammerEnt)
                                net.WriteBool(false)
                            net.SendToServer()
                        end)
                    end
                    break
                end
            end
        end
    end

    frame.OnKeyCodePressed = function(self, key)
        if key == KEY_ESCAPE then
            frame:Remove()
            net.Start("CommsJammer_MinigameResult")
                net.WriteEntity(jammerEnt)
                net.WriteBool(false)
            net.SendToServer()
        end
    end
end

--[[---------------------------------------------
    Spawnmenu / Q Menu Config
    Adds "Remove All Jammers" to the Utilities tab.
-----------------------------------------------]]
hook.Add("PopulateToolMenu", "CommsJammer_ToolMenu", function()
    spawnmenu.AddToolMenuOption("Utilities", "Comms Console", "CommsJammer_Config", "Jammer Config", "", "", function(panel)
        panel:ClearControls()

        panel:AddControl("Header", {
            Text = "Communications Jammer Config",
            Description = "Manage active communications jammers.",
        })

        local removeBtn = vgui.Create("DButton")
        removeBtn:SetText("Remove All Jammers (Admin)")
        removeBtn:SetTall(30)
        removeBtn.DoClick = function()
            net.Start("CommsJammer_RemoveAll")
            net.SendToServer()
        end
        panel:AddItem(removeBtn)

        panel:Help("This removes all jammer entities and clears all tool-applied jammer effects. Admin only.")
    end)
end)
