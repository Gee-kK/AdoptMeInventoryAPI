local HttpService = game:GetService("HttpService")

local Fsys = require(game.ReplicatedStorage:WaitForChild("Fsys")).load
local ClientData = Fsys("ClientData")

local inventory = ClientData.get("inventory")

local VERSION = "0.4"
local HANDSHAKE_COMPLETED = false

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Adopt Me API",
    Text = "v" .. VERSION,
    Icon = ""
})

local function extractInventoryData(data, results)
    results = results or {}

    for _, v in pairs(data) do
        if type(v) == "table" then

            if v.category or v.id or v.unique then
                table.insert(results, {
                    category = v.category,
                    id = v.id,
                    unique = v.unique
                })
            end
            extractInventoryData(v, results)
        end
    end

    return results
end

local function getInventoryJSON()
    local cleaned = extractInventoryData(inventory)
    return HttpService:JSONEncode(cleaned)
end

local ws = WebSocket.connect("wss://websocket-production-fb0a.up.railway.app")

-- inital handshake
ws:Send(HttpService:JSONEncode({
    type = "IDENTIFICATION",
    username = game.Players.LocalPlayer.Name
}))

ws.OnMessage:Connect(function(msg)
    local data

    pcall(function()
        data = HttpService:JSONDecode(msg)
    end)

    if not data then return end

    -- handle initial handshake
    if data.type == "HANDSHAKE" and not HANDSHAKE_COMPLETED then
        HANDSHAKE_COMPLETED = true
        print("Handshake completed with server.")
    end


    if data.type == "REQUEST_INVENTORY" then
        ws:Send(HttpService:JSONEncode({
            type = "INVENTORY_DATA",
            username = game.Players.LocalPlayer.Name,
            payload = inventory
        }))
    end
end)
