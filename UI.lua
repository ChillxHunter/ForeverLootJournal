-- Forever Loot Journal 1.5.0: option D charcoal / metal journal.
local addonName, FLJ = ...
FLJ.UI = FLJ.UI or {}
local UI = FLJ.UI
local W, H = 1100, 786
local Theme=FLJ.Theme
local journalParts={}
local gold = {1, .80, .27}
local parchment = {.87, .91, .98}
local muted = {.62, .64, .69}
local panel = {.030, .048, .081, 1}
local shadow = {.012, .021, .037, 1}
local currentTab, gearFilter, searchText, playerSearch, chosenPlayer = "loot", "all", "", "", nil
local selectedID, listOffset, playerOffset, detailRollOffset = nil, 0, 0, 0
local frame, itemRows, playerRows, detail, dropdown, dropdownRows
local headerTitle,headerSubtitle,headerEmblem
local searchBox, playerSearchBox, playerLabel, titleText, countText, listEmpty, mainSearchWrap
local tabButtons, filterButtons, clearPopup
local craftingPane, lootListPanel, craftingRows, craftingCount, craftingDetail, craftingSearch
local craftingQuery, craftingOffset, selectedCraftID, craftingMaterialsOffset = "",0,nil,0
local CRAFT_VISIBLE=8
local craftKind,craftTypeButtons="all",{}
local craftRange
local storageProfileButton, storageProfileMenu, storageProfileRows
local rarityButtons={}
local qualityMinimum, qualityFilterButton, archiveSummary, playerRange
local ITEM_VISIBLE = 5
local PLAYER_VISIBLE = 11
local ITEM_ROW_HEIGHT = 48
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
    if b>r+.08 then r,g,b=.29,.30,.33 end
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
    fs:SetFont((size or 13)>=17 and "Fonts\\FRIZQT__.TTF" or "Fonts\\ARIALN.TTF",size or 13, "")
    fs:SetText(text or "")
    fs:SetTextColor(Color(col or parchment))
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end
local function Panel(parent,x,y,w,h,bg)
    if parent==frame and y>=120 then y=y-44 end
    local p=CreateFrame("Frame", nil, parent)
    p:SetSize(w,h); p:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y)
    Fill(p,bg or panel)
    Border(p,.21,.31,.44,1)
    Theme.Paint(p,"d_panel","BORDER",8)
    return p
end
local function Button(parent,x,y,w,h,text,callback)
    local b=CreateFrame("Button",nil,parent)
    b:SetSize(w,h); b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y)
    b:EnableMouse(true)
    b:RegisterForClicks("LeftButtonUp")
    b.base=Fill(b,{.064,.094,.145,1})
    Border(b,.30,.40,.51,1)
    b.chrome=Theme.Paint(b,"d_button","BORDER",7)
    b.activeArt=Theme.Paint(b,"d_active","ARTWORK",7)
    b.activeArt:SetShown(false)
    b.highlight=MakeTexture(b,"ARTWORK",{.72,.51,.14,.18}); b.highlight:SetAllPoints(); b.highlight:Hide()
    b.label=Label(b,text or "",12,parchment,"CENTER"); b.label:SetAllPoints()
    b.activeEdge=MakeTexture(b,"OVERLAY",{.98,.77,.27,1})
    b.activeEdge:SetPoint("BOTTOMLEFT",b,"BOTTOMLEFT",3,3)
    b.activeEdge:SetPoint("BOTTOMRIGHT",b,"BOTTOMRIGHT",-3,3)
    b.activeEdge:SetHeight(2)
    b.activeEdge:Hide()
    b:SetScript("OnEnter",function(self) self.highlight:Show() end)
    b:SetScript("OnLeave",function(self) self.highlight:Hide() end)
    b:SetScript("OnClick",callback)
    return b
end
local function Edit(parent,x,y,w,h,hint,handler)
    local wrap=Panel(parent,x,y,w,h,{.055,.050,.043,1})
    local icon=wrap:CreateTexture(nil,"ARTWORK")
    icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    icon:SetSize(16,16)
    icon:SetPoint("LEFT",wrap,"LEFT",8,0)
    local edit=CreateFrame("EditBox",nil,wrap)
    edit:SetAutoFocus(false); edit:SetSize(w-42,h-8)
    edit:SetPoint("LEFT",wrap,"LEFT",28,0)
    edit:SetMaxLetters(70)
    edit:SetFont("Fonts\\ARIALN.TTF",13,"")
    edit:SetTextColor(.90,.94,1)
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
    if not ts or ts == 0 then return "--" end
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
-- Older SavedVariables can lack item-class IDs even though the gear was logged.
-- Resolve them from item metadata before applying the Armor/Weapons filter.
local function GearClass(rec)
    local classID=tonumber(rec.classID)
    if not classID and rec.link and FLJ.ItemInfo then
        local ok, info=pcall(FLJ.ItemInfo,rec.link)
        if ok and type(info)=="table" then
            local recovered=tonumber(info.classID)
            if recovered then
                classID=recovered
                rec.classID=recovered
            end
        end
    end
    return classID
end
local function FilteredLoot()
    local rows={}
    for _,r in ipairs(FLJ.GetRecords()) do
        local kind=GearClass(r)
        local valid=((gearFilter=="all" and (kind==2 or kind==4)) or (gearFilter=="armor" and kind==4) or (gearFilter=="weapons" and kind==2))
        if valid and (not qualityMinimum or (tonumber(r.quality) or -1)>=qualityMinimum) and PlayerMatches(r) and (searchText=="" or Includes(r.name,searchText) or Includes(r.winner,searchText) or Includes(r.zone,searchText) or Includes(r.subtype,searchText)) then
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
local function DisplayEnabled(key)
    local db=FLJ.GetDB and FLJ.GetDB()
    local options=db and db.ui and db.ui.displayOptions
    return type(options)~="table" or options[key]~=false
end
local function TooltipOnEnter(self)
    if not DisplayEnabled("itemTooltips") then return end
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
    local well=b:CreateTexture(nil,"BACKGROUND")
    well:SetTexture(TEXTURE.."f_icon_well");well:SetAllPoints()
    b.tex=b:CreateTexture(nil,"ARTWORK")
    b.tex:SetPoint("CENTER",b,"CENTER",0,0)
    b.tex:SetSize(size*.80,size*.80)
    b.tex:SetTexture(placeholder)
    if b.CreateMaskTexture and b.tex.AddMaskTexture then
        b.mask=b:CreateMaskTexture(nil,"ARTWORK")
        b.mask:SetTexture(TEXTURE.."f_circle_mask")
        b.mask:SetAllPoints(b.tex)
        b.tex:AddMaskTexture(b.mask)
    else
        b.tex:SetSize(size*.57,size*.57)
    end
    b.ring=b:CreateTexture(nil,"OVERLAY")
    b.ring:SetTexture(TEXTURE.."f_item_ring");b.ring:SetAllPoints()
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
    local f=CreateFrame("Frame",nil,parent)
    f:SetSize(size,size)
    f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y)
    Fill(f,{.06,.05,.04,1})
    Border(f,.48,.35,.17,1)
    f.face=f:CreateTexture(nil,"ARTWORK")
    f.face:SetPoint("TOPLEFT",f,"TOPLEFT",2,-2)
    f.face:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-2,2)
    f.fallback=f:CreateTexture(nil,"ARTWORK")
    f.fallback:SetPoint("TOPLEFT",f,"TOPLEFT",2,-2)
    f.fallback:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-2,2)
    f.fallback:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
    function f:SetClass(class)
        local coords=classCoords[class] or classCoords.WARRIOR
        self.fallback:SetTexCoord(coords[1],coords[2],coords[3],coords[4])
        self.face:Hide()
        self.fallback:Show()
    end
    function f:SetPlayer(player)
        local unit=player and FLJ.GetUnitForPlayer and FLJ.GetUnitForPlayer(player.name)
        if unit and UnitExists and UnitExists(unit) and SetPortraitTexture then
            SetPortraitTexture(self.face,unit)
            self.face:Show()
            self.fallback:Hide()
        else
            self:SetClass(player and player.class)
        end
    end
    f:SetClass("WARRIOR")
    return f
end
local function MakeItemRow(parent,index)
    local y=32+(index-1)*ITEM_ROW_HEIGHT
    local r=CreateFrame("Button",nil,parent)
    r:SetSize(776,ITEM_ROW_HEIGHT-4)
    r:SetPoint("TOPLEFT",parent,"TOPLEFT",8,-y)
    r.background=Fill(r,{.043,.047,.057,1})
    Border(r,.23,.34,.48,1)
    r.selected=r:CreateTexture(nil,"BORDER");r.selected:SetTexture(TEXTURE.."f_row_selected");r.selected:SetAllPoints();r.selected:Hide()
    r.hover=r:CreateTexture(nil,"ARTWORK");r.hover:SetTexture(TEXTURE.."f_row_hover");r.hover:SetAllPoints();r.hover:Hide()
    r.icon=Icon(r,5,2,40)
    r.itemName=Label(r,"",14,gold)
    r.itemName:SetPoint("TOPLEFT",r,"TOPLEFT",53,-6)
    r.itemName:SetWidth(350)
    r.itemName:SetHeight(19)
    r.meta=Label(r,"",11,muted)
    r.meta:SetPoint("TOPLEFT",r,"TOPLEFT",53,-27)
    r.meta:SetWidth(370)
    r.winner=Label(r,"",12,parchment,"RIGHT")
    r.winner:SetPoint("TOPRIGHT",r,"TOPRIGHT",-12,-6)
    r.winner:SetWidth(280)
    r.when=Label(r,"",10,muted,"RIGHT")
    r.when:SetPoint("TOPRIGHT",r,"TOPRIGHT",-12,-28)
    r.when:SetWidth(280)
    r:SetScript("OnEnter",function(self) self.hover:Show() end)
    r:SetScript("OnLeave",function(self) self.hover:Hide() end)
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
    r.meta:SetText((rec.itemLevel and ("iLvl "..rec.itemLevel.."   |   ") or "")..kind.."   |   "..status)
    r.winner:SetText(rec.winner or (rec.status=="All passed" and "All passed" or "Awaiting winner"))
    r.when:SetText((rec.zone or "Unknown zone").."   |   "..Date(rec.time))
    r.selected:SetShown(rec.id==selectedID)
    r:Show()
end
local function SetPlayerRow(r,pl)
    r.player=pl
    r.name:SetText(pl.name or "Unknown")
    r.name:SetTextColor(Color(DisplayEnabled("classColors") and PlayerColor(pl.class) or parchment))
    r.meta:SetText((pl.level and ("Lv "..pl.level.."  ") or "")..(pl.class or "Class unknown").."   |   "..tostring(pl.lootCount or 0).." won")
    r.live:SetShown(pl.current and DisplayEnabled("groupMarkers") or false)
    r.portrait:SetPlayer(pl)
    r.selected:SetShown(chosenPlayer and T(chosenPlayer)==T(pl.name))
    r:Show()
end
local function MakePlayerRow(parent,index)
    local y=10+(index-1)*PLAYER_ROW_HEIGHT
    local r=CreateFrame("Button",nil,parent)
    r:SetSize(247,38); r:SetPoint("TOPLEFT",parent,"TOPLEFT",5,-y)
    r.background=Fill(r,{.055,.082,.125,1})
    r.selected=MakeTexture(r,"BORDER",{.57,.42,.12,.33});r.selected:SetAllPoints();r.selected:Hide()
    r.portrait=ClassPortrait(r,5,5,28)
    r.name=Label(r,"",12,parchment)
    r.name:SetPoint("TOPLEFT",r,"TOPLEFT",40,-3);r.name:SetWidth(178)
    r.meta=Label(r,"",10,muted)
    r.meta:SetPoint("TOPLEFT",r,"TOPLEFT",40,-22);r.meta:SetWidth(200)
    r.live=CreateFrame("Frame",nil,r)
    r.live:SetSize(10,10)
    r.live:SetPoint("TOPRIGHT",r,"TOPRIGHT",-7,-8)
    local dot=MakeTexture(r.live,"ARTWORK",{.37,.92,.35,1})
    dot:SetPoint("TOPLEFT",r.live,"TOPLEFT",2,-2)
    dot:SetPoint("BOTTOMRIGHT",r.live,"BOTTOMRIGHT",-2,2)
    Border(r.live,.23,.3,.18,1)
    r:RegisterForClicks("LeftButtonUp","RightButtonUp")
    r:SetScript("OnEnter",function(self)
        self.background:SetColorTexture(.13,.19,.27,1)
        if self.player and GameTooltip then
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:AddLine(self.player.name or "Player",1,.82,.33)
            GameTooltip:AddLine("Left-click: filter loot history",.9,.9,.9)
            GameTooltip:AddLine("Right-click: player actions",.9,.9,.9)
            GameTooltip:Show()
        end
    end)
    r:SetScript("OnLeave",function(self)
        self.background:SetColorTexture(.055,.082,.125,1)
        if GameTooltip then GameTooltip:Hide() end
    end)
    r:SetScript("OnClick",function(self,mouseButton)
        if not self.player then return end
        if mouseButton=="RightButton" then
            if FLJ.ShowPlayerContextMenu then
                FLJ.ShowPlayerContextMenu(self,self.player)
            end
            return
        end
        if chosenPlayer and T(chosenPlayer)==T(self.player.name) then
            chosenPlayer=nil
        else
            chosenPlayer=self.player.name
        end
        listOffset=0
        UI.Refresh()
    end)
    return r
end
local function MakeDetail(parent)
    local p=Panel(parent,288,531,797,255,{.030,.048,.081,1})
    local hdr=p:CreateTexture(nil,"ARTWORK")
    hdr:SetTexture("Interface\\Buttons\\WHITE8X8")
    hdr:SetVertexColor(.055,.059,.070,1)
    hdr:SetPoint("TOPLEFT",1,-1); hdr:SetPoint("TOPRIGHT",-1,-1); hdr:SetHeight(37)
    p.header=Label(p,"ITEM DETAILS & ROLL HISTORY",15,gold)
    p.header:SetPoint("TOPLEFT",p,"TOPLEFT",14,-10)
    p.icon=Icon(p,13,47,53)
    p.name=Label(p,"Select any item to view its equipment and roll details.",15,parchment)
    p.name:SetPoint("TOPLEFT",p,"TOPLEFT",80,-50); p.name:SetWidth(274)
    p.name:SetHeight(21)
    p.source=Label(p,"",11,muted)
    p.source:SetPoint("TOPLEFT",p,"TOPLEFT",80,-77);p.source:SetWidth(274)
    p.won=Label(p,"",12,gold)
    p.won:SetPoint("TOPLEFT",p,"TOPLEFT",80,-97);p.won:SetWidth(274)
    p.winnerInfo=Label(p,"",10,muted)
    p.winnerInfo:SetPoint("TOPLEFT",p,"TOPLEFT",80,-117);p.winnerInfo:SetWidth(274)
    p.classIcon=ClassPortrait(p,368,53,29);p.classIcon:Hide()
    p.statHead=Label(p,"ITEM STATS",11,gold)
    p.statHead:SetPoint("TOPLEFT",p,"TOPLEFT",14,-133)
    p.stats={}
    for i=1,6 do
        local tx=Label(p,"",11,parchment)
        tx:SetPoint("TOPLEFT",p,"TOPLEFT",14,-151-(i-1)*16)
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
    for i=1,9 do
        local tx=Label(p,"",11,parchment)
        tx:SetPoint("TOPLEFT",p,"TOPLEFT",424,-97-(i-1)*17)
        tx:SetWidth(356)
        p.rollLines[i]=tx
    end
    ScrollWheel(p,function(delta)
        local record=GetSelected()
        if record and record.rolls and #record.rolls > 9 then
            detailRollOffset=math.max(0,math.min(#record.rolls-9,detailRollOffset-delta*2))
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
    detail.source:SetText((rec.zone or "Unknown zone").." | "..Date(rec.time))
    detail.won:SetText("Winner: "..(rec.winner or (rec.status=="All passed" and "No winner" or "Not yet known")))
    local found
    if rec.winner then
        for _,p in ipairs(FLJ.GetPlayers()) do
            if T(p.name)==T(rec.winner) or T(p.name):match("^([^-]+)")==T(rec.winner) then found=p;break end
        end
    end
    if found then
        local msg=(found.level and ("Lv "..found.level.." ") or "")..(found.class or "Class unknown")
        if found.race then msg=msg.." | "..found.race end
        if found.guild and found.guild~="" then msg=msg.." | <"..found.guild..">" end
        detail.winnerInfo:SetText(msg)
        detail.classIcon:SetPlayer(found)
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
        local value=tonumber(s.value)
        local formatted=value and string.format(value%1==0 and "%.0f" or "%.2f",value) or tostring(s.value or "--")
        info[#info+1]=(s.label or s.key or "Stat")..": "..(value and value>0 and "+" or "")..formatted
    end
    for i,lab in ipairs(detail.stats) do
        lab:SetText(info[i] or (i==1 and "Hover the item icon for complete stats." or ""))
    end
    -- Sorting for display must not reorder the persisted roll history.
    local rolls={}
    for _,roll in ipairs(rec.rolls or {}) do rolls[#rolls+1]=roll end
    detailRollOffset=math.min(detailRollOffset,math.max(0,#rolls-9))
    if #rolls==0 then
        detail.rollStatus:SetText(rec.source=="Group roll" and "Awaiting roll choices..." or "No group roll recorded for this item")
    else
        detail.rollStatus:SetText(tostring(#rolls).." participant(s)  |  "..(rec.status or "Recorded")..(#rolls>9 and "  |  Scroll to see all" or ""))
    end
    table.sort(rolls,function(a,b)
        if (not not a.winner) ~= (not not b.winner) then return a.winner end
        return (a.value or -1) > (b.value or -1)
    end)
    for i,line in ipairs(detail.rollLines) do
        local roll=rolls[i+detailRollOffset]
        if roll then
            local rv=roll.value and ("  ["..tostring(roll.value).."]") or ""
            local trophy=roll.winner and "WIN " or "    "
            line:SetText(trophy..(roll.name or "Unknown").."  -  "..(roll.action or "Unknown")..rv)
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
-- Crafting uses the actual recorded drops and the current player filter.
local function CraftMatch(r)
    local cls=tonumber(r.classID)
    if craftKind=="recipes" and cls~=9 then return false end
    if craftKind=="materials" and cls~=5 and cls~=7 then return false end
    if craftKind=="tools" and cls~=19 then return false end
    if r.record and not PlayerMatches(r.record) then return false end
    return craftingQuery=="" or Includes(r.name,craftingQuery) or Includes(r.profession,craftingQuery)
        or Includes(r.foundBy,craftingQuery) or Includes(r.zone,craftingQuery) or Includes(r.kind,craftingQuery)
end
local function CraftList()
    local craft=FLJ.Crafting
    local filtered={}
    for _,r in ipairs(craft and craft.GetDrops and craft.GetDrops() or {}) do
        if CraftMatch(r) then filtered[#filtered+1]=r end
    end
    return filtered
end
local function CraftingRefresh()
    if not craftingPane or gearFilter~="crafting" then return end
    local results=CraftList()
    craftingOffset=math.max(0,math.min(craftingOffset,math.max(0,#results-CRAFT_VISIBLE)))
    local current
    for _,r in ipairs(results) do
        if r.recipeID==selectedCraftID then current=r;break end
    end
    if not current then current=results[1];selectedCraftID=current and current.recipeID or nil end
    for key,b in pairs(craftTypeButtons) do
        b.activeArt:SetShown(key==craftKind)
        b.activeEdge:SetShown(key==craftKind)
    end
    titleText:SetText("CRAFTING DROPS")
    countText:SetText(#results.." matching loot drops"..(chosenPlayer and ("  |  "..chosenPlayer) or ""))
    craftingCount:SetText("Recipes, plans, materials and profession items obtained by your group")
    if craftRange then craftRange:SetText(#results==0 and "No matching drops" or (craftingOffset+1).."-"..math.min(#results,craftingOffset+CRAFT_VISIBLE).." of "..#results.." drops") end
    for i,row in ipairs(craftingRows) do
        local r=results[i+craftingOffset]
        row.recipe=r
        if r then
            row.icon.tex:SetTexture(r.icon or placeholder)
            row.icon.record=r.record
            row.name:SetText(r.name or "Unknown item")
            local color=ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[r.quality or 1]
            row.name:SetTextColor(color and color.r or 1,color and color.g or .85,color and color.b or .55)
            row.meta:SetText((r.profession or r.kind).."  |  "..(r.foundBy or "Awaiting winner"))
            row.highlight:SetShown(r.recipeID==selectedCraftID)
            row:Show()
        else row:Hide() end
    end
    craftingDetail.icon.record=current and current.record or nil
    for _,line in ipairs(craftingDetail.lines) do line:SetText("") end
    if not current then
        craftingDetail.icon.tex:SetTexture(placeholder)
        craftingDetail.name:SetText("No matching crafting drops")
        craftingDetail.profession:SetText("Recipes, plans, materials and profession gear")
        craftingDetail.known:SetText("Recorded loot will appear here as your group obtains it.")
        craftingDetail.materialsTitle:SetText("DROP DETAILS")
        return
    end
    craftingDetail.icon.tex:SetTexture(current.icon or placeholder)
    craftingDetail.name:SetText(current.name or "Unknown item")
    craftingDetail.profession:SetText(current.profession or current.kind)
    craftingDetail.known:SetText("Obtained by: "..(current.foundBy or "Awaiting winner"))
    craftingDetail.materialsTitle:SetText("DROP DETAILS")
    local lines={
        "Type: "..current.kind,
        "Location: "..(current.zone or "Unknown"),
        "Recorded: "..Date(current.date),
        "Source: "..(current.source or "Loot"),
        "Status: "..(current.status or "Received"),
    }
    if current.itemLevel then lines[#lines+1]="Item level: "..current.itemLevel end
    if current.requiredLevel and current.requiredLevel>0 then lines[#lines+1]="Requires level: "..current.requiredLevel end
    lines[#lines+1]="Hover the icon for the complete item tooltip."
    for i,line in ipairs(craftingDetail.lines) do line:SetText(lines[i] or "") end
end
local function MakeCraftingPane(parent)
    craftingPane=Panel(parent,284,241,803,545,{.030,.048,.081,1})
    local heading=Label(craftingPane,"PROFESSION LOOT",15,gold)
    heading:SetPoint("TOPLEFT",craftingPane,"TOPLEFT",13,-16)
    craftingCount=Label(craftingPane,"Recipes, plans, materials and profession gear",10,muted)
    craftingCount:SetPoint("TOPLEFT",craftingPane,"TOPLEFT",13,-42)
    craftingSearch=Edit(craftingPane,420,11,370,34,"Search item, profession, player, zone...",function(value)
        craftingQuery=T(value)
        craftingOffset=0
        selectedCraftID=nil
        CraftingRefresh()
    end)
    local listPanel=Panel(craftingPane,11,94,390,439,{.020,.034,.059,1})
    local detailPanel=Panel(craftingPane,413,94,377,439,{.026,.043,.072,1})
    for i,option in ipairs({{"all","All drops",103},{"recipes","Recipes / Plans",133},{"materials","Materials",103},{"tools","Profession gear",133}}) do
        local id=option[1]
        local x=13+(i-1)*120
        if i==2 then x=123 elseif i==3 then x=264 elseif i==4 then x=374 end
        local b=Button(craftingPane,x,62,option[3],24,option[2],function()
            craftKind=id;craftingOffset=0;selectedCraftID=nil;CraftingRefresh()
        end)
        craftTypeButtons[id]=b
    end
    craftingRows={}
    for i=1,CRAFT_VISIBLE do
        local row=CreateFrame("Button",nil,listPanel)
        row:SetSize(372,47)
        row:SetPoint("TOPLEFT",listPanel,"TOPLEFT",9,-8-(i-1)*50)
        Fill(row,{.050,.076,.118,1})
        Border(row,.23,.34,.48,1)
        row.highlight=row:CreateTexture(nil,"BORDER");row.highlight:SetTexture(TEXTURE.."f_row_selected")
        row.highlight:SetAllPoints()
        row.highlight:Hide()
        row.icon=Icon(row,4,3,41)
        row.name=Label(row,"",12,parchment)
        row.name:SetPoint("TOPLEFT",row,"TOPLEFT",52,-5)
        row.name:SetWidth(303)
        row.meta=Label(row,"",10,muted)
        row.meta:SetPoint("TOPLEFT",row,"TOPLEFT",52,-27)
        row.meta:SetWidth(300)
        row:RegisterForClicks("LeftButtonUp")
        row:SetScript("OnClick",function(self)
            if self.recipe then
                selectedCraftID=self.recipe.recipeID
                craftingMaterialsOffset=0
                CraftingRefresh()
            end
        end)
        craftingRows[i]=row
    end
    ScrollWheel(listPanel,function(delta)
        craftingOffset=math.max(0,math.min(math.max(0,#CraftList()-CRAFT_VISIBLE),craftingOffset-delta*2))
        CraftingRefresh()
    end)
    craftRange=Label(listPanel,"",10,muted)
    craftRange:SetPoint("TOPLEFT",listPanel,"TOPLEFT",12,-418)
    craftRange:SetWidth(290)
    Button(listPanel,326,413,22,20,"^",function()
        craftingOffset=math.max(0,craftingOffset-CRAFT_VISIBLE);CraftingRefresh()
    end)
    Button(listPanel,354,413,22,20,"v",function()
        craftingOffset=math.min(math.max(0,#CraftList()-CRAFT_VISIBLE),craftingOffset+CRAFT_VISIBLE);CraftingRefresh()
    end)
    craftingDetail={}
    craftingDetail.icon=Icon(detailPanel,14,15,53)
    craftingDetail.name=Label(detailPanel,"Select a drop",15,gold)
    craftingDetail.name:SetPoint("TOPLEFT",detailPanel,"TOPLEFT",76,-21)
    craftingDetail.name:SetWidth(285)
    craftingDetail.profession=Label(detailPanel,"",12,parchment)
    craftingDetail.profession:SetPoint("TOPLEFT",detailPanel,"TOPLEFT",14,-84)
    craftingDetail.profession:SetWidth(340)
    craftingDetail.known=Label(detailPanel,"",11,muted)
    craftingDetail.known:SetPoint("TOPLEFT",detailPanel,"TOPLEFT",14,-108)
    craftingDetail.known:SetWidth(344)
    craftingDetail.known:SetHeight(22)
    craftingDetail.materialsTitle=Label(detailPanel,"DROP DETAILS",12,gold)
    craftingDetail.materialsTitle:SetPoint("TOPLEFT",detailPanel,"TOPLEFT",14,-151)
    craftingDetail.lines={}
    for i=1,13 do
        local line=Label(detailPanel,"",11,parchment)
        line:SetPoint("TOPLEFT",detailPanel,"TOPLEFT",15,-178-(i-1)*20)
        line:SetWidth(343)
        craftingDetail.lines[i]=line
    end
    ScrollWheel(detailPanel,function(delta)
        local selected
        for _,r in ipairs(CraftList()) do
            if r.recipeID==selectedCraftID then selected=r;break end
        end
        local count=selected and #(selected.materials or {}) or 0
        craftingMaterialsOffset=math.max(0,math.min(math.max(0,count-#craftingDetail.lines),craftingMaterialsOffset-delta))
        CraftingRefresh()
    end)
    craftingPane:Hide()
end

local function RefreshFilters()
    for k,b in pairs(filterButtons or {}) do
        local chosen=gearFilter==k
        b.base:SetColorTexture(chosen and .33 or .065,chosen and .23 or .10,chosen and .055 or .15,1)
        b.label:SetTextColor(chosen and 1 or .73,chosen and .88 or .63,chosen and .46 or .32)
        if b.activeEdge then b.activeEdge:SetShown(chosen) end
        if b.activeArt then b.activeArt:SetShown(chosen) end
    end
end
local function SelectGearFilter(nextFilter)
    if nextFilter~="all" and nextFilter~="armor" and nextFilter~="weapons" and nextFilter~="crafting" then return end
    gearFilter=nextFilter
    selectedID=nil
    listOffset=0
    detailRollOffset=0
    UI.Refresh()
end
local function FormatLimit(n)
    local v=tostring(tonumber(n) or 0)
    return v:reverse():gsub("(%d%d%d)(%d)","%1,%2"):reverse()
end
local function RefreshStorageProfile()
    if not storageProfileButton or not FLJ.GetStoragePreset then return end
    local current,limit,label=FLJ.GetStoragePreset()
    storageProfileButton.label:SetText(label.."  -  "..FormatLimit(limit))
    if not storageProfileRows then return end
    for key,button in pairs(storageProfileRows) do
        local active=key==current
        button.base:SetColorTexture(active and .38 or .16,active and .27 or .127,active and .11 or .087,1)
        button.label:SetTextColor(active and 1 or .91,active and .84 or .76,active and .35 or .59)
        if button.activeEdge then button.activeEdge:SetShown(active) end
    end
end
local pendingStorage
local function ApplyStoragePreset(key)
    if not FLJ.SetStoragePreset then return end
    local ok,removed=FLJ.SetStoragePreset(key)
    if ok then
        selectedID=nil
        listOffset=0
        detailRollOffset=0
        RefreshStorageProfile()
        UI.Refresh()
        local _,limit,label=FLJ.GetStoragePreset()
        print("|cffffd76aForever Loot Journal:|r "..label.." selected. Storing up to "..
            FormatLimit(limit).." loot records."..
            (removed>0 and (" Removed "..FormatLimit(removed).." oldest records.") or ""))
    end
end
local function SelectStoragePreset(key)
    local profile=FLJ.StoragePresets and FLJ.StoragePresets[key]
    if not profile then return end
    if storageProfileMenu then storageProfileMenu:Hide() end
    local current=FLJ.GetStoragePreset()
    if current==key then return end
    local count=#FLJ.GetRecords()
    if count>profile.limit then
        if not StaticPopupDialogs or not StaticPopup_Show then
            print("|cffffd76aForever Loot Journal:|r Cannot lower the limit without a confirmation popup.")
            return
        end
        local dialogKey="FOREVER_LOOT_JOURNAL_STORAGE_PROFILE"
        if not StaticPopupDialogs[dialogKey] then
            StaticPopupDialogs[dialogKey]={
                text="Switch to %s?\n%s OLDEST loot records will be permanently deleted.\nThis cannot be undone.",
                button1=YES or "Confirm",button2=NO or "Cancel",
                timeout=0,whileDead=true,hideOnEscape=true,preferredIndex=3,
                OnAccept=function(_,data)
                    local chosen=data or pendingStorage
                    pendingStorage=nil
                    ApplyStoragePreset(chosen)
                end,
                OnCancel=function() pendingStorage=nil end,
            }
        end
        pendingStorage=key
        StaticPopup_Show(dialogKey,profile.label.." ("..FormatLimit(profile.limit)..")",FormatLimit(count-profile.limit),key)
    else
        ApplyStoragePreset(key)
    end
end
local function BuildStorageProfileMenu(parent)
    storageProfileMenu=CreateFrame("Frame",nil,parent)
    storageProfileMenu:SetSize(243,194)
    storageProfileMenu:SetPoint("TOPLEFT",parent,"TOPLEFT",819,-105)
    storageProfileMenu:SetFrameStrata("DIALOG")
    storageProfileMenu:SetFrameLevel(parent:GetFrameLevel()+32)
    storageProfileMenu:EnableMouse(true)
    Fill(storageProfileMenu,{.065,.051,.032,.99})
    Border(storageProfileMenu,.71,.52,.23,2)
    storageProfileRows={}
    for i,key in ipairs(FLJ.StoragePresetOrder or {}) do
        local profileKey=key
        local entry=FLJ.StoragePresets[profileKey]
        local text=entry.label.."  -  "..FormatLimit(entry.limit).." saved"
        local b=Button(storageProfileMenu,6,5+(i-1)*37,231,33,text,function()
            SelectStoragePreset(profileKey)
        end)
        b:SetFrameLevel(storageProfileMenu:GetFrameLevel()+1)
        storageProfileRows[key]=b
    end
    storageProfileMenu:Hide()
    RefreshStorageProfile()
end

-- Individual rarity registration switches; they never hide or delete saved loot.
local function RefreshRarityButtons()
    if not FLJ.IsRarityEnabled then return end
    for quality,b in pairs(rarityButtons) do
        local enabled=FLJ.IsRarityEnabled(quality)
        local rgb=b.rarityColor or gold
        b.base:SetColorTexture(enabled and .19 or .08,enabled and .16 or .07,enabled and .105 or .06,1)
        b.label:SetTextColor(enabled and rgb[1] or .45,enabled and rgb[2] or .43,enabled and rgb[3] or .4)
        b.state:SetText(enabled and "ON" or "OFF")
        b.state:SetTextColor(enabled and .48 or 1,enabled and .92 or .37,enabled and .43 or .34)
        if b.activeEdge then b.activeEdge:SetShown(enabled) end
    end
end
local function BuildRarityRegistration(parent)
    local heading=Label(parent,"SAVE NEW LOOT:",11,gold)
    heading:SetPoint("TOPLEFT",parent,"TOPLEFT",21,-99)
    for i,rarity in ipairs(FLJ.RarityOptions or {}) do
        local id=rarity.id -- capture per iteration for WoW Lua 5.1 callbacks
        local rarityName, rarityColor=rarity.label,rarity.color
        local b=Button(parent,152+(i-1)*81,92,78,28,rarityName,function()
            if FLJ.SetRarityEnabled then
                FLJ.SetRarityEnabled(id,not FLJ.IsRarityEnabled(id))
                RefreshRarityButtons()
            end
        end)
        b:SetFrameLevel(parent:GetFrameLevel()+25)
        b.rarityColor=rarityColor
        b.label:ClearAllPoints()
        b.label:SetPoint("TOP",b,"TOP",0,-2)
        b.label:SetWidth(76)
        b.label:SetHeight(14)
        b.label:SetFont("Fonts\\FRIZQT__.TTF",10,"OUTLINE")
        b.state=Label(b,"ON",9,{.48,.92,.43},"CENTER")
        b.state:SetPoint("BOTTOM",b,"BOTTOM",0,2)
        b.state:SetWidth(75)
        b:SetScript("OnEnter",function(self)
            self.highlight:Show()
            GameTooltip:SetOwner(self,"ANCHOR_BOTTOM")
            GameTooltip:AddLine(rarityName.." registration: "..(FLJ.IsRarityEnabled(id) and "ON" or "OFF"),
                rarityColor[1],rarityColor[2],rarityColor[3])
            GameTooltip:AddLine("Click to toggle saving NEW drops of this rarity.",1,1,1)
            GameTooltip:AddLine("Previously recorded items are never deleted.",.70,.85,1)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave",function(self)
            self.highlight:Hide()
            GameTooltip:Hide()
        end)
        rarityButtons[id]=b
    end
    RefreshRarityButtons()
end

function UI.Refresh()
    if not frame or not frame:IsShown() then return end
    if FLJ.SettingsUI and FLJ.SettingsUI.IsShown and FLJ.SettingsUI.IsShown() then
        FLJ.SettingsUI.Refresh()
        return
    end
    local crafting=gearFilter=="crafting"
    if mainSearchWrap then mainSearchWrap:SetShown(not crafting) end
    if qualityFilterButton then qualityFilterButton:SetShown(not crafting) end
    if lootListPanel then lootListPanel:SetShown(not crafting) end
    if detail then detail:SetShown(not crafting) end
    if craftingPane then craftingPane:SetShown(crafting) end
    local players=FilteredPlayers()
    playerOffset=math.max(0,math.min(playerOffset,math.max(0,#players-PLAYER_VISIBLE)))
    playerLabel:SetText(chosenPlayer or "All players")
    if playerRange then playerRange:SetText(#players.." players"..(chosenPlayer and "  |  Filter active" or "")) end
    if archiveSummary then
        local _,limit=FLJ.GetStoragePreset()
        local recipes=FLJ.Crafting and FLJ.Crafting.GetRecipes and #FLJ.Crafting.GetRecipes() or 0
        archiveSummary.saved:SetText(FormatLimit(#FLJ.GetRecords()))
        archiveSummary.players:SetText(tostring(#FLJ.GetPlayers()))
        archiveSummary.crafting:SetText(tostring(recipes))
    end
    if crafting then
        for i,r in ipairs(playerRows) do
            local pl=players[i+playerOffset]
            if pl then SetPlayerRow(r,pl) else r:Hide() end
        end
        CraftingRefresh()
        DropdownRefresh()
        RefreshFilters()
        RefreshStorageProfile()
        RefreshRarityButtons()
        return
    end
    local loot=FilteredLoot()
    local minPlayerOffset=math.max(0,#players-PLAYER_VISIBLE)
    if playerOffset>minPlayerOffset then playerOffset=minPlayerOffset end
    local minListOffset=math.max(0,#loot-ITEM_VISIBLE)
    if listOffset>minListOffset then listOffset=minListOffset end
    playerLabel:SetText(chosenPlayer or "All players")
    local filterName=gearFilter=="armor" and "ARMOR" or gearFilter=="weapons" and "WEAPONS" or "ALL EQUIPMENT"
    countText:SetText(filterName.."  |  "..(#loot>0 and (listOffset+1).."-"..math.min(#loot,listOffset+ITEM_VISIBLE).." of " or "")..#loot.." records"..(qualityMinimum and ("  |  "..(qualityMinimum==3 and "Rare+" or "Epic+")) or ""))
    titleText:SetText("LOOT ARCHIVE")
    for i,r in ipairs(playerRows) do
        if players[i+playerOffset] then SetPlayerRow(r,players[i+playerOffset]) else r:Hide() end
    end
    listEmpty:SetShown(#loot==0)
    local selectedVisible=false
    if selectedID then
        for _,rec in ipairs(loot) do
            if rec.id==selectedID then selectedVisible=true; break end
        end
    end
    if not selectedVisible then
        selectedID=loot[1] and loot[1].id or nil
        detailRollOffset=0
    end
    for i,r in ipairs(itemRows) do
        local rec=loot[i+listOffset]
        if rec then SetRow(r,rec) else r:Hide() end
    end
    DetailRefresh()
    DropdownRefresh()
    RefreshFilters()
    RefreshStorageProfile()
    RefreshRarityButtons()
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
function UI.SetHeaderMode(mode)
    if not headerTitle then return end
    local settings=mode=="settings"
    for _,p in ipairs(journalParts) do p:SetShown(not settings) end
    frame:SetHeight(settings and 560 or H)
    archiveSummary:SetShown(not settings)
    if dropdown then dropdown:Hide() end
    if mode=="settings" then
        headerTitle:SetText("Settings")
        headerSubtitle:SetText("")
        if headerEmblem then headerEmblem:SetTexture(TEXTURE.."d_crest") end
    else
        headerTitle:SetText("Forever Loot Journal")
        headerSubtitle:SetText("Loot tracker  |  Crafting journal  |  Party & raid history")
        if headerEmblem then headerEmblem:SetTexture(TEXTURE.."d_journal_crest") end
    end
    if UI.FitWindow then UI.FitWindow() end
    if not settings then UI.Refresh() end
end
local function MakeFrame()
    frame=CreateFrame("Frame","ForeverLootJournalFrame",UIParent,"BackdropTemplate")
    frame:SetSize(W,H)
    frame:SetPoint("CENTER",UIParent,"CENTER",0,0)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true);frame:EnableMouse(true)
    -- Only the title bar may drag the window. Dragging the entire root frame
    -- can capture mouse clicks intended for filter buttons and other controls.
    local dragHandle=CreateFrame("Frame",nil,frame)
    dragHandle:SetPoint("TOPLEFT",frame,"TOPLEFT",16,-15)
    dragHandle:SetSize(960,54)
    dragHandle:EnableMouse(true)
    dragHandle:RegisterForDrag("LeftButton")
    dragHandle:SetScript("OnDragStart",function() frame:StartMoving() end)
    dragHandle:SetScript("OnDragStop",function() frame:StopMovingOrSizing() end)
    frame:SetScript("OnShow",function() UI.Refresh() end)
    frame:SetScript("OnMouseDown",function() if dropdown then dropdown:Hide() end end)
    table.insert(UISpecialFrames,"ForeverLootJournalFrame")
    Fill(frame,shadow)
    Theme.Paint(frame,"d_window","BORDER",24)
    -- Root artwork must stay on the root. An opaque full-size child frame
    -- renders above its parent's title, banner, borders and other regions.
    Fill(frame,{.025,.044,.072,1},7)
    local hdr=frame:CreateTexture(nil,"ARTWORK")
    hdr:SetTexture(TEXTURE.."f_header")
    hdr:SetPoint("TOPLEFT",frame,"TOPLEFT",11,-11)
    hdr:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-11,-11)
    hdr:SetHeight(58)
    local emblem=CreateFrame("Frame",nil,frame)
    emblem:SetPoint("TOPLEFT",frame,"TOPLEFT",15,-5)
    emblem:SetSize(68,68)
    headerEmblem=emblem:CreateTexture(nil,"ARTWORK")
    headerEmblem:SetTexture(TEXTURE.."d_journal_crest")
    headerEmblem:SetAllPoints()
    headerTitle=Label(frame,"Forever Loot Journal",25,gold)
    headerTitle:SetPoint("TOPLEFT",frame,"TOPLEFT",91,-22)
    headerTitle:SetWidth(680)
    headerSubtitle=Label(frame,"Loot tracker  |  Crafting journal  |  Party & raid history",11,parchment)
    headerSubtitle:SetPoint("TOPLEFT",frame,"TOPLEFT",93,-51)
    headerSubtitle:SetWidth(450)
    archiveSummary=CreateFrame("Frame",nil,frame)
    archiveSummary:SetPoint("TOPLEFT",frame,"TOPLEFT",610,-14)
    archiveSummary:SetSize(378,49)
    for i,stat in ipairs({{"saved","LOOT COLLECTED"},{"players","PLAYERS"},{"crafting","CRAFTING DROPS"}}) do
        local badge=CreateFrame("Frame",nil,archiveSummary)
        badge:SetPoint("TOPLEFT",archiveSummary,"TOPLEFT",(i-1)*126,0)
        badge:SetSize(118,48)
        Theme.Paint(badge,"d_panel","BORDER",8)
        local caption=Label(badge,stat[2],9,muted,"CENTER")
        caption:SetPoint("TOP",badge,"TOP",0,-6)
        caption:SetSize(112,12)
        local value=Label(badge,"0",18,gold,"CENTER")
        value:SetPoint("TOP",badge,"TOP",0,-22)
        value:SetSize(112,23)
        archiveSummary[stat[1]]=value
    end
    local settingsButton=Button(frame,1006,19,32,30,"",function()
        if FLJ.SettingsUI then FLJ.SettingsUI.Toggle() end
    end)
    settingsButton:SetFrameLevel(frame:GetFrameLevel()+12)
    local settingsIcon=settingsButton:CreateTexture(nil,"ARTWORK")
    settingsIcon:SetTexture(TEXTURE.."d_crest")
    settingsIcon:SetPoint("CENTER",settingsButton,"CENTER",0,0)
    settingsIcon:SetSize(28,28)
    local close=Button(frame,1048,19,30,30,"X",function()
        if FLJ.SettingsUI then FLJ.SettingsUI.Hide() end
        frame:Hide()
    end)
    close:SetFrameLevel(frame:GetFrameLevel()+12)
    close.base:SetColorTexture(.27,.055,.045,1)
    close.label:SetTextColor(1,.43,.28)
    local side=Panel(frame,13,124,260,662,{.055,.078,.113,1})
    local sh=Label(side,"PARTY & RAID MEMBERS",14,gold)
    sh:SetPoint("TOPLEFT",side,"TOPLEFT",12,-12)
    local sdesc=Label(side,"Current party + everyone recorded",10,muted)
    sdesc:SetPoint("TOPLEFT",side,"TOPLEFT",12,-34)
    playerSearchBox=Edit(side,12,57,236,33,"Search player names...",function(s)
        playerSearch=T(s);playerOffset=0;UI.Refresh()
    end)
    local dropBtn=Button(side,12,102,236,32,"All players",function()
        dropdown:SetShown(not dropdown:IsShown());DropdownRefresh()
    end)
    playerLabel=dropBtn.label
    local dropArrow=Label(side,"v",11,parchment,"CENTER")
    dropArrow:SetPoint("RIGHT",dropBtn,"RIGHT",-12,0)
    local legendDot=CreateFrame("Frame",nil,side)
    legendDot:SetSize(10,10)
    legendDot:SetPoint("TOPLEFT",side,"TOPLEFT",13,-149)
    local active=MakeTexture(legendDot,"ARTWORK",{.37,.92,.35,1})
    active:SetPoint("TOPLEFT",legendDot,"TOPLEFT",2,-2)
    active:SetPoint("BOTTOMRIGHT",legendDot,"BOTTOMRIGHT",-2,2)
    Border(legendDot,.23,.3,.18,1)
    local liveText=Label(side,"Green = currently in your group",10,{.62,.79,.53})
    liveText:SetPoint("LEFT",legendDot,"RIGHT",6,0)
    local roster=Panel(side,0,170,260,470,{.031,.052,.084,1})
    playerRange=Label(side,"",11,muted)
    playerRange:SetPoint("TOPLEFT",side,"TOPLEFT",12,-645)
    playerRange:SetWidth(182)
    Button(side,207,641,21,19,"^",function()
        playerOffset=math.max(0,playerOffset-PLAYER_VISIBLE);UI.Refresh()
    end)
    Button(side,232,641,21,19,"v",function()
        playerOffset=math.min(math.max(0,#FilteredPlayers()-PLAYER_VISIBLE),playerOffset+PLAYER_VISIBLE);UI.Refresh()
    end)
    playerRows={}
    for i=1,PLAYER_VISIBLE do playerRows[i]=MakePlayerRow(roster,i) end
    ScrollWheel(roster,function(delta)
        playerOffset=math.max(0,math.min(math.max(0,#FilteredPlayers()-PLAYER_VISIBLE),playerOffset-delta*2))
        UI.Refresh()
    end)
    BuildDropdown(side)
    local mainTop=Panel(frame,284,124,803,61,{.076,.12,.18,1})
    titleText=Label(mainTop,"LOOT ARCHIVE",17,gold)
    titleText:SetPoint("TOPLEFT",mainTop,"TOPLEFT",14,-11)
    countText=Label(mainTop,"",10,muted)
    countText:SetPoint("TOPLEFT",mainTop,"TOPLEFT",14,-37)
    searchBox,mainSearchWrap=Edit(frame,720,137,356,35,"Search gear, winner, zone...",function(s)
        searchText=T(s);listOffset=0;UI.Refresh()
    end)
    local filt=Panel(frame,284,193,803,41,{.05,.076,.12,1})
    -- Keep filter controls above nearby noninteractive artwork and frames.
    filt:SetFrameLevel(frame:GetFrameLevel()+12)
    filterButtons={}
    filterButtons.all=Button(filt,7,5,108,30,"All Equipment",function()SelectGearFilter("all")end)
    filterButtons.armor=Button(filt,121,5,96,30,"Armor",function()SelectGearFilter("armor")end)
    filterButtons.weapons=Button(filt,223,5,96,30,"Weapons",function()SelectGearFilter("weapons")end)
    filterButtons.crafting=Button(filt,325,5,108,30,"Crafting",function()SelectGearFilter("crafting")end)
    qualityFilterButton=Button(filt,439,5,122,30,"All rarities",function(self)
        qualityMinimum=not qualityMinimum and 3 or qualityMinimum==3 and 4 or nil
        self.label:SetText(qualityMinimum==3 and "Rare+" or qualityMinimum==4 and "Epic+" or "All rarities")
        listOffset=0;UI.Refresh()
    end)
    Button(filt,568,5,112,30,"Refresh",function()
        if FLJ.RegisterRoster then
            FLJ.RegisterRoster()
        end
        UI.Refresh()
    end)
    Button(filt,686,5,107,30,"Clear log",function() FLJ.ShowClearConfirm() end)
    local list=Panel(frame,284,241,803,282,{.04,.063,.105,1})
    lootListPanel=list
    local itemHeading=Label(list,"ITEM / TYPE",10,muted)
    itemHeading:SetPoint("TOPLEFT",list,"TOPLEFT",52,-10)
    local winnerHeading=Label(list,"WINNER / SOURCE & DATE",10,muted,"RIGHT")
    winnerHeading:SetPoint("TOPLEFT",list,"TOPLEFT",458,-10)
    winnerHeading:SetWidth(275)
    Button(list,741,5,22,20,"^",function()
        listOffset=math.max(0,listOffset-ITEM_VISIBLE);UI.Refresh()
    end)
    Button(list,769,5,22,20,"v",function()
        listOffset=math.min(math.max(0,#FilteredLoot()-ITEM_VISIBLE),listOffset+ITEM_VISIBLE);UI.Refresh()
    end)
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
    MakeCraftingPane(frame)
    local footer=Panel(frame,13,796,W-26,26,{.030,.056,.10,1})
    local foot=Label(footer,"/flj to open   |   Mouse wheel to scroll   |   Shift-click item to link it   |   Account-wide saved history",11,parchment,"CENTER")
    foot:SetPoint("CENTER",footer,"CENTER",0,0)
    foot:SetWidth(W-48)
    journalParts={side,mainTop,mainSearchWrap,filt,list,detail,craftingPane,footer}
    if FLJ.SettingsUI and FLJ.SettingsUI.Build then FLJ.SettingsUI.Build(frame) end
    frame:Hide()
end
local function FitWindow()
    if not frame or not UIParent then return end
    local availableWidth=math.max(1,(UIParent:GetWidth() or W)-48)
    local availableHeight=math.max(1,(UIParent:GetHeight() or H)-80)
    local height=frame:GetHeight() or H
    local scale=math.min(1,availableWidth/W,availableHeight/height)
    frame:SetScale(scale)
    frame:ClearAllPoints()
    -- Bias the journal upward when space allows; this keeps the extended item
    -- details and footer further from the bottom of the physical display.
    local spare=(UIParent:GetHeight() or H) - height*scale
    local upward=math.max(0,math.min(28,(spare/2)-8))
    frame:SetPoint("CENTER",UIParent,"CENTER",0,upward)
end
UI.FitWindow=FitWindow
function FLJ.Toggle(players)
    if not frame then MakeFrame() end
    if frame:IsShown() and not players then
        if FLJ.SettingsUI then FLJ.SettingsUI.Hide() end
        frame:Hide()
    else
        FitWindow()
        frame:Show()
        if players then playerSearchBox:SetFocus() end
        UI.Refresh()
    end
end
local sizeWatch=CreateFrame("Frame")
sizeWatch:RegisterEvent("DISPLAY_SIZE_CHANGED")
sizeWatch:RegisterEvent("UI_SCALE_CHANGED")
sizeWatch:SetScript("OnEvent",function()
    if frame and frame:IsShown() then FitWindow() end
end)
-- Minimap launcher is created only by Minimap.lua, to avoid duplicate buttons.

