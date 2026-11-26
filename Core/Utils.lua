local _, ns = ...

local Utils = {}
ns.Utils = Utils

function Utils.GetCharacterKey()
    return UnitName("player") or "Unknown"
end

function Utils.SafeGetItemInfo(item)
    if _G.C_Item and _G.C_Item.GetItemInfo then
        return _G.C_Item.GetItemInfo(item)
    elseif _G.GetItemInfo then
        return _G.GetItemInfo(item)
    end
    return nil
end

function Utils.FormatMoneyUI(copper)
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

function Utils.FormatMoneyPlain(copper)
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

function Utils.FormatTime(sec)
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

function Utils.FormatDuration(sec)
    sec = math.floor(sec or 0)
    local hrs  = math.floor(sec / 3600)
    local mins = math.floor((sec % 3600) / 60)
    local secs = sec % 60
    if hrs > 0 then
        return string.format("%dh %02dm", hrs, mins)
    else
        return string.format("%dm %02ds", mins, secs)
    end
end

function Utils.FormatTTL(sec)
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

function Utils.FormatXP(xp)
    xp = math.floor(xp or 0)
    if xp >= 1000000 then
        return string.format("%.2fM", xp / 1000000)
    elseif xp >= 1000 then
        return string.format("%.1fk", xp / 1000)
    end
    return tostring(xp)
end

function Utils.IsMaxLevel()
    return (UnitLevel("player") or 60) >= 60
end

function Utils.GetFreeBagSlots()
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

function Utils.ParseLootedCoin(msg)
    if not msg then return 0 end
    if not (string.find(msg, "You loot", 1, true) or string.find(msg, "Your share of the loot", 1, true)) then
        return 0
    end

    local gold   = tonumber(string.match(msg, "(%d+)%s+Gold")) or 0
    local silver = tonumber(string.match(msg, "(%d+)%s+Silver")) or 0
    local copper = tonumber(string.match(msg, "(%d+)%s+Copper")) or 0

    return (gold * 10000) + (silver * 100) + copper
end

function Utils.GetSelectedFontPath()
    local selected = (ns.db and ns.db.timerFont) or "Friz Quadrata"
    if ns.GetAvailableFonts then
        for _, fInfo in ipairs(ns.GetAvailableFonts()) do
            if fInfo.name == selected then
                return fInfo.path
            end
        end
    end
    return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

function Utils.GetAvailableBarTextures()
    local textures = {}
    local seen = {}

    local function AddTex(name, path)
        if name and path and not seen[name] then
            seen[name] = true
            table.insert(textures, { name = name, path = path })
        end
    end

    AddTex("Blizzard",           "Interface\\TargetingFrame\\UI-StatusBar")
    AddTex("Blizzard Raid",      "Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
    AddTex("Blizzard Skill",     "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar")
    AddTex("Flat (Solid)",       "Interface\\Buttons\\WHITE8x8")

    -- Pull from LibSharedMedia-3.0 (includes SharedMedia, Atrocity, etc.)
    local lsm = _G.LibStub and _G.LibStub("LibSharedMedia-3.0", true)
    if lsm and lsm.List and lsm.Fetch then
        for _, name in ipairs(lsm:List("statusbar")) do
            local path = lsm:Fetch("statusbar", name, true)
            if path then
                AddTex(name, path)
            end
        end
    end

    -- Pull directly from EllesmereUI if loaded
    if _G.EllesmereUI and type(_G.EllesmereUI.BAR_TEXTURE_FILES) == "table" then
        local names = _G.EllesmereUI.BAR_TEXTURE_NAMES or {}
        for key, path in pairs(_G.EllesmereUI.BAR_TEXTURE_FILES) do
            local label = names[key] or tostring(key)
            AddTex(label, path)
        end
    end

    table.sort(textures, function(a, b)
        return a.name:lower() < b.name:lower()
    end)

    return textures
end

function Utils.GetSelectedBarTexturePath()
    local target = ns.db and ns.db.goalBarTexture or "Blizzard"
    for _, info in ipairs(Utils.GetAvailableBarTextures()) do
        if info.name == target then
            return info.path
        end
    end
    return "Interface\\TargetingFrame\\UI-StatusBar"
end

function Utils.ApplyBackdropTheme(frame, isTab, useCustomAlpha)
    if not frame or not frame.SetBackdrop then return end
    local alpha = (useCustomAlpha and ns.db and tonumber(ns.db.timerBgAlpha)) or nil
    if ns.db and ns.db.timerTheme == "classic" then
        frame:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile     = true,
            tileSize = 32,
            edgeSize = isTab and 12 or 16,
            insets   = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        frame:SetBackdropColor(1, 1, 1, alpha or 0.95)
        frame:SetBackdropBorderColor(0.85, 0.75, 0.55, 1)
    else
        frame:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile     = false,
            edgeSize = 1,
        })
        frame:SetBackdropColor(0.06, 0.06, 0.08, alpha or 0.92)
        frame:SetBackdropBorderColor(0.2, 0.2, 0.25, 1)
    end
end

Utils.AlertSounds = {
    { key = "COIN",      label = "Loot Coins",     id = (SOUNDKIT and SOUNDKIT.LOOT_WINDOW_COIN_SOUND) or 120 },
    { key = "PING",      label = "Map Ping",       id = (SOUNDKIT and SOUNDKIT.MAP_PING) or 3175 },
    { key = "WHISPER",   label = "Whisper Chime",  id = (SOUNDKIT and SOUNDKIT.TELL_MESSAGE) or 3081 },
    { key = "READY",     label = "Ready Check",    id = (SOUNDKIT and SOUNDKIT.READY_CHECK) or 8960 },
    { key = "QUEST",     label = "Quest Complete", id = (SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_COMPLETE) or 878 },
    { key = "RAID_WARN", label = "Raid Warning",   id = (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959 },
}

function Utils.PlayDropAlertSound()
    if ns.db and ns.db.dropAlertMuted then return end

    local soundKey = (ns.db and ns.db.dropAlertSound) or "COIN"
    local soundID  = 120
    for _, s in ipairs(Utils.AlertSounds) do
        if s.key == soundKey then
            soundID = s.id
            break
        end
    end

    if soundID then
        pcall(PlaySound, soundID, "SFX")
    end
end

local copyFrame = nil

function Utils.ShowCopyPopup(text, titleText)
    if not copyFrame then
        local cf = CreateFrame("Frame", "FarmTrackerCopyFrame", UIParent, "BackdropTemplate")
        tinsert(UISpecialFrames, "FarmTrackerCopyFrame")
        cf:SetSize(440, 128)
        cf:SetPoint("CENTER")
        cf:SetFrameStrata("FULLSCREEN_DIALOG")
        cf:SetMovable(true)
        cf:EnableMouse(true)
        cf:RegisterForDrag("LeftButton")
        cf:SetClampedToScreen(true)
        cf:SetScript("OnDragStart", cf.StartMoving)
        cf:SetScript("OnDragStop", cf.StopMovingOrSizing)

        local title = cf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 12, -10)
        cf.title = title

        local hint = cf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPRIGHT", -12, -11)
        hint:SetText("|cffaaaaaaPress Ctrl+C to copy|r")

        local ebBg = CreateFrame("Frame", nil, cf, "BackdropTemplate")
        ebBg:SetPoint("TOPLEFT", 12, -30)
        ebBg:SetPoint("BOTTOMRIGHT", -12, 38)
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
        eb:SetScript("OnEscapePressed", function() cf:Hide() end)
        cf.editBox = eb

        local closeBtn = CreateFrame("Button", nil, cf, "UIPanelButtonTemplate")
        closeBtn:SetSize(90, 22)
        closeBtn:SetPoint("BOTTOM", 0, 10)
        closeBtn:SetText("Close")
        closeBtn:SetScript("OnClick", function() cf:Hide() end)

        cf:Hide()
        copyFrame = cf
    end

    Utils.ApplyBackdropTheme(copyFrame, false, false)
    copyFrame.title:SetText(titleText or "|cff00ccffCopy Summary|r")
    copyFrame.editBox:SetText(text or "")
    copyFrame:Show()
    copyFrame.editBox:SetFocus()
    copyFrame.editBox:HighlightText()
end