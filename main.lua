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
	["white_bowtie"] = true
}

local VERSION = "1.1"
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
			if (v.category or v.id) and not INVENTORY_ID_TO_IGNORE[v.id] then
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
			type = "INVENTORY_DATA",
			username = game.Players.LocalPlayer.Name,
			payload = buildPayload()
		}))

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
		print("Server requested inventory. Sending...")
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