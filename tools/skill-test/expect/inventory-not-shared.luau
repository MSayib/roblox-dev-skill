-- expect: two new players get separate default tables (2.16.0 fixed a shared Inventory here).
local service = skilltestModule :: any
local a = { UserId = -910001, Name = "SkillTestA" } :: any
local b = { UserId = -910002, Name = "SkillTestB" } :: any
service.loadData(a)
service.loadData(b)
local da, db = service.getData(a), service.getData(b)
__skilltest.check("both players have session data", da ~= nil and db ~= nil)
if da and db then
	__skilltest.check("separate Inventory tables", da.Inventory ~= db.Inventory)
	table.insert(da.Inventory, "Sword")
	__skilltest.eq("an item given to A does not appear for B", #db.Inventory, 0)
	__skilltest.eq("defaults: 0 coins, level 1", `{db.Coins}/{db.Level}`, "0/1")
end
