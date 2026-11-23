local addonName, ns = ...

local mod = ns:RegisterModule("MinimapButton", {})
local button = nil

local function GetAddonIconPath()
    local tocIcon
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        tocIcon = C_AddOns.GetAddOnMetadata(addonName, "IconTexture")
    elseif GetAddOnMetadata then
        tocIcon = GetAddOnMetadata(addonName, "IconTexture")
    end

    if tocIcon and tocIcon ~= "" then
        return tocIcon
    end
    return "Interface\\AddOns\\" .. addonName .. "\\Media\\icon"
end

local function UpdatePosition(angle)
    if not button then return end
    local rad = math.rad(angle or 220)
    local radius = 80
    local x = math.cos(rad) * radius
    local y = math.sin(rad) * radius
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function mod:Refresh()
    if not button then return end
    if ns.db.timerMinimap then
        button:Show()
        UpdatePosition(ns.db.timerMinimapAngle)
    else
        button:Hide()
    end
end

function mod:OnInit()
    local btn = CreateFrame("Button", "FarmTrackerMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local overlay = btn:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(21, 21)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture(GetAddonIconPath())
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)

    local mask = btn:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(icon)
    icon:AddMaskTexture(mask)

    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local angle = math.deg(math.atan2(cy - my, cx - mx))
            ns.db.timerMinimapAngle = angle
            UpdatePosition(angle)
        end)
    end)

    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    btn:SetScript("OnClick", function(_, mouseBtn)
        if mouseBtn == "LeftButton" then
            local trackerMod = ns.Modules["Tracker"]
            if trackerMod and trackerMod.ToggleUI then
                trackerMod:ToggleUI()
            end
        elseif mouseBtn == "RightButton" then
            local optMod = ns.Modules["Options"]
            if optMod and optMod.ToggleUI then
                optMod:ToggleUI()
            end
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cff00ccffFarm|r Tracker", 1, 1, 1)
        GameTooltip:AddLine("|cff00ff00Left-Click:|r Toggle Farm Tracker", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("|cffffff00Right-Click:|r Open Settings", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("|cffaaaaaaDrag:|r Move Icon", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button = btn
    self:Refresh()
end