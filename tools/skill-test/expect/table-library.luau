-- expect: each table library call does what its comment says.
__skilltest.eq("table.find -> 2", idx, 2)
__skilltest.eq("table.create(10, 0) has 10", #zeros, 10)
__skilltest.eq("... filled with 0", zeros[10], 0)
__skilltest.eq("table.clear empties", #reusableTable, 0)
__skilltest.eq("table.isfrozen -> true", isProtected, true)
__skilltest.check("writing a frozen table errors", not pcall(function()
	(CONFIG :: any).MaxPlayers = 100
end))
__skilltest.check("table.clone makes a new table", copy ~= original)
__skilltest.eq("... with the same values", copy.coins, 10)
__skilltest.check("... and is shallow: nested tables are shared", copy.inventory == original.inventory)
