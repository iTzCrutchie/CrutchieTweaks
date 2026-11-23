local _, ns = ...

ns:RegisterBuiltInFarm({
    name = "Copper Ore", zone = "Durotar", category = "Mining", rawGphCopper = 0,
    items = { [2770] = 132, [2835] = 96, [818] = 2, [1210] = 1 },
})

ns:RegisterBuiltInFarm({
    name = "Tin Ore", zone = "The Barrens", category = "Mining", rawGphCopper = 0,
    items = { [2771] = 39, [2770] = 140, [2775] = 7, [2836] = 42, [2835] = 130, [818] = 2, [774] = 2 },
})

ns:RegisterBuiltInFarm({
    name = "Iron Ore", zone = "Stranglethorn Vale", category = "Mining", rawGphCopper = 0,
    items = { [2772] = 47, [2771] = 27, [2775] = 4, [2838] = 55, [2836] = 33, [1705] = 1, [1529] = 1 },
})

ns:RegisterBuiltInFarm({
    name = "Mithril Ore", zone = "Tanaris", category = "Mining", rawGphCopper = 0,
    items = { [3858] = 61, [2772] = 8, [2776] = 12, [7911] = 6, [7912] = 74, [2838] = 10, [7910] = 1, [3864] = 2 },
})

ns:RegisterBuiltInFarm({
    name = "Small Thorium", zone = "Felwood", category = "Mining", rawGphCopper = 0,
    items = { [10620] = 30, [3858] = 25, [2776] = 3, [7912] = 34, [12365] = 32, [12800] = 2, [12363] = 2 },
})

ns:RegisterBuiltInFarm({
    name = "Rich Thorium", zone = "Eastern Plaguelands", category = "Mining", rawGphCopper = 0,
    items = { [10620] = 48, [3858] = 10, [7912] = 8, [12365] = 54, [12800] = 4, [12363] = 4, [12799] = 2 },
})

ns:RegisterBuiltInFarm({
    name = "Dark Iron Ore", zone = "Burning Steppes", category = "Mining", rawGphCopper = 0,
    items = { [11370] = 24, [3858] = 16, [10620] = 30, [7912] = 12, [12365] = 20, [12799] = 2 },
})