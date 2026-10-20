local _, D = ...
local MAX = 65536
local function enc(s)
    return (tostring(s or ""):gsub("([^%w%._ %-])", function(c) return string.format("%%%02X", string.byte(c)) end))
end
local function dec(s)
    if s:gsub("%%[%x][%x]", ""):find("%%") then error("Invalid percent escape") end
    return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end
local function integer(s, field, optional)
    if optional and s == "" then return nil end
    if not s or not s:match("^%d+$") then error(field .. " must be a nonnegative integer") end
    local n = tonumber(s)
    if not n or n > 2147483647 then error(field .. " is out of range") end
    return n
end
function D.Encode(p)
    local c, s = p.character, p.source
    local rows = {"CDNA1", "N\t" .. enc(p.name),
        table.concat({"S", enc(s.game), enc(s.build), enc(s.api), enc(s.version), enc(s.interface)}, "\t"),
        table.concat({"C", enc(c.name), enc(c.race), enc(c.class), c.raceID or "", c.sexID or "", c.classID or ""}, "\t"),
        "T\t" .. enc(p.timestamp), "U\t" .. enc(p.availability)}
    local entries = {}
    for _, v in ipairs(p.appearance) do entries[#entries + 1] = v end
    table.sort(entries, function(a,b) return a.optionID < b.optionID end)
    for _, v in ipairs(entries) do
        rows[#rows + 1] = table.concat({"A", v.optionID, v.choiceID, v.index or "", enc(v.label)}, "\t")
    end
    return table.concat(rows, "\n")
end
function D.Decode(text)
    if type(text) ~= "string" or #text > MAX then return nil, "Input exceeds 65536 bytes" end
    local ok, result = pcall(function()
        text = text:gsub("\r\n", "\n")
        local p = {schemaVersion=1, appearance={}}
        local seen, fields = {}, {}
        local lineNumber = 0
        for line in (text .. "\n"):gmatch("(.-)\n") do
            lineNumber = lineNumber + 1
            if lineNumber == 1 then
                if line ~= "CDNA1" then error("Unsupported schema: expected CDNA1") end
            elseif line ~= "" then
                local a = {}
                for value in (line .. "\t"):gmatch("(.-)\t") do a[#a+1] = value end
                local tag = a[1]
                local counts = {N=2,S=6,C=7,T=2,U=2,A=5}
                if not counts[tag] or #a ~= counts[tag] then error("Malformed record on line " .. lineNumber) end
                if tag ~= "A" then
                    if fields[tag] then error("Duplicate " .. tag .. " record") end
                    fields[tag] = true
                end
                if tag == "N" then p.name = dec(a[2])
                elseif tag == "S" then p.source = {game=dec(a[2]),build=dec(a[3]),api=dec(a[4]),version=dec(a[5]),interface=dec(a[6])}
                elseif tag == "C" then p.character = {name=dec(a[2]),race=dec(a[3]),class=dec(a[4]),raceID=integer(a[5],"raceID",true),sexID=integer(a[6],"sexID",true),classID=integer(a[7],"classID",true)}
                elseif tag == "T" then p.timestamp = dec(a[2])
                elseif tag == "U" then p.availability = dec(a[2])
                elseif tag == "A" then
                    local id = integer(a[2], "optionID")
                    if seen[id] then error("Duplicate optionID " .. id) end
                    seen[id] = true
                    if #p.appearance >= 256 then error("More than 256 appearance entries") end
                    p.appearance[#p.appearance+1] = {optionID=id,choiceID=integer(a[3],"choiceID"),index=integer(a[4],"index",true),label=dec(a[5])}
                end
            end
        end
        for _, tag in ipairs({"N","S","C","T","U"}) do if not fields[tag] then error("Missing " .. tag .. " record") end end
        if #p.name < 1 or #p.name > 120 or not p.name:find("%S") or p.name:find("%c") then error("Profile name must be 1-120 bytes without control characters") end
        return p
    end)
    if not ok then return nil, tostring(result):gsub("^.-:%d+: ", "") end
    return result
end
