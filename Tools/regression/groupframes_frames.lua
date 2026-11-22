-- groupframes_frames.lua: Frames(G) makes G.New boot on the Frames HUD style for the *-frames.lua group frame tests: a saved profile carries it through migration 45, which gives the keys it never saved Frames' look; a fresh one picks it as the Options row does.
return function(G)
	local New = G.New
	function G.New(opts)
		if opts and opts.saved then opts.saved.profiles.Default.HudStyle = { style = "frames" } end
		local env, K, ns = New(opts)
		if not (opts and (opts.saved or opts.boot == false)) then K.Options.Write("HudStyle", "style", "frames") end
		return env, K, ns
	end
end
