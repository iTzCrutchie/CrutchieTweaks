local _, ns = ...

local mod = ns:RegisterModule("Options", {})
local optFrame = nil
local fontDropdown = nil

local function GetAvailableFonts()
    local fonts = {
        { name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
        { name = "Arial Narrow",  path = "Fonts\\ARIALN.TTF" },
        { name = "Morpheus",      path = "Fonts\\MORPHEUS.TTF" },
        { name = "Skurri",        path = "Fonts\\skurri.ttf" },
    }

    local lsm = _G.LibStub and _G.LibStub("LibSharedMedia-3.0", true)
    if lsm and lsm.Fetch then
        local expPath = lsm:Fetch("font", "Expressway", true)
        if expPath then
            table.insert(fonts, { name = "Expressway", path = expPath })
        end
    end

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

    local timerMod = ns.Modules["FarmTimer"]
    if timerMod and timerMod.RefreshSettings then
        timerMod:RefreshSettings()
    end
    local miniMod = ns.Modules["MinimapButton"]
    if miniMod and miniMod.Refresh then
        miniMod:Refresh()
    end
end

local function ToggleFontDropdown(anchorBtn)
    local fonts = GetAvailableFonts()

    if not fontDropdown then
        local dd = CreateFrame("Frame", "FarmTrackerFontDropdown", optFrame, "BackdropTemplate")
        dd:SetWidth(140)
        dd:SetFrameStrata("TOOLTIP")
        dd:SetClampedToScreen(true)
        dd.buttons = {}
        dd:Hide()
        fontDropdown = dd
    end

    if fontDropdown:IsShown() then
        fontDropdown:Hide()
        return
    end

    ApplyOptionsTheme(fontDropdown)
    fontDropdown:SetHeight((#fonts * 22) + 12)

    for i, fontInfo in ipairs(fonts) do
        local btn = fontDropdown.buttons[i]
        if not btn then
            btn = CreateFrame("Button", nil, fontDropdown)
            btn:SetHeight(20)
            btn:SetPoint("LEFT", 6, 0)
            btn:SetPoint("RIGHT", -6, 0)

            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(0.2, 0.5, 0.8, 0.3)

            local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            txt:SetPoint("LEFT", 4, 0)
            btn.txt = txt

            fontDropdown.buttons[i] = btn
        end

        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", 6, -6 - ((i - 1) * 22))
        btn:SetPoint("TOPRIGHT", -6, -6 - ((i - 1) * 22))
        btn.txt:SetFont(fontInfo.path, 11, "")
        btn.txt:SetText(fontInfo.name)

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

local function CreateOptionsUI()
    if optFrame then return optFrame end

    local f = CreateFrame("Frame", "FarmTrackerOptionsFrame", UIParent, "BackdropTemplate")
    f:SetSize(316, 444)
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
    end)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText("|cff00ccffFarm Tracker|r Settings")

    local closeBtn = CreateFrame("Button", nil, f)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("TOPRIGHT", -8, -8)
    closeBtn:SetNormalFontObject("GameFontNormal")
    closeBtn:SetText("|cffff5555X|r")
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local div1 = f:CreateTexture(nil, "ARTWORK")
    div1:SetColorTexture(0.25, 0.25, 0.3, 0.8)
    div1:SetSize(288, 1)
    div1:SetPoint("TOP", 0, -34)

    -- 1. Theme Selector
    local themeLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeLbl:SetPoint("TOPLEFT", 14, -44)
    themeLbl:SetText("UI Theme:")

    local themeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    themeBtn:SetSize(140, 22)
    themeBtn:SetPoint("TOPRIGHT", -14, -40)
    themeBtn:SetScript("OnClick", function(self)
        ns.db.timerTheme = (ns.db.timerTheme == "classic") and "dark" or "classic"
        self:SetText(ns.db.timerTheme == "classic" and "WoW Forever" or "Dark Modern")
        NotifyRefresh()
    end)
    f.themeBtn = themeBtn

    -- 2. Font Dropdown Selector
    local fontLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontLbl:SetPoint("TOPLEFT", 14, -74)
    fontLbl:SetText("Font Family:")

    local fontBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    fontBtn:SetSize(140, 22)
    fontBtn:SetPoint("TOPRIGHT", -14, -70)
    fontBtn:SetScript("OnClick", function(self)
        ToggleFontDropdown(self)
    end)
    f.fontBtn = fontBtn

    -- 3. Font Size Slider (8 - 64 px)
    local sizeLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sizeLbl:SetPoint("TOPLEFT", 14, -104)
    sizeLbl:SetText("Font Size:")

    local sizeValLbl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sizeValLbl:SetPoint("TOPRIGHT", -14, -104)
    sizeValLbl:SetText("11px")
    f.sizeValLbl = sizeValLbl

    local slider = CreateFrame("Slider", "FarmTrackerFontSizeSlider", f, "OptionsSliderTemplate")
    slider:SetWidth(280)
    slider:SetHeight(16)
    slider:SetPoint("TOP", 0, -122)
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

    local div2 = f:CreateTexture(nil, "ARTWORK")
    div2:SetColorTexture(0.25, 0.25, 0.3, 0.8)
    div2:SetSize(288, 1)
    div2:SetPoint("TOP", 0, -152)

    f.checks = {}
    local function AddCheckbox(key, label, yOffset, onToggle)
        local cb = CreateFrame("CheckButton", "FarmTrackerOptCheck_" .. key, f, "UICheckButtonTemplate")
        cb:SetSize(22, 22)
        cb:SetPoint("TOPLEFT", 14, yOffset)
        cb:SetScript("OnClick", function(self)
            ns.db[key] = self:GetChecked() and true or false
            if onToggle then onToggle(ns.db[key]) end
            NotifyRefresh()
        end)

        local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        lbl:SetText(label)

        f.checks[key] = cb
        return cb
    end

    -- General Section
    local genHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    genHeader:SetPoint("TOPLEFT", 14, -160)
    genHeader:SetText("|cff00ccffGeneral Display|r")

    AddCheckbox("timerMinimap",  "Show Minimap Button", -178)
    AddCheckbox("timerLocked",   "Lock Window Position & Size", -202)
    AddCheckbox("showTotalGold", "Show Total Session Value", -226)

    local div3 = f:CreateTexture(nil, "ARTWORK")
    div3:SetColorTexture(0.25, 0.25, 0.3, 0.8)
    div3:SetSize(288, 1)
    div3:SetPoint("TOP", 0, -256)

    -- Dungeon Mode Section
    local dungHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dungHeader:SetPoint("TOPLEFT", 14, -264)
    dungHeader:SetText("|cff00ccffDungeon Mode Options|r")

    AddCheckbox("timerAutoStart",     "Auto-Start Timer on Dungeon Entry", -282)
    AddCheckbox("showTotalRuns",      "Show Total Runs", -306)
    AddCheckbox("showRunsPerHour",    "Show Runs / Hour", -330)
    AddCheckbox("showFastestRun",     "Show Fastest Run", -354)
    AddCheckbox("showLockoutWarning", "Show Instance Lockout Warning (5/hr)", -378)

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

function mod:ToggleUI()
    local f = CreateOptionsUI()
    if f:IsShown() then
        f:Hide()
    else
        ApplyOptionsTheme(f)
        f.themeBtn:SetText(ns.db.timerTheme == "classic" and "WoW Forever" or "Dark Modern")
        f.fontBtn:SetText((ns.db.timerFont or "Friz Quadrata") .. "  v")

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