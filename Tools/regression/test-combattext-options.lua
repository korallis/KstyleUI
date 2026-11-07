-- test-combattext-options.lua: KstyleUI_CombatText's settings page, its checks on saved values, its live preview and its smoke check.
local CT = dofile("Tools/regression/combattext_env.lua")
local Shown = CT.Shown

-- The settings page declares every customisation ----------------------------------------------------

do
	local _, K = CT.New()
	local schema = K.Options.Get("CombatText")
	assert(schema, "CombatText registers a settings page")
	local keys = {}
	for _, row in ipairs(schema) do
		if row.key then
			keys[row.key] = row.type
		end
	end
	local expected = {
		worldFont = "toggle", worldFace = "font", style = "dropdown", font = "font", size = "slider",
		outline = "dropdown", format = "dropdown", duration = "slider", maxPerFrame = "slider",
		damage = "toggle", heals = "toggle", misses = "toggle", colorMode = "dropdown",
		damageColor = "color", healColor = "color", missColor = "color", critScale = "slider",
		critColor = "toggle", critTint = "color", playerPlacement = "dropdown", framePoint = "dropdown",
		distance = "slider", groupSize = "slider", ["units.player"] = "toggle", ["units.target"] = "toggle",
		["units.targettarget"] = "toggle", ["units.focus"] = "toggle", ["units.focustarget"] = "toggle", ["units.pet"] = "toggle",
		["units.boss"] = "toggle", ["units.party"] = "toggle", ["units.raid"] = "toggle",
		["units.nameplate"] = "toggle", blizzardSelf = "dropdown", blizzardTargets = "dropdown",
	}
	for key, rowType in pairs(expected) do
		assert(keys[key] == rowType, "the page has a " .. rowType .. " row for " .. key .. ", got " .. tostring(keys[key]))
	end
	assert(type(K.Options.Preview("CombatText")) == "function", "the page has a live preview")
	local defaults = K.Store.Defaults("CombatText")
	assert(defaults.enabled == nil or defaults.enabled == false, "the module is off by default")
end

-- Saved values that are not allowed fall back to the defaults ----------------------------------------

do
	local env, K, ns = CT.New({
		saved = CT.Saved({
			style = "spin", size = 900, outline = "SHOUTY", format = 7, duration = -1, maxPerFrame = 0.5,
			critScale = 40, colorMode = "rainbow", healColor = { r = "green" }, font = "not a font",
		}),
	})
	CT.Enable(env, K)
	local cfg = ns.Module.cfg
	assert(cfg.style == "rise" and cfg.size == 18 and cfg.flags == "OUTLINE" and cfg.format == "short", "bad style, size, outline and format use the defaults")
	assert(cfg.duration == 1.2 and cfg.maxPerFrame == 4 and cfg.critScale == 1.4 and cfg.colorMode == "school", "bad numbers and choices use the defaults")
	local r, g, b = K.Tokens.Color("friendly")
	assert(cfg.healR == r and cfg.healG == g and cfg.healB == b, "a broken colour uses the default colour")
	assert(cfg.fontPath == K.Tokens.FontPath("SourceSans3Semibold"), "a font that is not a font path uses the default")
	CT.Hit(env, "player", "HEAL", "", env.Secret(3), 2)
	assert(#Shown(ns) == 1 and env._errors[1] == nil, "the module works with the repaired settings")
end

-- The preview animates sample numbers while it is shown, with the current settings -------------------

do
	local env, K = CT.New()
	local W = CT.W
	local root = K.Scale.Root()
	local holder = env.CreateFrame("Frame", nil, root)
	local preview = K.Options.Preview("CombatText")(holder)
	assert(type(preview) == "table" and preview.GetObjectType, "the preview builder returns a frame")
	assert(type(preview.Refresh) == "function", "the preview refreshes after a setting changes")
	assert(not K.Modules.IsRunning("CombatText"), "the preview works while the module is off")
	local pool = preview.pool
	assert(pool, "the preview has its own pool")
	local words, heals, damage, most = 0, 0, 0, 0
	for _ = 1, 120 do
		W.Tick(env, 0.05)
		most = math.max(most, #pool.active)
		local newest = pool.active[#pool.active]
		local text = newest and CT.Text(env, newest)
		if text == "Dodge" then
			words = words + 1
		elseif type(text) == "string" and text:sub(1, 1) == "+" then
			heals = heals + 1
		elseif type(text) == "string" and text:find("^short%(") then
			damage = damage + 1
		end
	end
	assert(words > 0 and heals > 0 and damage > 0, "the preview cycles through damage, heals and words")
	local onField, onFrame = 0, 0
	for _, number in ipairs(pool.active) do
		local _, relative = number.frame:GetPoint(1)
		if relative == preview.field then
			onField = onField + 1
		elseif relative == preview.unitFrame then
			onFrame = onFrame + 1
		end
	end
	assert(onField > 0 and onFrame > 0, "the preview shows numbers in your field and on a sample unit frame")
	assert(onField <= 4 and onFrame <= 4 and most > 2, "each place keeps to the per-frame limit, got " .. onField .. " and " .. onFrame)

	K.Options.Write("CombatText", "size", 26)
	preview:Refresh()
	assert(#pool.active == 0, "a refresh clears the old samples")
	W.Tick(env, 1)
	local _, size = CT.LastCall(pool.active[1].text, "SetFont")
	assert(size == 26, "the preview uses the new size, got " .. tostring(size))

	preview:Hide()
	preview:GetScript("OnHide")(preview)
	assert(#pool.active == 0, "hiding the preview clears its numbers")
	assert(env._errors[1] == nil, tostring(env._errors[1]))
end

-- The smoke check reports what the module saw ----------------------------------------------------------

do
	local env, K = CT.New()
	CT.Enable(env, K)
	CT.Hit(env, "player", "WOUND", "", env.Secret(10), 4)
	CT.Hit(env, "nameplate3", "WOUND", "", 25, 4)
	K.DevTest.Run()
	local line
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		if entry.message:find("combat text", 1, true) then
			line = entry.message
		end
	end
	assert(line and line:find("^PASS"), "the smoke check passes, got " .. tostring(line))
	assert(line:find("2 UNIT_COMBAT", 1, true) and line:find("1 secret amount", 1, true), "the smoke check counts events and secret amounts: " .. line)
	assert(line:find("nameplate", 1, true), "the smoke check says whether nameplate units fired: " .. line)
end

print("combat text options ok")
