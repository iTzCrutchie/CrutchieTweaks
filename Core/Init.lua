local addonName, ns = ...

ns.AddonName = addonName
ns.Modules = {}

-- Colors
ns.Colors = {
    cyan = "|cff00ccff", -- Cyan
    green  = "|cff00ff00", -- Green
    red    = "|cffff3333", -- Soft Bright Red
    reset  = "|r",
}

-- Default SavedVariables
ns.Defaults = {
    hideRaidManager = false,
    farmTimer       = true,
    timerDungeonMode = true,
    timerPos        = { point = "CENTER", x = 0, y = 120 },
}

-- Reusable chat print helper
function ns:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(
        ns.Colors.cyan .. "Crutchie" .. ns.Colors.reset .. "Tweaks: " .. tostring(msg)
    )
end

-- Helper to register modules cleanly
function ns:RegisterModule(name, moduleTable)
    self.Modules[name] = moduleTable
    return moduleTable
end