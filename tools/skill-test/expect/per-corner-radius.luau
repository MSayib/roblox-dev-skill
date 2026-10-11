-- expect: UICorner's per-corner properties exist and hold what was set.
__skilltest.eq("TopLeftRadius", corner.TopLeftRadius, UDim.new(0, 16))
__skilltest.eq("BottomLeftRadius (flat)", corner.BottomLeftRadius, UDim.new(0, 0))
__skilltest.eq("parented to the bubble", corner.Parent, bubble)
