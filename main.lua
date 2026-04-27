local Fsys = require(game.ReplicatedStorage:WaitForChild("Fsys")).load
local ClientData = Fsys("ClientData")

local inventory = ClientData.get("inventory")

print(inventory)