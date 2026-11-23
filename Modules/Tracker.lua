local _, ns = ...

local mod = ns:RegisterModule("Tracker", {})
ns.Tracker = mod

local BASE_FONT_SIZE = 11
local BASE_WIDTH     = 276

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
    repairCopper   = 0,
    sessionXP      = 0,
    lastSaveTime   = nil,
    lootLog        = {},
    sessionIgnored = {},
    runTimestamps  = {},
}

local OPENABLE_CONTAINERS = {
    [5523]  = true, [5524]  = true, [7973]  = true, [15874] = true,
    [24476] = true, [36781] = true, [45909] = true, [52340] = true,
}

local debugMode             = false
local uiFrame               = nil
local postMenu              = nil
local pendingItems          = {}
local wasInDungeon          = false
local autoPausedReason      = nil
local lastXP                = 0
local lastXPMax             = 0
local lastLevel             = 0
local lastMoney             = 0
local lastRepairCost        = 0
local pendingMoneySpent     = 0
local pendingMoneyTime      = 0
local pendingRepairDrop     = 0
local pendingRepairDropTime = 0

local function DebugPrint(msg)
    if debugMode then
        ns:Print("|cffffaa00[TrackerDebug]|r " .. tostring(msg))
    end
end

function mod:GetState()
    return state
end

local function InitSavedState()
    FarmTrackerDB.timerState = FarmTrackerDB.timerState or {}
    local saved = FarmTrackerDB.timerState

    for k, defaultVal in pairs(state) do
        if saved[k] == nil then
            saved[k] = (type(defaultVal) == "table") and {} or defaultVal
        end
    end

    if type(saved.lootLog) ~= "table" then saved.lootLog = {} end
    if type(saved.sessionIgnored) ~= "table" then saved.sessionIgnored = {} end
    if type(saved.runTimestamps) ~= "table" then saved.runTimestamps = {} end

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

local function IsDungeonMode()
    if ns.db.timerDungeonMode == nil then ns.db.timerDungeonMode = true end
    return ns.db.timerDungeonMode
end

local function RecalculateLootTotals()
    local Pricing     = ns.Pricing
    local totalVendor = 0
    local totalAH     = 0

    for key, entry in pairs(state.lootLog) do
        if not Pricing.IsItemBlocked(entry.itemID or key, state.sessionIgnored) then
            local unitVendor = entry.vendorUnit or 0
            local unitAH     = Pricing.GetItemAHValue(entry.itemID, entry.link, unitVendor, entry.isBoP)
            entry.ahUnit     = unitAH
            local count      = entry.count or 1
            totalVendor      = totalVendor + (unitVendor * count)
            totalAH          = totalAH + (unitAH * count)
        end
    end

    state.vendorCopper = totalVendor
    state.ahCopper     = totalAH
end

local function GetHourlyRunCount()
    local now = time()
    local fresh = {}
    for _, ts in ipairs(state.runTimestamps) do
        if (now - ts) < 3600 then
            table.insert(fresh, ts)
        end
    end
    state.runTimestamps = fresh
    return #fresh
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
        table.insert(state.runTimestamps, time())
    end
    state.runTime = 0
end

local function ApplyTheme()
    local Utils = ns.Utils
    Utils.ApplyBackdropTheme(uiFrame, false, true)
    Utils.ApplyBackdropTheme(uiFrame and uiFrame.lootToggleBtn, true, true)
    Utils.ApplyBackdropTheme(postMenu, false, false)
    if ns.LootWindow then ns.LootWindow:ApplyTheme() end
end

local function ApplyLockState()
    if not uiFrame then return end
    local locked    = (ns.db.timerLocked == true)
    local clickThru = locked and (ns.db.compactMode == true) and (ns.db.compactClickThru == true)

    uiFrame:EnableMouse(not clickThru)

    if uiFrame.resizeBtn then
        if locked then uiFrame.resizeBtn:Hide() else uiFrame.resizeBtn:Show() end
    end

    if uiFrame.lockBtn then
        if locked then
            uiFrame.lockBtn:SetNormalTexture("Interface\\Buttons\\LockButton-Locked-Up")
            uiFrame.lockBtn:SetPushedTexture("Interface\\Buttons\\LockButton-Locked-Down")
        else
            uiFrame.lockBtn:SetNormalTexture("Interface\\Buttons\\LockButton-Unlocked-Up")
            uiFrame.lockBtn:SetPushedTexture("Interface\\Buttons\\LockButton-Unlocked-Down")
        end
    end
end

local function ApplyFontSize()
    if not uiFrame then return end

    local targetPx = tonumber(ns.db.timerFontSize) or BASE_FONT_SIZE
    if targetPx < 8 then targetPx = 8 elseif targetPx > 64 then targetPx = 64 end

    local fontPath = ns.Utils.GetSelectedFontPath()

    uiFrame.title:SetFont(fontPath, 13, "OUTLINE")
    uiFrame.sessionTimerText:SetFont(fontPath, 16, "OUTLINE")
    uiFrame.runTimerText:SetFont(fontPath, 16, "OUTLINE")
    uiFrame.sessionLabel:SetFont(fontPath, 11, "")
    uiFrame.runLabel:SetFont(fontPath, 11, "")
    uiFrame.valModeLbl:SetFont(fontPath, 11, "")
    if uiFrame.compactText then uiFrame.compactText:SetFont(fontPath, 12, "OUTLINE") end
    if uiFrame.goalBar and uiFrame.goalBar.text then uiFrame.goalBar.text:SetFont(fontPath, 10, "OUTLINE") end

    for _, row in ipairs(uiFrame.allStatRows) do
        row.lbl:SetFont(fontPath, 11, "")
        row.val:SetFont(fontPath, 11, "")
    end

    if ns.LootWindow then ns.LootWindow:ApplyFont(fontPath) end

    local newScale = targetPx / BASE_FONT_SIZE
    local oldScale = uiFrame:GetScale() or 1
    if math.abs(newScale - oldScale) > 0.001 then
        local left = uiFrame:GetLeft()
        local top  = uiFrame:GetTop()
        uiFrame:SetScale(newScale)
        if left and top then
            local screenLeft = left * oldScale
            local screenTop  = top * oldScale
            uiFrame:ClearAllPoints()
            uiFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", screenLeft / newScale, screenTop / newScale)
            ns.db.timerPos = {
                point = "TOPLEFT",
                x     = screenLeft / newScale,
                y     = screenTop / newScale,
            }
        end
    end
end

local function ApplyLayoutMode()
    if not uiFrame then return end

    local compact     = (ns.db.compactMode == true)
    local dungeonMode = IsDungeonMode()
    local maxLvl      = ns.Utils.IsMaxLevel()

    uiFrame.dungeonCheck:SetChecked(dungeonMode)
    if uiFrame.compactBtn then
        uiFrame.compactBtn:SetText(compact and "|cff00ff00+|r" or "|cff00ccff-|r")
    end

    if compact then
        uiFrame.dungeonCheck:Hide()
        uiFrame.dungeonCheckLbl:Hide()
        uiFrame.lootToggleBtn:Hide()
        uiFrame.sessionLabel:Hide()
        uiFrame.sessionTimerText:Hide()
        uiFrame.vDiv:Hide()
        uiFrame.runLabel:Hide()
        uiFrame.runTimerText:Hide()
        uiFrame.lapBtn:Hide()
        uiFrame.div2:Hide()
        uiFrame.div3:Hide()
        uiFrame.valModeLbl:Hide()
        uiFrame.valModeBtn:Hide()
        uiFrame.goalBar:Hide()
        uiFrame.startBtn:Hide()
        uiFrame.resetBtn:Hide()
        uiFrame.postBtn:Hide()
        for _, row in ipairs(uiFrame.allStatRows) do
            row.lbl:Hide()
            row.val:Hide()
        end

        uiFrame.compactText:Show()
        uiFrame:SetHeight(52)
        return
    end

    uiFrame.compactText:Hide()
    uiFrame.dungeonCheck:Show()
    uiFrame.dungeonCheckLbl:Show()
    uiFrame.lootToggleBtn:Show()
    uiFrame.sessionLabel:Show()
    uiFrame.sessionTimerText:Show()
    uiFrame.div2:Show()
    uiFrame.div3:Show()
    uiFrame.valModeLbl:Show()
    uiFrame.valModeBtn:Show()
    uiFrame.startBtn:Show()
    uiFrame.resetBtn:Show()
    uiFrame.postBtn:Show()

    local rowStep = 16
    local y = 0

    if dungeonMode then
        uiFrame.sessionLabel:ClearAllPoints()
        uiFrame.sessionLabel:SetPoint("TOP", -62, -32)
        uiFrame.sessionTimerText:ClearAllPoints()
        uiFrame.sessionTimerText:SetPoint("TOP", -62, -46)

        uiFrame.vDiv:Show()
        uiFrame.runLabel:Show()
        uiFrame.runTimerText:Show()
        uiFrame.lapBtn:Show()
        y = -88
    else
        uiFrame.sessionLabel:ClearAllPoints()
        uiFrame.sessionLabel:SetPoint("TOP", 0, -32)
        uiFrame.sessionTimerText:ClearAllPoints()
        uiFrame.sessionTimerText:SetPoint("TOP", 0, -46)

        uiFrame.vDiv:Hide()
        uiFrame.runLabel:Hide()
        uiFrame.runTimerText:Hide()
        uiFrame.lapBtn:Hide()
        y = -72
    end

    uiFrame.div2:ClearAllPoints()
    uiFrame.div2:SetPoint("TOP", 0, y)
    y = y - 8

    local function PlaceRow(row, visible)
        if visible then
            row.lbl:ClearAllPoints()
            row.lbl:SetPoint("TOPLEFT", 12, y)
            row.val:ClearAllPoints()
            row.val:SetPoint("TOPRIGHT", -12, y)
            row.lbl:Show()
            row.val:Show()
            y = y - rowStep
        else
            row.lbl:Hide()
            row.val:Hide()
        end
    end

    PlaceRow(uiFrame.rows.totalRuns, dungeonMode and ns.db.showTotalRuns ~= false)
    PlaceRow(uiFrame.rows.rph,       dungeonMode and ns.db.showRunsPerHour ~= false)
    PlaceRow(uiFrame.rows.lastRun,   dungeonMode)
    PlaceRow(uiFrame.rows.fastRun,   dungeonMode and ns.db.showFastestRun ~= false)
    PlaceRow(uiFrame.rows.lockout,   dungeonMode and ns.db.showLockoutWarning ~= false)

    PlaceRow(uiFrame.rows.raw,     true)
    PlaceRow(uiFrame.rows.vendor,  true)
    PlaceRow(uiFrame.rows.ah,      ns.Pricing.HasAnyAHAddon())
    PlaceRow(uiFrame.rows.repairs, ns.db.showRepairCosts ~= false)

    y = y - 2
    uiFrame.div3:ClearAllPoints()
    uiFrame.div3:SetPoint("TOP", 0, y)
    y = y - 8

    uiFrame.valModeLbl:ClearAllPoints()
    uiFrame.valModeLbl:SetPoint("TOPLEFT", 12, y - 2)
    uiFrame.valModeBtn:ClearAllPoints()
    uiFrame.valModeBtn:SetPoint("TOPRIGHT", -12, y + 1)
    y = y - 22

    PlaceRow(uiFrame.rows.total, ns.db.showTotalGold ~= false)
    PlaceRow(uiFrame.rows.gph,   true)
    PlaceRow(uiFrame.rows.xph,   (not maxLvl) and ns.db.showXpPerHour ~= false)
    PlaceRow(uiFrame.rows.ttl,   (not maxLvl) and ns.db.showTimeToLevel ~= false)
    PlaceRow(uiFrame.rows.bags,  ns.db.showBagSpace ~= false)

    if ns.db.showGoalBar then
        y = y - 4
        uiFrame.goalBar:ClearAllPoints()
        uiFrame.goalBar:SetPoint("TOP", 0, y)
        uiFrame.goalBar:Show()
        y = y - 20
    else
        uiFrame.goalBar:Hide()
    end

    local totalHeight = math.abs(y) + 40
    uiFrame:SetHeight(totalHeight)
    if ns.LootWindow then ns.LootWindow:SetHeight(totalHeight) end
end

local function UpdateDisplay()
    if not uiFrame or not uiFrame:IsShown() then return end

    local Utils        = ns.Utils
    local Pricing      = ns.Pricing
    local useVendor    = Pricing.IsVendorOnlyMode()
    local itemTotal    = useVendor and state.vendorCopper or state.ahCopper
    local repairCopper = state.repairCopper or 0
    local netCopper    = (state.rawCopper + itemTotal) - repairCopper
    local gphCopper    = 0
    local rph          = 0
    local xph          = 0

    if state.sessionTime >= 1 then
        local sessionHours = state.sessionTime / 3600
        gphCopper = netCopper / sessionHours
        rph       = state.completedRuns / sessionHours
        xph       = (state.sessionXP or 0) / sessionHours
    end

    uiFrame.sessionTimerText:SetText(Utils.FormatTime(state.sessionTime))
    uiFrame.runTimerText:SetText(Utils.FormatTime(state.runTime))
    uiFrame.runLabel:SetText(string.format("|cff00ccffRun #%d|r", state.runCount))

    uiFrame.rows.totalRuns.val:SetText(tostring(state.completedRuns))
    uiFrame.rows.rph.val:SetText(string.format("%.1f/hr", rph))
    uiFrame.rows.lastRun.val:SetText(Utils.FormatTime(state.lastRunTime))
    uiFrame.rows.fastRun.val:SetText(state.fastestRunTime and ("|cff00ff00" .. Utils.FormatTime(state.fastestRunTime) .. "|r") or "--:--")

    local hourlyRuns = GetHourlyRunCount()
    if hourlyRuns >= 5 then
        uiFrame.rows.lockout.val:SetText("|cffff3333LOCKOUT! (" .. hourlyRuns .. "/5)|r")
    elseif hourlyRuns == 4 then
        uiFrame.rows.lockout.val:SetText("|cffffaa00Warning (" .. hourlyRuns .. "/5)|r")
    else
        uiFrame.rows.lockout.val:SetText("|cff00ff00Safe (" .. hourlyRuns .. "/5)|r")
    end

    uiFrame.rows.raw.val:SetText(Utils.FormatMoneyUI(state.rawCopper))
    uiFrame.rows.vendor.val:SetText(Utils.FormatMoneyUI(state.vendorCopper))
    uiFrame.rows.ah.val:SetText(Utils.FormatMoneyUI(state.ahCopper))
    uiFrame.rows.repairs.val:SetText(repairCopper > 0 and ("|cffff5555-|r" .. Utils.FormatMoneyUI(repairCopper)) or "0c")

    if not Pricing.HasAnyAHAddon() then
        uiFrame.valModeBtn:SetText("|cffaaaaaaVendor + Raw|r")
    elseif useVendor then
        uiFrame.valModeBtn:SetText("|cffffd700Vendor + Raw|r")
    else
        uiFrame.valModeBtn:SetText("|cff00ccffAH + Raw|r")
    end

    uiFrame.rows.total.val:SetText(Utils.FormatMoneyUI(netCopper))
    uiFrame.rows.gph.val:SetText(Utils.FormatMoneyUI(gphCopper) .. "/hr")
    uiFrame.rows.xph.val:SetText("|cffc080ff" .. Utils.FormatXP(xph) .. "/hr|r")

    if xph > 0 and not Utils.IsMaxLevel() then
        local remXP = (UnitXPMax("player") or 0) - (UnitXP("player") or 0)
        local ttlSec = (remXP / xph) * 3600
        uiFrame.rows.ttl.val:SetText("|cffc080ff" .. Utils.FormatTTL(ttlSec) .. "|r")
    else
        uiFrame.rows.ttl.val:SetText("|cffaaaaaa--:--|r")
    end

    local freeSlots = Utils.GetFreeBagSlots()
    if freeSlots == 0 then
        uiFrame.rows.bags.val:SetText("|cffff33330 (FULL!)|r")
    elseif freeSlots <= 5 then
        uiFrame.rows.bags.val:SetText("|cffff8800" .. freeSlots .. " Free|r")
    else
        uiFrame.rows.bags.val:SetText("|cff00ff00" .. freeSlots .. " Free|r")
    end

    local goalCopper = tonumber(ns.db.sessionGoalCopper) or 1000000
    if goalCopper > 0 then
        local pct = math.max(0, (netCopper / goalCopper) * 100)
        uiFrame.goalBar:SetValue(math.min(pct, 100))
        if pct >= 100 then
            uiFrame.goalBar:SetStatusBarColor(0.15, 0.85, 0.25, 0.9)
        else
            uiFrame.goalBar:SetStatusBarColor(0.0, 0.72, 0.95, 0.9)
        end
        uiFrame.goalBar.text:SetText(string.format("Goal: %s / %s (%.0f%%)", Utils.FormatMoneyPlain(math.max(0, netCopper)), Utils.FormatMoneyPlain(goalCopper), pct))
    else
        uiFrame.goalBar:SetValue(0)
        uiFrame.goalBar.text:SetText("Goal: Not Set")
    end

    local statusDot = state.isRunning and "|cff00ff00*|r " or "|cffffaa00|| |r"
    uiFrame.compactText:SetText(statusDot .. Utils.FormatTime(state.sessionTime) .. "  |cff555555/|r  " .. Utils.FormatMoneyUI(gphCopper) .. "/hr")

    if state.isRunning then
        uiFrame.startBtn:SetText("|cffffaa00Pause|r")
    else
        uiFrame.startBtn:SetText("|cff00ff00Start|r")
    end
end

local function ProcessLootedItem(itemID, count, retryIfUncached)
    if not itemID or OPENABLE_CONTAINERS[itemID] then return end

    local Utils   = ns.Utils
    local Pricing = ns.Pricing
    local itemName, cleanLink, itemQuality, _, _, _, _, _, _, itemTexture, sellPrice, _, _, bindType = Utils.SafeGetItemInfo(itemID)

    if not itemName and retryIfUncached then
        DebugPrint("Item uncached, queuing ID: " .. tostring(itemID))
        pendingItems[itemID] = (pendingItems[itemID] or 0) + count
        return
    end

    sellPrice = tonumber(sellPrice) or 0
    local isBoP = (bindType == 1)

    local unitAH = Pricing.GetItemAHValue(itemID, cleanLink, sellPrice, isBoP)
    local itemVendorTotal = sellPrice * count
    local itemAHTotal     = unitAH * count

    local key = tostring(itemID)
    local entry = state.lootLog[key]
    if entry then
        entry.count      = (entry.count or 0) + count
        entry.vendorUnit = sellPrice
        entry.ahUnit     = unitAH
        entry.quality    = itemQuality or entry.quality or 1
        if cleanLink then entry.link = cleanLink end
        if itemTexture then entry.icon = itemTexture end
    else
        state.lootLog[key] = {
            itemID     = itemID,
            name       = itemName or ("Item #" .. key),
            link       = cleanLink,
            icon       = itemTexture,
            quality    = itemQuality or 1,
            count      = count,
            vendorUnit = sellPrice,
            ahUnit     = unitAH,
            isBoP      = isBoP,
        }
    end

    if not Pricing.IsItemBlocked(itemID, state.sessionIgnored) then
        state.vendorCopper = state.vendorCopper + itemVendorTotal
        state.ahCopper     = state.ahCopper + itemAHTotal

        if ns.db.dropAlertEnabled then
            local threshold = tonumber(ns.db.dropAlertThreshold) or 20000
            local dropVal   = Pricing.IsVendorOnlyMode() and itemVendorTotal or itemAHTotal
            if dropVal >= threshold then
                if ns.LootWindow then
                    ns.LootWindow:ShowDropAlert(cleanLink, itemName, itemTexture, dropVal, count)
                end
                local label = cleanLink or itemName or ("Item #" .. key)
                if count > 1 then label = label .. " x" .. count end
                ns:Print("|cffffd700High-Value Drop:|r " .. label .. " (" .. Utils.FormatMoneyUI(dropVal) .. ")")
            end
        end
    end

    UpdateDisplay()
    if ns.LootWindow then ns.LootWindow:UpdateList() end
end

local function SaveCurrentSessionToHistory()
    if (state.sessionTime or 0) < 10 then return end
    local histMod = ns.Modules["History"]
    if not (histMod and histMod.SaveSession) then return end

    local useVendor    = ns.Pricing.IsVendorOnlyMode()
    local itemTotal    = useVendor and state.vendorCopper or state.ahCopper
    local repairCopper = state.repairCopper or 0
    local netCopper    = (state.rawCopper + itemTotal) - repairCopper
    local sessionHours = state.sessionTime / 3600
    local gphCopper    = (sessionHours > 0) and (netCopper / sessionHours) or 0
    local itemCounts = {}
    for _, entry in pairs(state.lootLog) do
        if entry.itemID and (entry.count or 0) > 0 and not ns.Pricing.IsItemBlocked(entry.itemID, state.sessionIgnored) then
            itemCounts[entry.itemID] = (itemCounts[entry.itemID] or 0) + entry.count
        end
    end

    histMod:SaveSession({
        timestamp    = time(),
        dateStr      = date("%m/%d %H:%M"),
        zone         = GetRealZoneText() or "Unknown",
        charName     = UnitName("player") or "",
        duration     = state.sessionTime,
        dungeonMode  = IsDungeonMode(),
        runs         = state.completedRuns or 0,
        rawCopper    = state.rawCopper or 0,
        vendorCopper = state.vendorCopper or 0,
        ahCopper     = state.ahCopper or 0,
        repairCopper = repairCopper,
        netCopper    = netCopper,
        gphCopper    = gphCopper,
        items        = itemCounts,
        modeTag      = useVendor and "Vendor" or "AH",
        sessionXP    = state.sessionXP or 0,
    })
end

local function BuildSummaryString()
    local Utils        = ns.Utils
    local useVendor    = ns.Pricing.IsVendorOnlyMode()
    local itemTotal    = useVendor and state.vendorCopper or state.ahCopper
    local modeTag      = useVendor and "Vendor" or "AH"
    local repairCopper = state.repairCopper or 0
    local netCopper    = (state.rawCopper + itemTotal) - repairCopper
    local sessionHours = (state.sessionTime >= 1) and (state.sessionTime / 3600) or 0
    local gphCopper    = (sessionHours > 0) and (netCopper / sessionHours) or 0
    local rph          = (sessionHours > 0) and (state.completedRuns / sessionHours) or 0
    local zoneName     = GetRealZoneText() or "Farm Run"

    local runInfo = ""
    if IsDungeonMode() then
        local lastStr = state.lastRunTime and (", Last: " .. Utils.FormatTime(state.lastRunTime)) or ""
        local fastStr = state.fastestRunTime and (", Best: " .. Utils.FormatTime(state.fastestRunTime)) or ""
        runInfo = string.format(" [Runs: %d (%.1f/hr)%s%s]", state.completedRuns, rph, lastStr, fastStr)
    end

    local repairInfo = (repairCopper > 0) and (" // Repairs: -" .. Utils.FormatMoneyPlain(repairCopper)) or ""

    return string.format(
        "[Farm Tracker] %s - Session: %s%s // Net (%s+Raw): %s (%s/hr) // Raw: %s // Vendor: %s // AH/Est: %s%s",
        zoneName,
        Utils.FormatTime(state.sessionTime),
        runInfo,
        modeTag,
        Utils.FormatMoneyPlain(netCopper),
        Utils.FormatMoneyPlain(gphCopper),
        Utils.FormatMoneyPlain(state.rawCopper),
        Utils.FormatMoneyPlain(state.vendorCopper),
        Utils.FormatMoneyPlain(state.ahCopper),
        repairInfo
    )
end

local function SendSummaryToChannel(chatType)
    if chatType == "PARTY" and not IsInGroup() then
        ns:Print(ns.Colors.red .. "You are not currently in a party." .. ns.Colors.reset)
        return
    end
    if chatType == "GUILD" and not IsInGuild() then
        ns:Print(ns.Colors.red .. "You are not currently in a guild." .. ns.Colors.reset)
        return
    end
    SendChatMessage(BuildSummaryString(), chatType)
end

local function TogglePostMenu(anchorBtn)
    if not postMenu then
        local m = CreateFrame("Frame", "FarmTrackerPostMenu", UIParent, "BackdropTemplate")
        m:SetSize(134, 145)
        m:SetFrameStrata("DIALOG")
        m:SetClampedToScreen(true)
        ns.Utils.ApplyBackdropTheme(m, false, false)

        local header = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        header:SetPoint("TOP", 0, -7)
        header:SetText("|cff00ccffPost Summary To:|r")

        local function MakeChannelBtn(label, yOffset, onClick)
            local b = CreateFrame("Button", nil, m, "UIPanelButtonTemplate")
            b:SetSize(114, 20)
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
        MakeChannelBtn("|cffffd700Copy (Ctrl+C)|r", -93, function()
            ns.Utils.ShowCopyPopup(BuildSummaryString(), "|cff00ccffCopy Live Summary|r")
        end)
        MakeChannelBtn("|cffff6666Cancel|r", -118, nil)

        m:Hide()
        postMenu = m
    end

    if postMenu:IsShown() then
        postMenu:Hide()
    else
        ns.Utils.ApplyBackdropTheme(postMenu, false, false)
        postMenu:ClearAllPoints()
        postMenu:SetPoint("TOP", anchorBtn, "BOTTOM", 0, -4)
        postMenu:Show()
    end
end

local function CreateTimerUI()
    if uiFrame then return uiFrame end

    local f = CreateFrame("Frame", "FarmTrackerFrame", UIParent, "BackdropTemplate")
    f:SetSize(BASE_WIDTH, 340)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)

    local pos = ns.db.timerPos or { point = "CENTER", x = 0, y = 120 }
    if pos.point == "TOPLEFT" then
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y)
    else
        f:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    end

    f:SetScript("OnDragStart", function(self)
        if not ns.db.timerLocked then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local left, top = self:GetLeft(), self:GetTop()
        if left and top then
            ns.db.timerPos = { point = "TOPLEFT", x = left, y = top }
        else
            local point, _, _, x, y = self:GetPoint()
            ns.db.timerPos = { point = point, x = x, y = y }
        end
    end)

    -- Header Bar
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText("|cff00ccffFarm|r Tracker")
    f.title = title

    local closeBtn = CreateFrame("Button", nil, f)
    closeBtn:SetSize(18, 18)
    closeBtn:SetPoint("TOPRIGHT", -6, -6)
    closeBtn:SetNormalFontObject("GameFontNormal")
    closeBtn:SetText("|cffff5555X|r")
    closeBtn:SetScript("OnClick", function()
        state.isShown = false
        if postMenu then postMenu:Hide() end
        if ns.LootWindow then ns.LootWindow:HideMenus() end
        f:Hide()
    end)

    local optBtn = CreateFrame("Button", nil, f)
    optBtn:SetSize(16, 16)
    optBtn:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)
    optBtn:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    optBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    optBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Open Settings", 1, 1, 1)
        GameTooltip:Show()
    end)
    optBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    optBtn:SetScript("OnClick", function()
        local optMod = ns.Modules["Options"]
        if optMod and optMod.ToggleUI then optMod:ToggleUI() end
    end)

    local histBtn = CreateFrame("Button", nil, f)
    histBtn:SetSize(16, 16)
    histBtn:SetPoint("RIGHT", optBtn, "LEFT", -3, 0)
    histBtn:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
    histBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    histBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Session History Log", 1, 1, 1)
        GameTooltip:Show()
    end)
    histBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    histBtn:SetScript("OnClick", function()
        local histMod = ns.Modules["History"]
        if histMod and histMod.ToggleUI then histMod:ToggleUI() end
    end)

    local ffBtn = CreateFrame("Button", nil, f)
    ffBtn:SetSize(16, 16)
    ffBtn:SetPoint("RIGHT", histBtn, "LEFT", -3, 0)
    ffBtn:SetNormalTexture("Interface\\Icons\\INV_Misc_Map_01")
    ffBtn:GetNormalTexture():SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ffBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    ffBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Open Farm Finder (/ft farms)", 1, 1, 1)
        GameTooltip:Show()
    end)
    ffBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ffBtn:SetScript("OnClick", function()
        local ffMod = ns.Modules["FarmFinder"]
        if ffMod and ffMod.ToggleUI then ffMod:ToggleUI() end
    end)

    local lockBtn = CreateFrame("Button", nil, f)
    lockBtn:SetSize(18, 18)
    lockBtn:SetPoint("RIGHT", ffBtn, "LEFT", -2, 0)
    lockBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    lockBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(ns.db.timerLocked and "Unlock Window (Position & Size)" or "Lock Window (Position & Size)", 1, 1, 1)
        GameTooltip:Show()
    end)
    lockBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    lockBtn:SetScript("OnClick", function()
        ns.db.timerLocked = not ns.db.timerLocked
        ApplyLockState()
        local optMod = ns.Modules["Options"]
        if optMod and optMod.SyncLockState then optMod:SyncLockState() end
    end)
    f.lockBtn = lockBtn

    local compactBtn = CreateFrame("Button", nil, f)
    compactBtn:SetSize(16, 16)
    compactBtn:SetPoint("RIGHT", lockBtn, "LEFT", -2, 0)
    compactBtn:SetNormalFontObject("GameFontNormal")
    compactBtn:SetText("|cff00ccff-|r")
    compactBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(ns.db.compactMode and "Expand Full Tracker" or "Switch to Compact Mode", 1, 1, 1)
        GameTooltip:Show()
    end)
    compactBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    compactBtn:SetScript("OnClick", function()
        ns.db.compactMode = not ns.db.compactMode
        ApplyLayoutMode()
        ApplyLockState()
        UpdateDisplay()
        if ns.LootWindow then ns.LootWindow:UpdateVisibility(f) end
    end)
    f.compactBtn = compactBtn

    local dungeonCheck = CreateFrame("CheckButton", "FarmTrackerDungeonCheck", f, "UICheckButtonTemplate")
    dungeonCheck:SetSize(18, 18)
    dungeonCheck:SetPoint("RIGHT", compactBtn, "LEFT", -34, 0)
    dungeonCheck:SetScript("OnClick", function(self)
        ns.db.timerDungeonMode = self:GetChecked() and true or false
        ApplyLayoutMode()
        UpdateDisplay()
    end)

    local dungeonCheckLbl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dungeonCheckLbl:SetPoint("LEFT", dungeonCheck, "RIGHT", -1, 0)
    dungeonCheckLbl:SetText("|cffccccccDung|r")
    f.dungeonCheck    = dungeonCheck
    f.dungeonCheckLbl = dungeonCheckLbl

    local lootToggleBtn = CreateFrame("Button", "FarmTrackerLootToggle", f, "BackdropTemplate")
    lootToggleBtn:SetSize(18, 48)
    lootToggleBtn:SetPoint("TOPLEFT", f, "TOPRIGHT", -1, -24)
    lootToggleBtn:SetNormalFontObject("GameFontNormal")
    lootToggleBtn:SetText(">")
    lootToggleBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.db.timerLootOpen and "Hide Loot Window" or "Show Loot Window", 1, 1, 1)
        GameTooltip:Show()
    end)
    lootToggleBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    lootToggleBtn:SetScript("OnClick", function()
        ns.db.timerLootOpen = not ns.db.timerLootOpen
        if ns.LootWindow then ns.LootWindow:UpdateVisibility(f) end
    end)
    f.lootToggleBtn = lootToggleBtn

    if ns.LootWindow then ns.LootWindow:Create(f, lootToggleBtn) end

    local div1 = f:CreateTexture(nil, "ARTWORK")
    div1:SetColorTexture(0.25, 0.25, 0.3, 0.8)
    div1:SetSize(256, 1)
    div1:SetPoint("TOP", 0, -26)
    f.div1 = div1

    local compactText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    compactText:SetPoint("TOP", 0, -32)
    compactText:SetText("00:00  |  0c/hr")
    compactText:Hide()
    f.compactText = compactText

    local sessionLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sessionLabel:SetText("|cffaaaaaaSession Total|r")
    f.sessionLabel = sessionLabel

    local sessionTimerText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
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
    div2:SetSize(256, 1)
    f.div2 = div2

    f.rows = {}
    f.allStatRows = {}
    local function CreateStatRow(key, label, defaultVal)
        local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetText(label)
        local val = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        val:SetText(defaultVal or "0c")
        local row = { lbl = lbl, val = val }
        f.rows[key] = row
        table.insert(f.allStatRows, row)
        return row
    end

    CreateStatRow("totalRuns", "|cffaaaaaaTotal Runs:|r", "0")
    CreateStatRow("rph",       "|cffaaaaaaRuns / Hour:|r", "0.0/hr")
    CreateStatRow("lastRun",   "|cffaaaaaaLast Run Clear:|r", "--:--")
    CreateStatRow("fastRun",   "|cffaaaaaaFastest Run:|r", "--:--")
    CreateStatRow("lockout",   "|cffaaaaaaHourly Lockout:|r", "|cff00ff00Safe (0/5)|r")
    CreateStatRow("raw",       "|cffaaaaaaRaw Looted Coin:|r", "0c")
    CreateStatRow("vendor",    "|cffaaaaaaItems (Vendor):|r", "0c")
    CreateStatRow("ah",        "|cffaaaaaaItems (AH / Est):|r", "0c")
    CreateStatRow("repairs",   "|cffff6666Repair Costs:|r", "0c")
    CreateStatRow("total",     "|cffffd700Net Session Profit:|r", "0c")
    CreateStatRow("gph",       "|cff00ccffNet Gold / Hr:|r", "0c/hr")
    CreateStatRow("xph",       "|cffc080ffSession XP / Hr:|r", "0/hr")
    CreateStatRow("ttl",       "|cffc080ffTime to Level:|r", "--:--")
    CreateStatRow("bags",      "|cffaaaaaaFree Bag Slots:|r", "0 Free")

    local div3 = f:CreateTexture(nil, "ARTWORK")
    div3:SetColorTexture(0.25, 0.25, 0.3, 0.8)
    div3:SetSize(256, 1)
    f.div3 = div3

    local valModeLbl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valModeLbl:SetText("|cffaaaaaaGPH Source:|r")
    f.valModeLbl = valModeLbl

    local valModeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    valModeBtn:SetSize(98, 18)
    valModeBtn:SetNormalFontObject("GameFontHighlightSmall")
    valModeBtn:SetText("|cff00ccffAH + Raw|r")
    valModeBtn:SetScript("OnClick", function()
        if not ns.Pricing.HasAnyAHAddon() then
            ns:Print("Install TradeSkillMaster or Auctionator to enable AH valuation. Using Vendor + Raw.")
            return
        end
        ns.db.timerVendorOnly = not ns.db.timerVendorOnly
        UpdateDisplay()
        if ns.LootWindow then ns.LootWindow:UpdateList() end
    end)
    f.valModeBtn = valModeBtn

    local goalBar = CreateFrame("StatusBar", nil, f)
    goalBar:SetSize(252, 16)
    goalBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    goalBar:SetMinMaxValues(0, 100)
    goalBar:SetValue(0)
    goalBar:SetStatusBarColor(0.0, 0.72, 0.95, 0.9)

    local goalBg = goalBar:CreateTexture(nil, "BACKGROUND")
    goalBg:SetAllPoints()
    goalBg:SetColorTexture(0.12, 0.12, 0.16, 0.9)

    local goalText = goalBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    goalText:SetPoint("CENTER", 0, 0)
    goalText:SetText("Goal: 0c / 100g (0%)")
    goalBar.text = goalText
    f.goalBar = goalBar

    local function CreateActionButton(text, width, xOffset, onClick)
        local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btn:SetSize(width, 22)
        btn:SetPoint("BOTTOMLEFT", xOffset, 10)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        return btn
    end

    f.startBtn = CreateActionButton("|cff00ff00Start|r", 80, 10, function()
        autoPausedReason = nil
        state.isRunning  = not state.isRunning
        if state.isRunning then state.lastSaveTime = GetTime() end
        UpdateDisplay()
    end)

    f.resetBtn = CreateActionButton("Reset", 80, 98, function()
        SaveCurrentSessionToHistory()
        autoPausedReason     = nil
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
        state.repairCopper   = 0
        state.sessionXP      = 0
        state.lastSaveTime   = GetTime()
        wipe(state.lootLog)
        wipe(state.sessionIgnored)
        wipe(pendingItems)
        if postMenu then postMenu:Hide() end
        if ns.LootWindow then
            ns.LootWindow:HideMenus()
            ns.LootWindow:UpdateList()
        end
        UpdateDisplay()
    end)

    f.postBtn = CreateActionButton("|cff00ccffPost|r", 80, 186, function(self)
        TogglePostMenu(self)
    end)

    local resizeBtn = CreateFrame("Button", nil, f)
    resizeBtn:SetSize(14, 14)
    resizeBtn:SetPoint("BOTTOMRIGHT", -2, 2)
    resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    f.resizeBtn = resizeBtn

    resizeBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Drag to resize window & font", 1, 1, 1)
        GameTooltip:Show()
    end)
    resizeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    resizeBtn:SetScript("OnMouseDown", function(self, btn)
        if btn ~= "LeftButton" or ns.db.timerLocked then return end
        local startScale = f:GetScale() or 1
        local screenLeft = (f:GetLeft() or 0) * startScale
        local uiScale    = UIParent:GetEffectiveScale()

        self:SetScript("OnUpdate", function()
            local cx = GetCursorPosition() / uiScale
            local desiredWidth = cx - screenLeft
            local newScale = desiredWidth / BASE_WIDTH
            local newPx = math.floor((newScale * BASE_FONT_SIZE) + 0.5)
            if newPx < 8 then newPx = 8 elseif newPx > 64 then newPx = 64 end

            if newPx ~= ns.db.timerFontSize then
                ns.db.timerFontSize = newPx
                ApplyFontSize()
                local optMod = ns.Modules["Options"]
                if optMod and optMod.SyncFontSize then optMod:SyncFontSize(newPx) end
            end
        end)
    end)
    resizeBtn:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)

    local accum = 0
    f:SetScript("OnUpdate", function(_, dt)
        if not state.isRunning then return end
        state.sessionTime = state.sessionTime + dt
        if IsDungeonMode() then state.runTime = state.runTime + dt end
        accum = accum + dt
        if accum >= 0.2 then
            accum = 0
            state.lastSaveTime = GetTime()
            UpdateDisplay()
        end
    end)

    uiFrame = f
    ApplyTheme()
    ApplyLayoutMode()
    ApplyFontSize()
    ApplyLockState()

    if state.isShown then
        f:Show()
        UpdateDisplay()
    else
        f:Hide()
    end

    if ns.LootWindow then ns.LootWindow:UpdateVisibility(f) end
    return f
end

function mod:OnLootBlacklistChanged()
    RecalculateLootTotals()
    UpdateDisplay()
    if ns.LootWindow then ns.LootWindow:UpdateList() end
end

function mod:RefreshSettings()
    if not uiFrame then return end
    RecalculateLootTotals()
    ApplyTheme()
    ApplyLayoutMode()
    ApplyFontSize()
    ApplyLockState()
    UpdateDisplay()
    if ns.LootWindow then ns.LootWindow:UpdateList() end
end

function mod:ToggleUI()
    local f = CreateTimerUI()
    if f:IsShown() then
        state.isShown = false
        if postMenu then postMenu:Hide() end
        if ns.LootWindow then ns.LootWindow:HideMenus() end
        f:Hide()
        if ns.LootWindow then ns.LootWindow:UpdateVisibility(f) end
    else
        state.isShown = true
        ApplyLayoutMode()
        ApplyFontSize()
        ApplyLockState()
        f:Show()
        UpdateDisplay()
        if ns.LootWindow then ns.LootWindow:UpdateVisibility(f) end
    end
end

function mod:ToggleStartPause()
    autoPausedReason = nil
    state.isRunning  = not state.isRunning
    if state.isRunning then state.lastSaveTime = GetTime() end
    UpdateDisplay()
end

function mod:TriggerNewRun()
    if IsDungeonMode() then
        StartNextRun()
        UpdateDisplay()
    end
end

function mod:ToggleCompact()
    local f = CreateTimerUI()
    ns.db.compactMode = not ns.db.compactMode
    ApplyLayoutMode()
    ApplyLockState()
    UpdateDisplay()
    if ns.LootWindow then ns.LootWindow:UpdateVisibility(f) end
end

function mod:ToggleDebug()
    debugMode = not debugMode
    ns:Print("Tracker debug mode: " .. (debugMode and "|cff00ff00ON|r" or "|cffff3333OFF|r"))
end

function mod:TestDropAlert()
    if ns.LootWindow then
        ns.LootWindow:ShowDropAlert("|cffa335ee[Test Epic Drop]|r", "Test Epic Drop", 133784, 52500, 1)
    end
end

local function CheckAutoStartDungeon()
    local inInstance, instanceType = IsInInstance()
    local isDungeon = inInstance and (instanceType == "party")

    if isDungeon and not wasInDungeon then
        if IsDungeonMode() and ns.db.timerAutoStart and not state.isRunning then
            autoPausedReason   = nil
            state.isRunning    = true
            state.lastSaveTime = GetTime()
            if uiFrame and not uiFrame:IsShown() then
                state.isShown = true
                uiFrame:Show()
                if ns.LootWindow then ns.LootWindow:UpdateVisibility(uiFrame) end
            end
            UpdateDisplay()
            ns:Print("Entered dungeon — Farm Tracker |cff00ff00auto-started|r.")
        end
    end

    wasInDungeon = isDungeon
end

local function GetCurrentRepairCost()
    if not _G.GetRepairAllCost then return 0 end
    local cost, canRepair = GetRepairAllCost()
    if canRepair and cost and cost > 0 then
        return cost
    end
    return 0
end

local function TryMatchRepair()
    local now = GetTime()
    if pendingMoneySpent > 0 and pendingRepairDrop > 0 then
        if math.abs(pendingMoneyTime - pendingRepairDropTime) <= 2 then
            if pendingMoneySpent <= (pendingRepairDrop + 5) then
                if state.isRunning or (state.sessionTime or 0) > 0 then
                    state.repairCopper = (state.repairCopper or 0) + pendingMoneySpent
                    DebugPrint("Recorded repair cost: " .. pendingMoneySpent .. "c")
                    UpdateDisplay()
                end
                pendingMoneySpent = 0
                pendingRepairDrop = 0
            end
        end
    end

    if pendingMoneySpent > 0 and (now - pendingMoneyTime) > 2 then
        pendingMoneySpent = 0
    end
    if pendingRepairDrop > 0 and (now - pendingRepairDropTime) > 2 then
        pendingRepairDrop = 0
    end
end

function mod:OnInit()
    if not ns.db.farmTimer then return end

    InitSavedState()
    CreateTimerUI()

    lastXP         = UnitXP("player") or 0
    lastXPMax      = UnitXPMax("player") or 0
    lastLevel      = UnitLevel("player") or 1
    lastMoney      = GetMoney() or 0
    lastRepairCost = GetCurrentRepairCost()

    local tracker = CreateFrame("Frame")
    tracker:RegisterEvent("CHAT_MSG_MONEY")
    tracker:RegisterEvent("CHAT_MSG_LOOT")
    tracker:RegisterEvent("CHAT_MSG_SYSTEM")
    tracker:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    tracker:RegisterEvent("PLAYER_ENTERING_WORLD")
    tracker:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    tracker:RegisterEvent("PLAYER_XP_UPDATE")
    tracker:RegisterEvent("PLAYER_LEVEL_UP")
    tracker:RegisterEvent("MERCHANT_SHOW")
    tracker:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
    tracker:RegisterEvent("PLAYER_MONEY")
    tracker:RegisterEvent("BAG_UPDATE_DELAYED")
    tracker:RegisterEvent("PLAYER_FLAGS_CHANGED")
    tracker:RegisterEvent("PLAYER_UPDATE_RESTING")
    tracker:RegisterEvent("PLAYER_REGEN_DISABLED")
    tracker:RegisterEvent("PLAYER_LOGOUT")

    tracker:SetScript("OnEvent", function(_, event, arg1, arg2)
        if event == "PLAYER_LOGOUT" then
            state.lastSaveTime = GetTime()

        elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
            CheckAutoStartDungeon()
            lastRepairCost = GetCurrentRepairCost()

        elseif event == "BAG_UPDATE_DELAYED" then
            UpdateDisplay()

        elseif event == "PLAYER_FLAGS_CHANGED" and arg1 == "player" then
            if state.isRunning and ns.db.autoPauseAFK and UnitIsAFK("player") then
                state.isRunning  = false
                autoPausedReason = "AFK"
                UpdateDisplay()
                ns:Print("Auto-paused timer (|cffffaa00AFK|r).")
            elseif not state.isRunning and autoPausedReason == "AFK" and ns.db.autoResume and not UnitIsAFK("player") then
                state.isRunning    = true
                state.lastSaveTime = GetTime()
                autoPausedReason   = nil
                UpdateDisplay()
                ns:Print("Auto-resumed timer (|cff00ff00AFK cleared|r).")
            end

        elseif event == "PLAYER_UPDATE_RESTING" then
            if state.isRunning and ns.db.autoPauseCity and IsResting() then
                state.isRunning  = false
                autoPausedReason = "CITY"
                UpdateDisplay()
                ns:Print("Auto-paused timer (|cffffaa00Entered City / Rested Area|r).")
            elseif not state.isRunning and autoPausedReason == "CITY" and ns.db.autoResume and not IsResting() then
                state.isRunning    = true
                state.lastSaveTime = GetTime()
                autoPausedReason   = nil
                UpdateDisplay()
                ns:Print("Auto-resumed timer (|cff00ff00Left Rested Area|r).")
            end

        elseif event == "PLAYER_REGEN_DISABLED" then
            if not state.isRunning and autoPausedReason and ns.db.autoResumeCombat then
                state.isRunning    = true
                state.lastSaveTime = GetTime()
                autoPausedReason   = nil
                UpdateDisplay()
                ns:Print("Auto-resumed timer (|cff00ff00Entered Combat|r).")
            end

        elseif event == "MERCHANT_SHOW" then
            lastMoney = GetMoney() or lastMoney
            local curCost = GetCurrentRepairCost()
            if curCost > 0 then
                lastRepairCost = curCost
            end

        elseif event == "UPDATE_INVENTORY_DURABILITY" then
            local curCost = GetCurrentRepairCost()
            if curCost < lastRepairCost then
                pendingRepairDrop     = lastRepairCost - curCost
                pendingRepairDropTime = GetTime()
                lastRepairCost        = curCost
                TryMatchRepair()
            else
                lastRepairCost = curCost
            end

        elseif event == "PLAYER_MONEY" then
            local curMoney = GetMoney() or 0
            local spent    = lastMoney - curMoney
            lastMoney      = curMoney

            if spent > 0 then
                local curCost = GetCurrentRepairCost()
                if curCost < lastRepairCost then
                    pendingRepairDrop     = lastRepairCost - curCost
                    pendingRepairDropTime = GetTime()
                    lastRepairCost        = curCost
                end
                pendingMoneySpent = spent
                pendingMoneyTime  = GetTime()
                TryMatchRepair()
            end

        elseif event == "PLAYER_XP_UPDATE" then
            local curXP    = UnitXP("player") or 0
            local curXPMax = UnitXPMax("player") or 0
            local curLevel = UnitLevel("player") or lastLevel

            if state.isRunning and not ns.Utils.IsMaxLevel() then
                local gained = 0
                if curLevel > lastLevel then
                    gained = (lastXPMax - lastXP) + curXP
                else
                    gained = curXP - lastXP
                end
                if gained > 0 then
                    state.sessionXP = (state.sessionXP or 0) + gained
                    UpdateDisplay()
                end
            end

            lastXP    = curXP
            lastXPMax = curXPMax
            lastLevel = curLevel

        elseif event == "PLAYER_LEVEL_UP" then
            ApplyLayoutMode()
            UpdateDisplay()

        elseif event == "CHAT_MSG_SYSTEM" and arg1 then
            if IsDungeonMode() and string.find(arg1, "has been reset.", 1, true) then
                StartNextRun()
                UpdateDisplay()
            end

        elseif event == "CHAT_MSG_MONEY" and arg1 then
            DebugPrint("CHAT_MSG_MONEY: " .. tostring(arg1))
            if not state.isRunning then return end
            local copper = ns.Utils.ParseLootedCoin(arg1)
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

            local itemID = tonumber(string.match(lootMsg, "|Hitem:(%d+)"))
            if not itemID then return end

            local count = tonumber(string.match(lootMsg, "|h|r%s*x(%d+)") or string.match(lootMsg, "|h%s*x(%d+)")) or 1
            ProcessLootedItem(itemID, count, true)
        end
    end)
end