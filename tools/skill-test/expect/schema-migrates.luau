-- expect: v1 and v2 saves migrate to v3, v3 is untouched, a newer save is refused.
local schema = skilltestModule :: any
local v1 = { Coins = 5, inventory = { "Sword", "Sword", "Potion" } }
local m = schema.migrate(v1)
__skilltest.eq("v1 -> version 3", m.version, 3)
__skilltest.eq("v1 Coins renamed coins", m.coins, 5)
__skilltest.eq("v1 Coins removed", m.Coins, nil)
__skilltest.eq("v1 gems added", m.gems, 0)
__skilltest.eq("v1 list -> counts (Sword)", m.inventory.Sword, 2)
__skilltest.eq("v1 list -> counts (Potion)", m.inventory.Potion, 1)
__skilltest.eq("stored v1 table left as it was", `{v1.Coins}/{v1.inventory[1]}`, "5/Sword")
local m2 = schema.migrate({ version = 2, coins = 7, inventory = { "Shield" } })
__skilltest.eq("v2 -> v3 keeps coins", m2.coins, 7)
__skilltest.eq("v2 -> v3 counts", m2.inventory.Shield, 1)
local v3 = schema.default()
v3.coins = 9
v3.inventory = { Bow = 2 }
local m3 = schema.migrate(v3)
__skilltest.eq("v3 unchanged", `{m3.version}/{m3.coins}/{m3.inventory.Bow}`, "3/9/2")
__skilltest.check("a v4 save is refused (errors)", not pcall(schema.migrate, { version = 4 }))
