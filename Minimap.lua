-- Forever Loot Journal: circular, movable minimap launcher
local addonName, FLJ = ...
local DEFAULT_ANGLE, BUTTON_SIZE = 315, 34
local button

local function Settings()
    if type(ForeverLootJournalDB)~="table" then ForeverLootJournalDB={} end
    if type(ForeverLootJournalDB.ui)~="table" then ForeverLootJournalDB.ui={} end
    return ForeverLootJournalDB.ui
end

local function Radius()
    if not Minimap then return 115 end
    return (Minimap:GetWidth() or 180)/2 + BUTTON_SIZE/2 + 5
end

local function Position()
    if not button or not Minimap then return end
    local ui=Settings()
    local angle=math.rad(tonumber(ui.minimapAngle) or DEFAULT_ANGLE)
    local r=Radius()
    button:ClearAllPoints()
    button:SetPoint("CENTER",Minimap,"CENTER",math.cos(angle)*r,math.sin(angle)*r)
    button:SetShown(not ui.minimapHidden)
end

local function CursorAngle()
    local cx,cy=Minimap:GetCenter()
    local scale=Minimap:GetEffectiveScale()
    if not cx or not cy or not scale or scale==0 then return nil end
    local mx,my=GetCursorPosition()
    local dx,dy=mx/scale-cx,my/scale-cy
    if math.abs(dx)+math.abs(dy)<.001 then return nil end
    if math.abs(dx)<.001 then return dy>=0 and 90 or 270 end
    local a
    if math.atan2 then a=math.atan2(dy,dx)
    else
        a=math.atan(dy/dx)
        if dx<0 then a=a+math.pi end
    end
    return math.deg(a)
end

local function CreateButton()
    if not Minimap or not UIParent then return end
    if not button then
        button=_G.ForeverLootJournalMinimapButton or CreateFrame("Button","ForeverLootJournalMinimapButton",UIParent)
    end
    -- Avoid Minimap's cropping region, and avoid the old legacy shortcut frame.
    button:SetParent(UIParent)
    if button._fljBuilt then return end
    button._fljBuilt=true
    button:SetSize(BUTTON_SIZE,BUTTON_SIZE)
    button:SetFrameStrata("HIGH")
    button:SetFrameLevel((Minimap:GetFrameLevel() or 0)+8)
    button:SetClampedToScreen(true)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetNormalTexture(nil)
    button:SetPushedTexture(nil)
    button:SetHighlightTexture(nil)

    -- NO opaque backdrop: just a masked portrait and transparent circular rim.
    local icon=button:CreateTexture(nil,"ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Chest_Chain_05")
    icon:SetPoint("CENTER",button,"CENTER",0,0)
    icon:SetSize(26,26)
    icon:SetTexCoord(.07,.93,.07,.93)
    button.icon=icon
    if button.CreateMaskTexture and icon.AddMaskTexture then
        local mask=button:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        mask:SetAllPoints(icon)
        icon:AddMaskTexture(mask)
        button.iconMask=mask
    end
    local ring=button:CreateTexture(nil,"OVERLAY")
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    ring:SetAllPoints(button)
    button.ring=ring
    local glow=button:CreateTexture(nil,"HIGHLIGHT")
    glow:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    glow:SetBlendMode("ADD")
    glow:SetAllPoints(button)

    button:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_LEFT")
        GameTooltip:AddLine("Forever Loot Journal",1,.82,.33)
        GameTooltip:AddLine("Left-click: open or close journal",1,1,1)
        GameTooltip:AddLine("Drag: move around the minimap",.8,.86,1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave",function() GameTooltip:Hide() end)
    button:SetScript("OnClick",function(self)
        if not self._ignoreClick and not self._dragging and FLJ.Toggle then FLJ.Toggle() end
    end)
    button:SetScript("OnDragStart",function(self)
        self._dragging=true
        self._ignoreClick=true
        GameTooltip:Hide()
        self:SetScript("OnUpdate",function()
            local angle=CursorAngle()
            if angle then Settings().minimapAngle=angle; Position() end
        end)
    end)
    button:SetScript("OnDragStop",function(self)
        self:SetScript("OnUpdate",nil)
        self._dragging=false
        if C_Timer and C_Timer.After then
            C_Timer.After(.15,function() self._ignoreClick=false end)
        else self._ignoreClick=false end
    end)
end

function FLJ.UpdateMinimapButton()
    CreateButton()
    Position()
end

local previousSlash=SlashCmdList and SlashCmdList.FOREVERLOOTJOURNAL
if previousSlash then
    SlashCmdList.FOREVERLOOTJOURNAL=function(message)
        local cmd=tostring(message or ""):lower():match("^%s*(.-)%s*$")
        local ui=Settings()
        if cmd=="showicon" or cmd=="map" or cmd=="minimap" then
            ui.minimapHidden=false; FLJ.UpdateMinimapButton()
            print("|cffffd76aForever Loot Journal:|r minimap icon shown; drag to move.")
        elseif cmd=="hideicon" then
            ui.minimapHidden=true; FLJ.UpdateMinimapButton()
        elseif cmd=="icon" then
            ui.minimapHidden=not ui.minimapHidden; FLJ.UpdateMinimapButton()
        elseif cmd=="reseticon" then
            ui.minimapAngle=DEFAULT_ANGLE
            ui.minimapHidden=false
            FLJ.UpdateMinimapButton()
            print("|cffffd76aForever Loot Journal:|r minimap icon reset outside the map.")
        else
            previousSlash(message)
            if cmd=="help" then print("|cffffd76aMinimap:|r /flj showicon, hideicon, reseticon") end
        end
    end
end

local updater=CreateFrame("Frame")
updater:RegisterEvent("PLAYER_LOGIN")
updater:RegisterEvent("PLAYER_ENTERING_WORLD")
updater:RegisterEvent("UI_SCALE_CHANGED")
updater:RegisterEvent("DISPLAY_SIZE_CHANGED")
updater:SetScript("OnEvent",function() FLJ.UpdateMinimapButton() end)
FLJ.UpdateMinimapButton()
