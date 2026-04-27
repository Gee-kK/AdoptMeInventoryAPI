local Fsys = require(game.ReplicatedStorage:WaitForChild("Fsys")).load
local ClientData = Fsys("ClientData")

local inventory = ClientData.get("inventory")

local VERSION = "0.35"

local function toJSON(value, indent)
    indent = indent or 0
    local spacing = string.rep("    ", indent)

    if type(value) == "table" then
        local isArray = true
        local index = 1

        for k, _ in pairs(value) do
            if k ~= index then
                isArray = false
                break
            end
            index += 1
        end

        local result = {}

        if isArray then
            table.insert(result, "[")
            for i, v in ipairs(value) do
                table.insert(result,
                    string.rep("    ", indent + 1) ..
                    toJSON(v, indent + 1) ..
                    (i < #value and "," or "")
                )
            end
            table.insert(result, spacing .. "]")
        else
            table.insert(result, "{")
            local count = 0
            local total = 0

            for _ in pairs(value) do total += 1 end

            for k, v in pairs(value) do
                count += 1
                table.insert(result,
                    string.rep("    ", indent + 1) ..
                    '"' .. tostring(k) .. '": ' ..
                    toJSON(v, indent + 1) ..
                    (count < total and "," or "")
                )
            end
            table.insert(result, spacing .. "}")
        end

        return table.concat(result, "\n")

    elseif type(value) == "string" then
        return '"' .. value .. '"'
    else
        return tostring(value)
    end
end

print(toJSON(inventory))


game:GetService("StarterGui"):SetCore("SendNotification",{
	Title = "Adopt Me API",
	Text = `v{VERSION}`,
	Icon = ""
})