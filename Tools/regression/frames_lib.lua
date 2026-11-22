-- frames_lib.lua: Frames(E) makes the test environment E's New pick the Frames HUD style, the default the tests written before Medallions became the default expect.
--
--   local D = dofile("Tools/regression/frames_lib.lua")(dofile("Tools/regression/databars_env.lua"))
return function(E)
	local New = E.New
	E.New = function(...)
		local out = { New(...) }
		out[2].Options.Write("HudStyle", "style", "frames")
		return unpack(out, 1, table.maxn(out))
	end
	return E
end
