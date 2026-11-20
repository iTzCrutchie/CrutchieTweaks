local _, ns = ...

local mod = ns:RegisterModule("HideRaidManager", {})

local function ApplyHide()
    if not ns.db.hideRaidManager then return end

    local frame = _G.CompactRaidFrameManager
    if not frame or frame._crutchieHidden then return end

    frame:UnregisterAllEvents()
    frame:Hide()

    hooksecurefunc(frame, "Show", function(self)
        self:Hide()
    end)

    -- Hook Blizzard's internal visibility updater if it exists in this client
    if type(_G.CompactRaidFrameManager_UpdateShown) == "function" then
        hooksecurefunc("CompactRaidFrameManager_UpdateShown", function()
            if _G.CompactRaidFrameManager then
                _G.CompactRaidFrameManager:Hide()
            end
        end)
    end

    frame._crutchieHidden = true
end

function mod:OnInit()
    if not ns.db.hideRaidManager then return end

    -- Try immediately on login
    ApplyHide()

    -- Also listen for Load-On-Demand UI or party/raid changes
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("ADDON_LOADED")
    watcher:RegisterEvent("GROUP_ROSTER_UPDATE")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:SetScript("OnEvent", function()
        ApplyHide()
        if _G.CompactRaidFrameManager and _G.CompactRaidFrameManager:IsShown() then
            _G.CompactRaidFrameManager:Hide()
        end
    end)
end