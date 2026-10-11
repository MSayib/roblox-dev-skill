-- expect: the tween ran to its goal before Completed fired.
__skilltest.eq("BackgroundTransparency reached 0", frame.BackgroundTransparency, 0)
__skilltest.eq("PlaybackState Completed", tween.PlaybackState, Enum.PlaybackState.Completed)
