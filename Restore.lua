local _, D = ...
local function integer(n)
    return type(n)=="number" and n>=0 and n<=2147483647 and n==math.floor(n)
end
local function read(fn)
    if type(fn)~="function" then return false,"API unavailable" end
    return pcall(fn)
end
local function optionMap(categories)
    if type(categories)~="table" then return nil,"Barber customization data unavailable" end
    local map, count = {}, 0
    for _,category in ipairs(categories) do
        if type(category)~="table" or type(category.options)~="table" then return nil,"Unrecognized category data" end
        for _,option in ipairs(category.options) do
            count=count+1
            if count>256 or type(option)~="table" or not integer(option.id) or map[option.id] then return nil,"Invalid or duplicate barber option IDs" end
            local index=option.currentChoiceIndex
            if not integer(index) or index<1 or type(option.choices)~="table" or option.choices[0]~=nil then return nil,"Selected choice index unavailable" end
            local choices={}
            for _,choice in ipairs(option.choices) do
                if type(choice)~="table" or not integer(choice.id) or choices[choice.id] then return nil,"Invalid or duplicate barber choice IDs" end
                choices[choice.id]=choice
            end
            local current=option.choices[index]
            if type(current)~="table" or not integer(current.id) then return nil,"Current choice ID unavailable" end
            map[option.id]={current=current.id,choices=choices,order=count,label=option.name or tostring(option.id)}
        end
    end
    return map
end
function D.MakeApplyPlan(profile)
    if not D.atBarber then return nil,"Enter the barber shop before applying a profile." end
    if not BarberShopFrame or type(BarberShopFrame.IsShown)~="function" or not BarberShopFrame:IsShown()
        or type(BarberShopFrame.UpdateCharCustomizationFrame)~="function" then return nil,"The barber shop UI is not ready." end
    local api=C_BarberShop
    if type(api)~="table" or type(api.SetCustomizationChoice)~="function" then return nil,"The client does not expose SetCustomizationChoice." end
    local version,build,_,interface=D.Call(GetBuildInfo)
    if version~="1.60.1" or tostring(build)~="70450" or interface~=16001 then return nil,"Apply is unavailable on this unverified client build." end
    if type(profile)~="table" then return nil,"Choose a saved profile first." end
    local encodedOK,encoded=pcall(D.Encode,profile)
    if not encodedOK then return nil,"Saved profile is malformed." end
    local p,err=D.Decode(encoded)
    if not p then return nil,err end
    if p.source.version~=version or p.source.build~=tostring(build) or p.source.interface~=tostring(interface) then return nil,"Profile client/build does not match this client." end
    local _,raceFile,raceID=D.Call(UnitRace,"player")
    if not integer(raceID) or p.character.raceID~=raceID then return nil,"Profile race does not match this character." end
    local sex=p.character.sexID
    if sex~=2 and sex~=3 then return nil,"Profile body type is unavailable or unsupported. Recapture it in the barber shop." end
    local previewSex,rawSex=D.PreviewSexID()
    if not previewSex then return nil,"The current barber race/body could not be verified." end
    local expected=sex==2 and Enum.UnitSex.Male or Enum.UnitSex.Female
    local formOK,altered=read(api.IsViewingAlteredForm)
    local modelOK,model=read(api.GetViewingChrModel)
    if not formOK or altered~=false or not modelOK or model~=nil then return nil,"Apply supports the normal character form only." end
    if #p.appearance==0 then return nil,"This profile has no appearance choices to apply." end
    local plan={profile=p,entries={},changes=0,blocked={},fingerprint=encoded .. "\n" .. raceFile .. ":" .. rawSex}
    if previewSex~=sex then
        if type(api.SetSelectedSex)~="function" or type(BarberShopFrame.SetCharacterSex)~="function" then
            return nil,"The client does not expose body selection. Select the saved body manually first."
        end
        plan.bodyOnly=true
        plan.targetSex=expected
        plan.currentBody=previewSex
        plan.changes=1
        return plan
    end
    local rawOK,raw=read(api.GetAvailableCustomizations)
    if not rawOK then return nil,"Could not read barber choices: " .. tostring(raw) end
    local map; map,err=optionMap(raw)
    if not map then return nil,err end
    for _,entry in ipairs(p.appearance) do
        local option=map[entry.optionID]
        local choice=option and option.choices[entry.choiceID]
        local label=entry.label~="" and entry.label or tostring(entry.optionID)
        if not choice then
            plan.blocked[#plan.blocked+1]=label .. ": option/choice is unavailable (" .. entry.optionID .. "/" .. entry.choiceID .. ")"
        elseif choice.isLocked~=false or choice.ineligibleChoice~=false then
            plan.blocked[#plan.blocked+1]=label .. ": choice is locked, ineligible, or availability is unverified"
        else
            local row={optionID=entry.optionID,choiceID=entry.choiceID,current=option.current,label=label,order=option.order}
            plan.entries[#plan.entries+1]=row
            if row.current~=row.choiceID then plan.changes=plan.changes+1 end
        end
    end
    table.sort(plan.entries,function(a,b) return a.order<b.order end)
    for _,row in ipairs(plan.entries) do plan.fingerprint=plan.fingerprint .. "\n" .. row.optionID .. ":" .. row.current .. ":" .. row.choiceID end
    for _,reason in ipairs(plan.blocked) do plan.fingerprint=plan.fingerprint .. "\nblocked:" .. reason end
    return plan
end
function D.FormatApplyPlan(plan)
    if plan.bodyOnly then
        local function body(sex) return sex==2 and "Male" or "Female" end
        return "Profile: " .. plan.profile.name .. "\nBody: " .. body(plan.currentBody) .. " -> " .. body(plan.profile.character.sexID)
            .. "\n\nClick Confirm preview to restore the saved body first. Its appearance choices can only be checked after that body's options load."
            .. "\n\nThe addon will then show the appearance differences for a second confirmation. No changes are purchased until you click WoW's Accept."
    end
    local lines={"Profile: " .. plan.profile.name, "Changes: " .. plan.changes, ""}
    for _,row in ipairs(plan.entries) do
        lines[#lines+1]=row.label .. ": choiceID " .. row.current .. " -> " .. row.choiceID .. (row.current==row.choiceID and " (unchanged)" or "")
    end
    for _,reason in ipairs(plan.blocked) do lines[#lines+1]="Unavailable: " .. reason end
    lines[#lines+1]=""
    if #plan.blocked>0 then lines[#lines+1]="Nothing will be applied while any saved choice is unavailable."
    elseif plan.changes==0 then lines[#lines+1]="The barber selections already match this profile. Review your character and use WoW's Accept to finalize any pending barber changes."
    else lines[#lines+1]="Click Confirm preview to set these barber choices. Then review the character and click WoW's Accept yourself to confirm and pay." end
    return table.concat(lines,"\n")
end
-- Called only by the confirmation button's OnClick. Never from timers/import/load.
function D.ApplyPlan(plan)
    if type(plan)~="table" then return nil,"Click Apply profile to review the changes first." end
    if D.selected~=plan.profile.name then return nil,"The selected profile changed. Review Apply profile again." end
    local fresh,err=D.MakeApplyPlan(D.Profiles()[D.selected])
    if not fresh then return nil,err end
    if #fresh.blocked>0 then return nil,D.FormatApplyPlan(fresh) end
    if fresh.fingerprint~=plan.fingerprint then return nil,"Profile or barber choices changed. Click Apply profile again to review the updated differences." end
    if fresh.bodyOnly then
        local ok,result=pcall(BarberShopFrame.SetCharacterSex,BarberShopFrame,fresh.targetSex)
        if not ok or result==false then return nil,"Body preview rejected: " .. tostring(result) .. ". No changes were committed." end
        local uiOK,uiError=pcall(BarberShopFrame.UpdateCharCustomizationFrame,BarberShopFrame,false,true)
        if not uiOK then return nil,"Body preview was requested, but the barber UI could not refresh: " .. tostring(uiError) end
        return true,"Saved body preview requested. Waiting for its options, then review and confirm the appearance choices. No changes have been purchased.","body"
    end
    local applied=0
    local failure
    for _,row in ipairs(fresh.entries) do
        if row.current~=row.choiceID then
            -- Earlier selections may change eligibility of later choices.
            local current; current,err=D.MakeApplyPlan(fresh.profile)
            if not current or current.bodyOnly or #current.blocked>0 then failure=err or "The barber body or choice availability changed during preview."; break end
            local ok,result=pcall(C_BarberShop.SetCustomizationChoice,row.optionID,row.choiceID)
            if not ok or result==false then failure="Client rejected " .. row.label .. ": " .. tostring(result); break end
            applied=applied+1
        end
    end
    local uiOK,uiError=pcall(BarberShopFrame.UpdateCharCustomizationFrame,BarberShopFrame,false,true)
    if not uiOK then failure=failure or ("Barber UI refresh failed: " .. tostring(uiError)) end
    local final; final,err=D.MakeApplyPlan(fresh.profile)
    if not final or final.bodyOnly or #final.blocked>0 or final.changes>0 then failure=failure or err or "The client did not retain every requested choice; dependent choices may have changed." end
    D.RefreshCapture()
    if failure then return nil,failure .. "\nPreview operations completed: " .. applied .. ". No changes were committed. Review the barber choices or use WoW's Cancel." end
    return true,"Profile preview set. Review your character, then click WoW's Accept to confirm and pay."
end
