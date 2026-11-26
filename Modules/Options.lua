local _, ns = ...

local mod = ns:RegisterModule("Options", {})

local optFrame      = nil
local tabPanels     = {}
local tabButtons    = {}
local activeTab     = "APPEARANCE"
local controls      = {}
local fontMenuFrame = nil
local texMenuFrame  = nil
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

local function FormatGoldInput(copper)
    copper = math.floor(copper or 0)
    if copper <= 0 then return "0g" end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    local parts = {}
    if g > 0 then table.insert(parts, g .. "g") end
    if s > 0 then table.insert(parts, s .. "s") end
    if c > 0 then table.insert(parts, c .. "c") end
    return table.concat(parts, " ")
end

local function ParseGoldInput(text, fallback)
    if not text then return fallback or 0 end
    local clean = string.lower(strtrim(text))
    if clean == "" or clean == "0" or clean == "0c" or clean == "0g" then return 0 end

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

local function HideDropdowns()
    if fontMenuFrame then fontMenuFrame:Hide() end
    if texMenuFrame then texMenuFrame:Hide() end
    if profileMenu then profileMenu:Hide() end
end

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
    HideDropdowns()
    activeTab = tabKey
    for key, panel in pairs(tabPanels) do
        if key == tabKey then
            panel.scrollFrame:Show()
            panel.scrollFrame:SetVerticalScroll(0)
        else
            panel.scrollFrame:Hide()
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
    local charKey = ns.Utils.GetCharacterKey()

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
    local wasShown = profileMenu and profileMenu:IsShown()
    HideDropdowns()
    if wasShown then return end

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

local function OpenGoalColorPicker()
    local c = ns.db.goalBarColor or { r = 0.0, g = 0.72, b = 0.95 }
    local prevR, prevG, prevB = c.r or 0.0, c.g or 0.72, c.b or 0.95

    local function ApplyColor(r, g, b)
        ns.db.goalBarColor = { r = r, g = g, b = b }
        if controls.goalColorSwatch then
            controls.goalColorSwatch.tex:SetColorTexture(r, g, b, 1)
        end
        NotifyRefresh()
    end

    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = prevR,
            g = prevG,
            b = prevB,
            hasOpacity = false,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                ApplyColor(r, g, b)
            end,
            cancelFunc = function()
                ApplyColor(prevR, prevG, prevB)
            end,
        })
    elseif ColorPickerFrame then
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = { prevR, prevG, prevB }
        ColorPickerFrame.func = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            ApplyColor(r, g, b)
        end
        ColorPickerFrame.cancelFunc = function(prev)
            if prev then ApplyColor(prev[1], prev[2], prev[3]) end
        end
        ColorPickerFrame:SetColorRGB(prevR, prevG, prevB)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end
end

local function ToggleTextureMenu(anchorBtn)
    local wasShown = texMenuFrame and texMenuFrame:IsShown()
    HideDropdowns()
    if wasShown then return end

    if not texMenuFrame then
        local tm = CreateFrame("Frame", "FarmTrackerTexDropdown", UIParent, "BackdropTemplate")
        tm:SetSize(220, 200)
        tm:SetFrameStrata("FULLSCREEN_DIALOG")
        tm:SetClampedToScreen(true)
        ns.Utils.ApplyBackdropTheme(tm, false, false)

        local sf = CreateFrame("ScrollFrame", "FarmTrackerTexScroll", tm, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 6, -6)
        sf:SetPoint("BOTTOMRIGHT", -24, 6)

        local sc = CreateFrame("Frame", nil, sf)
        sc:SetWidth(188)
        sc:SetHeight(1)
        sf:SetScrollChild(sc)
        tm.scrollChild = sc
        tm.rows = {}
        tm:Hide()
        texMenuFrame = tm
    end

    ns.Utils.ApplyBackdropTheme(texMenuFrame, false, false)
    local list = ns.Utils.GetAvailableBarTextures()
    local rowH = 22

    for i, tInfo in ipairs(list) do
        local rb = texMenuFrame.rows[i]
        if not rb then
            rb = CreateFrame("Button", nil, texMenuFrame.scrollChild)
            rb:SetHeight(20)

            local bg = rb:CreateTexture(nil, "BACKGROUND")
            bg:SetPoint("TOPLEFT", 2, -2)
            bg:SetPoint("BOTTOMRIGHT", -2, 2)
            bg:SetVertexColor(0.25, 0.55, 0.85, 0.45)
            rb.bg = bg

            local hl = rb:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.15)

            local txt = rb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            txt:SetPoint("LEFT", 6, 0)
            txt:SetPoint("RIGHT", -6, 0)
            txt:SetJustifyH("LEFT")
            txt:SetWordWrap(false)
            rb.txt = txt

            texMenuFrame.rows[i] = rb
        end

        rb:ClearAllPoints()
        rb:SetPoint("TOPLEFT", 0, -((i - 1) * rowH))
        rb:SetPoint("TOPRIGHT", 0, -((i - 1) * rowH))
        rb.bg:SetTexture(tInfo.path)
        rb.txt:SetText(tInfo.name)
        rb:SetScript("OnClick", function()
            ns.db.goalBarTexture = tInfo.name
            anchorBtn:SetText(tInfo.name)
            texMenuFrame:Hide()
            NotifyRefresh()
        end)
        rb:Show()
    end

    for i = #list + 1, #texMenuFrame.rows do
        texMenuFrame.rows[i]:Hide()
    end

    texMenuFrame.scrollChild:SetHeight(math.max(#list * rowH, 1))
    texMenuFrame:ClearAllPoints()
    texMenuFrame:SetPoint("TOPLEFT", anchorBtn, "BOTTOMLEFT", 0, -2)
    texMenuFrame:Show()
end

local function RefreshBlocklistUI()
    local container = controls.blkContainer
    if not container then return end

    local bl = ns.db.globalBlacklist or {}
    local items = {}

    for k, v in pairs(bl) do
        if v then
            local id = tonumber(k)
            if id then
                local name, link, _, _, _, _, _, _, _, icon = ns.Utils.SafeGetItemInfo(id)
                table.insert(items, {
                    key  = k,
                    id   = id,
                    name = name or ("Item #" .. id),
                    link = link,
                    icon = icon,
                })
            end
        end
    end

    table.sort(items, function(a, b)
        return string.lower(a.name) < string.lower(b.name)
    end)

    if controls.blkHeader then
        controls.blkHeader:SetText(string.format("Global Blocklist |cffaaaaaa(%d items):|r", #items))
    end

    container.rows = container.rows or {}
    local rowH = 22

    if #items == 0 then
        for _, r in ipairs(container.rows) do r:Hide() end
        container.emptyTxt:Show()
        container:SetHeight(28)
        if tabPanels["LOOT_AH"] then tabPanels["LOOT_AH"]:SetHeight(340) end
        return
    end

    container.emptyTxt:Hide()

    for i, info in ipairs(items) do
        local row = container.rows[i]
        if not row then
            row = CreateFrame("Frame", nil, container)
            row:SetHeight(rowH)

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0.0)

            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(16, 16)
            icon:SetPoint("LEFT", 6, 0)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            row.icon = icon

            local txt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            txt:SetPoint("LEFT", icon, "RIGHT", 6, 0)
            txt:SetPoint("RIGHT", -28, 0)
            txt:SetJustifyH("LEFT")
            txt:SetWordWrap(false)
            row.txt = txt

            local delBtn = CreateFrame("Button", nil, row)
            delBtn:SetSize(18, 18)
            delBtn:SetPoint("RIGHT", -4, 0)
            delBtn:SetNormalFontObject("GameFontNormal")
            delBtn:SetText("|cffff5555X|r")
            delBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Remove from Global Blocklist", 1, 0.35, 0.35)
                GameTooltip:Show()
            end)
            delBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row.delBtn = delBtn

            row:EnableMouse(true)
            row:SetScript("OnEnter", function(self)
                if not self.itemID then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if self.itemLink then
                    GameTooltip:SetHyperlink(self.itemLink)
                else
                    GameTooltip:SetItemByID(self.itemID)
                end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)

            container.rows[i] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 2, -4 - ((i - 1) * rowH))
        row:SetPoint("TOPRIGHT", -2, -4 - ((i - 1) * rowH))
        row.itemID   = info.id
        row.itemLink = info.link
        row.icon:SetTexture(info.icon or 134400)
        row.txt:SetText(info.link or info.name)

        row.delBtn:SetScript("OnClick", function()
            if ns.db.globalBlacklist then
                ns.db.globalBlacklist[info.key] = nil
                ns.db.globalBlacklist[info.id] = nil
                ns.db.globalBlacklist[tostring(info.id)] = nil
            end
            if ns.Tracker and ns.Tracker.OnLootBlacklistChanged then
                ns.Tracker:OnLootBlacklistChanged()
            end
            NotifyRefresh()
            RefreshBlocklistUI()
        end)

        row:Show()
    end

    for i = #items + 1, #container.rows do
        container.rows[i]:Hide()
    end

    local boxH = (#items * rowH) + 8
    container:SetHeight(boxH)
    if tabPanels["LOOT_AH"] then
        tabPanels["LOOT_AH"]:SetHeight(310 + boxH)
    end
end

local function CreateOptionsUI()
    if optFrame then return optFrame end

    local f = CreateFrame("Frame", "FarmTrackerOptionsFrame", UIParent, "BackdropTemplate")
    tinsert(UISpecialFrames, "FarmTrackerOptionsFrame")
    f:SetSize(470, 466)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetScript("OnHide", HideDropdowns)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText("|cff00ccffFarm Tracker|r Settings")

    local closeBtn = CreateFrame("Button", nil, f)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("TOPRIGHT", -8, -8)
    closeBtn:SetNormalFontObject("GameFontNormal")
    closeBtn:SetText("|cffff5555X|r")
    closeBtn:SetScript("OnClick", function()
        HideDropdowns()
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
    selectBtn:SetSize(160, 20)
    selectBtn:SetPoint("LEFT", profLbl, "RIGHT", 6, 0)
    selectBtn:SetNormalFontObject("GameFontHighlightSmall")
    selectBtn:SetScript("OnClick", function(self) ToggleProfileMenu(self) end)
    pBar.selectBtn = selectBtn

    local delBtn = CreateFrame("Button", nil, pBar, "UIPanelButtonTemplate")
    delBtn:SetSize(74, 20)
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
    newBox:SetSize(210, 18)
    newBox:SetPoint("TOPLEFT", 12, -44)
    newBox:SetAutoFocus(false)
    newBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    pBar.newBox = newBox

    local createBtn = CreateFrame("Button", nil, pBar, "UIPanelButtonTemplate")
    createBtn:SetSize(112, 20)
    createBtn:SetPoint("LEFT", newBox, "RIGHT", 8, 0)
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

    -- 4 Scrollable Category Tabs
    for i, tInfo in ipairs(TABS) do
        local tb = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        tb:SetSize(106, 22)
        tb:SetPoint("TOPLEFT", 14 + ((i - 1) * 112), -104)
        tb:SetNormalFontObject("GameFontHighlightSmall")
        tb:SetDisabledFontObject("GameFontHighlightSmall")
        tb.tabKey   = tInfo.key
        tb.tabLabel = tInfo.label
        tb:SetScript("OnClick", function() SetActiveTab(tInfo.key) end)
        table.insert(tabButtons, tb)

        local sf = CreateFrame("ScrollFrame", "FarmTrackerOptScroll_" .. tInfo.key, f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 12, -132)
        sf:SetPoint("BOTTOMRIGHT", -32, 42)
        sf:Hide()

        local sc = CreateFrame("Frame", nil, sf)
        sc:SetWidth(416)
        sc:SetHeight(320)
        sf:SetScrollChild(sc)

        sc.scrollFrame = sf
        tabPanels[tInfo.key] = sc
    end

    -- Helper for checkboxes
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

    -- =========================================================================
    -- TAB 1: APPEARANCE
    -- =========================================================================
    local app = tabPanels["APPEARANCE"]

    local themeLbl = app:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    themeLbl:SetPoint("TOPLEFT", 6, -8)
    themeLbl:SetText("Theme:")

    local darkBtn = CreateFrame("Button", nil, app, "UIPanelButtonTemplate")
    darkBtn:SetSize(120, 20)
    darkBtn:SetPoint("TOPLEFT", 6, -26)
    darkBtn:SetNormalFontObject("GameFontHighlightSmall")
    darkBtn:SetScript("OnClick", function()
        ns.db.timerTheme = "dark"
        NotifyRefresh()
        mod:RefreshUI()
    end)

    local classicBtn = CreateFrame("Button", nil, app, "UIPanelButtonTemplate")
    classicBtn:SetSize(120, 20)
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
    alphaSlider:SetSize(390, 16)
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
    fontBtn:SetSize(240, 22)
    fontBtn:SetPoint("TOPLEFT", 6, -120)
    fontBtn:SetNormalFontObject("GameFontHighlightSmall")
    fontBtn:SetScript("OnClick", function(self)
        local wasShown = fontMenuFrame and fontMenuFrame:IsShown()
        HideDropdowns()
        if wasShown then return end

        if not fontMenuFrame then
            local fm = CreateFrame("Frame", "FarmTrackerFontDropdown", UIParent, "BackdropTemplate")
            fm:SetSize(240, 180)
            fm:SetFrameStrata("FULLSCREEN_DIALOG")
            fm:SetClampedToScreen(true)
            ns.Utils.ApplyBackdropTheme(fm, false, false)

            local sf = CreateFrame("ScrollFrame", "FarmTrackerFontScroll", fm, "UIPanelScrollFrameTemplate")
            sf:SetPoint("TOPLEFT", 6, -6)
            sf:SetPoint("BOTTOMRIGHT", -24, 6)

            local sc = CreateFrame("Frame", nil, sf)
            sc:SetWidth(208)
            sc:SetHeight(1)
            sf:SetScrollChild(sc)
            fm.scrollChild = sc
            fm.rows = {}
            fm:Hide()
            fontMenuFrame = fm
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

    local fSizeLbl = app:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fSizeLbl:SetPoint("TOPLEFT", 6, -158)
    fSizeLbl:SetText("Font Size (px):")

    local fSizeBox = CreateFrame("EditBox", "FarmTrackerFontSizeBox", app, "InputBoxTemplate")
    fSizeBox:SetSize(70, 20)
    fSizeBox:SetPoint("LEFT", fSizeLbl, "RIGHT", 8, 0)
    fSizeBox:SetAutoFocus(false)
    fSizeBox:SetJustifyH("CENTER")
    local function CommitFontSize(self)
        local val = tonumber(strtrim(self:GetText() or ""))
        if not val then
            self:SetText(tostring(ns.db.timerFontSize or 11))
            return
        end
        val = math.floor(val + 0.5)
        if val < 6 then val = 6 elseif val > 72 then val = 72 end
        ns.db.timerFontSize = val
        self:SetText(tostring(val))
        NotifyRefresh()
    end
    fSizeBox:SetScript("OnEnterPressed", function(self) CommitFontSize(self); self:ClearFocus() end)
    fSizeBox:SetScript("OnEscapePressed", function(self) self:SetText(tostring(ns.db.timerFontSize or 11)); self:ClearFocus() end)
    fSizeBox:SetScript("OnEditFocusLost", CommitFontSize)
    controls.fSizeBox = fSizeBox

    local wScaleLbl = app:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    wScaleLbl:SetPoint("LEFT", fSizeBox, "RIGHT", 22, 0)
    wScaleLbl:SetText("Window Scale (%):")

    local wScaleBox = CreateFrame("EditBox", "FarmTrackerWindowScaleBox", app, "InputBoxTemplate")
    wScaleBox:SetSize(70, 20)
    wScaleBox:SetPoint("LEFT", wScaleLbl, "RIGHT", 8, 0)
    wScaleBox:SetAutoFocus(false)
    wScaleBox:SetJustifyH("CENTER")
    local function CommitWindowScale(self)
        local clean = string.gsub(strtrim(self:GetText() or ""), "%%", "")
        local val = tonumber(clean)
        if not val then
            self:SetText(tostring(ns.db.timerWindowScale or 100))
            return
        end
        val = math.floor(val + 0.5)
        if val < 30 then val = 30 elseif val > 300 then val = 300 end
        ns.db.timerWindowScale = val
        self:SetText(tostring(val))
        NotifyRefresh()
    end
    wScaleBox:SetScript("OnEnterPressed", function(self) CommitWindowScale(self); self:ClearFocus() end)
    wScaleBox:SetScript("OnEscapePressed", function(self) self:SetText(tostring(ns.db.timerWindowScale or 100)); self:ClearFocus() end)
    wScaleBox:SetScript("OnEditFocusLost", CommitWindowScale)
    controls.wScaleBox = wScaleBox

    local scaleNote = app:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scaleNote:SetPoint("TOPLEFT", 6, -184)
    scaleNote:SetText("|cffaaaaaaWindow width & row spacing auto-expand if Font Size is larger than default.|r")

    app:SetHeight(210)

    -- =========================================================================
    -- TAB 2: DISPLAY (2-Column Layout + Session Gold Goal Bar Customization)
    -- =========================================================================
    local disp = tabPanels["DISPLAY"]
    local col1X = 4
    local col2X = 212

    local hGen = disp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hGen:SetPoint("TOPLEFT", col1X, -4)
    hGen:SetText("|cff00ccffWindow & General|r")

    local hStats = disp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hStats:SetPoint("TOPLEFT", col2X, -4)
    hStats:SetText("|cff00ccffTracker Rows|r")

    -- Left Column
    AddCheckbox(disp, "farmTimer",        "Enable Farm Tracker", col1X, -22)
    AddCheckbox(disp, "timerMinimap",     "Show Minimap Button", col1X, -44)
    AddCheckbox(disp, "timerLocked",      "Lock Window & Size", col1X, -66)
    AddCheckbox(disp, "compactMode",      "Compact Mode", col1X, -88)
    AddCheckbox(disp, "compactClickThru", "Click-Through (Compact)", col1X + 12, -110)
    AddCheckbox(disp, "showBagSpace",     "Show Free Bag Slots", col1X, -132)

    -- Right Column
    AddCheckbox(disp, "showTotalGold",      "Net Session Profit", col2X, -22)
    AddCheckbox(disp, "showXpPerHour",      "Session XP / Hr", col2X, -44)
    AddCheckbox(disp, "showTimeToLevel",    "Time to Level", col2X, -66)
    AddCheckbox(disp, "showTotalRuns",      "Total Runs (Dungeon)", col2X, -88)
    AddCheckbox(disp, "showRunsPerHour",    "Runs / Hour (Dungeon)", col2X, -110)
    AddCheckbox(disp, "showFastestRun",     "Fastest Run (Dungeon)", col2X, -132)
    AddCheckbox(disp, "showLockoutWarning", "Hourly Lockout (5/hr)", col2X, -154)

    -- Divider before Goal Bar section
    local gDiv = disp:CreateTexture(nil, "ARTWORK")
    gDiv:SetColorTexture(0.25, 0.25, 0.32, 0.8)
    gDiv:SetSize(404, 1)
    gDiv:SetPoint("TOPLEFT", 4, -182)

    local hGoal = disp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hGoal:SetPoint("TOPLEFT", col1X, -190)
    hGoal:SetText("|cff00ccffSession Gold Goal Bar|r")

    AddCheckbox(disp, "showGoalBar", "Show Session Gold Goal Bar", col1X, -208)

    local goalAmtLbl = disp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    goalAmtLbl:SetPoint("TOPLEFT", col2X, -214)
    goalAmtLbl:SetText("Goal |cffaaaaaa(e.g. 100g):|r")

    local goalBox = CreateFrame("EditBox", "FarmTrackerGoalAmountBox", disp, "InputBoxTemplate")
    goalBox:SetSize(84, 20)
    goalBox:SetPoint("LEFT", goalAmtLbl, "RIGHT", 8, 0)
    goalBox:SetAutoFocus(false)
    goalBox:SetJustifyH("CENTER")
    goalBox:SetScript("OnEnterPressed", function(self)
        ns.db.sessionGoalCopper = ParseGoldInput(self:GetText(), ns.db.sessionGoalCopper)
        self:SetText(FormatGoldInput(ns.db.sessionGoalCopper))
        self:ClearFocus()
        NotifyRefresh()
    end)
    goalBox:SetScript("OnEscapePressed", function(self)
        self:SetText(FormatGoldInput(ns.db.sessionGoalCopper))
        self:ClearFocus()
    end)
    goalBox:SetScript("OnEditFocusLost", function(self)
        ns.db.sessionGoalCopper = ParseGoldInput(self:GetText(), ns.db.sessionGoalCopper)
        self:SetText(FormatGoldInput(ns.db.sessionGoalCopper))
        NotifyRefresh()
    end)
    controls.goalBox = goalBox

    -- Bar Color Mode + Color Swatch
    local cmLbl = disp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cmLbl:SetPoint("TOPLEFT", col1X + 2, -240)
    cmLbl:SetText("Bar Color Mode:")

    local solidBtn = CreateFrame("Button", nil, disp, "UIPanelButtonTemplate")
    solidBtn:SetSize(96, 20)
    solidBtn:SetPoint("TOPLEFT", col1X, -256)
    solidBtn:SetNormalFontObject("GameFontHighlightSmall")
    solidBtn:SetScript("OnClick", function()
        ns.db.goalBarColorMode = "solid"
        mod:RefreshUI()
        NotifyRefresh()
    end)
    controls.solidBtn = solidBtn

    local compBtn = CreateFrame("Button", nil, disp, "UIPanelButtonTemplate")
    compBtn:SetSize(134, 20)
    compBtn:SetPoint("LEFT", solidBtn, "RIGHT", 6, 0)
    compBtn:SetNormalFontObject("GameFontHighlightSmall")
    compBtn:SetScript("OnClick", function()
        ns.db.goalBarColorMode = "completion"
        mod:RefreshUI()
        NotifyRefresh()
    end)
    controls.compBtn = compBtn

    local swatch = CreateFrame("Button", nil, disp, "BackdropTemplate")
    swatch:SetSize(22, 20)
    swatch:SetPoint("LEFT", compBtn, "RIGHT", 10, 0)
    swatch:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    swatch:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)
    local swTex = swatch:CreateTexture(nil, "ARTWORK")
    swTex:SetPoint("TOPLEFT", 1, -1)
    swTex:SetPoint("BOTTOMRIGHT", -1, 1)
    swTex:SetColorTexture(0.0, 0.72, 0.95, 1)
    swatch.tex = swTex
    swatch:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Pick Solid Bar Color", 1, 1, 1)
        GameTooltip:Show()
    end)
    swatch:SetScript("OnLeave", function() GameTooltip:Hide() end)
    swatch:SetScript("OnClick", OpenGoalColorPicker)
    controls.goalColorSwatch = swatch

    local swLbl = disp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    swLbl:SetPoint("LEFT", swatch, "RIGHT", 6, 0)
    swLbl:SetText("Solid Color")

    -- Bar Texture Dropdown
    local texLbl = disp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    texLbl:SetPoint("TOPLEFT", col1X + 2, -286)
    texLbl:SetText("Bar Texture |cffaaaaaa(Blizzard / LSM / EllesmereUI):|r")

    local texBtn = CreateFrame("Button", nil, disp, "UIPanelButtonTemplate")
    texBtn:SetSize(240, 22)
    texBtn:SetPoint("TOPLEFT", col1X, -302)
    texBtn:SetNormalFontObject("GameFontHighlightSmall")
    texBtn:SetScript("OnClick", function(self) ToggleTextureMenu(self) end)
    controls.texBtn = texBtn

    disp:SetHeight(340)

    -- =========================================================================
    -- TAB 3: LOOT & AH
    -- =========================================================================
    local lah = tabPanels["LOOT_AH"]

    local ahLbl = lah:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ahLbl:SetPoint("TOPLEFT", 6, -6)
    ahLbl:SetText("AH Price Source:")

    controls.ahBtns = {}
    for i, src in ipairs(AH_SOURCES) do
        local col = (i - 1) % 2
        local rowIdx = math.floor((i - 1) / 2)
        local b = CreateFrame("Button", nil, lah, "UIPanelButtonTemplate")
        b:SetSize(194, 20)
        b:SetPoint("TOPLEFT", 6 + (col * 202), -24 - (rowIdx * 24))
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

    local threshLbl = lah:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    threshLbl:SetPoint("TOPLEFT", 6, -134)
    threshLbl:SetText("Drop Alert Threshold |cffaaaaaa(e.g. 50s, 2g, 250g, 0c):|r")

    local threshBox = CreateFrame("EditBox", "FarmTrackerAlertThreshBox", lah, "InputBoxTemplate")
    threshBox:SetSize(96, 20)
    threshBox:SetPoint("LEFT", threshLbl, "RIGHT", 10, 0)
    threshBox:SetAutoFocus(false)
    threshBox:SetJustifyH("CENTER")
    local function CommitThreshold(self)
        ns.db.dropAlertThreshold = ParseGoldInput(self:GetText(), ns.db.dropAlertThreshold)
        self:SetText(FormatGoldInput(ns.db.dropAlertThreshold))
        NotifyRefresh()
    end
    threshBox:SetScript("OnEnterPressed", function(self) CommitThreshold(self); self:ClearFocus() end)
    threshBox:SetScript("OnEscapePressed", function(self) self:SetText(FormatGoldInput(ns.db.dropAlertThreshold)); self:ClearFocus() end)
    threshBox:SetScript("OnEditFocusLost", CommitThreshold)
    controls.threshBox = threshBox

    local sndLbl = lah:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sndLbl:SetPoint("TOPLEFT", 6, -164)
    sndLbl:SetText("Alert Sound:")

    controls.sndBtns = {}
    for i, sInfo in ipairs(ALERT_SOUNDS) do
        local col = (i - 1) % 2
        local rowIdx = math.floor((i - 1) / 2)
        local b = CreateFrame("Button", nil, lah, "UIPanelButtonTemplate")
        b:SetSize(194, 20)
        b:SetPoint("TOPLEFT", 6 + (col * 202), -182 - (rowIdx * 23))
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
    testAlertBtn:SetPoint("TOPLEFT", 6, -256)
    testAlertBtn:SetNormalFontObject("GameFontHighlightSmall")
    testAlertBtn:SetText("Test Alert")
    testAlertBtn:SetScript("OnClick", function()
        if ns.Tracker and ns.Tracker.TestDropAlert then
            ns.Tracker:TestDropAlert()
        end
    end)

    local clearBlkBtn = CreateFrame("Button", nil, lah, "UIPanelButtonTemplate")
    clearBlkBtn:SetSize(150, 20)
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

    local blkHeader = lah:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    blkHeader:SetPoint("TOPLEFT", 6, -286)
    blkHeader:SetText("Global Blocklist |cffaaaaaa(0 items):|r")
    controls.blkHeader = blkHeader

    local blkContainer = CreateFrame("Frame", nil, lah, "BackdropTemplate")
    blkContainer:SetPoint("TOPLEFT", 6, -304)
    blkContainer:SetWidth(396)
    blkContainer:SetHeight(28)
    blkContainer:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile     = false,
        edgeSize = 1,
    })
    blkContainer:SetBackdropColor(0.06, 0.06, 0.09, 0.85)
    blkContainer:SetBackdropBorderColor(0.25, 0.25, 0.32, 1)

    local emptyTxt = blkContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    emptyTxt:SetPoint("CENTER", 0, 0)
    emptyTxt:SetText("|cff888888No globally blocked items.|r")
    blkContainer.emptyTxt = emptyTxt
    controls.blkContainer = blkContainer

    lah:SetHeight(340)

    -- =========================================================================
    -- TAB 4: AUTOMATION
    -- =========================================================================
    local auto = tabPanels["AUTOMATION"]
    AddCheckbox(auto, "timerAutoStart",   "Auto-Start Timer When Entering a Dungeon", 4, -8)
    AddCheckbox(auto, "autoPauseAFK",     "Auto-Pause Timer When AFK", 4, -34)
    AddCheckbox(auto, "autoPauseCity",    "Auto-Pause Timer in Cities / Rested Areas", 4, -60)
    AddCheckbox(auto, "autoResume",       "Auto-Resume After AFK / Rested Auto-Pause", 4, -86)
    AddCheckbox(auto, "autoResumeCombat", "Auto-Resume on Entering Combat", 4, -112)

    auto:SetHeight(160)

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
        HideDropdowns()
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
    if controls.fSizeBox then
        controls.fSizeBox:SetText(tostring(newPx))
    end
end

function mod:SyncWindowScale(newPct)
    if controls.wScaleBox then
        controls.wScaleBox:SetText(tostring(newPct))
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

    if controls.fSizeBox then
        controls.fSizeBox:SetText(tostring(tonumber(ns.db.timerFontSize) or 11))
    end
    if controls.wScaleBox then
        controls.wScaleBox:SetText(tostring(tonumber(ns.db.timerWindowScale) or 100))
    end

    controls.fontBtn:SetText(ns.db.timerFont or "Friz Quadrata TT")

    for key, cb in pairs(controls.checks or {}) do
        cb:SetChecked(ns.db[key] == true)
    end

    -- Goal Bar Controls
    if controls.goalBox then
        controls.goalBox:SetText(FormatGoldInput(ns.db.sessionGoalCopper))
    end
    local isComp = (ns.db.goalBarColorMode == "completion")
    if controls.solidBtn then
        controls.solidBtn:SetText((not isComp) and "|cff00ccffSolid Color|r" or "Solid Color")
    end
    if controls.compBtn then
        controls.compBtn:SetText(isComp and "|cff00ccffBy Completion (R/O/Y/G)|r" or "By Completion (R/O/Y/G)")
    end
    if controls.goalColorSwatch then
        local c = ns.db.goalBarColor or { r = 0.0, g = 0.72, b = 0.95 }
        controls.goalColorSwatch.tex:SetColorTexture(c.r or 0.0, c.g or 0.72, c.b or 0.95, 1)
    end
    if controls.texBtn then
        controls.texBtn:SetText(ns.db.goalBarTexture or "Blizzard")
    end

    local curSrc = ns.db.ahPriceSource or "AUTO"
    for _, b in ipairs(controls.ahBtns or {}) do
        b:SetText((b.srcKey == curSrc) and ("|cff00ccff" .. b.srcLabel .. "|r") or b.srcLabel)
    end

    if controls.threshBox then
        controls.threshBox:SetText(FormatGoldInput(ns.db.dropAlertThreshold))
    end

    local curSnd = ns.db.dropAlertSound or "RAID_WARNING"
    for _, b in ipairs(controls.sndBtns or {}) do
        b:SetText((b.sndKey == curSnd) and ("|cff00ccff" .. b.sndLabel .. "|r") or b.sndLabel)
    end
    RefreshBlocklistUI()
end

function mod:ToggleUI()
    local f = CreateOptionsUI()
    if f:IsShown() then
        HideDropdowns()
        f:Hide()
    else
        self:RefreshUI()
        f:Show()
    end
end

function mod:OnInit()
    -- Created lazily on first open
end