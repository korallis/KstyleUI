-- test-bar-options.lua: every module keeps its saved bar keys, defaults, choices and off rules through the shared rows.
local specs = {
	{ "UnitFrames", "unitframes", "player.healthTexture", "player.healthColor", "player.healthCustom", "player.powerHeight" },
	{ "Nameplates", "nameplates", "cast.texture", "cast.colorSource", "cast.color", "cast.height" },
	{ "GroupFrames", "group", "health.texture", "health.colorSource", "health.color", "party.powerHeight" },
	{ "Cooldowns", "cooldowns", "bars.texture", "bars.colorSource", "bars.color", "bars.height" },
	{ "Meters", "meters", "damage.texture", "damage.colorSource", "damage.color", "damage.rowHeight" },
	{ "DataBars", "databars", "xp.texture", "xp.colorSource", "xp.color" },
}
for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	for _, spec in ipairs(specs) do
		local env, K = dofile("Tools/regression/" .. spec[2] .. "_env.lua").New({
			width = screen[1], height = screen[2], enabled = false, enable = false,
		})
		local before = K.Options.Copy(K.Store.Module(spec[1]))
		local page = K.Options.Get(spec[1])
		assert(K.Options.Get(spec[1]) == page, "cache each module's schema after opening its page")
		assert(K.Options.Equal(before, K.Store.Module(spec[1])), "opening bar options must not rewrite saved settings")
		if spec[1] == "UnitFrames" then K.Options.Write(spec[1], "edit", "player") end
		for i = 3, #spec do
			local key = spec[i]
			local row = assert(K.Options.Row(spec[1], key), "keep the existing bar key " .. key)
			local labels = { "Bar texture", "Bar colour", "Custom bar colour", "Bar height" }
			assert(row.label == K.L[labels[i - 2]], "use the same bar labels in every module")
			assert(K.Options.Equal(K.Options.Read(spec[1], key), K.Options.Default(spec[1], key)), "absent keys retain today's default")
			local value = i == 3 and K.Tokens.Texture("barGlass") or i == 4 and "custom"
				or i == 5 and { r = 0.2, g = 0.4, b = 0.6 } or row.max
			K.Options.Write(spec[1], key, value)
			assert(K.Options.Equal(K.Options.Read(spec[1], key), value), "bar choices use the existing storage key")
		end
		local custom = K.Options.Row(spec[1], spec[5])
		assert(custom.showWhen(K.Store.Module(spec[1])), "show the colour picker when custom is selected")
		local source = K.Options.Row(spec[1], spec[4])
		K.Options.Write(spec[1], spec[4], source.options[1].value)
		assert(not custom.showWhen(K.Store.Module(spec[1])), "hide the colour picker for another colour source")
		if spec[1] == "Nameplates" then
			K.Options.Write(spec[1], "cast.enabled", false)
			assert(source.disableWhen(K.Store.Module(spec[1])), "off disables the plate's cast bar options")
		elseif spec[1] == "GroupFrames" then
			K.Options.Write(spec[1], "party.power", false)
			assert(not K.Options.Row(spec[1], "party.powerHeight").showWhen(K.Store.Module(spec[1])), "off hides power height")
		elseif spec[1] == "UnitFrames" then
			K.Options.Write(spec[1], "player.power", false)
			assert(not K.Options.Row(spec[1], "player.powerTexture").showWhen(K.Store.Module(spec[1])), "off hides power options")
		elseif spec[1] == "Meters" then
			K.Options.Write(spec[1], "followRole", false)
			K.Options.Write(spec[1], "damage.shown", false)
			K.Options.Write(spec[1], "threat.shown", false)
			assert(source.disableWhen(K.Store.Module(spec[1])), "off disables meter bar options")
		end
		env.RunTimers()
		assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
	end
end
print("bar options ok: six modules, defaults, saved keys and off at four screen sizes")
