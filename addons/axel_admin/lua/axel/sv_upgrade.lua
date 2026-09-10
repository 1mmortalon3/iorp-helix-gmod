-- Read legacy data only during upgrade; active identifiers use Axel.
-- Keep the existing MySQL prefix so remote rank records remain accessible.
file.CreateDir("axel")
for _, name in ipairs({"mysql.json", "player_ranks.json"}) do
    local destination = "axel/" .. name
    if not file.Exists(destination, "DATA") then
        local raw = file.Read("ax31/" .. name, "DATA")
        if raw then
            local decoded = util.JSONToTable(raw)
            if not istable(decoded) then
                error("[Axel] Cannot migrate invalid saved data: " .. name)
            end
            if name == "mysql.json" and decoded.table_prefix == nil then
                decoded.table_prefix = "ax31_"
                raw = util.TableToJSON(decoded, true)
            end
            file.Write(destination, raw)
            if file.Read(destination, "DATA") ~= raw then
                error("[Axel] Could not verify migrated data: " .. name)
            end
        end
    end
end
