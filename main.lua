local Fsys = require(game.ReplicatedStorage:WaitForChild("Fsys")).load
local ClientData = Fsys("ClientData")

local inventory = ClientData.get("inventory")

local VERSION = "0.1"


for _, item in pairs(inventory) do
    print(item)
end


game:GetService("StarterGui"):SetCore("SendNotification",{
	Title = "Adopt Me API",
	Text = `v{VERSION}`,
	Icon = ""
})