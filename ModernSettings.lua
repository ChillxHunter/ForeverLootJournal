-- Forever Loot Journal v1.5.0: option D settings.
-- D-inspired modern WoW settings. Presentation only; reuses Core.lua
-- saved-variable APIs, so all loot and prior settings are preserved.
local addonName, FLJ = ...
local Theme=FLJ.Theme
local S = {}
FLJ.SettingsUI = S

local C = {
    back={.025,.028,.035,1}, panel={.040,.044,.054,1},
    well={.020,.023,.030,1}, button={.065,.071,.084,1},
    border={.28,.29,.32,1}, gold={1,.78,.26,1},
    pale={.88,.91,.96,1}, muted={.58,.67,.77,1},
}
local overlay,host
local pages,navButtons={},{}
local qualityButtons,storageButtons,displayButtons={},{},{}
local page="general"
local pendingStorage
local profileText={}
local function Color(t) return t[1],t[2],t[3],t[4] or 1 end

local function Paint(frame,color)
    local t=frame:CreateTexture(nil,"BACKGROUND")
    t:SetAllPoints(frame)
    t:SetColorTexture(Color(color))
    return t
end
local function Stroke(frame,color,n)
    local sz=n or 1
    local pieces={}
    local function Edge(anchors,w,h)
        local x=frame:CreateTexture(nil,"BORDER")
        x:SetColorTexture(Color(color))
        for _,p in ipairs(anchors) do x:SetPoint(unpack(p)) end
        if w then x:SetWidth(w) end
        if h then x:SetHeight(h) end
        pieces[#pieces+1]=x
    end
    Edge({{"TOPLEFT"},{"TOPRIGHT"}},nil,sz)
    Edge({{"BOTTOMLEFT"},{"BOTTOMRIGHT"}},nil,sz)
    Edge({{"TOPLEFT"},{"BOTTOMLEFT"}},sz,nil)
    Edge({{"TOPRIGHT"},{"BOTTOMRIGHT"}},sz,nil)
    return pieces
end
local function Panel(parent,x,y,w,h,color,edge)
    local f=CreateFrame("Frame",nil,parent)
    f:SetSize(w,h)
    f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y)
    f.base=Paint(f,color or C.panel)
    Stroke(f,edge or C.border,1)
    Theme.Paint(f,"d_panel","BORDER",8)
    return f
end
local function Text(parent,str,x,y,size,color,width)
    local t=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    t:SetFont((size or 13)>=17 and "Fonts\\FRIZQT__.TTF" or "Fonts\\ARIALN.TTF",size or 13,"")
    t:SetTextColor(Color(color or C.pale))
    t:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y)
    if width then t:SetWidth(width); t:SetJustifyH("LEFT") end
    t:SetText(str)
    return t
end
local function Button(parent,x,y,w,h,text,callback)
    local b=CreateFrame("Button",nil,parent)
    b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y)
    b:SetSize(w,h)
    b:RegisterForClicks("LeftButtonUp")
    b:EnableMouse(true)
    b.base=Paint(b,C.button)
    Stroke(b,C.border,1)
    b.chrome=Theme.Paint(b,"d_button","BORDER",7)
    b.active=Theme.Paint(b,"d_active","ARTWORK",7)
    b.active:SetShown(false)
    b.highlight=b:CreateTexture(nil,"ARTWORK")
    b.highlight:SetColorTexture(.83,.62,.19,.14)
    b.highlight:SetAllPoints(b)
    b.highlight:Hide()
    b.label=Text(b,text,7,7,12,C.pale,w-14)
    b.label:SetHeight(h-10)
    b.label:SetJustifyH("CENTER")
    b:SetScript("OnEnter",function(self) self.highlight:Show() end)
    b:SetScript("OnLeave",function(self) self.highlight:Hide() end)
    b:SetScript("OnClick",callback)
    return b
end
local function Format(n)
    local s=tostring(tonumber(n) or 0)
    return s:reverse():gsub("(%d%d%d)(%d)","%1,%2"):reverse()
end
local function StorageKey()
    if FLJ.GetStoragePreset then return FLJ.GetStoragePreset() end
    return "MONSTER"
end
local function UIOptions()
    local db=FLJ.GetDB and FLJ.GetDB()
    if not db then return nil end
    if type(db.ui)~="table" then db.ui={} end
    if type(db.ui.displayOptions)~="table" then db.ui.displayOptions={} end
    return db.ui.displayOptions
end
local function GetDisplay(name)
    local opt=UIOptions()
    return not opt or opt[name]~=false
end
local function SetDisplay(name,value)
    local opt=UIOptions()
    if not opt then return end
    opt[name]=not not value
    if FLJ.UI and FLJ.UI.Refresh then FLJ.UI.Refresh() end
    S.Refresh()
end

local function TitleBlock(parent,heading,subtitle)
    local title=Text(parent,heading,18,16,16,C.pale,800)
    Text(parent,subtitle,18,41,11,C.muted,800)
    return title
end
local function MakeRarities(parent,topLabel)
    if topLabel then
        TitleBlock(parent,"Rarity Registration (New Loot)",
            "Choose which rarities should be saved for new loot.")
    end
    for i,opt in ipairs(FLJ.RarityOptions or {}) do
        local id,name,color=opt.id,opt.label,opt.color
        local b=Button(parent,18+(i-1)*100,68,90,91,"",function()
            FLJ.SetRarityEnabled(id,not FLJ.IsRarityEnabled(id))
            S.Refresh()
        end)
        b.rarityColor=color
        Theme.Paint(b,"d_card","ARTWORK",10)
        b.glow=Theme.Paint(b,"d_glow","ARTWORK",10)
        b.glow:SetTint(color[1],color[2],color[3])
        local check=Panel(b,30,14,30,30,C.well)
        b.check=check:CreateTexture(nil,"OVERLAY")
        b.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        b.check:SetPoint("CENTER",check,"CENTER",0,0)
        b.check:SetSize(36,36)
        b.check:SetVertexColor(color[1],color[2],color[3])
        b.label:ClearAllPoints()
        b.label:SetPoint("TOPLEFT",b,"TOPLEFT",3,-61)
        b.label:SetSize(84,20)
        b.label:SetJustifyH("CENTER")
        b.label:SetText(name)
        b.state=Text(b,"",0,0,1,C.muted,1)
        b:SetScript("OnEnter",function(self)
            self.highlight:Show()
            GameTooltip:SetOwner(self,"ANCHOR_TOP")
            GameTooltip:AddLine(name,color[1],color[2],color[3])
            GameTooltip:AddLine("Toggle saving NEW loot of this quality",1,1,1)
            GameTooltip:AddLine("Previously saved items are never removed.",.7,.83,1)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave",function(self) self.highlight:Hide();GameTooltip:Hide() end)
        qualityButtons[id]=qualityButtons[id] or {}
        qualityButtons[id][#qualityButtons[id]+1]=b
    end
end
local function UpdateRarities()
    for id,buttons in pairs(qualityButtons) do
        local on=FLJ.IsRarityEnabled(id)
        for _,b in ipairs(buttons) do
            local c=b.rarityColor
            b.check:SetShown(on)
            b.glow:SetShown(on)
            b.label:SetTextColor(on and c[1] or .48,on and c[2] or .50,on and c[3] or .55)
        end
    end
end
local function SetStorage(key)
    if not FLJ.SetStoragePreset then return end
    local ok,removed=FLJ.SetStoragePreset(key)
    if ok then
        S.Refresh()
        local _,limit,label=FLJ.GetStoragePreset()
        print("|cffffd76aForever Loot Journal:|r "..label.." - "..Format(limit)..
            " records."..(removed>0 and (" Removed "..Format(removed).." oldest records.") or ""))
    end
end
local function ChooseStorage(key)
    local preset=FLJ.StoragePresets and FLJ.StoragePresets[key]
    if not preset or key==StorageKey() then return end
    local records=FLJ.GetRecords and FLJ.GetRecords() or {}
    local toDelete=#records-preset.limit
    if toDelete>0 then
        local dialog="FLJ_MODERN_STORAGE_CONFIRM"
        if not StaticPopupDialogs or not StaticPopup_Show then
            print("|cffffd76aForever Loot Journal:|r A confirmation dialog is required to lower the saved-loot limit.")
            return
        end
        if not StaticPopupDialogs[dialog] then
            StaticPopupDialogs[dialog]={
                text="Change to %s?\n%s OLDEST records will be permanently deleted. Newer loot is kept.",
                button1=YES or "Confirm",button2=NO or "Cancel",
                timeout=0,whileDead=true,hideOnEscape=true,preferredIndex=3,
                OnAccept=function()
                    local selected=pendingStorage
                    pendingStorage=nil
                    if selected then SetStorage(selected) end
                end,
                OnCancel=function() pendingStorage=nil end,
            }
        end
        pendingStorage=key
        StaticPopup_Show(dialog,preset.label,Format(toDelete))
    else SetStorage(key) end
end
local function DrawMonitor(parent,color)
    local f=CreateFrame("Frame",nil,parent)
    f:SetSize(48,37)
    f:SetPoint("TOP",parent,"TOP",0,-17)
    local screen=Panel(f,3,1,42,28,C.well,color)
    local highlight=screen:CreateTexture(nil,"ARTWORK")
    highlight:SetPoint("TOPLEFT",screen,"TOPLEFT",3,-3)
    highlight:SetSize(34,2)
    highlight:SetColorTexture(color[1],color[2],color[3],.62)
    local stem=f:CreateTexture(nil,"ARTWORK")
    stem:SetColorTexture(color[1],color[2],color[3],1)
    stem:SetPoint("TOP",screen,"BOTTOM",0,0)
    stem:SetSize(3,7)
    local foot=f:CreateTexture(nil,"ARTWORK")
    foot:SetColorTexture(color[1],color[2],color[3],1)
    foot:SetPoint("TOP",stem,"BOTTOM",0,0)
    foot:SetSize(22,2)
end
local function MakeStorage(parent)
    local title=TitleBlock(parent,"Save Limit (PC Performance)","Maximum number of items to save.")
    title:SetTextColor(Color(C.gold))
    local colors={POTATO={.64,.70,.80},NORMAL={.64,.70,.80},STRONG={.64,.70,.80},
        MONSTER={1,.79,.24},EXTREME={.72,.35,1}}
    for i,key in ipairs(FLJ.StoragePresetOrder or {}) do
        local profile=key
        local entry=FLJ.StoragePresets[key]
        local b=Button(parent,18+(i-1)*163,70,151,154,"",function() ChooseStorage(profile) end)
        b.profile=key;b.profileColor=colors[key]
        Theme.Paint(b,"d_card","ARTWORK",12)
        b.glow=Theme.Paint(b,"d_glow","ARTWORK",12)
        DrawMonitor(b,colors[key])
        b.label:ClearAllPoints()
        b.label:SetPoint("TOPLEFT",b,"TOPLEFT",6,-84)
        b.label:SetSize(139,26)
        b.label:SetJustifyH("CENTER")
        b.label:SetText(entry.label)
        b.limit=Text(b,Format(entry.limit),6,116,17,C.pale,139)
        b.limit:SetJustifyH("CENTER")
        b.selected=b:CreateTexture(nil,"OVERLAY")
        b.selected:SetTexture("Interface\\AddOns\\ForeverLootJournal\\Media\\d_selected")
        b.selected:SetPoint("TOPRIGHT",b,"TOPRIGHT",-3,-3)
        b.selected:SetSize(25,25)
        storageButtons[key]=storageButtons[key] or {}
        storageButtons[key][#storageButtons[key]+1]=b
    end
end
local function UpdateStorage()
    local key=StorageKey()
    for id,buttons in pairs(storageButtons) do
        for _,b in ipairs(buttons) do
            local selected=id==key
            b.glow:SetShown(selected or id=="EXTREME")
            if selected then b.glow:SetTint(1,.78,.19)
            else b.glow:SetTint(.62,.25,.9,.7) end
            b.selected:SetShown(selected)
            b.label:SetTextColor(selected and 1 or .88,selected and .82 or .90,selected and .34 or .96)
            b.limit:SetTextColor(selected and 1 or .88,selected and .82 or .90,selected and .34 or .96)
        end
    end
end
local function NewPage(key)
    local f=CreateFrame("Frame",nil,overlay)
    f:SetPoint("TOPLEFT",overlay,"TOPLEFT",222,-8)
    f:SetSize(840,450)
    pages[key]=f
    return f
end
local function BuildGeneral()
    local p=NewPage("general")
    local rarity=Panel(p,0,0,840,181,C.panel)
    MakeRarities(rarity,true)
    local store=Panel(p,0,193,840,257,C.panel)
    MakeStorage(store)
end
local function BuildRarityPage()
    local p=NewPage("rarity")
    local rarity=Panel(p,0,0,840,181,C.panel)
    MakeRarities(rarity,true)
    local info=Panel(p,0,193,840,257,C.panel)
    Text(info,"Rarity registration",18,18,16,C.gold,800)
    Text(info,"Your choices apply to future drops. Existing loot stays in the archive.",18,62,13,C.pale,800)
    Text(info,"Previously saved items are never removed.",18,101,13,C.muted,800)
    Text(info,"Learned crafting recipes are stored separately from loot history.",18,140,13,C.muted,800)
end
local function BuildStoragePage()
    local p=NewPage("storage")
    local store=Panel(p,0,0,840,257,C.panel)
    MakeStorage(store)
    local info=Panel(p,0,269,840,181,C.panel)
    Text(info,"Saved loot history",18,18,16,C.gold,800)
    Text(info,"Increasing the limit keeps every saved item.",18,58,13,C.pale,800)
    Text(info,"A lower limit asks for confirmation before removing the oldest entries.",18,96,13,C.muted,800)
    Text(info,"Players, recipes and preferences remain saved account-wide.",18,134,13,C.muted,800)
end
local displayDefs={
    {id="classColors",label="Use class colors for player names",desc="Keep class identity visible in the party roster."},
    {id="itemTooltips",label="Show item tooltips on hover",desc="View the game's full item tooltip when moving over an icon."},
    {id="groupMarkers",label="Show current-group indicators",desc="Use green markers to identify party and raid members."},
}
local function BuildDisplayPage()
    local p=NewPage("display")
    TitleBlock(p,"Display","Choose how the journal presents players and items.")
    for i,option in ipairs(displayDefs) do
        local key=option.id
        local card=Panel(p,12,85+(i-1)*109,816,98,C.well,{.25,.35,.46,1})
        Text(card,option.label,20,17,16,C.pale,600)
        Text(card,option.desc,20,49,11,C.muted,600)
        local btn=Button(card,680,25,110,45,"",function()
            SetDisplay(key,not GetDisplay(key))
        end)
        displayButtons[key]=btn
    end
end
local function BuildProfilesPage()
    local p=NewPage("profiles")
    TitleBlock(p,"Profiles & History","Overview of your account-wide journal and party data.")
    profileText.players=Text(p,"Known players: --",24,88,17,C.pale,700)
    profileText.loot=Text(p,"Saved loot: --",24,132,17,C.pale,700)
    profileText.recipes=Text(p,"Learned recipes: --",24,176,17,C.pale,700)
    profileText.sync=Text(p,"Party sync: --",24,220,17,C.pale,700)
    profileText.limit=Text(p,"Storage profile: --",24,264,17,C.pale,700)
    Button(p,24,350,300,52,"Refresh Current Party",function()
        if FLJ.RegisterRoster then FLJ.RegisterRoster() end
        if FLJ.UI and FLJ.UI.Refresh then FLJ.UI.Refresh() end
        S.Refresh()
    end)
    Button(p,350,350,300,52,"Return to Loot Journal",function() S.Hide() end)
end

local function RefreshPages()
    for key,p in pairs(pages) do p:SetShown(key==page) end
    for key,b in pairs(navButtons) do
        local selected=key==page
        b.active:SetShown(selected)
        b.base:SetColorTexture(selected and .40 or .053,
            selected and .25 or .079,selected and .045 or .129,1)
        b.label:SetTextColor(selected and 1 or .84,selected and .84 or .88,
            selected and .34 or .97)
    end
end
local function ChoosePage(id)
    page=id
    RefreshPages()
    S.Refresh()
end

function S.Refresh()
    UpdateRarities()
    UpdateStorage()
    for key,b in pairs(displayButtons) do
        local on=GetDisplay(key)
        b.label:SetText(on and "ON" or "OFF")
        b.label:SetTextColor(on and .43 or 1,on and 1 or .43,on and .55 or .36)
        b.base:SetColorTexture(on and .08 or .20,on and .20 or .08,on and .11 or .08,1)
    end
    if profileText.players then
        local countPlayers=FLJ.GetPlayers and #FLJ.GetPlayers() or 0
        local records=FLJ.GetRecords and #FLJ.GetRecords() or 0
        local recipes=FLJ.Crafting and FLJ.Crafting.GetRecipes and #FLJ.Crafting.GetRecipes() or 0
        local _,limit,label=FLJ.GetStoragePreset()
        local db=FLJ.GetDB and FLJ.GetDB()
        local syncing=db and db.ui and db.ui.syncEnabled~=false
        profileText.players:SetText("Known players: "..Format(countPlayers))
        profileText.loot:SetText("Saved loot records: "..Format(records))
        profileText.recipes:SetText("Learned crafting recipes: "..Format(recipes))
        profileText.sync:SetText("Party synchronization: "..(syncing and "Enabled" or "Disabled"))
        profileText.limit:SetText("Storage profile: "..label.." ("..Format(limit)..")")
    end
end
function S.Show(nextPage)
    if not overlay then return end
    page=nextPage or "general"
    RefreshPages()
    overlay:Show()
    if FLJ.UI and FLJ.UI.SetHeaderMode then FLJ.UI.SetHeaderMode("settings") end
    S.Refresh()
end
function S.Hide()
    if overlay then overlay:Hide() end
    if FLJ.UI and FLJ.UI.SetHeaderMode then FLJ.UI.SetHeaderMode("journal") end
end
function S.Toggle()
    if not overlay then return end
    if overlay:IsShown() then S.Hide() else S.Show("general") end
end
function S.IsShown() return overlay and overlay:IsShown() or false end

function S.Build(window)
    if overlay or not window then return end
    host=window
    overlay=Panel(window,13,76,1074,470,C.back)
    overlay:SetFrameLevel(window:GetFrameLevel()+48)
    overlay:EnableMouse(true)
    local left=Panel(overlay,8,8,202,450,C.well)
    local nav={{"general","General"},{"rarity","Rarity Filter"},{"storage","Storage"},{"display","Display"},{"profiles","Profiles"}}
    local icons={general="d_crest",rarity="d_crest",storage="d_monitor",display="d_display",profiles="d_crest"}
    for i,item in ipairs(nav) do
        local id=item[1]
        local b=Button(left,8,10+(i-1)*52,186,43,item[2],function() ChoosePage(id) end)
        b.label:ClearAllPoints()
        b.label:SetPoint("LEFT",b,"LEFT",47,0)
        b.label:SetSize(132,32)
        b.label:SetJustifyH("LEFT")
        b.label:SetFont("Fonts\\ARIALN.TTF",14,"")
        local icon=b:CreateTexture(nil,"OVERLAY")
        icon:SetTexture("Interface\\AddOns\\ForeverLootJournal\\Media\\"..icons[id])
        icon:SetPoint("LEFT",b,"LEFT",11,0)
        icon:SetSize(27,27)
        navButtons[id]=b
    end
    Button(left,8,377,186,35,"Back to Journal",function() S.Hide() end)
    Text(left,"v1.5.0  |  Saved automatically",12,426,10,C.muted,182)
    BuildGeneral();BuildRarityPage();BuildStoragePage();BuildDisplayPage();BuildProfilesPage()
    overlay:Hide();RefreshPages();S.Refresh()
end
-- END SETTINGS
