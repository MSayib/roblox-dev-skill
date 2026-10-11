-- expect: UpdateAsync applied the transform (coins grew by 10 from whatever was stored).
__skilltest.check("UpdateAsync succeeded", success == true)
local updated = updatedValue :: any
__skilltest.check("returned table has coins >= 10", type(updated) == "table" and updated.coins >= 10, tostring(updated))
