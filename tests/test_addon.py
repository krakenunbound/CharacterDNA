"""Offline Lua integration checks. Run with Python and lupa installed."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
scripts = {}
timers = {}
C_Timer = {After=function(_,fn) timers[#timers+1]=fn end}
tickers = {}
C_Timer.NewTicker = function(_,fn)
    local ticker = {callback=fn,Cancel=function(self) self.cancelled=true end}
    tickers[#tickers+1]=ticker
    return ticker
end
function flushTimers() local pending=timers; timers={}; for _,fn in ipairs(pending) do fn() end end
SlashCmdList = {}; UISpecialFrames = {}; UIParent = {}
DEFAULT_CHAT_FRAME = {AddMessage=function() end}
local widget = {}
function widget:SetScript(event, fn) self.scripts = rawget(self,"scripts") or {}; self.scripts[event] = fn end
function widget:SetText(s) self.text = s; local handlers=rawget(self,"scripts"); if handlers and handlers.OnTextChanged then handlers.OnTextChanged(self) end end
function widget:GetText() return rawget(self,"text") or "" end
function widget:GetStringHeight() return 30 end
function widget:GetEffectiveScale() return 1 end
function widget:GetWidth() return 140 end
function widget:GetHeight() return 140 end
function widget:SetParent(parent) self.parent = parent end
function widget:GetParent() return rawget(self,"parent") end
function widget:SetPoint(...) self.point = {...} end
function widget:SetFrameStrata(value) self.strata = value end
function widget:Show() self.visible = true end
function widget:Hide() self.visible = false end
function widget:IsShown() return rawget(self,"visible") ~= false end
function widget:IsVisible() local parent=self:GetParent(); return self:IsShown() and (not parent or parent:IsVisible()) end
function widget:CreateTexture() return setmetatable({}, {__index=widget}) end
function widget:CreateFontString() return setmetatable({}, {__index=widget}) end
setmetatable(widget, {__index=function() return function() end end})
setmetatable(UIParent,{__index=widget})
Minimap = setmetatable({parent=UIParent},{__index=widget})
function CreateFrame(kind, name, parent, template)
    local frame = setmetatable({parent=parent}, {__index=widget})
    if name then _G[name] = frame end
    scripts[#scripts+1] = frame
    return frame
end
function GetBuildInfo() return "1.60.1", "70450", "test", 16001 end
function UnitRace() return "Human", "Human", 1 end
function UnitClass() return "Mage", "MAGE", 8 end
function UnitSex() return 3 end
function UnitName() return "Example" end
function date() return "2026-10-20T12:00:00Z" end
D = {}
''')
for filename in (root / 'CharacterDNA.toc').read_text().splitlines():
    if filename.endswith('.lua'):
        lua.execute('assert(loadstring(...))("CharacterDNA", D)', (root / filename).read_text())
lua.execute(r'''
local function reject(text, needle)
    local value, err = D.Decode(text)
    assert(value == nil and err:find(needle,1,true), tostring(err))
end
D.InitStorage()
scripts[1].scripts.OnEvent(nil,"ADDON_LOADED","CharacterDNA")
local launcher = D.launcher
assert(launcher and launcher:IsShown())
assert(launcher.point[1] == "CENTER" and launcher.point[2] == Minimap)
assert(math.abs(launcher.point[4]^2+launcher.point[5]^2-75^2) < 0.001)
scripts[1].scripts.OnEvent(nil,"PLAYER_ENTERING_WORLD")
assert(D.launcher == launcher)
launcher.scripts.OnClick(launcher,"LeftButton")
assert(CharacterDNAFrame:IsShown())
launcher.scripts.OnClick(launcher,"LeftButton")
assert(not CharacterDNAFrame:IsShown())
launcher.scripts.OnClick(launcher,"LeftButton")
assert(CharacterDNAFrame:IsShown())
launcher.scripts.OnClick(launcher,"RightButton")
assert(D.diagnostics and CharacterDNAFrame:IsShown())
local p, err = D.Manual("0 0 None\n101 203 Hair % café 龙", "UTF-8 café 龙")
assert(p, err)
p.appearance[2].index = 0
local encoded = D.Encode(p)
local decoded = assert(D.Decode(encoded))
assert(D.Encode(decoded) == encoded)
assert(decoded.appearance[1].optionID == 0 and decoded.appearance[1].choiceID == 0)
assert(decoded.appearance[2].choiceID == 203 and decoded.appearance[2].index == 0)
assert(decoded.name == p.name and decoded.appearance[2].label == p.appearance[2].label)
assert(D.Save(p))
assert(not D.Save(p))
decoded.name = "Renamed"
assert(D.Save(decoded,p.name))
assert(D.Profiles()[p.name] == nil and D.Profiles().Renamed)
reject(encoded:gsub("CDNA1", "CDNA2"), "Unsupported schema")
reject(encoded .. "\nA\t101\t999\t\tduplicate", "Duplicate optionID")
reject(encoded .. "\nA\t5\t-1\t\tbad", "choiceID must")
reject(encoded .. "\nA\t2147483648\t1\t\tbad", "out of range")
reject(encoded .. "\nN\tduplicate", "Duplicate N")
reject(encoded:gsub("N\t[^\n]+", "N\t%%ZZ"), "Invalid percent")
reject(encoded:gsub("\nT\t[^\n]+", ""), "Missing T")
reject(string.rep("x",65537), "exceeds")
assert(not D.Manual("1 2\n1 3", "Duplicate"))
assert(not D.Manual("-1 2", "Bad"))
assert(not D.Manual("", "Empty"))
local many = {}
for i=1,257 do many[#many+1] = i .. " 1" end
assert(not D.Manual(table.concat(many,"\n"), "Many"))
local metadata = D.Capture("Metadata")
assert(#metadata.appearance == 0 and metadata.character.sexID == 3)
assert(tostring(metadata.source.interface) == "16001")
assert(D.Save(metadata))
local saved = CharacterDNADB
D.InitStorage(); assert(CharacterDNADB == saved and D.Profiles().Metadata)
local count = 0
local function setter() error("MUTATION CALLED") end
C_BarberShop = {
    GetAvailableCustomizations=function() count=count+1; return {{id=1,choices={{id=2}}}} end,
    SetCustomizationChoice=setter,
    GetCustomizationChoices=setter
}
assert(D.Scan():find("Capture adapter",1,true)); assert(count == 0)
CharacterDNAFrame:Hide()
scripts[1].scripts.OnEvent(nil,"BARBER_SHOP_OPEN")
UIParent:Hide()
assert(not launcher:IsVisible(), "minimap launcher must inherit hidden UIParent")
assert(D.barberButton:IsVisible(), "barber button must remain visible")
assert(not CharacterDNAFrame:IsShown(), "background scan must not open the panel")
-- Open the panel without manually running a scan.
D.ShowUI()
assert(CharacterDNAFrame:IsVisible(), "DNA panel must remain visible")
assert(CharacterDNAFrame:GetParent() == CharacterDNABarberOverlay)
assert(CharacterDNABarberOverlay:GetParent() == nil)
assert(CharacterDNAFrame.strata == "FULLSCREEN_DIALOG")
assert(count == 0)
flushTimers()
assert(count == 1 and D.lastBarberScan:find("id=2",1,true))
assert(CharacterDNADB.lastBarberScan == D.lastBarberScan)
assert(D.Scan():find("id=2",1,true)); assert(count == 2)
scripts[1].scripts.OnEvent(nil,"BARBER_SHOP_CUSTOMIZATION_CHANGED")
scripts[1].scripts.OnEvent(nil,"BARBER_SHOP_CUSTOMIZATION_CHANGED")
assert(#timers == 1)
flushTimers(); assert(count == 3)
scripts[1].scripts.OnEvent(nil,"BARBER_SHOP_CLOSE")
assert(tickers[#tickers].cancelled and D.captureTicker == nil)
UIParent:Show()
assert(not D.barberButton:IsVisible())
assert(CharacterDNAFrame:GetParent() == UIParent and CharacterDNAFrame.strata == "DIALOG")
local lastBarberScan = D.lastBarberScan
D.Scan(); assert(count == 3 and D.lastBarberScan == lastBarberScan)
D.lastBarberScan = nil
D.ShowLastScan() -- Falls back to SavedVariables after reload.
scripts[1].scripts.OnEvent(nil,"BARBER_SHOP_OPEN")
scripts[1].scripts.OnEvent(nil,"BARBER_SHOP_CLOSE")
flushTimers(); assert(count == 3) -- No read after leaving before the delayed scan.
D.atBarber = true
C_BarberShop.GetAvailableCustomizations=function() error("test read failure") end
assert(D.Scan():find("success=false",1,true))
D.ShowUI(); D.ShowText(encoded,"Test"); D.selected="Renamed"; D.ExportSelected()
SlashCmdList.CHARACTERDNA("scan")
SlashCmdList.CHARACTERDNA("export")
-- Forever's observed category/options shape, with nested choice IDs.
local raw = {
    {id=74,name="Main",options={
        {id=14,name="Skin Color",currentChoiceIndex=2,choices={{id=501},{id=777}}},
        {id=16,name="Hair Style",currentChoiceIndex=1,choices={{id=901},{id=902}}},
    }},
    {id=75,name="Appearance",options={
        {id=501,name="Piercings",currentChoiceIndex=1,choices={{id=1200}}},
    }},
}
local captured = D.CaptureFromData("Real shape",raw)
assert(#captured.appearance == 3 and captured.appearance[1].choiceID == 777)
assert(captured.appearance[1].index == 2 and captured.appearance[2].optionID == 16)
local round = assert(D.Decode(D.Encode(captured)))
assert(round.appearance[3].choiceID == 1200)
local seenReads = 0
C_BarberShop.GetAvailableCustomizations=function() seenReads=seenReads+1; return raw end
scripts[1].scripts.OnEvent(nil,"BARBER_SHOP_OPEN")
flushTimers()
assert(#D.lastCapture.appearance == 3)
raw[1].options[1].currentChoiceIndex=1
tickers[#tickers].callback()
assert(D.lastCapture.appearance[1].choiceID == 501)
scripts[1].scripts.OnEvent(nil,"BARBER_SHOP_CLOSE")
local before=seenReads
local snapshot=D.Capture("Saved after leaving")
assert(#snapshot.appearance == 3 and seenReads == before)
assert(snapshot.name == "Saved after leaving" and D.lastCapture.name == "Last barber capture")
D.lastCapture=nil
assert(#D.Capture("After reload").appearance == 3)
local oldName=UnitName
UnitName=function() return "Different character" end
assert(#D.Capture("Alt").appearance == 0)
UnitName=oldName
assert(not D.Save(D.Capture("")))
local manual=assert(D.Manual("2 3 Test", "Manual after capture"))
assert(#manual.appearance==1 and manual.appearance[1].optionID==2)
raw[1].options[1].currentChoiceIndex=0
local partial=D.CaptureFromData("Zero index",raw)
assert(#partial.appearance==2 and partial.availability:find("Skin Color",1,true))
raw[1].options[1].currentChoiceIndex=2
raw[1].options[1].choices[2].id=nil
assert(#D.CaptureFromData("Missing ID",raw).appearance==2)
raw[1].options[1].choices[2].id=777
raw[2].options[1].id=14
assert(#D.CaptureFromData("Duplicate IDs",raw).appearance==0)
local oldBuild=GetBuildInfo
GetBuildInfo=function() return "1.60.1","99999","test",16001 end
assert(#D.CaptureFromData("Unknown build",raw).appearance==0)
GetBuildInfo=oldBuild
-- Profile picker loads the chosen saved record and remembers it across init.
local function findButton(text,parent)
    for _,frame in ipairs(scripts) do
        if rawget(frame,"text")==text and (not parent or frame:GetParent()==parent) then return frame end
    end
    error("Button not found: " .. text)
end
D.LoadProfile("Renamed")
assert(D.selected=="Renamed" and CharacterDNADB.lastSelected=="Renamed")
D.selected=nil
D.InitStorage()
assert(D.selected=="Renamed")
for i=1,8 do
    local fixture=assert(D.Decode(D.Encode(captured)))
    fixture.name="Picker " .. i
    assert(D.Save(fixture))
end
D.LoadProfile("Metadata")
findButton("Saved profile: Metadata  v").scripts.OnClick()
assert(CharacterDNAProfileList:IsShown())
local row=findButton("Picker 1",CharacterDNAProfileList)
row.scripts.OnClick(row)
assert(D.selected=="Picker 1" and CharacterDNADB.lastSelected=="Picker 1")
assert(not CharacterDNAProfileList:IsShown())
findButton("Saved profile: Picker 1  v").scripts.OnClick()
findButton("Next page",CharacterDNAProfileList).scripts.OnClick()
row=findButton("Picker 8",CharacterDNAProfileList)
row.scripts.OnClick(row)
assert(D.selected=="Picker 8")
findButton("Load profile").scripts.OnClick()
assert(D.selected=="Picker 8")
assert(not D.SelectProfile("Nonexistent"))
assert(D.selected=="Picker 8")
local renamed=assert(D.Decode(D.Encode(D.Profiles()[D.selected])))
renamed.name="Picker renamed"
assert(D.Save(renamed,D.selected))
D.selected=nil; D.InitStorage()
assert(D.selected=="Picker renamed")
CharacterDNADB.profiles[D.selected]=nil
D.InitStorage()
assert(D.selected and D.Profiles()[D.selected])
-- Unsupported saved data is preserved and writes fail closed.
CharacterDNADB = {schemaVersion=99, profiles={keep=true}}
D.InitStorage(); assert(D.storageError and not D.Save(metadata))
assert(CharacterDNADB.schemaVersion == 99 and CharacterDNADB.profiles.keep)
''')
print('PASS: profile picker/paging/load, persisted selection/rename/fallback, Lua 5.1 load, minimap/barber UI, automatic scans, capture IDs, round trip, validation, storage.')
