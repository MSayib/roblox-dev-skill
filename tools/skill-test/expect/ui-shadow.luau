-- expect: UIShadow is creatable at runtime and holds what was set.
__skilltest.eq("UIShadow under the card", shadow.Parent, card)
__skilltest.eq("BlurRadius", shadow.BlurRadius, UDim.new(0, 16))
__skilltest.eq("Offset", shadow.Offset, UDim2.fromOffset(0, 4))
