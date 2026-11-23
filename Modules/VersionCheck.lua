local addonName, ns = ...

local mod = ns:RegisterModule("VersionCheck", {})

local PREFIX = "FarmTracker"
local alertedThisSession = false
local lastBroadcast = 0

local function GetAddonVersion()
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(addonName, "Version") or "0.0.0"
    elseif GetAddOnMetadata then
        return GetAddOnMetadata(addonName, "Version") or "0.0.0"
    end
    return "0.0.0"
end

local function IsNewerVersion(remoteVer, localVer)
    local r1, r2, r3 = string.match(remoteVer or "", "(%d+)%.(%d+)%.(%d+)")
    local l1, l2, l3 = string.match(localVer or "", "(%d+)%.(%d+)%.(%d+)")
    if not (r1 and l1) then return false end

    r1, r2, r3 = tonumber(r1), tonumber(r2), tonumber(r3)
    l1, l2, l3 = tonumber(l1), tonumber(l2), tonumber(l3)

    if r1 ~= l1 then return r1 > l1 end
    if r2 ~= l2 then return r2 > l2 end
    return r3 > l3
end

local function SendVersion(channel)
    local ver = GetAddonVersion()
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(PREFIX, "VER:" .. ver, channel)
    elseif SendAddonMessage then
        SendAddonMessage(PREFIX, "VER:" .. ver, channel)
    end
end

local function BroadcastVersion()
    local now = GetTime()
    if (now - lastBroadcast) < 15 then return end
    lastBroadcast = now

    if IsInGuild() then
        SendVersion("GUILD")
    end
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        SendVersion("INSTANCE_CHAT")
    elseif IsInRaid() then
        SendVersion("RAID")
    elseif IsInGroup() then
        SendVersion("PARTY")
    end
end

function mod:OnInit()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    elseif RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(PREFIX)
    end

    local localVer = GetAddonVersion()

    local f = CreateFrame("Frame")
    f:RegisterEvent("CHAT_MSG_ADDON")
    f:RegisterEvent("GROUP_ROSTER_UPDATE")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")

    f:SetScript("OnEvent", function(_, event, prefix, message)
        if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
            BroadcastVersion()
            return
        end

        if event == "CHAT_MSG_ADDON" and prefix == PREFIX and message then
            local remoteVer = string.match(message, "^VER:(.+)")
            if not remoteVer then return end

            if not alertedThisSession and IsNewerVersion(remoteVer, localVer) then
                alertedThisSession = true
                ns:Print(
                    "|cffffff00A newer version (|cff00ff00v" .. remoteVer .. "|cffffff00) is available on CurseForge! " ..
                    "(You have v" .. localVer .. ")|r"
                )
            end
        end
    end)
end