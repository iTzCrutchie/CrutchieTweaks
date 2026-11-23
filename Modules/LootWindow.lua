local _, ns = ...

local LootWindow = ns:RegisterModule("LootWindow", {})
ns.LootWindow = LootWindow

local QUALITY_FILTERS = {
    { minQ = 0, label = "|cffccccccAll|r" },
    { minQ = 1, label = "|cffffffffCommon+|r" },
    { minQ = 2, label = "|cff1eff00Uncommon+|r" },
    { minQ = 3, label = "|cff0070ddRare+|r" },
    { minQ = 4, label = "|cffa335eeEpic+|r" },
    { minQ = 5, label = "|cffff8000Legendary+|r" },
}

local lootFrame       = nil
local lootRows        = {}
local lootContextMenu = nil
local alertFrame      = nil

local function ShowLootContextMenu(itemID, itemName, anchorFrame)
    local Utils = ns.Utils
    if not lootContextMenu then
        local m = CreateFrame("Frame", "FarmTrackerLootContextMenu", UIParent, "BackdropTemplate")
        m:SetSize(166, 98)
        m:SetFrameStrata("TOOLTIP")
        m:SetClampedToScreen(true)
        Utils.ApplyBackdropTheme(m, false, false)

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

    Utils.ApplyBackdropTheme(lootContextMenu, false, false)
    lootContextMenu.hdr:SetText("|cff00ccff" .. (itemName or ("Item #" .. tostring(itemID))) .. "|r")

    lootContextMenu.sessBtn:SetScript("OnClick", function()
        local tracker = ns.Modules["Tracker"]
        local state = tracker and tracker:GetState()
        if state then
            state.sessionIgnored[tostring(itemID)] = true
        end
        lootContextMenu:Hide()
        if tracker and tracker.OnLootBlacklistChanged then
            tracker:OnLootBlacklistChanged()
        end
    end)

    lootContextMenu.globBtn:SetScript("OnClick", function()
        ns.db.globalBlacklist[tostring(itemID)] = itemName or tostring(itemID)
        lootContextMenu:Hide()
        local tracker = ns.Modules["Tracker"]
        if tracker and tracker.OnLootBlacklistChanged then
            tracker:OnLootBlacklistChanged()
        end
        local optMod = ns.Modules["Options"]
        if optMod and optMod.SyncBlacklistCount then optMod:SyncBlacklistCount() end
        ns:Print("Added |cffffaa00" .. (itemName or ("Item #" .. tostring(itemID))) .. "|r to Global Blocklist.")
    end)

    lootContextMenu:ClearAllPoints()
    lootContextMenu:SetPoint("TOPLEFT", anchorFrame, "TOPRIGHT", 4, 0)
    lootContextMenu:Show()
end

function LootWindow:Create(parentFrame, toggleTabBtn)
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
        LootWindow:UpdateList()
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

function LootWindow:UpdateList()
    if not lootFrame or not lootFrame:IsShown() then return end

    local Utils   = ns.Utils
    local Pricing = ns.Pricing
    local tracker = ns.Modules["Tracker"]
    local state   = tracker and tracker:GetState()
    if not state then return end

    local useVendor = Pricing.IsVendorOnlyMode()
    local minQual   = ns.db.timerLootMinQual or 0
    local sorted    = {}
    local totalItemCount = 0

    for _, entry in pairs(state.lootLog) do
        if not Pricing.IsItemBlocked(entry.itemID, state.sessionIgnored) then
            if entry.quality == nil and entry.itemID then
                local _, _, fetchedQuality = Utils.SafeGetItemInfo(entry.itemID)
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

    local fontPath = Utils.GetSelectedFontPath()
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
        row.valText:SetText(Utils.FormatMoneyUI(itemData.totalVal))
        row:Show()
    end

    for i = #sorted + 1, #lootRows do
        lootRows[i]:Hide()
    end

    lootFrame.scrollChild:SetHeight(math.max(#sorted * rowHeight, 1))
end

function LootWindow:UpdateVisibility(parentFrame)
    if not parentFrame or not lootFrame then return end

    if ns.db.timerLootOpen and parentFrame:IsShown() and not ns.db.compactMode then
        lootFrame:SetHeight(parentFrame:GetHeight())
        lootFrame:Show()
        if parentFrame.lootToggleBtn then parentFrame.lootToggleBtn:SetText("<") end
        self:UpdateList()
    else
        lootFrame:Hide()
        self:HideMenus()
        if parentFrame.lootToggleBtn then parentFrame.lootToggleBtn:SetText(">") end
    end
end

function LootWindow:SetHeight(h)
    if lootFrame then lootFrame:SetHeight(h) end
end

function LootWindow:ApplyTheme()
    ns.Utils.ApplyBackdropTheme(lootFrame, false, true)
    ns.Utils.ApplyBackdropTheme(lootContextMenu, false, false)
end

function LootWindow:ApplyFont(fontPath)
    if not lootFrame then return end
    lootFrame.header:SetFont(fontPath, 13, "OUTLINE")
    for _, lRow in ipairs(lootRows) do
        lRow.nameText:SetFont(fontPath, 11, "")
        lRow.valText:SetFont(fontPath, 11, "")
    end
end

function LootWindow:HideMenus()
    if lootContextMenu then lootContextMenu:Hide() end
end

function LootWindow:ShowDropAlert(itemLink, itemName, itemTexture, dropVal, count)
    local Utils = ns.Utils
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

    local fontPath = Utils.GetSelectedFontPath()
    alertFrame.hdr:SetFont(fontPath, 12, "OUTLINE")
    alertFrame.sub:SetFont(fontPath, 12, "OUTLINE")

    alertFrame.icon:SetTexture(itemTexture or 134400)
    local label = itemLink or itemName or "Unknown Item"
    if (count or 1) > 1 then
        label = label .. " |cffaaaaaax" .. count .. "|r"
    end
    alertFrame.sub:SetText(label .. "  (" .. Utils.FormatMoneyUI(dropVal) .. ")")

    Utils.PlayDropAlertSound()

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