-- test-unitframes-preview-fit-frames.lua: on Frames, the unit frames live preview fits its pane: every frame kind, its cast line and its sample auras lie inside the pane at the options pane's width, and a resize fits it again (round 4: Opus #1, Astra #2; "ing Frostbolt" cut at the pane's edge).
assert(loadfile("Tools/regression/test-unitframes-preview-fit.lua"))("frames")
