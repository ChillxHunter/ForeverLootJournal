-- Test Inspect.lua on a simulated WoW Forever / Lua 5.1 client.
-- Covers nearby inspection, GUID matching, last-seen history, retries, and UI.
local allFrames={}
local function Widget(kind,parent)
    local f={kind=kind,parent=parent,events={},scripts={},shown=true}
    function f:SetPoint(...)self.point={...}end
    function f:ClearAllPoints()self.point=nil end
    function f:SetSize(w,h)self.width=w;self.height=h end
    function f:SetWidth(w)self.width=w end
    function f:SetHeight(h)self.height=h end
    function f:SetAllPoints()self.all=true end
    function f:SetFrameStrata(s)self.strata=s end
    function f:SetFrameLevel(v)self.level=v end
    function f:SetClampedToScreen()end
    function f:SetMovable()end
    function f:EnableMouse()end
    function f:RegisterForDrag()end
    function f:SetAlpha(a)self.alpha=a end
    function f:SetColorTexture(...)self.color={...}end
    function f:SetTexture(path)self.texture=path end
    function f:SetVertexColor(...)end
    function f:SetFont(...)end
    function f:SetTextColor(...)end
    function f:SetJustifyH(...)end
    function f:SetText(s)self.text=s end
    function f:GetText()return self.text end
    function f:RegisterEvent(e)self.events[e]=true end
    function f:SetScript(e,handler)self.scripts[e]=handler end
    function f:Hide()self.shown=false end
    function f:Show()self.shown=true end
    function f:IsShown()return self.shown end
    function f:CreateTexture()return Widget("Texture",self)end
    function f:CreateFontString()return Widget("FontString",self)end
    function f:StartMoving()end
    function f:StopMovingOrSizing()end
    allFrames[#allFrames+1]=f
    return f
end
UIParent=Widget("Frame")
function CreateFrame(kind,name,parent)
    local f=Widget(kind,parent)
    if name then _G[name]=f end
    return f
end
local clock=100
local epoch=1800000000
GetTime=function()return clock end
time=function()return epoch end
date=function()return "15 Nov 2026 21:00" end
local near=true
UnitExists=function(unit)return unit=="party1" end
UnitIsPlayer=function(unit)return unit=="party1" end
UnitIsConnected=function(unit)return true end
UnitIsUnit=function(a,b)return a==b end
UnitFullName=function(unit)
    if unit=="party1" then return "Remote","Realm" end
    if unit=="player" then return "Local","Realm" end
end
UnitName=function(unit)return unit=="party1" and "Remote" or "Local" end
UnitGUID=function(unit)return unit=="party1" and "Player-123" or "Player-LOCAL" end
UnitLevel=function(unit)return 35 end
UnitClass=function(unit)return "Warrior","WARRIOR" end
CanInspect=function(unit)return near end
CheckInteractDistance=function(unit,idx)
    assert(idx==1)
    return near
end
InCombatLockdown=function()return false end
local notifyCount,cleared=0,0
NotifyInspect=function(unit)
    assert(unit=="party1")
    notifyCount=notifyCount+1
end
ClearInspectPlayer=function()cleared=cleared+1 end
local itemLinks={
    [1]="|cff0070dd|Hitem:12345|h[Blue Helm]|h|r",
    [16]="|cff1eff00|Hitem:98765|h[Green Sword]|h|r",
}
GetInventoryItemLink=function(unit,slot)
    assert(unit=="party1")
    return itemLinks[slot]
end
GetInventoryItemID=function(unit,slot)
    local link=itemLinks[slot]
    return link and tonumber(link:match("item:(%d+)"))
end
GetInventoryItemTexture=function(unit,slot)
    return itemLinks[slot] and "SomeIcon" or nil
end
GetItemInfo=function(link)return "Sample Item" end
GameTooltip={SetOwner=function()end,SetHyperlink=function()end,Show=function()end,Hide=function()end,AddLine=function()end}
local deferred={}
local ticker
C_Timer={
    NewTicker=function(_,fn)ticker=fn end,
    After=function(_,fn)deferred[#deferred+1]=fn end,
}
local prints={}
print=function(t)prints[#prints+1]=t end
local db={records={{id=1}},ui={},inspections={}}
local addon={
    GetDB=function()return db end,
    GetPlayers=function()return {{name="Remote-Realm",current=true}} end,
    GetUnitForPlayer=function(name)
        if name=="Remote-Realm" or name=="Remote" then return "party1" end
        return nil
    end,
    Zone=function()return "Ironforge"end,
}
assert(loadfile("Inspect.lua"))("ForeverLootJournal",addon)
assert(addon.Inspect and addon.Inspect.ScanNearby,"inspect feature not loaded")
assert(ticker,"automatic nearby scan timer not registered")
local function Fire(event,...)
    for _,f in ipairs(allFrames) do
        if f.events[event] and f.scripts.OnEvent then
            f.scripts.OnEvent(f,event,...)
        end
    end
end
Fire("PLAYER_ENTERING_WORLD")
for _,fn in ipairs(deferred) do fn()end
assert(notifyCount==1,"nearby party member must be inspected automatically")
Fire("INSPECT_READY","Player-OTHER")
assert(not addon.Inspect.HasSnapshot("Remote-Realm"),"wrong GUID may not overwrite snapshot")
Fire("INSPECT_READY","Player-123")
local snap=assert(addon.Inspect.Get("Remote-Realm"),"inspection was not saved")
assert(snap.name=="Remote-Realm" and snap.guid=="Player-123")
assert(snap.itemCount==2 and snap.items[1].itemID==12345 and snap.items[16].itemID==98765)
assert(snap.zone=="Ironforge" and snap.capturedAt==epoch,"last-seen timestamp/zone missing")
assert(cleared==1,"successful inspection should release its inspect request")
assert(#db.records==1,"inspect data must NOT be added to loot archive")

near=false
assert(addon.Inspect.Show({name="Remote-Realm"}),"cached inspect viewer did not open")
local window=assert(_G.ForeverLootJournalInspectFrame,"inspect popup not built")
assert(window:IsShown(),"gear viewer did not appear")
assert(window.title.text:find("Remote%-Realm"),"viewer did not display player name")
assert(window.info.text:find("15 Nov 2026"),"viewer did not display saved inspection time")
assert(window.status.text:find("2 equipped slots"),"viewer did not show slot count")
assert(notifyCount==1,"opening cached gear out of range must not request new inspection")
assert(not addon.Inspect.Request("Remote-Realm",true),"far-away request must be rejected")

clock=clock+200
epoch=epoch+200
near=true
assert(addon.Inspect.Request("Remote-Realm",false),"nearby stale snapshot should refresh")
assert(notifyCount==2)
itemLinks={}
Fire("INSPECT_READY","Player-123")
assert(addon.Inspect.Get("Remote-Realm").itemCount==2,
    "empty API response must not erase previously saved equipment")

near=false
clock=clock+200
ticker()
assert(notifyCount==2,"automatic scan must never request out-of-range gear")
assert(addon.Inspect.Get("Remote-Realm").items[1].itemID==12345)

near=true
itemLinks[1]="|cff0070dd|Hitem:22222|h[New Helm]|h|r"
clock=clock+200
epoch=epoch+200
assert(addon.Inspect.Request("Remote-Realm",false))
Fire("INSPECT_READY","Player-123")
assert(addon.Inspect.Get("Remote-Realm").items[1].itemID==22222,
    "reinspection did not update the last known equipment")

-- Different full realms must never match the same inspectable unit.
assert(not addon.Inspect.Request("Remote-AnotherRealm",true),"cross-realm identity mismatch")
assert(#db.records==1,"equipment snapshots cannot alter loot history")
io.write("Last-seen party gear inspection tests passed\n")
