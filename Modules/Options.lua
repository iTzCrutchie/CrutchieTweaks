local _, ns = ...

local mod = ns:RegisterModule("Options", {})

local optFrame      = nil
local tabPanels     = {}
local tabButtons    = {}
local activeTab     = "APPEARANCE"
local controls      = {}
local fontMenuFrame = nil
local profileMenu   = nil

local TABS = {
    { key = "APPEARANCE", label = "Appearance" },
    { key = "DISPLAY",    label = "Display" },
    { key = "LOOT_AH",    label = "Loot & AH" },
    { key = "AUTOMATION", label = "Automation" },
}

local AH_SOURCES = {
    { key = "AUTO",        label = "Auto (TSM / Auc)" },
    { key = "TSM_MIN",     label = "TSM: Min Buyout" },
    { key = "TSM_MARKET",  label = "TSM: Market" },
    { key = "TSM_HIST",    label = "TSM: Historical" },
    { key = "AUCTIONATOR", label = "Auctionator" },
    { key = "VENDOR",      label = "Vendor Only" },
}

local ALERT_SOUNDS = {
    { key = "RAID_WARNING", label = "Raid Warning" },
    { key = "LEVEL_UP",     label = "Level Up" },
    { key = "QUEST_DONE",   label = "Quest Complete" },
    { key = "BELL",         label = "Auction Bell" },
    { key = "NONE",         label = "Silent (Flash Only)" },
}

local function NotifyRefresh()
    if ns.Profiles and ns.Profiles.SyncCurrentProfileFromDB then
        ns.Profiles.SyncCurrentProfileFromDB()
    end
    if ns.Tracker and ns.Tracker.RefreshSettings then
        ns.Tracker:RefreshSettings()
    end
    if ns.MinimapButton and ns.MinimapButton.Refresh then
        ns.MinimapButton:Refresh()
    end
    local histMod = ns.Modules["History"]
    if histMod and histMod.RefreshTheme then
        histMod:RefreshTheme()
    end
    local ffMod = ns.Modules["FarmFinder"]
    if ffMod then
        if ffMod.RefreshTheme then ffMod:RefreshTheme() end
        if ffMod.RefreshList then ffMod:RefreshList() end
    end
end

local function SetActiveTab(tabKey)
    activeTab = tabKey
    for key, panel in pairs(tabPanels) do
        if key == tabKey then
            panel:Show()
        else
            panel:Hide()
        end
    end
    for _, btn in ipairs(tabButtons) do
        if btn.tabKey == tabKey then
            btn:SetText("|cff00ccff" .. btn.tabLabel .. "|r")
            btn:Disable()
        else
            btn:SetText("|cffcccccc" .. btn.tabLabel .. "|r")
            btn:Enable()
        end
    end
end

local function RefreshProfileBar()
    if not optFrame or not optFrame.profileBar then return end
    local bar = optFrame.profileBar
    local activeName = (ns.Profiles and ns.Profiles.GetActiveProfileName()) or "Default"
    local charKey = (ns.Profiles and ns.Utils.GetCharacterKey()) or (UnitName("player") or "")

    bar.charTxt:SetText("|cffaaaaaaCharacter:|r |cffffffff" .. charKey .. "|r")
    bar.selectBtn:SetText("|cff00ccff" .. activeName .. "|r")

    if bar.delBtn then
        if activeName == "Default" then
            bar.delBtn:Disable()
        else
            bar.delBtn:Enable()
        end
    end
end

local function ToggleProfileMenu(anchorBtn)
    if not profileMenu then
        local m = CreateFrame("Frame", "FarmTrackerProfileSelectMenu", UIParent, "BackdropTemplate")
        m:SetSize(180, 160)
        m:SetFrameStrata("FULLSCREEN_DIALOG")
        m:SetClampedToScreen(true)
        ns.Utils.ApplyBackdropTheme(m, false, false)

        local sf = CreateFrame("ScrollFrame", "FarmTrackerProfileSelectScroll", m, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 6, -6)
        sf:SetPoint("BOTTOMRIGHT", -24, 6)

        local sc = CreateFrame("Frame", nil, sf)
        sc:SetWidth(148)
        sc:SetHeight(1)
        sf:SetScrollChild(sc)
        m.scrollChild = sc
        m.rows = {}

        m:Hide()
        profileMenu = m
    end

    if profileMenu:IsShown() then
        profileMenu:Hide()
        return
    end

    ns.Utils.ApplyBackdropTheme(profileMenu, false, false)
    local names = (ns.Profiles and ns.Profiles.GetProfileNames()) or { "Default" }
    local activeName = (ns.Profiles and ns.Profiles.GetActiveProfileName()) or "Default"
    local rowH = 20

    for i, name in ipairs(names) do
        local btn = profileMenu.rows[i]
        if not btn then
            btn = CreateFrame("Button", nil, profileMenu.scrollChild)
            btn:SetHeight(rowH)
            btn:SetNormalFontObject("GameFontHighlightSmall")
            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(0.2, 0.5, 0.8, 0.25)
            profileMenu.rows[i] = btn
        end
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", 0, -((i - 1) * rowH))
        btn:SetPoint("TOPRIGHT", 0, -((i - 1) * rowH))
        btn:SetText((name == activeName) and ("|cff00ff00" .. name .. "|r") or name)
        btn:SetScript("OnClick", function()
            if ns.Profiles and ns.Profiles.ApplyProfile then
                ns.Profiles.ApplyProfile(name)
                ns.Profiles.NotifyAllUI()
            end
            profileMenu:Hide()
        end)
        btn:Show()
    end

    for i = #names + 1, #profileMenu.rows do
        profileMenu.rows[i]:Hide()
    end

    profileMenu.scrollChild:SetHeight(math.max(#names * rowH, 1))
    profileMenu:ClearAllPoints()
    profileMenu:SetPoint("TOPLEFT", anchorBtn, "BOTTOMLEFT", 0, -2)
    profileMenu:Show()
end

local function CreateOptionsUI()
    if optFrame then return optFrame end

    local f = CreateFrame("Frame", "FarmTrackerOptionsFrame", UIParent, "BackdropTemplate")
    tinsert(UISpecialFrames, "FarmTrackerOptionsFrame")
    f:SetSize(366, 466)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText("|cff00ccffFarm Tracker|r Settings")

    local closeBtn = CreateFrame("Button", nil, f)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("TOPRIGHT", -8, -8)
    closeBtn:SetNormalFontObject("GameFontNormal")
    closeBtn:SetText("|cffff5555X|r")
    closeBtn:SetScript("OnClick", function()
        if fontMenuFrame then fontMenuFrame:Hide() end
        if profileMenu then profileMenu:Hide() end
        f:Hide()
    end)

    -- Profile Selector & Creation Bar
    local pBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    pBar:SetPoint("TOPLEFT", 12, -34)
    pBar:SetPoint("TOPRIGHT", -12, -34)
    pBar:SetHeight(64)
    pBar:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile     = false,
        edgeSize = 1,
    })
    pBar:SetBackdropColor(0.08, 0.08, 0.11, 0.85)
    pBar:SetBackdropBorderColor(0.25, 0.25, 0.32, 1)
    f.profileBar = pBar

    local charTxt = pBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    charTxt:SetPoint("TOPLEFT", 8, -7)
    pBar.charTxt = charTxt

    local profLbl = pBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    profLbl:SetPoint("TOPLEFT", 8, -24)
    profLbl:SetText("Profile:")

    local selectBtn = CreateFrame("Button", nil, pBar, "UIPanelButtonTemplate")
    selectBtn:SetSize(134, 20)
    selectBtn:SetPoint("LEFT", profLbl, "RIGHT", 6, 0)
    selectBtn:SetNormalFontObject("GameFontHighlightSmall")
    selectBtn:SetScript("OnClick", function(self) ToggleProfileMenu(self) end)
    pBar.selectBtn = selectBtn

    local delBtn = CreateFrame("Button", nil, pBar, "UIPanelButtonTemplate")
    delBtn:SetSize(64, 20)
    delBtn:SetPoint("TOPRIGHT", -8, -22)
    delBtn:SetNormalFontObject("GameFontHighlightSmall")
    delBtn:SetText("|cffff6666Delete|r")
    delBtn:SetScript("OnClick", function()
        local cur = ns.Profiles and ns.Profiles.GetActiveProfileName()
        local ok, err = ns.Profiles.DeleteProfile(cur)
        if not ok then
            ns:Print(ns.Colors.red .. tostring(err) .. ns.Colors.reset)
            return
        end
        ns:Print("Deleted profile |cffffaa00" .. tostring(cur) .. "|r; reverted to Default.")
        ns.Profiles.NotifyAllUI()
    end)
    pBar.delBtn = delBtn

    local newBox = CreateFrame("EditBox", "FarmTrackerNewProfileBox", pBar, "InputBoxTemplate")
    newBox:SetSize(156, 18)
    newBox:SetPoint("TOPLEFT", 12, -44)
    newBox:SetAutoFocus(false)
    newBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    pBar.newBox = newBox

    local createBtn = CreateFrame("Button", nil, pBar, "UIPanelButtonTemplate")
    createBtn:SetSize(102, 20)
    createBtn:SetPoint("LEFT", newBox, "RIGHT", 6, 0)
    createBtn:SetNormalFontObject("GameFontHighlightSmall")
    createBtn:SetText("|cff00ff00New Profile|r")
    createBtn:SetScript("OnClick", function()
        local created, err = ns.Profiles.CreateProfile(newBox:GetText(), true)
        if not created then
            ns:Print(ns.Colors.red .. tostring(err) .. ns.Colors.reset)
            return
        end
        newBox:SetText("")
        newBox:ClearFocus()
        ns:Print("Created & applied profile: |cff00ccff" .. created .. "|r.")
        ns.Profiles.NotifyAllUI()
    end)
    pBar.createBtn = createBtn

    -- 4 Category Tabs
    for i, tInfo in ipairs(TABS) do
        local tb = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        tb:SetSize(82, 22)
        tb:SetPoint("TOPLEFT", 14 + ((i - 1) * 85), -104)
        tb:SetNormalFontObject("GameFontHighlightSmall")
        tb:SetDisabledFontObject("GameFontHighlightSmall")
        tb.tabKey   = tInfo.key
        tb.tabLabel = tInfo.label
        tb:SetScript("OnClick", function() SetActiveTab(tInfo.key) end)
        table.insert(tabButtons, tb)

        local panel = CreateFrame("Frame", nil, f)
        panel:SetPoint("TOPLEFT", 12, -132)
        panel:SetPoint("BOTTOMRIGHT", -12, 42)
        panel:Hide()
        tabPanels[tInfo.key] = panel
    end

    -- TAB 1: APPEARANCE
    local app = tabPanels["APPEARANCE"]

    local themeLbl = app:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    themeLbl:SetPoint("TOPLEFT", 6, -8)
    themeLbl:SetText("Theme:")

    local darkBtn = CreateFrame("Button", nil, app, "UIPanelButtonTemplate")
    darkBtn:SetSize(102, 20)
    darkBtn:SetPoint("TOPLEFT", 6, -26)
    darkBtn:SetNormalFontObject("GameFontHighlightSmall")
    darkBtn:SetScript("OnClick", function()
        ns.db.timerTheme = "dark"
        NotifyRefresh()
        mod:RefreshUI()
    end)

    local classicBtn = CreateFrame("Button", nil, app, "UIPanelButtonTemplate")
    classicBtn:SetSize(102, 20)
    classicBtn:SetPoint("LEFT", darkBtn, "RIGHT", 8, 0)
    classicBtn:SetNormalFontObject("GameFontHighlightSmall")
    classicBtn:SetScript("OnClick", function()
        ns.db.timerTheme = "classic"
        NotifyRefresh()
        mod:RefreshUI()
    end)
    controls.darkBtn = darkBtn
    controls.classicBtn = classicBtn

    local alphaSlider = CreateFrame("Slider", "FarmTrackerBgAlphaSlider", app, "OptionsSliderTemplate")
    alphaSlider:SetSize(316, 16)
    alphaSlider:SetPoint("TOPLEFT", 10, -64)
    alphaSlider:SetMinMaxValues(0.10, 1.00)
    alphaSlider:SetValueStep(0.05)
    alphaSlider:SetObeyStepOnDrag(true)
    alphaSlider:SetScript("OnValueChanged", function(self, val)
        val = math.floor((val * 20) + 0.5) / 20
        ns.db.timerBgAlpha = val
        if _G[self:GetName() .. "Text"] then
            _G[self:GetName() .. "Text"]:SetText(string.format("Background Opacity: %d%%", math.floor(val * 100 + 0.5)))
        end
        NotifyRefresh()
    end)
    if _G[alphaSlider:GetName() .. "Low"] then _G[alphaSlider:GetName() .. "Low"]:SetText("10%") end
    if _G[alphaSlider:GetName() .. "High"] then _G[alphaSlider:GetName() .. "High"]:SetText("100%") end
    controls.alphaSlider = alphaSlider

    local fontLbl = app:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fontLbl:SetPoint("TOPLEFT", 6, -102)
    fontLbl:SetText("Font Family:")

    local fontBtn = CreateFrame("Button", nil, app, "UIPanelButtonTemplate")
    fontBtn:SetSize(220, 22)
    fontBtn:SetPoint("TOPLEFT", 6, -120)
    fontBtn:SetNormalFontObject("GameFontHighlightSmall")
    fontBtn:SetScript("OnClick", function(self)
        if not fontMenuFrame then
            local fm = CreateFrame("Frame", "FarmTrackerFontDropdown", UIParent, "BackdropTemplate")
            fm:SetSize(220, 180)
            fm:SetFrameStrata("FULLSCREEN_DIALOG")
            fm:SetClampedToScreen(true)
            ns.Utils.ApplyBackdropTheme(fm, false, false)

            local sf = CreateFrame("ScrollFrame", "FarmTrackerFontScroll", fm, "UIPanelScrollFrameTemplate")
            sf:SetPoint("TOPLEFT", 6, -6)
            sf:SetPoint("BOTTOMRIGHT", -24, 6)

            local sc = CreateFrame("Frame", nil, sf)
            sc:SetWidth(188)
            sc:SetHeight(1)
            sf:SetScrollChild(sc)
            fm.scrollChild = sc
            fm.rows = {}
            fm:Hide()
            fontMenuFrame = fm
        end

        if fontMenuFrame:IsShown() then
            fontMenuFrame:Hide()
            return
        end

        ns.Utils.ApplyBackdropTheme(fontMenuFrame, false, false)
        local list = ns.Utils.GetAvailableFonts()
        local rowH = 20
        for i, fInfo in ipairs(list) do
            local rb = fontMenuFrame.rows[i]
            if not rb then
                rb = CreateFrame("Button", nil, fontMenuFrame.scrollChild)
                rb:SetHeight(rowH)
                rb:SetNormalFontObject("GameFontHighlightSmall")
                local hl = rb:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints()
                hl:SetColorTexture(0.2, 0.5, 0.8, 0.25)
                fontMenuFrame.rows[i] = rb
            end
            rb:ClearAllPoints()
            rb:SetPoint("TOPLEFT", 0, -((i - 1) * rowH))
            rb:SetPoint("TOPRIGHT", 0, -((i - 1) * rowH))
            rb:SetText(fInfo.name)
            rb:SetScript("OnClick", function()
                ns.db.timerFont = fInfo.name
                fontBtn:SetText(fInfo.name)
                fontMenuFrame:Hide()
                NotifyRefresh()
            end)
            rb:Show()
        end
        for i = #list + 1, #fontMenuFrame.rows do
            fontMenuFrame.rows[i]:Hide()
        end
        fontMenuFrame.scrollChild:SetHeight(math.max(#list * rowH, 1))
        fontMenuFrame:ClearAllPoints()
        fontMenuFrame:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        fontMenuFrame:Show()
    end)
    controls.fontBtn = fontBtn

    local sizeSlider = CreateFrame("Slider", "FarmTrackerFontSizeSlider", app, "OptionsSliderTemplate")
    sizeSlider:SetSize(316, 16)
    sizeSlider:SetPoint("TOPLEFT", 10, -162)
    sizeSlider:SetMinMaxValues(8, 64)
    sizeSlider:SetValueStep(1)
    sizeSlider:SetObeyStepOnDrag(true)
    sizeSlider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val + 0.5)
        ns.db.timerFontSize = val
        if _G[self:GetName() .. "Text"] then
            _G[self:GetName() .. "Text"]:SetText(string.format("Window & Font Scale: %dpx", val))
        end
        NotifyRefresh()
    end)
    if _G[sizeSlider:GetName() .. "Low"] then _G[sizeSlider:GetName() .. "Low"]:SetText("8px") end
    if _G[sizeSlider:GetName() .. "High"] then _G[sizeSlider:GetName() .. "High"]:SetText("64px") end
    controls.sizeSlider = sizeSlider

    -- TAB 2: DISPLAY
    local disp = tabPanels["DISPLAY"]
    controls.checks = {}

    local function AddCheckbox(parent, key, label, x, y, onToggle)
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetSize(22, 22)
        cb:SetPoint("TOPLEFT", x, y)

        local txt = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        txt:SetText(label)

        cb:SetScript("OnClick", function(self)
            ns.db[key] = self:GetChecked() and true or false
            if onToggle then onToggle(ns.db[key]) end
            NotifyRefresh()
        end)

        controls.checks[key] = cb
        return cb
    end

    AddCheckbox(disp, "farmTimer",          "Enable Farm Tracker Module", 4, -4)
    AddCheckbox(disp, "timerMinimap",       "Show Minimap Button", 4, -26)
    AddCheckbox(disp, "timerLocked",        "Lock Window Position & Size", 4, -48)
    AddCheckbox(disp, "compactMode",        "Compact Mode", 4, -70)
    AddCheckbox(disp, "compactClickThru",   "Click-Through When Compact & Locked", 22, -92)
    AddCheckbox(disp, "showTotalGold",      "Show Net Session Profit Row", 4, -118)
    AddCheckbox(disp, "showTotalRuns",      "Show Total Runs Row (Dungeon)", 4, -140)
    AddCheckbox(disp, "showRunsPerHour",    "Show Runs / Hour Row (Dungeon)", 4, -162)
    AddCheckbox(disp, "showFastestRun",     "Show Fastest Run Row (Dungeon)", 4, -184)
    AddCheckbox(disp, "showLockoutWarning", "Show Hourly Lockout Status (Dungeon)", 4, -206)
    AddCheckbox(disp, "showXpPerHour",      "Show Session XP / Hr Row", 4, -228)
    AddCheckbox(disp, "showTimeToLevel",    "Show Time to Level Row", 4, -250)
    AddCheckbox(disp, "showBagSpace",       "Show Free Bag Slots Row", 4, -272)
    AddCheckbox(disp, "showGoalBar",        "Show Session Gold Goal Bar", 4, -294)

    -- TAB 3: LOOT & AH
    local lah = tabPanels["LOOT_AH"]

    local ahLbl = lah:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ahLbl:SetPoint("TOPLEFT", 6, -6)
    ahLbl:SetText("AH Price Source:")

    controls.ahBtns = {}
    for i, src in ipairs(AH_SOURCES) do
        local col = (i - 1) % 2
        local rowIdx = math.floor((i - 1) / 2)
        local b = CreateFrame("Button", nil, lah, "UIPanelButtonTemplate")
        b:SetSize(154, 20)
        b:SetPoint("TOPLEFT", 6 + (col * 160), -24 - (rowIdx * 24))
        b:SetNormalFontObject("GameFontHighlightSmall")
        b.srcKey = src.key
        b.srcLabel = src.label
        b:SetScript("OnClick", function()
            ns.db.ahPriceSource = src.key
            mod:RefreshUI()
            NotifyRefresh()
        end)
        table.insert(controls.ahBtns, b)
    end

    AddCheckbox(lah, "dropAlertEnabled", "Enable High-Value Drop Alerts", 4, -104)

    local threshSlider = CreateFrame("Slider", "FarmTrackerAlertThreshSlider", lah, "OptionsSliderTemplate")
    threshSlider:SetSize(316, 16)
    threshSlider:SetPoint("TOPLEFT", 10, -142)
    threshSlider:SetMinMaxValues(100, 500000)
    threshSlider:SetValueStep(100)
    threshSlider:SetObeyStepOnDrag(true)
    threshSlider:SetScript("OnValueChanged", function(self, val)
        val = math.floor((val / 100) + 0.5) * 100
        ns.db.dropAlertThreshold = val
        if _G[self:GetName() .. "Text"] then
            _G[self:GetName() .. "Text"]:SetText("Drop Alert Threshold: " .. ns.Utils.FormatMoneyPlain(val))
        end
        NotifyRefresh()
    end)
    if _G[threshSlider:GetName() .. "Low"] then _G[threshSlider:GetName() .. "Low"]:SetText("1s") end
    if _G[threshSlider:GetName() .. "High"] then _G[threshSlider:GetName() .. "High"]:SetText("50g") end
    controls.threshSlider = threshSlider

    local sndLbl = lah:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sndLbl:SetPoint("TOPLEFT", 6, -176)
    sndLbl:SetText("Alert Sound:")

    controls.sndBtns = {}
    for i, sInfo in ipairs(ALERT_SOUNDS) do
        local col = (i - 1) % 2
        local rowIdx = math.floor((i - 1) / 2)
        local b = CreateFrame("Button", nil, lah, "UIPanelButtonTemplate")
        b:SetSize(154, 20)
        b:SetPoint("TOPLEFT", 6 + (col * 160), -194 - (rowIdx * 23))
        b:SetNormalFontObject("GameFontHighlightSmall")
        b.sndKey = sInfo.key
        b.sndLabel = sInfo.label
        b:SetScript("OnClick", function()
            ns.db.dropAlertSound = sInfo.key
            mod:RefreshUI()
            NotifyRefresh()
        end)
        table.insert(controls.sndBtns, b)
    end

    local testAlertBtn = CreateFrame("Button", nil, lah, "UIPanelButtonTemplate")
    testAlertBtn:SetSize(120, 20)
    testAlertBtn:SetPoint("TOPLEFT", 6, -268)
    testAlertBtn:SetNormalFontObject("GameFontHighlightSmall")
    testAlertBtn:SetText("Test Alert")
    testAlertBtn:SetScript("OnClick", function()
        if ns.Tracker and ns.Tracker.TestDropAlert then
            ns.Tracker:TestDropAlert()
        end
    end)

    local clearBlkBtn = CreateFrame("Button", nil, lah, "UIPanelButtonTemplate")
    clearBlkBtn:SetSize(140, 20)
    clearBlkBtn:SetPoint("LEFT", testAlertBtn, "RIGHT", 8, 0)
    clearBlkBtn:SetNormalFontObject("GameFontHighlightSmall")
    clearBlkBtn:SetText("|cffff6666Clear Global Blocklist|r")
    clearBlkBtn:SetScript("OnClick", function()
        ns.db.globalBlacklist = {}
        if ns.Tracker and ns.Tracker.OnLootBlacklistChanged then
            ns.Tracker:OnLootBlacklistChanged()
        end
        NotifyRefresh()
    end)

    -- TAB 4: AUTOMATION
    local auto = tabPanels["AUTOMATION"]
    AddCheckbox(auto, "timerAutoStart",   "Auto-Start Timer When Entering a Dungeon", 4, -8)
    AddCheckbox(auto, "autoPauseAFK",     "Auto-Pause Timer When AFK", 4, -34)
    AddCheckbox(auto, "autoPauseCity",    "Auto-Pause Timer in Cities / Rested Areas", 4, -60)
    AddCheckbox(auto, "autoResume",       "Auto-Resume After AFK / Rested Auto-Pause", 4, -86)
    AddCheckbox(auto, "autoResumeCombat", "Auto-Resume on Entering Combat", 4, -112)

    local goalSlider = CreateFrame("Slider", "FarmTrackerGoalSlider", auto, "OptionsSliderTemplate")
    goalSlider:SetSize(316, 16)
    goalSlider:SetPoint("TOPLEFT", 10, -156)
    goalSlider:SetMinMaxValues(0, 5000000)
    goalSlider:SetValueStep(10000)
    goalSlider:SetObeyStepOnDrag(true)
    goalSlider:SetScript("OnValueChanged", function(self, val)
        val = math.floor((val / 10000) + 0.5) * 10000
        ns.db.sessionGoalCopper = val
        if _G[self:GetName() .. "Text"] then
            _G[self:GetName() .. "Text"]:SetText("Session Gold Goal: " .. (val > 0 and ns.Utils.FormatMoneyPlain(val) or "Disabled"))
        end
        NotifyRefresh()
    end)
    if _G[goalSlider:GetName() .. "Low"] then _G[goalSlider:GetName() .. "Low"]:SetText("Off") end
    if _G[goalSlider:GetName() .. "High"] then _G[goalSlider:GetName() .. "High"]:SetText("500g") end
    controls.goalSlider = goalSlider

    -- Bottom Buttons
    local reloadBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    reloadBtn:SetSize(96, 22)
    reloadBtn:SetPoint("BOTTOMLEFT", 14, 12)
    reloadBtn:SetText("/reload")
    reloadBtn:SetScript("OnClick", function() ReloadUI() end)

    local doneBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    doneBtn:SetSize(96, 22)
    doneBtn:SetPoint("BOTTOMRIGHT", -14, 12)
    doneBtn:SetText("Close")
    doneBtn:SetScript("OnClick", function()
        if fontMenuFrame then fontMenuFrame:Hide() end
        if profileMenu then profileMenu:Hide() end
        f:Hide()
    end)

    f:Hide()
    optFrame = f
    SetActiveTab(activeTab)
    mod:RefreshUI()
    return f
end

function mod:SyncLockState()
    if controls.checks and controls.checks.timerLocked then
        controls.checks.timerLocked:SetChecked(ns.db.timerLocked == true)
    end
end

function mod:SyncFontSize(newPx)
    if controls.sizeSlider then
        controls.sizeSlider:SetValue(newPx)
    end
end

function mod:RefreshUI()
    if not optFrame then return end
    ns.Utils.ApplyBackdropTheme(optFrame, false, false)
    RefreshProfileBar()

    local isClassic = (ns.db.timerTheme == "classic")
    controls.darkBtn:SetText((not isClassic) and "|cff00ccffDark Modern|r" or "Dark Modern")
    controls.classicBtn:SetText(isClassic and "|cff00ccffWoW Forever|r" or "WoW Forever")

    local alpha = tonumber(ns.db.timerBgAlpha) or 0.92
    controls.alphaSlider:SetValue(alpha)
    if _G[controls.alphaSlider:GetName() .. "Text"] then
        _G[controls.alphaSlider:GetName() .. "Text"]:SetText(string.format("Background Opacity: %d%%", math.floor(alpha * 100 + 0.5)))
    end

    local fSize = tonumber(ns.db.timerFontSize) or 11
    controls.sizeSlider:SetValue(fSize)
    if _G[controls.sizeSlider:GetName() .. "Text"] then
        _G[controls.sizeSlider:GetName() .. "Text"]:SetText(string.format("Window & Font Scale: %dpx", fSize))
    end

    controls.fontBtn:SetText(ns.db.timerFont or "Friz Quadrata TT")

    for key, cb in pairs(controls.checks or {}) do
        cb:SetChecked(ns.db[key] == true)
    end

    local curSrc = ns.db.ahPriceSource or "AUTO"
    for _, b in ipairs(controls.ahBtns or {}) do
        b:SetText((b.srcKey == curSrc) and ("|cff00ccff" .. b.srcLabel .. "|r") or b.srcLabel)
    end

    local thresh = tonumber(ns.db.dropAlertThreshold) or 20000
    controls.threshSlider:SetValue(thresh)
    if _G[controls.threshSlider:GetName() .. "Text"] then
        _G[controls.threshSlider:GetName() .. "Text"]:SetText("Drop Alert Threshold: " .. ns.Utils.FormatMoneyPlain(thresh))
    end

    local curSnd = ns.db.dropAlertSound or "RAID_WARNING"
    for _, b in ipairs(controls.sndBtns or {}) do
        b:SetText((b.sndKey == curSnd) and ("|cff00ccff" .. b.sndLabel .. "|r") or b.sndLabel)
    end

    local goalVal = tonumber(ns.db.sessionGoalCopper) or 1000000
    controls.goalSlider:SetValue(goalVal)
    if _G[controls.goalSlider:GetName() .. "Text"] then
        _G[controls.goalSlider:GetName() .. "Text"]:SetText("Session Gold Goal: " .. (goalVal > 0 and ns.Utils.FormatMoneyPlain(goalVal) or "Disabled"))
    end
end

function mod:ToggleUI()
    local f = CreateOptionsUI()
    if f:IsShown() then
        if fontMenuFrame then fontMenuFrame:Hide() end
        if profileMenu then profileMenu:Hide() end
        f:Hide()
    else
        self:RefreshUI()
        f:Show()
    end
end

function mod:OnInit()
    -- Created lazily on first open
end