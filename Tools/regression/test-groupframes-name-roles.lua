-- test-groupframes-name-roles.lua: one measured face and size per party, semantic names in roomy lanes, whole compact raid names, and saved choices across restyles.
local G = dofile("Tools/regression/group_env.lua")
local Looks = dofile("Tools/regression/group_looks.lua")
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

local function uniform(ns, path, what)
	local size
	ns.Unit.ForEach(function(f)
		if f.kind == "party" and f.unit then
			local face, current = f.name:GetFont()
			eq(face, path, what .. ": every row has the chosen face")
			assert(not size or W.Near(size, current), what .. ": every row has one size")
			size = current
		end
	end)
	return size
end

local function fits(K, ns, f, what)
	local text = f.name:GetText()
	local _, size = f.name:GetFont()
	assert(ns.Names.Width(f.name, text, size) <= f.nameWidth + 0.01, what .. ": the displayed name fits")
	assert(size >= K.Widgets.FontSize(f.name, f.nameFit.min) - 0.001, what .. ": fitting respects the existing floor")
end

-- The captioned rows of KSTY-31's party card, which KSTY-57 left a choice.
do
	local env, K, ns = G.New({ saved = Looks.Saved(Looks.PARTY_CARD) })
	G.SetRoster(env, "party", {
		{ name = "Thaldren", class = "WARRIOR", role = "TANK", health = 72 },
		{ name = "Kragar", class = "SHAMAN", role = "DAMAGER", health = 60 },
	})
	assert(K.Modules.Enable("GroupFrames"))
	env.RunTimers()
	local tank, shaman = member(ns, "party1"), member(ns, "party2")
	local legacy = K.Tokens.FontPath("AlegreyaSansRegular")
	eq(font(tank), legacy, "captioned party lanes deliberately keep the compact face")
	local originalSize = uniform(ns, legacy, "short party")
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
	ns.Names.Set(tank, "Thaldrenwick")
	eq(tank.name:GetText(), "Thaldrenwick", "a twelve-letter party member stays whole beside the class caption")
	local groupSize = uniform(ns, legacy, "twelve-letter party")
	assert(groupSize < originalSize, "one longer row makes the whole party step down")
	ns.Names.Set(tank, "Thaldren")
	assert(W.Near(uniform(ns, legacy, "short names restored"), originalSize), "shortening that row restores the whole group")
	K.Options.Write("GroupFrames", "party.classLine", false)
	env.RunTimers()
	uniform(ns, (K.Tokens.Font("names")), "roomy party without class captions")
	K.Options.Write("GroupFrames", "party.classLine", true)
	K.Options.Write("GroupFrames", "party.width", 500)
	env.RunTimers()
	uniform(ns, (K.Tokens.Font("names")), "wider user party")
	K.Options.Write("GroupFrames", "party.width", 278)
	env.RunTimers()
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
	local nativeLong = string.rep("Shadow", 10)
	ns.Names.Set(tank, nativeLong)
	eq(tank.name:GetText(), nativeLong, "explicit global name data stays whole for the native setter")
	ns.Names.Set(tank, "Thaldren")
	assert(K.Theme.SetFontFace("Lumen"))
	env.RunTimers()
	eq(font(tank), legacy, "the compact kit treatment returns without a reload")
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
	eq(tank.rawName, long, "oversized data remains available for a later refit")
	assert(tank.name:GetText():find("...", 1, true), "an out-of-contract long name is explicitly abbreviated")
	uniform(ns, legacy, "oversized name")
	local _, size = tank.name:GetFont()
	assert(W.Near(size, K.Widgets.FontSize(tank.name, tank.nameFit.min)), "a long name stops at the existing party floor")
	local secret = env.Secret("Hidden")
	ns.Names.Set(tank, secret)
	eq(tank.name._state.Text[1], secret, "a secret name reaches the native setter unchanged")
	eq(tank.rawName, nil, "secret data is never retained for fitting")
	ns.Style.Apply(tank)
	local _, secretSize = tank.name:GetFont()
	assert(W.Near(secretSize, K.Widgets.FontSize(tank.name, tank.nameFit.min)), "a secret-name restyle stays at the floor without reading the name back")
	uniform(ns, legacy, "secret member")
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
	K.Options.Write("GroupFrames", "raid.width", 200)
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

do
	local env, K = G.New()
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(300, 420)
	local preview = K.Options.Preview("GroupFrames")(parent)
	local names = (K.Tokens.Font("names"))
	local function previewSize()
		local size, count
		count = 0
		for _, f in ipairs(preview.partyFrames) do
			local face, current = f.name:GetFont()
			eq(face, names, "the preview uses the live party's names face (KSTY-57)")
			assert(not size or W.Near(size, current), "preview members have one size")
			eq(f.nameGroup, preview.partyFrames, "the preview has its own party membership")
			eq(f.name:GetText(), f.sample.name, "the sample name stays whole")
			size, count = current, count + 1
		end
		return size, count
	end
	local original, count = previewSize()
	eq(count, 3, "all three preview samples participate")
	G.SetRoster(env, "party", { { name = string.rep("Shadow", 10), class = "WARRIOR", health = 72 } })
	assert(K.Modules.Enable("GroupFrames"))
	env.RunTimers()
	assert(W.Near(previewSize(), original), "the real roster does not shrink the preview group")
	local last = preview.partyFrames[1]
	local name = last.sample.name
	last.sample.name = "Mhaldrenwick"
	preview:Refresh()
	assert(previewSize() < original, "one longer preview member steps down the entire group")
	last.sample.name = name
	preview:Refresh()
	assert(W.Near(previewSize(), original), "restoring the sample name restores the whole group")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

print("ok")
