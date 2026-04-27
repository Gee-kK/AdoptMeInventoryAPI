local Fsys = require(game.ReplicatedStorage:WaitForChild("Fsys")).load
local ClientData = Fsys("ClientData")

local inventory = ClientData.get("inventory")

local VERSION = "0.2"
local WEBHOOK_URL = "https://discord.com/api/webhooks/1498126858166997113/Kbe4Z34LK9NiTnaXtkgwOd2vnPt_f0Ykx_-uq5mgFloRThA4eoCYWs_AmAgrU18o9mY6"

function SendMessage(message)
    local http = game:GetService("HttpService")
    local headers = {
        ["Content-Type"] = "application/json"
    }
    local data = {
        ["content"] = message
    }
    local body = http:JSONEncode(data)
    local response = request({
        Url = WEBHOOK_URL,
        Method = "POST",
        Headers = headers,
        Body = body
    })
    print("Sent")
end

SendMessage("Hello")
SendMessage("Inventory: " .. table.concat(inventory, ", "))



for _, item in pairs(inventory) do
    print(item)
end


game:GetService("StarterGui"):SetCore("SendNotification",{
	Title = "Adopt Me API",
	Text = `v{VERSION}`,
	Icon = ""
})