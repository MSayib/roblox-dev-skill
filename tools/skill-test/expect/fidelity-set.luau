-- expect: the plugin-level loop changed the tagged MeshPart (a game Script cannot: PluginOrOpenCloud).
__skilltest.eq("CollisionFidelity Box", decorative.CollisionFidelity, Enum.CollisionFidelity.Box)
__skilltest.eq("CanCollide off", decorative.CanCollide, false)
__skilltest.eq("CanQuery off", decorative.CanQuery, false)
decorative:Destroy()
