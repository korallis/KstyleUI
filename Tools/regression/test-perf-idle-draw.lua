-- test-perf-idle-draw.lua: what the idle suite asks the renderer to draw stays bounded: no transparent nine-slice centre is shown, nothing runs every frame once the login fades end, no animation plays on a hidden owner, Frames and Orbs loop nothing, and shown regions stay under each style's ceiling.
local Suite = dofile("Tools/regression/suite_env.lua")
local CEILING = { frames = 2900, orbs = 2810, medallions = 1800 }
local SETTLE = 600

for _, style in ipairs({ "frames", "orbs", "medallions" }) do
	local env, K = Suite.Prepare(style, 1920, 1080)()
	local hollow = {}
	for name in pairs(K.Widgets.HOLLOW) do
		assert(K.Widgets.TEXTURE_TEXELS[name], "Widgets.HOLLOW names " .. name .. ", which is no sliced texture; list only nine-slice textures whose centre texels are all transparent")
		hollow[(K.Tokens.Texture(name))] = name
	end
	local frames, settled = 0, false
	while frames < SETTLE and not settled do
		frames = frames + 1
		settled = true
		env._now = env._now + 1 / 60
		for _, f in ipairs(env._frames) do
			local update = f._scripts.OnUpdate
			if update and f:IsVisible() then
				settled = false
				update(f, 1 / 60)
			end
		end
		env.RunTimers()
	end
	assert(settled, style .. ": an OnUpdate still runs after " .. SETTLE .. " idle frames; stop per-frame scripts when their work is done (Motion's driver clears its own when no tween runs)")
	local shown = 0
	local function Groups(owner, visible, what)
		for _, group in ipairs(owner._groups or {}) do
			local looping = group:IsPlaying() and group:GetLooping()
			if looping and looping ~= "NONE" then
				assert(visible, style .. ": a " .. looping .. " loop plays on a hidden " .. what .. "; stop it on hide and play it again on show")
				assert(style == "medallions", style .. ": a " .. looping .. " loop plays at idle on a " .. what .. "; Frames and Orbs animate only while something changes")
			end
		end
	end
	for _, f in ipairs(env._frames) do
		local visible = f:IsVisible()
		Groups(f, visible, f._type)
		for _, r in ipairs(f._regions) do
			Groups(r, visible and r._shown ~= false, r._type)
			if visible and r._shown ~= false and r._type ~= "MaskTexture" then
				shown = shown + 1
				local file, coords = r._state.Texture and r._state.Texture[1], r._state.TexCoord
				local centre = coords and coords[1] > 0 and coords[2] < 1 and coords[3] > 0 and coords[4] < 1
				assert(not (hollow[file] and centre), style .. ": the centre piece of a " .. tostring(hollow[file]) .. " nine-slice is shown; its texels are transparent, so ShowSlice and PaintSlice keep it hidden (Core/Widgets/Base.lua)")
			end
		end
	end
	assert(shown <= CEILING[style], string.format("%s: %d shown regions at idle, ceiling %d; build art on first use and hide what draws nothing, or raise the ceiling to the measured count when the new regions are drawn", style, shown, CEILING[style]))
	assert(#env._errors == 0 and K.ErrorCount() == 0, style .. ": the idle suite raised " .. tostring(env._errors[1]))
	print(string.format("idle draw ok: %s settles in %d frames with %d shown regions (ceiling %d)", style, frames, shown, CEILING[style]))
end
