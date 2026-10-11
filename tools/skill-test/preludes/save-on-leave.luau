--@skilltest: prelude players
-- prelude: the reader's PlayerRemoving save handler.
local savedOnLeave: { Player } = {}
local function onPlayerRemoving(player: Player)
	table.insert(savedOnLeave, player)
end
