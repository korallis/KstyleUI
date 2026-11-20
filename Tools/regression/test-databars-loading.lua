-- test-databars-loading.lua: post-load FPS waits for the next timed sample, including refreshes and tooltips.
local D = dofile("Tools/regression/databars_env.lua")
local env, K, ns, game = D.New()
local fps = ns.Strip.view.items.fps
for _, flags in ipairs({ { true, false }, { false, false }, { false, true } }) do
	game.fps = 240000
	env.FireEvent("PLAYER_ENTERING_WORLD", unpack(flags))
	assert(fps.value:GetText() == "--", "ignore the first FPS sample after every loading screen")
	ns.Strip.Refresh()
	assert(fps.value:GetText() == "--", "a refresh must not reintroduce the loading-screen sample")
	ns.Strip.ShowTooltip(fps)
	for _, row in ipairs(K.Widgets.Tooltip().used) do
		assert(not (row.right:GetText() or ""):find("240000", 1, true), "the tooltip must ignore the loading-screen sample too")
	end
	game.fps = 143.6
	env.RunTickers()
	assert(fps.value:GetText() == "144", "the next timed FPS sample resumes normal rounding")
end
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("databars loading ok")
