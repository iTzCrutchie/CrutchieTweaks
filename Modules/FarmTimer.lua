local _, ns = ...

local mod = ns:RegisterModule("FarmTimer", {})

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
    mobsKilled     = 0,
    lastSaveTime   = nil,
    lootLog        = {},
    sessionIgnored = {},
    runTimestamps  = {},
}

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

local debugMode         = false
local uiFrame           = nil
local lootFrame         = nil
local lootRows          = {}
local postMenu          = nil
local lootContextMenu   = nil
local alertFrame        = nil
local pendingItems      = {}
local wasInDungeon      = false
local lastXP            = 0
local lastXPMax         = 0
local lastLevel         = 0
local merchantOpen      = false
local lastMoney         = 0
local pendingRepairCost = 0
local pendingRepairTime = 0
local repairHooked      = false

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

local function HasTSM()
    return (_G.TSM_API and _G.TSM_API.GetCustomPriceValue) ~= nil
end

local function HasAuctionator()
    return (_G.Auctionator and _G.Auctionator.API and _G.Auctionator.API.v1) ~= nil
end

local function HasAnyAHAddon()
    return HasTSM() or HasAuctionator()
end

local function IsItemBlocked(itemID)
    if not itemID then return false end
    local key = tostring(itemID)
    if state.sessionIgnored and state.sessionIgnored[key] then return true end
    if ns.db.globalBlacklist and ns.db.globalBlacklist[key] then return true end
    return false
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

local function FormatMoneyUI(copper)
    copper = math.floor(copper or 0)
    local isNeg = copper < 0
    local absC  = math.abs(copper)
    local g = math.floor(absC / 10000)
    local s = math.floor((absC % 10000) / 100)
    local c = absC % 100
    local sign = isNeg and "|cffff4444-|r" or ""

    if g > 0 then
        return string.format("%s|cffffd700%dg|r |cffc7c7cf%ds|r", sign, g, s)
    elseif s > 0 then
        return string.format("%s|cffc7c7cf%ds|r |cffeda55f%dc|r", sign, s, c)
    else
        return string.format("%s|cffeda55f%dc|r", sign, c)
    end
end

local function FormatMoneyPlain(copper)
    copper = math.floor(copper or 0)
    local isNeg = copper < 0
    local absC  = math.abs(copper)
    local g = math.floor(absC / 10000)
    local s = math.floor((absC % 10000) / 100)
    local c = absC % 100
    local sign = isNeg and "-" or ""

    if g > 0 then
        return string.format("%s%dg %ds", sign, g, s)
    elseif s > 0 then
        return string.format("%s%ds %dc", sign, s, c)
    else
        return string.format("%s%dc", sign, c)
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

local function FormatTTL(sec)
    if not sec or sec <= 0 then return "--:--" end
    sec = math.floor(sec)
    local hrs  = math.floor(sec / 3600)
    local mins = math.floor((sec % 3600) / 60)
    local secs = sec % 60
    if hrs >= 100 then
        return ">99h"
    elseif hrs > 0 then
        return string.format("%dh %02dm", hrs, mins)
    elseif mins > 0 then
        return string.format("%dm %02ds", mins, secs)
    else
        return string.format("%ds", secs)
    end
end

local function IsMaxLevel()
    return (UnitLevel("player") or 60) >= 60
end

local function FormatXP(xp)
    xp = math.floor(xp or 0)
    if xp >= 1000000 then
        return string.format("%.2fM", xp / 1000000)
    elseif xp >= 1000 then
        return string.format("%.1fk", xp / 1000)
    end
    return tostring(xp)
end

local function GetFreeBagSlots()
    local totalFree = 0
    for bag = 0, 4 do
        local free, bagType
        if _G.C_Container and _G.C_Container.GetContainerNumFreeSlots then
            free, bagType = _G.C_Container.GetContainerNumFreeSlots(bag)
        elseif _G.GetContainerNumFreeSlots then
            free, bagType = _G.GetContainerNumFreeSlots(bag)
        end
        if free and (bagType == nil or bagType == 0) then
            totalFree = totalFree + free
        end
    end
    return totalFree
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

local function QueryTSM(priceKey, tsmItemString)
    if not (HasTSM() and tsmItemString) then return 0 end
    local ok, val = pcall(_G.TSM_API.GetCustomPriceValue, priceKey, tsmItemString)
    if ok and type(val) == "number" and val > 0 then
        return val
    end
    return 0
end

local function QueryAuctionator(itemID, cleanLink)
    if not HasAuctionator() then return 0 end
    local api = _G.Auctionator.API.v1
    if itemID and api.GetAuctionPriceByItemID then
        local ok, val = pcall(api.GetAuctionPriceByItemID, "FarmTracker", itemID)
        if ok and type(val) == "number" and val > 0 then return val end
    end
    if cleanLink and api.GetAuctionPriceByItemLink then
        local ok, val = pcall(api.GetAuctionPriceByItemLink, "FarmTracker", cleanLink)
        if ok and type(val) == "number" and val > 0 then return val end
    end
    return 0
end

local function GetItemAHValue(itemID, cleanLink, vendorUnitPrice, isBoP)
    local vendor = vendorUnitPrice or 0
    if isBoP or not HasAnyAHAddon() then
        return vendor
    end

    local source = ns.db.ahPriceSource or "AUTO"
    if source == "VENDOR" then
        return vendor
    end

    local ahUnit = 0
    local tsmItemString = itemID and ("i:" .. itemID) or nil

    if source == "TSM_MIN" then
        ahUnit = QueryTSM("DBMinBuyout", tsmItemString)
    elseif source == "TSM_MARKET" then
        ahUnit = QueryTSM("DBMarket", tsmItemString)
    elseif source == "TSM_HIST" then
        ahUnit = QueryTSM("DBHistorical", tsmItemString)
    elseif source == "AUCTIONATOR" then
        ahUnit = QueryAuctionator(itemID, cleanLink)
    else
        ahUnit = QueryTSM("DBMinBuyout", tsmItemString)
        if ahUnit == 0 then ahUnit = QueryTSM("DBMarket", tsmItemString) end
        if ahUnit == 0 then ahUnit = QueryAuctionator(itemID, cleanLink) end
    end

    if ahUnit < vendor then ahUnit = vendor end
    return ahUnit
end

local function IsDungeonMode()
    if ns.db.timerDungeonMode == nil then ns.db.timerDungeonMode = true end
    return ns.db.timerDungeonMode
end

local function IsVendorOnlyMode()
    if not HasAnyAHAddon() or ns.db.ahPriceSource == "VENDOR" then
        return true
    end
    return ns.db.timerVendorOnly == true
end

local function IsLootPanelOpen()
    return ns.db.timerLootOpen == true
end

local function RecalculateLootTotals()
    local totalVendor = 0
    local totalAH     = 0

    for key, entry in pairs(state.lootLog) do
        if not IsItemBlocked(entry.itemID or key) then
            local unitVendor = entry.vendorUnit or 0
            local unitAH     = GetItemAHValue(entry.itemID, entry.link, unitVendor, entry.isBoP)
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
    ApplyBackdropTheme(lootContextMenu, false)
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
    if uiFrame.compactText then uiFrame.compactText:SetFont(fontPath, 12, "OUTLINE") end
    if uiFrame.goalBar and uiFrame.goalBar.text then uiFrame.goalBar.text:SetFont(fontPath, 10, "OUTLINE") end

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

local UpdateDisplay
local UpdateLootList

local function ShowLootContextMenu(itemID, itemName, anchorFrame)
    if not lootContextMenu then
        local m = CreateFrame("Frame", "FarmTrackerLootContextMenu", UIParent, "BackdropTemplate")
        m:SetSize(166, 98)
        m:SetFrameStrata("TOOLTIP")
        m:SetClampedToScreen(true)
        ApplyBackdropTheme(m, false)

        local hdr = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hdr:SetPoint("TOPLEFT", 8, -7)
        hdr:SetPoint("TOPRIGHT", -8, -7)
        hdr:SetJustifyH("CENTER")
        hdr:SetWordWrap(false)
        m.hdr = hdr

        local sessBtn = CreateFrame("Button", nil, m, "UIPanelButtonTemplate")
        sessBtn:SetSize(148, 20)
        sessBtn:SetPoint("TOP", 0, -24)
        sessBtn:SetNormalFontObject("GameFontHighlightSmall")
        sessBtn:SetText("Ignore This Session")
        m.sessBtn = sessBtn

        local globBtn = CreateFrame("Button", nil, m, "UIPanelButtonTemplate")
        globBtn:SetSize(148, 20)
        globBtn:SetPoint("TOP", 0, -47)
        globBtn:SetNormalFontObject("GameFontHighlightSmall")
        globBtn:SetText("|cffffaa00Add to Global Blocklist|r")
        m.globBtn = globBtn

        local cancelBtn = CreateFrame("Button", nil, m, "UIPanelButtonTemplate")
        cancelBtn:SetSize(148, 20)
        cancelBtn:SetPoint("TOP", 0, -70)
        cancelBtn:SetNormalFontObject("GameFontHighlightSmall")
        cancelBtn:SetText("|cffff6666Cancel|r")
        cancelBtn:SetScript("OnClick", function() m:Hide() end)

        m:Hide()
        lootContextMenu = m
    end

    ApplyBackdropTheme(lootContextMenu, false)
    lootContextMenu.hdr:SetText("|cff00ccff" .. (itemName or ("Item #" .. tostring(itemID))) .. "|r")

    lootContextMenu.sessBtn:SetScript("OnClick", function()
        state.sessionIgnored[tostring(itemID)] = true
        lootContextMenu:Hide()
        RecalculateLootTotals()
        UpdateDisplay()
        UpdateLootList()
    end)

    lootContextMenu.globBtn:SetScript("OnClick", function()
        ns.db.globalBlacklist[tostring(itemID)] = itemName or tostring(itemID)
        lootContextMenu:Hide()
        RecalculateLootTotals()
        UpdateDisplay()
        UpdateLootList()
        local optMod = ns.Modules["Options"]
        if optMod and optMod.SyncBlacklistCount then optMod:SyncBlacklistCount() end
        ns:Print("Added |cffffaa00" .. (itemName or ("Item #" .. tostring(itemID))) .. "|r to Global Blocklist.")
    end)

    lootContextMenu:ClearAllPoints()
    lootContextMenu:SetPoint("TOPLEFT", anchorFrame, "TOPRIGHT", 4, 0)
    lootContextMenu:Show()
end

UpdateLootList = function()
    if not lootFrame or not lootFrame:IsShown() then return end

    local useVendor = IsVendorOnlyMode()
    local minQual   = ns.db.timerLootMinQual or 0
    local sorted    = {}
    local totalItemCount = 0

    for _, entry in pairs(state.lootLog) do
        if not IsItemBlocked(entry.itemID) then
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
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

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

            row:SetScript("OnClick", function(self, btn)
                if btn == "RightButton" and self.itemID then
                    ShowLootContextMenu(self.itemID, self.itemName, self)
                end
            end)

            row:SetScript("OnEnter", function(self)
                if self.itemID then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    if self.itemLink then
                        GameTooltip:SetHyperlink(self.itemLink)
                    else
                        GameTooltip:SetHyperlink("item:" .. self.itemID)
                    end
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("|cffaaaaaaRight-Click to ignore or blacklist|r")
                    GameTooltip:Show()
                end
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)

            lootRows[i] = row
        end

        local e = itemData.entry
        row.itemID   = e.itemID
        row.itemLink = e.link
        row.itemName = e.name
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

    if IsLootPanelOpen() and uiFrame:IsShown() and not ns.db.compactMode then
        lootFrame:SetHeight(uiFrame:GetHeight())
        lootFrame:Show()
        uiFrame.lootToggleBtn:SetText("<")
        UpdateLootList()
    else
        lootFrame:Hide()
        if lootContextMenu then lootContextMenu:Hide() end
        uiFrame.lootToggleBtn:SetText(">")
    end
end

local function ApplyLayoutMode()
    if not uiFrame then return end

    local compact     = (ns.db.compactMode == true)
    local dungeonMode = IsDungeonMode()
    local maxLvl      = IsMaxLevel()

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

    -- Full Mode
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
    PlaceRow(uiFrame.rows.ah,      HasAnyAHAddon())
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
    if lootFrame then
        lootFrame:SetHeight(totalHeight)
    end
end

UpdateDisplay = function()
    if not uiFrame or not uiFrame:IsShown() then return end

    local useVendor    = IsVendorOnlyMode()
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
    uiFrame.rows.repairs.val:SetText(repairCopper > 0 and ("|cffff5555-|r" .. FormatMoneyUI(repairCopper)) or "0c")

    if not HasAnyAHAddon() then
        uiFrame.valModeBtn:SetText("|cffaaaaaaVendor + Raw|r")
    elseif useVendor then
        uiFrame.valModeBtn:SetText("|cffffd700Vendor + Raw|r")
    else
        uiFrame.valModeBtn:SetText("|cff00ccffAH + Raw|r")
    end

    uiFrame.rows.total.val:SetText(FormatMoneyUI(netCopper))
    uiFrame.rows.gph.val:SetText(FormatMoneyUI(gphCopper) .. "/hr")
    uiFrame.rows.xph.val:SetText("|cffc080ff" .. FormatXP(xph) .. "/hr|r")

    if xph > 0 and not IsMaxLevel() then
        local remXP = (UnitXPMax("player") or 0) - (UnitXP("player") or 0)
        local ttlSec = (remXP / xph) * 3600
        uiFrame.rows.ttl.val:SetText("|cffc080ff" .. FormatTTL(ttlSec) .. "|r")
    else
        uiFrame.rows.ttl.val:SetText("|cffaaaaaa--:--|r")
    end

    -- Free Bag Slots (orange <= 5, red == 0)
    local freeSlots = GetFreeBagSlots()
    if freeSlots == 0 then
        uiFrame.rows.bags.val:SetText("|cffff33330 (FULL!)|r")
    elseif freeSlots <= 5 then
        uiFrame.rows.bags.val:SetText("|cffff8800" .. freeSlots .. " Free|r")
    else
        uiFrame.rows.bags.val:SetText("|cff00ff00" .. freeSlots .. " Free|r")
    end

    -- Session Gold Goal Progress Bar
    local goalCopper = tonumber(ns.db.sessionGoalCopper) or 1000000
    if goalCopper > 0 then
        local pct = math.max(0, (netCopper / goalCopper) * 100)
        uiFrame.goalBar:SetValue(math.min(pct, 100))
        if pct >= 100 then
            uiFrame.goalBar:SetStatusBarColor(0.15, 0.85, 0.25, 0.9)
        else
            uiFrame.goalBar:SetStatusBarColor(0.0, 0.72, 0.95, 0.9)
        end
        uiFrame.goalBar.text:SetText(string.format("Goal: %s / %s (%.0f%%)", FormatMoneyPlain(math.max(0, netCopper)), FormatMoneyPlain(goalCopper), pct))
    else
        uiFrame.goalBar:SetValue(0)
        uiFrame.goalBar.text:SetText("Goal: Not Set")
    end

    -- Compact Mode Single-Line Summary
    local statusDot = state.isRunning and "|cff00ff00*|r " or "|cffffaa00|| |r"
    uiFrame.compactText:SetText(statusDot .. FormatTime(state.sessionTime) .. "  |cff555555/|r  " .. FormatMoneyUI(gphCopper) .. "/hr")

    if state.isRunning then
        uiFrame.startBtn:SetText("|cffffaa00Pause|r")
    else
        uiFrame.startBtn:SetText("|cff00ff00Start|r")
    end
end

local function ShowDropAlert(itemLink, itemName, itemTexture, dropVal, count)
    if not alertFrame then
        local af = CreateFrame("Frame", "FarmTrackerDropAlertFrame", UIParent, "BackdropTemplate")
        af:SetSize(320, 56)
        af:SetPoint("TOP", UIParent, "TOP", 0, -140)
        af:SetFrameStrata("HIGH")
        af:EnableMouse(false)
        af:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile     = false,
            edgeSize = 2,
        })
        af:SetBackdropColor(0.06, 0.06, 0.08, 0.92)
        af:SetBackdropBorderColor(1, 0.82, 0.15, 1)

        local flash = af:CreateTexture(nil, "OVERLAY")
        flash:SetAllPoints()
        flash:SetColorTexture(1, 0.85, 0.2, 0.55)
        af.flash = flash

        local icon = af:CreateTexture(nil, "ARTWORK")
        icon:SetSize(36, 36)
        icon:SetPoint("LEFT", 10, 0)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        af.icon = icon

        local hdr = af:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        hdr:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
        hdr:SetPoint("RIGHT", -10, 0)
        hdr:SetJustifyH("LEFT")
        hdr:SetText("|cffffd700HIGH-VALUE DROP!|r")
        af.hdr = hdr

        local sub = af:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        sub:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 10, 2)
        sub:SetPoint("RIGHT", -10, 0)
        sub:SetJustifyH("LEFT")
        sub:SetWordWrap(false)
        af.sub = sub

        af:Hide()
        alertFrame = af
    end

    local fontPath = GetSelectedFontPath()
    alertFrame.hdr:SetFont(fontPath, 12, "OUTLINE")
    alertFrame.sub:SetFont(fontPath, 12, "OUTLINE")

    alertFrame.icon:SetTexture(itemTexture or 134400)
    local label = itemLink or itemName or "Unknown Item"
    if (count or 1) > 1 then
        label = label .. " |cffaaaaaax" .. count .. "|r"
    end
    alertFrame.sub:SetText(label .. "  (" .. FormatMoneyUI(dropVal) .. ")")

    pcall(PlaySound, SOUNDKIT and SOUNDKIT.LOOT_WINDOW_COIN_SOUND or 120, "SFX")

    local elapsed = 0
    alertFrame:SetAlpha(0)
    alertFrame.flash:SetAlpha(0.55)
    alertFrame:Show()

    alertFrame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt

        if elapsed <= 0.6 then
            self.flash:SetAlpha(0.55 * (1 - (elapsed / 0.6)))
        else
            self.flash:SetAlpha(0)
        end

        if elapsed < 0.2 then
            self:SetAlpha(elapsed / 0.2)
        elseif elapsed < 3.2 then
            self:SetAlpha(1)
        elseif elapsed < 4.0 then
            self:SetAlpha(1 - ((elapsed - 3.2) / 0.8))
        else
            self:SetAlpha(0)
            self:SetScript("OnUpdate", nil)
            self:Hide()
        end
    end)
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

    if not IsItemBlocked(itemID) then
        state.vendorCopper = state.vendorCopper + itemVendorTotal
        state.ahCopper     = state.ahCopper + itemAHTotal

        if ns.db.dropAlertEnabled then
            local threshold = tonumber(ns.db.dropAlertThreshold) or 20000
            local dropVal   = IsVendorOnlyMode() and itemVendorTotal or itemAHTotal
            if dropVal >= threshold then
                ShowDropAlert(cleanLink, itemName, itemTexture, dropVal, count)
                local label = cleanLink or itemName or ("Item #" .. key)
                if count > 1 then label = label .. " x" .. count end
                ns:Print("|cffffd700High-Value Drop:|r " .. label .. " (" .. FormatMoneyUI(dropVal) .. ")")
            end
        end
    end

    UpdateDisplay()
    UpdateLootList()
end

local function SaveCurrentSessionToHistory()
    if (state.sessionTime or 0) < 10 then return end
    local histMod = ns.Modules["History"]
    if not (histMod and histMod.SaveSession) then return end

    local useVendor    = IsVendorOnlyMode()
    local itemTotal    = useVendor and state.vendorCopper or state.ahCopper
    local repairCopper = state.repairCopper or 0
    local netCopper    = (state.rawCopper + itemTotal) - repairCopper
    local sessionHours = state.sessionTime / 3600
    local gphCopper    = (sessionHours > 0) and (netCopper / sessionHours) or 0

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
        modeTag      = useVendor and "Vendor" or "AH",
        sessionXP    = state.sessionXP or 0,
        mobsKilled   = state.mobsKilled or 0,
    })
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
    local repairCopper = state.repairCopper or 0
    local netCopper    = (state.rawCopper + itemTotal) - repairCopper
    local sessionHours = (state.sessionTime >= 1) and (state.sessionTime / 3600) or 0
    local gphCopper    = (sessionHours > 0) and (netCopper / sessionHours) or 0
    local rph          = (sessionHours > 0) and (state.completedRuns / sessionHours) or 0
    local zoneName     = GetRealZoneText() or "Farm Run"

    local runInfo = ""
    if IsDungeonMode() then
        local lastStr = state.lastRunTime and (", Last: " .. FormatTime(state.lastRunTime)) or ""
        local fastStr = state.fastestRunTime and (", Best: " .. FormatTime(state.fastestRunTime)) or ""
        runInfo = string.format(" [Runs: %d (%.1f/hr)%s%s]", state.completedRuns, rph, lastStr, fastStr)
    end

    local repairInfo = (repairCopper > 0) and (" // Repairs: -" .. FormatMoneyPlain(repairCopper)) or ""

    local msg = string.format(
        "[Farm Tracker] %s - Session: %s%s // Net (%s+Raw): %s (%s/hr) // Raw: %s // Vendor: %s // AH/Est: %s%s",
        zoneName,
        FormatTime(state.sessionTime),
        runInfo,
        modeTag,
        FormatMoneyPlain(netCopper),
        FormatMoneyPlain(gphCopper),
        FormatMoneyPlain(state.rawCopper),
        FormatMoneyPlain(state.vendorCopper),
        FormatMoneyPlain(state.ahCopper),
        repairInfo
    )

    SendChatMessage(msg, chatType)
end

local function TogglePostMenu(anchorBtn)
    if not postMenu then
        local m = CreateFrame("Frame", "FarmTrackerPostMenu", UIParent, "BackdropTemplate")
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

    local lf = CreateFrame("Frame", "FarmTrackerLootFrame", parentFrame, "BackdropTemplate")
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

    local scrollFrame = CreateFrame("ScrollFrame", "FarmTrackerLootScroll", lf, "UIPanelScrollFrameTemplate")
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
        if lootContextMenu then lootContextMenu:Hide() end
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

    local lockBtn = CreateFrame("Button", nil, f)
    lockBtn:SetSize(18, 18)
    lockBtn:SetPoint("RIGHT", histBtn, "LEFT", -2, 0)
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

    -- Compact / Mini Mode Toggle Button
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
        UpdateDisplay()
        UpdateLootPanelVisibility()
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
    f.div1 = div1

    -- Compact Mode Single-Line Summary
    local compactText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    compactText:SetPoint("TOP", 0, -32)
    compactText:SetText("00:00  |  0c/hr")
    compactText:Hide()
    f.compactText = compactText

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
        if not HasAnyAHAddon() then
            ns:Print("Install TradeSkillMaster or Auctionator to enable AH valuation. Using Vendor + Raw.")
            return
        end
        ns.db.timerVendorOnly = not ns.db.timerVendorOnly
        UpdateDisplay()
        UpdateLootList()
    end)
    f.valModeBtn = valModeBtn

    -- Session Goal Progress Bar
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
        state.isRunning = not state.isRunning
        if state.isRunning then state.lastSaveTime = GetTime() end
        UpdateDisplay()
    end)

    f.resetBtn = CreateActionButton("Reset", 80, 98, function()
        SaveCurrentSessionToHistory()
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
        state.mobsKilled     = 0
        state.lastSaveTime   = GetTime()
        wipe(state.lootLog)
        wipe(state.sessionIgnored)
        wipe(pendingItems)
        if postMenu then postMenu:Hide() end
        if lootContextMenu then lootContextMenu:Hide() end
        UpdateDisplay()
        UpdateLootList()
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
    RecalculateLootTotals()
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
        if lootContextMenu then lootContextMenu:Hide() end
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

function mod:TestDropAlert()
    ShowDropAlert("|cffa335ee[Test Epic Drop]|r", "Test Epic Drop", 133784, 52500, 1)
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

    lastXP    = UnitXP("player") or 0
    lastXPMax = UnitXPMax("player") or 0
    lastLevel = UnitLevel("player") or 1
    lastMoney = GetMoney() or 0

    if not repairHooked and _G.RepairAllItems then
        hooksecurefunc("RepairAllItems", function(useGuildBank)
            if not useGuildBank and state.isRunning then
                local cost, canRepair = GetRepairAllCost()
                if canRepair and cost and cost > 0 then
                    pendingRepairCost = cost
                    pendingRepairTime = GetTime()
                end
            end
        end)
        repairHooked = true
    end

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
    tracker:RegisterEvent("MERCHANT_CLOSED")
    tracker:RegisterEvent("PLAYER_MONEY")
    tracker:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    tracker:RegisterEvent("BAG_UPDATE_DELAYED")
    tracker:RegisterEvent("PLAYER_FLAGS_CHANGED")
    tracker:RegisterEvent("PLAYER_UPDATE_RESTING")
    tracker:RegisterEvent("PLAYER_LOGOUT")

    tracker:SetScript("OnEvent", function(_, event, arg1, arg2)
        if event == "PLAYER_LOGOUT" then
            state.lastSaveTime = GetTime()

        elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
            CheckAutoStartDungeon()

        elseif event == "BAG_UPDATE_DELAYED" then
            UpdateDisplay()

        elseif event == "PLAYER_FLAGS_CHANGED" and arg1 == "player" then
            if state.isRunning and ns.db.autoPauseAFK and UnitIsAFK("player") then
                state.isRunning = false
                UpdateDisplay()
                ns:Print("Auto-paused timer (|cffffaa00AFK|r).")
            end

        elseif event == "PLAYER_UPDATE_RESTING" then
            if state.isRunning and ns.db.autoPauseCity and IsResting() then
                state.isRunning = false
                UpdateDisplay()
                ns:Print("Auto-paused timer (|cffffaa00Entered City / Rested Area|r).")
            end

        elseif event == "MERCHANT_SHOW" then
            merchantOpen = true
            lastMoney    = GetMoney() or lastMoney

        elseif event == "MERCHANT_CLOSED" then
            merchantOpen      = false
            pendingRepairCost = 0

        elseif event == "PLAYER_MONEY" then
            local curMoney = GetMoney() or 0
            local spent    = lastMoney - curMoney
            lastMoney      = curMoney

            if state.isRunning and spent > 0 then
                if pendingRepairCost > 0 and (GetTime() - pendingRepairTime) < 3 and spent == pendingRepairCost then
                    state.repairCopper = (state.repairCopper or 0) + spent
                    pendingRepairCost  = 0
                    DebugPrint("Recorded RepairAll cost: " .. spent .. "c")
                    UpdateDisplay()
                elseif merchantOpen and InRepairMode and InRepairMode() then
                    state.repairCopper = (state.repairCopper or 0) + spent
                    DebugPrint("Recorded single-item repair: " .. spent .. "c")
                    UpdateDisplay()
                end
            end

        elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
            if not state.isRunning then return end
            local _, subevent, _, _, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
            if subevent == "PARTY_KILL" and destGUID and string.sub(destGUID, 1, 8) == "Creature" then
                state.mobsKilled = (state.mobsKilled or 0) + 1
            end

        elseif event == "PLAYER_XP_UPDATE" then
            local curXP    = UnitXP("player") or 0
            local curXPMax = UnitXPMax("player") or 0
            local curLevel = UnitLevel("player") or lastLevel

            if state.isRunning and not IsMaxLevel() then
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