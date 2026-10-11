-- expect: the action and binding exist with the properties the snippet sets.
__skilltest.eq("action under the context", action.Parent, playContext)
__skilltest.eq("Type is Bool", action.Type, Enum.InputActionType.Bool)
__skilltest.eq("DisplayName", action.DisplayName, "Sprint")
__skilltest.eq("binding under the action", binding.Parent, action)
__skilltest.eq("KeyCode", binding.KeyCode, Enum.KeyCode.LeftShift)
playContext:Destroy()
