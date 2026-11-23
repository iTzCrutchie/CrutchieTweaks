local _, ns = ...

local Pricing = ns:RegisterModule("Pricing", {})
ns.Pricing = Pricing

function Pricing.HasTSM()
    return (_G.TSM_API and _G.TSM_API.GetCustomPriceValue) ~= nil
end

function Pricing.HasAuctionator()
    return (_G.Auctionator and _G.Auctionator.API and _G.Auctionator.API.v1) ~= nil
end

function Pricing.HasAnyAHAddon()
    return Pricing.HasTSM() or Pricing.HasAuctionator()
end

function Pricing.IsVendorOnlyMode()
    if not Pricing.HasAnyAHAddon() or (ns.db and ns.db.ahPriceSource == "VENDOR") then
        return true
    end
    return ns.db and ns.db.timerVendorOnly == true
end

function Pricing.IsItemBlocked(itemID, sessionIgnored)
    if not itemID then return false end
    local key = tostring(itemID)
    if sessionIgnored and sessionIgnored[key] then return true end
    if ns.db and ns.db.globalBlacklist and ns.db.globalBlacklist[key] then return true end
    return false
end

local function QueryTSM(priceKey, tsmItemString)
    if not (Pricing.HasTSM() and tsmItemString) then return 0 end
    local ok, val = pcall(_G.TSM_API.GetCustomPriceValue, priceKey, tsmItemString)
    if ok and type(val) == "number" and val > 0 then
        return val
    end
    return 0
end

local function QueryAuctionator(itemID, cleanLink)
    if not Pricing.HasAuctionator() then return 0 end
    local api = _G.Auctionator.API.v1
    if itemID and api.GetAuctionPriceByItemID then
        local ok, val = pcall(api.GetAuctionPriceByItemID, "FarmTracker", itemID)
        if ok and type(val) == "number" and val > 0 then return val end
    end
    if cleanLink and api.GetAuctionPriceByItemLink then
        local ok, val = pcall(api.GetAuctionPriceByItemLink, "FarmTracker", cleanLink)
        if ok and type(val) == "number" and val > 0 then return val end
    end
    return 0
end

function Pricing.GetItemAHValue(itemID, cleanLink, vendorUnitPrice, isBoP)
    local vendor = vendorUnitPrice or 0
    if isBoP or not Pricing.HasAnyAHAddon() then
        return vendor
    end

    local source = (ns.db and ns.db.ahPriceSource) or "AUTO"
    if source == "VENDOR" then
        return vendor
    end

    local ahUnit = 0
    local tsmItemString = itemID and ("i:" .. itemID) or nil

    if source == "TSM_MIN" then
        ahUnit = QueryTSM("DBMinBuyout", tsmItemString)
    elseif source == "TSM_MARKET" then
        ahUnit = QueryTSM("DBMarket", tsmItemString)
    elseif source == "TSM_HIST" then
        ahUnit = QueryTSM("DBHistorical", tsmItemString)
    elseif source == "AUCTIONATOR" then
        ahUnit = QueryAuctionator(itemID, cleanLink)
    else
        ahUnit = QueryTSM("DBMinBuyout", tsmItemString)
        if ahUnit == 0 then ahUnit = QueryTSM("DBMarket", tsmItemString) end
        if ahUnit == 0 then ahUnit = QueryAuctionator(itemID, cleanLink) end
    end

    if ahUnit < vendor then ahUnit = vendor end
    return ahUnit
end