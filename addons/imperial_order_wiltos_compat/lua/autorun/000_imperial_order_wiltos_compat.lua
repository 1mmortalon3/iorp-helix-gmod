-- Imperial Order - wiltOS compatibility bootstrap
-- Keeps separately installed wiltOS/Sentinel modules from indexing combat
-- registries before their optional lightsaber packages have initialized.

if SERVER then
    AddCSLuaFile()
end

local function EnsureWiltOSRegistries()
    wOS = istable(wOS) and wOS or {}
    wOS.ALCS = istable(wOS.ALCS) and wOS.ALCS or {}

    -- Different wiltOS generations reference either of these registries.
    -- Only create missing tables; never replace data populated by the addon.
    wOS.Lightsabers = istable(wOS.Lightsabers) and wOS.Lightsabers or {}
    wOS.ALCS.Lightsabers = istable(wOS.ALCS.Lightsabers) and wOS.ALCS.Lightsabers or {}
    wOS.ALCS.LightsaberBase = istable(wOS.ALCS.LightsaberBase) and wOS.ALCS.LightsaberBase or {}
end

EnsureWiltOSRegistries()

hook.Add("Initialize", "IMPERIAL_ORDER.WiltOSCompat.Initialize", EnsureWiltOSRegistries)
hook.Add("InitPostEntity", "IMPERIAL_ORDER.WiltOSCompat.InitPostEntity", EnsureWiltOSRegistries)
hook.Add("OnReloaded", "IMPERIAL_ORDER.WiltOSCompat.Reload", EnsureWiltOSRegistries)

-- Some workshop collections rebuild wOS.ALCS asynchronously. Repair only nil
-- registries during the first minute after joining, then stop polling.
if CLIENT then
    timer.Create("IMPERIAL_ORDER.WiltOSCompat.BootWindow", 0.5, 120, EnsureWiltOSRegistries)
end
