-- Forever Loot Journal v1.3.0: WoW 16001 UI mock.
-- Validate actual construction, navigation and save-setting interactions.
local frames={}
local function MakeWidget(parent,kind)
    local f={parent=parent,kind=kind,shown=true,scripts={},fontStrings={},textures={}}
    function f:SetSize(w,h) self.width=w;self.height=h end
    function f:GetWidth() return self.width or 1100 end
    function f:GetHeight() return self.height or 830 end
    function f:SetWidth(w) self.width=w end
    function f:SetHeight(h) self.height=h end
    function f:SetPoint(...) self.points=self.points or {};self.points[#self.points+1]={...} end
    function f:ClearAllPoints() self.points={} end
    function f:SetAllPoints() self.full=true end
    function f:SetColorTexture(...) self.color={...} end
    function f:SetVertexColor(...) self.vertex={...} end
    function f:SetTexture(t) self.texture=t end
    function f:SetTexCoord(...) self.coords={...} end
    function f:SetAlpha(a) self.alpha=a end
    function f:SetScale(s) self.scale=s end
    function f:SetClampedToScreen(b) self.clamp=b end
    function f:SetMovable(b) self.move=b end
    function f:EnableMouse(b) self.mouse=b end
    function f:EnableMouseWheel(b) self.wheel=b end
    function f:RegisterForDrag(...) self.drag={...} end
    function f:RegisterForClicks(...) self.clicks={...} end
    function f:SetFrameStrata(v) self.strata=v end
    function f:SetFrameLevel(v) self.level=v end
    function f:GetFrameLevel() return self.level or 1 end
    function f:GetParent() return self.parent end
    function f:SetScript(ev,fn) self.scripts[ev]=fn end
    function f:RegisterEvent(ev) self.events=self.events or {};self.events[ev]=true end
    function f:Hide() self.shown=false end
    function f:Show()
        local before=self.shown
        self.shown=true
        if not before and self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function f:IsShown() return self.shown end
    function f:SetShown(v) if v then self:Show() else self:Hide() end end
    function f:SetText(v) self.text=v end
    function f:GetText() return self.text or "" end
    function f:SetTextColor(...) self.textColor={...} end
    function f:SetFont(...) self.font={...} end
    function f:SetJustifyH(v) self.justify=v end
    function f:SetWordWrap(v) self.wordWrap=v end
    function f:SetAutoFocus(v) self.autofocus=v end
    function f:SetMaxLetters(v) self.maxLetters=v end
    function f:ClearFocus() end
    function f:SetFocus() end
    function f:CreateTexture(_,layer)
        local t=MakeWidget(self,"Texture")
        t.layer=layer
        self.textures[#self.textures+1]=t
        return t
    end
    function f:CreateFontString(_,layer,template)
        local t=MakeWidget(self,"FontString")
        self.fontStrings[#self.fontStrings+1]=t
        return t
    end
    frames[#frames+1]=f
    return f
end
UIParent=MakeWidget(nil,"Frame")
UIParent:SetSize(1600,1000)
function CreateFrame(kind,name,parent,template)
    local f=MakeWidget(parent,kind)
    f.template=template
    if name then _G[name]=f end
    return f
end
GameTooltip={SetOwner=function()end,SetHyperlink=function()end,AddLine=function()end,
    Show=function()end,Hide=function()end}
UISpecialFrames={}
C_Timer={After=function(_,fn)fn()end}
YES="Confirm";NO="Cancel"
StaticPopupDialogs={}
local lastPopup
StaticPopup_Show=function(name,...)
    lastPopup={name=name,args={...}}
end
RAID_CLASS_COLORS={
    HUNTER={r=.66,g=.83,b=.45},
}
date=function() return "Now" end
time=function() return 1700000000 end
GetTime=function() return 100 end
IsModifiedClick=function() return false end
local db={ui={displayOptions={}},records={},players={},recipes={}}
local presets={
    POTATO={label="Potato PC",limit=1000},
    NORMAL={label="Normal PC",limit=2000},
    STRONG={label="Strong PC",limit=3000},
    MONSTER={label="MONSTER PC",limit=5000},
    EXTREME={label="EXTREME!!",limit=10000},
}
local qualities={}
local storage="MONSTER"
local addon={
    GetDB=function()return db end,
    GetPlayers=function()return db.players end,
    GetRecords=function()return db.records end,
    StoragePresets=presets,
    StoragePresetOrder={"POTATO","NORMAL","STRONG","MONSTER","EXTREME"},
    GetStoragePreset=function()return storage,presets[storage].limit,presets[storage].label end,
    SetStoragePreset=function(key)
        if not presets[key] then return false,0 end
        storage=key
        db.ui.storagePreset=key
        local removed=0
        while #db.records>presets[key].limit do
            table.remove(db.records)
            removed=removed+1
        end
        return true,removed
    end,
    RarityOptions={},
    IsRarityEnabled=function(id) return qualities[id]~=false end,
    SetRarityEnabled=function(id,on) qualities[id]=on;db.ui.rarityRegistration=qualities;return true end,
    Crafting={GetRecipes=function()return {} end,Scan=function()return 0 end},
}
for i,name in ipairs({"Poor","Common","Uncommon","Rare","Epic","Legendary","Artifact","Heirloom"}) do
    local colors={{.6,.6,.6},{1,1,1},{0,1,0},{0,.5,1},{.65,.3,1},{1,.5,.07},{.9,.7,.3},{.4,.9,.9}}
    addon.RarityOptions[#addon.RarityOptions+1]={id=i-1,label=name,color=colors[i]}
end
local logs={}
print=function(s)logs[#logs+1]=s end
assert(loadfile("UI.lua"))("ForeverLootJournal",addon)
assert(loadfile("ModernSettings.lua"))("ForeverLootJournal",addon)
assert(addon.Toggle,"journal toggle missing")
addon.Toggle()
local main=_G.ForeverLootJournalFrame
assert(main and main:IsShown(),"journal not shown")
assert(addon.SettingsUI and addon.SettingsUI.Build,"settings module missing")
local headerTex=false
for _,frame in ipairs(frames) do
    if frame.texture=="Interface\\AddOns\\ForeverLootJournal\\Media\\modern_header" then
        headerTex=true
    end
end
assert(headerTex,"modern custom header artwork not applied")
addon.SettingsUI.Show("general")
assert(addon.SettingsUI.IsShown(),"general settings page failed to open")
local textSettings=false
for _,f in ipairs(frames) do
    if f.kind=="FontString" and f.text=="Settings" then textSettings=true end
end
assert(textSettings,"settings header failed to update")

local function ClickButton(title)
    for _,f in ipairs(frames) do
        if f.kind=="Button" and f.label and f.label:GetText()==title and f.scripts.OnClick then
            f.scripts.OnClick(f,"LeftButton")
            return true
        end
    end
    return false
end
-- All eight rarities persist and do not delete existing records.
db.records={{id=1}}
assert(ClickButton("Epic"),"Epic rarity switch not built")
assert(qualities[4]==false and #db.records==1,"Epic toggle must not delete loot")
assert(ClickButton("Epic"),"Epic toggle second click missing")
assert(qualities[4]==true,"Epic toggle did not reenable")

assert(ClickButton("EXTREME!!"),"Extreme storage card not built")
assert(storage=="EXTREME" and db.ui.storagePreset=="EXTREME",
    "storage card didn't persist 10000-record limit")

-- Changing to a smaller limit with too many items must confirm deletion.
db.records={}
for i=1,1200 do db.records[i]={id=i} end
assert(ClickButton("Potato PC"),"Potato storage card missing")
assert(lastPopup and lastPopup.name=="FLJ_MODERN_STORAGE_CONFIRM",
    "reducing the cap must require explicit user confirmation")
assert(#db.records==1200,"records deleted before player confirmed")
StaticPopupDialogs[lastPopup.name].OnAccept()
assert(storage=="POTATO" and #db.records==1000,"confirmed storage change not applied")

addon.SettingsUI.Show("display")
assert(ClickButton("ON"),"functional display ON/OFF controls missing")
local hasOff=false
for _,f in ipairs(frames) do if f.kind=="FontString" and f.text=="OFF" then hasOff=true end end
assert(hasOff,"display toggle not visually updated")
addon.SettingsUI.Show("profiles")
addon.SettingsUI.Refresh()
assert(ClickButton("Return to Loot Journal"),"return navigation missing")
assert(not addon.SettingsUI.IsShown(),"couldn't close settings")
assert(main:IsShown(),"returning to journal closed the addon")
assert(#db.records==1000,"navigation changed saved data")
io.write("Modern D-style Settings and Journal integration tests passed\n")
