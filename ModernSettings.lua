-- Forever Loot Journal v1.3.0
-- D-inspired modern WoW settings. Presentation only; reuses Core.lua
-- saved-variable APIs, so all loot and prior settings are preserved.
local addonName, FLJ = ...
local S = {}
FLJ.SettingsUI = S

local C = {
    back={.020,.032,.056,1}, panel={.027,.045,.075,1},
    well={.014,.024,.044,1}, button={.061,.086,.129,1},
    border={.23,.32,.43,1}, gold={1,.78,.26,1},
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
    return f
end
local function Text(parent,str,x,y,size,color,width)
    local t=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    t:SetFont("Fonts\\FRIZQT__.TTF",size or 13,"OUTLINE")
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
    Text(parent,heading,22,20,20,C.gold,690)
    Text(parent,subtitle,22,54,12,C.muted,690)
    local goldLine=parent:CreateTexture(nil,"ARTWORK")
    goldLine:SetColorTexture(.70,.47,.12,.65)
    goldLine:SetPoint("TOPLEFT",parent,"TOPLEFT",22,-80)
    goldLine:SetSize(720,1)
end

local function MakeRarities(parent,topLabel)
    if topLabel then
        TitleBlock(parent,"Rarity Registration (New Loot)",
            "Choose which rarities should be saved for future drops.")
    end
    local area=Panel(parent,14,93,738,139,C.well,{.24,.34,.46,1})
    for i,opt in ipairs(FLJ.RarityOptions or {}) do
        local rarityID=opt.id
        local color=opt.color
        local b=Button(area,10+(i-1)*91,10,83,117,"",function()
            if FLJ.SetRarityEnabled then
                FLJ.SetRarityEnabled(rarityID,not FLJ.IsRarityEnabled(rarityID))
                S.Refresh()
            end
        end)
        b.rarityColor=color
        local check=Panel(b,26,19,31,31,C.well,{.43,.51,.60,1})
        check.base:SetColorTexture(.025,.04,.065,.9)
        b.check=b:CreateTexture(nil,"OVERLAY")
        b.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        b.check:SetSize(40,40)
        b.check:SetPoint("CENTER",check,"CENTER",0,0)
        b.check:SetVertexColor(color[1],color[2],color[3])
        b.label:SetPoint("TOPLEFT",b,"TOPLEFT",2,-72)
        b.label:SetSize(79,18)
        b.label:SetJustifyH("CENTER")
        b.label:SetText(opt.label)
        b.state=Text(b,"ON",34,96,10,C.muted,44)
        b.state:SetJustifyH("CENTER")
        b.state:ClearAllPoints()
        b.state:SetPoint("BOTTOM",b,"BOTTOM",0,4)
        b:SetScript("OnEnter",function(self)
            self.highlight:Show()
            GameTooltip:SetOwner(self,"ANCHOR_TOP")
            GameTooltip:AddLine(opt.label, color[1],color[2],color[3])
            GameTooltip:AddLine("Toggle saving NEW loot of this quality",1,1,1)
            GameTooltip:AddLine("Previously saved items are never removed.",.7,.83,1)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave",function(self)
            self.highlight:Hide()
            GameTooltip:Hide()
        end)
        qualityButtons[rarityID]=b
    end
end
local function UpdateRarities()
    for id,b in pairs(qualityButtons) do
        local enabled=FLJ.IsRarityEnabled and FLJ.IsRarityEnabled(id)
        local c=b.rarityColor
        b.base:SetColorTexture(enabled and .05+c[1]*.16 or .038,
            enabled and .05+c[2]*.13 or .048,
            enabled and .07+c[3]*.16 or .064,1)
        b.check:SetShown(enabled)
        b.label:SetTextColor(enabled and c[1] or .48,enabled and c[2] or .53,
            enabled and c[3] or .60)
        b.state:SetText(enabled and "ON" or "OFF")
        b.state:SetTextColor(enabled and .39 or .88,enabled and .92 or .48,enabled and .56 or .45)
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
    TitleBlock(parent,"Save Limit (PC Performance)",
        "Maximum number of loot records to keep on this account.")
    local area=Panel(parent,13,91,741,168,C.well,{.23,.32,.43,1})
    local colors={
        POTATO={.43,.70,1},NORMAL={.43,.70,1},
        STRONG={.43,.70,1}, MONSTER={1,.74,.22},EXTREME={.75,.42,1},
    }
    for i,key in ipairs(FLJ.StoragePresetOrder or {}) do
        local profile=key
        local entry=FLJ.StoragePresets[profile]
        local b=Button(area,10+(i-1)*146,10,137,146,"",function()
            ChooseStorage(profile)
        end)
        b.profile=profile
        b.profileColor=colors[profile]
        DrawMonitor(b,colors[profile])
        b.label:ClearAllPoints()
        b.label:SetPoint("TOPLEFT",b,"TOPLEFT",5,-70)
        b.label:SetSize(127,27)
        b.label:SetJustifyH("CENTER")
        b.label:SetText(entry.label)
        b.limit=Text(b,Format(entry.limit),7,109,15,C.pale,122)
        b.limit:SetJustifyH("CENTER")
        b.selected=Text(b,"SELECTED",8,5,9,C.gold,117)
        b.selected:SetJustifyH("RIGHT")
        storageButtons[profile]=b
    end
end
local function UpdateStorage()
    local selected=StorageKey()
    for key,b in pairs(storageButtons) do
        local active=selected==key
        local color=b.profileColor
        b.base:SetColorTexture(active and .24 or .045,active and .17 or .073,
            active and .045 or .13,1)
        b.label:SetTextColor(active and 1 or .88,active and .82 or .90,active and .34 or .98)
        b.limit:SetTextColor(active and 1 or color[1],active and .82 or color[2],
            active and .32 or color[3])
        b.selected:SetShown(active)
    end
end

local function NewPage(key)
    local f=Panel(overlay,293,10,766,633,C.panel,{.26,.36,.48,1})
    pages[key]=f
    return f
end

local function BuildGeneral()
    local p=NewPage("general")
    local rarity=Panel(p,8,8,750,291,C.panel,{.34,.42,.51,1})
    MakeRarities(rarity,true)
    local storage=Panel(p,8,311,750,310,C.panel,{.34,.42,.51,1})
    MakeStorage(storage)
end
local function BuildRarityPage()
    local p=NewPage("rarity")
    local rarity=Panel(p,8,8,750,290,C.panel,{.34,.42,.51,1})
    MakeRarities(rarity,true)
    local info=Panel(p,8,310,750,310,C.panel)
    Text(info,"How Rarity Registration Works",22,20,18,C.gold,670)
    Text(info,"Changes affect only newly acquired equipment and recipe drops.",22,69,14,C.pale,700)
    Text(info,"Items already saved in your journal are never hidden or deleted.",22,107,13,C.muted,700)
    Text(info,"The game must know an item's rarity before applying your selection.",22,145,13,C.muted,700)
    Text(info,"Learned crafting recipes are saved separately from equipment history.",22,184,13,C.muted,700)
end
local function BuildStoragePage()
    local p=NewPage("storage")
    local store=Panel(p,8,8,750,310,C.panel,{.34,.42,.51,1})
    MakeStorage(store)
    local info=Panel(p,8,331,750,290,C.panel)
    Text(info,"About Your PC Profile",22,20,18,C.gold,700)
    Text(info,"Increasing your limit preserves every existing item.",22,73,13,C.pale,700)
    Text(info,"Lowering the limit requires confirmation when older entries would be deleted.",22,117,13,C.muted,700)
    Text(info,"The oldest loot entries are removed first. Keep a backup of SavedVariables.",22,161,13,C.muted,700)
    Text(info,"PC tiers are capacity preferences, not guaranteed performance ratings.",22,205,13,C.muted,700)
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
        local card=Panel(p,18,111+(i-1)*139,730,124,C.well,{.25,.35,.46,1})
        Text(card,option.label,20,17,16,C.pale,580)
        Text(card,option.desc,20,49,11,C.muted,580)
        local btn=Button(card,600,35,110,45,"",function()
            SetDisplay(key,not GetDisplay(key))
        end)
        displayButtons[key]=btn
    end
end
local function BuildProfilesPage()
    local p=NewPage("profiles")
    TitleBlock(p,"Profiles & History","Overview of your account-wide journal and party data.")
    profileText.players=Text(p,"Known players: --",24,121,17,C.pale,700)
    profileText.loot=Text(p,"Saved loot: --",24,171,17,C.pale,700)
    profileText.recipes=Text(p,"Learned recipes: --",24,221,17,C.pale,700)
    profileText.sync=Text(p,"Party sync: --",24,271,17,C.pale,700)
    profileText.limit=Text(p,"Storage profile: --",24,321,17,C.pale,700)
    Button(p,24,416,300,52,"Refresh Current Party",function()
        if FLJ.RegisterRoster then FLJ.RegisterRoster() end
        if FLJ.UI and FLJ.UI.Refresh then FLJ.UI.Refresh() end
        S.Refresh()
    end)
    Button(p,340,416,300,52,"Return to Loot Journal",function() S.Hide() end)
end

local function RefreshPages()
    for key,p in pairs(pages) do p:SetShown(key==page) end
    for key,b in pairs(navButtons) do
        local selected=key==page
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
    overlay=Panel(window,13,127,1074,660,C.back,{.64,.45,.17,1})
    overlay:SetFrameLevel(window:GetFrameLevel()+48)
    local left=Panel(overlay,11,10,271,637,C.well,{.27,.37,.48,1})
    Text(left,"SETTINGS",18,15,18,C.gold,230)
    Text(left,"Journal preferences",18,42,11,C.muted,230)
    local nav={
        {"general","General","G"},
        {"rarity","Rarity Filter","R"},
        {"storage","Storage","S"},
        {"display","Display","D"},
        {"profiles","Profiles","P"},
    }
    for i,item in ipairs(nav) do
        local id=item[1]
        local b=Button(left,12,76+(i-1)*76,246,62,item[2],function()
            ChoosePage(id)
        end)
        b.label:ClearAllPoints()
        b.label:SetPoint("LEFT",b,"LEFT",53,0)
        b.label:SetSize(172,40)
        b.label:SetJustifyH("LEFT")
        b.label:SetFont("Fonts\\FRIZQT__.TTF",15,"OUTLINE")
        local emblem=Text(b,item[3],17,18,18,C.gold,28)
        navButtons[id]=b
    end
    local bottom=Text(left,"v1.3.0  |  Settings save automatically",15,589,10,C.muted,245)
    Button(left,13,537,245,41,"Back to Journal",function() S.Hide() end)
    BuildGeneral()
    BuildRarityPage()
    BuildStoragePage()
    BuildDisplayPage()
    BuildProfilesPage()
    overlay:Hide()
    RefreshPages()
    S.Refresh()
end
