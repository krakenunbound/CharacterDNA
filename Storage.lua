local _, D = ...
function D.InitStorage()
    if CharacterDNADB == nil then CharacterDNADB = {schemaVersion=1,profiles={}} end
    if type(CharacterDNADB) ~= "table" or CharacterDNADB.schemaVersion ~= 1 or type(CharacterDNADB.profiles) ~= "table" then
        D.storageError = "SavedVariables schema is unsupported; existing data was left untouched."
        D.Print(D.storageError)
        return
    end
    local last = CharacterDNADB.lastSelected
    D.selected = type(last)=="string" and CharacterDNADB.profiles[last] and last or D.Names()[1]
end
function D.SelectProfile(name)
    if name ~= nil and not D.Profiles()[name] then return nil, "Saved profile not found: " .. tostring(name) end
    D.selected = name
    if not D.storageError and CharacterDNADB then CharacterDNADB.lastSelected = name end
    return true
end
function D.Profiles()
    if D.storageError then return {} end
    return CharacterDNADB and CharacterDNADB.profiles or {}
end
function D.Save(profile, replaceName)
    if D.storageError then return nil, D.storageError end
    local valid, err = D.Decode(D.Encode(profile))
    if not valid then return nil, err end
    local profiles = D.Profiles()
    if profiles[valid.name] and valid.name ~= replaceName then return nil, "That profile name already exists; choose a new name." end
    if replaceName then profiles[replaceName] = nil end
    profiles[valid.name] = valid
    D.SelectProfile(valid.name)
    return true
end
function D.Names()
    local names = {}
    for name in pairs(D.Profiles()) do names[#names+1] = name end
    table.sort(names)
    return names
end
