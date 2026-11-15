-- Forever Loot Journal: Journal-inspired browsable loot and player archive
local addonName, FLJ = ...
FLJ.UI = FLJ.UI or {}
local UI = FLJ.UI
local W, H = 1100, 738
local gold = {1, .80, .31}
local parchment = {.91, .82, .62}
local muted = {.63, .61, .55}
local panel = {.085, .073, .061, 1}
local shadow = {.038, .034, .029, 1}
local currentTab, gearFilter, searchText, playerSearch, chosenPlayer = "loot", "all", "", "", nil
local selectedID, listOffset, playerOffset, detailRollOffset = nil, 0, 0, 0
local frame, itemRows, playerRows, detail, dropdown, dropdownRows
local searchBox, playerSearchBox, playerLabel, titleText, countText, listEmpty
local tabButtons, filterButtons, clearPopup
local ITEM_VISIBLE = 4
local PLAYER_VISIBLE = 10
local ITEM_ROW_HEIGHT = 57
local PLAYER_ROW_HEIGHT = 40
local TEXTURE = "Interface\\AddOns\\ForeverLootJournal\\Media\\"
local placeholder = "Interface\\Icons\\INV_Misc_QuestionMark"
local classCoords = {
    WARRIOR={0, .25,0,.25}, MAGE={.25,.496,0,.25}, ROGUE={.496,.742,0,.25}, DRUID={.742,1,0,.25},
    HUNTER={0,.25,.25,.496}, SHAMAN={.25,.496,.25,.496}, PRIEST={.496,.742,.25,.496}, WARLOCK={.742,1,.25,.496},
    PALADIN={0,.25,.496,.742}, DEATHKNIGHT={.25,.496,.496,.742}, MONK={.496,.742,.496,.742}, DEMONHUNTER={.742,1,.496,.742},
    EVOKER={0,.25,.742,1},
}
local function Color(t)
    return (t and t[1] or 1), (t and t[2] or 1), (t and t[3] or 1)
end
local function SetColor(t,c,alpha) t:SetVertexColor(Color(c)); if alpha then t:SetAlpha(alpha) end end
local function MakeTexture(parent,layer,col)
    local tx = parent:CreateTexture(nil, layer or "BACKGROUND")
    tx:SetColorTexture(col[1], col[2], col[3], col[4] or 1)
    return tx
end
local function Fill(parent,col,inset)
    local tx=MakeTexture(parent,"BACKGROUND",col)
    tx:SetPoint("TOPLEFT",parent,"TOPLEFT",inset or 0,-(inset or 0))
    tx:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",-(inset or 0),(inset or 0))
    return tx
end
local function Border(parent,r,g,b,thick)
    local size=thick or 1
    local a=parent:CreateTexture(nil,"BORDER") a:SetColorTexture(r,g,b,1)
    a:SetPoint("TOPLEFT"); a:SetPoint("TOPRIGHT"); a:SetHeight(size)
    local z=parent:CreateTexture(nil,"BORDER") z:SetColorTexture(r,g,b,1)
    z:SetPoint("BOTTOMLEFT"); z:SetPoint("BOTTOMRIGHT"); z:SetHeight(size)
    local l=parent:CreateTexture(nil,"BORDER") l:SetColorTexture(r,g,b,1)
    l:SetPoint("TOPLEFT"); l:SetPoint("BOTTOMLEFT"); l:SetWidth(size)
    local rr=parent:CreateTexture(nil,"BORDER") rr:SetColorTexture(r,g,b,1)
    rr:SetPoint("TOPRIGHT"); rr:SetPoint("BOTTOMRIGHT"); rr:SetWidth(size)
end
local function Label(parent,text,size,col,justify)
    local fs=parent:CreateFontString(nil,"OVERLAY", "GameFontNormal")
    fs:SetFont("Fonts\\FRIZQT__.TTF",size or 13, "OUTLINE")
    fs:SetText(text or "")
    fs:SetTextColor(Color(col or parchment))
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end
local function Panel(parent,x,y,w,h,bg)
    local p=CreateFrame("Frame", nil, parent)
    p:SetSize(w,h); p:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y)
    Fill(p,bg or panel)
    Border(p,.30,.23,.14,1)
    return p
end
local function Button(parent,x,y,w,h,text,callback)
    local b=CreateFrame("Button",nil,parent)
    b:SetSize(w,h); b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y)
    b.base=Fill(b,{.16,.127,.087,1})
    Border(b,.39,.30,.17,1)
    b.highlight=MakeTexture(b,"ARTWORK",{.73,.54,.20,.19}); b.highlight:SetAllPoints(); b.highlight:Hide()
    b.label=Label(b,text or "",12,gold,"CENTER"); b.label:SetAllPoints()
    b:SetScript("OnEnter",function(self) self.highlight:Show() end)
    b:SetScript("OnLeave",function(self) self.highlight:Hide() end)
    b:SetScript("OnClick",callback)
    return b
end
local function Edit(parent,x,y,w,h,hint,handler)
    local wrap=Panel(parent,x,y,w,h,{.055,.050,.043,1})
    local icon=Label(wrap,"⌕",17,muted)
    icon:SetPoint("LEFT",wrap,"LEFT",9,0)
    local edit=CreateFrame("EditBox",nil,wrap,"InputBoxTemplate")
    edit:SetAutoFocus(false); edit:SetSize(w-42,h-8)
    edit:SetPoint("LEFT",wrap,"LEFT",28,0)
    edit:SetMaxLetters(70)
    edit:SetFont("Fonts\\FRIZQT__.TTF",12,"")
    edit:SetTextColor(1,.91,.72)
    edit:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    edit:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
    local prompt=Label(wrap,hint,11,muted)
    prompt:SetPoint("LEFT",wrap,"LEFT",31,0)
    edit:SetScript("OnTextChanged",function(self)
        prompt:SetShown(self:GetText()=="")
        handler(self:GetText() or "")
    end)
    return edit,wrap
end
local function ScrollWheel(control,fn)
    control:EnableMouseWheel(true)
    control:SetScript("OnMouseWheel",function(_,delta) fn(delta) end)
end
local function Date(ts)
    if not ts or ts == 0 then return "—" end
    return date("%d %b %Y  %H:%M", ts)
end
local function T(str) return (str or ""):lower() end
local function Includes(str,query) return T(tostring(str or "")):find(T(query),1,true)~=nil end
local function PlayerColor(cls)
    local c=cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
    if c then return {c.r,c.g,c.b} end
    return parchment
end
local function PlayerText(name,cls)
    if not name or name=="" then return "Unknown" end
    return name
end
local function GetSelected()
    if not selectedID then return nil end
    for _,rec in ipairs(FLJ.GetRecords()) do if rec.id == selectedID then return rec end end
    return nil
end
local function PlayerMatches(r)
    if not chosenPlayer then return true end
    local s=T(chosenPlayer)
    if T(r.winner)==s or T(r.winner):match("^([^-]+)")==s then return true end
    for _,v in ipairs(r.rolls or {}) do
        if T(v.name)==s or T(v.name):match("^([^-]+)")==s then return true end
    end
    return false
end
local function FilteredLoot()
    local rows={}
    for _,r in ipairs(FLJ.GetRecords()) do
        local valid = (gearFilter=="all" or (gearFilter=="armor" and r.classID==4) or (gearFilter=="weapons" and r.classID==2))
        if valid and PlayerMatches(r) and (searchText=="" or Includes(r.name,searchText) or Includes(r.winner,searchText) or Includes(r.zone,searchText) or Includes(r.subtype,searchText)) then
            rows[#rows+1]=r
        end
    end
    return rows
end
local function FilteredPlayers()
    local rows={}
    for _,p in ipairs(FLJ.GetPlayers()) do
        if playerSearch=="" or Includes(p.name,playerSearch) or Includes(p.class,playerSearch) or Includes(p.guild,playerSearch) then
            rows[#rows+1]=p
        end
    end
    return rows
end
local function TooltipOnEnter(self)
    local rec=self.record
    if rec and rec.link then
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(rec.link)
        GameTooltip:Show()
    end
end
local function TooltipOnLeave() GameTooltip:Hide() end
local function Icon(parent,x,y,size)
    local b=CreateFrame("Button",nil,parent)
    b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y)
    b:SetSize(size,size)
    local bg=Fill(b,{.12,.1,.075,1})
    Border(b,.58,.44,.21,1)
    b.tex=b:CreateTexture(nil,"ARTWORK")
    b.tex:SetPoint("TOPLEFT",2,-2); b.tex:SetPoint("BOTTOMRIGHT",-2,2)
    b.tex:SetTexture(placeholder)
    b:SetScript("OnEnter",TooltipOnEnter)
    b:SetScript("OnLeave",TooltipOnLeave)
    b:SetScript("OnClick",function(self)
        if self.record and self.record.link and IsModifiedClick() and HandleModifiedItemClick then
            HandleModifiedItemClick(self.record.link)
        end
    end)
    return b
end
local function ClassPortrait(parent,x,y,size)
    local t=parent:CreateTexture(nil,"ARTWORK")
    t:SetSize(size,size); t:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y)
    t:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
    function t:SetClass(class)
        local tc=classCoords[class] or classCoords.WARRIOR
        self:SetTexCoord(tc[1],tc[2],tc[3],tc[4])
    end
    t:SetClass("WARRIOR")
    return t
end
local function MakeItemRow(parent,index)
    local y=8+(index-1)*ITEM_ROW_HEIGHT
    local r=CreateFrame("Button",nil,parent)
    r:SetSize(776,ITEM_ROW_HEIGHT-4)
    r:SetPoint("TOPLEFT",parent,"TOPLEFT",8,-y)
    r.background=Fill(r,{.12,.103,.079,1})
    Border(r,.29,.23,.15,1)
    r.selected=MakeTexture(r,"BORDER",{.55,.39,.13,.25}); r.selected:SetAllPoints(); r.selected:Hide()
    r.icon=Icon(r,8,6,41)
    r.itemName=Label(r,"",14,gold)
    r.itemName:SetPoint("TOPLEFT",r,"TOPLEFT",60,-7)
    r.itemName:SetWidth(350)
    r.itemName:SetHeight(19)
    r.meta=Label(r,"",11,muted)
    r.meta:SetPoint("TOPLEFT",r,"TOPLEFT",60,-30)
    r.meta:SetWidth(370)
    r.winner=Label(r,"",12,parchment,"RIGHT")
    r.winner:SetPoint("TOPRIGHT",r,"TOPRIGHT",-10,-7)
    r.winner:SetWidth(280)
    r.when=Label(r,"",10,muted,"RIGHT")
    r.when:SetPoint("TOPRIGHT",r,"TOPRIGHT",-10,-31)
    r.when:SetWidth(280)
    r:SetScript("OnEnter",function(self) self.background:SetColorTexture(.18,.14,.09,1) end)
    r:SetScript("OnLeave",function(self) self.background:SetColorTexture(.12,.103,.079,1) end)
    r:SetScript("OnClick",function(self)
        if self.record then selectedID=self.record.id; detailRollOffset=0; UI.Refresh() end
    end)
    return r
end
local function SetRow(r,rec)
    r.record=rec; r.icon.record=rec
    r.icon.tex:SetTexture(rec.icon or placeholder)
    r.itemName:SetText(rec.name or "Unknown item")
    local q = rec.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[rec.quality]
    if q then r.itemName:SetTextColor(q.r,q.g,q.b) else r.itemName:SetTextColor(Color(gold)) end
    local kind=(rec.subtype or rec.type or "Equipment")
    local status=rec.status or "Recorded"
    r.meta:SetText((rec.itemLevel and ("iLvl "..rec.itemLevel.."   •   ") or "")..kind.."   •   "..status)
    r.winner:SetText("Obtained by: "..(rec.winner or "Unknown"))
    r.when:SetText((rec.zone or "Unknown zone").."   •   "..Date(rec.time))
    r.selected:SetShown(rec.id==selectedID)
    r:Show()
end
local function SetPlayerRow(r,pl)
    r.player=pl
    r.name:SetText(pl.name or "Unknown")
    r.name:SetTextColor(Color(PlayerColor(pl.class)))
    r.meta:SetText((pl.level and ("Lv "..pl.level.."  ") or "")..(pl.class or "Class unknown").."   •   "..tostring(pl.lootCount or 0).." won")
    r.live:SetText(pl.current and "●" or "")
    r.portrait:SetClass(pl.class)
    r.selected:SetShown(chosenPlayer and T(chosenPlayer)==T(pl.name))
    r:Show()
end
local function MakePlayerRow(parent,index)
    local y=10+(index-1)*PLAYER_ROW_HEIGHT
    local r=CreateFrame("Button",nil,parent)
    r:SetSize(247,38); r:SetPoint("TOPLEFT",parent,"TOPLEFT",5,-y)
    r.background=Fill(r,{.12,.11,.087,1})
    r.selected=MakeTexture(r,"BORDER",{.50,.35,.11,.24});r.selected:SetAllPoints();r.selected:Hide()
    r.portrait=ClassPortrait(r,5,5,28)
    r.name=Label(r,"",12,parchment)
    r.name:SetPoint("TOPLEFT",r,"TOPLEFT",40,-3);r.name:SetWidth(178)
    r.meta=Label(r,"",10,muted)
    r.meta:SetPoint("TOPLEFT",r,"TOPLEFT",40,-22);r.meta:SetWidth(200)
    r.live=Label(r,"",17,{.4,1,.4})
    r.live:SetPoint("TOPRIGHT",r,"TOPRIGHT",-4,-8)
    r:SetScript("OnEnter",function(self) self.background:SetColorTexture(.21,.16,.094,1) end)
    r:SetScript("OnLeave",function(self) self.background:SetColorTexture(.12,.11,.087,1) end)
    r:SetScript("OnClick",function(self)
        if self.player then
            if chosenPlayer and T(chosenPlayer)==T(self.player.name) then chosenPlayer=nil
            else chosenPlayer=self.player.name end
            listOffset=0;UI.Refresh()
        end
    end)
    return r
end
local function MakeDetail(parent)
    local p=Panel(parent,288,506,797,216,{.079,.073,.064,1})
    local hdr=p:CreateTexture(nil,"ARTWORK")
    hdr:SetTexture(TEXTURE.."detail")
    hdr:SetPoint("TOPLEFT",1,-1); hdr:SetPoint("TOPRIGHT",-1,-1); hdr:SetHeight(37)
    p.header=Label(p,"ITEM DETAILS & ROLL HISTORY",15,gold)
    p.header:SetPoint("TOPLEFT",p,"TOPLEFT",14,-10)
    p.icon=Icon(p,13,47,53)
    p.name=Label(p,"Select any item to view its equipment and roll details.",15,parchment)
    p.name:SetPoint("TOPLEFT",p,"TOPLEFT",80,-50); p.name:SetWidth(320)
    p.name:SetHeight(21)
    p.source=Label(p,"",11,muted)
    p.source:SetPoint("TOPLEFT",p,"TOPLEFT",80,-77);p.source:SetWidth(330)
    p.won=Label(p,"",12,gold)
    p.won:SetPoint("TOPLEFT",p,"TOPLEFT",80,-97);p.won:SetWidth(330)
    p.winnerInfo=Label(p,"",10,muted)
    p.winnerInfo:SetPoint("TOPLEFT",p,"TOPLEFT",80,-117);p.winnerInfo:SetWidth(322)
    p.classIcon=ClassPortrait(p,368,53,29);p.classIcon:Hide()
    p.statHead=Label(p,"ITEM STATS",11,gold)
    p.statHead:SetPoint("TOPLEFT",p,"TOPLEFT",14,-143)
    p.stats={}
    for i=1,3 do
        local tx=Label(p,"",11,parchment)
        tx:SetPoint("TOPLEFT",p,"TOPLEFT",14,-161-(i-1)*18)
        tx:SetWidth(379)
        p.stats[i]=tx
    end
    local separator=MakeTexture(p,"ARTWORK",{.37,.28,.16,1})
    separator:SetPoint("TOPLEFT",p,"TOPLEFT",407,-47)
    separator:SetPoint("BOTTOMLEFT",p,"BOTTOMLEFT",407,8)
    separator:SetWidth(1)
    local rollsHead=Label(p,"GROUP ROLLS  (Need / Greed / Pass)",11,gold)
    rollsHead:SetPoint("TOPLEFT",p,"TOPLEFT",424,-51)
    p.rollStatus=Label(p,"",11,muted)
    p.rollStatus:SetPoint("TOPLEFT",p,"TOPLEFT",424,-76)
    p.rollStatus:SetWidth(345)
    p.rollLines={}
    for i=1,6 do
        local tx=Label(p,"",11,parchment)
        tx:SetPoint("TOPLEFT",p,"TOPLEFT",424,-97-(i-1)*18)
        tx:SetWidth(356)
        p.rollLines[i]=tx
    end
    ScrollWheel(p,function(delta)
        local record=GetSelected()
        if record and #record.rolls > 6 then
            detailRollOffset=math.max(0,math.min(#record.rolls-6,detailRollOffset-delta*2))
            UI.Refresh()
        end
    end)
    return p
end
local function DetailRefresh()
    local rec=GetSelected()
    detail.icon.record=rec
    if not rec then
        detail.icon.tex:SetTexture(placeholder)
        detail.name:SetText("Select an item from the archive")
        detail.source:SetText("Full in-game tooltip appears when you hover its icon.")
        detail.won:SetText("")
        detail.winnerInfo:SetText("");detail.classIcon:Hide()
        for _,s in ipairs(detail.stats) do s:SetText("") end
        detail.rollStatus:SetText("Recorded rolls will appear here.")
        for _,s in ipairs(detail.rollLines) do s:SetText("") end
        return
    end
    detail.icon.tex:SetTexture(rec.icon or placeholder)
    detail.name:SetText(rec.name or "Unknown item")
    local q=ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[rec.quality or 1]
    if q then detail.name:SetTextColor(q.r,q.g,q.b) else detail.name:SetTextColor(Color(gold)) end
    detail.source:SetText((rec.zone or "Unknown zone").." • "..Date(rec.time))
    detail.won:SetText("Winner: "..(rec.winner or (rec.status=="All passed" and "No winner" or "Not yet known")))
    local found
    if rec.winner then
        for _,p in ipairs(FLJ.GetPlayers()) do
            if T(p.name)==T(rec.winner) or T(p.name):match("^([^-]+)")==T(rec.winner) then found=p;break end
        end
    end
    if found then
        local msg=(found.level and ("Lv "..found.level.." ") or "")..(found.class or "Class unknown")
        if found.race then msg=msg.." • "..found.race end
        if found.guild and found.guild~="" then msg=msg.." • <"..found.guild..">" end
        detail.winnerInfo:SetText(msg)
        detail.classIcon:SetClass(found.class)
        detail.classIcon:Show()
    else
        detail.winnerInfo:SetText(rec.winner and "Player details not available" or "")
        detail.classIcon:Hide()
    end
    local stats=rec.stats or {}
    local info={}
    if rec.itemLevel then info[#info+1]="Item level "..rec.itemLevel end
    if rec.subtype then info[#info+1]=rec.subtype end
    if rec.requiredLevel and rec.requiredLevel>0 then info[#info+1]="Requires level "..rec.requiredLevel end
    for _,s in ipairs(stats) do
        info[#info+1]=(s.label or s.key)..": "..(s.value>0 and "+" or "")..tostring(s.value)
    end
    for i,lab in ipairs(detail.stats) do
        lab:SetText(info[i] or (i==1 and "Hover the item icon for complete stats." or ""))
    end
    local rolls=rec.rolls or {}
    if #rolls==0 then
        detail.rollStatus:SetText(rec.source=="Group roll" and "Awaiting roll choices..." or "No group roll recorded for this item")
    else
        detail.rollStatus:SetText(tostring(#rolls).." participant(s)  •  "..(rec.status or "Recorded")..(#rolls>6 and "  •  Scroll to see all" or ""))
    end
    table.sort(rolls,function(a,b)
        if (not not a.winner) ~= (not not b.winner) then return a.winner end
        return (a.value or -1) > (b.value or -1)
    end)
    for i,line in ipairs(detail.rollLines) do
        local roll=rolls[i+detailRollOffset]
        if roll then
            local rv=roll.value and ("  ["..tostring(roll.value).."]") or ""
            local trophy=roll.winner and "★ " or "    "
            line:SetText(trophy..(roll.name or "Unknown").."  —  "..(roll.action or "Unknown")..rv)
            line:SetTextColor(Color(roll.winner and gold or PlayerColor(roll.class)))
        else
            line:SetText("")
        end
    end
end
local function DropdownRefresh()
    if not dropdown or not dropdown:IsShown() then return end
    local players=FilteredPlayers()
    for i,row in ipairs(dropdownRows) do
        local name
        if i==1 then name="All players" else name=players[i-1] and players[i-1].name end
        if name then
            row.label:SetText(name)
            row.itemName=name=="All players" and nil or name
            row:Show()
        else row:Hide() end
    end
end
local function BuildDropdown(parent)
    dropdown=CreateFrame("Frame",nil,parent)
    dropdown:SetSize(259,298)
    dropdown:SetPoint("TOPLEFT",parent,"TOPLEFT",13,-198)
    dropdown:SetFrameStrata("DIALOG")
    Fill(dropdown,{.07,.058,.041,.99})
    Border(dropdown,.68,.48,.22,2)
    local head=Label(dropdown,"CHOOSE A PLAYER",12,gold)
    head:SetPoint("TOPLEFT",dropdown,"TOPLEFT",13,-10)
    dropdownRows={}
    for i=1,10 do
        local y=31+(i-1)*26
        local b=CreateFrame("Button",nil,dropdown)
        b:SetSize(234,24)
        b:SetPoint("TOPLEFT",dropdown,"TOPLEFT",13,-y)
        local hl=b:CreateTexture(nil,"BACKGROUND")
        hl:SetColorTexture(.48,.31,.095,.19);hl:SetAllPoints();hl:Hide()
        b.label=Label(b,"",11,parchment)
        b.label:SetPoint("LEFT",b,"LEFT",5,0)
        b:SetScript("OnEnter",function() hl:Show() end)
        b:SetScript("OnLeave",function() hl:Hide() end)
        b:SetScript("OnClick",function(self)
            chosenPlayer=self.itemName;dropdown:Hide();listOffset=0;UI.Refresh()
        end)
        dropdownRows[i]=b
    end
    dropdown:Hide()
end
local function RefreshFilters()
    for k,b in pairs(filterButtons) do
        local chosen=gearFilter==k
        b.base:SetColorTexture(chosen and .39 or .16,chosen and .27 or .127,chosen and .095 or .087,1)
        b.label:SetTextColor(chosen and 1 or .73,chosen and .88 or .63,chosen and .46 or .32)
    end
end
function UI.Refresh()
    if not frame or not frame:IsShown() then return end
    local players=FilteredPlayers()
    local loot=FilteredLoot()
    local minPlayerOffset=math.max(0,#players-PLAYER_VISIBLE)
    if playerOffset>minPlayerOffset then playerOffset=minPlayerOffset end
    local minListOffset=math.max(0,#loot-ITEM_VISIBLE)
    if listOffset>minListOffset then listOffset=minListOffset end
    playerLabel:SetText(chosenPlayer and (chosenPlayer.."  ▼") or "All players  ▼")
    countText:SetText(tostring(#loot).." loot records  |  "..tostring(#FLJ.GetPlayers()).." known players")
    titleText:SetText("LOOT ARCHIVE")
    for i,r in ipairs(playerRows) do
        if players[i+playerOffset] then SetPlayerRow(r,players[i+playerOffset]) else r:Hide() end
    end
    for i,r in ipairs(itemRows) do
        local rec=loot[i+listOffset]
        if rec then SetRow(r,rec) else r:Hide() end
    end
    listEmpty:SetShown(#loot==0)
    if selectedID and not GetSelected() then selectedID=nil end
    if not selectedID and loot[1] then selectedID=loot[1].id end
    DetailRefresh()
    DropdownRefresh()
    RefreshFilters()
end
function FLJ.ShowClearConfirm()
    if not StaticPopupDialogs then return end
    if not StaticPopupDialogs["FOREVER_LOOT_JOURNAL_CLEAR"] then
        StaticPopupDialogs["FOREVER_LOOT_JOURNAL_CLEAR"]={
            text="Delete ALL recorded loot items? Your known player list will remain.",
            button1=YES,button2=NO,timeout=0,whileDead=true,hideOnEscape=true,preferredIndex=3,
            OnAccept=function() FLJ.ClearRecords();selectedID=nil;listOffset=0;UI.Refresh() end,
        }
    end
    StaticPopup_Show("FOREVER_LOOT_JOURNAL_CLEAR")
end
local function MakeFrame()
    frame=CreateFrame("Frame","ForeverLootJournalFrame",UIParent,"BackdropTemplate")
    frame:SetSize(W,H)
    frame:SetPoint("CENTER",UIParent,"CENTER",0,0)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true);frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart",function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
    frame:SetScript("OnShow",function() UI.Refresh() end)
    frame:SetScript("OnMouseDown",function() if dropdown then dropdown:Hide() end end)
    table.insert(UISpecialFrames,"ForeverLootJournalFrame")
    Fill(frame,shadow)
    Border(frame,.46,.35,.19,2)
    local inner=Panel(frame,9,9,W-18,H-18,{.16,.122,.077,1})
    local velvet=inner:CreateTexture(nil,"BACKGROUND")
    velvet:SetTexture(TEXTURE.."paper")
    velvet:SetAllPoints();velvet:SetAlpha(.84)
    local bgShade=MakeTexture(frame,"BORDER",{.02,.015,.009,.76})
    bgShade:SetPoint("TOPLEFT",frame,"TOPLEFT",15,-16)
    bgShade:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-15,15)
    local hdr=frame:CreateTexture(nil,"ARTWORK")
    hdr:SetTexture(TEXTURE.."banner")
    hdr:SetPoint("TOPLEFT",frame,"TOPLEFT",16,-15)
    hdr:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-16,-15)
    hdr:SetHeight(103)
    local lead=Label(frame,"FOREVER",18,{.88,.72,.37},"CENTER")
    lead:SetPoint("TOP",frame,"TOP",0,-21)
    lead:SetWidth(330)
    local title=Label(frame,"LOOT JOURNAL",27,{1,.84,.45},"CENTER")
    title:SetPoint("TOP",frame,"TOP",0,-44)
    title:SetWidth(450)
    local sub=Label(frame,"An archive of the treasures and rolls shared on your adventures",10,parchment,"CENTER")
    sub:SetPoint("TOP",frame,"TOP",0,-84);sub:SetWidth(550)
    local close=Button(frame,1053,19,27,25,"X",function()frame:Hide()end)
    close.label:SetTextColor(1,.30,.20)
    local side=Panel(frame,13,124,260,598,{.094,.073,.051,1})
    local sh=Label(side,"PARTY & RAID MEMBERS",14,gold)
    sh:SetPoint("TOPLEFT",side,"TOPLEFT",12,-12)
    local sdesc=Label(side,"Current party + everyone recorded",10,muted)
    sdesc:SetPoint("TOPLEFT",side,"TOPLEFT",12,-34)
    playerSearchBox=Edit(side,12,57,236,33,"Search player names...",function(s)
        playerSearch=T(s);playerOffset=0;UI.Refresh()
    end)
    local dropBtn=Button(side,12,102,236,32,"All players  ▼",function()
        dropdown:SetShown(not dropdown:IsShown());DropdownRefresh()
    end)
    playerLabel=dropBtn.label
    local live=Label(side,"●  Green = currently in your group",10,{.62,.79,.53})
    live:SetPoint("TOPLEFT",side,"TOPLEFT",13,-146)
    local roster=Panel(side,0,170,260,419,{.067,.061,.049,1})
    playerRows={}
    for i=1,PLAYER_VISIBLE do playerRows[i]=MakePlayerRow(roster,i) end
    ScrollWheel(roster,function(delta)
        playerOffset=math.max(0,math.min(math.max(0,#FilteredPlayers()-PLAYER_VISIBLE),playerOffset-delta*2))
        UI.Refresh()
    end)
    BuildDropdown(side)
    local mainTop=Panel(frame,284,124,803,61,{.105,.085,.055,1})
    titleText=Label(mainTop,"LOOT ARCHIVE",17,gold)
    titleText:SetPoint("TOPLEFT",mainTop,"TOPLEFT",14,-11)
    countText=Label(mainTop,"",10,muted)
    countText:SetPoint("TOPLEFT",mainTop,"TOPLEFT",14,-37)
    searchBox=Edit(frame,704,137,372,35,"Search gear, winner, zone...",function(s)
        searchText=T(s);listOffset=0;UI.Refresh()
    end)
    local filt=Panel(frame,284,193,803,41,{.091,.081,.064,1})
    filterButtons={}
    filterButtons.all=Button(filt,7,5,108,30,"All Equipment",function()gearFilter="all";listOffset=0;UI.Refresh()end)
    filterButtons.armor=Button(filt,121,5,96,30,"Armor",function()gearFilter="armor";listOffset=0;UI.Refresh()end)
    filterButtons.weapons=Button(filt,223,5,96,30,"Weapons",function()gearFilter="weapons";listOffset=0;UI.Refresh()end)
    Button(filt,568,5,112,30,"Refresh",function()
        if FLJ.RegisterRoster then FLJ.RegisterRoster() end
        UI.Refresh()
    end)
    Button(filt,686,5,107,30,"Clear log",function() FLJ.ShowClearConfirm() end)
    local list=Panel(frame,284,241,803,257,{.068,.057,.045,1})
    itemRows={}
    for i=1,ITEM_VISIBLE do itemRows[i]=MakeItemRow(list,i) end
    listEmpty=Label(list,"No matching loot yet. Items appear after your group obtains weapons or armor.",13,muted,"CENTER")
    listEmpty:SetPoint("CENTER",list,"CENTER",0,0)
    listEmpty:SetWidth(730)
    ScrollWheel(list,function(delta)
        listOffset=math.max(0,math.min(math.max(0,#FilteredLoot()-ITEM_VISIBLE),listOffset-delta*2))
        UI.Refresh()
    end)
    detail=MakeDetail(frame)
    local foot=Label(frame,"/flj to open • Wheel to scroll • Shift-click an item icon to link it in chat • Account-wide saved history",10,muted,"CENTER")
    foot:SetPoint("BOTTOM",frame,"BOTTOM",0,5);foot:SetWidth(W-40)
    frame:Hide()
end
function FLJ.Toggle(players)
    if not frame then MakeFrame() end
    if players then playerSearchBox:SetFocus() end
    if frame:IsShown() and not players then frame:Hide()
    else
        local scale=math.min(1,math.max(.62,UIParent:GetWidth()/(W+30)),math.max(.62,UIParent:GetHeight()/(H+25)))
        frame:SetScale(scale)
        frame:Show()
        UI.Refresh()
    end
end
-- Small optional minimap shortcut (left-click toggles the window).
local function MinimapShortcut()
    if not Minimap then return end
    local b=CreateFrame("Button","ForeverLootJournalMinimapButton",Minimap)
    b:SetSize(30,30); b:SetFrameStrata("MEDIUM")
    b:SetPoint("TOPLEFT",Minimap,"TOPLEFT",-9,12)
    b:SetNormalTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    b.icon=b:CreateTexture(nil,"ARTWORK")
    b.icon:SetSize(18,18);b.icon:SetPoint("CENTER",b,"CENTER",-1,1)
    b.icon:SetTexture("Interface\\Icons\\INV_Chest_Chain_05")
    b:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_LEFT")
        GameTooltip:AddLine("Forever Loot Journal",1,.8,.3)
        GameTooltip:AddLine("Left-click to browse the loot archive",.9,.9,.9)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave",function()GameTooltip:Hide()end)
    b:SetScript("OnClick",function() FLJ.Toggle() end)
end
MinimapShortcut()
