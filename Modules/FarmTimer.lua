local _, ns = ...

local mod = ns:RegisterModule("FarmTimer", {})

local BASE_FONT_SIZE = 11
local BASE_WIDTH     = 276

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
    lootLog        = {},
    runTimestamps  = {},
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

local QUALITY_FILTERS = {
    { minQ = 0, label = "|cffccccccAll|r" },
    { minQ = 1, label = "|cffffffffCommon+|r" },
    { minQ = 2, label = "|cff1eff00Uncommon+|r" },
    { minQ = 3, label = "|cff0070ddRare+|r" },
    { minQ = 4, label = "|cffa335eeEpic+|r" },
    { minQ = 5, label = "|cffff8000Legendary+|r" },
}

local debugMode    = false
local uiFrame      = nil
local lootFrame    = nil
local lootRows     = {}
local postMenu     = nil
local pendingItems = {}
local wasInDungeon = false

local function DebugPrint(msg)
    if debugMode then
        ns:Print("|cffffaa00[TimerDebug]|r " .. tostring(msg))
    end
end

local function SafeGetItemInfo(item)
    if _G.C_Item and _G.C_Item.GetItemInfo then
        return _G.C_Item.GetItemInfo(item)
    elseif _G.GetItemInfo then
        return _G.GetItemInfo(item)
    end
    return nil
end

local function InitSavedState()
    CrutchieTweaksDB.timerState = CrutchieTweaksDB.timerState or {}
    local saved = CrutchieTweaksDB.timerState

    for k, defaultVal in pairs(state) do
        if saved[k] == nil then
            saved[k] = (type(defaultVal) == "table") and {} or defaultVal
        end
    end

    if type(saved.lootLog) ~= "table" then saved.lootLog = {} end
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

local function GetItemAHValue(itemID, cleanLink, vendorUnitPrice, isBoP)
    if isBoP then
        return vendorUnitPrice or 0
    end

    local ahUnit = 0
    local tsmItemString = itemID and ("i:" .. itemID) or nil

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
    if ns.db.timerDungeonMode == nil then ns.db.timerDungeonMode = true end
    return ns.db.timerDungeonMode
end

local function IsVendorOnlyMode()
    return ns.db.timerVendorOnly == true
end

local function IsLootPanelOpen()
    return ns.db.timerLootOpen == true
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

local function ApplyBackdropTheme(frame, isTab)
    if not frame or not frame.SetBackdrop then return end
    if ns.db.timerTheme == "classic" then
        frame:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile     = true,
            tileSize = 32,
            edgeSize = isTab and 12 or 16,
            insets   = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        frame:SetBackdropColor(1, 1, 1, 0.95)
        frame:SetBackdropBorderColor(0.85, 0.75, 0.55, 1)
    else
        frame:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile     = false,
            edgeSize = 1,
        })
        frame:SetBackdropColor(0.06, 0.06, 0.08, 0.92)
        frame:SetBackdropBorderColor(0.2, 0.2, 0.25, 1)
    end
end

local function ApplyTheme()
    ApplyBackdropTheme(uiFrame, false)
    ApplyBackdropTheme(lootFrame, false)
    ApplyBackdropTheme(uiFrame and uiFrame.lootToggleBtn, true)
    ApplyBackdropTheme(postMenu, false)
end

local function ApplyLockState()
    if not uiFrame then return end
    local locked = (ns.db.timerLocked == true)

    if uiFrame.resizeBtn then
        if locked then
            uiFrame.resizeBtn:Hide()
        else
            uiFrame.resizeBtn:Show()
        end
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

local function GetSelectedFontPath()
    local selected = ns.db.timerFont or "Friz Quadrata"
    if ns.GetAvailableFonts then
        for _, fInfo in ipairs(ns.GetAvailableFonts()) do
            if fInfo.name == selected then
                return fInfo.path
            end
        end
    end
    return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local function ApplyFontSize()
    if not uiFrame then return end

    local targetPx = tonumber(ns.db.timerFontSize) or BASE_FONT_SIZE
    if targetPx < 8 then targetPx = 8 elseif targetPx > 64 then targetPx = 64 end

    local fontPath = GetSelectedFontPath()

    uiFrame.title:SetFont(fontPath, 13, "OUTLINE")
    uiFrame.sessionTimerText:SetFont(fontPath, 16, "OUTLINE")
    uiFrame.runTimerText:SetFont(fontPath, 16, "OUTLINE")
    uiFrame.sessionLabel:SetFont(fontPath, 11, "")
    uiFrame.runLabel:SetFont(fontPath, 11, "")
    uiFrame.valModeLbl:SetFont(fontPath, 11, "")

    for _, row in ipairs(uiFrame.allStatRows) do
        row.lbl:SetFont(fontPath, 11, "")
        row.val:SetFont(fontPath, 11, "")
    end

    if lootFrame then
        lootFrame.header:SetFont(fontPath, 13, "OUTLINE")
        for _, lRow in ipairs(lootRows) do
            lRow.nameText:SetFont(fontPath, 11, "")
            lRow.valText:SetFont(fontPath, 11, "")
        end
    end

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

local function UpdateLootList()
    if not lootFrame or not lootFrame:IsShown() then return end

    local useVendor = IsVendorOnlyMode()
    local minQual   = ns.db.timerLootMinQual or 0
    local sorted    = {}
    local totalItemCount = 0

    for _, entry in pairs(state.lootLog) do
        if entry.quality == nil and entry.itemID then
            local _, _, fetchedQuality = SafeGetItemInfo(entry.itemID)
            if fetchedQuality then
                entry.quality = fetchedQuality
            end
        end

        local q = entry.quality or 1
        if q >= minQual then
            local unitVal = useVendor and (entry.vendorUnit or 0) or (entry.ahUnit or 0)
            local rowVal  = unitVal * (entry.count or 1)
            totalItemCount = totalItemCount + (entry.count or 1)
            table.insert(sorted, {
                entry    = entry,
                totalVal = rowVal,
            })
        end
    end

    table.sort(sorted, function(a, b)
        if a.totalVal ~= b.totalVal then
            return a.totalVal > b.totalVal
        end
        return (a.entry.name or "") < (b.entry.name or "")
    end)

    lootFrame.header:SetText(string.format("|cff00ccffLoot|r |cffaaaaaa(%d)|r", totalItemCount))

    for _, qf in ipairs(QUALITY_FILTERS) do
        if qf.minQ == minQual then
            lootFrame.filterBtn:SetText(qf.label)
            break
        end
    end

    if #sorted == 0 then
        lootFrame.emptyText:Show()
    else
        lootFrame.emptyText:Hide()
    end

    local fontPath = GetSelectedFontPath()
    local rowHeight = 20
    for i, itemData in ipairs(sorted) do
        local row = lootRows[i]
        if not row then
            row = CreateFrame("Button", nil, lootFrame.scrollChild)
            row:SetHeight(rowHeight)

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.03 or 0.0)
            row.bg = bg

            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(0.2, 0.5, 0.8, 0.2)

            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(16, 16)
            icon:SetPoint("LEFT", 2, 0)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            row.icon = icon

            local valText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            valText:SetPoint("RIGHT", -4, 0)
            valText:SetJustifyH("RIGHT")
            row.valText = valText

            local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            nameText:SetPoint("LEFT", icon, "RIGHT", 5, 0)
            nameText:SetPoint("RIGHT", valText, "LEFT", -6, 0)
            nameText:SetJustifyH("LEFT")
            nameText:SetWordWrap(false)
            row.nameText = nameText

            row:SetScript("OnEnter", function(self)
                if self.itemID then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    if self.itemLink then
                        GameTooltip:SetHyperlink(self.itemLink)
                    else
                        GameTooltip:SetHyperlink("item:" .. self.itemID)
                    end
                    GameTooltip:Show()
                end
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)

            lootRows[i] = row
        end

        local e = itemData.entry
        row.itemID   = e.itemID
        row.itemLink = e.link
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", lootFrame.scrollChild, "TOPLEFT", 0, -((i - 1) * rowHeight))
        row:SetPoint("TOPRIGHT", lootFrame.scrollChild, "TOPRIGHT", 0, -((i - 1) * rowHeight))

        row.icon:SetTexture(e.icon or 134400)
        row.nameText:SetFont(fontPath, 11, "")
        row.valText:SetFont(fontPath, 11, "")

        local displayLabel = e.link or e.name or ("Item #" .. tostring(e.itemID))
        if (e.count or 1) > 1 then
            displayLabel = displayLabel .. " |cffaaaaaax" .. e.count .. "|r"
        end
        row.nameText:SetText(displayLabel)
        row.valText:SetText(FormatMoneyUI(itemData.totalVal))
        row:Show()
    end

    for i = #sorted + 1, #lootRows do
        lootRows[i]:Hide()
    end

    lootFrame.scrollChild:SetHeight(math.max(#sorted * rowHeight, 1))
end

local function UpdateLootPanelVisibility()
    if not uiFrame or not lootFrame then return end

    if IsLootPanelOpen() and uiFrame:IsShown() then
        lootFrame:SetHeight(uiFrame:GetHeight())
        lootFrame:Show()
        uiFrame.lootToggleBtn:SetText("<")
        UpdateLootList()
    else
        lootFrame:Hide()
        uiFrame.lootToggleBtn:SetText(">")
    end
end

local function ApplyLayoutMode()
    if not uiFrame then return end

    local dungeonMode = IsDungeonMode()
    uiFrame.dungeonCheck:SetChecked(dungeonMode)

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

    PlaceRow(uiFrame.rows.raw,    true)
    PlaceRow(uiFrame.rows.vendor, true)
    PlaceRow(uiFrame.rows.ah,     true)

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

    local totalHeight = math.abs(y) + 40
    uiFrame:SetHeight(totalHeight)
    if lootFrame then
        lootFrame:SetHeight(totalHeight)
    end
end

local function UpdateDisplay()
    if not uiFrame or not uiFrame:IsShown() then return end

    local useVendor   = IsVendorOnlyMode()
    local itemTotal   = useVendor and state.vendorCopper or state.ahCopper
    local totalCopper = state.rawCopper + itemTotal
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

    uiFrame.rows.totalRuns.val:SetText(tostring(state.completedRuns))
    uiFrame.rows.rph.val:SetText(string.format("%.1f/hr", rph))
    uiFrame.rows.lastRun.val:SetText(FormatTime(state.lastRunTime))
    uiFrame.rows.fastRun.val:SetText(state.fastestRunTime and ("|cff00ff00" .. FormatTime(state.fastestRunTime) .. "|r") or "--:--")

    local hourlyRuns = GetHourlyRunCount()
    if hourlyRuns >= 5 then
        uiFrame.rows.lockout.val:SetText("|cffff3333LOCKOUT! (" .. hourlyRuns .. "/5)|r")
    elseif hourlyRuns == 4 then
        uiFrame.rows.lockout.val:SetText("|cffffaa00Warning (" .. hourlyRuns .. "/5)|r")
    else
        uiFrame.rows.lockout.val:SetText("|cff00ff00Safe (" .. hourlyRuns .. "/5)|r")
    end

    uiFrame.rows.raw.val:SetText(FormatMoneyUI(state.rawCopper))
    uiFrame.rows.vendor.val:SetText(FormatMoneyUI(state.vendorCopper))
    uiFrame.rows.ah.val:SetText(FormatMoneyUI(state.ahCopper))

    if useVendor then
        uiFrame.valModeBtn:SetText("|cffffd700Vendor + Raw|r")
    else
        uiFrame.valModeBtn:SetText("|cff00ccffAH + Raw|r")
    end

    uiFrame.rows.total.val:SetText(FormatMoneyUI(totalCopper))
    uiFrame.rows.gph.val:SetText(FormatMoneyUI(gphCopper) .. "/hr")

    if state.isRunning then
        uiFrame.startBtn:SetText("|cffffaa00Pause|r")
    else
        uiFrame.startBtn:SetText("|cff00ff00Start|r")
    end
end

local function ProcessLootedItem(itemID, count, retryIfUncached)
    if not itemID or OPENABLE_CONTAINERS[itemID] then return end

    local itemName, cleanLink, itemQuality, _, _, _, _, _, _, itemTexture, sellPrice, _, _, bindType = SafeGetItemInfo(itemID)

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

    DebugPrint(string.format("Looted %s (ID:%d) x%d | Q=%s | BoP=%s | Vendor=%dc | AH=%dc", tostring(itemName), itemID, count, tostring(itemQuality), tostring(isBoP), itemVendorTotal, itemAHTotal))

    state.vendorCopper = state.vendorCopper + itemVendorTotal
    state.ahCopper     = state.ahCopper + itemAHTotal

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

    UpdateDisplay()
    UpdateLootList()
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

    local useVendor    = IsVendorOnlyMode()
    local itemTotal    = useVendor and state.vendorCopper or state.ahCopper
    local modeTag      = useVendor and "Vendor" or "AH"
    local totalCopper  = state.rawCopper + itemTotal
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
        "[Crutchie's Farm Tracker] %s - Session: %s%s // Total (%s+Raw): %s (%s/hr) // Raw: %s // Vendor: %s // AH/Est: %s",
        zoneName,
        FormatTime(state.sessionTime),
        runInfo,
        modeTag,
        FormatMoneyPlain(totalCopper),
        FormatMoneyPlain(gphCopper),
        FormatMoneyPlain(state.rawCopper),
        FormatMoneyPlain(state.vendorCopper),
        FormatMoneyPlain(state.ahCopper)
    )

    SendChatMessage(msg, chatType)
end

local function TogglePostMenu(anchorBtn)
    if not postMenu then
        local m = CreateFrame("Frame", "CrutchieFarmPostMenu", UIParent, "BackdropTemplate")
        m:SetSize(130, 122)
        m:SetFrameStrata("DIALOG")
        m:SetClampedToScreen(true)
        ApplyBackdropTheme(m, false)

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
        ApplyBackdropTheme(postMenu, false)
        postMenu:ClearAllPoints()
        postMenu:SetPoint("TOP", anchorBtn, "BOTTOM", 0, -4)
        postMenu:Show()
    end
end

local function CreateLootPanel(parentFrame, toggleTabBtn)
    if lootFrame then return lootFrame end

    local lf = CreateFrame("Frame", "CrutchieTweaksLootFrame", parentFrame, "BackdropTemplate")
    lf:SetWidth(244)
    lf:SetHeight(parentFrame:GetHeight())
    lf:SetPoint("TOPLEFT", toggleTabBtn, "TOPRIGHT", 1, 24)
    lf:SetFrameStrata("MEDIUM")
    lf:SetClampedToScreen(true)

    local header = lf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 10, -8)
    header:SetText("|cff00ccffLoot|r |cffaaaaaa(0)|r")
    lf.header = header

    local filterBtn = CreateFrame("Button", nil, lf, "UIPanelButtonTemplate")
    filterBtn:SetSize(82, 18)
    filterBtn:SetPoint("TOPRIGHT", -8, -5)
    filterBtn:SetNormalFontObject("GameFontHighlightSmall")
    filterBtn:SetText("All")
    filterBtn:SetScript("OnClick", function()
        local cur = ns.db.timerLootMinQual or 0
        local nextQ = 0
        for i, qf in ipairs(QUALITY_FILTERS) do
            if qf.minQ == cur then
                nextQ = QUALITY_FILTERS[(i % #QUALITY_FILTERS) + 1].minQ
                break
            end
        end
        ns.db.timerLootMinQual = nextQ
        UpdateLootList()
    end)
    filterBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Click to filter Loot Window by minimum item quality", 1, 1, 1)
        GameTooltip:Show()
    end)
    filterBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    lf.filterBtn = filterBtn

    local div = lf:CreateTexture(nil, "ARTWORK")
    div:SetColorTexture(0.25, 0.25, 0.3, 0.8)
    div:SetSize(224, 1)
    div:SetPoint("TOP", 0, -26)

    local scrollFrame = CreateFrame("ScrollFrame", "CrutchieFarmLootScroll", lf, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -32)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 10)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(206)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    lf.scrollFrame = scrollFrame
    lf.scrollChild = scrollChild

    local emptyText = lf:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("CENTER", 0, -6)
    emptyText:SetText("No matching items looted.")
    lf.emptyText = emptyText

    lf:Hide()
    lootFrame = lf
    return lf
end

local function CreateTimerUI()
    if uiFrame then return uiFrame end

    local f = CreateFrame("Frame", "CrutchieTweaksTimerFrame", UIParent, "BackdropTemplate")
    f:SetSize(BASE_WIDTH, 320)
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
        if not ns.db.timerLocked then
            self:StartMoving()
        end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local left = self:GetLeft()
        local top  = self:GetTop()
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
    title:SetText("|cff00ccffCrutchie's|r Farm Tracker")
    f.title = title

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

    -- Options Gear Icon Button
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

    -- Lock / Unlock Position & Size Button
    local lockBtn = CreateFrame("Button", nil, f)
    lockBtn:SetSize(18, 18)
    lockBtn:SetPoint("RIGHT", optBtn, "LEFT", -2, 0)
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

    -- Dungeon Mode Checkbox in Header
    local dungeonCheck = CreateFrame("CheckButton", "CrutchieFarmDungeonCheck", f, "UICheckButtonTemplate")
    dungeonCheck:SetSize(18, 18)
    dungeonCheck:SetPoint("RIGHT", lockBtn, "LEFT", -36, 0)
    dungeonCheck:SetScript("OnClick", function(self)
        ns.db.timerDungeonMode = self:GetChecked() and true or false
        ApplyLayoutMode()
        UpdateDisplay()
    end)

    local dungeonCheckLbl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dungeonCheckLbl:SetPoint("LEFT", dungeonCheck, "RIGHT", -1, 0)
    dungeonCheckLbl:SetText("|cffccccccDung|r")
    f.dungeonCheck = dungeonCheck

    -- Collapsible Side Arrow Tab for Loot Window
    local lootToggleBtn = CreateFrame("Button", "CrutchieFarmLootToggle", f, "BackdropTemplate")
    lootToggleBtn:SetSize(18, 48)
    lootToggleBtn:SetPoint("TOPLEFT", f, "TOPRIGHT", -1, -24)
    lootToggleBtn:SetNormalFontObject("GameFontNormal")
    lootToggleBtn:SetText(">")
    lootToggleBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(IsLootPanelOpen() and "Hide Loot Window" or "Show Loot Window", 1, 1, 1)
        GameTooltip:Show()
    end)
    lootToggleBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    lootToggleBtn:SetScript("OnClick", function()
        ns.db.timerLootOpen = not IsLootPanelOpen()
        UpdateLootPanelVisibility()
    end)
    f.lootToggleBtn = lootToggleBtn

    CreateLootPanel(f, lootToggleBtn)

    local div1 = f:CreateTexture(nil, "ARTWORK")
    div1:SetColorTexture(0.25, 0.25, 0.3, 0.8)
    div1:SetSize(256, 1)
    div1:SetPoint("TOP", 0, -26)

    -- Dual Timer Columns
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
    CreateStatRow("total",     "|cffffd700Total Session Value:|r", "0c")
    CreateStatRow("gph",       "|cff00ccffSession Gold / Hr:|r", "0c/hr")

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
        ns.db.timerVendorOnly = not IsVendorOnlyMode()
        UpdateDisplay()
        UpdateLootList()
    end)
    f.valModeBtn = valModeBtn

    local function CreateActionButton(text, width, xOffset, onClick)
        local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btn:SetSize(width, 22)
        btn:SetPoint("BOTTOMLEFT", xOffset, 10)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        return btn
    end

    f.startBtn = CreateActionButton("|cff00ff00Start|r", 80, 10, function()
        state.isRunning = not state.isRunning
        if state.isRunning then state.lastSaveTime = GetTime() end
        UpdateDisplay()
    end)

    f.resetBtn = CreateActionButton("Reset", 80, 98, function()
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
        wipe(state.lootLog)
        wipe(pendingItems)
        if postMenu then postMenu:Hide() end
        UpdateDisplay()
        UpdateLootList()
    end)

    f.postBtn = CreateActionButton("|cff00ccffPost|r", 80, 186, function(self)
        TogglePostMenu(self)
    end)

    -- Bottom-Right Drag-to-Resize Handle (auto-adjusts font size & syncs Options slider)
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
                if optMod and optMod.SyncFontSize then
                    optMod:SyncFontSize(newPx)
                end
            end
        end)
    end)

    resizeBtn:SetScript("OnMouseUp", function(self)
        self:SetScript("OnUpdate", nil)
    end)

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

    UpdateLootPanelVisibility()
    return f
end

function mod:RefreshSettings()
    if not uiFrame then return end
    ApplyTheme()
    ApplyLayoutMode()
    ApplyFontSize()
    ApplyLockState()
    UpdateDisplay()
    UpdateLootList()
end

function mod:ToggleUI()
    local f = CreateTimerUI()
    if f:IsShown() then
        state.isShown = false
        if postMenu then postMenu:Hide() end
        f:Hide()
        UpdateLootPanelVisibility()
    else
        state.isShown = true
        ApplyLayoutMode()
        ApplyFontSize()
        ApplyLockState()
        f:Show()
        UpdateDisplay()
        UpdateLootPanelVisibility()
    end
end

function mod:ToggleDebug()
    debugMode = not debugMode
    ns:Print("FarmTimer debug mode: " .. (debugMode and "|cff00ff00ON|r" or "|cffff3333OFF|r"))
end

local function CheckAutoStartDungeon()
    local inInstance, instanceType = IsInInstance()
    local isDungeon = inInstance and (instanceType == "party")

    if isDungeon and not wasInDungeon then
        if IsDungeonMode() and ns.db.timerAutoStart and not state.isRunning then
            state.isRunning    = true
            state.lastSaveTime = GetTime()
            if uiFrame and not uiFrame:IsShown() then
                state.isShown = true
                uiFrame:Show()
                UpdateLootPanelVisibility()
            end
            UpdateDisplay()
            ns:Print("Entered dungeon — Farm Tracker |cff00ff00auto-started|r.")
        end
    end

    wasInDungeon = isDungeon
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
    tracker:RegisterEvent("PLAYER_ENTERING_WORLD")
    tracker:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    tracker:RegisterEvent("PLAYER_LOGOUT")

    tracker:SetScript("OnEvent", function(_, event, arg1, arg2)
        if event == "PLAYER_LOGOUT" then
            state.lastSaveTime = GetTime()

        elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
            CheckAutoStartDungeon()

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

            local itemID = tonumber(string.match(lootMsg, "|Hitem:(%d+)"))
            if not itemID then return end

            local count = tonumber(string.match(lootMsg, "|h|r%s*x(%d+)") or string.match(lootMsg, "|h%s*x(%d+)")) or 1
            ProcessLootedItem(itemID, count, true)
        end
    end)
end