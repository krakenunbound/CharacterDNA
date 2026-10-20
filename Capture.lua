local _, D = ...
function D.PreviewSexID()
    local api=C_BarberShop
    if type(api)~="table" or type(api.GetCurrentCharacterData)~="function" then return nil end
    local ok,data=pcall(api.GetCurrentCharacterData)
    local _,raceFile=D.Call(UnitRace,"player")
    local enums=Enum and Enum.UnitSex
    if not ok or type(data)~="table" or type(raceFile)~="string" or data.fileName~=raceFile
        or not enums or type(enums.Male)~="number" or type(enums.Female)~="number" or enums.Male==enums.Female then return nil end
    if data.sex==enums.Male then return 2,data.sex end
    if data.sex==enums.Female then return 3,data.sex end
end
function D.IdentityProfile(name)
    local race, _, raceID = D.Call(UnitRace, "player")
    local class, _, classID = D.Call(UnitClass, "player")
    local version, build, _, interface = D.Call(GetBuildInfo)
    local stamp = D.Call(date, "!%Y-%m-%dT%H:%M:%SZ") or D.Call(date, "%Y-%m-%d %H:%M:%S local") or "unavailable"
    return {schemaVersion=1,name=name, timestamp=stamp,
        source={game="WoW Forever",version=version or "unavailable",build=build or "unavailable",interface=interface or "unavailable",api="unavailable: no verified capture adapter"},
        character={name=D.Call(UnitName,"player"),race=race,raceID=raceID,class=class,classID=classID,sexID=D.Call(UnitSex,"player")},
        appearance={},availability="Appearance unavailable; character metadata only"}
end
local function id(value)
    return type(value)=="number" and value >= 0 and value <= 2147483647 and value == math.floor(value)
end
function D.ReadAppearance(categories)
    local version, build, _, interface = D.Call(GetBuildInfo)
    if version ~= "1.60.1" or tostring(build) ~= "70450" or interface ~= 16001 then
        return {}, "Unsupported client build; appearance reader disabled"
    end
    if type(categories) ~= "table" then return {}, "Customization categories unavailable" end
    local entries, errors, seen = {}, {}, {}
    for _, category in ipairs(categories) do
        if type(category) ~= "table" or type(category.options) ~= "table" then
            errors[#errors+1] = "Category has no options table"
        else
            for _, option in ipairs(category.options) do
                local label = type(option)=="table" and type(option.name)=="string" and option.name or "Unlabeled option"
                local index = type(option)=="table" and option.currentChoiceIndex
                local choices = type(option)=="table" and option.choices
                -- The matching shared UI schema calls this a luaIndex. Never offset it
                -- or substitute the option index for an ID; validate the actual record.
                local choice = id(index) and index >= 1 and type(choices)=="table" and choices[0]==nil and choices[index]
                if type(option) ~= "table" or not id(option.id) then
                    errors[#errors+1] = label .. ": invalid option ID"
                elseif seen[option.id] then
                    return {}, "Duplicate option ID; capture rejected"
                elseif type(choice) ~= "table" or not id(choice.id) then
                    errors[#errors+1] = label .. ": selected choice ID unavailable (index=" .. tostring(index) .. ")"
                else
                    seen[option.id] = true
                    entries[#entries+1] = {optionID=option.id,choiceID=choice.id,index=index,label=label}
                    if #entries > 256 then return {}, "More than 256 options; capture rejected" end
                end
            end
        end
    end
    table.sort(entries,function(a,b) return a.optionID < b.optionID end)
    local status = #entries .. " appearance selections captured"
    if #entries == 0 then status = "Appearance unavailable; no validated selected choice records" end
    if #errors > 0 then status = status .. "; " .. table.concat(errors,"; ") end
    return entries, status
end
function D.CaptureFromData(name, categories)
    local p = D.IdentityProfile(name)
    if D.atBarber then p.character.sexID=D.PreviewSexID() end
    p.appearance, p.availability = D.ReadAppearance(categories)
    if D.atBarber and not p.character.sexID then p.availability=p.availability .. "; preview body unavailable" end
    if #p.appearance > 0 then
        p.source.api = "C_BarberShop.GetAvailableCustomizations: option.id + choices[currentChoiceIndex].id (luaIndex); barber preview; body from GetCurrentCharacterData, other identity from Unit APIs"
    end
    return p
end
function D.RememberCapture(categories)
    local p = D.CaptureFromData("Last barber capture",categories)
    -- A failed/new empty read must not cause an old snapshot to look current.
    D.lastCapture = p
    if not D.storageError and type(CharacterDNADB)=="table" then CharacterDNADB.lastCapture = p end
    return p
end
function D.RefreshCapture()
    if not D.atBarber then return end
    if type(C_BarberShop)=="table" and type(C_BarberShop.GetAvailableCustomizations)=="function" then
        local ok, categories = pcall(C_BarberShop.GetAvailableCustomizations)
        return D.RememberCapture(ok and categories or nil)
    end
    return D.RememberCapture(nil)
end
function D.Capture(name)
    local p = D.atBarber and D.RefreshCapture() or nil
    if not p then
        local saved = D.lastCapture or (not D.storageError and CharacterDNADB and CharacterDNADB.lastCapture)
        local current = D.IdentityProfile(name)
        if type(saved)=="table" and type(saved.character)=="table" and type(saved.source)=="table"
            and saved.character.name==current.character.name and saved.character.raceID==current.character.raceID
            and saved.character.classID==current.character.classID
            and tostring(saved.source.build)==tostring(current.source.build) then
            p = D.Decode(D.Encode(saved))
        end
        p = p or current
    end
    local copy = D.Decode(D.Encode(p)) or p
    copy.name = name
    return copy
end
function D.StartCaptureTracking()
    if D.captureTicker then D.captureTicker:Cancel(); D.captureTicker=nil end
    if C_Timer and type(C_Timer.NewTicker)=="function" then
        D.captureTicker = C_Timer.NewTicker(1,function() if D.atBarber then D.Scan(true) end end)
    end
end
function D.StopCaptureTracking()
    if D.captureTicker then D.captureTicker:Cancel(); D.captureTicker=nil end
end
function D.Manual(text, name)
    if #text > 32768 then return nil, "Manual input exceeds 32768 bytes" end
    local p = D.IdentityProfile(name)
    if D.atBarber then p.character.sexID=D.PreviewSexID() end
    for line in (text .. "\n"):gmatch("(.-)\n") do
        if line:find("%S") then
            local option, choice, label = line:match("^%s*(%d+)%s+(%d+)%s*(.-)%s*$")
            if not option then return nil, "Use one optionID choiceID label per line; numeric IDs only." end
            p.appearance[#p.appearance+1] = {optionID=tonumber(option),choiceID=tonumber(choice),label=label}
        end
    end
    if #p.appearance == 0 then return nil, "Enter at least one optionID choiceID pair." end
    p.source.api = "manual: user-supplied IDs, unverified"
    p.availability = "Manual IDs; not verified against the client"
    return D.Decode(D.Encode(p))
end
