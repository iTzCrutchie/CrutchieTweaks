local _, ns = ...

local mod = ns:RegisterModule("FarmTimer", {})

-- Active state table (persisted in CrutchieTweaksDB.timerState across /reload)
local state = {
    isRunning      = false,
    isShown        = false,
    sessionTime    = 0,
    runTime        = 0,
    lastRunTime    = nil,
    fastestRunTime = nil,
    runCount       = 1,
    completedRuns  = 0,
    rawCopper      = 0,
    vendorCopper   = 0,
    ahCopper       = 0,
    lastSaveTime   = nil,
}

-- Openable clams / containers whose contents fire a second CHAT_MSG_LOOT when auto-opened
local OPENABLE_CONTAINERS = {
    [5523]  = true, -- Small Barnacled Clam
    [5524]  = true, -- Thick-shelled Clam
    [7973]  = true, -- Big-mouth Clam
    [15874] = true, -- Soft-shelled Clam
    [24476] = true, -- Jaggal Clam
    [36781] = true, -- Darkwater Clam
    [45909] = true, -- Giant Darkwater Clam
    [52340] = true, -- Abyssal Clam
}

local debugMode    = false
local uiFrame      = nil
local postMenu     = nil
local pendingItems = {}

local function DebugPrint(msg)
    if debugMode then
        ns:Print("|cffffaa00[TimerDebug]|r " .. tostring(msg))
    end
end

-- Cross-client safe GetItemInfo wrapper (supports 1.60.1 C_Item.GetItemInfo and legacy GetItemInfo)
local function SafeGetItemInfo(item)
    if _G.C_Item and _G.C_Item.GetItemInfo then
        return _G.C_Item.GetItemInfo(item)
    elseif _G.GetItemInfo then
        return _G.GetItemInfo(item)
    end
    return nil
end

-- Sync local state pointer with SavedVariables
local function InitSavedState()
    CrutchieTweaksDB.timerState = CrutchieTweaksDB.timerState or {}
    local saved = CrutchieTweaksDB.timerState

    for k, defaultVal in pairs(state) do
        if saved[k] == nil then
            saved[k] = defaultVal
        end
    end

    state = saved

    if state.isRunning and state.lastSaveTime then
        local delta = GetTime() - state.lastSaveTime
        if delta > 0 and delta < 300 then
            state.sessionTime = state.sessionTime + delta
            if ns.db.timerDungeonMode ~= false then
                state.runTime = state.runTime + delta
            end
        end
    end
    state.lastSaveTime = GetTime()
end

-- Format copper into compact gold/silver/copper string (UI display with colors)
local function FormatMoneyUI(copper)
    copper = math.floor(copper or 0)
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100

    if g > 0 then
        return string.format("|cffffd700%dg|r |cffc7c7cf%ds|r", g, s)
    elseif s > 0 then
        return string.format("|cffc7c7cf%ds|r |cffeda55f%dc|r", s, c)
    else
        return string.format("|cffeda55f%dc|r", c)
    end
end

-- Plain text money formatting for Chat posting
local function FormatMoneyPlain(copper)
    copper = math.floor(copper or 0)
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100

    if g > 0 then
        return string.format("%dg %ds", g, s)
    elseif s > 0 then
        return string.format("%ds %dc", s, c)
    else
        return string.format("%dc", c)
    end
end

-- Format seconds into HH:MM:SS or MM:SS
local function FormatTime(sec)
    if not sec then return "--:--" end
    sec = math.floor(sec)
    local hrs  = math.floor(sec / 3600)
    local mins = math.floor((sec % 3600) / 60)
    local secs = sec % 60
    if hrs > 0 then
        return string.format("%02d:%02d:%02d", hrs, mins, secs)
    else
        return string.format("%02d:%02d", mins, secs)
    end
end

-- Parse copper directly from CHAT_MSG_MONEY
local function ParseLootedCoin(msg)
    if not msg then return 0 end
    if not (string.find(msg, "You loot", 1, true) or string.find(msg, "Your share of the loot", 1, true)) then
        return 0
    end

    local gold   = tonumber(string.match(msg, "(%d+)%s+Gold")) or 0
    local silver = tonumber(string.match(msg, "(%d+)%s+Silver")) or 0
    local copper = tonumber(string.match(msg, "(%d+)%s+Copper")) or 0

    return (gold * 10000) + (silver * 100) + copper
end

-- Lookup Auction House price via TSM or Auctionator (skips AH for Soulbound/BoP items)
local function GetItemAHValue(itemID, cleanLink, vendorUnitPrice, isBoP)
    if isBoP then
        return vendorUnitPrice or 0
    end

    local ahUnit = 0
    local tsmItemString = itemID and ("i:" .. itemID) or nil

    -- 1. Try TradeSkillMaster (TSM)
    if _G.TSM_API and _G.TSM_API.GetCustomPriceValue and tsmItemString then
        local okMin, minVal = pcall(_G.TSM_API.GetCustomPriceValue, "DBMinBuyout", tsmItemString)
        if okMin and type(minVal) == "number" and minVal > 0 then
            ahUnit = minVal
        else
            local okVal, val = pcall(_G.TSM_API.GetCustomPriceValue, "DBMarket", tsmItemString)
            if okVal and type(val) == "number" and val > 0 then
                ahUnit = val
            end
        end
    end

    -- 2. Fallback to Auctionator
    if ahUnit == 0 and _G.Auctionator and _G.Auctionator.API and _G.Auctionator.API.v1 then
        if itemID and _G.Auctionator.API.v1.GetAuctionPriceByItemID then
            local ok, val = pcall(_G.Auctionator.API.v1.GetAuctionPriceByItemID, "CrutchieTweaks", itemID)
            if ok and type(val) == "number" and val > 0 then
                ahUnit = val
            end
        end
        if ahUnit == 0 and cleanLink and _G.Auctionator.API.v1.GetAuctionPriceByItemLink then
            local ok, val = pcall(_G.Auctionator.API.v1.GetAuctionPriceByItemLink, "CrutchieTweaks", cleanLink)
            if ok and type(val) == "number" and val > 0 then
                ahUnit = val
            end
        end
    end

    if ahUnit < (vendorUnitPrice or 0) then
        ahUnit = vendorUnitPrice or 0
    end

    return ahUnit
end

local function IsDungeonMode()
    if ns.db.timerDungeonMode == nil then
        ns.db.timerDungeonMode = true
    end
    return ns.db.timerDungeonMode
end

local function StartNextRun()
    if not IsDungeonMode() then return end
    if state.runTime > 3 then
        state.lastRunTime = state.runTime
        if not state.fastestRunTime or state.runTime < state.fastestRunTime then
            state.fastestRunTime = state.runTime
        end
        state.completedRuns = state.completedRuns + 1
        state.runCount      = state.runCount + 1
    end
    state.runTime = 0
end

local function ApplyLayoutMode()
    if not uiFrame then return end

    local dungeonMode = IsDungeonMode()
    uiFrame.dungeonCheck:SetChecked(dungeonMode)

    if dungeonMode then
        uiFrame:SetHeight(288)

        uiFrame.sessionLabel:ClearAllPoints()
        uiFrame.sessionLabel:SetPoint("TOP", -62, -32)

        uiFrame.sessionTimerText:ClearAllPoints()
        uiFrame.sessionTimerText:SetPoint("TOP", -62, -46)

        uiFrame.vDiv:Show()
        uiFrame.runLabel:Show()
        uiFrame.runTimerText:Show()
        uiFrame.lapBtn:Show()

        uiFrame.div2:ClearAllPoints()
        uiFrame.div2:SetPoint("TOP", 0, -88)

        uiFrame.totalRunsLbl:Show()
        uiFrame.totalRunsVal:Show()
        uiFrame.rphLbl:Show()
        uiFrame.rphVal:Show()
        uiFrame.lastRunLbl:Show()
        uiFrame.lastRunVal:Show()
        uiFrame.fastRunLbl:Show()
        uiFrame.fastRunVal:Show()

        uiFrame.rawLbl:ClearAllPoints()
        uiFrame.rawLbl:SetPoint("TOPLEFT", 12, -160)
        uiFrame.rawVal:ClearAllPoints()
        uiFrame.rawVal:SetPoint("TOPRIGHT", -12, -160)

        uiFrame.vendorLbl:ClearAllPoints()
        uiFrame.vendorLbl:SetPoint("TOPLEFT", 12, -176)
        uiFrame.vendorVal:ClearAllPoints()
        uiFrame.vendorVal:SetPoint("TOPRIGHT", -12, -176)

        uiFrame.ahLbl:ClearAllPoints()
        uiFrame.ahLbl:SetPoint("TOPLEFT", 12, -192)
        uiFrame.ahVal:ClearAllPoints()
        uiFrame.ahVal:SetPoint("TOPRIGHT", -12, -192)

        uiFrame.div3:ClearAllPoints()
        uiFrame.div3:SetPoint("TOP", 0, -208)

        uiFrame.totalLbl:ClearAllPoints()
        uiFrame.totalLbl:SetPoint("TOPLEFT", 12, -215)
        uiFrame.totalVal:ClearAllPoints()
        uiFrame.totalVal:SetPoint("TOPRIGHT", -12, -215)

        uiFrame.gphLbl:ClearAllPoints()
        uiFrame.gphLbl:SetPoint("TOPLEFT", 12, -232)
        uiFrame.gphVal:ClearAllPoints()
        uiFrame.gphVal:SetPoint("TOPRIGHT", -12, -232)
    else
        uiFrame:SetHeight(208)

        uiFrame.sessionLabel:ClearAllPoints()
        uiFrame.sessionLabel:SetPoint("TOP", 0, -32)

        uiFrame.sessionTimerText:ClearAllPoints()
        uiFrame.sessionTimerText:SetPoint("TOP", 0, -46)

        uiFrame.vDiv:Hide()
        uiFrame.runLabel:Hide()
        uiFrame.runTimerText:Hide()
        uiFrame.lapBtn:Hide()

        uiFrame.div2:ClearAllPoints()
        uiFrame.div2:SetPoint("TOP", 0, -72)

        uiFrame.totalRunsLbl:Hide()
        uiFrame.totalRunsVal:Hide()
        uiFrame.rphLbl:Hide()
        uiFrame.rphVal:Hide()
        uiFrame.lastRunLbl:Hide()
        uiFrame.lastRunVal:Hide()
        uiFrame.fastRunLbl:Hide()
        uiFrame.fastRunVal:Hide()

        uiFrame.rawLbl:ClearAllPoints()
        uiFrame.rawLbl:SetPoint("TOPLEFT", 12, -80)
        uiFrame.rawVal:ClearAllPoints()
        uiFrame.rawVal:SetPoint("TOPRIGHT", -12, -80)

        uiFrame.vendorLbl:ClearAllPoints()
        uiFrame.vendorLbl:SetPoint("TOPLEFT", 12, -96)
        uiFrame.vendorVal:ClearAllPoints()
        uiFrame.vendorVal:SetPoint("TOPRIGHT", -12, -96)

        uiFrame.ahLbl:ClearAllPoints()
        uiFrame.ahLbl:SetPoint("TOPLEFT", 12, -112)
        uiFrame.ahVal:ClearAllPoints()
        uiFrame.ahVal:SetPoint("TOPRIGHT", -12, -112)

        uiFrame.div3:ClearAllPoints()
        uiFrame.div3:SetPoint("TOP", 0, -128)

        uiFrame.totalLbl:ClearAllPoints()
        uiFrame.totalLbl:SetPoint("TOPLEFT", 12, -135)
        uiFrame.totalVal:ClearAllPoints()
        uiFrame.totalVal:SetPoint("TOPRIGHT", -12, -135)

        uiFrame.gphLbl:ClearAllPoints()
        uiFrame.gphLbl:SetPoint("TOPLEFT", 12, -152)
        uiFrame.gphVal:ClearAllPoints()
        uiFrame.gphVal:SetPoint("TOPRIGHT", -12, -152)
    end
end

local function UpdateDisplay()
    if not uiFrame or not uiFrame:IsShown() then return end

    local totalCopper = state.rawCopper + state.ahCopper
    local gphCopper   = 0
    local rph         = 0

    if state.sessionTime >= 1 then
        local sessionHours = state.sessionTime / 3600
        gphCopper = totalCopper / sessionHours
        rph       = state.completedRuns / sessionHours
    end

    uiFrame.sessionTimerText:SetText(FormatTime(state.sessionTime))
    uiFrame.runTimerText:SetText(FormatTime(state.runTime))
    uiFrame.runLabel:SetText(string.format("|cff00ccffRun #%d|r", state.runCount))

    uiFrame.totalRunsVal:SetText(tostring(state.completedRuns))
    uiFrame.rphVal:SetText(string.format("%.1f/hr", rph))
    uiFrame.lastRunVal:SetText(FormatTime(state.lastRunTime))
    uiFrame.fastRunVal:SetText(state.fastestRunTime and ("|cff00ff00" .. FormatTime(state.fastestRunTime) .. "|r") or "--:--")

    uiFrame.rawVal:SetText(FormatMoneyUI(state.rawCopper))
    uiFrame.vendorVal:SetText(FormatMoneyUI(state.vendorCopper))
    uiFrame.ahVal:SetText(FormatMoneyUI(state.ahCopper))
    uiFrame.totalVal:SetText(FormatMoneyUI(totalCopper))
    uiFrame.gphVal:SetText(FormatMoneyUI(gphCopper) .. "/hr")

    if state.isRunning then
        uiFrame.startBtn:SetText("|cffffaa00Pause|r")
    else
        uiFrame.startBtn:SetText("|cff00ff00Start|r")
    end
end

local function ProcessLootedItem(itemID, count, retryIfUncached)
    if not itemID or OPENABLE_CONTAINERS[itemID] then return end

    -- Query directly by numeric itemID so |cnIQ1: link formatting never interferes
    local itemName, cleanLink, _, _, _, _, _, _, _, _, sellPrice, _, _, bindType = SafeGetItemInfo(itemID)

    if not itemName and retryIfUncached then
        DebugPrint("Item uncached, queuing ID: " .. tostring(itemID))
        pendingItems[itemID] = (pendingItems[itemID] or 0) + count
        return
    end

    sellPrice = tonumber(sellPrice) or 0
    local isBoP = (bindType == 1)

    local unitAH = GetItemAHValue(itemID, cleanLink, sellPrice, isBoP)
    local itemVendorTotal = sellPrice * count
    local itemAHTotal     = unitAH * count

    DebugPrint(string.format("Looted %s (ID:%d) x%d | BoP=%s | Vendor=%dc | AH=%dc", tostring(itemName), itemID, count, tostring(isBoP), itemVendorTotal, itemAHTotal))

    state.vendorCopper = state.vendorCopper + itemVendorTotal
    state.ahCopper     = state.ahCopper + itemAHTotal
    UpdateDisplay()
end

-- Send formatted summary to the chosen channel (no single '|' characters allowed in SendChatMessage)
local function SendSummaryToChannel(chatType)
    if chatType == "PARTY" and not IsInGroup() then
        ns:Print(ns.Colors.red .. "You are not currently in a party." .. ns.Colors.reset)
        return
    end
    if chatType == "GUILD" and not IsInGuild() then
        ns:Print(ns.Colors.red .. "You are not currently in a guild." .. ns.Colors.reset)
        return
    end

    local totalCopper  = state.rawCopper + state.ahCopper
    local sessionHours = (state.sessionTime >= 1) and (state.sessionTime / 3600) or 0
    local gphCopper    = (sessionHours > 0) and (totalCopper / sessionHours) or 0
    local rph          = (sessionHours > 0) and (state.completedRuns / sessionHours) or 0
    local zoneName     = GetRealZoneText() or "Farm Run"

    local runInfo = ""
    if IsDungeonMode() then
        local lastStr = state.lastRunTime and (", Last: " .. FormatTime(state.lastRunTime)) or ""
        local fastStr = state.fastestRunTime and (", Best: " .. FormatTime(state.fastestRunTime)) or ""
        runInfo = string.format(" [Runs: %d (%.1f/hr)%s%s]", state.completedRuns, rph, lastStr, fastStr)
    end

    local msg = string.format(
        "[Crutchie's Farm Tracker] %s - Session: %s%s // Total: %s (%s/hr) // Raw: %s // Vendor: %s // AH/Est: %s",
        zoneName,
        FormatTime(state.sessionTime),
        runInfo,
        FormatMoneyPlain(totalCopper),
        FormatMoneyPlain(gphCopper),
        FormatMoneyPlain(state.rawCopper),
        FormatMoneyPlain(state.vendorCopper),
        FormatMoneyPlain(state.ahCopper)
    )

    SendChatMessage(msg, chatType)
end

-- Build or toggle the Post Channel Selector popup
local function TogglePostMenu(anchorBtn)
    if not postMenu then
        local m = CreateFrame("Frame", "CrutchieFarmPostMenu", UIParent, "BackdropTemplate")
        m:SetSize(130, 122)
        m:SetFrameStrata("DIALOG")
        m:SetClampedToScreen(true)

        if m.SetBackdrop then
            m:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                tile     = false,
                edgeSize = 1,
            })
            m:SetBackdropColor(0.08, 0.08, 0.11, 0.96)
            m:SetBackdropBorderColor(0.3, 0.3, 0.38, 1)
        end

        local header = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        header:SetPoint("TOP", 0, -7)
        header:SetText("|cff00ccffPost Summary To:|r")

        local function MakeChannelBtn(label, yOffset, onClick)
            local b = CreateFrame("Button", nil, m, "UIPanelButtonTemplate")
            b:SetSize(110, 20)
            b:SetPoint("TOP", 0, yOffset)
            b:SetText(label)
            b:SetScript("OnClick", function()
                m:Hide()
                if onClick then onClick() end
            end)
            return b
        end

        MakeChannelBtn("Say (/s)", -24, function() SendSummaryToChannel("SAY") end)
        MakeChannelBtn("|cffaaaaffParty (/p)|r", -47, function() SendSummaryToChannel("PARTY") end)
        MakeChannelBtn("|cff40ff40Guild (/g)|r", -70, function() SendSummaryToChannel("GUILD") end)
        MakeChannelBtn("|cffff6666Cancel|r", -95, nil)

        m:Hide()
        postMenu = m
    end

    if postMenu:IsShown() then
        postMenu:Hide()
    else
        postMenu:ClearAllPoints()
        postMenu:SetPoint("TOP", anchorBtn, "BOTTOM", 0, -4)
        postMenu:Show()
    end
end

local function CreateTimerUI()
    if uiFrame then return uiFrame end

    local f = CreateFrame("Frame", "CrutchieTweaksTimerFrame", UIParent, "BackdropTemplate")
    f:SetSize(268, 288)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)

    local pos = ns.db.timerPos or { point = "CENTER", x = 0, y = 120 }
    f:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)

    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile     = false,
            edgeSize = 1,
        })
        f:SetBackdropColor(0.06, 0.06, 0.08, 0.92)
        f:SetBackdropBorderColor(0.2, 0.2, 0.25, 1)
    end

    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        ns.db.timerPos = { point = point, x = x, y = y }
    end)

    -- Header Bar
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText("|cff00ccffCrutchie's|r Farm Tracker")

    -- Close Button ('X')
    local closeBtn = CreateFrame("Button", nil, f)
    closeBtn:SetSize(18, 18)
    closeBtn:SetPoint("TOPRIGHT", -6, -6)
    closeBtn:SetNormalFontObject("GameFontNormal")
    closeBtn:SetText("|cffff5555X|r")
    closeBtn:SetScript("OnClick", function()
        state.isShown = false
        if postMenu then postMenu:Hide() end
        f:Hide()
    end)

    -- Dungeon Mode Checkbox in Header
    local dungeonCheck = CreateFrame("CheckButton", "CrutchieFarmDungeonCheck", f, "UICheckButtonTemplate")
    dungeonCheck:SetSize(20, 20)
    dungeonCheck:SetPoint("RIGHT", closeBtn, "LEFT", -46, 0)
    dungeonCheck:SetScript("OnClick", function(self)
        ns.db.timerDungeonMode = self:GetChecked() and true or false
        ApplyLayoutMode()
        UpdateDisplay()
    end)

    local dungeonCheckLbl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dungeonCheckLbl:SetPoint("LEFT", dungeonCheck, "RIGHT", -1, 0)
    dungeonCheckLbl:SetText("|cffccccccDungeon|r")
    f.dungeonCheck = dungeonCheck

    local div1 = f:CreateTexture(nil, "ARTWORK")
    div1:SetColorTexture(0.25, 0.25, 0.3, 0.8)
    div1:SetSize(248, 1)
    div1:SetPoint("TOP", 0, -26)

    -- Dual Timer Columns
    local sessionLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sessionLabel:SetPoint("TOP", -62, -32)
    sessionLabel:SetText("|cffaaaaaaSession Total|r")
    f.sessionLabel = sessionLabel

    local sessionTimerText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    sessionTimerText:SetPoint("TOP", -62, -46)
    sessionTimerText:SetText("00:00")
    f.sessionTimerText = sessionTimerText

    local vDiv = f:CreateTexture(nil, "ARTWORK")
    vDiv:SetColorTexture(0.25, 0.25, 0.3, 0.8)
    vDiv:SetSize(1, 36)
    vDiv:SetPoint("TOP", 0, -32)
    f.vDiv = vDiv

    local runLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    runLabel:SetPoint("TOP", 62, -32)
    runLabel:SetText("|cff00ccffRun #1|r")
    f.runLabel = runLabel

    local runTimerText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    runTimerText:SetPoint("TOP", 62, -46)
    runTimerText:SetText("00:00")
    f.runTimerText = runTimerText

    local lapBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    lapBtn:SetSize(64, 16)
    lapBtn:SetPoint("TOP", 62, -67)
    lapBtn:SetNormalFontObject("GameFontHighlightSmall")
    lapBtn:SetText("New Run")
    lapBtn:SetScript("OnClick", function()
        StartNextRun()
        UpdateDisplay()
    end)
    f.lapBtn = lapBtn

    local div2 = f:CreateTexture(nil, "ARTWORK")
    div2:SetColorTexture(0.25, 0.25, 0.3, 0.8)
    div2:SetSize(248, 1)
    div2:SetPoint("TOP", 0, -88)
    f.div2 = div2

    local function CreateStatRow(label, yOffset)
        local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("TOPLEFT", 12, yOffset)
        lbl:SetText(label)

        local val = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        val:SetPoint("TOPRIGHT", -12, yOffset)
        val:SetText("0c")
        return lbl, val
    end

    f.totalRunsLbl, f.totalRunsVal = CreateStatRow("|cffaaaaaaTotal Runs:|r", -95)
    f.totalRunsVal:SetText("0")

    f.rphLbl, f.rphVal             = CreateStatRow("|cffaaaaaaRuns / Hour:|r", -111)
    f.rphVal:SetText("0.0/hr")

    f.lastRunLbl, f.lastRunVal     = CreateStatRow("|cffaaaaaaLast Run Clear:|r", -127)
    f.lastRunVal:SetText("--:--")

    f.fastRunLbl, f.fastRunVal     = CreateStatRow("|cffaaaaaaFastest Run:|r", -143)
    f.fastRunVal:SetText("--:--")

    f.rawLbl, f.rawVal             = CreateStatRow("|cffaaaaaaRaw Looted Coin:|r", -160)
    f.vendorLbl, f.vendorVal       = CreateStatRow("|cffaaaaaaItems (Vendor):|r", -176)
    f.ahLbl, f.ahVal               = CreateStatRow("|cffaaaaaaItems (AH / Est):|r", -192)

    local div3 = f:CreateTexture(nil, "ARTWORK")
    div3:SetColorTexture(0.25, 0.25, 0.3, 0.8)
    div3:SetSize(248, 1)
    div3:SetPoint("TOP", 0, -208)
    f.div3 = div3

    f.totalLbl, f.totalVal = CreateStatRow("|cffffd700Total Session Value:|r", -215)
    f.gphLbl, f.gphVal     = CreateStatRow("|cff00ccffSession Gold / Hr:|r", -232)

    local function CreateActionButton(text, width, xOffset, onClick)
        local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btn:SetSize(width, 22)
        btn:SetPoint("BOTTOMLEFT", xOffset, 10)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        return btn
    end

    -- Start / Pause Button
    f.startBtn = CreateActionButton("|cff00ff00Start|r", 78, 10, function()
        state.isRunning = not state.isRunning
        if state.isRunning then
            state.lastSaveTime = GetTime()
        end
        UpdateDisplay()
    end)

    -- Reset All Button
    f.resetBtn = CreateActionButton("Reset", 78, 95, function()
        state.isRunning      = false
        state.sessionTime    = 0
        state.runTime        = 0
        state.lastRunTime    = nil
        state.fastestRunTime = nil
        state.runCount       = 1
        state.completedRuns  = 0
        state.rawCopper      = 0
        state.vendorCopper   = 0
        state.ahCopper       = 0
        state.lastSaveTime   = GetTime()
        wipe(pendingItems)
        if postMenu then postMenu:Hide() end
        UpdateDisplay()
    end)

    -- Post to Chat Button (opens channel chooser)
    f.postBtn = CreateActionButton("|cff00ccffPost|r", 78, 180, function(self)
        TogglePostMenu(self)
    end)

    -- Live Tick (updates every 0.2s while running)
    local accum = 0
    f:SetScript("OnUpdate", function(_, dt)
        if not state.isRunning then return end
        state.sessionTime = state.sessionTime + dt
        if IsDungeonMode() then
            state.runTime = state.runTime + dt
        end
        accum = accum + dt
        if accum >= 0.2 then
            accum = 0
            state.lastSaveTime = GetTime()
            UpdateDisplay()
        end
    end)

    ApplyLayoutMode()
    if state.isShown then
        f:Show()
        UpdateDisplay()
    else
        f:Hide()
    end

    uiFrame = f
    return f
end

function mod:ToggleUI()
    local f = CreateTimerUI()
    if f:IsShown() then
        state.isShown = false
        if postMenu then postMenu:Hide() end
        f:Hide()
    else
        state.isShown = true
        ApplyLayoutMode()
        f:Show()
        UpdateDisplay()
    end
end

function mod:ToggleDebug()
    debugMode = not debugMode
    ns:Print("FarmTimer debug mode: " .. (debugMode and "|cff00ff00ON|r" or "|cffff3333OFF|r"))
end

function mod:OnInit()
    if not ns.db.farmTimer then return end

    InitSavedState()
    CreateTimerUI()

    local tracker = CreateFrame("Frame")
    tracker:RegisterEvent("CHAT_MSG_MONEY")
    tracker:RegisterEvent("CHAT_MSG_LOOT")
    tracker:RegisterEvent("CHAT_MSG_SYSTEM")
    tracker:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    tracker:RegisterEvent("PLAYER_LOGOUT")

    tracker:SetScript("OnEvent", function(_, event, arg1, arg2)
        if event == "PLAYER_LOGOUT" then
            state.lastSaveTime = GetTime()

        elseif event == "CHAT_MSG_SYSTEM" and arg1 then
            if IsDungeonMode() and string.find(arg1, "has been reset.", 1, true) then
                StartNextRun()
                UpdateDisplay()
            end

        elseif event == "CHAT_MSG_MONEY" and arg1 then
            DebugPrint("CHAT_MSG_MONEY: " .. tostring(arg1))
            if not state.isRunning then return end

            local copper = ParseLootedCoin(arg1)
            if copper > 0 then
                state.rawCopper = state.rawCopper + copper
                UpdateDisplay()
            end

        elseif event == "GET_ITEM_INFO_RECEIVED" and arg1 then
            local itemID = arg1
            local pendingCount = pendingItems[itemID]
            if pendingCount and arg2 then
                pendingItems[itemID] = nil
                ProcessLootedItem(itemID, pendingCount, false)
            end

        elseif event == "CHAT_MSG_LOOT" and arg1 then
            DebugPrint("CHAT_MSG_LOOT: " .. gsub(tostring(arg1), "|", "||"))
            if not state.isRunning then return end

            local lootMsg = arg1
            local isSelfLoot = string.find(lootMsg, "You receive loot:", 1, true)
                or string.find(lootMsg, "You receive item:", 1, true)
                or string.find(lootMsg, "You loot", 1, true)
                or string.find(lootMsg, "You create:", 1, true)

            if not isSelfLoot then return end

            -- Extract numeric itemID directly from "|Hitem:2674:..." regardless of |cnIQ1: or |cffffffff wrapper
            local itemID = tonumber(string.match(lootMsg, "|Hitem:(%d+)"))
            if not itemID then
                DebugPrint("Failed to extract itemID from: " .. gsub(tostring(lootMsg), "|", "||"))
                return
            end

            -- Match stack count across "|h|rx5", "|hx5", or "|h x5"
            local count = tonumber(string.match(lootMsg, "|h|r%s*x(%d+)") or string.match(lootMsg, "|h%s*x(%d+)")) or 1
            ProcessLootedItem(itemID, count, true)
        end
    end)
end