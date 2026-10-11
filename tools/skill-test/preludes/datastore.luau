-- prelude: the reader's DataStore and key. A store per case, so the examples, which a reader runs
-- one at a time, do not throttle each other on one key (they run at once here), and never touch
-- the "PlayerData" saves other examples use.
local DataStoreService = game:GetService("DataStoreService")
local playerStore = DataStoreService:GetDataStore("SkillTest_" .. script.Name)
local key = "SkillTest_1"
local playerKey = key
