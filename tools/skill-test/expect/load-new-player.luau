-- expect: a player with no save gets the current default (through the real DataStore).
local fake = { UserId = -910003, Kick = function(_self: any, _msg: string) end } :: any
local data = load(fake) :: any
__skilltest.check("default returned", data ~= nil)
if data then
	__skilltest.eq("default is version 3 with 0 coins", `{data.version}/{data.coins}`, "3/0")
end
