local _, ns = ...

local mod = ns:RegisterModule("MyNewTweak", {})

function mod:OnInit()
    if not ns.db.myNewTweak then return end

    -- Put tweak logic here
end