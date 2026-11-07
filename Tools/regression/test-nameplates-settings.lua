-- test-nameplates-settings.lua: KstyleUI_Nameplates' rules, settings page, Layout element, preview and nameplate CVars.
local N = dofile("Tools/regression/nameplates_env.lua")
local Raises = N.CoreEnv.Raises
local Last = N.Last

-- The pure rules ------------------------------------------------------------------------------------

do
	local env, _, ns = N.New({ enable = false })
	local Logic = ns.Logic
	assert(type(Logic) == "table", "the module exposes its rules as Logic")

	-- Threat: a tank wants aggro, everyone else does not. nil means the unit is not on the threat list.
	assert(Logic.ThreatState(3, true) == "safe" and Logic.ThreatState(2, true) == "warning")
	assert(Logic.ThreatState(1, true) == "warning" and Logic.ThreatState(0, true) == "danger")
	assert(Logic.ThreatState(0, false) == nil and Logic.ThreatState(1, false) == "warning")
	assert(Logic.ThreatState(2, false) == "danger" and Logic.ThreatState(3, false) == "danger")
	assert(Logic.ThreatState(nil, true) == nil and Logic.ThreatState(nil, false) == nil)
	assert(Logic.ThreatState(env.Secret(3), true) == nil, "a secret status gives no state")
	assert(Logic.ThreatState(7, false) == nil and Logic.ThreatState("3", true) == nil, "nonsense gives no state")

	-- The colour a bar uses.
	assert(Logic.ColorKind("class", true, false) == "class")
	assert(Logic.ColorKind("class", false, false) == "reaction", "NPCs have no class colour")
	assert(Logic.ColorKind("reaction", true, false) == "reaction")
	assert(Logic.ColorKind("custom", true, false) == "custom")
	assert(Logic.ColorKind("custom", true, true) == "tapped", "a tapped unit is grey whatever the source")

	-- Classification markers.
	assert(Logic.MarkerColor("elite") == "neutral" and Logic.MarkerColor("worldboss") == "hostile")
	assert(Logic.MarkerColor("rare") == "rare" and Logic.MarkerColor("rareelite") == "rare")
	assert(Logic.MarkerColor("normal") == nil and Logic.MarkerColor("minus") == nil and Logic.MarkerColor(nil) == nil)
	assert(Logic.MarkerColor(env.Secret("elite")) == nil, "a secret classification is never used as a key")

	-- Level text.
	assert(Logic.LevelText(60) == "60" and Logic.LevelText(-1) == "??" and Logic.LevelText(0) == nil)
	assert(Logic.LevelText(env.Secret(5)) == nil and Logic.LevelText(nil) == nil)

	-- The plate's scale turns plate units into KstyleUI root units.
	assert(Logic.PlateScale(0.5, 1) == 0.5 and Logic.PlateScale(0.711, 0.64) > 1.1)
	assert(Logic.PlateScale(env.Secret(1), 1) == 1 and Logic.PlateScale(1, 0) == 1 and Logic.PlateScale(nil, 1) == 1)

	-- The CVar plan: names and values for the game, in a fixed order.
	local plan = Logic.CVarPlan({ maxDistance = 45, verticalDistance = 0, stacking = "enemy", selectedScale = 1.25, minScale = 0.8, clickSize = 3 })
	local byName = {}
	for _, entry in ipairs(plan) do
		byName[entry.name .. (entry.index and ("[" .. entry.index .. "]") or "")] = entry.value
	end
	assert(byName.nameplateMaxDistance == "45" and byName.nameplateMaxVerticalDistance == "0")
	assert(byName.nameplateSelectedScale == "1.25" and byName.nameplateMinScale == "0.8" and byName.nameplateSize == "3")
	assert(byName["nameplateStackingTypes[1]"] == true and byName["nameplateStackingTypes[2]"] == false)
	assert(byName.nameplateMotion == "1", "the older stacking CVar is in the plan as a fallback")
	plan = Logic.CVarPlan({ maxDistance = 45, verticalDistance = 0, stacking = "none", selectedScale = 1, minScale = 1, clickSize = 2 })
	for _, entry in ipairs(plan) do
		if entry.name == "nameplateStackingTypes" then
			assert(entry.value == false, "no stacking clears both bits")
		elseif entry.name == "nameplateMotion" then
			assert(entry.value == "0")
		end
	end
end

-- The settings page: every row validates at load, and the rules from the spec are there -------------

do
	local env, K, ns = N.New({ enable = false })
	local schema = K.Options.Get("Nameplates")
	assert(type(schema) == "table" and #schema > 0, "the module registers its settings page")
	assert(type(schema.preview) == "function", "the page has a live preview")
	local rows = {}
	for _, row in ipairs(schema) do
		if row.key then
			rows[row.key] = row
		end
	end
	local function need(key, kind)
		assert(rows[key], "the settings page needs " .. key)
		assert(rows[key].type == kind, key .. " is a " .. kind .. " row")
	end
	need("font", "font")
	for _, text in ipairs({ "name", "level", "healthText" }) do
		need(text .. ".show", "toggle")
		need(text .. ".size", "slider")
		need(text .. ".outline", "dropdown")
	end
	need("health.texture", "texture")
	need("health.orientation", "dropdown")
	need("health.reverse", "toggle")
	for _, kind in ipairs({ "enemy", "friendly" }) do
		need(kind .. ".colorSource", "dropdown")
		need(kind .. ".color", "color")
		local values = {}
		for _, option in ipairs(rows[kind .. ".colorSource"].options) do
			values[option.value] = true
		end
		assert(values.class and values.reaction and values.custom, kind .. " colour source offers class, reaction and custom")
	end
	need("threat.display", "dropdown")
	for _, key in ipairs({ "safe", "warning", "danger" }) do
		need("threat." .. key, "color")
	end
	need("target.colorSource", "dropdown")
	need("target.color", "color")
	need("focus.color", "color")
	need("markers.raidSize", "slider")
	need("cvars.enabled", "toggle")
	need("cvars.maxDistance", "slider")
	need("cvars.stacking", "dropdown")
	assert(rows["target.color"].showWhen(K.Store.Module("Nameplates")) == false, "the custom colour shows only for a custom source")

	-- A game setting the client does not have hides its row instead of showing a slider that does nothing.
	local settings = K.Store.Module("Nameplates")
	assert(rows["cvars.maxDistance"].showWhen and rows["cvars.maxDistance"].showWhen(settings), "the distance row shows while the client has the CVar")
	assert(rows["cvars.verticalDistance"].showWhen(settings), "and so does the height row")
	local distance, height = env._cvars.nameplateMaxDistance, env._cvars.nameplateMaxVerticalDistance
	env._cvars.nameplateMaxDistance, env._cvars.nameplateMaxVerticalDistance = nil, nil
	assert(not rows["cvars.maxDistance"].showWhen(settings), "a client without nameplateMaxDistance hides the distance row")
	assert(not rows["cvars.verticalDistance"].showWhen(settings), "and one without nameplateMaxVerticalDistance hides the height row")
	env._cvars.nameplateMaxDistance, env._cvars.nameplateMaxVerticalDistance = distance, height

	-- A value the setting does not allow reads as the default, with one devlog line.
	K.Store.Module("Nameplates").threat.display = "sparkles"
	assert(ns.Settings.Get("threat.display") == "glow", "an unknown choice reads as the default")
	K.Store.Module("Nameplates").name.size = 400
	assert(ns.Settings.Get("name.size") == rows["name.size"].max, "a size out of range clamps")
	K.Store.Module("Nameplates").enemy.color = { r = 2, g = 0, b = 0 }
	local hr = K.Tokens.Color("hostile")
	assert(ns.Settings.Get("enemy.color").r == hr, "a colour out of range reads as the default")
	Raises(function() ns.Settings.Get("nope") end, "unknown setting", "an unknown key")
end

-- The Layout element: a sample plate that sizes every plate ------------------------------------------

do
	local env, K, ns = N.New()
	local el = K.Layout.Element("nameplates.plate")
	assert(el, "the module registers the sample plate with Layout")
	assert(el.module == "Nameplates" and el.opts.resizable, "the sample is resizable and belongs to the module")
	assert(not ns.Sample:IsShown(), "the sample hides outside Layout Mode")
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	local width = K.Layout.Get("nameplates.plate").width
	assert(plate.health.opts.width == width, "plates take the sample's width")
	assert(K.Layout.Set("nameplates.plate", "width", 180))
	assert(plate.health.opts.width == K.Layout.Get("nameplates.plate").width and plate.health.opts.width ~= width, "resizing the sample resizes every plate")
	assert(K.Layout.Set("nameplates.plate", "height", 16))
	assert(plate.health.opts.height == K.Layout.Get("nameplates.plate").height, "and their height")

	assert(K.Layout.Enter(), "Layout Mode opens")
	assert(ns.Sample:IsShown(), "the sample shows in Layout Mode")
	K.Layout.Exit(true)
	assert(not ns.Sample:IsShown(), "and hides after it")
end

-- The live preview -----------------------------------------------------------------------------------

do
	local env, K = N.New()
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	local preview = K.Options.Preview("Nameplates")(parent)
	assert(type(preview) == "table" and preview:GetParent() == parent, "the preview builds inside the pane")
	assert(type(preview.Refresh) == "function", "the preview refreshes after a setting changes")
	local sample = preview.plates[1]
	K.Options.Write("Nameplates", "name.size", 15)
	preview:Refresh()
	assert(Last(sample.name, "SetFont")[2] == 15, "the preview follows the settings")
	assert(#env._errors == 0, "the preview raised no error: " .. tostring(env._errors[1]))
end

-- Nameplate CVars: only when asked, only out of combat, back to the game's defaults when turned off ----

do
	local env, K, ns = N.New()
	assert(#env._cvarWrites == 0, "the module leaves CVars alone by default")
	K.Options.Write("Nameplates", "cvars.enabled", true)
	assert(env._cvars.nameplateMaxDistance == tostring(ns.Settings.Get("cvars.maxDistance")), "turning CVars on applies the distance")
	assert(env._stacking[1] == true and env._stacking[2] == false, "stacking applies to enemies by default")

	env.SetCombat(true)
	K.Options.Write("Nameplates", "cvars.maxDistance", 30)
	assert(env._cvars.nameplateMaxDistance ~= "30", "a change in combat waits")
	env.SetCombat(false)
	assert(env._cvars.nameplateMaxDistance == "30", "and applies when combat ends")

	K.Options.Write("Nameplates", "cvars.enabled", false)
	assert(env._cvars.nameplateMaxDistance == "60" and env._cvars.nameplateSize == "2", "turning CVars off restores the game's defaults")
	assert(env._stacking[1] == false and env._stacking[2] == false, "and clears the stacking bits")
end

do
	local env, K = N.New({ noBitfield = true, motion = true })
	K.Options.Write("Nameplates", "cvars.enabled", true)
	assert(env._cvars.nameplateMotion == "1", "without nameplateStackingTypes, stacking uses nameplateMotion")
	K.Modules.Disable("Nameplates")
	env.RunTimers()
	assert(env._cvars.nameplateMotion == "0", "disabling the module restores the defaults it changed")
end

do
	local env, K = N.New({ saved = nil })
	env._cvars.nameplateSelectedScale = nil
	K.Options.Write("Nameplates", "cvars.enabled", true)
	local wrote = false
	for _, write in ipairs(env._cvarWrites) do
		wrote = wrote or write.name == "nameplateSelectedScale"
	end
	assert(not wrote, "a CVar the client lacks is skipped")
	local logged = false
	for _, entry in ipairs(K.Store.Data().devlog) do
		logged = logged or (entry.module == "Nameplates" and entry.message:find("nameplateSelectedScale", 1, true) ~= nil)
	end
	assert(logged, "and logged")
end

print("nameplates settings ok")
