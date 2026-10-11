-- expect: JSONDecode turns the body into a Luau table.
local decoded = jsonData :: any
__skilltest.eq("coins", decoded.coins, 50)
__skilltest.eq("items[1]", decoded.items[1], "Sword")
