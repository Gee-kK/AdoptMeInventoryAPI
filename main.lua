local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ScreenGui = game:GetService("Players")
local VirtualUser = game:GetService('VirtualUser')

local Fsys = require(game.ReplicatedStorage:WaitForChild("Fsys")).load
local ClientData = Fsys("ClientData")
local RouterClient = Fsys("RouterClient")

local inventory = ClientData.get("inventory")
local INVENTORY_ID_TO_IGNORE = {
    ["stickers_2024_ham_and_pineapple_pizza_misc"] = true,
    ["stickers_2024_cloud_1_environment"] = true,
    ["pride_2024_gender_fluid_flag_misc"] = true,
    ["stickers_2024_raccoon_pet"] = true,
    ["stickers_2024_tree_2_environment"] = true,
    ["pride_2024_omnisex_flag_misc"] = true,
    ["pride_2024_gender_queer_flag_misc"] = true,
    ["stickers_2024_spiral_emote"] = true,
    ["stickers_2024_laugh_cry_emote"] = true,
    ["stickers_2024_smile_emote"] = true,
    ["stickers_2024_eyes_emote"] = true,
    ["pride_2024_gay_man_flag_misc"] = true,
    ["stickers_2024_mushroom_pizza_misc"] = true,
    ["stickers_2024_cool_emote"] = true,
    ["pride_2024_agender_flag_misc"] = true,
    ["pride_2024_transgender_flag_misc"] = true,
    ["stickers_2024_plain_cheese_pizza_misc"] = true,
    ["pride_2024_progress_pride_flag_misc"] = true,
    ["stickers_2024_pepperoni_pizza_misc"] = true,
    ["stickers_2024_grey_cat_pet"] = true,
    ["pride_2024_bi_flag_misc"] = true,
    ["stickers_2024_bucks_misc"] = true,
    ["stickers_2024_rose_environment"] = true,
    ["stickers_2024_question_mark_emote"] = true,
    ["stickers_2024_tree_1_environment"] = true,
    ["pride_2024_aromantic_flag_misc"] = true,
    ["stickers_2024_angry_emote"] = true,
    ["pride_2024_lesbian_flag_misc"] = true,
    ["pride_2024_pan_flag_misc"] = true,
    ["stickers_2024_sweat_emote"] = true,
    ["pride_2024_enby_flag_misc"] = true,
    ["stickers_2024_heart_emote"] = true,
    ["stickers_2024_exclamation_emote"] = true,
    ["stickers_2024_confetti_emote"] = true,
    ["stickers_2024_surprised_emote"] = true,
    ["stickers_2024_question_emote"] = true,
    ["stickers_2024_star_emote"] = true,
    ["stickers_2024_grass_platform_environment"] = true,
    ["pride_2024_ace_flag_misc"] = true,
    ["stickers_2024_mouse_pet"] = true,
    ["stickers_2024_zzz_emote"] = true,
    ["pride_2024_intersex_flag_misc"] = true,
    ["stickers_2024_tree_3_environment"] = true,
    ["stickers_2024_fire_emote"] = true,
    ["pride_2024_demi_flag_misc"] = true,
    ["stickers_2024_cloud_2_environment"] = true,
    ["stickers_2024_100_emote"] = true,
	["trade_license"] = true,
	["ice_skates"] = true,
	["squeaky_bone_default"] = true,
	["stroller-default"] = true,
	["sandwich-default"] = true,
	["beach_2024_mahi_spinning_rod_temporary"] = true,
	["ice_dimension_2025_ice_soup_bait"] = true,
	["blue_cap"] = true,
	["cowbell"] = true,
	["white_bowtie"] = true,
	["practice_dog"] = true
}

local VERSION = "1.1"
local HANDSHAKE_COMPLETED = false
local ISCONNECTED = false

local ws = WebSocket.connect("wss://goatedwebsocket.duckdns.org/ws/")

local isProcessingDelivery = false
local deliveryQueue = {}


local currentOrderId      = nil
local cancelledOrders     = {}

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
	if not list or #list == 0 then return nil end
	return table.remove(list)
end

local function extractInventoryData(data, categorized)
	categorized = categorized or {}
	for _, v in pairs(data) do
		if type(v) == "table" then
			if (v.category or v.id) and not INVENTORY_ID_TO_IGNORE[v.id] then
				local cat = tostring(v.category or "unknown")
				local id  = tostring(v.id       or "unknown")
				if not categorized[cat] then categorized[cat] = {} end
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
	local categorized = extractInventoryData(ClientData.get("inventory"))
	local payload = {}
	for cat, items in pairs(categorized) do
		local itemList = {}
		for _, itemData in pairs(items) do
			table.insert(itemList, itemData)
		end
		table.insert(payload, { category = cat, items = itemList })
	end
	return payload
end


local function tryCloseTrade()
	pcall(function()
		local tradeFrame = game.Players.LocalPlayer.PlayerGui.TradeApp.Frame
		if tradeFrame.Visible then
			RouterClient.get("TradeAPI/CancelTrade"):FireServer()
		end
	end)
end


local function deliverItems(targetPlayer, itemsToDeliver, orderId)
	local inventoryIndex = flattenInventory(ClientData.get("inventory"))

	local allItemsFlattened = {}
	for _, entry in ipairs(itemsToDeliver) do
		if #(inventoryIndex[entry.name] or {}) < entry.amount then
			warn("Not enough items for:", entry.name)
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

	for batchIndex, currentBatch in ipairs(batches) do

		if cancelledOrders[orderId] then
			print(string.format("[Order #%s] Cancelled before batch %d — aborting delivery.", tostring(orderId), batchIndex))
			tryCloseTrade()
			return false
		end

		print(string.format("[Order #%s] Starting batch %d/%d (%d items) for %s",
			tostring(orderId), batchIndex, #batches, #currentBatch, targetPlayer.Name))

		RouterClient.get("TradeAPI/SendTradeRequest"):FireServer(targetPlayer)

		if not game.Players.LocalPlayer.PlayerGui.TradeApp.Frame.Visible then
			repeat
				if cancelledOrders[orderId] then
					print(string.format("[Order #%s] Cancelled while waiting for trade window.", tostring(orderId)))
					tryCloseTrade()
					return false
				end
				task.wait(2)
				RouterClient.get("TradeAPI/SendTradeRequest"):FireServer(targetPlayer)
			until game.Players.LocalPlayer.PlayerGui.TradeApp.Frame.Visible
		end

		for _, itemId in ipairs(currentBatch) do
			if cancelledOrders[orderId] then
				print(string.format("[Order #%s] Cancelled mid-batch — closing trade.", tostring(orderId)))
				tryCloseTrade()
				return false
			end

			local itemUid = takeUnique(inventoryIndex, itemId)
			if itemUid then
				RouterClient.get("TradeAPI/AddItemToOffer"):FireServer(itemUid)
				task.wait(0.25)
			else
				warn("Ran out of uniques for:", itemId)
			end
		end

		task.wait(7)

		if cancelledOrders[orderId] then
			print(string.format("[Order #%s] Cancelled before accepting — closing trade.", tostring(orderId)))
			tryCloseTrade()
			return false
		end

		RouterClient.get("TradeAPI/AcceptNegotiation"):FireServer()

		if game:GetService("Players").LocalPlayer.PlayerGui.TradeApp.Frame.NegotiationFrame.Body.MyOffer.Accepted.ImageTransparency ~= 0.3 then
			repeat
				task.wait(1)
				RouterClient.get("TradeAPI/AcceptNegotiation"):FireServer()
			until game:GetService("Players").LocalPlayer.PlayerGui.TradeApp.Frame.NegotiationFrame.Body.MyOffer.Accepted.ImageTransparency == 0.3
			   or game.Players.LocalPlayer.PlayerGui.TradeApp.Frame.ConfirmationFrame.Visible
		end

		if not game.Players.LocalPlayer.PlayerGui.TradeApp.Frame.ConfirmationFrame.Visible then
			repeat task.wait(0.5) until game.Players.LocalPlayer.PlayerGui.TradeApp.Frame.ConfirmationFrame.Visible
		end

		task.wait(0.5)

		RouterClient.get("TradeAPI/ConfirmTrade"):FireServer()

		if game:GetService("Players").LocalPlayer.PlayerGui.TradeApp.Frame.ConfirmationFrame.MyOffer.Accepted.ImageTransparency ~= 0.3 then
			repeat
				task.wait(1)
				RouterClient.get("TradeAPI/ConfirmTrade"):FireServer()
			until game:GetService("Players").LocalPlayer.PlayerGui.TradeApp.Frame.ConfirmationFrame.MyOffer.Accepted.ImageTransparency == 0.3
			   or game:GetService("Players").LocalPlayer.PlayerGui.TradeApp.Frame.Visible == false
		end

		task.wait(2)
	end

	return true
end

local function processDeliveryQueue()
	if isProcessingDelivery then return end
	isProcessingDelivery = true

	while #deliveryQueue > 0 do
		local job = table.remove(deliveryQueue, 1)

		if cancelledOrders[job.orderId] then
			print(string.format("[Order #%s] Skipped — was cancelled while queued.", tostring(job.orderId)))
			cancelledOrders[job.orderId] = nil
			continue
		end

		currentOrderId = job.orderId

		local targetPlayer = game.Players:FindFirstChild(job.player)
		if not targetPlayer then
			print("Waiting for player:", job.player)
			repeat
				if cancelledOrders[job.orderId] then
					print(string.format("[Order #%s] Cancelled while waiting for player.", tostring(job.orderId)))
					break
				end
				task.wait(1)
				targetPlayer = game.Players:FindFirstChild(job.player)
			until targetPlayer or cancelledOrders[job.orderId]
		end

		if cancelledOrders[job.orderId] then
			cancelledOrders[job.orderId] = nil
			currentOrderId = nil
			continue
		end

		print(string.format("[Order #%s] Processing delivery for: %s", tostring(job.orderId), targetPlayer.Name))

		local completed = deliverItems(targetPlayer, job.order, job.orderId)

		cancelledOrders[job.orderId] = nil
		currentOrderId = nil

		if completed then
			ws:Send(HttpService:JSONEncode({
				type     = "DELIVERYCOMPLETED",
				username = game.Players.LocalPlayer.Name,
				payload  = buildPayload()
			}))

			game:GetService("StarterGui"):SetCore("SendNotification", {
				Title = "Delivery Complete",
				Text  = "Delivered to " .. targetPlayer.Name,
				Icon  = ""
			})
		else
			print(string.format("[Order #%s] Delivery aborted.", tostring(job.orderId)))

			game:GetService("StarterGui"):SetCore("SendNotification", {
				Title = "Order Cancelled",
				Text  = "Order #" .. tostring(job.orderId) .. " was cancelled.",
				Icon  = ""
			})
		end

		task.wait(1)
	end

	isProcessingDelivery = false
end


ws:Send(HttpService:JSONEncode({
	type     = "IDENTIFICATION",
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

		game:GetService("Players").LocalPlayer.Idled:Connect(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
	end

	if data.type == "REQUEST_INVENTORY" then
		print("Server requested inventory. Sending...")
		ws:Send(HttpService:JSONEncode({
			type     = "INVENTORY_DATA",
			username = game.Players.LocalPlayer.Name,
			payload  = buildPayload()
		}))
	end

	if data.type == "DELIVERY" then
		task.spawn(function()
			local orderId = data.orderId

			print(string.format("[Order #%s] Received delivery order for: %s", tostring(orderId), tostring(data.buyer)))

			table.insert(deliveryQueue, {
				player  = data.buyer,
				order   = data.order,
				orderId = orderId
			})

			local accountToDeliverTo = game.Players:FindFirstChild(data.buyer)
			if not accountToDeliverTo then
				repeat
					task.wait(2)
					accountToDeliverTo = game.Players:FindFirstChild(data.buyer)
				until accountToDeliverTo
			end

			print(string.format("[Order #%s] Queued delivery for: %s", tostring(orderId), accountToDeliverTo.Name))
			processDeliveryQueue()
		end)
	end

	if data.type == "DELIVERY_CANCELLED" then
		local orderId = data.orderId

		print(string.format("[Order #%s] Cancellation received from dashboard (buyer: %s)", tostring(orderId), tostring(data.buyer)))

		cancelledOrders[orderId] = true

		for i = #deliveryQueue, 1, -1 do
			if deliveryQueue[i].orderId == orderId then
				table.remove(deliveryQueue, i)
				cancelledOrders[orderId] = nil
				print(string.format("[Order #%s] Removed from queue before processing.", tostring(orderId)))
				break
			end
		end

		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "Order Cancelled",
			Text  = "Order #" .. tostring(orderId) .. " cancelled by dashboard.",
			Icon  = ""
		})
	end
end)

ws.OnClose:Connect(function()
	ISCONNECTED = false
end)