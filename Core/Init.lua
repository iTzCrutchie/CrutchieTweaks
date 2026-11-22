local addonName, ns = ...

ns.AddonName = addonName
ns.Modules   = {}

ns.Colors = {
    prefix = "|cff00ccff[FarmTracker]|r ",
    green  = "|cff00ff00",
    red    = "|cffff3333",
    yellow = "|cffffff00",
    reset  = "|r",
}

ns.Defaults = {
    farmTimer          = true,
    timerDungeonMode   = true,
    timerVendorOnly    = false,
    timerLootOpen      = false,
    timerLootMinQual   = 0,                 -- 0=All, 1=Common+, 2=Uncommon+, 3=Rare+, 4=Epic+, 5=Legendary+
    timerTheme         = "dark",            -- "dark" or "classic"
    timerFont          = "Friz Quadrata",
    timerFontSize      = 11,                -- 8 - 64 px
    timerAutoStart     = true,
    timerLocked        = false,
    timerMinimap       = true,
    timerMinimapAngle  = 220,
    timerPos           = { point = "CENTER", x = 0, y = 120 },

    -- UI Element Toggles
    showTotalGold      = true,
    showXpPerHour      = true,
    showTimeToLevel    = true,
    showTotalRuns      = true,
    showRunsPerHour    = true,
    showFastestRun     = true,
    showLockoutWarning = true,
    compactMode        = false,

    -- Pricing Alerts & Blocklists
    ahPriceSource      = "AUTO",            -- AUTO, TSM_MIN, TSM_MARKET, TSM_HIST, AUCTIONATOR, VENDOR
    dropAlertEnabled   = true,
    dropAlertThreshold = 20000,             -- 2g default (0 = alert on every drop)
    globalBlacklist    = {},

    -- Bags
    showBagSpace       = true,

    -- Timer automation
    autoPauseAFK       = true,
    autoPauseCity      = true,

    -- Progress bar
    showGoalBar        = true,
    sessionGoalCopper  = 10000000 -- 100g default


}

function ns:RegisterModule(name, tbl)
    self.Modules[name] = tbl
    return tbl
end

function ns:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(self.Colors.prefix .. tostring(msg))
end