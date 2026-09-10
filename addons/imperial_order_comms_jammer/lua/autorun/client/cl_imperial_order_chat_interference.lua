-- Imperial Order chat-box static/scramble effect.

local persistent = false
local burstEndsAt = 0
local bypass = false
local originalChatAddText = chat.AddText

local replacements = {"#", "%", "?", "-", "~", "0", "1", "X"}

local function IsActive()
    return persistent or CurTime() < burstEndsAt
end

local function ScrambleCharacters(text)
    if not isstring(text) or text == "" then return text end

    local output = {}
    for i = 1, #text do
        local ch = string.sub(text, i, i)
        if string.match(ch, "%s") or string.match(ch, "[%[%]%(%)%:%.,!/'\"_-]") then
            output[#output + 1] = ch
        elseif math.random() < 0.72 then
            output[#output + 1] = replacements[math.random(1, #replacements)]
        else
            output[#output + 1] = ch
        end
    end
    return table.concat(output)
end

function IMPERIAL_ORDER_CommsScrambleText(text)
    if not IsActive() then return text end
    return ScrambleCharacters(text)
end

local function TransformArgument(value, index, total)
    if not isstring(value) then return value end

    -- Preserve short channel prefixes and speaker names so players can still
    -- identify where a transmission originated. Garble the message payload.
    if string.match(value, "^%b[]%s*$") then return value end
    if string.StartWith(value, "[Comms") or string.StartWith(value, "[Jammer") then return value end
    if total >= 3 and index < total and #value < 32 and not string.StartWith(value, ":") then
        return value
    end

    if string.StartWith(value, ": ") then
        return ": " .. ScrambleCharacters(string.sub(value, 3))
    end

    return ScrambleCharacters(value)
end

chat.AddText = function(...)
    if bypass or not IsActive() then
        return originalChatAddText(...)
    end

    local args = {...}
    for i = 1, #args do
        args[i] = TransformArgument(args[i], i, #args)
    end
    return originalChatAddText(unpack(args))
end

net.Receive("IMPERIAL_ORDER_CommsChatInterference", function()
    local wasActive = IsActive()
    persistent = net.ReadBool()
    local burstRemaining = net.ReadFloat()
    local reason = net.ReadString()
    burstEndsAt = math.max(burstEndsAt, CurTime() + math.max(burstRemaining, 0))
    local nowActive = IsActive()

    bypass = true
    if nowActive and not wasActive then
        originalChatAddText(Color(210, 45, 35), "[IMPERIAL COMMS] ", Color(230, 230, 230), "Signal corruption detected: " .. (reason ~= "" and reason or "unknown interference") .. ".")
        surface.PlaySound("ambient/energy/newspark04.wav")
    elseif not nowActive and wasActive then
        originalChatAddText(Color(50, 180, 90), "[IMPERIAL COMMS] ", Color(230, 230, 230), "Signal integrity restored.")
    end
    bypass = false
end)
