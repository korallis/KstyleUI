-- test-nameplates-bible.lua: the KSTY-44 bible's plate. No ornament on or around the bar at any ornament level; a plate on a nameplate the game restricts for measurement builds, takes a target, a cast, effects and a setting change with no measuring and no error; nothing moves a plate or its pieces after it builds (Lee saw plates "dart around"), so a target change only shows or hides the brackets; the brackets close in once at full motion and never on a restyle; the level diamond and the right-hand raid marker stay clear of the brackets on every screen.
local N = dofile("Tools/regression/nameplates_env.lua")
local Scene = dofile("Tools/render/scene.lua")
local A = dofile("Tools/regression/auras_env.lua")

local MEASURE = "Can't measure restricted regions"
local UNIT = { name = "Bloodtalon Matriarch", health = 29800, maxHealth = 48000, level = 40, classification = "elite", reaction = 2, canAttack = true, raid = 8 }
local CAST = { name = "Molten Pulse", text = "Molten Pulse", texture = 135808, notInterruptible = false }
local SCREENS = { { 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 }, { 5120, 1440 }, { 3840, 2160 }, { 2383, 1540 }, { 3456, 2234 } }
local MOVES = { "SetPoint", "ClearAllPoints", "SetAllPoints", "SetSize", "SetWidth", "SetHeight", "SetScale" }

local function edge(bar)
	local c = N.Last(bar.under.edgeHard, "SetColorTexture")
	return c[1], c[2], c[3]
end

local function errors(env, K, label)
	assert(#env._errors == 0 and K.ErrorCount() == 0, label .. ": no error, got " .. tostring(env._errors[1]))
end

local function counts(frames)
	local out = {}
	for i, frame in ipairs(frames) do
		local n = 0
		for _, method in ipairs(MOVES) do
			n = n + #N.Calls(frame, method)
		end
		out[i] = n
	end
	return out
end

-- No ornament on a plate, at Subtle or Full -----------------------------------------------------------------

for _, level in ipairs({ "Subtle", "Full" }) do
	for _, screen in ipairs({ { 1920, 1080 }, { 5120, 1440 } }) do
		local env, K, ns = N.New({ width = screen[1], height = screen[2] })
		local widgets = K.Store.Module("Widgets")
		widgets.cardMaterial, widgets.ornaments = "ForgedBrackets", level
		K.Callbacks.Fire("SettingChanged", "Widgets", "ornaments")
		N.Add(env, "nameplate1", UNIT)
		N.Target(env, "nameplate1")
		N.Cast(env, "nameplate1", CAST)
		local plate = ns.Plates.Get("nameplate1")
		local where = level .. " " .. screen[1] .. "x" .. screen[2]
		assert(plate.ornament == nil, where .. ": a plate owns no ornament handle")
		local seen = 0
		for _, object in ipairs(A.Descendants(plate)) do
			if object:GetObjectType() == "Texture" then
				seen = seen + 1
				local file = object:GetTexture()
				assert(not (type(file) == "string" and file:find("Ornament")), where .. ": no ornament art anywhere on the plate, got " .. tostring(file))
			end
		end
		assert(seen > 10, where .. ": the check saw the plate's textures, got " .. seen)
		errors(env, K, where)
	end
end

-- A restricted nameplate: build, target, cast, effects and a setting change measure nothing -------------------

do
	local env, K, ns = N.New({ width = 1920, height = 1080, uiScale = 768 / 1080 })
	env._textWidth = function(text, fontPath, size)
		return Scene.TextWidth(Scene.PlainText(text), size, fontPath)
	end
	env.WorldFrame:SetPoint("TOPLEFT")
	env.WorldFrame:SetPoint("BOTTOMRIGHT")
	local base = N.Base(env)
	N.Add(env, "nameplate1", UNIT, { base = base })
	N.Add(env, "nameplate2", UNIT)
	local plate = ns.Plates.Get("nameplate1")
	assert(plate.health:IsAnchoringRestricted() == true, "the plate's bar on a restricted nameplate is restricted")
	local ok, err = pcall(plate.health.GetLeft, plate.health)
	assert(not ok and tostring(err):find(MEASURE, 1, true), "the stub raises the game's error when a restricted region is measured")
	N.Target(env, "nameplate1")
	N.Cast(env, "nameplate1", CAST)
	N.Debuffs(env, "nameplate1", 8)
	N.Target(env, "nameplate2")
	N.Focus(env, "nameplate1")
	env._units.nameplate1.classification = "rare"
	env.FireEvent("UNIT_CLASSIFICATION_CHANGED", "nameplate1")
	K.Options.Write("Nameplates", "level.show", false)
	K.Options.Write("Nameplates", "target.color", { r = 0.9, g = 0.1, b = 0.1 })
	for _ = 1, 20 do N.Tick(env, 0.05) end
	env.RunTimers()
	errors(env, K, "a restricted plate through target, cast, effects, focus, rank and settings changes")
end

-- Nothing moves a plate or its pieces after it builds --------------------------------------------------------

do
	local env, K, ns = N.New()
	N.Add(env, "nameplate1", UNIT)
	N.Add(env, "nameplate2", { name = "Riverglade Snapper", level = 37, reaction = 2, canAttack = true })
	N.Debuffs(env, "nameplate1", 3)
	env.RunTimers()
	local plate = ns.Plates.Get("nameplate1")
	local watched = { plate, plate.health, plate.name, plate.level, plate.raid, plate.cast, plate.auras, plate.brackets, plate.brackets.sides[1], plate.brackets.sides[2] }
	local names = { "plate", "bar", "name", "diamond", "raid marker", "cast", "effects", "brackets", "left bracket", "right bracket" }
	local before = counts(watched)
	N.Target(env, "nameplate1")
	N.Target(env, "nameplate2")
	N.Target(env, "nameplate1")
	N.Focus(env, "nameplate1")
	N.Focus(env, nil)
	N.Cast(env, "nameplate1", CAST)
	for _ = 1, 30 do N.Tick(env, 0.05) end
	env._units.nameplate1.health = 1200
	env.FireEvent("UNIT_HEALTH", "nameplate1")
	N.Debuffs(env, "nameplate1", 6)
	env._units.nameplate1.raid = nil
	env.FireEvent("RAID_TARGET_UPDATE")
	env._units.nameplate1.classification = "normal"
	env.FireEvent("UNIT_CLASSIFICATION_CHANGED", "nameplate1")
	env.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "nameplate1")
	env.FireEvent("UNIT_FLAGS", "nameplate1")
	local after = counts(watched)
	for i = 1, #watched do
		assert(after[i] == before[i], string.format("the %s takes no anchor, size or scale call after it builds, got %d", names[i], after[i] - before[i]))
	end
	assert(plate.brackets:IsShown(), "the target's brackets show")
	errors(env, K, "the moves check")
end

-- The brackets close in once, at full motion only, never on a restyle -----------------------------------------

do
	local env, K, ns = N.New()
	N.Add(env, "nameplate1", UNIT)
	N.Add(env, "nameplate2", UNIT)
	local plate = ns.Plates.Get("nameplate1")
	local side = plate.brackets.sides[1]
	local function plays()
		return #N.Calls(side.group, "Play")
	end
	N.Target(env, "nameplate1")
	assert(plays() == 1, "becoming the target closes the brackets in once")
	local open, close = N.Last(side.open, "SetOffset"), N.Last(side.close, "SetOffset")
	assert(open[1] < 0 and N.Same(open[1], -close[1]) and open[2] == 0, "the left bracket starts out to the left and comes back exactly to its place")
	assert(N.Last(side.close, "SetDuration")[1] == 0.12 and N.Last(side.close, "SetSmoothing")[1] == "OUT", "in 0.12 s, easing out, the bible's target-acquired timing")
	K.Widgets.RestyleAll()
	K.Options.Write("Nameplates", "name.size", 15)
	assert(plays() == 1, "a restyle keeps the brackets shown without playing them again")
	N.Target(env, "nameplate2")
	assert(not plate.brackets:IsShown() and #N.Calls(side.group, "Stop") > 0, "losing the target hides the brackets and stops their motion")
	K.Motion.SetLevel("reduced")
	N.Target(env, "nameplate1")
	assert(plate.brackets:IsShown() and plays() == 1, "at reduced motion the brackets show in place")
	K.Motion.SetLevel("full")
	errors(env, K, "the brackets")
end

-- The diamond, the brackets and the raid marker keep clear of each other on every screen -----------------------

for _, screen in ipairs(SCREENS) do
	local env, K, ns = N.New({ width = screen[1], height = screen[2] })
	N.Add(env, "nameplate1", UNIT)
	N.Target(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	local where = screen[1] .. "x" .. screen[2]
	local px = K.Scale.Pixel(1) / K.Widgets.ScaleFactor(plate)
	local reach = K.Widgets.Snap(plate, ns.Plate.BRACKET_REACH)
	local _, _, _, x = plate.level:GetPoint(1)
	local tip = -x - env.Look(plate.level:GetWidth()) / 2
	assert(tip >= reach + px - 1e-6, where .. ": the diamond's right point is a pixel clear of the left bracket")
	local _, _, _, rx = plate.raid:GetPoint(1)
	assert(rx >= reach - 1e-6, where .. ": the raid marker starts beyond the right bracket")
	local _, _, _, bx = plate.brackets.sides[2]:GetPoint(1)
	assert(N.Same(bx + env.Look(plate.brackets.sides[2]:GetWidth()), reach), where .. ": the right bracket's outer edge is at its reach")
	errors(env, K, where)
end

-- The target's bar keeps its black edge even when the target is also the focus; the brackets mark it ------------

do
	local env, K, ns = N.New()
	N.Add(env, "nameplate1", UNIT)
	local plate = ns.Plates.Get("nameplate1")
	N.Focus(env, "nameplate1")
	local fr, fg, fb = K.Tokens.Color("rare")
	assert(N.SameColor(fr, fg, fb, edge(plate.health)), "the focus alone takes the focus edge")
	N.Target(env, "nameplate1")
	assert(N.SameColor(0, 0, 0, edge(plate.health)) and plate.brackets:IsShown(), "the focus as the target keeps the black edge and shows the brackets")
	N.Target(env, nil)
	assert(N.SameColor(fr, fg, fb, edge(plate.health)), "and the focus edge comes back when it is no longer the target")
	errors(env, K, "focus and target")
end

-- With the level off, a marked unit's empty diamond still counts in the footprint ----------------------------------

do
	local env, K, ns = N.New()
	K.Options.Write("Nameplates", "level.show", false)
	K.Options.Write("Nameplates", "name.show", false)
	K.Options.Write("Nameplates", "cast.enabled", false)
	K.Options.Write("Nameplates", "debuffs.enabled", false)
	local sample = ns.Preview.samplePlate
	local width, above, height, below = ns.Stacking.Extent()
	assert(N.Same(width, ns.state.width + ns.Plate.DiamondReach(sample) + ns.Plate.BRACKET_REACH + 16), "the diamond's reach counts while classification marks are on, got " .. tostring(width))
	local overhang = (ns.Plate.DiamondSize(sample) - height) / 2
	assert(N.Same(above, overhang) and N.Same(below, overhang), "and its height above and below the bar")
	K.Options.Write("Nameplates", "markers.classification", false)
	local bare = ns.Stacking.Extent()
	assert(N.Same(bare, ns.state.width + ns.Plate.BRACKET_REACH * 2 + 16), "with both off only the brackets and the raid marker count, got " .. tostring(bare))
	errors(env, K, "the footprint")
end

-- The settings preview shows one sample, the richest that fits, chosen from the plate's own extent -------------

do
	local env, K, ns = N.New()
	local holder = env.CreateFrame("Frame", nil, K.Scale.Root())
	holder:SetSize(400, 300)
	holder:SetPoint("CENTER")
	local preview = K.Options.Preview("Nameplates")(holder)
	preview:SetAllPoints(holder)
	preview:Refresh()
	local shown = {}
	for i, plate in ipairs(preview.plates) do
		if plate:GetParent():IsShown() then
			shown[#shown + 1] = i
		end
	end
	assert(#shown == 1 and shown[1] == 1, "a roomy preview shows the elite target sample alone, got " .. table.concat(shown, ","))
	local width = ns.Stacking.Extent(preview.plates[1])
	holder:SetSize(width - 1, 300)
	preview:Refresh()
	shown = {}
	for i, plate in ipairs(preview.plates) do
		if plate:GetParent():IsShown() then
			shown[#shown + 1] = i
		end
	end
	assert(#shown == 1, "a narrow preview still shows one sample, got " .. #shown)
	errors(env, K, "the preview")
end

print("nameplates bible ok")
