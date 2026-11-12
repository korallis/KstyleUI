-- test-render-story-guard-dps.lua: the strict render guard finds nothing on the DPS story rail's two cards, at rest and with the owner's live story, on every screen of the matrix (render_story_guard_lib.lua).
local n = dofile("Tools/regression/render_story_guard_lib.lua")("DPS")
print("test-render-story-guard-dps: ok, " .. n .. " scenes")
