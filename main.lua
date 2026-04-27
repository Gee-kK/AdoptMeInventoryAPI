local Fsys = require(game.ReplicatedStorage:WaitForChild("Fsys")).load
local ClientData = Fsys("ClientData")

local inventory = ClientData.get("inventory")

local VERSION = "0.35"

local results = {}

local function collectItems(tbl)
    for _, value in pairs(tbl) do
        if type(value) == "table" then
            -- Check if this table looks like an item
            if value.category ~= nil or value.id ~= nil or value.unique ~= nil then
                table.insert(results, {
                    category = value.category,
                    id = value.id,
                    unique = value.unique
                })
            end

            -- Keep searching deeper
            collectItems(value)
        end
    end
end

collectItems(inventory)

-- Simple JSON encoder (array only)
local function toJSON(tbl)
    local lines = {"["}

    for i, item in ipairs(tbl) do
        table.insert(lines, "    {")
        table.insert(lines, '        "category": "' .. tostring(item.category) .. '",')
        table.insert(lines, '        "id": "' .. tostring(item.id) .. '",')
        table.insert(lines, '        "unique": "' .. tostring(item.unique) .. '"')
        table.insert(lines, "    }" .. (i < #tbl and "," or ""))
    end

    table.insert(lines, "]")
    return table.concat(lines, "\n")
end

print(toJSON(results))


game:GetService("StarterGui"):SetCore("SendNotification",{
	Title = "Adopt Me API",
	Text = `v{VERSION}`,
	Icon = ""
})