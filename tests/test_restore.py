"""Preview integration tests; all WoW APIs are mocks, no game actions."""
from test_addon import lua

lua.execute(r'''
CharacterDNADB=nil; D.storageError=nil; D.InitStorage()
Enum={UnitSex={Male=0,Female=1}}
local raw, target, calls, commits, refreshes, behavior
BarberShopFrame=CreateFrame("Frame","BarberShopFrame",UIParent)
function BarberShopFrame:UpdateCharCustomizationFrame(reset,keepCamera)
    assert(reset==false and keepCamera==true)
    refreshes=refreshes+1
end
local function setup()
    calls,commits,refreshes=0,0,0
    behavior=nil
    raw={{id=74,options={}}}
    target=D.IdentityProfile("Apply fixture")
    for i=1,9 do
        raw[1].options[i]={id=100+i,name="Option " .. i,currentChoiceIndex=1,
            choices={{id=1000+i,isLocked=false,ineligibleChoice=false},{id=2000+i,isLocked=false,ineligibleChoice=false}}}
        target.appearance[i]={optionID=100+i,choiceID=2000+i,label="Option " .. i,index=2}
    end
    assert(D.Save(target,"Apply fixture"))
    D.atBarber=true
    BarberShopFrame:Show()
    C_BarberShop={
        GetCurrentCharacterData=function() return {fileName="Human",sex=1} end,
        IsViewingAlteredForm=function() return false end,
        GetViewingChrModel=function() return nil end,
        GetAvailableCustomizations=function() return raw end,
        ApplyCustomizationChoices=function() commits=commits+1; error("MUST NOT COMMIT") end,
        SetCustomizationChoice=function(optionID,choiceID)
            calls=calls+1
            if behavior then return behavior(optionID,choiceID) end
            local option=raw[1].options[optionID-100]
            assert(option.id==optionID and option.choices[2].id==choiceID)
            option.currentChoiceIndex=2
        end,
    }
    D.ClearApplyPreview()
end
local function confirm()
    for _,frame in ipairs(scripts) do
        if rawget(frame,"text")=="Confirm preview" then
            assert(frame:IsShown(),"Confirmation must be visible")
            frame.scripts.OnClick(frame)
            return
        end
    end
    error("Confirm preview button missing")
end
setup()
D.BeginApply()
assert(D.pendingApply and D.pendingApply.changes==9 and calls==0)
confirm()
assert(calls==9 and commits==0 and refreshes==1)
assert(not CharacterDNAFrame:IsShown())
local plan=assert(D.MakeApplyPlan(D.Profiles()[D.selected]))
assert(plan.changes==0)
D.BeginApply(); assert(D.pendingApply==nil and calls==9)
-- Load, import/save, scanning and polling never invoke the setter.
setup(); D.LoadProfile(D.selected); D.Scan(true)
assert(D.Save(target,"Apply fixture"))
assert(calls==0 and commits==0)
-- Every compatibility gate fails before mutation.
setup(); D.atBarber=false
assert(not D.MakeApplyPlan(target) and calls==0)
setup(); BarberShopFrame:Hide()
assert(not D.MakeApplyPlan(target) and calls==0)
setup(); target.character.raceID=2
assert(not D.MakeApplyPlan(target) and calls==0)
setup(); target.character.sexID=2
assert(not D.MakeApplyPlan(target) and calls==0)
setup(); target.source.build="99999"
assert(not D.MakeApplyPlan(target) and calls==0)
setup(); target.appearance={}
assert(not D.MakeApplyPlan(target) and calls==0)
setup(); C_BarberShop.GetCurrentCharacterData=function() return {fileName="Human",sex=0} end
assert(not D.MakeApplyPlan(target) and calls==0)
setup(); C_BarberShop.IsViewingAlteredForm=function() return true end
assert(not D.MakeApplyPlan(target) and calls==0)
setup(); C_BarberShop.GetViewingChrModel=function() return 123 end
assert(not D.MakeApplyPlan(target) and calls==0)
setup(); C_BarberShop.SetCustomizationChoice=nil
assert(not D.MakeApplyPlan(target))
-- Missing, locked and ineligible targets block the entire operation.
for _,flag in ipairs({"isLocked","ineligibleChoice"}) do
    setup(); raw[1].options[5].choices[2][flag]=true
    D.BeginApply(); assert(D.pendingApply==nil and calls==0)
end
setup(); raw[1].options[5].choices[2].id=99999
D.BeginApply(); assert(D.pendingApply==nil and calls==0)
setup(); raw[1].options[5].choices[2].isLocked=nil
D.BeginApply(); assert(D.pendingApply==nil and calls==0)
-- Reject stale confirmations without any setters.
setup(); D.BeginApply(); raw[1].options[1].currentChoiceIndex=2
confirm(); assert(calls==0 and commits==0)
setup(); D.BeginApply(); D.Profiles()[D.selected].appearance[1].choiceID=1001
confirm(); assert(calls==0 and commits==0)
setup(); D.BeginApply(); D.atBarber=false
confirm(); assert(calls==0 and commits==0)
-- A protected/rejected API stops immediately; no secure-call fallback/commit.
setup(); behavior=function() error("protected call blocked") end
D.BeginApply(); confirm(); assert(calls==1 and commits==0)
-- Partial failure stops further setters and leaves finalization to the user.
setup(); behavior=function(optionID)
    if calls==2 then error("test refusal") end
    raw[1].options[optionID-100].currentChoiceIndex=2
end
D.BeginApply(); confirm(); assert(calls==2 and commits==0)
-- A silent no-op is detected by post-apply verification.
setup(); behavior=function() return nil end
D.BeginApply(); local pending=D.pendingApply
local ok,message=D.ApplyPlan(pending)
assert(not ok and message:find("did not retain",1,true) and commits==0)
-- Dependencies can invalidate later choices; don't continue blindly.
setup(); behavior=function(optionID)
    raw[1].options[optionID-100].currentChoiceIndex=2
    raw[1].options[2].choices[2].isLocked=true
end
D.BeginApply(); confirm(); assert(calls==1 and commits==0)
D.atBarber=false; D.ClearApplyPreview()
''')
print('PASS: nine-choice preview/verification, zero commits, compatibility/eligibility gates, stale confirmation, protected-call rejection, partial/dependency failures, no automatic application.')
