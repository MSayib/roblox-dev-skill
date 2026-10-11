-- expect: old DataStore2 data is merged once, then the profile is marked migrated.
local profile = { Data = { coins = 0, inventory = {}, migrated = false } }
local fake = { UserId = -910004 } :: any
migrateFromDataStore2(fake, profile)
__skilltest.eq("coins merged from the old store", profile.Data.coins, 99)
__skilltest.eq("inventory merged", profile.Data.inventory[1], "Bow")
__skilltest.eq("marked migrated", profile.Data.migrated, true)
profile.Data.coins = 5
migrateFromDataStore2(fake, profile)
__skilltest.eq("a second call changes nothing", profile.Data.coins, 5)
