local _, ns = ...

ns:RegisterBuiltInFarm({
    name = "Linen Cloth", zone = "The Barrens", category = "Cloth", rawGphCopper = 0,
    items = { [2589] = 344, [2592] = 24 },
})

ns:RegisterBuiltInFarm({
    name = "Wool Cloth", zone = "Hillsbrad Foothills", category = "Cloth", rawGphCopper = 0,
    items = { [2592] = 152, [2589] = 96, [4306] = 28 },
})

ns:RegisterBuiltInFarm({
    name = "Silk Cloth", zone = "Alterac Mountains", category = "Cloth", rawGphCopper = 0,
    items = { [4306] = 212, [2592] = 4, [4338] = 5 },
})

ns:RegisterBuiltInFarm({
    name = "Mageweave Cloth", zone = "Tanaris", category = "Cloth", rawGphCopper = 0,
    items = { [4338] = 84, [4306] = 32 },
})

ns:RegisterBuiltInFarm({
    name = "Runecloth", zone = "Western Plaguelands", category = "Cloth", rawGphCopper = 0,
    items = { [14047] = 76, [7972] = 12 },
})

ns:RegisterBuiltInFarm({
    name = "Felcloth", zone = "Felwood", category = "Cloth", rawGphCopper = 0,
    items = { [14256] = 12, [4338] = 72, [14047] = 28 },
})