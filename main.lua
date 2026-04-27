local Fsys = require(game.ReplicatedStorage:WaitForChild("Fsys")).load
local ClientData = Fsys("ClientData")

local inventory = ClientData.get("inventory")

local VERSION = "0.30"

local function printDescendants(tbl, indent)
    indent = indent or ""

    for key, value in pairs(tbl) do
        if type(value) == "table" then
            print(indent .. tostring(key) .. " -> (table)")
            printDescendants(value, indent .. "   ")
        else
            print(indent .. tostring(key) .. " -> " .. tostring(value))
        end
    end
end

printDescendants(inventory)


game:GetService("StarterGui"):SetCore("SendNotification",{
	Title = "Adopt Me API",
	Text = `v{VERSION}`,
	Icon = ""
})