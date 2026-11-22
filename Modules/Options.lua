local _, ns = ...

local mod = ns:RegisterModule("Options", {})
local optFrame      = nil
local fontDropdown  = nil
local priceDropdown = nil

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

local function ParseThresholdInput(text)
    if not text then return 0 end
    local clean = string.lower(strtrim(text))
    if clean == "" or clean == "0" or clean == "0c" then return 0 end

    local g = tonumber(string.match(clean, "(%d+%.?%d*)%s*g")) or 0
    local s = tonumber(string.match(clean, "(%d+)%s*s")) or 0
    local c = tonumber(string.match(clean, "(%d+)%s*c")) or 0

    if g > 0 or s > 0 or c > 0 then
        return math.floor((g * 10000) + (s * 100) + c + 0.5)
    end

    -- Plain number without units defaults to gold (e.g. "2.5" -> 2g 50s)
    local plain = tonumber(clean)
    if plain and plain >= 0 then
        return math.floor((plain * 10000) + 0.5)
    end
    return ns.db.dropAlertThreshold or 20000
end

local function CountBlacklist()
    local n = 0
    if type(ns.db.globalBlacklist) == "table" then
        for _ in pairs(ns.db.globalBlacklist) do n = n + 1 end
    end
    return n
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

local function ApplyOptionsTheme(frame)
    if not frame or not frame.SetBackdrop then return end
    if ns.db.timerTheme == "classic" then
        frame:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile     = true,
            tileSize = 32,
            edgeSize = 16,
            insets   = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        frame:SetBackdropColor(1, 1, 1, 0.96)
        frame:SetBackdropBorderColor(0.85, 0.75, 0.55, 1)
    else
        frame:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile     = false,
            edgeSize = 1,
        })
        frame:SetBackdropColor(0.06, 0.06, 0.09, 0.96)
        frame:SetBackdropBorderColor(0.25, 0.25, 0.32, 1)
    end
end

local function NotifyRefresh()
    ApplyOptionsTheme(optFrame)
    ApplyOptionsTheme(fontDropdown)
    ApplyOptionsTheme(priceDropdown)

    local timerMod = ns.Modules["FarmTimer"]
    if timerMod and timerMod.RefreshSettings then
        timerMod:RefreshSettings()
    end
    local miniMod = ns.Modules["MinimapButton"]
    if miniMod and miniMod.Refresh then
        miniMod:Refresh()
    end
    local histMod = ns.Modules["History"]
    if histMod and histMod.RefreshTheme then
        histMod:RefreshTheme()
    end
end

local function TogglePriceDropdown(anchorBtn)
    if fontDropdown then fontDropdown:Hide() end

    if not priceDropdown then
        local dd = CreateFrame("Frame", "FarmTrackerPriceDropdown", optFrame, "BackdropTemplate")
        dd:SetWidth(150)
        dd:SetFrameStrata("TOOLTIP")
        dd:SetClampedToScreen(true)
        dd.buttons = {}
        dd:Hide()
        priceDropdown = dd
    end

    if priceDropdown:IsShown() then
        priceDropdown:Hide()
        return
    end

    ApplyOptionsTheme(priceDropdown)
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

local function ToggleFontDropdown(anchorBtn)
    if priceDropdown then priceDropdown:Hide() end
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

    if fontDropdown:IsShown() then
        fontDropdown:Hide()
        return
    end

    ApplyOptionsTheme(fontDropdown)

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

local function CreateOptionsUI()
    if optFrame then return optFrame end

    local f = CreateFrame("Frame", "FarmTrackerOptionsFrame", UIParent, "BackdropTemplate")
    tinsert(UISpecialFrames, "FarmTrackerOptionsFrame")
    f:SetWidth(316)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)

    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetScript("OnHide", function()
        if fontDropdown then fontDropdown:Hide() end
        if priceDropdown then priceDropdown:Hide() end
    end)

    local y = -12
    f.checks = {}

    local function AddDivider()
        y = y - 6
        local div = f:CreateTexture(nil, "ARTWORK")
        div:SetColorTexture(0.25, 0.25, 0.3, 0.8)
        div:SetSize(288, 1)
        div:SetPoint("TOP", 0, y)
        y = y - 8
    end

    local function AddHeader(text)
        local hdr = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        hdr:SetPoint("TOPLEFT", 14, y)
        hdr:SetText(text)
        y = y - 18
    end

    local function AddCheckbox(key, label, onToggle)
        local cb = CreateFrame("CheckButton", "FarmTrackerOptCheck_" .. key, f, "UICheckButtonTemplate")
        cb:SetSize(22, 22)
        cb:SetPoint("TOPLEFT", 14, y)
        cb:SetScript("OnClick", function(self)
            ns.db[key] = self:GetChecked() and true or false
            if onToggle then onToggle(ns.db[key]) end
            NotifyRefresh()
        end)

        local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        lbl:SetText(label)

        f.checks[key] = cb
        y = y - 24
        return cb
    end

    -- Title Bar
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, y)
    title:SetText("|cff00ccffFarm Tracker|r Settings")

    local closeBtn = CreateFrame("Button", nil, f)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("TOPRIGHT", -8, -8)
    closeBtn:SetNormalFontObject("GameFontNormal")
    closeBtn:SetText("|cffff5555X|r")
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    y = y - 22
    AddDivider()

    -- 1. Theme Selector
    local themeLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeLbl:SetPoint("TOPLEFT", 14, y - 4)
    themeLbl:SetText("UI Theme:")

    local themeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    themeBtn:SetSize(140, 22)
    themeBtn:SetPoint("TOPRIGHT", -14, y)
    themeBtn:SetScript("OnClick", function(self)
        ns.db.timerTheme = (ns.db.timerTheme == "classic") and "dark" or "classic"
        self:SetText(ns.db.timerTheme == "classic" and "WoW Forever" or "Dark Modern")
        NotifyRefresh()
    end)
    f.themeBtn = themeBtn
    y = y - 28

    -- 2. Font Dropdown Selector
    local fontLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontLbl:SetPoint("TOPLEFT", 14, y - 4)
    fontLbl:SetText("Font Family:")

    local fontBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    fontBtn:SetSize(140, 22)
    fontBtn:SetPoint("TOPRIGHT", -14, y)
    fontBtn:SetScript("OnClick", function(self) ToggleFontDropdown(self) end)
    fontBtn:SetText("Friz Quadrata  v")
    ClampButtonText(fontBtn)
    f.fontBtn = fontBtn
    y = y - 28

    -- 3. AH Price Source Dropdown
    local priceLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    priceLbl:SetPoint("TOPLEFT", 14, y - 4)
    priceLbl:SetText("AH Price Source:")

    local priceBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    priceBtn:SetSize(140, 22)
    priceBtn:SetPoint("TOPRIGHT", -14, y)
    priceBtn:SetScript("OnClick", function(self) TogglePriceDropdown(self) end)
    priceBtn:SetText("Auto (TSM / Auc)  v")
    ClampButtonText(priceBtn)
    f.priceBtn = priceBtn
    y = y - 28

    -- 4. Font Size Slider (8 - 64 px)
    local sizeLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sizeLbl:SetPoint("TOPLEFT", 14, y)
    sizeLbl:SetText("Font Size:")

    local sizeValLbl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sizeValLbl:SetPoint("TOPRIGHT", -14, y)
    sizeValLbl:SetText("11px")
    f.sizeValLbl = sizeValLbl
    y = y - 18

    local slider = CreateFrame("Slider", "FarmTrackerFontSizeSlider", f, "OptionsSliderTemplate")
    slider:SetWidth(280)
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
    y = y - 24

    AddDivider()

    -- Loot & Drop Alerts Section
    AddHeader("|cff00ccffLoot & Drop Alerts|r")
    AddCheckbox("dropAlertEnabled", "Enable High-Value Drop Alert")

    local threshLbl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    threshLbl:SetPoint("TOPLEFT", 18, y - 4)
    threshLbl:SetText("Alert Threshold |cffaaaaaa(0c = all)|r:")

    local threshBox = CreateFrame("EditBox", "FarmTrackerAlertThresholdBox", f, "InputBoxTemplate")
    threshBox:SetSize(86, 20)
    threshBox:SetPoint("TOPRIGHT", -14, y)
    threshBox:SetAutoFocus(false)
    threshBox:SetJustifyH("CENTER")
    threshBox:SetScript("OnEnterPressed", function(self)
        ns.db.dropAlertThreshold = ParseThresholdInput(self:GetText())
        self:SetText(FormatThresholdText(ns.db.dropAlertThreshold))
        self:ClearFocus()
    end)
    threshBox:SetScript("OnEscapePressed", function(self)
        self:SetText(FormatThresholdText(ns.db.dropAlertThreshold))
        self:ClearFocus()
    end)
    threshBox:SetScript("OnEditFocusLost", function(self)
        ns.db.dropAlertThreshold = ParseThresholdInput(self:GetText())
        self:SetText(FormatThresholdText(ns.db.dropAlertThreshold))
    end)
    f.threshBox = threshBox
    y = y - 26

    local clearBlBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearBlBtn:SetSize(200, 20)
    clearBlBtn:SetPoint("TOPLEFT", 14, y)
    clearBlBtn:SetNormalFontObject("GameFontHighlightSmall")
    clearBlBtn:SetText("Clear Global Blocklist (0)")
    clearBlBtn:SetScript("OnClick", function(self)
        wipe(ns.db.globalBlacklist)
        self:SetText("Clear Global Blocklist (0)")
        ns:Print("Global loot blocklist cleared.")
        NotifyRefresh()
    end)
    f.clearBlBtn = clearBlBtn
    y = y - 24

    AddDivider()

    -- General Section
    AddHeader("|cff00ccffGeneral Display|r")
    AddCheckbox("timerMinimap",    "Show Minimap Button")
    AddCheckbox("timerLocked",     "Lock Window Position & Size")
    AddCheckbox("showTotalGold",   "Show Net Session Profit")
    AddCheckbox("showRepairCosts", "Show Repair Costs")
    AddCheckbox("showXpPerHour",   "Show XP / Hour |cffaaaaaa(hidden at 60)|r")
    AddCheckbox("showTimeToLevel", "Show Time to Level |cffaaaaaa(hidden at 60)|r")

    AddDivider()

    -- Dungeon Mode Section
    AddHeader("|cff00ccffDungeon Mode Options|r")
    AddCheckbox("timerAutoStart",     "Auto-Start Timer on Dungeon Entry")
    AddCheckbox("showTotalRuns",      "Show Total Runs")
    AddCheckbox("showRunsPerHour",    "Show Runs / Hour")
    AddCheckbox("showFastestRun",     "Show Fastest Run")
    AddCheckbox("showLockoutWarning", "Show Instance Lockout Warning (5/hr)")

    AddCheckbox("showBagSpace",    "Show Free Bag Slots")

    AddDivider()

    -- Automation & Session Goal Section
    AddHeader("|cff00ccffAutomation & Session Goal|r")
    AddCheckbox("autoPauseAFK",  "Auto-Pause When AFK")
    AddCheckbox("autoPauseCity", "Auto-Pause in Cities / Rested Areas")
    AddCheckbox("showGoalBar",   "Show Session Gold Goal Bar")

    local goalLbl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    goalLbl:SetPoint("TOPLEFT", 18, y - 4)
    goalLbl:SetText("Gold Goal |cffaaaaaa(e.g. 100g):|r")

    local goalBox = CreateFrame("EditBox", "FarmTrackerGoalBox", f, "InputBoxTemplate")
    goalBox:SetSize(86, 20)
    goalBox:SetPoint("TOPRIGHT", -14, y)
    goalBox:SetAutoFocus(false)
    goalBox:SetJustifyH("CENTER")
    goalBox:SetScript("OnEnterPressed", function(self)
        ns.db.sessionGoalCopper = ParseThresholdInput(self:GetText())
        self:SetText(FormatThresholdText(ns.db.sessionGoalCopper))
        self:ClearFocus()
        NotifyRefresh()
    end)
    goalBox:SetScript("OnEscapePressed", function(self)
        self:SetText(FormatThresholdText(ns.db.sessionGoalCopper))
        self:ClearFocus()
    end)
    goalBox:SetScript("OnEditFocusLost", function(self)
        ns.db.sessionGoalCopper = ParseThresholdInput(self:GetText())
        self:SetText(FormatThresholdText(ns.db.sessionGoalCopper))
        NotifyRefresh()
    end)
    f.goalBox = goalBox
    y = y - 26

    f:SetHeight(math.abs(y) + 46)

    local doneBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    doneBtn:SetSize(100, 22)
    doneBtn:SetPoint("BOTTOM", 0, 12)
    doneBtn:SetText("Close")
    doneBtn:SetScript("OnClick", function() f:Hide() end)

    f:Hide()
    optFrame = f
    ApplyOptionsTheme(f)
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
    if optFrame.clearBlBtn then
        optFrame.clearBlBtn:SetText("Clear Global Blocklist (" .. CountBlacklist() .. ")")
    end
end

function mod:ToggleUI()
    local f = CreateOptionsUI()
    if f:IsShown() then
        f:Hide()
    else
        ApplyOptionsTheme(f)
        f.themeBtn:SetText(ns.db.timerTheme == "classic" and "WoW Forever" or "Dark Modern")
        f.fontBtn:SetText((ns.db.timerFont or "Friz Quadrata") .. "  v")
        f.priceBtn:SetText(GetPriceSourceLabel(ns.db.ahPriceSource or "AUTO") .. "  v")
        f.threshBox:SetText(FormatThresholdText(ns.db.dropAlertThreshold))
        f.goalBox:SetText(FormatThresholdText(ns.db.sessionGoalCopper))
        f.clearBlBtn:SetText("Clear Global Blocklist (" .. CountBlacklist() .. ")")

        local px = tonumber(ns.db.timerFontSize) or 11
        if px < 8 then px = 8 elseif px > 64 then px = 64 end
        f:SetSyncing(true)
        f.slider:SetValue(px)
        f.sizeValLbl:SetText(px .. "px")
        f:SetSyncing(false)

        for key, cb in pairs(f.checks) do
            cb:SetChecked(ns.db[key] == true)
        end
        f:Show()
    end
end

function mod:OnInit()
    -- Options frame is created lazily on first open
end