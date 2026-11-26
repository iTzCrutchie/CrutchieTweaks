local _, ns = ...

local Profiles = ns:RegisterModule("Profiles", {})
ns.Profiles = Profiles

local PROFILE_KEYS = {
    "farmTimer",
    "timerMinimap",
    "timerMinimapAngle",
    "timerPos",
    "timerLocked",
    "timerDungeonMode",
    "timerLootOpen",
    "lootMinQuality",
    "timerVendorOnly",
    "timerFontSize",
    "timerFont",
    "timerTheme",
    "timerBgAlpha",
    "compactMode",
    "compactClickThru",
    "ahPriceSource",
    "dropAlertEnabled",
    "dropAlertThreshold",
    "dropAlertSound",
    "showGoalBar",
    "sessionGoalCopper",
    "showTotalGold",
    "showTotalRuns",
    "showRunsPerHour",
    "showFastestRun",
    "showLockoutWarning",
    "showXpPerHour",
    "showTimeToLevel",
    "showBagSpace",
    "timerAutoStart",
    "autoPauseAFK",
    "autoPauseCity",
    "autoResume",
    "autoResumeCombat",
    "globalBlacklist",
}

local function CloneValue(val)
    if type(val) ~= "table" then
        return val
    end
    local copy = {}
    for k, v in pairs(val) do
        copy[k] = CloneValue(v)
    end
    return copy
end

local function EnsureDB()
    FarmTrackerDB = FarmTrackerDB or {}
    FarmTrackerDB.profiles = FarmTrackerDB.profiles or {}
    FarmTrackerDB.charProfileAssignments = FarmTrackerDB.charProfileAssignments or {}
    FarmTrackerDB.charSessions = FarmTrackerDB.charSessions or {}

    if not FarmTrackerDB.profiles["Default"] then
        local defProfile = {}
        for _, key in ipairs(PROFILE_KEYS) do
            local val = FarmTrackerDB[key]
            if val == nil and ns.Defaults then
                val = ns.Defaults[key]
            end
            defProfile[key] = CloneValue(val)
        end
        FarmTrackerDB.profiles["Default"] = defProfile
    end

    return FarmTrackerDB
end

local function CopyProfileIntoDB(profileTbl)
    local db = EnsureDB()
    for _, key in ipairs(PROFILE_KEYS) do
        local srcVal
        if type(profileTbl) == "table" and profileTbl[key] ~= nil then
            srcVal = profileTbl[key]
        elseif ns.Defaults and ns.Defaults[key] ~= nil then
            srcVal = ns.Defaults[key]
        end
        db[key] = CloneValue(srcVal)
    end
    ns.db = db
end

local function SnapshotDBIntoProfile(profileTbl)
    local db = EnsureDB()
    if type(profileTbl) ~= "table" then return end
    for _, key in ipairs(PROFILE_KEYS) do
        profileTbl[key] = CloneValue(db[key])
    end
end

function Profiles.GetActiveProfileName()
    local db = EnsureDB()
    local charKey = ns.Utils.GetCharacterKey()
    local assigned = db.charProfileAssignments[charKey]
    if assigned and db.profiles[assigned] then
        return assigned
    end
    db.charProfileAssignments[charKey] = "Default"
    return "Default"
end

function Profiles.GetProfileNames()
    local db = EnsureDB()
    local names = {}
    for name in pairs(db.profiles) do
        table.insert(names, name)
    end
    table.sort(names, function(a, b)
        if a == "Default" then return true end
        if b == "Default" then return false end
        return string.lower(a) < string.lower(b)
    end)
    return names
end

function Profiles.SyncCurrentProfileFromDB()
    local db = EnsureDB()
    local activeName = Profiles.GetActiveProfileName()
    db.profiles[activeName] = db.profiles[activeName] or {}
    SnapshotDBIntoProfile(db.profiles[activeName])
end

function Profiles.ApplyProfile(profileName)
    local db = EnsureDB()
    if not profileName or not db.profiles[profileName] then
        profileName = "Default"
    end
    local charKey = ns.Utils.GetCharacterKey()
    db.charProfileAssignments[charKey] = profileName
    CopyProfileIntoDB(db.profiles[profileName])
    return profileName
end

function Profiles.CreateProfile(newName, copyCurrent)
    local db = EnsureDB()
    local clean = strtrim(newName or "")
    if clean == "" then
        return nil, "Enter a profile name first."
    end
    if db.profiles[clean] then
        return nil, "A profile named '" .. clean .. "' already exists."
    end

    local sourceTbl = {}
    if copyCurrent ~= false then
        Profiles.SyncCurrentProfileFromDB()
        sourceTbl = db.profiles[Profiles.GetActiveProfileName()] or {}
    else
        for _, key in ipairs(PROFILE_KEYS) do
            sourceTbl[key] = CloneValue(ns.Defaults and ns.Defaults[key])
        end
    end

    local created = {}
    for _, key in ipairs(PROFILE_KEYS) do
        created[key] = CloneValue(sourceTbl[key])
    end

    db.profiles[clean] = created
    Profiles.ApplyProfile(clean)
    return clean
end

function Profiles.DeleteProfile(profileName)
    local db = EnsureDB()
    if not profileName or profileName == "Default" then
        return false, "The Default profile cannot be deleted."
    end
    if not db.profiles[profileName] then
        return false, "Profile not found."
    end

    db.profiles[profileName] = nil

    for charKey, assigned in pairs(db.charProfileAssignments) do
        if assigned == profileName then
            db.charProfileAssignments[charKey] = "Default"
        end
    end

    if ns.Utiils.GetCharacterKey() and db.charProfileAssignments[GetCharacterKey()] == "Default" then
        Profiles.ApplyProfile("Default")
    end

    return true
end

function Profiles.NotifyAllUI()
    if ns.Tracker and ns.Tracker.RefreshSettings then
        ns.Tracker:RefreshSettings()
    end
    if ns.MinimapButton and ns.MinimapButton.Refresh then
        ns.MinimapButton:Refresh()
    end
    local histMod = ns.Modules["History"]
    if histMod and histMod.RefreshList then
        histMod:RefreshList()
    end
    local ffMod = ns.Modules["FarmFinder"]
    if ffMod then
        if ffMod.RefreshTheme then ffMod:RefreshTheme() end
        if ffMod.RefreshList then ffMod:RefreshList() end
    end
    local optMod = ns.Modules["Options"]
    if optMod and optMod.RefreshUI then
        optMod:RefreshUI()
    end
end

function Profiles:OnInit()
    EnsureDB()
    Profiles.ApplyProfile(Profiles.GetActiveProfileName())
end