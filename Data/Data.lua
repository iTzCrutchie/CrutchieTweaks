local _, ns = ...

ns.BuiltInFarms = {}

function ns:RegisterBuiltInFarm(farm)
    farm.isBuiltIn = true
    table.insert(self.BuiltInFarms, farm)
end