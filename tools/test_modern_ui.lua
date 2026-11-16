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
    function f:SetPoint(...)
        local p={...}
        self.points=self.points or {}
        for i,old in ipairs(self.points) do
            if old[1]==p[1] then self.points[i]=p;return end
        end
        self.points[#self.points+1]=p
    end
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
    function f:GetFrameLevel() return self.level or (self.parent and self.parent:GetFrameLevel()+1) or 1 end
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
        t.layer=layer
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
assert(loadfile("Theme.lua"))("ForeverLootJournal",addon)
assert(loadfile("UI.lua"))("ForeverLootJournal",addon)
assert(loadfile("ModernSettings.lua"))("ForeverLootJournal",addon)
assert(addon.Toggle,"journal toggle missing")
addon.Toggle()
local main=_G.ForeverLootJournalFrame
assert(main and main:IsShown(),"journal not shown")
assert(addon.SettingsUI and addon.SettingsUI.Build,"settings module missing")
local headerTex=false
for _,frame in ipairs(frames) do
    if frame.texture=="Interface\\AddOns\\ForeverLootJournal\\Media\\d_header" then
        headerTex=true
    end
end
assert(headerTex,"modern custom header artwork not applied")
addon.SettingsUI.Show("general")
assert(addon.SettingsUI.IsShown(),"general settings page failed to open")
assert(main:GetHeight()==560,"option D settings must use the compact window")
for _,f in ipairs(frames) do
    if f.parent==main and (f.width or 0)>250 and (f.height or 0)>100 and f.width~=1074 then
        assert(not f:IsShown(),"journal panel leaked behind compact settings")
    end
end
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
assert(main:GetHeight()==786,"returning to the journal must restore its height")
assert(#db.records==1000,"navigation changed saved data")
io.write("Modern D-style Settings and Journal integration tests passed\n")

-- Regression: a full-window opaque child used to hide the root's entire
-- fantasy banner and title while every interaction test still passed.
for _,f in ipairs(frames) do
    assert(not(f.kind=="Frame" and f.parent==main and
        (f.width or 0)>=1080 and (f.height or 0)>=800),
        "opaque child frame would cover the journal header")
    if f.check and f.rarityColor then
        assert(f.check.parent~=f and f.check.parent.parent==f,
            "rarity checkmark must render inside its box, above the box background")
    end
end

db.records={}
db.players={
    {name="Chillx-Ranger",class="HUNTER",level=35,race="Night Elf",guild="NORGE",current=true,lootCount=5},
    {name="Dragon-Soulseeker",class="ROGUE",level=57,current=true,lootCount=2},
    {name="Ivan-Overdrivaarn",class="WARRIOR",level=33,current=true,lootCount=1},
    {name="Legolas-Thranduil",class="HUNTER",level=32,lootCount=0},
    {name="Saint-Ramz",class="PRIEST",level=34,lootCount=0},
}
local samples={
    {"Guerrilla Cleaver",2,2,"One-Handed Axes","Stranglethorn Vale","Chillx-Ranger",34},
    {"Guardian's Pauldrons",4,4,"Plate","Onyxia's Lair","Ivan-Overdrivaarn",55},
    {"Trueshot Bow",3,2,"Bows","Dire Maul","Chillx-Ranger",53},
    {"Bindings of Power",4,4,"Leather","Molten Core","Dragon-Soulseeker",54},
    {"Huntsman's Stoneclub",2,2,"One-Handed Maces","Stranglethorn Vale","Chillx-Ranger",40},
    {"Double Mail Vest",2,4,"Mail","Stranglethorn Vale","Chillx-Ranger",43},
    {"Duskwood Longbow",3,2,"Bows","Duskwood","Chillx-Ranger",35},
    {"Worn Leather Boots",1,4,"Leather","Westfall","Dragon-Soulseeker",12},
}
ITEM_QUALITY_COLORS={
    [1]={r=1,g=1,b=1},[2]={r=.12,g=1,b=.12},
    [3]={r=.2,g=.57,b=1},[4]={r=.73,g=.34,b=1},
}
for i,v in ipairs(samples) do
    db.records[i]={id=i,name=v[1],quality=v[2],classID=v[3],subtype=v[4],
        zone=v[5],winner=v[6],itemLevel=v[7],time=1700000000-i*600,
        status="Received",source="Group roll",icon="Interface\\Icons\\INV_Axe_04",
        stats={{label="Agility",value=3},{label="Stamina",value=4},{label="Damage per second",value=17.67857170105}}}
end
db.records[1].rolls={
    {name="Dragon-Soulseeker",action="Greed",value=92},
    {name="Chillx-Ranger",class="HUNTER",action="Need",value=87,winner=true},
    {name="Ivan-Overdrivaarn",action="Pass"},
}
addon.UI.Refresh()
local visibleRows=0
local selectedRows=0
local rounded=false
for _,f in ipairs(frames) do
    if f.record and f.itemName and f:IsShown() then
        visibleRows=visibleRows+1
        if f.selected:IsShown() then selectedRows=selectedRows+1 end
    end
    if f.text=="Damage per second: +17.68" then rounded=true end
end
assert(visibleRows==6,"archive must show six rows")
assert(selectedRows==1,"first displayed record must highlight immediately")
assert(rounded,"decimal item stats must be readable")
assert(db.records[1].rolls[1].name=="Dragon-Soulseeker","viewing details reordered saved rolls")
assert(ClickButton("All rarities"),"quick rarity filter missing")
local rareRows=0
for _,f in ipairs(frames) do
    if f.record and f.itemName and f:IsShown() then
        rareRows=rareRows+1
        assert(f.record.quality>=3,"Rare+ filter leaked lower-quality records")
    end
end
assert(rareRows==4 and #db.records==8,"quick filter changed archive data")
assert(ClickButton("Rare+") and ClickButton("Epic+"),"quick filter could not return to all rarities")
assert(#db.records==8,"filter cycle lost saved records")
io.write("Header layering, row selection, decimal stats and rarity filter regressions passed\n")

-- Export the widgets created by the real addon code for a layout preview.
-- This is not a replacement UI or a generated fantasy mockup.
if os.getenv("FLJ_SNAPSHOT")=="1" then
    storage="MONSTER"
    for _,f in ipairs(frames) do
        if f.record and f.record.id==1 and f.itemName then f.scripts.OnClick(f);break end
    end
    local function Encode(v)
        if v==nil then return "null" end
        if type(v)=="boolean" or type(v)=="number" then return tostring(v) end
        if type(v)=="string" then
            return '"'..v:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t')..'"'
        end
        local parts={}
        for _,value in ipairs(v) do parts[#parts+1]=Encode(value) end
        return '['..table.concat(parts,',')..']'
    end
    local ids={}
    for i,f in ipairs(frames) do ids[f]=i end
    local function Snapshot(path)
        local output={}
        for i,f in ipairs(frames) do
            local points={}
            for _,point in ipairs(f.points or {}) do
                local p={}
                for j,v in ipairs(point) do p[j]=type(v)=="table" and ("@"..ids[v]) or v end
                points[#points+1]=p
            end
            output[#output+1]=Encode({i,ids[f.parent] or 0,f.kind,f.shown,f.width or 0,f.height or 0,
                points,f.full or false,f.color or {},f.vertex or {},f.alpha or 1,f.texture or "",
                f.text or "",f.font or {},f.textColor or {},f.justify or "LEFT",f.layer or "",
                f:GetFrameLevel(),f.coords or {}})
        end
        local file=assert(io.open(path,"w"))
        file:write('{"root":'..ids[main]..',"widgets":['..table.concat(output,',')..']}')
        file:close()
    end
    addon.UI.Refresh()
    Snapshot("tools/journal-scene.json")
    addon.SettingsUI.Show("general")
    Snapshot("tools/settings-scene.json")
end

