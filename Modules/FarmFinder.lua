local _, ns = ...

local mod = ns:RegisterModule("FarmFinder", {})

local CONTINENTS = {
    { key = "ALL",              label = "All Continents" },
    { key = "Eastern Kingdoms", label = "Eastern Kingdoms" },
    { key = "Kalimdor",         label = "Kalimdor" },
}

local CATEGORIES = {
    { key = "ALL",       label = "All" },
    { key = "CUSTOM",    label = "Custom" },
    { key = "Mining",    label = "Mining" },
    { key = "Herbalism", label = "Herb" },
    { key = "Skinning",  label = "Skin" },
    { key = "Cloth",     label = "Cloth" },
    { key = "Fishing",   label = "Fish" },
    { key = "Dungeon",   label = "Dungeon" },
    { key = "Mob Grind", label = "Grind" },
}

local SAVE_CATEGORIES = {
    { key = "Mining",    label = "Mining" },
    { key = "Herbalism", label = "Herb" },
    { key = "Skinning",  label = "Skin" },
    { key = "Cloth",     label = "Cloth" },
    { key = "Fishing",   label = "Fish" },
    { key = "Dungeon",   label = "Dungeon" },
    { key = "Mob Grind", label = "Grind" },
    { key = "Other",     label = "Other" },
}

local ZONE_CONTINENT = {
    -- Eastern Kingdoms
    ["alterac mountains"]    = "Eastern Kingdoms",
    ["arathi highlands"]     = "Eastern Kingdoms",
    ["badlands"]             = "Eastern Kingdoms",
    ["blasted lands"]        = "Eastern Kingdoms",
    ["burning steppes"]      = "Eastern Kingdoms",
    ["deadwind pass"]        = "Eastern Kingdoms",
    ["dun morogh"]           = "Eastern Kingdoms",
    ["duskwood"]             = "Eastern Kingdoms",
    ["eastern plaguelands"]  = "Eastern Kingdoms",
    ["elwynn forest"]        = "Eastern Kingdoms",
    ["hillsbrad foothills"]  = "Eastern Kingdoms",
    ["loch modan"]           = "Eastern Kingdoms",
    ["redridge mountains"]   = "Eastern Kingdoms",
    ["searing gorge"]        = "Eastern Kingdoms",
    ["silverpine forest"]    = "Eastern Kingdoms",
    ["stranglethorn vale"]   = "Eastern Kingdoms",
    ["swamp of sorrows"]     = "Eastern Kingdoms",
    ["the hinterlands"]      = "Eastern Kingdoms",
    ["tirisfal glades"]      = "Eastern Kingdoms",
    ["western plaguelands"]  = "Eastern Kingdoms",
    ["westfall"]             = "Eastern Kingdoms",
    ["wetlands"]             = "Eastern Kingdoms",
    ["the deadmines"]        = "Eastern Kingdoms",
    ["shadowfang keep"]      = "Eastern Kingdoms",
    ["the stockade"]         = "Eastern Kingdoms",
    ["gnomeregan"]           = "Eastern Kingdoms",
    ["scarlet monastery"]    = "Eastern Kingdoms",
    ["uldaman"]              = "Eastern Kingdoms",
    ["the temple of atal'hakkar"] = "Eastern Kingdoms",
    ["sunken temple"]        = "Eastern Kingdoms",
    ["blackrock depths"]     = "Eastern Kingdoms",
    ["blackrock spire"]      = "Eastern Kingdoms",
    ["stratholme"]           = "Eastern Kingdoms",
    ["scholomance"]          = "Eastern Kingdoms",

    -- Kalimdor
    ["ashenvale"]            = "Kalimdor",
    ["azshara"]              = "Kalimdor",
    ["darkshore"]            = "Kalimdor",
    ["desolace"]             = "Kalimdor",
    ["durotar"]              = "Kalimdor",
    ["dustwallow marsh"]     = "Kalimdor",
    ["felwood"]              = "Kalimdor",
    ["feralas"]              = "Kalimdor",
    ["moonglade"]            = "Kalimdor",
    ["mulgore"]              = "Kalimdor",
    ["silithus"]             = "Kalimdor",
    ["stonetalon mountains"] = "Kalimdor",
    ["tanaris"]              = "Kalimdor",
    ["teldrassil"]           = "Kalimdor",
    ["the barrens"]          = "Kalimdor",
    ["thousand needles"]     = "Kalimdor",
    ["un'goro crater"]       = "Kalimdor",
    ["winterspring"]         = "Kalimdor",
    ["ragefire chasm"]       = "Kalimdor",
    ["wailing caverns"]      = "Kalimdor",
    ["blackfathom deeps"]    = "Kalimdor",
    ["razorfen kraul"]       = "Kalimdor",
    ["razorfen downs"]       = "Kalimdor",
    ["zul'farrak"]           = "Kalimdor",
    ["maraudon"]             = "Kalimdor",
    ["dire maul"]            = "Kalimdor",
}

local finderFrame     = nil
local finderRows      = {}
local importFrame     = nil
local saveFrame       = nil
local activeContinent = "ALL"
local activeFilter    = "ALL"
local sortBy          = "gph"   -- "zone", "category", "gph"
local sortAsc         = false
local refreshQueued   = false

local function GetFarmContinent(farm)
    if farm.continent and farm.continent ~= "" then
        return farm.continent
    end
    local z = string.lower(strtrim(farm.zone or ""))
    return ZONE_CONTINENT[z] or "Other"
end

local function EnsureFarmsDB()
    FarmTrackerDB.customFarms = FarmTrackerDB.customFarms or {}
    return FarmTrackerDB.customFarms
end

local function SanitizeField(str)
    str = tostring(str or "")
    return string.gsub(str, "[|\r\n]", " ")
end

-- Format: FT1:<name>|<zone>|<category>|<rawGphCopper>|<itemID:qty,itemID:qty>|<routeString>
local function ExportFarmString(farm)
    local itemParts = {}
    if type(farm.items) == "table" then
        for id, qty in pairs(farm.items) do
            if tonumber(id) and tonumber(qty) and tonumber(qty) > 0 then
                table.insert(itemParts, string.format("%d:%.2f", tonumber(id), tonumber(qty)))
            end
        end
    end
    table.sort(itemParts)

    return table.concat({
        "FT1:" .. SanitizeField(farm.name),
        SanitizeField(farm.zone),
        SanitizeField(farm.category or "Other"),
        tostring(math.floor(farm.rawGphCopper or 0)),
        table.concat(itemParts, ","),
        SanitizeField(farm.route or ""),
    }, "|")
end

local function ParseImportString(rawText)
    local text = strtrim(rawText or "")
    if string.sub(text, 1, 4) ~= "FT1:" then
        return nil, "String must start with 'FT1:'."
    end

    local body = string.sub(text, 5)
    local parts = {}
    local startIdx = 1
    while true do
        local sep = string.find(body, "|", startIdx, true)
        if sep then
            table.insert(parts, string.sub(body, startIdx, sep - 1))
            startIdx = sep + 1
        else
            table.insert(parts, string.sub(body, startIdx))
            break
        end
    end

    if #parts < 5 then
        return nil, "Invalid farm string format."
    end

    local items = {}
    if parts[5] and parts[5] ~= "" then
        for pair in string.gmatch(parts[5], "[^,]+") do
            local idStr, qtyStr = string.match(pair, "^(%d+):(%d+%.?%d*)$")
            local id, qty = tonumber(idStr), tonumber(qtyStr)
            if id and qty and qty > 0 then
                items[id] = qty
            end
        end
    end

    return {
        name         = (parts[1] ~= "" and parts[1]) or "Imported Farm",
        zone         = (parts[2] ~= "" and parts[2]) or "Unknown",
        category     = (parts[3] ~= "" and parts[3]) or "Other",
        rawGphCopper = tonumber(parts[4]) or 0,
        items        = items,
        route        = parts[6] or "",
    }
end

local function EvaluateFarmGPH(farm)
    local Utils     = ns.Utils
    local Pricing   = ns.Pricing
    local useVendor = Pricing.IsVendorOnlyMode()
    local rawGph    = tonumber(farm.rawGphCopper) or 0
    local itemGph   = 0
    local breakdown = {}

    if type(farm.items) == "table" then
        for id, qtyPerHr in pairs(farm.items) do
            local itemID = tonumber(id)
            local qty    = tonumber(qtyPerHr) or 0
            if itemID and qty > 0 then
                local itemName, cleanLink, _, _, _, _, _, _, _, _, sellPrice, _, _, bindType = Utils.SafeGetItemInfo(itemID)
                sellPrice = tonumber(sellPrice) or 0
                local isBoP   = (bindType == 1)
                local unitVal = useVendor and sellPrice or Pricing.GetItemAHValue(itemID, cleanLink, sellPrice, isBoP)
                local lineVal = unitVal * qty
                itemGph = itemGph + lineVal

                table.insert(breakdown, {
                    label = cleanLink or itemName or ("Item #" .. itemID),
                    qty   = qty,
                    val   = lineVal,
                })
            end
        end
    end

    table.sort(breakdown, function(a, b) return a.val > b.val end)
    return rawGph + itemGph, breakdown
end

local function UpdateSortHeaderLabels()
    if not finderFrame or not finderFrame.sortHeaders then return end
    local arrow = sortAsc and " ^" or " v"

    for key, btn in pairs(finderFrame.sortHeaders) do
        if key == sortBy then
            btn.txt:SetText("|cff00ccff" .. btn.baseLabel .. arrow .. "|r")
        else
            btn.txt:SetText("|cffaaaaaa" .. btn.baseLabel .. "|r")
        end
    end
end

function mod:RefreshList()
    if not finderFrame then return end
    local Utils = ns.Utils
    Utils.ApplyBackdropTheme(finderFrame, false, false)
    UpdateSortHeaderLabels()

    local customFarms = EnsureFarmsDB()
    local scored      = {}

    local function AddFarms(list, isCustom)
        if type(list) ~= "table" then return end
        for idx, farm in ipairs(list) do
            local catMatch = false
            if activeFilter == "ALL" then
                catMatch = true
            elseif activeFilter == "CUSTOM" then
                catMatch = isCustom
            else
                catMatch = (farm.category == activeFilter)
            end

            local contMatch = (activeContinent == "ALL") or (GetFarmContinent(farm) == activeContinent)

            if catMatch and contMatch then
                local gph, breakdown = EvaluateFarmGPH(farm)
                table.insert(scored, {
                    index     = idx,
                    isCustom  = isCustom,
                    farm      = farm,
                    gph       = gph,
                    breakdown = breakdown,
                })
            end
        end
    end

    AddFarms(ns.BuiltInFarms, false)
    AddFarms(customFarms, true)

    table.sort(scored, function(a, b)
        if sortBy == "zone" then
            local za = string.lower(a.farm.zone or "")
            local zb = string.lower(b.farm.zone or "")
            if za ~= zb then
                if sortAsc then return za < zb else return za > zb end
            end
            return string.lower(a.farm.name or "") < string.lower(b.farm.name or "")
        elseif sortBy == "category" then
            local ca = string.lower(a.farm.category or "")
            local cb = string.lower(b.farm.category or "")
            if ca ~= cb then
                if sortAsc then return ca < cb else return ca > cb end
            end
            if a.gph ~= b.gph then return a.gph > b.gph end
            return string.lower(a.farm.name or "") < string.lower(b.farm.name or "")
        else
            if a.gph ~= b.gph then
                if sortAsc then return a.gph < b.gph else return a.gph > b.gph end
            end
            return string.lower(a.farm.name or "") < string.lower(b.farm.name or "")
        end
    end)

    if #scored == 0 then
        if activeFilter == "CUSTOM" then
            finderFrame.emptyText:SetText("No custom farms yet. Click '+' in Session History or Import a farm string.")
        else
            finderFrame.emptyText:SetText("No farms match the current filters.")
        end
        finderFrame.emptyText:Show()
    else
        finderFrame.emptyText:Hide()
    end

    local rowHeight = 24
    for i, data in ipairs(scored) do
        local row = finderRows[i]
        if not row then
            row = CreateFrame("Button", nil, finderFrame.scrollChild)
            row:SetHeight(rowHeight)

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0.0)

            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(0.2, 0.5, 0.8, 0.25)

            local delBtn = CreateFrame("Button", nil, row)
            delBtn:SetSize(16, 16)
            delBtn:SetPoint("RIGHT", -2, 0)
            delBtn:SetNormalFontObject("GameFontHighlightSmall")
            delBtn:SetText("|cffff5555x|r")
            row.delBtn = delBtn

            local expBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            expBtn:SetSize(44, 18)
            expBtn:SetPoint("RIGHT", delBtn, "LEFT", -4, 0)
            expBtn:SetNormalFontObject("GameFontHighlightSmall")
            expBtn:SetText("Share")
            row.expBtn = expBtn

            local routeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            routeBtn:SetSize(44, 18)
            routeBtn:SetPoint("RIGHT", expBtn, "LEFT", -4, 0)
            routeBtn:SetNormalFontObject("GameFontHighlightSmall")
            routeBtn:SetText("|cff00ff00Route|r")
            row.routeBtn = routeBtn

            local gphTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            gphTxt:SetPoint("RIGHT", routeBtn, "LEFT", -8, 0)
            gphTxt:SetWidth(92)
            gphTxt:SetJustifyH("RIGHT")
            row.gphTxt = gphTxt

            local catTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            catTxt:SetPoint("RIGHT", gphTxt, "LEFT", -6, 0)
            catTxt:SetWidth(68)
            catTxt:SetJustifyH("RIGHT")
            row.catTxt = catTxt

            local nameTxt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            nameTxt:SetPoint("LEFT", 4, 0)
            nameTxt:SetPoint("RIGHT", catTxt, "LEFT", -6, 0)
            nameTxt:SetJustifyH("LEFT")
            nameTxt:SetWordWrap(false)
            row.nameTxt = nameTxt

            row:SetScript("OnEnter", function(self)
                local d = self.scoredData
                if not d then return end
                local fm = d.farm
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local tag = d.isCustom and " |cff00ff00[Custom]|r" or ""
                GameTooltip:AddLine(string.format("|cff00ccff%s|r  |cffaaaaaa(%s)|r%s", fm.name or "Farm", fm.zone or "Unknown", tag), 1, 1, 1)
                GameTooltip:AddDoubleLine("Continent:", GetFarmContinent(fm), 0.7, 0.7, 0.7, 1, 1, 1)
                GameTooltip:AddDoubleLine("Category:", fm.category or "Other", 0.7, 0.7, 0.7, 1, 1, 1)
                GameTooltip:AddDoubleLine("|cff00ccffLive Est. Gold / Hr:|r", Utils.FormatMoneyUI(d.gph) .. "/hr", 0, 0.8, 1, 1, 1, 1)
                GameTooltip:AddLine(" ")
                if (fm.rawGphCopper or 0) > 0 then
                    GameTooltip:AddDoubleLine("Raw / Vendor Coin / Hr:", Utils.FormatMoneyUI(fm.rawGphCopper), 0.7, 0.7, 0.7, 1, 1, 1)
                end
                for idxB, b in ipairs(d.breakdown) do
                    if idxB <= 12 then
                        GameTooltip:AddDoubleLine(
                            string.format("%s |cffaaaaaax%.1f/hr|r", b.label, b.qty),
                            Utils.FormatMoneyUI(b.val),
                            1, 1, 1, 1, 1, 1
                        )
                    end
                end
                if #d.breakdown > 12 then
                    GameTooltip:AddLine(string.format("|cffaaaaaa...and %d more items|r", #d.breakdown - 12))
                end
                if fm.route and fm.route ~= "" then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("|cff00ff00Routes string attached|r — click |cffffffffRoute|r to copy for RoutesImportExport.")
                end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)

            finderRows[i] = row
        end

        local fm = data.farm
        row.scoredData = data
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", finderFrame.scrollChild, "TOPLEFT", 0, -((i - 1) * rowHeight))
        row:SetPoint("TOPRIGHT", finderFrame.scrollChild, "TOPRIGHT", 0, -((i - 1) * rowHeight))

        local prefix = data.isCustom and "|cff00ff00*|r " or ""
        row.nameTxt:SetText(string.format("%s%s |cffaaaaaa(%s)|r", prefix, fm.name or "Farm", fm.zone or ""))
        row.catTxt:SetText("|cffcccccc" .. (fm.category or "Other") .. "|r")
        row.gphTxt:SetText(Utils.FormatMoneyUI(data.gph) .. "/hr")

        if fm.route and fm.route ~= "" then
            row.routeBtn:Show()
            row.routeBtn:SetScript("OnClick", function()
                Utils.ShowCopyPopup(fm.route, "|cff00ff00Copy Routes String (RoutesImportExport)|r")
            end)
        else
            row.routeBtn:Hide()
        end

        if data.isCustom then
            row.expBtn:Show()
            row.expBtn:SetScript("OnClick", function()
                Utils.ShowCopyPopup(ExportFarmString(fm), "|cff00ccffExport Farm String|r")
            end)

            row.delBtn:Show()
            row.delBtn:SetScript("OnClick", function()
                table.remove(customFarms, data.index)
                mod:RefreshList()
            end)
        else
            row.expBtn:Hide()
            row.delBtn:Hide()
        end

        row:Show()
    end

    for i = #scored + 1, #finderRows do
        finderRows[i]:Hide()
    end

    finderFrame.scrollChild:SetHeight(math.max(#scored * rowHeight, 1))
end

local function ShowImportModal()
    if not importFrame then
        local im = CreateFrame("Frame", "FarmTrackerImportFrame", UIParent, "BackdropTemplate")
        tinsert(UISpecialFrames, "FarmTrackerImportFrame")
        im:SetSize(440, 148)
        im:SetPoint("CENTER")
        im:SetFrameStrata("FULLSCREEN_DIALOG")
        im:SetMovable(true)
        im:EnableMouse(true)
        im:RegisterForDrag("LeftButton")
        im:SetClampedToScreen(true)
        im:SetScript("OnDragStart", im.StartMoving)
        im:SetScript("OnDragStop", im.StopMovingOrSizing)

        local title = im:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 12, -10)
        title:SetText("|cff00ccffImport Farm String|r  |cffaaaaaa(Paste FT1:... string)|r")

        local ebBg = CreateFrame("Frame", nil, im, "BackdropTemplate")
        ebBg:SetPoint("TOPLEFT", 12, -30)
        ebBg:SetPoint("BOTTOMRIGHT", -12, 42)
        ebBg:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile     = false,
            edgeSize = 1,
        })
        ebBg:SetBackdropColor(0, 0, 0, 0.5)
        ebBg:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)

        local eb = CreateFrame("EditBox", nil, ebBg)
        eb:SetPoint("TOPLEFT", 6, -6)
        eb:SetPoint("BOTTOMRIGHT", -6, 6)
        eb:SetMultiLine(true)
        eb:SetFontObject("GameFontHighlightSmall")
        eb:SetAutoFocus(false)
        eb:SetScript("OnEscapePressed", function() im:Hide() end)
        im.editBox = eb

        local okBtn = CreateFrame("Button", nil, im, "UIPanelButtonTemplate")
        okBtn:SetSize(96, 22)
        okBtn:SetPoint("BOTTOMLEFT", 12, 12)
        okBtn:SetText("|cff00ff00Import|r")
        okBtn:SetScript("OnClick", function()
            local farm, err = ParseImportString(im.editBox:GetText())
            if not farm then
                ns:Print(ns.Colors.red .. tostring(err) .. ns.Colors.reset)
                return
            end
            table.insert(EnsureFarmsDB(), farm)
            im:Hide()
            ns:Print("Imported farm: |cff00ccff" .. farm.name .. "|r.")
            mod:RefreshList()
        end)

        local cancelBtn = CreateFrame("Button", nil, im, "UIPanelButtonTemplate")
        cancelBtn:SetSize(96, 22)
        cancelBtn:SetPoint("BOTTOMRIGHT", -12, 12)
        cancelBtn:SetText("Cancel")
        cancelBtn:SetScript("OnClick", function() im:Hide() end)

        im:Hide()
        importFrame = im
    end

    ns.Utils.ApplyBackdropTheme(importFrame, false, false)
    importFrame.editBox:SetText("")
    importFrame:Show()
    importFrame.editBox:SetFocus()
end

function mod:PromptSaveFromHistory(entry)
    if not entry then return end

    if not saveFrame then
        local sf = CreateFrame("Frame", "FarmTrackerSaveFarmFrame", UIParent, "BackdropTemplate")
        tinsert(UISpecialFrames, "FarmTrackerSaveFarmFrame")
        sf:SetSize(370, 212)
        sf:SetPoint("CENTER")
        sf:SetFrameStrata("FULLSCREEN_DIALOG")
        sf:SetMovable(true)
        sf:EnableMouse(true)
        sf:RegisterForDrag("LeftButton")
        sf:SetClampedToScreen(true)
        sf:SetScript("OnDragStart", sf.StartMoving)
        sf:SetScript("OnDragStop", sf.StopMovingOrSizing)

        local title = sf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 14, -12)
        title:SetText("|cff00ccffSave History Run as Farm|r")

        local nameLbl = sf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameLbl:SetPoint("TOPLEFT", 14, -38)
        nameLbl:SetText("Farm Name:")

        local nameBox = CreateFrame("EditBox", "FarmTrackerSaveFarmName", sf, "InputBoxTemplate")
        nameBox:SetSize(230, 20)
        nameBox:SetPoint("TOPRIGHT", -14, -34)
        nameBox:SetAutoFocus(false)
        sf.nameBox = nameBox

        local catLbl = sf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        catLbl:SetPoint("TOPLEFT", 14, -66)
        catLbl:SetText("Category:")

        sf.catBtns = {}
        local function SelectCat(catKey)
            sf.selectedCat = catKey
            for _, b in ipairs(sf.catBtns) do
                if b.catKey == catKey then
                    b:SetText("|cff00ccff" .. b.catLabel .. "|r")
                else
                    b:SetText("|cffcccccc" .. b.catLabel .. "|r")
                end
            end
        end
        sf.SelectCat = SelectCat

        for i, cat in ipairs(SAVE_CATEGORIES) do
            local col    = (i - 1) % 4
            local rowIdx = math.floor((i - 1) / 4)
            local b = CreateFrame("Button", nil, sf, "UIPanelButtonTemplate")
            b:SetSize(60, 20)
            b:SetPoint("TOPLEFT", 104 + (col * 64), -62 - (rowIdx * 24))
            b:SetNormalFontObject("GameFontHighlightSmall")
            b.catKey   = cat.key
            b.catLabel = cat.label
            b:SetScript("OnClick", function() SelectCat(cat.key) end)
            table.insert(sf.catBtns, b)
        end

        local routeLbl = sf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        routeLbl:SetPoint("TOPLEFT", 14, -120)
        routeLbl:SetText("Optional Routes String |cffaaaaaa(RoutesImportExport):|r")

        local routeBox = CreateFrame("EditBox", "FarmTrackerSaveFarmRoute", sf, "InputBoxTemplate")
        routeBox:SetSize(336, 20)
        routeBox:SetPoint("TOPLEFT", 18, -138)
        routeBox:SetAutoFocus(false)
        sf.routeBox = routeBox

        local saveBtn = CreateFrame("Button", nil, sf, "UIPanelButtonTemplate")
        saveBtn:SetSize(100, 22)
        saveBtn:SetPoint("BOTTOMLEFT", 14, 12)
        saveBtn:SetText("|cff00ff00Save Farm|r")
        sf.saveBtn = saveBtn

        local cancelBtn = CreateFrame("Button", nil, sf, "UIPanelButtonTemplate")
        cancelBtn:SetSize(100, 22)
        cancelBtn:SetPoint("BOTTOMRIGHT", -14, 12)
        cancelBtn:SetText("Cancel")
        cancelBtn:SetScript("OnClick", function() sf:Hide() end)

        sf:Hide()
        saveFrame = sf
    end

    ns.Utils.ApplyBackdropTheme(saveFrame, false, false)
    saveFrame.nameBox:SetText(entry.zone or "Custom Farm")
    saveFrame.routeBox:SetText("")
    saveFrame.SelectCat(entry.dungeonMode and "Dungeon" or "Mob Grind")

    saveFrame.saveBtn:SetScript("OnClick", function()
        local hours = math.max((entry.duration or 60) / 3600, 1 / 3600)
        local hourlyItems = {}
        if type(entry.items) == "table" then
            for id, count in pairs(entry.items) do
                if tonumber(id) and (tonumber(count) or 0) > 0 then
                    hourlyItems[tonumber(id)] = tonumber(count) / hours
                end
            end
        end

        local cleanName = strtrim(saveFrame.nameBox:GetText() or "")
        local farm = {
            name         = (cleanName ~= "" and cleanName) or (entry.zone or "Custom Farm"),
            zone         = entry.zone or "Unknown",
            category     = saveFrame.selectedCat or "Other",
            rawGphCopper = math.floor((entry.rawCopper or 0) / hours),
            items        = hourlyItems,
            route        = strtrim(saveFrame.routeBox:GetText() or ""),
        }

        table.insert(EnsureFarmsDB(), farm)
        saveFrame:Hide()
        ns:Print("Saved |cff00ccff" .. farm.name .. "|r to Farm Finder (" .. farm.category .. ").")
        if finderFrame and finderFrame:IsShown() then
            mod:RefreshList()
        end
    end)

    saveFrame:Show()
    saveFrame.nameBox:SetFocus()
    saveFrame.nameBox:HighlightText()
end

local function CreateFinderUI()
    if finderFrame then return finderFrame end

    local f = CreateFrame("Frame", "FarmTrackerFarmFinderFrame", UIParent, "BackdropTemplate")
    tinsert(UISpecialFrames, "FarmTrackerFarmFinderFrame")
    f:SetSize(600, 430)
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
    title:SetText("|cff00ccffFarm|r Finder")

    local closeBtn = CreateFrame("Button", nil, f)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("TOPRIGHT", -8, -8)
    closeBtn:SetNormalFontObject("GameFontNormal")
    closeBtn:SetText("|cffff5555X|r")
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local div1 = f:CreateTexture(nil, "ARTWORK")
    div1:SetColorTexture(0.25, 0.25, 0.3, 0.8)
    div1:SetSize(572, 1)
    div1:SetPoint("TOP", 0, -34)

    -- Continent Filter Bar (Larger buttons above categories)
    f.contBtns = {}
    local function SetContinent(contKey)
        activeContinent = contKey
        for _, b in ipairs(f.contBtns) do
            if b.contKey == contKey then
                b:SetText("|cffffd700" .. b.contLabel .. "|r")
                b:Disable()
            else
                b:SetText("|cffcccccc" .. b.contLabel .. "|r")
                b:Enable()
            end
        end
        mod:RefreshList()
    end

    for i, cont in ipairs(CONTINENTS) do
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(186, 24)
        b:SetPoint("TOPLEFT", 14 + ((i - 1) * 193), -40)
        b:SetNormalFontObject("GameFontNormal")
        b:SetDisabledFontObject("GameFontNormal")
        b.contKey   = cont.key
        b.contLabel = cont.label
        b:SetScript("OnClick", function() SetContinent(cont.key) end)
        table.insert(f.contBtns, b)
    end

    -- Category Filter Buttons (9 tabs)
    f.filterBtns = {}
    local function SetFilter(catKey)
        activeFilter = catKey
        for _, b in ipairs(f.filterBtns) do
            if b.catKey == catKey then
                b:SetText("|cff00ccff" .. b.catLabel .. "|r")
                b:Disable()
            else
                b:SetText("|cffcccccc" .. b.catLabel .. "|r")
                b:Enable()
            end
        end
        mod:RefreshList()
    end

    for i, cat in ipairs(CATEGORIES) do
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(60, 20)
        b:SetPoint("TOPLEFT", 14 + ((i - 1) * 64), -70)
        b:SetNormalFontObject("GameFontHighlightSmall")
        b:SetDisabledFontObject("GameFontHighlightSmall")
        b.catKey   = cat.key
        b.catLabel = cat.label
        b:SetScript("OnClick", function() SetFilter(cat.key) end)
        table.insert(f.filterBtns, b)
    end

    local div2 = f:CreateTexture(nil, "ARTWORK")
    div2:SetColorTexture(0.25, 0.25, 0.3, 0.8)
    div2:SetSize(572, 1)
    div2:SetPoint("TOP", 0, -94)

    -- Sortable Column Headers
    f.sortHeaders = {}
    local function CreateSortHeader(key, label, width, justify, defaultAsc)
        local btn = CreateFrame("Button", nil, f)
        btn:SetSize(width, 18)
        btn.baseLabel = label

        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(0.2, 0.5, 0.8, 0.2)

        local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetAllPoints()
        txt:SetJustifyH(justify)
        txt:SetText("|cffaaaaaa" .. label .. "|r")
        btn.txt = txt

        btn:SetScript("OnClick", function()
            if sortBy == key then
                sortAsc = not sortAsc
            else
                sortBy  = key
                sortAsc = defaultAsc
            end
            mod:RefreshList()
        end)

        f.sortHeaders[key] = btn
        return btn
    end

    local colGph = CreateSortHeader("gph", "Gold / Hr", 92, "RIGHT", false)
    colGph:SetPoint("TOPRIGHT", -154, -98)

    local colCat = CreateSortHeader("category", "Category", 68, "RIGHT", true)
    colCat:SetPoint("RIGHT", colGph, "LEFT", -6, 0)

    local colZone = CreateSortHeader("zone", "Farm / Zone", 260, "LEFT", true)
    colZone:SetPoint("TOPLEFT", 14, -98)

    local div3 = f:CreateTexture(nil, "ARTWORK")
    div3:SetColorTexture(0.25, 0.25, 0.3, 0.8)
    div3:SetSize(572, 1)
    div3:SetPoint("TOP", 0, -118)

    local scrollFrame = CreateFrame("ScrollFrame", "FarmTrackerFinderScroll", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -122)
    scrollFrame:SetPoint("BOTTOMRIGHT", -32, 42)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(552)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    f.scrollFrame = scrollFrame
    f.scrollChild = scrollChild

    local emptyText = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("CENTER", 0, -10)
    emptyText:SetText("No farms saved yet. Click '+' in Session History or Import a farm string.")
    f.emptyText = emptyText

    local importBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    importBtn:SetSize(104, 22)
    importBtn:SetPoint("BOTTOMLEFT", 14, 12)
    importBtn:SetText("|cff00ff00Import Farm|r")
    importBtn:SetScript("OnClick", ShowImportModal)

    local refreshBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    refreshBtn:SetSize(114, 22)
    refreshBtn:SetPoint("LEFT", importBtn, "RIGHT", 8, 0)
    refreshBtn:SetText("Refresh Prices")
    refreshBtn:SetScript("OnClick", function() mod:RefreshList() end)

    local doneBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    doneBtn:SetSize(96, 22)
    doneBtn:SetPoint("BOTTOMRIGHT", -14, 12)
    doneBtn:SetText("Close")
    doneBtn:SetScript("OnClick", function() f:Hide() end)

    f:Hide()
    finderFrame = f
    ns.Utils.ApplyBackdropTheme(f, false, false)
    SetContinent("ALL")
    SetFilter("ALL")
    return f
end

function mod:RefreshTheme()
    if finderFrame then ns.Utils.ApplyBackdropTheme(finderFrame, false, false) end
    if importFrame then ns.Utils.ApplyBackdropTheme(importFrame, false, false) end
    if saveFrame then ns.Utils.ApplyBackdropTheme(saveFrame, false, false) end
end

function mod:ToggleUI()
    local f = CreateFinderUI()
    if f:IsShown() then
        f:Hide()
    else
        self:RefreshList()
        f:Show()
    end
end

function mod:OnInit()
    local cacheFrame = CreateFrame("Frame")
    cacheFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    cacheFrame:SetScript("OnEvent", function(_, _, _, success)
        if not success or not finderFrame or not finderFrame:IsShown() then return end
        if not refreshQueued then
            refreshQueued = true
            C_Timer.After(0.25, function()
                refreshQueued = false
                if finderFrame and finderFrame:IsShown() then
                    mod:RefreshList()
                end
            end)
        end
    end)
end