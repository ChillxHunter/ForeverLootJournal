-- Forever Loot Journal v1.3.1 - remembered party-member equipment.
-- Uses WoW's inspect APIs only when an eligible group member is near.
-- Equipment snapshots are account-wide and independent of loot-record limits.
local addonName, FLJ = ...
local Inspect = {}
FLJ.Inspect = Inspect

local MAX_SNAPSHOTS=250
local REFRESH_INTERVAL=180       -- inspect nearby members at most every 3 minutes
local MIN_REQUEST_GAP=18         -- one inspect request globally per 18 seconds
local REQUEST_TIMEOUT=12
local SLOTS={
    {1,"Head"}, {2,"Neck"}, {3,"Shoulder"}, {4,"Shirt"}, {5,"Chest"},
    {6,"Waist"}, {7,"Legs"}, {8,"Feet"}, {9,"Wrist"}, {10,"Hands"},
    {11,"Ring 1"}, {12,"Ring 2"}, {13,"Trinket 1"}, {14,"Trinket 2"},
    {15,"Back"}, {16,"Main Hand"}, {17,"Off Hand"}, {18,"Ranged"}, {19,"Tabard"},
}
Inspect.Slots=SLOTS
local popup,rows,shownName
local pending,lastRequest,scanIndex=nil,-MIN_REQUEST_GAP,0
local lastRequested={} -- in-memory only, prevents repeated API requests

local function Safe(fn,...)
    if type(fn)~="function" then return nil end
    local ok,a,b,c=pcall(fn,...)
    if ok then return a,b,c end
    return nil
end
local function Now()
    return (type(time)=="function" and Safe(time)) or 0
end
local function Clock()
    return (type(GetTime)=="function" and Safe(GetTime)) or Now()
end
local function Normalize(name)
    if type(name)~="string" then return nil end
    name=name:match("^%s*(.-)%s*$")
    if name=="" or #name>96 or name:find("[%c|/]") then return nil end
    return name:lower()
end
local function FullName(unit)
    local name,realm=Safe(UnitFullName,unit)
    if not name then name=Safe(UnitName,unit) end
    if type(name)~="string" then return nil end
    if type(realm)=="string" and realm~="" then return name.."-"..realm end
    return name
end
local function DB()
    local db=FLJ.GetDB and FLJ.GetDB()
    if type(db)~="table" then return nil end
    if type(db.inspections)~="table" then db.inspections={} end
    return db
end
local function Status(msg)
    if type(print)=="function" then
        print("|cffffd76aForever Loot Journal:|r "..msg)
    end
end
local function MemberUnit(name)
    if not name or not FLJ.GetUnitForPlayer then return nil end
    local unit=FLJ.GetUnitForPlayer(name)
    if not unit or not Safe(UnitExists,unit) or Safe(UnitIsPlayer,unit)==false
        or Safe(UnitIsUnit,unit,"player") then return nil end
    -- Verify the unit still represents the requested player after roster changes.
    local actual=FullName(unit)
    if not actual then return nil end
    local expected=Normalize(name)
    local got=Normalize(actual)
    if expected~=got then
        -- Accept short name only if the game does not expose a realm.
        local short=got and got:match("^([^-]+)")
        if expected~=short then return nil end
    end
    return unit
end
local function Near(unit)
    if not unit or not Safe(UnitExists,unit) then return false end
    if Safe(UnitIsConnected,unit)==false then return false end
    if type(CanInspect)~="function" or Safe(CanInspect,unit,false)~=true then
        return false
    end
    -- Minimap visibility is not the same as inspect range. This check avoids
    -- "too far away" chat/UI errors on players in other zones.
    if type(CheckInteractDistance)=="function" and
       Safe(CheckInteractDistance,unit,1)~=true then return false end
    return true
end
local function Busy()
    if type(InCombatLockdown)=="function" and Safe(InCombatLockdown) then return true end
    if InspectFrame and type(InspectFrame.IsShown)=="function" and InspectFrame:IsShown() then
        return true -- do not interrupt Blizzard's native inspect window
    end
    return false
end
function Inspect.Get(name)
    local db=DB()
    local key=Normalize(name)
    return db and key and db.inspections[key] or nil
end
local function Prune(db)
    local count=0
    for _ in pairs(db.inspections) do count=count+1 end
    while count>MAX_SNAPSHOTS do
        local oldest,oldestTime
        for key,item in pairs(db.inspections) do
            local stamp=tonumber(item.capturedAt) or 0
            if not oldest or stamp<oldestTime then oldest,oldestTime=key,stamp end
        end
        if not oldest then return end
        db.inspections[oldest]=nil
        count=count-1
    end
end

local function ItemIcon(item)
    if not item then return "Interface\\PaperDoll\\UI-PaperDoll-Slot-Background" end
    if item.texture then return item.texture end
    local icon=Safe(GetItemIcon,item.link or item.itemID)
    if not icon and C_Item then
        icon=Safe(C_Item.GetItemIconByID,item.itemID)
    end
    return icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end
local function ItemLabel(item)
    if not item then return "Empty" end
    local label=item.link and item.link:match("%[(.-)%]")
    if label and label~="" then return label end
    local name=Safe(GetItemInfo,item.link or item.itemID)
    return type(name)=="string" and name or (item.itemID and ("Item #"..item.itemID) or "Unknown item")
end
local function Timestamp(stamp)
    if type(date)=="function" and tonumber(stamp) then
        return date("%d %b %Y  %H:%M",stamp)
    end
    return "Unknown time"
end
local function Paint(frame,r,g,b,a)
    local tex=frame:CreateTexture(nil,"BACKGROUND")
    tex:SetAllPoints(frame)
    tex:SetColorTexture(r,g,b,a or 1)
    return tex
end
local function Label(parent,text,x,y,size,r,g,b)
    local font=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    font:SetFont("Fonts\\FRIZQT__.TTF",size or 12,"OUTLINE")
    font:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y)
    font:SetTextColor(r or .91,g or .92,b or .95)
    font:SetJustifyH("LEFT")
    font:SetText(text or "")
    return font
end
local function SmallButton(parent,x,y,w,text,onClick)
    local button=CreateFrame("Button",nil,parent)
    button:SetSize(w,28)
    button:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y)
    Paint(button,.082,.12,.18,1)
    local title=Label(button,text,7,6,12,1,.79,.3)
    title:SetWidth(w-14)
    title:SetJustifyH("CENTER")
    button:SetScript("OnEnter",function(self)
        self:SetAlpha(.82)
    end)
    button:SetScript("OnLeave",function(self) self:SetAlpha(1) end)
    button:SetScript("OnClick",onClick)
    return button
end
local function BuildPopup()
    if popup or not UIParent then return end
    popup=CreateFrame("Frame","ForeverLootJournalInspectFrame",UIParent,"BackdropTemplate")
    popup:SetSize(742,615)
    popup:SetPoint("CENTER",UIParent,"CENTER",32,4)
    popup:SetFrameStrata("DIALOG")
    popup:SetFrameLevel(80)
    popup:SetClampedToScreen(true)
    popup:SetMovable(true)
    popup:EnableMouse(true)
    Paint(popup,.015,.027,.047,.98)
    local bar=CreateFrame("Frame",nil,popup)
    bar:SetSize(730,64)
    bar:SetPoint("TOP",popup,"TOP",0,-6)
    Paint(bar,.044,.080,.14,.98)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart",function()popup:StartMoving()end)
    bar:SetScript("OnDragStop",function()popup:StopMovingOrSizing()end)
    popup.title=Label(bar,"INSPECT - LAST SEEN",16,11,20,1,.80,.32)
    popup.info=Label(bar,"Saved equipment snapshot",16,40,11,.62,.72,.84)
    SmallButton(bar,686,11,34,"X",function()popup:Hide()end)
    popup.status=Label(popup,"",17,79,12,.77,.85,.96)
    popup.status:SetWidth(702)
    popup.hint=Label(popup,"",17,104,11,.53,.66,.81)
    popup.hint:SetWidth(703)
    rows={}
    local slotsPerColumn=10
    for i,slot in ipairs(SLOTS) do
        local col=math.floor((i-1)/slotsPerColumn)
        local ix=(i-1)%slotsPerColumn
        local left=17+col*360
        local top=137+ix*43
        local button=CreateFrame("Button",nil,popup)
        button:SetSize(350,40)
        button:SetPoint("TOPLEFT",popup,"TOPLEFT",left,-top)
        Paint(button,(ix%2==0) and .055 or .039,.079,.116,.94)
        button.icon=button:CreateTexture(nil,"ARTWORK")
        button.icon:SetSize(33,33)
        button.icon:SetPoint("LEFT",button,"LEFT",4,0)
        button.label=Label(button,slot[2]..":",44,3,11,1,.79,.35)
        button.itemName=Label(button,"",44,20,11,.86,.9,.97)
        button.itemName:SetWidth(292)
        button:SetScript("OnEnter",function(self)
            if not self.item or not self.item.link or not GameTooltip then return end
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            if type(GameTooltip.SetHyperlink)=="function" then
                GameTooltip:SetHyperlink(self.item.link)
            else
                GameTooltip:AddLine(ItemLabel(self.item))
            end
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave",function()
            if GameTooltip then GameTooltip:Hide() end
        end)
        button:SetScript("OnClick",function(self)
            if self.item and self.item.link and type(HandleModifiedItemClick)=="function" then
                HandleModifiedItemClick(self.item.link)
            end
        end)
        rows[slot[1]]=button
    end
    popup.refresh=SmallButton(popup,17,571,215,"Inspect Again (Nearby)",function()
        if not shownName then return end
        local succeeded=Inspect.Request(shownName,true)
        if not succeeded then
            Status("Cannot inspect now. Target must be nearby, grouped and inspectable.")
        end
    end)
    popup:Hide()
end

function Inspect.Refresh()
    if not popup or not popup:IsShown() or not shownName then return end
    local data=Inspect.Get(shownName)
    popup.title:SetText("INSPECT  -  "..shownName)
    if data then
        popup.info:SetText("Last saved: "..Timestamp(data.capturedAt)..
            "  |  "..tostring(data.zone or "Unknown zone"))
        local count=tonumber(data.itemCount) or 0
        popup.status:SetText("Last known equipment  |  "..count.." equipped slots captured")
        popup.hint:SetText("Historical snapshot, not live gear. Hover for item details. Shift-click to link.")
    else
        popup.info:SetText("No equipment snapshot saved")
        popup.status:SetText("No previous inspection available for this player.")
        popup.hint:SetText("Stand nearby in the same party, then inspect to save their gear.")
    end
    for _,slot in ipairs(SLOTS) do
        local button=rows[slot[1]]
        local item=data and data.items and data.items[slot[1]]
        button.item=item
        button.icon:SetTexture(ItemIcon(item))
        button.itemName:SetText(ItemLabel(item))
        button.itemName:SetTextColor(item and .87 or .42,item and .92 or .51,item and 1 or .65)
    end
end
function Inspect.Show(player)
    local name=type(player)=="table" and player.name or player
    if not Normalize(name) then return false end
    BuildPopup()
    if not popup then return false end
    shownName=name
    popup:Show()
    Inspect.Refresh()
    -- Refresh opportunistically only if the player is currently inspectable.
    Inspect.Request(name,false)
    return true
end
function Inspect.HasSnapshot(name)
    return Inspect.Get(name)~=nil
end
function Inspect.Request(name,force)
    local unit=MemberUnit(name)
    if not unit or not Near(unit) or Busy() then return false end
    if type(NotifyInspect)~="function" then return false end
    local now=Clock()
    if pending and now-pending.clock<REQUEST_TIMEOUT then return false end
    if now-lastRequest<MIN_REQUEST_GAP then return false end
    local canonical=FullName(unit)
    local key=Normalize(canonical)
    if not key then return false end
    local saved=Inspect.Get(canonical)
    if not force then
        if saved and Now()-tonumber(saved.capturedAt or 0)<REFRESH_INTERVAL then return false end
        if now-(lastRequested[key] or -REFRESH_INTERVAL)<REFRESH_INTERVAL then return false end
    end
    local guid=Safe(UnitGUID,unit)
    if type(guid)~="string" or guid=="" then return false end
    pending={name=canonical,key=key,guid=guid,unit=unit,clock=now}
    lastRequest=now
    lastRequested[key]=now
    local ok=pcall(NotifyInspect,unit)
    if not ok then
        pending=nil
        return false
    end
    return true
end

local function Capture(guid)
    local p=pending
    if not p then return end
    if type(guid)~="string" or guid~=p.guid then return end
    if Safe(UnitGUID,p.unit)~=p.guid then pending=nil;return end
    local db=DB()
    if not db then pending=nil;return end
    local items={}
    local count=0
    for _,entry in ipairs(SLOTS) do
        local slot=entry[1]
        local link=Safe(GetInventoryItemLink,p.unit,slot)
        local id=Safe(GetInventoryItemID,p.unit,slot)
        if type(link)=="string" and link~="" then
            id=id or tonumber(link:match("item:(%d+)"))
        end
        if (type(link)=="string" and link~="") or type(id)=="number" then
            items[slot]={
                link=type(link)=="string" and link or ("item:"..id),
                itemID=tonumber(id),
                texture=Safe(GetInventoryItemTexture,p.unit,slot),
            }
            count=count+1
        end
    end
    pending=nil
    if type(ClearInspectPlayer)=="function" and
       not (InspectFrame and InspectFrame:IsShown()) then
        pcall(ClearInspectPlayer)
    end
    -- A response with no slots usually indicates an uncached/incomplete
    -- inspection. Never overwrite good saved history with an empty result.
    if count==0 then return end
    db.inspections[p.key]={
        name=p.name,guid=p.guid,capturedAt=Now(),
        zone=(FLJ.Zone and FLJ.Zone()) or "Unknown zone",
        level=Safe(UnitLevel,p.unit),class=select(2,Safe(UnitClass,p.unit)),
        items=items,itemCount=count,
    }
    Prune(db)
    if shownName and Normalize(shownName)==p.key then Inspect.Refresh() end
end
function Inspect.ScanNearby()
    if not DB() or pending and Clock()-pending.clock<REQUEST_TIMEOUT then return end
    if not FLJ.GetPlayers then return end
    local current={}
    for _,p in ipairs(FLJ.GetPlayers()) do
        if p.current and p.name then current[#current+1]=p.name end
    end
    if #current==0 then return end
    for i=1,#current do
        scanIndex=(scanIndex%#current)+1
        if Inspect.Request(current[scanIndex],false) then return end
    end
end

local frame=CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("INSPECT_READY")
frame:SetScript("OnEvent",function(_,event,guid)
    if event=="INSPECT_READY" then
        Capture(guid)
    elseif event=="PLAYER_ENTERING_WORLD" or event=="GROUP_ROSTER_UPDATE" then
        if C_Timer and type(C_Timer.After)=="function" then
            C_Timer.After(3,Inspect.ScanNearby)
        else
            Inspect.ScanNearby()
        end
    elseif event=="PLAYER_TARGET_CHANGED" then
        Inspect.ScanNearby()
    end
end)
if C_Timer and type(C_Timer.NewTicker)=="function" then
    C_Timer.NewTicker(12,Inspect.ScanNearby)
end
