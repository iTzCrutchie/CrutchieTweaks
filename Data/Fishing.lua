local _, ns = ...

ns:RegisterBuiltInFarm({
    name = "Deviate Fish", zone = "The Barrens", category = "Fishing", rawGphCopper = 0,
    items = { [6522] = 56, [6289] = 81, [6308] = 41, [6291] = 34 },
})

ns:RegisterBuiltInFarm({
    name = "Redgill / Salmon", zone = "Eastern Plaguelands", category = "Fishing", rawGphCopper = 0,
    items = { [13758] = 87, [6358] = 21, [13760] = 75, [8365] = 27, [13757] = 27 },
})

ns:RegisterBuiltInFarm({
    name = "Spotted Yellowtail", zone = "The Hinterlands", category = "Fishing", rawGphCopper = 0,
    items = { [4603] = 114, [13422] = 10, [6362] = 24, [6359] = 18, [13754] = 16 },
})

ns:RegisterBuiltInFarm({
    name = "Whitescale Salmon", zone = "Durotar", category = "Fishing", rawGphCopper = 0,
    items = { [13889] = 52, [13757] = 11, [13760] = 22, [13758] = 5 },
})

ns:RegisterBuiltInFarm({
    name = "Darkclaw Lobster / Stonescale", zone = "Wetlands", category = "Fishing", rawGphCopper = 0,
    items = { [13888] = 55, [13422] = 41, [13754] = 24, [6359] = 6, [4603] = 18 },
})