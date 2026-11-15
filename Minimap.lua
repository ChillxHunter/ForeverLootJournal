-- Forever Loot Journal: movable minimap launcher (Casino-style)
-- Loaded after UI.lua so we can upgrade its existing static shortcut.
local addonName, FLJ = ...
local DEFAULT_ANGLE = 135
local RADIUS = 81
local button

local function Settings()
    if type(ForeverLootJournalDB) ~= "table" then return nil end
    local db = ForeverLootJournalDB
    if type(db.ui) ~= "table" then db.ui = {} end
    return db.ui
end

local function Position()
    if not button or not Minimap then return end
    local ui = Settings()
    local angle = ui and tonumber(ui.minimapAngle) or DEFAULT_ANGLE
    local rad = math.rad(angle)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * RADIUS, math.sin(rad) * RADIUS)
    button:SetShown(not (ui and ui.minimapHidden))
end

local function CursorAngle()
    if not Minimap then return nil end
    local cx, cy = Minimap:GetCenter()
    if not cx then return nil end
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    if not scale or scale == 0 then return nil end
    local dx, dy = px / scale - cx, py / scale - cy
    if math.abs(dx) + math.abs(dy) < .001 then return nil end
    if math.abs(dx) < .001 then return dy >= 0 and 90 or 270 end
    local rad
    if math.atan2 then
        rad = math.atan2(dy, dx)
    else
        rad = math.atan(dy / dx)
        if dx < 0 then rad = rad + math.pi end
    end
    return math.deg(rad)
end

local function CreateButton()
    if not Minimap then return end
    if button and button:GetParent() ~= Minimap then button:SetParent(Minimap) end
    if not button then
        button = _G.ForeverLootJournalMinimapButton
            or CreateFrame("Button", "ForeverLootJournalMinimapButton", Minimap)
    end
    if button._fljMovable then return end
    button._fljMovable = true
    button:SetSize(34, 34)
    button:SetFrameStrata("HIGH")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetNormalTexture(nil)

    local icon = button.icon or button:CreateTexture(nil, "ARTWORK")
    button.icon = icon
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetSize(22, 22)
    icon:SetTexture("Interface\\Icons\\INV_Chest_Chain_05")

    local ring = button:CreateTexture(nil, "OVERLAY")
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    ring:SetAllPoints()

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Forever Loot Journal", 1, .80, .35)
        GameTooltip:AddLine("Left-click: open / close journal", .95, .95, .95)
        GameTooltip:AddLine("Alt + drag: move around the minimap", .75, .8, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnClick", function(self)
        if self._ignoreClick or IsAltKeyDown() then return end
        if FLJ.Toggle then FLJ.Toggle() end
    end)
    button:SetScript("OnDragStart", function(self)
        if not IsAltKeyDown() then return end
        self._dragging = true
        GameTooltip:Hide()
        self:SetScript("OnUpdate", function()
            local angle = CursorAngle()
            local ui = Settings()
            if angle and ui then
                ui.minimapAngle = angle
                Position()
            end
        end)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        if self._dragging then
            self._dragging = false
            self._ignoreClick = true
            if C_Timer and C_Timer.After then
                C_Timer.After(.15, function() self._ignoreClick = false end)
            else
                self._ignoreClick = false
            end
        end
    end)
end

function FLJ.UpdateMinimapButton()
    CreateButton()
    Position()
end

-- Keep the original journal commands and add recovery commands for the launcher.
local oldSlash = SlashCmdList and SlashCmdList.FOREVERLOOTJOURNAL
if oldSlash then
    SlashCmdList.FOREVERLOOTJOURNAL = function(msg)
        local command = tostring(msg or ""):lower():match("^%s*(.-)%s*$")
        local ui = Settings()
        if (command == "showicon" or command == "map" or command == "minimap") and ui then
            ui.minimapHidden = false
            FLJ.UpdateMinimapButton()
            print("|cffffd76aForever Loot Journal:|r minimap button shown. Alt + drag to move.")
        elseif command == "hideicon" and ui then
            ui.minimapHidden = true
            FLJ.UpdateMinimapButton()
            print("|cffffd76aForever Loot Journal:|r minimap button hidden. /flj showicon restores it.")
        elseif command == "icon" and ui then
            ui.minimapHidden = not ui.minimapHidden
            FLJ.UpdateMinimapButton()
            print("|cffffd76aForever Loot Journal:|r minimap button " .. (ui.minimapHidden and "hidden." or "shown."))
        elseif command == "reseticon" and ui then
            ui.minimapAngle = DEFAULT_ANGLE
            ui.minimapHidden = false
            FLJ.UpdateMinimapButton()
            print("|cffffd76aForever Loot Journal:|r minimap button position reset.")
        else
            oldSlash(msg)
            if command == "help" then
                print("|cffffd76aMinimap:|r /flj showicon, /flj hideicon, /flj icon, /flj reseticon")
            end
        end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function()
    FLJ.UpdateMinimapButton()
end)
FLJ.UpdateMinimapButton()
