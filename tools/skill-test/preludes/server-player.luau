--@skilltest: prelude players
-- prelude: a real player on the server (the playtest's), as a PlayerAdded handler would have.
local player: Player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
