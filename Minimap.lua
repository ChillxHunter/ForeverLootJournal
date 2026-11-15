-- Forever Loot Journal minimap launcher v1.1.5
-- Uses the same simple minimap-button structure as ForeverCasino.
-- No mask texture or opaque background: avoids invisible icon and black square.
local addonName, FLJ = ...
local DEFAULT_ANGLE=305
local BUTTON_SIZE=32
local button

local function Settings()
    if type(ForeverLootJournalDB)~="table" then ForeverLootJournalDB={} end
    local db=ForeverLootJournalDB
    if type(db.ui)~="table" then db.ui={} end
    local ui=db.ui
    -- The previous button could be hidden or placed offscreen. Restore it
    -- exactly once on upgrading; preserve existing loot history and later moves.
    if not ui.minimapLauncherV3 then
        ui.minimapLauncherV3=true
        ui.minimapHidden=false
        ui.minimapAngle=DEFAULT_ANGLE
    end
    return ui
end

local function Radius()
    if not Minimap then return 94 end
    local width=Minimap:GetWidth() or 160
    return math.max(79,width/2+13)
end

local function UpdatePosition()
    if not button or not Minimap then return end
    local ui=Settings()
    local a=math.rad(tonumber(ui.minimapAngle) or DEFAULT_ANGLE)
    local r=Radius()
    button:ClearAllPoints()
    button:SetPoint("CENTER",Minimap,"CENTER",r*math.cos(a),r*math.sin(a))
    button:SetShown(not ui.minimapHidden)
end

local function CursorAngle()
    if not Minimap then return nil end
    local mx,my=GetCursorPosition()
    local cx,cy=Minimap:GetCenter()
    local scale=Minimap:GetEffectiveScale()
    if not cx or not cy or not scale or scale==0 then return nil end
    local dx,dy=mx/scale-cx,my/scale-cy
    if math.abs(dx)+math.abs(dy)<0.001 then return nil end
    if math.atan2 then return math.deg(math.atan2(dy,dx)) end
    if math.abs(dx)<0.001 then return dy>=0 and 90 or 270 end
    local a=math.atan(dy/dx)
    if dx<0 then a=a+math.pi end
    return math.deg(a)
end

local function BuildButton()
    if not Minimap then return end
    if not button then
        button=_G.ForeverLootJournalMinimapButton
            or CreateFrame("Button","ForeverLootJournalMinimapButton",Minimap)
    end
    -- Minimap parenting matches standard Blizzard and ForeverCasino buttons.
    button:SetParent(Minimap)
    if button._fljInstalledV3 then return end
    button._fljInstalledV3=true
    button:SetSize(BUTTON_SIZE,BUTTON_SIZE)
    button:SetFrameStrata("HIGH")
    button:SetFrameLevel(Minimap:GetFrameLevel()+8)
    button:SetClampedToScreen(true)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetNormalTexture(nil)
    button:SetPushedTexture(nil)
    button:SetHighlightTexture(nil)

    -- The chest itself is intentionally small, with no square backdrop.
    local icon=button.icon or button:CreateTexture(nil,"ARTWORK")
    icon:ClearAllPoints()
    icon:SetPoint("CENTER",button,"CENTER",0,0)
    icon:SetSize(20,20)
    icon:SetTexture("Interface\\Icons\\INV_Chest_Chain_05")
    icon:SetTexCoord(.10,.90,.10,.90)
    icon:Show()
    button.icon=icon

    -- Conventional gold circular minimap rim (transparent outside the circle).
    local border=button:CreateTexture(nil,"OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53,53)
    border:SetPoint("TOPLEFT",button,"TOPLEFT",-11,11)
    button.border=border

    local glow=button:CreateTexture(nil,"HIGHLIGHT")
    glow:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    glow:SetBlendMode("ADD")
    glow:SetAllPoints(button)

    button:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_LEFT")
        GameTooltip:AddLine("Forever Loot Journal",1,.82,.36)
        GameTooltip:AddLine("Left-click: open the journal",1,1,1)
        GameTooltip:AddLine("Drag: move around the minimap",.75,.83,1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave",function() GameTooltip:Hide() end)
    button:SetScript("OnClick",function(self)
        if not self._dragging and not self._ignoreNextClick and FLJ.Toggle then
            FLJ.Toggle()
        end
    end)
    button:SetScript("OnDragStart",function(self)
        self._dragging=true
        self._ignoreNextClick=true
        GameTooltip:Hide()
        self:SetScript("OnUpdate",function()
            local angle=CursorAngle()
            if angle then Settings().minimapAngle=angle;UpdatePosition() end
        end)
    end)
    button:SetScript("OnDragStop",function(self)
        self._dragging=false
        self:SetScript("OnUpdate",nil)
        if C_Timer and C_Timer.After then
            C_Timer.After(.2,function() self._ignoreNextClick=false end)
        else self._ignoreNextClick=false end
    end)
end

function FLJ.UpdateMinimapButton()
    if not Minimap then return end
    BuildButton()
    UpdatePosition()
end

local previous=SlashCmdList and SlashCmdList.FOREVERLOOTJOURNAL
if previous then
    SlashCmdList.FOREVERLOOTJOURNAL=function(message)
        local command=tostring(message or ""):lower():match("^%s*(.-)%s*$")
        local ui=Settings()
        if command=="showicon" or command=="map" or command=="minimap" then
            ui.minimapHidden=false
            FLJ.UpdateMinimapButton()
            print("|cffffd76aForever Loot Journal:|r Minimap marker is visible. Drag it to reposition.")
        elseif command=="hideicon" then
            ui.minimapHidden=true
            FLJ.UpdateMinimapButton()
        elseif command=="icon" then
            ui.minimapHidden=not ui.minimapHidden
            FLJ.UpdateMinimapButton()
        elseif command=="reseticon" then
            ui.minimapAngle=DEFAULT_ANGLE
            ui.minimapHidden=false
            FLJ.UpdateMinimapButton()
            print("|cffffd76aForever Loot Journal:|r Minimap marker reset to the lower-right edge.")
        elseif command=="iconstatus" then
            FLJ.UpdateMinimapButton()
            print("|cffffd76aForever Loot Journal:|r minimap="..tostring(Minimap~=nil)..
                " button="..tostring(button~=nil).." shown="..tostring(button and button:IsShown())..
                " hiddenSetting="..tostring(ui.minimapHidden))
        else
            previous(message)
            if command=="help" then
                print("|cffffd76aMinimap:|r /flj showicon, /flj reseticon, /flj iconstatus")
            end
        end
    end
end

local lifecycle=CreateFrame("Frame")
lifecycle:RegisterEvent("PLAYER_LOGIN")
lifecycle:RegisterEvent("PLAYER_ENTERING_WORLD")
lifecycle:RegisterEvent("UI_SCALE_CHANGED")
lifecycle:RegisterEvent("DISPLAY_SIZE_CHANGED")
lifecycle:SetScript("OnEvent",function()
    FLJ.UpdateMinimapButton()
end)
FLJ.UpdateMinimapButton()
