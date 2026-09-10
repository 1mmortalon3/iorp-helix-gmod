-- Imperial Order communications chat interference controller.
-- Persistent sources remain active until repaired; bursts are timed EMP/static events.

util.AddNetworkString("IMPERIAL_ORDER_CommsChatInterference")

local persistentSources = {}
local burstEndsAt = 0

local function HasPersistentSource()
    return next(persistentSources) ~= nil
end

local function SendState(target, reason)
    net.Start("IMPERIAL_ORDER_CommsChatInterference")
        net.WriteBool(HasPersistentSource())
        net.WriteFloat(math.max(burstEndsAt - CurTime(), 0))
        net.WriteString(reason or "")
    if IsValid(target) then
        net.Send(target)
    else
        net.Broadcast()
    end
end

function IMPERIAL_ORDER_CommsInterferenceBurst(duration, reason)
    duration = math.Clamp(tonumber(duration) or 10, 0.5, 120)
    burstEndsAt = math.max(burstEndsAt, CurTime() + duration)
    SendState(nil, reason or "electrical discharge")
end

function IMPERIAL_ORDER_CommsInterferenceSetPersistent(source, enabled, reason)
    source = tostring(source or "unknown")
    if enabled then
        persistentSources[source] = true
    else
        persistentSources[source] = nil
    end
    SendState(nil, reason or (enabled and "communications failure" or "communications restored"))
end

hook.Add("PlayerInitialSpawn", "IMPERIAL_ORDER_CommsInterferenceSync", function(ply)
    timer.Simple(4, function()
        if IsValid(ply) then
            SendState(ply, "state synchronization")
        end
    end)
end)
