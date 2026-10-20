local _, D = ...
local ui
local barberRoot
function D.PositionBarberButton()
    local b=D.barberButton
    if not b then return end
    local choices=CharCustomizeFrame and CharCustomizeFrame.CustomizeOptionsContainerFrame
    b:ClearAllPoints()
    if choices then
        b:SetPoint("BOTTOM",choices,"TOP",0,10)
    else
        b:SetPoint("TOPRIGHT",barberRoot,"TOPRIGHT",-20,-80)
    end
end
local function panelParent()
    if not ui then return end
    ui:SetParent(D.atBarber and barberRoot or UIParent)
    ui:SetFrameStrata(D.atBarber and "FULLSCREEN_DIALOG" or "DIALOG")
end
function D.SetBarberUI(open)
    if open and not barberRoot then
        barberRoot = CreateFrame("Frame", "CharacterDNABarberOverlay")
        -- UIParent is hidden in the barber shop; this must be an independent root.
        barberRoot:SetParent(nil)
        barberRoot:SetScale(UIParent:GetEffectiveScale())
        barberRoot:SetAllPoints(UIParent)
        barberRoot:SetFrameStrata("FULLSCREEN_DIALOG")
        local b = CreateFrame("Button",nil,barberRoot,"UIPanelButtonTemplate")
        b:SetSize(170,28)
        b:SetText("Character DNA / Scan")
        b:SetScript("OnClick",function() D.ShowText(D.Scan(),"Barber diagnostics: Ctrl+A, Ctrl+C") end)
        D.barberButton = b
    end
    if open then D.PositionBarberButton() end
    panelParent()
    if barberRoot then if open then barberRoot:Show() else barberRoot:Hide() end end
end
function D.ShowLastScan()
    local saved = not D.storageError and CharacterDNADB and CharacterDNADB.lastBarberScan
    D.ShowText(D.lastBarberScan or saved or D.diagnostics or "No barber scan yet. Enter the barber shop to scan automatically.","Last barber scan: Ctrl+A, Ctrl+C to copy")
end
function D.ToggleUI()
    if ui and ui:IsShown() then ui:Hide() else D.ShowUI() end
end
function D.CreateLauncher()
    if D.launcher then return end
    local launcher = CreateFrame("Button", "CharacterDNAMinimapButton", Minimap or UIParent)
    launcher:SetSize(31,31)
    local function position()
        launcher:ClearAllPoints()
        if Minimap then
            local angle = math.rad(225)
            launcher:SetPoint("CENTER",Minimap,"CENTER",math.cos(angle)*(Minimap:GetWidth()/2+5),math.sin(angle)*(Minimap:GetHeight()/2+5))
        else launcher:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -28, -180) end
    end
    position()
    if Minimap then Minimap:HookScript("OnSizeChanged",position) end
    launcher:SetFrameStrata("MEDIUM")
    launcher:SetFrameLevel(8)
    launcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local background = launcher:CreateTexture(nil,"BACKGROUND")
    background:SetSize(20,20); background:SetPoint("TOPLEFT",7,-5)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local icon = launcher:CreateTexture(nil,"ARTWORK")
    icon:SetSize(17,17); icon:SetPoint("TOPLEFT",7,-6)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    local border = launcher:CreateTexture(nil,"OVERLAY")
    border:SetSize(53,53); border:SetPoint("TOPLEFT",0,0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    launcher:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
    launcher:SetScript("OnClick",function(_, mouseButton)
        if mouseButton == "RightButton" then D.ShowText(D.Scan(),"Runtime diagnostics")
        else D.ToggleUI() end
    end)
    launcher:SetScript("OnEnter",function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self,"ANCHOR_LEFT")
        GameTooltip:SetText("Character DNA")
        GameTooltip:AddLine("Left-click: open saved appearances",1,1,1)
        GameTooltip:AddLine("Right-click: scan available APIs",1,1,1)
        GameTooltip:Show()
    end)
    launcher:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    launcher:Show()
    D.launcher = launcher
end
local function button(parent, label, x, y, action, width)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 110, 24); b:SetPoint("TOPLEFT", x, y); b:SetText(label)
    b:SetScript("OnClick", action)
    return b
end
function D.ShowText(text, title)
    D.ShowUI()
    D.ClearApplyPreview()
    ui.status:SetText(title or "Character DNA")
    ui.text:SetText(text or "")
    ui.text:HighlightText(); ui.text:SetFocus()
    ui.scroll:SetVerticalScroll(0)
end
function D.ClearApplyPreview()
    D.pendingApply=nil
    D.bodyReviewToken=nil
    if ui and ui.confirmApply then ui.confirmApply:Hide() end
end
function D.BeginApply()
    local plan,err=D.MakeApplyPlan(D.Profiles()[D.selected])
    if not plan then D.ShowText(err,"Cannot apply profile"); return end
    D.ShowText(D.FormatApplyPlan(plan),"Review profile preview")
    if #plan.blocked==0 and plan.changes>0 then
        D.pendingApply=plan
        ui.confirmApply:Show()
    end
end
function D.Refresh()
    local names = D.Names()
    ui.picker:SetText(D.selected and ("Saved profile: " .. D.selected .. "  v") or "Choose a saved profile  v")
    ui.count:SetText(tostring(#names) .. " saved profiles. Click the profile picker to choose one.")
    if ui.profileList:IsShown() then D.RefreshProfileList() end
end
function D.ExportSelected()
    local p = D.Profiles()[D.selected]
    if not p then D.ShowLastScan(); return end
    D.ShowText(D.Encode(p), "Export: Ctrl+A, Ctrl+C to copy")
end
local function inspect()
    local p = D.Profiles()[D.selected]
    if not p then D.Print("No saved profile selected."); return end
    ui.name:SetText(p.name)
    local c = p.character
    local rows = {p.name, "Character: " .. (c.name or "unavailable"),
        "Race: " .. (c.race or "unavailable") .. " ID=" .. tostring(c.raceID),
        "Saved body: " .. (c.sexID==2 and "Male" or c.sexID==3 and "Female" or "unavailable") .. " (UnitSex code " .. tostring(c.sexID) .. ")",
        "Class: " .. (c.class or "unavailable") .. " ID=" .. tostring(c.classID),
        "Build: " .. tostring(p.source.build), "Captured: " .. p.timestamp,
        "Source: " .. p.source.api, p.availability, ""}
    for _, v in ipairs(p.appearance) do rows[#rows+1] = string.format("%s: optionID=%d choiceID=%d index=%s", v.label ~= "" and v.label or "Unlabeled", v.optionID, v.choiceID, tostring(v.index)) end
    rows[#rows+1] = "\nOptions absent from this profile are unavailable; no values are inferred."
    if p.source.api:find("barber preview",1,true) then
        rows[#rows+1] = "Snapshot may include uncommitted preview choices. Older captures may need recapturing if their saved body did not match the preview."
    end
    D.ShowText(table.concat(rows,"\n"), "Saved profile (read-only)")
end
function D.LoadProfile(name)
    D.ShowUI()
    local ok, err = D.SelectProfile(name or D.selected)
    if not ok or not D.selected then D.Print(err or "No saved profiles yet."); return end
    ui.profileList:Hide()
    D.Refresh()
    inspect()
end
function D.RefreshProfileList()
    local names = D.Names()
    local pageCount = math.max(1,math.ceil(#names/6))
    ui.profilePage = math.min(ui.profilePage or 1,pageCount)
    for i,row in ipairs(ui.profileRows) do
        local name = names[(ui.profilePage-1)*6+i]
        row.profileName = name
        if name then row:SetText(name); row:Show() else row:Hide() end
    end
    ui.profilePageLabel:SetText(#names==0 and "No saved profiles" or (ui.profilePage .. " / " .. pageCount))
end
local function browse(delta)
    local names = D.Names()
    if #names == 0 then return end
    local index = delta > 0 and 0 or 1
    for i, name in ipairs(names) do if name == D.selected then index = i end end
    D.LoadProfile(names[((index + delta - 1) % #names) + 1])
end
function D.ShowUI()
    if ui then panelParent(); ui:Show(); return end
    ui = CreateFrame("Frame", "CharacterDNAFrame", UIParent)
    panelParent()
    ui:SetSize(660, 580); ui:SetPoint("CENTER")
    ui:SetMovable(true); ui:EnableMouse(true); ui:RegisterForDrag("LeftButton")
    ui:SetScript("OnDragStart", ui.StartMoving); ui:SetScript("OnDragStop", ui.StopMovingOrSizing)
    local bg = ui:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.035,0.04,0.055,0.98)
    local title = ui:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    title:SetPoint("TOPLEFT",16,-14); title:SetText("Character DNA")
    button(ui,"Close",550,-10,function() ui:Hide() end,90)
    ui.name = CreateFrame("EditBox",nil,ui,"InputBoxTemplate")
    ui.name:SetSize(360,24); ui.name:SetPoint("TOPLEFT",22,-45); ui.name:SetAutoFocus(false); ui.name:SetMaxLetters(120)
    ui.name:SetText("Appearance profile")
    button(ui,"Scan",410,-45,function() D.ShowText(D.Scan(),"Runtime diagnostics: copy with Ctrl+A, Ctrl+C") end)
    button(ui,"Last scan",530,-45,D.ShowLastScan)
    button(ui,"Save capture",16,-80,function()
        local name = ui.name:GetText()
        local replace = D.selected == name and D.selected or nil
        local ok, err = D.Save(D.Capture(name), replace)
        if not ok then D.Print(err); return end
        D.Refresh(); inspect()
    end)
    button(ui,"Rename",132,-80,function()
        local p = D.Profiles()[D.selected]
        if not p then D.Print("Select a profile first."); return end
        local copy, err = D.Decode(D.Encode(p))
        if not copy then D.Print(err); return end
        copy.name = ui.name:GetText()
        local ok; ok,err = D.Save(copy,D.selected)
        if not ok then D.Print(err); return end
        D.Refresh(); inspect()
    end)
    button(ui,"Delete",248,-80,function()
        if D.storageError then D.Print(D.storageError); return end
        if not D.selected then return end
        if ui.name:GetText() ~= D.selected then D.Print("To delete, enter the exact selected profile name, then click Delete."); return end
        D.Profiles()[D.selected] = nil; D.SelectProfile(D.Names()[1]); D.Refresh()
        D.ShowText("Profile deleted.","Deleted")
    end)
    button(ui,"Export",364,-80,D.ExportSelected)
    button(ui,"Import text",480,-80,function()
        local p, err = D.Decode(ui.text:GetText())
        if not p then D.Print("Import failed: " .. err); return end
        local ok; ok,err = D.Save(p)
        if not ok then D.Print(err); return end
        D.Refresh(); inspect()
    end,140)
    button(ui,"Previous",16,-112,function() browse(-1) end)
    button(ui,"Next",132,-112,function() browse(1) end)
    button(ui,"Inspect",248,-112,function() D.LoadProfile(D.selected) end)
    button(ui,"Manual help",364,-112,function()
        D.ShowText("", "Enter optionID choiceID label per line, then Save manual. IDs remain unverified.")
    end)
    button(ui,"Save manual",480,-112,function()
        local p, err = D.Manual(ui.text:GetText(),ui.name:GetText())
        if not p then D.Print(err); return end
        local ok; ok,err = D.Save(p)
        if not ok then D.Print(err); return end
        D.Refresh(); inspect()
    end,140)
    ui.picker = button(ui,"Choose a saved profile  v",16,-146,function()
        if ui.profileList:IsShown() then ui.profileList:Hide()
        else
            local names = D.Names()
            for i,name in ipairs(names) do if name==D.selected then ui.profilePage=math.ceil(i/6) end end
            D.RefreshProfileList(); ui.profileList:Show()
        end
    end,468)
    ui.picker:SetNormalFontObject("GameFontHighlight")
    button(ui,"Load profile",492,-146,function() D.LoadProfile(D.selected) end,148)
    ui.profileList = CreateFrame("Frame","CharacterDNAProfileList",ui)
    ui.profileList:SetSize(468,206); ui.profileList:SetPoint("TOPLEFT",ui.picker,"BOTTOMLEFT",0,-2)
    ui.profileList:SetFrameLevel(100); ui.profileList:EnableMouse(true)
    local listBG=ui.profileList:CreateTexture(nil,"BACKGROUND")
    listBG:SetAllPoints(); listBG:SetColorTexture(0.06,0.07,0.10,1)
    ui.profileRows={}
    for i=1,6 do
        local row=button(ui.profileList,"",8,-8-(i-1)*26,function(self) D.LoadProfile(self.profileName) end,452)
        ui.profileRows[i]=row
    end
    button(ui.profileList,"Previous page",8,-174,function()
        ui.profilePage=math.max(1,(ui.profilePage or 1)-1); D.RefreshProfileList()
    end,130)
    button(ui.profileList,"Next page",330,-174,function()
        ui.profilePage=(ui.profilePage or 1)+1; D.RefreshProfileList()
    end,130)
    ui.profilePageLabel=ui.profileList:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    ui.profilePageLabel:SetPoint("TOP",0,-180)
    ui.profileList:Hide()
    button(ui,"Apply profile",16,-180,D.BeginApply,152)
    ui.confirmApply=button(ui,"Confirm preview",178,-180,function()
        local plan=D.pendingApply
        D.ClearApplyPreview()
        local ok,message,stage=D.ApplyPlan(plan)
        D.ShowText(message,ok and "Profile preview set" or "Profile preview stopped")
        if ok and stage=="body" then
            local token={}
            local name=D.selected
            D.bodyReviewToken=token
            local function review()
                if D.bodyReviewToken==token and D.atBarber and D.selected==name and ui:IsShown() then D.BeginApply() end
            end
            if C_Timer and type(C_Timer.After)=="function" then C_Timer.After(0.5,review) else review() end
        elseif ok then D.Print(message); ui:Hide() end
    end,152)
    ui.confirmApply:Hide()
    local applyNote=ui:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    applyNote:SetPoint("TOPLEFT",344,-184); applyNote:SetWidth(292); applyNote:SetJustifyH("LEFT")
    applyNote:SetText("Preview only. Click WoW's Accept to finish.")
    ui.count = ui:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); ui.count:SetPoint("TOPLEFT",18,-214)
    ui.status = ui:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    ui.status:SetPoint("TOPLEFT",18,-236); ui.status:SetWidth(620); ui.status:SetJustifyH("LEFT")
    ui.scroll = CreateFrame("ScrollFrame",nil,ui,"UIPanelScrollFrameTemplate")
    ui.scroll:SetPoint("TOPLEFT",18,-266); ui.scroll:SetPoint("BOTTOMRIGHT",-36,18)
    ui.text = CreateFrame("EditBox",nil,ui.scroll)
    ui.text:SetMultiLine(true); ui.text:SetFontObject(ChatFontNormal); ui.text:SetWidth(594)
    ui.text:SetAutoFocus(false); ui.text:SetMaxLetters(65536)
    ui.text:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    ui.text:SetScript("OnTextChanged",function(self)
        -- Estimate wrapped lines without depending on FontString-only methods.
        local lines = 0
        for line in (self:GetText() .. "\n"):gmatch("(.-)\n") do
            lines = lines + math.max(1, math.ceil(#line / 65))
        end
        self:SetHeight(math.max(280,lines * 18 + 24))
    end)
    ui.scroll:SetScrollChild(ui.text)
    if UISpecialFrames then table.insert(UISpecialFrames,"CharacterDNAFrame") end
    D.Refresh()
    if D.selected then D.LoadProfile(D.selected); return end
    D.ShowText("The barber shop is scanned automatically. Enter a name and click Save capture to keep the latest snapshot.\n\nChoose a saved profile in the picker. Inside the barber shop, click Apply profile to review differences, then Confirm preview to set the selections. Review the character and click WoW's Accept yourself to finalize and pay.\n\nTo update a saved profile, select it and click Save capture with its existing name. Last scan shows diagnostics. Import and Load profile only display saved data.\n\nSnapshots may include uncommitted preview choices.","Appearance profiles")
end
