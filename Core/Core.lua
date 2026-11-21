local addonName, ns = ...

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        CrutchieTweaksDB = CrutchieTweaksDB or {}
        for k, v in pairs(ns.Defaults) do
            if CrutchieTweaksDB[k] == nil then
                CrutchieTweaksDB[k] = v
            end
        end
        ns.db = CrutchieTweaksDB

    elseif event == "PLAYER_LOGIN" then
        local hasErrors = false

        for name, module in pairs(ns.Modules) do
            if module.OnInit then
                local ok, err = pcall(module.OnInit, module)
                if not ok then
                    hasErrors = true
                    ns:Print(ns.Colors.red .. "Error loading module [" .. name .. "]: " .. tostring(err) .. ns.Colors.reset)
                end
            end
        end

        if not hasErrors then
            ns:Print(ns.Colors.green .. "Loaded successfully. Type /ct for options." .. ns.Colors.reset)
        else
            ns:Print(ns.Colors.red .. "Loaded with errors." .. ns.Colors.reset)
        end
    end
end)

-- Slash Commands (/ct or /crutchietweaks)
SLASH_CRUTCHIETWEAKS1 = "/ct"
SLASH_CRUTCHIETWEAKS2 = "/crutchietweaks"

SlashCmdList["CRUTCHIETWEAKS"] = function(msg)
    local cmd = string.lower(strtrim(msg or ""))

    -- Open In-Game Settings Menu
    if cmd == "config" or cmd == "options" or cmd == "menu" then
        local optMod = ns.Modules["Options"]
        if optMod and optMod.ToggleUI then
            optMod:ToggleUI()
        end
        return
    end

    -- Toggle Farm Timer UI
    if cmd == "timer" or cmd == "t" then
        local timerMod = ns.Modules["FarmTimer"]
        if timerMod and timerMod.ToggleUI then
            timerMod:ToggleUI()
        else
            ns:Print(ns.Colors.red .. "FarmTimer module is disabled or not loaded." .. ns.Colors.reset)
        end
        return
    end

    -- debug
    if cmd == "debug" then
        local timerMod = ns.Modules["FarmTimer"]
        if timerMod and timerMod.ToggleDebug then
            timerMod:ToggleDebug()
        end
        return
    end

    if cmd == "" or cmd == "help" then
        ns:Print("Commands & Toggles (toggles require /reload):")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff00ccff/ct timer|r - Open/Close the Solo Farm Timer")
        for k, v in pairs(ns.db) do
            if type(v) == "boolean" then
                local state = v and (ns.Colors.green .. "ON" .. ns.Colors.reset) or (ns.Colors.red .. "OFF" .. ns.Colors.reset)
                DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00" .. k .. "|r: " .. state)
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage("Usage: |cff00ccff/ct <setting>|r to toggle.")
        return
    end

    -- Case-insensitive lookup in ns.db
    for k, v in pairs(ns.db) do
        if string.lower(k) == cmd and type(v) == "boolean" then
            ns.db[k] = not v
            local state = ns.db[k] and (ns.Colors.green .. "ON" .. ns.Colors.reset) or (ns.Colors.red .. "OFF" .. ns.Colors.reset)
            ns:Print(k .. " is now " .. state .. ". Type |cffffff00/reload|r to apply.")
            return
        end
    end

    ns:Print(ns.Colors.red .. "Unknown setting: " .. cmd .. ns.Colors.reset)
end