"""Body-changing profile regression tests, using mocked WoW APIs only."""
from test_restore import lua

lua.execute(r'''
local raw,body,bodyCalls,choiceCalls,commits,bodyFailure
local function choices(sex)
    local categories={{id=74,options={}}}
    for i=1,9 do
        local base=sex==0 and 1000 or 3000
        categories[1].options[i]={id=100+i,name="Option " .. i,currentChoiceIndex=1,
            choices={{id=base+i,isLocked=false,ineligibleChoice=false},{id=base+1000+i,isLocked=false,ineligibleChoice=false}}}
    end
    return categories
end
local function setup()
    CharacterDNADB=nil; D.storageError=nil; D.InitStorage()
    D.atBarber=true
    body,bodyCalls,choiceCalls,commits=0,0,0,0
    bodyFailure=false
    raw=choices(body)
    C_BarberShop={
        GetCurrentCharacterData=function() return {fileName="Human",sex=body} end,
        IsViewingAlteredForm=function() return false end,
        GetViewingChrModel=function() return nil end,
        GetAvailableCustomizations=function() return raw end,
        SetSelectedSex=function(sex)
            bodyCalls=bodyCalls+1
            if bodyFailure then error("protected body setter") end
            assert(sex==0 or sex==1)
            body=sex; raw=choices(body)
        end,
        SetCustomizationChoice=function(optionID,choiceID)
            choiceCalls=choiceCalls+1
            local option=raw[1].options[optionID-100]
            assert(option.choices[2].id==choiceID)
            option.currentChoiceIndex=2
        end,
        ApplyCustomizationChoices=function() commits=commits+1; error("MUST NOT COMMIT") end,
    }
    function BarberShopFrame:SetCharacterSex(sex) C_BarberShop.SetSelectedSex(sex) end
    function BarberShopFrame:UpdateCharCustomizationFrame() end
    BarberShopFrame:Show()
    local p=D.IdentityProfile("Mira female fixture")
    assert(p.character.sexID==3) -- Logged-in character stays female in these tests.
    for i=1,9 do p.appearance[i]={optionID=100+i,choiceID=4000+i,label="Option " .. i,index=2} end
    assert(D.Save(p))
    D.ClearApplyPreview()
end
local function confirm()
    for _,frame in ipairs(scripts) do
        if rawget(frame,"text")=="Confirm preview" then
            assert(frame:IsShown())
            frame.scripts.OnClick(frame)
            return
        end
    end
    error("Confirmation not found")
end
setup()
D.BeginApply()
assert(D.pendingApply.bodyOnly and D.pendingApply.changes==1)
assert(D.FormatApplyPlan(D.pendingApply):find("Male -> Female",1,true))
assert(bodyCalls==0 and choiceCalls==0)
confirm()
assert(body==1 and bodyCalls==1 and choiceCalls==0 and commits==0)
flushTimers()
assert(D.pendingApply and not D.pendingApply.bodyOnly and D.pendingApply.changes==9)
assert(bodyCalls==1 and choiceCalls==0) -- Delayed review never applies choices.
confirm()
assert(body==1 and bodyCalls==1 and choiceCalls==9 and commits==0)
assert(not CharacterDNAFrame:IsShown())
-- Capture stores the preview body, not the logged-in female body.
setup()
local captured=D.RefreshCapture()
assert(captured.character.sexID==2 and UnitSex("player")==3)
assert(D.Decode(D.Encode(captured)).character.sexID==2)
D.atBarber=false
assert(D.Capture("Male saved after leaving").character.sexID==2)
-- A captured male profile can be restored from a female preview.
assert(D.Save(captured))
D.atBarber=true; body=1; raw=choices(body)
D.BeginApply(); assert(D.pendingApply.bodyOnly and D.pendingApply.targetSex==0)
confirm(); assert(body==0 and bodyCalls==1 and choiceCalls==0)
flushTimers(); assert(D.pendingApply==nil) -- Male choices already match snapshot.
assert(commits==0)
-- Reject stale review before any body setter.
setup(); D.BeginApply()
body=1; raw=choices(body)
confirm(); assert(bodyCalls==0 and choiceCalls==0 and commits==0)
-- A rejected body operation never continues to choice application.
setup(); bodyFailure=true; D.BeginApply(); confirm(); flushTimers()
assert(bodyCalls==1 and choiceCalls==0 and commits==0 and not D.pendingApply)
-- Closing or loading another view cancels the delayed appearance review.
setup(); D.BeginApply(); confirm()
scripts[1].scripts.OnEvent(nil,"BARBER_SHOP_CLOSE")
flushTimers(); assert(D.pendingApply==nil and choiceCalls==0)
setup(); D.BeginApply(); confirm(); D.ShowLastScan(); flushTimers()
assert(D.pendingApply==nil and choiceCalls==0)
-- Unknown preview identity cannot capture a falsely identified body.
setup(); C_BarberShop.GetCurrentCharacterData=function() return {fileName="Human",sex=99} end
assert(D.RefreshCapture().character.sexID==nil)
assert(not D.MakeApplyPlan(D.Profiles()[D.selected]))
-- Invalid/empty body profiles cannot cause a body switch.
setup(); local p=D.Profiles()[D.selected]; p.character.sexID=99
assert(not D.MakeApplyPlan(p) and bodyCalls==0)
p.character.sexID=3; p.appearance={}
assert(not D.MakeApplyPlan(p) and bodyCalls==0)
D.atBarber=false; D.ClearApplyPreview()
''')
print('PASS: male-to-female and female-to-male profiles, separate body/choice confirmations, preview-body capture/export/reuse, stale/rejected body changes, cancelled delayed review, zero purchases.')
