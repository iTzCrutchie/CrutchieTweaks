local _, ns = ...

local mod = ns:RegisterModule("History", {})

local MAX_HISTORY = 50
local histFrame   = nil
local histRows    = {}

local function EnsureHistoryDB()
    FarmTrackerDB.history = FarmTrackerDB.history or {}
    return FarmTrackerDB.history
end

function mod:SaveSession(entry)
    if not entry then return end
    local list = EnsureHistoryDB()
    table.insert(list, 1, entry) -- newest first
    while #list > MAX_HISTORY do
        table.remove(list)
    end
    if histFrame and histFrame:IsShown() then
        self:RefreshList()
    end
end

function mod:RefreshList()
    if not histFrame then return end
    local Utils = ns.Utils
    Utils.ApplyBackdropTheme(histFrame, false, false)

    local list = EnsureHistoryDB()
    if #list == 0 then
        histFrame.emptyText:Show()
    else
        histFrame.emptyText:Hide()
    end

    local rowHeight = 24
    for i, entry in ipairs(list) do
        local row = histRows[i]
        if not row then
            row = CreateFrame("Button", nil, histFrame.scrollChild)
            row:SetHeight(rowHeight)

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0.0)
            row.bg = bg

            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(0.2, 0.5, 0.8, 0.25)

            local delBtn = CreateFrame("Button", nil, row)
            delBtn:SetSize(16, 16)
            delBtn:SetPoint("RIGHT", -2, 0)
            delBtn:SetNormalFontObject("GameFontHighlightSmall")
            delBtn:SetText("|cffff5555x|r")
            row.delBtn = delBtn

            local gphTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            gphTxt:SetPoint("RIGHT", delBtn, "LEFT", -6, 0)
            gphTxt:SetWidth(90)
            gphTxt:SetJustifyH("RIGHT")
            row.gphTxt = gphTxt

            local netTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            netTxt:SetPoint("RIGHT", gphTxt, "LEFT", -6, 0)
            netTxt:SetWidth(75)
            netTxt:SetJustifyH("RIGHT")
            row.netTxt = netTxt

            local durTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            durTxt:SetPoint("RIGHT", netTxt, "LEFT", -6, 0)
            durTxt:SetWidth(52)
            durTxt:SetJustifyH("RIGHT")
            row.durTxt = durTxt

            local zoneTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            zoneTxt:SetPoint("LEFT", 4, 0)
            zoneTxt:SetPoint("RIGHT", durTxt, "LEFT", -6, 0)
            zoneTxt:SetJustifyH("LEFT")
            zoneTxt:SetWordWrap(false)
            row.zoneTxt = zoneTxt

            row:SetScript("OnEnter", function(self)
                local e = self.entryData
                if not e then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(string.format("|cff00ccff%s|r  |cffaaaaaa(%s)|r", e.zone or "Unknown", e.dateStr or ""), 1, 1, 1)
                if e.charName and e.charName ~= "" then
                    GameTooltip:AddDoubleLine("Character:", e.charName, 0.7, 0.7, 0.7, 1, 1, 1)
                end
                GameTooltip:AddDoubleLine("Duration:", Utils.FormatDuration(e.duration), 0.7, 0.7, 0.7, 1, 1, 1)
                GameTooltip:AddDoubleLine("GPH Mode:", (e.modeTag or "AH") .. " + Raw", 0.7, 0.7, 0.7, 0.4, 0.85, 1)
                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine("Raw Looted Coin:", Utils.FormatMoneyUI(e.rawCopper), 0.7, 0.7, 0.7, 1, 1, 1)
                GameTooltip:AddDoubleLine("Items (Vendor):", Utils.FormatMoneyUI(e.vendorCopper), 0.7, 0.7, 0.7, 1, 1, 1)
                GameTooltip:AddDoubleLine("Items (AH / Est):", Utils.FormatMoneyUI(e.ahCopper), 0.7, 0.7, 0.7, 1, 1, 1)
                if (e.repairCopper or 0) > 0 then
                    GameTooltip:AddDoubleLine("Repair Costs:", "|cffff5555-|r" .. Utils.FormatMoneyUI(e.repairCopper), 1, 0.4, 0.4, 1, 0.4, 0.4)
                end
                GameTooltip:AddDoubleLine("|cffffd700Net Profit:|r", Utils.FormatMoneyUI(e.netCopper), 1, 0.85, 0, 1, 1, 1)
                GameTooltip:AddDoubleLine("|cff00ccffNet Gold / Hr:|r", Utils.FormatMoneyUI(e.gphCopper) .. "/hr", 0, 0.8, 1, 1, 1, 1)

                if e.dungeonMode or (e.runs or 0) > 0 or (e.sessionXP or 0) > 0 then
                    GameTooltip:AddLine(" ")
                    if e.dungeonMode or (e.runs or 0) > 0 then
                        GameTooltip:AddDoubleLine("Completed Runs:", tostring(e.runs or 0), 0.7, 0.7, 0.7, 1, 1, 1)
                    end
                    if (e.sessionXP or 0) > 0 then
                        GameTooltip:AddDoubleLine("Session XP:", "|cffc080ff" .. Utils.FormatXP(e.sessionXP) .. "|r", 0.7, 0.7, 0.7, 1, 1, 1)
                    end
                end
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cffaaaaaaClick row to copy summary|r")
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)

            row:SetScript("OnClick", function(self)
                local e = self.entryData
                if not e then return end
                local repairStr = (e.repairCopper or 0) > 0 and (" // Repairs: -" .. Utils.FormatMoneyPlain(e.repairCopper)) or ""
                local runStr    = (e.runs or 0) > 0 and (" // Runs: " .. e.runs) or ""
                local text = string.format(
                    "[Farm Tracker] %s (%s) - Time: %s%s // Net (%s+Raw): %s (%s/hr) // Raw: %s // Vendor: %s // AH/Est: %s%s",
                    e.zone or "Unknown",
                    e.dateStr or "",
                    Utils.FormatDuration(e.duration),
                    runStr,
                    e.modeTag or "AH",
                    Utils.FormatMoneyPlain(e.netCopper),
                    Utils.FormatMoneyPlain(e.gphCopper),
                    Utils.FormatMoneyPlain(e.rawCopper),
                    Utils.FormatMoneyPlain(e.vendorCopper),
                    Utils.FormatMoneyPlain(e.ahCopper),
                    repairStr
                )
                Utils.ShowCopyPopup(text, "|cff00ccffCopy Session Summary|r")
            end)

            histRows[i] = row
        end

        row.entryData = entry
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", histFrame.scrollChild, "TOPLEFT", 0, -((i - 1) * rowHeight))
        row:SetPoint("TOPRIGHT", histFrame.scrollChild, "TOPRIGHT", 0, -((i - 1) * rowHeight))

        local datePrefix = entry.dateStr and ("|cffaaaaaa" .. entry.dateStr .. "|r  ") or ""
        row.zoneTxt:SetText(datePrefix .. (entry.zone or "Unknown"))
        row.durTxt:SetText("|cffcccccc" .. Utils.FormatDuration(entry.duration) .. "|r")
        row.netTxt:SetText(Utils.FormatMoneyUI(entry.netCopper))
        row.gphTxt:SetText(Utils.FormatMoneyUI(entry.gphCopper) .. "/hr")

        row.delBtn:SetScript("OnClick", function()
            table.remove(list, i)
            mod:RefreshList()
        end)

        row:Show()
    end

    for i = #list + 1, #histRows do
        histRows[i]:Hide()
    end

    histFrame.scrollChild:SetHeight(math.max(#list * rowHeight, 1))
end

local function CreateHistoryUI()
    if histFrame then return histFrame end

    local f = CreateFrame("Frame", "FarmTrackerHistoryFrame", UIParent, "BackdropTemplate")
    tinsert(UISpecialFrames, "FarmTrackerHistoryFrame")
    f:SetSize(490, 340)
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
    title:SetText("|cff00ccffFarm Tracker|r Session History")

    local closeBtn = CreateFrame("Button", nil, f)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("TOPRIGHT", -8, -8)
    closeBtn:SetNormalFontObject("GameFontNormal")
    closeBtn:SetText("|cffff5555X|r")
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local div1 = f:CreateTexture(nil, "ARTWORK")
    div1:SetColorTexture(0.25, 0.25, 0.3, 0.8)
    div1:SetSize(462, 1)
    div1:SetPoint("TOP", 0, -34)

    -- Column Headers
    local colZone = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    colZone:SetPoint("TOPLEFT", 14, -40)
    colZone:SetText("|cffaaaaaaDate & Zone|r")

    local colGph = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    colGph:SetPoint("TOPRIGHT", -54, -40)
    colGph:SetWidth(90)
    colGph:SetJustifyH("RIGHT")
    colGph:SetText("|cffaaaaaaNet / Hr|r")

    local colNet = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    colNet:SetPoint("RIGHT", colGph, "LEFT", -6, 0)
    colNet:SetWidth(75)
    colNet:SetJustifyH("RIGHT")
    colNet:SetText("|cffaaaaaaNet Profit|r")

    local colDur = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    colDur:SetPoint("RIGHT", colNet, "LEFT", -6, 0)
    colDur:SetWidth(52)
    colDur:SetJustifyH("RIGHT")
    colDur:SetText("|cffaaaaaaTime|r")

    local div2 = f:CreateTexture(nil, "ARTWORK")
    div2:SetColorTexture(0.25, 0.25, 0.3, 0.8)
    div2:SetSize(462, 1)
    div2:SetPoint("TOP", 0, -56)

    local scrollFrame = CreateFrame("ScrollFrame", "FarmTrackerHistoryScroll", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -60)
    scrollFrame:SetPoint("BOTTOMRIGHT", -32, 42)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(442)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    f.scrollFrame = scrollFrame
    f.scrollChild = scrollChild

    local emptyText = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("CENTER", 0, 0)
    emptyText:SetText("No saved sessions yet. Click Reset after a farm run to log it.")
    f.emptyText = emptyText

    local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearBtn:SetSize(96, 22)
    clearBtn:SetPoint("BOTTOMLEFT", 14, 12)
    clearBtn:SetText("|cffff6666Clear All|r")
    clearBtn:SetScript("OnClick", function()
        wipe(EnsureHistoryDB())
        mod:RefreshList()
    end)

    local doneBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    doneBtn:SetSize(96, 22)
    doneBtn:SetPoint("BOTTOMRIGHT", -14, 12)
    doneBtn:SetText("Close")
    doneBtn:SetScript("OnClick", function() f:Hide() end)

    f:Hide()
    histFrame = f
    ns.Utils.ApplyBackdropTheme(f, false, false)
    return f
end

function mod:RefreshTheme()
    if histFrame then
        ns.Utils.ApplyBackdropTheme(histFrame, false, false)
    end
end

function mod:ToggleUI()
    local f = CreateHistoryUI()
    if f:IsShown() then
        f:Hide()
    else
        self:RefreshList()
        f:Show()
    end
end

function mod:OnInit()
    -- Created lazily on first open
end