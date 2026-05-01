local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ScreenGui = game:GetService("Players")
local VirtualUser = game:GetService('VirtualUser')

local Fsys = require(game.ReplicatedStorage:WaitForChild("Fsys")).load
local ClientData = Fsys("ClientData")
local RouterClient = Fsys("RouterClient")

local inventory = ClientData.get("inventory")

local VERSION = "1"
local HANDSHAKE_COMPLETED = false
local ISCONNECTED = false

local ws = WebSocket.connect("wss://goatedwebsocket.duckdns.org/ws/")

local isProcessingDelivery = false
local deliveryQueue = {}

game:GetService("StarterGui"):SetCore("SendNotification", {
	Title = "Adopt Me API",
	Text = "v" .. VERSION,
	Icon = ""
})

local function flattenInventory(tbl, index)
	index = index or {}

	for _, v in pairs(tbl) do
		if type(v) == "table" then
			if v.id and v.unique then
				index[v.id] = index[v.id] or {}
				table.insert(index[v.id], v.unique)
			end

			flattenInventory(v, index)
		end
	end

	return index
end

local function takeUnique(index, itemId)
	local list = index[itemId]
	if not list or #list == 0 then
		return nil
	end

	return table.remove(list)
end




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

local function deliverItems(targetPlayer, itemsToDeliver)

    local inventory = ClientData.get("inventory")
    local inventoryIndex = flattenInventory(inventory)

    local allItemsFlattened = {}

    for _, entry in ipairs(itemsToDeliver) do
        if #(inventoryIndex[entry.name] or {}) < entry.amount then
            warn("Not enough items for:", entry.named)
        end

        for i = 1, entry.amount do
            table.insert(allItemsFlattened, entry.name)
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
            repeat
				task.wait(2)
				RouterClient.get("TradeAPI/SendTradeRequest"):FireServer(targetPlayer)
            until game.Players.LocalPlayer.PlayerGui.TradeApp.Frame.Visible
        end

        for _, itemId in ipairs(currentBatch) do
            local itemUid = takeUnique(inventoryIndex, itemId)

            if itemUid then
                RouterClient.get("TradeAPI/AddItemToOffer"):FireServer(itemUid)
                task.wait(0.25)
            else
                warn("Ran out of uniques for:", itemId)
            end
        end

                task.wait(7)

        RouterClient.get("TradeAPI/AcceptNegotiation"):FireServer()
        
        if game:GetService("Players").LocalPlayer.PlayerGui.TradeApp.Frame.NegotiationFrame.Body.MyOffer.Accepted.ImageTransparency ~= 0.3 then
            repeat
                task.wait(1)
                RouterClient.get("TradeAPI/AcceptNegotiation"):FireServer()
            until game:GetService("Players").LocalPlayer.PlayerGui.TradeApp.Frame.NegotiationFrame.Body.MyOffer.Accepted.ImageTransparency == 0.3 or game.Players.LocalPlayer.PlayerGui.TradeApp.Frame.ConfirmationFrame.Visible
        end

        if not game.Players.LocalPlayer.PlayerGui.TradeApp.Frame.ConfirmationFrame.Visible then
            repeat task.wait(.5)
            until game.Players.LocalPlayer.PlayerGui.TradeApp.Frame.ConfirmationFrame.Visible
        end

        task.wait(.5)

        RouterClient.get("TradeAPI/ConfirmTrade"):FireServer()

        if game:GetService("Players").LocalPlayer.PlayerGui.TradeApp.Frame.ConfirmationFrame.MyOffer.Accepted.ImageTransparency ~= 0.3 then
            repeat
                task.wait(1)
                RouterClient.get("TradeAPI/ConfirmTrade"):FireServer()
            until game:GetService("Players").LocalPlayer.PlayerGui.TradeApp.Frame.ConfirmationFrame.MyOffer.Accepted.ImageTransparency == 0.3 or game:GetService("Players").LocalPlayer.PlayerGui.TradeApp.Frame.Visible == false
        end

        task.wait(2)
    end
end

local function processDeliveryQueue()
    if isProcessingDelivery then return end
    isProcessingDelivery = true

    while #deliveryQueue > 0 do
        local job = table.remove(deliveryQueue, 1)

        local targetPlayer = game.Players:FindFirstChild(job.player)
        local order = job.order

		if not targetPlayer then
			print("NO TARGET PLAYER")
			repeat
				task.wait(1)
				targetPlayer = game.Players:FindFirstChild(job.player)
			until targetPlayer
		end

        print("Processing delivery for:", targetPlayer.Name)

        deliverItems(targetPlayer, order)

        ws:Send(HttpService:JSONEncode({
            type = "DELIVERYCOMPLETED",
            username = game.Players.LocalPlayer.Name,
            payload = buildPayload()
        }))



        task.wait(1)
    end

    isProcessingDelivery = false
end



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
        ISCONNECTED = true
		print("Handshake completed with server.")
 
		game:GetService('Players').LocalPlayer.Idled:Connect(function()
    		VirtualUser:CaptureController()
    		VirtualUser:ClickButton2(Vector2.new())
		end)
	end

	if data.type == "REQUEST_INVENTORY" then
		ws:Send(HttpService:JSONEncode({
			type = "INVENTORY_DATA",
			username = game.Players.LocalPlayer.Name,
			payload = buildPayload()
		}))
	end

	if data.type == "DELIVERY" then

		task.spawn(function()
            table.insert(deliveryQueue, {
				player = data.buyer,
				order = data.order
			})


			local accountToDeliverTo = game.Players:FindFirstChild(data.buyer)

			if not accountToDeliverTo then
				repeat
					task.wait(2)
					accountToDeliverTo = game.Players:FindFirstChild(data.buyer)
				until accountToDeliverTo
			end

			

			print("Queued delivery for:", accountToDeliverTo.Name)

			processDeliveryQueue()

            --if not success then
            --    print("Error running processDeliveryQueue:", result)
            --    ws:Close()
            --end
		end)
	end
end)


ws.OnClose:Connect(function()
    ISCONNECTED = false
end)