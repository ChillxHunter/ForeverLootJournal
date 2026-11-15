-- Forever Loot Journal - reliable round minimap launcher (1.1.6)
local addonName, FLJ = ...
local BUTTON_SIZE = 34
local DEFAULT_ANGLE = 300
local button

local function GetSettings()
    -- SavedVariables are prepared in Core.lua during ADDON_LOADED.
    if type(ForeverLootJournalDB) ~= "table" then
        ForeverLootJournalDB = {}
    end
    local db = ForeverLootJournalDB
    if type(db.ui) ~= "table" then db.ui = {} end
    local ui = db.ui
    -- Previous positions and masks could leave the icon invisible.
    -- Recover ONCE on upgrade; all subsequent movements are preserved.
    if not ui.minimapRepair116 then
        ui.minimapRepair116 = true
        ui.minimapHidden = false
        ui.minimapAngle = DEFAULT_ANGLE
    end
    return ui
end

local function Radius()
    local width = Minimap and Minimap:GetWidth() or 160
    -- The icon straddles the outside of the minimap frame, not its interior.
    return math.max(88, width / 2 + 12)
end

local function Position()
    if not button or not Minimap then return end
    local settings = GetSettings()
    local angle = math.rad(tonumber(settings.minimapAngle) or DEFAULT_ANGLE)
    local radius = Radius()
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(angle) * radius, math.sin(angle) * radius)
    if settings.minimapHidden then button:Hide() else button:Show() end
end

local function GetAngleFromMouse()
    if not Minimap then return nil end
    local cx,cy = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    if not cx or not cy or not scale or scale == 0 then return nil end
    local mx,my = GetCursorPosition()
    local dx = mx / scale - cx
    local dy = my / scale - cy
    if math.abs(dx) + math.abs(dy) < 0.01 then return nil end
    if math.atan2 then return math.deg(math.atan2(dy,dx)) end
    if math.abs(dx) < 0.001 then
        return dy >= 0 and 90 or 270
    end
    local a = math.atan(dy/dx)
    if dx < 0 then a = a + math.pi end
    return math.deg(a)
end

local function BuildButton()
    if not Minimap or not UIParent then return end
    if not button then
        button = _G.ForeverLootJournalMinimapButton
            or CreateFrame("Button","ForeverLootJournalMinimapButton",UIParent)
    end
    -- Important: UIParent never clips children to the minimap's round map mask.
    button:SetParent(UIParent)
    if button._fljButton116 then return end
    button._fljButton116 = true
    button:SetSize(BUTTON_SIZE,BUTTON_SIZE)
    button:SetFrameStrata("HIGH")
    button:SetFrameLevel(math.max(30,(Minimap:GetFrameLevel() or 1)+12))
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetNormalTexture(nil)
    button:SetPushedTexture(nil)
    button:SetHighlightTexture(nil)

    -- Do not draw any opaque background or unsupported mask texture.
    -- The stock tracking border has a transparent circular opening.
    local icon = button.icon or button:CreateTexture(nil,"ARTWORK")
    icon:ClearAllPoints()
    icon:SetPoint("CENTER",button,"CENTER",0,0)
    icon:SetSize(18,18)
    icon:SetTexture("Interface\\Icons\\INV_Chest_Chain_05")
    icon:SetTexCoord(.12,.88,.12,.88)
    icon:Show()
    button.icon = icon

    local rim=button:CreateTexture(nil,"OVERLAY")
    rim:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    rim:SetAllPoints(button)
    rim:SetSize(34,34)
    button.rim=rim

    local glow=button:CreateTexture(nil,"HIGHLIGHT")
    glow:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    glow:SetAllPoints(button)
    glow:SetBlendMode("ADD")

    button:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_LEFT")
        GameTooltip:AddLine("Forever Loot Journal",1,.84,.35)
        GameTooltip:AddLine("Left click to open",1,1,1)
        GameTooltip:AddLine("Drag to move around the minimap",.78,.84,1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave",function() GameTooltip:Hide() end)
    button:SetScript("OnClick",function(self)
        if not self._dragging and not self._suppressClick and FLJ.Toggle then
            FLJ.Toggle()
        end
    end)
    button:SetScript("OnDragStart",function(self)
        self._dragging=true
        self._suppressClick=true
        GameTooltip:Hide()
        self:SetScript("OnUpdate",function()
            local angle=GetAngleFromMouse()
            if angle then
                GetSettings().minimapAngle=angle
                Position()
            end
        end)
    end)
    button:SetScript("OnDragStop",function(self)
        self._dragging=false
        self:SetScript("OnUpdate",nil)
        if C_Timer and C_Timer.After then
            C_Timer.After(.15,function() self._suppressClick=false end)
        else
            self._suppressClick=false
        end
    end)
end

function FLJ.UpdateMinimapButton()
    if not Minimap or not UIParent then return end
    BuildButton()
    Position()
end

local previousSlash=SlashCmdList and SlashCmdList.FOREVERLOOTJOURNAL
if previousSlash then
    SlashCmdList.FOREVERLOOTJOURNAL=function(message)
        local cmd=tostring(message or ""):lower():match("^%s*(.-)%s*$")
        local ui=GetSettings()
        if cmd=="showicon" or cmd=="map" or cmd=="minimap" then
            ui.minimapHidden=false
            FLJ.UpdateMinimapButton()
            print("|cffffd76aForever Loot Journal:|r map icon shown")
        elseif cmd=="hideicon" then
            ui.minimapHidden=true
            FLJ.UpdateMinimapButton()
            print("|cffffd76aForever Loot Journal:|r map icon hidden")
        elseif cmd=="icon" then
            ui.minimapHidden=not ui.minimapHidden
            FLJ.UpdateMinimapButton()
        elseif cmd=="reseticon" then
            ui.minimapHidden=false
            ui.minimapAngle=DEFAULT_ANGLE
            FLJ.UpdateMinimapButton()
            print("|cffffd76aForever Loot Journal:|r map icon restored to the map's lower-right edge")
        elseif cmd=="iconstatus" then
            FLJ.UpdateMinimapButton()
            print("|cffffd76aForever Loot Journal:|r minimap="..tostring(Minimap~=nil)
                .." button="..tostring(button~=nil)
                .." visible="..tostring(button and button:IsVisible())
                .." shown="..tostring(button and button:IsShown())
                .." angle="..tostring(ui.minimapAngle)
                .." hidden="..tostring(ui.minimapHidden))
        else
            previousSlash(message)
            if cmd=="help" then
                print("|cffffd76aMinimap commands:|r /flj reseticon, /flj showicon, /flj iconstatus")
            end
        end
    end
end

local loader=CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:RegisterEvent("UI_SCALE_CHANGED")
loader:RegisterEvent("DISPLAY_SIZE_CHANGED")
loader:SetScript("OnEvent",function()
    FLJ.UpdateMinimapButton()
end)
FLJ.UpdateMinimapButton()
