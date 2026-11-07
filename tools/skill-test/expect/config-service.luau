-- expect: a key never published falls back to the default; a test value overrides it and clears.
__skilltest.check("GetConfigAsync loaded", loaded == true)
__skilltest.eq("unpublished key -> default", bossHealth(), 500)
ConfigService:SetTestingValue("bossHealth", 200)
snapshot:Refresh()
__skilltest.eq("test value", bossHealth(), 200)
ConfigService:ClearTestingValue("bossHealth")
snapshot:Refresh()
__skilltest.eq("cleared -> default", bossHealth(), 500)
