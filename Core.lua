local _, D = ...
CharacterDNA = D
D.version = "0.3.0"
function D.Print(s)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("CharacterDNA: " .. tostring(s)) end
end
function D.Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
for _, event in ipairs({"BARBER_SHOP_OPEN", "BARBER_SHOP_CLOSE", "BARBER_SHOP_APPEARANCE_APPLIED", "BARBER_SHOP_CUSTOMIZATION_CHANGED"}) do
    pcall(f.RegisterEvent, f, event)
end
f:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == "CharacterDNA" then
        D.InitStorage()
        D.CreateLauncher()
    end
    if event == "PLAYER_ENTERING_WORLD" then
        D.CreateLauncher()
        if not D.welcomed then
            D.Print("Loaded. Click the DNA button beside the minimap, or type /cdna, to open the panel.")
            D.welcomed = true
        end
    end
    if event == "BARBER_SHOP_OPEN" then
        D.atBarber = true
        D.scanNotice = nil
        D.SetBarberUI(true)
        D.StartCaptureTracking()
        D.QueueBarberScan()
    end
    if event == "BARBER_SHOP_CLOSE" then
        D.atBarber = false
        D.StopCaptureTracking()
        D.ClearApplyPreview()
        D.SetBarberUI(false)
    end
    if event == "BARBER_SHOP_CUSTOMIZATION_CHANGED" or event == "BARBER_SHOP_APPEARANCE_APPLIED" then
        D.QueueBarberScan()
    end
    if event ~= "ADDON_LOADED" then
        D.events = D.events or {}
        D.events[#D.events + 1] = event
        if #D.events > 30 then table.remove(D.events, 1) end
    end
end)
SLASH_CHARACTERDNA1 = "/cdna"
SlashCmdList.CHARACTERDNA = function(msg)
    local command = (msg or ""):match("^%s*(%S+)")
    D.ShowUI()
    if command == "scan" then D.ShowText(D.Scan(), "Runtime diagnostics")
    elseif command == "export" then D.ExportSelected()
    elseif command and command ~= "" then D.Print("Use /cdna, /cdna scan, or /cdna export.") end
end
