local addonName, ns = ...

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        FarmTrackerDB = FarmTrackerDB or {}
        for k, v in pairs(ns.Defaults) do
            if FarmTrackerDB[k] == nil then
                FarmTrackerDB[k] = v
            end
        end
        ns.db = FarmTrackerDB

    elseif event == "PLAYER_LOGIN" then
        if ns.Profiles and ns.Profiles.OnInit then
            ns.Profiles:OnInit()
        end

        local hasErrors = false
        for name, module in pairs(ns.Modules) do
            if name ~= "Profiles" and module.OnInit then
                local ok, err = pcall(module.OnInit, module)
                if not ok then
                    hasErrors = true
                    ns:Print(ns.Colors.red .. "Error loading module [" .. name .. "]: " .. tostring(err) .. ns.Colors.reset)
                end
            end
        end

        if not hasErrors then
            ns:Print(ns.Colors.green .. "Loaded successfully. Type /ft for options." .. ns.Colors.reset)
        else
            ns:Print(ns.Colors.red .. "Loaded with errors." .. ns.Colors.reset)
        end

    elseif event == "PLAYER_LOGOUT" then
        if ns.Profiles and ns.Profiles.SyncCurrentProfileFromDB then
            ns.Profiles.SyncCurrentProfileFromDB()
        end
    end
end)

SLASH_FARMTRACKER1 = "/ft"
SLASH_FARMTRACKER2 = "/farmtracker"

SlashCmdList["FARMTRACKER"] = function(msg)
    local cmd = string.lower(strtrim(msg or ""))

    if cmd == "" or cmd == "timer" or cmd == "t" then
        local trkMod = ns.Modules["Tracker"]
        if trkMod and trkMod.ToggleUI then
            trkMod:ToggleUI()
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

    if cmd == "history" or cmd == "hist" then
        local histMod = ns.Modules["History"]
        if histMod and histMod.ToggleUI then
            histMod:ToggleUI()
        end
        return
    end

    if cmd == "config" or cmd == "menu" or cmd == "options" then
        local optMod = ns.Modules["Options"]
        if optMod and optMod.ToggleUI then
            optMod:ToggleUI()
        end
        return
    end

    if cmd == "testalert" then
        local trkMod = ns.Modules["Tracker"]
        if trkMod and trkMod.TestDropAlert then
            trkMod:TestDropAlert()
        end
        return
    end

    if cmd == "debug" then
        local trkMod = ns.Modules["Tracker"]
        if trkMod and trkMod.ToggleDebug then
            trkMod:ToggleDebug()
        end
        return
    end

    ns:Print("Commands:")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/ft|r or |cffffff00/ft timer|r - Toggle Farm Tracker window.")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/ft farms|r - Open Farm Finder.")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/ft history|r - Open Session History.")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/ft config|r - Open Settings & Profiles.")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/ft testalert|r - Preview high-value drop alert.")
    DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/ft debug|r - Toggle loot/coin debug output.")
end