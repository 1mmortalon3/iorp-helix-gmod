local UI = IMPERIAL_ORDER_WILTOS_UI
UI.Adapter = UI.Adapter or {}
local A = UI.Adapter

function A.SafeCall(object, method, fallback, ...)
    if not object then return fallback end
    local fn = object[method]
    if not isfunction(fn) then return fallback end
    local ok, result = pcall(fn, object, ...)
    if not ok or result == nil then return fallback end
    return result
end

function A.GetPlayer()
    local ply = LocalPlayer()
    return IsValid(ply) and ply or nil
end

function A.GetLevel()
    local ply = A.GetPlayer()
    if not ply then return 0 end
    return ply:GetNW2Int("wOS.SkillLevel", 0)
end

function A.GetXP()
    local ply = A.GetPlayer()
    if not ply then return 0 end
    return ply:GetNW2Int("wOS.SkillExperience", 0)
end

function A.GetPoints()
    local ply = A.GetPlayer()
    if not ply then return 0 end
    return ply:GetNW2Int("wOS.SkillPoints", 0)
end

function A.GetMaxLevel()
    if wOS and wOS.ALCS and wOS.ALCS.Config and wOS.ALCS.Config.Skills then
        return tonumber(wOS.ALCS.Config.Skills.SkillMaxLevel) or 0
    end
    return 0
end

function A.GetPrestigeRequirement()
    if wOS and wOS.ALCS and wOS.ALCS.Config and wOS.ALCS.Config.Prestige then
        local configured = wOS.ALCS.Config.Prestige.PrestigeLevel
        if configured then return tonumber(configured) or A.GetMaxLevel() end
    end
    return A.GetMaxLevel()
end

function A.GetLevelBounds()
    local level = A.GetLevel()
    local xp = A.GetXP()
    local required = math.max(1, level + 1)
    local previous = 0
    if wOS and wOS.ALCS and wOS.ALCS.Config and wOS.ALCS.Config.Skills and isfunction(wOS.ALCS.Config.Skills.XPScaleFormula) then
        local ok1, value1 = pcall(wOS.ALCS.Config.Skills.XPScaleFormula, level)
        if ok1 and tonumber(value1) then required = tonumber(value1) end
        if level > 0 then
            local ok2, value2 = pcall(wOS.ALCS.Config.Skills.XPScaleFormula, level - 1)
            if ok2 and tonumber(value2) then previous = tonumber(value2) end
        end
    end
    local maximum = A.GetMaxLevel()
    local fraction = (xp - previous) / math.max(1, required - previous)
    if maximum > 0 and level >= maximum then fraction = 1 end
    return previous, required, math.Clamp(fraction, 0, 1)
end

local function tableHasValue(tbl, value)
    if not istable(tbl) then return false end
    for _, candidate in pairs(tbl) do
        if candidate == value then return true end
    end
    return false
end

function A.CanViewTree(name, data)
    local ply = A.GetPlayer()
    if not ply then return false end

    local hookResult = hook.Run("wOS.ALCS.Skill.CanViewTree", ply, name, data)
    if hookResult ~= nil then return hookResult == true end

    local whitelists = (wOS and wOS.SkillTreeWhitelists) or {}
    if whitelists[name] then return true end

    if istable(data.UserGroups) and not tableHasValue(data.UserGroups, ply:GetUserGroup()) then
        return false
    end

    if istable(data.JobRestricted) then
        local found = false
        for _, globalName in pairs(data.JobRestricted) do
            if _G[globalName] == ply:Team() then
                found = true
                break
            end
        end
        if not found then return false end
    end

    return true
end

function A.GetTrees()
    local result = {}
    if not wOS or not istable(wOS.SkillTrees) then return result end
    for name, data in pairs(wOS.SkillTrees) do
        if istable(data) and A.CanViewTree(name, data) then
            result[#result + 1] = {name = name, data = data}
        end
    end
    table.sort(result, function(left, right)
        return string.lower(left.name) < string.lower(right.name)
    end)
    return result
end

function A.GetTree(name)
    return wOS and wOS.SkillTrees and wOS.SkillTrees[name] or nil
end

function A.HasSkill(tree, tier, skill)
    if wOS and isfunction(wOS.HasSkillEquipped) then
        local ok, result = pcall(wOS.HasSkillEquipped, wOS, tree, tier, skill)
        if ok then return result == true end
    end
    local equipped = wOS and wOS.EquippedSkills or nil
    return equipped and equipped[tree] and equipped[tree][tier] and equipped[tree][tier][skill] == true or false
end

function A.GetSkill(tree, tier, skill)
    local data = A.GetTree(tree)
    return data and data.Tier and data.Tier[tier] and data.Tier[tier][skill] or nil
end

function A.MeetsRequirements(tree, skillData)
    if not skillData then return false end
    if istable(skillData.LockOuts) then
        for tier, skills in pairs(skillData.LockOuts) do
            for _, skill in pairs(skills) do
                if A.HasSkill(tree, tier, skill) then return false end
            end
        end
    end
    if istable(skillData.Requirements) then
        for tier, skills in pairs(skillData.Requirements) do
            for _, skill in pairs(skills) do
                if not A.HasSkill(tree, tier, skill) then return false end
            end
        end
    end
    return true
end

function A.CanPurchaseSkill(tree, tier, skill)
    local data = A.GetSkill(tree, tier, skill)
    if not data or data.DummySkill then return false, "Invalid skill" end
    if A.HasSkill(tree, tier, skill) then return false, "Already unlocked" end
    if not A.MeetsRequirements(tree, data) then return false, "Requirements not met" end
    local cost = tonumber(data.PointsRequired) or 0
    if A.GetPoints() < cost then return false, "Not enough skill points" end
    return true
end

function A.PurchaseSkill(tree, tier, skill)
    local allowed, reason = A.CanPurchaseSkill(tree, tier, skill)
    if not allowed then
        UI.Notify(reason, NOTIFY_ERROR)
        return
    end
    net.Start("wOS.SkillTree.ChooseSkill")
        net.WriteString(tree)
        net.WriteInt(tier, 32)
        net.WriteInt(skill, 32)
    net.SendToServer()
    UI.Notify("Unlock request transmitted", NOTIFY_HINT, 2)
end

function A.ResetSkills()
    net.Start("wOS.SkillTree.ResetAllSkills")
    net.SendToServer()
end

function A.GetUnlockedCount()
    local count = 0
    local equipped = wOS and wOS.EquippedSkills or {}
    for _, tiers in pairs(equipped) do
        for _, skills in pairs(tiers) do
            for _, unlocked in pairs(skills) do
                if unlocked then count = count + 1 end
            end
        end
    end
    return count
end

function A.GetPrestigeData()
    local prestige = wOS and wOS.ALCS and wOS.ALCS.Prestige
    local data = prestige and prestige.Data or {}
    return {
        Level = tonumber(data.Level) or 0,
        Tokens = tonumber(data.Tokens) or 0,
        Mastery = istable(data.Mastery) and data.Mastery or {},
    }
end

function A.GetPrestigeMap()
    local prestige = wOS and wOS.ALCS and wOS.ALCS.Prestige
    return prestige and istable(prestige.MapData) and prestige.MapData or {Paths = {}}
end

function A.CanAscend()
    local required = A.GetPrestigeRequirement()
    if required <= 0 then return false end
    return A.GetLevel() >= required
end

function A.Ascend()
    net.Start("wOS.ALCS.Prestige.Ascend")
    net.SendToServer()
end

function A.CanPurchaseMastery(id, data)
    local prestige = A.GetPrestigeData()
    if prestige.Mastery[id] then return false, "Already mastered" end
    local cost = tonumber(data and data.Amount) or 0
    if prestige.Tokens < cost then return false, "Not enough prestige tokens" end
    local required = data and data.RequiredMastery or {}
    if istable(required) and #required > 0 then
        local found = false
        for _, mastery in ipairs(required) do
            if prestige.Mastery[mastery] then
                found = true
                break
            end
        end
        if not found then return false, "Required mastery missing" end
    end
    return true
end

function A.PurchaseMastery(id, data)
    local allowed, reason = A.CanPurchaseMastery(id, data)
    if not allowed then
        UI.Notify(reason, NOTIFY_ERROR)
        return
    end
    net.Start("wOS.ALCS.Prestige.GetMasteryBate")
        net.WriteInt(id, 32)
    net.SendToServer()
    UI.Notify("Mastery request transmitted", NOTIFY_HINT, 2)
end

function A.GetActiveSaber()
    local ply = A.GetPlayer()
    if not ply then return nil end
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return nil end
    if not wep.IsLightsaber and not string.find(string.lower(wep:GetClass()), "lightsaber", 1, true) then return nil end
    return wep
end

function A.GetCurrentForm(wep)
    wep = wep or A.GetActiveSaber()
    if not IsValid(wep) then return "NO SABER", 0 end
    local formIndex = A.SafeCall(wep, "GetForm", 0)
    local stance = A.SafeCall(wep, "GetStance", 0)
    local localized = wOS and wOS.Form and wOS.Form.LocalizedForms
    local formName = localized and localized[formIndex] or tostring(formIndex)
    return formName or "UNKNOWN", stance
end

function A.GetAvailableForms()
    local wep = A.GetActiveSaber()
    if not IsValid(wep) then return {}, {}, nil end

    local forms, stances = {}, {}
    local dual = A.SafeCall(wep, "GetDualMode", false)
    local group = A.GetPlayer():GetUserGroup()

    if not wep.UseSkills then
        if istable(wep.UseForms) then
            for form, stanceData in pairs(wep.UseForms) do
                forms[#forms + 1] = form
                stances[form] = {}
                if istable(stanceData) then
                    for stance in pairs(stanceData) do stances[form][#stances[form] + 1] = stance end
                end
            end
        else
            local database = dual and (wOS and wOS.DualForms) or (wOS and wOS.Forms)
            local allAccess = wOS and wOS.ALCS and wOS.ALCS.Config and wOS.ALCS.Config.AllAccessForms
            for form, access in pairs(database or {}) do
                if tableHasValue(allAccess, group) or (istable(access) and access[group]) then
                    forms[#forms + 1] = form
                    stances[form] = {1, 2, 3}
                end
            end
        end
    else
        local database = dual and (wOS and wOS.DualForms) or (wOS and wOS.Forms)
        if istable(wep.Forms) then
            for _, form in pairs(wep.Forms) do
                if database and database[form] then
                    forms[#forms + 1] = form
                    stances[form] = {}
                    local index = wOS and wOS.Form and wOS.Form.IndexedForms and wOS.Form.IndexedForms[form]
                    local stanceData = index and wep.Stances and wep.Stances[index]
                    if istable(stanceData) then
                        for _, stance in pairs(stanceData) do stances[form][#stances[form] + 1] = stance end
                    end
                end
            end
        end
    end

    table.sort(forms, function(left, right) return string.lower(left) < string.lower(right) end)
    for _, list in pairs(stances) do table.sort(list) end
    return forms, stances, wep
end

function A.SelectForm(form)
    net.Start("wOS.ALCS.SendFormSelect")
        net.WriteString(form)
    net.SendToServer()
end

function A.SelectStance(form, stance)
    net.Start("wOS.ALCS.SendStanceSelect")
        net.WriteString(form)
        net.WriteUInt(stance, 3)
    net.SendToServer()
end

function A.RemoveDefaultMenus()
    if not wOS or not wOS.ALCS or not wOS.ALCS.Skills then return end
    local skills = wOS.ALCS.Skills
    local panels = {skills.Menu, skills.ClassicMenu, skills.DataTab, skills.SkillInfoPanel}
    for _, panel in ipairs(panels) do UI.SafeRemove(panel) end
    skills.Menu = nil
    skills.ClassicMenu = nil
    skills.DataTab = nil
    skills.SkillInfoPanel = nil
    if istable(skills.CubeModels) then
        for _, model in pairs(skills.CubeModels) do UI.SafeRemove(model) end
        skills.CubeModels = {}
    end
    if wOS.ALCS.FormMenu then
        UI.SafeRemove(wOS.ALCS.FormMenu)
        wOS.ALCS.FormMenu = nil
    end
end
