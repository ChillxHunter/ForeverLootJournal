-- Forever Loot Journal - Casino-style minimap button
-- Built after login, as in ForeverCasino/UI.lua and LayoutFix.lua.
local addonName, FLJ = ...
local DEFAULT_ANGLE = 315
local RADIUS = 81
local button

local function Settings()
    if type(ForeverLootJournalDB) ~= "table" then return nil end
    local db = ForeverLootJournalDB
    if type(db.ui) ~= "table" then db.ui = {} end
    local ui = db.ui
    -- One-time recovery from the previous invisible minimap launcher.
    if not ui.minimapCasinoFix117 then
        ui.minimapCasinoFix117 = true
        ui.minimapHidden = false
        ui.minimapAngle = DEFAULT_ANGLE
    end
    return ui
end

local function Position()
    if not button or not Minimap then return end
    local ui = Settings()
    if not ui then return end
    local a = math.rad(tonumber(ui.minimapAngle) or DEFAULT_ANGLE)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(a) * RADIUS, math.sin(a) * RADIUS)
    button:SetShown(not ui.minimapHidden)
end

local function CursorAngle()
    if not Minimap then return nil end
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = Minimap:GetCenter()
    if not scale or scale == 0 or not cx or not cy then return nil end
    local mx, my = GetCursorPosition()
    local dx, dy = mx / scale - cx, my / scale - cy
    if math.abs(dx) + math.abs(dy) < 0.01 then return nil end
    if math.atan2 then return math.deg(math.atan2(dy, dx)) end
    if math.abs(dx) < 0.001 then return dy >= 0 and 90 or 270 end
    local a = math.atan(dy / dx)
    if dx < 0 then a = a + math.pi end
    return math.deg(a)
end

local function BuildMinimap()
    -- Mirrors the working Casino button: parent to Minimap, native icon,
    -- tracking border as a transparent round frame, movable by drag.
    if not Minimap then return end
    if button then return end
    local m = _G.ForeverLootJournalMinimapButton
        or CreateFrame("Button", "ForeverLootJournalMinimapButton", Minimap)
    m:SetParent(Minimap)
    m:SetSize(34, 34)
    m:SetFrameStrata("HIGH")
    m:SetFrameLevel(Minimap:GetFrameLevel() + 6)
    m:RegisterForClicks("LeftButtonUp")
    m:RegisterForDrag("LeftButton")

    local icon = m:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER")
    icon:SetSize(22, 22)
    icon:SetTexture("Interface\\Icons\\INV_Chest_Chain_05")
    m.icon = icon

    local border = m:CreateTexture(nil, "OVERLAY")
    border:SetAllPoints()
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    m.border = border

    m:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Forever Loot Journal", 1, .80, .35)
        GameTooltip:AddLine("Click: open / close journal", 1, 1, 1)
        GameTooltip:AddLine("Drag: reposition around minimap", .78, .82, .9)
        GameTooltip:Show()
    end)
    m:SetScript("OnLeave", function() GameTooltip:Hide() end)
    m:SetScript("OnClick", function(self)
        if not self._fljDragging and not self._fljIgnoreClick and FLJ.Toggle then
            FLJ.Toggle()
        end
    end)
    m:SetScript("OnDragStart", function(self)
        self._fljDragging = true
        self._fljIgnoreClick = true
        GameTooltip:Hide()
        self:SetScript("OnUpdate", function()
            local angle = CursorAngle()
            local ui = Settings()
            if ui and angle then
                ui.minimapAngle = angle
                Position()
            end
        end)
    end)
    m:SetScript("OnDragStop", function(self)
        self._fljDragging = false
        self:SetScript("OnUpdate", nil)
        if C_Timer and C_Timer.After then
            C_Timer.After(.15, function() self._fljIgnoreClick = false end)
        else
            self._fljIgnoreClick = false
        end
    end)
    button = m
    Position()
end

function FLJ.UpdateMinimapButton()
    if not Minimap or not Settings() then return end
    if not button then BuildMinimap() end
    Position()
end

-- Retain the existing journal commands, adding minimap recovery commands.
local previousSlash = SlashCmdList and SlashCmdList.FOREVERLOOTJOURNAL
if previousSlash then
    SlashCmdList.FOREVERLOOTJOURNAL = function(message)
        local cmd = tostring(message or ""):lower():match("^%s*(.-)%s*$")
        if cmd == "showicon" or cmd == "map" or cmd == "minimap" then
            local ui = Settings()
            if ui then ui.minimapHidden = false end
            FLJ.UpdateMinimapButton()
            print("|cffffd76aForever Loot Journal:|r minimap button shown; drag to reposition.")
        elseif cmd == "hideicon" then
            local ui = Settings()
            if ui then ui.minimapHidden = true end
            FLJ.UpdateMinimapButton()
        elseif cmd == "icon" then
            local ui = Settings()
            if ui then ui.minimapHidden = not ui.minimapHidden end
            FLJ.UpdateMinimapButton()
        elseif cmd == "reseticon" then
            local ui = Settings()
            if ui then
                ui.minimapAngle = DEFAULT_ANGLE
                ui.minimapHidden = false
            end
            FLJ.UpdateMinimapButton()
            print("|cffffd76aForever Loot Journal:|r minimap button reset.")
        elseif cmd == "iconstatus" then
            FLJ.UpdateMinimapButton()
            local ui = Settings()
            print("|cffffd76aForever Loot Journal:|r button="..tostring(button ~= nil)
                .." shown="..tostring(button and button:IsShown())
                .." visible="..tostring(button and button:IsVisible())
                .." minimap="..tostring(Minimap ~= nil)
                .." angle="..tostring(ui and ui.minimapAngle)
                .." hidden="..tostring(ui and ui.minimapHidden))
        else
            previousSlash(message)
            if cmd == "help" then
                print("|cffffd76aMinimap:|r /flj showicon, /flj hideicon, /flj reseticon, /flj iconstatus")
            end
        end
    end
end

-- Unlike earlier revisions, do NOT create the button during addon-file load.
-- This is when Casino makes its button and avoids load-order / scale issues.
local lifecycle = CreateFrame("Frame")
lifecycle:RegisterEvent("PLAYER_LOGIN")
lifecycle:RegisterEvent("PLAYER_ENTERING_WORLD")
lifecycle:RegisterEvent("UI_SCALE_CHANGED")
lifecycle:RegisterEvent("DISPLAY_SIZE_CHANGED")
lifecycle:SetScript("OnEvent", function(_, event)
    FLJ.UpdateMinimapButton()
    if event == "PLAYER_LOGIN" and C_Timer and C_Timer.After then
        C_Timer.After(1, function() FLJ.UpdateMinimapButton() end)
    end
end)
