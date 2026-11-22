-- test-unitframes-aura-overflow-frames.lua: on Frames, every frame's aura rows hold many auras cleanly: the engine sorts them (yours,
-- then priority, then time left), the rows stay inside the footprint the layouts keep for them, and past rows by
-- columns a "+N" chip covers the last socket. The chip is counted by a hidden AuraContainer's own flow layout through
-- anchors alone, so the module never reads a count, a size or an aura; here the stub plays the engine's layout pass.
assert(loadfile("Tools/regression/test-unitframes-aura-overflow.lua"))("frames")
