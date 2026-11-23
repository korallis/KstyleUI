-- test-role-fonts-modules.lua: an explicit role font reaches the GroupFrames party, loses to an element font, never reaches the Medallions raid tile or unit slab labels (which follow the number role and keep an element font equal to their own face), and leaves default geometry and records alone.
local G = dofile("Tools/regression/group_env.lua")
local W = dofile("Tools/regression/widget_env.lua")
local U = dofile("Tools/regression/unitframes_env.lua")
local D = dofile("Tools/regression/databars_env.lua")

local function eq(got, want, what)
	assert(got == want, what .. ": want " .. tostring(want) .. ", got " .. tostring(got))
end

local ROLE_FACE = "CinzelUnit"
local OTHER = "Interface\\AddOns\\OtherMedia\\Second.ttf"

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

local function uniform(ns, path, what)
	local size
	ns.Unit.ForEach(function(f)
		if f.kind == "party" and f.unit then
			local face, current = f.name:GetFont()
			eq(face, path, what .. ": every row has the face")
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

-- GroupFrames: party names, in the captioned rows of KSTY-31's party card (KSTY-57's bare rows take names; see
-- test-groupframes-rows.lua).
do
	local Looks = dofile("Tools/regression/group_looks.lua")
	local env, K, ns = G.New({ saved = Looks.Saved(Looks.PARTY_CARD) })
	G.SetRoster(env, "party", {
		{ name = "Thaldren", class = "WARRIOR", role = "TANK", health = 72 },
		{ name = "Kragar", class = "SHAMAN", role = "DAMAGER", health = 60 },
	})
	assert(K.Modules.Enable("GroupFrames"))
	env.RunTimers()
	local tank, shaman = member(ns, "party1"), member(ns, "party2")
	local compact = ns.Settings.COMPACT_NAME_FONT
	local names = K.Tokens.FontPath("AlegreyaSansRegular")
	eq(compact, names, "the compact constant is still Alegreya Sans Regular")
	eq(ns.Settings.THEME_FONT, "theme", "the follow sentinel is unchanged")
	eq(K.Store.Defaults("GroupFrames").text.nameFont, "theme", "the saved default is the sentinel, not a captured file")
	local kit = (K.Tokens.Font("names"))
	eq((tank.name:GetFont()), kit, "a captioned party's names fit their Medallions lanes in the names face by default")
	local healthFace = (tank.healthText:GetFont())
	eq(healthFace, (K.Tokens.Font("number")), "the health default follows the number role")
	K.Options.Write("Appearance", "roleFontNumber", ROLE_FACE)
	env.RunTimers()
	eq((tank.healthText:GetFont()), K.Tokens.FontPath(ROLE_FACE), "health text follows an explicit number role")
	K.Options.Write("Appearance", "roleFontNumber", "")
	env.RunTimers()
	local parts, caption = tank.parts, tank.classLine:GetText()
	local nameWidth, healthTop, roleLeft = parts.name.width, parts.health.top, parts.icons.role.left
	local originalSize = uniform(ns, kit, "default party")

	K.Options.Write("Appearance", "roleFontNames", ROLE_FACE)
	env.RunTimers()
	local roleFace = K.Tokens.FontPath(ROLE_FACE)
	eq((tank.name:GetFont()), roleFace, "an explicit names role is used, not the compact default")
	eq((shaman.name:GetFont()), roleFace, "the whole party uses it")
	uniform(ns, roleFace, "role party")
	eq(tank.classLine:GetText(), caption, "the fixed class label is untouched")
	eq(tank.parts.name.width, nameWidth, "no lane moved")
	eq(tank.parts.health.top, healthTop, "the health bar did not move")
	eq(tank.parts.icons.role.left, roleLeft, "the role icon did not move")
	eq((tank.healthText:GetFont()), healthFace, "health text keeps its own default face")
	fits(K, ns, tank, "role party")
	ns.Names.Set(tank, "Thaldrenwick")
	assert(tank.name:GetText() == "Thaldrenwick" or tank.name:GetText():find("...", 1, true), "a longer name is whole or abbreviated, never lost")
	eq((tank.name:GetFont()), roleFace, "a longer name does not swap the role face for the compact one")
	local longName = string.rep("Shadow", 10)
	ns.Names.Set(tank, longName)
	eq((tank.name:GetFont()), roleFace, "even an out-of-contract name keeps the role face")
	assert(tank.name:GetText():find("...", 1, true), "and is abbreviated like a custom-face lane")
	local _, size = tank.name:GetFont()
	assert(W.Near(size, K.Widgets.FontSize(tank.name, tank.nameFit.min)), "it stops at the existing floor")
	ns.Names.Set(tank, "Thaldren")

	K.Options.Write("GroupFrames", "text.nameFont", OTHER)
	env.RunTimers()
	eq((tank.name:GetFont()), OTHER, "an element font beats the role font")
	K.Options.Write("GroupFrames", "text.nameFont", ns.Settings.THEME_FONT)
	env.RunTimers()
	eq((tank.name:GetFont()), roleFace, "returning to the sentinel follows the role again")

	assert(K.Theme.SetFontFace("InterSemiBold"))
	env.RunTimers()
	eq((tank.name:GetFont()), roleFace, "a whole-interface font loses to the role font")
	K.Options.Write("Appearance", "roleFontNames", "")
	env.RunTimers()
	eq((tank.name:GetFont()), (K.Tokens.Font("names")), "clearing the role follows the whole-interface font")
	assert(K.Theme.SetFontFace(""))
	env.RunTimers()
	eq((tank.name:GetFont()), kit, "and then the kit default returns exactly")
	local _, restored = tank.name:GetFont()
	assert(W.Near(restored, originalSize), "at its original size")
	eq(tank.parts.name.width, nameWidth, "default geometry is unchanged after the round trip")
	eq(K.Store.Module("GroupFrames").text.nameFont, "theme", "the saved element value never captured a file")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- GroupFrames: raid names on the Medallions tile take the number face (one typeface voice), whatever the names role.
do
	local env, K, ns = G.New()
	G.SetRoster(env, "raid", G.Members(5))
	assert(K.Modules.Enable("GroupFrames"))
	env.RunTimers()
	local f = member(ns, "raid1")
	local label = (K.Tokens.Font("number"))
	eq((f.name:GetFont()), label, "the raid tile labels its names in the number face")
	K.Options.Write("Appearance", "roleFontNames", ROLE_FACE)
	env.RunTimers()
	eq((f.name:GetFont()), label, "a names role does not reach the tile's label")
	assert(f.nameFit.kit == false, "the tile's label is no kit face: no compact swap")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- UnitFrames: the Medallions slab names in its label face (the number role), long names included; a names role does not
-- reach it and an element font beats it, even one equal to the role's own face.
do
	local env, K, ns = U.New()
	env._textWidth = D.TextWidth
	local focus = ns.Frames.Get("focus").views[1]
	assert(ns.Settings.Form("focus") == "slab", "the focus frame is a slab")
	local label = (K.Tokens.Font("number"))
	local function named(name)
		U.SetUnit(env, "focus", { name = name, level = 39, health = 300, healthMax = 400, reaction = 2, canAttack = true })
		env.FireEvent("UNIT_NAME_UPDATE", "focus")
		return (focus.name:GetFont())
	end
	eq(named("Elunara"), label, "a short name wears the slab's label face")
	eq(named("Elunara Frostweaver the Everlasting Moonshadow"), label, "a very long name keeps it as it shrinks")
	K.Options.Write("Appearance", "roleFontNames", ROLE_FACE)
	eq(named("Elunara Frostweaver"), label, "a names role does not reach the slab's label")
	K.Options.Write("UnitFrames", "focus.fonts.name.font", OTHER)
	eq(named("Elunara Frostweaver"), OTHER, "an element font beats the label face")
	K.Options.Write("UnitFrames", "focus.fonts.name.font", ns.Settings.THEME_FONT)
	K.Options.Write("Appearance", "roleFontNames", "")
	eq(named("Elunara Frostweaver"), label, "clearing both returns the label face")
	local own = (K.Tokens.Font(ns.Settings.Role("focus", "name")))
	K.Options.Write("UnitFrames", "focus.fonts.name.font", own)
	eq(named("Elunara Frostweaver"), own, "an element font equal to the role's own face is still the player's choice")
	K.Options.Write("UnitFrames", "focus.fonts.name.font", ns.Settings.THEME_FONT)
	K.Options.Write("Appearance", "roleFontNumber", "InterSemiBold")
	eq(named("Elunara Frostweaver"), K.Tokens.FontPath("InterSemiBold"), "a chosen number face reaches the slab's label")
	local form, forms = ns.Settings.Form, 0
	ns.Settings.Form = function(...) forms = forms + 1; return form(...) end
	ns.Settings.Font("focus", "name")
	ns.Settings.Form = form
	eq(forms, 1, "Settings.Font resolves the frame's form once")
	assert(#env._errors == 0, tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, "no errors caught by KstyleUI.Call")
end

print("role fonts modules ok")
