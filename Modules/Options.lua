local _, ns = ...

local mod = ns:RegisterModule("Options", {})

local optFrame      = nil
local fontDropdown  = nil
local priceDropdown = nil
local soundDropdown = nil
local blRows        = {}

local PRICE_SOURCES = {
    { key = "AUTO",        label = "Auto (TSM / Auc)" },
    { key = "TSM_MIN",     label = "TSM: Min Buyout" },
    { key = "TSM_MARKET",  label = "TSM: Market" },
    { key = "TSM_HIST",    label = "TSM: Historical" },
    { key = "AUCTIONATOR", label = "Auctionator" },
    { key = "VENDOR",      label = "Vendor Only" },
}

local function GetPriceSourceLabel(key)
    for _, src in ipairs(PRICE_SOURCES) do
        if src.key == key then return src.label end
    end
    return "Auto (TSM / Auc)"
end

local function GetAlertSoundLabel(key)
    for _, s in ipairs(ns.Utils.AlertSounds) do
        if s.key == key then return s.label end
    end
    return "Loot Coins"
end

local function FormatThresholdText(copper)
    copper = math.floor(copper or 0)
    if copper <= 0 then return "0c" end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    local parts = {}
    if g > 0 then table.insert(parts, g .. "g") end
    if s > 0 then table.insert(parts, s .. "s") end
    if c > 0 then table.insert(parts, c .. "c") end
    return table.concat(parts, " ")
end

local function ParseThresholdInput(text, fallback)
    if not text then return 0 end
    local clean = string.lower(strtrim(text))
    if clean == "" or clean == "0" or clean == "0c" then return 0 end

    local g = tonumber(string.match(clean, "(%d+%.?%d*)%s*g")) or 0
    local s = tonumber(string.match(clean, "(%d+)%s*s")) or 0
    local c = tonumber(string.match(clean, "(%d+)%s*c")) or 0

    if g > 0 or s > 0 or c > 0 then
        return math.floor((g * 10000) + (s * 100) + c + 0.5)
    end

    local plain = tonumber(clean)
    if plain and plain >= 0 then
        return math.floor((plain * 10000) + 0.5)
    end
    return fallback or 0
end

local function GetAvailableFonts()
    local fonts = {}
    local seen  = {}

    local function AddFont(name, path)
        if name and path and not seen[name] then
            seen[name] = true
            table.insert(fonts, { name = name, path = path })
        end
    end

    AddFont("Friz Quadrata", "Fonts\\FRIZQT__.TTF")
    AddFont("Arial Narrow",  "Fonts\\ARIALN.TTF")
    AddFont("Morpheus",      "Fonts\\MORPHEUS.TTF")
    AddFont("Skurri",        "Fonts\\skurri.ttf")

    local lsm = _G.LibStub and _G.LibStub("LibSharedMedia-3.0", true)
    if lsm and lsm.List and lsm.Fetch then
        for _, name in ipairs(lsm:List("font")) do
            local path = lsm:Fetch("font", name, true)
            if path then
                AddFont(name, path)
            end
        end
    end

    table.sort(fonts, function(a, b)
        return a.name:lower() < b.name:lower()
    end)

    return fonts
end

ns.GetAvailableFonts = GetAvailableFonts

local function HideDropdowns()
    if fontDropdown then fontDropdown:Hide() end
    if priceDropdown then priceDropdown:Hide() end
    if soundDropdown then soundDropdown:Hide() end
end

local function NotifyRefresh()
    local Utils = ns.Utils
    Utils.ApplyBackdropTheme(optFrame, false, false)
    Utils.ApplyBackdropTheme(fontDropdown, false, false)
    Utils.ApplyBackdropTheme(priceDropdown, false, false)
    Utils.ApplyBackdropTheme(soundDropdown, false, false)

    -- Main farm tracking window
    local trackerMod = ns.Modules["Tracker"]
    if trackerMod and trackerMod.RefreshSettings then
        trackerMod:RefreshSettings()
    end

    -- MinimapButton
    local miniMod = ns.Modules["MinimapButton"]
    if miniMod and miniMod.Refresh then
        miniMod:Refresh()
    end

    -- History
    local histMod = ns.Modules["History"]
    if histMod and histMod.RefreshTheme then
        histMod:RefreshTheme()
    end

    -- Farm finder
    local ffMod = ns.Modules["FarmFinder"]
    if ffMod then
        if ffMod.RefreshTheme then ffMod:RefreshTheme() end
        if ffMod.RefreshList then ffMod:RefreshList() end
    end
end

local function ClampButtonText(btn)
    local fs = btn:GetFontString()
    if fs then
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", 8, 0)
        fs:SetPoint("RIGHT", -8, 0)
        fs:SetJustifyH("CENTER")
        fs:SetWordWrap(false)
    end
end

local function TogglePriceDropdown(anchorBtn)
    local wasShown = priceDropdown and priceDropdown:IsShown()
    HideDropdowns()
    if wasShown then return end

    if not priceDropdown then
        local dd = CreateFrame("Frame", "FarmTrackerPriceDropdown", optFrame, "BackdropTemplate")
        dd:SetWidth(155)
        dd:SetFrameStrata("TOOLTIP")
        dd:SetClampedToScreen(true)
        dd.buttons = {}
        dd:Hide()
        priceDropdown = dd
    end

    ns.Utils.ApplyBackdropTheme(priceDropdown, false, false)
    priceDropdown:SetHeight((#PRICE_SOURCES * 22) + 12)

    for i, src in ipairs(PRICE_SOURCES) do
        local btn = priceDropdown.buttons[i]
        if not btn then
            btn = CreateFrame("Button", nil, priceDropdown)
            btn:SetHeight(20)

            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(0.2, 0.5, 0.8, 0.3)

            local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            txt:SetPoint("LEFT", 6, 0)
            txt:SetPoint("RIGHT", -6, 0)
            txt:SetJustifyH("LEFT")
            btn.txt = txt

            priceDropdown.buttons[i] = btn
        end

        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", 6, -6 - ((i - 1) * 22))
        btn:SetPoint("TOPRIGHT", -6, -6 - ((i - 1) * 22))
        btn.txt:SetText(src.label)

        btn:SetScript("OnClick", function()
            ns.db.ahPriceSource = src.key
            anchorBtn:SetText(src.label .. "  v")
            priceDropdown:Hide()
            NotifyRefresh()
        end)
        btn:Show()
    end

    priceDropdown:ClearAllPoints()
    priceDropdown:SetPoint("TOP", anchorBtn, "BOTTOM", 0, -2)
    priceDropdown:Show()
end

local function ToggleSoundDropdown(anchorBtn)
    local wasShown = soundDropdown and soundDropdown:IsShown()
    HideDropdowns()
    if wasShown then return end

    if not soundDropdown then
        local dd = CreateFrame("Frame", "FarmTrackerSoundDropdown", optFrame, "BackdropTemplate")
        dd:SetWidth(155)
        dd:SetFrameStrata("TOOLTIP")
        dd:SetClampedToScreen(true)
        dd.buttons = {}
        dd:Hide()
        soundDropdown = dd
    end

    local sounds = ns.Utils.AlertSounds
    ns.Utils.ApplyBackdropTheme(soundDropdown, false, false)
    soundDropdown:SetHeight((#sounds * 22) + 12)

    for i, s in ipairs(sounds) do
        local btn = soundDropdown.buttons[i]
        if not btn then
            btn = CreateFrame("Button", nil, soundDropdown)
            btn:SetHeight(20)

            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(0.2, 0.5, 0.8, 0.3)

            local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            txt:SetPoint("LEFT", 6, 0)
            txt:SetPoint("RIGHT", -6, 0)
            txt:SetJustifyH("LEFT")
            btn.txt = txt

            soundDropdown.buttons[i] = btn
        end

        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", 6, -6 - ((i - 1) * 22))
        btn:SetPoint("TOPRIGHT", -6, -6 - ((i - 1) * 22))
        btn.txt:SetText(s.label)

        btn:SetScript("OnClick", function()
            ns.db.dropAlertSound = s.key
            anchorBtn:SetText(s.label .. "  v")
            soundDropdown:Hide()
            ns.Utils.PlayDropAlertSound()
        end)
        btn:Show()
    end

    soundDropdown:ClearAllPoints()
    soundDropdown:SetPoint("TOP", anchorBtn, "BOTTOM", 0, -2)
    soundDropdown:Show()
end

local function ToggleFontDropdown(anchorBtn)
    local wasShown = fontDropdown and fontDropdown:IsShown()
    HideDropdowns()
    if wasShown then return end

    local fonts = GetAvailableFonts()

    if not fontDropdown then
        local dd = CreateFrame("Frame", "FarmTrackerFontDropdown", optFrame, "BackdropTemplate")
        dd:SetWidth(175)
        dd:SetFrameStrata("TOOLTIP")
        dd:SetClampedToScreen(true)

        local scrollFrame = CreateFrame("ScrollFrame", "FarmTrackerFontScroll", dd, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 6, -6)
        scrollFrame:SetPoint("BOTTOMRIGHT", -26, 6)

        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetWidth(140)
        scrollChild:SetHeight(1)
        scrollFrame:SetScrollChild(scrollChild)

        dd.scrollFrame = scrollFrame
        dd.scrollChild = scrollChild
        dd.buttons     = {}
        dd:Hide()
        fontDropdown = dd
    end

    ns.Utils.ApplyBackdropTheme(fontDropdown, false, false)

    local rowHeight   = 22
    local totalHeight = (#fonts * rowHeight) + 12
    fontDropdown:SetHeight(math.min(totalHeight, 220))
    fontDropdown.scrollChild:SetHeight(math.max(#fonts * rowHeight, 1))

    for i, fontInfo in ipairs(fonts) do
        local btn = fontDropdown.buttons[i]
        if not btn then
            btn = CreateFrame("Button", nil, fontDropdown.scrollChild)
            btn:SetHeight(20)

            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(0.2, 0.5, 0.8, 0.3)

            local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            txt:SetPoint("LEFT", 4, 0)
            txt:SetPoint("RIGHT", -4, 0)
            txt:SetJustifyH("LEFT")
            txt:SetWordWrap(false)
            btn.txt = txt

            fontDropdown.buttons[i] = btn
        end

        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", fontDropdown.scrollChild, "TOPLEFT", 0, -((i - 1) * rowHeight))
        btn:SetPoint("TOPRIGHT", fontDropdown.scrollChild, "TOPRIGHT", 0, -((i - 1) * rowHeight))

        local ok = btn.txt:SetFont(fontInfo.path, 11, "")
        btn.txt:SetText(fontInfo.name)
        if not ok or (btn.txt:GetStringWidth() or 0) == 0 then
            btn.txt:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
            btn.txt:SetText(fontInfo.name)
        end

        btn:SetScript("OnClick", function()
            ns.db.timerFont = fontInfo.name
            anchorBtn:SetText(fontInfo.name .. "  v")
            fontDropdown:Hide()
            NotifyRefresh()
        end)
        btn:Show()
    end

    for i = #fonts + 1, #fontDropdown.buttons do
        fontDropdown.buttons[i]:Hide()
    end

    fontDropdown:ClearAllPoints()
    fontDropdown:SetPoint("TOP", anchorBtn, "BOTTOM", 0, -2)
    fontDropdown:Show()
end

local function RefreshBlacklistUI()
    if not optFrame or not optFrame.blScrollChild then return end

    local items = {}
    if type(ns.db.globalBlacklist) == "table" then
        for idKey, name in pairs(ns.db.globalBlacklist) do
            table.insert(items, { id = idKey, name = tostring(name) })
        end
    end
    table.sort(items, function(a, b) return a.name:lower() < b.name:lower() end)

    optFrame.blHeader:SetText(string.format("|cff00ccffGlobal Blocklist|r |cffaaaaaa(%d)|r", #items))

    if #items == 0 then
        optFrame.blEmpty:Show()
    else
        optFrame.blEmpty:Hide()
    end

    local rowHeight = 20
    for i, info in ipairs(items) do
        local row = blRows[i]
        if not row then
            row = CreateFrame("Frame", nil, optFrame.blScrollChild)
            row:SetHeight(rowHeight)

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0.0)

            local delBtn = CreateFrame("Button", nil, row)
            delBtn:SetSize(16, 16)
            delBtn:SetPoint("RIGHT", -2, 0)
            delBtn:SetNormalFontObject("GameFontHighlightSmall")
            delBtn:SetText("|cffff5555x|r")
            row.delBtn = delBtn

            local txt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            txt:SetPoint("LEFT", 4, 0)
            txt:SetPoint("RIGHT", delBtn, "LEFT", -4, 0)
            txt:SetJustifyH("LEFT")
            txt:SetWordWrap(false)
            row.txt = txt

            blRows[i] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", optFrame.blScrollChild, "TOPLEFT", 0, -((i - 1) * rowHeight))
        row:SetPoint("TOPRIGHT", optFrame.blScrollChild, "TOPRIGHT", 0, -((i - 1) * rowHeight))
        row.txt:SetText(info.name)

        row.delBtn:SetScript("OnClick", function()
            ns.db.globalBlacklist[info.id] = nil
            RefreshBlacklistUI()
            NotifyRefresh()
        end)
        row:Show()
    end

    for i = #items + 1, #blRows do
        blRows[i]:Hide()
    end

    optFrame.blScrollChild:SetHeight(math.max(#items * rowHeight, 1))
end

local function CreateOptionsUI()
    if optFrame then return optFrame end

    local f = CreateFrame("Frame", "FarmTrackerOptionsFrame", UIParent, "BackdropTemplate")
    tinsert(UISpecialFrames, "FarmTrackerOptionsFrame")
    f:SetSize(350, 464)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)

    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetScript("OnHide", HideDropdowns)

    -- Title Bar
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText("|cff00ccffFarm Tracker|r Settings")

    local closeBtn = CreateFrame("Button", nil, f)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("TOPRIGHT", -8, -8)
    closeBtn:SetNormalFontObject("GameFontNormal")
    closeBtn:SetText("|cffff5555X|r")
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local divTop = f:CreateTexture(nil, "ARTWORK")
    divTop:SetColorTexture(0.25, 0.25, 0.3, 0.8)
    divTop:SetSize(322, 1)
    divTop:SetPoint("TOP", 0, -34)

    -- Tab Bar Setup (4 Tabs)
    local tabDefs = {
        { key = "appearance", label = "Appearance" },
        { key = "display",    label = "Display" },
        { key = "loot",       label = "Loot & AH" },
        { key = "auto",       label = "Automation" },
    }

    f.tabs   = {}
    f.panels = {}
    f.checks = {}

    local function SelectTab(activeKey)
        HideDropdowns()
        f.activeTab = activeKey
        for _, def in ipairs(tabDefs) do
            local isSel = (def.key == activeKey)
            local tb = f.tabs[def.key]
            local pn = f.panels[def.key]
            if isSel then
                tb:SetText("|cff00ccff" .. def.label .. "|r")
                tb:Disable()
                pn:Show()
            else
                tb:SetText("|cffcccccc" .. def.label .. "|r")
                tb:Enable()
                pn:Hide()
            end
        end
        if activeKey == "loot" then
            RefreshBlacklistUI()
        end
    end
    f.SelectTab = SelectTab

    for i, def in ipairs(tabDefs) do
        local tb = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        tb:SetSize(78, 22)
        tb:SetPoint("TOPLEFT", 14 + ((i - 1) * 81), -40)
        tb:SetNormalFontObject("GameFontHighlightSmall")
        tb:SetDisabledFontObject("GameFontHighlightSmall")
        tb:SetScript("OnClick", function() SelectTab(def.key) end)
        f.tabs[def.key] = tb

        local panel = CreateFrame("Frame", nil, f)
        panel:SetPoint("TOPLEFT", 14, -70)
        panel:SetPoint("BOTTOMRIGHT", -14, 42)
        panel:Hide()
        f.panels[def.key] = panel
    end

    local divTab = f:CreateTexture(nil, "ARTWORK")
    divTab:SetColorTexture(0.25, 0.25, 0.3, 0.8)
    divTab:SetSize(322, 1)
    divTab:SetPoint("TOP", 0, -66)

    -- Shared panel builder helpers
    local function AddHeader(panel, text, y)
        local hdr = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        hdr:SetPoint("TOPLEFT", 0, y)
        hdr:SetText(text)
        return hdr, y - 18
    end

    local function AddDivider(panel, y)
        y = y - 4
        local div = panel:CreateTexture(nil, "ARTWORK")
        div:SetColorTexture(0.25, 0.25, 0.3, 0.8)
        div:SetSize(320, 1)
        div:SetPoint("TOP", 0, y)
        return y - 8
    end

    local function AddCheckbox(panel, key, label, y)
        local cb = CreateFrame("CheckButton", "FarmTrackerOptCheck_" .. key, panel, "UICheckButtonTemplate")
        cb:SetSize(22, 22)
        cb:SetPoint("TOPLEFT", 0, y)
        cb:SetScript("OnClick", function(self)
            ns.db[key] = self:GetChecked() and true or false
            NotifyRefresh()
        end)

        local lbl = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        lbl:SetText(label)

        f.checks[key] = cb
        return y - 22
    end

    -- =========================================================================
    -- TAB 1: APPEARANCE
    -- =========================================================================
    local pApp = f.panels.appearance
    local y = -4

    local themeLbl = pApp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeLbl:SetPoint("TOPLEFT", 0, y - 4)
    themeLbl:SetText("UI Theme:")

    local themeBtn = CreateFrame("Button", nil, pApp, "UIPanelButtonTemplate")
    themeBtn:SetSize(155, 22)
    themeBtn:SetPoint("TOPRIGHT", 0, y)
    themeBtn:SetScript("OnClick", function(self)
        ns.db.timerTheme = (ns.db.timerTheme == "classic") and "dark" or "classic"
        self:SetText(ns.db.timerTheme == "classic" and "WoW Forever" or "Dark Modern")
        NotifyRefresh()
    end)
    f.themeBtn = themeBtn
    y = y - 30

    local fontLbl = pApp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontLbl:SetPoint("TOPLEFT", 0, y - 4)
    fontLbl:SetText("Font Family:")

    local fontBtn = CreateFrame("Button", nil, pApp, "UIPanelButtonTemplate")
    fontBtn:SetSize(155, 22)
    fontBtn:SetPoint("TOPRIGHT", 0, y)
    fontBtn:SetScript("OnClick", function(self) ToggleFontDropdown(self) end)
    fontBtn:SetText("Friz Quadrata  v")
    ClampButtonText(fontBtn)
    f.fontBtn = fontBtn
    y = y - 32

    local sizeLbl = pApp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sizeLbl:SetPoint("TOPLEFT", 0, y)
    sizeLbl:SetText("Font Size:")

    local sizeValLbl = pApp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sizeValLbl:SetPoint("TOPRIGHT", 0, y)
    sizeValLbl:SetText("11px")
    f.sizeValLbl = sizeValLbl
    y = y - 18

    local slider = CreateFrame("Slider", "FarmTrackerFontSizeSlider", pApp, "OptionsSliderTemplate")
    slider:SetWidth(308)
    slider:SetHeight(16)
    slider:SetPoint("TOP", 0, y)
    slider:SetMinMaxValues(8, 64)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    if _G["FarmTrackerFontSizeSliderLow"] then _G["FarmTrackerFontSizeSliderLow"]:SetText("8px") end
    if _G["FarmTrackerFontSizeSliderHigh"] then _G["FarmTrackerFontSizeSliderHigh"]:SetText("64px") end
    if _G["FarmTrackerFontSizeSliderText"] then _G["FarmTrackerFontSizeSliderText"]:SetText("") end

    local isSyncing = false
    slider:SetScript("OnValueChanged", function(_, value)
        if isSyncing then return end
        local px = math.floor(value + 0.5)
        ns.db.timerFontSize = px
        f.sizeValLbl:SetText(px .. "px")
        NotifyRefresh()
    end)
    f.slider = slider
    f.SetSyncing = function(_, val) isSyncing = val end
    y = y - 30

    local opLbl = pApp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    opLbl:SetPoint("TOPLEFT", 0, y)
    opLbl:SetText("Background Opacity:")

    local opValLbl = pApp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    opValLbl:SetPoint("TOPRIGHT", 0, y)
    opValLbl:SetText("92%")
    f.opValLbl = opValLbl
    y = y - 18

    local opSlider = CreateFrame("Slider", "FarmTrackerBgOpacitySlider", pApp, "OptionsSliderTemplate")
    opSlider:SetWidth(308)
    opSlider:SetHeight(16)
    opSlider:SetPoint("TOP", 0, y)
    opSlider:SetMinMaxValues(10, 100)
    opSlider:SetValueStep(5)
    opSlider:SetObeyStepOnDrag(true)
    if _G["FarmTrackerBgOpacitySliderLow"] then _G["FarmTrackerBgOpacitySliderLow"]:SetText("10%") end
    if _G["FarmTrackerBgOpacitySliderHigh"] then _G["FarmTrackerBgOpacitySliderHigh"]:SetText("100%") end
    if _G["FarmTrackerBgOpacitySliderText"] then _G["FarmTrackerBgOpacitySliderText"]:SetText("") end

    opSlider:SetScript("OnValueChanged", function(_, value)
        if isSyncing then return end
        local pct = math.floor(value + 0.5)
        ns.db.timerBgAlpha = pct / 100
        f.opValLbl:SetText(pct .. "%")
        NotifyRefresh()
    end)
    f.opSlider = opSlider
    y = y - 30

    y = AddDivider(pApp, y)
    _, y = AddHeader(pApp, "|cff00ccffWindow & Minimap|r", y)
    y = AddCheckbox(pApp, "timerMinimap",     "Show Minimap Button", y)
    y = AddCheckbox(pApp, "timerLocked",      "Lock Window Position & Size", y)
    y = AddCheckbox(pApp, "compactClickThru", "Click-Through Compact Mode |cffaaaaaa(when Locked)|r", y)

    -- =========================================================================
    -- TAB 2: DISPLAY
    -- =========================================================================
    local pDisp = f.panels.display
    y = -2

    _, y = AddHeader(pDisp, "|cff00ccffGeneral Stats|r", y)
    y = AddCheckbox(pDisp, "showTotalGold",   "Show Net Session Profit", y)
    y = AddCheckbox(pDisp, "showRepairCosts", "Show Repair Costs", y)
    y = AddCheckbox(pDisp, "showXpPerHour",   "Show XP / Hour |cffaaaaaa(hidden at 60)|r", y)
    y = AddCheckbox(pDisp, "showTimeToLevel", "Show Time to Level |cffaaaaaa(hidden at 60)|r", y)
    y = AddCheckbox(pDisp, "showBagSpace",    "Show Free Bag Slots", y)
    y = AddCheckbox(pDisp, "showGoalBar",     "Show Session Gold Goal Bar", y)

    local goalLbl = pDisp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    goalLbl:SetPoint("TOPLEFT", 6, y - 4)
    goalLbl:SetText("Gold Goal |cffaaaaaa(e.g. 100g):|r")

    local goalBox = CreateFrame("EditBox", "FarmTrackerGoalBox", pDisp, "InputBoxTemplate")
    goalBox:SetSize(96, 20)
    goalBox:SetPoint("TOPRIGHT", 0, y)
    goalBox:SetAutoFocus(false)
    goalBox:SetJustifyH("CENTER")
    goalBox:SetScript("OnEnterPressed", function(self)
        ns.db.sessionGoalCopper = ParseThresholdInput(self:GetText(), ns.db.sessionGoalCopper)
        self:SetText(FormatThresholdText(ns.db.sessionGoalCopper))
        self:ClearFocus()
        NotifyRefresh()
    end)
    goalBox:SetScript("OnEscapePressed", function(self)
        self:SetText(FormatThresholdText(ns.db.sessionGoalCopper))
        self:ClearFocus()
    end)
    goalBox:SetScript("OnEditFocusLost", function(self)
        ns.db.sessionGoalCopper = ParseThresholdInput(self:GetText(), ns.db.sessionGoalCopper)
        self:SetText(FormatThresholdText(ns.db.sessionGoalCopper))
        NotifyRefresh()
    end)
    f.goalBox = goalBox
    y = y - 26

    y = AddDivider(pDisp, y)
    _, y = AddHeader(pDisp, "|cff00ccffDungeon Mode Stats|r", y)
    y = AddCheckbox(pDisp, "showTotalRuns",      "Show Total Runs", y)
    y = AddCheckbox(pDisp, "showRunsPerHour",    "Show Runs / Hour", y)
    y = AddCheckbox(pDisp, "showFastestRun",     "Show Fastest Run", y)
    y = AddCheckbox(pDisp, "showLockoutWarning", "Show Instance Lockout Warning (5/hr)", y)

    -- =========================================================================
    -- TAB 3: LOOT & AH
    -- =========================================================================
    local pLoot = f.panels.loot
    y = -4

    local priceLbl = pLoot:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    priceLbl:SetPoint("TOPLEFT", 0, y - 4)
    priceLbl:SetText("AH Price Source:")

    local priceBtn = CreateFrame("Button", nil, pLoot, "UIPanelButtonTemplate")
    priceBtn:SetSize(155, 22)
    priceBtn:SetPoint("TOPRIGHT", 0, y)
    priceBtn:SetScript("OnClick", function(self) TogglePriceDropdown(self) end)
    priceBtn:SetText("Auto (TSM / Auc)  v")
    ClampButtonText(priceBtn)
    f.priceBtn = priceBtn
    y = y - 30

    y = AddDivider(pLoot, y)
    _, y = AddHeader(pLoot, "|cff00ccffHigh-Value Drop Alert|r", y)
    y = AddCheckbox(pLoot, "dropAlertEnabled", "Enable High-Value Drop Alert", y)
    y = AddCheckbox(pLoot, "dropAlertMuted",   "Mute Alert Sound |cffaaaaaa(Flash Banner Only)|r", y)

    local threshLbl = pLoot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    threshLbl:SetPoint("TOPLEFT", 4, y - 4)
    threshLbl:SetText("Threshold |cffaaaaaa(0c = all)|r:")

    local testAlertBtn = CreateFrame("Button", nil, pLoot, "UIPanelButtonTemplate")
    testAlertBtn:SetSize(48, 20)
    testAlertBtn:SetPoint("TOPRIGHT", 0, y)
    testAlertBtn:SetNormalFontObject("GameFontHighlightSmall")
    testAlertBtn:SetText("Test")
    testAlertBtn:SetScript("OnClick", function()
        local trackerMod = ns.Modules["Tracker"]
        if trackerMod and trackerMod.TestDropAlert then
            trackerMod:TestDropAlert()
        end
    end)

    local threshBox = CreateFrame("EditBox", "FarmTrackerAlertThresholdBox", pLoot, "InputBoxTemplate")
    threshBox:SetSize(82, 20)
    threshBox:SetPoint("RIGHT", testAlertBtn, "LEFT", -8, 0)
    threshBox:SetAutoFocus(false)
    threshBox:SetJustifyH("CENTER")
    threshBox:SetScript("OnEnterPressed", function(self)
        ns.db.dropAlertThreshold = ParseThresholdInput(self:GetText(), ns.db.dropAlertThreshold)
        self:SetText(FormatThresholdText(ns.db.dropAlertThreshold))
        self:ClearFocus()
    end)
    threshBox:SetScript("OnEscapePressed", function(self)
        self:SetText(FormatThresholdText(ns.db.dropAlertThreshold))
        self:ClearFocus()
    end)
    threshBox:SetScript("OnEditFocusLost", function(self)
        ns.db.dropAlertThreshold = ParseThresholdInput(self:GetText(), ns.db.dropAlertThreshold)
        self:SetText(FormatThresholdText(ns.db.dropAlertThreshold))
    end)
    f.threshBox = threshBox
    y = y - 24

    local soundLbl = pLoot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    soundLbl:SetPoint("TOPLEFT", 4, y - 4)
    soundLbl:SetText("Alert Sound:")

    local soundBtn = CreateFrame("Button", nil, pLoot, "UIPanelButtonTemplate")
    soundBtn:SetSize(155, 20)
    soundBtn:SetPoint("TOPRIGHT", 0, y)
    soundBtn:SetNormalFontObject("GameFontHighlightSmall")
    soundBtn:SetScript("OnClick", function(self) ToggleSoundDropdown(self) end)
    soundBtn:SetText("Loot Coins  v")
    ClampButtonText(soundBtn)
    f.soundBtn = soundBtn
    y = y - 26

    y = AddDivider(pLoot, y)

    local blHeader, nextY = AddHeader(pLoot, "|cff00ccffGlobal Blocklist|r |cffaaaaaa(0)|r", y)
    f.blHeader = blHeader

    local clearBlBtn = CreateFrame("Button", nil, pLoot, "UIPanelButtonTemplate")
    clearBlBtn:SetSize(74, 18)
    clearBlBtn:SetPoint("TOPRIGHT", 0, y + 2)
    clearBlBtn:SetNormalFontObject("GameFontHighlightSmall")
    clearBlBtn:SetText("|cffff6666Clear All|r")
    clearBlBtn:SetScript("OnClick", function()
        wipe(ns.db.globalBlacklist)
        RefreshBlacklistUI()
        ns:Print("Global loot blocklist cleared.")
        NotifyRefresh()
    end)
    y = nextY - 2

    local blBox = CreateFrame("Frame", nil, pLoot, "BackdropTemplate")
    blBox:SetPoint("TOPLEFT", 0, y)
    blBox:SetPoint("BOTTOMRIGHT", 0, 4)
    blBox:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile     = false,
        edgeSize = 1,
    })
    blBox:SetBackdropColor(0, 0, 0, 0.35)
    blBox:SetBackdropBorderColor(0.25, 0.25, 0.3, 0.8)

    local blScroll = CreateFrame("ScrollFrame", "FarmTrackerBlacklistScroll", blBox, "UIPanelScrollFrameTemplate")
    blScroll:SetPoint("TOPLEFT", 4, -4)
    blScroll:SetPoint("BOTTOMRIGHT", -24, 4)

    local blScrollChild = CreateFrame("Frame", nil, blScroll)
    blScrollChild:SetWidth(286)
    blScrollChild:SetHeight(1)
    blScroll:SetScrollChild(blScrollChild)
    f.blScrollChild = blScrollChild

    local blEmpty = blBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    blEmpty:SetPoint("CENTER", 0, 0)
    blEmpty:SetText("Right-click any item in the Loot Window to blacklist it.")
    f.blEmpty = blEmpty

    -- =========================================================================
    -- TAB 4: AUTOMATION
    -- =========================================================================
    local pAuto = f.panels.auto
    y = -2

    _, y = AddHeader(pAuto, "|cff00ccffTimer Automation|r", y)
    y = AddCheckbox(pAuto, "timerAutoStart",   "Auto-Start Timer on Dungeon Entry", y)
    y = AddCheckbox(pAuto, "autoPauseAFK",     "Auto-Pause When Flagged AFK", y)
    y = AddCheckbox(pAuto, "autoPauseCity",    "Auto-Pause in Cities / Rested Areas", y)
    y = AddCheckbox(pAuto, "autoResume",       "Auto-Resume When Leaving AFK / City", y)
    y = AddCheckbox(pAuto, "autoResumeCombat", "Auto-Resume on Entering Combat", y)

    -- Close Button
    local doneBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    doneBtn:SetSize(100, 22)
    doneBtn:SetPoint("BOTTOM", 0, 12)
    doneBtn:SetText("Close")
    doneBtn:SetScript("OnClick", function() f:Hide() end)

    f:Hide()
    optFrame = f
    ns.Utils.ApplyBackdropTheme(f, false, false)
    SelectTab("appearance")
    return f
end

function mod:SyncFontSize(px)
    if not optFrame or not optFrame:IsShown() then return end
    optFrame:SetSyncing(true)
    optFrame.slider:SetValue(px)
    optFrame.sizeValLbl:SetText(px .. "px")
    optFrame:SetSyncing(false)
end

function mod:SyncLockState()
    if not optFrame or not optFrame:IsShown() then return end
    if optFrame.checks and optFrame.checks["timerLocked"] then
        optFrame.checks["timerLocked"]:SetChecked(ns.db.timerLocked == true)
    end
end

function mod:SyncBlacklistCount()
    if not optFrame or not optFrame:IsShown() then return end
    RefreshBlacklistUI()
end

function mod:ToggleUI()
    local f = CreateOptionsUI()
    if f:IsShown() then
        f:Hide()
    else
        ns.Utils.ApplyBackdropTheme(f, false, false)
        f.themeBtn:SetText(ns.db.timerTheme == "classic" and "WoW Forever" or "Dark Modern")
        f.fontBtn:SetText((ns.db.timerFont or "Friz Quadrata") .. "  v")
        f.priceBtn:SetText(GetPriceSourceLabel(ns.db.ahPriceSource or "AUTO") .. "  v")
        f.soundBtn:SetText(GetAlertSoundLabel(ns.db.dropAlertSound or "COIN") .. "  v")
        f.threshBox:SetText(FormatThresholdText(ns.db.dropAlertThreshold))
        f.goalBox:SetText(FormatThresholdText(ns.db.sessionGoalCopper))

        local px = tonumber(ns.db.timerFontSize) or 11
        if px < 8 then px = 8 elseif px > 64 then px = 64 end
        local pct = math.floor(((tonumber(ns.db.timerBgAlpha) or 0.92) * 100) + 0.5)
        if pct < 10 then pct = 10 elseif pct > 100 then pct = 100 end

        f:SetSyncing(true)
        f.slider:SetValue(px)
        f.sizeValLbl:SetText(px .. "px")
        f.opSlider:SetValue(pct)
        f.opValLbl:SetText(pct .. "%")
        f:SetSyncing(false)

        for key, cb in pairs(f.checks) do
            cb:SetChecked(ns.db[key] == true)
        end

        RefreshBlacklistUI()
        f:Show()
    end
end

function mod:OnInit()
    -- Created lazily on first open
end