-- Minimal WoW 16001 UI mock for ForeverLootJournal's minimap launcher.
-- This test runs with standard Lua 5.1 in GitHub Actions.
local frames={}
local function Frame(parent)
    local f={parent=parent,scripts={},events={},shown=true,textures={}}
    function f:SetParent(p) self.parent=p end
    function f:GetParent() return self.parent end
    function f:SetSize(w,h) self.width=w;self.height=h end
    function f:GetSize() return self.width,self.height end
    function f:SetFrameStrata(s) self.strata=s end
    function f:SetFrameLevel(l) self.level=l end
    function f:GetFrameLevel() return self.level or 1 end
    function f:SetPoint(...) self.point={...} end
    function f:ClearAllPoints() self.point=nil end
    function f:RegisterForClicks(...) self.clicks={...} end
    function f:RegisterForDrag(...) self.drags={...} end
    function f:EnableMouse(v) self.mouse=v end
    function f:SetScript(n,v) self.scripts[n]=v end
    function f:RegisterEvent(event) self.events[event]=true end
    function f:SetShown(b) self.shown=b end
    function f:IsShown() return self.shown end
    function f:IsVisible() return self.shown end
    function f:Hide() self.shown=false end
    function f:Show() self.shown=true end
    function f:CreateTexture(_,layer)
        local t={layer=layer}
        function t:SetPoint(...) self.point={...} end
        function t:SetSize(w,h) self.width=w;self.height=h end
        function t:SetTexture(s) self.texture=s end
        function t:SetAllPoints() self.allPoints=true end
        f.textures[#f.textures+1]=t
        return t
    end
    frames[#frames+1]=f
    return f
end

UIParent=Frame()
Minimap=Frame(UIParent)
function Minimap:GetCenter() return 100,100 end
function Minimap:GetEffectiveScale() return 1 end
function Minimap:GetWidth() return 180 end
Minimap:SetFrameLevel(10)
function CreateFrame(kind,name,parent)
    local f=Frame(parent)
    f.kind=kind
    if name then _G[name]=f end
    return f
end
local cursorX,cursorY=100,190
function GetCursorPosition() return cursorX,cursorY end
local deferred={}
C_Timer={After=function(_,fn) deferred[#deferred+1]=fn end}
GameTooltip={SetOwner=function()end,AddLine=function()end,Show=function()end,Hide=function()end}
local printed={}
function print(s) printed[#printed+1]=tostring(s) end
ForeverLootJournalDB={ui={}}
local fallbackCount,toggleCount=0,0
SlashCmdList={FOREVERLOOTJOURNAL=function() fallbackCount=fallbackCount+1 end}
local flj={Toggle=function() toggleCount=toggleCount+1 end}
assert(loadfile("Minimap.lua"))("ForeverLootJournal",flj)

-- Verify no premature creation before PLAYER_LOGIN, unlike the old implementation.
assert(not _G.ForeverLootJournalMinimapButton,"minimap button created before login")
for _,f in ipairs(frames) do
    if f.events.PLAYER_LOGIN and f.scripts.OnEvent then
        f.scripts.OnEvent(f,"PLAYER_LOGIN")
    end
end
for _,fn in ipairs(deferred) do fn() end
local m=assert(_G.ForeverLootJournalMinimapButton,"minimap button not built at login")
assert(m:GetParent()==Minimap,"launcher must match Casino's minimap parent")
assert(m.width==34 and m.height==34,"incorrect minimap button size")
assert(m:IsShown(),"button hidden at login")
assert(#m.textures==2,"expected exactly one icon and one round border")
assert(m.textures[1].texture=="Interface\\Icons\\INV_Chest_Chain_05")
assert(m.textures[2].texture=="Interface\\Minimap\\MiniMap-TrackingBorder")
assert(m.textures[2].allPoints,"border must cover minimap button")
assert(m.scripts.OnClick and m.scripts.OnDragStart and m.scripts.OnDragStop)
m.scripts.OnClick(m)
assert(toggleCount==1,"click did not open journal")
m.scripts.OnDragStart(m)
assert(type(m.scripts.OnUpdate)=="function","drag update not registered")
m.scripts.OnUpdate(m)
assert(math.abs(ForeverLootJournalDB.ui.minimapAngle-90)<.001,"drag angle not saved")
m.scripts.OnDragStop(m)
for i=1,#deferred do deferred[i]() end
m.scripts.OnClick(m)
assert(toggleCount==2,"click did not work after dragging")
SlashCmdList.FOREVERLOOTJOURNAL("hideicon")
assert(not m:IsShown(),"hideicon command failed")
SlashCmdList.FOREVERLOOTJOURNAL("showicon")
assert(m:IsShown(),"showicon command failed")
SlashCmdList.FOREVERLOOTJOURNAL("reseticon")
assert(ForeverLootJournalDB.ui.minimapAngle==315,"reseticon angle incorrect")
SlashCmdList.FOREVERLOOTJOURNAL("iconstatus")
SlashCmdList.FOREVERLOOTJOURNAL("players")
assert(fallbackCount==1,"previous /flj handlers not preserved")
print("Minimap mock tests passed")
