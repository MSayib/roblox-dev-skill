--!strict
-- Test double for the legacy DataStore2 module (datastore-persistence.md migration example): a
-- store that already holds a player's old save. Not the real library; the example only calls
-- DataStore2(name, player):Get(default).
return function(_name: string, _player: Player)
	return {
		Get = function(_self: any, _default: any)
			return { coins = 99, inventory = { "Bow" } }
		end,
	}
end
