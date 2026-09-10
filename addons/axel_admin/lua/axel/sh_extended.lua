-- Extended administration. Every action runs through AXEL.RunCommand.
local function register(name, category, description, arguments, labels, callback, permission)
    AXEL.RegisterCommand(name, {category = category, description = description,
        arguments = arguments, argumentLabels = labels, OnRun = callback, permission = permission})
end
local function each(name, description, callback, permission)
    register(name, "Player", description, {"players"}, {"Player"}, function(actor, targets)
        for _, target in ipairs(targets) do callback(target) end
        return true, name .. " applied to " .. AXEL.DescribeTargets(targets) .. "."
    end, permission)
end
each("godon", "Enable godmode.", function(p) p:GodEnable() end, "god")
each("unnoclip", "Disable noclip and restore walking.", function(p) p:SetMoveType(MOVETYPE_WALK) end, "noclip")
each("stripweapons", "Remove all carried weapons (until restored by the gamemode).", function(p) p:StripWeapons() end)
each("stripammo", "Remove all reserve ammunition.", function(p) p:RemoveAllAmmo() end, "giveammo")
each("exitvehicle", "Make players leave their vehicle.", function(p) p:ExitVehicle() end)
each("resetdeaths", "Reset the scoreboard death count.", function(p) p:SetDeaths(0) end, "score")
each("resetfrags", "Reset the scoreboard frag count.", function(p) p:SetFrags(0) end, "score")
for _, spec in ipairs({
    {"walkspeed", "Walking speed", "SetWalkSpeed", 1, 1000, "movement"},
    {"runspeed", "Running speed", "SetRunSpeed", 1, 2000, "movement"},
    {"jumppower", "Jump power", "SetJumpPower", 0, 1000, "movement"},
    {"gravity", "Player gravity multiplier", "SetGravity", 0.1, 5, "movement"},
    {"frags", "Scoreboard frags", "SetFrags", -10000, 100000, "score"},
    {"deaths", "Scoreboard deaths", "SetDeaths", 0, 100000, "score"}
}) do
    local item = spec
    register(item[1], "Player", "Set " .. string.lower(item[2]) .. ".", {"players", "number"},
        {"Player", item[2] .. " (" .. item[4] .. " to " .. item[5] .. ")"}, function(actor, targets, value)
            if value < item[4] or value > item[5] then return false, "Value must be between " .. item[4] .. " and " .. item[5] .. "." end
            for _, target in ipairs(targets) do target[item[3]](target, value) end
            return true, item[1] .. " set to " .. value .. " for " .. AXEL.DescribeTargets(targets) .. "."
        end, item[6])
end
register("setmodel", "Appearance", "Set a temporary player model; respawn or character changes may replace it.", {"player", "string"}, {"Player", "Model path (.mdl)"}, function(actor, target, model)
    if not util.IsValidModel(model) then return false, "Model is invalid or missing on the server." end
    target.AXELOriginalModel = target.AXELOriginalModel or target:GetModel()
    target:SetModel(model)
    target:SetupHands()
    return true, target:Nick() .. " model changed."
end)
register("resetmodel", "Appearance", "Restore the model saved before Set Model.", {"player"}, {"Player"}, function(actor, target)
    local model = target.AXELOriginalModel
    if not model or not util.IsValidModel(model) then return false, "No valid saved model." end
    target:SetModel(model); target:SetupHands(); target.AXELOriginalModel = nil
    return true, target:Nick() .. " model restored."
end, "setmodel")
register("skin", "Appearance", "Set a model skin by index.", {"player", "number"}, {"Player", "Skin index (starts at 0)"}, function(actor, target, value)
    value = math.floor(value)
    if value < 0 or value >= target:SkinCount() then return false, "Skin index is outside this model's range." end
    target:SetSkin(value)
    return true, target:Nick() .. " skin set to " .. value .. "."
end, "setmodel")
register("bodygroup", "Appearance", "Set a model bodygroup by index.", {"player", "number", "number"}, {"Player", "Bodygroup index", "Value index"}, function(actor, target, group, value)
    group, value = math.floor(group), math.floor(value)
    if group < 0 or group >= target:GetNumBodyGroups() or value < 0 or value >= target:GetBodygroupCount(group) then return false, "Invalid bodygroup or value for this model." end
    target:SetBodygroup(group, value)
    return true, target:Nick() .. " bodygroup updated."
end, "setmodel")
register("giveweapon", "Equipment", "Give an installed weapon; gamemode pickup rules still apply.", {"player", "string"}, {"Player", "Weapon class"}, function(actor, target, class)
    local native = {weapon_crowbar=true, weapon_pistol=true, weapon_357=true, weapon_smg1=true, weapon_ar2=true, weapon_shotgun=true, weapon_crossbow=true, weapon_frag=true, weapon_rpg=true, weapon_physcannon=true, weapon_bugbait=true}
    if not native[class] and not weapons.GetStored(class) then return false, "Unknown weapon class." end
    if not target:Alive() then return false, "Player must be alive." end
    local weapon = target:Give(class)
    if not IsValid(weapon) then return false, "Weapon could not be given; check gamemode restrictions." end
    return true, "Gave " .. class .. " to " .. target:Nick() .. "."
end)
register("removeweapon", "Equipment", "Remove one carried weapon by class.", {"player", "string"}, {"Player", "Weapon class"}, function(actor, target, class)
    if not target:HasWeapon(class) then return false, "Player does not carry that weapon." end
    target:StripWeapon(class)
    return true, "Removed " .. class .. " from " .. target:Nick() .. "."
end, "stripweapons")
register("giveammo", "Equipment", "Give reserve ammunition by ammo name.", {"player", "number", "string"}, {"Player", "Amount (1-10000)", "Ammo name (e.g. Pistol)"}, function(actor, target, amount, ammo)
    local id = game.GetAmmoID(ammo)
    if id < 0 then return false, "Unknown ammo name." end
    amount = math.floor(amount)
    if amount < 1 or amount > 10000 then return false, "Amount must be 1-10000." end
    local given = target:GiveAmmo(amount, id)
    return true, "Gave " .. tostring(given) .. " " .. ammo .. " rounds to " .. target:Nick() .. "."
end)
register("announce", "General", "Send a labelled server-wide announcement.", {"text"}, {"Announcement"}, function(actor, message)
    if string.Trim(message) == "" then return false, "Enter an announcement." end
    return true, "[ANNOUNCEMENT] " .. string.sub(message, 1, 200)
end)
register("warn", "Moderation", "Send a logged warning to a player.", {"player", "text"}, {"Player", "Reason"}, function(actor, target, reason)
    if string.Trim(reason) == "" then return false, "Enter a warning reason." end
    target:ChatPrint("[Axel WARNING] " .. reason)
    return true, target:Nick() .. " warned: " .. reason
end)
-- Collision checked destinations for Send and Teleport.
function AXEL.SafeMove(target, origin)
    if target:InVehicle() then return false end
    local mins, maxs = target:GetHull()
    for _, offset in ipairs({Vector(80,0,8), Vector(-80,0,8), Vector(0,80,8), Vector(0,-80,8), Vector(120,120,8), Vector(-120,-120,8)}) do
        local pos = origin + offset
        local trace = util.TraceHull({start=pos, endpos=pos, mins=mins, maxs=maxs, filter=target, mask=MASK_PLAYERSOLID})
        if util.IsInWorld(pos) and not trace.Hit and not trace.StartSolid then
            target.AXELReturnPos = target:GetPos()
            target:SetPos(pos)
            return true
        end
    end
    return false
end
register("send", "Teleport", "Teleport a player beside another player.", {"player", "player"}, {"Player to move", "Destination player"}, function(actor, target, destination)
    if target == destination then return false, "Choose two different players." end
    if not AXEL.SafeMove(target, destination:GetPos()) then return false, "No clear destination, or player is in a vehicle." end
    return true, target:Nick() .. " sent to " .. destination:Nick() .. "."
end, "teleport")
register("teleport", "Teleport", "Move a player near the point you are aiming at.", {"player"}, {"Player"}, function(actor, target)
    if not IsValid(actor) then return false, "Run this in game while looking at the destination." end
    if not AXEL.SafeMove(target, actor:GetEyeTrace().HitPos) then return false, "No clear destination, or player is in a vehicle." end
    return true, target:Nick() .. " teleported."
end)
register("cleanup", "Server", "Reset map entities and remove spawned props. This affects everyone.", {}, {}, function(actor)
    game.CleanUpMap()
    return true, "Map cleanup completed."
end)
register("stopsounds", "Server", "Stop currently playing sounds for every client.", {}, {}, function(actor)
    for _, client in ipairs(player.GetAll()) do client:ConCommand("stopsound") end
    return true, "Stopped client sounds."
end)
register("map", "Server", "Change to an installed map; all players will reload.", {"string"}, {"Installed map name"}, function(actor, map)
    if not string.match(map, "^[%w_%-]+$") or not file.Exists("maps/" .. map .. ".bsp", "GAME") then return false, "Map is not installed or its name is invalid." end
    timer.Simple(1, function() RunConsoleCommand("changelevel", map) end)
    return true, "Changing map to " .. map .. "."
end)
register("restartmap", "Server", "Reload the current map; all players will reload.", {}, {}, function(actor)
    local map = game.GetMap()
    timer.Simple(1, function() RunConsoleCommand("changelevel", map) end)
    return true, "Reloading map " .. map .. "."
end, "map")
for _, spec in ipairs({{"servergravity", "sv_gravity", 100, 2000}, {"alltalk", "sv_alltalk", 0, 1}, {"friendlyfire", "sbox_playershurtplayers", 0, 1}}) do
    local item = spec
    register(item[1], "Server", "Set " .. item[2] .. " (gamemode support required).", {"number"}, {"Value (" .. item[3] .. " to " .. item[4] .. ")"}, function(actor, value)
        if not GetConVar(item[2]) then return false, "This gamemode does not provide " .. item[2] .. "." end
        if value < item[3] or value > item[4] or value ~= math.floor(value) then return false, "Enter a whole number in the displayed range." end
        RunConsoleCommand(item[2], tostring(value))
        return true, item[2] .. " set to " .. value .. "."
    end, "serverconfig")
end
