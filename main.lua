local HttpService = game:GetService("HttpService")

local Fsys = require(game.ReplicatedStorage:WaitForChild("Fsys")).load
local ClientData = Fsys("ClientData")

local inventory = ClientData.get("inventory")

local VERSION = "0.5"
local HANDSHAKE_COMPLETED = false

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Adopt Me API",
    Text = "v" .. VERSION,
    Icon = ""
})

local function extractInventoryData(data, categorized)
    categorized = categorized or {}
    for _, v in pairs(data) do
        if type(v) == "table" then
            if v.category or v.id or v.unique then
                local cat = tostring(v.category or "unknown")
                local id  = tostring(v.id       or "unknown")

                if not categorized[cat] then
                    categorized[cat] = {}
                end

                if categorized[cat][id] then
                    categorized[cat][id].amount = categorized[cat][id].amount + 1
                else
                    categorized[cat][id] = { item = id, amount = 1, unique = v.unique }
                end
            end
            extractInventoryData(v, categorized)
        end
    end
    return categorized
end


local function buildPayload()
    local categorized = extractInventoryData(inventory)
    local payload = {}

    for cat, items in pairs(categorized) do
        local itemList = {}
        for _, itemData in pairs(items) do
            table.insert(itemList, itemData)
        end
        table.insert(payload, {
            category = cat,
            items = itemList
        })
    end

    return payload
end

local ws = WebSocket.connect("wss://websocket-production-fb0a.up.railway.app")


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

    if data.type == "HANDSHAKE" and not HANDSHAKE_COMPLETED then
        HANDSHAKE_COMPLETED = true
        print("Handshake completed with server.")
    end

    if data.type == "REQUEST_INVENTORY" then
        ws:Send(HttpService:JSONEncode({
            type = "INVENTORY_DATA",
            username = game.Players.LocalPlayer.Name,
            payload = buildPayload()
        }))
    end
end)