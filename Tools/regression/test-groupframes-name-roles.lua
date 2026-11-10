-- test-groupframes-name-roles.lua: semantic names in roomy lanes, a deliberate legacy face for compact raid lanes, unchanged fixed labels, and saved name-font choices across restyles.
local G = dofile("Tools/regression/group_env.lua")
local W = dofile("Tools/regression/widget_env.lua")

local function eq(got, want, what)
	assert(got == want, what .. ": want " .. tostring(want) .. ", got " .. tostring(got))
end

local function member(ns, name)
	local found
	ns.Unit.ForEach(function(f)
		if f.unit == name then
			found = f
		end
	end)
	assert(found, "the roster draws " .. name)
	return found
end

local function font(f)
	return (f.name:GetFont())
end

local function fits(K, ns, f, what)
	local text = f.name:GetText()
	local _, size = f.name:GetFont()
	assert(ns.Names.Width(f.name, text, size) <= f.nameWidth + 0.01, what .. ": the displayed name fits")
	assert(size >= K.Widgets.FontSize(f.name, f.nameFit.min) - 0.001, what .. ": fitting respects the existing floor")
end

do
	local env, K, ns = G.New()
	G.SetRoster(env, "party", {
		{ name = "Thaldren", class = "WARRIOR", role = "TANK", health = 72 },
		{ name = "Kragar", class = "SHAMAN", role = "DAMAGER", health = 60 },
	})
	assert(K.Modules.Enable("GroupFrames"))
	env.RunTimers()
	local tank, shaman = member(ns, "party1"), member(ns, "party2")
	eq(font(tank), (K.Tokens.Font("names")), "party names resolve the semantic role")
	for _, row in ipairs(K.Options.Get("GroupFrames")) do
		if row.key == "text.nameFont" then
			local choices = row.options()
			eq(choices[1].value, ns.Settings.THEME_FONT, "the picker can reselect the semantic default")
			eq(choices[1].value, "theme", "the default choice saves a sentinel, not a captured face")
			eq(choices[1].label, K.L["KstyleUI font"], "the default has a readable picker label")
		end
	end
	eq(font(shaman), font(tank), "the party uses one name face")
	eq(tank.name:GetText(), "Thaldren", "the engine receives the full original name")
	assert(tank.nameWidth and shaman.nameWidth, "the class-caption lane is measured after its text is set")
	fits(K, ns, tank, "party tank")
	fits(K, ns, shaman, "party shaman")
	local parts, caption = tank.parts, tank.classLine:GetText()
	local custom = K.Tokens.FontPath("InterSemiBold")
	K.Options.Write("GroupFrames", "text.nameFont", custom)
	env.RunTimers()
	eq(font(tank), custom, "a saved name face wins over the role")
	eq(tank.classLine:GetText(), caption, "choosing a name face does not change the fixed class label")
	eq(tank.parts.name.width, parts.name.width, "a name face does not widen the lane")
	eq(tank.parts.health.top, parts.health.top, "a name face does not move the health bar")
	eq(tank.parts.icons.role.left, parts.icons.role.left, "a name face does not move the role icon")
	K.Callbacks.Fire("ScaleChanged")
	env.RunTimers()
	eq(font(tank), custom, "a scale restyle preserves the saved face")
	K.Options.Write("GroupFrames", "text.nameFont", ns.Settings.THEME_FONT)
	env.RunTimers()
	assert(K.Theme.SetFontFace("InterSemiBold"))
	env.RunTimers()
	eq(font(tank), (K.Tokens.Font("names")), "inherited names follow an actual theme-face change immediately")
	assert(K.Theme.SetFontFace("Lumen"))
	env.RunTimers()
	eq(font(tank), (K.Tokens.Font("names")), "the inherited face returns without a reload")
	K.Options.Write("GroupFrames", "party.healthText", "CURRENT_MAX")
	env.RunTimers()
	eq(tank.nameWidth, nil, "unreserved health text never gives the fitter a guessed full name lane")
	local _, currentSize = tank.name:GetFont()
	assert(W.Near(currentSize, K.Widgets.FontSize(tank.name, tank.nameFit.min)), "unknown health width uses native fitting at the floor")
	K.Options.Write("GroupFrames", "party.classLine", false)
	env.RunTimers()
	local _, uncaptionedSize = tank.name:GetFont()
	assert(W.Near(uncaptionedSize, K.Widgets.FontSize(tank.name, tank.nameFit.size)), "without a class caption, the existing native row keeps the requested size")
	K.Options.Write("GroupFrames", "party.classLine", true)
	K.Options.Write("GroupFrames", "party.healthText", "NONE")
	env.RunTimers()
	local long = string.rep("Shadow", 10)
	ns.Names.Set(tank, long)
	eq(tank.name:GetText(), long, "names-role data remains whole for native truncation")
	local _, size = tank.name:GetFont()
	assert(W.Near(size, K.Widgets.FontSize(tank.name, tank.nameFit.min)), "a long name stops at the existing party floor")
	local secret = env.Secret("Hidden")
	ns.Names.Set(tank, secret)
	eq(tank.name._state.Text[1], secret, "a secret name reaches the native setter unchanged")
	eq(tank.rawName, nil, "secret data is never retained for fitting")
	ns.Style.Apply(tank)
	local _, secretSize = tank.name:GetFont()
	assert(W.Near(secretSize, K.Widgets.FontSize(tank.name, tank.nameFit.min)), "a secret-name restyle stays at the floor without reading the name back")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

do
	local env, K, ns = G.New()
	local originalFont = K.Tokens.Font
	K.Tokens.Font = function(role)
		if role == "body" then
			return K.Tokens.FontPath("InterSemiBold"), 12, ""
		end
		return originalFont(role)
	end
	G.SetRoster(env, "raid", G.Members(5, function(i, m)
		if i == 1 then
			m.name = "Thaldrenwick"
		end
	end))
	assert(K.Modules.Enable("GroupFrames"))
	env.RunTimers()
	local f = member(ns, "raid1")
	local legacy = K.Tokens.FontPath("AlegreyaSansRegular")
	eq(font(f), legacy, "the compact raid deliberately keeps the proven Alegreya face")
	eq(f.name:GetText(), "Thaldrenwick", "the existing twelve-letter fixture stays whole")
	fits(K, ns, f, "compact raid")
	assert(K.Theme.SetFontFace("InterSemiBold"))
	env.RunTimers()
	eq(font(f), (K.Tokens.Font("names")), "an explicit global face overrides the compact default")
	assert(K.Theme.SetFontFace("Lumen"))
	env.RunTimers()
	eq(font(f), legacy, "returning to a kit restores the compact treatment")
	K.Options.Write("GroupFrames", "raid.width", 120)
	env.RunTimers()
	eq(font(f), (K.Tokens.Font("names")), "a roomy raid lane uses names")
	eq(f.name:GetText(), "Thaldrenwick", "the roomy raid also keeps the full data")
	fits(K, ns, f, "roomy raid")
	local custom = K.Tokens.FontPath("SourceSans3Regular")
	K.Options.Write("GroupFrames", "text.nameFont", custom)
	K.Options.Write("GroupFrames", "raid.width", 72)
	env.RunTimers()
	eq(font(f), custom, "a compact lane never replaces a saved custom face")
	K.Callbacks.Fire("ThemeChanged")
	env.RunTimers()
	eq(font(f), custom, "a theme restyle preserves the saved custom face")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

print("ok")
