-- expect: UpdateSourceAsync applied the transform (plugin level).
__skilltest.eq("Source transformed", target.Source, "print('after')")
target:Destroy()
