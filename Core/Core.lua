local addonName, ns = ...

local function ApplyDefaults(db, defaults)
    for k, v in pairs(defaults) do
        if db[k] == nil then
            if type(v) == "table" then
                db[k] = {}
                ApplyDefaults(db[k], v)
            else
                db[k] = v
            end
        end
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        FarmTrackerDB = FarmTrackerDB or {}
        ApplyDefaults(FarmTrackerDB, ns.Defaults)
        ns.db = FarmTrackerDB
        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGIN" then
        local hasErrors = false
        for name, mod in pairs(ns.Modules) do
            if type(mod.OnInit) == "function" then
                local ok, err = pcall(mod.OnInit, mod)
                if not ok then
                    hasErrors = true
                    ns:Print(ns.Colors.red .. "Error loading module '" .. name .. "': " .. tostring(err) .. ns.Colors.reset)
                end
            end
        end

        if not hasErrors then
            ns:Print(ns.Colors.green .. "by Crutchie loaded successfully. " .. ns.Colors.reset .. "Type /ft for options.")
        else
            ns:Print(ns.Colors.red .. "Loaded with error." .. ns.Colors.reset)
        end
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

-- Slash Commands (/ft or /farmtracker)
SLASH_FARMTRACKER1 = "/ft"
SLASH_FARMTRACKER2 = "/farmtracker"

SlashCmdList["FARMTRACKER"] = function(msg)
    local cmd = string.lower(string.match(msg or "", "^%s*(%S*)") or "")

    if cmd == "" or cmd == "timer" or cmd == "t" then
        local timerMod = ns.Modules["Tracker"]
        if timerMod and timerMod.ToggleUI then
            timerMod:ToggleUI()
        end
        return
    end

    if cmd == "history" or cmd == "hist" or cmd == "log" then
        local histMod = ns.Modules["History"]
        if histMod and histMod.ToggleUI then
            histMod:ToggleUI()
        end
        return
    end

    if cmd == "farms" or cmd == "farm" or cmd == "finder" then
        local ffMod = ns.Modules["FarmFinder"]
        if ffMod and ffMod.ToggleUI then
            ffMod:ToggleUI()
        end
        return
    end

    if cmd == "config" or cmd == "options" or cmd == "menu" then
        local optMod = ns.Modules["Options"]
        if optMod and optMod.ToggleUI then
            optMod:ToggleUI()
        end
        return
    end

    if cmd == "testalert" then
        local timerMod = ns.Modules["Tracker"]
        if timerMod and timerMod.TestDropAlert then
            timerMod:TestDropAlert()
        end
        return
    end

    if cmd == "debug" then
        local timerMod = ns.Modules["Tracker"]
        if timerMod and timerMod.ToggleDebug then
            timerMod:ToggleDebug()
        end
        return
    end

    ns:Print("Commands:")
    print("  |cffffff00/ft|r (or |cffffff00/ft timer|r) - Toggle Farm Tracker window.")
    print("  |cffffff00/ft history|r - Open Session History log.")
    print("  |cffffff00/ft farms|r - Open the farm finder window to show best GPH farms")
    print("  |cffffff00/ft config|r - Open Settings menu.")
    print("  |cffffff00/ft testalert|r - Preview the High-Value Drop Alert.")
    print("  |cffffff00/ft debug|r - Toggle loot/coin debug output.")
end

-- Key Bindings Labels
BINDING_HEADER_FARMTRACKER          = "Farm Tracker"
BINDING_NAME_FARMTRACKER_TOGGLE     = "Toggle Tracker Window"
BINDING_NAME_FARMTRACKER_STARTPAUSE = "Start / Pause Timer"
BINDING_NAME_FARMTRACKER_NEWRUN     = "Start New Dungeon Run"
BINDING_NAME_FARMTRACKER_COMPACT    = "Toggle Compact Mode"

function FarmTracker_GetTracker()
    return ns.Modules["Tracker"]
end