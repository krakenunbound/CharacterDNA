local _, D = ...
local function dump(value, depth, seen, budget)
    if budget.n <= 0 then return "<truncated>" end
    budget.n = budget.n - 1
    if type(value) ~= "table" then return tostring(value):sub(1,200) end
    if depth == 0 then return "<table>" end
    if seen[value] then return "<cycle>" end
    seen[value] = true
    local keys, rows = {}, {}
    for key in pairs(value) do
        if #keys >= 80 then break end
        keys[#keys+1] = key
    end
    table.sort(keys, function(a,b) return tostring(a)<tostring(b) end)
    for _, key in ipairs(keys) do rows[#rows+1] = tostring(key) .. "=" .. dump(value[key],depth-1,seen,budget) end
    seen[value] = nil
    return "{" .. table.concat(rows,", ") .. "}"
end
function D.QueueBarberScan()
    if not D.atBarber or D.scanQueued then return end
    D.scanQueued = true
    local function run()
        D.scanQueued = nil
        if D.atBarber then
            D.PositionBarberButton()
            D.Scan(true)
            if not D.scanNotice then
                D.Print("Barber scan saved. After leaving, open DNA and click Last scan to copy it.")
                D.scanNotice = true
            end
        end
    end
    if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(0.3, run)
    else run() end
end
function D.Scan(background)
    local version, build, _, interface = D.Call(GetBuildInfo)
    local lines = {"CharacterDNA " .. D.version, "Client: " .. tostring(version) .. " build=" .. tostring(build) .. " interface=" .. tostring(interface),
        "Barber event state: " .. tostring(D.atBarber == true), "Scanning is read-only. Preview setters run only on Confirm preview; Accept is never automated."}
    for _, namespace in ipairs({"C_BarberShop", "C_CharacterCustomization"}) do
        local api = _G[namespace]
        lines[#lines+1] = namespace .. ": " .. type(api)
        local names, listed = {}, {}
        if type(api) == "table" then for name in pairs(api) do if type(name)=="string" then names[#names+1]=name; listed[name]=true end end end
        for _, name in ipairs({"GetAvailableCustomizations","GetCustomizationChoices","SetCustomizationChoice"}) do if not listed[name] then names[#names+1]=name end end
        table.sort(names)
        for _, name in ipairs(names) do lines[#lines+1] = "  " .. name .. ": " .. type(type(api)=="table" and api[name] or nil) end
    end
    if D.atBarber and type(C_BarberShop)=="table" and type(C_BarberShop.GetAvailableCustomizations)=="function" then
        local ok, value = pcall(C_BarberShop.GetAvailableCustomizations)
        lines[#lines+1] = "GetAvailableCustomizations() success=" .. tostring(ok)
        lines[#lines+1] = dump(value, 5, {}, {n=450})
        local p = D.RememberCapture(ok and value or nil)
        lines[#lines+1] = "Capture: " .. p.availability
        if ok and type(value)=="table" then
            local count = 0
            for _, category in ipairs(value) do
                if type(category)=="table" and type(category.options)=="table" then
                    for _, option in ipairs(category.options) do
                        if type(option)=="table" and count < 256 then
                            count = count + 1
                            local index = option.currentChoiceIndex
                            local selected = type(option.choices)=="table" and type(index)=="number" and option.choices[index]
                            lines[#lines+1] = "Selected option=" .. tostring(option.id) .. " label=" .. tostring(option.name)
                                .. " currentChoiceIndex=" .. tostring(index) .. " choice=" .. dump(selected,3,{}, {n=35})
                        end
                    end
                end
            end
        end
        if type(C_BarberShop.GetCurrentCharacterData)=="function" then
            local charOK, charData = pcall(C_BarberShop.GetCurrentCharacterData)
            lines[#lines+1] = "GetCurrentCharacterData() success=" .. tostring(charOK) .. " result=" .. dump(charData,3,{}, {n=60})
        end
    else lines[#lines+1] = "Read sample unavailable. Open barber shop and scan again." end
    lines[#lines+1] = "Observed events: " .. table.concat(D.events or {}, ", ")
    lines[#lines+1] = "Capture adapter: 1.60.1/70450 only; validates numeric option.id and choices[currentChoiceIndex].id. Missing records remain unavailable."
    D.diagnostics = table.concat(lines,"\n")
    if D.atBarber then
        D.lastBarberScan = D.diagnostics
        if not D.storageError and type(CharacterDNADB)=="table" then CharacterDNADB.lastBarberScan = D.diagnostics end
    end
    if not background then D.Print("Scan complete. Copy diagnostics from the panel.") end
    return D.diagnostics
end
